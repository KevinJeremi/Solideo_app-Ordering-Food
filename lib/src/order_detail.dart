import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'helper/currency_formatter.dart';

class OrderDetailsPage extends StatefulWidget {
  final String orderId;

  const OrderDetailsPage({
    Key? key,
    required this.orderId,
  }) : super(key: key);

  @override
  State<OrderDetailsPage> createState() => _OrderDetailsPageState();
}

class _OrderDetailsPageState extends State<OrderDetailsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool isLoading = true;
  String errorMessage = '';
  Map<String, dynamic>? orderData;

  List<Map<String, dynamic>> items = [];
  double subtotal = 0;
  double total = 0;
  String status = '';
  int statusCode = 0;
  bool isActive = true;

  @override
  void initState() {
    super.initState();
    _loadOrderDetails();
  }

  // Fungsi untuk memuat detail pesanan dari Firestore
  Future<void> _loadOrderDetails() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = '';
      });

      final DocumentSnapshot doc =
          await _firestore.collection('orders').doc(widget.orderId).get();

      if (!doc.exists) {
        setState(() {
          isLoading = false;
          errorMessage = 'Pesanan tidak ditemukan';
        });
        return;
      }

      // Ambil data pesanan
      final data = doc.data() as Map<String, dynamic>;

      // Proses data item
      List<Map<String, dynamic>> orderItems = [];
      if (data.containsKey('items') && data['items'] is List) {
        orderItems =
            List<Map<String, dynamic>>.from((data['items'] as List).map((item) {
          if (item is Map) {
            return Map<String, dynamic>.from(item);
          }
          return <String, dynamic>{};
        }));
      }

      // Hitung subtotal dari items
      double orderSubtotal = 0.0;
      for (var item in orderItems) {
        int quantity = item['quantity'] ?? 1;
        double price = 0.0;

        // Handle berbagai tipe data harga
        if (item['price'] is int) {
          price = (item['price'] as int).toDouble();
        } else if (item['price'] is double) {
          price = item['price'] as double;
        } else if (item['price'] is String) {
          price = double.tryParse(item['price'] as String) ?? 0.0;
        }

        orderSubtotal += quantity * price;
      }

      // Hitung pajak dan total
      double orderTax = orderSubtotal * 0.1; // 10% pajak
      double orderFee = 3000; // Biaya layanan tetap
      double orderTotal =
          data['totalAmount'] ?? (orderSubtotal + orderTax + orderFee);

      // Set status dan kode status
      String orderStatus = data['status'] ?? 'pending';
      int orderStatusCode = _getStatusCode(orderStatus);
      bool orderIsActive = orderStatusCode < 3;

      setState(() {
        orderData = data;
        items = orderItems;
        subtotal = orderSubtotal;
        total = orderTotal;
        status = orderStatus;
        statusCode = orderStatusCode;
        isActive = orderIsActive;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Terjadi kesalahan: ${e.toString()}';
      });
    }
  }

  // Konversi status string ke kode angka
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

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Detail Pesanan'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (errorMessage.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Detail Pesanan'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
        ),
        body: Center(child: Text(errorMessage)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildOrderStatus(),
              _buildOrderInfo(),
              _buildRestaurantInfo(),
              _buildOrderItems(),
              _buildPaymentSummary(),
              _buildPaymentMethod(),
              const SizedBox(height: 24),
              _buildActionButtons(),
              _buildActionHelp(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      title: const Text(
        'Detail Pesanan',
        style: TextStyle(
          color: Colors.black,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.help_outline, color: Colors.orange),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Bantuan & Dukungan')),
            );
          },
        ),
      ],
    );
  }

  Widget _buildOrderStatus() {
    Color backgroundColor;
    Color textColor;
    IconData icon;
    String message;

    switch (statusCode) {
      case 0: // Pending
        backgroundColor = Colors.grey[200]!;
        textColor = Colors.grey[800]!;
        icon = Icons.pending;
        message = 'Pesanan Anda menunggu konfirmasi dari restoran';
        break;
      case 1: // Preparing
        backgroundColor = Colors.blue[100]!;
        textColor = Colors.blue[800]!;
        icon = Icons.restaurant;
        message = 'Restoran sedang menyiapkan pesanan Anda';
        break;
      case 2: // Ready
        backgroundColor = Colors.green[100]!;
        textColor = Colors.green[800]!;
        icon = Icons.check_circle;
        message = 'Pesanan Anda siap untuk diambil';
        break;
      case 3: // Completed
        backgroundColor = Colors.purple[100]!;
        textColor = Colors.purple[800]!;
        icon = Icons.done_all;
        message = 'Pesanan Anda telah selesai';
        break;
      case 4: // Cancelled
        backgroundColor = Colors.red[100]!;
        textColor = Colors.red[800]!;
        icon = Icons.cancel;
        message = 'Pesanan Anda telah dibatalkan';
        break;
      default:
        backgroundColor = Colors.grey[200]!;
        textColor = Colors.grey[800]!;
        icon = Icons.help;
        message = 'Informasi status tidak tersedia';
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 16,
        horizontal: 20,
      ),
      color: backgroundColor,
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getStatusTitle(status),
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusTitle(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Menunggu Konfirmasi';
      case 'preparing':
        return 'Sedang Diproses';
      case 'ready':
        return 'Siap Diambil';
      case 'completed':
        return 'Pesanan Selesai';
      case 'cancelled':
        return 'Pesanan Dibatalkan';
      default:
        return status;
    }
  }

  Widget _buildOrderInfo() {
    // Format tanggal dari Timestamp
    String dateStr = 'Tidak tersedia';
    String timeStr = '';

    if (orderData != null &&
        orderData!.containsKey('orderTime') &&
        orderData!['orderTime'] is Timestamp) {
      final DateTime orderTime =
          (orderData!['orderTime'] as Timestamp).toDate();
      dateStr = DateFormat('dd MMM yyyy').format(orderTime);
      timeStr = DateFormat('HH:mm').format(orderTime);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ID: ${widget.orderId.substring(0, 8).toUpperCase()}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                '$dateStr, $timeStr',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (statusCode == 1) // Preparing
            Row(
              children: [
                const Icon(
                  Icons.access_time,
                  size: 14,
                  color: Colors.blue,
                ),
                const SizedBox(width: 8),
                Text(
                  'Pesanan sedang diproses',
                  style: TextStyle(
                    color: Colors.blue[700],
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          if (statusCode == 2) // Ready
            Row(
              children: [
                Icon(
                  Icons.check_circle,
                  size: 14,
                  color: Colors.green[700],
                ),
                const SizedBox(width: 8),
                Text(
                  'Pesanan siap untuk diambil',
                  style: TextStyle(
                    color: Colors.green[700],
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          if (statusCode == 3) // Completed
            Row(
              children: [
                Icon(
                  Icons.done_all,
                  size: 14,
                  color: Colors.purple[700],
                ),
                const SizedBox(width: 8),
                Text(
                  'Pesanan selesai',
                  style: TextStyle(
                    color: Colors.purple[700],
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          if (statusCode == 4) // Cancelled
            Row(
              children: [
                const Icon(
                  Icons.cancel,
                  size: 14,
                  color: Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  'Pesanan dibatalkan',
                  style: TextStyle(
                    color: Colors.red[700],
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          // Tampilkan nomor meja jika ada
          if (orderData != null &&
              orderData!.containsKey('tableNumber') &&
              orderData!['tableNumber'] != '-')
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.table_restaurant,
                    size: 14,
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Nomor Meja: ${orderData!['tableNumber']}',
                    style: TextStyle(
                      color: Colors.orange[700],
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRestaurantInfo() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.orange[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.restaurant,
              color: Colors.orange[800],
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'RM. Solideo Kuliner',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Row(),
                const SizedBox(height: 4),
                Text(
                  'Jl. Komp. Bahu Mall, Bahu, Kec. Malalayang, Kota Manado',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // IconButton(
          //   icon: Icon(Icons.call, color: Colors.green[700]),
          //   onPressed: () {
          //     ScaffoldMessenger.of(context).showSnackBar(
          //       const SnackBar(
          //         content: Text('Menghubungi restoran...'),
          //       ),
          //     );
          //   },
          // ),
        ],
      ),
    );
  }

  Widget _buildOrderItems() {
    if (items.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(16),
        color: Colors.white,
        child: const Center(
          child: Text(
            'Tidak ada item dalam pesanan ini',
            style: TextStyle(
              color: Colors.grey,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pesanan Anda',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          ...items.map((item) => _buildOrderItem(item)),

          // Tampilkan catatan jika ada
          if (orderData != null &&
              orderData!.containsKey('notes') &&
              orderData!['notes'].toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Catatan Pesanan:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Text(
                      orderData!['notes'],
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOrderItem(Map<String, dynamic> item) {
    // Mengambil data item dengan penanganan tipe data yang baik
    final String name = item['name'] ?? 'Item Tidak Diketahui';
    final int quantity = item['quantity'] ?? 1;

    double price = 0.0;
    if (item['price'] is int) {
      price = (item['price'] as int).toDouble();
    } else if (item['price'] is double) {
      price = item['price'] as double;
    } else if (item['price'] is String) {
      price = double.tryParse(item['price'] as String) ?? 0.0;
    }

    final double total = quantity * price;
    final String note = item['note'] ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${quantity}x',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      'Harga satuan: ${CurrencyFormatter.formatRupiah(price)}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 10,
                      ),
                    ),
                    if (note.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'Catatan: $note',
                          style: TextStyle(
                            color: Colors.orange[700],
                            fontSize: 10,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                CurrencyFormatter.formatRupiah(total),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          if (item != items.last) const Divider(height: 16),
        ],
      ),
    );
  }

  Widget _buildPaymentSummary() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ringkasan Pembayaran',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          _buildPriceRow('Subtotal', subtotal),
          const Divider(height: 24),
          _buildPriceRow('Total Pembayaran', total, isTotal: true),
        ],
      ),
    );
  }

  Widget _buildPriceRow(
    String label,
    double amount, {
    bool isTotal = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 14 : 12,
              color: isTotal ? Colors.black : Colors.grey[700],
            ),
          ),
          Text(
            CurrencyFormatter.formatRupiah(amount),
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 14 : 12,
              color: isTotal ? Colors.black : Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethod() {
    // Mengambil data pembayaran dari pesanan
    String paymentMethod = 'Tidak tersedia';
    String paymentStatus = 'Menunggu';
    IconData paymentIcon = Icons.payment;

    if (orderData != null && orderData!.containsKey('paymentMethod')) {
      paymentMethod = orderData!['paymentMethod'];
    }

    if (orderData != null && orderData!.containsKey('paymentStatus')) {
      paymentStatus = orderData!['paymentStatus'];
    }

    // Warna dan ikon berdasarkan metode pembayaran
    Color backgroundColor = Colors.blue[50]!;
    Color iconColor = Colors.blue[700]!;

    if (paymentMethod.toLowerCase().contains('cod') ||
        paymentMethod.toLowerCase().contains('counter')) {
      backgroundColor = Colors.green[50]!;
      iconColor = Colors.green[700]!;
      paymentIcon = Icons.point_of_sale;
      paymentMethod = 'Bayar di Konter';
    } else if (paymentMethod.toLowerCase().contains('transfer') ||
        paymentMethod.toLowerCase().contains('bank')) {
      backgroundColor = Colors.blue[50]!;
      iconColor = Colors.blue[700]!;
      paymentIcon = Icons.account_balance;
      paymentMethod = 'Transfer Bank';
    }

    // Format status pembayaran
    String formattedStatus;
    Color statusColor;

    switch (paymentStatus.toLowerCase()) {
      case 'completed':
      case 'confirmed':
      case 'paid':
        formattedStatus = 'Terbayar';
        statusColor = Colors.green;
        break;
      case 'awaiting_confirmation':
        formattedStatus = 'Menunggu Konfirmasi';
        statusColor = Colors.orange;
        break;
      case 'cancelled':
        formattedStatus = 'Dibatalkan';
        statusColor = Colors.red;
        break;
      case 'pending':
      default:
        formattedStatus = 'Menunggu Pembayaran';
        statusColor = Colors.orange;
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Metode Pembayaran',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(paymentIcon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      paymentMethod,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    // Tambahan info pembayaran seperti rekening atau detail lainnya
                    if (paymentMethod.contains('Transfer'))
                      Text(
                        'BCA/BNI/Mandiri/Bank lainnya',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 10,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: statusColor.withOpacity(0.5)),
                ),
                child: Text(
                  formattedStatus,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    // Tombol aksi akan berbeda tergantung status pesanan
    if (statusCode == 4) {
      // Dibatalkan
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ElevatedButton.icon(
          onPressed: () {
            _reorderItems();
          },
          icon: const Icon(Icons.refresh),
          label: const Text('Pesan Lagi'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 44),
          ),
        ),
      );
    } else if (statusCode == 0) {
      // Pending
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ElevatedButton.icon(
          onPressed: () {
            _cancelOrder();
          },
          icon: const Icon(Icons.cancel),
          label: const Text('Batalkan Pesanan'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 44),
          ),
        ),
      );
    } else if (statusCode == 3) {
      // Completed
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ElevatedButton.icon(
          onPressed: () {
            _reorderItems();
          },
          icon: const Icon(Icons.refresh),
          label: const Text('Pesan Lagi'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 44),
          ),
        ),
      );
    }

    // Default jika tidak ada tombol khusus
    return const SizedBox.shrink();
  }

  // Fungsi untuk membatalkan pesanan
  void _cancelOrder() {
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
                await _firestore
                    .collection('orders')
                    .doc(widget.orderId)
                    .update({
                  'status': 'cancelled',
                  'lastUpdated': FieldValue.serverTimestamp(),
                });

                // Reload data
                await _loadOrderDetails();

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
  void _reorderItems() {
    // Implementasi untuk memesan ulang
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Menambahkan item ke keranjang...'),
        duration: Duration(seconds: 1),
      ),
    );

    // Di sini Anda bisa menambahkan logika untuk menambahkan
    // semua item di pesanan ini ke keranjang belanja

    // Contoh navigasi ke halaman menu
    Future.delayed(const Duration(seconds: 1), () {
      Navigator.popUntil(context, (route) => route.isFirst);
    });
  }

  Widget _buildActionHelp() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextButton.icon(
        onPressed: () {
          _showHelpSheet();
        },
        icon: const Icon(Icons.headset_mic),
        label: const Text('Butuh Bantuan?'),
        style: TextButton.styleFrom(foregroundColor: Colors.grey[700]),
      ),
    );
  }

  void _showHelpSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(16),
        ),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Hubungi Dukungan',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.email,
                color: Colors.orange,
              ),
              title: const Text('Email'),
              subtitle: const Text('support@solideokuliner.com'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Membuka aplikasi email...'),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
