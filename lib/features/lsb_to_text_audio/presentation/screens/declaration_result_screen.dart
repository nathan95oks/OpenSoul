import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:lsb_legal_app/app/app_theme.dart';
import 'package:lsb_legal_app/app/navigation_provider.dart';
import 'package:lsb_legal_app/core/domain/entities/translation_result.dart';
import 'package:lsb_legal_app/core/domain/services/conversation_bridge.dart';
import 'package:lsb_legal_app/core/presentation/session/cards_flow_launch.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/controllers/translation_controller.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/cards_flow_session.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/conversation_return.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/guided_flow_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/result_visibility_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/sentence_provider.dart';

class DeclarationResultScreen extends ConsumerWidget {
  const DeclarationResultScreen({super.key});

  static const _orange = AppTheme.brandPrimary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final translationState = ref.watch(translationControllerProvider);
    final result = translationState.value;
    final glosses = ref.watch(sentenceProvider);
    final playback = ref.watch(audioPlaybackProvider);
    // Que la declaración sirva a una conversación es propiedad del
    // lanzamiento, no de la pestaña ni de la superficie: en modo A no se
    // ofrece enviarla al chat aunque haya un chat abierto detrás.
    final servesConversation = ref
        .watch(cardsFlowLaunchProvider)
        .purpose
        .servesConversation;
    // Mientras el backend responde se muestra la misma redacción del banco
    // que ya se veía en la vista previa: nunca otra frase.
    final guidedText = ref.watch(guidedPreviewProvider);
    final displayText = (result != null && result.generatedText.isNotEmpty)
        ? result.generatedText
        : (guidedText.isNotEmpty ? guidedText : (result?.baseSentence ?? ''));

    final hasContent = displayText.isNotEmpty || glosses.isNotEmpty;

    return Scaffold(
      backgroundColor: AppTheme.lightBg,
      appBar: AppBar(
        backgroundColor: AppTheme.lightBg,
        elevation: 0,
        automaticallyImplyLeading: false,
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
      ),
      body: SafeArea(
        child: !hasContent
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
                      'Tu declaración formal ha sido consolidada',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.lightTextSub,
                      ),
                    ),
                    const SizedBox(height: 18),

                    const _Label('Texto formal para autoridades:'),
                    const SizedBox(height: 8),

                    // Tarjeta Principal con la Declaración Formal Consolidada
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: _orange,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _orange, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: _orange.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        displayText,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Reproductor de la declaración, como una nota de voz.
                    _VoiceNotePlayer(
                      playback: playback,
                      text: displayText,
                      onPlay: () {
                        final controller = ref.read(
                          translationControllerProvider.notifier,
                        );
                        if (playback == AudioPlaybackState.paused) {
                          controller.resumeAudio(fallbackText: displayText);
                        } else {
                          controller.replayAudio(fallbackText: displayText);
                        }
                      },
                      onPause: () => ref
                          .read(translationControllerProvider.notifier)
                          .pauseAudio(),
                    ),
                    const SizedBox(height: 20),

                    const SizedBox(height: 24),

                    if (servesConversation) ...[
                      if (result != null) ...[
                        _FullWidthBtn(
                          label: 'Enviar al chat',
                          icon: Icons.forum_outlined,
                          filled: true,
                          onTap: () =>
                              _sendToConversation(context, ref, result),
                        ),
                        const SizedBox(height: 10),
                      ],
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
                              .select(AppTabId.conversation);
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
                      onTap: () => _newDeclaration(ref),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Future<void> _sendToConversation(
    BuildContext context,
    WidgetRef ref,
    TranslationResult result,
  ) async {
    // El enlace es el que se congeló al abrir, no el último turno de ahora:
    // si entró otro mensaje mientras se armaba la respuesta, esta sigue
    // colgando de la pregunta que la persona sorda tenía delante.
    final outcome = await ref
        .read(conversationReturnProvider)
        .deliver(
          result,
          intervention: ref.read(guidedFlowProvider.notifier).intervention,
        );

    if (outcome == SubmitOutcome.staleReply) {
      if (!context.mounted) return;
      // No se envía a ciegas ni se reengancha a otra pregunta: se dice qué
      // pasó y la declaración queda intacta para copiarla o rehacerla.
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'El mensaje al que respondías ya no está en el chat. '
              'Tu declaración no se envió: vuelve al chat y responde de nuevo.',
            ),
            duration: Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  void _backToEdit(BuildContext context, WidgetRef ref) {
    ref.read(translationControllerProvider.notifier).pauseAudio();
    // El resultado es un paso de la pestaña, no una ruta apilada: se vuelve
    // ocultándolo, y el armado de la frase sigue intacto detrás para permitir
    // cambiar y editar las glosas y respuestas usadas.
    ref.read(resultVisibleProvider.notifier).hide();
    if (context.canPop()) {
      context.pop();
    }
  }

  Future<void> _newDeclaration(WidgetRef ref) async {
    ref.read(translationControllerProvider.notifier).pauseAudio();
    // Limpia todo el flujo y contexto para redirigir a la selección de contexto
    // (trámites, consultas, demandas o preguntas).
    await ref.read(cardsFlowSessionProvider).reset(keepContext: false);
    ref
        .read(cardsFlowLaunchProvider.notifier)
        .start(const CardsFlowLaunch.standalone());
    ref.read(resultVisibleProvider.notifier).hide();
    ref.read(selectedTabProvider.notifier).select(AppTabId.cards);
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

/// Reproductor de la declaración al estilo de una nota de voz: un botón
/// redondo que pasa de play a pausa y una onda que se va llenando mientras
/// suena.
///
/// El audio no informa su posición, así que el llenado sigue una duración
/// estimada por la cantidad de palabras; si el audio termina antes, la onda
/// vuelve a empezar, y si dura más, espera llena hasta que termine.
class _VoiceNotePlayer extends StatefulWidget {
  final AudioPlaybackState playback;
  final String text;
  final VoidCallback onPlay;
  final VoidCallback onPause;

  const _VoiceNotePlayer({
    required this.playback,
    required this.text,
    required this.onPlay,
    required this.onPause,
  });

  @override
  State<_VoiceNotePlayer> createState() => _VoiceNotePlayerState();
}

class _VoiceNotePlayerState extends State<_VoiceNotePlayer>
    with TickerProviderStateMixin {
  static const _orange = AppTheme.brandPrimary;
  static const _barras = 28;

  late final AnimationController _progreso = AnimationController(
    vsync: this,
    duration: _duracionEstimada(widget.text),
  );
  late final AnimationController _pulso = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );

  /// Alturas fijas de la onda (entre 0.3 y 1), derivadas del texto para que
  /// cada declaración tenga su propio dibujo.
  late List<double> _alturas = _ondaDe(widget.text);

  bool get _sonando => widget.playback == AudioPlaybackState.playing;

  static Duration _duracionEstimada(String text) {
    final palabras = text.trim().split(RegExp(r'\s+')).length;
    // Unas 2,5 palabras por segundo, como habla Polly.
    final ms = (palabras / 2.5 * 1000).round().clamp(1500, 60000);
    return Duration(milliseconds: ms);
  }

  static List<double> _ondaDe(String text) {
    var semilla = text.hashCode & 0x7fffffff;
    return List.generate(_barras, (i) {
      semilla = (semilla * 1103515245 + 12345) & 0x7fffffff;
      final base = 0.3 + (semilla % 1000) / 1000 * 0.7;
      // Los extremos más bajos, como el inicio y el final de una frase.
      final borde = (i < 3 || i >= _barras - 3) ? 0.6 : 1.0;
      return (base * borde).clamp(0.3, 1.0);
    });
  }

  @override
  void initState() {
    super.initState();
    if (_sonando) _progreso.forward();
  }

  @override
  void didUpdateWidget(covariant _VoiceNotePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _progreso.duration = _duracionEstimada(widget.text);
      _alturas = _ondaDe(widget.text);
      _progreso.value = 0;
    }
    if (oldWidget.playback == widget.playback) return;
    switch (widget.playback) {
      case AudioPlaybackState.playing:
        if (oldWidget.playback == AudioPlaybackState.idle) _progreso.value = 0;
        _progreso.forward();
        _pulso.forward(from: 0);
      case AudioPlaybackState.paused:
        _progreso.stop();
      case AudioPlaybackState.idle:
        _progreso.value = 0;
    }
  }

  @override
  void dispose() {
    _progreso.dispose();
    _pulso.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final etiqueta = switch (widget.playback) {
      AudioPlaybackState.playing => 'Reproduciendo…',
      AudioPlaybackState.paused => 'En pausa',
      AudioPlaybackState.idle => 'Reproducir',
    };

    return Semantics(
      button: true,
      label: _sonando ? 'Pausar' : 'Reproducir',
      excludeSemantics: true,
      child: Material(
        color: AppTheme.lightSurface,
        borderRadius: BorderRadius.circular(32),
        child: InkWell(
          key: const Key('reproducir_declaracion'),
          borderRadius: BorderRadius.circular(32),
          onTap: _sonando ? widget.onPause : widget.onPlay,
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 8, 18, 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: AppTheme.lightBorder, width: 1.5),
            ),
            child: Row(
              children: [
                _boton(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(height: 30, child: _onda()),
                      const SizedBox(height: 4),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Text(
                          etiqueta,
                          key: ValueKey(etiqueta),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.lightTextSub,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Botón redondo: al tocarlo late una vez y el ícono gira de play a pausa.
  Widget _boton() {
    return AnimatedBuilder(
      animation: _pulso,
      builder: (context, child) {
        // Crece y vuelve, como la burbuja de WhatsApp al tocar play.
        final t = Curves.easeOut.transform(_pulso.value);
        final escala = 1 + 0.12 * (1 - (2 * t - 1).abs());
        return Transform.scale(scale: escala, child: child);
      },
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: _orange,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: _orange.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: (child, animation) => RotationTransition(
            turns: Tween<double>(begin: 0.75, end: 1).animate(animation),
            child: ScaleTransition(scale: animation, child: child),
          ),
          child: Icon(
            _sonando ? Icons.pause_rounded : Icons.play_arrow_rounded,
            key: ValueKey(_sonando),
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
    );
  }

  /// La onda: las barras ya escuchadas se pintan del color de la marca y un
  /// punto recorre la línea marcando por dónde va.
  Widget _onda() {
    return AnimatedBuilder(
      animation: _progreso,
      builder: (context, _) {
        final avance = _progreso.value;
        return LayoutBuilder(
          builder: (context, constraints) {
            final ancho = constraints.maxWidth;
            return Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.centerLeft,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (var i = 0; i < _barras; i++)
                      Container(
                        width: 3,
                        height: 30 * _alturas[i],
                        decoration: BoxDecoration(
                          color: (i + 0.5) / _barras <= avance
                              ? _orange
                              : AppTheme.lightTextSub.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                  ],
                ),
                Positioned(
                  left: (ancho - 12) * avance,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: _orange,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
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
        : (enabled
              ? AppTheme.lightText
              : AppTheme.lightTextSub.withValues(alpha: 0.5));
    final bg = filled
        ? (enabled ? _orange : AppTheme.lightBorder)
        : AppTheme.lightSurface;
    final borderColor = filled
        ? bg
        : (enabled
              ? AppTheme.lightBorder
              : AppTheme.lightBorder.withValues(alpha: 0.5));

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
