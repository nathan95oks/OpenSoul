import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/audio_translation_controller.dart';
import '../widgets/avatar_3d_viewer.dart';
import '../widgets/record_button.dart';

class AudioToLsbScreen extends ConsumerWidget {
  const AudioToLsbScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(audioTranslationControllerProvider);
    final controller = ref.read(audioTranslationControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Audio a Lenguaje de Señas'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Avatar3DViewer(
                isProcessing: state.status == AudioTranslationStatus.processing,
                glosses: state.status == AudioTranslationStatus.success 
                  ? state.translationResult?.glosses 
                  : null,
              ),
              const SizedBox(height: 48),
              if (state.status == AudioTranslationStatus.error)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    state.errorMessage ?? 'Ocurrió un error',
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              const Spacer(),
              Text(
                state.status == AudioTranslationStatus.recording
                    ? 'Escuchando...'
                    : 'Toca para grabar',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 24),
              RecordButton(
                onStartRecording: () {
                  controller.setRecordingState();
                },
                onStopRecording: (audioPath) async {
                  controller.processAudio(audioPath);
                },
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
