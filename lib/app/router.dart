import 'package:go_router/go_router.dart';
import 'main_navigation_screen.dart';
import '../features/lsb_to_text_audio/presentation/screens/home_screen.dart';
import '../features/audio_to_lsb/presentation/screens/audio_to_lsb_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const MainNavigationScreen(),
    ),
    GoRoute(
      path: '/lsb-to-audio',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/audio-to-lsb',
      builder: (context, state) => const AudioToLsbScreen(),
    ),
  ],
);
