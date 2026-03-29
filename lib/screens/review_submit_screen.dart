import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../providers/app_services.dart';

class ReviewSubmitScreen extends StatefulWidget {
  const ReviewSubmitScreen({
    super.key,
    required this.appUser,
    required this.expertDocId,
    required this.consultationId,
  });

  final AppUser appUser;
  final String expertDocId;
  final String consultationId;

  @override
  State<ReviewSubmitScreen> createState() => _ReviewSubmitScreenState();
}

class _ReviewSubmitScreenState extends State<ReviewSubmitScreen> {
  double _rating = 5;
  final _feedback = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _feedback.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _sending = true);
    try {
      await context.svc.reviews.submitReview(
        userId: widget.appUser.uid,
        expertDocId: widget.expertDocId,
        consultationDocId: widget.consultationId,
        rating: _rating.round(),
        feedback: _feedback.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thank you — expert rating updated.')));
      Navigator.of(context).popUntil((r) => r.isFirst);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Review')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Rating: ${_rating.round()} / 5'),
          Slider(
            min: 1,
            max: 5,
            divisions: 4,
            label: _rating.round().toString(),
            value: _rating,
            onChanged: (v) => setState(() => _rating = v),
          ),
          TextField(
            controller: _feedback,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Feedback',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _sending ? null : _submit,
            child: _sending ? const CircularProgressIndicator() : const Text('Submit'),
          ),
        ],
      ),
    );
  }
}
