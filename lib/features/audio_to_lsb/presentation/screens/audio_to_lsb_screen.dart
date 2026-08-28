import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui';
import 'package:lsb_legal_app/app/app_theme.dart';
import 'package:lsb_legal_app/features/audio_to_lsb/presentation/controllers/audio_translation_controller.dart';
import 'package:lsb_legal_app/core/presentation/widgets/avatar_3d_viewer.dart';
import 'package:lsb_legal_app/features/audio_to_lsb/presentation/widgets/text_input_widget.dart';

class AudioToLsbScreen extends ConsumerWidget {
  /// `false` cuando la pantalla sigue montada pero el usuario esta en otro
  /// modulo: detiene el avatar y el dictado en vez de dejarlos correr detras.
  final bool isActive;

  const AudioToLsbScreen({super.key, this.isActive = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(audioTranslationControllerProvider);
    final controller = ref.read(audioTranslationControllerProvider.notifier);

    return Theme(
      data: AppTheme.darkTheme,
      child: Builder(builder: (context) {
        return _buildScreen(context, state, controller);
      }),
    );
  }

  Widget _buildScreen(
    BuildContext context,
    AudioTranslationState state,
    AudioTranslationController controller,
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
      body: Stack(
        children: [
          Positioned(
            top: -100,
            left: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 50.0, sigmaY: 50.0),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.15),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 50.0, sigmaY: 50.0),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
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
                            color: AppTheme.brandPrimary.withValues(alpha: 0.18),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: Avatar3DViewer(
                          isActive: isActive,
                          isProcessing: isActive &&
                              state.status == AudioTranslationStatus.processing,
                          glosses: state.status == AudioTranslationStatus.success
                            ? (state.translationResult?.animationGlosses.isNotEmpty == true
                                ? state.translationResult?.animationGlosses
                                : state.translationResult?.glosses)
                            : null,
                          animationUrls: state.status == AudioTranslationStatus.success
                            ? state.translationResult?.animationUrls
                            : null,
                        ),
                      ),
                    ),
                  ),
                ),

                if (state.status == AudioTranslationStatus.error)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.redAccent),
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

                Container(
                  padding: const EdgeInsets.only(left: 20, right: 20, bottom: 24, top: 12),
                  child: Column(
                    children: [
                      TextInputWidget(
                        isActive: isActive,
                        onSubmit: (text) {
                          controller.processText(text);
                        },
                      ),
                      const SizedBox(height: 16),

                      if (state.status == AudioTranslationStatus.success &&
                          state.recognizedText != null &&
                          state.recognizedText!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppTheme.darkSurface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppTheme.darkBorder),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'FRASE TRADUCIDA:',
                                  style: TextStyle(
                                    color: AppTheme.brandLight,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '"${state.recognizedText}"',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),

                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          state.status == AudioTranslationStatus.recording
                              ? (state.recognizedText?.isNotEmpty == true
                                  ? '"${state.recognizedText}"'
                                  : 'Escuchando tu voz...')
                              : state.status == AudioTranslationStatus.processing
                                ? 'Traduciendo a LSB...'
                                : 'Presiona el micrófono para dictar',
                          key: ValueKey<String>('${state.status}_${state.recognizedText}'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: state.status == AudioTranslationStatus.recording
                                ? AppTheme.errorDark
                                : AppTheme.darkTextSub,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
