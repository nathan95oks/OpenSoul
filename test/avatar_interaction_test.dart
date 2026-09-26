import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'package:lsb_legal_app/core/presentation/widgets/avatar_3d_viewer.dart';
import 'package:lsb_legal_app/core/domain/services/animation_url_resolver.dart';
import 'package:lsb_legal_app/features/audio_to_lsb/presentation/widgets/text_input_widget.dart';

import 'support/fake_webview_platform.dart';

void main() {
  WebViewPlatform.instance = FakeWebViewPlatform();

  testWidgets('el avatar expandido ocupa todo el alto disponible', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox.expand(
              child: Avatar3DViewer(
                isActive: false,
                isProcessing: false,
                expandToFit: true,
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byType(Avatar3DViewer)).height, 600);
  });

  testWidgets('enviar texto quita el foco y cierra el campo', (tester) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);
    String? submitted;
    final composing = <bool>[];

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: TextInputWidget(
              focusNode: focusNode,
              onSubmit: (text) => submitted = text,
              onComposingChanged: composing.add,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);

    await tester.enterText(find.byType(TextField), 'Necesito ayuda');
    expect(composing.last, isTrue);
    await tester.tap(find.byTooltip('Enviar mensaje'));
    await tester.pump();

    expect(submitted, 'Necesito ayuda');
    expect(focusNode.hasFocus, isFalse);
    expect(find.text('Necesito ayuda'), findsNothing);
    expect(composing.last, isFalse);
  });

  testWidgets('volver espera el fin de la sena y solicita el estado inicial', (
    tester,
  ) async {
    var returned = false;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Avatar3DViewer(
              isProcessing: false,
              glosses: const ['HOLA'],
              animationUrls: const [
                '${AnimationUrlResolver.placeholderScheme}HOLA',
              ],
              animationDuration: const Duration(milliseconds: 1),
              onReturnToInput: () => returned = true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byTooltip('Volver a escribir'), findsOneWidget);
    expect(find.byTooltip('Volver a hacer la seña'), findsOneWidget);

    await tester.tap(find.byTooltip('Volver a escribir'));
    await tester.pump();

    expect(returned, isFalse, reason: 'No debe cortar el clip en seco.');
    await tester.pump(const Duration(milliseconds: 5));

    expect(returned, isTrue);
    await tester.pump(const Duration(milliseconds: 450));
    expect(find.byTooltip('Volver a escribir'), findsNothing);
  });

  testWidgets('una solicitud repetida vuelve a iniciar la misma sena', (
    tester,
  ) async {
    const urls = ['${AnimationUrlResolver.placeholderScheme}HOLA'];
    const glosses = ['HOLA'];
    final playbackEvents = <bool>[];

    Widget viewer({
      required int requestId,
      required bool processing,
      List<String>? animationUrls,
      List<String>? animationGlosses,
    }) {
      return ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Avatar3DViewer(
              isProcessing: processing,
              isUserComposing: true,
              animationDuration: const Duration(milliseconds: 1),
              playbackRequestId: requestId,
              animationUrls: animationUrls,
              glosses: animationGlosses,
              onPlaybackStateChanged: playbackEvents.add,
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(
      viewer(
        requestId: 1,
        processing: false,
        animationUrls: urls,
        animationGlosses: glosses,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 5));
    expect(playbackEvents.where((event) => event), hasLength(1));
    expect(playbackEvents.last, isFalse);

    await tester.pumpWidget(
      viewer(
        requestId: 2,
        processing: false,
        animationUrls: urls,
        animationGlosses: glosses,
      ),
    );
    await tester.pump();

    expect(playbackEvents.where((event) => event), hasLength(2));
  });
}
