import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/review.dart';
import 'expert_repository.dart';

class ReviewRepository {
  ReviewRepository({FirebaseFirestore? firestore, ExpertRepository? expertRepository})
      : _db = firestore ?? FirebaseFirestore.instance,
        _experts = expertRepository ?? ExpertRepository(firestore: firestore);

  final FirebaseFirestore _db;
  final ExpertRepository _experts;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('reviews');

  Stream<List<Review>> watchForExpert(String expertId) {
    return _col.where('expertId', isEqualTo: expertId).snapshots().map(
          (q) => q.docs.map((d) => Review.fromFirestore(d.id, d.data())).toList(),
        );
  }

  Stream<List<Review>> watchAll() {
    return _col.snapshots().map(
          (q) => q.docs.map((d) => Review.fromFirestore(d.id, d.data())).toList(),
        );
  }

  Future<void> submitReview({
    required String userId,
    required String expertDocId,
    required String consultationDocId,
    required int rating,
    required String feedback,
  }) async {
    final batch = _db.batch();
    final doc = _col.doc();
    batch.set(doc, {
      'reviewId': doc.id,
      'userId': userId,
      'expertId': expertDocId,
      'consultationId': consultationDocId,
      'rating': rating.clamp(1, 5),
      'feedback': feedback,
      'timestamp': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    final all = await _col.where('expertId', isEqualTo: expertDocId).get();
    var sum = 0;
    var n = 0;
    for (final d in all.docs) {
      final r = d.data()['rating'];
      if (r is num) {
        sum += r.toInt();
        n++;
      }
    }
    if (n > 0) {
      await _experts.updateRatingStats(expertDocId, sum / n, n);
    }
  }

  Future<void> deleteReview(String reviewDocId) async {
    await _col.doc(reviewDocId).delete();
  }
}
