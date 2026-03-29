import 'package:cloud_firestore/cloud_firestore.dart';

class Consultation {
  const Consultation({
    required this.id,
    required this.consultationId,
    required this.userId,
    required this.expertId,
    required this.type,
    required this.status,
    required this.price,
    required this.questionLimit,
    required this.scheduledAt,
    required this.createdAt,
  });

  final String id;
  final String consultationId;
  final String userId;
  final String expertId;
  final String type;
  final String status;
  final num price;
  final int questionLimit;
  final DateTime? scheduledAt;
  final DateTime? createdAt;

  static String _cleanStatus(String raw) {
    var s = raw.trim();
    while ((s.startsWith('"') && s.endsWith('"')) || (s.startsWith("'") && s.endsWith("'"))) {
      s = s.substring(1, s.length - 1).trim();
    }
    return s.replaceAll('""', '"');
  }

  factory Consultation.fromFirestore(String docId, Map<String, dynamic> m) {
    DateTime? ts(dynamic v) => v is Timestamp ? v.toDate() : null;
    String cid(dynamic v) => v == null ? docId : v.toString();

    return Consultation(
      id: docId,
      consultationId: cid(m['consultationId']),
      userId: m['userId']?.toString() ?? '',
      expertId: m['expertId']?.toString() ?? '',
      type: _cleanStatus(m['type']?.toString() ?? 'chat'),
      status: _cleanStatus(m['status']?.toString() ?? 'pending'),
      price: m['price'] is num ? m['price'] as num : 0,
      questionLimit: (m['questionLimit'] is num) ? (m['questionLimit'] as num).toInt() : 5,
      scheduledAt: ts(m['scheduledAt']),
      createdAt: ts(m['createdAt']),
    );
  }

  Map<String, dynamic> toCreateMap() {
    return {
      'consultationId': consultationId,
      'userId': userId,
      'expertId': expertId,
      'type': type,
      'status': status,
      'price': price,
      'questionLimit': questionLimit,
      'scheduledAt': scheduledAt != null ? Timestamp.fromDate(scheduledAt!) : Timestamp.now(),
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
