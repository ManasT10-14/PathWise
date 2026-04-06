import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Dio-based HTTP client that connects Flutter to the Pathwise FastAPI backend.
///
/// Responsibilities:
///   - Inject Firebase ID token on every request via Bearer interceptor
///   - Provide typed methods for AI analysis and payment endpoints
///   - Long receive timeout (60s) to accommodate Gemini 2.5 Flash latency (6-8s per call, 4 calls)
class ApiClient {
  ApiClient({
    String? baseUrl,
  }) : _baseUrl = baseUrl ??
            const String.fromEnvironment(
              'API_BASE_URL',
              defaultValue: 'http://10.0.2.2:8080',
            ) {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token =
            await FirebaseAuth.instance.currentUser?.getIdToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        // Surface the DioException to callers — don't swallow it.
        // Screens handle fallback behavior (e.g., local AI stub).
        handler.next(error);
      },
    ));
  }

  late final Dio _dio;
  final String _baseUrl;

  String get baseUrl => _baseUrl;

  // ---------------------------------------------------------------------------
  // AI Analysis
  // ---------------------------------------------------------------------------

  /// POST /api/v1/roadmaps/analyze
  ///
  /// Runs the 4-step Gemini 2.5 Flash prompt chain on the backend and writes
  /// the resulting roadmap to Firestore.
  ///
  /// Returns a [Map] matching the backend [AnalyzeResponse] schema:
  /// ```json
  /// {
  ///   "roadmap_id": "...",
  ///   "target_role": "...",
  ///   "goal_analysis": "...",
  ///   "skill_gaps": [...],
  ///   "milestones": [...],
  ///   "resources": [...],
  ///   "timeline": "...",
  ///   "confidence": 0.87
  /// }
  /// ```
  Future<Map<String, dynamic>> analyzeCareer({
    required String resumeText,
    required List<String> skills,
    required List<String> interests,
    required String careerGoals,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/roadmaps/analyze',
      data: {
        'resume_text': resumeText,
        'skills': skills,
        'interests': interests,
        'career_goals': careerGoals,
      },
    );
    return response.data ?? {};
  }

  // ---------------------------------------------------------------------------
  // Payments — server-side order creation and verification (PAY-01, PAY-02)
  // ---------------------------------------------------------------------------

  /// POST /api/v1/payments/create-order
  ///
  /// Asks the server to create a Razorpay order.  The server reads the price
  /// from Firestore — the client NEVER supplies an amount (prevents tampering).
  ///
  /// Returns:
  /// ```json
  /// { "order_id": "order_xxx", "amount": 49900, "currency": "INR" }
  /// ```
  Future<Map<String, dynamic>> createPaymentOrder({
    required String consultationId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/payments/create-order',
      data: {'consultation_id': consultationId},
    );
    return response.data ?? {};
  }

  /// POST /api/v1/payments/verify
  ///
  /// Sends Razorpay's payment response to the server for HMAC-SHA256
  /// signature verification.  On success the server updates the consultation
  /// status to "captured" — the client must NOT do this directly.
  ///
  /// Returns:
  /// ```json
  /// { "status": "captured", "consultation_id": "..." }
  /// ```
  Future<Map<String, dynamic>> verifyPayment({
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/payments/verify',
      data: {
        'razorpay_order_id': orderId,
        'razorpay_payment_id': paymentId,
        'razorpay_signature': signature,
      },
    );
    return response.data ?? {};
  }

  // ---------------------------------------------------------------------------
  // Adaptive Replanning (ADAPT-02)
  // ---------------------------------------------------------------------------

  /// POST /api/v1/roadmaps/replan
  ///
  /// Requests an AI-generated adjusted roadmap based on progress stall or
  /// explicit learner feedback. Rate limited to 3 replans per day (AI-10).
  ///
  /// Returns:
  /// ```json
  /// {
  ///   "new_roadmap_id": "...",
  ///   "replan_reason": "...",
  ///   "adjusted_milestones": [...],
  ///   "stalled_stages": [...],
  ///   "version": 2
  /// }
  /// ```
  Future<Map<String, dynamic>> replanRoadmap({
    required String roadmapId,
    required Map<String, double> currentProgress,
    String learnerFeedback = '',
    int? stallDays,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/roadmaps/replan',
      data: {
        'roadmap_id': roadmapId,
        'current_progress': currentProgress,
        'learner_feedback': learnerFeedback,
        if (stallDays != null) 'stall_days': stallDays,
      },
    );
    return response.data ?? {};
  }

  // ---------------------------------------------------------------------------
  // Expert Annotations (EXP-04, EXP-05)
  // ---------------------------------------------------------------------------

  /// POST /api/v1/roadmaps/annotate
  ///
  /// Stores an expert annotation for a specific milestone on a learner's roadmap.
  /// Annotations are fed into future AI replans (EXP-05).
  ///
  /// Returns:
  /// ```json
  /// { "status": "ok" }
  /// ```
  Future<Map<String, dynamic>> submitExpertAnnotation({
    required String roadmapId,
    required String userId,
    required String milestoneLevel,
    required String annotation,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/roadmaps/annotate',
      data: {
        'roadmap_id': roadmapId,
        'user_id': userId,
        'milestone_level': milestoneLevel,
        'annotation': annotation,
      },
    );
    return response.data ?? {};
  }
}
