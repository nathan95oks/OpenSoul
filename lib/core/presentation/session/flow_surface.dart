import 'package:flutter_riverpod/flutter_riverpod.dart';

enum FlowSurface {
  conversation,

  standaloneCards,

  standaloneAvatar;

  bool get isConversation => this == FlowSurface.conversation;
}

class FlowSurfaceNotifier extends Notifier<FlowSurface> {
  @override
  FlowSurface build() => FlowSurface.conversation;

  void set(FlowSurface surface) => state = surface;
}

final flowSurfaceProvider = NotifierProvider<FlowSurfaceNotifier, FlowSurface>(
  FlowSurfaceNotifier.new,
);
