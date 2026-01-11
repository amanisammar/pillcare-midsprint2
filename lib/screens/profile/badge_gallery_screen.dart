import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/badge.dart' as app_badge;

class BadgeGalleryScreen extends StatelessWidget {
  const BadgeGalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please sign in to view badges')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Badge Gallery'),
        backgroundColor: const Color(0xFF23C3AE),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('No data available'));
          }

          final userData = snapshot.data!.data() as Map<String, dynamic>;
          final earnedBadges = ((userData['badges'] as List?) ?? [])
              .cast<String>();
          final points = (userData['points'] as num?)?.toInt() ?? 0;
          final streakDays = (userData['streakDays'] as num?)?.toInt() ?? 0;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header stats
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF23C3AE), Color(0xFF1A9B8A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem(
                        '${earnedBadges.length}/${app_badge.BadgeDefinitions.all.length}',
                        'Badges Earned',
                      ),
                      Container(width: 1, height: 40, color: Colors.white30),
                      _buildStatItem('$points', 'Total Points'),
                      Container(width: 1, height: 40, color: Colors.white30),
                      _buildStatItem('$streakDays', 'Day Streak'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Earned badges section
                if (earnedBadges.isNotEmpty) ...[
                  const Text(
                    'Unlocked Badges',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF23C3AE),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.85,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                    itemCount: earnedBadges.length,
                    itemBuilder: (context, index) {
                      final badgeId = earnedBadges[index];
                      final badge = app_badge.BadgeDefinitions.getBadge(
                        badgeId,
                      );
                      if (badge == null) return const SizedBox.shrink();
                      return _buildBadgeCard(context, badge, true);
                    },
                  ),
                  const SizedBox(height: 24),
                ],

                // Locked badges section
                const Text(
                  'Locked Badges',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.85,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount:
                      app_badge.BadgeDefinitions.all.length -
                      earnedBadges.length,
                  itemBuilder: (context, index) {
                    final allBadgeIds = app_badge.BadgeDefinitions.all.keys
                        .toList();
                    final lockedBadgeIds = allBadgeIds
                        .where((id) => !earnedBadges.contains(id))
                        .toList();

                    if (index >= lockedBadgeIds.length) {
                      return const SizedBox.shrink();
                    }

                    final badgeId = lockedBadgeIds[index];
                    final badge = app_badge.BadgeDefinitions.getBadge(badgeId);
                    if (badge == null) return const SizedBox.shrink();

                    return _buildBadgeCard(
                      context,
                      badge,
                      false,
                      points: points,
                      streakDays: streakDays,
                    );
                  },
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.white70),
        ),
      ],
    );
  }

  Widget _buildBadgeCard(
    BuildContext context,
    app_badge.Badge badge,
    bool isUnlocked, {
    int points = 0,
    int streakDays = 0,
  }) {
    String? progressText;
    if (!isUnlocked) {
      // Calculate progress for locked badges
      switch (badge.id) {
        case 'first_steps':
          progressText = null; // This should already be earned
          break;
        case 'three_day_warrior':
          if (streakDays < 3) {
            progressText = '$streakDays / 3 days';
          }
          break;
        case 'week_warrior':
          if (streakDays < 7) {
            progressText = '$streakDays / 7 days';
          }
          break;
        case 'month_master':
          if (streakDays < 30) {
            progressText = '$streakDays / 30 days';
          }
          break;
        case 'century':
          if (points < 100) {
            progressText = '$points / 100 points';
          }
          break;
      }
    }

    return GestureDetector(
      onTap: () => _showBadgeDetails(context, badge, isUnlocked, progressText),
      child: Container(
        decoration: BoxDecoration(
          color: isUnlocked ? Colors.white : Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isUnlocked ? const Color(0xFF23C3AE) : Colors.grey[400]!,
            width: 2,
          ),
          boxShadow: isUnlocked
              ? [
                  BoxShadow(
                    color: const Color(0xFF23C3AE).withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Badge emoji
            Text(
              badge.emoji,
              style: TextStyle(
                fontSize: 64,
                color: isUnlocked ? null : Colors.grey,
              ),
            ),
            const SizedBox(height: 12),

            // Badge name
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                badge.name,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isUnlocked
                      ? const Color(0xFF23C3AE)
                      : Colors.grey[600],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Lock icon or progress
            if (!isUnlocked) ...[
              if (progressText != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    progressText,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange[800],
                    ),
                  ),
                )
              else
                Icon(Icons.lock, color: Colors.grey[400], size: 20),
            ] else
              Icon(
                Icons.check_circle,
                color: const Color(0xFF23C3AE),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  void _showBadgeDetails(
    BuildContext context,
    app_badge.Badge badge,
    bool isUnlocked,
    String? progressText,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 24),
            Text(badge.emoji, style: const TextStyle(fontSize: 80)),
            const SizedBox(height: 16),
            Text(
              badge.name,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF23C3AE),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                badge.description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (!isUnlocked && progressText != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Progress: $progressText',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange[800],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: isUnlocked
                    ? const Color(0xFF23C3AE).withOpacity(0.1)
                    : Colors.grey[200],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isUnlocked ? Icons.check_circle : Icons.lock,
                    color: isUnlocked ? const Color(0xFF23C3AE) : Colors.grey,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isUnlocked ? 'Unlocked!' : 'Locked',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isUnlocked ? const Color(0xFF23C3AE) : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
