import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lsb_legal_app/core/presentation/session/flow_surface.dart';

/// Pestañas de la barra inferior, en su orden de aparición.
enum AppTab {
  conversation,
  cards,
  avatar;

  FlowSurface get surface => switch (this) {
        AppTab.conversation => FlowSurface.conversation,
        AppTab.cards => FlowSurface.standaloneCards,
        AppTab.avatar => FlowSurface.standaloneAvatar,
      };
}

/// Pestaña abierta.
///
/// Vive en un provider y no en el estado de la pantalla de navegación para que
/// cualquier parte de la aplicación pueda pedir un cambio de pestaña. Lo
/// necesita el retorno a la conversación desde el módulo de tarjetas: sin esto
/// habría que empujar y sacar rutas a mano, que es frágil y depende de cómo se
/// llegó hasta ahí.
class SelectedTabNotifier extends Notifier<AppTab> {
  @override
  AppTab build() => AppTab.conversation;

  void select(AppTab tab) => state = tab;

  void selectIndex(int index) {
    if (index < 0 || index >= AppTab.values.length) return;
    state = AppTab.values[index];
  }
}

final selectedTabProvider =
    NotifierProvider<SelectedTabNotifier, AppTab>(SelectedTabNotifier.new);
