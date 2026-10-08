// QA del módulo Conversación con las respuestas reales de las Lambdas.
//
//     flutter test test/qa_conversacion_test.dart \
//       --dart-define=LSB_API_URL=https://api.qa.invalid/translate \
//       --dart-define=LSB_TEXT_API_URL=https://texto.qa.invalid/translate
//
// Cada guion de test/qa/guiones_conversacion.json se juega con la app real:
// el oyente escribe, la Lambda Texto→LSB traduce (respuesta real grabada en
// test/qa/lambda_respuestas.json), el router y el RAG deciden qué tarjetas
// abrir, la persona sorda contesta y su texto vuelve al chat. Las llamadas
// que falten se anotan en test/qa/lambda_pendientes.json:
// `python tool/qa_capturar_lambdas.py` las pide a las Lambdas desplegadas.
// Con REPORTE_QA=<ruta> se escribe el informe de cada turno.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lsb_legal_app/core/di/injection.dart';
import 'package:lsb_legal_app/core/domain/conversation/conversation_route.dart';
import 'package:lsb_legal_app/core/domain/entities/semantic_message.dart';
import 'package:lsb_legal_app/core/domain/entities/translation_result.dart';
import 'package:lsb_legal_app/core/domain/repositories/translation_repository.dart';
import 'package:lsb_legal_app/features/conversation/di/conversation_bindings.dart';
import 'package:lsb_legal_app/features/conversation/presentation/providers/conversation_handoff.dart';
import 'package:lsb_legal_app/features/conversation/presentation/providers/conversation_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/context_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/guided_emission.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/guided_flow_provider.dart';

import 'helpers/fake_audio_output.dart';
import 'helpers/official_dictionary.dart';

const _guiones = 'test/qa/guiones_conversacion.json';
const _respuestas = 'test/qa/lambda_respuestas.json';
const _pendientes = 'test/qa/lambda_pendientes.json';

/// Reproduce las respuestas reales grabadas de las Lambdas. Lo que no está
/// grabado se anota y falla como falla la red (503).
class _Grabadas extends http.BaseClient {
  _Grabadas(this.grabadas);

  final Map<String, dynamic> grabadas;
  final Map<String, Map<String, dynamic>> faltan = {};

  /// El id del turno cambia en cada corrida y no cambia la respuesta.
  static String clave(Uri url, String cuerpo) =>
      '${url.host.split('.').first}${url.path}|'
      '${cuerpo.replaceAll(RegExp(r'"turnId":"[^"]*"'), '"turnId":""')}';

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final cuerpo = request is http.Request ? request.body : '';
    final k = clave(request.url, cuerpo);
    final r = grabadas[k] as Map<String, dynamic>?;
    if (r == null) {
      faltan[k] = {
        'lambda': request.url.host.split('.').first,
        'cuerpo': cuerpo,
      };
      return http.StreamedResponse(Stream.value(utf8.encode('{}')), 503);
    }
    return http.StreamedResponse(
      Stream.value(utf8.encode(r['cuerpo'] as String)),
      r['estado'] as int,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }
}

/// La redacción de la persona sorda: la local del banco (la que la Lambda
/// certifica cuando coincide). No se graba: lleva ids y horas que cambian.
class _Redaccion implements TranslationRepository {
  @override
  Future<TranslationResult> translateCards({
    required String context,
    required List<String> cards,
    Map<String, dynamic>? declaration,
    String? speechAct,
    String? replyToId,
    BusinessSignals? business,
    Map<String, dynamic>? guided,
  }) async => TranslationResult(baseSentence: '', generatedText: '');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final guiones =
      (jsonDecode(File(_guiones).readAsStringSync())['conversaciones'] as List)
          .cast<Map<String, dynamic>>();
  // RESPUESTAS_QA elige otra grabación: la de tool/qa_simular_redespliegue.py
  // mide el QA con la Lambda nueva antes de desplegarla.
  final respuestas = Platform.environment['RESPUESTAS_QA'] ?? _respuestas;
  final grabadas = File(respuestas).existsSync()
      ? jsonDecode(File(respuestas).readAsStringSync()) as Map<String, dynamic>
      : <String, dynamic>{};
  final cliente = _Grabadas(grabadas);
  final informe = <Map<String, dynamic>>[];

  setUp(() => SharedPreferences.setMockInitialValues({}));

  tearDownAll(() {
    const encoder = JsonEncoder.withIndent('  ');
    File(_pendientes).writeAsStringSync(encoder.convert(cliente.faltan));
    final ruta = Platform.environment['REPORTE_QA'];
    if (ruta != null) File(ruta).writeAsStringSync(encoder.convert(informe));
  });

  ProviderContainer app() {
    final c = ProviderContainer(
      overrides: [
        httpClientProvider.overrideWithValue(cliente),
        lexiconRepositoryProvider.overrideWithValue(FakeLexiconRepository()),
        translationRepositoryProvider.overrideWithValue(_Redaccion()),
        audioOutputProvider.overrideWithValue(FakeAudioOutput()),
        ...conversationOverrides(),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  /// La persona sorda contesta lo que se le pide: la opción del guion o la
  /// primera ofrecida que no pide un dato ni cierra el recorrido.
  Future<String?> contestar(
    ProviderContainer c,
    Map<String, dynamic> sorda,
    List<String> pedidas,
  ) async {
    final flow = c.read(guidedFlowProvider.notifier);
    final rules = c.read(guidedFlowRulesProvider);
    final bank = c.read(questionBankProvider);
    final elige = (sorda['elige'] as Map?)?.cast<String, String>() ?? {};

    bool responder(String qid) {
      final session = c.read(guidedFlowProvider).session;
      if (session == null || session.stepOf(qid) == null) return false;
      final ofrecidas = rules.offeredOptions(session, qid);
      final orden = [
        if (elige[qid] != null) elige[qid]!,
        for (final o in ofrecidas)
          if (!o.isExit && !o.requiresValue) o.id,
      ];
      for (final id in orden) {
        if (bank.question(qid)?.options.any((o) => o.id == id) != true) {
          continue;
        }
        if (flow.select(qid, id).accepted) return true;
      }
      return false;
    }

    final session = c.read(guidedFlowProvider).session;
    if (session == null) return null;
    final aResponder = [
      ...elige.keys,
      for (final q in pedidas)
        if (!elige.containsKey(q)) q,
    ];
    if (aResponder.isEmpty && session.currentQuestionId != null) {
      aResponder.add(session.currentQuestionId!);
    }
    for (final q in aResponder) {
      responder(q);
    }
    for (var i = 0; i < 6; i++) {
      final outcome = await c.read(guidedEmissionProvider).emit();
      if (outcome.status != GuidedEmissionStatus.missingRequired) break;
      final falta = c.read(guidedFlowProvider).session?.currentQuestionId;
      if (falta == null || !responder(falta)) break;
    }
    final ultimo = c.read(conversationProvider).conversation.lastTurn;
    return ultimo?.message.speaker == SpeakerRole.deaf
        ? ultimo!.outputs.text
        : null;
  }

  for (final guion in guiones) {
    test('${guion['id']} ${guion['titulo']}', () async {
      final c = app();
      await c.read(lexiconEntriesProvider.future);
      await c.read(conversationGraphCatalogProvider.future);
      await c.read(ragCorpusProvider.future);
      final turnos = <Map<String, dynamic>>[];
      final fallas = <String>[];

      final inicio = guion['inicia_sorda'] as Map<String, dynamic>?;
      if (inicio != null) {
        final handoff = c.read(conversationHandoffProvider);
        handoff.openCards(handoff.nextDeafLaunch());
        c
            .read(contextProvider.notifier)
            .setContext(contextById(inicio['contexto'] as String)!);
        final texto = await contestar(c, inicio, const []);
        turnos.add({'sorda_inicia': texto});
      }

      for (final t in (guion['turnos'] as List).cast<Map<String, dynamic>>()) {
        final texto = t['oyente'] as String;
        final espera = (t['espera'] as Map?)?.cast<String, dynamic>() ?? {};
        final activo = c.read(conversationProvider).conversation.topicContextId;
        await c.read(conversationProvider.notifier).sendHearingMessage(texto);
        await pumpEventQueue(times: 50);
        final estado = c.read(conversationProvider);
        final registro = <String, dynamic>{'oyente': texto, 'espera': espera};
        turnos.add(registro);

        final ultimo = estado.conversation.lastHearingTurn;
        if (ultimo == null || ultimo.message.text != texto.trim()) {
          registro['rechazado'] = estado.error ?? 'sin turno';
          if (espera['rechazado'] != true) {
            fallas.add('«$texto»: rechazado (${estado.error})');
          }
          continue;
        }
        if (espera['rechazado'] == true) {
          fallas.add('«$texto»: se aceptó y debía rechazarse');
        }
        final sem = ultimo.semantic;
        registro['glosas'] = ultimo.message.glosses;
        final router = c.read(conversationGraphRouterProvider);
        if (sem != null && router != null) {
          registro['coincidencias'] = [
            for (final m
                in router.matcher.match(sem, activeContextId: activo).take(6))
              '${m.questionId} ${m.score.toStringAsFixed(2)}',
          ];
          registro['activo'] = activo;
        }
        registro['lectura'] = {
          'intencion': sem?.intent.name,
          'datos': sem?.requestedSlots,
          'contextos': sem?.mentionedContexts,
          'negaciones': sem?.negations,
          'fuente': sem?.source.name,
        };

        final retriever = c.read(ragRetrieverProvider);
        registro['rag'] = [
          for (final s in retriever?.suggest(texto, limit: 8) ?? const [])
            '${s.scenarioId}#${s.questionTurn} ${s.score.toStringAsFixed(2)}',
        ];

        final handoff = c.read(conversationHandoffProvider);
        final launch = handoff.nextDeafLaunch();
        handoff.openCards(launch);
        final r = launch.route;
        final session = c.read(guidedFlowProvider).session;
        final contexto = c.read(contextProvider)?.id;
        final bank = c.read(questionBankProvider);
        final pasos = [
          for (final s in session?.steps ?? const []) s.questionId,
        ];
        final pedidas = [
          ...?r?.targetQuestionIds,
          ...?r?.pathQuestionIds,
        ].where(pasos.contains).toSet().toList();
        final visibles = pedidas.isNotEmpty
            ? pedidas
            : [
                if (session?.currentQuestionId != null)
                  session!.currentQuestionId!,
              ];
        registro['ruta'] = {
          'tipo': r?.type.name,
          'origen': r?.sourceLabel,
          'contexto': r?.targetContextId,
          'familia': r?.targetFamilyId,
          'preguntas': r?.targetQuestionIds,
          'camino': r?.pathQuestionIds,
          'motivo': r?.reason,
        };
        registro['abre'] = {
          'contexto': contexto,
          'familiaEnfocada': launch.focusedFamilyId,
          'preguntas': [
            for (final q in visibles)
              {'id': q, 'formulacion': bank.question(q)?.formulation},
          ],
          'pasos': pasos.length,
        };

        // ¿Coherente?
        final abiertas = {...visibles, ...pedidas};
        final tramite = (contexto ?? '').startsWith('tramite_')
            ? contexto
            : null;
        bool algunaPregunta(List l) => l.any((q) => abiertas.contains(q));
        bool enContexto(List l) => l.contains(contexto);
        bool enTramite(List l) => tramite != null && l.contains(tramite);
        bool enArea(List l) =>
            tramite != null &&
            l.any((a) => tramite.startsWith('tramite_${'$a'.toLowerCase()}_'));
        final alternativas = <bool>[];
        void exige(String clave, bool ok) {
          if (espera.containsKey(clave)) alternativas.add(ok);
        }

        exige(
          'preguntas',
          espera['todas'] == true
              ? (espera['preguntas'] as List).every(abiertas.contains)
              : algunaPregunta(espera['preguntas'] as List? ?? const []),
        );
        exige(
          'o_preguntas',
          algunaPregunta(espera['o_preguntas'] as List? ?? const []),
        );
        exige('contexto', contexto == espera['contexto']);
        exige(
          'o_contexto',
          enContexto(espera['o_contexto'] as List? ?? const []),
        );
        exige(
          'familia',
          launch.focusedFamilyId == espera['familia'] ||
              c.read(questionBankProvider).journey(contexto ?? '') != null &&
                  r?.targetFamilyId == espera['familia'],
        );
        exige(
          'tipo',
          (espera['tipo'] as List? ?? const []).contains(r?.type.name),
        );
        exige(
          'o_tipo',
          (espera['o_tipo'] as List? ?? const []).contains(r?.type.name),
        );
        exige('tramite', enTramite(espera['tramite'] as List? ?? const []));
        exige('o_tramite', enTramite(espera['o_tramite'] as List? ?? const []));
        exige(
          'tramite_area',
          enArea(espera['tramite_area'] as List? ?? const []),
        );
        exige(
          'o_tramite_area',
          enArea(espera['o_tramite_area'] as List? ?? const []),
        );
        final positivas = alternativas.isEmpty || alternativas.any((x) => x);
        // Lo que dijo el oyente tiene que llegar en señas: «buenas tardes»
        // no es BUENOS_DÍAS.
        final glosas = [
          for (final g in ultimo.message.glosses)
            g.toUpperCase().replaceAll('Í', 'I'),
        ];
        final prohibido = [
          for (final g in espera['glosas_contienen'] as List? ?? const [])
            if (!glosas.contains(g)) 'faltó la seña $g',
          for (final g in espera['glosas_no_contienen'] as List? ?? const [])
            if (glosas.contains(g)) 'tradujo $g',
          for (final x in espera['no_contexto'] as List? ?? const [])
            if (x == contexto) 'abrió $x',
          if ((espera['sin_tramite'] == true) && tramite != null)
            'abrió el trámite $tramite',
        ];
        if (!positivas || prohibido.isNotEmpty) {
          fallas.add(
            '«$texto»: abrió ${contexto ?? 'el selector'} '
            '${visibles.isEmpty ? '' : visibles} '
            '(${r?.type.name}) ${prohibido.join(', ')}',
          );
          registro['falla'] = true;
        }

        // La persona sorda contesta y su texto vuelve al chat.
        final sorda = (t['sorda'] as Map?)?.cast<String, dynamic>() ?? {};
        // El selector, o la familia enfocada («Denuncias»): la persona sorda
        // elige su caso, como en la app (también con el buscador).
        if (contexto == null &&
            (r?.type == ConversationRouteType.contextSelector ||
                launch.focusedFamilyId != null)) {
          final elegido = sorda['contexto'] as String?;
          if (elegido == null) {
            registro['sorda'] = '(elige contexto en el selector)';
            continue;
          }
          c.read(contextProvider.notifier).setContext(contextById(elegido)!);
        }
        final dicho = await contestar(c, sorda, pedidas);
        registro['sorda'] = dicho;
        // La persona sorda no dice datos que nadie mencionó («es mi jefe»).
        final inventado = [
          for (final w in espera['sorda_no_dice'] as List? ?? const [])
            if ((dicho ?? '').toLowerCase().contains('$w'.toLowerCase())) w,
        ];
        if (inventado.isNotEmpty) {
          fallas.add('«$texto»: la persona sorda dijo «$dicho» ($inventado)');
          registro['falla'] = true;
        }
      }
      informe.add({
        'id': guion['id'],
        'titulo': guion['titulo'],
        'turnos': turnos,
        'fallas': fallas,
      });
      if (Platform.environment['QA_ESTRICTO'] == '1') {
        expect(fallas, isEmpty);
      }
    });
  }
}
