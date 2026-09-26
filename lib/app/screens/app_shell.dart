import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lsb_legal_app/app/app_theme.dart';
import 'package:lsb_legal_app/app/screens/main_navigation_screen.dart';
import 'package:lsb_legal_app/core/presentation/session/usage_mode_provider.dart';

/// Espera a que se lea la configuración del dispositivo y monta la navegación.
///
/// Es una puerta, no una pantalla: mientras no se sepa el modo de uso no se
/// monta la navegación, de modo que **no puede** verse una conversación
/// anterior antes de decidir qué sesión corresponde.
///
/// Ya no se pregunta el modo al entrar: sin modo guardado se usa el personal
/// (ver [UsageSessionNotifier]).
class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(usageSessionProvider);

    if (session.loading) {
      return const Scaffold(
        backgroundColor: AppTheme.lightBg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return const MainNavigationScreen();
  }
}
