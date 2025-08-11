import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:food_ui/src/main_screen.dart';
import 'package:food_ui/src/cart_service.dart';
import 'package:food_ui/src/cart.dart';

class BankTransferPage extends StatefulWidget {
  final String orderId;
  final double total;

  const BankTransferPage({
    Key? key,
    required this.orderId,
    required this.total,
  }) : super(key: key);

  @override
  State<BankTransferPage> createState() => _BankTransferPageState();
}

class _BankTransferPageState extends State<BankTransferPage> {
  final List<Map<String, String>> _bankAccounts = [
    {
      'bank': 'BCA',
      'number': '1234567890',
      'name': 'RM Solideo Kuliner',
    },
    {
      'bank': 'BNI',
      'number': '0987654321',
      'name': 'RM Solideo Kuliner',
    },
    {
      'bank': 'Mandiri',
      'number': '2468013579',
      'name': 'RM Solideo Kuliner',
    },
  ];

  final CartService _cartService = CartService();
  late Timer _timer;
  late StreamSubscription _paymentSubscription;

  int _secondsRemaining = 7200; // 2 jam dalam detik
  String _paymentStatus =
      'pending'; // pending, awaiting_confirmation, verified, completed
  bool _isWaitingConfirmation = false;
  bool _isProcessing = false;
  String? _selectedBank;
  // Controller untuk nama pengirim
  final TextEditingController _senderNameController = TextEditingController();

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

    // Tambahkan listener untuk memantau perubahan status pembayaran
    _paymentSubscription =
        _cartService.getOrderDetails(widget.orderId).listen((snapshot) {
      if (!mounted) return;

      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        final paymentStatus = data['paymentStatus'] as String?;

        // Tambahkan log debugging
        print('PAYMENT STATUS UPDATE: $paymentStatus');

        setState(() {
          if (paymentStatus == 'awaiting_confirmation') {
            _isWaitingConfirmation = true;
            _paymentStatus = 'awaiting_confirmation';
          } else if (paymentStatus == 'verified' ||
              paymentStatus == 'completed' ||
              paymentStatus == 'paid') {
            // Tambahkan 'paid' di sini
            _isWaitingConfirmation = false;
            _paymentStatus = 'completed';
            // Bersihkan keranjang
            final CartProvider cartProvider = CartProvider();
            cartProvider.clearCart();
          }
        });

        // Log status untuk debugging
        print('Payment status updated: $paymentStatus');
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _paymentSubscription.cancel();
    _senderNameController.dispose();
    super.dispose();
  }

  // Format waktu dari detik ke hh:mm:ss
  String _formatTime(int seconds) {
    int hours = seconds ~/ 3600;
    int minutes = (seconds % 3600) ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  // Copy text to clipboard
  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Disalin ke clipboard'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  // Get bank color
  Color _getBankColor(String bank) {
    switch (bank) {
      case 'BCA':
        return Colors.blue[800]!;
      case 'BNI':
        return Colors.orange[800]!;
      case 'Mandiri':
        return Colors.amber[800]!;
      default:
        return Colors.grey[800]!;
    }
  }

  // Confirm payment
  Future<void> _confirmPayment() async {
    if (_selectedBank == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan pilih bank yang digunakan untuk transfer'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_senderNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan masukkan nama pengirim transfer'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // Log untuk memastikan data yang dikirim benar
      print('Mengirim konfirmasi pembayaran:');
      print('Order ID: ${widget.orderId}');
      print('Bank Name: ${_selectedBank}');
      print('Sender Name: ${_senderNameController.text.trim()}');

      // Update payment data di Firestore
      await _cartService.confirmManualTransfer(
        orderId: widget.orderId,
        bankName: _selectedBank!,
        senderName: _senderNameController.text.trim(),
      );

      if (!mounted) return;

      setState(() {
        _isWaitingConfirmation = true;
        _isProcessing = false;
      });

      // Tampilkan pesan sukses
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Konfirmasi pembayaran berhasil dikirim. Menunggu verifikasi admin.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );

      // PENTING: Tidak perlu lagi menggunakan simulasi Future.delayed
      // Status akan berubah otomatis melalui StreamSubscription
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      print('Error confirming payment: $e');

      // Ganti pesan error di sini
      String errorMessage = 'Terjadi kesalahan saat konfirmasi pembayaran.';

      // Cek jika error adalah permission-denied
      if (e.toString().contains('permission-denied')) {
        errorMessage =
            'Pembayaran Anda telah diterima. Menunggu konfirmasi dari admin.';

        // Set status waiting confirmation karena sebenarnya operasi berhasil
        setState(() {
          _isWaitingConfirmation = true;
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor:
              _isWaitingConfirmation ? Colors.green : Colors.orange,
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

  // Cancel order
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

  // Go back to home
  void _goToHome() {
    Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    if (_paymentStatus == 'completed') {
      return _buildPaymentCompleted();
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Transfer Bank',
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
      body: _isWaitingConfirmation
          ? _buildWaitingConfirmation()
          : _buildPaymentInstructions(),
    );
  }

  Widget _buildPaymentInstructions() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Countdown timer
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber[200]!),
            ),
            child: Column(
              children: [
                const Text(
                  'Selesaikan pembayaran dalam',
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
                    color: _secondsRemaining < 1800 ? Colors.red : Colors.black,
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
                    'Rp ${widget.total.toStringAsFixed(0)}'),
                const SizedBox(height: 8),
                _buildInfoRow('Metode Pembayaran', 'Transfer Bank'),
                const SizedBox(height: 8),
                _buildInfoRow('Status', 'Menunggu Pembayaran'),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Bank accounts
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
                const Row(
                  children: [
                    Icon(Icons.account_balance, color: Colors.blue),
                    SizedBox(width: 8),
                    Text(
                      'Rekening Tujuan',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Silakan transfer ke salah satu rekening berikut:',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),

                // List of bank accounts
                ..._bankAccounts
                    .map((account) => _buildBankAccountCard(account))
                    .toList(),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Konfirmasi transfer manual
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
                const Row(
                  children: [
                    Icon(Icons.check_circle_outline, color: Colors.green),
                    SizedBox(width: 8),
                    Text(
                      'Konfirmasi Pembayaran',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Bank selection
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Bank yang Digunakan',
                    border: OutlineInputBorder(),
                  ),
                  hint: const Text('Pilih bank yang digunakan'),
                  value: _selectedBank,
                  items: _bankAccounts.map((account) {
                    return DropdownMenuItem<String>(
                      value: account['bank'],
                      child: Text(account['bank']!),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedBank = value;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Nama pengirim
                TextFormField(
                  controller: _senderNameController,
                  decoration: const InputDecoration(
                    labelText: 'Nama Pengirim Transfer',
                    hintText: 'Masukkan nama sesuai rekening',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Admin akan melakukan verifikasi manual. Harap pastikan nama pengirim sesuai dengan rekening Anda.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Payment instructions
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
                    Text(
                      'Petunjuk Pembayaran',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildInstructionStep(
                  1,
                  'Transfer tepat hingga 3 digit terakhir',
                  'Transfer tepat Rp ${widget.total.toStringAsFixed(0)} ke salah satu rekening di atas',
                ),
                const SizedBox(height: 12),
                _buildInstructionStep(
                  2,
                  'Catat kode referensi',
                  'Gunakan ID Pesanan (${widget.orderId}) sebagai keterangan transfer',
                ),
                const SizedBox(height: 12),
                _buildInstructionStep(
                  3,
                  'Isi form konfirmasi',
                  'Pilih bank dan masukkan nama pengirim pada form di atas',
                ),
                const SizedBox(height: 12),
                _buildInstructionStep(
                  4,
                  'Klik tombol Konfirmasi',
                  'Setelah mengisi form, klik tombol "Saya Sudah Transfer" di bawah',
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
                          'Saya Sudah Transfer',
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

  Widget _buildWaitingConfirmation() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Progress indicator
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                shape: BoxShape.circle,
              ),
              child: const SizedBox(
                height: 80,
                width: 80,
                child: CircularProgressIndicator(
                  color: Colors.blue,
                  strokeWidth: 4,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Status text
            const Text(
              'Konfirmasi Pembayaran',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            Text(
              'Terima kasih telah melakukan pembayaran.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            Text(
              'Admin akan segera memverifikasi pembayaran Anda.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
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

            // Tombol refresh manual
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                // Ambil data terbaru secara manual
                try {
                  final doc = await FirebaseFirestore.instance
                      .collection('orders')
                      .doc(widget.orderId)
                      .get();

                  if (doc.exists) {
                    final data = doc.data() as Map<String, dynamic>;
                    final paymentStatus = data['paymentStatus'] as String?;

                    print('Manual refresh - Payment status: $paymentStatus');

                    if (paymentStatus == 'verified' ||
                        paymentStatus == 'completed' ||
                        paymentStatus == 'paid') {
                      setState(() {
                        _paymentStatus = 'completed';
                      });

                      // Clear cart
                      final CartProvider cartProvider = CartProvider();
                      cartProvider.clearCart();
                    } else {
                      // Tampilkan status terkini
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'Status pembayaran: ${paymentStatus ?? 'belum diproses'}'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }
                  }
                } catch (e) {
                  print('Error refreshing payment status: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Gagal memeriksa status: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Periksa Status Pembayaran'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              ),
            ),

            // Tambahkan tombol kembali ke beranda
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _goToHome,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue,
                  side: const BorderSide(color: Colors.blue),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Kembali ke Beranda',
                  style: TextStyle(
                    fontSize: 16,
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

  Widget _buildPaymentCompleted() {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.black),
            onPressed: _goToHome,
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
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
              const SizedBox(height: 32),

              // Success text
              const Text(
                'Konfirmasi Diterima!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              Text(
                'Konfirmasi pembayaran Anda telah diterima.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              Text(
                'Admin akan segera memverifikasi pembayaran Anda dan memproses pesanan.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Order ID and status
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  children: [
                    _buildInfoRow('ID Pesanan', widget.orderId),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                        'Total', 'Rp ${widget.total.toStringAsFixed(0)}'),
                    const SizedBox(height: 8),
                    _buildInfoRow('Status', 'Menunggu Verifikasi',
                        valueColor: Colors.orange),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Back to home button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final CartProvider cartProvider = CartProvider();
                    cartProvider.clearCart();
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                          builder: (context) => const MainScreen()),
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
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBankAccountCard(Map<String, String> account) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _getBankColor(account['bank'] ?? ''),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              account['bank'] ?? '',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      account['number'] ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 16),
                      onPressed: () =>
                          _copyToClipboard(account['number'] ?? ''),
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.only(left: 8),
                    ),
                  ],
                ),
                Text(
                  account['name'] ?? '',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[700],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: valueColor ?? Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildInstructionStep(
    int number,
    String title,
    String description,
  ) {
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
            number.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
