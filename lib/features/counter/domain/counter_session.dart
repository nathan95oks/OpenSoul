import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lsb_legal_app/core/di/injection.dart';
import 'package:lsb_legal_app/core/presentation/session/cards_flow_launch.dart';
import 'package:lsb_legal_app/core/presentation/session/usage_mode_provider.dart';
import 'package:lsb_legal_app/features/conversation/presentation/providers/conversation_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/cards_flow_session.dart';

/// El ciclo de una atención en ventanilla.
///
/// Una atención es lo que ocurre entre que llega una persona y se va. El
/// dispositivo se queda; la persona no. Todo lo que dijo tiene que
/// desaparecer al terminar, y la configuración de la institución tiene que
/// seguir ahí para la siguiente.
class CounterSession {
  final Ref ref;

  const CounterSession(this.ref);

  /// Empieza una atención con una sesión de contenido limpia.
  ///
  /// El perfil institucional queda disponible, pero no es contenido: nada de
  /// lo que diga el perfil entra en la declaración de nadie.
  Future<void> startAttention() async {
    await _wipeCitizenData();
  }

  /// Cierra la atención del ciudadano.
  ///
  /// Borra mensajes, borradores, aclaraciones y resultados reproducibles.
  /// Conserva el modo de uso y el perfil institucional, que son del
  /// dispositivo y no de la persona.
  Future<void> endAttention() async {
    await _wipeCitizenData();
  }

  Future<void> _wipeCitizenData() async {
    // En memoria primero, para que la pantalla no muestre ni un fotograma de
    // lo anterior mientras se escribe en disco.
    ref.read(conversationProvider.notifier).startNew();
    await ref.read(cardsFlowSessionProvider).reset();
    ref
        .read(cardsFlowLaunchProvider.notifier)
        .start(const CardsFlowLaunch.standalone());

    // Y en disco, por separado de la configuración.
    await ref.read(sessionRepositoryProvider).clearContent();
  }

  /// El perfil institucional activo, si lo hay.
  String? get institutionProfileId =>
      ref.read(usageSessionProvider).institutionProfileId;
}

final counterSessionProvider =
    Provider<CounterSession>(CounterSession.new);
