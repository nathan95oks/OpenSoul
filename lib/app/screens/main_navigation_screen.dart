import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lsb_legal_app/core/presentation/session/cards_flow_launch.dart';
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
  AppTabId get _currentTab => ref.watch(selectedTabProvider);

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
    ref.read(selectedTabProvider.notifier).select(tab);
    ref.read(flowSurfaceProvider.notifier).set(_surfaceOf(tab));
    // Una sesión restaurada no reanuda una respuesta a medias: el turno al
    // que apuntaba pudo cambiar mientras la aplicación estaba cerrada, y
    // enlazar a ciegas es colgar la respuesta de la pregunta equivocada. Se
    // vuelve al modo A, y responder se pide otra vez desde el chat.
    ref
        .read(cardsFlowLaunchProvider.notifier)
        .start(const CardsFlowLaunch.standalone());
  }

  static FlowSurface _surfaceOf(AppTabId tab) => switch (tab) {
        AppTabId.conversation => FlowSurface.conversation,
        AppTabId.cards => FlowSurface.standaloneCards,
        AppTabId.avatar => FlowSurface.standaloneAvatar,
      };

  void _select(int visualIndex) {
    final tab = kTabOrder[visualIndex];
    if (tab == _currentTab) return;
    ref.read(selectedTabProvider.notifier).select(tab);
    ref.read(surfaceSessionProvider).enter(_surfaceOf(tab));
    ref.read(sessionRestorerProvider).recordTab(tab);
  }

  /// Contenido de cada pestaña, en el mismo orden visual que la barra.
  ///
  /// El `IndexedStack` se indexa por posición visual y no por `AppTabId.index`:
  /// así reordenar la barra es cambiar [kTabOrder] y nada más.
  List<Widget> _screensInVisualOrder(AppTabId current) => [
        for (final tab in kTabOrder)
          switch (tab) {
            AppTabId.cards => const LsbFlowScreen(),
            AppTabId.conversation => const ConversationScreen(),
            // El IndexedStack mantiene la pantalla montada: le avisamos cuando
            // deja de estar visible para que el avatar deje de senar.
            AppTabId.avatar =>
              AudioToLsbScreen(isActive: current == AppTabId.avatar),
          },
      ];

  static const Map<AppTabId, BottomNavigationBarItem> _items = {
    AppTabId.cards: BottomNavigationBarItem(
      icon: Icon(Icons.sign_language),
      label: 'Tarjetas LSB',
    ),
    AppTabId.conversation: BottomNavigationBarItem(
      icon: Icon(Icons.forum),
      label: 'Conversación',
    ),
    AppTabId.avatar: BottomNavigationBarItem(
      icon: Icon(Icons.mic),
      label: 'Voz a LSB',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final current = _currentTab;
    return Scaffold(
      body: IndexedStack(
        index: visualIndexOf(current),
        children: _screensInVisualOrder(current),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: visualIndexOf(current),
        onTap: _select,
        items: [for (final tab in kTabOrder) _items[tab]!],
      ),
    );
  }
}
