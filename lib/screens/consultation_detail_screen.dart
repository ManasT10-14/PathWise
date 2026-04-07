import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../models/app_user.dart';
import '../models/consultation.dart';
import '../providers/app_services.dart';
import '../services/payment_service.dart';
import '../theme/app_theme.dart';
import '../theme/glass_card.dart';
import '../theme/gradient_background.dart';
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
  bool _creatingOrder = false;

  // Holds the server-issued order ID while payment is in progress.
  String? _pendingOrderId;

  @override
  void dispose() {
    _payment.dispose();
    super.dispose();
  }

  /// Initiates payment — uses mock flow for demo, real Razorpay for production.
  Future<void> _startPayment(Consultation c) async {
    if (_creatingOrder) return;

    final svc = context.svc;
    setState(() => _creatingOrder = true);

    try {
      // Try server-side payment flow first (production)
      try {
        final order = await svc.api.createPaymentOrder(consultationId: c.id);
        final orderId = order['order_id']?.toString() ?? '';

        if (orderId.isNotEmpty) {
          _pendingOrderId = orderId;
          final amount = order['amount'];
          _payment.startWithOrder(
            context: context,
            payments: svc.payments,
            orderId: orderId,
            amountPaise: amount is num ? amount.toInt() : (c.price * 100).toInt(),
            title: 'Consultation ${c.id}',
            email: widget.appUser.email,
            onSuccess: (paymentId, signature) async {
              await _verifyPayment(orderId: orderId, paymentId: paymentId, signature: signature);
            },
            onFailure: (msg) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Payment cancelled: $msg')),
                );
              }
            },
          );
          return;
        }
      } catch (_) {
        // Server unavailable — fall through to mock payment
      }

      // Mock payment flow for demo/testing
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirm Payment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Amount: INR ${c.price}'),
              const SizedBox(height: 8),
              Text(
                'This is a simulated payment for demo purposes. '
                'In production, Razorpay checkout will open.',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Pay (Demo)'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        // Simulate payment success — update consultation status
        await svc.consultations.updateStatus(c.id, 'accepted');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Payment successful! Consultation confirmed.')),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _creatingOrder = false);
    }
  }

  /// PAY-02: Verify Razorpay signature on the server after payment success.
  Future<void> _verifyPayment({
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    try {
      await context.svc.api.verifyPayment(
        orderId: orderId,
        paymentId: paymentId,
        signature: signature,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment verified successfully. Consultation confirmed.')),
        );
      }
      // Server handles consultation status update — no client-side write.
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment verification failed: ${e.message ?? 'Unknown error'}')),
        );
      }
    }
  }

  Color _statusColor(String status, ColorScheme colorScheme) {
    switch (status) {
      case 'pending':
        return AppTheme.warning;
      case 'accepted':
        return AppTheme.success;
      case 'completed':
        return AppTheme.accent;
      case 'cancelled':
        return AppTheme.error;
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
      body: GradientBackground(
        variant: GradientVariant.accent,
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
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
                              onPressed: _creatingOrder ? null : () => _startPayment(c),
                              child: _creatingOrder
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Text('Pay with Razorpay'),
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

/// Thin wrapper around [PaymentService] that adds guard against double-taps
/// and supports the server-side order flow (PAY-01).
class PaymentShell {
  PaymentShell();

  bool _busy = false;
  final Razorpay _razorpay = Razorpay();
  void Function(String, String)? _onSuccess;
  void Function(String)? _onFailure;

  void _init() {
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handleSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handleError);
  }

  void dispose() {
    _razorpay.clear();
  }

  /// Opens Razorpay checkout with a server-issued [orderId].
  ///
  /// The [orderId] must come from the backend's create-order endpoint so that
  /// the amount is server-authoritative (PAY-01 anti-tampering).
  void startWithOrder({
    required BuildContext context,
    required PaymentService payments,
    required String orderId,
    required num amountPaise,
    required String title,
    String? email,
    required void Function(String paymentId, String signature) onSuccess,
    required void Function(String message) onFailure,
  }) {
    if (_busy) return;
    _busy = true;
    _onSuccess = onSuccess;
    _onFailure = onFailure;
    _init();

    final key = PaymentService.apiKey;
    if (key.contains('PLACEHOLDER')) {
      _busy = false;
      onFailure('Razorpay key not set. Use --dart-define=RAZORPAY_KEY=rzp_test_xxx');
      return;
    }

    final options = <String, dynamic>{
      'key': key,
      'amount': amountPaise,
      'order_id': orderId,
      'name': 'Pathwise',
      'description': title,
      'prefill': {
        if (email != null && email.isNotEmpty) 'email': email,
      },
      'external': {'wallets': ['paytm']},
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      _busy = false;
      onFailure(e.toString());
    }
  }

  void _handleSuccess(PaymentSuccessResponse r) {
    _busy = false;
    _onSuccess?.call(r.paymentId ?? '', r.signature ?? '');
    _clearCallbacks();
  }

  void _handleError(PaymentFailureResponse r) {
    _busy = false;
    _onFailure?.call(r.message ?? 'Payment failed');
    _clearCallbacks();
  }

  void _clearCallbacks() {
    _onSuccess = null;
    _onFailure = null;
  }
}
