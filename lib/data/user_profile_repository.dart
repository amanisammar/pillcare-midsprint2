import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Repository for managing user profile data in Firestore.
class UserProfileRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _usersCollection = 'users';
  static const String _patientsCollection = 'patients';
  static const String _connectionsCollection = 'connections';
  static const String _publicIdsCollection = 'patientPublicIds';
  static const String _medicineRequestsCollection = 'medicineRequests';
  static const String rolePatient = 'patient';
  static const String roleFamilyMember = 'family_member';
  static const String legacyRoleFamily = 'family';
  static const String _publicIdPrefix = 'P-';

  /// Fetches user profile data from Firestore.
  /// Returns null if the profile doesn't exist.
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection(_usersCollection).doc(uid).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching user profile: $e');
      return null;
    }
  }

  /// Alias for getUserProfile for consistency with requirements.
  Future<Map<String, dynamic>?> getProfile(String uid) async {
    return getUserProfile(uid);
  }

  /// Creates a new user profile in Firestore.
  /// Role is initially empty and will be set later.
  Future<void> createUserProfile(
    String uid,
    String name,
    String email, {
    DateTime? birthDate,
  }) async {
    try {
      await _firestore.collection(_usersCollection).doc(uid).set({
        'name': name,
        'email': email,
        'role': '', // Empty initially, set later in role selection
        'roles': {rolePatient: false, roleFamilyMember: false},
        if (birthDate != null) 'birthDate': Timestamp.fromDate(birthDate),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error creating user profile: $e');
      rethrow;
    }
  }

  /// Ensures profile exists, creates it if missing.
  Future<void> ensureProfileExists({
    required String uid,
    required String email,
    String? name,
  }) async {
    try {
      final docRef = _firestore.collection(_usersCollection).doc(uid);
      final doc = await docRef.get();
      final trimmedEmail = email.trim();
      final trimmedName = name?.trim();
      final hasName = trimmedName != null && trimmedName.isNotEmpty;
      final hasEmail = trimmedEmail.isNotEmpty;
      if (!doc.exists) {
        final initialData = <String, Object?>{
          if (hasName) 'name': trimmedName,
          if (hasName) 'displayName': trimmedName,
          if (hasEmail) 'email': trimmedEmail,
          'roles': {rolePatient: false, roleFamilyMember: false},
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };
        await docRef.set(initialData, SetOptions(merge: true));
        return;
      }

      final data = doc.data();
      final rolesMap = _readRolesMap(data);
      var needsRoleInit = data?['roles'] is! Map;
      if (!rolesMap.containsKey(rolePatient)) {
        rolesMap[rolePatient] = false;
        needsRoleInit = true;
      }
      if (!rolesMap.containsKey(roleFamilyMember)) {
        rolesMap[roleFamilyMember] = false;
        needsRoleInit = true;
      }

      final updates = <String, Object?>{};
      if (needsRoleInit) {
        updates['roles'] = rolesMap.isEmpty
            ? {rolePatient: false, roleFamilyMember: false}
            : rolesMap;
      }

      if (hasName) {
        final existingName = data?['name'] as String?;
        if (existingName == null || existingName.trim().isEmpty) {
          updates['name'] = trimmedName;
        }

        final existingDisplayName = data?['displayName'] as String?;
        if (existingDisplayName == null || existingDisplayName.trim().isEmpty) {
          updates['displayName'] = trimmedName;
        }
      }

      if (hasEmail) {
        final existingEmail = data?['email'] as String?;
        if (existingEmail == null || existingEmail.trim().isEmpty) {
          updates['email'] = trimmedEmail;
        }
      }

      if (updates.isNotEmpty) {
        updates['updatedAt'] = FieldValue.serverTimestamp();
        await docRef.set(updates, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('Error ensuring profile exists: $e');
      rethrow;
    }
  }

  /// Updates the user's role (patient or family).
  Future<void> updateUserRole(
    String uid,
    String role, {
    String? email,
    String? displayName,
  }) async {
    try {
      final normalizedRole = _normalizeRoleKey(role);
      if (normalizedRole == null) {
        throw ArgumentError('Unknown role: $role');
      }
      await ensureProfileExists(
        uid: uid,
        email: email ?? '',
        name: displayName,
      );
      await _firestore.collection(_usersCollection).doc(uid).update({
        'roles.$normalizedRole': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (normalizedRole == rolePatient) {
        await ensurePatientPublicId(uid);
      }
    } catch (e) {
      debugPrint('Error updating user role: $e');
      rethrow;
    }
  }

  /// Alias for updateUserRole for consistency with requirements.
  Future<void> updateRole(
    String uid,
    String role, {
    String? email,
    String? displayName,
  }) async {
    return updateUserRole(uid, role, email: email, displayName: displayName);
  }

  Future<bool> userHasRole(String uid, String roleKey) async {
    final profile = await getUserProfile(uid);
    return profileHasRole(profile, roleKey);
  }

  Future<void> addUserRole(
    String uid,
    String roleKey, {
    String? email,
    String? displayName,
  }) async {
    try {
      final normalizedRole = _normalizeRoleKey(roleKey);
      if (normalizedRole == null) {
        throw ArgumentError('Unknown role: $roleKey');
      }
      await ensureProfileExists(
        uid: uid,
        email: email ?? '',
        name: displayName,
      );
      await _firestore.collection(_usersCollection).doc(uid).update({
        'roles.$normalizedRole': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (normalizedRole == rolePatient) {
        await ensurePatientPublicId(uid);
      }
    } catch (e) {
      debugPrint('Error adding user role: $e');
      rethrow;
    }
  }

  Future<void> setUserRoleState(
    String uid,
    String roleKey,
    bool enabled,
  ) async {
    try {
      final normalizedRole = _normalizeRoleKey(roleKey);
      if (normalizedRole == null) return;
      await _firestore.collection(_usersCollection).doc(uid).update({
        'roles.$normalizedRole': enabled,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error setting user role state: $e');
      rethrow;
    }
  }

  Future<String?> ensurePatientPublicId(String uid) async {
    try {
      final patientRef = _firestore.collection(_patientsCollection).doc(uid);
      final patientDoc = await patientRef.get();
      final existingId = patientDoc.data()?['publicId'] as String?;
      if (existingId != null && existingId.isNotEmpty) {
        await _ensurePublicIdMapping(uid, existingId);
        return existingId;
      }

      final random = Random();
      for (var attempt = 0; attempt < 6; attempt++) {
        final candidate = _generatePublicId(random);
        final mappingRef = _firestore
            .collection(_publicIdsCollection)
            .doc(candidate);
        try {
          await _firestore.runTransaction((txn) async {
            final mappingDoc = await txn.get(mappingRef);
            if (mappingDoc.exists) {
              throw _PublicIdCollision();
            }
            txn.set(mappingRef, {
              'uid': uid,
              'createdAt': FieldValue.serverTimestamp(),
            });
            txn.set(patientRef, {
              'publicId': candidate,
              'createdAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          });
          return candidate;
        } on _PublicIdCollision {
          continue;
        }
      }
      throw StateError('Unable to allocate patient public ID');
    } catch (e) {
      debugPrint('Error ensuring patient public ID: $e');
      rethrow;
    }
  }

  Future<void> _ensurePublicIdMapping(String uid, String publicId) async {
    final mappingRef = _firestore
        .collection(_publicIdsCollection)
        .doc(publicId);
    final mappingDoc = await mappingRef.get();
    if (!mappingDoc.exists) {
      await mappingRef.set({
        'uid': uid,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<String?> findPatientUidByPublicId(String publicId) async {
    try {
      final mappingDoc = await _firestore
          .collection(_publicIdsCollection)
          .doc(publicId)
          .get();
      final mappedUid = mappingDoc.data()?['uid'] as String?;
      if (mappedUid != null && mappedUid.isNotEmpty) {
        return mappedUid;
      }

      final query = await _firestore
          .collection(_patientsCollection)
          .where('publicId', isEqualTo: publicId)
          .limit(1)
          .get();
      if (query.docs.isEmpty) return null;
      return query.docs.first.id;
    } catch (e) {
      debugPrint('Error finding patient by public ID: $e');
      rethrow;
    }
  }

  Future<bool> connectionExists({
    required String familyMemberUid,
    required String patientUid,
  }) async {
    final docId = _connectionId(familyMemberUid, patientUid);
    final doc = await _firestore
        .collection(_connectionsCollection)
        .doc(docId)
        .get();
    return doc.exists;
  }

  Future<void> createConnection({
    required String familyMemberUid,
    required String patientUid,
    required String relation,
    String? patientPublicId,
  }) async {
    final docId = _connectionId(familyMemberUid, patientUid);
    await _firestore.collection(_connectionsCollection).doc(docId).set({
      'familyMemberUid': familyMemberUid,
      'familyUid': familyMemberUid,
      'patientUid': patientUid,
      if (patientPublicId != null && patientPublicId.isNotEmpty)
        'patientPublicId': patientPublicId,
      'relation': relation,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> createMedicineRequest({
    required String familyMemberUid,
    required String patientUid,
    required Map<String, dynamic> medicineData,
  }) async {
    await _firestore.collection(_medicineRequestsCollection).add({
      'familyMemberUid': familyMemberUid,
      'patientUid': patientUid,
      'status': 'pending',
      'type': 'add',
      'medicine': medicineData,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>>
  watchPendingMedicineRequestsForPatient(String patientUid) {
    return _firestore
        .collection(_medicineRequestsCollection)
        .where('patientUid', isEqualTo: patientUid)
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  Future<void> approveMedicineRequest({required String requestId}) async {
    final requestRef = _firestore
        .collection(_medicineRequestsCollection)
        .doc(requestId);

    await _firestore.runTransaction((txn) async {
      final requestSnap = await txn.get(requestRef);
      final requestData = requestSnap.data();
      if (requestData == null) return;
      if (requestData['status'] != 'pending') return;

      final patientUid = requestData['patientUid'] as String?;
      final medicine = requestData['medicine'] as Map?;
      if (patientUid == null || medicine == null) return;

      final medicineData = Map<String, dynamic>.from(medicine);
      medicineData['createdAt'] = FieldValue.serverTimestamp();
      medicineData['updatedAt'] = FieldValue.serverTimestamp();

      final medRef = _firestore
          .collection(_usersCollection)
          .doc(patientUid)
          .collection('medicines')
          .doc();

      txn.set(medRef, medicineData);
      txn.update(requestRef, {
        'status': 'approved',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> rejectMedicineRequest(String requestId) async {
    await _firestore
        .collection(_medicineRequestsCollection)
        .doc(requestId)
        .update({
          'status': 'rejected',
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchPendingConnectionsForPatient(
    String patientUid,
  ) {
    return _firestore
        .collection(_connectionsCollection)
        .where('patientUid', isEqualTo: patientUid)
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchApprovedConnectionsForFamily(
    String familyMemberUid,
  ) {
    return _firestore
        .collection(_connectionsCollection)
        .where('familyMemberUid', isEqualTo: familyMemberUid)
        .where('status', isEqualTo: 'approved')
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchConnectionsForFamily(
    String familyMemberUid,
  ) {
    return _firestore
        .collection(_connectionsCollection)
        .where('familyMemberUid', isEqualTo: familyMemberUid)
        .snapshots();
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  getConnectionsForFamily(String familyMemberUid) async {
    final snapshot = await _firestore
        .collection(_connectionsCollection)
        .where('familyMemberUid', isEqualTo: familyMemberUid)
        .get();
    return snapshot.docs;
  }

  Future<void> approveConnection(String connectionId) async {
    final connectionRef = _firestore
        .collection(_connectionsCollection)
        .doc(connectionId);

    await _firestore.runTransaction((txn) async {
      final snapshot = await txn.get(connectionRef);
      final data = snapshot.data();
      if (data == null) return;

      final familyMemberUid = data['familyMemberUid'] as String?;
      if (familyMemberUid == null || familyMemberUid.isEmpty) return;

      final status = data['status'] as String?;
      if (status != 'approved') {
        txn.update(connectionRef, {
          'status': 'approved',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      final familyRef = _firestore
          .collection(_usersCollection)
          .doc(familyMemberUid);
      final familySnap = await txn.get(familyRef);
      final roleUpdates = _buildRoleUpdate(
        data: familySnap.data(),
        addRole: roleFamilyMember,
        includeNormalizedRoles: false,
        cleanDottedFields: false,
      );
      txn.set(familyRef, roleUpdates, SetOptions(merge: true));
    });
  }

  Future<void> ensureRolesConsistency(
    String uid,
    Map<String, dynamic>? profile,
  ) async {
    if (profile == null || !_needsRoleCleanup(profile)) return;
    final docRef = _firestore.collection(_usersCollection).doc(uid);
    await _firestore.runTransaction((txn) async {
      final snapshot = await txn.get(docRef);
      final updates = _buildRoleUpdate(data: snapshot.data());
      txn.set(docRef, updates, SetOptions(merge: true));
    });
  }

  Map<Object, Object> _buildRoleUpdate({
    required Map<String, dynamic>? data,
    String? addRole,
    bool includeNormalizedRoles = true,
    bool cleanDottedFields = true,
  }) {
    final rolesMap = _readRolesMap(data);
    rolesMap.putIfAbsent(rolePatient, () => false);
    rolesMap.putIfAbsent(roleFamilyMember, () => false);
    if (includeNormalizedRoles) {
      final normalized = normalizeRoles(data);
      for (final entry in normalized.entries) {
        if (entry.value == true) {
          rolesMap[entry.key] = true;
        }
      }
    }
    if (addRole != null) {
      rolesMap[addRole] = true;
    }

    final updates = <Object, Object>{
      'roles': rolesMap,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (cleanDottedFields && data != null) {
      for (final key in data.keys) {
        if (key.startsWith('roles.')) {
          updates[FieldPath([key])] = FieldValue.delete();
        }
      }
    }

    return updates;
  }

  Map<String, bool> _readRolesMap(Map<String, dynamic>? data) {
    final roles = <String, bool>{};
    final rawRoles = data?['roles'];
    if (rawRoles is Map) {
      rawRoles.forEach((key, value) {
        if (value is bool) {
          roles[key.toString()] = value;
        }
      });
    }
    return roles;
  }

  bool _needsRoleCleanup(Map<String, dynamic> data) {
    if (data.containsKey('roles') && data['roles'] is! Map) {
      return true;
    }

    for (final key in data.keys) {
      if (key.startsWith('roles.')) {
        return true;
      }
    }

    final rolesMap = _readRolesMap(data);
    final normalized = normalizeRoles(data);
    for (final entry in normalized.entries) {
      if (entry.value == true && rolesMap[entry.key] != true) {
        return true;
      }
    }
    return false;
  }

  Future<void> rejectConnection(String connectionId) async {
    await _firestore
        .collection(_connectionsCollection)
        .doc(connectionId)
        .delete();
  }

  Future<void> cancelConnectionRequest(String connectionId) async {
    await _firestore
        .collection(_connectionsCollection)
        .doc(connectionId)
        .delete();
  }

  String _connectionId(String familyMemberUid, String patientUid) {
    return '${familyMemberUid}_$patientUid';
  }

  /// Updates the user's name if it's missing or empty.
  Future<void> updateNameIfMissing(String uid, String name) async {
    try {
      final doc = await _firestore.collection(_usersCollection).doc(uid).get();
      if (doc.exists) {
        final data = doc.data();
        final currentName = data?['name'] as String?;
        if (currentName == null || currentName.isEmpty) {
          await _firestore.collection(_usersCollection).doc(uid).update({
            'name': name,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      debugPrint('Error updating name: $e');
      rethrow;
    }
  }

  Future<void> updateFamilyMemberSetup({
    required String uid,
    required String relation,
    required List<String> patients,
  }) async {
    try {
      await _firestore.collection(_usersCollection).doc(uid).set({
        'familyMember': {'relation': relation, 'patients': patients},
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error updating family member setup: $e');
      rethrow;
    }
  }

  /// Stream of user profile for real-time updates.
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchProfile(String uid) {
    return _firestore.collection(_usersCollection).doc(uid).snapshots();
  }

  /// Stream of user profile data (map only) for real-time updates.
  Stream<Map<String, dynamic>?> getUserProfileStream(String uid) {
    return _firestore
        .collection(_usersCollection)
        .doc(uid)
        .snapshots()
        .map((snapshot) => snapshot.data());
  }

  static Map<String, bool> normalizeRoles(Map<String, dynamic>? profile) {
    final roles = <String, bool>{};
    if (profile == null) return roles;

    final rawRoles = profile['roles'];
    if (rawRoles is Map) {
      rawRoles.forEach((key, value) {
        if (value == true) {
          roles[key.toString()] = true;
        }
      });
    }

    final dottedPatient = profile['roles.$rolePatient'];
    if (dottedPatient == true) {
      roles[rolePatient] = true;
    }
    final dottedFamily = profile['roles.$roleFamilyMember'];
    if (dottedFamily == true) {
      roles[roleFamilyMember] = true;
    }

    final legacyRole = profile['role'] as String?;
    if (legacyRole == rolePatient) {
      roles[rolePatient] = true;
    } else if (legacyRole == roleFamilyMember ||
        legacyRole == legacyRoleFamily) {
      roles[roleFamilyMember] = true;
    }

    return roles;
  }

  static bool profileHasRole(Map<String, dynamic>? profile, String roleKey) {
    final normalized = normalizeRoles(profile);
    final normalizedKey = _normalizeRoleKey(roleKey);
    if (normalizedKey == null) return false;
    return normalized[normalizedKey] == true;
  }

  static String? resolvePrimaryRole(Map<String, dynamic>? profile) {
    final roles = normalizeRoles(profile);
    if (roles[rolePatient] == true) return rolePatient;
    if (roles[roleFamilyMember] == true) return roleFamilyMember;
    return null;
  }

  static String? _normalizeRoleKey(String roleKey) {
    if (roleKey == rolePatient) return rolePatient;
    if (roleKey == roleFamilyMember) return roleFamilyMember;
    if (roleKey == legacyRoleFamily) return roleFamilyMember;
    return null;
  }

  String _generatePublicId(Random random) {
    final value = random.nextInt(1000000).toString().padLeft(6, '0');
    return '$_publicIdPrefix$value';
  }
}

class _PublicIdCollision implements Exception {}
