import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'auth/auth_notifier.dart';
import 'auth/auth_status.dart';
import 'data/user_profile_repository.dart';
import 'models/family_member_status.dart';
import 'services/role_mode_storage.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/onboarding/role_selection_screen.dart';

/// RootGate decides which screen to show based on auth status and profile.
class RootGate extends StatefulWidget {
  const RootGate({super.key});

  @override
  State<RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<RootGate> {
  final _profileRepo = UserProfileRepository();
  int _retryKey = 0;
  bool _ensuredProfile = false;
  String? _ensuredForUid;
  bool _ensuredPatientPublicId = false;
  String? _ensuredPatientForUid;
  bool _ensuredRoles = false;
  String? _ensuredRolesForUid;
  bool? _familyRoleTarget;
  String? _familyRoleTargetForUid;

  FamilyMemberStatus _resolveFamilyStatus(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> connections,
  ) {
    var hasPending = false;
    for (final doc in connections) {
      final status = doc.data()['status'] as String?;
      if (status == 'approved') return FamilyMemberStatus.active;
      if (status == 'pending') hasPending = true;
    }
    return hasPending ? FamilyMemberStatus.pending : FamilyMemberStatus.none;
  }

  void _syncFamilyRoleState({
    required String uid,
    required Map<String, bool> roles,
    required FamilyMemberStatus status,
  }) {
    final shouldHaveRole = status != FamilyMemberStatus.none;
    final hasRole =
        roles[UserProfileRepository.roleFamilyMember] == true;
    if (shouldHaveRole == hasRole) {
      _familyRoleTarget = null;
      _familyRoleTargetForUid = uid;
      return;
    }
    if (_familyRoleTargetForUid == uid &&
        _familyRoleTarget == shouldHaveRole) {
      return;
    }
    _familyRoleTargetForUid = uid;
    _familyRoleTarget = shouldHaveRole;
    _profileRepo.setUserRoleState(
      uid,
      UserProfileRepository.roleFamilyMember,
      shouldHaveRole,
    );
  }

  void _retry() {
    setState(() {
      _retryKey++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authNotifier = context.watch<AuthNotifier>();
    final authStatus = authNotifier.status;

    // App starting
    if (authStatus == AuthStatus.uninitialized ||
        authStatus == AuthStatus.authenticating) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Not logged in
    if (authStatus == AuthStatus.unauthenticated) {
      return const LoginScreen();
    }

    final user = authNotifier.user;
    if (user == null) {
      return const LoginScreen();
    }

    // Logged in -> check profile
    return StreamBuilder<Map<String, dynamic>?>(
      key: ValueKey(_retryKey),
      stream: _profileRepo.getUserProfileStream(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: _retry,
                child: const Text('Retry'),
              ),
            ),
          );
        }

        final profile = snapshot.data;

        // No profile yet -> role selection
        if (profile == null) {
          final uid = user.uid;
          final email = user.email ?? '';
          if (!_ensuredProfile || _ensuredForUid != uid) {
            _ensuredProfile = true;
            _ensuredForUid = uid;
            _profileRepo.ensureProfileExists(uid: uid, email: email);
          }
          return const RoleSelectionScreen();
        }

        final roles = UserProfileRepository.normalizeRoles(profile);
        final name = profile['name'] as String?;
        final uid = user.uid;

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _profileRepo.watchConnectionsForFamily(uid),
          builder: (context, connectionSnapshot) {
            if (connectionSnapshot.connectionState ==
                    ConnectionState.waiting &&
                connectionSnapshot.data == null) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (connectionSnapshot.hasError) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: _retry,
                    child: const Text('Retry'),
                  ),
                ),
              );
            }

            final connections = connectionSnapshot.data?.docs ?? [];
            final familyStatus = _resolveFamilyStatus(connections);
            _syncFamilyRoleState(
              uid: uid,
              roles: roles,
              status: familyStatus,
            );

            final resolvedRoles = <String, bool>{...roles};
            if (familyStatus == FamilyMemberStatus.none) {
              resolvedRoles.remove(UserProfileRepository.roleFamilyMember);
            } else {
              resolvedRoles[UserProfileRepository.roleFamilyMember] = true;
            }

            String? baseRole;
            if (resolvedRoles[UserProfileRepository.rolePatient] == true) {
              baseRole = UserProfileRepository.rolePatient;
            } else if (resolvedRoles[UserProfileRepository.roleFamilyMember] ==
                true) {
              baseRole = UserProfileRepository.roleFamilyMember;
            }

            if (baseRole == null || baseRole.isEmpty) {
              return const RoleSelectionScreen();
            }
            final resolvedBaseRole = baseRole;

            if (!_ensuredRoles || _ensuredRolesForUid != uid) {
              _ensuredRoles = true;
              _ensuredRolesForUid = uid;
              _profileRepo.ensureRolesConsistency(uid, profile);
            }

            if (resolvedRoles[UserProfileRepository.rolePatient] == true) {
              if (!_ensuredPatientPublicId || _ensuredPatientForUid != uid) {
                _ensuredPatientPublicId = true;
                _ensuredPatientForUid = uid;
                _profileRepo.ensurePatientPublicId(uid);
              }
            }

            if (resolvedRoles.length > 1) {
              return FutureBuilder<String?>(
                future: RoleModeStorage.getSelectedRole(user.uid),
                builder: (context, roleSnapshot) {
                  if (roleSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Scaffold(
                      body: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final preferredRole = roleSnapshot.data;
                  var selectedRole = preferredRole != null &&
                          resolvedRoles[preferredRole] == true
                      ? preferredRole
                      : resolvedBaseRole;

                  if (preferredRole != null &&
                      resolvedRoles[preferredRole] != true) {
                    RoleModeStorage.clearSelectedRole(user.uid);
                  }

                  final familyPending =
                      familyStatus == FamilyMemberStatus.pending;
                  if (familyPending &&
                      selectedRole ==
                          UserProfileRepository.roleFamilyMember &&
                      resolvedRoles[UserProfileRepository.rolePatient] ==
                          true) {
                    selectedRole = UserProfileRepository.rolePatient;
                    RoleModeStorage.clearSelectedRole(user.uid);
                  }

                  return HomeScreen(
                    role: selectedRole,
                    name: name,
                    roles: resolvedRoles,
                    familyMemberStatus: familyStatus,
                  );
                },
              );
            }

            // Auth + role OK
            return HomeScreen(
              role: resolvedBaseRole,
              name: name,
              roles: resolvedRoles,
              familyMemberStatus: familyStatus,
            );
          },
        );
        // For testing Add Medicine directly, you can temporarily use:
        // return const AddMedicineScreen();
      },
    );
  }
}
