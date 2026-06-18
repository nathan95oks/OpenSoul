import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/repositories/translation_repository.dart';
import '../controllers/translation_controller.dart';
import '../providers/sentence_provider.dart';
import '../providers/semantic_zones_provider.dart';
import '../widgets/card_grid.dart' show expandedAnswersProvider;

/// Pantalla de resultado dedicada (CAMBIO #4).
///
/// Tras pulsar "Traducir" se navega aquí, de modo que la declaración
/// generada es lo primero que se ve, sin tener que desplazarse por el
/// flujo guiado. Reutiliza el `TranslationController`, los providers y el
/// `AudioPlayer` existentes — no duplica la lógica de traducción ni de
/// generación de audio.
///
///   - "Volver a editar": regresa al flujo guiado conservando TODAS las
///     respuestas (simple `pop`; el estado vive en el ProviderScope raíz).
///   - "Nueva declaración": limpia el estado y vuelve al inicio del flujo.
class DeclarationResultScreen extends ConsumerWidget {
  const DeclarationResultScreen({super.key});

  static const _orange = Color(0xFFFF6B00);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final translationState = ref.watch(translationControllerProvider);
    final result = translationState.value;
    final glosses = ref.watch(sentenceProvider);
    final playback = ref.watch(audioPlaybackProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          tooltip: 'Volver a editar',
          onPressed: () => _backToEdit(context, ref),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 2, color: Colors.black),
        ),
        title: const Text(
          'Declaración',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.black,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: SafeArea(
        child: result == null || result.generatedText.isEmpty
            ? _EmptyResult(onBack: () => _backToEdit(context, ref))
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Traducción lista',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Tu declaración ha sido generada',
                      style: TextStyle(fontSize: 14, color: Color(0xFF666666)),
                    ),
                    const SizedBox(height: 20),

                    // ── Traducción (lo más importante, arriba) ───────────
                    Row(
                      children: [
                        const Expanded(
                          child: _Label('Traducción para institución pública:'),
                        ),
                        _OriginChip(bedrockUsed: result.bedrockUsed),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: _orange,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _orange, width: 2),
                      ),
                      child: Text(
                        result.generatedText,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Copiar la declaración al portapapeles ────────────
                    _FullWidthBtn(
                      label: 'Copiar al portapapeles',
                      icon: Icons.copy_outlined,
                      filled: false,
                      onTap: () => _copyToClipboard(context, result),
                    ),
                    const SizedBox(height: 16),

                    // ── Controles de audio + indicador ───────────────────
                    _AudioControls(
                      playback: playback,
                      hasRemoteAudio:
                          result.audioUrl != null &&
                          result.audioUrl!.isNotEmpty,
                      onPlay: () {
                        if (playback == AudioPlaybackState.paused) {
                          ref
                              .read(translationControllerProvider.notifier)
                              .resumeAudio();
                        } else {
                          ref
                              .read(translationControllerProvider.notifier)
                              .replayAudio();
                        }
                      },
                      onPause: () => ref
                          .read(translationControllerProvider.notifier)
                          .pauseAudio(),
                    ),
                    const SizedBox(height: 20),

                    // ── Secuencia de glosas (referencia) ─────────────────
                    const _Label('Secuencia de glosas:'),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.black, width: 2),
                      ),
                      child: Text(
                        glosses.map((g) => g.replaceAll('_', ' ')).join(' • '),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE0E0E0)),
                      ),
                      child: const Text(
                        'Esta traducción puede ser presentada en instituciones '
                        'públicas para formalizar tu declaración.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF555555),
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Acciones principales ─────────────────────────────
                    _FullWidthBtn(
                      label: 'Volver a editar',
                      icon: Icons.edit_outlined,
                      filled: false,
                      onTap: () => _backToEdit(context, ref),
                    ),
                    const SizedBox(height: 10),
                    _FullWidthBtn(
                      label: 'Nueva declaración',
                      icon: Icons.refresh_outlined,
                      filled: true,
                      onTap: () => _newDeclaration(context, ref),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  /// Vuelve al flujo guiado conservando todas las respuestas. El estado
  /// (frase, zonas, contexto) sigue vivo en el ProviderScope raíz; solo
  /// detenemos el audio en curso.
  void _backToEdit(BuildContext context, WidgetRef ref) {
    ref.read(translationControllerProvider.notifier).pauseAudio();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/lsb-to-audio');
    }
  }

  /// Copia la declaración generada al portapapeles del sistema. Prefiere el
  /// texto refinado ([generatedText]); si estuviera vacío, recurre a la oración
  /// base del motor local ([baseSentence]). Confirma con un SnackBar.
  Future<void> _copyToClipboard(
      BuildContext context, TranslationResult result) async {
    final text = result.generatedText.isNotEmpty
        ? result.generatedText
        : result.baseSentence;
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Declaración copiada al portapapeles'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  /// Limpia todo el estado y regresa al inicio del flujo (misma categoría
  /// de contexto). Reutiliza exactamente la misma secuencia de limpieza
  /// que ya existía para "Nueva declaración".
  Future<void> _newDeclaration(BuildContext context, WidgetRef ref) async {
    await ref.read(translationControllerProvider.notifier).reset();
    ref.read(sentenceProvider.notifier).clearSentence();
    ref.read(semanticZonesProvider.notifier).reset();
    ref.read(expandedAnswersProvider.notifier).collapse();
    if (!context.mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/lsb-to-audio');
    }
  }
}

/// Indica al usuario el origen de la declaración (RVP-01): si la oración fue
/// refinada por la IA remota (Bedrock) o producida por el motor local —que
/// actúa como fallback cuando el backend cae, degenera o no está disponible.
class _OriginChip extends StatelessWidget {
  final bool bedrockUsed;
  const _OriginChip({required this.bedrockUsed});

  static const _orange = Color(0xFFFF6B00);

  @override
  Widget build(BuildContext context) {
    final (icon, label, color) = bedrockUsed
        ? (Icons.auto_awesome, 'Refinado por IA', _orange)
        : (Icons.offline_bolt_outlined, 'Motor local', const Color(0xFF555555));
    return Semantics(
      label: bedrockUsed
          ? 'Declaración refinada por inteligencia artificial'
          : 'Declaración generada por el motor local sin conexión',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        color: Color(0xFF888888),
        fontWeight: FontWeight.w700,
        letterSpacing: 1.0,
      ),
    );
  }
}

/// Controles de reproducción: botón reproducir, botón pausar e indicador
/// del estado de reproducción actual.
class _AudioControls extends StatelessWidget {
  final AudioPlaybackState playback;
  final bool hasRemoteAudio;
  final VoidCallback onPlay;
  final VoidCallback onPause;

  const _AudioControls({
    required this.playback,
    required this.hasRemoteAudio,
    required this.onPlay,
    required this.onPause,
  });

  static const _orange = Color(0xFFFF6B00);

  @override
  Widget build(BuildContext context) {
    final isPlaying = playback == AudioPlaybackState.playing;

    final (indicatorIcon, indicatorText) = switch (playback) {
      AudioPlaybackState.playing => (Icons.graphic_eq, 'Reproduciendo…'),
      AudioPlaybackState.paused => (Icons.pause_circle_outline, 'En pausa'),
      AudioPlaybackState.idle => (
        Icons.volume_up_outlined,
        hasRemoteAudio ? 'Audio listo (Polly)' : 'Audio listo (local)',
      ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Indicador de reproducción actual
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: _orange.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _orange.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(indicatorIcon, size: 15, color: _orange),
              const SizedBox(width: 6),
              Text(
                indicatorText,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _orange,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _FullWidthBtn(
                label: 'Reproducir',
                icon: Icons.play_arrow_rounded,
                filled: !isPlaying,
                onTap: isPlaying ? null : onPlay,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _FullWidthBtn(
                label: 'Pausar',
                icon: Icons.pause_rounded,
                filled: isPlaying,
                onTap: isPlaying ? onPause : null,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Botón full-width reutilizable — mismo lenguaje visual que el resto.
class _FullWidthBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool filled;
  final VoidCallback? onTap;

  const _FullWidthBtn({
    required this.label,
    required this.icon,
    required this.filled,
    required this.onTap,
  });

  static const _orange = Color(0xFFFF6B00);

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final fg = filled
        ? Colors.white
        : (enabled ? Colors.black : Colors.black.withValues(alpha: 0.3));
    final bg = filled
        ? (enabled ? _orange : const Color(0xFFE5E5E5))
        : Colors.white;
    final borderColor = filled
        ? bg
        : (enabled ? const Color(0xFFCCCCCC) : const Color(0xFFE5E5E5));

    return SizedBox(
      height: 52,
      // A11Y-01: cada acción se anuncia como botón con su etiqueta y estado.
      child: Semantics(
        button: true,
        enabled: enabled,
        label: label,
        excludeSemantics: true,
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor, width: filled ? 2 : 1.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 18, color: fg),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: fg,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyResult extends StatelessWidget {
  final VoidCallback onBack;
  const _EmptyResult({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'No hay ninguna declaración generada todavía.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Color(0xFF666666)),
            ),
            const SizedBox(height: 16),
            _FullWidthBtn(
              label: 'Volver a editar',
              icon: Icons.edit_outlined,
              filled: true,
              onTap: onBack,
            ),
          ],
        ),
      ),
    );
  }
}
