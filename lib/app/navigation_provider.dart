import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Los tres módulos de la barra inferior.
///
/// El identificador es una cadena y no la posición en el enum. Antes se
/// persistía el índice del enum y el orden visual salía de una lista paralela,
/// así que reordenar la barra —o insertar un valor— hacía que una sesión guardada
/// reabriera otro módulo, en silencio. El orden visual vive en [kTabOrder] y
/// puede cambiarse sin tocar lo guardado.
///
/// El orden de declaración es **deliberadamente distinto** del orden visual
/// ([kTabOrder]). Si coincidieran, un uso accidental de `AppTabId.index` como
/// posición funcionaría por casualidad y nadie lo notaría hasta reordenar la
/// barra. Así rompe de inmediato.
enum AppTabId {
  conversation('conversation'),
  cards('cards'),
  avatar('avatar');

  final String id;

  const AppTabId(this.id);

  static AppTabId? byId(String? id) {
    if (id == null) return null;
    for (final t in AppTabId.values) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// Traduce el índice que persistía la versión anterior.
  ///
  /// Aquel orden era: 0 conversación, 1 tarjetas, 2 avatar. No coincide con el
  /// actual, así que leerlo como posición abriría el módulo equivocado.
  static const List<AppTabId> legacyIndexOrder = [
    AppTabId.conversation,
    AppTabId.cards,
    AppTabId.avatar,
  ];

  static AppTabId? fromLegacyIndex(int? index) {
    if (index == null || index < 0 || index >= legacyIndexOrder.length) {
      return null;
    }
    return legacyIndexOrder[index];
  }
}

/// Orden de izquierda a derecha en la barra inferior.
///
/// Conversación va en el centro en ambos modos de uso: es el punto de
/// encuentro de los dos módulos de traducción, no una pestaña más.
const List<AppTabId> kTabOrder = [
  AppTabId.cards,
  AppTabId.conversation,
  AppTabId.avatar,
];

/// Posición visual de una pestaña. El `IndexedStack` se indexa con esto, no
/// con `AppTabId.index`.
int visualIndexOf(AppTabId tab) => kTabOrder.indexOf(tab);

/// Pestaña abierta.
///
/// Vive en un provider y no en el estado de la pantalla de navegación para que
/// cualquier parte de la aplicación pueda pedir un cambio de pestaña. Lo
/// necesita el retorno a la conversación desde el módulo de tarjetas: sin esto
/// habría que empujar y sacar rutas a mano, que es frágil y depende de cómo se
/// llegó hasta ahí.
class SelectedTabNotifier extends Notifier<AppTabId> {
  @override
  AppTabId build() => AppTabId.conversation;

  void select(AppTabId tab) => state = tab;

  /// Selecciona por posición visual, que es lo que reporta la barra inferior.
  void selectVisualIndex(int index) {
    if (index < 0 || index >= kTabOrder.length) return;
    state = kTabOrder[index];
  }
}

final selectedTabProvider =
    NotifierProvider<SelectedTabNotifier, AppTabId>(SelectedTabNotifier.new);
