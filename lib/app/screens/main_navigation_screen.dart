import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lsb_legal_app/core/presentation/session/flow_surface.dart';
import 'package:lsb_legal_app/features/conversation/presentation/screens/conversation_screen.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/screens/home_screen.dart';
import 'package:lsb_legal_app/features/audio_to_lsb/presentation/screens/audio_to_lsb_screen.dart';
import 'package:lsb_legal_app/app/surface_session.dart';

class MainNavigationScreen extends ConsumerStatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  ConsumerState<MainNavigationScreen> createState() =>
      _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> {
  int _currentIndex = 0;

  static const List<FlowSurface> _surfaces = [
    FlowSurface.conversation,
    FlowSurface.standaloneCards,
    FlowSurface.standaloneAvatar,
  ];

  void _select(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
    ref.read(surfaceSessionProvider).enter(_surfaces[index]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          const ConversationScreen(),
          const HomeScreen(),
          // El IndexedStack mantiene la pantalla montada: le avisamos cuando
          // deja de estar visible para que el avatar deje de senar.
          AudioToLsbScreen(isActive: _currentIndex == 2),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _select,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.forum),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.sign_language),
            label: 'Tarjetas LSB',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.mic),
            label: 'Voz a LSB',
          ),
        ],
      ),
    );
  }
}
