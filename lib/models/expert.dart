import 'package:cloud_firestore/cloud_firestore.dart';

class Expert {
  const Expert({
    required this.id,
    required this.expertId,
    required this.name,
    required this.email,
    required this.domain,
    required this.experience,
    required this.rating,
    required this.pricePerSession,
    required this.isVerified,
    required this.skills,
    required this.totalReviews,
    required this.createdAt,
    this.linkedUserId,
  });

  final String id;
  final String expertId;
  final String name;
  final String email;
  final String domain;
  final String experience;
  final double rating;
  final num pricePerSession;
  final bool isVerified;
  final List<String> skills;
  final int totalReviews;
  final DateTime? createdAt;
  final String? linkedUserId;

  factory Expert.fromFirestore(String docId, Map<String, dynamic> m) {
    List<String> sk(dynamic v) {
      if (v is List) return v.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
      return [];
    }

    final eid = m['expertId'];
    final expertIdStr = eid == null ? docId : eid.toString();

    DateTime? ts(dynamic v) => v is Timestamp ? v.toDate() : null;

    return Expert(
      id: docId,
      expertId: expertIdStr,
      name: m['name']?.toString() ?? '',
      email: m['email']?.toString() ?? '',
      domain: m['domain']?.toString() ?? '',
      experience: m['experience']?.toString() ?? '',
      rating: (m['rating'] is num) ? (m['rating'] as num).toDouble() : 0,
      pricePerSession: m['pricePerSession'] is num ? m['pricePerSession'] as num : 0,
      isVerified: m['isVerified'] == true,
      skills: sk(m['skills']),
      totalReviews: (m['totalReviews'] is num) ? (m['totalReviews'] as num).toInt() : 0,
      createdAt: ts(m['createdAt']),
      linkedUserId: m['linkedUserId']?.toString(),
    );
  }
}
