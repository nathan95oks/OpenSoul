import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lsb_legal_app/core/session/flow_surface.dart';
import 'package:lsb_legal_app/features/audio_to_lsb/presentation/controllers/audio_translation_controller.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/cards_flow_session.dart';

/// Cambio de superficie: qué se conserva y qué se descarta al saltar entre la
/// conversación y las herramientas sueltas.
///
/// La regla es una sola y deliberadamente simple: **los módulos de traducción
/// no guardan nada entre superficies; solo la conversación tiene memoria.**
///
/// Es la única forma de que la promesa se cumpla en los dos sentidos. Limpiar
/// nada más al entrar a una pestaña autónoma dejaría la fuga al revés: lo que
/// alguien construyera allí aparecería después como respuesta de un turno.
/// Como los tres módulos comparten el `ProviderScope` raíz, el estado se
/// descarta en cada cruce y quien llega encuentra su módulo en blanco.
///
/// El precio, asumido: salir de la conversación a una pestaña autónoma con una
/// respuesta a medio construir la descarta. Se prefiere a la alternativa —que
/// reaparezca donde no corresponde—, porque una respuesta que se cuela en otro
/// contexto no es un inconveniente sino una declaración falsa.
///
/// Vive en `lib/app/` porque es la raíz de composición: la única capa que
/// puede conocer a los tres módulos sin reintroducir el ciclo entre ellos
/// (ver `test/module_boundaries_test.dart`).
class SurfaceSession {
  final Ref ref;

  const SurfaceSession(this.ref);

  /// Entra a [surface] dejando los módulos de traducción en blanco.
  ///
  /// Idempotente: volver a entrar donde ya se está no descarta nada, de modo
  /// que reconstruir la navegación nunca borra trabajo del usuario.
  Future<void> enter(FlowSurface surface) async {
    if (ref.read(flowSurfaceProvider) == surface) return;

    // El orden importa: la superficie se fija ANTES de limpiar. El recorrido
    // de zonas se reconstruye a partir de `pendingReplyProvider`, que depende
    // de la superficie; al revés, el reset leería todavía la pregunta del
    // oyente y reabriría el flujo en la zona que ella pedía.
    ref.read(flowSurfaceProvider.notifier).set(surface);

    await ref.read(cardsFlowSessionProvider).reset();
    ref.read(audioTranslationControllerProvider.notifier).reset();
  }
}

final surfaceSessionProvider = Provider<SurfaceSession>(SurfaceSession.new);
