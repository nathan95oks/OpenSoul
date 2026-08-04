import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Desde qué superficie se está usando la app en este momento.
///
/// Los dos módulos de traducción tienen **un solo estado** en el
/// `ProviderScope` raíz y **dos dueños posibles**: la conversación, donde cada
/// turno condiciona al siguiente, y las pestañas autónomas, donde cada módulo
/// es una herramienta suelta. Sin declarar cuál manda, el estado de un dueño
/// se cuela en el del otro: la respuesta a medias de un turno reaparece en la
/// pestaña de tarjetas, y la pregunta del oyente enruta un flujo que no está
/// respondiendo a nadie.
///
/// Este enum es esa declaración. Vive en el núcleo porque lo consulta
/// [pendingReplyProvider], pero **no sabe limpiar nada**: quién se limpia al
/// cambiar de superficie lo decide la raíz de composición
/// (`lib/app/surface_session.dart`), la única capa que conoce a los tres
/// módulos.
enum FlowSurface {
  /// La conversación bidireccional: los dos módulos trabajan juntos.
  conversation,

  /// El flujo de tarjetas (LSB → texto/audio) como herramienta suelta.
  standaloneCards,

  /// El traductor a avatar (voz/texto → LSB) como herramienta suelta.
  standaloneAvatar;

  bool get isConversation => this == FlowSurface.conversation;
}

class FlowSurfaceNotifier extends Notifier<FlowSurface> {
  /// La app abre en la conversación: es su pantalla central.
  @override
  FlowSurface build() => FlowSurface.conversation;

  void set(FlowSurface surface) => state = surface;
}

final flowSurfaceProvider = NotifierProvider<FlowSurfaceNotifier, FlowSurface>(
  FlowSurfaceNotifier.new,
);
