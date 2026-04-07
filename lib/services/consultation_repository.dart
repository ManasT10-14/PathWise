import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/consultation.dart';

class ConsultationRepository {
  ConsultationRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('consultations');

  Stream<List<Consultation>> watchForUser(String userId) {
    return _col.where('userId', isEqualTo: userId).snapshots().map(
          (q) => q.docs.map((d) => Consultation.fromFirestore(d.id, d.data())).toList(),
        );
  }

  Stream<List<Consultation>> watchForExpert(String expertId) {
    return _col.where('expertId', isEqualTo: expertId).snapshots().map(
          (q) => q.docs.map((d) => Consultation.fromFirestore(d.id, d.data())).toList(),
        );
  }

  Stream<List<Consultation>> watchAll() {
    return _col.snapshots().map(
          (q) => q.docs.map((d) => Consultation.fromFirestore(d.id, d.data())).toList(),
        );
  }

  Future<String> create(Consultation c) async {
    final doc = _col.doc();
    final withIds = Consultation(
      id: doc.id,
      consultationId: doc.id,
      userId: c.userId,
      expertId: c.expertId,
      type: c.type,
      status: c.status,
      price: c.price,
      questionLimit: c.questionLimit,
      scheduledAt: c.scheduledAt,
      createdAt: c.createdAt,
    );
    await doc.set(withIds.toCreateMap());
    return doc.id;
  }

  Future<void> updateStatus(String docId, String status) async {
    await _col.doc(docId).update({'status': status});
  }

  Future<void> updateMeetLink(String docId, String meetLink) async {
    await _col.doc(docId).update({'meetLink': meetLink});
  }
}
