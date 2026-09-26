import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lsb_legal_app/core/data/datasources/remote_translation_datasource.dart';
import 'package:lsb_legal_app/core/domain/entities/lsb_translation.dart';
import 'package:lsb_legal_app/core/domain/entities/translation_result.dart';
import 'package:lsb_legal_app/core/domain/guided/guided_answer.dart';
import 'package:lsb_legal_app/core/domain/guided/guided_composer.dart';
import 'package:lsb_legal_app/core/domain/guided/guided_session.dart';
import 'package:lsb_legal_app/core/domain/guided/question_bank.dart';
import 'package:lsb_legal_app/core/domain/repositories/audio_translation_repository.dart';
import 'package:lsb_legal_app/core/domain/repositories/translation_repository.dart';
import 'package:lsb_legal_app/core/domain/services/conversation_engine.dart';
import 'package:lsb_legal_app/core/domain/services/local_sentence_assembler.dart';

/// Preview, resultado y backend parten de la MISMA intervención.
///
/// El servidor recibe exactamente la intervención de la vista previa, y su
/// respuesta solo se acepta si es la misma frase: un backend que pierda o
/// cambie un hecho no puede colarse en el resultado.
class _Backend implements TranslationRepository {
  _Backend(this.responder);
  final String Function(Map<String, dynamic>? guided) responder;
  Map<String, dynamic>? guidedEnviado;
  List<String>? cardsEnviadas;
  bool falla = false;

  @override
  Future<TranslationResult> translateCards({
    required String context,
    required List<String> cards,
    Map<String, dynamic>? declaration,
    String? speechAct,
    String? replyToId,
    BusinessSignals? business,
    Map<String, dynamic>? guided,
  }) async {
    guidedEnviado = guided;
    cardsEnviadas = cards;
    if (falla) throw Exception('sin red');
    final texto = responder(guided);
    return TranslationResult(
      baseSentence: texto,
      generatedText: texto,
      audioUrl: 'https://audio/x.mp3',
      coverageValidated: true,
    );
  }
}

class _Signs implements AudioTranslationRepository {
  @override
  Future<LsbTranslation> translateText(String text,
          {String? situation, Map<String, String>? resolvedSenses}) async =>
      LsbTranslation(glosses: const [], animationUrl: '');
}

void main() {
  final bank = QuestionBank.generated();
  final flow = GuidedFlow(bank);
  final composer = GuidedComposer(bank);

  GuidedIntervention robo() {
    var s = flow.startJourney('denuncia_robo');
    s = flow.select(s, 'Q.HEC.QUE_OCURRIO', 'robar').session;
    s = flow
        .select(s, 'Q.ROB.QUE', 'dinero',
            values: {'monto': '500', 'moneda': 'Bs'})
        .session;
    s = flow.select(s, 'Q.PER.CONOCE', 'no_sabe').session;
    return s.toIntervention();
  }

  ConversationEngine engine(TranslationRepository backend) => ConversationEngine(
        assembler: const LocalSentenceAssembler(),
        declarationRepository: backend,
        signRepository: _Signs(),
      );

  test('el backend recibe exactamente la intervención de la vista previa',
      () async {
    final intervention = robo();
    final local = composer.compose(intervention);
    final backend = _Backend((_) => local);
    await engine(backend).generateGuided(
      intervention: intervention,
      localText: local,
      glosses: flow.glossesOf(intervention),
    );
    expect(jsonEncode(backend.guidedEnviado),
        jsonEncode(intervention.toJson()));
    expect(jsonEncode(backend.guidedEnviado),
        contains('{"monto":"500","moneda":"Bs"}'));
    expect(backend.cardsEnviadas, ['ROBAR', 'BILLETES', 'NO_SABER']);

    // El cuerpo HTTP real lleva el mismo objeto, sin tocar.
    final body = RemoteTranslationDataSourceImpl.buildRequestBody(
      context: 'denuncia_robo',
      cards: backend.cardsEnviadas!,
      guided: backend.guidedEnviado,
    );
    expect(body['guided'], same(backend.guidedEnviado));
    expect(body['contractVersion'], 4);
  });

  test('una respuesta idéntica del servidor aporta su audio', () async {
    final intervention = robo();
    final local = composer.compose(intervention);
    final r = await engine(_Backend((_) => local)).generateGuided(
      intervention: intervention,
      localText: local,
      glosses: flow.glossesOf(intervention),
    );
    expect(r.generatedText, local);
    expect(r.audioUrl, 'https://audio/x.mp3');
    expect(r.coverageValidated, isTrue);
  });

  test('una respuesta distinta del servidor se descarta: gana la preview',
      () async {
    final intervention = robo();
    final local = composer.compose(intervention);
    // Un servidor que pierde la duda y cambia el monto.
    final r = await engine(
            _Backend((_) => 'Me robaron 50 bolivianos y conozco al ladrón.'))
        .generateGuided(
      intervention: intervention,
      localText: local,
      glosses: flow.glossesOf(intervention),
    );
    expect(r.generatedText, local);
    expect(r.generatedText, contains('Bs 500'));
    expect(r.generatedText, contains('No sé si la conozco.'));
    expect(r.audioUrl, isNull,
        reason: 'el audio del servidor sería de otra frase');
  });

  test('sin red, el resultado es la misma frase de la vista previa', () async {
    final intervention = robo();
    final local = composer.compose(intervention);
    final backend = _Backend((_) => local)..falla = true;
    final r = await engine(backend).generateGuided(
      intervention: intervention,
      localText: local,
      glosses: flow.glossesOf(intervention),
    );
    expect(r.generatedText, local);
  });
}
