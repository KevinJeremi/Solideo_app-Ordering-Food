import 'package:flutter/material.dart';
import 'admin_orders.dart';
import 'admin_payments.dart';
import 'admin_order_history.dart';
import 'admin_statistics.dart';
import 'user_auth/firebase_auth_implementation/firebase_auth_services.dart';
import 'login.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final FirebaseAuthService _authService = FirebaseAuthService();
  int _selectedIndex = 0;
  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    // Penting: Pastikan onLogout dikirim dengan benar
    _initializePages();
  }

  void _initializePages() {
    _pages = [
      const AdminOrdersPage(),
      const AdminPaymentsPage(),
      AdminOrderHistoryPage(onLogout: _handleLogout),
      const AdminStatisticsPage(),
    ];
  }

  Future<void> _handleLogout() async {
    print("Logout dipanggil"); // Tambahkan log untuk debugging
    try {
      await _authService.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }
    } catch (e) {
      print("Error saat logout: $e");
      // Tampilkan pesan error jika diperlukan
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel - Solideo Kuliner'),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
        // Tombol logout dihapus dari sini
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.deepOrange,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_basket),
            label: 'Pesanan Baru',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.payment),
            label: 'Konfirmasi Pembayaran',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Riwayat Pesanan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Statistik',
          ),
        ],
      ),
    );
  }
}
