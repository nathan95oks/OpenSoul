import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lsb_legal_app/features/audio_to_lsb/domain/entities/lsb_translation.dart';
import 'package:lsb_legal_app/features/audio_to_lsb/domain/usecases/translate_text_usecase.dart';
import 'package:lsb_legal_app/features/audio_to_lsb/presentation/controllers/audio_translation_controller.dart';

// 1. Crear un Mock del Caso de Uso para simular su comportamiento
class MockTranslateTextUseCase extends Mock implements TranslateTextUseCase {}

void main() {
  late MockTranslateTextUseCase mockTranslateTextUseCase;
  late ProviderContainer container;

  setUp(() {
    mockTranslateTextUseCase = MockTranslateTextUseCase();
    
    // 2. Sobrescribir el proveedor de Riverpod para inyectar nuestro Mock
    container = ProviderContainer(
      overrides: [
        translateTextUseCaseProvider.overrideWithValue(mockTranslateTextUseCase),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('AudioTranslationController Tests (Pruebas Unitarias Obj. 2)', () {
    test('1. El estado inicial debe ser "idle" (en espera)', () {
      final state = container.read(audioTranslationControllerProvider);
      expect(state.status, AudioTranslationStatus.idle);
      expect(state.recognizedText, isNull);
    });

    test('2. setRecordingState debe cambiar el estado a "recording" y limpiar el texto', () {
      final controller = container.read(audioTranslationControllerProvider.notifier);
      controller.setRecordingState();
      
      final state = container.read(audioTranslationControllerProvider);
      expect(state.status, AudioTranslationStatus.recording);
      expect(state.recognizedText, "");
    });

    test('3. updateRecognizedText debe actualizar el texto dictado en vivo', () {
      final controller = container.read(audioTranslationControllerProvider.notifier);
      controller.updateRecognizedText("El juez");
      
      final state = container.read(audioTranslationControllerProvider);
      expect(state.recognizedText, "El juez");
    });

    test('4. processText debe simular una traducción exitosa y actualizar a "success"', () async {
      // Configuramos el Mock para devolver una respuesta simulada de AWS
      final expectedTranslation = LsbTranslation(glosses: ["JUEZ", "DICTAR", "AUTO"], animationUrl: "");
      when(() => mockTranslateTextUseCase.execute("El juez dictó el auto"))
          .thenAnswer((_) async => expectedTranslation);

      final controller = container.read(audioTranslationControllerProvider.notifier);
      
      // Ejecutamos el procesamiento
      controller.processText("El juez dictó el auto");

      // Verificamos el estado inmediato "processing"
      var state = container.read(audioTranslationControllerProvider);
      expect(state.status, AudioTranslationStatus.processing);

      // Esperamos el ciclo de microtareas (simulación del Future)
      await Future.delayed(Duration.zero);

      // Verificamos el estado final "success"
      state = container.read(audioTranslationControllerProvider);
      expect(state.status, AudioTranslationStatus.success);
      expect(state.translationResult?.glosses, ["JUEZ", "DICTAR", "AUTO"]);
    });

    test('5. processText debe manejar errores y actualizar a "error"', () async {
      // Configuramos el Mock para simular una caída de conexión
      when(() => mockTranslateTextUseCase.execute("Hola"))
          .thenThrow(Exception("Network Timeout error"));

      final controller = container.read(audioTranslationControllerProvider.notifier);
      controller.processText("Hola");

      // Esperamos el ciclo asíncrono
      await Future.delayed(Duration.zero);

      final state = container.read(audioTranslationControllerProvider);
      expect(state.status, AudioTranslationStatus.error);
      expect(state.errorMessage, "Exception: Network Timeout error");
    });
  });
}
