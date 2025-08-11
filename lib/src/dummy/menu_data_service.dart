import 'package:flutter/material.dart';

// Singleton class untuk mengelola data menu
class MenuDataService {
  // Singleton instance
  static final MenuDataService _instance = MenuDataService._internal();

  // Factory constructor
  factory MenuDataService() {
    return _instance;
  }

  // Private constructor
  MenuDataService._internal();

  // Daftar kategori menu
  final List<Map<String, dynamic>> categories = [
    {
      'name': 'Semua',
      'icon': Icons.restaurant_menu,
    },
    {
      'name': 'Paketan',
      'icon': Icons.restaurant,
    },
    {
      'name': 'Ikan Bakar',
      'icon': Icons.set_meal,
    },
    {
      'name': 'Prasmanan',
      'icon': Icons.dinner_dining,
    },
    {
      'name': 'Minuman',
      'icon': Icons.local_drink,
    },
  ];

  // Data menu berdasarkan kategori
  final Map<String, List<Map<String, dynamic>>> menuItems = {
    'Semua': [
      {
        'name': 'Nasi Goreng Solideo',
        'description': 'Nasi goreng special dengan telur mata sapi dan kerupuk',
        'price': 25000,
        'image': 'https://placehold.co/400x300',
        'category': 'Paketan',
        'rating': 4.8,
        'isRecommended': true,
      },
      {
        'name': 'Ikan Bakar Rica',
        'description': 'Ikan bakar dengan bumbu rica-rica khas Manado',
        'price': 45000,
        'image': 'https://placehold.co/400x300',
        'category': 'Ikan Bakar',
        'rating': 4.9,
        'isRecommended': true,
      },
      {
        'name': 'Es Jeruk Peras',
        'description': 'Jeruk segar diperas langsung',
        'price': 10000,
        'image': 'https://placehold.co/400x300',
        'category': 'Minuman',
        'rating': 4.5,
        'isRecommended': false,
      },
    ],
    'Paketan': [
      {
        'name': 'Nasi Goreng Solideo',
        'description': 'Nasi goreng special dengan telur mata sapi dan kerupuk',
        'price': 25000,
        'image': 'https://placehold.co/400x300',
        'category': 'Paketan',
        'rating': 4.8,
        'isRecommended': true,
      },
      {
        'name': 'Ayam Goreng Paket',
        'description': 'Ayam goreng dengan nasi, sambal, dan lalapan',
        'price': 30000,
        'image': 'https://placehold.co/400x300',
        'category': 'Paketan',
        'rating': 4.7,
        'isRecommended': false,
      },
    ],
    'Ikan Bakar': [
      {
        'name': 'Ikan Bakar Rica',
        'description': 'Ikan bakar dengan bumbu rica-rica khas Manado',
        'price': 45000,
        'image': 'https://placehold.co/400x300',
        'category': 'Ikan Bakar',
        'rating': 4.9,
        'isRecommended': true,
      },
      {
        'name': 'Ikan Nila Bakar',
        'description': 'Ikan nila segar dibakar dengan bumbu tradisional',
        'price': 40000,
        'image': 'https://placehold.co/400x300',
        'category': 'Ikan Bakar',
        'rating': 4.6,
        'isRecommended': false,
      },
    ],
    'Prasmanan': [
      {
        'name': 'Paket Prasmanan A',
        'description': 'Paket untuk 10 orang dengan 5 macam lauk',
        'price': 550000,
        'image': 'https://placehold.co/400x300',
        'category': 'Prasmanan',
        'rating': 4.7,
        'isRecommended': true,
      },
      {
        'name': 'Paket Prasmanan B',
        'description': 'Paket untuk 20 orang dengan 7 macam lauk',
        'price': 950000,
        'image': 'https://placehold.co/400x300',
        'category': 'Prasmanan',
        'rating': 4.8,
        'isRecommended': false,
      },
    ],
    'Minuman': [
      {
        'name': 'Es Jeruk Peras',
        'description': 'Jeruk segar diperas langsung',
        'price': 10000,
        'image': 'https://placehold.co/400x300',
        'category': 'Minuman',
        'rating': 4.5,
        'isRecommended': false,
      },
      {
        'name': 'Es Teh Manis',
        'description': 'Teh manis dingin segar',
        'price': 8000,
        'image': 'https://placehold.co/400x300',
        'category': 'Minuman',
        'rating': 4.4,
        'isRecommended': false,
      },
    ],
  };
}