import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/badge.dart';
import 'history_service.dart';

class GamificationResult {
  final int pointsAwarded;
  final int streakDays;
  final bool streakMilestone;
  final bool fullDayAwarded;
  final bool onTime;
  final double? fullDayAdherence;
  final String? newBadgeEarned; // Newly earned badge ID, if any
  final bool leveledUp; // Whether user leveled up
  final int? newLevel; // New level if leveled up

  const GamificationResult({
    required this.pointsAwarded,
    required this.streakDays,
    required this.streakMilestone,
    required this.fullDayAwarded,
    required this.onTime,
    this.fullDayAdherence,
    this.newBadgeEarned,
    this.leveledUp = false,
    this.newLevel,
  });
}

class GamificationService {
  GamificationService({
    FirebaseFirestore? firestore,
    HistoryService? historyService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _historyService = historyService ?? HistoryService();

  final FirebaseFirestore _firestore;
  final HistoryService _historyService;

  static const _streakMilestones = {3, 7, 14, 21, 30, 60, 90};

  String _buildDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  DateTime _parseDateKey(String dateKey) {
    final parts = dateKey.split('-');
    if (parts.length != 3) return DateTime.now();
    return DateTime(
      int.tryParse(parts[0]) ?? DateTime.now().year,
      int.tryParse(parts[1]) ?? 1,
      int.tryParse(parts[2]) ?? 1,
    );
  }

  Future<GamificationResult> awardDose({
    required String uid,
    required DateTime scheduledAt,
    required DateTime takenAt,
  }) async {
    final dateKey = _buildDateKey(scheduledAt);
    final onTime = takenAt.isBefore(
      scheduledAt.add(const Duration(minutes: 30)),
    );
    final basePoints = onTime ? 10 : 5;

    try {
      final userRef = _firestore.collection('users').doc(uid);
      final userSnap = await userRef.get();
      final data = userSnap.data() ?? {};

      final currentPoints = (data['points'] as num?)?.toInt() ?? 0;
      final currentStreak = (data['streakDays'] as num?)?.toInt() ?? 0;
      final longestStreak = (data['longestStreak'] as num?)?.toInt() ?? 0;
      final lastStreakDate = data['lastStreakDate'] as String?;
      final awardedFullDaysRaw = (data['awardedFullDays'] as List?) ?? [];
      final awardedFullDays = awardedFullDaysRaw.cast<String>().toSet();

      // Compute streak with zero-meds grace.
      final todayDate = DateTime(
        scheduledAt.year,
        scheduledAt.month,
        scheduledAt.day,
      );
      int updatedStreak = currentStreak;

      if (lastStreakDate == null) {
        updatedStreak = 1;
      } else {
        final lastDate = _parseDateKey(lastStreakDate);
        final gap = todayDate
            .difference(DateTime(lastDate.year, lastDate.month, lastDate.day))
            .inDays;

        if (gap == 0) {
          // already counted today
        } else if (gap == 1) {
          updatedStreak = currentStreak + 1;
        } else if (gap > 1) {
          // Check if any missing day had scheduled doses; if none, keep streak, else reset.
          bool broke = false;
          for (int i = 1; i < gap; i++) {
            final checkDate = lastDate.add(Duration(days: i));
            final summary = await _historyService.getDaySummary(uid, checkDate);
            if (summary.scheduledCount > 0 &&
                summary.takenCount < summary.scheduledCount) {
              broke = true;
              break;
            }
          }
          updatedStreak = broke ? 1 : currentStreak + 1;
        }
      }

      final newLongest = updatedStreak > longestStreak
          ? updatedStreak
          : longestStreak;
      bool streakMilestone = _streakMilestones.contains(updatedStreak);

      // Full day adherence award (after logging dose, recompute day summary)
      final daySummary = await _historyService.getDaySummary(uid, todayDate);
      bool fullDayAwarded = false;
      int extraPoints = 0;
      if (daySummary.scheduledCount > 0 &&
          daySummary.takenCount == daySummary.scheduledCount &&
          !awardedFullDays.contains(dateKey)) {
        fullDayAwarded = true;
        extraPoints += 20;
        awardedFullDays.add(dateKey);
      }

      final totalAward = basePoints + extraPoints;
      final newPoints = currentPoints + totalAward;

      // Check for level up (200 points per level)
      final oldLevel = (currentPoints ~/ 200) + 1;
      final newLevel = (newPoints ~/ 200) + 1;
      final leveledUp = newLevel > oldLevel;

      await userRef.set({
        'points': newPoints,
        'streakDays': updatedStreak,
        'longestStreak': newLongest,
        'lastStreakDate': dateKey,
        'awardedFullDays': awardedFullDays.toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Check for badge unlocks and get newly earned badge
      final newBadgeEarned = await _checkAndAwardBadges(
        uid,
        newPoints,
        updatedStreak,
        fullDayAwarded,
      );

      return GamificationResult(
        pointsAwarded: totalAward,
        streakDays: updatedStreak,
        streakMilestone: streakMilestone,
        fullDayAwarded: fullDayAwarded,
        onTime: onTime,
        fullDayAdherence: daySummary.adherencePercent,
        newBadgeEarned: newBadgeEarned,
        leveledUp: leveledUp,
        newLevel: leveledUp ? newLevel : null,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Gamification award error: $e');
      }
      return const GamificationResult(
        pointsAwarded: 0,
        streakDays: 0,
        streakMilestone: false,
        fullDayAwarded: false,
        onTime: false,
        newBadgeEarned: null,
        leveledUp: false,
        newLevel: null,
      );
    }
  }

  Future<void> awardRefill(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).set({
        'points': FieldValue.increment(15),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Gamification refill award error: $e');
      }
    }
  }

  Future<void> awardProfileCompletion(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).set({
        'points': FieldValue.increment(10),
        'profileCompleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Award Profile Star badge
      await _awardBadgeIfNotOwned(uid, 'profile_star');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Gamification profile completion error: $e');
      }
    }
  }

  /// Check and award badges based on user progress, return newly earned badge ID
  Future<String?> _checkAndAwardBadges(
    String uid,
    int currentPoints,
    int currentStreak,
    bool fullDayAwarded,
  ) async {
    try {
      // First Steps - earn any points
      if (currentPoints > 0) {
        if (await _awardBadgeIfNotOwned(uid, 'first_steps')) {
          return 'first_steps';
        }
      }

      // 3-Day Warrior
      if (currentStreak >= 3) {
        if (await _awardBadgeIfNotOwned(uid, 'three_day_warrior')) {
          return 'three_day_warrior';
        }
      }

      // Week Warrior
      if (currentStreak >= 7) {
        if (await _awardBadgeIfNotOwned(uid, 'week_warrior')) {
          return 'week_warrior';
        }
      }

      // Month Master
      if (currentStreak >= 30) {
        if (await _awardBadgeIfNotOwned(uid, 'month_master')) {
          return 'month_master';
        }
      }

      // Century
      if (currentPoints >= 100) {
        if (await _awardBadgeIfNotOwned(uid, 'century')) {
          return 'century';
        }
      }

      // Perfect Day
      if (fullDayAwarded) {
        if (await _awardBadgeIfNotOwned(uid, 'perfect_day')) {
          return 'perfect_day';
        }
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Badge check error: $e');
      }
      return null;
    }
  }

  /// Award a badge if user doesn't already own it, returns true if newly awarded
  Future<bool> _awardBadgeIfNotOwned(String uid, String badgeId) async {
    try {
      final userRef = _firestore.collection('users').doc(uid);
      final userSnap = await userRef.get();
      final data = userSnap.data() ?? {};
      final badgesRaw = (data['badges'] as List?) ?? [];
      final badges = badgesRaw.cast<String>();

      // Check if badge already owned
      if (badges.contains(badgeId)) {
        return false; // Already owned, not newly awarded
      }

      // Add new badge
      await userRef.update({
        'badges': FieldValue.arrayUnion([badgeId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) {
        debugPrint('Badge awarded: $badgeId');
      }

      return true; // Newly awarded
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Award badge error: $e');
      }
      return false; // Error, not awarded
    }
  }

  /// Get user's earned badges
  Future<List<Badge>> getUserBadges(String uid) async {
    try {
      final userRef = _firestore.collection('users').doc(uid);
      final userSnap = await userRef.get();
      final data = userSnap.data() ?? {};
      final badgesRaw = (data['badges'] as List?) ?? [];
      final badgeIds = badgesRaw.cast<String>();

      final badges = <Badge>[];
      for (final badgeId in badgeIds) {
        badges.add(
          Badge(
            id: badgeId,
            name: BadgeDefinitions.getName(badgeId),
            emoji: BadgeDefinitions.getEmoji(badgeId),
            description: BadgeDefinitions.getDescription(badgeId),
            unlockedAt:
                DateTime.now(), // Would need timestamp if stored separately
          ),
        );
      }

      return badges;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Get badges error: $e');
      }
      return [];
    }
  }
}
