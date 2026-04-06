import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../models/app_user.dart';
import '../models/consultation.dart';
import '../providers/app_services.dart';
import '../services/payment_service.dart';
import '../theme/glass_card.dart';
import '../widgets/error_state.dart';
import '../widgets/skeleton_loader.dart';
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

  Color _statusColor(String status, ColorScheme colorScheme) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.green;
      case 'completed':
        return colorScheme.primary;
      case 'cancelled':
        return Colors.red;
      default:
        return colorScheme.outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.svc;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Consultation')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('consultations')
            .doc(widget.consultationId)
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return ErrorStateWidget(
              message: 'Failed to load consultation details',
              onRetry: () {},
            );
          }

          if (!snap.hasData || snap.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: SkeletonLoader(lines: 4, hasAvatar: true),
            );
          }

          if (!snap.data!.exists) {
            return Center(
              child: Text(
                'Consultation not found',
                style: TextStyle(color: colorScheme.error),
              ),
            );
          }

          final c = Consultation.fromFirestore(snap.data!.id, snap.data!.data()!);
          final isUser = c.userId == widget.appUser.uid;

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
                  // Status and details card
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Consultation Details',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: _statusColor(c.status, colorScheme).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _statusColor(c.status, colorScheme).withOpacity(0.5),
                                ),
                              ),
                              child: Text(
                                c.status.toUpperCase(),
                                style: TextStyle(
                                  color: _statusColor(c.status, colorScheme),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _DetailRow(label: 'Type', value: c.type),
                        _DetailRow(label: 'Price', value: 'INR ${c.price}'),
                        _DetailRow(label: 'Questions', value: '${c.questionLimit}'),
                        if (c.scheduledAt != null)
                          _DetailRow(
                            label: 'Scheduled',
                            value: DateFormat.yMMMd().add_jm().format(c.scheduledAt!),
                          ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 300.ms),

                  const SizedBox(height: 16),

                  // Payment / action buttons
                  if (isUser && c.status == 'pending') ...[
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Payment Required',
                            style: theme.textTheme.titleSmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'INR ${c.price}',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
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
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () async {
                                await svc.consultations.updateStatus(c.id, 'cancelled');
                              },
                              child: const Text('Cancel booking'),
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 100.ms),
                  ],

                  if (canExpertAct && c.status == 'accepted') ...[
                    GlassCard(
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () async {
                            await svc.consultations.updateStatus(c.id, 'completed');
                          },
                          child: const Text('Mark completed'),
                        ),
                      ),
                    ).animate().fadeIn(delay: 100.ms),
                  ],

                  if (isUser && c.status == 'completed') ...[
                    GlassCard(
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonal(
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
                      ),
                    ).animate().fadeIn(delay: 100.ms),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
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
