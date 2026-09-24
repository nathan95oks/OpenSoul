import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lsb_legal_app/app/navigation_provider.dart';
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
///
/// Lo que **no** se restaura es el contenido de una atención en modo
/// ventanilla: ese dispositivo pasa de una persona a la siguiente, y reponer
/// la conversación anterior sería enseñarle a la siguiente lo que declaró la
/// anterior.
class SessionRestorer {
  final Ref ref;

  SessionRestorer(this.ref);

  Timer? _pendiente;

  /// Se escribe con retardo: seleccionar tarjetas dispara muchos cambios
  /// seguidos y no tiene sentido tocar el disco en cada uno.
  static const _retardo = Duration(milliseconds: 600);

  /// Pestaña abierta, que la guarda la navegación y no un provider.
  AppTabId _tab = AppTabId.conversation;

  void recordTab(AppTabId tab) {
    _tab = tab;
    scheduleSave();
  }

  void scheduleSave() {
    _pendiente?.cancel();
    _pendiente = Timer(_retardo, saveNow);
  }

  Future<void> saveNow() async {
    _pendiente?.cancel();
    _pendiente = null;

    final repo = ref.read(sessionRepositoryProvider);
    final config = await repo.loadConfig();

    await repo.saveConfig(config.copyWith(lastTabId: _tab.id));
    await repo.saveContent(
      SessionContent(
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
  Future<AppTabId?> restore() async {
    final repo = ref.read(sessionRepositoryProvider);
    final config = await repo.loadConfig();
    final tab = AppTabId.byId(config.lastTabId);
    if (tab != null) _tab = tab;

    // En ventanilla no se repone contenido: el dispositivo es compartido y la
    // atención anterior ya terminó, aunque el proceso muriera sin que nadie
    // pulsara «Finalizar atención».
    if (config.mode == UsageMode.counter) {
      await repo.clearContent();
      return tab;
    }

    final content = await repo.loadContent();
    if (content == null || !content.isWorthRestoring) return tab;

    // La conversación se repone antes que nada: es el hilo del que cuelga el
    // resto —quién preguntó, qué contexto se propuso— y sin ella el flujo de
    // tarjetas no sabría a qué está respondiendo.
    final guardada = content.conversation;
    if (guardada != null) {
      final conversacion = ConversationJson.decode(guardada);
      if (conversacion != null && conversacion.turns.isNotEmpty) {
        ref.read(conversationProvider.notifier).replaceConversation(
              conversacion,
            );
      }
    }

    final contexto = content.contextId == null
        ? null
        : allSelectableContexts
            .where((c) => c.id == content.contextId)
            .firstOrNull;

    if (contexto != null) {
      ref.read(contextProvider.notifier).setContext(contexto);
      // La frase solo tiene sentido dentro de su contexto: sin el, sus glosas
      // no pertenecen a ninguna zona y el flujo quedaria incoherente.
      ref.read(sentenceProvider.notifier).setWords(content.sentence);
      if (content.resultVisible) {
        ref.read(resultVisibleProvider.notifier).show();
      }
    }

    return tab;
  }
}

final sessionRestorerProvider = Provider<SessionRestorer>(SessionRestorer.new);
