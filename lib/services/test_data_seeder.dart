import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Seeds deterministic test data for whitelisted test accounts.
class TestDataSeeder {
  static const _seedVersion = 2;
  static const _allowedEmails = {
    'testamani@pillcare.app',
    'testamani2@pillcare.app',
    'amani.sammar.3@gmail.com',
  };

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> ensureSeeded(User user) async {
    final email = user.email;
    if (email == null || !_allowedEmails.contains(email.toLowerCase())) {
      return;
    }

    final docRef = _firestore.collection('users').doc(user.uid);
    final docSnap = await docRef.get();
    final currentVersion = docSnap.data()?['seedVersion'] as int?;
    if (currentVersion == _seedVersion) {
      return; // already seeded
    }

    await _seedUser(user, docRef);
  }

  Future<void> _seedUser(
    User user,
    DocumentReference<Map<String, dynamic>> docRef,
  ) async {
    // Clear existing subcollections to avoid duplicates
    await _clearCollection(docRef.collection('medicines'));
    await _clearCollection(docRef.collection('doseLogs'));
    await _clearCollection(docRef.collection('daySummaries'));

    // User document
    await docRef.set({
      'uid': user.uid,
      'email': user.email,
      'name': user.displayName ?? 'Test User',
      'displayName': user.displayName ?? 'Test User',
      'photoUrl': null,
      'role': 'patient',
      'roles': {'patient': true, 'family_member': false},
      'points': 450,
      'streakDays': 15,
      'longestStreak': 15,
      'shareWithFamily': true,
      'timezone': 'UTC',
      'createdAt': Timestamp.fromDate(
        DateTime.now().subtract(const Duration(days: 30)),
      ),
      'badges': [
        'first_steps',
        'perfect_day',
        'three_day_warrior',
        'week_warrior',
        'century',
      ],
      'updatedAt': Timestamp.now(),
      'lastStreakDate': _buildDateKey(DateTime.now()),
      'awardedFullDays': _getAwardedDays(),
      'seedVersion': _seedVersion,
    }, SetOptions(merge: true));

    // Medicines
    await docRef.collection('medicines').doc('med_0').set({
      'name': 'Aspirin',
      'dosage': '500mg',
      'description': 'Pain reliever',
      'timesOfDay': ['08:00', '20:00'],
      'days': [1, 2, 3, 4, 5, 6, 7], // All days
      'createdAt': Timestamp.now(),
      'active': true,
    });

    await docRef.collection('medicines').doc('med_1').set({
      'name': 'Vitamin D',
      'dosage': '1000IU',
      'description': 'Bone health',
      'timesOfDay': ['09:00'],
      'days': [1, 2, 3, 4, 5, 6, 7], // All days
      'createdAt': Timestamp.now(),
      'active': true,
    });

    await docRef.collection('medicines').doc('med_2').set({
      'name': 'Metformin',
      'dosage': '500mg',
      'description': 'Diabetes management',
      'timesOfDay': ['07:00', '13:00', '19:00'],
      'days': [1, 2, 3, 4, 5, 6, 7], // All days
      'createdAt': Timestamp.now(),
      'active': true,
    });

    // Dose history + day summaries - create realistic dose logs matching medicine times
    for (int i = 0; i < 15; i++) {
      final date = DateTime.now().subtract(Duration(days: i));
      final dateKey = _buildDateKey(date);
      final isOnTime = (i < 12);

      // Create dose logs for Aspirin (08:00, 20:00)
      final aspirinTimes = ['08:00', '20:00'];
      for (final time in aspirinTimes) {
        final parts = time.split(':');
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        final minuteOffset = isOnTime ? 5 : 45;

        await docRef.collection('doseLogs').add({
          'medicineId': 'med_0',
          'medName': 'Aspirin',
          'dosage': '500mg',
          'dateKey': dateKey,
          'timeKey': time,
          'scheduledAt': Timestamp.fromDate(
            DateTime(date.year, date.month, date.day, hour, minute),
          ),
          'takenAt': Timestamp.fromDate(
            DateTime(
              date.year,
              date.month,
              date.day,
              hour,
              minute + minuteOffset,
            ),
          ),
          'status': 'taken',
          'onTime': isOnTime,
          'notes': i < 5 ? 'Great progress!' : null,
          'createdAt': Timestamp.now(),
        });
      }

      // Create dose log for Vitamin D (09:00)
      final vitDHour = 9;
      final vitDMinute = 0;
      final vitDOffset = isOnTime ? 5 : 45;
      await docRef.collection('doseLogs').add({
        'medicineId': 'med_1',
        'medName': 'Vitamin D',
        'dosage': '1000IU',
        'dateKey': dateKey,
        'timeKey': '09:00',
        'scheduledAt': Timestamp.fromDate(
          DateTime(date.year, date.month, date.day, vitDHour, vitDMinute),
        ),
        'takenAt': Timestamp.fromDate(
          DateTime(
            date.year,
            date.month,
            date.day,
            vitDHour,
            vitDMinute + vitDOffset,
          ),
        ),
        'status': 'taken',
        'onTime': isOnTime,
        'createdAt': Timestamp.now(),
      });

      // Day summary reflects 3 taken doses per day (2 Aspirin + 1 Vitamin D)
      await docRef.collection('daySummaries').doc(dateKey).set({
        'date': Timestamp.fromDate(date),
        'dateKey': dateKey,
        'scheduledCount': 3,
        'takenCount': 3,
        'onTimeCount': isOnTime ? 3 : 2,
        'adherencePercent': 100.0,
        'pointsEarned': isOnTime ? 30 : 20,
      });
    }
  }

  Future<void> _clearCollection(
    CollectionReference<Map<String, dynamic>> ref,
  ) async {
    final snap = await ref.get();
    for (final doc in snap.docs) {
      await doc.reference.delete();
    }
  }

  String _buildDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  List<String> _getAwardedDays() {
    final days = <String>[];
    for (int i = 0; i < 10; i++) {
      final date = DateTime.now().subtract(Duration(days: i));
      days.add(_buildDateKey(date));
    }
    return days;
  }
}
