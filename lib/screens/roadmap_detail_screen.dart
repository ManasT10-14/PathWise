import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/roadmap.dart';
import '../providers/app_services.dart';
import '../services/roadmap_repository.dart';
import '../theme/glass_card.dart';
import '../theme/gradient_background.dart';
import '../widgets/confidence_badge.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/timeline_node.dart';

class RoadmapDetailScreen extends StatelessWidget {
  const RoadmapDetailScreen({super.key, required this.roadmapId});

  final String roadmapId;

  @override
  Widget build(BuildContext context) {
    final svc = context.svc;
    return Scaffold(
      appBar: AppBar(title: const Text('Your Roadmap')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('roadmaps').doc(roadmapId).snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return GradientBackground(
              variant: GradientVariant.primary,
              child: ErrorStateWidget(
                message: 'Failed to load roadmap',
                onRetry: () {},
              ),
            );
          }
          if (!snap.hasData || snap.connectionState == ConnectionState.waiting) {
            return GradientBackground(
              variant: GradientVariant.primary,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: SkeletonLoader.list(itemCount: 3),
              ),
            );
          }
          if (!snap.data!.exists) {
            return GradientBackground(
              variant: GradientVariant.primary,
              child: EmptyStateWidget(
                title: 'No Roadmap Yet',
                subtitle: 'Complete the AI guidance wizard to generate your personalized roadmap',
                icon: Icons.map_outlined,
              ),
            );
          }

          final r = Roadmap.fromFirestore(snap.data!.id, snap.data!.data()!);
          final rawData = snap.data!.data()!;

          // Extract skill gaps if available (progressive enhancement)
          List<Map<String, dynamic>>? skillGaps;
          if (rawData['skillGaps'] is List) {
            skillGaps = (rawData['skillGaps'] as List)
                .whereType<Map<String, dynamic>>()
                .toList();
          }

          return _RoadmapBody(
            roadmap: r,
            repo: svc.roadmaps,
            skillGaps: skillGaps,
          );
        },
      ),
    );
  }
}

class _RoadmapBody extends StatefulWidget {
  const _RoadmapBody({
    required this.roadmap,
    required this.repo,
    this.skillGaps,
  });

  final Roadmap roadmap;
  final RoadmapRepository repo;
  final List<Map<String, dynamic>>? skillGaps;

  @override
  State<_RoadmapBody> createState() => _RoadmapBodyState();
}

class _RoadmapBodyState extends State<_RoadmapBody> {
  late Map<String, double> _progress;
  bool _isReplanning = false;

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

  Future<void> _updateProgress(String level, double val) async {
    setState(() => _progress[level] = val);
    await widget.repo.updateProgress(widget.roadmap.id, _progress);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Progress saved')));
    }
  }

  bool _isCurrentStage(int index, List<RoadmapStage> stages) {
    // First stage with progress < 1.0 is the current stage
    for (var i = 0; i < stages.length; i++) {
      final progress = _progress[stages[i].level] ?? 0.0;
      if (progress < 1.0) return i == index;
    }
    return false;
  }

  double _overallProgress(List<RoadmapStage> stages) {
    if (stages.isEmpty) return 0.0;
    final total = stages.fold<double>(
      0.0,
      (sum, s) => sum + (_progress[s.level] ?? 0.0),
    );
    return total / stages.length;
  }

  Future<void> _triggerReplan({String feedback = ''}) async {
    final apiClient = context.svc.api;
    setState(() => _isReplanning = true);

    try {
      final stallDays = widget.roadmap.daysSinceUpdate();
      final result = await apiClient.replanRoadmap(
        roadmapId: widget.roadmap.id,
        currentProgress: _progress,
        learnerFeedback: feedback,
        stallDays: stallDays,
      );

      final newRoadmapId = result['new_roadmap_id'] as String?;
      if (newRoadmapId != null && mounted) {
        // Navigate to the new versioned roadmap document
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => RoadmapDetailScreen(roadmapId: newRoadmapId),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Replan failed: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isReplanning = false);
    }
  }

  Future<void> _showReplanDialog() async {
    final feedbackController = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Replan Your Roadmap'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'The AI will generate an adjusted roadmap based on your progress. '
              'Optionally tell us what you\'re struggling with:',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: feedbackController,
              maxLines: 3,
              maxLength: 500,
              decoration: const InputDecoration(
                hintText: 'e.g. "I find the math in ML difficult..."',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _triggerReplan(feedback: feedbackController.text);
            },
            child: const Text('Replan'),
          ),
        ],
      ),
    );
    feedbackController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final stages = widget.roadmap.structuredStages;

    if (stages.isEmpty) {
      return GradientBackground(
        variant: GradientVariant.primary,
        child: EmptyStateWidget(
          title: 'No Roadmap Yet',
          subtitle: 'Complete the AI guidance wizard to generate your personalized roadmap',
          icon: Icons.map_outlined,
        ),
      );
    }

    final overallProgress = _overallProgress(stages);

    return GradientBackground(
      variant: GradientVariant.primary,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Header card with overall progress
          GlassCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.roadmap.targetRole.isEmpty
                            ? 'Your Roadmap'
                            : widget.roadmap.targetRole,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Timeline: ${widget.roadmap.timeline}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 56,
                  height: 56,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: overallProgress,
                        strokeWidth: 5,
                        backgroundColor: colorScheme.outline.withOpacity(0.2),
                        color: colorScheme.primary,
                      ),
                      Text(
                        '${(overallProgress * 100).round()}%',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 500.ms).scale(
                      begin: const Offset(0.9, 0.9),
                      end: const Offset(1, 1),
                    ),
              ],
            ),
          ),

          // Replan version banner (shown on replanned roadmaps — ADAPT-03)
          if (widget.roadmap.replanReason != null) ...[
            const SizedBox(height: 12),
            GlassCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.auto_fix_high, color: colorScheme.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Version ${widget.roadmap.replanVersion ?? 2} — Adapted for you',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.roadmap.replanReason!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.05, end: 0),
          ],

          // Skill gaps section (progressive enhancement)
          if (widget.skillGaps != null && widget.skillGaps!.isNotEmpty) ...[
            const SizedBox(height: 16),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Skill Gaps', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: widget.skillGaps!.map((gap) {
                      final confidence = (gap['confidence'] as num?)?.toDouble() ?? 0.0;
                      final skill = gap['skill']?.toString() ?? '';
                      return ConfidenceBadge(
                        confidence: confidence,
                        label: skill.isEmpty ? null : skill,
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],

          // Replan trigger (shown when roadmap is stalled — ADAPT-01)
          if (widget.roadmap.isStalled()) ...[
            const SizedBox(height: 12),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Progress stalled for ${widget.roadmap.daysSinceUpdate()} days',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your roadmap can be adjusted to better match your current pace.',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isReplanning ? null : _showReplanDialog,
                      icon: _isReplanning
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_fix_high, size: 18),
                      label: Text(_isReplanning ? 'Replanning...' : 'Replan Roadmap'),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0),
          ],

          const SizedBox(height: 20),

          // Timeline nodes
          ...List.generate(stages.length, (i) {
            final stage = stages[i];
            final progress = _progress[stage.level] ?? 0.0;
            return SizedBox(
              height: 200 + (stage.tasks.isNotEmpty ? 80.0 : 0),
              child: TimelineNode(
                stage: stage,
                progress: progress,
                isFirst: i == 0,
                isLast: i == stages.length - 1,
                isCurrent: _isCurrentStage(i, stages),
                onProgressChanged: (val) => _updateProgress(stage.level, val),
                index: i,
              ),
            );
          }),
        ],
      ),
    );
  }
}
