import 'package:flutter/material.dart';
import 'Menu_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'user_auth/firebase_auth_implementation/firebase_auth_services.dart';
import 'register.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndexbanner = 0;
  String userName = "Tamu"; // Default name
  bool isGuest = false; // Menandai apakah pengguna adalah tamu
  final FirebaseAuthService _authService = FirebaseAuthService();

  // Variabel untuk menyimpan data dari Firestore
  List<Map<String, dynamic>> categories = [];
  List<Map<String, dynamic>> recommendedItems = [];

  // Flag untuk menandakan proses loading
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _getUserInfo();
    _loadDataFromFirestore(); // Memuat data dari Firestore
  }
  // Bottom Navigation telah dipindahkan ke MainScreen

  // Fungsi untuk memuat data dari Firestore
  Future<void> _loadDataFromFirestore() async {
    try {
      // Memuat data kategori
      final categoriesSnapshot = await FirebaseFirestore.instance
          .collection('menu_categories')
          .orderBy('order')
          .get();

      setState(() {
        categories = categoriesSnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': data['name'],
            'icon': _getIconDataFromString(
                data['icon']), // Konversi string ke IconData
            'description': data['description'] ?? 'Tidak ada deskripsi',
          };
        }).toList();
      });

      // Memuat item-item rekomendasi
      final menuItemsSnapshot = await FirebaseFirestore.instance
          .collection('menu_items')
          .where('isRecommended',
              isEqualTo: true) // Filter item yang direkomendasikan
          .where('isAvailable', isEqualTo: true) // Hanya yang tersedia
          .limit(5) // Batasi jumlah item
          .get();

      setState(() {
        recommendedItems = menuItemsSnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': data['name'],
            'description': data['description'] ?? 'Tidak ada deskripsi',
            'price': data['price'],
            'image': data['image'],
            'rating': data['rating'] ?? 4.5,
            'category': data['category'],
            'fullDescription': data['fullDescription'] ??
                data['description'] ??
                'Tidak ada deskripsi',
            'ingredients': data['ingredients'] ?? 'Bahan dasar',
            'preparationTime': data['preparationTime'] ?? '15-20 menit',
            'availability':
                data['isAvailable'] ? 'Tersedia setiap hari' : 'Tidak tersedia'
          };
        }).toList();

        isLoading = false;
      });

      // Jika tidak ada item rekomendasi yang ditemukan, ambil beberapa item terbaru
      if (recommendedItems.isEmpty) {
        final recentItemsSnapshot = await FirebaseFirestore.instance
            .collection('menu_items')
            .where('isAvailable', isEqualTo: true)
            .orderBy('createdAt', descending: true)
            .limit(5)
            .get();

        setState(() {
          recommendedItems = recentItemsSnapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'name': data['name'],
              'description': data['description'] ?? 'Tidak ada deskripsi',
              'price': data['price'],
              'image': data['image'],
              'rating': data['rating'] ?? 4.5,
              'category': data['category'],
              'fullDescription': data['fullDescription'] ??
                  data['description'] ??
                  'Tidak ada deskripsi',
              'ingredients': data['ingredients'] ?? 'Bahan dasar',
              'preparationTime': data['preparationTime'] ?? '15-20 menit',
              'availability': data['isAvailable']
                  ? 'Tersedia setiap hari'
                  : 'Tidak tersedia'
            };
          }).toList();

          isLoading = false;
        });
      }

      // Memuat data menu item per kategori untuk daftar item di dialog detail kategori
      for (var i = 0; i < categories.length; i++) {
        final categoryName = categories[i]['name'];
        final menuItemsInCategory = await FirebaseFirestore.instance
            .collection('menu_items')
            .where('category', isEqualTo: categoryName)
            .where('isAvailable', isEqualTo: true)
            .limit(10)
            .get();

        setState(() {
          categories[i]['items'] = menuItemsInCategory.docs.map((doc) {
            final data = doc.data();
            return '${data['name']} (Rp ${data['price']})';
          }).toList();

          // Jika tidak ada item dalam kategori ini, buat pesan kosong
          if ((categories[i]['items'] as List).isEmpty) {
            categories[i]
                ['items'] = ['Tidak ada menu tersedia dalam kategori ini'];
          }
        });
      }
    } catch (e) {
      print('Error loading data from Firestore: $e');
      setState(() {
        isLoading = false;
      });

      // Menampilkan snackbar jika terjadi error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memuat data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Mengkonversi string nama icon menjadi IconData
  IconData _getIconDataFromString(String iconName) {
    switch (iconName) {
      case 'restaurant_menu':
        return Icons.restaurant_menu;
      case 'restaurant':
        return Icons.restaurant;
      case 'set_meal':
        return Icons.set_meal;
      case 'dinner_dining':
        return Icons.dinner_dining;
      case 'local_drink':
        return Icons.local_drink;
      case 'fastfood':
        return Icons.fastfood;
      case 'lunch_dining':
        return Icons.lunch_dining;
      default:
        return Icons.restaurant_menu;
    }
  }

  // Mendapatkan informasi pengguna dan status tamu
  void _getUserInfo() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        // Cek apakah pengguna adalah tamu
        isGuest = user.isAnonymous;

        // Set nama pengguna
        if (isGuest) {
          userName = "Tamu";
        } else {
          // Gunakan null-aware operators untuk menghindari error
          if (user.displayName != null) {
            userName = user.displayName!;
          } else if (user.email != null) {
            userName = user.email!.split('@')[0];
          } else {
            userName = "Pengguna";
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      body: isLoading
          ? _buildLoadingIndicator()
          : SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Banner untuk pengguna tamu
                    if (isGuest) _buildGuestBanner(),
                    const SizedBox(height: 24),
                    _buildPromoBanner(),
                    const SizedBox(height: 20),
                    _buildDineInTakeAwayOptions(),
                    const SizedBox(height: 12),
                    _buildSectionHeader('Kategori'),
                    const SizedBox(height: 16),
                    _buildCategories(),
                    const SizedBox(height: 24),
                    _buildSectionHeader('Rekomendasi'),
                    const SizedBox(height: 16),
                    _buildRecommendedItems(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  // Widget untuk menampilkan indikator loading
  Widget _buildLoadingIndicator() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.orange),
          SizedBox(height: 16),
          Text('Memuat data...', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  // Widget banner untuk pengguna tamu
  Widget _buildGuestBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.amber[800], size: 20),
              const SizedBox(width: 8),
              const Text(
                'Anda masuk sebagai Tamu',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Daftar akun untuk menyimpan riwayat pesanan dan akses ke semua fitur.',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const RegisterPage(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber[800],
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: const Size(120, 30),
              textStyle: const TextStyle(fontSize: 12),
            ),
            child: const Text('Daftar Akun'),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Halo, $userName!',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const Text(
            'Kuliner Nusantara',
            style: TextStyle(
              color: Colors.black,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      actions: [
        // Indikator status tamu
        if (isGuest)
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.amber.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Tamu',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPromoBanner() {
    // Definisikan item promo (hanya gambar)
    final List<String> imageUrls = [
      'assets/images/prasmanan.png',
      'assets/images/ikan_bakar.png',
      'assets/images/minuman.png',
    ];

    // Define background colors for indicators
    final List<Color> indicatorColors = [
      Colors.blue[700]!,
      Colors.green[700]!,
      Colors.orange[700]!,
    ];

    return Column(
      children: [
        SizedBox(
          height: 180, // Tinggi gambar banner
          child: PageView.builder(
            onPageChanged: (index) {
              setState(() {
                _currentIndexbanner = index % imageUrls.length;
              });
            },
            itemBuilder: (context, index) {
              final imageUrl = imageUrls[index % imageUrls.length];
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      spreadRadius: 1,
                      blurRadius: 5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    imageUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    errorBuilder: (context, error, stackTrace) {
                      // Placeholder jika gambar tidak dapat dimuat
                      return Container(
                        color: Colors.grey[300],
                        child: const Center(
                          child: Icon(
                            Icons.image,
                            size: 50,
                            color: Colors.grey,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
        // Indikator untuk slider
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            imageUrls.length,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: 8,
              width: _currentIndexbanner == index ? 24 : 8,
              decoration: BoxDecoration(
                color: _currentIndexbanner == index
                    ? indicatorColors[index]
                    : Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDineInTakeAwayOptions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildOptionButton(
          icon: Icons.restaurant,
          label: 'Makan di Tempat',
          color: Colors.blue[700]!,
          onTap: () {
            // Pastikan tipe orderType adalah String, bukan null
            String orderType = 'dine_in';
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MenuPage(orderType: orderType),
              ),
            );
          },
        ),
        _buildOptionButton(
          icon: Icons.delivery_dining,
          label: 'Bawa Pulang',
          color: Colors.orange[700]!,
          onTap: () {
            // Pastikan tipe orderType adalah String, bukan null
            String orderType = 'takeaway';
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MenuPage(orderType: orderType),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildOptionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: color,
              size: 24,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Memunculkan popup untuk detail kategori
  void _showCategoryDetailsDialog(Map<String, dynamic> category) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        category['icon'],
                        color: Colors.orange,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            category['name'],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            category['description'],
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 10),
                const Text(
                  'Menu Tersedia:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 10),
                if (category['items'] != null)
                  ...List.generate(
                    (category['items'] as List).length,
                    (index) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              category['items'][index],
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  const Text('Tidak ada menu tersedia',
                      style: TextStyle(fontSize: 14, color: Colors.grey)),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    // Navigasi ke halaman menu dengan filter kategori
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MenuPage(
                          orderType: 'dine_in',
                          // Tambahkan parameter kategori jika diperlukan
                          // category: category['name'],
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    minimumSize: const Size(double.infinity, 45),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Lihat Semua Menu'),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Tutup',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategories() {
    // Jika belum ada data kategori dari Firebase, tampilkan indikator loading
    if (categories.isEmpty) {
      return SizedBox(
        height: 100,
        child: Center(
          child: Text(
            'Tidak ada kategori tersedia',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
      );
    }

    return SizedBox(
      height: 100,
      child: Center(
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final category = categories[index];
            return GestureDetector(
              onTap: () {
                _showCategoryDetailsDialog(category);
              },
              child: Container(
                width: 80,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withAlpha(25),
                            spreadRadius: 1,
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Icon(
                        category['icon'],
                        color: Colors.orange,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      category['name'],
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Center(
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // Memunculkan popup untuk detail makanan rekomendasi
  void _showRecommendedItemDetails(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            padding: const EdgeInsets.all(0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Gambar menu dengan overlay gradien
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                      child: item['image'].toString().startsWith('http')
                          ? Image.network(
                              item['image'],
                              height: 180,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 180,
                                  color: Colors.grey[300],
                                  child: const Icon(
                                    Icons.image_not_supported,
                                    color: Colors.grey,
                                    size: 50,
                                  ),
                                );
                              },
                            )
                          : Image.asset(
                              item['image'],
                              height: 180,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 180,
                                  color: Colors.grey[300],
                                  child: const Icon(
                                    Icons.image_not_supported,
                                    color: Colors.grey,
                                    size: 50,
                                  ),
                                );
                              },
                            ),
                    ),
                    // Tombol tutup
                    Positioned(
                      top: 10,
                      right: 10,
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.8),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.black,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                    // Gradien overlay
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 60,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withOpacity(0.7),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Judul dan rating
                    Positioned(
                      bottom: 10,
                      left: 16,
                      right: 16,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            item['name'],
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.star,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${item['rating']}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // Detail makanan
                Flexible(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Harga
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Rp ${item['price']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.orange,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Deskripsi lengkap
                          const Text(
                            'Deskripsi',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            item['fullDescription'],
                            style: TextStyle(
                              color: Colors.grey[800],
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Bahan-bahan
                          const Text(
                            'Bahan-bahan',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            item['ingredients'],
                            style: TextStyle(
                              color: Colors.grey[800],
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Informasi tambahan
                          Row(
                            children: [
                              Expanded(
                                child: _buildInfoItem(
                                  icon: Icons.access_time,
                                  title: 'Waktu Persiapan',
                                  value: item['preparationTime'],
                                ),
                              ),
                              Expanded(
                                child: _buildInfoItem(
                                  icon: Icons.event_available,
                                  title: 'Ketersediaan',
                                  value: item['availability'],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          // Tombol pesan
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              // Navigasi ke halaman menu, hanya dengan orderType (yang wajib)
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => MenuPage(
                                    orderType: 'dine_in',
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              minimumSize: const Size(double.infinity, 45),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('Pesan Sekarang'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              color: Colors.orange,
              size: 18,
            ),
            const SizedBox(width: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendedItems() {
    // Jika belum ada data item rekomendasi dari Firebase, tampilkan pesan
    if (recommendedItems.isEmpty) {
      return Center(
        child: Text(
          'Tidak ada rekomendasi menu tersedia',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }

    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: recommendedItems.length,
      itemBuilder: (context, index) {
        final item = recommendedItems[index];
        return GestureDetector(
          onTap: () {
            _showRecommendedItemDetails(item);
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withAlpha(25),
                  spreadRadius: 1,
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                  child: item['image'].toString().startsWith('http')
                      ? Image.network(
                          item['image'],
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            print(
                                "Error loading image: ${item['image']} - $error");
                            return Container(
                              width: 100,
                              height: 100,
                              color: Colors.grey[300],
                              child: const Icon(
                                Icons.image_not_supported,
                                color: Colors.grey,
                              ),
                            );
                          },
                        )
                      : Image.asset(
                          item['image'],
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            print(
                                "Error loading image: ${item['image']} - $error");
                            return Container(
                              width: 100,
                              height: 100,
                              color: Colors.grey[300],
                              child: const Icon(
                                Icons.image_not_supported,
                                color: Colors.grey,
                              ),
                            );
                          },
                        ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['name'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item['description'],
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.star,
                                  color: Colors.amber,
                                  size: 16,
                                ),
                                Text(
                                  ' ${item['rating']}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'Rp ${item['price']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
