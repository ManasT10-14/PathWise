import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'providers/app_services.dart';
import 'screens/login_screen.dart';
import 'screens/role_router.dart';
import 'services/ai_roadmap_service.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/consultation_repository.dart';
import 'services/expert_repository.dart';
import 'services/payment_service.dart';
import 'services/review_repository.dart';
import 'services/roadmap_repository.dart';
import 'services/user_repository.dart';
import 'theme/app_theme.dart';

ValueNotifier<ThemeMode> themeMode = ValueNotifier(ThemeMode.dark);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const PathwiseApp());
}

class PathwiseApp extends StatefulWidget {
  const PathwiseApp({super.key});

  @override
  State<PathwiseApp> createState() => _PathwiseAppState();
}

class _PathwiseAppState extends State<PathwiseApp> {
  late final AuthService _auth;
  late final UserRepository _users;
  late final ExpertRepository _experts;
  late final ConsultationRepository _consultations;
  late final RoadmapRepository _roadmaps;
  late final ReviewRepository _reviews;
  late final AiRoadmapService _ai;
  late final PaymentService _payments;
  late final ApiClient _api;

  @override
  void initState() {
    super.initState();
    _auth = AuthService();
    _users = UserRepository();
    _experts = ExpertRepository();
    _consultations = ConsultationRepository();
    _roadmaps = RoadmapRepository();
    _reviews = ReviewRepository(expertRepository: _experts);
    _ai = AiRoadmapService();
    _payments = PaymentService();
    _api = ApiClient();
  }

  @override
  void dispose() {
    _payments.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider.value(value: _auth),
        Provider.value(value: _users),
        Provider.value(value: _experts),
        Provider.value(value: _consultations),
        Provider.value(value: _roadmaps),
        Provider.value(value: _reviews),
        Provider.value(value: _ai),
        Provider.value(value: _payments),
        Provider.value(value: _api),
      ],
      child: AppServices(
        auth: _auth,
        users: _users,
        experts: _experts,
        consultations: _consultations,
        roadmaps: _roadmaps,
        reviews: _reviews,
        ai: _ai,
        payments: _payments,
        api: _api,
        child: ValueListenableBuilder<ThemeMode>(
          valueListenable: themeMode,
          builder: (context, mode, _) => MaterialApp(
            title: 'Pathwise',
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: mode,
            home: const _AuthGate(),
          ),
        ),
      ),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final auth = context.svc.auth;
    return StreamBuilder<User?>(
      stream: auth.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final user = snapshot.data;
        if (user == null) {
          return const LoginScreen();
        }
        return RoleRouter(firebaseUser: user);
      },
    );
  }
}
