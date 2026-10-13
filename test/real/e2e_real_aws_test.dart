import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:lsb_legal_app/core/data/datasources/remote_audio_datasource.dart';
import 'package:lsb_legal_app/core/data/datasources/remote_translation_datasource.dart';

const _run = bool.fromEnvironment('RUN_REAL_E2E');
const _textoUrl = String.fromEnvironment('LSB_TEXT_API_URL');
const _apiUrl = String.fromEnvironment('LSB_API_URL');
const _outPath = String.fromEnvironment('E2E_OUT');

final _filas = <Map<String, dynamic>>[];

Future<void> _caso(
  String id,
  String descripcion,
  Future<Map<String, dynamic>> Function() cuerpo,
) async {
  final sw = Stopwatch()..start();
  var fila = <String, dynamic>{'id': id, 'descripcion': descripcion};
  try {
    fila = {...fila, ...await cuerpo(), 'resultado': 'respuesta'};
  } catch (e) {
    fila['resultado'] = 'error';
    fila['error'] = '$e'.replaceAll(RegExp(r'https?://[^\s"]+'), '<url>');
  }
  sw.stop();
  fila['ms'] = sw.elapsedMilliseconds;
  _filas.add(fila);
  debugPrint('E2E|${jsonEncode(fila)}', wrapWidth: 100000);
}

Future<Map<String, dynamic>> _audio(String? url, http.Client c) async {
  if (url == null || url.isEmpty) return {'audio': 'sin url'};
  final r = await c.get(Uri.parse(url));
  return {
    'audioHttp': r.statusCode,
    'audioTipo': r.headers['content-type'],
    'audioBytes': r.bodyBytes.length,
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;

  tearDownAll(() {
    final resumen = {
      'fecha': DateTime.now().toUtc().toIso8601String(),
      'dart': Platform.version.split(' ').first,
      'so': Platform.operatingSystem,
      'casos': _filas,
    };
    if (_outPath.isNotEmpty) {
      File(_outPath)
        ..createSync(recursive: true)
        ..writeAsStringSync(const JsonEncoder.withIndent('  ').convert(resumen));
    }
  });

  group(
    'Extremo a extremo con AWS real',
    skip: _run ? false : 'Requiere --dart-define=RUN_REAL_E2E=true y las URL reales',
    () {
      final client = http.Client();
      final texto = RemoteAudioDataSourceImpl(client: client, apiGatewayUrl: _textoUrl);
      final tarjetas = RemoteTranslationDataSourceImpl(client: client, apiGatewayUrl: _apiUrl);

      test('configuración presente', () {
        expect(_textoUrl, startsWith('https://'));
        expect(_apiUrl, startsWith('https://'));
      });

      test('R1 a R5: español a LSB (TextToLSB)', () async {
        await _caso('R1', 'ES a LSB: pregunta simple', () async {
          final t = await texto.translateText('¿Cuál es su nombre?');
          return {'glosas': t.glosses, 'estado': t.semanticStatus.name, 'representacion': t.representationStatus.name};
        });
        await _caso('R2', 'ES a LSB: misma frase (debe salir de caché)', () async {
          final t = await texto.translateText('¿Cuál es su nombre?');
          return {'glosas': t.glosses, 'estado': t.semanticStatus.name};
        });
        await _caso('R3', 'ES a LSB: sigla FELCC (deletreo)', () async {
          final t = await texto.translateText('Debe ir a la FELCC.');
          return {'glosas': t.glosses, 'deletreadas': t.spelledWords.length, 'representacion': t.representationStatus.name};
        });
        await _caso('R4', 'ES a LSB: término ambiguo "auto" sin pista', () async {
          final t = await texto.translateText('Traiga el auto mañana.');
          return {'glosas': t.glosses, 'estado': t.semanticStatus.name, 'aclaraciones': t.pendingClarifications.length};
        });
        final fraseUnica = 'Su cita es mañana a las ${DateTime.now().toUtc().microsecondsSinceEpoch}.';
        await _caso('R10', 'ES a LSB: frase nueva (sin caché)', () async {
          final t = await texto.translateText(fraseUnica);
          return {'glosas': t.glosses, 'estado': t.semanticStatus.name, 'representacion': t.representationStatus.name};
        });
        await _caso('R5', 'ES a LSB: más de 1000 caracteres (debe rechazarse)', () async {
          final t = await texto.translateText('a' * 1100);
          return {'glosas': t.glosses};
        });
        expect(_filas.where((f) => f['resultado'] == 'respuesta').length, greaterThanOrEqualTo(3));
      });

      test('R6 a R9: LSB a español y audio (translate)', () async {
        final base = jsonDecode(File('test/fixtures/contract/solo_perder.json').readAsStringSync()) as Map<String, dynamic>;
        final viol = jsonDecode(File('test/fixtures/contract/violencia_estructurada.json').readAsStringSync()) as Map<String, dynamic>;
        Future<Map<String, dynamic>> enviar(Map<String, dynamic> fx) async {
          final r = await tarjetas.translateCards(
            context: fx['context'] as String,
            cards: List<String>.from(fx['cards'] as List),
            declaration: Map<String, dynamic>.from(fx['declaration'] as Map),
            speechAct: fx['speechAct'] as String?,
          );
          return {
            'texto': r.generatedText,
            'bedrockUsado': r.bedrockUsed,
            'cobertura': r.coverageValidated,
            'cacheHit': r.cacheHit,
            ...await _audio(r.audioUrl, client),
          };
        }

        await _caso('R6', 'LSB a ES: perder celular (primera vez)', () => enviar(base));
        await _caso('R7', 'LSB a ES: misma declaración (debe salir de caché)', () => enviar(base));
        await _caso('R8', 'LSB a ES: violencia estructurada', () => enviar(viol));
        await _caso('R9', 'LSB a ES: sin tarjetas (debe rechazarse)', () async {
          final r = await tarjetas.translateCards(context: 'denuncia_robo', cards: const []);
          return {'texto': r.generatedText};
        });
        final marca = DateTime.now().toUtc().microsecondsSinceEpoch.toString();
        final unico = jsonDecode(
          File('test/fixtures/contract/solo_perder.json')
              .readAsStringSync()
              .replaceAll('CELULAR', 'MOCHILA'),
        ) as Map<String, dynamic>;
        (unico['declaration'] as Map<String, dynamic>)['notaPrueba'] = marca;
        await _caso('R11', 'LSB a ES: perder mochila (entrada nueva, sin caché)', () => enviar(unico));
        await _caso('R12', 'LSB a ES: perder mochila otra vez (con caché)', () => enviar(unico));
        expect(_filas.any((f) => f['id'] == 'R6' && f['resultado'] == 'respuesta'), isTrue);
      });
    },
  );
}
