import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../widgets/medicine_card.dart';

class MedicineDetailsScreen extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;

  const MedicineDetailsScreen({
    super.key,
    required this.docId,
    required this.data,
  });

  String _formatList(List<String> items, AppLocalizations loc) {
    if (items.isEmpty) return loc.t('noResults');
    return items.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final name = data['name'] as String? ?? loc.t('medicineName');
    final dosage = data['dosage'];
    final unit = data['unit'] as String? ?? '';
    final dosageText = dosage != null ? '$dosage $unit' : unit;
    final rawDays = data['days'] as List?;
    final times = (data['timesOfDay'] as List?)?.cast<String>() ?? [];
    final daysList = <String>[];
    if (rawDays != null) {
      for (final item in rawDays) {
        if (item is int) {
          switch (item) {
            case 1:
              daysList.add('Monday');
              break;
            case 2:
              daysList.add('Tuesday');
              break;
            case 3:
              daysList.add('Wednesday');
              break;
            case 4:
              daysList.add('Thursday');
              break;
            case 5:
              daysList.add('Friday');
              break;
            case 6:
              daysList.add('Saturday');
              break;
            case 7:
              daysList.add('Sunday');
              break;
            default:
              break;
          }
        } else if (item is String) {
          daysList.add(item);
        }
      }
    }
    final localizedDays = daysList.map((d) => _localizedDay(loc, d)).toList();
    final isEveryday = _isEveryday(rawDays);
    final daysDisplay = isEveryday
        ? loc.t('everyday')
        : _formatList(localizedDays, loc);
    final localizedTimes = times.map((t) => _localizedTime(loc, t)).toList();
    final startDate = data['startDate'];
    final startDateString = _formatDate(startDate, loc);
    final endDate = data['endDate'];
    final endDateString = _formatDate(endDate, loc);
    final notes = data['notes'] as String? ?? '';

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(
          loc.t('medicineDetails'),
          style: const TextStyle(color: Colors.black),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            _sectionContainer(
              context,
              child: MedicineCard(
                name: name,
                dose: dosageText,
                time: null,
                status: null,
                isTaken: false,
              ),
            ),
            const SizedBox(height: 12),
            _detailSection(
              context,
              title: loc.t('daysOfWeek'),
              subtitle: daysDisplay,
            ),
            const SizedBox(height: 12),
            _detailSection(
              context,
              title: loc.t('timesOfDay'),
              subtitle: _formatList(localizedTimes, loc),
            ),
            const SizedBox(height: 12),
            _detailSection(
              context,
              title: loc.t('startDate'),
              subtitle: startDateString,
            ),
            const SizedBox(height: 12),
            _detailSection(
              context,
              title: loc.t('endDate'),
              subtitle: endDateString,
            ),
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              _detailSection(
                context,
                title: loc.t('notesOptional'),
                subtitle: notes,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionContainer(
    BuildContext context, {
    required Widget child,
    EdgeInsetsGeometry? padding,
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: child,
    );
  }

  Widget _detailSection(
    BuildContext context, {
    required String title,
    required String subtitle,
  }) {
    return _sectionContainer(
      context,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }

  String _formatDate(dynamic value, AppLocalizations loc) {
    if (value == null) return loc.t('startDateNotSet');
    if (value is DateTime) {
      return value.toLocal().toString().split(' ').first;
    }
    if (value is Timestamp) {
      return value.toDate().toLocal().toString().split(' ').first;
    }
    return value.toString();
  }

  String _localizedDay(AppLocalizations loc, String day) {
    switch (day.toLowerCase()) {
      case 'sunday':
        return loc.t('sunday');
      case 'monday':
        return loc.t('monday');
      case 'tuesday':
        return loc.t('tuesday');
      case 'wednesday':
        return loc.t('wednesday');
      case 'thursday':
        return loc.t('thursday');
      case 'friday':
        return loc.t('friday');
      case 'saturday':
        return loc.t('saturday');
      default:
        return day;
    }
  }

  String _localizedTime(AppLocalizations loc, String time) {
    switch (time.toLowerCase()) {
      case 'morning':
        return loc.t('morning');
      case 'noon':
        return loc.t('noon');
      case 'evening':
        return loc.t('evening');
      case 'night':
        return loc.t('night');
      default:
        return time;
    }
  }

  bool _isEveryday(List? rawDays) {
    return _normalizedDays(rawDays).length == 7;
  }

  Set<int> _normalizedDays(List? rawDays) {
    final days = <int>{};
    if (rawDays == null) return days;
    for (final item in rawDays) {
      if (item is int) {
        if (item >= 1 && item <= 7) days.add(item);
      } else if (item is String) {
        final lower = item.toLowerCase();
        switch (lower) {
          case 'monday':
            days.add(1);
            break;
          case 'tuesday':
            days.add(2);
            break;
          case 'wednesday':
            days.add(3);
            break;
          case 'thursday':
            days.add(4);
            break;
          case 'friday':
            days.add(5);
            break;
          case 'saturday':
            days.add(6);
            break;
          case 'sunday':
            days.add(7);
            break;
          default:
            final parsed = int.tryParse(item);
            if (parsed != null && parsed >= 1 && parsed <= 7) {
              days.add(parsed);
            }
        }
      }
    }
    return days;
  }
}

