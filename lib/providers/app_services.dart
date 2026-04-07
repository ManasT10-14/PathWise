import 'package:flutter/widgets.dart';
import '../services/ai_roadmap_service.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/consultation_repository.dart';
import '../services/expert_repository.dart';
import '../services/notification_service.dart';
import '../services/payment_service.dart';
import '../services/review_repository.dart';
import '../services/roadmap_repository.dart';
import '../services/user_repository.dart';

/// Locates shared services from [BuildContext].
class AppServices extends InheritedWidget {
  const AppServices({
    super.key,
    required this.auth,
    required this.users,
    required this.experts,
    required this.consultations,
    required this.roadmaps,
    required this.reviews,
    required this.ai,
    required this.payments,
    required this.api,
    required this.chat,
    required this.notifications,
    required super.child,
  });

  final AuthService auth;
  final UserRepository users;
  final ExpertRepository experts;
  final ConsultationRepository consultations;
  final RoadmapRepository roadmaps;
  final ReviewRepository reviews;
  final AiRoadmapService ai;
  final PaymentService payments;
  final ApiClient api;
  final ChatService chat;
  final NotificationService notifications;

  static AppServices of(BuildContext context) {
    final s = context.dependOnInheritedWidgetOfExactType<AppServices>();
    assert(s != null, 'AppServices not found');
    return s!;
  }

  @override
  bool updateShouldNotify(covariant AppServices oldWidget) =>
      auth != oldWidget.auth ||
      users != oldWidget.users ||
      experts != oldWidget.experts ||
      consultations != oldWidget.consultations ||
      roadmaps != oldWidget.roadmaps ||
      reviews != oldWidget.reviews ||
      ai != oldWidget.ai ||
      payments != oldWidget.payments ||
      api != oldWidget.api ||
      chat != oldWidget.chat ||
      notifications != oldWidget.notifications;
}

extension AppServicesX on BuildContext {
  AppServices get svc => AppServices.of(this);
}
