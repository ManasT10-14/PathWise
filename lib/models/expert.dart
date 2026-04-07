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
    required this.priceChat,
    required this.priceCall,
    required this.priceVideo,
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
  final num priceChat;
  final num priceCall;
  final num priceVideo;
  final bool isVerified;
  final List<String> skills;
  final int totalReviews;
  final DateTime? createdAt;
  final String? linkedUserId;

  /// Backward-compatible getter — returns the cheapest rate.
  num get pricePerSession => [priceChat, priceCall, priceVideo]
      .where((p) => p > 0)
      .fold<num>(priceChat, (a, b) => a < b ? a : b);

  /// Get price for a specific consultation type.
  num priceForType(String type) {
    switch (type.toLowerCase()) {
      case 'chat':
        return priceChat;
      case 'audio':
        return priceCall;
      case 'video':
        return priceVideo;
      default:
        return priceChat;
    }
  }

  factory Expert.fromFirestore(String docId, Map<String, dynamic> m) {
    List<String> sk(dynamic v) {
      if (v is List) return v.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
      return [];
    }

    final eid = m['expertId'];
    final expertIdStr = eid == null ? docId : eid.toString();

    DateTime? ts(dynamic v) => v is Timestamp ? v.toDate() : null;

    // Read 3-tier pricing with fallback to legacy single price
    final legacyPrice = m['pricePerSession'] is num ? m['pricePerSession'] as num : 500;
    final pricing = m['pricing'];
    num pChat = legacyPrice;
    num pCall = legacyPrice;
    num pVideo = legacyPrice;
    if (pricing is Map) {
      pChat = pricing['chat'] is num ? pricing['chat'] as num : legacyPrice;
      pCall = pricing['call'] is num ? pricing['call'] as num : legacyPrice;
      pVideo = pricing['video'] is num ? pricing['video'] as num : legacyPrice;
    }

    return Expert(
      id: docId,
      expertId: expertIdStr,
      name: m['name']?.toString() ?? '',
      email: m['email']?.toString() ?? '',
      domain: m['domain']?.toString() ?? '',
      experience: m['experience']?.toString() ?? '',
      rating: (m['rating'] is num) ? (m['rating'] as num).toDouble() : 0,
      priceChat: pChat,
      priceCall: pCall,
      priceVideo: pVideo,
      isVerified: m['isVerified'] == true,
      skills: sk(m['skills']),
      totalReviews: (m['totalReviews'] is num) ? (m['totalReviews'] as num).toInt() : 0,
      createdAt: ts(m['createdAt']),
      linkedUserId: m['linkedUserId']?.toString(),
    );
  }
}
