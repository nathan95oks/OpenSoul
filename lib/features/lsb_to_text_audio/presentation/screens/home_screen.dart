import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/repositories/translation_repository.dart';
import '../providers/sentence_provider.dart';
import '../providers/semantic_zones_provider.dart';
import '../controllers/translation_controller.dart';
import '../providers/context_provider.dart';
import '../widgets/context_selection_widget.dart';
import '../widgets/node_flow_canvas.dart';
import '../widgets/gloss_path_builder.dart';
import '../widgets/story_preview_card.dart';
import '../widgets/card_grid.dart';

/// Pantalla principal del módulo LSB → Texto → Audio.
///
/// Nueva arquitectura de interacción (rediseño UX/UI):
///   NodeFlowCanvas       ← ContextPathIndicator + SuggestedGlossPanel
///   GlossPathBuilder     ← Ruta de glosas: ROBAR › CELULAR › AYER
///   StoryPreviewCard     ← "Me robaron mi celular ayer en la plaza."
///   ResultPanel          ← Resultado multimodal (texto + audio)
///   TranslateButton      ← Botón "Traducir"
///
/// Paleta estricta: #FFFFFF · #000000 · #FF6B00. Sin colores adicionales.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const _orange = Color(0xFFFF6B00);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedWords = ref.watch(sentenceProvider);
    final translationState = ref.watch(translationControllerProvider);
    final contextState = ref.watch(contextProvider);

    ref.listen<AsyncValue<TranslationResult?>>(
      translationControllerProvider,
      (_, next) {
        if (next is AsyncError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${next.error}'),
              backgroundColor: _orange,
            ),
          );
        }
      },
    );

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _buildAppBar(ref, contextState, selectedWords),
      body: SafeArea(
        child: contextState == null
            ? const ContextSelectionWidget()
            : _buildMain(context, ref, contextState, selectedWords, translationState),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    WidgetRef ref,
    dynamic contextState,
    List<String> selectedWords,
  ) {
    return AppBar(
      backgroundColor: Colors.black,
      elevation: 0,
      title: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              color: _orange,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.account_balance, color: Colors.black, size: 16),
          ),
          const SizedBox(width: 10),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'OpenSoul',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.2,
                ),
              ),
              Text(
                'Asistente LSB',
                style: TextStyle(
                  fontSize: 10,
                  color: Color(0x66FFFFFF),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        if (contextState != null) ...[
          // Indicador de contexto activo
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _orange.withValues(alpha: 0.3)),
            ),
            child: Text(
              '${contextState.emoji} ${contextState.name}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.close,
              color: Colors.white.withValues(alpha: 0.4),
              size: 20,
            ),
            onPressed: () {
              ref.read(contextProvider.notifier).clearContext();
              ref.read(sentenceProvider.notifier).clearSentence();
            },
            tooltip: 'Cambiar contexto',
          ),
        ],
      ],
    );
  }

  Widget _buildMain(
    BuildContext context,
    WidgetRef ref,
    dynamic contextState,
    List<String> selectedWords,
    AsyncValue<TranslationResult?> translationState,
  ) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Flujo de nodos: breadcrumb + nodos semánticos
          const NodeFlowCanvas(),

          // Divider sutil
          const SizedBox(height: 4),

          // Controles de flujo: progreso + saltar
          const _FlowControls(),

          // Ruta de glosas: ROBAR › CELULAR › AYER
          const GlossPathBuilder(),

          // Vista previa del relato en español
          const StoryPreviewCard(),

          // Panel de resultado (cuando la traducción está lista)
          if (translationState.value != null &&
              translationState.value!.generatedText.isNotEmpty)
            _ResultPanel(result: translationState.value!),

          const SizedBox(height: 8),

          // Botón traducir
          _TranslateButton(
            isLoading: translationState.isLoading,
            enabled: selectedWords.isNotEmpty && !translationState.isLoading,
            onTap: () async {
              final ctxId = contextState.id;
              await ref.read(translationControllerProvider.notifier).translateCards(
                    context: ctxId,
                    cards: selectedWords,
                  );
            },
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// Controles de progreso y skip — versión minimalista.
class _FlowControls extends ConsumerWidget {
  const _FlowControls();

  static const _orange = Color(0xFFFF6B00);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctx = ref.watch(contextProvider);
    final zonesState = ref.watch(semanticZonesProvider);

    if (ctx == null || zonesState.snapshot.orderedZones.isEmpty) {
      return const SizedBox.shrink();
    }

    final total = ctx.zones.length;
    final answered = zonesState.visitedZoneIds.length;
    final hasNext = zonesState.snapshot.orderedZones.any((p) =>
        p.zone.id != zonesState.activeZoneId &&
        !zonesState.visitedZoneIds.contains(p.zone.id));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          // Barra de progreso lineal
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: total > 0 ? answered / total : 0,
                    backgroundColor: Colors.white.withValues(alpha: 0.06),
                    color: _orange,
                    minHeight: 2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$answered de $total preguntas',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withValues(alpha: 0.35),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          if (hasNext)
            GestureDetector(
              onTap: () =>
                  ref.read(semanticZonesProvider.notifier).skipCurrentQuestion(),
              child: Text(
                'Saltar',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.35),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Botón principal de traducción — diseño minimalista en naranja.
class _TranslateButton extends StatelessWidget {
  final bool isLoading;
  final bool enabled;
  final VoidCallback onTap;

  const _TranslateButton({
    required this.isLoading,
    required this.enabled,
    required this.onTap,
  });

  static const _orange = Color(0xFFFF6B00);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: enabled ? _orange : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: enabled
                  ? _orange
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: enabled ? onTap : null,
              child: Center(
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.black,
                          strokeWidth: 2,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.translate,
                            size: 18,
                            color: enabled
                                ? Colors.black
                                : Colors.white.withValues(alpha: 0.2),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'TRADUCIR',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                              color: enabled
                                  ? Colors.black
                                  : Colors.white.withValues(alpha: 0.2),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Panel de resultado multimodal — versión rediseñada con paleta estricta.
class _ResultPanel extends ConsumerWidget {
  final TranslationResult result;
  const _ResultPanel({required this.result});

  static const _orange = Color(0xFFFF6B00);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showBoth =
        result.bedrockUsed && result.baseSentence != result.generatedText;
    final hasText = result.generatedText.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0A0A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _orange.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.check_circle, color: _orange, size: 14),
                const SizedBox(width: 6),
                Text(
                  'TRADUCCIÓN',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const Spacer(),
                if (result.bedrockUsed)
                  Text(
                    'IA Refinado',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withValues(alpha: 0.35),
                    ),
                  ),
              ],
            ),

            if (showBoth) ...[
              const SizedBox(height: 10),
              Text(
                result.baseSentence,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.35),
                  fontStyle: FontStyle.italic,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 6),
              Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
            ],

            SizedBox(height: showBoth ? 10 : 14),

            // Texto final
            Text(
              result.generatedText,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                height: 1.45,
              ),
            ),

            const SizedBox(height: 14),

            // Acciones
            Row(
              children: [
                if (hasText)
                  _ActionButton(
                    icon: Icons.volume_up_outlined,
                    label: result.audioUrl?.isNotEmpty == true
                        ? 'Audio'
                        : 'Audio local',
                    onTap: () async {
                      await ref
                          .read(translationControllerProvider.notifier)
                          .replayAudio();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Reproduciendo...'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                const SizedBox(width: 8),
                _ActionButton(
                  icon: Icons.copy_outlined,
                  label: 'Copiar',
                  onTap: () {
                    Clipboard.setData(
                      ClipboardData(text: result.generatedText),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Texto copiado'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                _ActionButton(
                  icon: Icons.refresh_outlined,
                  label: 'Nueva',
                  onTap: () async {
                    await ref
                        .read(translationControllerProvider.notifier)
                        .reset();
                    ref.read(sentenceProvider.notifier).clearSentence();
                    ref.read(semanticZonesProvider.notifier).reset();
                    ref.read(expandedAnswersProvider.notifier).collapse();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Listo para nueva declaración'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  static const _orange = Color(0xFFFF6B00);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: _orange),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.7),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
