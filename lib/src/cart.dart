import 'package:flutter/material.dart';
import 'package:food_ui/src/checkout_page.dart';
import 'package:food_ui/src/cart_provider.dart' as cart;

class CartItem {
  final String id;
  final String name;
  final String restaurant;
  final int price;
  final int quantity;
  final String image;
  final String note;
  final List<String> options;

  CartItem({
    required this.id,
    required this.name,
    required this.restaurant,
    required this.price,
    required this.quantity,
    required this.image,
    this.note = '',
    this.options = const [],
  });
}

// Class untuk menyimpan data keranjang secara global
class CartProvider {
  // Singleton pattern untuk memastikan hanya ada satu instance
  static final CartProvider _instance = CartProvider._internal();

  factory CartProvider() {
    return _instance;
  }

  CartProvider._internal();

  // Item keranjang
  final List<CartItem> items = [];

  // Menambahkan item ke keranjang
  void addItem({
    required String name,
    required int price,
    required String category,
    required String image,
  }) {
    // Cek apakah item sudah ada di keranjang
    int existingIndex = items.indexWhere((item) => item.name == name);

    if (existingIndex != -1) {
      // Jika sudah ada, tambah quantity
      final existingItem = items[existingIndex];
      items[existingIndex] = CartItem(
        id: existingItem.id,
        name: existingItem.name,
        restaurant: existingItem.restaurant,
        price: existingItem.price,
        quantity: existingItem.quantity + 1,
        image: existingItem.image,
        note: existingItem.note,
        options: existingItem.options,
      );
    } else {
      // Jika belum ada, tambahkan item baru
      items.add(CartItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        restaurant: 'RM Solideo Kuliner',
        price: price,
        quantity: 1,
        image: image,
      ));
    }
  }

  // Mengurangi item dari keranjang
  void removeItem(String name) {
    int existingIndex = items.indexWhere((item) => item.name == name);

    if (existingIndex != -1) {
      final existingItem = items[existingIndex];

      if (existingItem.quantity > 1) {
        // Jika quantity lebih dari 1, kurangi quantity
        items[existingIndex] = CartItem(
          id: existingItem.id,
          name: existingItem.name,
          restaurant: existingItem.restaurant,
          price: existingItem.price,
          quantity: existingItem.quantity - 1,
          image: existingItem.image,
          note: existingItem.note,
          options: existingItem.options,
        );
      } else {
        // Jika quantity 1, hapus item dari keranjang
        items.removeAt(existingIndex);
      }
    }
  }

  // Mendapatkan quantity item di keranjang
  int getItemQuantity(String name) {
    int existingIndex = items.indexWhere((item) => item.name == name);
    if (existingIndex != -1) {
      return items[existingIndex].quantity;
    }
    return 0;
  }

  // Mendapatkan total item di keranjang
  int getTotalItems() {
    int total = 0;
    for (var item in items) {
      total += item.quantity;
    }
    return total;
  }

  // Mendapatkan subtotal
  double getSubtotal() {
    double subtotal = 0;
    for (var item in items) {
      subtotal += (item.price * item.quantity);
    }
    return subtotal;
  }

  // Membersihkan keranjang
  void clearCart() {
    items.clear();
  }
}

class CartPage extends StatefulWidget {
  String? orderType;
  CartPage({super.key, required this.orderType});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final CartProvider _cartProvider = CartProvider();
  double _subtotal = 0;
  double _total = 0;
  double _discountAmount = 0;
  int _itemCount = 0;

  final List<Map<String, dynamic>> addresses = [
    {
      'type': 'Home',
      'address': 'Jl. Sudirman No. 123, Jakarta Pusat',
      'note': 'Apartemen Sudirman Tower, Unit 12A',
    },
    {
      'type': 'Office',
      'address': 'Menara BCA, Jl. Gatot Subroto, Jakarta Selatan',
      'note': 'Lantai 25, Ruang 25B',
    },
    {
      'type': 'Other',
      'address': 'Jl. Kemang Raya No. 45, Jakarta Selatan',
      'note': 'Rumah cat putih, pagar hitam',
    },
  ];

  @override
  void initState() {
    super.initState();
    _calculateTotals();
  }

  void _calculateTotals() {
    setState(() {
      _subtotal = _cartProvider.getSubtotal();
      _itemCount = _cartProvider.getTotalItems();
      _total = _subtotal;
    });
  }

  void _showClearCartDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Keranjang'),
        content: const Text(
            'Apakah anda yakin untuk menghapus item dalam keranjang?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _cartProvider.clearCart();
                _calculateTotals();
              });

              Navigator.pop(context);
              _showSnackBar('Keranjang Dibersihkan', color: Colors.green);
            },
            child: const Text(
              'Hapus',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(
    String message, {
    SnackBarAction? action,
    Duration duration = const Duration(seconds: 2),
    Color? color,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontSize: 12),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: duration,
        action: action,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      body:
          _cartProvider.items.isEmpty ? _buildEmptyCart() : _buildCartContent(),
      bottomNavigationBar:
          _cartProvider.items.isEmpty ? null : _buildBottomBar(),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 100,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 20),
          Text(
            'Keranjang anda kosong',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Tambahkan item ke keranjang untuk melanjutkan',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: const Icon(Icons.restaurant_menu),
            label: const Text('Belanja Sekarang'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              backgroundColor: Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCartItems(),
          _buildOrderSummary(),
        ],
      ),
    );
  }

  Widget _buildCartItems() {
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
                'Item dalam Keranjang (${_cartProvider.getTotalItems()})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                },
                icon: const Icon(
                  Icons.add,
                  size: 18,
                  color: Colors.orange,
                ),
                label: const Text(
                  'Tambah Item',
                  style: TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _cartProvider.items.length,
            itemBuilder: (context, index) {
              final item = _cartProvider.items[index];
              return _buildCartItemTile(item);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCartItemTile(CartItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Item image
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              item.image,
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 80,
                  height: 80,
                  color: Colors.grey[300],
                  child: const Icon(
                    Icons.image_not_supported,
                    color: Colors.grey,
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Item name
                Text(
                  item.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                // Restaurant name
                Text(
                  item.restaurant,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                // Item price
                Text(
                  'Rp ${item.price}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(height: 8),
                // Options (if any)
                if (item.options.isNotEmpty) ...[
                  Wrap(
                    spacing: 6,
                    children: item.options.map((option) {
                      return Chip(
                        label: Text(
                          option,
                          style: const TextStyle(fontSize: 10),
                        ),
                        backgroundColor: Colors.orange[50],
                        padding: EdgeInsets.zero,
                        labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                ],
                // Note (if any)
                if (item.note.isNotEmpty) ...[
                  Text(
                    'Note: ${item.note}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
          // Quantity controls
          Column(
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    _cartProvider.addItem(
                      name: item.name,
                      price: item.price,
                      category: '',
                      image: item.image,
                    );
                    _calculateTotals();
                  });
                },
                icon: const Icon(Icons.add_circle),
                color: Colors.orange,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  item.quantity.toString(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _cartProvider.removeItem(item.name);
                    _calculateTotals();
                  });
                },
                icon: const Icon(Icons.remove_circle),
                color: Colors.red[400],
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSummary() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ringkasan Pesanan',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          // Subtotal
          _buildSummaryRow('Subtotal', 'Rp ${_subtotal.toStringAsFixed(0)}'),
          const SizedBox(height: 8),
          // Tax
          // Discount (if any)
          if (_discountAmount > 0) ...[
            const SizedBox(height: 8),
            _buildSummaryRow(
              'Discount',
              '- Rp ${_discountAmount.toStringAsFixed(0)}',
              valueColor: Colors.green,
            ),
          ],
          const Divider(height: 24),
          // Total
          _buildSummaryRow(
            'Total',
            'Rp ${_total.toStringAsFixed(0)}',
            isBold: true,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool isBold = false,
    Color? valueColor,
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
            color: valueColor ?? (isBold ? Colors.black : Colors.grey[600]),
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
        onPressed: () {
          // Convert the CartItem objects to the expected type
          List<cart.CartItem> checkoutItems = _cartProvider.items
              .map((item) => cart.CartItem(
                  id: item.id,
                  name: item.name,
                  restaurant: item.restaurant,
                  price: item.price,
                  quantity: item.quantity,
                  image: item.image,
                  note: item.note,
                  options: item.options,
                  orderType: widget.orderType!))
              .toList();

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CheckoutPage(
                  subtotal: _subtotal,
                  total: _total,
                  cartItems: checkoutItems,
                  orderType: widget.orderType!),
            ),
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
          'Proses ke Checkout',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
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
        'Keranjang Saya',
        style: TextStyle(
          color: Colors.black,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back,
          color: Colors.black,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        if (_cartProvider.items.isNotEmpty)
          IconButton(
            icon: Icon(
              Icons.delete_sweep,
              color: Colors.red[800],
              size: 24,
            ),
            onPressed: () {
              _showClearCartDialog();
            },
          ),
      ],
    );
  }
}
