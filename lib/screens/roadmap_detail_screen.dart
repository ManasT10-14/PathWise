import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/roadmap.dart';
import '../providers/app_services.dart';
import '../services/roadmap_repository.dart';

class RoadmapDetailScreen extends StatelessWidget {
  const RoadmapDetailScreen({super.key, required this.roadmapId});

  final String roadmapId;

  @override
  Widget build(BuildContext context) {
    final svc = context.svc;
    return Scaffold(
      appBar: AppBar(title: const Text('Your roadmap')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('roadmaps').doc(roadmapId).snapshots(),
        builder: (context, snap) {
          if (!snap.hasData || !snap.data!.exists) {
            return const Center(child: CircularProgressIndicator());
          }
          final r = Roadmap.fromFirestore(snap.data!.id, snap.data!.data()!);
          return _RoadmapBody(roadmap: r, repo: svc.roadmaps);
        },
      ),
    );
  }
}

class _RoadmapBody extends StatefulWidget {
  const _RoadmapBody({required this.roadmap, required this.repo});

  final Roadmap roadmap;
  final RoadmapRepository repo;

  @override
  State<_RoadmapBody> createState() => _RoadmapBodyState();
}

class _RoadmapBodyState extends State<_RoadmapBody> {
  late Map<String, double> _progress;

  @override
  void initState() {
    super.initState();
    _progress = Map<String, double>.from(widget.roadmap.stageProgress);
    for (final s in ['beginner', 'intermediate', 'advanced']) {
      _progress.putIfAbsent(s, () => 0);
    }
  }

  @override
  void didUpdateWidget(covariant _RoadmapBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.roadmap.id != widget.roadmap.id) {
      _progress = Map<String, double>.from(widget.roadmap.stageProgress);
    }
  }

  Future<void> _persist() async {
    await widget.repo.updateProgress(widget.roadmap.id, _progress);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Progress saved')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stages = widget.roadmap.structuredStages;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(widget.roadmap.targetRole, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Timeline: ${widget.roadmap.timeline}', style: theme.textTheme.bodyMedium),
        const SizedBox(height: 20),
        ...stages.map((stage) {
          final key = stage.level;
          final value = _progress[key] ?? 0.0;
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(key.toUpperCase(), style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary)),
                  const SizedBox(height: 6),
                  Text(stage.title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (stage.resources.isNotEmpty) ...[
                    Text('Resources', style: theme.textTheme.labelMedium),
                    ...stage.resources.map((u) => SelectableText(u, style: theme.textTheme.bodySmall)),
                  ],
                  const SizedBox(height: 8),
                  Text('Stage progress'),
                  Slider(
                    value: value.clamp(0, 1),
                    onChanged: (v) => setState(() => _progress[key] = v),
                  ),
                ],
              ),
            ),
          );
        }),
        FilledButton(onPressed: _persist, child: const Text('Save progress')),
      ],
    );
  }
}
