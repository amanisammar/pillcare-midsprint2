import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'auth/auth_notifier.dart';
import 'auth/auth_status.dart';
import 'data/user_profile_repository.dart';
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
        final role = UserProfileRepository.resolvePrimaryRole(profile);
        final name = profile['name'] as String?;

        if (role == null || role.isEmpty) {
          return const RoleSelectionScreen();
        }

        final uid = user.uid;
        if (!_ensuredRoles || _ensuredRolesForUid != uid) {
          _ensuredRoles = true;
          _ensuredRolesForUid = uid;
          _profileRepo.ensureRolesConsistency(uid, profile);
        }

        if (roles[UserProfileRepository.rolePatient] == true) {
          if (!_ensuredPatientPublicId || _ensuredPatientForUid != uid) {
            _ensuredPatientPublicId = true;
            _ensuredPatientForUid = uid;
            _profileRepo.ensurePatientPublicId(uid);
          }
        }

        if (roles.length > 1) {
          return FutureBuilder<String?>(
            future: RoleModeStorage.getSelectedRole(user.uid),
            builder: (context, roleSnapshot) {
              if (roleSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              final preferredRole = roleSnapshot.data;
              final selectedRole = preferredRole != null &&
                      roles[preferredRole] == true
                  ? preferredRole
                  : role;

              if (preferredRole != null && roles[preferredRole] != true) {
                RoleModeStorage.clearSelectedRole(user.uid);
              }

              return HomeScreen(role: selectedRole, name: name, roles: roles);
            },
          );
        }

        // Auth + role OK
        return HomeScreen(role: role, name: name, roles: roles);
        // For testing Add Medicine directly, you can temporarily use:
        // return const AddMedicineScreen();
      },
    );
  }
}
