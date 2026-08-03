import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'features/conversation/presentation/providers/conversation_bindings.dart';

void main() {
  runApp(
    ProviderScope(
      // Aquí, y solo aquí, se conectan los módulos entre sí. El núcleo declara
      // los puertos desactivados y el módulo de conversación los implementa;
      // los módulos de traducción nunca se enteran de con quién hablan.
      overrides: conversationOverrides(),
      child: const AppScope(),
    ),
  );
}
