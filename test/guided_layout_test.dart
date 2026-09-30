import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lsb_legal_app/core/domain/entities/lsb_card.dart';
import 'package:lsb_legal_app/core/domain/guided/question_bank.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/sign_images_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/gloss_row.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/node_flow_canvas.dart';

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
  Future<bool> sinElegir(LsbCard _) async => false;

  testWidgets(
    'las filas miden según su contenido: ninguna pisa a la siguiente',
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
        GlossRowList(cards: cards, onToggle: sinElegir),
        textScale: 2.0,
      );
      expect(tester.takeException(), isNull);

      final rects = [
        for (final c in cards) tester.getRect(find.byKey(ValueKey(c.id))),
      ];
      for (var i = 0; i + 1 < rects.length; i++) {
        expect(
          rects[i + 1].top,
          greaterThanOrEqualTo(rects[i].bottom),
          reason: 'la fila ${i + 1} no puede montarse sobre la siguiente',
        );
        // Una debajo de otra, a todo el ancho: ya no hay columnas.
        expect(rects[i + 1].left, rects[i].left);
        expect(rects[i + 1].width, rects[i].width);
      }
      for (final c in cards) {
        final row = tester.getRect(find.byKey(ValueKey(c.id)));
        final label = tester.getRect(
          find.descendant(
            of: find.byKey(ValueKey(c.id)),
            matching: find.text(c.displayText),
          ),
        );
        expect(
          row.top <= label.top && label.bottom <= row.bottom,
          isTrue,
          reason: 'la etiqueta de ${c.id} debe quedar dentro de su fila',
        );
      }
      expect(find.byType(GlossRow), findsNWidgets(5));
    },
  );

  testWidgets('las filas son compactas y van separadas por líneas finas', (
    tester,
  ) async {
    final cards = [for (var i = 0; i < 6; i++) _card('r$i', 'GLOSA $i')];
    for (final ancho in const [280.0, 360.0, 800.0]) {
      await _pump(
        tester,
        GlossRowList(cards: cards, onToggle: sinElegir),
        size: Size(ancho, 640),
      );
      final rects = [
        for (final card in cards) tester.getRect(find.byKey(ValueKey(card.id))),
      ];
      for (final r in rects) {
        expect(r.width, ancho, reason: 'fila a todo el ancho ($ancho)');
        expect(
          r.height,
          lessThan(72),
          reason: 'una fila de una línea no es un bloque grande ($ancho)',
        );
        expect(r.height, greaterThanOrEqualTo(48), reason: 'área táctil');
      }
      expect(find.byType(Divider), findsNWidgets(cards.length - 1));
    }
  });

  testWidgets('la elegida se marca sin pintarse entera y nada se trunca', (
    tester,
  ) async {
    final cards = [
      _card('selected', 'UNA GLOSA SELECCIONADA DE VARIAS PALABRAS'),
      _card('plain', 'OTRA GLOSA EXTENSA QUE DEBE VERSE COMPLETA'),
    ];
    final elegidas = <String>[];
    final vistas = <String>[];
    await _pump(
      tester,
      GlossRowList(
        cards: cards,
        selectedIds: const {'selected'},
        onToggle: (card) async {
          elegidas.add(card.id);
          return true;
        },
        onPreview: (card) => vistas.add(card.id),
      ),
    );

    Finder dentro(String id, Finder f) =>
        find.descendant(of: find.byKey(ValueKey(id)), matching: f);

    expect(
      dentro('selected', find.byKey(const Key('fila_elegida'))),
      findsOneWidget,
    );
    expect(
      dentro('plain', find.byKey(const Key('fila_elegida'))),
      findsNothing,
    );
    Color marca(String id) => tester
        .widget<Container>(dentro(id, find.byKey(const Key('marca_fila'))))
        .color!;
    expect(marca('selected'), isNot(Colors.transparent));
    expect(marca('plain'), Colors.transparent);
    // Fondo blanco también en la elegida: se marca, no se rellena.
    for (final id in ['selected', 'plain']) {
      final fondo = tester
          .widgetList<ColoredBox>(dentro(id, find.byType(ColoredBox)))
          .map((b) => b.color)
          .toList();
      expect(fondo, contains(Colors.white), reason: id);
      final label = tester.widget<Text>(dentro(id, find.byType(Text)).first);
      expect(label.maxLines, isNull);
      expect(label.data, contains('GLOSA'));
    }

    await tester.tap(find.text(cards[1].displayText));
    await tester.pumpAndSettle();
    expect(elegidas, ['plain'], reason: 'tocar la fila la elige');
    expect(vistas, isEmpty, reason: 'tocar la fila no abre el avatar');

    // Sin botón de flecha: el avatar se abre deslizando la fila.
    expect(dentro('plain', find.byType(IconButton)), findsNothing);
    final fila = tester.getRect(find.byKey(const ValueKey('plain')));
    await tester.dragFrom(
      Offset(fila.left + 40, fila.center.dy),
      Offset(fila.width * 0.6, 0),
    );
    await tester.pumpAndSettle();
    expect(vistas, ['plain'], reason: 'deslizar abre el avatar');
    expect(elegidas, ['plain'], reason: 'deslizar no elige');
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
