import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'package:lsb_legal_app/core/domain/services/animation_url_resolver.dart';
import 'package:lsb_legal_app/features/conversation/presentation/widgets/avatar_playback_sheet.dart';

import 'support/fake_webview_platform.dart';

void main() {
  WebViewPlatform.instance = FakeWebViewPlatform();

  testWidgets(
    'Conversación cierra el avatar después de cada secuencia, aunque sea corta',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  key: const Key('mostrar_avatar_conversacion'),
                  onPressed: () => AvatarPlaybackSheet.show(
                    context,
                    glosses: const ['HOLA'],
                    animationUrls: const [
                      '${AnimationUrlResolver.placeholderScheme}HOLA',
                    ],
                    animationDuration: const Duration(milliseconds: 200),
                  ),
                  child: const Text('Enviar mensaje'),
                ),
              ),
            ),
          ),
        ),
      );

      for (var turn = 0; turn < 2; turn++) {
        await tester.tap(find.byKey(const Key('mostrar_avatar_conversacion')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.byType(AvatarPlaybackSheet), findsOneWidget);

        await tester.pump(const Duration(milliseconds: 200));
        await tester.pump(AvatarPlaybackSheet.dismissDelay);
        await tester.pumpAndSettle();

        expect(
          find.byType(AvatarPlaybackSheet),
          findsNothing,
          reason: 'el turno $turn debe devolver siempre la pantalla del chat',
        );
        expect(find.text('Enviar mensaje'), findsOneWidget);
      }
    },
  );

  testWidgets(
    'dos palabras deletreadas seguidas se ven por separado y «Siguiente» '
    'pasa a la palabra que sigue, no a la letra',
    (tester) async {
      const palabras = ['PERSONA', 'DESCRIBIR'];
      final letras = palabras.expand((p) => p.split('')).toList();
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  key: const Key('mostrar_avatar_conversacion'),
                  onPressed: () => AvatarPlaybackSheet.show(
                    context,
                    glosses: letras,
                    animationUrls: [
                      for (final l in letras)
                        '${AnimationUrlResolver.placeholderScheme}$l',
                    ],
                    spelledWords: palabras,
                    autoDismissOnFinish: false,
                    animationDuration: const Duration(seconds: 30),
                  ),
                  child: const Text('Describir persona'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('mostrar_avatar_conversacion')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // La primera palabra, sola: ni una letra de la segunda en la franja.
      expect(find.byKey(const Key('avatar_deletreo_ayuda')), findsOneWidget);
      expect(find.text('PERSONA'), findsOneWidget);
      expect(find.text('DESCRIBIR'), findsNothing);
      final primera = tester.widgetList<Text>(
        find.descendant(
          of: find.byKey(const Key('avatar_deletreo_letras')),
          matching: find.byType(Text),
        ),
      );
      expect(primera.map((t) => t.data).join(), 'PERSONA');

      await tester.tap(find.text('Siguiente'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // Pasó a la segunda palabra entera, no a la letra R.
      expect(find.text('DESCRIBIR'), findsOneWidget);
      expect(find.text('PERSONA'), findsNothing);
      final segunda = tester.widgetList<Text>(
        find.descendant(
          of: find.byKey(const Key('avatar_deletreo_letras')),
          matching: find.byType(Text),
        ),
      );
      // Una palabra larga se ve por tramos («DESCRIB…»), nunca mezclada con la
      // anterior.
      expect(segunda.map((t) => t.data).join(), startsWith('DESCRIB'));
    },
  );
}
