import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lsb_legal_app/core/domain/entities/lsb_translation.dart';
import 'package:lsb_legal_app/core/domain/entities/semantic_message.dart';
import 'package:lsb_legal_app/features/audio_to_lsb/domain/usecases/translate_text_usecase.dart';
import 'package:lsb_legal_app/features/audio_to_lsb/di/injection.dart';
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

    test(
        '6. una traducción con aclaración pendiente bloquea en needsClarification '
        'y no muestra un resultado reproducible', () async {
      final pendiente = LsbTranslation(
        glosses: const [],
        animationUrl: '',
        semanticStatus: SemanticStatus.needsClarification,
        pendingClarifications: const [
          PendingClarification(
            term: 'AUTO',
            question: '¿Vehículo o resolución?',
            options: [
              ClarificationOption(id: 'vehiculo', label: 'Vehículo'),
              ClarificationOption(id: 'resolucion', label: 'Resolución'),
            ],
          ),
        ],
      );
      when(() => mockTranslateTextUseCase.execute('Traiga el auto'))
          .thenAnswer((_) async => pendiente);

      final controller = container.read(audioTranslationControllerProvider.notifier);
      controller.processText('Traiga el auto');
      await Future.delayed(Duration.zero);

      final state = container.read(audioTranslationControllerProvider);
      expect(state.status, AudioTranslationStatus.needsClarification);
      expect(state.pendingClarifications.single.term, 'AUTO');
      expect(state.translationResult, isNull,
          reason: 'no debe haber resultado reproducible mientras hay una '
              'aclaración pendiente');
    });

    test(
        '7. resolveClarification reenvía la frase completa con el sentido '
        'elegido y pasa a success', () async {
      final pendiente = LsbTranslation(
        glosses: const [],
        animationUrl: '',
        semanticStatus: SemanticStatus.needsClarification,
        pendingClarifications: const [
          PendingClarification(
            term: 'AUTO',
            question: '¿Vehículo o resolución?',
            options: [ClarificationOption(id: 'vehiculo', label: 'Vehículo')],
          ),
        ],
      );
      final resuelto = LsbTranslation(glosses: const ['RESOLUCION'], animationUrl: '');

      when(() => mockTranslateTextUseCase.execute('Traiga el auto'))
          .thenAnswer((_) async => pendiente);
      when(() => mockTranslateTextUseCase.execute('Traiga el auto',
              resolvedSenses: {'AUTO': 'resolucion'}))
          .thenAnswer((_) async => resuelto);

      final controller = container.read(audioTranslationControllerProvider.notifier);
      controller.processText('Traiga el auto');
      await Future.delayed(Duration.zero);
      expect(container.read(audioTranslationControllerProvider).status,
          AudioTranslationStatus.needsClarification);

      controller.resolveClarification('AUTO', 'resolucion');
      await Future.delayed(Duration.zero);

      final state = container.read(audioTranslationControllerProvider);
      expect(state.status, AudioTranslationStatus.success);
      expect(state.translationResult?.glosses, ['RESOLUCION']);
      expect(state.pendingClarifications, isEmpty);
    });

    test('8. una respuesta de una solicitud ya superada no sobrescribe un reinicio',
        () async {
      when(() => mockTranslateTextUseCase.execute('primera frase'))
          .thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 20));
        return LsbTranslation(glosses: const ['UNO'], animationUrl: '');
      });

      final controller = container.read(audioTranslationControllerProvider.notifier);
      controller.processText('primera frase');
      controller.reset(); // la persona reinicia mientras la respuesta viaja.

      await Future.delayed(const Duration(milliseconds: 40));

      final state = container.read(audioTranslationControllerProvider);
      expect(state.status, AudioTranslationStatus.idle,
          reason: 'la respuesta tardía no debe reactivar un estado ya '
              'reiniciado');
      expect(state.translationResult, isNull);
    });

    test('9. errorMessage se limpia realmente al reiniciar', () async {
      when(() => mockTranslateTextUseCase.execute('falla'))
          .thenThrow(Exception('boom'));
      final controller = container.read(audioTranslationControllerProvider.notifier);
      controller.processText('falla');
      await Future.delayed(Duration.zero);
      expect(container.read(audioTranslationControllerProvider).errorMessage,
          isNotNull);

      controller.reset();

      expect(container.read(audioTranslationControllerProvider).errorMessage, isNull);
      expect(container.read(audioTranslationControllerProvider).status,
          AudioTranslationStatus.idle);
    });
  });
}
