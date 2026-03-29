import 'package:flutter/foundation.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

typedef PaymentSuccess = void Function(String paymentId);
typedef PaymentFailure = void Function(String message);

/// Wire real keys via `--dart-define=RAZORPAY_KEY=...` or replace defaults for testing.
class PaymentService {
  PaymentService() {
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handleSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handleError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternal);
  }

  final Razorpay _razorpay = Razorpay();
  PaymentSuccess? _onSuccess;
  PaymentFailure? _onFailure;

  static String get _key {
    const fromEnv = String.fromEnvironment('RAZORPAY_KEY', defaultValue: '');
    if (fromEnv.isNotEmpty) return fromEnv;
    return 'rzp_test_PLACEHOLDER_REPLACE';
  }

  void dispose() {
    _razorpay.clear();
  }

  void payConsultation({
    required num amountPaise,
    required String orderTitle,
    required PaymentSuccess onSuccess,
    required PaymentFailure onFailure,
    String? userEmail,
    String? userPhone,
  }) {
    _onSuccess = onSuccess;
    _onFailure = onFailure;
    if (_key.contains('PLACEHOLDER')) {
      onFailure(
        'Razorpay key not set. Use --dart-define=RAZORPAY_KEY=rzp_test_xxx or edit payment_service.dart.',
      );
      return;
    }
    final options = {
      'key': _key,
      'amount': amountPaise,
      'name': 'Pathwise',
      'description': orderTitle,
      'prefill': {
        if (userEmail != null && userEmail.isNotEmpty) 'email': userEmail,
        if (userPhone != null && userPhone.isNotEmpty) 'contact': userPhone,
      },
      'external': {'wallets': ['paytm']},
    };
    try {
      _razorpay.open(options);
    } catch (e) {
      onFailure(e.toString());
    }
  }

  void _handleSuccess(PaymentSuccessResponse r) {
    _onSuccess?.call(r.paymentId ?? 'unknown');
    _clearCallbacks();
  }

  void _handleError(PaymentFailureResponse r) {
    debugPrint('Razorpay error: ${r.message}');
    _onFailure?.call(r.message ?? 'Payment failed');
    _clearCallbacks();
  }

  void _handleExternal(ExternalWalletResponse r) {
    debugPrint('External wallet: ${r.walletName}');
  }

  void _clearCallbacks() {
    _onSuccess = null;
    _onFailure = null;
  }
}
