import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/auth_notifier.dart';
import '../../data/user_profile_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../patient_code_input_formatter.dart';
import '../../root_gate.dart';

class FamilyMemberSetupScreen extends StatefulWidget {
  static const routeName = '/family-member-setup';

  const FamilyMemberSetupScreen({super.key});

  @override
  State<FamilyMemberSetupScreen> createState() => _FamilyMemberSetupScreenState();
}

class _FamilyMemberSetupScreenState extends State<FamilyMemberSetupScreen> {
  final _profileRepo = UserProfileRepository();
  late final List<TextEditingController> _patientControllers;
  String? _selectedRelation;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _patientControllers = [_createPatientController()];
  }

  @override
  void dispose() {
    for (final controller in _patientControllers) {
      controller.removeListener(_onPatientInputChanged);
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _createPatientController() {
    final controller = TextEditingController();
    controller.addListener(_onPatientInputChanged);
    return controller;
  }

  void _onPatientInputChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _addPatientField() {
    setState(() {
      _patientControllers.add(_createPatientController());
    });
  }

  void _removePatientField(int index) {
    if (_patientControllers.length <= 1) {
      _patientControllers[index].clear();
      return;
    }
    setState(() {
      final controller = _patientControllers.removeAt(index);
      controller.removeListener(_onPatientInputChanged);
      controller.dispose();
    });
  }

  String _digitsOnly(String value) {
    return value.replaceAll(RegExp(r'\D'), '');
  }

  List<String> _collectPatients() {
    final unique = <String>[];
    final seen = <String>{};
    for (final controller in _patientControllers) {
      final digits = _digitsOnly(controller.text);
      if (digits.isEmpty) continue;
      final value = 'P-$digits';
      if (seen.add(value)) {
        unique.add(value);
      }
    }
    return unique;
  }

  bool get _hasValidPatientInputs {
    final entries = _patientControllers
        .map((controller) => _digitsOnly(controller.text))
        .where((value) => value.isNotEmpty)
        .toList();
    if (entries.isEmpty) return false;
    return entries.every((value) => value.length == 6);
  }

  bool _isValidPublicId(String value) {
    return RegExp(r'^P-\d{6}$').hasMatch(value);
  }

  Future<void> _saveAndContinue() async {
    if (_isSaving) return;
    final patients = _collectPatients();
    final loc = context.loc;

    if (patients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.t('addPatientIdRequired'))),
      );
      return;
    }

    if (_selectedRelation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.t('selectRelation'))),
      );
      return;
    }

    for (final patientId in patients) {
      if (!_isValidPublicId(patientId)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.t('invalidPatientId'))),
        );
        return;
      }
    }

    setState(() => _isSaving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw _ValidationError(loc.t('pleaseSignIn'));
      }

      final patientPairs = <({String uid, String publicId})>[];
      for (final patientId in patients) {
        final patientUid =
            await _profileRepo.findPatientUidByPublicId(patientId);
        if (patientUid == null) {
          throw _ValidationError(loc.t('patientNotFound'));
        }
        final alreadyConnected = await _profileRepo.connectionExists(
          familyMemberUid: user.uid,
          patientUid: patientUid,
        );
        if (alreadyConnected) {
          throw _ValidationError(loc.t('alreadyConnected'));
        }
        patientPairs.add((uid: patientUid, publicId: patientId));
      }

      for (final pair in patientPairs) {
        await _profileRepo.createConnection(
          familyMemberUid: user.uid,
          patientUid: pair.uid,
          relation: _selectedRelation!,
          patientPublicId: pair.publicId,
        );
      }

      await _profileRepo.updateFamilyMemberSetup(
        uid: user.uid,
        relation: _selectedRelation!,
        patients: patients,
      );
      await context.read<AuthNotifier>().addUserRole(
            UserProfileRepository.roleFamilyMember,
          );

      if (!mounted) return;
      _goToHome();
    } on _ValidationError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.t('failedSave'))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _goToHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const RootGate()),
      (route) => false,
    );
  }

  List<_RelationOption> _relationOptions(AppLocalizations loc) {
    return [
      _RelationOption('mother', loc.t('relationMother')),
      _RelationOption('father', loc.t('relationFather')),
      _RelationOption('brother', loc.t('relationBrother')),
      _RelationOption('sister', loc.t('relationSister')),
      _RelationOption('spouse', loc.t('relationSpouse')),
      _RelationOption('child', loc.t('relationChild')),
      _RelationOption('other', loc.t('relationOther')),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final relations = _relationOptions(loc);
    final canContinue =
        !_isSaving && _hasValidPatientInputs && _selectedRelation != null;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(
          loc.t('familyMemberSetupTitle'),
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
                Text(
                  loc.t('relationQuestion'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: relations
                      .map(
                        (relation) => ChoiceChip(
                          label: Text(relation.label),
                          selected: _selectedRelation == relation.key,
                          onSelected: (selected) {
                            setState(() {
                              _selectedRelation = selected ? relation.key : null;
                            });
                          },
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 24),
                Text(
                  loc.t('addPatientsTitle'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Column(
                  children: List.generate(
                    _patientControllers.length,
                    (index) => _PatientField(
                      controller: _patientControllers[index],
                      label: loc.t('patientIdentifierLabel'),
                      onRemove: () => _removePatientField(index),
                      canRemove: _patientControllers.length > 1,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _addPatientField,
                  icon: const Icon(Icons.add),
                  label: Text(loc.t('addAnotherPatient')),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: canContinue ? _saveAndContinue : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2EC4B6),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 24,
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              loc.t('continue'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RelationOption {
  final String key;
  final String label;
  const _RelationOption(this.key, this.label);
}

class _ValidationError implements Exception {
  final String message;
  _ValidationError(this.message);
}

class _PatientField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final VoidCallback onRemove;
  final bool canRemove;

  const _PatientField({
    required this.controller,
    required this.label,
    required this.onRemove,
    required this.canRemove,
  });

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, child) {
          final digits = value.text.replaceAll(RegExp(r'\D'), '');
          final showError = digits.isNotEmpty && digits.length < 6;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.hintColor,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  PatientCodeInputFormatter(),
                ],
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  hintText: '123 456',
                  prefixText: 'P- ',
                  prefixStyle: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  suffixIcon: canRemove
                      ? IconButton(
                          onPressed: onRemove,
                          icon: const Icon(Icons.close),
                          tooltip: 'Remove',
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  errorText: showError ? loc.t('patientIdDigitsError') : null,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
