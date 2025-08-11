import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'user_auth/firebase_auth_implementation/firebase_auth_services.dart';
import 'main_screen.dart';
import 'register.dart';
import 'admin_dashboard.dart'; // Import dashboard admin

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final FirebaseAuthService _authService = FirebaseAuthService();

  bool _obscureText = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Login pengguna (baik user biasa maupun admin)
  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      FocusScope.of(context).unfocus();

      try {
        // Gunakan metode login untuk mendapatkan user
        final user = await _authService.signInWithEmailAndPassword(
            _emailController.text.trim(), _passwordController.text.trim());

        if (user != null && mounted) {
          // Periksa apakah user adalah admin
          bool isAdmin = await _authService.isUserAdmin(user.uid);

          if (isAdmin) {
            // Jika admin, navigasi ke dashboard admin
            Future.delayed(const Duration(milliseconds: 500), () {
              if (!mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const AdminDashboard()),
              );
            });
          } else {
            // Jika user biasa, navigasi ke halaman utama
            Future.delayed(const Duration(milliseconds: 500), () {
              if (!mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const MainScreen()),
              );
            });
          }
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  // Fungsi untuk menangani login sebagai tamu
  Future<void> _handleGuestLogin() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = await _authService.signInAnonymously();
      if (user != null && mounted) {
        // Tamu selalu diarahkan ke halaman utama
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const MainScreen()),
          );
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildLogo(),
                    const SizedBox(height: 20),
                    _buildWelcomeText(),
                    const SizedBox(height: 10),
                    _buildDescriptionText(),
                    const SizedBox(height: 40),
                    _buildEmailField(),
                    const SizedBox(height: 16),
                    _buildPasswordField(),
                    const SizedBox(height: 16),
                    _buildForgotPassword(),
                    const SizedBox(height: 24),
                    _buildLoginButton(),
                    const SizedBox(height: 16),
                    _buildGuestLoginButton(), // Tombol untuk login sebagai tamu
                    const SizedBox(height: 20),
                    _buildSignUpOption(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return SvgPicture.asset(
      'assets/images/logo.svg',
      width: 250,
      height: 250,
    );
  }

  Widget _buildWelcomeText() {
    return const Text(
      'Selamat Datang',
      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildDescriptionText() {
    return const Text(
      'Silahkan login akun anda',
      style: TextStyle(fontSize: 14, color: Colors.grey),
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      style: const TextStyle(fontSize: 14),
      decoration: const InputDecoration(
        hintText: 'Email',
        prefixIcon: Icon(Icons.email_outlined),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your email';
        } else if (!value.contains('@')) {
          return 'Please enter a valid email';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: TextInputAction.done,
      obscureText: _obscureText,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: 'Password',
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(
            _obscureText ? Icons.visibility_off : Icons.visibility,
            color: Colors.grey,
          ),
          onPressed: () {
            setState(() {
              _obscureText = !_obscureText;
            });
          },
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your password';
        }
        return null;
      },
    );
  }

  Widget _buildForgotPassword() {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: const Size(0, 0),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: () {
          // Implementasi reset password
          final email = _emailController.text.trim();
          if (email.isNotEmpty && email.contains('@')) {
            _authService.resetPassword(email);
          } else {
            // Tampilkan dialog untuk meminta email
            _showResetPasswordDialog();
          }
        },
        child: const Text(
          'Lupa Password?',
          style: TextStyle(fontSize: 14),
        ),
      ),
    );
  }

  // Dialog untuk reset password
  Future<void> _showResetPasswordDialog() async {
    final resetEmailController = TextEditingController();

    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reset Password'),
          content: TextField(
            controller: resetEmailController,
            decoration: const InputDecoration(
              hintText: 'Masukkan email Anda',
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () {
                final email = resetEmailController.text.trim();
                if (email.isNotEmpty && email.contains('@')) {
                  _authService.resetPassword(email);
                  Navigator.pop(context);
                }
              },
              child: const Text('Kirim'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text('Login'),
      ),
    );
  }

  // Widget untuk tombol login sebagai tamu
  Widget _buildGuestLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: _isLoading ? null : _handleGuestLogin,
        icon: const Icon(Icons.person_outline),
        label: const Text('Masuk sebagai Tamu'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.grey[700],
          side: BorderSide(color: Colors.grey[400]!),
        ),
      ),
    );
  }

  Widget _buildSignUpOption() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "Tidak punya akun?",
          style: TextStyle(color: Colors.grey),
        ),
        TextButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const RegisterPage(),
              ),
            );
          },
          child: const Text(
            'Daftar Akun',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
