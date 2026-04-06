import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/repositories/translation_repository.dart';
import '../providers/sentence_provider.dart';
import '../controllers/translation_controller.dart';
import '../widgets/sentence_builder.dart';
import '../widgets/category_filter.dart';
import '../widgets/card_grid.dart';

/// Pantalla principal del módulo LSB → Texto → Audio.
///
/// Layout: SentenceBuilder → CategoryFilter → CardGrid → ResultPanel → TranslateButton
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedWords = ref.watch(sentenceProvider);
    final translationState = ref.watch(translationControllerProvider);

    ref.listen<AsyncValue<TranslationResult?>>(
      translationControllerProvider,
      (previous, next) {
        if (next is AsyncError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${next.error}'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.gavel, color: Color(0xFFFFD700), size: 20),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('OpenSoul', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                Text('Asistente Jurídico LSB', style: TextStyle(fontSize: 11, color: Color(0xFF8B949E))),
              ],
            ),
          ],
        ),
        actions: [
          if (selectedWords.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.white54),
              onPressed: () => ref.read(sentenceProvider.notifier).clearSentence(),
              tooltip: 'Borrar secuencia',
            ),
        ],
      ),
      body: Column(
        children: [
          const SentenceBuilder(),
          const CategoryFilter(),
          const CardGrid(),

          // Panel de resultado multimodal
          if (translationState.value != null && translationState.value!.generatedText.isNotEmpty)
            _ResultPanel(result: translationState.value!),

          // Botón traducir
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: selectedWords.isEmpty || translationState.isLoading
                    ? null
                    : () async {
                        await ref.read(translationControllerProvider.notifier).translateCards(
                          context: 'legal',
                          cards: selectedWords,
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD700),
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: const Color(0xFF21262D),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: translationState.isLoading
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                      )
                    : const Icon(Icons.translate, size: 22),
                label: Text(
                  translationState.isLoading ? 'PROCESANDO...' : 'TRADUCIR Y GENERAR',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Panel de resultado multimodal integrado en la misma pantalla.
/// Muestra baseSentence, generatedText, indicador de Bedrock y controles de audio.
class _ResultPanel extends StatelessWidget {
  final TranslationResult result;
  const _ResultPanel({required this.result});

  @override
  Widget build(BuildContext context) {
    final showBothTexts = result.bedrockUsed && result.baseSentence != result.generatedText;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.check_circle, color: Color(0xFF3FB950), size: 16),
                const SizedBox(width: 6),
                const Text(
                  'RESULTADO',
                  style: TextStyle(color: Color(0xFF8B949E), fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2),
                ),
                const Spacer(),
                if (result.bedrockUsed)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00ADB5).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome, size: 12, color: Color(0xFF00ADB5)),
                        SizedBox(width: 4),
                        Text('IA Refinado', style: TextStyle(fontSize: 10, color: Color(0xFF00ADB5), fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
              ],
            ),

            // Base sentence (if Bedrock refined it)
            if (showBothTexts) ...[
              const SizedBox(height: 10),
              const Text(
                'Motor propio:',
                style: TextStyle(color: Color(0xFF8B949E), fontSize: 10, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                result.baseSentence,
                style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.5), fontStyle: FontStyle.italic),
              ),
            ],

            // Generated text (main)
            SizedBox(height: showBothTexts ? 8 : 10),
            if (showBothTexts)
              const Text(
                'Texto refinado:',
                style: TextStyle(color: Color(0xFFFFD700), fontSize: 10, fontWeight: FontWeight.w600),
              ),
            const SizedBox(height: 2),
            Text(
              result.generatedText,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white, height: 1.4),
            ),

            // Intermediate representation (type of event)
            if (result.intermediateRepresentation != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF21262D),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Tipo: ${result.intermediateRepresentation!['tipo_evento'] ?? 'GENERAL'}',
                  style: const TextStyle(fontSize: 10, color: Color(0xFF8B949E), fontWeight: FontWeight.w600),
                ),
              ),
            ],

            // Action buttons
            const SizedBox(height: 10),
            Row(
              children: [
                if (result.audioUrl != null && result.audioUrl!.isNotEmpty)
                  _ActionChip(
                    icon: Icons.volume_up,
                    label: 'Audio',
                    color: const Color(0xFFFFD700),
                    onTap: () {
                      // Audio already auto-plays via controller
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Reproduciendo audio...'), duration: Duration(seconds: 1)),
                      );
                    },
                  ),
                const SizedBox(width: 8),
                _ActionChip(
                  icon: Icons.copy,
                  label: 'Copiar',
                  color: const Color(0xFF8B949E),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: result.generatedText));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Texto copiado'), duration: Duration(seconds: 1)),
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

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionChip({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}


