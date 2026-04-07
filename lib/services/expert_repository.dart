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
