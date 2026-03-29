import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../models/expert.dart';
import 'book_consultation_screen.dart';

class ExpertDetailScreen extends StatelessWidget {
  const ExpertDetailScreen({super.key, required this.appUser, required this.expert});

  final AppUser appUser;
  final Expert expert;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(expert.name)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(expert.domain, style: theme.textTheme.titleMedium),
            subtitle: Text('${expert.experience} experience'),
            trailing: expert.isVerified
                ? const Chip(label: Text('Verified'), avatar: Icon(Icons.verified, size: 18))
                : const Chip(label: Text('Unverified'), avatar: Icon(Icons.warning_amber, size: 18)),
          ),
          const SizedBox(height: 8),
          Text('Rating: ${expert.rating.toStringAsFixed(1)} (${expert.totalReviews} reviews)'),
          Text('Price per session: ₹${expert.pricePerSession}'),
          if (expert.skills.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Skills', style: theme.textTheme.titleSmall),
            Wrap(
              spacing: 8,
              children: expert.skills.map((s) => Chip(label: Text(s))).toList(),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => BookConsultationScreen(appUser: appUser, expert: expert),
                ),
              );
            },
            child: const Text('Book consultation'),
          ),
        ],
      ),
    );
  }
}
