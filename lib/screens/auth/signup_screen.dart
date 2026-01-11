import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import '../../auth/auth_notifier.dart';
import '../../auth/auth_status.dart';
import '../../widgets/pill_logo.dart';
import '../../l10n/app_localizations.dart';
import '../onboarding/role_selection_screen.dart';

/// Signup screen for PillCare - creates new user accounts.
class SignupScreen extends StatefulWidget {
  static const routeName = '/signup';

  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  DateTime? _birthDate;
  int _selectedMonth = 1;
  int _selectedDay = 1;
  int _selectedYear = 1990;
  final DateFormat _birthDateDisplayFormatter = DateFormat('MMMM dd, yyyy');

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = now.month;
    _selectedDay = now.day;
    _selectedYear = now.year - 30;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _updateBirthDate() {
    setState(() {
      try {
        _birthDate = DateTime(_selectedYear, _selectedMonth, _selectedDay);
      } catch (e) {
        // Invalid date, keep previous value
      }
    });
  }

  Future<void> _handleSignUp() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.loc.t('fillAllFields'))));
      return;
    }

    if (_birthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.loc.t('pleaseSelectBirthDate'))),
      );
      return;
    }

    if (_birthDate!.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.loc.t('birthDateFutureError'))),
      );
      return;
    }

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.loc.t('passwordTooShort'))),
      );
      return;
    }

    final auth = context.read<AuthNotifier>();
    setState(() => _isLoading = true);

    final success = await auth.signUp(
      name,
      email,
      password,
      birthDate: _birthDate!,
    );

    setState(() => _isLoading = false);

    if (success) {
      if (!mounted) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('lastEmail', email);
      if (!mounted) return;
      // Immediately take new users to role selection and block back navigation
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
        (route) => false,
      );
    } else {
      if (!mounted) return;
      final msg =
          context.read<AuthNotifier>().lastErrorMessage ??
          context.loc.t('signupError');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _pickBirthDate() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _BirthDateSpinnerPicker(
        initialMonth: _selectedMonth,
        initialDay: _selectedDay,
        initialYear: _selectedYear,
        onConfirm: (month, day, year) {
          setState(() {
            _selectedMonth = month;
            _selectedDay = day;
            _selectedYear = year;
            _updateBirthDate();
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authStatus = context.watch<AuthNotifier>().status;
    final isBusy = _isLoading || authStatus == AuthStatus.authenticating;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFFF9F7F4),
      body: Stack(
        children: [
          // Fixed background blobs
          const Positioned(
            top: -60,
            left: -70,
            child: _Blob(color: Color(0xFFBFE6FF), size: 220),
          ),
          const Positioned(
            bottom: -40,
            left: 40,
            child: _Blob(color: Color(0xFFFFD9D6), size: 200),
          ),
          const Positioned(
            bottom: -70,
            right: -60,
            child: _Blob(color: Color(0xFFCCF2EA), size: 240),
          ),
          // Scrollable content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 12),
                      const Center(
                        child: PillLogoAnimated(
                          size: 90,
                          showHalo: false,
                          showBadgeCircle: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          'PillCare',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF24948C),
                              ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        context.loc.t('joinUs'),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF2B2D31),
                            ),
                      ),
                      const SizedBox(height: 24),
                      _RoundedInput(
                        controller: _nameController,
                        hintText: context.loc.t('name'),
                        enabled: !isBusy,
                        keyboardType: TextInputType.name,
                      ),
                      const SizedBox(height: 14),
                      _RoundedInput(
                        controller: _emailController,
                        hintText: context.loc.t('email'),
                        enabled: !isBusy,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 14),
                      _RoundedInput(
                        controller: _passwordController,
                        hintText: context.loc.t('password'),
                        enabled: !isBusy,
                        obscureText: true,
                      ),
                      const SizedBox(height: 14),
                      _BirthDatePicker(
                        selectedDate: _birthDate,
                        enabled: !isBusy,
                        onPickDate: _pickBirthDate,
                        label: context.loc.t('birthDate'),
                        displayFormatter: _birthDateDisplayFormatter,
                      ),
                      const SizedBox(height: 22),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          isBusy
                              ? const Center(child: CircularProgressIndicator())
                              : ElevatedButton(
                                  key: const Key('signupButton'),
                                  onPressed: _handleSignUp,
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(26),
                                    ),
                                    backgroundColor: const Color(0xFF23C3AE),
                                    foregroundColor: Colors.white,
                                    textStyle: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  child: Text(context.loc.t('signUp')),
                                ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                context.loc.t('haveAccount'),
                                style: TextStyle(color: Colors.grey[700]),
                              ),
                              TextButton(
                                key: const Key('loginLink'),
                                onPressed: isBusy
                                    ? null
                                    : () => Navigator.of(context).pop(),
                                child: Text(
                                  context.loc.t('signIn'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF2B2D31),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundedInput extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final bool enabled;
  final bool obscureText;
  final TextInputType? keyboardType;

  const _RoundedInput({
    required this.controller,
    required this.hintText,
    required this.enabled,
    this.obscureText = false,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      obscureText: obscureText,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hintText,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          borderSide: BorderSide(color: Color(0xFF23C3AE), width: 1.5),
        ),
      ),
    );
  }
}

class _BirthDatePicker extends StatelessWidget {
  final DateTime? selectedDate;
  final bool enabled;
  final VoidCallback onPickDate;
  final String label;
  final DateFormat displayFormatter;

  const _BirthDatePicker({
    required this.selectedDate,
    required this.enabled,
    required this.onPickDate,
    required this.label,
    required this.displayFormatter,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 12),
        Material(
          child: InkWell(
            onTap: enabled ? onPickDate : null,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300, width: 1),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  Icon(
                    Icons.cake_outlined,
                    color: const Color(0xFF23C3AE),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (selectedDate != null)
                          Text(
                            displayFormatter.format(selectedDate!),
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[900],
                                ),
                          )
                        else
                          Text(
                            context.loc.t('selectBirthDate'),
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(color: Colors.grey[500]),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.calendar_month_rounded,
                    color: const Color(0xFF23C3AE),
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (selectedDate == null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              context.loc.t('pleaseSelectBirthDate'),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.red[600]),
            ),
          ),
      ],
    );
  }
}

class _BirthDateSpinnerPicker extends StatefulWidget {
  final int initialMonth;
  final int initialDay;
  final int initialYear;
  final Function(int month, int day, int year) onConfirm;

  const _BirthDateSpinnerPicker({
    required this.initialMonth,
    required this.initialDay,
    required this.initialYear,
    required this.onConfirm,
  });

  @override
  State<_BirthDateSpinnerPicker> createState() =>
      _BirthDateSpinnerPickerState();
}

class _BirthDateSpinnerPickerState extends State<_BirthDateSpinnerPicker> {
  late int _month;
  late int _day;
  late int _year;
  late TextEditingController _monthController;
  late TextEditingController _dayController;
  late TextEditingController _yearController;

  @override
  void initState() {
    super.initState();
    _month = widget.initialMonth;
    _day = widget.initialDay;
    _year = widget.initialYear;
    _monthController = TextEditingController(
      text: _month.toString().padLeft(2, '0'),
    );
    _dayController = TextEditingController(
      text: _day.toString().padLeft(2, '0'),
    );
    _yearController = TextEditingController(text: _year.toString());
  }

  @override
  void dispose() {
    _monthController.dispose();
    _dayController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  void _updateMonthFromText(String value) {
    final parsed = int.tryParse(value);
    if (parsed != null && parsed >= 1 && parsed <= 12) {
      setState(() {
        _month = parsed;
        _updateDay();
      });
    }
  }

  void _updateDayFromText(String value) {
    final parsed = int.tryParse(value);
    final maxDays = _daysInMonth(_month, _year);
    if (parsed != null && parsed >= 1 && parsed <= maxDays) {
      setState(() => _day = parsed);
    }
  }

  void _updateYearFromText(String value) {
    final parsed = int.tryParse(value);
    final now = DateTime.now();
    if (parsed != null && parsed >= now.year - 120 && parsed <= now.year) {
      setState(() {
        _year = parsed;
        _updateDay();
      });
    }
  }

  List<String> get _monthNames => [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  int _daysInMonth(int month, int year) {
    if (month == 2) {
      return (year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)) ? 29 : 28;
    }
    if ([4, 6, 9, 11].contains(month)) return 30;
    return 31;
  }

  void _updateDay() {
    final maxDays = _daysInMonth(_month, _year);
    if (_day > maxDays) {
      setState(() => _day = maxDays);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final maxDays = _daysInMonth(_month, _year);

    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  Text(
                    'Select Birth Date',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => widget.onConfirm(_month, _day, _year),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF23C3AE),
                    ),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
            const Divider(),
            // Spinners with editable fields
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Month Spinner
                  _EditableSpinnerColumn(
                    label: 'Month',
                    value: _monthNames[_month - 1],
                    controller: _monthController,
                    onIncrement: () {
                      if (_month < 12) {
                        setState(() => _month++);
                        _monthController.text = _month.toString().padLeft(
                          2,
                          '0',
                        );
                        _updateDay();
                      }
                    },
                    onDecrement: () {
                      if (_month > 1) {
                        setState(() => _month--);
                        _monthController.text = _month.toString().padLeft(
                          2,
                          '0',
                        );
                        _updateDay();
                      }
                    },
                    onTextChanged: _updateMonthFromText,
                    hint: 'MM',
                  ),
                  // Day Spinner
                  _EditableSpinnerColumn(
                    label: 'Day',
                    value: _day.toString().padLeft(2, '0'),
                    controller: _dayController,
                    onIncrement: () {
                      if (_day < maxDays) {
                        setState(() => _day++);
                        _dayController.text = _day.toString().padLeft(2, '0');
                      }
                    },
                    onDecrement: () {
                      if (_day > 1) {
                        setState(() => _day--);
                        _dayController.text = _day.toString().padLeft(2, '0');
                      }
                    },
                    onTextChanged: _updateDayFromText,
                    hint: 'DD',
                  ),
                  // Year Spinner
                  _EditableSpinnerColumn(
                    label: 'Year',
                    value: _year.toString(),
                    controller: _yearController,
                    onIncrement: () {
                      if (_year < now.year) {
                        setState(() => _year++);
                        _yearController.text = _year.toString();
                        _updateDay();
                      }
                    },
                    onDecrement: () {
                      if (_year > now.year - 120) {
                        setState(() => _year--);
                        _yearController.text = _year.toString();
                        _updateDay();
                      }
                    },
                    onTextChanged: _updateYearFromText,
                    hint: 'YYYY',
                  ),
                ],
              ),
            ),
            // Add bottom padding for Android navigation bar
            SizedBox(height: MediaQuery.of(context).viewPadding.bottom + 16),
          ],
        ),
      ),
    );
  }
}

class _EditableSpinnerColumn extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final TextEditingController controller;
  final ValueChanged<String> onTextChanged;
  final String hint;

  const _EditableSpinnerColumn({
    required this.label,
    required this.value,
    required this.onIncrement,
    required this.onDecrement,
    required this.controller,
    required this.onTextChanged,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Colors.grey[600],
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        // Increment Button
        SizedBox(
          width: 80,
          child: ElevatedButton(
            onPressed: onIncrement,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF23C3AE),
              minimumSize: const Size(80, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Icon(Icons.add, color: Colors.white, size: 24),
          ),
        ),
        const SizedBox(height: 12),
        // Editable Text Field
        SizedBox(
          width: 80,
          child: TextField(
            controller: controller,
            onChanged: onTextChanged,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF23C3AE),
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey[400]),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 8,
                horizontal: 4,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFF23C3AE),
                  width: 2,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Decrement Button
        SizedBox(
          width: 80,
          child: ElevatedButton(
            onPressed: onDecrement,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF23C3AE),
              minimumSize: const Size(80, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Icon(Icons.remove, color: Colors.white, size: 24),
          ),
        ),
      ],
    );
  }
}

class _Blob extends StatelessWidget {
  final Color color;
  final double size;

  const _Blob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size * 0.35),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000000).withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
    );
  }
}
