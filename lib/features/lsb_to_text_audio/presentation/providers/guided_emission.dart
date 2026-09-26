import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lsb_legal_app/core/domain/services/conversation_bridge.dart';
import 'package:lsb_legal_app/core/presentation/session/active_need_provider.dart';
import 'package:lsb_legal_app/core/presentation/session/cards_flow_launch.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/controllers/translation_controller.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/conversation_return.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/guided_flow_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/result_visibility_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/screens/needs_screen.dart';

enum GuidedEmissionStatus {
  /// No había nada que emitir.
  nothing,

  /// Falta una respuesta obligatoria; el flujo ya fue a esa pregunta.
  missingRequired,

  /// Se muestra la declaración en la pantalla de resultado (uso autónomo).
  shownResult,

  /// La respuesta quedó en el hilo de Conversation y se volvió al chat.
  returnedToConversation,

  /// El turno al que respondía ya no está en el chat: no se envió y la
  /// declaración queda en la pantalla de resultado.
  staleConversation,
}

class GuidedEmissionOutcome {
  final GuidedEmissionStatus status;

  /// Formulación de la pregunta obligatoria que falta, si es el caso.
  final String? missingQuestion;

  const GuidedEmissionOutcome(this.status, {this.missingQuestion});
}

/// Emite la intervención guiada: la misma que se ve en la vista previa viaja
/// al backend, y el resultado solo acepta del servidor una redacción
/// validada. Si el encargo vino de Conversation, la respuesta vuelve sola a
/// su hilo.
class GuidedEmission {
  final Ref ref;

  const GuidedEmission(this.ref);

  Future<GuidedEmissionOutcome> emit() async {
    final flow = ref.read(guidedFlowProvider.notifier);
    final session = ref.read(guidedFlowProvider).session;
    final rules = ref.read(guidedFlowRulesProvider);
    if (session == null) {
      return const GuidedEmissionOutcome(GuidedEmissionStatus.nothing);
    }

    final faltan = rules.missingRequired(session);
    if (faltan.isNotEmpty) {
      final primera = faltan.first;
      flow.goTo(primera);
      return GuidedEmissionOutcome(
        GuidedEmissionStatus.missingRequired,
        missingQuestion: rules.formulationOf(session, primera),
      );
    }

    final intervention = flow.intervention;
    if (intervention == null || intervention.isEmpty) {
      return const GuidedEmissionOutcome(GuidedEmissionStatus.nothing);
    }
    final text = ref.read(guidedComposerProvider).compose(intervention);
    final glosses = rules.glossesOf(intervention);

    // El acto comunicativo se decide por ESTA intervención, no por la
    // necesidad elegida hace cinco pantallas.
    final launch = ref.read(cardsFlowLaunchProvider);
    final acto = NeedsScreen.actForIntervention(
      purpose: launch.purpose,
      need: ref.read(activeNeedProvider),
      glosses: glosses,
    );

    ref.read(resultVisibleProvider.notifier).show();

    try {
      await ref
          .read(translationControllerProvider.notifier)
          .translateGuided(
            intervention: intervention,
            localText: text,
            glosses: glosses,
            speechAct: acto.wireName,
          );
    } catch (_) {}

    final result = ref.read(translationControllerProvider).value;
    if (result == null) {
      return const GuidedEmissionOutcome(GuidedEmissionStatus.shownResult);
    }
    final delivered = await ref
        .read(conversationReturnProvider)
        .deliver(result, intervention: intervention);
    return GuidedEmissionOutcome(switch (delivered) {
      null => GuidedEmissionStatus.shownResult,
      SubmitOutcome.sent => GuidedEmissionStatus.returnedToConversation,
      _ => GuidedEmissionStatus.staleConversation,
    });
  }
}

final guidedEmissionProvider = Provider<GuidedEmission>(GuidedEmission.new);
