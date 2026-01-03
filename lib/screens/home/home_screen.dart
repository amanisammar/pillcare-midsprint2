import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/auth_notifier.dart';
import '../../data/user_profile_repository.dart';
import '../../root_gate.dart';
import '../../services/role_mode_storage.dart';
import '../../features/medicines/add_medicine_screen.dart';
import '../../features/medicines/edit_medicine_screen.dart';
import '../../features/medicines/medicine_details_screen.dart';
import '../../l10n/app_localizations.dart';
import '../today_medicine.dart';
import '../profile/profile_screen.dart';
import '../../widgets/medicine_card.dart';

/// HomeScreen for PillCare - main app screen with logout capability.
class HomeScreen extends StatelessWidget {
  final String role;
  final String? name;
  final Map<String, bool> roles;

  const HomeScreen({
    super.key,
    required this.role,
    this.name,
    required this.roles,
  });

  @override
  Widget build(BuildContext context) {
    if (role == UserProfileRepository.roleFamilyMember) {
      return _FamilyHomeScreen(role: role, name: name, roles: roles);
    }
    return _PatientHomeScreen(role: role, name: name, roles: roles);
  }
}

const String _roleSeparator = '\u2022';

Future<void> _switchRole(
  BuildContext context,
  String uid,
  String currentRole,
  String nextRole,
) async {
  if (currentRole == nextRole) return;
  await RoleModeStorage.setSelectedRole(uid, nextRole);
  if (!context.mounted) return;
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const RootGate()),
    (route) => false,
  );
}

List<PopupMenuEntry<String>> _buildRoleMenuItems(
  BuildContext context,
  Map<String, bool> roles,
) {
  final items = <PopupMenuEntry<String>>[];
  if (roles[UserProfileRepository.rolePatient] == true) {
    items.add(
      PopupMenuItem(
        value: UserProfileRepository.rolePatient,
        child: Text(context.loc.t('patientMode')),
      ),
    );
  }
  if (roles[UserProfileRepository.roleFamilyMember] == true) {
    items.add(
      PopupMenuItem(
        value: UserProfileRepository.roleFamilyMember,
        child: Text(context.loc.t('familyMemberMode')),
      ),
    );
  }
  return items;
}

String _relationLabel(BuildContext context, String? key) {
  switch (key) {
    case 'mother':
      return context.loc.t('relationMother');
    case 'father':
      return context.loc.t('relationFather');
    case 'brother':
      return context.loc.t('relationBrother');
    case 'sister':
      return context.loc.t('relationSister');
    case 'spouse':
      return context.loc.t('relationSpouse');
    case 'child':
      return context.loc.t('relationChild');
    case 'other':
      return context.loc.t('relationOther');
    default:
      return key == null || key.isEmpty
          ? context.loc.t('relationOther')
          : key;
  }
}

String _formatDoseText(Map<String, dynamic>? medicine) {
  if (medicine == null) return '';
  final dosage = medicine['dosage'];
  final unit = medicine['unit'] as String? ?? '';
  if (dosage == null) return unit;
  return '$dosage $unit'.trim();
}

String _formatTimeLabels(BuildContext context, List<String> times) {
  if (times.isEmpty) return '';
  final labels = times.map((time) {
    switch (time) {
      case 'morning':
        return context.loc.t('morning');
      case 'noon':
        return context.loc.t('noon');
      case 'evening':
        return context.loc.t('evening');
      case 'night':
        return context.loc.t('night');
      default:
        return time;
    }
  }).toList();
  return labels.join(', ');
}

class _HomeAppBarTitle extends StatelessWidget {
  final String? name;
  final String role;
  final Map<String, bool> roles;
  final String uid;

  const _HomeAppBarTitle({
    required this.name,
    required this.role,
    required this.roles,
    required this.uid,
  });

  @override
  Widget build(BuildContext context) {
    final isPatient = role == UserProfileRepository.rolePatient;
    final hasMultipleRoles = roles.length > 1;

    return Row(
      children: [
        const SizedBox(width: 8),
        CircleAvatar(
          radius: 18,
          backgroundColor: Colors.teal[100],
          child: Icon(
            isPatient ? Icons.healing : Icons.volunteer_activism,
            color: Colors.teal[700],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name != null && name!.isNotEmpty
                    ? context.loc.t(
                        'welcomeName',
                        params: {'name': name!},
                      )
                    : context.loc.t('welcome'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(
                    Icons.medication,
                    size: 16,
                    color: Colors.teal[700],
                  ),
                  const SizedBox(width: 6),
                  if (isPatient)
                    StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('patients')
                          .doc(uid)
                          .snapshots(),
                      builder: (context, snapshot) {
                        final publicId =
                            snapshot.data?.data()?['publicId'] as String?;
                        return _buildRoleChip(
                          context,
                          label: _buildRoleLabelText(
                            context,
                            role,
                            publicId,
                          ),
                          hasMultipleRoles: hasMultipleRoles,
                        );
                      },
                    )
                  else
                    _buildRoleChip(
                      context,
                      label: _buildRoleLabelText(context, role, null),
                      hasMultipleRoles: hasMultipleRoles,
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _buildRoleLabelText(
    BuildContext context,
    String role,
    String? publicId,
  ) {
    final base = role == UserProfileRepository.rolePatient
        ? context.loc.t('patient')
        : context.loc.t('family');
    if (role == UserProfileRepository.rolePatient &&
        publicId != null &&
        publicId.isNotEmpty) {
      return '$base $_roleSeparator $publicId';
    }
    return base;
  }

  Widget _buildRoleChip(
    BuildContext context, {
    required String label,
    required bool hasMultipleRoles,
  }) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.teal[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.teal[700],
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (hasMultipleRoles) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.expand_more,
              size: 16,
              color: Colors.teal[700],
            ),
          ],
        ],
      ),
    );

    if (!hasMultipleRoles) return chip;
    return PopupMenuButton<String>(
      tooltip: context.loc.t('switchRole'),
      onSelected: (value) => _switchRole(context, uid, role, value),
      itemBuilder: (context) => _buildRoleMenuItems(context, roles),
      child: chip,
    );
  }
}

class _PendingRequestsAction extends StatelessWidget {
  final UserProfileRepository profileRepo;
  final String patientUid;

  const _PendingRequestsAction({
    required this.profileRepo,
    required this.patientUid,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: profileRepo.watchPendingConnectionsForPatient(patientUid),
      builder: (context, connectionSnapshot) {
        final connectionCount = connectionSnapshot.data?.docs.length ?? 0;
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: profileRepo.watchPendingMedicineRequestsForPatient(patientUid),
          builder: (context, requestSnapshot) {
            final requestCount = requestSnapshot.data?.docs.length ?? 0;
            final pendingCount = connectionCount + requestCount;
            return IconButton(
              tooltip: context.loc.t('requestsInbox'),
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.notifications_outlined),
                  if (pendingCount > 0)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(minWidth: 16),
                        child: Text(
                          pendingCount > 9 ? '9+' : pendingCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  builder: (_) => _PendingRequestsSheet(
                    profileRepo: profileRepo,
                    patientUid: patientUid,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _PendingRequestsSheet extends StatelessWidget {
  final UserProfileRepository profileRepo;
  final String patientUid;

  const _PendingRequestsSheet({
    required this.profileRepo,
    required this.patientUid,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.loc.t('requestsInbox'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 420,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.loc.t('connectionRequests'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _PendingConnectionList(
                      profileRepo: profileRepo,
                      patientUid: patientUid,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      context.loc.t('medicineRequests'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _PendingMedicineRequestList(
                      profileRepo: profileRepo,
                      patientUid: patientUid,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingConnectionList extends StatelessWidget {
  final UserProfileRepository profileRepo;
  final String patientUid;

  const _PendingConnectionList({
    required this.profileRepo,
    required this.patientUid,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: profileRepo.watchPendingConnectionsForPatient(patientUid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text(context.loc.t('failedLoad')));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(context.loc.t('noPendingRequests')),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            return _ConnectionRequestTile(
              profileRepo: profileRepo,
              connectionId: doc.id,
              familyMemberUid: data['familyMemberUid'] as String? ?? '',
              relation: data['relation'] as String?,
            );
          },
        );
      },
    );
  }
}

class _PendingMedicineRequestList extends StatelessWidget {
  final UserProfileRepository profileRepo;
  final String patientUid;

  const _PendingMedicineRequestList({
    required this.profileRepo,
    required this.patientUid,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: profileRepo.watchPendingMedicineRequestsForPatient(patientUid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text(context.loc.t('failedLoad')));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(context.loc.t('noMedicineRequests')),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            return _MedicineRequestTile(
              profileRepo: profileRepo,
              requestId: doc.id,
              familyMemberUid: data['familyMemberUid'] as String? ?? '',
              medicine: data['medicine'] as Map<String, dynamic>?,
            );
          },
        );
      },
    );
  }
}

class _ConnectionRequestTile extends StatelessWidget {
  final UserProfileRepository profileRepo;
  final String connectionId;
  final String familyMemberUid;
  final String? relation;

  const _ConnectionRequestTile({
    required this.profileRepo,
    required this.connectionId,
    required this.familyMemberUid,
    required this.relation,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: profileRepo.getProfile(familyMemberUid),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final name = profile?['name'] as String?;
        final title = (name != null && name.isNotEmpty)
            ? name
            : familyMemberUid;

        return ListTile(
          title: Text(title),
          subtitle: Text(_relationLabel(context, relation)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () async {
                  try {
                    await profileRepo.approveConnection(connectionId);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(context.loc.t('connectionApproved')),
                      ),
                    );
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(context.loc.t('failedSave'))),
                    );
                  }
                },
                child: Text(context.loc.t('accept')),
              ),
              TextButton(
                onPressed: () async {
                  try {
                    await profileRepo.rejectConnection(connectionId);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(context.loc.t('connectionRejected')),
                      ),
                    );
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(context.loc.t('failedSave'))),
                    );
                  }
                },
                child: Text(context.loc.t('reject')),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MedicineRequestTile extends StatelessWidget {
  final UserProfileRepository profileRepo;
  final String requestId;
  final String familyMemberUid;
  final Map<String, dynamic>? medicine;

  const _MedicineRequestTile({
    required this.profileRepo,
    required this.requestId,
    required this.familyMemberUid,
    required this.medicine,
  });

  @override
  Widget build(BuildContext context) {
    final medName = medicine?['name'] as String? ?? context.loc.t('medicineName');
    final doseText = _formatDoseText(medicine);
    final times =
        (medicine?['timesOfDay'] as List?)?.cast<String>() ?? <String>[];
    final timeLabel = _formatTimeLabels(context, times);
    final details = [
      if (doseText.isNotEmpty) doseText,
      if (timeLabel.isNotEmpty) timeLabel,
    ].join(' $_roleSeparator ');

    return FutureBuilder<Map<String, dynamic>?>(
      future: profileRepo.getProfile(familyMemberUid),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final name = profile?['name'] as String?;
        final requester = (name != null && name.isNotEmpty)
            ? name
            : familyMemberUid;

        return ListTile(
          title: Text(medName),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.loc.t('requestedBy', params: {'name': requester}),
              ),
              if (details.isNotEmpty) Text(details),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () async {
                  try {
                    await profileRepo.approveMedicineRequest(
                      requestId: requestId,
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text(context.loc.t('medicineRequestApproved')),
                      ),
                    );
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(context.loc.t('failedSave'))),
                    );
                  }
                },
                child: Text(context.loc.t('accept')),
              ),
              TextButton(
                onPressed: () async {
                  try {
                    await profileRepo.rejectMedicineRequest(requestId);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text(context.loc.t('medicineRequestRejected')),
                      ),
                    );
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(context.loc.t('failedSave'))),
                    );
                  }
                },
                child: Text(context.loc.t('reject')),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PatientHomeScreen extends StatelessWidget {
  final String role;
  final String? name;
  final Map<String, bool> roles;

  const _PatientHomeScreen({
    required this.role,
    this.name,
    required this.roles,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final user = auth.user;
    final uid = user?.uid;
    if (uid == null) {
      return Scaffold(
        body: Center(child: Text(context.loc.t('signInToView'))),
      );
    }

    final profileRepo = UserProfileRepository();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          titleSpacing: 0,
          title: _HomeAppBarTitle(
            name: name,
            role: role,
            roles: roles,
            uid: uid,
          ),
          actions: [
            _PendingRequestsAction(
              profileRepo: profileRepo,
              patientUid: uid,
            ),
            IconButton(
              icon: const Icon(Icons.account_circle_outlined),
              tooltip: context.loc.t('profile'),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              key: const Key('logoutIcon'),
              tooltip: context.loc.t('logout'),
              onPressed: () async {
                await context.read<AuthNotifier>().signOut();
                // Navigate to RootGate which will redirect to LoginScreen
                // ignore: use_build_context_synchronously
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const RootGate()),
                  (route) => false,
                );
              },
            ),
          ],
          bottom: TabBar(
            labelColor: Colors.black87,
            indicatorColor: Color(0xFF2EC4B6),
            tabs: [
              Tab(text: context.loc.t('today')),
              Tab(text: context.loc.t('allMedicines')),
            ],
          ),
        ),
        /*body: TabBarView(
          children: [
            _TodayTab(role: role, name: name, userEmail: user?.email),
            const _AllMedicinesTab(),
          ],
        ),*/
        body: TabBarView(
          children: [
            TodayMedicineTab(role: role, name: name, userEmail: user?.email),
            const _AllMedicinesTab(),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          tooltip: context.loc.t('addMedicine'),
          backgroundColor: const Color(0xFF2EC4B6),
          foregroundColor: Colors.white,
          onPressed: () => Navigator.of(context).pushNamed('/add-medicine'),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}

class _FamilyHomeScreen extends StatefulWidget {
  final String role;
  final String? name;
  final Map<String, bool> roles;

  const _FamilyHomeScreen({
    required this.role,
    this.name,
    required this.roles,
  });

  @override
  State<_FamilyHomeScreen> createState() => _FamilyHomeScreenState();
}

class _FamilyHomeScreenState extends State<_FamilyHomeScreen> {
  bool _addingRole = false;

  Future<void> _addPatientRole() async {
    if (_addingRole) return;
    setState(() => _addingRole = true);
    try {
      await context.read<AuthNotifier>().addUserRole(
            UserProfileRepository.rolePatient,
          );
      final user = context.read<AuthNotifier>().user;
      if (user != null) {
        await RoleModeStorage.setSelectedRole(
          user.uid,
          UserProfileRepository.roleFamilyMember,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.loc.t('patientRoleAdded'))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.loc.t('failedSave'))),
      );
    } finally {
      if (mounted) {
        setState(() => _addingRole = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final user = auth.user;
    if (user == null) {
      return Scaffold(
        body: Center(child: Text(context.loc.t('signInToView'))),
      );
    }

    final profileRepo = UserProfileRepository();
    final canAddPatient =
        widget.roles[UserProfileRepository.rolePatient] != true;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        titleSpacing: 0,
        title: _HomeAppBarTitle(
          name: widget.name,
          role: widget.role,
          roles: widget.roles,
          uid: user.uid,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: context.loc.t('profile'),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            key: const Key('logoutIcon'),
            tooltip: context.loc.t('logout'),
            onPressed: () async {
              await context.read<AuthNotifier>().signOut();
              // Navigate to RootGate which will redirect to LoginScreen
              // ignore: use_build_context_synchronously
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const RootGate()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.loc.t('connectedPatients'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            if (canAddPatient) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _addingRole ? null : _addPatientRole,
                icon: _addingRole
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.medication_outlined),
                label: Text(context.loc.t('alsoTakeMedicines')),
              ),
            ],
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: profileRepo.watchApprovedConnectionsForFamily(user.uid),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text(context.loc.t('failedLoad')));
                  }

                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return Center(
                      child: Text(context.loc.t('noApprovedConnections')),
                    );
                  }

                  return ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data();
                      return _ApprovedConnectionTile(
                        profileRepo: profileRepo,
                        patientUid: data['patientUid'] as String? ?? '',
                        relation: data['relation'] as String?,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ApprovedConnectionTile extends StatelessWidget {
  final UserProfileRepository profileRepo;
  final String patientUid;
  final String? relation;

  const _ApprovedConnectionTile({
    required this.profileRepo,
    required this.patientUid,
    required this.relation,
  });

  Future<_PatientLabel> _loadPatientLabel() async {
    final profile = await profileRepo.getProfile(patientUid);
    final patientDoc = await FirebaseFirestore.instance
        .collection('patients')
        .doc(patientUid)
        .get();
    final publicId = patientDoc.data()?['publicId'] as String?;
    final name = profile?['name'] as String?;
    return _PatientLabel(name: name, publicId: publicId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_PatientLabel>(
      future: _loadPatientLabel(),
      builder: (context, snapshot) {
        final label = snapshot.data;
        final title = (label?.name != null && label!.name!.isNotEmpty)
            ? label.name!
            : (label?.publicId ?? context.loc.t('patient'));
        final publicId = label?.publicId;
        final subtitleParts = <String>[
          if (publicId != null && publicId.isNotEmpty) publicId,
          if (relation != null && relation!.isNotEmpty)
            _relationLabel(context, relation),
        ];
        final subtitle = subtitleParts.join(' $_roleSeparator ');

        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: patientUid.isEmpty
                      ? null
                      : () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => AddMedicineScreen(
                                requestOnly: true,
                                patientUid: patientUid,
                                patientName: label?.name,
                                patientPublicId: publicId,
                              ),
                            ),
                          );
                        },
                  icon: const Icon(Icons.add),
                  label: Text(context.loc.t('requestAddMedicine')),
                ),
                const SizedBox(height: 12),
                Text(
                  context.loc.t('todaysMedicines'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                _PatientTodayMedicines(patientUid: patientUid),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PatientTodayMedicines extends StatelessWidget {
  final String patientUid;

  const _PatientTodayMedicines({required this.patientUid});

  @override
  Widget build(BuildContext context) {
    if (patientUid.isEmpty) {
      return Text(context.loc.t('noMedicinesToday'));
    }

    final stream = FirebaseFirestore.instance
        .collection('users')
        .doc(patientUid)
        .collection('medicines')
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Text(context.loc.t('failedLoad'));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Text(context.loc.t('noMedicinesToday'));
        }

        final now = DateTime.now();
        final todayDate = _todayDateKey(now);
        final doses = _buildTodayDoses(docs, now, todayDate, context);

        if (doses.isEmpty) {
          return Text(context.loc.t('noMedicinesToday'));
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: doses.length,
          itemBuilder: (context, index) {
            final dose = doses[index];
            return MedicineCard(
              name: dose.name,
              dose: dose.dose,
              time: dose.timeLabel,
              status: dose.status,
              isTaken: dose.isTaken,
              showDivider: index != doses.length - 1,
            );
          },
        );
      },
    );
  }
}

class _TodayDose {
  final String name;
  final String dose;
  final String timeLabel;
  final TimeOfDay timeValue;
  final String status;
  final bool isTaken;

  const _TodayDose({
    required this.name,
    required this.dose,
    required this.timeLabel,
    required this.timeValue,
    required this.status,
    required this.isTaken,
  });
}

String _todayDateKey(DateTime now) {
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

List<_TodayDose> _buildTodayDoses(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  DateTime now,
  String todayDate,
  BuildContext context,
) {
  final doses = <_TodayDose>[];
  final currentTime = TimeOfDay.fromDateTime(now);

  for (final doc in docs) {
    final data = doc.data();
    if (!_isMedicineScheduledToday(data, now)) continue;

    final name = data['name'] as String? ?? 'Unnamed';
    final dosage = data['dosage'];
    final unit = data['unit'] as String? ?? '';
    final doseText = dosage != null ? '$dosage $unit' : unit;
    final times = (data['timesOfDay'] as List?)?.cast<String>() ?? [];

    final dailyTaken = data['dailyTaken'];
    final takenTimes = <String>[];
    if (dailyTaken is Map && dailyTaken[todayDate] is List) {
      takenTimes.addAll(List<String>.from(dailyTaken[todayDate] as List));
    }

    for (final timeKey in times) {
      final timeValue = _parseTimeKey(timeKey);
      if (timeValue == null) continue;
      final isTaken = takenTimes.contains(timeKey);
      final status = isTaken ? 'taken' : _getDoseStatus(timeKey, currentTime);
      doses.add(
        _TodayDose(
          name: name,
          dose: doseText,
          timeLabel: _timeLabel(context, timeKey),
          timeValue: timeValue,
          status: status,
          isTaken: isTaken,
        ),
      );
    }
  }

  doses.sort((a, b) {
    final aMin = a.timeValue.hour * 60 + a.timeValue.minute;
    final bMin = b.timeValue.hour * 60 + b.timeValue.minute;
    return aMin - bMin;
  });

  return doses;
}

bool _isMedicineScheduledToday(Map<String, dynamic> data, DateTime now) {
  final rawDays = data['days'] as List?;
  final daysSet = _normalizeDays(rawDays);
  if (!daysSet.contains(now.weekday)) return false;

  final startTimestamp = data['startDate'] as Timestamp?;
  final endTimestamp = data['endDate'] as Timestamp?;
  final nowDate = DateTime(now.year, now.month, now.day);

  final startDate = startTimestamp?.toDate();
  final endDate = endTimestamp?.toDate();

  final startOk = startDate == null ||
      !nowDate.isBefore(DateTime(startDate.year, startDate.month, startDate.day));
  final endOk = endDate == null ||
      !nowDate.isAfter(DateTime(endDate.year, endDate.month, endDate.day));

  return startOk && endOk;
}

Set<int> _normalizeDays(List? rawDays) {
  final daysSet = <int>{};
  if (rawDays == null) return daysSet;
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
  return daysSet;
}

TimeOfDay? _parseTimeKey(String timeKey) {
  switch (timeKey) {
    case 'morning':
      return const TimeOfDay(hour: 5, minute: 0);
    case 'noon':
      return const TimeOfDay(hour: 12, minute: 0);
    case 'evening':
      return const TimeOfDay(hour: 17, minute: 0);
    case 'night':
      return const TimeOfDay(hour: 19, minute: 0);
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

String _timeLabel(BuildContext context, String timeKey) {
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

String _getDoseStatus(String timeKey, TimeOfDay now) {
  TimeOfDay start;
  TimeOfDay end;
  var isNight = false;

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
      final medTime = _parseTimeKey(timeKey);
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
    if (nowMin < startMin) return 'upcoming';
    if (nowMin >= startMin || nowMin <= endMin) return 'due';
    return 'late';
  } else {
    if (nowMin < startMin) return 'upcoming';
    if (nowMin <= endMin) return 'due';
    return 'late';
  }
}

class _PatientLabel {
  final String? name;
  final String? publicId;
  const _PatientLabel({this.name, this.publicId});
}

/*
class _TodayTab extends StatelessWidget {
  final String role;
  final String? name;
  final String? userEmail;

  const _TodayTab({required this.role, this.name, this.userEmail});

  @override
  Widget build(BuildContext context) {
    final isPatient = role == 'patient';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.teal[300]!, Colors.teal[600]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF000000).withValues(alpha: 0.13),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(
                isPatient ? Icons.medication_liquid : Icons.family_restroom,
                size: 44,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              name != null && name!.isNotEmpty
                  ? context.loc.t('welcomeName', params: {'name': name!})
                  : context.loc.t('welcome'),
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (userEmail != null)
              Text(
                userEmail!,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
              ),
            const SizedBox(height: 40),
            Text(
              'Your medication management starts here!',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
*/
class _AllMedicinesTab extends StatefulWidget {
  const _AllMedicinesTab();

  @override
  State<_AllMedicinesTab> createState() => _AllMedicinesTabState();
}

class _AllMedicinesTabState extends State<_AllMedicinesTab> {
  String _searchQuery = '';
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Center(child: Text(context.loc.t('signInToView')));
    }

    final stream = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('medicines')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Column(
      children: [
        Padding(padding: const EdgeInsets.all(12), child: _searchBar()),
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

              final filtered = docs.where((doc) {
                final data = doc.data();
                final targetName = data['name'] as String? ?? '';
                final nameLower = targetName.toLowerCase();
                final queryLower = _searchQuery.toLowerCase();
                return _searchQuery.isEmpty || nameLower.contains(queryLower);
              }).toList();

              if (filtered.isEmpty) {
                return Center(child: Text(context.loc.t('noResults')));
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final doc = filtered[index];
                  final data = doc.data();
                  final name = data['name'] as String? ?? 'Unnamed';
                  final dosage = data['dosage'];
                  final unit = data['unit'] as String? ?? '';
                  final dosageText = dosage != null ? '$dosage $unit' : unit;
                  final times =
                      (data['timesOfDay'] as List?)?.cast<String>() ?? [];
                  final schedule = _formatSchedule(times);

                  return Dismissible(
                    key: ValueKey(doc.id),
                    direction: DismissDirection.horizontal,
                    confirmDismiss: (direction) async {
                      return await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text(context.loc.t('deleteMedicine')),
                              content: Text(
                                context.loc.t(
                                  'deleteConfirm',
                                  params: {'name': name},
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(false),
                                  child: Text(context.loc.t('cancel')),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(true),
                                  child: Text(context.loc.t('delete')),
                                ),
                              ],
                            ),
                          ) ??
                          false;
                    },
                    onDismissed: (_) async {
                      try {
                        await doc.reference.delete();
                        // ignore: use_build_context_synchronously
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('"$name" deleted')),
                        );
                      } catch (e) {
                        // ignore: use_build_context_synchronously
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            // ignore: use_build_context_synchronously
                            content: Text(context.loc.t('failedLoad')),
                          ),
                        );
                      }
                    },
                    child: GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => MedicineDetailsScreen(
                              docId: doc.id,
                              data: data,
                            ),
                          ),
                        );
                      },
                      child: MedicineCard(
                        name: name,
                        dose: dosageText,
                        time: schedule,
                        status: null,
                        isTaken: false,
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.edit,
                            color: Colors.black87,
                          ),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => EditMedicineScreen(
                                  docId: doc.id,
                                  initialData: data,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _searchBar() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search),
        hintText: context.loc.t('searchHint'),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onChanged: (value) => setState(() {
        _searchQuery = value;
      }),
    );
  }

  String _formatSchedule(List<String> times) {
    if (times.isEmpty) return context.loc.t('noSchedule');
    if (times.length == 1) return context.loc.t('onceDaily');
    if (times.length == 2) return context.loc.t('twiceDaily');
    return context.loc.t(
      'timesPerDay',
      params: {'count': times.length.toString()},
    );
  }
}
