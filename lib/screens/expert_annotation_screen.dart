import 'package:flutter/material.dart';
import '../providers/app_services.dart';
import '../theme/glass_card.dart';
import '../theme/gradient_background.dart';

/// ExpertAnnotationScreen — EXP-04
///
/// Allows an expert to annotate a specific milestone on a learner's roadmap.
/// The annotation is submitted to the backend, stored in learner_memory,
/// and injected into future AI replans (EXP-05).
class ExpertAnnotationScreen extends StatefulWidget {
  const ExpertAnnotationScreen({
    super.key,
    required this.roadmapId,
    required this.learnerId,
    required this.consultationId,
  });

  final String roadmapId;
  final String learnerId;
  final String consultationId;

  @override
  State<ExpertAnnotationScreen> createState() => _ExpertAnnotationScreenState();
}

class _ExpertAnnotationScreenState extends State<ExpertAnnotationScreen> {
  final _annotationController = TextEditingController();
  String _selectedLevel = 'beginner';
  bool _isSubmitting = false;
  bool _submitted = false;

  static const _levels = ['beginner', 'intermediate', 'advanced'];

  @override
  void dispose() {
    _annotationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _annotationController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an annotation')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await context.svc.api.submitExpertAnnotation(
        roadmapId: widget.roadmapId,
        userId: widget.learnerId,
        milestoneLevel: _selectedLevel,
        annotation: text,
      );
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _submitted = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit annotation: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Annotate Roadmap')),
      body: GradientBackground(
        variant: GradientVariant.primary,
        child: _submitted
            ? _buildSuccessState(theme, colorScheme)
            : _buildForm(theme, colorScheme),
      ),
    );
  }

  Widget _buildSuccessState(ThemeData theme, ColorScheme colorScheme) {
    return Center(
      child: GlassCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, size: 56, color: colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'Annotation Submitted',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Your feedback will be incorporated into the learner\'s next AI replan.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(ThemeData theme, ColorScheme colorScheme) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Milestone Stage', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              // Level selector chips
              Wrap(
                spacing: 8,
                children: _levels.map((level) {
                  final selected = _selectedLevel == level;
                  return ChoiceChip(
                    label: Text(level[0].toUpperCase() + level.substring(1)),
                    selected: selected,
                    onSelected: (_) => setState(() => _selectedLevel = level),
                    selectedColor: colorScheme.primaryContainer,
                    labelStyle: TextStyle(
                      color: selected ? colorScheme.onPrimaryContainer : null,
                      fontWeight: selected ? FontWeight.bold : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Your Observation', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Text(
                'Describe what you noticed about the learner\'s understanding or struggles. '
                'Be specific — this note will be used by the AI to adjust their roadmap.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _annotationController,
                maxLines: 6,
                maxLength: 800,
                decoration: InputDecoration(
                  hintText: 'e.g. "Learner understands CNNs conceptually but struggles with PyTorch '
                      'implementation — recommend a hands-on project before advancing."',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton.icon(
            onPressed: _isSubmitting ? null : _submit,
            icon: _isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_outlined),
            label: Text(_isSubmitting ? 'Submitting...' : 'Submit Annotation'),
          ),
        ),
      ],
    );
  }
}
