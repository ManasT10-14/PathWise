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

    // Recalculate expert rating (excludes flagged reviews)
    await _recalculateRating(expertDocId);
  }

  Future<void> deleteReview(String reviewDocId) async {
    // Read expert ID before deleting so we can recalculate rating
    final doc = await _col.doc(reviewDocId).get();
    final expertId = doc.data()?['expertId']?.toString();

    await _col.doc(reviewDocId).delete();

    // Recalculate expert rating after deletion
    if (expertId != null && expertId.isNotEmpty) {
      await _recalculateRating(expertId);
    }
  }

  /// Recalculates an expert's rating from all unflagged reviews.
  Future<void> _recalculateRating(String expertDocId) async {
    final all = await _col.where('expertId', isEqualTo: expertDocId).get();
    var totalRating = 0;
    var count = 0;
    for (final d in all.docs) {
      final data = d.data();
      // Skip flagged reviews
      if (data['flagged'] == true) continue;
      final r = data['rating'];
      if (r is num) {
        totalRating += r.toInt();
        count++;
      }
    }
    final avg = count > 0 ? totalRating / count : 0.0;
    await _experts.updateRatingStats(expertDocId, avg, count);
  }
}
