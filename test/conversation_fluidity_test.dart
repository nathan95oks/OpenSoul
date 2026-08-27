import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:lsb_legal_app/core/data/datasources/remote_audio_datasource.dart';
import 'package:lsb_legal_app/core/data/repositories/caching_audio_translation_repository.dart';
import 'package:lsb_legal_app/core/di/injection.dart';
import 'package:lsb_legal_app/core/domain/entities/lsb_translation.dart';
import 'package:lsb_legal_app/core/domain/repositories/audio_translation_repository.dart';
import 'package:lsb_legal_app/features/conversation/presentation/providers/conversation_provider.dart';

import 'helpers/official_dictionary.dart';

/// Fluidez de la conversación.
///
/// Una conversación no se mide solo por traducir bien, sino por cuánto tiempo
/// deja a alguien esperando sin poder hacer nada. Lo que se audita aquí es el
/// **camino crítico**: cuánto tarda la persona sorda en poder empezar a
/// responder desde que la oyente terminó de hablar.
///
/// Antes ese camino incluía el viaje entero a Bedrock: sin respuesta remota no
/// había turno, sin turno no había pregunta pendiente, y sin pregunta
/// pendiente el botón de tarjetas no llevaba a ninguna parte concreta.

/// Repositorio que no responde hasta que la prueba lo autoriza: permite
/// observar el estado **durante** la traducción, que es donde vive el
/// problema.
class _GatedSignRepository implements AudioTranslationRepository {
  final _gate = Completer<void>();
  int calls = 0;

  void release() => _gate.complete();

  @override
  Future<LsbTranslation> translateText(String text, {String? situation}) async {
    calls++;
    await _gate.future;
    return LsbTranslation(
      glosses: const ['TU', 'CELULAR', 'ROBAR'],
      animationUrl: '',
      animationUrls: const ['https://s3/ROBAR.glb'],
    );
  }
}

class _FailingSignRepository implements AudioTranslationRepository {
  @override
  Future<LsbTranslation> translateText(String text, {String? situation}) async {
    throw TimeoutException('sin red');
  }
}

class _CountingSignRepository implements AudioTranslationRepository {
  final List<String> received = [];

  @override
  Future<LsbTranslation> translateText(String text, {String? situation}) async {
    received.add('$text|${situation ?? ''}');
    return LsbTranslation(
      glosses: const ['ROBAR'],
      animationUrl: '',
      animationUrls: const ['https://s3/ROBAR.glb'],
    );
  }
}

Future<ProviderContainer> _containerWith(AudioTranslationRepository sign) async {
  final container = ProviderContainer(
    overrides: [
      lexiconRepositoryProvider.overrideWithValue(FakeLexiconRepository()),
      audioTranslationRepositoryProvider.overrideWithValue(sign),
    ],
  );
  addTearDown(container.dispose);
  // La inferencia de contexto se construye sobre el diccionario.
  await container.read(lexiconEntriesProvider.future);
  return container;
}

void main() {
  group('el turno del oyente no espera al backend', () {
    test('aparece en el hilo antes de que llegue la traducción', () async {
      final sign = _GatedSignRepository();
      final container = await _containerWith(sign);

      final pending = container
          .read(conversationProvider.notifier)
          .sendHearingMessage('¿Le robaron su celular?');

      // Todavía no hay respuesta remota…
      expect(sign.calls, 1);
      final conversation = container.read(conversationProvider).conversation;
      // …y el turno ya está en la conversación.
      expect(conversation.turns, hasLength(1));
      expect(conversation.turns.single.outputs.text, '¿Le robaron su celular?');
      expect(conversation.turns.single.pending, isTrue,
          reason: 'El turno debe declarar que le faltan señas por llegar.');

      sign.release();
      await pending;
    });

    test('la persona sorda ya puede responder, con el contexto inferido',
        () async {
      final sign = _GatedSignRepository();
      final container = await _containerWith(sign);

      final inFlight = container
          .read(conversationProvider.notifier)
          .sendHearingMessage('¿Le robaron su celular?');

      final conversation = container.read(conversationProvider).conversation;
      expect(conversation.pendingReply, isNotNull,
          reason: 'Sin pregunta pendiente el botón de tarjetas no sabe a qué '
              'se está respondiendo.');
      // La inferencia local sobre el texto en español basta para enrutar:
      // no hace falta esperar a las glosas del backend.
      expect(conversation.suggestedReplyContextId, 'denuncia_robo');

      sign.release();
      await inFlight;
    });

    test('la traducción completa el mismo turno, no añade otro', () async {
      final sign = _GatedSignRepository();
      final container = await _containerWith(sign);

      final inFlight = container
          .read(conversationProvider.notifier)
          .sendHearingMessage('¿Le robaron su celular?');
      final draftId =
          container.read(conversationProvider).conversation.turns.single.message.id;

      sign.release();
      await inFlight;

      final turns = container.read(conversationProvider).conversation.turns;
      expect(turns, hasLength(1), reason: 'El turno mostrado y el traducido '
          'son el mismo; duplicarlo partiría el hilo en dos.');
      expect(turns.single.message.id, draftId);
      expect(turns.single.pending, isFalse);
      expect(turns.single.message.glosses, ['TU', 'CELULAR', 'ROBAR']);
      expect(turns.single.outputs.hasAvatar, isTrue);
    });
  });

  group('si el backend cae, la conversación sigue', () {
    test('el turno se queda y se puede responder igual', () async {
      final container = await _containerWith(_FailingSignRepository());

      await container
          .read(conversationProvider.notifier)
          .sendHearingMessage('¿Le robaron su celular?');

      final state = container.read(conversationProvider);
      expect(state.error, isNotNull);
      expect(state.processing, isFalse);
      // Lo dicho se dijo: el enunciado no desaparece del hilo…
      expect(state.conversation.turns, hasLength(1));
      expect(state.conversation.turns.single.pending, isFalse);
      // …y sin red el contexto se dedujo igual, en local.
      expect(state.conversation.suggestedReplyContextId, 'denuncia_robo');
    });
  });

  group('las preguntas repetidas no vuelven a viajar', () {
    test('la segunda vez se sirve de la caché de sesión', () async {
      final inner = _CountingSignRepository();
      final repo = CachingAudioTranslationRepository(inner);

      await repo.translateText('¿Dónde ocurrió?', situation: 'denuncia_robo');
      await repo.translateText('¿Dónde ocurrió?', situation: 'denuncia_robo');
      // Mayúsculas y espacios sobrantes son la misma pregunta.
      await repo.translateText('  ¿dónde ocurrió?  ',
          situation: 'denuncia_robo');

      expect(inner.received, hasLength(1));
    });

    test('la misma frase en otra situación se vuelve a traducir', () async {
      final inner = _CountingSignRepository();
      final repo = CachingAudioTranslationRepository(inner);

      await repo.translateText('¿Qué pasó?', situation: 'denuncia_robo');
      await repo.translateText('¿Qué pasó?', situation: 'violencia');

      expect(inner.received, hasLength(2),
          reason: 'Servir una situación por otra devolvería la traducción de '
              'otra conversación.');
    });

    test('una traducción vacía no se recuerda', () async {
      var calls = 0;
      final repo = CachingAudioTranslationRepository(_EmptyThenFull(() => calls++));

      final first = await repo.translateText('Buenos días');
      expect(first.glosses, isEmpty);
      final second = await repo.translateText('Buenos días');

      expect(second.glosses, isNotEmpty,
          reason: 'Cachear un fallo del modelo lo congelaría toda la sesión.');
      expect(calls, 2);
    });
  });

  group('una petición colgada no bloquea la conversación', () {
    test('el datasource de señas corta por timeout', () async {
      final client = MockClient((_) async {
        // Más lenta que el tope: simula red caída sin cerrar la conexión.
        await Future<void>.delayed(
            RemoteAudioDataSourceImpl.requestTimeout * 2);
        return http.Response('{}', 200);
      });
      final datasource = RemoteAudioDataSourceImpl(
        apiGatewayUrl: 'https://example.test/OpenSoul-TextToLSB',
        client: client,
      );

      await expectLater(
        datasource.translateText('¿Le robaron su celular?'),
        throwsA(isA<Exception>()),
      );
    }, timeout: const Timeout(Duration(seconds: 60)));
  });
}

/// Devuelve una traducción vacía la primera vez y una útil después.
class _EmptyThenFull implements AudioTranslationRepository {
  final void Function() onCall;
  bool _served = false;

  _EmptyThenFull(this.onCall);

  @override
  Future<LsbTranslation> translateText(String text, {String? situation}) async {
    onCall();
    if (!_served) {
      _served = true;
      return LsbTranslation(glosses: const [], animationUrl: '');
    }
    return LsbTranslation(glosses: const ['HOLA'], animationUrl: '');
  }
}
