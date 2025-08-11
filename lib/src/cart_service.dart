import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

class CartService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Generate order ID
  String generateOrderId() {
    const uuid = Uuid();
    return 'ORDER-${uuid.v4().substring(0, 8).toUpperCase()}';
  }

  // Menyimpan pesanan ke Firestore
  Future<String> createOrder(
      {required List<Map<String, dynamic>> cartItems,
      required double totalAmount,
      required String paymentMethod,
      String? tableNumber,
      String? notes,
      String? orderType}) async {
    try {
      // Dapatkan data pengguna
      User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User tidak terautentikasi');
      }

      // Generate order ID
      final orderId = generateOrderId();

      // Siapkan data pesanan
      Map<String, dynamic> orderData = {
        'orderId': orderId,
        'userId': currentUser.uid,
        'customerName': currentUser.displayName ?? 'Pelanggan',
        'customerPhone': currentUser.phoneNumber ?? '-',
        'email': currentUser.email ?? '-',
        'totalAmount': totalAmount,
        'items': cartItems,
        'status': 'pending', // Status awal: pending
        'paymentStatus': 'pending', // Status pembayaran awal: pending
        'paymentMethod': paymentMethod,
        'orderTime': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
        'tableNumber': tableNumber ?? '-',
        'notes': notes ?? '',
        'orderType': orderType,
      };

      print("Data order yang akan disimpan: $orderData");

      // Simpan ke koleksi orders
      await _firestore.collection('orders').doc(orderId).set(orderData);

      // Jika pembayaran adalah transfer bank, buat data pembayaran
      if (paymentMethod == 'Transfer Bank') {
        Map<String, dynamic> paymentData = {
          'orderId': orderId,
          'userId': currentUser.uid,
          'customerName': currentUser.displayName ?? 'Pelanggan',
          'amount': totalAmount,
          'paymentMethod': paymentMethod,
          'bankName': '', // Tambahkan field kosong untuk bankName
          'senderName': '', // Tambahkan field kosong untuk senderName
          'status': 'pending', // Status awal: pending
          'timestamp': FieldValue.serverTimestamp(),
        };

        // Log untuk memastikan data pembayaran lengkap
        print("Payment data being saved: $paymentData");

        // Simpan ke koleksi payments
        await _firestore
            .collection('payments')
            .doc('payment_$orderId')
            .set(paymentData);
      } else if (paymentMethod == 'COD') {
        // Untuk COD (Cash on Delivery), juga buat record pembayaran
        Map<String, dynamic> paymentData = {
          'orderId': orderId,
          'userId': currentUser.uid,
          'customerName': currentUser.displayName ?? 'Pelanggan',
          'amount': totalAmount,
          'paymentMethod': 'COD',
          'status': 'pending', // Status awal: pending
          'timestamp': FieldValue.serverTimestamp(),
        };

        await _firestore
            .collection('payments')
            .doc('payment_$orderId')
            .set(paymentData);
      }

      return orderId;
    } catch (e) {
      print('Error creating order: $e');
      rethrow;
    }
  }

  // Konfirmasi transfer bank manual (tanpa bukti pembayaran)
  Future<void> confirmManualTransfer({
    required String orderId,
    required String bankName,
    required String senderName,
  }) async {
    try {
      // Sediakan data yang akan diupdate
      Map<String, dynamic> paymentUpdateData = {
        'bankName': bankName,
        'senderName': senderName,
        'status': 'awaiting_confirmation',
        'confirmedByUser': true,
        'confirmedByUserAt': FieldValue.serverTimestamp(),
      };

      // Log data update untuk debugging
      print('Payment update data: $paymentUpdateData for orderId: $orderId');

      // Update dokumen payment
      await _firestore
          .collection('payments')
          .doc('payment_$orderId')
          .update(paymentUpdateData);

      // Update status pesanan ke awaiting_confirmation
      await _firestore.collection('orders').doc(orderId).update({
        'paymentStatus': 'awaiting_confirmation',
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // Verifikasi update berhasil dengan get document
      DocumentSnapshot paymentDoc =
          await _firestore.collection('payments').doc('payment_$orderId').get();
      print('Payment document after update: ${paymentDoc.data()}');
    } catch (e) {
      print('Error confirming manual transfer: $e');
      rethrow;
    }
  }

  // Konfirmasi pembayaran COD oleh user
  Future<void> confirmCodPayment(String orderId) async {
    try {
      // Update dokumen payment
      await _firestore.collection('payments').doc('payment_$orderId').update({
        'status': 'confirmed_by_user',
        'confirmedAt': FieldValue.serverTimestamp(),
      });

      // Update status pesanan
      await _firestore.collection('orders').doc(orderId).update({
        'paymentStatus':
            'awaiting_confirmation', // Dibayar, menunggu konfirmasi admin
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error confirming COD payment: $e');
      rethrow;
    }
  }

  // Dapatkan daftar pesanan untuk pengguna saat ini
  Stream<QuerySnapshot> getUserOrders() {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('User tidak terautentikasi');
    }

    return _firestore
        .collection('orders')
        .where('userId', isEqualTo: currentUser.uid)
        .orderBy('orderTime', descending: true)
        .snapshots();
  }

  // Dapatkan detail pesanan berdasarkan ID
  Stream<DocumentSnapshot> getOrderDetails(String orderId) {
    return _firestore.collection('orders').doc(orderId).snapshots();
  }

  // Batalkan pesanan
  Future<void> cancelOrder(String orderId, String reason) async {
    try {
      await _firestore.collection('orders').doc(orderId).update({
        'status': 'cancelled',
        'cancelReason': reason,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // Juga update status pembayaran jika ada
      try {
        await _firestore.collection('payments').doc('payment_$orderId').update({
          'status': 'cancelled',
          'cancelledAt': FieldValue.serverTimestamp(),
          'cancelReason': reason,
        });
      } catch (e) {
        // Ignore if payment document doesn't exist
        print(
            'Warning: Could not update payment status for order $orderId: $e');
      }
    } catch (e) {
      print('Error cancelling order: $e');
      rethrow;
    }
  }

  // Mendapatkan status pesanan
  Future<String?> getOrderStatus(String orderId) async {
    try {
      DocumentSnapshot doc =
          await _firestore.collection('orders').doc(orderId).get();
      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return data['status'] as String?;
      }
      return null;
    } catch (e) {
      print('Error getting order status: $e');
      rethrow;
    }
  }
}
