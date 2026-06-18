import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui';
import '../../../../app/theme.dart';
import '../controllers/audio_translation_controller.dart';
import '../widgets/avatar_3d_viewer.dart';
import '../widgets/record_button.dart';
import '../widgets/text_input_widget.dart';

class AudioToLsbScreen extends ConsumerWidget {
  const AudioToLsbScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(audioTranslationControllerProvider);
    final controller = ref.read(audioTranslationControllerProvider.notifier);

    // El módulo Audio/Texto → LSB usa el tema oscuro del design system.
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
        title: const Text(
          'Traductor a LSB',
          style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.5),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Background Decor (Gradients)
          Positioned(
            top: -100,
            left: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
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
                color: Theme.of(context).colorScheme.secondary.withOpacity(0.15),
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
                // 3D Avatar Area
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                    child: Container(
                      decoration: BoxDecoration(
                        // Halo/glow azul sutil detrás del avatar para destacarlo.
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
                          isProcessing: state.status == AudioTranslationStatus.processing,
                          glosses: state.status == AudioTranslationStatus.success 
                            ? state.translationResult?.glosses 
                            : null,
                          animationUrls: state.status == AudioTranslationStatus.success
                            ? state.translationResult?.animationUrls
                            : null,
                        ),
                      ),
                    ),
                  ),
                ),
                
                // Status or Error Messages
                if (state.status == AudioTranslationStatus.error)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
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

                // Input Area (Text & Audio)
                Container(
                  padding: const EdgeInsets.only(left: 20, right: 20, bottom: 24, top: 12),
                  child: Column(
                    children: [
                      // Text Input Field
                      TextInputWidget(
                        onSubmit: (text) {
                          controller.processText(text);
                        },
                      ),
                      const SizedBox(height: 24),
                      
                      // Status Text
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          state.status == AudioTranslationStatus.recording
                              ? (state.recognizedText?.isNotEmpty == true 
                                  ? '"${state.recognizedText}"' 
                                  : 'Escuchando tu voz...')
                              : state.status == AudioTranslationStatus.processing
                                ? 'Traduciendo a LSB...'
                                : 'Mantén presionado para dictar',
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
                      const SizedBox(height: 16),
                      
                      // Record Button
                      RecordButton(
                        onStartRecording: () {
                          controller.setRecordingState();
                        },
                        onTextRecognized: (text) {
                          controller.updateRecognizedText(text);
                        },
                        onStopRecording: (transcribedText) {
                          controller.processAudioAsText(transcribedText);
                        },
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
