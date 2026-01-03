import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:confetti/confetti.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../services/dose_log_service.dart';
import '../services/gamification_service.dart';
import '../services/history_service.dart';
import '../widgets/medicine_card.dart';

class TodayMedicineTab extends StatefulWidget {
  final String role;
  final String? name;
  final String? userEmail;

  const TodayMedicineTab({
    super.key,
    required this.role,
    this.name,
    this.userEmail,
  });

  @override
  State<TodayMedicineTab> createState() => _TodayMedicineTabState();
}

class _TodayMedicineTabState extends State<TodayMedicineTab> {
  Timer? _timer;
  final _doseLogService = DoseLogService();
  final _gamificationService = GamificationService();
  final _historyService = HistoryService();
  final ConfettiController _confettiController =
      ConfettiController(duration: const Duration(seconds: 1));

  double? _weeklyAdherence;
  bool _loadingAdherence = false;

  @override
  void initState() {
    super.initState();
    // Update status every minute for real-time changes
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => setState(() {}));
    _loadWeeklyAdherence();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadWeeklyAdherence() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _loadingAdherence = true);
    try {
      final summaries = await _historyService.getLast7DaysSummary(user.uid);
      final totalScheduled = summaries.fold<int>(0, (acc, s) => acc + s.scheduledCount);
      final totalTaken = summaries.fold<int>(0, (acc, s) => acc + s.takenCount);
      final adherence = totalScheduled > 0 ? (totalTaken / totalScheduled) * 100 : 0.0;
      setState(() => _weeklyAdherence = adherence);
    } finally {
      if (mounted) {
        setState(() => _loadingAdherence = false);
      }
    }
  }

  Future<void> _markAsTaken(
    String docId,
    String timeKey,
    String todayDate,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('medicines')
          .doc(docId);

      final doc = await docRef.get();
      final data = doc.data();
      final medName = data?['name'] as String? ?? 'Unnamed';
      final dailyTaken = Map<String, dynamic>.from(data?['dailyTaken'] ?? {});
      final previousTakenList = List<String>.from(dailyTaken[todayDate] ?? []);

      if (previousTakenList.contains(timeKey)) return;

      final updatedDailyTaken = Map<String, dynamic>.from(dailyTaken);
      final updatedTakenList = List<String>.from(previousTakenList)..add(timeKey);
      updatedDailyTaken[todayDate] = updatedTakenList;
      await docRef.update({'dailyTaken': updatedDailyTaken});

      if (!mounted) {
        await _finalizeMarkAsTaken(
          uid: user.uid,
          docId: docId,
          medName: medName,
          todayDate: todayDate,
          timeKey: timeKey,
        );
        return;
      }

      bool undone = false;
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      final controller = messenger.showSnackBar(
        SnackBar(
          content: Text(context.loc.t('markedAsTaken')),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: context.loc.t('undo'),
            onPressed: () async {
              undone = true;
              final revertedDailyTaken = Map<String, dynamic>.from(dailyTaken);
              if (previousTakenList.isEmpty) {
                revertedDailyTaken.remove(todayDate);
              } else {
                revertedDailyTaken[todayDate] = previousTakenList;
              }
              try {
                await docRef.update({'dailyTaken': revertedDailyTaken});
              } catch (e) {
                debugPrint('Error undoing taken dose: $e');
              }
            },
          ),
        ),
      );

      final reason = await controller.closed;
      if (undone || reason == SnackBarClosedReason.action) {
        return;
      }

      await _finalizeMarkAsTaken(
        uid: user.uid,
        docId: docId,
        medName: medName,
        todayDate: todayDate,
        timeKey: timeKey,
      );
    } catch (e) {
      // Handle error, maybe show snackbar
      debugPrint('Error marking as taken: $e');
    }
  }

  DateTime _buildScheduledDateTime(String dateKey, String timeKey) {
    final parts = dateKey.split('-');
    final year = int.tryParse(parts[0]) ?? DateTime.now().year;
    final month = int.tryParse(parts[1]) ?? DateTime.now().month;
    final day = int.tryParse(parts[2]) ?? DateTime.now().day;
    final date = DateTime(year, month, day);

    final time = _parseTime(timeKey);
    if (time != null) {
      return DateTime(date.year, date.month, date.day, time.hour, time.minute);
    }
    return date;
  }

  Future<void> _finalizeMarkAsTaken({
    required String uid,
    required String docId,
    required String medName,
    required String todayDate,
    required String timeKey,
  }) async {
    await _doseLogService.logDoseTaken(
      uid: uid,
      medicineId: docId,
      medName: medName,
      dateKey: todayDate,
      timeKey: timeKey,
    );

    final scheduledAt = _buildScheduledDateTime(todayDate, timeKey);
    final result = await _gamificationService.awardDose(
      uid: uid,
      scheduledAt: scheduledAt,
      takenAt: DateTime.now(),
    );

    if (!mounted) return;

    final snack = SnackBar(
      content: Text(_buildRewardMessage(result, context, medName)),
      duration: const Duration(seconds: 2),
    );
    ScaffoldMessenger.of(context).showSnackBar(snack);

    if (result.streakMilestone || result.fullDayAwarded) {
      _confettiController.play();
    }

    _loadWeeklyAdherence();
  }

  String _buildRewardMessage(
    GamificationResult result,
    BuildContext context,
    String medName,
  ) {
    final buffer = StringBuffer();
    buffer.write(result.onTime
        ? context.loc.t('statusTaken')
        : context.loc.t('statusLate'));
    buffer.write(' ');
    buffer.write(medName);
    buffer.write(' ƒ?½ +');
    buffer.write(result.pointsAwarded);
    buffer.write(' ');
    buffer.write(context.loc.t('points'));

    if (result.streakMilestone) {
      buffer.write(' ƒ?½ ');
      buffer.write('${result.streakDays}-day streak!');
    }
    if (result.fullDayAwarded) {
      buffer.write(' ƒ?½ ');
      buffer.write(context.loc.t('historyLoadedSuccess'));
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Center(child: Text(context.loc.t('signInToView')));
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
        final points = userData?['points'] ?? 0;
        final streak = userData?['streakDays'] ?? 0;

        final stream = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('medicines')
            .snapshots();

        return Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: _PointsCard(points: points)),
                      const SizedBox(width: 12),
                      _StreakChip(streakDays: streak),
                      const SizedBox(width: 12),
                      _AdherenceRing(
                        adherence: _weeklyAdherence,
                        loading: _loadingAdherence,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Text(
                    context.loc.t('todayMedicinesTitle'),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Expanded(
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: stream,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        if (snapshot.hasError) {
                          return Center(child: Text(context.loc.t('failedLoad')));
                        }

                        final docs = snapshot.data?.docs ?? [];
                        if (docs.isEmpty) {
                          return Center(child: Text(context.loc.t('noMedicines')));
                        }

                    final now = DateTime.now();
                    final currentDay = _getCurrentDay(now.weekday);
                    final currentTime = TimeOfDay.fromDateTime(now);
                    final todayDate =
                        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

                    /// 🔹 סינון תרופות לפי היום והתאריכים
                    final filteredDocs = docs.where((doc) {
                      final data = doc.data();

                      /// 🔹 ימים (support storing List<int> or List<String>)
                      final rawDays = data['days'] as List?;
                      final daysSet = <int>{};
                      if (rawDays != null) {
                        for (final item in rawDays) {
                          if (item is int) {
                            if (item >= 1 && item <= 7) daysSet.add(item);
                          } else if (item is String) {
                            final lower = item.toLowerCase();
                            switch (lower) {
                              case 'monday':
                                daysSet.add(1);
                                break;
                              case 'tuesday':
                                daysSet.add(2);
                                break;
                              case 'wednesday':
                                daysSet.add(3);
                                break;
                              case 'thursday':
                                daysSet.add(4);
                                break;
                              case 'friday':
                                daysSet.add(5);
                                break;
                              case 'saturday':
                                daysSet.add(6);
                                break;
                              case 'sunday':
                                daysSet.add(7);
                                break;
                              default:
                                final parsed = int.tryParse(item);
                                if (parsed != null && parsed >= 1 && parsed <= 7) {
                                  daysSet.add(parsed);
                                }
                            }
                          }
                        }
                      }
                      final validDay = daysSet.contains(now.weekday);

                      /// 🔹 תאריכים
                      final startTimestamp = data['startDate'] as Timestamp?;
                      final endTimestamp = data['endDate'] as Timestamp?;

                      final nowDate = DateTime(now.year, now.month, now.day);

                      final startDate = startTimestamp?.toDate();
                      final endDate = endTimestamp?.toDate();

                      final validDate =
                          (startDate == null || !nowDate.isBefore(startDate)) &&
                          (endDate == null || !nowDate.isAfter(endDate));

                      return validDay && validDate;
                    }).toList();

                    if (filteredDocs.isEmpty) {
                      return Center(
                        child: Text(context.loc.t('noMedicinesToday')),
                      );
                    }

                    /// 🔹 בניית רשימת תרופות להיום
                    final todayMedicines = <Map<String, dynamic>>[];

                    for (final doc in filteredDocs) {
                      final data = doc.data();

                      final name = data['name'] as String? ?? 'Unnamed';

                      final dosage = data['dosage'];
                      final unit = data['unit'] ?? '';
                      final dose = dosage != null
                          ? '$dosage $unit'
                          : unit.toString();

                      final times =
                          (data['timesOfDay'] as List?)?.cast<String>() ?? [];

                      final takenTimes =
                          (data['dailyTaken']?[todayDate] as List?)
                              ?.cast<String>() ??
                          [];

                      for (final timeKey in times) {
                        final timeValue = _parseTime(timeKey);
                        if (timeValue == null) continue;

                        final isTaken = takenTimes.contains(timeKey);
                        final status = isTaken
                            ? 'taken'
                            : _getStatus(timeKey, currentTime);

                        todayMedicines.add({
                          'name': name,
                          'dose': dose,
                          'timeLabel': _getTimeDisplay(timeKey),
                          'timeValue': timeValue,
                          'status': status,
                          'isTaken': isTaken,
                          'docId': doc.id,
                          'timeKey': timeKey,
                        });
                      }
                    }

                    /// 🔹 מיון מהבוקר לערב
                    todayMedicines.sort((a, b) {
                      final t1 = a['timeValue'] as TimeOfDay;
                      final t2 = b['timeValue'] as TimeOfDay;
                      return (t1.hour * 60 + t1.minute) -
                          (t2.hour * 60 + t2.minute);
                    });

                        return ListView.builder(
                          itemCount: todayMedicines.length,
                          itemBuilder: (context, index) {
                            final med = todayMedicines[index];
                            return MedicineCard(
                              name: med['name'],
                              dose: med['dose'],
                              time: med['timeLabel'],
                              status: med['status'],
                              isTaken: med['isTaken'],
                              onMarkTaken: () => _markAsTaken(
                                med['docId'],
                                med['timeKey'],
                                todayDate,
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                emissionFrequency: 0.2,
                numberOfParticles: 20,
                maxBlastForce: 15,
                minBlastForce: 5,
                shouldLoop: false,
              ),
            ),
          ],
        );
      },
    );
  }

  /// 🔹 יום נוכחי
  String _getCurrentDay(int weekday) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return days[weekday - 1];
  }

  /// 🔹 המרת זמן
  TimeOfDay? _parseTime(String timeKey) {
    switch (timeKey) {
      case 'morning':
        return const TimeOfDay(hour: 5, minute: 0); // טווח 5:00-11:59
      case 'noon':
        return const TimeOfDay(hour: 12, minute: 0); // טווח 12:00-16:59
      case 'evening':
        return const TimeOfDay(hour: 17, minute: 0); // טווח 17:00-18:59
      case 'night':
        return const TimeOfDay(hour: 19, minute: 0); // טווח 19:00-4:59
      default:
        final parts = timeKey.split(':');
        if (parts.length == 2) {
          final h = int.tryParse(parts[0]);
          final m = int.tryParse(parts[1]);
          if (h != null && m != null) {
            return TimeOfDay(hour: h, minute: m);
          }
        }
        return null;
    }
  }

  /// 🔹 תצוגת זמן
  String _getTimeDisplay(String timeKey) {
    switch (timeKey) {
      case 'morning':
        return context.loc.t('morning');
      case 'noon':
        return context.loc.t('noon');
      case 'evening':
        return context.loc.t('evening');
      case 'night':
        return context.loc.t('night');
      default:
        return timeKey;
    }
  }

  /// 🔹 סטטוס תרופה
  String _getStatus(String timeKey, TimeOfDay now) {
    TimeOfDay start, end;
    bool isNight = false;

    switch (timeKey) {
      case 'morning':
        start = const TimeOfDay(hour: 5, minute: 0);
        end = const TimeOfDay(hour: 11, minute: 59);
        break;
      case 'noon':
        start = const TimeOfDay(hour: 12, minute: 0);
        end = const TimeOfDay(hour: 16, minute: 59);
        break;
      case 'evening':
        start = const TimeOfDay(hour: 17, minute: 0);
        end = const TimeOfDay(hour: 18, minute: 59);
        break;
      case 'night':
        start = const TimeOfDay(hour: 19, minute: 0);
        end = const TimeOfDay(hour: 4, minute: 59);
        isNight = true;
        break;
      default:
        // For custom times like HH:MM, use point logic
        final medTime = _parseTime(timeKey);
        if (medTime != null) {
          final medMin = medTime.hour * 60 + medTime.minute;
          final nowMin = now.hour * 60 + now.minute;
          if (medMin < nowMin) return 'late';
          if (medMin <= nowMin + 30) return 'due';
          return 'upcoming';
        }
        return 'upcoming';
    }

    final nowMin = now.hour * 60 + now.minute;
    final startMin = start.hour * 60 + start.minute;
    final endMin = end.hour * 60 + end.minute;

    if (isNight) {
      // Night spans midnight: 21:00 to 4:59 next day
      if (nowMin < startMin) return 'upcoming';
      if (nowMin >= startMin || nowMin <= endMin) return 'due';
      return 'late';
    } else {
      if (nowMin < startMin) return 'upcoming';
      if (nowMin <= endMin) return 'due';
      return 'late';
    }
  }
}

/// ⭐ כרטיס נקודות
class _PointsCard extends StatelessWidget {
  final int points;
  const _PointsCard({required this.points});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFC83D),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.paid, color: Colors.white),
          const SizedBox(width: 10),
          Text(
            '${context.loc.t('points')}: $points',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class _StreakChip extends StatelessWidget {
  final int streakDays;
  const _StreakChip({required this.streakDays});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF23C3AE), width: 1.2),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_fire_department, color: Color(0xFF23C3AE)),
          const SizedBox(width: 6),
          Text(
            '$streakDays d',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF23C3AE),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdherenceRing extends StatelessWidget {
  final double? adherence;
  final bool loading;
  const _AdherenceRing({required this.adherence, required this.loading});

  @override
  Widget build(BuildContext context) {
    final value = (adherence ?? 0).clamp(0, 100).toDouble();
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: SizedBox(
        height: 52,
        width: 52,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              value: loading ? null : value / 100,
              strokeWidth: 6,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                value >= 80
                    ? Colors.green
                    : value >= 50
                        ? Colors.orange
                        : Colors.red,
              ),
            ),
            Text(
              loading ? '…' : '${value.toStringAsFixed(0)}%',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

// Using shared MedicineCard widget from widgets/medicine_card.dart
