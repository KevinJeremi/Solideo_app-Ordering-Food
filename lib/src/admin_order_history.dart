import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'order_detail_admin.dart';

class AdminOrderHistoryPage extends StatefulWidget {
  // Parameter untuk fungsi logout
  final Future<void> Function()? onLogout;

  const AdminOrderHistoryPage({super.key, this.onLogout});

  @override
  State<AdminOrderHistoryPage> createState() => _AdminOrderHistoryPageState();
}

class _AdminOrderHistoryPageState extends State<AdminOrderHistoryPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final currencyFormatter =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ');

  String _statusFilter = 'all';
  DateTime? _startDate;
  DateTime? _endDate;

  // Konfirmasi logout
  void _confirmLogout() {
    if (widget.onLogout == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Logout'),
        content: const Text('Apakah Anda yakin ingin keluar dari akun admin?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              print("Logout dikonfirmasi");
              widget.onLogout!();
            },
            child: const Text(
              'Logout',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _endDate) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  void _resetFilters() {
    setState(() {
      _statusFilter = 'all';
      _startDate = null;
      _endDate = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Pesanan'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: Column(
        children: [
          _buildFilterSection(),
          Expanded(
            child: _buildOrderHistoryList(),
          ),
          // Tambahkan tombol logout di bagian bawah
          if (widget.onLogout != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: ElevatedButton.icon(
                onPressed: _confirmLogout,
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filter Riwayat Pesanan',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  value: _statusFilter,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('Semua')),
                    DropdownMenuItem(
                        value: 'completed', child: Text('Selesai')),
                    DropdownMenuItem(
                        value: 'cancelled', child: Text('Dibatalkan')),
                    DropdownMenuItem(value: 'ready', child: Text('Siap')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _statusFilter = value!;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _resetFilters,
                tooltip: 'Reset Filter',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _selectStartDate(context),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Dari Tanggal',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    child: Text(
                      _startDate == null
                          ? 'Pilih Tanggal'
                          : DateFormat('dd/MM/yyyy').format(_startDate!),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () => _selectEndDate(context),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Sampai Tanggal',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    child: Text(
                      _endDate == null
                          ? 'Pilih Tanggal'
                          : DateFormat('dd/MM/yyyy').format(_endDate!),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderHistoryList() {
    // Create base query
    Query query = _firestore.collection('orders');

    // Apply status filter
    if (_statusFilter != 'all') {
      query = query.where('status', isEqualTo: _statusFilter);
    } else {
      // If 'all', only show completed, cancelled, or ready orders (exclude pending and preparing)
      query =
          query.where('status', whereIn: ['completed', 'cancelled', 'ready']);
    }

    // Apply date filters if available
    if (_startDate != null) {
      // Start of day
      final startTimestamp = Timestamp.fromDate(
        DateTime(_startDate!.year, _startDate!.month, _startDate!.day, 0, 0, 0),
      );
      query = query.where('orderTime', isGreaterThanOrEqualTo: startTimestamp);
    }

    if (_endDate != null) {
      // End of day
      final endTimestamp = Timestamp.fromDate(
        DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59),
      );
      query = query.where('orderTime', isLessThanOrEqualTo: endTimestamp);
    }

    // Order by order time, most recent first
    query = query.orderBy('orderTime', descending: true);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
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
                Icon(Icons.history, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'Tidak ada riwayat pesanan',
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
            final status = data['status'] ?? 'completed';
            final paymentStatus = data['paymentStatus'] ?? 'pending';
            final paymentMethod = data['paymentMethod'] ?? 'COD';

            // Choose color based on status
            Color statusColor;
            switch (status) {
              case 'completed':
                statusColor = Colors.green;
                break;
              case 'cancelled':
                statusColor = Colors.red;
                break;
              case 'ready':
                statusColor = Colors.blue;
                break;
              default:
                statusColor = Colors.orange;
            }

            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 16),
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => OrderDetailPage(orderId: orderId),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Pesanan #${orderId.substring(0, 6)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Chip(
                            label: Text(
                              status,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                            backgroundColor: statusColor,
                            padding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Pelanggan: $customerName'),
                      Text(
                          'Tanggal: ${DateFormat('dd MMM yyyy, HH:mm').format(orderTime)}'),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total: ${currencyFormatter.format(totalAmount)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Row(
                            children: [
                              Icon(
                                paymentStatus == 'paid'
                                    ? Icons.check_circle
                                    : Icons.pending,
                                color: paymentStatus == 'paid'
                                    ? Colors.green
                                    : Colors.orange,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$paymentMethod (${paymentStatus == 'paid' ? 'Lunas' : 'Belum Lunas'})',
                                style: TextStyle(
                                  color: paymentStatus == 'paid'
                                      ? Colors.green
                                      : Colors.orange,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
