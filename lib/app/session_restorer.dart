import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lsb_legal_app/core/di/injection.dart';
import 'package:lsb_legal_app/core/domain/entities/session_snapshot.dart';
import 'package:lsb_legal_app/core/data/models/conversation_json.dart';
import 'package:lsb_legal_app/features/conversation/presentation/providers/conversation_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/context_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/result_visibility_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/sentence_provider.dart';

/// Devuelve la sesión donde estaba tras un reinicio de la aplicación.
///
/// En un dispositivo con poca memoria Android mata el proceso en cuanto la
/// aplicación pasa a segundo plano, así que volver a abrirla equivale a
/// instalarla de nuevo: contexto perdido, frase perdida. Para quien está
/// declarando en una ventanilla eso significa volver a empezar delante del
/// funcionario.
class SessionRestorer {
  final Ref ref;

  SessionRestorer(this.ref);

  Timer? _pendiente;

  /// Se escribe con retardo: seleccionar tarjetas dispara muchos cambios
  /// seguidos y no tiene sentido tocar el disco en cada uno.
  static const _retardo = Duration(milliseconds: 600);

  /// Pestaña abierta, que la guarda la navegación y no un provider.
  int _tabIndex = 0;

  void recordTab(int index) {
    _tabIndex = index;
    scheduleSave();
  }

  void scheduleSave() {
    _pendiente?.cancel();
    _pendiente = Timer(_retardo, saveNow);
  }

  Future<void> saveNow() async {
    _pendiente?.cancel();
    _pendiente = null;
    await ref.read(sessionRepositoryProvider).save(
          SessionSnapshot(
            tabIndex: _tabIndex,
            contextId: ref.read(contextProvider)?.id,
            sentence: ref.read(sentenceProvider),
            resultVisible: ref.read(resultVisibleProvider),
            conversation: ConversationJson.encode(
              ref.read(conversationProvider).conversation,
            ),
          ),
        );
  }

  /// Restaura la sesión guardada y devuelve la pestaña donde estaba.
  ///
  /// Solo se restaura lo que se guardó explícitamente: las zonas semánticas y
  /// las tarjetas se recalculan a partir del contexto y de la frase.
  Future<int?> restore() async {
    final snapshot = await ref.read(sessionRepositoryProvider).load();
    if (snapshot == null || !snapshot.isWorthRestoring) return null;

    _tabIndex = snapshot.tabIndex;

    // La conversación se repone antes que nada: es el hilo del que cuelga el
    // resto —quién preguntó, qué contexto se propuso— y sin ella el flujo de
    // tarjetas no sabría a qué está respondiendo.
    final guardada = snapshot.conversation;
    if (guardada != null) {
      final conversacion = ConversationJson.decode(guardada);
      if (conversacion != null && conversacion.turns.isNotEmpty) {
        ref.read(conversationProvider.notifier).replaceConversation(
              conversacion,
            );
      }
    }

    final contexto = snapshot.contextId == null
        ? null
        : allSelectableContexts
            .where((c) => c.id == snapshot.contextId)
            .firstOrNull;

    if (contexto != null) {
      ref.read(contextProvider.notifier).setContext(contexto);
      // La frase solo tiene sentido dentro de su contexto: sin el, sus glosas
      // no pertenecen a ninguna zona y el flujo quedaria incoherente.
      ref.read(sentenceProvider.notifier).setWords(snapshot.sentence);
      if (snapshot.resultVisible) {
        ref.read(resultVisibleProvider.notifier).show();
      }
    }

    return snapshot.tabIndex;
  }
}

final sessionRestorerProvider = Provider<SessionRestorer>(SessionRestorer.new);
