import 'package:cloud_firestore/cloud_firestore.dart';

class Review {
  const Review({
    required this.id,
    required this.reviewId,
    required this.userId,
    required this.expertId,
    required this.consultationId,
    required this.rating,
    required this.feedback,
    required this.timestamp,
  });

  final String id;
  final String reviewId;
  final String userId;
  final String expertId;
  final String consultationId;
  final int rating;
  final String feedback;
  final DateTime? timestamp;

  factory Review.fromFirestore(String docId, Map<String, dynamic> m) {
    DateTime? ts(dynamic v) {
      if (v is Timestamp) return v.toDate();
      return null;
    }

    return Review(
      id: docId,
      reviewId: m['reviewId']?.toString() ?? docId,
      userId: m['userId']?.toString() ?? '',
      expertId: m['expertId']?.toString() ?? '',
      consultationId: m['consultationId']?.toString() ?? '',
      rating: (m['rating'] is num) ? (m['rating'] as num).toInt().clamp(0, 5) : 0,
      feedback: m['feedback']?.toString() ?? '',
      timestamp: ts(m['timestamp'] ?? m['CreatedAt']),
    );
  }
}
