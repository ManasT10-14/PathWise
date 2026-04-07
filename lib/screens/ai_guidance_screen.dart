import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/app_user.dart';
import '../providers/app_services.dart';
import '../theme/app_theme.dart';
import '../theme/glass_card.dart';
import '../theme/gradient_background.dart';
import '../widgets/ai_progress_indicator.dart';
import 'roadmap_detail_screen.dart';

class AiGuidanceScreen extends StatefulWidget {
  const AiGuidanceScreen({super.key, required this.appUser});

  final AppUser appUser;

  @override
  State<AiGuidanceScreen> createState() => _AiGuidanceScreenState();
}

class _AiGuidanceScreenState extends State<AiGuidanceScreen> {
  final _resumeCtrl = TextEditingController();
  final _goalsCtrl = TextEditingController();
  final _skillCtrl = TextEditingController();
  final _interestCtrl = TextEditingController();
  final List<String> _skills = [];
  final List<String> _interests = [];
  bool _working = false;
  int _aiStep = 0;

  final _pageController = PageController();
  int _currentPage = 0;

  static const _stepLabels = ['Goals', 'Skills', 'Resume', 'Interests'];

  @override
  void initState() {
    super.initState();
    _goalsCtrl.text = widget.appUser.careerGoals;
    _skills.addAll(widget.appUser.skills);
    _interests.addAll(widget.appUser.interests);
    _resumeCtrl.text = widget.appUser.resume;
  }

  @override
  void dispose() {
    _resumeCtrl.dispose();
    _goalsCtrl.dispose();
    _skillCtrl.dispose();
    _interestCtrl.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _pickResumeFile() async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['txt', 'md'],
      withData: true,
    );
    if (r == null || r.files.isEmpty) return;
    final f = r.files.single;
    final bytes = f.bytes;
    if (bytes != null) {
      final text = utf8.decode(bytes, allowMalformed: true);
      _resumeCtrl.text = text;
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not read file (try .txt). PDF parsing is not bundled — paste text instead.')),
      );
    }
  }

  void _addSkill() {
    final s = _skillCtrl.text.trim();
    if (s.isEmpty) return;
    setState(() {
      _skills.add(s);
      _skillCtrl.clear();
    });
  }

  void _addInterest() {
    final s = _interestCtrl.text.trim();
    if (s.isEmpty) return;
    setState(() {
      _interests.add(s);
      _interestCtrl.clear();
    });
  }

  void _nextStep() {
    if (_currentPage < 3) {
      setState(() => _currentPage++);
      _pageController.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _generate();
    }
  }

  void _previousStep() {
    if (_currentPage > 0) {
      setState(() => _currentPage--);
      _pageController.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _generate() async {
    final resume = _resumeCtrl.text.trim();
    final goals = _goalsCtrl.text.trim();
    if (resume.isEmpty && _skills.isEmpty && goals.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add resume text, skills, or career goals so the AI can analyze gaps.')),
      );
      return;
    }

    setState(() {
      _working = true;
      _aiStep = 0;
    });

    final svc = context.svc;
    Timer? stepTimer;

    try {
      // Simulate the 4-step Gemini prompt chain progressing while the single
      // HTTP call runs in the background.  Steps advance every 1.5 s; the
      // response handler cancels the timer and jumps to step 4.
      stepTimer = Timer.periodic(const Duration(milliseconds: 1500), (t) {
        if (_aiStep < 3) {
          if (mounted) setState(() => _aiStep++);
        } else {
          t.cancel();
        }
      });

      final effectiveGoals = goals.isEmpty ? widget.appUser.careerGoals : goals;

      String? roadmapId;

      try {
        // --- Primary path: FastAPI backend with Gemini 2.5 Flash ---
        final result = await svc.api.analyzeCareer(
          resumeText: resume,
          skills: _skills,
          interests: _interests,
          careerGoals: effectiveGoals,
        );

        stepTimer.cancel();
        if (mounted) setState(() => _aiStep = 4);

        roadmapId = result['roadmap_id']?.toString();
      } on DioException catch (e) {
        // --- Fallback: local keyword-based AiRoadmapService ---
        stepTimer.cancel();
        debugPrint('ApiClient error, falling back to local AI: $e');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Using offline analysis — connect to server for full AI analysis'),
              duration: Duration(seconds: 4),
            ),
          );
        }

        final analysis = svc.ai.analyze(
          resumeText: resume,
          userSkills: _skills,
          interests: _interests,
          careerGoals: effectiveGoals,
        );

        if (mounted) setState(() => _aiStep = 4);

        roadmapId = await svc.roadmaps.createFromAnalysis(
          userId: widget.appUser.uid,
          targetRole: analysis.targetRole,
          milestones: analysis.milestones,
          resources: analysis.resources,
          timeline: analysis.timeline,
          skillGaps: analysis.skillGaps,
          goalAnalysis: analysis.goalAnalysis,
        );
      }

      if (!mounted) return;
      if (roadmapId == null || roadmapId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Analysis complete — could not retrieve roadmap ID.')),
        );
        return;
      }

      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => RoadmapDetailScreen(roadmapId: roadmapId!),
        ),
      );
    } finally {
      stepTimer?.cancel();
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_working) {
      return Scaffold(
        body: GradientBackground(
          variant: GradientVariant.secondary,
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Generating your roadmap...',
                      style: theme.textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    AiProgressIndicator(currentStep: _aiStep),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('AI Guidance')),
      body: GradientBackground(
        variant: GradientVariant.secondary,
        child: SafeArea(
          child: Column(
            children: [
              // Progress indicator header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: _StepProgressBar(
                  currentStep: _currentPage,
                  stepLabels: _stepLabels,
                ),
              ),
              const SizedBox(height: 16),
              // Page view content
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _StepPage(
                      title: 'Career Goals',
                      subtitle: 'What do you want to achieve in your career?',
                      child: TextField(
                        controller: _goalsCtrl,
                        minLines: 3,
                        maxLines: 6,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'e.g. Become an ML engineer in fintech',
                          labelText: 'Career goals',
                        ),
                      ),
                    ),
                    _StepPage(
                      title: 'Your Skills',
                      subtitle: 'What skills do you currently have?',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _skillCtrl,
                                  decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                    hintText: 'Add a skill',
                                  ),
                                  onSubmitted: (_) => _addSkill(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              FilledButton(onPressed: _addSkill, child: const Text('Add')),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_skills.isNotEmpty)
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: _skills
                                  .map(
                                    (s) => Chip(
                                      label: Text(s),
                                      onDeleted: () => setState(() => _skills.remove(s)),
                                    ),
                                  )
                                  .toList(),
                            ),
                        ],
                      ),
                    ),
                    _StepPage(
                      title: 'Resume',
                      subtitle: 'Paste your resume or upload a text file.',
                      child: Column(
                        children: [
                          TextField(
                            controller: _resumeCtrl,
                            minLines: 4,
                            maxLines: 10,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              hintText: 'Paste resume text or upload a .txt file',
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _pickResumeFile,
                              icon: const Icon(Icons.upload_file),
                              label: const Text('Upload plain text (.txt / .md)'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _StepPage(
                      title: 'Interests',
                      subtitle: 'What topics or domains interest you?',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _interestCtrl,
                                  decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                    hintText: 'e.g. AI, Web Dev, Cloud, Data Science',
                                  ),
                                  onSubmitted: (_) => _addInterest(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              FilledButton(onPressed: _addInterest, child: const Text('Add')),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_interests.isNotEmpty)
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: _interests
                                  .map(
                                    (s) => Chip(
                                      label: Text(s),
                                      onDeleted: () => setState(() => _interests.remove(s)),
                                    ),
                                  )
                                  .toList(),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Navigation buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Row(
                  children: [
                    if (_currentPage > 0)
                      OutlinedButton(
                        onPressed: _previousStep,
                        child: const Text('Back'),
                      ),
                    const Spacer(),
                    FilledButton(
                      onPressed: _nextStep,
                      child: Text(
                        _currentPage == 3 ? 'Generate Roadmap' : 'Next',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepProgressBar extends StatelessWidget {
  const _StepProgressBar({
    required this.currentStep,
    required this.stepLabels,
  });

  final int currentStep;
  final List<String> stepLabels;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        Row(
          children: List.generate(stepLabels.length * 2 - 1, (i) {
            if (i.isOdd) {
              final stepIdx = i ~/ 2;
              return Expanded(
                child: Container(
                  height: 2,
                  color: stepIdx < currentStep
                      ? AppTheme.success
                      : colorScheme.outline.withOpacity(0.3),
                ),
              );
            }
            final stepIdx = i ~/ 2;
            final isCompleted = stepIdx < currentStep;
            final isActive = stepIdx == currentStep;

            return CircleAvatar(
              radius: 16,
              backgroundColor: isCompleted
                  ? AppTheme.success
                  : isActive
                      ? AppTheme.accent
                      : colorScheme.outline.withOpacity(0.3),
              child: isCompleted
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : Text(
                      '${stepIdx + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isActive ? colorScheme.onPrimary : colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: stepLabels
              .map(
                (label) => Text(
                  label,
                  style: textTheme.labelSmall,
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _StepPage extends StatelessWidget {
  const _StepPage({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ).animate().fadeIn(duration: 300.ms).slideX(begin: 0.05, end: 0),
    );
  }
}
