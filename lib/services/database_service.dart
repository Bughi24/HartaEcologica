import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Salvează o scanare nouă
  Future<void> saveScan(String label, double confidence) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // 1. Adăugăm scanarea în sub-colecția 'scans'
    await _db.collection('users').doc(user.uid).collection('scans').add({
      'label': label,
      'confidence': confidence,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // 2. RECUPERĂM numărul real de documente din istoric
    // Asta garantează că dacă ai 7 documente, scriem cifra 7, nu incrementăm greșit
    final snapshot = await _db.collection('users').doc(user.uid).collection('scans').get();
    int actualTotal = snapshot.docs.length;

    // 3. Actualizăm documentul principal cu cifra REALĂ și Email-ul
    await _db.collection('users').doc(user.uid).set({
      'email': user.email,
      'totalScans': actualTotal, // Scriem valoarea absolută
      'lastActive': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Stream pentru istoric (rămâne la fel)
  Stream<QuerySnapshot> get scanHistory {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return _db.collection('users')
        .doc(uid)
        .collection('scans')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }
}