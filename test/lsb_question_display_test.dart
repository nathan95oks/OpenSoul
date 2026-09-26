import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lsb_legal_app/core/domain/guided/question_bank.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/sign_images_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/node_flow_canvas.dart';

class _ImagesOff extends SignImagesNotifier {
  @override
  bool build() => false;
}

void main() {
  final bank = QuestionBank.generated();

  test('las 492 opciones con seña muestran su secuencia LSB completa', () {
    final options = [
      for (final question in bank.allQuestions) ...question.options,
    ];
    final signed = options.where((option) => option.hasSign).toList();
    final fallback = options.where((option) => !option.hasSign).toList();
    expect(options, hasLength(528));
    expect(signed, hasLength(492));
    expect(fallback, hasLength(36));

    for (final option in signed) {
      expect(
        option.displayFormulation,
        option.glosses.join(' · '),
        reason: option.id,
      );
    }
    for (final option in fallback) {
      expect(option.displayFormulation, option.label, reason: option.id);
    }

    final happened = bank.question('Q.HEC.QUE_OCURRIO')!;
    expect(
      {for (final option in happened.options) option.displayFormulation},
      {'ROBAR', 'PERDER', 'DAÑAR', 'ESCAPAR'},
    );
  });

  Future<void> pumpQuestion(WidgetTester tester, BankQuestion question) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [signImagesEnabledProvider.overrideWith(_ImagesOff.new)],
        child: MaterialApp(
          home: Scaffold(
            body: LsbQuestionDisplay(
              spanish: question.formulation,
              formulation: question.lsb,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('las 143 preguntas muestran exactamente una formulación', (
    tester,
  ) async {
    expect(bank.allQuestions, hasLength(143));
    for (final question in bank.allQuestions) {
      await pumpQuestion(tester, question);
      final lsb = find.byKey(const Key('formulacion_lsb')).evaluate().length;
      final spanish = find
          .byKey(const Key('formulacion_es_fallback'))
          .evaluate()
          .length;
      expect(lsb + spanish, 1, reason: question.id);
      if (question.lsb.hasUsableLsb) {
        expect(lsb, 1, reason: question.id);
        expect(
          find.text(question.formulation),
          findsNothing,
          reason: question.id,
        );
      } else {
        expect(spanish, 1, reason: question.id);
        expect(
          find.text(question.formulation),
          findsOneWidget,
          reason: question.id,
        );
        expect(
          lsb,
          0,
          reason: '${question.id}: no debe mostrar una secuencia parcial',
        );
      }
      for (final technical in const [
        'LSB provisional',
        'LSB validada',
        'GRAMMAR_PROVISIONAL',
        'GRAMMAR_PENDING',
        'LEXICAL_GAP',
        'PENDING',
        'VALIDATED',
      ]) {
        expect(
          find.textContaining(technical),
          findsNothing,
          reason: question.id,
        );
        expect(
          find.bySemanticsLabel(
            RegExp(RegExp.escape(technical), caseSensitive: false),
          ),
          findsNothing,
          reason: question.id,
        );
      }
    }
  });

  testWidgets('QUÉ OCURRIÓ muestra solo TÚ NARRAR QUÉ', (tester) async {
    final question = bank.question('Q.HEC.QUE_OCURRIO')!;
    await pumpQuestion(tester, question);

    final lsb = find.byKey(const Key('formulacion_lsb'));
    expect(lsb, findsOneWidget);
    for (final token in const ['TÚ', 'NARRAR', '¿QUÉ?']) {
      expect(
        find.descendant(of: lsb, matching: find.text(token)),
        findsOneWidget,
      );
    }
    expect(find.text('¿Qué ocurrió?'), findsNothing);
    final token = tester.widget<Text>(find.text('NARRAR'));
    expect(token.style?.fontSize, greaterThanOrEqualTo(16));
  });

  testWidgets('las glosas grandes hacen wrap sin overflow en móvil pequeño', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [signImagesEnabledProvider.overrideWith(_ImagesOff.new)],
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 240,
              child: LsbQuestionDisplay(
                spanish: 'fallback no visible',
                formulation: LsbFormulation(
                  displayReady: true,
                  glosses: [
                    'INVESTIGACIÓN',
                    'CONTINUAR',
                    'DOCUMENTO',
                    'PRESENTAR',
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    final first = tester.getTopLeft(find.text('INVESTIGACIÓN')).dy;
    final last = tester.getTopLeft(find.text('PRESENTAR')).dy;
    expect(
      last,
      greaterThan(first),
      reason: 'la secuencia debe ocupar más de una fila',
    );
    expect(find.text('fallback no visible'), findsNothing);
  });

  testWidgets('pendiente y hueco incompleto usan español sin LSB parcial', (
    tester,
  ) async {
    for (final id in const ['I.PREG.CUANDO', 'Q.EVI.QUE_TIENE']) {
      final question = bank.question(id)!;
      await pumpQuestion(tester, question);
      expect(
        find.byKey(const Key('formulacion_es_fallback')),
        findsOneWidget,
        reason: id,
      );
      expect(find.text(question.formulation), findsOneWidget, reason: id);
      expect(
        find.byKey(const Key('formulacion_lsb')),
        findsNothing,
        reason: id,
      );
    }
  });

  testWidgets('provisional completa y dactilología se muestran como LSB', (
    tester,
  ) async {
    for (final id in const ['Q.HEC.QUE_OCURRIO', 'Q.SEG.DONDE_FISCALIA']) {
      final question = bank.question(id)!;
      await pumpQuestion(tester, question);
      expect(
        find.byKey(const Key('formulacion_lsb')),
        findsOneWidget,
        reason: id,
      );
      expect(
        find.byKey(const Key('formulacion_es_fallback')),
        findsNothing,
        reason: id,
      );
      expect(find.text(question.formulation), findsNothing, reason: id);
    }
    expect(find.text('d(FISCALÍA)'), findsOneWidget);
  });
}
