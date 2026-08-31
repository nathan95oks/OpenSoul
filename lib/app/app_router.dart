import 'package:go_router/go_router.dart';
import 'package:lsb_legal_app/app/screens/splash_screen.dart';
import 'package:lsb_legal_app/app/screens/main_navigation_screen.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/screens/lsb_flow_screen.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/screens/declaration_result_screen.dart';
import 'package:lsb_legal_app/features/audio_to_lsb/presentation/screens/audio_to_lsb_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const MainNavigationScreen(),
    ),
    GoRoute(
      path: '/lsb-to-audio',
      builder: (context, state) => const LsbFlowScreen(),
      routes: [
        GoRoute(
          path: 'result',
          builder: (context, state) => const DeclarationResultScreen(),
        ),
      ],
    ),
    GoRoute(
      path: '/audio-to-lsb',
      builder: (context, state) => const AudioToLsbScreen(),
    ),
  ],
);
