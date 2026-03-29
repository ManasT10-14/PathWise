import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../models/consultation.dart';
import '../providers/app_services.dart';
import '../services/payment_service.dart';
import 'review_submit_screen.dart';

class ConsultationDetailScreen extends StatefulWidget {
  const ConsultationDetailScreen({
    super.key,
    required this.consultationId,
    required this.appUser,
    required this.expertDocId,
  });

  final String consultationId;
  final AppUser appUser;
  final String expertDocId;

  @override
  State<ConsultationDetailScreen> createState() => _ConsultationDetailScreenState();
}

class _ConsultationDetailScreenState extends State<ConsultationDetailScreen> {
  final _payment = PaymentShell();

  @override
  void dispose() {
    _payment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.svc;
    return Scaffold(
      appBar: AppBar(title: const Text('Consultation')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('consultations').doc(widget.consultationId).snapshots(),
        builder: (context, snap) {
          if (!snap.hasData || !snap.data!.exists) {
            return const Center(child: CircularProgressIndicator());
          }
          final c = Consultation.fromFirestore(snap.data!.id, snap.data!.data()!);
          final isUser = c.userId == widget.appUser.uid;
          final theme = Theme.of(context);

          return FutureBuilder(
            future: svc.experts.fetchExpert(c.expertId),
            builder: (context, expertSnap) {
              final ex = expertSnap.data;
              final isAssignedExpert = ex != null &&
                  (ex.linkedUserId == widget.appUser.uid ||
                      ex.email.toLowerCase() == widget.appUser.email.toLowerCase());
              final canExpertAct = isAssignedExpert || widget.appUser.role == UserRole.admin;

              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text('Status: ${c.status}', style: theme.textTheme.titleMedium),
                  Text('Type: ${c.type}'),
                  Text('Price: ₹${c.price}'),
                  Text('Questions: ${c.questionLimit}'),
                  if (c.scheduledAt != null) Text('Scheduled: ${c.scheduledAt}'),
                  const Divider(height: 32),
                  if (isUser && c.status == 'pending') ...[
                    FilledButton(
                      onPressed: () {
                        _payment.start(
                          context: context,
                          payments: svc.payments,
                          amountPaise: (c.price).toInt() * 100,
                          title: 'Consultation ${c.id}',
                          email: widget.appUser.email,
                          onSuccess: (paymentId) async {
                            await svc.consultations.updateStatus(c.id, 'accepted');
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Payment OK ($paymentId). Session accepted.')),
                              );
                            }
                          },
                          onFailure: (msg) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Payment failed or cancelled: $msg')),
                              );
                            }
                          },
                        );
                      },
                      child: const Text('Pay with Razorpay'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () async {
                        await svc.consultations.updateStatus(c.id, 'cancelled');
                      },
                      child: const Text('Cancel booking'),
                    ),
                  ],
                  if (canExpertAct && c.status == 'accepted') ...[
                    FilledButton(
                      onPressed: () async {
                        await svc.consultations.updateStatus(c.id, 'completed');
                      },
                      child: const Text('Mark completed'),
                    ),
                  ],
                  if (isUser && c.status == 'completed')
                    FilledButton.tonal(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ReviewSubmitScreen(
                            appUser: widget.appUser,
                            expertDocId: c.expertId,
                            consultationId: c.id,
                          ),
                        ),
                      ),
                      child: const Text('Submit review'),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class PaymentShell {
  PaymentShell();

  bool _busy = false;

  void dispose() {}

  void start({
    required BuildContext context,
    required PaymentService payments,
    required num amountPaise,
    required String title,
    String? email,
    required void Function(String paymentId) onSuccess,
    required void Function(String message) onFailure,
  }) {
    if (_busy) return;
    _busy = true;
    payments.payConsultation(
      amountPaise: amountPaise,
      orderTitle: title,
      userEmail: email,
      onSuccess: (id) {
        _busy = false;
        onSuccess(id);
      },
      onFailure: (m) {
        _busy = false;
        onFailure(m);
      },
    );
  }
}
