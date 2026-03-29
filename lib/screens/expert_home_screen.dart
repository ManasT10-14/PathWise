import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/app_user.dart';
import '../models/consultation.dart';
import '../models/expert.dart';
import '../providers/app_services.dart';
import 'consultation_detail_screen.dart';

class ExpertHomeScreen extends StatelessWidget {
  const ExpertHomeScreen({super.key, required this.appUser});

  final AppUser appUser;

  @override
  Widget build(BuildContext context) {
    final svc = context.svc;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expert console'),
        actions: [
          IconButton(
            onPressed: () => svc.auth.signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: FutureBuilder<Expert?>(
        future: svc.experts.findExpertForUser(uid: appUser.uid, email: appUser.email),
        builder: (context, expertSnap) {
          if (!expertSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final expert = expertSnap.data;
          if (expert == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No expert profile linked to this account. Ask an admin to create an experts document with your email or linkedUserId.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return StreamBuilder<List<Consultation>>(
            stream: svc.consultations.watchForExpert(expert.id),
            builder: (context, snap) {
              final list = snap.data ?? [];
              if (list.isEmpty) {
                return const Center(child: Text('No consultation requests yet.'));
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final c = list[i];
                  return ListTile(
                    tileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    title: Text(c.status),
                    subtitle: Text(
                      '${c.type} • ${c.scheduledAt != null ? DateFormat.yMMMd().add_jm().format(c.scheduledAt!) : '—'}',
                    ),
                    trailing: Text('₹${c.price}'),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ConsultationDetailScreen(
                          consultationId: c.id,
                          appUser: appUser,
                          expertDocId: expert.id,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
