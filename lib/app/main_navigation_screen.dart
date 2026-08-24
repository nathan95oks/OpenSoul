import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lsb_legal_app/core/session/flow_surface.dart';
import '../features/conversation/presentation/screens/conversation_screen.dart';
import '../features/lsb_to_text_audio/presentation/screens/home_screen.dart';
import '../features/audio_to_lsb/presentation/screens/audio_to_lsb_screen.dart';
import 'surface_session.dart';

/// Navegación raíz. La Conversación es el centro de la aplicación; los
/// flujos de tarjetas y de voz siguen accesibles como herramientas
/// directas mientras se completa la transición al modelo conversacional
/// (Fase 1 de la arquitectura unificada).
///
/// Cambiar de pestaña no es solo cambiar de pantalla: es cambiar de dueño de
/// los módulos de traducción, que comparten estado en el `ProviderScope`
/// raíz. Por eso cada salto anuncia su superficie a [SurfaceSession], que
/// deja el módulo destino en blanco — ver `surface_session.dart` para la
/// regla completa.
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

  static const List<Widget> _screens = [
    ConversationScreen(),
    HomeScreen(),
    AudioToLsbScreen(),
  ];

  void _select(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
    // Sin `await`: el reset no bloquea el cambio de pestaña. La pantalla
    // destino se reconstruye sola cuando el estado cae.
    ref.read(surfaceSessionProvider).enter(_surfaces[index]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
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
