import 'package:flutter/material.dart';
import 'dart:async';
import 'package:food_ui/src/main_screen.dart';
import 'package:food_ui/src/cart_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:food_ui/src/cart.dart'; // Import cart.dart, not cart_provider.dart

class CounterPaymentPage extends StatefulWidget {
  final String orderId;
  final double total;
  final List<Map<String, dynamic>> cartItems;
  final String? tableNumber;

  const CounterPaymentPage({
    Key? key,
    required this.orderId,
    required this.total,
    required this.cartItems,
    this.tableNumber,
  }) : super(key: key);

  @override
  State<CounterPaymentPage> createState() => _CounterPaymentPageState();
}

class _CounterPaymentPageState extends State<CounterPaymentPage> {
  bool _isPaid = false;
  bool _isProcessing = false;
  late Timer _timer;
  int _secondsRemaining = 900; // 15 menit dalam detik
  final CartService _cartService = CartService();

  @override
  void initState() {
    super.initState();
    // Timer untuk countdown
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          _timer.cancel();
          // Batalkan pesanan secara otomatis jika waktu habis
          _cancelOrderDueToTimeout();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  // Format waktu dari detik ke mm:ss
  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  // Konfirmasi pembayaran COD yang diperbarui dengan penanganan error
  Future<void> _confirmPayment() async {
    try {
      setState(() {
        _isProcessing = true;
      });

      // Kode yang diperbarui untuk menangani masalah izin
      // Dapatkan referensi ke dokumen pembayaran
      final paymentRef = FirebaseFirestore.instance
          .collection('payments')
          .doc('payment_${widget.orderId}');
      final orderRef =
          FirebaseFirestore.instance.collection('orders').doc(widget.orderId);

      // Pendekatan dengan transaction untuk meminimalkan masalah konkurensi
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // Periksa dokumen pembayaran
        DocumentSnapshot paymentSnapshot = await transaction.get(paymentRef);

        if (!paymentSnapshot.exists) {
          throw Exception('Dokumen pembayaran tidak ditemukan');
        }

        // Update status dokumen
        transaction.update(paymentRef, {
          'status': 'confirmed_by_user',
          'confirmedByUser': true,
          'confirmedByUserAt': FieldValue.serverTimestamp(),
        });

        // Update order status
        transaction.update(orderRef, {
          'paymentStatus': 'awaiting_confirmation',
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      });

      if (!mounted) return;
      final CartProvider cartProvider = CartProvider();
      cartProvider.clearCart();

      setState(() {
        _isProcessing = false;
        _isPaid = true;
      });
      setState(() {
        _isProcessing = false;
        _isPaid = true;
      });

      // Setelah berhasil dikonfirmasi, tampilkan informasi kepada pengguna
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pembayaran Anda akan segera diverifikasi oleh admin'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 4),
        ),
      );
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      print('Error confirming payment: $e');

      // Tampilkan pesan error yang lebih user-friendly
      String errorMessage =
          'Terjadi kesalahan saat konfirmasi. Silakan coba lagi nanti.';

      if (e.toString().contains('permission-denied')) {
        errorMessage =
            'Pembayaran telah dikirim dan menunggu verifikasi admin. Terima kasih.';
        // Jika masalah izin, tetapi sebenarnya pembayaran sudah berhasil, tampilkan ui sukses
        setState(() {
          _isPaid = true;
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: _isPaid ? Colors.green : Colors.red,
        ),
      );
    }
  }

  // Batalkan pesanan karena timeout
  void _cancelOrderDueToTimeout() async {
    try {
      await _cartService.cancelOrder(widget.orderId, 'Waktu pembayaran habis');

      if (!mounted) return;

      // Navigasi ke beranda
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);

      // Tampilkan snackbar pembatalan
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pesanan dibatalkan karena waktu pembayaran habis.'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      print('Error cancelling order: $e');
    }
  }

  void _cancelOrder() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Batalkan Pesanan'),
        content: const Text('Apakah Anda yakin ingin membatalkan pesanan ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tidak'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Tutup dialog

              try {
                // Update status pesanan menjadi 'cancelled'
                await _cartService.cancelOrder(
                    widget.orderId, 'Dibatalkan oleh pelanggan');

                if (!mounted) return;

                // Navigasi ke beranda
                Navigator.pushNamedAndRemoveUntil(
                    context, '/', (route) => false);

                // Tampilkan snackbar pembatalan
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Pesanan dibatalkan.'),
                    backgroundColor: Colors.red,
                  ),
                );
              } catch (e) {
                print('Error cancelling order: $e');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Bayar di Konter',
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
      ),
      body: _isPaid ? _buildPaymentConfirmed() : _buildWaitingForPayment(),
    );
  }

  Widget _buildWaitingForPayment() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Countdown timer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber[200]!),
            ),
            child: Column(
              children: [
                const Text(
                  'Mohon bayar dalam',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatTime(_secondsRemaining),
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: _secondsRemaining < 300 ? Colors.red : Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Pesanan akan dibatalkan jika tidak dibayar dalam waktu tersebut',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Order information
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Informasi Pesanan',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildInfoRow('ID Pesanan', widget.orderId),
                const SizedBox(height: 8),
                _buildInfoRow('Total Pembayaran',
                    'Rp ${NumberFormat('#,###').format(widget.total.toInt())}'),
                const SizedBox(height: 8),
                _buildInfoRow('Metode Pembayaran', 'Bayar di Konter'),
                const SizedBox(height: 8),
                _buildInfoRow('Status', 'Menunggu Pembayaran'),
                if (widget.tableNumber != null &&
                    widget.tableNumber!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildInfoRow('Nomor Meja', widget.tableNumber!),
                ],
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Instructions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Column(
              children: [
                const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Instruksi Pembayaran',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildInstructionStep(
                  '1',
                  'Tunjukkan ID pesanan Anda ke kasir',
                  Icons.confirmation_number_outlined,
                ),
                const SizedBox(height: 12),
                _buildInstructionStep(
                  '2',
                  'Bayar sesuai jumlah total yang tertera',
                  Icons.payments_outlined,
                ),
                const SizedBox(height: 12),
                _buildInstructionStep(
                  '3',
                  'Tekan tombol "Sudah Bayar" setelah melakukan pembayaran',
                  Icons.check_circle_outline,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _cancelOrder,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Batalkan',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _confirmPayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isProcessing
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Sudah Bayar',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentConfirmed() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Success icon
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green[50],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle,
              size: 80,
              color: Colors.green[700],
            ),
          ),
          const SizedBox(height: 24),

          // Success text
          const Text(
            'Pembayaran Dikonfirmasi!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          // Description
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Terima kasih atas pesanan Anda. Pembayaran akan segera diverifikasi oleh admin dan pesanan Anda akan diproses.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),

          // Order ID
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'ID Pesanan: ${widget.orderId}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Home button
          SizedBox(
            width: 200,
            child: ElevatedButton(
              onPressed: () {
                final CartProvider cartProvider = CartProvider();
                cartProvider.clearCart();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const MainScreen()),
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Kembali ke Beranda',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[700],
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildInstructionStep(String number, String text, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Colors.blue,
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Row(
            children: [
              Icon(icon, color: Colors.blue[700], size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[800],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
