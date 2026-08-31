import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:lsb_legal_app/app/app_theme.dart';
import 'package:lsb_legal_app/app/navigation_provider.dart';
import 'package:lsb_legal_app/core/di/injection.dart';
import 'package:lsb_legal_app/core/presentation/session/flow_surface.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/controllers/translation_controller.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/cards_flow_session.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/context_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/sentence_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/result_visibility_provider.dart';
import 'package:lsb_legal_app/core/domain/entities/translation_result.dart';
import 'package:lsb_legal_app/core/domain/entities/semantic_context.dart';

class DeclarationResultScreen extends ConsumerWidget {
  const DeclarationResultScreen({super.key});

  static const _orange = AppTheme.brandPrimary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final translationState = ref.watch(translationControllerProvider);
    final result = translationState.value;
    final glosses = ref.watch(sentenceProvider);
    final playback = ref.watch(audioPlaybackProvider);
    final servesConversation = ref.watch(flowSurfaceProvider).isConversation;

    return Scaffold(
      backgroundColor: AppTheme.lightBg,
      appBar: AppBar(
        backgroundColor: AppTheme.lightBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.lightText),
          tooltip: 'Volver a editar',
          onPressed: () => _backToEdit(context, ref),
        ),

        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppTheme.lightBorder),
        ),
        title: const Text(
          'Declaración',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppTheme.lightText,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => _cambiarContexto(context, ref),
            icon: const Icon(Icons.swap_horiz_rounded, size: 20),
            label: Text(
              ref.watch(contextProvider)?.name ?? 'Contexto',
              overflow: TextOverflow.ellipsis,
            ),
            style: TextButton.styleFrom(foregroundColor: _orange),
          ),
          const SizedBox(width: 4),
        ],
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
                        color: AppTheme.lightText,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Tu declaración ha sido generada',
                      style: TextStyle(fontSize: 14, color: AppTheme.lightTextSub),
                    ),
                    const SizedBox(height: 20),

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

                    _FullWidthBtn(
                      label: 'Copiar al portapapeles',
                      icon: Icons.copy_outlined,
                      filled: false,
                      onTap: () => _copyToClipboard(context, result),
                    ),
                    const SizedBox(height: 16),

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

                    const _Label('Secuencia de glosas:'),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.lightSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.lightBorder, width: 1.5),
                        boxShadow: AppTheme.cardShadow,
                      ),
                      child: Text(
                        glosses.map((g) => g.replaceAll('_', ' ')).join(' • '),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.lightText,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.lightSubtle,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.lightBorder),
                      ),
                      child: const Text(
                        'Esta traducción puede ser presentada en instituciones '
                        'públicas para formalizar tu declaración.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.lightTextSub,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    if (servesConversation) ...[
                      _FullWidthBtn(
                        label: 'Enviar al chat',
                        icon: Icons.forum_outlined,
                        filled: true,
                        onTap: () => _sendToConversation(context, ref, result),
                      ),
                      const SizedBox(height: 10),
                      _FullWidthBtn(
                        label: 'Volver a la conversación',
                        icon: Icons.arrow_back,
                        filled: false,
                        onTap: () {
                          ref
                              .read(translationControllerProvider.notifier)
                              .pauseAudio();
                          ref
                              .read(selectedTabProvider.notifier)
                              .select(AppTab.conversation);
                        },
                      ),
                      const SizedBox(height: 10),
                    ],
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

  Future<void> _sendToConversation(
      BuildContext context, WidgetRef ref, TranslationResult result) async {
    ref.read(conversationBridgeProvider).submitDeclaration(
          result: result,
          glosses: ref.read(sentenceProvider),
          contextId: ref.read(contextProvider)?.id,
        );
    final session = ref.read(cardsFlowSessionProvider);
    ref.read(selectedTabProvider.notifier).select(AppTab.conversation);
    ref.read(resultVisibleProvider.notifier).hide();
    await session.reset();
  }

  /// Cambia el contexto sin salir de la declaración.
  ///
  /// Se confirma antes porque no es reversible: el contexto determina las
  /// zonas y las tarjetas disponibles, así que lo respondido bajo el anterior
  /// deja de tener sentido y el flujo arranca limpio.
  Future<void> _cambiarContexto(BuildContext context, WidgetRef ref) async {
    final actual = ref.read(contextProvider);

    final elegido = await showModalBottomSheet<SemanticContext>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Text(
                'Cambiar de contexto',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                'Se empezará una declaración nueva.',
                style: TextStyle(fontSize: 13, color: AppTheme.lightTextSub),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final c in allSelectableContexts)
                    ListTile(
                      leading: Text(c.emoji,
                          style: const TextStyle(fontSize: 22)),
                      title: Text(c.name),
                      subtitle: Text(
                        c.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      selected: c.id == actual?.id,
                      selectedTileColor:
                          _orange.withValues(alpha: 0.08),
                      trailing: c.id == actual?.id
                          ? const Icon(Icons.check_rounded, color: _orange)
                          : null,
                      onTap: () => Navigator.of(sheetContext).pop(c),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (elegido == null || elegido.id == actual?.id) return;

    ref.read(translationControllerProvider.notifier).pauseAudio();
    await ref.read(cardsFlowSessionProvider).reset();
    ref.read(contextProvider.notifier).setContext(elegido);
    ref.read(resultVisibleProvider.notifier).hide();
  }

  void _backToEdit(BuildContext context, WidgetRef ref) {
    ref.read(translationControllerProvider.notifier).pauseAudio();
    // El resultado es un paso de la pestana, no una ruta apilada: se vuelve
    // ocultandolo, y el armado de la frase sigue intacto detras.
    ref.read(resultVisibleProvider.notifier).hide();
  }

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

  Future<void> _newDeclaration(BuildContext context, WidgetRef ref) async {
    await ref.read(cardsFlowSessionProvider).reset(keepContext: true);
    if (!context.mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/lsb-to-audio');
    }
  }
}

class _OriginChip extends StatelessWidget {
  final bool bedrockUsed;
  const _OriginChip({required this.bedrockUsed});

  static const _orange = AppTheme.brandPrimary;

  @override
  Widget build(BuildContext context) {
    final (icon, label, color) = bedrockUsed
        ? (Icons.auto_awesome, 'Refinado por IA', _orange)
        : (Icons.offline_bolt_outlined, 'Motor local', AppTheme.lightTextSub);
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
        color: AppTheme.lightTextSub,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.0,
      ),
    );
  }
}

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

  static const _orange = AppTheme.brandPrimary;

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

  static const _orange = AppTheme.brandPrimary;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final fg = filled
        ? Colors.white
        : (enabled ? AppTheme.lightText : AppTheme.lightTextSub.withValues(alpha: 0.5));
    final bg = filled
        ? (enabled ? _orange : AppTheme.lightBorder)
        : AppTheme.lightSurface;
    final borderColor = filled
        ? bg
        : (enabled ? AppTheme.lightBorder : AppTheme.lightBorder.withValues(alpha: 0.5));

    return SizedBox(
      height: 52,
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
              style: TextStyle(fontSize: 15, color: AppTheme.lightTextSub),
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
