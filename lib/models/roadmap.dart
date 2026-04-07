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
    this.replanVersion,
    this.replanReason,
    this.previousRoadmapId,
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

  /// Version number incremented on each replan (ADAPT-03).
  final int? replanVersion;

  /// AI-generated explanation of why the roadmap was replanned (ADAPT-03).
  final String? replanReason;

  /// Firestore ID of the previous roadmap document, if this is a replanned version.
  final String? previousRoadmapId;

  /// Returns true if any stage has been at < 1.0 progress and updatedAt
  /// is more than [thresholdDays] days ago (default 14 — ADAPT-01).
  bool isStalled({int thresholdDays = 14}) {
    if (updatedAt == null) return false;
    final daysSinceUpdate = DateTime.now().difference(updatedAt!).inDays;
    if (daysSinceUpdate < thresholdDays) return false;
    // Check that at least one stage is incomplete
    return stageProgress.values.any((p) => p < 1.0);
  }

  /// Returns day count since last progress update, or null if updatedAt missing.
  int? daysSinceUpdate() {
    if (updatedAt == null) return null;
    return DateTime.now().difference(updatedAt!).inDays;
  }

  List<RoadmapStage> get structuredStages {
    final stages = <RoadmapStage>[];
    final labels = ['beginner', 'intermediate', 'advanced'];
    final stageCount = milestones.length.clamp(1, 10);

    // Distribute ALL resources across stages evenly
    final resourcesPerStage = <int, List<String>>{};
    for (var i = 0; i < resources.length; i++) {
      final bucket = i % stageCount;
      resourcesPerStage.putIfAbsent(bucket, () => []).add(resources[i]);
    }

    for (var i = 0; i < milestones.length; i++) {
      final level = i < labels.length ? labels[i] : 'stage_${i + 1}';
      // Parse tasks from milestone text — extract items after ":"
      final raw = milestones[i];
      final tasks = <String>[];
      final colonIdx = raw.indexOf(':');
      if (colonIdx > 0 && colonIdx < raw.length - 1) {
        final afterColon = raw.substring(colonIdx + 1).trim();
        tasks.addAll(
          afterColon
              .replaceAll(', and ', ', ')
              .replaceAll(' and ', ', ')
              .split(',')
              .map((s) => s.trim().replaceAll(RegExp(r'[.]$'), ''))
              .where((s) => s.isNotEmpty && s.length > 2),
        );
      }
      stages.add(RoadmapStage(
        level: level,
        title: raw,
        tasks: tasks,
        resources: resourcesPerStage[i] ?? [],
      ));
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
      replanVersion: m['replan_version'] is int ? m['replan_version'] as int : null,
      replanReason: m['replan_reason']?.toString(),
      previousRoadmapId: m['previous_roadmap_id']?.toString(),
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
      if (replanVersion != null) 'replan_version': replanVersion,
      if (replanReason != null) 'replan_reason': replanReason,
      if (previousRoadmapId != null) 'previous_roadmap_id': previousRoadmapId,
    };
  }

  Roadmap copyWith({
    Map<String, double>? stageProgress,
    DateTime? updatedAt,
    int? replanVersion,
    String? replanReason,
    String? previousRoadmapId,
  }) {
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
      replanVersion: replanVersion ?? this.replanVersion,
      replanReason: replanReason ?? this.replanReason,
      previousRoadmapId: previousRoadmapId ?? this.previousRoadmapId,
    );
  }
}
