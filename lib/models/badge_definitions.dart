// lib/models/badge_definitions.dart

class BadgeDefinition {
  final String id;
  final String title;
  final String emoji;
  final String description;
  final int pointsRequired;

  const BadgeDefinition({
    required this.id,
    required this.title,
    required this.emoji,
    required this.description,
    required this.pointsRequired,
  });
}

class BadgeDefinitions {
  static const List<BadgeDefinition> all = [
    BadgeDefinition(
      id: 'first_scan',
      title: 'Prima Scanare',
      emoji: '🌱',
      description: 'Ai făcut prima ta scanare!',
      pointsRequired: 10,
    ),
    BadgeDefinition(
      id: 'eco_beginner',
      title: 'Eco Începător',
      emoji: '♻️',
      description: 'Ai acumulat 50 de puncte eco.',
      pointsRequired: 50,
    ),
    BadgeDefinition(
      id: 'green_warrior',
      title: 'Războinic Verde',
      emoji: '🌿',
      description: 'Ai acumulat 100 de puncte eco.',
      pointsRequired: 100,
    ),
    BadgeDefinition(
      id: 'eco_enthusiast',
      title: 'Eco Entuziast',
      emoji: '🌍',
      description: '250 de puncte acumulate!',
      pointsRequired: 250,
    ),
    BadgeDefinition(
      id: 'recycle_hero',
      title: 'Erou Reciclare',
      emoji: '🦸',
      description: '500 de puncte - ești un erou!',
      pointsRequired: 500,
    ),
    BadgeDefinition(
      id: 'eco_champion',
      title: 'Campion Eco',
      emoji: '🏆',
      description: '1000 de puncte - campion absolut!',
      pointsRequired: 1000,
    ),
    BadgeDefinition(
      id: 'planet_guardian',
      title: 'Gardianul Planetei',
      emoji: '🌟',
      description: '2000 de puncte - legendă!',
      pointsRequired: 2000,
    ),
  ];

  /// Returnează lista de badge-uri câștigate pentru un număr de puncte dat
  static List<BadgeDefinition> earnedFor(int points) {
    return all.where((b) => points >= b.pointsRequired).toList();
  }

  /// Returnează următorul badge care nu a fost câștigat încă
  static BadgeDefinition? nextBadgeFor(int points) {
    try {
      return all.firstWhere((b) => points < b.pointsRequired);
    } catch (_) {
      return null; // Toate badge-urile au fost câștigate
    }
  }
}