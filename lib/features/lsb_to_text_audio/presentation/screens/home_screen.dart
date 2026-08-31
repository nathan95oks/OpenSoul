import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lsb_legal_app/app/app_theme.dart';
import 'package:lsb_legal_app/app/navigation_provider.dart';
import 'package:lsb_legal_app/core/presentation/session/flow_surface.dart';
import 'package:lsb_legal_app/core/di/injection.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/sign_images_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/cards_flow_session.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/sentence_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/result_visibility_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/semantic_zones_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/controllers/translation_controller.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/context_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/cards_provider.dart' show allCardsProvider;
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/context_selection_widget.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/node_flow_canvas.dart';
import 'package:lsb_legal_app/core/domain/entities/translation_result.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedWords = ref.watch(sentenceProvider);
    final translationState = ref.watch(translationControllerProvider);
    final contextState = ref.watch(contextProvider);

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
    // Dentro de una conversacion, armar la frase no puede ser un callejon sin
    // salida: la persona oyente puede necesitar hablar en cualquier momento, y
    // volver no debe costar descartar lo que se lleva armado.
    final sirveConversacion = ref.watch(flowSurfaceProvider).isConversation;

    return AppBar(
      backgroundColor: AppTheme.lightBg,
      elevation: 0,
      leading: sirveConversacion
          ? IconButton(
              icon: const Icon(Icons.arrow_back, color: AppTheme.brandPrimary),
              tooltip: 'Volver a la conversación',
              onPressed: () =>
                  ref.read(selectedTabProvider.notifier).select(AppTab.conversation),
            )
          : null,
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
        Builder(builder: (_) {
          final conImagen = ref.watch(signImagesEnabledProvider);
          return IconButton(
            icon: Icon(
              conImagen ? Icons.image : Icons.image_not_supported_outlined,
              color: AppTheme.brandPrimary,
            ),
            tooltip: conImagen ? 'Ocultar imágenes' : 'Mostrar imágenes',
            onPressed: () =>
                ref.read(signImagesEnabledProvider.notifier).alternar(),
          );
        }),
        if (contextState != null)
          TextButton(
            onPressed: () => ref.read(cardsFlowSessionProvider).reset(),
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
    final pending = ref.watch(pendingReplyProvider);
    final wasInferred = pending?.suggestion?.contextId == contextState?.id;

    return Column(
      children: [
        if (pending != null)
          _ReplyingToStrip(
            text: pending.question,
            inferredContextName: wasInferred ? contextState.name as String : null,
          ),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: const [NodeFlowCanvas(), SizedBox(height: 8)],
            ),
          ),
        ),
        const GuidedNavBar(),
        _BottomPanel(
          glosses: selectedWords,
          isLoading: translationState.isLoading,
          onTranslate: selectedWords.isEmpty || translationState.isLoading
              ? null
              : () async {
                  final allCards = ref.read(allCardsProvider).value ?? const [];
                  String? categoryOf(String g) {
                    for (final c in allCards) {
                      if (c.gloss == g) return c.categoryId;
                    }
                    return null;
                  }

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
                        context: contextState.id,
                        cards: cardsForEngines,
                        assemblerContext: assemblerContext,
                      );
                  ref.read(resultVisibleProvider.notifier).show();
                },
        ),
      ],
    );
  }
}

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
          SizedBox(
            width: double.infinity,
            height: 56,
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
