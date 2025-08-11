import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:food_ui/splash.dart';
import 'package:food_ui/src/login.dart';
import 'package:google_fonts/google_fonts.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Konfigurasi ErrorWidget.builder untuk menangkap error rendering dengan lebih detail
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Container(
      padding: const EdgeInsets.all(8),
      alignment: Alignment.center,
      child: Text(
        'Error: ${details.exception}',
        style: const TextStyle(color: Colors.red),
      ),
    );
  };

  // Inisialisasi Firebase tanpa options khusus
  // Ini akan menggunakan konfigurasi default dari google-services.json (Android)
  // atau GoogleService-Info.plist (iOS)
  await Firebase.initializeApp();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'RM Solideo Kuliner',
      theme: ThemeData(
        primarySwatch: Colors.orange,
        fontFamily: GoogleFonts.poppins().fontFamily,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          hintStyle: const TextStyle(color: Colors.grey),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            minimumSize: const Size(double.infinity, 48),
          ),
        ),
      ),
      home: SplashPage(),
    );
  }
}
