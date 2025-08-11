import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdminPaymentsPage extends StatefulWidget {
  const AdminPaymentsPage({super.key});

  @override
  State<AdminPaymentsPage> createState() => _AdminPaymentsPageState();
}

class _AdminPaymentsPageState extends State<AdminPaymentsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final currencyFormatter =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ');

  Future<void> _confirmPayment(String orderId, String paymentId) async {
    // Show confirmation dialog first
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Pembayaran'),
        content: const Text(
            'Apakah Anda yakin ingin mengkonfirmasi pembayaran ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text('Konfirmasi', style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );

    // If not confirmed, exit the function
    if (confirm != true) return;

    try {
      // Start a batch to update both the payment and order
      final batch = _firestore.batch();

      // Update payment status
      final paymentRef = _firestore.collection('payments').doc(paymentId);
      batch.update(paymentRef, {
        'status': 'confirmed',
        'confirmedAt': FieldValue.serverTimestamp(),
      });

      // Update order payment status
      final orderRef = _firestore.collection('orders').doc(orderId);
      batch.update(orderRef, {
        'paymentStatus': 'paid',
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pembayaran berhasil dikonfirmasi'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Terjadi kesalahan: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Helper method to format timestamp
  String _getFormattedTime(DateTime timestamp) {
    final difference = DateTime.now().difference(timestamp);

    // If payment was made within the last 5 minutes
    if (difference.inMinutes <= 5) {
      return "Baru saja";
    } else {
      return DateFormat('dd/MM/yyyy HH:mm').format(timestamp);
    }
  }

  Future<void> _rejectPayment(String orderId, String paymentId) async {
    // Show confirmation dialog first
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tolak Pembayaran'),
        content: const Text('Apakah Anda yakin ingin menolak pembayaran ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Tolak', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    // If not confirmed, exit the function
    if (confirm != true) return;

    try {
      // Start a batch to update both the payment and order
      final batch = _firestore.batch();

      // Update payment status
      final paymentRef = _firestore.collection('payments').doc(paymentId);
      batch.update(paymentRef, {
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
      });

      // Update order payment status
      final orderRef = _firestore.collection('orders').doc(orderId);
      batch.update(orderRef, {
        'paymentStatus': 'rejected',
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pembayaran ditolak'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Terjadi kesalahan: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        // Modifikasi query untuk menampilkan semua pembayaran yang perlu verifikasi
        stream: _firestore
            .collection('payments')
            .where('status', whereIn: ['pending', 'awaiting_confirmation'])
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Terjadi kesalahan: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.payment, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Tidak ada pembayaran yang perlu dikonfirmasi',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;

              // Log data untuk debugging
              print('Payment data being displayed: $data');

              final paymentId = doc.id;
              final orderId = data['orderId'] ?? '';
              final customerName = data['customerName'] ?? 'Pelanggan';
              final amount = data['amount'] ?? 0;
              final paymentMethod = data['paymentMethod'] ?? 'Transfer Bank';

              // Tambahkan penanganan untuk bank name dan sender name
              final bankName = data['bankName'] ?? '-';
              final senderName = data['senderName'] ?? '-';

              final timestamp = (data['timestamp'] as Timestamp).toDate();
              final proofImageUrl = data['proofImageUrl'] ?? '';
              final status = data['status'] ?? 'pending';

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      title: Text(
                        'Pembayaran #${paymentId.contains("_") ? paymentId.split("_").last : paymentId}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Pelanggan: $customerName'),
                          Text(
                              'Order ID: #${orderId.contains("_") ? orderId.split("_").last : orderId}'),
                          Text(
                            'Jumlah: ${currencyFormatter.format(amount)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text('Metode: $paymentMethod'),
                          if (paymentMethod.contains('Transfer')) ...[
                            Text('Bank: $bankName'),
                            Text('Pengirim: $senderName'),
                          ],
                          Text(
                            'Waktu Pembayaran: ${_getFormattedTime(timestamp)}',
                            style: DateTime.now()
                                        .difference(timestamp)
                                        .inMinutes <=
                                    5
                                ? const TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold)
                                : null,
                          ),
                          Text(
                              'Status: ${status[0].toUpperCase() + status.substring(1)}'),
                          // ...existing code...
                        ],
                      ),
                    ),
                    if (proofImageUrl.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Bukti Pembayaran:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                proofImageUrl,
                                height: 200,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    height: 200,
                                    width: double.infinity,
                                    color: Colors.grey[300],
                                    alignment: Alignment.center,
                                    child: const Text('Gagal memuat gambar'),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () =>
                                  _confirmPayment(orderId, paymentId),
                              child: const Text('Konfirmasi'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () =>
                                  _rejectPayment(orderId, paymentId),
                              child: const Text('Tolak'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
