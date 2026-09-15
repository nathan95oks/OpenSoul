import 'package:flutter_test/flutter_test.dart';
import 'package:lsb_legal_app/core/domain/entities/lsb_translation.dart';
import 'package:lsb_legal_app/core/domain/entities/semantic_message.dart';
import 'package:lsb_legal_app/core/domain/repositories/audio_translation_repository.dart';
import 'package:lsb_legal_app/core/data/repositories/caching_audio_translation_repository.dart';

/// Repositorio de prueba que cuenta cuántas veces se le pidió traducir y
/// devuelve una respuesta distinta según el sentido ya resuelto que reciba.
class _CountingRepository implements AudioTranslationRepository {
  int calls = 0;

  @override
  Future<LsbTranslation> translateText(
    String text, {
    String? situation,
    Map<String, String>? resolvedSenses,
  }) async {
    calls++;
    final sentido = resolvedSenses?['AUTO'];
    if (sentido == null) {
      return LsbTranslation(
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
    }
    return LsbTranslation(glosses: [sentido.toUpperCase()], animationUrl: '');
  }
}

void main() {
  group('CachingAudioTranslationRepository', () {
    test('no sirve desde caché el resultado de un texto distinto', () async {
      final inner = _CountingRepository();
      final repo = CachingAudioTranslationRepository(inner);

      await repo.translateText('hola');
      await repo.translateText('chau');

      expect(inner.calls, 2);
    });

    test('una aclaración pendiente no se guarda como traducción completa',
        () async {
      final inner = _CountingRepository();
      final repo = CachingAudioTranslationRepository(inner);

      final primera = await repo.translateText('traiga el auto');
      expect(primera.needsClarification, isTrue);

      // La misma frase, todavía sin resolver: no debe servirse desde caché
      // como si la pregunta pendiente fuera en sí misma la respuesta final.
      await repo.translateText('traiga el auto');
      expect(inner.calls, 2);
    });

    test('el mismo texto con sentidos resueltos distintos no comparte caché',
        () async {
      final inner = _CountingRepository();
      final repo = CachingAudioTranslationRepository(inner);

      final vehiculo = await repo.translateText('traiga el auto',
          resolvedSenses: {'AUTO': 'vehiculo'});
      final resolucion = await repo.translateText('traiga el auto',
          resolvedSenses: {'AUTO': 'resolucion'});

      expect(vehiculo.glosses, ['VEHICULO']);
      expect(resolucion.glosses, ['RESOLUCION']);
      expect(inner.calls, 2);

      // Repetir la primera combinación sí debe venir de caché.
      await repo.translateText('traiga el auto',
          resolvedSenses: {'AUTO': 'vehiculo'});
      expect(inner.calls, 2);
    });

    test('la misma frase bajo situaciones distintas no comparte caché', () async {
      final inner = _CountingRepository();
      final repo = CachingAudioTranslationRepository(inner);

      await repo.translateText('hola', situation: 'denuncia_robo');
      await repo.translateText('hola', situation: 'violencia');

      expect(inner.calls, 2);
    });
  });
}
