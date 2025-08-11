import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import 'helper/currency_formatter.dart';
import 'order_detail.dart'; // Pastikan ini mengarah ke file yang benar

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Controller untuk mendeteksi scroll
  final ScrollController _activeScrollController = ScrollController();
  final ScrollController _pastScrollController = ScrollController();

  bool isLoading = true;
  bool isLoadingMore = false; // Flag untuk memuat data tambahan
  List<DocumentSnapshot> activeOrders = [];
  List<DocumentSnapshot> pastOrders = [];
  String errorMessage = '';

  // Untuk pagination / infinite scroll
  int activeOrdersLimit = 10; // Jumlah pesanan aktif yang dimuat awalnya
  int pastOrdersLimit = 10; // Jumlah riwayat pesanan yang dimuat awalnya
  bool hasMoreActiveOrders =
      true; // Flag untuk menandai jika masih ada data aktif
  bool hasMorePastOrders =
      true; // Flag untuk menandai jika masih ada data riwayat
  DocumentSnapshot?
      lastActiveOrderDoc; // Dokumen terakhir untuk query berikutnya
  DocumentSnapshot? lastPastOrderDoc; // Dokumen terakhir untuk query berikutnya

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Load data awal
    _loadOrders();

    // Tambahkan listener untuk scroll controllers
    _activeScrollController.addListener(_onActiveScroll);
    _pastScrollController.addListener(_onPastScroll);
  }

  @override
  void dispose() {
    // Hapus listener untuk menghindari memory leak
    _activeScrollController.removeListener(_onActiveScroll);
    _pastScrollController.removeListener(_onPastScroll);

    // Dispose controller
    _activeScrollController.dispose();
    _pastScrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // Listener untuk active orders scroll
  void _onActiveScroll() {
    if (_activeScrollController.position.pixels >=
            _activeScrollController.position.maxScrollExtent * 0.8 &&
        !isLoadingMore &&
        hasMoreActiveOrders) {
      _loadMoreActiveOrders();
    }
  }

  // Listener untuk past orders scroll
  void _onPastScroll() {
    if (_pastScrollController.position.pixels >=
            _pastScrollController.position.maxScrollExtent * 0.8 &&
        !isLoadingMore &&
        hasMorePastOrders) {
      _loadMorePastOrders();
    }
  }

  // Fungsi untuk memuat pesanan dari Firebase
  Future<void> _loadOrders() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = '';
      });

      // Reset pagination state
      activeOrdersLimit = 10;
      pastOrdersLimit = 10;
      hasMoreActiveOrders = true;
      hasMorePastOrders = true;
      lastActiveOrderDoc = null;
      lastPastOrderDoc = null;

      // Pastikan pengguna telah login
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        setState(() {
          isLoading = false;
          errorMessage = 'Anda harus login untuk melihat pesanan';
        });
        return;
      }

      // Ambil pesanan aktif (pending, preparing, ready)
      final QuerySnapshot activeOrdersSnapshot = await _firestore
          .collection('orders')
          .where('userId', isEqualTo: currentUser.uid)
          .where('status', whereIn: ['pending', 'preparing', 'ready'])
          .orderBy('orderTime', descending: true)
          .limit(activeOrdersLimit)
          .get();

      // Ambil pesanan selesai atau batal (completed, cancelled)
      final QuerySnapshot pastOrdersSnapshot = await _firestore
          .collection('orders')
          .where('userId', isEqualTo: currentUser.uid)
          .where('status', whereIn: ['completed', 'cancelled'])
          .orderBy('orderTime', descending: true)
          .limit(pastOrdersLimit)
          .get();

      setState(() {
        activeOrders = activeOrdersSnapshot.docs;
        pastOrders = pastOrdersSnapshot.docs;
        isLoading = false;

        // Update last document references
        if (activeOrdersSnapshot.docs.isNotEmpty) {
          lastActiveOrderDoc = activeOrdersSnapshot.docs.last;
        }
        if (pastOrdersSnapshot.docs.isNotEmpty) {
          lastPastOrderDoc = pastOrdersSnapshot.docs.last;
        }

        // Check if we have fewer results than the limit
        hasMoreActiveOrders =
            activeOrdersSnapshot.docs.length >= activeOrdersLimit;
        hasMorePastOrders = pastOrdersSnapshot.docs.length >= pastOrdersLimit;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Terjadi kesalahan: ${e.toString()}';
      });
    }
  }

  // Fungsi untuk memuat lebih banyak pesanan aktif
  Future<void> _loadMoreActiveOrders() async {
    if (!hasMoreActiveOrders || lastActiveOrderDoc == null) return;

    try {
      setState(() {
        isLoadingMore = true;
      });

      final User? currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final QuerySnapshot moreActiveOrdersSnapshot = await _firestore
          .collection('orders')
          .where('userId', isEqualTo: currentUser.uid)
          .where('status', whereIn: ['pending', 'preparing', 'ready'])
          .orderBy('orderTime', descending: true)
          .startAfterDocument(lastActiveOrderDoc!)
          .limit(activeOrdersLimit)
          .get();

      setState(() {
        if (moreActiveOrdersSnapshot.docs.isNotEmpty) {
          activeOrders.addAll(moreActiveOrdersSnapshot.docs);
          lastActiveOrderDoc = moreActiveOrdersSnapshot.docs.last;
        }

        // Check if we should stop pagination
        hasMoreActiveOrders =
            moreActiveOrdersSnapshot.docs.length >= activeOrdersLimit;
        isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        isLoadingMore = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memuat data tambahan: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Fungsi untuk memuat lebih banyak riwayat pesanan
  Future<void> _loadMorePastOrders() async {
    if (!hasMorePastOrders || lastPastOrderDoc == null) return;

    try {
      setState(() {
        isLoadingMore = true;
      });

      final User? currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final QuerySnapshot morePastOrdersSnapshot = await _firestore
          .collection('orders')
          .where('userId', isEqualTo: currentUser.uid)
          .where('status', whereIn: ['completed', 'cancelled'])
          .orderBy('orderTime', descending: true)
          .startAfterDocument(lastPastOrderDoc!)
          .limit(pastOrdersLimit)
          .get();

      setState(() {
        if (morePastOrdersSnapshot.docs.isNotEmpty) {
          pastOrders.addAll(morePastOrdersSnapshot.docs);
          lastPastOrderDoc = morePastOrdersSnapshot.docs.last;
        }

        // Check if we should stop pagination
        hasMorePastOrders =
            morePastOrdersSnapshot.docs.length >= pastOrdersLimit;
        isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        isLoadingMore = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memuat data tambahan: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Fungsi refresh untuk digunakan dengan RefreshIndicator
  Future<void> _refreshOrders() async {
    await _loadOrders();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage.isNotEmpty
              ? _buildErrorWithRefresh()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    activeOrders.isEmpty
                        ? _buildEmptyStateWithRefresh(
                            'Tidak ada pesanan aktif',
                            'Pesanan aktif Anda akan muncul di sini',
                          )
                        : _buildOrdersListWithRefresh(
                            activeOrders,
                            isActive: true,
                            scrollController: _activeScrollController,
                            hasMoreData: hasMoreActiveOrders,
                          ),
                    pastOrders.isEmpty
                        ? _buildEmptyStateWithRefresh(
                            'Tidak ada riwayat pesanan',
                            'Riwayat pesanan Anda akan muncul di sini',
                          )
                        : _buildOrdersListWithRefresh(
                            pastOrders,
                            isActive: false,
                            scrollController: _pastScrollController,
                            hasMoreData: hasMorePastOrders,
                          ),
                  ],
                ),
    );
  }

  // Widget untuk menampilkan pesan error dengan refresh
  Widget _buildErrorWithRefresh() {
    return RefreshIndicator(
      onRefresh: _refreshOrders,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 80,
                    color: Colors.red[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    errorMessage,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Tarik ke bawah untuk memuat ulang',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget untuk menampilkan empty state dengan refresh
  Widget _buildEmptyStateWithRefresh(String title, String subtitle) {
    return RefreshIndicator(
      onRefresh: _refreshOrders,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.receipt_long,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Tarik ke bawah untuk memuat ulang',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const SizedBox(height: 24),
                  if (title.contains('Tidak ada pesanan aktif'))
                    SizedBox(
                      width: 150,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                        ),
                        child: const Text('Pesan Sekarang'),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget untuk menampilkan daftar pesanan dengan refresh
  Widget _buildOrdersListWithRefresh(
    List<DocumentSnapshot> orders, {
    required bool isActive,
    required ScrollController scrollController,
    required bool hasMoreData,
  }) {
    return RefreshIndicator(
      onRefresh: _refreshOrders,
      child: ListView.builder(
        controller: scrollController,
        padding: const EdgeInsets.all(16),
        itemCount:
            orders.length + (hasMoreData ? 1 : 0), // +1 untuk loading indicator
        itemBuilder: (context, index) {
          // Jika ini adalah item terakhir dan masih ada data lagi, tampilkan loading
          if (index == orders.length && hasMoreData) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                ),
              ),
            );
          }

          // Jika tidak, tampilkan order card seperti biasa
          if (index < orders.length) {
            final orderData = orders[index].data() as Map<String, dynamic>;
            final orderId = orders[index].id;
            return _buildOrderCard(orderId, orderData, isActive);
          }

          return null; // Tidak seharusnya terjadi
        },
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      title: const Text(
        'Pesanan',
        style: TextStyle(
          color: Colors.black,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      bottom: TabBar(
        controller: _tabController,
        labelColor: Colors.orange,
        unselectedLabelColor: Colors.grey,
        indicatorColor: Colors.orange,
        indicatorWeight: 3,
        labelStyle: const TextStyle(fontSize: 14),
        indicatorSize: TabBarIndicatorSize.tab,
        tabs: const [
          Tab(text: 'Pesanan Aktif'),
          Tab(text: 'Riwayat Pesanan'),
        ],
      ),
      // Tambahkan tombol refresh di AppBar
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.orange),
          onPressed: () {
            // Tampilkan indikator loading
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Memperbarui data pesanan...'),
                duration: Duration(seconds: 1),
              ),
            );
            // Muat ulang data
            _refreshOrders();
          },
          tooltip: 'Perbarui Pesanan',
        ),
      ],
    );
  }

  Widget _buildOrderCard(
      String orderId, Map<String, dynamic> orderData, bool isActive) {
    // Mengambil data items
    List<Map<String, dynamic>> items = [];
    int totalItems = 0;

    if (orderData.containsKey('items') && orderData['items'] is List) {
      try {
        for (var item in orderData['items']) {
          if (item is Map) {
            final itemMap = Map<String, dynamic>.from(item);
            items.add(itemMap);
            totalItems += item['quantity'] as int? ?? 1;
          }
        }
      } catch (e) {
        print('Error parsing items: $e');
      }
    }

    // Mengambil status pesanan
    String status = orderData['status'] ?? 'pending';
    int statusCode = _getStatusCode(status);

    // Mengambil metode pembayaran
    String paymentMethod = orderData['paymentMethod'] ?? 'Tidak tersedia';
    IconData paymentIcon = _getPaymentIcon(paymentMethod);

    // Mengambil waktu pesanan
    String formattedDate = 'Tidak tersedia';
    String formattedTime = '';
    String orderType = orderData['orderType'] ?? '';
    if (orderData.containsKey('orderTime') &&
        orderData['orderTime'] is Timestamp) {
      final DateTime orderTime = (orderData['orderTime'] as Timestamp).toDate();
      formattedDate = DateFormat('dd MMM yyyy').format(orderTime);
      formattedTime = DateFormat('HH:mm').format(orderTime);
    }

    // Menghitung total pembayaran
    double totalAmount = 0;
    if (orderData.containsKey('totalAmount')) {
      if (orderData['totalAmount'] is int) {
        totalAmount = (orderData['totalAmount'] as int).toDouble();
      } else if (orderData['totalAmount'] is double) {
        totalAmount = orderData['totalAmount'] as double;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(25),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          // Order header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withAlpha(25),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'RM. Solideo Kuliner',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '#${orderId.substring(0, 8).toUpperCase()}',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.restaurant,
                      size: 16,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$totalItems item${totalItems > 1 ? 's' : ''}',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '$formattedDate $formattedTime',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Payment method
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(paymentIcon, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(
                          paymentMethod,
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    orderType == ''
                        ? Container()
                        : Row(
                            children: [
                              const Icon(Icons.delivery_dining_sharp),
                              Text(
                                orderType,
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          )
                  ],
                ),

                const SizedBox(height: 16),

                // Order items (tampilkan 2 item pertama)
                ...items.take(2).map<Widget>((item) {
                  final String name = item['name'] ?? 'Item';
                  final int quantity = item['quantity'] ?? 1;

                  double price = 0.0;
                  if (item['price'] is int) {
                    price = (item['price'] as int).toDouble();
                  } else if (item['price'] is double) {
                    price = item['price'] as double;
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        // Item name with quantity
                        Expanded(
                          child: Text(
                            '${quantity}x $name',
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Item price
                        Text(
                          CurrencyFormatter.formatRupiah(price),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  );
                }).toList(),

                // Show more items if there are more than 2
                if (items.length > 2)
                  Padding(
                    padding: const EdgeInsets.only(
                      top: 4,
                      bottom: 12,
                    ),
                    child: Text(
                      '+ ${items.length - 2} item lainnya',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 10,
                      ),
                    ),
                  ),
                const Divider(),

                // Order total and status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Total amount
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total Pembayaran',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            CurrencyFormatter.formatRupiah(totalAmount),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    _buildStatusBadge(statusCode, _getStatusText(status)),
                  ],
                ),

                if (isActive && statusCode == 1) // Jika sedang diproses
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.access_time,
                          size: 16,
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Pesanan sedang diproses',
                            style: TextStyle(
                              color: Colors.blue[700],
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                if (isActive && statusCode == 2) // Jika siap diambil
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 16,
                          color: Colors.green[700],
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Pesanan siap untuk diambil',
                            style: TextStyle(
                              color: Colors.green[700],
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => OrderDetailsPage(
                            orderId: orderId,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.receipt_long,
                      size: 16,
                    ),
                    label: const Text(
                      'Detail',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ),
                if (!isActive) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _reorderItems(items);
                      },
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text(
                        'Pesan Lagi',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
                if (isActive && statusCode == 0) ...[
                  // Tombol batalkan untuk pesanan pending
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _cancelOrder(orderId);
                      },
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.cancel, size: 16),
                      label: const Text(
                        'Batalkan',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
  // Bottom Navigation bar telah dipindahkan ke MainScreen

  Widget _buildStatusBadge(int statusCode, String status) {
    Color badgeColor;
    Color textColor;
    IconData icon;

    switch (statusCode) {
      case 0: // Pending
        badgeColor = Colors.grey[200]!;
        textColor = Colors.grey[800]!;
        icon = Icons.pending;
        break;
      case 1: // Preparing
        badgeColor = Colors.blue[100]!;
        textColor = Colors.blue[800]!;
        icon = Icons.restaurant;
        break;
      case 2: // Ready
        badgeColor = Colors.green[100]!;
        textColor = Colors.green[800]!;
        icon = Icons.check_circle;
        break;
      case 3: // Completed
        badgeColor = Colors.purple[100]!;
        textColor = Colors.purple[800]!;
        icon = Icons.done_all;
        break;
      case 4: // Cancelled
        badgeColor = Colors.red[100]!;
        textColor = Colors.red[800]!;
        icon = Icons.cancel;
        break;
      default:
        badgeColor = Colors.grey[200]!;
        textColor = Colors.grey[800]!;
        icon = Icons.help;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            status,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  // Helper function untuk mendapatkan kode status
  int _getStatusCode(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 0;
      case 'preparing':
        return 1;
      case 'ready':
        return 2;
      case 'completed':
        return 3;
      case 'cancelled':
        return 4;
      default:
        return 0;
    }
  }

  // Helper function untuk mendapatkan teks status
  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Menunggu';
      case 'preparing':
        return 'Diproses';
      case 'ready':
        return 'Siap Diambil';
      case 'completed':
        return 'Selesai';
      case 'cancelled':
        return 'Dibatalkan';
      default:
        return status;
    }
  }

  // Helper function untuk mendapatkan ikon metode pembayaran
  IconData _getPaymentIcon(String method) {
    if (method.toLowerCase().contains('cod') ||
        method.toLowerCase().contains('konter') ||
        method.toLowerCase().contains('cash')) {
      return Icons.point_of_sale;
    } else if (method.toLowerCase().contains('transfer') ||
        method.toLowerCase().contains('bank')) {
      return Icons.account_balance;
    }
    return Icons.payment;
  }

  // Fungsi untuk membatalkan pesanan
  void _cancelOrder(String orderId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Batalkan Pesanan'),
        content: const Text(
          'Apakah Anda yakin ingin membatalkan pesanan ini? Tindakan ini tidak dapat dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tidak'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              setState(() {
                isLoading = true;
              });

              try {
                await _firestore.collection('orders').doc(orderId).update({
                  'status': 'cancelled',
                  'lastUpdated': FieldValue.serverTimestamp(),
                });

                // Reload data
                await _loadOrders();

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Pesanan berhasil dibatalkan'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                setState(() {
                  isLoading = false;
                });

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Gagal membatalkan pesanan: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text(
              'Ya, Batalkan',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  // Fungsi untuk memesan ulang
  void _reorderItems(List<Map<String, dynamic>> items) {
    // Implementasi untuk memesan ulang
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Menambahkan item ke keranjang...'),
        duration: Duration(seconds: 1),
      ),
    );

    // Di sini Anda bisa menambahkan logika untuk menambahkan
    // semua item di pesanan ini ke keranjang belanja    // Contoh navigasi ke halaman menu
    Future.delayed(const Duration(seconds: 1), () {
      Navigator.pop(context); // Close this dialog
      // Navigate to home page is now handled by MainScreen
    });
  }
}
