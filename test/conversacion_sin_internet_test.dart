import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lsb_legal_app/core/di/injection.dart';
import 'package:lsb_legal_app/features/conversation/di/conversation_bindings.dart';
import 'package:lsb_legal_app/features/conversation/presentation/providers/conversation_provider.dart';

import 'helpers/fake_audio_output.dart';
import 'helpers/official_dictionary.dart';

/// Sin internet (o con la Lambda caída, p. ej. «Fail to request
/// credentials»), lo que dicta o escribe el oyente igual llega en señas: la
/// app traduce en el teléfono.
class _SinRed extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      Future.error(const SocketException('sin red'));
}

class _LambdaSinCredenciales extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      http.StreamedResponse(
        Stream.value('{"message":"Internal server error"}'.codeUnits),
        502,
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final (nombre, cliente) in [
    ('sin internet', _SinRed()),
    ('con la Lambda fallando', _LambdaSinCredenciales()),
  ]) {
    test('$nombre, el mensaje del oyente se traduce en el teléfono', () async {
      final c = ProviderContainer(
        overrides: [
          httpClientProvider.overrideWithValue(cliente),
          lexiconRepositoryProvider.overrideWithValue(FakeLexiconRepository()),
          audioOutputProvider.overrideWithValue(FakeAudioOutput()),
          ...conversationOverrides(),
        ],
      );
      addTearDown(c.dispose);
      await c.read(lexiconEntriesProvider.future);

      await c
          .read(conversationProvider.notifier)
          .sendHearingMessage('Buenos días, ¿en qué le puedo ayudar?');
      await pumpEventQueue(times: 50);

      final estado = c.read(conversationProvider);
      final turno = estado.conversation.lastHearingTurn;
      expect(turno, isNotNull, reason: '${estado.error}');
      expect(turno!.failed, isFalse);
      expect(turno.message.glosses, containsAll(['BUENOS_DIAS', 'AYUDAR_DAR']));
      expect(turno.outputs.hasAvatar, isTrue);
    });
  }
}
