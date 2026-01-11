import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

Future<void> main() async {
  await Firebase.initializeApp();

  final firestore = FirebaseFirestore.instance;

  // Create test account with everything populated
  const testUid = 'test_user_demo_001';
  const testEmail = 'testdemo@pillcare.app';
  const displayName = 'Demo User';

  print('🌱 Creating comprehensive test account...');

  // 1. Create user document with all features
  await firestore.collection('users').doc(testUid).set({
    'email': testEmail,
    'displayName': displayName,
    'photoUrl': null,
    'points': 450, // Level 3
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
  });

  print('✅ User created with:');
  print('   - 450 points (Level 3)');
  print('   - 15-day streak');
  print('   - 5 badges unlocked');

  // 2. Create medicines batch
  final medicinesBatch = firestore.batch();
  const medicines = [
    {
      'name': 'Aspirin',
      'dosage': '500mg',
      'times': ['08:00', '20:00'],
      'description': 'Pain reliever',
    },
    {
      'name': 'Vitamin D',
      'dosage': '1000IU',
      'times': ['09:00'],
      'description': 'Bone health',
    },
    {
      'name': 'Metformin',
      'dosage': '500mg',
      'times': ['07:00', '13:00', '19:00'],
      'description': 'Diabetes management',
    },
  ];

  int medicineCount = 0;
  for (final med in medicines) {
    final docRef = firestore
        .collection('users')
        .doc(testUid)
        .collection('medicines')
        .doc();

    medicinesBatch.set(docRef, {
      'name': med['name'],
      'dosage': med['dosage'],
      'description': med['description'],
      'times': med['times'],
      'createdAt': Timestamp.now(),
      'active': true,
    });
    medicineCount++;
  }
  await medicinesBatch.commit();
  print('✅ Created $medicineCount medicines');

  // 3. Create dose history for past 15 days
  final historyBatch = firestore.batch();
  int doseCount = 0;

  for (int i = 0; i < 15; i++) {
    final date = DateTime.now().subtract(Duration(days: i));
    final dateKey = _buildDateKey(date);

    // Create dose logs
    int dosesPerDay = 2;
    for (int j = 0; j < dosesPerDay; j++) {
      final docRef = firestore
          .collection('users')
          .doc(testUid)
          .collection('doseLogs')
          .doc();

      final isOnTime = (i < 12); // Last 12 days on time
      final minuteOffset = isOnTime ? 5 : 45;

      historyBatch.set(docRef, {
        'dateKey': dateKey,
        'timeKey': '${8 + (j * 12)}:${minuteOffset.toString().padLeft(2, '0')}',
        'medicineId': 'med_${j % 3}',
        'medicineName': medicines[j % 3]['name'],
        'dosage': medicines[j % 3]['dosage'],
        'takenAt': Timestamp.fromDate(
          date.add(Duration(hours: 8 + (j * 12), minutes: minuteOffset)),
        ),
        'scheduledAt': Timestamp.fromDate(
          date.add(Duration(hours: 8 + (j * 12))),
        ),
        'onTime': isOnTime,
        'notes': i < 5 ? 'Great progress!' : null,
      });
      doseCount++;
    }
  }
  await historyBatch.commit();
  print('✅ Created $doseCount dose history entries for past 15 days');

  // 4. Create day summaries
  final summaryBatch = firestore.batch();
  for (int i = 0; i < 15; i++) {
    final date = DateTime.now().subtract(Duration(days: i));
    final dateKey = _buildDateKey(date);

    final docRef = firestore
        .collection('users')
        .doc(testUid)
        .collection('daySummaries')
        .doc(dateKey);

    summaryBatch.set(docRef, {
      'date': Timestamp.fromDate(date),
      'dateKey': dateKey,
      'scheduledCount': 2,
      'takenCount': 2,
      'onTimeCount': (i < 12) ? 2 : 1,
      'adherencePercent': (i < 12) ? 100 : 50,
      'pointsEarned': (i < 12) ? 30 : 15,
    });
  }
  await summaryBatch.commit();
  print('✅ Created day summaries for 15 days');

  print('\n🎉 Test account ready!');
  print('📧 Email: $testEmail');
  print('🎯 Points: 450 (Level 3)');
  print('🔥 Streak: 15 days');
  print('🏆 Badges: 5 unlocked');
  print('💊 Medicines: 3 active');
  print('\nThe test account is fully populated with gamification data!');

  print('\nThe test account is fully populated with gamification data!');
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
