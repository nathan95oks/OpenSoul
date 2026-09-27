import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lsb_legal_app/core/data/models/conversation_json.dart';
import 'package:lsb_legal_app/core/domain/entities/conversation.dart';
import 'package:lsb_legal_app/features/conversation/presentation/providers/conversation_provider.dart';

/// Conserva el chat mientras la tarea siga viva en «recientes».
///
/// Pulsar Inicio no cierra la aplicación, pero Android puede matar el proceso
/// en segundo plano para liberar memoria. Al volver, sin esto, el chat
/// aparecería vacío aunque la persona nunca lo cerró.
///
/// Se usa la restauración de estado del sistema y no el disco a propósito: el
/// sistema solo devuelve estos datos si la tarea sigue en recientes. Cerrar la
/// app deslizándola desde recientes los descarta, y entonces el chat empieza
/// vacío, que es lo que se espera de «cerrar la app».
class ConversationRestoration extends ConsumerStatefulWidget {
  final Widget child;

  const ConversationRestoration({super.key, required this.child});

  /// Tope del estado guardado. Android lo pasa en un `Bundle` con un límite
  /// de transacción de ~1 MB compartido con todo lo demás; pasarlo cierra la
  /// app. Si el chat es más largo se guardan sus turnos más recientes.
  static const int maxBytes = 200 * 1024;

  @override
  ConsumerState<ConversationRestoration> createState() =>
      _ConversationRestorationState();
}

class _ConversationRestorationState
    extends ConsumerState<ConversationRestoration>
    with RestorationMixin {
  final RestorableStringN _guardada = RestorableStringN(null);

  @override
  String get restorationId => 'conversation';

  @override
  void initState() {
    super.initState();
    ref.listenManual<ConversationState>(
      conversationProvider,
      (_, next) => _guardar(next.conversation),
    );
  }

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(_guardada, 'json');
    final crudo = _guardada.value;
    if (!initialRestore || crudo == null) return;

    final Conversation? conversacion;
    try {
      conversacion = ConversationJson.decode(
        Map<String, dynamic>.from(jsonDecode(crudo) as Map),
      );
    } catch (_) {
      return;
    }
    if (conversacion == null || conversacion.turns.isEmpty) return;

    // Un provider no se modifica mientras se construye el árbol.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!ref.read(conversationProvider).conversation.isEmpty) return;
      ref
          .read(conversationProvider.notifier)
          .replaceConversation(conversacion!);
    });
  }

  void _guardar(Conversation conversacion) {
    if (conversacion.turns.isEmpty) {
      _guardada.value = null;
      return;
    }
    // Una traducción en curso no sobrevive al proceso: se repone como fallida
    // para que el turno no quede cargando para siempre.
    var turnos = [
      for (final t in conversacion.turns)
        t.pending ? t.copyWith(pending: false, failed: true) : t,
    ];
    while (turnos.isNotEmpty) {
      final json = jsonEncode(
        ConversationJson.encode(
          Conversation(
            id: conversacion.id,
            startedAt: conversacion.startedAt,
            turns: turnos,
          ),
        ),
      );
      if (utf8.encode(json).length <= ConversationRestoration.maxBytes) {
        _guardada.value = json;
        return;
      }
      turnos = turnos.sublist(turnos.length ~/ 4 + 1);
    }
    _guardada.value = null;
  }

  @override
  void dispose() {
    _guardada.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
