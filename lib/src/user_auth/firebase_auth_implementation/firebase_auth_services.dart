import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'global/common/toast.dart';

class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Metode untuk registrasi user baru
  Future<User?> signUpWithEmailAndPassword(
      String email, String password, String name) async {
    try {
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);

      // Update displayName pengguna
      await credential.user?.updateDisplayName(name);

      // Tambahkan user ke Firestore dengan role 'customer'
      await _firestore.collection('users').doc(credential.user!.uid).set({
        'email': email,
        'name': name,
        'role': 'customer',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Tambahkan pesan sukses dengan warna hijau
      showToast(message: 'Pendaftaran berhasil!', isSuccess: true);
      return credential.user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        showToast(message: 'Email sudah digunakan.');
      } else if (e.code == 'weak-password') {
        showToast(
            message: 'Password terlalu lemah. Gunakan minimal 6 karakter.');
      } else if (e.code == 'invalid-email') {
        showToast(message: 'Format email tidak valid.');
      } else {
        showToast(message: 'Terjadi kesalahan: ${e.code}');
      }
    } catch (e) {
      showToast(message: 'Terjadi kesalahan yang tidak diketahui.');
    }
    return null;
  }

  // Metode untuk login user
  Future<User?> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      UserCredential credential = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      // Tambahkan pesan sukses dengan warna hijau
      showToast(message: 'Berhasil masuk', isSuccess: true);
      return credential.user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        showToast(message: 'Email tidak ditemukan.');
      } else if (e.code == 'wrong-password') {
        showToast(message: 'Password salah.');
      } else if (e.code == 'invalid-email') {
        showToast(message: 'Format email tidak valid.');
      } else if (e.code == 'user-disabled') {
        showToast(message: 'Akun ini telah dinonaktifkan.');
      } else {
        showToast(message: 'Terjadi kesalahan: ${e.code}');
      }
    } catch (e) {
      showToast(message: 'Terjadi kesalahan yang tidak diketahui.');
    }
    return null;
  }

  // Metode untuk login sebagai tamu (anonymous)
  Future<User?> signInAnonymously() async {
    try {
      UserCredential credential = await _auth.signInAnonymously();

      // Tambahkan data tamu ke Firestore untuk tracking
      if (credential.user != null) {
        await _firestore.collection('users').doc(credential.user!.uid).set({
          'role': 'guest',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // Tambahkan warna hijau untuk pesan sukses
      showToast(message: 'Berhasil masuk sebagai tamu.', isSuccess: true);
      return credential.user;
    } on FirebaseAuthException catch (e) {
      showToast(message: 'Gagal masuk sebagai tamu: ${e.code}');
    } catch (e) {
      showToast(message: 'Terjadi kesalahan yang tidak diketahui.');
    }
    return null;
  }

  // Metode untuk logout
  Future<void> signOut() async {
    await _auth.signOut();
    // Opsional: Tambahkan pesan logout sukses
    showToast(message: 'Berhasil keluar', isSuccess: true);
  }

  // Metode untuk mendapatkan user saat ini
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  // Memeriksa apakah pengguna adalah tamu
  bool isUserGuest() {
    final user = _auth.currentUser;
    return user != null && user.isAnonymous;
  }

  // Metode untuk reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      // Tambahkan warna hijau untuk pesan sukses
      showToast(
          message: 'Email reset password telah dikirim.', isSuccess: true);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        showToast(message: 'Email tidak ditemukan.');
      } else {
        showToast(message: 'Terjadi kesalahan: ${e.code}');
      }
    }
  }

  // ====== FITUR ADMIN ======

  // Memeriksa apakah pengguna adalah admin
  Future<bool> isUserAdmin(String uid) async {
    try {
      // Akses dokumen langsung berdasarkan UID tanpa menggunakan query
      DocumentSnapshot doc =
          await _firestore.collection('users').doc(uid).get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return data['role'] == 'admin';
      }
      return false;
    } catch (e) {
      print('Error checking admin status: $e');
      return false;
    }
  }

  // Membuat akun admin baru
  Future<User?> createAdminUser(
      String email, String password, String name) async {
    try {
      // Buat user baru
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);

      // Update display name
      await credential.user?.updateDisplayName(name);

      // Tetapkan sebagai admin dalam Firestore
      await _firestore.collection('users').doc(credential.user!.uid).set({
        'email': email,
        'name': name,
        'role': 'admin',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Tambahkan warna hijau untuk pesan sukses
      showToast(message: 'Akun admin berhasil dibuat.', isSuccess: true);
      return credential.user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        showToast(message: 'Email sudah digunakan.');
      } else {
        showToast(message: 'Gagal membuat admin: ${e.message}');
      }
      return null;
    } catch (e) {
      showToast(message: 'Terjadi kesalahan yang tidak diketahui.');
      return null;
    }
  }

  // Login sebagai admin
  Future<User?> signInAsAdmin(String email, String password) async {
    try {
      User? user = await signInWithEmailAndPassword(email, password);

      if (user != null) {
        // Periksa apakah user adalah admin
        bool isAdmin = await isUserAdmin(user.uid);

        if (!isAdmin) {
          showToast(message: 'Akun ini bukan admin.');
          await signOut();
          return null;
        }

        // Tambahkan pesan sukses khusus admin (opsional, karena sudah ada di signInWithEmailAndPassword)
        showToast(message: 'Berhasil masuk sebagai admin.', isSuccess: true);
        return user;
      }

      return null;
    } catch (e) {
      showToast(message: 'Gagal login sebagai admin.');
      return null;
    }
  }
}
