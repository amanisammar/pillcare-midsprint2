import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

Future<void> main() async {
  await Firebase.initializeApp();

  final auth = FirebaseAuth.instance;
  final firestore = FirebaseFirestore.instance;

  const testEmail = 'demo@pillcare.app';
  const testPassword = 'Demo12345!';
  const displayName = 'Demo User';

  try {
    print('🌱 Creating test account...');

    // Try to sign out first if needed
    try {
      await auth.signOut();
    } catch (_) {}

    // Create user
    final userCred = await auth.createUserWithEmailAndPassword(
      email: testEmail,
      password: testPassword,
    );

    final uid = userCred.user!.uid;
    print('✅ Auth user created: $uid');

    // Update profile
    await userCred.user!.updateDisplayName(displayName);
    print('✅ Display name set');

    // Create comprehensive user document
    await firestore.collection('users').doc(uid).set({
      'uid': uid,
      'email': testEmail,
      'displayName': displayName,
      'photoUrl': null,
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
    });
    print('✅ User document created');

    // Create medicines
    await firestore
        .collection('users')
        .doc(uid)
        .collection('medicines')
        .doc('med_0')
        .set({
          'name': 'Aspirin',
          'dosage': '500mg',
          'description': 'Pain reliever',
          'times': ['08:00', '20:00'],
          'createdAt': Timestamp.now(),
          'active': true,
        });

    await firestore
        .collection('users')
        .doc(uid)
        .collection('medicines')
        .doc('med_1')
        .set({
          'name': 'Vitamin D',
          'dosage': '1000IU',
          'description': 'Bone health',
          'times': ['09:00'],
          'createdAt': Timestamp.now(),
          'active': true,
        });

    await firestore
        .collection('users')
        .doc(uid)
        .collection('medicines')
        .doc('med_2')
        .set({
          'name': 'Metformin',
          'dosage': '500mg',
          'description': 'Diabetes management',
          'times': ['07:00', '13:00', '19:00'],
          'createdAt': Timestamp.now(),
          'active': true,
        });
    print('✅ Created 3 medicines');

    // Create dose history
    int doseCount = 0;
    for (int i = 0; i < 15; i++) {
      final date = DateTime.now().subtract(Duration(days: i));
      final dateKey = _buildDateKey(date);
      final isOnTime = (i < 12);
      final minuteOffset = isOnTime ? 5 : 45;

      for (int j = 0; j < 2; j++) {
        await firestore.collection('users').doc(uid).collection('doseLogs').add(
          {
            'dateKey': dateKey,
            'timeKey':
                '${8 + (j * 12)}:${minuteOffset.toString().padLeft(2, '0')}',
            'medicineId': 'med_${j % 3}',
            'medicineName': ['Aspirin', 'Vitamin D', 'Metformin'][j % 3],
            'dosage': ['500mg', '1000IU', '500mg'][j % 3],
            'takenAt': Timestamp.fromDate(
              date.add(Duration(hours: 8 + (j * 12), minutes: minuteOffset)),
            ),
            'scheduledAt': Timestamp.fromDate(
              date.add(Duration(hours: 8 + (j * 12))),
            ),
            'onTime': isOnTime,
            'notes': i < 5 ? 'Great progress!' : null,
          },
        );
        doseCount++;
      }

      // Create day summary
      await firestore
          .collection('users')
          .doc(uid)
          .collection('daySummaries')
          .doc(dateKey)
          .set({
            'date': Timestamp.fromDate(date),
            'dateKey': dateKey,
            'scheduledCount': 2,
            'takenCount': 2,
            'onTimeCount': isOnTime ? 2 : 1,
            'adherencePercent': isOnTime ? 100 : 50,
            'pointsEarned': isOnTime ? 30 : 15,
          });
    }
    print('✅ Created $doseCount dose entries with day summaries');

    print('\n🎉 Test account ready to use!');
    print('📧 Email: $testEmail');
    print('🔑 Password: $testPassword');
    print('👤 Name: $displayName');
    print('\n📊 Account has:');
    print('   • 450 points (Level 3)');
    print('   • 15-day streak');
    print(
      '   • 5 badges: First Steps, Perfect Day, 3-Day Warrior, Week Warrior, Century',
    );
    print('   • 3 medicines: Aspirin, Vitamin D, Metformin');
    print('   • 15 days of dose history');
    print('   • 100% adherence for last 12 days');
  } catch (e) {
    print('❌ Error: $e');
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
