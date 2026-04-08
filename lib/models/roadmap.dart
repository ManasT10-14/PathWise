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
    this.roadmapPlan,
    this.curatedResources,
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
  final int? replanVersion;
  final String? replanReason;
  final String? previousRoadmapId;

  /// Enhanced structured data from backend (null for legacy/local roadmaps).
  final Map<String, dynamic>? roadmapPlan;
  final Map<String, dynamic>? curatedResources;

  bool isStalled({int thresholdDays = 14}) {
    if (updatedAt == null) return false;
    final daysSinceUpdate = DateTime.now().difference(updatedAt!).inDays;
    if (daysSinceUpdate < thresholdDays) return false;
    return stageProgress.values.any((p) => p < 1.0);
  }

  int? daysSinceUpdate() {
    if (updatedAt == null) return null;
    return DateTime.now().difference(updatedAt!).inDays;
  }

  /// Build stages from enhanced data (backend v2) or legacy milestones.
  List<RoadmapStage> get structuredStages {
    // Try enhanced format first (has full structured data)
    if (roadmapPlan != null) {
      return _stagesFromEnhanced();
    }
    // Fallback to legacy format
    return _stagesFromLegacy();
  }

  /// Parse stages from enhanced roadmapPlan + curatedResources fields.
  List<RoadmapStage> _stagesFromEnhanced() {
    final phases = roadmapPlan?['phases'];
    if (phases is! List || phases.isEmpty) return _stagesFromLegacy();

    // Build resource map: phase_index -> list of resource strings
    final resourceMap = <int, List<String>>{};
    final resList = curatedResources?['resources'];
    if (resList is List) {
      for (final r in resList) {
        if (r is Map) {
          final idx = r['phase_index'];
          final title = r['title']?.toString() ?? '';
          final url = r['url']?.toString() ?? '';
          final display = title.isNotEmpty ? '$title ($url)' : url;
          if (idx is int && display.isNotEmpty) {
            resourceMap.putIfAbsent(idx, () => []).add(display);
          }
        }
      }
    }

    final stages = <RoadmapStage>[];
    for (var i = 0; i < phases.length; i++) {
      final phase = phases[i];
      if (phase is! Map) continue;

      final level = phase['level']?.toString() ?? (i < 3 ? ['beginner', 'intermediate', 'advanced'][i] : 'stage_${i + 1}');
      final title = phase['title']?.toString() ?? 'Phase ${i + 1}';

      // Extract tasks
      final rawTasks = phase['tasks'];
      final tasks = <String>[];
      if (rawTasks is List) {
        for (final t in rawTasks) {
          if (t is String && t.trim().isNotEmpty) tasks.add(t.trim());
        }
      }

      stages.add(RoadmapStage(
        level: level,
        title: title,
        tasks: tasks,
        resources: resourceMap[i] ?? [],
      ));
    }

    return stages.isNotEmpty ? stages : _stagesFromLegacy();
  }

  /// Parse stages from legacy milestones[] + resources[] fields.
  List<RoadmapStage> _stagesFromLegacy() {
    final stages = <RoadmapStage>[];
    final labels = ['beginner', 'intermediate', 'advanced'];
    final stageCount = milestones.length.clamp(1, 10);

    final resourcesPerStage = <int, List<String>>{};
    for (var i = 0; i < resources.length; i++) {
      final bucket = i % stageCount;
      resourcesPerStage.putIfAbsent(bucket, () => []).add(resources[i]);
    }

    for (var i = 0; i < milestones.length; i++) {
      final level = i < labels.length ? labels[i] : 'stage_${i + 1}';
      final raw = milestones[i];

      // Parse tasks from legacy milestone text (after ":")
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

      // For legacy, extract just the title part (before ":")
      String title = raw;
      if (colonIdx > 0) {
        title = raw.substring(0, colonIdx).trim();
      }

      stages.add(RoadmapStage(
        level: level,
        title: title,
        tasks: tasks,
        resources: resourcesPerStage[i] ?? [],
      ));
    }

    if (stages.isEmpty) {
      stages.add(RoadmapStage(
        level: 'beginner',
        title: 'Foundation',
        tasks: const ['Complete profile', 'Core concepts'],
        resources: resources,
      ));
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
      roadmapPlan: m['roadmapPlan'] is Map<String, dynamic> ? m['roadmapPlan'] as Map<String, dynamic> : null,
      curatedResources: m['curatedResources'] is Map<String, dynamic> ? m['curatedResources'] as Map<String, dynamic> : null,
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
      roadmapPlan: roadmapPlan,
      curatedResources: curatedResources,
    );
  }
}
