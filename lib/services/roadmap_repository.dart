import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/roadmap.dart';

class RoadmapRepository {
  RoadmapRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('roadmaps');

  Stream<List<Roadmap>> watchForUser(String userId) {
    return _col.where('userId', isEqualTo: userId).snapshots().map(
          (q) => q.docs.map((d) => Roadmap.fromFirestore(d.id, d.data())).toList(),
        );
  }

  Future<String> createFromAnalysis({
    required String userId,
    required String targetRole,
    required List<String> milestones,
    required List<String> resources,
    required String timeline,
    List<String>? skillGaps,
    String? goalAnalysis,
  }) async {
    final doc = _col.doc();
    await doc.set({
      'roadmapId': doc.id,
      'userId': userId,
      'targetRole': targetRole,
      'milestones': milestones,
      'resources': resources,
      'timeline': timeline,
      if (skillGaps != null)
        'skillGaps': skillGaps
            .map((g) => {'skill': g, 'confidence': 0.5})
            .toList(),
      if (goalAnalysis != null) 'goalAnalysis': goalAnalysis,
      'stageProgress': <String, double>{
        'beginner': 0,
        'intermediate': 0,
        'advanced': 0,
      },
      'replan_version': 1,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Future<void> updateProgress(String docId, Map<String, double> stageProgress) async {
    await _col.doc(docId).update({
      'stageProgress': stageProgress,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
