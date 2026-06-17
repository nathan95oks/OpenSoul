import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/repositories/translation_repository.dart';
import '../providers/sentence_provider.dart';
import '../providers/semantic_zones_provider.dart';
import '../controllers/translation_controller.dart';
import '../providers/context_provider.dart';
import '../providers/cards_provider.dart' show allCardsProvider;
import '../widgets/context_selection_widget.dart';
import '../widgets/node_flow_canvas.dart';
import '../widgets/card_grid.dart' show expandedAnswersProvider;

/// Pantalla principal del módulo LSB → Texto → Audio.
///
/// Layout (fondo blanco, árbol conceptual vertical):
///   AppBar  → "OpenSoul" + contexto activo
///   Body    → SingleChildScrollView con NodeFlowCanvas (árbol pregunta→respuesta)
///   Bottom  → Panel fijo: secuencia construida + botón TRADUCIR
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedWords = ref.watch(sentenceProvider);
    final translationState = ref.watch(translationControllerProvider);
    final contextState = ref.watch(contextProvider);

    // Nota (RVP-01): no se observa AsyncError aquí porque el controlador
    // nunca emite error — siempre degrada al motor local y entrega un
    // resultado. El origen del texto (IA remota vs motor local) se comunica
    // al usuario con un chip en la pantalla de resultado.

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(ref, contextState, selectedWords),
      body: SafeArea(
        child: contextState == null
            ? const ContextSelectionWidget()
            : _buildFlow(
                context,
                ref,
                contextState,
                selectedWords,
                translationState,
              ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    WidgetRef ref,
    dynamic contextState,
    List<String> selectedWords,
  ) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 2, color: Colors.black),
      ),
      title: const Text(
        'OpenSoul',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: Colors.black,
          letterSpacing: -0.3,
        ),
      ),
      actions: [
        if (contextState != null)
          TextButton(
            onPressed: () async {
              await ref.read(translationControllerProvider.notifier).reset();
              ref.read(contextProvider.notifier).clearContext();
              ref.read(sentenceProvider.notifier).clearSentence();
              ref.read(semanticZonesProvider.notifier).reset();
              ref.read(expandedAnswersProvider.notifier).collapse();
            },
            child: const Text(
              '← Cambiar contexto',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFlow(
    BuildContext context,
    WidgetRef ref,
    dynamic contextState,
    List<String> selectedWords,
    AsyncValue<TranslationResult?> translationState,
  ) {
    return Column(
      children: [
        // Pregunta activa + opciones (scrollable solo si hay muchas opciones)
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: const [NodeFlowCanvas(), SizedBox(height: 8)],
            ),
          ),
        ),
        // Controles fijos Volver/Continuar — siempre visibles, sin scroll.
        const GuidedNavBar(),
        // Panel fijo inferior: secuencia + botón traducir
        _BottomPanel(
          glosses: selectedWords,
          isLoading: translationState.isLoading,
          onTranslate: selectedWords.isEmpty || translationState.isLoading
              ? null
              : () async {
                  // Capturamos el router ANTES del await para no depender de
                  // un BuildContext tras el gap asíncrono.
                  final router = GoRouter.of(context);
                  // Para el contexto fusionado, resolvemos el sub-dominio más
                  // fiel para el ensamblador (motor intacto) según las glosas.
                  final allCards = ref.read(allCardsProvider).value ?? const [];
                  String? categoryOf(String g) {
                    for (final c in allCards) {
                      if (c.gloss == g) return c.categoryId;
                    }
                    return null;
                  }

                  final assemblerContext = resolveAssemblerContext(
                    contextState.id,
                    selectedWords,
                    categoryOf,
                  );
                  await ref
                      .read(translationControllerProvider.notifier)
                      .translateCards(
                        // RVP-03: el backend recibe el contexto de UI real…
                        context: contextState.id,
                        cards: selectedWords,
                        // …y el motor local el sub-dominio resuelto.
                        assemblerContext: assemblerContext,
                      );
                  // Navega a la pantalla de resultado dedicada. El estado
                  // del flujo permanece vivo para "Volver a editar".
                  router.push('/lsb-to-audio/result');
                },
        ),
      ],
    );
  }
}

/// Panel fijo inferior: secuencia de glosas + botón TRADUCIR.
class _BottomPanel extends StatelessWidget {
  final List<String> glosses;
  final bool isLoading;
  final VoidCallback? onTranslate;

  const _BottomPanel({
    required this.glosses,
    required this.isLoading,
    required this.onTranslate,
  });

  static const _orange = Color(0xFFFF6B00);

  @override
  Widget build(BuildContext context) {
    final enabled = onTranslate != null;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.black, width: 2)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Secuencia construida
          if (glosses.isNotEmpty) ...[
            const Text(
              'Secuencia construida:',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF666666),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              glosses.map((g) => g.replaceAll('_', ' ')).join(' • '),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
          ] else ...[
            const Text(
              'Selecciona glosas para construir tu declaración.',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF999999),
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 12),
          ],
          // Botón TRADUCIR
          SizedBox(
            width: double.infinity,
            height: 56,
            // A11Y-01: anuncia el botón principal como tal, con su estado.
            child: Semantics(
              button: true,
              enabled: enabled,
              label: isLoading ? 'Traduciendo' : 'Traducir',
              excludeSemantics: true,
              child: Material(
                color: enabled ? _orange : const Color(0xFFE5E5E5),
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: onTranslate,
                  child: Center(
                    child: isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
                            'TRADUCIR',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2.0,
                              color: enabled
                                  ? Colors.white
                                  : const Color(0xFFAAAAAA),
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
