import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lsb_legal_app/core/domain/entities/lsb_card.dart';
import 'package:lsb_legal_app/core/domain/guided/question_bank.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/sign_images_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/adaptive_node_layout.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/node_flow_canvas.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/semantic_node.dart';

class _ImagesOff extends SignImagesNotifier {
  @override
  bool build() => false;
}

LsbCard _card(String id, String text) => LsbCard(
  id: id,
  gloss: id,
  displayText: text,
  iconUrl: '',
  categoryId: '',
  subcategoryId: '',
  contexts: const [],
  priority: 0,
  suggestedNextCardIds: const [],
  isFrequent: false,
  isEmergency: false,
);

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(360, 640),
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [signImagesEnabledProvider.overrideWith(_ImagesOff.new)],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
          ),
          child: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets(
    'las tarjetas miden según su contenido: ninguna fila pisa a la siguiente',
    (tester) async {
      final cards = [
        for (var i = 0; i < 5; i++)
          _card(
            'c$i',
            i.isEven ? 'CORTO' : 'UNA ETIQUETA BASTANTE LARGA · QUE OCUPA',
          ),
      ];
      await _pump(
        tester,
        AdaptiveNodeLayout(cards: cards, onCardTap: (_) {}),
        textScale: 2.0,
      );
      expect(tester.takeException(), isNull);

      final rects = [
        for (final c in cards) tester.getRect(find.byKey(ValueKey(c.id))),
      ];
      for (var i = 0; i + 2 < rects.length; i += 2) {
        final bottomOfRow = rects[i].bottom > rects[i + 1].bottom
            ? rects[i].bottom
            : rects[i + 1].bottom;
        expect(
          rects[i + 2].top,
          greaterThan(bottomOfRow),
          reason: 'la fila ${i ~/ 2 + 1} no puede montarse sobre la siguiente',
        );
      }
      for (final c in cards) {
        final card = tester.getRect(find.byKey(ValueKey(c.id)));
        final label = tester.getRect(
          find.descendant(
            of: find.byKey(ValueKey(c.id)),
            matching: find.byType(Text),
          ),
        );
        expect(
          card.top <= label.top && label.bottom <= card.bottom,
          isTrue,
          reason: 'la etiqueta de ${c.id} debe quedar dentro de su tarjeta',
        );
      }
      // Las dos tarjetas de una fila igualan la altura de la más alta.
      expect(rects[0].height, rects[1].height);
      expect(find.byType(SemanticNode), findsNWidgets(5));
    },
  );

  testWidgets('la grilla usa una, dos o tres columnas según el ancho', (
    tester,
  ) async {
    final cards = [for (var i = 0; i < 6; i++) _card('r$i', 'GLOSA $i')];

    await _pump(
      tester,
      AdaptiveNodeLayout(cards: cards, onCardTap: (_) {}),
      size: const Size(280, 640),
    );
    var rects = [
      for (final card in cards) tester.getRect(find.byKey(ValueKey(card.id))),
    ];
    expect(rects[1].top, greaterThan(rects[0].bottom));
    expect(rects[1].left, rects[0].left);

    await _pump(
      tester,
      AdaptiveNodeLayout(cards: cards, onCardTap: (_) {}),
      size: const Size(360, 640),
    );
    rects = [
      for (final card in cards) tester.getRect(find.byKey(ValueKey(card.id))),
    ];
    expect(rects[1].top, rects[0].top);
    expect(rects[2].top, greaterThan(rects[0].bottom));

    await _pump(
      tester,
      AdaptiveNodeLayout(cards: cards, onCardTap: (_) {}),
      size: const Size(800, 640),
    );
    rects = [
      for (final card in cards) tester.getRect(find.byKey(ValueKey(card.id))),
    ];
    expect(rects[1].top, rects[0].top);
    expect(rects[2].top, rects[0].top);
    expect(rects[3].top, greaterThan(rects[0].bottom));
  });

  testWidgets('la selección es visible y las etiquetas no se truncan', (
    tester,
  ) async {
    final cards = [
      _card('selected', 'UNA GLOSA SELECCIONADA DE VARIAS PALABRAS'),
      _card('plain', 'OTRA GLOSA EXTENSA QUE DEBE VERSE COMPLETA'),
    ];
    String? tapped;
    await _pump(
      tester,
      AdaptiveNodeLayout(
        cards: cards,
        selectedIds: const {'selected'},
        onCardTap: (card) => tapped = card.id,
      ),
    );

    BoxDecoration decorationOf(String id) =>
        tester
                .widget<AnimatedContainer>(
                  find.descendant(
                    of: find.byKey(ValueKey(id)),
                    matching: find.byType(AnimatedContainer),
                  ),
                )
                .decoration
            as BoxDecoration;

    expect(decorationOf('selected').gradient, isNotNull);
    expect(decorationOf('plain').gradient, isNull);
    for (final id in ['selected', 'plain']) {
      final label = tester.widget<Text>(
        find.descendant(
          of: find.byKey(ValueKey(id)),
          matching: find.byType(Text),
        ),
      );
      expect(label.maxLines, isNull);
      expect(label.data, contains('GLOSA'));
    }

    await tester.tap(find.byKey(const ValueKey('plain')));
    await tester.pumpAndSettle();
    expect(tapped, 'plain');
  });

  testWidgets('la formulación superior es compacta en las 148 preguntas', (
    tester,
  ) async {
    final bank = QuestionBank.generated();
    expect(bank.allQuestions, hasLength(148));
    for (final question in bank.allQuestions) {
      await _pump(
        tester,
        LsbQuestionDisplay(
          spanish: question.formulation,
          formulation: question.lsb,
        ),
      );
      expect(tester.takeException(), isNull, reason: question.id);
      final display = tester.getRect(find.byType(LsbQuestionDisplay));
      expect(
        display.height,
        lessThan(640 * 0.25),
        reason: '${question.id} ocupa ${display.height}px de 640',
      );
    }
  });
}
