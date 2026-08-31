import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lsb_legal_app/core/presentation/session/flow_surface.dart';
import 'package:lsb_legal_app/features/conversation/presentation/screens/conversation_screen.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/screens/lsb_flow_screen.dart';
import 'package:lsb_legal_app/features/audio_to_lsb/presentation/screens/audio_to_lsb_screen.dart';
import 'package:lsb_legal_app/app/surface_session.dart';
import 'package:lsb_legal_app/app/session_restorer.dart';
import 'package:lsb_legal_app/app/navigation_provider.dart';

class MainNavigationScreen extends ConsumerStatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  ConsumerState<MainNavigationScreen> createState() =>
      _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen>
    with WidgetsBindingObserver {
  int get _currentIndex => ref.watch(selectedTabProvider).index;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restaurarSesion();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Al pasar a segundo plano se escribe ya, sin esperar al retardo: puede
    // que no haya una proxima oportunidad si el sistema mata el proceso.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      ref.read(sessionRestorerProvider).saveNow();
    }
  }

  Future<void> _restaurarSesion() async {
    final tab = await ref.read(sessionRestorerProvider).restore();
    if (!mounted || tab == null) return;
    ref.read(selectedTabProvider.notifier).selectIndex(tab);
    ref.read(flowSurfaceProvider.notifier).set(_surfaces[tab]);
  }

  static const List<FlowSurface> _surfaces = [
    FlowSurface.conversation,
    FlowSurface.standaloneCards,
    FlowSurface.standaloneAvatar,
  ];

  void _select(int index) {
    if (index == _currentIndex) return;
    ref.read(selectedTabProvider.notifier).selectIndex(index);
    ref.read(surfaceSessionProvider).enter(_surfaces[index]);
    ref.read(sessionRestorerProvider).recordTab(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          const ConversationScreen(),
          const LsbFlowScreen(),
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
