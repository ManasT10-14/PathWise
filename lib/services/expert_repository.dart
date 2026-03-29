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
