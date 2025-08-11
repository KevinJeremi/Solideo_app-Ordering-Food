import 'package:flutter/material.dart';

final Map<String, dynamic> userData = {
  'name': 'John Doe',
  'email': 'john.doe@example.com',
  'phone': '+62 812-3456-7890',
  'image': 'assets/images/profile.jpg',
  'memberSince': 'January 2023',
  'favoriteAddress': {
    'home': {
      'address': 'Jl. Sudirman No. 123, Jakarta Pusat',
      'isDefault': true,
    },
    'office': {
      'address': 'Menara BCA, Jl. Gatot Subroto, Jakarta Selatan',
      'isDefault': false,
    },
  },
};
