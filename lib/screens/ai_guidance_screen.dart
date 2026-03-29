import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../providers/app_services.dart';
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

  @override
  void dispose() {
    _resumeCtrl.dispose();
    _goalsCtrl.dispose();
    _skillCtrl.dispose();
    _interestCtrl.dispose();
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

  Future<void> _generate() async {
    final resume = _resumeCtrl.text.trim();
    final goals = _goalsCtrl.text.trim();
    if (resume.isEmpty && _skills.isEmpty && goals.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add résumé text, skills, or career goals so the AI module can analyze gaps.')),
      );
      return;
    }

    setState(() => _working = true);
    try {
      final svc = context.svc;
      final analysis = svc.ai.analyze(
        resumeText: resume,
        userSkills: [..._skills, ...widget.appUser.skills],
        interests: [..._interests, ...widget.appUser.interests],
        careerGoals: goals.isEmpty ? widget.appUser.careerGoals : goals,
      );
      final id = await svc.roadmaps.createFromAnalysis(
        userId: widget.appUser.uid,
        targetRole: analysis.targetRole,
        milestones: analysis.milestones,
        resources: analysis.resources,
        timeline: analysis.timeline,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Roadmap saved (extracted ${analysis.extractedSkills.length} skills)')),
      );
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => RoadmapDetailScreen(roadmapId: id),
        ),
      );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('AI guidance')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Résumé',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _resumeCtrl,
            minLines: 4,
            maxLines: 10,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Paste résumé text or upload a .txt file',
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _pickResumeFile,
            icon: const Icon(Icons.upload_file),
            label: const Text('Upload plain text (.txt / .md)'),
          ),
          const SizedBox(height: 20),
          Text('Skills', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
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
          Wrap(
            spacing: 8,
            children: _skills.map((s) => Chip(label: Text(s), onDeleted: () => setState(() => _skills.remove(s)))).toList(),
          ),
          const SizedBox(height: 16),
          Text('Interests', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _interestCtrl,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Interest area',
                  ),
                  onSubmitted: (_) => _addInterest(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: _addInterest, child: const Text('Add')),
            ],
          ),
          Wrap(
            spacing: 8,
            children: _interests
                .map((s) => Chip(label: Text(s), onDeleted: () => setState(() => _interests.remove(s))))
                .toList(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _goalsCtrl,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Career goals',
              hintText: 'e.g. Become an ML engineer in fintech',
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _working ? null : _generate,
            child: _working
                ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Analyze & generate roadmap'),
          ),
        ],
      ),
    );
  }
}
