import 'package:cloud_firestore/cloud_firestore.dart';

class RoadmapStage {
  const RoadmapStage({required this.level, required this.title, required this.tasks, required this.resources});

  final String level;
  final String title;
  final List<String> tasks;
  final List<String> resources;
}

class Roadmap {
  const Roadmap({
    required this.id,
    required this.roadmapId,
    required this.userId,
    required this.targetRole,
    required this.milestones,
    required this.resources,
    required this.timeline,
    required this.createdAt,
    required this.updatedAt,
    this.stageProgress = const {},
  });

  final String id;
  final String roadmapId;
  final String userId;
  final String targetRole;
  final List<String> milestones;
  final List<String> resources;
  final String timeline;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Map<String, double> stageProgress;

  List<RoadmapStage> get structuredStages {
    final stages = <RoadmapStage>[];
    final labels = ['beginner', 'intermediate', 'advanced'];
    for (var i = 0; i < milestones.length; i++) {
      final level = i < labels.length ? labels[i] : 'stage_${i + 1}';
      final chunk = resources.length > i
          ? [resources[i]]
          : resources.isNotEmpty
              ? [resources[i % resources.length]]
              : <String>[];
      stages.add(RoadmapStage(level: level, title: milestones[i], tasks: const [], resources: chunk));
    }
    if (stages.isEmpty) {
      stages.add(
        RoadmapStage(
          level: 'beginner',
          title: 'Foundation',
          tasks: const ['Complete profile', 'Core concepts'],
          resources: resources,
        ),
      );
    }
    return stages;
  }

  factory Roadmap.fromFirestore(String docId, Map<String, dynamic> m) {
    DateTime? ts(dynamic v) => v is Timestamp ? v.toDate() : null;

    List<String> ls(dynamic v) {
      if (v is List) return v.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
      return [];
    }

    final progress = <String, double>{};
    final p = m['stageProgress'];
    if (p is Map) {
      p.forEach((k, v) {
        if (v is num) progress[k.toString()] = v.toDouble().clamp(0, 1);
      });
    }

    return Roadmap(
      id: docId,
      roadmapId: m['roadmapId']?.toString() ?? docId,
      userId: m['userId']?.toString() ?? '',
      targetRole: m['targetRole']?.toString() ?? '',
      milestones: ls(m['milestones']),
      resources: ls(m['resources']),
      timeline: m['timeline']?.toString() ?? '',
      createdAt: ts(m['createdAt']),
      updatedAt: ts(m['updatedAt']),
      stageProgress: progress,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'roadmapId': roadmapId,
      'userId': userId,
      'targetRole': targetRole,
      'milestones': milestones,
      'resources': resources,
      'timeline': timeline,
      'stageProgress': stageProgress.map((k, v) => MapEntry(k, v)),
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Roadmap copyWith({Map<String, double>? stageProgress, DateTime? updatedAt}) {
    return Roadmap(
      id: id,
      roadmapId: roadmapId,
      userId: userId,
      targetRole: targetRole,
      milestones: milestones,
      resources: resources,
      timeline: timeline,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      stageProgress: stageProgress ?? this.stageProgress,
    );
  }
}
