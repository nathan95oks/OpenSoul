import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/controllers/translation_controller.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/cards_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/context_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/denuncia_robo_draft_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/guided_flow_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/result_visibility_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/semantic_zones_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/sentence_provider.dart';

class CardsFlowSession {
  final Ref ref;

  const CardsFlowSession(this.ref);

  Future<void> reset({bool keepContext = false}) async {
    await ref.read(translationControllerProvider.notifier).reset();
    resetNow(keepContext: keepContext);
  }

  /// Lo mismo que [reset], sin esperar a que se detenga el audio: lo que se
  /// ve (el resultado, el contexto, el recorrido guiado) queda limpio ya, en
  /// el mismo instante. Lo usa quien abre otro encargo y necesita que lo
  /// siguiente que se arme no se mezcle con lo anterior.
  void resetNow({bool keepContext = false}) {
    // La pantalla de resultado es la última oración formal del módulo: si
    // sigue visible, abrir un encargo nuevo muestra la oración anterior en
    // vez de sus preguntas.
    ref.read(resultVisibleProvider.notifier).hide();
    unawaited(ref.read(translationControllerProvider.notifier).reset());
    if (!keepContext) ref.read(contextProvider.notifier).clearContext();
    ref.read(sentenceProvider.notifier).clearSentence();
    ref.read(semanticZonesProvider.notifier).reset();
    ref.read(guidedFlowProvider.notifier).reset();
    // El borrador de entidades (personas, objetos, lugar) es propio de cada
    // caso: si no se limpia, una respuesta tardía podría insertarse en el
    // caso nuevo tras cambiar de contexto.
    ref.read(denunciaRoboDraftProvider.notifier).reset();
    ref
        .read(currentCategoryProvider.notifier)
        .setCategory(kSuggestionsCategory);
  }
}

final cardsFlowSessionProvider = Provider<CardsFlowSession>(
  CardsFlowSession.new,
);
