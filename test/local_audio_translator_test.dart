import 'package:flutter_test/flutter_test.dart';
import 'package:lsb_legal_app/core/data/repositories/caching_audio_translation_repository.dart';
import 'package:lsb_legal_app/core/domain/entities/lsb_translation.dart';
import 'package:lsb_legal_app/core/domain/repositories/audio_translation_repository.dart';

class FailingAudioTranslationRepository implements AudioTranslationRepository {
  @override
  Future<LsbTranslation> translateText(
    String text, {
    String? situation,
    Map<String, String>? resolvedSenses,
  }) async {
    throw Exception('SocketException: No internet connection (Modo Avión)');
  }
}

void main() {
  test('Modo sin conexión: traduce localmente usando las 200 señas del avatar si AWS falla', () async {
    final repo = CachingAudioTranslationRepository(
      FailingAudioTranslationRepository(),
    );

    // Frase típica del funcionario oyente
    final result = await repo.translateText('Buenos días, ¿en qué le puedo ayudar?');

    expect(result.glosses, isNotEmpty);
    expect(result.animationUrls, isNotEmpty);
    expect(result.animationGlosses, contains('BUENOS_DIAS'));
    expect(result.animationGlosses, contains('AYUDAR_DAR'));
  });

  test('Modo sin conexión: reconoce señas nuevas como CONTINUAR o ABRIR', () async {
    final repo = CachingAudioTranslationRepository(
      FailingAudioTranslationRepository(),
    );

    final result = await repo.translateText('Continuar');

    expect(result.glosses, contains('CONTINUAR'));
    expect(result.animationGlosses, contains('CONTINUAR'));
  });

  test('Modo sin conexión: conserva la Ñ al deletrear y al buscar señas con Ñ', () async {
    final repo = CachingAudioTranslationRepository(
      FailingAudioTranslationRepository(),
    );

    final deletreo = await repo.translateText('ñandu');
    expect(deletreo.glosses, ['ÑANDU']);
    expect(deletreo.animationGlosses, ['Ñ', 'A', 'N', 'D', 'U']);

    final manana = await repo.translateText('mañana');
    expect(manana.animationGlosses, ['MANANA']);

    final dano = await repo.translateText('engañar y dañar');
    expect(dano.animationGlosses, containsAll(['ENGANAR', 'DANAR']));
  });
}
