import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lsb_legal_app/features/audio_to_lsb/presentation/controllers/audio_translation_controller.dart';
import 'package:lsb_legal_app/features/audio_to_lsb/presentation/widgets/text_input_widget.dart';

/// Dictar en Texto/Audio → LSB envía solo lo reconocido, sin esperar al
/// botón de enviar. Un error de reconocimiento, en cambio, nunca envía.
void main() {
  const canal = MethodChannel('plugin.csdcorp.com/speech_to_text');
  // Lo que la app le pidió al motor al escuchar (p. ej. `onDevice`).
  final escuchas = <Map<Object?, Object?>>[];

  setUp(() {
    escuchas.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(canal, (call) async {
          switch (call.method) {
            case 'listen':
              escuchas.add(
                Map<Object?, Object?>.from(call.arguments as Map? ?? {}),
              );
              return true;
            case 'has_permission':
            case 'initialize':
              return true;
            case 'locales':
              return <String>['es_BO:Español (Bolivia)'];
            default:
              return null;
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(canal, null);
  });

  // El ícono de grabar late sin parar: se avanza el reloj a mano.
  Future<void> avanzar(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  // El motor de voz deja temporizadores propios (fin de escucha): se
  // desmonta y se deja correr el reloj antes de cerrar la prueba.
  Future<void> cerrar(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 1));
  }

  /// El motor de voz le habla a la app por el mismo canal.
  Future<void> delMotor(WidgetTester tester, String metodo, Object args) async {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      canal.name,
      const StandardMethodCodec().encodeMethodCall(MethodCall(metodo, args)),
      (_) {},
    );
    await avanzar(tester);
  }

  Future<void> oir(WidgetTester tester, String palabras) => delMotor(
    tester,
    'textRecognition',
    jsonEncode({
      'alternates': [
        {'recognizedWords': palabras, 'confidence': 0.9},
      ],
      'resultType': 2, // final
    }),
  );

  Future<List<String>> montar(
    WidgetTester tester, {
    required bool automatico,
    bool conInternet = true,
  }) async {
    final enviados = <String>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          internetProbeProvider.overrideWithValue(() async => conInternet),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: TextInputWidget(
              onSubmit: enviados.add,
              sendSpeechAutomatically: automatico,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Grabar voz'));
    await avanzar(tester);
    expect(find.byTooltip('Detener grabación'), findsOneWidget);
    return enviados;
  }

  testWidgets('al terminar de oír, lo dictado se envía solo', (tester) async {
    final enviados = await montar(tester, automatico: true);
    await oir(tester, 'buenos días necesito su carnet');
    expect(enviados, isEmpty, reason: 'todavía está escuchando');

    await delMotor(tester, 'notifyStatus', 'done');
    expect(enviados, ['buenos días necesito su carnet']);
    // El campo queda limpio y el micrófono listo para otra frase.
    expect(find.text('buenos días necesito su carnet'), findsNothing);
    expect(find.byTooltip('Grabar voz'), findsOneWidget);
    await cerrar(tester);
  });

  testWidgets('detener con el botón también envía', (tester) async {
    final enviados = await montar(tester, automatico: true);
    await oir(tester, 'pase a la ventanilla cuatro');
    await tester.tap(find.byTooltip('Detener grabación'));
    await avanzar(tester);
    expect(enviados, ['pase a la ventanilla cuatro']);
    await cerrar(tester);
  });

  testWidgets('detener con el botón y el aviso de fin del motor envían una '
      'sola vez, sin un audio vacío detrás', (tester) async {
    final enviados = await montar(tester, automatico: true);
    // Un resultado parcial: al detener se espera el final, y en esa espera
    // el motor avisa de que terminó de oír.
    await delMotor(
      tester,
      'textRecognition',
      jsonEncode({
        'alternates': [
          {'recognizedWords': 'quiero hacer un trámite', 'confidence': 0.9},
        ],
        'resultType': 1,
      }),
    );
    await tester.tap(find.byTooltip('Detener grabación'));
    await tester.pump(const Duration(milliseconds: 10));
    await delMotor(tester, 'notifyStatus', 'done');
    await avanzar(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(enviados, ['quiero hacer un trámite']);
    // Un segundo «detener» con el campo ya vacío mandaría un audio vacío, que
    // devuelve el traductor a «idle» y cancela lo recién enviado.
    final contenedor = ProviderScope.containerOf(
      tester.element(find.byType(TextInputWidget)),
    );
    expect(
      contenedor.read(audioTranslationControllerProvider).status,
      isNot(AudioTranslationStatus.idle),
    );
    await cerrar(tester);
  });

  testWidgets('un error de reconocimiento no envía: queda para revisar', (
    tester,
  ) async {
    final enviados = await montar(tester, automatico: true);
    await oir(tester, 'pase a la venta');
    await delMotor(
      tester,
      'notifyError',
      jsonEncode({'errorMsg': 'error_network', 'permanent': true}),
    );
    expect(enviados, isEmpty);
    expect(find.text('pase a la venta'), findsOneWidget);
    await cerrar(tester);
  });

  testWidgets('sin envío automático, espera al botón de enviar', (
    tester,
  ) async {
    final enviados = await montar(tester, automatico: false);
    await oir(tester, 'buenos días');
    await delMotor(tester, 'notifyStatus', 'done');
    expect(enviados, isEmpty);
    expect(find.text('buenos días'), findsOneWidget);

    await tester.tap(find.byTooltip('Enviar mensaje'));
    await avanzar(tester);
    expect(enviados, ['buenos días']);
    await cerrar(tester);
  });

  testWidgets('tras dictar en otro campo, el aviso de fin llega a este', (
    tester,
  ) async {
    // El motor es uno solo para toda la app: primero se dicta en otro
    // campo (como el de Conversación)…
    await montar(tester, automatico: false);
    await delMotor(tester, 'notifyStatus', 'done');
    await tester.pumpWidget(const SizedBox());

    // …y luego en Texto/Audio → LSB, que tiene que enterarse de que terminó.
    final enviados = await montar(tester, automatico: true);
    await oir(tester, 'su número de caso');
    await delMotor(tester, 'notifyStatus', 'done');
    expect(enviados, ['su número de caso']);
    await cerrar(tester);
  });

  testWidgets('lo dictado llega como voz, no como texto escrito', (
    tester,
  ) async {
    final escritos = <String>[];
    final dictados = <String>[];
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: TextInputWidget(
              onSubmit: escritos.add,
              onSpeechSubmit: dictados.add,
              sendSpeechAutomatically: true,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Grabar voz'));
    await avanzar(tester);
    await oir(tester, 'tome asiento por favor');
    await delMotor(tester, 'notifyStatus', 'done');
    expect(dictados, ['tome asiento por favor']);
    expect(escritos, isEmpty);
    await cerrar(tester);
  });

  test('Conversación y Texto/Audio → LSB envían solos lo dictado', () {
    for (final pantalla in const [
      'lib/features/conversation/presentation/screens/conversation_screen.dart',
      'lib/features/audio_to_lsb/presentation/screens/audio_to_lsb_screen.dart',
    ]) {
      expect(
        File(pantalla).readAsStringSync(),
        contains('sendSpeechAutomatically: true'),
        reason: pantalla,
      );
    }
  });

  group('sin internet', () {
    testWidgets('con internet se usa el reconocimiento normal', (tester) async {
      await montar(tester, automatico: true);
      expect(escuchas.single['onDevice'], isFalse);
      await cerrar(tester);
    });

    testWidgets('sin internet se intenta reconocer en el propio teléfono', (
      tester,
    ) async {
      final enviados = await montar(
        tester,
        automatico: true,
        conInternet: false,
      );
      expect(escuchas.single['onDevice'], isTrue);
      // Si el teléfono reconoce sin red, se envía como siempre.
      await oir(tester, 'necesito ayuda');
      await delMotor(tester, 'notifyStatus', 'done');
      expect(enviados, ['necesito ayuda']);
      await cerrar(tester);
    });

    testWidgets('si no puede reconocer sin internet, pide conectarse', (
      tester,
    ) async {
      final enviados = await montar(
        tester,
        automatico: true,
        conInternet: false,
      );
      await delMotor(
        tester,
        'notifyError',
        jsonEncode({'errorMsg': 'error_network', 'permanent': true}),
      );
      expect(enviados, isEmpty);
      expect(find.text(sinInternetParaDictar), findsOneWidget);
      expect(find.byTooltip('Grabar voz'), findsOneWidget);
      await cerrar(tester);
    });

    testWidgets('con internet que se corta a mitad, también lo dice', (
      tester,
    ) async {
      await montar(tester, automatico: true);
      await delMotor(
        tester,
        'notifyError',
        jsonEncode({'errorMsg': 'error_network_timeout', 'permanent': true}),
      );
      expect(find.text(sinInternetParaDictar), findsOneWidget);
      await cerrar(tester);
    });
  });
}
