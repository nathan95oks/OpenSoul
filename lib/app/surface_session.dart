import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/context_provider.dart';
import 'package:lsb_legal_app/core/presentation/session/cards_flow_launch.dart';
import 'package:lsb_legal_app/core/presentation/session/flow_surface.dart';
import 'package:lsb_legal_app/features/audio_to_lsb/presentation/controllers/audio_translation_controller.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/cards_flow_session.dart';

class SurfaceSession {
  final Ref ref;

  const SurfaceSession(this.ref);

  Future<void> enter(FlowSurface surface) async {
    if (ref.read(flowSurfaceProvider) == surface) return;

    ref.read(flowSurfaceProvider.notifier).set(surface);
    ref.read(audioTranslationControllerProvider.notifier).reset();

    // Salir del módulo de tarjetas no borra lo que se estaba armando: la
    // persona puede ir al chat y volver a terminar su declaración. Si desde
    // el chat se abre otro encargo (responder), la pantalla pregunta antes
    // de descartarlo ("Tienes un mensaje a medias").
    if (surface != FlowSurface.standaloneCards) return;

    // Volver a una declaración propia: sigue donde quedó.
    final launch = ref.read(cardsFlowLaunchProvider);
    if (launch.purpose == CardsFlowPurpose.standaloneIntervention) return;

    // Llegar por la barra mientras se respondía al chat es el modo A: una
    // declaración propia, limpia. Seguir respondiendo bajo una pregunta que
    // ya no se tiene delante enlazaría la respuesta al turno equivocado.
    ref
        .read(cardsFlowLaunchProvider.notifier)
        .start(const CardsFlowLaunch.standalone());
    await ref.read(cardsFlowSessionProvider).reset();
    ref.read(openFamilyProvider.notifier).clear();
  }
}

final surfaceSessionProvider = Provider<SurfaceSession>(SurfaceSession.new);
