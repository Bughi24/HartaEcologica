// lib/services/badge_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/badge_definitions.dart';

class BadgeService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static Future<List<BadgeDefinition>> checkAndAwardBadges() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return [];

    final docRef = _db.collection('users').doc(uid);
    final snapshot = await docRef.get();
    final data = snapshot.data() ?? {};

    final int currentPoints = data['totalScans'] != null
        ? (data['totalScans'] as int) * 10
        : 0;

    final List<String> existingBadgeIds =
        List<String>.from(data['badgeIds'] ?? []);

    final earned = BadgeDefinitions.earnedFor(currentPoints);
    final newBadges = earned
        .where((b) => !existingBadgeIds.contains(b.id))
        .toList();

    if (newBadges.isNotEmpty) {
      final updatedIds = [
        ...existingBadgeIds,
        ...newBadges.map((b) => b.id),
      ];

      await docRef.update({
        'badgeIds': updatedIds,
        'badges': updatedIds.map((id) {
          final def = BadgeDefinitions.all.firstWhere(
            (b) => b.id == id,
            orElse: () => BadgeDefinitions.all.first,
          );
          return '${def.emoji} ${def.title}';
        }).toList(),
      });
    }

    return newBadges;
  }
}