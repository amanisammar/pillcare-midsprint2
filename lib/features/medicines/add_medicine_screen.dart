import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../data/user_profile_repository.dart';
import '../../l10n/app_localizations.dart';

class AddMedicineScreen extends StatefulWidget {
  final bool requestOnly;
  final String? patientUid;
  final String? patientName;
  final String? patientPublicId;

  const AddMedicineScreen({
    super.key,
    this.requestOnly = false,
    this.patientUid,
    this.patientName,
    this.patientPublicId,
  }) : assert(!requestOnly || patientUid != null);

  @override
  State<AddMedicineScreen> createState() => _AddMedicineScreenState();
}

class _AddMedicineScreenState extends State<AddMedicineScreen> {
  late TextEditingController _nameController;
  final _dosageController = TextEditingController();
  final _notesController = TextEditingController();

  final List<String> _selectedTimes = [];
  final List<int> _selectedDays = [];
  // Weekdays: 1 = Monday ... 7 = Sunday
  final List<int> _weekdays = const [1, 2, 3, 4, 5, 6, 7];

  String _dosageUnit = 'pill';
  DateTime _startDate = DateUtils.dateOnly(DateTime.now());
  DateTime _endDate = DateUtils.dateOnly(DateTime.now());

  final List<String> _commonMedicines = const [
    'Acamol',
    'Nurofen',
    'Optalgin',
    'Ibuprofen',
    'Kalgaron',
    'Acamoli',
    'Simvastatin',
    'Losec',
    'Zantac',
    'Tegretol',
    'Adex',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  void _toggleTime(String time) {
    setState(() {
      _selectedTimes.contains(time)
          ? _selectedTimes.remove(time)
          : _selectedTimes.add(time);
    });
  }

  void _toggleDay(int weekday) {
    setState(() {
      _selectedDays.contains(weekday)
          ? _selectedDays.remove(weekday)
          : _selectedDays.add(weekday);
    });
  }

  void _setEveryday(bool selected) {
    setState(() {
      _selectedDays.clear();
      if (selected) {
        _selectedDays.addAll(_weekdays);
      }
    });
  }

  bool get _everydaySelected => _selectedDays.toSet().length == _weekdays.length;

  bool get _showDayError => !_everydaySelected && _selectedDays.isEmpty;

  Future<void> _pickStartDate() async {
    final allowedWeekdays = _allowedWeekdays;
    if (allowedWeekdays.isEmpty) {
      _showSelectDaysMessage();
      return;
    }

    final now = DateTime.now();
    final firstDate = DateTime(now.year - 1);
    final lastDate = DateTime(now.year + 5);
    final initialDate = _initialPickerDate(
      _startDate,
      allowedWeekdays,
      firstDate,
      lastDate,
    );
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      selectableDayPredicate: (day) => allowedWeekdays.contains(day.weekday),
    );
    if (picked != null) {
      setState(() {
        _startDate = DateUtils.dateOnly(picked);
        final updatedAllowedWeekdays = _allowedWeekdays;
        if (_endDate.isBefore(_startDate) ||
            !updatedAllowedWeekdays.contains(_endDate.weekday)) {
          _endDate = _findNextAllowedDate(
            _startDate,
            updatedAllowedWeekdays,
            firstDate,
            lastDate,
          );
        }
      });
    }
  }

  void _showSelectDaysMessage() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.loc.t('selectDaysFirst'))));
  }

  Set<int> get _allowedWeekdays => _selectedDays.toSet();

  String _shortDayLabel(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Mon';
      case DateTime.tuesday:
        return 'Tue';
      case DateTime.wednesday:
        return 'Wed';
      case DateTime.thursday:
        return 'Thu';
      case DateTime.friday:
        return 'Fri';
      case DateTime.saturday:
        return 'Sat';
      case DateTime.sunday:
        return 'Sun';
      default:
        return '';
    }
  }

  DateTime _initialPickerDate(
    DateTime preferred,
    Set<int> allowedWeekdays,
    DateTime firstDate,
    DateTime lastDate,
  ) {
    var candidate = DateUtils.dateOnly(preferred);
    if (candidate.isBefore(firstDate)) {
      candidate = firstDate;
    }
    if (candidate.isAfter(lastDate)) {
      candidate = lastDate;
    }
    if (!allowedWeekdays.contains(candidate.weekday)) {
      candidate = _findNextAllowedDate(
        candidate,
        allowedWeekdays,
        firstDate,
        lastDate,
      );
    }
    return candidate;
  }

  DateTime _findNextAllowedDate(
    DateTime start,
    Set<int> allowedWeekdays,
    DateTime firstDate,
    DateTime lastDate,
  ) {
    var date = DateUtils.dateOnly(start);
    for (var i = 0; i < 7; i++) {
      if (!date.isAfter(lastDate) && allowedWeekdays.contains(date.weekday)) {
        return date;
      }
      date = date.add(const Duration(days: 1));
    }
    date = DateUtils.dateOnly(start);
    for (var i = 0; i < 7; i++) {
      if (!date.isBefore(firstDate) && allowedWeekdays.contains(date.weekday)) {
        return date;
      }
      date = date.subtract(const Duration(days: 1));
    }
    return DateUtils.dateOnly(start.isBefore(firstDate) ? firstDate : lastDate);
  }

  String _formatDate(DateTime date) {
    return date.toLocal().toString().split(' ').first;
  }

  Future<void> _pickEndDate() async {
    final allowedWeekdays = _allowedWeekdays;
    if (allowedWeekdays.isEmpty) {
      _showSelectDaysMessage();
      return;
    }

    final now = DateTime.now();
    final firstDate = DateUtils.dateOnly(_startDate);
    final lastDate = DateTime(now.year + 5);
    final initialDate = _initialPickerDate(
      _endDate.isBefore(firstDate) ? firstDate : _endDate,
      allowedWeekdays,
      firstDate,
      lastDate,
    );

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      selectableDayPredicate: (day) =>
          allowedWeekdays.contains(day.weekday) && !day.isBefore(firstDate),
    );

    if (picked != null) {
      setState(() {
        _endDate = DateUtils.dateOnly(picked);
      });
    }
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty ||
        _dosageController.text.trim().isEmpty ||
        _selectedDays.isEmpty ||
        _selectedTimes.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.loc.t('pleaseFill'))));
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.loc.t('pleaseSignIn'))));
      return;
    }

    final name = _nameController.text.trim();

    try {
      if (widget.requestOnly) {
        final patientUid = widget.patientUid;
        if (patientUid == null) {
          throw StateError('Missing patient UID');
        }
        await UserProfileRepository().createMedicineRequest(
          familyMemberUid: user.uid,
          patientUid: patientUid,
          medicineData: {
            'name': name,
            'dosage': double.tryParse(_dosageController.text),
            'unit': _dosageUnit,
            'days': _selectedDays,
            'timesOfDay': _selectedTimes,
            'startDate': Timestamp.fromDate(_startDate),
            'endDate': Timestamp.fromDate(_endDate),
            'notes': _notesController.text.trim(),
          },
        );

        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.loc.t('requestSent'))));

        Navigator.pop(context);
        return;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('medicines')
          .add({
            'name': name,
            'dosage': double.tryParse(_dosageController.text),
            'unit': _dosageUnit,
            'days': _selectedDays,
            'timesOfDay': _selectedTimes,
            'startDate': Timestamp.fromDate(_startDate),
            'endDate': Timestamp.fromDate(_endDate),
            'notes': _notesController.text.trim(),
            'createdAt': Timestamp.now(),
          });

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.loc.t('medicineSaved'))));

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.loc.t('failedSave'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F4EF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(
          widget.requestOnly ? loc.t('requestMedicine') : loc.t('addMedicine'),
          style: const TextStyle(color: Colors.black),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: ListView(
              children: [
                if (widget.requestOnly) _requestHeader(context),
                _medicineNameField(),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _inputField(
                        label: loc.t('dosageAmount'),
                        icon: Icons.science,
                        controller: _dosageController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    DropdownButton<String>(
                      value: _dosageUnit,
                      items: [
                        DropdownMenuItem(
                          value: 'pill',
                          child: Text(loc.t('pill')),
                        ),
                        DropdownMenuItem(value: 'ml', child: Text(loc.t('ml'))),
                        DropdownMenuItem(value: 'mg', child: Text(loc.t('mg'))),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _dosageUnit = value);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                Text(
                  loc.t('daysOfWeek'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        loc.t('everyday'),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Switch.adaptive(
                      value: _everydaySelected,
                      onChanged: _setEveryday,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                AnimatedOpacity(
                  opacity: _everydaySelected ? 0.5 : 1,
                  duration: const Duration(milliseconds: 180),
                  child: AbsorbPointer(
                    absorbing: _everydaySelected,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: _weekdays
                          .map(
                            (weekday) => FilterChip(
                              label: Text(_shortDayLabel(weekday)),
                              selected: _selectedDays.contains(weekday),
                              onSelected: _everydaySelected
                                  ? null
                                  : (_) => _toggleDay(weekday),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
                if (_showDayError)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      loc.t('selectAtLeastOneDay'),
                      style: TextStyle(color: Colors.red[600], fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 24),

                Text(
                  loc.t('selectTime'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  children: [
                    _timeTile(loc.t('morning'), Icons.wb_sunny, 'morning'),
                    _timeTile(loc.t('noon'), Icons.sunny, 'noon'),
                    _timeTile(loc.t('evening'), Icons.nights_stay, 'evening'),
                    _timeTile(
                      loc.t('night'),
                      CupertinoIcons.moon_stars_fill,
                      'night',
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                _inputField(
                  label: loc.t('notesOptional'),
                  icon: Icons.notes,
                  controller: _notesController,
                  maxLines: 2,
                ),

                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${loc.t('startDate')}: ${_formatDate(_startDate)}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    TextButton(
                      onPressed: _pickStartDate,
                      child: Text(loc.t('startDate')),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${loc.t('endDate')}: ${_formatDate(_endDate)}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    TextButton(
                      onPressed: _pickEndDate,
                      child: Text(loc.t('endDate')),
                    ),
                  ],
                ),

                const SizedBox(height: 30),

                ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2EC4B6),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    widget.requestOnly
                        ? loc.t('sendRequest')
                        : loc.t('addMedicine'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _inputField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _medicineNameField() {
    final optionsList = _commonMedicines;

    return Autocomplete<String>(
      initialValue: TextEditingValue(text: _nameController.text),
      optionsBuilder: (TextEditingValue textEditingValue) {
        final query = textEditingValue.text.toLowerCase();
        if (query.isEmpty) return optionsList;
        return optionsList.where(
          (option) => option.toLowerCase().contains(query),
        );
      },
      onSelected: (selection) {
        setState(() {
          _nameController.text = selection;
          _nameController.selection = TextSelection.fromPosition(
            TextPosition(offset: selection.length),
          );
        });
      },
      fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
        // Sync the autocomplete controller with our existing controller.
        _nameController = textController;
        return TextField(
          controller: textController,
          focusNode: focusNode,
          onSubmitted: (_) => onFieldSubmitted(),
          decoration: InputDecoration(
            labelText: context.loc.t('medicineName'),
            prefixIcon: const Icon(Icons.medication),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return ListTile(
                    title: Text(option),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _requestHeader(BuildContext context) {
    final loc = context.loc;
    final name = widget.patientName;
    final publicId = widget.patientPublicId;
    final title = name != null && name.isNotEmpty
        ? name
        : loc.t('patient');
    final subtitle = publicId != null && publicId.isNotEmpty ? publicId : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.teal[50],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.person, color: Colors.teal[700]),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loc.t('requestForPatient', params: {'name': title}),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(color: Colors.teal[700]),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timeTile(String label, IconData icon, String value) {
    final selected = _selectedTimes.contains(value);

    Color iconColor;
    Color selectedBg;

    switch (value) {
      case 'morning':
        iconColor = const Color.fromARGB(255, 255, 230, 7);
        selectedBg = const Color(0xFFFFF3CD);
        break;
      case 'noon':
        iconColor = const Color.fromARGB(255, 249, 176, 7);
        selectedBg = const Color(0xFFFFF8E1);
        break;
      case 'evening':
        iconColor = const Color.fromARGB(255, 187, 106, 0);
        selectedBg = const Color(0xFFFFE0B2);
        break;
      case 'night':
        iconColor = const Color.fromARGB(255, 28, 36, 127);
        selectedBg = const Color(0xFFE8EAF6);
        break;
      default:
        iconColor = Colors.grey;
        selectedBg = Colors.white;
    }

    return GestureDetector(
      onTap: () => _toggleTime(value),
      child: Container(
        decoration: BoxDecoration(
          color: selected ? selectedBg : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? iconColor : Colors.grey.shade300,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: iconColor),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 14, color: Colors.black),
            ),
            const SizedBox(height: 4),
            Text(
              _timeRangeText(value),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }

  String _timeRangeText(String value) {
    switch (value) {
      case 'morning':
        return '05:00 - 11:59';
      case 'noon':
        return '12:00 - 16:59';
      case 'evening':
        return '17:00 - 20:59';
      case 'night':
        return '21:00 - 04:59';
      default:
        return '';
    }
  }

}
