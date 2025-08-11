import 'package:flutter/material.dart';

final List<Map<String, dynamic>> categories = [
  {'icon': Icons.set_meal, 'name': 'Paket Hemat'},
  {'icon': Icons.tapas, 'name': 'Pisgor'},
  {'icon': Icons.restaurant, 'name': 'Prasmanan'},
  {'icon': Icons.emoji_food_beverage, 'name': 'Jus Segar'},
  {'icon': Icons.coffee, 'name': 'Minuman'},

];

final List<Map<String, dynamic>> recommendedItems = [
  {
    'image': 'https://placehold.co/150',
    'name': 'Prasmanan',
    'description': 'Menu lezat sekali ambil',
    'rating': '5',
    'price':30000,
  },
  {
    'image': 'https://placehold.co/150',
    'name': 'Paket Ikan Bakar',
    'description': 'Nasi+ikan+kangkung cah+dabu-dabu',
    'rating': '5',
    'price': 30000,
  },
  {
    'image': 'https://placehold.co/150',
    'name': 'Camu-camu',
    'description': 'pisang goreng, kentang goreng',
    'rating': '5',
    'price': 19000,
  },
];
