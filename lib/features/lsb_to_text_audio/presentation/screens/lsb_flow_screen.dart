import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/result_visibility_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/screens/declaration_result_screen.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/screens/home_screen.dart';

/// El módulo de tarjetas completo: armado de la frase y declaración terminada.
///
/// Las dos pantallas son pasos del mismo flujo, así que viven dentro de la
/// misma pestaña en lugar de apilarse sobre ella. Antes el resultado se
/// empujaba como ruta de nivel raíz y tapaba la barra de navegación: se
/// llegaba a la declaración y ya no había forma de ir a otro módulo.
///
/// Se usa un [IndexedStack] y no un condicional para que el armado de la
/// frase siga vivo detrás: al volver a editar, las tarjetas y el
/// desplazamiento están como se dejaron.
class LsbFlowScreen extends ConsumerWidget {
  const LsbFlowScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mostrandoResultado = ref.watch(resultVisibleProvider);

    return PopScope(
      // El botón atrás del sistema devuelve al armado en vez de sacar de la
      // aplicación, que es lo que esperaría cualquiera estando en un paso
      // intermedio.
      canPop: !mostrandoResultado,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) ref.read(resultVisibleProvider.notifier).hide();
      },
      child: IndexedStack(
        index: mostrandoResultado ? 1 : 0,
        children: const [
          HomeScreen(),
          DeclarationResultScreen(),
        ],
      ),
    );
  }
}
