import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lsb_legal_app/app/app_theme.dart';
import 'package:lsb_legal_app/features/audio_to_lsb/presentation/controllers/audio_translation_controller.dart';
import 'package:lsb_legal_app/core/presentation/widgets/avatar_3d_viewer.dart';
import 'package:lsb_legal_app/features/audio_to_lsb/presentation/widgets/text_input_widget.dart';

class AudioToLsbScreen extends ConsumerStatefulWidget {
  /// `false` cuando la pantalla sigue montada pero el usuario esta en otro
  /// modulo: detiene el avatar y el dictado en vez de dejarlos correr detras.
  final bool isActive;

  const AudioToLsbScreen({super.key, this.isActive = true});

  @override
  ConsumerState<AudioToLsbScreen> createState() => _AudioToLsbScreenState();
}

class _AudioToLsbScreenState extends ConsumerState<AudioToLsbScreen> {
  bool _playbackActive = false;
  bool _userComposing = false;
  int _playbackRequestId = 0;

  @override
  void didUpdateWidget(AudioToLsbScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive && !widget.isActive) {
      _playbackActive = false;
    }
  }

  void _setPlaybackActive(bool active) {
    if (!mounted || _playbackActive == active) return;
    setState(() => _playbackActive = active);
  }

  void _submit(
    BuildContext context,
    AudioTranslationController controller,
    String text,
  ) {
    FocusScope.of(context).unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');
    setState(() {
      _playbackActive = true;
      _userComposing = false;
      _playbackRequestId++;
    });
    controller.processText(text);
  }

  void _returnToInitial(AudioTranslationController controller) {
    _setPlaybackActive(false);
    controller.reset();
  }

  void _setUserComposing(bool composing) {
    if (!mounted || _userComposing == composing) return;
    setState(() => _userComposing = composing);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(audioTranslationControllerProvider);
    final controller = ref.read(audioTranslationControllerProvider.notifier);
    final immersive =
        widget.isActive &&
        (state.status == AudioTranslationStatus.processing ||
            (state.status == AudioTranslationStatus.success &&
                _playbackActive));

    return Theme(
      data: AppTheme.darkTheme,
      child: Builder(
        builder: (context) {
          return _buildScreen(context, state, controller, immersive);
        },
      ),
    );
  }

  Widget _buildScreen(
    BuildContext context,
    AudioTranslationState state,
    AudioTranslationController controller,
    bool immersive,
  ) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
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
            const Text(
              'Traductor a LSB',
              style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.5),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: GestureDetector(
        onTap: () {
          FocusManager.instance.primaryFocus?.unfocus();
          SystemChannels.textInput.invokeMethod('TextInput.hide');
        },
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: AnimatedPadding(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                      padding: EdgeInsets.symmetric(
                        horizontal: immersive ? 8 : 20,
                        vertical: immersive ? 4 : 10,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            colors: [
                              AppTheme.brandElectric.withValues(alpha: 0.12),
                              AppTheme.darkSurface,
                            ],
                            radius: 0.9,
                          ),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: AppTheme.darkBorder),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.brandPrimary.withValues(
                                alpha: 0.18,
                              ),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(30),
                          child: Avatar3DViewer(
                            isActive: widget.isActive,
                            isProcessing:
                                widget.isActive &&
                                state.status ==
                                    AudioTranslationStatus.processing,
                            expandToFit: immersive,
                            onPlaybackStateChanged: _setPlaybackActive,
                            onReturnToInput: () => _returnToInitial(controller),
                            playbackRequestId: _playbackRequestId,
                            isUserComposing: _userComposing,
                            glosses:
                                state.status == AudioTranslationStatus.success
                                ? (state
                                              .translationResult
                                              ?.animationGlosses
                                              .isNotEmpty ==
                                          true
                                      ? state
                                            .translationResult
                                            ?.animationGlosses
                                      : state.translationResult?.glosses)
                                : null,
                            animationUrls:
                                state.status == AudioTranslationStatus.success
                                ? state.translationResult?.animationUrls
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ),

                  if (state.status == AudioTranslationStatus.needsClarification)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24.0,
                        vertical: 8.0,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.brandElectric.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppTheme.brandElectric.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'ANTES DE TRADUCIR, UNA PRECISIÓN:',
                              style: TextStyle(
                                color: AppTheme.brandLight,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(height: 8),
                            for (final pendiente
                                in state.pendingClarifications) ...[
                              Text(
                                pendiente.question,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final opcion in pendiente.options)
                                    OutlinedButton(
                                      onPressed: () =>
                                          controller.resolveClarification(
                                            pendiente.term,
                                            opcion.id,
                                          ),
                                      child: Text(opcion.label),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                            ],
                            TextButton(
                              onPressed: controller.cancelClarification,
                              child: const Text('Prefiero reformular la frase'),
                            ),
                          ],
                        ),
                      ),
                    ),

                  if (state.status == AudioTranslationStatus.error)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24.0,
                        vertical: 8.0,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.redAccent.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.redAccent,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                state.errorMessage ?? 'Ocurrió un error',
                                style: const TextStyle(color: Colors.redAccent),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  if (!immersive)
                    Container(
                      padding: const EdgeInsets.only(
                        left: 20,
                        right: 20,
                        bottom: 24,
                        top: 12,
                      ),
                      child: TextInputWidget(
                        isActive: widget.isActive,
                        onSubmit: (text) => _submit(context, controller, text),
                        onComposingChanged: _setUserComposing,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
