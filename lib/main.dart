import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lsb_legal_app/app/app.dart';
import 'package:lsb_legal_app/features/conversation/presentation/providers/conversation_bindings.dart';

void main() {
  runApp(
    ProviderScope(
      overrides: conversationOverrides(),
      child: const AppScope(),
    ),
  );
}
