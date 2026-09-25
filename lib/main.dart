import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lsb_legal_app/app/app.dart';
import 'package:lsb_legal_app/core/data/repositories/animation_repository_impl.dart';
import 'package:lsb_legal_app/features/conversation/di/conversation_bindings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Precarga en segundo plano del modelo 3D para tenerlo listo antes de usar el módulo
  unawaited(AnimationRepositoryImpl().precacheDefaultModel());

  runApp(
    ProviderScope(
      overrides: conversationOverrides(),
      child: const AppScope(),
    ),
  );
}
