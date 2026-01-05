import 'package:cloud_firestore/cloud_firestore.dart';
class FamilyConnectionRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _connectionsCollection = 'connections';
  static const String _patientsCollection = 'patients';
  static const String _usersCollection = 'users';

  Future<void> acceptConnection(String connectionId) async {
    final connectionRef =
        _firestore.collection(_connectionsCollection).doc(connectionId);
    await _firestore.runTransaction((txn) async {
      final connectionSnap = await txn.get(connectionRef);
      if (!connectionSnap.exists) {
        throw StateError('Connection request not found');
      }
      final data = connectionSnap.data() ?? <String, dynamic>{};
      final patientUid = data['patientUid'] as String? ?? '';
      final familyMemberUid = data['familyMemberUid'] as String? ?? '';
      if (patientUid.isEmpty || familyMemberUid.isEmpty) {
        throw StateError('Invalid connection data');
      }

      final patientPublicId = data['patientPublicId'] as String?;
      final relation = data['relation'] as String?;
      final patientKey =
          (patientPublicId != null && patientPublicId.isNotEmpty)
              ? patientPublicId
              : patientUid;

      final familyMemberRef = _firestore
          .collection(_patientsCollection)
          .doc(patientUid)
          .collection('familyMembers')
          .doc(familyMemberUid);
      final familyUserRef =
          _firestore.collection(_usersCollection).doc(familyMemberUid);

      txn.set(
        familyMemberRef,
        {
          'familyMemberUid': familyMemberUid,
          'patientUid': patientUid,
          if (relation != null && relation.isNotEmpty) 'relation': relation,
          'status': 'approved',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      txn.update(familyUserRef, {
        'familyMember.pendingPatients': FieldValue.arrayRemove([patientKey]),
        'familyMember.patients': FieldValue.arrayUnion([patientKey]),
        'roles.family_member': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (data['status'] != 'approved') {
        txn.update(connectionRef, {
          'status': 'approved',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  Future<void> rejectConnection(String connectionId) async {
    final connectionRef =
        _firestore.collection(_connectionsCollection).doc(connectionId);
    await _firestore.runTransaction((txn) async {
      final connectionSnap = await txn.get(connectionRef);
      if (!connectionSnap.exists) return;

      final data = connectionSnap.data() ?? <String, dynamic>{};
      final patientUid = data['patientUid'] as String? ?? '';
      final familyMemberUid = data['familyMemberUid'] as String? ?? '';
      if (patientUid.isEmpty || familyMemberUid.isEmpty) {
        txn.delete(connectionRef);
        return;
      }

      final patientPublicId = data['patientPublicId'] as String?;
      final patientKey =
          (patientPublicId != null && patientPublicId.isNotEmpty)
              ? patientPublicId
              : patientUid;

      final familyMemberRef = _firestore
          .collection(_patientsCollection)
          .doc(patientUid)
          .collection('familyMembers')
          .doc(familyMemberUid);
      final familyUserRef =
          _firestore.collection(_usersCollection).doc(familyMemberUid);

      txn.delete(familyMemberRef);
      txn.update(familyUserRef, {
        'familyMember.pendingPatients': FieldValue.arrayRemove([patientKey]),
        'familyMember.patients': FieldValue.arrayRemove([patientKey]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      txn.delete(connectionRef);
    });
  }
}
