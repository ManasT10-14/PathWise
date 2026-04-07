import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/expert.dart';

class ExpertRepository {
  ExpertRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('experts');

  Stream<List<Expert>> watchExperts() {
    return _col.snapshots().map(
          (q) => q.docs.map((d) => Expert.fromFirestore(d.id, d.data())).toList(),
        );
  }

  Future<void> setVerified(String expertDocId, bool verified) async {
    await _col.doc(expertDocId).update({'isVerified': verified});
  }

  Future<void> updateRatingStats(String expertDocId, double newAvg, int totalReviews) async {
    await _col.doc(expertDocId).update({
      'rating': newAvg,
      'totalReviews': totalReviews,
    });
  }

  /// Creates a default expert profile linked to a user account.
  /// Called when admin promotes a user to expert role.
  Future<String> createForUser({
    required String uid,
    required String name,
    required String email,
  }) async {
    // Check if expert profile already exists
    final existing = await findExpertForUser(uid: uid, email: email);
    if (existing != null) return existing.id;

    final doc = _col.doc();
    await doc.set({
      'expertId': doc.id,
      'name': name,
      'email': email,
      'domain': '',
      'experience': '',
      'rating': 0.0,
      'pricePerSession': 500,
      'isVerified': false,
      'skills': <String>[],
      'totalReviews': 0,
      'linkedUserId': uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  /// Returns only verified experts for the user-facing marketplace.
  Stream<List<Expert>> watchVerifiedExperts() {
    return _col.where('isVerified', isEqualTo: true).snapshots().map(
          (q) => q.docs.map((d) => Expert.fromFirestore(d.id, d.data())).toList(),
        );
  }

  Future<Expert?> fetchExpert(String expertDocId) async {
    final s = await _col.doc(expertDocId).get();
    if (!s.exists || s.data() == null) return null;
    return Expert.fromFirestore(s.id, s.data()!);
  }

  // ---------------------------------------------------------------------------
  // Expert Applications
  // ---------------------------------------------------------------------------

  CollectionReference<Map<String, dynamic>> get _applications =>
      _db.collection('expert_applications');

  /// Submit an application to become an expert. Admin reviews in dashboard.
  Future<void> submitApplication({
    required String uid,
    required String name,
    required String email,
    required String domain,
    required String experience,
    required List<String> skills,
  }) async {
    // Prevent duplicate applications
    final existing = await _applications.where('uid', isEqualTo: uid).limit(1).get();
    if (existing.docs.isNotEmpty) {
      final status = existing.docs.first.data()['status'];
      if (status == 'pending') throw Exception('Application already pending');
      if (status == 'approved') throw Exception('Already approved as expert');
    }

    await _applications.doc().set({
      'uid': uid,
      'name': name,
      'email': email,
      'domain': domain,
      'experience': experience,
      'skills': skills,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Watch all pending applications (admin only).
  Stream<List<Map<String, dynamic>>> watchApplications() {
    return _applications
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((q) => q.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  /// Approve application: create expert profile + set user role to expert.
  Future<void> approveApplication(String applicationId, Map<String, dynamic> app) async {
    final uid = app['uid'] as String;
    final name = app['name'] as String;
    final email = app['email'] as String;
    final domain = app['domain'] as String? ?? '';
    final experience = app['experience'] as String? ?? '';
    final skills = (app['skills'] as List?)?.cast<String>() ?? <String>[];

    // Create expert profile
    await createForUser(uid: uid, name: name, email: email);

    // Update expert profile with application details
    final expert = await findExpertForUser(uid: uid, email: email);
    if (expert != null) {
      await _col.doc(expert.id).update({
        'domain': domain,
        'experience': experience,
        'skills': skills,
        'isVerified': true,
      });
    }

    // Set user role
    await _db.collection('users').doc(uid).update({'role': 'expert'});

    // Mark application as approved
    await _applications.doc(applicationId).update({'status': 'approved'});
  }

  /// Reject an application.
  Future<void> rejectApplication(String applicationId) async {
    await _applications.doc(applicationId).update({'status': 'rejected'});
  }

  /// Check if a user has a pending or approved application.
  Future<String?> getApplicationStatus(String uid) async {
    final snap = await _applications.where('uid', isEqualTo: uid).limit(1).get();
    if (snap.docs.isEmpty) return null;
    return snap.docs.first.data()['status'] as String?;
  }

  /// Finds expert profile linked by [linkedUserId] or matching [email].
  Future<Expert?> findExpertForUser({required String uid, required String email}) async {
    final byUid = await _col.where('linkedUserId', isEqualTo: uid).limit(1).get();
    if (byUid.docs.isNotEmpty) {
      final d = byUid.docs.first;
      return Expert.fromFirestore(d.id, d.data());
    }
    final byEmail = await _col.where('email', isEqualTo: email).limit(1).get();
    if (byEmail.docs.isNotEmpty) {
      final d = byEmail.docs.first;
      return Expert.fromFirestore(d.id, d.data());
    }
    return null;
  }
}
