import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../models/app_user.dart';
import '../models/consultation.dart';
import '../models/expert.dart';
import '../providers/app_services.dart';
import '../theme/glass_card.dart';
import '../theme/gradient_background.dart';
import '../widgets/skeleton_loader.dart';
import 'consultation_detail_screen.dart';

class BookConsultationScreen extends StatefulWidget {
  const BookConsultationScreen({super.key, required this.appUser, required this.expert});

  final AppUser appUser;
  final Expert expert;

  @override
  State<BookConsultationScreen> createState() => _BookConsultationScreenState();
}

class _BookConsultationScreenState extends State<BookConsultationScreen> {
  String _type = 'chat';
  DateTime _when = DateTime.now().add(const Duration(hours: 1));
  bool _booking = false;

  Future<void> _pickTime() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _when,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_when));
    if (t == null || !mounted) return;
    setState(() {
      _when = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    });
  }

  Future<void> _book() async {
    if (!widget.expert.isVerified) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Unverified expert'),
          content: const Text(
            'This expert is not verified. You can still proceed, but quality is not vetted by admins.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Continue')),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }

    if (_when.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a future slot — this time is unavailable.')),
      );
      return;
    }

    setState(() => _booking = true);
    try {
      final svc = context.svc;
      final c = Consultation(
        id: '',
        consultationId: '',
        userId: widget.appUser.uid,
        expertId: widget.expert.id,
        type: _type,
        status: 'pending',
        price: widget.expert.pricePerSession,
        questionLimit: 0,
        scheduledAt: _when,
        createdAt: DateTime.now(),
      );
      final id = await svc.consultations.create(c);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => ConsultationDetailScreen(
            consultationId: id,
            appUser: widget.appUser,
            expertDocId: widget.expert.id,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _booking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_booking) {
      return Scaffold(
        body: GradientBackground(
          variant: GradientVariant.accent,
          child: const Center(child: SkeletonLoader(lines: 3)),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Book Consultation')),
      body: GradientBackground(
        variant: GradientVariant.accent,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Pricing card
            GlassCard(
              child: Column(
                children: [
                  Text('Session Price', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Text(
                    'INR ${widget.expert.pricePerSession}',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 300.ms),

            const SizedBox(height: 16),

            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Session type', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 12),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'chat', label: Text('Chat'), icon: Icon(Icons.chat)),
                      ButtonSegment(value: 'audio', label: Text('Audio'), icon: Icon(Icons.mic)),
                      ButtonSegment(value: 'video', label: Text('Video'), icon: Icon(Icons.videocam)),
                    ],
                    selected: {_type},
                    onSelectionChanged: (s) => setState(() => _type = s.first),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 100.ms),

            const SizedBox(height: 16),

            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Schedule', style: theme.textTheme.titleSmall),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Scheduled time'),
                    subtitle: Text(DateFormat.yMMMd().add_jm().format(_when)),
                    trailing: IconButton(icon: const Icon(Icons.event), onPressed: _pickTime),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 200.ms),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _book,
                child: const Text('Create Booking (Pending Payment)'),
              ),
            )
                .animate()
                .fadeIn(delay: 300.ms),
          ],
        ),
      ),
    );
  }
}
