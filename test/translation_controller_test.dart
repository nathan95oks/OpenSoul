import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/data/services/audio_output.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/domain/repositories/translation_repository.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/controllers/translation_controller.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/translation_provider.dart';

/// Pruebas del TranslationController (TST-01).
///
/// Verifican la lógica híbrida central — la pieza con más decisiones y, hasta
/// ahora, sin cobertura: merge baseSentence/generatedText, detección de
/// degeneración, y fallback al motor local cuando el backend cae.
///
/// El audio (Polly/TTS) se inyecta como [_FakeAudioOutput] para que el test se
/// concentre en el estado (TranslationResult) sin tocar plugins nativos.

/// Repositorio falso configurable: devuelve un resultado fijo o lanza.
class _FakeRepository implements TranslationRepository {
  _FakeRepository.returns(this._result) : _error = null;
  _FakeRepository.throws(this._error) : _result = null;

  final TranslationResult? _result;
  final Object? _error;

  @override
  Future<TranslationResult> translateCards({
    required String context,
    required List<String> cards,
  }) async {
    if (_error != null) throw _error;
    return _result!;
  }
}

/// Doble de prueba de la salida de audio: registra lo invocado, no reproduce.
class _FakeAudioOutput implements AudioOutput {
  final List<String> played = [];
  final List<String> spoken = [];

  @override
  Future<void> playUrl(String url) async => played.add(url);
  @override
  Future<void> speak(String text) async => spoken.add(text);
  @override
  Future<void> stop() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
  @override
  void setOnComplete(void Function() onComplete) {}
  @override
  Future<void> dispose() async {}
}

ProviderContainer _containerWith(
  TranslationRepository repo, {
  _FakeAudioOutput? audio,
}) {
  final c = ProviderContainer(
    overrides: [
      translationRepositoryProvider.overrideWithValue(repo),
      audioOutputProvider.overrideWithValue(audio ?? _FakeAudioOutput()),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

Future<TranslationResult?> _translate(
  ProviderContainer c, {
  required String context,
  required List<String> cards,
}) async {
  await c.read(translationControllerProvider.notifier).translateCards(
        context: context,
        cards: cards,
      );
  return c.read(translationControllerProvider).value;
}

void main() {
  group('translateCards — backend sano', () {
    test('usa el generatedText remoto cuando cubre todas las glosas', () async {
      final repo = _FakeRepository.returns(TranslationResult(
        baseSentence: 'base',
        generatedText: 'Un hombre me robó el celular en la calle.',
        audioUrl: 'https://s3.test/a.mp3',
        bedrockUsed: true,
      ));
      final audio = _FakeAudioOutput();
      final c = _containerWith(repo, audio: audio);

      final result = await _translate(c,
          context: 'denuncia_robo', cards: ['HOMBRE', 'ROBAR', 'CELULAR']);

      expect(result, isNotNull);
      expect(result!.generatedText, 'Un hombre me robó el celular en la calle.');
      expect(result.audioUrl, 'https://s3.test/a.mp3');
      expect(result.bedrockUsed, true);
      // baseSentence siempre proviene del motor local (fiel a las glosas).
      expect(result.baseSentence.toLowerCase(), contains('hombre'));
      // Con audioUrl válido se reproduce el audio remoto (no TTS local).
      expect(audio.played, ['https://s3.test/a.mp3']);
      expect(audio.spoken, isEmpty);
    });
  });

  group('translateCards — backend degenerado', () {
    test('descarta el remoto y usa el motor local; sin audio remoto', () async {
      // Texto remoto degenerado: no cubre las glosas seleccionadas.
      final repo = _FakeRepository.returns(TranslationResult(
        baseSentence: 'x',
        generatedText: 'ok',
        audioUrl: 'https://s3.test/a.mp3',
        bedrockUsed: true,
      ));
      final c = _containerWith(repo);

      final result = await _translate(c,
          context: 'denuncia_robo', cards: ['HOMBRE', 'ROBAR', 'CELULAR']);

      expect(result, isNotNull);
      // Cae al motor local: oración fiel y con estructura española.
      expect(result!.generatedText.toLowerCase(), contains('robó'));
      expect(result.generatedText, isNot('ok'));
      // Al degenerar, no se reproduce audio remoto.
      expect(result.audioUrl, isNull);
      expect(result.bedrockUsed, false);
    });
  });

  group('translateCards — backend caído', () {
    test('excepción → fallback local con texto y sin audio remoto', () async {
      final repo = _FakeRepository.throws(Exception('network down'));
      final c = _containerWith(repo);

      final result = await _translate(c,
          context: 'violencia', cards: ['ESPOSO', 'PEGAR', 'MIEDO']);

      expect(result, isNotNull);
      expect(result!.generatedText.isNotEmpty, true);
      expect(result.generatedText.toLowerCase(), contains('golpeó'));
      expect(result.audioUrl, isNull);
      expect(result.bedrockUsed, false);
      // baseSentence y generatedText coinciden en el fallback puro.
      expect(result.baseSentence, result.generatedText);
    });
  });

  group('translateCards — backend sano sin audioUrl', () {
    test('mantiene el texto remoto y deja audioUrl nulo (TTS local)', () async {
      final repo = _FakeRepository.returns(TranslationResult(
        baseSentence: 'base',
        generatedText: 'Quiero renovar mi carné de identidad en el SEGIP.',
        audioUrl: null,
        bedrockUsed: true,
      ));
      final c = _containerWith(repo);

      final result = await _translate(c,
          context: 'tramite_id', cards: ['RENOVAR', 'CARNE', 'SEGIP']);

      expect(result, isNotNull);
      expect(result!.generatedText, contains('SEGIP'));
      expect(result.audioUrl, isNull);
    });
  });
}
