import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lsb_legal_app/app/screens/main_navigation_screen.dart';
import 'package:lsb_legal_app/app/screens/splash_screen.dart';
import 'package:lsb_legal_app/app/app.dart';
import 'package:lsb_legal_app/features/conversation/presentation/screens/conversation_screen.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'support/fake_webview_platform.dart';

void main() {
  // La pantalla de conversación incluye el avatar 3D, que crea un
  // WebViewController real en initState. Sin un WebViewPlatform registrado,
  // pumpWidget revienta con una aserción ajena a lo que esta prueba verifica.
  WebViewPlatform.instance = FakeWebViewPlatform();

  // `appRouter` es global y conserva la ruta entre pruebas del mismo
  // archivo: solo la primera arranca en el splash.
  Future<void> arrancar(WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: AppScope()));
    // Se deja correr el temporizador del splash y se asienta la carga de la
    // configuración del dispositivo, que es asíncrona.
    await tester.pump(const Duration(seconds: 3));
    // `pumpAndSettle` no sirve aquí: el campo de voz y el visor del avatar
    // tienen animaciones que se repiten, así que nunca queda todo quieto.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('sin modo guardado, del splash se entra directo a la navegación',
      (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const ProviderScope(child: AppScope()));
    expect(find.byType(SplashScreen), findsOneWidget,
        reason: 'La app arranca en el splash.');
    await tester.pump(const Duration(seconds: 3));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.byType(MainNavigationScreen), findsOneWidget,
        reason: 'Ya no hay pantalla para elegir entre personal y ventanilla.');
  });

  testWidgets('con modo ya elegido, se entra directo a la navegación',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'device_config_v1': jsonEncode({
        'schemaVersion': 1,
        'mode': 'personal',
        'lastTabId': 'conversation',
      }),
    });

    await arrancar(tester);

    expect(find.byType(MainNavigationScreen), findsOneWidget);
    // La pestaña por defecto es la Conversación, en el centro de la barra.
    // (IndexedStack es lazy: las demás se construyen al visitarlas.)
    expect(find.byType(ConversationScreen), findsOneWidget);
  });

  testWidgets('la barra inferior tiene Conversación en el centro',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'device_config_v1': jsonEncode({'schemaVersion': 1, 'mode': 'personal'}),
    });

    await arrancar(tester);

    expect(find.text('Tarjetas LSB'), findsOneWidget);
    expect(find.text('Conversación'), findsOneWidget);
    expect(find.text('Voz a LSB'), findsOneWidget);

    // Posición real en pantalla, no el orden del enum.
    final x = <String, double>{
      for (final etiqueta in ['Tarjetas LSB', 'Conversación', 'Voz a LSB'])
        etiqueta: tester.getCenter(find.text(etiqueta)).dx,
    };
    expect(x['Tarjetas LSB']!, lessThan(x['Conversación']!));
    expect(x['Conversación']!, lessThan(x['Voz a LSB']!));
  });
}
