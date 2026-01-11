import 'package:cloud_firestore/cloud_firestore.dart';

class Badge {
  final String id;
  final String name;
  final String emoji;
  final String description;
  final DateTime unlockedAt;

  const Badge({
    required this.id,
    required this.name,
    required this.emoji,
    required this.description,
    required this.unlockedAt,
  });

  factory Badge.fromMap(Map<String, dynamic> map) {
    return Badge(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      emoji: map['emoji'] as String? ?? '🏆',
      description: map['description'] as String? ?? '',
      unlockedAt: (map['unlockedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'emoji': emoji,
      'description': description,
      'unlockedAt': Timestamp.fromDate(unlockedAt),
    };
  }
}

/// Badge definitions - all available badges in the system
class BadgeDefinitions {
  static const Map<String, Map<String, String>> all = {
    'first_steps': {
      'name': 'First Steps',
      'emoji': '👣',
      'description': 'Take your first dose',
    },
    'perfect_day': {
      'name': 'Perfect Day',
      'emoji': '⭐',
      'description': 'Complete 100% of medicines in a day',
    },
    'three_day_warrior': {
      'name': '3-Day Warrior',
      'emoji': '🔥',
      'description': 'Reach a 3-day streak',
    },
    'week_warrior': {
      'name': 'Week Warrior',
      'emoji': '🌟',
      'description': 'Reach a 7-day streak',
    },
    'profile_star': {
      'name': 'Profile Star',
      'emoji': '💫',
      'description': 'Complete your profile with photo',
    },
    'month_master': {
      'name': 'Month Master',
      'emoji': '👑',
      'description': 'Reach a 30-day streak',
    },
    'century': {
      'name': 'Century',
      'emoji': '💯',
      'description': 'Earn 100 points',
    },
    'punctual_pro': {
      'name': 'Punctual Pro',
      'emoji': '⏰',
      'description': '10 consecutive on-time doses',
    },
  };

  static String getName(String badgeId) =>
      all[badgeId]?['name'] ?? 'Unknown Badge';
  static String getEmoji(String badgeId) => all[badgeId]?['emoji'] ?? '🏆';
  static String getDescription(String badgeId) =>
      all[badgeId]?['description'] ?? '';

  /// Get a Badge object from badge ID
  static Badge? getBadge(String badgeId) {
    final badgeData = all[badgeId];
    if (badgeData == null) return null;

    return Badge(
      id: badgeId,
      name: badgeData['name'] ?? 'Unknown Badge',
      emoji: badgeData['emoji'] ?? '🏆',
      description: badgeData['description'] ?? '',
      unlockedAt: DateTime.now(),
    );
  }
}
