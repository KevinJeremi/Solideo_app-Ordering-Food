import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'order_detail.dart';

class AdminOrdersPage extends StatefulWidget {
  const AdminOrdersPage({super.key});

  @override
  State<AdminOrdersPage> createState() => _AdminOrdersPageState();
}

class _AdminOrdersPageState extends State<AdminOrdersPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final currencyFormatter =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ');

  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    String actionTitle = '';
    String actionMessage = '';
    String confirmButtonText = '';
    Color confirmButtonColor = Colors.green;

    if (newStatus == 'preparing') {
      actionTitle = 'Terima Pesanan';
      actionMessage =
          'Apakah Anda yakin ingin menerima dan memproses pesanan ini?';
      confirmButtonText = 'Terima';
      confirmButtonColor = Colors.green;
    } else if (newStatus == 'ready') {
      actionTitle = 'Pesanan Siap';
      actionMessage = 'Apakah pesanan sudah siap untuk diambil?';
      confirmButtonText = 'Siap';
      confirmButtonColor = Colors.deepOrange;
    } else if (newStatus == 'cancelled') {
      actionTitle = 'Batalkan Pesanan';
      actionMessage = 'Apakah Anda yakin ingin membatalkan pesanan ini?';
      confirmButtonText = 'Batalkan';
      confirmButtonColor = Colors.red;
    }

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(actionTitle),
        content: Text(actionMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              confirmButtonText,
              style: TextStyle(color: confirmButtonColor),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _firestore.collection('orders').doc(orderId).update({
        'status': newStatus,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Status pesanan berhasil diubah menjadi $newStatus'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('orders')
            .where('status', whereIn: ['pending', 'preparing'])
            .orderBy('orderTime', descending: true)
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
                  Icon(Icons.shopping_basket, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Tidak ada pesanan baru',
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
              final orderId = doc.id;
              final customerName = data['customerName'] ?? 'Pelanggan';
              final orderTime = (data['orderTime'] as Timestamp).toDate();
              final totalAmount = data['totalAmount'] ?? 0;
              final status = data['status'] ?? 'pending';
              final paymentMethod = data['paymentMethod'] ?? 'COD';
              final tableNumber = data['tableNumber'] ?? '-';
              final orderType = data['orderType'] ?? "";

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 16),
                child: ExpansionTile(
                  title: Text(
                    'Pesanan #${orderId.contains("_") ? orderId.split("_").last : orderId}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (orderType.isNotEmpty)
                        Text('Jenis Pesanan: $orderType'),
                      Text('Pelanggan: $customerName'),
                      Text(
                        'Total: ${currencyFormatter.format(totalAmount)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Status: $status',
                        style: TextStyle(
                          color:
                              status == 'pending' ? Colors.orange : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  trailing: const Icon(Icons.expand_more),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                flex: 3,
                                child: Text(
                                  'Waktu: ${DateFormat('dd/MM/yy, HH:mm').format(orderTime)}',
                                  style: const TextStyle(fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                flex: 1,
                                child: Text(
                                  'Meja: $tableNumber',
                                  style: const TextStyle(fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text('Metode Pembayaran: $paymentMethod'),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            OrderDetailPage(orderId: orderId),
                                      ),
                                    );
                                  },
                                  child: const Text('Lihat Detail'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: status == 'pending'
                                        ? Colors.green
                                        : Colors.deepOrange,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () {
                                    if (status == 'pending') {
                                      _updateOrderStatus(orderId, 'preparing');
                                    } else if (status == 'preparing') {
                                      _updateOrderStatus(orderId, 'ready');
                                    }
                                  },
                                  child: Text(
                                    status == 'pending'
                                        ? 'Terima Pesanan'
                                        : 'Pesanan Siap',
                                  ),
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
            },
          );
        },
      ),
    );
  }
}

class OrderDetailPage extends StatelessWidget {
  final String orderId;

  const OrderDetailPage({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Detail Pesanan #${orderId.substring(0, 6)}'),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future:
            FirebaseFirestore.instance.collection('orders').doc(orderId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Pesanan tidak ditemukan'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final items = List<Map<String, dynamic>>.from(data['items'] ?? []);
          final totalAmount = data['totalAmount'] ?? 0;
          final currencyFormatter =
              NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ');

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Daftar Item',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final name = item['name'] ?? 'Item';
                      final price = item['price'] ?? 0;
                      final quantity = item['quantity'] ?? 1;
                      final notes = item['notes'] ?? '';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(name),
                          subtitle:
                              notes.isNotEmpty ? Text('Catatan: $notes') : null,
                          trailing: Text(
                            '${quantity}x ${currencyFormatter.format(price)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const Divider(thickness: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Pembayaran:',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        currencyFormatter.format(totalAmount),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepOrange,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
