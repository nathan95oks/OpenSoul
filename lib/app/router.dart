import 'package:go_router/go_router.dart';
import 'splash_screen.dart';
import 'main_navigation_screen.dart';
import '../features/lsb_to_text_audio/presentation/screens/home_screen.dart';
import '../features/lsb_to_text_audio/presentation/screens/declaration_result_screen.dart';
import '../features/audio_to_lsb/presentation/screens/audio_to_lsb_screen.dart';

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
      builder: (context, state) => const HomeScreen(),
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
