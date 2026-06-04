import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/repositories/translation_repository.dart';
import '../providers/sentence_provider.dart';
import '../providers/semantic_zones_provider.dart';
import '../controllers/translation_controller.dart';
import '../providers/context_provider.dart';
import '../providers/story_preview_provider.dart';
import '../widgets/context_selection_widget.dart';
import '../widgets/node_flow_canvas.dart';
import '../widgets/card_grid.dart';

/// Pantalla principal del módulo LSB → Texto → Audio.
///
/// Layout (fondo blanco, árbol conceptual vertical):
///   AppBar  → "OpenSoul" + contexto activo
///   Body    → SingleChildScrollView con NodeFlowCanvas (árbol pregunta→respuesta)
///   Bottom  → Panel fijo: secuencia construida + botón TRADUCIR
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
      backgroundColor: Colors.white,
      appBar: _buildAppBar(ref, contextState, selectedWords),
      body: SafeArea(
        child: contextState == null
            ? const ContextSelectionWidget()
            : _buildFlow(context, ref, contextState, selectedWords, translationState),
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
            onPressed: () {
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
        // Árbol conceptual scrollable
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const NodeFlowCanvas(),
                // Panel de resultado (si hay traducción)
                if (translationState.value != null &&
                    translationState.value!.generatedText.isNotEmpty)
                  _ResultSection(result: translationState.value!),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        // Panel fijo inferior: secuencia + botón traducir
        _BottomPanel(
          glosses: selectedWords,
          isLoading: translationState.isLoading,
          onTranslate: selectedWords.isEmpty || translationState.isLoading
              ? null
              : () async {
                  await ref
                      .read(translationControllerProvider.notifier)
                      .translateCards(
                        context: contextState.id,
                        cards: selectedWords,
                      );
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
                            color: enabled ? Colors.white : const Color(0xFFAAAAAA),
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

/// Sección de resultado de traducción — dentro del scroll.
class _ResultSection extends ConsumerWidget {
  final TranslationResult result;
  const _ResultSection({required this.result});

  static const _orange = Color(0xFFFF6B00);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview = ref.watch(storyPreviewProvider);
    final hasText = result.generatedText.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Separador visual
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: SizedBox(
                height: 12,
                child: VerticalDivider(color: Color(0xFFCCCCCC), width: 1),
              ),
            ),
          ),

          // Glosas (secuencia LSB)
          const Text(
            'SECUENCIA DE GLOSAS:',
            style: TextStyle(
              fontSize: 11,
              color: Color(0xFF888888),
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black, width: 2),
            ),
            child: Text(
              preview.isNotEmpty ? preview : result.baseSentence,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Flecha visual
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Icon(Icons.keyboard_arrow_down, size: 28, color: Color(0xFFCCCCCC)),
            ),
          ),

          const SizedBox(height: 8),

          // Traducción
          const Text(
            'TRADUCCIÓN PARA INSTITUCIÓN PÚBLICA:',
            style: TextStyle(
              fontSize: 11,
              color: Color(0xFF888888),
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _orange,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _orange, width: 2),
            ),
            child: Text(
              result.generatedText,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                height: 1.5,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Acciones
          Row(
            children: [
              if (hasText)
                _ActionBtn(
                  label: 'Audio',
                  icon: Icons.volume_up_outlined,
                  onTap: () async {
                    await ref
                        .read(translationControllerProvider.notifier)
                        .replayAudio();
                  },
                ),
              const SizedBox(width: 10),
              _ActionBtn(
                label: 'Copiar',
                icon: Icons.copy_outlined,
                onTap: () {
                  Clipboard.setData(ClipboardData(text: result.generatedText));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Texto copiado'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
              ),
              const Spacer(),
              _ActionBtn(
                label: 'Nueva declaración',
                icon: Icons.refresh_outlined,
                filled: true,
                onTap: () async {
                  await ref.read(translationControllerProvider.notifier).reset();
                  ref.read(sentenceProvider.notifier).clearSentence();
                  ref.read(semanticZonesProvider.notifier).reset();
                  ref.read(expandedAnswersProvider.notifier).collapse();
                },
              ),
            ],
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool filled;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.onTap,
    this.filled = false,
  });

  static const _orange = Color(0xFFFF6B00);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: filled ? _orange : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: filled ? _orange : Colors.black,
            width: filled ? 2 : 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: filled ? Colors.white : Colors.black),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: filled ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
