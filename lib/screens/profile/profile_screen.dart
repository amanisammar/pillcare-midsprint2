import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/auth_notifier.dart';
import '../../auth/auth_status.dart';
import '../../data/user_profile_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../models/app_user.dart';
import '../../root_gate.dart';
import '../../services/profile_service.dart';
import '../../theme/theme_controller.dart';
import '../../widgets/profile/profile_achievements_row.dart';
import '../../widgets/profile/profile_care_circle_section.dart';
import '../../widgets/profile/profile_header.dart';
import '../../widgets/profile/profile_settings_list.dart';
import '../../widgets/profile/profile_stats_grid.dart';
import '../../widgets/gamification_info_sheet.dart';
import '../auth/login_screen.dart';
import '../history/history_7days_screen.dart';
import '../settings/about_screen.dart';
import '../settings/help_support_screen.dart';
import '../settings/notifications_settings_screen.dart';
import '../settings/privacy_settings_screen.dart';
import '../onboarding/family_member_setup_screen.dart';
import 'edit_profile_sheet.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileService _service = ProfileService();
  final UserProfileRepository _profileRepo = UserProfileRepository();
  Map<String, bool>? _rolesOverride;

  Future<({int taken, int missed, double adherence})> _loadWeeklyStats(
    String uid,
  ) async {
    // Use the new HistoryService-based method for accurate counts
    return await _service.getWeeklyAdherence(uid);
  }

  bool _rolesMatch(Map<String, bool>? left, Map<String, bool>? right) {
    if (left == null || right == null) return false;
    if (left.length != right.length) return false;
    for (final entry in left.entries) {
      if (right[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    if (auth.status == AuthStatus.unauthenticated) {
      return const LoginScreen();
    }
    final user = auth.user;
    if (user == null) {
      return const LoginScreen();
    }

    return StreamBuilder<AppUser?>(
      stream: _service.getUserStream(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(context.loc.t('couldNotLoadWeeklyStats')),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: Text(context.loc.t('retry')),
                  ),
                ],
              ),
            ),
          );
        }

        final appUser = snapshot.data;
        if (appUser == null) {
          return Scaffold(
            body: Center(
              child: Text(context.loc.t('notAvailable')),
            ), // Should not happen
          );
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF7F4EF),
          appBar: AppBar(
            title: Text(context.loc.t('profile')),
            centerTitle: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: () async => setState(() {}),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ProfileHeader(
                      user: appUser,
                      onEdit: () =>
                          EditProfileSheet.show(context, appUser, _service),
                      onAvatarTap: () => EditProfileSheet.show(
                        context,
                        appUser,
                        _service,
                        focusAvatar: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ProfileStatsGrid(
                            points: appUser.points,
                            streakDays: appUser.streakDays,
                            badgesCount: appUser.badges.length,
                            level: appUser.level,
                            progress: appUser.levelProgress,
                            nextLevelPoints: appUser.nextLevelPoints,
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () => GamificationInfoSheet.show(context),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF23C3AE),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF23C3AE,
                                  ).withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.info_outline,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    FutureBuilder<({int taken, int missed, double adherence})>(
                      future: _loadWeeklyStats(appUser.uid),
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const _CardShell(height: 160);
                        }
                        if (snap.hasError) {
                          return _ErrorCard(
                            message: context.loc.t('couldNotLoadWeeklyStats'),
                          );
                        }
                        final data =
                            snap.data ?? (taken: 0, missed: 0, adherence: 0.0);
                        final total = data.taken + data.missed;
                        if (total == 0) {
                          return _EmptyCard(
                            title: context.loc.t('trackingTitle'),
                            message: context.loc.t('trackingEmpty'),
                          );
                        }
                        final adherence = data.adherence
                            .clamp(0, 100)
                            .toDouble();
                        return _TrackingCard(
                          taken: data.taken,
                          missed: data.missed,
                          adherence: adherence,
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    ProfileAchievementsRow(badgeIds: appUser.badges),
                    const SizedBox(height: 16),
                    const ProfileCareCircleSection(),
                    const SizedBox(height: 16),
                    StreamBuilder<Map<String, dynamic>?>(
                      stream: _profileRepo.getUserProfileStream(appUser.uid),
                      builder: (context, profileSnapshot) {
                        if (profileSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const _CardShell(height: 96);
                        }
                        if (profileSnapshot.hasError) {
                          return _ErrorCard(
                            message: context.loc.t('failedLoad'),
                          );
                        }

                        final rolesFromProfile =
                            UserProfileRepository.normalizeRoles(
                              profileSnapshot.data,
                            );
                        final roles = _rolesOverride ?? rolesFromProfile;
                        if (_rolesOverride != null &&
                            _rolesMatch(_rolesOverride, rolesFromProfile)) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!mounted) return;
                            if (_rolesOverride != null &&
                                _rolesMatch(_rolesOverride, rolesFromProfile)) {
                              setState(() => _rolesOverride = null);
                            }
                          });
                        }

                        final canAddRole = _availableRoles(roles).isNotEmpty;

                        return _RolesSection(
                          roles: roles,
                          onAddRole: canAddRole
                              ? () => _showAddRoleSheet(context, roles)
                              : null,
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _profileRepo.watchConnectionsForFamily(
                        appUser.uid,
                      ),
                      builder: (context, connectionSnapshot) {
                        if (connectionSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const _CardShell(height: 120);
                        }
                        if (connectionSnapshot.hasError) {
                          return _ErrorCard(
                            message: context.loc.t('failedLoad'),
                          );
                        }

                        final docs = connectionSnapshot.data?.docs ?? [];
                        if (docs.isEmpty) {
                          return const SizedBox.shrink();
                        }

                        return _FamilyConnectionsSection(
                          profileRepo: _profileRepo,
                          connections: docs,
                          relationLabel: _relationLabel,
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    ProfileSettingsList(
                      shareWithFamily: appUser.shareWithFamily,
                      onToggleShare: (val) =>
                          _service.updateShareWithFamily(appUser.uid, val),
                      onOpenNotifications: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const NotificationsSettingsScreen(),
                        ),
                      ),
                      onOpenTheme: () => _openThemeSheet(context),
                      onOpenPrivacy: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const PrivacySettingsScreen(),
                        ),
                      ),
                      onOpenHelp: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const HelpSupportScreen(),
                        ),
                      ),
                      onOpenAbout: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AboutScreen()),
                      ),
                      onOpenHistory: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const History7DaysScreen(),
                        ),
                      ),
                      onOpenDelete: () => _confirmDeleteAccount(context),
                      onSignOut: () async {
                        await context.read<AuthNotifier>().signOut();
                        if (!context.mounted) return;
                        // Navigate to RootGate which will redirect to LoginScreen
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const RootGate()),
                          (route) => false,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(context.loc.t('deleteAccount')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.loc.t('deleteAccountConfirm'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(context.loc.t('deleteAccountWarning')),
            const SizedBox(height: 8),
            Text('• ${context.loc.t('allMedicines')}'),
            Text('• ${context.loc.t('doseLogs')}'),
            Text(
              '• ${context.loc.t('profile')} & ${context.loc.t('settings')}',
            ),
            Text('• ${context.loc.t('personalInformation')}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.loc.t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(context.loc.t('deleteForever')),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await _deleteAccount(context);
    }
  }

  Future<void> _deleteAccount(BuildContext context) async {
    try {
      final auth = context.read<AuthNotifier>();
      final user = auth.user;
      if (user == null) return;

      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Deleting account...'),
                ],
              ),
            ),
          ),
        ),
      );

      // Delete Firestore user data
      await _service.deleteUserData(user.uid);

      // Delete Firebase Auth account
      await user.delete();

      // Sign out
      await auth.signOut();

      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        // Navigate to RootGate which will redirect to LoginScreen
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const RootGate()),
          (route) => false,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account deleted successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete account: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _openThemeSheet(BuildContext context) async {
    final themeController = context.read<ThemeController>();
    final choices = themeController.choices;
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                context.loc.t('theme'),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              ...choices.map(
                (c) => ListTile(
                  leading: CircleAvatar(backgroundColor: c.primary),
                  title: Text(c.name),
                  trailing: themeController.themeKey == c.key
                      ? const Icon(Icons.check, color: Colors.teal)
                      : null,
                  onTap: () {
                    themeController.setTheme(c.key);
                    Navigator.of(context).pop();
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  List<_RoleOption> _availableRoles(Map<String, bool> roles) {
    final options = <_RoleOption>[];
    if (roles[UserProfileRepository.rolePatient] != true) {
      options.add(
        _RoleOption(
          key: UserProfileRepository.rolePatient,
          label: context.loc.t('patient'),
          icon: Icons.medication_outlined,
          requiresSetup: false,
        ),
      );
    }
    if (roles[UserProfileRepository.roleFamilyMember] != true) {
      options.add(
        _RoleOption(
          key: UserProfileRepository.roleFamilyMember,
          label: context.loc.t('family'),
          icon: Icons.groups_2_outlined,
          requiresSetup: true,
        ),
      );
    }
    return options;
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

  void _showAddRoleSheet(BuildContext context, Map<String, bool> roles) {
    final options = _availableRoles(roles);
    if (options.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.loc.t('allRolesAdded'))));
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                context.loc.t('chooseRoleToAdd'),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              ...options.map(
                (option) => ListTile(
                  leading: Icon(option.icon, color: Colors.teal),
                  title: Text(option.label),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await _handleAddRole(option, roles);
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleAddRole(
    _RoleOption option,
    Map<String, bool> currentRoles,
  ) async {
    if (currentRoles[option.key] == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.loc.t('roleAlreadyAdded'))),
      );
      return;
    }

    final auth = context.read<AuthNotifier>();
    final user = auth.user;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.loc.t('pleaseSignIn'))));
      return;
    }

    try {
      if (option.requiresSetup) {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const FamilyMemberSetupScreen()),
        );
        if (!mounted) return;
        final refreshedProfile = await _profileRepo.getUserProfile(user.uid);
        if (!mounted) return;
        if (refreshedProfile != null) {
          setState(
            () => _rolesOverride = UserProfileRepository.normalizeRoles(
              refreshedProfile,
            ),
          );
        }
        return;
      }

      await auth.addUserRole(option.key);
      if (!mounted) return;
      var updatedRoles = <String, bool>{...currentRoles, option.key: true};
      final refreshedProfile = await _profileRepo.getUserProfile(user.uid);
      if (refreshedProfile != null) {
        updatedRoles = UserProfileRepository.normalizeRoles(refreshedProfile);
      }
      if (!mounted) return;
      setState(() => _rolesOverride = updatedRoles);
      if (option.requiresSetup) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const FamilyMemberSetupScreen()),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.loc.t('roleAdded'))));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.loc.t('failedAddRole'))));
    }
  }
}

class _RoleOption {
  final String key;
  final String label;
  final IconData icon;
  final bool requiresSetup;

  const _RoleOption({
    required this.key,
    required this.label,
    required this.icon,
    required this.requiresSetup,
  });
}

class _RolesSection extends StatelessWidget {
  final Map<String, bool> roles;
  final VoidCallback? onAddRole;

  const _RolesSection({required this.roles, required this.onAddRole});

  List<String> _orderedRoles() {
    const known = [
      UserProfileRepository.rolePatient,
      UserProfileRepository.roleFamilyMember,
    ];
    final ordered = <String>[
      for (final key in known)
        if (roles[key] == true) key,
    ];
    for (final entry in roles.entries) {
      if (entry.value && !ordered.contains(entry.key)) {
        ordered.add(entry.key);
      }
    }
    return ordered;
  }

  String _labelForRole(BuildContext context, String key) {
    if (key == UserProfileRepository.rolePatient) {
      return context.loc.t('patient');
    }
    if (key == UserProfileRepository.roleFamilyMember) {
      return context.loc.t('family');
    }
    return key;
  }

  @override
  Widget build(BuildContext context) {
    final roleList = _orderedRoles();
    final canAddRole = onAddRole != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.badge_outlined, color: Colors.teal),
              const SizedBox(width: 8),
              Text(
                context.loc.t('roles'),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: onAddRole,
                icon: const Icon(Icons.add),
                label: Text(context.loc.t('addRole')),
              ),
            ],
          ),
          if (roleList.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(context.loc.t('notAvailable')),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: roleList
                  .map(
                    (roleKey) => Chip(
                      label: Text(_labelForRole(context, roleKey)),
                      backgroundColor: Colors.teal[50],
                      labelStyle: TextStyle(
                        color: Colors.teal[800],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                  .toList(),
            ),
          if (!canAddRole)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                context.loc.t('allRolesAdded'),
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

class _FamilyConnectionsSection extends StatelessWidget {
  final UserProfileRepository profileRepo;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> connections;
  final String Function(BuildContext, String?) relationLabel;

  const _FamilyConnectionsSection({
    required this.profileRepo,
    required this.connections,
    required this.relationLabel,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = [...connections];
    sorted.sort((a, b) {
      final statusA = a.data()['status'] as String? ?? '';
      final statusB = b.data()['status'] as String? ?? '';
      if (statusA == statusB) return 0;
      if (statusA == 'pending') return -1;
      if (statusB == 'pending') return 1;
      return statusA.compareTo(statusB);
    });

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.link, color: Colors.teal),
              const SizedBox(width: 8),
              Text(
                context.loc.t('connectionRequests'),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sorted.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              return _FamilyConnectionTile(
                profileRepo: profileRepo,
                connection: sorted[index],
                relationLabel: relationLabel,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FamilyConnectionTile extends StatelessWidget {
  final UserProfileRepository profileRepo;
  final QueryDocumentSnapshot<Map<String, dynamic>> connection;
  final String Function(BuildContext, String?) relationLabel;

  const _FamilyConnectionTile({
    required this.profileRepo,
    required this.connection,
    required this.relationLabel,
  });

  Future<_ConnectionPatientLabel> _loadPatientLabel(
    Map<String, dynamic> data,
  ) async {
    final patientUid = data['patientUid'] as String? ?? '';
    String? publicId = data['patientPublicId'] as String?;
    if ((publicId == null || publicId.isEmpty) && patientUid.isNotEmpty) {
      final patientDoc = await FirebaseFirestore.instance
          .collection('patients')
          .doc(patientUid)
          .get();
      publicId = patientDoc.data()?['publicId'] as String?;
    }
    final profile = patientUid.isEmpty
        ? null
        : await profileRepo.getProfile(patientUid);
    final name = profile?['name'] as String?;
    return _ConnectionPatientLabel(name: name, publicId: publicId);
  }

  @override
  Widget build(BuildContext context) {
    final data = connection.data();
    final status = data['status'] as String? ?? 'pending';
    final isPending = status == 'pending';
    final relation = data['relation'] as String?;

    return FutureBuilder<_ConnectionPatientLabel>(
      future: _loadPatientLabel(data),
      builder: (context, snapshot) {
        final label = snapshot.data;
        final title = (label?.name != null && label!.name!.isNotEmpty)
            ? label.name!
            : (label?.publicId ?? context.loc.t('patient'));

        final subtitleParts = <String>[
          if (label?.publicId != null && label!.publicId!.isNotEmpty)
            label.publicId!,
          if (relation != null && relation.isNotEmpty)
            relationLabel(context, relation),
          isPending
              ? context.loc.t('connectionPendingStatus')
              : context.loc.t('connectionApprovedStatus'),
        ];

        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(title),
          subtitle: Text(subtitleParts.join(' - ')),
          trailing: isPending
              ? TextButton(
                  onPressed: () async {
                    try {
                      await profileRepo.cancelConnectionRequest(connection.id);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(context.loc.t('requestCancelled')),
                        ),
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(context.loc.t('failedCancelRequest')),
                        ),
                      );
                    }
                  },
                  child: Text(context.loc.t('cancelRequest')),
                )
              : null,
        );
      },
    );
  }
}

class _ConnectionPatientLabel {
  final String? name;
  final String? publicId;

  const _ConnectionPatientLabel({this.name, this.publicId});
}

class _CardShell extends StatelessWidget {
  final double height;
  const _CardShell({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
          TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: Text(context.loc.t('close')),
          ),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String title;
  final String message;
  const _EmptyCard({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.analytics_outlined, color: Colors.teal),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrackingCard extends StatelessWidget {
  final int taken;
  final int missed;
  final double adherence;
  const _TrackingCard({
    required this.taken,
    required this.missed,
    required this.adherence,
  });

  @override
  Widget build(BuildContext context) {
    final percent = adherence.clamp(0, 100).toStringAsFixed(0);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.loc.t('trackingTitle'),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _StatChip(
                label: context.loc.t('taken7d'),
                value: taken.toString(),
                color: Colors.green,
              ),
              const SizedBox(width: 12),
              _StatChip(
                label: context.loc.t('missed7d'),
                value: missed.toString(),
                color: Colors.redAccent,
              ),
              const SizedBox(width: 12),
              _StatChip(
                label: context.loc.t('adherence'),
                value: '$percent%',
                color: Colors.blue,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
