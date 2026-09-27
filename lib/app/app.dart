import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lsb_legal_app/app/app_router.dart';
import 'package:lsb_legal_app/app/app_theme.dart';
import 'package:lsb_legal_app/app/conversation_restoration.dart';

class AppScope extends StatefulWidget {
  const AppScope({super.key, this.showSplash = true});

  final bool showSplash;

  @override
  State<AppScope> createState() => _AppScopeState();
}

class _AppScopeState extends State<AppScope> {
  late final GoRouter _router = createAppRouter(showSplash: widget.showSplash);

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'OpenSoul - Asistente Ciudadano LSB',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: _router,
      // Habilita la restauración de estado del sistema: el chat sobrevive a
      // que Android mate el proceso en segundo plano (ver
      // [ConversationRestoration]).
      restorationScopeId: 'app',
      builder: (context, child) =>
          ConversationRestoration(child: child ?? const SizedBox.shrink()),
    );
  }
}
