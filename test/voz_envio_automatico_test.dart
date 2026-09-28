import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lsb_legal_app/features/audio_to_lsb/presentation/widgets/text_input_widget.dart';

/// Dictar en Texto/Audio → LSB envía solo lo reconocido, sin esperar al
/// botón de enviar. Un error de reconocimiento, en cambio, nunca envía.
void main() {
  const canal = MethodChannel('plugin.csdcorp.com/speech_to_text');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(canal, (call) async {
          switch (call.method) {
            case 'has_permission':
            case 'initialize':
            case 'listen':
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
  }) async {
    final enviados = <String>[];
    await tester.pumpWidget(
      ProviderScope(
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
}
