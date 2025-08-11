import 'package:flutter/material.dart';

final List<String> popularSearches = [
  'Ikan Bakar',
  'Paket Prasmanan',
  'Jus Segar',
  'Makanan Ringan',
  'Kopi Panas',
];

final List<Map<String, dynamic>> cuisines = [
  {
    'name': 'Ikan Bakar',
    'image': 'ikan_bakar.jpg',
    'color': Colors.red[100],
    'icon': Icons.set_meal, // Icon ikan
  },
  {
    'name': 'Pisgor',
    'image': 'makanan_ringan.jpg',
    'color': Colors.orange[100],
    'icon': Icons.tapas, // Icon camilan
  },
  {
    'name': 'Jus Segar',
    'image': 'jus.jpg',
    'color': Colors.green[100],
    'icon': Icons.emoji_food_beverage, // Icon minuman
  },
  {
    'name': 'Kopi Panas',
    'image': 'kopi.jpg',
    'color': Colors.brown[100],
    'icon': Icons.coffee, // Icon kopi
  },
  {
    'name': 'Prasmanan',
    'image': 'prasmanan.jpg',
    'color': Colors.purple[100],
    'icon': Icons.dinner_dining, // Icon prasmanan
  },
];