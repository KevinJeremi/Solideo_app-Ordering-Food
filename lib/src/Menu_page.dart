import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:food_ui/src/cart_provider.dart' as cart;
import 'package:food_ui/src/cart.dart';

class MenuPage extends StatefulWidget {
  final String orderType; // 'dine_in' atau 'takeaway'

  const MenuPage({Key? key, required this.orderType}) : super(key: key);

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedCategoryIndex = 0;
  bool _showSearch = false;
  final TextEditingController _searchController = TextEditingController();

  // Akses CartProvider untuk mengelola keranjang
  final CartProvider _cartProvider = CartProvider();

  // Daftar kategori menu
  List<Map<String, dynamic>> categories = [];

  // Data menu berdasarkan kategori
  Map<String, List<Map<String, dynamic>>> menuItems = {};

  // Flag untuk menandakan proses loading
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMenuData();
  }

  // Memuat data kategori dan menu dari Firestore
  Future<void> _loadMenuData() async {
    try {
      // 1. Memuat kategori dari Firestore
      final categoriesSnapshot = await FirebaseFirestore.instance
          .collection('menu_categories')
          .orderBy('order')
          .get();

      categories = categoriesSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'name': data['name'],
          'icon': _getIconForName(data['icon']),
        };
      }).toList();

      // Tambahkan kategori 'Semua' di awal
      categories.insert(0, {
        'name': 'Semua',
        'icon': Icons.restaurant_menu,
      });

      // 2. Memuat item menu dari Firestore
      final menuSnapshot = await FirebaseFirestore.instance
          .collection('menu_items')
          .where('isAvailable', isEqualTo: true)
          .get();

      // Inisialisasi map menuItems
      menuItems = {for (var category in categories) category['name']: []};

      // Proses item menu
      for (var doc in menuSnapshot.docs) {
        final item = {
          ...doc.data(),
          'id': doc.id, // Tambahkan ID dokumen
        };

        // Tambahkan ke kategori 'Semua'
        menuItems['Semua']!.add(item);

        // Tambahkan ke kategori spesifik
        if (menuItems.containsKey(item['category'])) {
          menuItems[item['category']]!.add(item);
        }
      }

      // Inisialisasi TabController
      setState(() {
        isLoading = false;
        _tabController = TabController(
          length: categories.length,
          vsync: this,
        );

        _tabController.addListener(() {
          if (!_tabController.indexIsChanging) {
            setState(() {
              _selectedCategoryIndex = _tabController.index;
            });
          }
        });
      });
    } catch (e) {
      print('Error loading menu data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memuat menu: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        isLoading = false;
      });
    }
  }

  // Konversi nama icon ke IconData
  IconData _getIconForName(String iconName) {
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
      default:
        return Icons.restaurant_menu;
    }
  }

  // Menambahkan item ke keranjang
  void _addToCart(Map<String, dynamic> item) {
    setState(() {
      _cartProvider.addItem(
        name: item['name'] as String,
        price: item['price'] as int,
        category: item['category'] as String,
        image: item['image'] as String,
      );
    });
    _showSnackBar('${item['name']} ditambahkan ke keranjang');
  }

  // Mengurangi item dari keranjang
  void _removeFromCart(String name) {
    setState(() {
      _cartProvider.removeItem(name);
    });
    _showSnackBar('$name dikurangi dari keranjang');
  }

  // Menampilkan snackbar
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Tampilan loading
    if (isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('Menu Restoran'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Colors.orange),
        ),
      );
    }

    // Jika tidak ada kategori atau menu
    if (categories.isEmpty || menuItems.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('Menu Restoran'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.no_meals, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                'Tidak ada menu yang tersedia',
                style: TextStyle(color: Colors.grey[600]),
              ),
              ElevatedButton(
                onPressed: _loadMenuData,
                child: const Text('Muat Ulang'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildOrderTypeHeader(),
          _buildCategoryTabs(),
          if (_showSearch) _buildSearchBar(),
          Expanded(
            child: SizedBox(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height * 0.7,
              child: TabBarView(
                controller: _tabController,
                children: categories.map((category) {
                  String categoryName = category['name'] as String;
                  List<Map<String, dynamic>> items =
                      menuItems[categoryName] ?? [];

                  // Filter berdasarkan pencarian jika aktif
                  if (_showSearch && _searchController.text.isNotEmpty) {
                    final query = _searchController.text.toLowerCase();
                    items = items.where((item) {
                      final name = (item['name'] as String).toLowerCase();
                      final description =
                          (item['description'] as String).toLowerCase();
                      return name.contains(query) ||
                          description.contains(query);
                    }).toList();
                  }

                  return _buildMenuList(items);
                }).toList(),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.orange,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CartPage(orderType: widget.orderType),
            ),
          ).then((_) {
            // Refresh UI ketika kembali dari halaman cart
            setState(() {});
          });
        },
        child: Stack(
          children: [
            const Icon(Icons.shopping_cart, color: Colors.white),
            if (_cartProvider.getTotalItems() > 0)
              Positioned(
                right: 0,
                top: 0,
                child: CircleAvatar(
                  backgroundColor: Colors.red,
                  radius: 8,
                  child: Text(
                    _cartProvider.getTotalItems().toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      title: const Text(
        'Menu Restoran',
        style: TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: Icon(
            _showSearch ? Icons.search_off : Icons.search,
            color: Colors.black,
          ),
          onPressed: () {
            setState(() {
              _showSearch = !_showSearch;
              if (!_showSearch) {
                _searchController.clear();
              }
            });
          },
        ),
      ],
    );
  }

  Widget _buildOrderTypeHeader() {
    final isBackgroundBlue = widget.orderType == 'dine_in';
    final label =
        widget.orderType == 'dine_in' ? 'Makan di Tempat' : 'Bawa Pulang';
    final icon = widget.orderType == 'dine_in'
        ? Icons.restaurant
        : Icons.delivery_dining;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: isBackgroundBlue ? Colors.blue[700] : Colors.orange[700],
      child: Row(
        children: [
          Icon(
            icon,
            color: Colors.white,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTabs() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: Colors.orange,
        unselectedLabelColor: Colors.grey,
        indicatorColor: Colors.orange,
        labelPadding: const EdgeInsets.symmetric(horizontal: 16.0),
        tabs: categories.map((category) {
          return Tab(
            text: category['name'] as String,
            icon: Icon(category['icon'] as IconData),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: 'Cari menu...',
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          filled: true,
          fillColor: Colors.grey[100],
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildMenuList(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.no_meals, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Tidak ada menu yang tersedia',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _buildMenuItem(item);
      },
    );
  }

  Widget _buildMenuItem(Map<String, dynamic> item) {
    // Ekstrak data dengan null safety
    final name = item['name'] as String? ?? 'Tidak ada nama';
    final description = item['description'] as String? ?? 'Tidak ada deskripsi';
    final price = item['price'] as int? ?? 0;
    final image = item['image'] as String? ?? 'https://placehold.co/400x300';
    final category = item['category'] as String? ?? 'Tidak ada kategori';
    final isRecommended = item['isRecommended'] as bool? ?? false;

    // Jumlah item dalam keranjang
    final quantity = _cartProvider.getItemQuantity(name);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Menu image
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
            child: Image.network(
              image,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 180,
                  color: Colors.grey[200],
                  child: const Center(
                    child: Icon(Icons.image_not_supported, color: Colors.grey),
                  ),
                );
              },
            ),
          ),

          // Menu info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and recommended badge
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (isRecommended)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.thumb_up,
                              size: 12,
                              color: Colors.orange[700],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Recommended',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                // Category badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    category,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Description
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 16),

                // Price and quantity controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Price
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Harga',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          'Rp ${price.toString()}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),

                    // Quantity controls
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          // Decrease button
                          IconButton(
                            onPressed: quantity > 0
                                ? () => _removeFromCart(name)
                                : null,
                            icon: Icon(
                              Icons.remove,
                              color: quantity > 0
                                  ? Colors.orange
                                  : Colors.grey[400],
                            ),
                            iconSize: 20,
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                          ),

                          // Quantity display
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              quantity.toString(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),

                          // Increase button
                          IconButton(
                            onPressed: () => _addToCart(item),
                            icon: const Icon(
                              Icons.add,
                              color: Colors.orange,
                            ),
                            iconSize: 20,
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
