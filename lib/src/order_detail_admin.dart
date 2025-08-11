import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class OrderDetailPage extends StatefulWidget {
  final String orderId;

  const OrderDetailPage({super.key, required this.orderId});

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NumberFormat currencyFormatter =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ');
  final DateFormat dateFormatter = DateFormat('dd MMM yyyy, HH:mm');

  // Loading state untuk button actions
  bool _isUpdating = false;

  /// Update status pesanan dengan loading state
  Future<void> _updateOrderStatus(String newStatus) async {
    if (_isUpdating) return; // Prevent multiple calls

    setState(() {
      _isUpdating = true;
    });

    try {
      await _firestore.collection('orders').doc(widget.orderId).update({
        'status': newStatus,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      _showSnackBar(
        message: 'Status pesanan berhasil diubah menjadi $newStatus',
        isError: false,
      );
    } catch (e) {
      if (!mounted) return;

      _showSnackBar(
        message: 'Terjadi kesalahan: ${e.toString()}',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  /// Helper method untuk menampilkan snackbar
  void _showSnackBar({required String message, required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Fetch data pembayaran berdasarkan orderId
  Future<Map<String, dynamic>?> _fetchPaymentData(String orderId) async {
    try {
      final paymentQuery = await _firestore
          .collection('payments')
          .where('orderId', isEqualTo: orderId)
          .limit(1) // Optimasi: hanya ambil 1 dokumen
          .get();

      if (paymentQuery.docs.isNotEmpty) {
        return paymentQuery.docs.first.data();
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching payment data: $e');
      return null;
    }
  }

  /// Format status pembayaran untuk display
  String _formatPaymentStatus(String paymentMethod, String paymentStatus) {
    final statusText = paymentStatus == 'paid' ? 'Lunas' : 'Belum Lunas';
    return '$paymentMethod ($statusText)';
  }

  /// Format informasi meja
  String _formatTableNumber(dynamic tableNumber) {
    if (tableNumber == null || tableNumber.toString().isEmpty) {
      return 'Takeaway';
    }
    return 'Meja $tableNumber';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Detail Pesanan #${widget.orderId.substring(0, 6)}'),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _fetchPaymentData(widget.orderId),
        builder: (context, paymentSnapshot) {
          return StreamBuilder<DocumentSnapshot>(
            stream:
                _firestore.collection('orders').doc(widget.orderId).snapshots(),
            builder: (context, orderSnapshot) {
              if (orderSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.deepOrange),
                  ),
                );
              }

              if (orderSnapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Error: ${orderSnapshot.error}'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => setState(() {}),
                        child: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                );
              }

              if (!orderSnapshot.hasData || !orderSnapshot.data!.exists) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('Pesanan tidak ditemukan'),
                    ],
                  ),
                );
              }

              final orderData =
                  orderSnapshot.data!.data() as Map<String, dynamic>;
              final paymentData = paymentSnapshot.data;

              return _buildOrderDetail(orderData, paymentData);
            },
          );
        },
      ),
    );
  }

  Widget _buildOrderDetail(
      Map<String, dynamic> orderData, Map<String, dynamic>? paymentData) {
    final customerName = orderData['customerName'] ?? 'Pelanggan';
    final customerPhone = orderData['customerPhone'] ?? '-';
    final tableNumber = orderData['tableNumber'];
    final items = List<Map<String, dynamic>>.from(orderData['items'] ?? []);
    final totalAmount = (orderData['totalAmount'] ?? 0).toDouble();
    final status = orderData['status'] ?? 'pending';
    final paymentStatus = orderData['paymentStatus'] ?? 'pending';
    final paymentMethod = orderData['paymentMethod'] ?? 'COD';
    final orderTime = (orderData['orderTime'] as Timestamp).toDate();
    final notes = orderData['notes'] ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order Information Card
          _buildOrderInfoCard(
            customerName: customerName,
            customerPhone: customerPhone,
            tableNumber: tableNumber,
            orderTime: orderTime,
            paymentMethod: paymentMethod,
            paymentStatus: paymentStatus,
            paymentData: paymentData,
            notes: notes,
            status: status,
          ),

          const SizedBox(height: 16),

          // Items List
          _buildItemsList(items),

          const SizedBox(height: 16),

          // Total Amount Card
          _buildTotalCard(totalAmount),

          const SizedBox(height: 20),

          // Action Buttons
          _buildActionButtons(status),
        ],
      ),
    );
  }

  Widget _buildOrderInfoCard({
    required String customerName,
    required String customerPhone,
    required dynamic tableNumber,
    required DateTime orderTime,
    required String paymentMethod,
    required String paymentStatus,
    required Map<String, dynamic>? paymentData,
    required String notes,
    required String status,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Informasi Pesanan',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                _buildStatusChip(status),
              ],
            ),
            const Divider(height: 24),
            _buildInfoRow('Pelanggan', customerName),
            _buildInfoRow('No. Telepon', customerPhone),
            _buildInfoRow('Lokasi', _formatTableNumber(tableNumber)),
            _buildInfoRow('Waktu Pesanan', dateFormatter.format(orderTime)),
            _buildInfoRow(
              'Metode Pembayaran',
              _formatPaymentStatus(paymentMethod, paymentStatus),
            ),
            // Payment confirmation time if available
            if (paymentData != null && paymentData['confirmedAt'] != null) ...[
              Builder(builder: (context) {
                final confirmedTime =
                    (paymentData['confirmedAt'] as Timestamp).toDate();
                final timeDifference = DateTime.now().difference(confirmedTime);

                return _buildInfoRow(
                  'Waktu Konfirmasi Pembayaran',
                  timeDifference.inMinutes <= 5
                      ? 'Baru saja'
                      : dateFormatter.format(confirmedTime),
                  textStyle: timeDifference.inMinutes <= 5
                      ? const TextStyle(
                          color: Colors.green, fontWeight: FontWeight.bold)
                      : null,
                );
              }),
            ],

            // Notes if available
            if (notes.isNotEmpty)
              _buildInfoRow('Catatan', notes, isMultiline: true),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsList(List<Map<String, dynamic>> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Daftar Item',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: items.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: Text('Tidak ada item')),
                )
              : ListView.separated(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: items.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) => _buildItemTile(items[index]),
                ),
        ),
      ],
    );
  }

  Widget _buildItemTile(Map<String, dynamic> item) {
    final name = item['name'] ?? 'Item';
    final price = (item['price'] ?? 0).toDouble();
    final quantity = (item['quantity'] ?? 1).toInt();
    final itemNotes = item['notes'] ?? '';
    final subtotal = price * quantity;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      title: Text(
        name,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: itemNotes.isNotEmpty
          ? Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Catatan: $itemNotes',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          : null,
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${quantity}x ${currencyFormatter.format(price)}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            currencyFormatter.format(subtotal),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalCard(double totalAmount) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [Colors.deepOrange.shade50, Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Total Pembayaran',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            Text(
              currencyFormatter.format(totalAmount),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.deepOrange,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value,
      {bool isMultiline = false, TextStyle? textStyle}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment:
            isMultiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
          const Text(': '),
          Expanded(
            child: Text(
              value,
              style: textStyle ??
                  TextStyle(
                    color: Colors.grey[700],
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    final statusConfig = _getStatusConfig(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusConfig.color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: statusConfig.color.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            statusConfig.icon,
            color: Colors.white,
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            statusConfig.label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  StatusConfig _getStatusConfig(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return StatusConfig(
          color: Colors.orange,
          label: 'Menunggu',
          icon: Icons.schedule,
        );
      case 'preparing':
        return StatusConfig(
          color: Colors.blue,
          label: 'Diproses',
          icon: Icons.kitchen,
        );
      case 'ready':
        return StatusConfig(
          color: Colors.green,
          label: 'Siap',
          icon: Icons.check_circle,
        );
      case 'completed':
        return StatusConfig(
          color: Colors.teal,
          label: 'Selesai',
          icon: Icons.done_all,
        );
      case 'cancelled':
        return StatusConfig(
          color: Colors.red,
          label: 'Dibatalkan',
          icon: Icons.cancel,
        );
      default:
        return StatusConfig(
          color: Colors.grey,
          label: status,
          icon: Icons.help,
        );
    }
  }

  Widget _buildActionButtons(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Row(
          children: [
            Expanded(
              child: _buildActionButton(
                label: 'Terima & Persiapkan',
                color: Colors.blue,
                icon: Icons.kitchen,
                onPressed: () => _updateOrderStatus('preparing'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                label: 'Batalkan',
                color: Colors.red,
                icon: Icons.cancel,
                onPressed: () => _updateOrderStatus('cancelled'),
              ),
            ),
          ],
        );

      case 'preparing':
        return Row(
          children: [
            Expanded(
              child: _buildActionButton(
                label: 'Pesanan Siap',
                color: Colors.green,
                icon: Icons.check_circle,
                onPressed: () => _updateOrderStatus('ready'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                label: 'Batalkan',
                color: Colors.red,
                icon: Icons.cancel,
                onPressed: () => _updateOrderStatus('cancelled'),
              ),
            ),
          ],
        );

      case 'ready':
        return SizedBox(
          width: double.infinity,
          child: _buildActionButton(
            label: 'Tandai Selesai',
            color: Colors.teal,
            icon: Icons.done_all,
            onPressed: () => _updateOrderStatus('completed'),
          ),
        );

      case 'completed':
      case 'cancelled':
        return const SizedBox.shrink();

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildActionButton({
    required String label,
    required Color color,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        elevation: 2,
      ),
      onPressed: _isUpdating ? null : onPressed,
      icon: _isUpdating
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Icon(icon, size: 18),
      label: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
    );
  }
}

/// Class untuk konfigurasi status
class StatusConfig {
  final Color color;
  final String label;
  final IconData icon;

  StatusConfig({
    required this.color,
    required this.label,
    required this.icon,
  });
}
