import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/app_user.dart';
import '../models/consultation.dart';
import '../models/expert.dart';
import '../providers/app_services.dart';
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
  int _questionLimit = 5;

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

    final svc = context.svc;
    final c = Consultation(
      id: '',
      consultationId: '',
      userId: widget.appUser.uid,
      expertId: widget.expert.id,
      type: _type,
      status: 'pending',
      price: widget.expert.pricePerSession,
      questionLimit: _questionLimit,
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
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Book')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Session type', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'chat', label: Text('Chat'), icon: Icon(Icons.chat)),
              ButtonSegment(value: 'audio', label: Text('Audio'), icon: Icon(Icons.mic)),
              ButtonSegment(value: 'video', label: Text('Video'), icon: Icon(Icons.videocam)),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          const SizedBox(height: 20),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Scheduled time'),
            subtitle: Text(DateFormat.yMMMd().add_jm().format(_when)),
            trailing: IconButton(icon: const Icon(Icons.event), onPressed: _pickTime),
          ),
          Text('Question limit: $_questionLimit'),
          Slider(
            min: 1,
            max: 20,
            divisions: 19,
            value: _questionLimit.toDouble(),
            label: '$_questionLimit',
            onChanged: (v) => setState(() => _questionLimit = v.round()),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: _book, child: const Text('Create booking (pending payment)')),
        ],
      ),
    );
  }
}
