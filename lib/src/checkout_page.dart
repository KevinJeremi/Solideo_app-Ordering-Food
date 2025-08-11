import 'package:flutter/material.dart';
import 'package:food_ui/src/cart_provider.dart';
import 'package:food_ui/src/counter_payment_page.dart';
import 'package:food_ui/src/bank_transfer_page.dart';
import 'package:food_ui/src/cart_service.dart'; // Import service baru
import 'package:uuid/uuid.dart';
import 'dart:math';

class CheckoutPage extends StatefulWidget {
  final double subtotal;
  final List<CartItem> cartItems;
  final double total;
  final String orderType;

  const CheckoutPage(
      {Key? key,
      required this.subtotal,
      required this.total,
      required this.cartItems,
      required this.orderType})
      : super(key: key);

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final CartProvider _cartProvider = CartProvider();
  final CartService _cartService = CartService(); // Instance CartService
  String _selectedPaymentMethod = ""; // "counter" atau "bank_transfer"
  bool _isProcessing = false;
  String? _tableNumber; // Tambahkan untuk menyimpan nomor meja

  // Untuk input catatan tambahan
  final TextEditingController _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  // Generate ID Pesanan secara acak
  String _generateOrderId() {
    const uuid = Uuid();
    return 'ORDER-${uuid.v4().substring(0, 8).toUpperCase()}';
  }

  // Proses pesanan
  void _processOrder() async {
    if (_selectedPaymentMethod.isEmpty) {
      _showErrorSnackBar('Silakan pilih metode pembayaran');
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // Konversi CartItems ke format yang dibutuhkan Firestore
      List<Map<String, dynamic>> cartItems = widget.cartItems.map((item) {
        return {
          'name': item.name,
          'price': item.price,
          'quantity': item.quantity,
          'note': item.note,
          'image': item.image,
          'restaurant': item.restaurant,
          'options': item.options,
          'subtotal': item.price * item.quantity,
        };
      }).toList();

      // Cetak log untuk debugging
      print("CheckoutPage - Memproses pesanan");
      print("Jumlah items: ${cartItems.length}");
      for (var item in cartItems) {
        print("Item: ${item['name']}, Qty: ${item['quantity']}");
      }
      // Tentukan metode pembayaran
      String paymentMethod =
          _selectedPaymentMethod == 'counter' ? 'COD' : 'Transfer Bank';

      // Buat pesanan di Firestore
      final orderId = await _cartService.createOrder(
          cartItems: cartItems,
          totalAmount: widget.total,
          paymentMethod: paymentMethod,
          tableNumber: _tableNumber,
          notes: _notesController.text,
          orderType: widget.orderType);

      if (!mounted) return;

      // Navigasi ke halaman pembayaran yang sesuai
      if (_selectedPaymentMethod == 'counter') {
        // Navigasi ke halaman pembayaran di konter
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => CounterPaymentPage(
              orderId: orderId,
              total: widget.total,
              cartItems: cartItems, // Kirim data cart items
              tableNumber: _tableNumber, // Kirim nomor meja
            ),
          ),
        );
      } else if (_selectedPaymentMethod == 'bank_transfer') {
        // Navigasi ke halaman transfer bank
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => BankTransferPage(
              orderId: orderId,
              total: widget.total,
            ),
          ),
        );
      }
    } catch (e) {
      print('Error creating order: $e');
      setState(() {
        _isProcessing = false;
      });
      _showErrorSnackBar('Terjadi kesalahan: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
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
          'Checkout',
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
      body: _isProcessing ? _buildProcessingView() : _buildCheckoutForm(),
      bottomNavigationBar: _isProcessing ? null : _buildBottomBar(),
    );
  }

  Widget _buildProcessingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
          ),
          const SizedBox(height: 20),
          Text(
            'Memproses pesanan Anda...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[800],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order Items Summary
          _buildOrderSummaryCard(),
          const SizedBox(height: 16),

          // Table Number Selection (hanya untuk dine-in)
          _buildTableNumberCard(),
          const SizedBox(height: 16),

          // Payment Methods
          _buildPaymentMethodsCard(),
          const SizedBox(height: 16),

          // Additional Notes
          _buildAdditionalNotesCard(),
          const SizedBox(height: 16),

          // Total Summary
          _buildTotalSummaryCard(),
        ],
      ),
    );
  }

  Widget _buildTableNumberCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Nomor Meja',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(Icons.table_restaurant, color: Colors.orange),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: 'Masukkan nomor meja (opsional)',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (value) {
                setState(() {
                  _tableNumber = value.isEmpty ? null : value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummaryCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Pesanan Anda',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(Icons.shopping_bag_outlined, color: Colors.orange),
              ],
            ),
            const Divider(height: 24),

            // List of items (collapsed view)
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _cartProvider.items.length > 2
                  ? 2
                  : _cartProvider.items.length,
              itemBuilder: (context, index) {
                final item = _cartProvider.items[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${item.quantity}x ${item.name}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[800],
                        ),
                      ),
                      Text(
                        'Rp ${(item.price * item.quantity).toString()}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[800],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            // Show more items if needed
            if (_cartProvider.items.length > 2)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '+ ${_cartProvider.items.length - 2} item lainnya',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),

            const Divider(height: 24),

            // Total items and subtotal
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Subtotal (${_cartProvider.getTotalItems()} item)',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'Rp ${widget.subtotal.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodsCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Metode Pembayaran',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(Icons.payment, color: Colors.orange),
              ],
            ),
            const SizedBox(height: 16),

            // Bayar di Konter
            _buildPaymentMethodOption(
              title: 'Bayar di Konter',
              subtitle: 'Bayar langsung di kasir restoran',
              icon: Icons.point_of_sale,
              value: 'counter',
            ),

            const SizedBox(height: 12),

            // Transfer Bank
            _buildPaymentMethodOption(
              title: 'Transfer Bank',
              subtitle: 'BCA, BNI, Mandiri, dan bank lainnya',
              icon: Icons.account_balance,
              value: 'bank_transfer',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required String value,
  }) {
    final isSelected = _selectedPaymentMethod == value;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedPaymentMethod = value;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.orange : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          color: isSelected ? Colors.orange.withOpacity(0.1) : Colors.white,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.orange : Colors.grey[700],
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.orange : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Radio(
              value: value,
              groupValue: _selectedPaymentMethod,
              activeColor: Colors.orange,
              onChanged: (newValue) {
                setState(() {
                  _selectedPaymentMethod = newValue as String;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdditionalNotesCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Catatan Tambahan',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(Icons.note_alt_outlined, color: Colors.orange),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              maxLines: 3,
              maxLength: 200,
              decoration: InputDecoration(
                hintText: 'Tambahkan catatan untuk pesanan Anda (opsional)',
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[400],
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.orange),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalSummaryCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ringkasan Pembayaran',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildSummaryRow(
                'Subtotal', 'Rp ${widget.subtotal.toStringAsFixed(0)}'),
            const Divider(height: 24),
            _buildSummaryRow(
              'Total Pembayaran',
              'Rp ${widget.total.toStringAsFixed(0)}',
              isBold: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isBold ? 16 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: isBold ? Colors.black : Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 16 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: isBold ? Colors.orange : Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _processOrder,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: const Text(
          'Konfirmasi Pesanan',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
