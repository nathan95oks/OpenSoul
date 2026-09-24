import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lsb_legal_app/app/app_theme.dart';
import 'package:lsb_legal_app/app/screens/main_navigation_screen.dart';
import 'package:lsb_legal_app/app/screens/mode_selection_screen.dart';
import 'package:lsb_legal_app/core/presentation/session/usage_mode_provider.dart';

/// Decide si toca elegir modo o seguir trabajando.
///
/// Es una puerta, no una pantalla: mientras no haya modo elegido no se monta
/// la navegación, de modo que **no puede** verse una conversación anterior
/// antes de decidir qué sesión corresponde.
///
/// Volver del segundo plano no pasa por aquí: el modo ya está en memoria, así
/// que la sesión activa se reanuda sin interrumpir con el selector.
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

    if (session.needsSelection) {
      return const ModeSelectionScreen();
    }

    return const MainNavigationScreen();
  }
}
