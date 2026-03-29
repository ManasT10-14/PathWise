import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../models/expert.dart';
import '../providers/app_services.dart';
import 'expert_detail_screen.dart';

class ExpertsScreen extends StatelessWidget {
  const ExpertsScreen({super.key, required this.appUser});

  final AppUser appUser;

  @override
  Widget build(BuildContext context) {
    final svc = context.svc;
    return Scaffold(
      appBar: AppBar(title: const Text('Experts')),
      body: StreamBuilder<List<Expert>>(
        stream: svc.experts.watchExperts(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snap.data!;
          if (list.isEmpty) {
            return const Center(child: Text('No experts yet.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final e = list[i];
              return ListTile(
                tileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                leading: CircleAvatar(
                  child: Text(e.name.isNotEmpty ? e.name[0].toUpperCase() : '?'),
                ),
                title: Text(e.name),
                subtitle: Text('${e.domain} • ★ ${e.rating.toStringAsFixed(1)} • ₹${e.pricePerSession}'),
                trailing: e.isVerified
                    ? const Icon(Icons.verified, color: Colors.blue)
                    : const Icon(Icons.help_outline, color: Colors.orange),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => ExpertDetailScreen(appUser: appUser, expert: e)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
