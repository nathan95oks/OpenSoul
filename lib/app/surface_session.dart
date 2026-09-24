import 'package:flutter_riverpod/flutter_riverpod.dart';

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

    // Llegar al módulo de tarjetas por la barra de navegación es el modo A:
    // una declaración propia. El lanzamiento se reinicia aquí para que un
    // chat guardado detrás no siga presentando su última pregunta en una
    // pantalla que ya no responde a nadie.
    if (surface != FlowSurface.conversation) {
      ref
          .read(cardsFlowLaunchProvider.notifier)
          .start(const CardsFlowLaunch.standalone());
    }

    await ref.read(cardsFlowSessionProvider).reset();
    ref.read(audioTranslationControllerProvider.notifier).reset();
  }
}

final surfaceSessionProvider = Provider<SurfaceSession>(SurfaceSession.new);
