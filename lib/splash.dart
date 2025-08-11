import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:food_ui/src/admin_dashboard.dart';
import 'package:food_ui/src/landing_page.dart';
import 'package:food_ui/src/main_screen.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    checkUser();
    super.initState();
  }

  void checkUser() {
    final user = FirebaseAuth.instance.currentUser;
    print(user);
    print("user");
    if (user != null) {
      if (user.email!.contains('admin')) {
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (!mounted) return;
          Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const AdminDashboard()),
              (route) => false);
        });
      } else {
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (!mounted) return;
          Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const MainScreen()),
              (route) => false);
        });
      }
    } else {
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LandingPage()),
            (route) => false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color.fromARGB(255, 0, 0, 0),
      height: MediaQuery.of(context).size.height,
      width: MediaQuery.of(context).size.width,
      child: Center(
        child: Image.asset('assets/images/logo.png'),
      ),
    );
  }
}
