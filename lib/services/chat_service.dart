import 'package:cloud_firestore/cloud_firestore.dart';

/// Simple Firestore-based real-time chat for consultation sessions.
///
/// Messages are stored in: consultations/{consultationId}/messages
/// Each message: { senderId, senderName, text, timestamp }
class ChatService {
  ChatService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _messages(String consultationId) =>
      _db.collection('consultations').doc(consultationId).collection('messages');

  /// Send a text message in a consultation chat.
  Future<void> sendMessage({
    required String consultationId,
    required String senderId,
    required String senderName,
    required String text,
  }) async {
    if (text.trim().isEmpty) return;
    await _messages(consultationId).add({
      'senderId': senderId,
      'senderName': senderName,
      'text': text.trim(),
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Watch messages in real-time, ordered by timestamp.
  Stream<List<ChatMessage>> watchMessages(String consultationId) {
    return _messages(consultationId)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ChatMessage.fromFirestore(d.id, d.data()))
            .toList());
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    this.timestamp,
  });

  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime? timestamp;

  factory ChatMessage.fromFirestore(String docId, Map<String, dynamic> m) {
    final ts = m['timestamp'];
    return ChatMessage(
      id: docId,
      senderId: m['senderId']?.toString() ?? '',
      senderName: m['senderName']?.toString() ?? '',
      text: m['text']?.toString() ?? '',
      timestamp: ts is Timestamp ? ts.toDate() : null,
    );
  }
}
