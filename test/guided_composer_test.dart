import 'package:flutter_test/flutter_test.dart';
import 'package:lsb_legal_app/core/domain/guided/guided_answer.dart';
import 'package:lsb_legal_app/core/domain/guided/guided_composer.dart';
import 'package:lsb_legal_app/core/domain/guided/question_bank.dart';
import 'package:lsb_legal_app/core/data/datasources/remote_translation_datasource.dart';

void main() {
  late GuidedComposer composer;
  setUp(() => composer = GuidedComposer(QuestionBank.generated()));

  GuidedAnswer answer(String question, String option,
          {GuidedAnswerState state = GuidedAnswerState.affirmed,
          Map<String, Object?>? values}) =>
      GuidedAnswer(
        questionId: question,
        state: state,
        optionIds: [option],
        values: values == null ? const {} : {option: values},
      );

  test('robo y huida conservan hechos y actores distintos', () {
    final text = composer.compose(GuidedIntervention(
      journeyId: 'denuncia_robo',
      purpose: GuidedPurpose.initiative,
      answers: [
        GuidedAnswer(
          questionId: 'Q.HEC.QUE_OCURRIO',
          state: GuidedAnswerState.affirmed,
          optionIds: const ['robar', 'escapar'],
        ),
        answer('Q.ROB.QUE', 'celular'),
        answer('Q.HEC.ESCAPE_ACTOR', 'yo'),
      ],
    ));
    expect(text, contains('Me robaron el celular.'));
    expect(text, contains('Logré escapar.'));
    expect(text, isNot(contains('no sé quién')));
  });

  test('monto y medio se redactan solo desde valores confirmados', () {
    final text = composer.compose(GuidedIntervention(
      journeyId: 'engano_dinero',
      purpose: GuidedPurpose.initiative,
      answers: [
        answer('Q.DIN.MECANISMO', 'banco'),
        answer('Q.DIN.MONTO', 'monto', values: const {
          'monto': '150',
          'moneda': 'Bs',
        }),
      ],
    ));
    expect(text, contains('Bs 150'));
    expect(text.toLowerCase(), contains('banco'));
    expect(text.toLowerCase(), isNot(contains('factura')));
  });

  test('edad exacta no se convierte en joven ni en aproximada', () {
    final exact = composer.compose(GuidedIntervention(
      journeyId: 'denuncia_robo',
      purpose: GuidedPurpose.standalone,
      answers: [
        answer('Q.PER.DESC.EDAD', 'numero', values: const {'n': 24}),
      ],
    ));
    expect(exact, contains('24 años'));
    expect(exact, isNot(contains('aproximadamente')));
    expect(exact.toLowerCase(), isNot(contains('joven')));
  });

  test('omitido, negado y desconocido son estados distintos', () {
    String compose(GuidedAnswer value) => composer.compose(GuidedIntervention(
          journeyId: 'denuncia_robo',
          purpose: GuidedPurpose.reply,
          answers: [value],
        ));
    expect(compose(answer('Q.EVI.FACTURA', 'no', state: GuidedAnswerState.denied)),
        contains('No tengo'));
    expect(compose(answer('Q.EVI.FACTURA', 'no_sabe', state: GuidedAnswerState.unknown)),
        contains('No sé'));
    expect(
        compose(const GuidedAnswer(
          questionId: 'Q.EVI.FACTURA',
          state: GuidedAnswerState.omitted,
        )),
        isEmpty);
  });

  test('el banco no ofrece celular como remitente', () {
    final question = QuestionBank.generated().questions['Q.DIG.REMITENTE']!;
    final options = (question['opciones'] as List)
        .map((option) => (option as Map<String, dynamic>)['id'])
        .toList();
    expect(options, isNot(contains('celular')));
    expect(options, containsAll(['conoce', 'solo_numero', 'no_sabe']));
  });

  test('el cliente conserva turno exacto y respuestas tipadas en contrato v4', () {
    final intervention = GuidedIntervention(
      journeyId: 'amenaza_digital',
      purpose: GuidedPurpose.reply,
      conversationId: 'conversation-7',
      hearingTurnId: 'hearing-3',
      hearingTurnText: '¿Quién envió los mensajes?',
      answers: [
        answer('Q.DIG.REMITENTE', 'solo_numero',
            values: const {'telefono': '70012345'}),
      ],
    );
    final body = RemoteTranslationDataSourceImpl.buildRequestBody(
      context: 'amenaza_digital',
      cards: const [],
      replyToId: intervention.hearingTurnId,
      guided: intervention.toJson(),
    );
    expect(body['contractVersion'], 4);
    expect(body['replyToId'], 'hearing-3');
    expect((body['guided'] as Map)['hearingTurnText'],
        '¿Quién envió los mensajes?');
  });
}
