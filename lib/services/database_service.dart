import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> saveScan(String label, double confidence) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await _db.collection('users').doc(user.uid).collection('scans').add({
      'label': label,
      'confidence': confidence,
      'timestamp': FieldValue.serverTimestamp(),
    });

    final snapshot = await _db
        .collection('users')
        .doc(user.uid)
        .collection('scans')
        .get();
    int actualTotal = snapshot.docs.length;

    await _db.collection('users').doc(user.uid).set({
      'email': user.email,
      'totalScans': actualTotal,
      'lastActive': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<QuerySnapshot> get scanHistory {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return _db
        .collection('users')
        .doc(uid)
        .collection('scans')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }
}