import 'package:flutter/material.dart';
import 'package:food_ui/src/cart_provider.dart';

class CartItem {
  final String id;
  final String name;
  final String restaurant;
  final int price;
  final int quantity;
  final String image;
  final String note;
  final List<String> options;
  final String orderType;

  CartItem(
      {required this.id,
      required this.name,
      required this.restaurant,
      required this.price,
      required this.quantity,
      required this.image,
      this.note = '',
      this.options = const [],
      this.orderType = ''});
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
