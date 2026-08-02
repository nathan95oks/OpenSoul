import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:lsb_legal_app/app/theme.dart';
import 'package:lsb_legal_app/core/domain/repositories/translation_repository.dart';
import 'package:lsb_legal_app/features/conversation/presentation/providers/conversation_provider.dart';
import 'package:lsb_legal_app/features/dictionary_proposals/presentation/widgets/propose_sign_sheet.dart';
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
      backgroundColor: AppTheme.lightBg,
      appBar: _buildAppBar(context, ref, contextState, selectedWords),
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
    BuildContext context,
    WidgetRef ref,
    dynamic contextState,
    List<String> selectedWords,
  ) {
    return AppBar(
      backgroundColor: AppTheme.lightBg,
      elevation: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: AppTheme.lightBorder),
      ),
      title: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/logo.png',
              width: 32,
              height: 32,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 10),
          // Flexible: con la flecha de volver y las dos acciones, el título
          // no cabía y desbordaba por 4 px (franja de depuración visible).
          const Flexible(
            child: Text(
              'OpenSoul',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppTheme.brandPrimary,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ],
      ),
      actions: [
        // Diccionario evolutivo (Fase 3): cualquier palabra que falte en el
        // catálogo puede proponerse; queda pendiente de validación.
        IconButton(
          icon: const Icon(Icons.playlist_add, color: AppTheme.brandPrimary),
          tooltip: 'Proponer palabra o seña',
          onPressed: () => ProposeSignSheet.show(
            context,
            contextId: contextState?.id as String?,
          ),
        ),
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
              'Cambiar contexto',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.brandPrimary,
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
    // Frase del oyente que se está respondiendo: se mantiene a la vista
    // durante todo el flujo guiado para no obligar a recordarla.
    final pending = ref.watch(conversationProvider).conversation.pendingReply;
    // Se entró directo a este contexto por inferencia, no porque nadie lo
    // eligiera: hay que decirlo, o una suposición equivocada pasaría por
    // decisión propia.
    final wasInferred =
        pending?.message.contextSuggestion?.contextId == contextState?.id;

    return Column(
      children: [
        if (pending != null)
          _ReplyingToStrip(
            text: pending.outputs.text,
            inferredContextName: wasInferred ? contextState.name as String : null,
          ),
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

                  // Secuencia con marcadores de rol (p. ej. agresor vs.
                  // persona agredida en testigo). [sentenceProvider] sigue
                  // puro para la UI; el marcador solo viaja a los motores.
                  final markedCards = ref
                      .read(semanticZonesProvider.notifier)
                      .orderedGlossesMarked();
                  final cardsForEngines =
                      markedCards.isEmpty ? selectedWords : markedCards;

                  final assemblerContext = resolveAssemblerContext(
                    contextState.id,
                    cardsForEngines,
                    categoryOf,
                  );
                  await ref
                      .read(translationControllerProvider.notifier)
                      .translateCards(
                        // RVP-03: el backend recibe el contexto de UI real…
                        context: contextState.id,
                        cards: cardsForEngines,
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

/// Franja superior con la frase del oyente que se está respondiendo.
///
/// Cuando el contexto se dedujo de esa frase, lo declara: la persona sorda
/// entra directa a la primera pregunta —así se responde rápido— pero debe
/// poder ver de un vistazo que el sistema supuso, y corregirlo.
class _ReplyingToStrip extends StatelessWidget {
  final String text;
  final String? inferredContextName;

  const _ReplyingToStrip({required this.text, this.inferredContextName});

  @override
  Widget build(BuildContext context) {
    final inferred = inferredContextName;
    return Semantics(
      label: [
        'Respondiendo a: $text',
        if (inferred != null)
          'Contexto sugerido: $inferred. Usa Cambiar contexto si no corresponde.',
      ].join(' '),
      excludeSemantics: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
        color: AppTheme.brandPrimary.withValues(alpha: 0.07),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.record_voice_over,
                    size: 15, color: AppTheme.brandPrimary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '«$text»',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.lightText,
                    ),
                  ),
                ),
              ],
            ),
            if (inferred != null) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 23),
                child: Text(
                  'Contexto sugerido: $inferred · cámbialo arriba si no corresponde',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.lightTextSub.withValues(alpha: 0.95),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
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

  static const _orange = AppTheme.brandPrimary;

  @override
  Widget build(BuildContext context) {
    final enabled = onTranslate != null;
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.lightSurface,
        border: Border(top: BorderSide(color: AppTheme.lightBorder, width: 1)),
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
                color: AppTheme.lightTextSub,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              glosses.map((g) => g.replaceAll('_', ' ')).join(' • '),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.lightText,
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
                color: AppTheme.lightTextSub,
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
                color: enabled ? _orange : AppTheme.lightBorder,
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
                                  : AppTheme.lightTextSub,
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
