import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:lsb_legal_app/core/data/datasources/remote_translation_datasource.dart';
import 'package:lsb_legal_app/core/data/repositories/translation_repository_impl.dart';
import 'package:lsb_legal_app/core/domain/services/conversation_engine.dart';
import 'package:lsb_legal_app/core/domain/services/local_sentence_assembler.dart';
import 'package:lsb_legal_app/core/domain/repositories/audio_translation_repository.dart';
import 'package:lsb_legal_app/core/domain/entities/lsb_translation.dart';

import 'corpus.dart';
import 'metrics.dart';

/// Banco de evaluación del motor semántico LSB → español.
///
/// Sostiene con cifras la decisión de arquitectura del módulo: **motor de
/// reglas propio con la IA como refinador complementario, no como sustituto**.
/// Sin medición, esa afirmación es una opinión.
///
/// Uso:
///
/// ```
/// flutter test test/benchmark/engine_benchmark_test.dart          # solo motor local
/// flutter test test/benchmark/engine_benchmark_test.dart \
///     --dart-define=BENCHMARK_REMOTE=true                          # + Bedrock e híbrido
/// ```
///
/// La comparación remota está apagada por defecto: gasta cuota de Bedrock y
/// depende de la red, así que no debe correr en cada `flutter test`.
const bool _runRemote = bool.fromEnvironment('BENCHMARK_REMOTE');

void main() {
  const assembler = LocalSentenceAssembler();

  test('motor local — informe de evaluación', () {
    final scores = <CaseScore>[];
    for (final c in benchmarkCorpus) {
      final output =
          assembler.assemble(contextId: c.contextId, glosses: c.glosses);
      scores.add(scoreOutput(
        label: '${c.contextId} · ${c.label}',
        output: output,
        glosses: c.glosses,
        reference: c.reference,
      ));
    }

    final report = BenchmarkReport(variant: 'motor local', scores: scores);
    _printReport(report);

    // Umbrales: el motor local es la red de seguridad de todo el módulo —
    // es lo que responde cuando el backend cae. Si deja de cubrir las glosas
    // o de redactar bien, la degradación deja de ser aceptable.
    expect(report.coverageRate, 1.0,
        reason: 'El motor local perdió glosas: ${_failing(scores, (s) => !s.covers)}');
    expect(report.wellFormedRate, 1.0,
        reason: 'Declaraciones mal formadas: ${_failing(scores, (s) => !s.wellFormed)}');
  });

  test('el corpus declara su estado de validación humana', () {
    final validated = benchmarkCorpus.where((c) => c.hasReference).length;
    final total = benchmarkCorpus.length;
    // ignore: avoid_print
    print('\nESTÁNDAR DE ORO: $validated/$total casos validados por una '
        'persona.\n${validated == 0 ? "Las métricas con referencia (coincidencia exacta, F1) "
        "se activan al rellenar `reference` en corpus.dart.\n" : ""}');
    // No es un fallo tener el corpus sin validar: es una medición honesta del
    // estado del trabajo. La prueba solo obliga a que el corpus exista.
    expect(total, greaterThanOrEqualTo(20),
        reason: 'El corpus es demasiado pequeño para sostener una conclusión.');
  });

  test(
    'comparación motor local vs Bedrock vs híbrido',
    () async {
      final client = http.Client();
      addTearDown(client.close);
      final engine = ConversationEngine(
        assembler: assembler,
        declarationRepository:
            TranslationRepositoryImpl(RemoteTranslationDataSourceImpl(client: client)),
        signRepository: _UnusedSignRepository(),
      );

      final local = <CaseScore>[];
      final remote = <CaseScore>[];
      final hybrid = <CaseScore>[];
      var degenerated = 0;
      var remoteFailures = 0;

      for (final c in benchmarkCorpus) {
        final localText =
            assembler.assemble(contextId: c.contextId, glosses: c.glosses);
        local.add(scoreOutput(
          label: c.label,
          output: localText,
          glosses: c.glosses,
          reference: c.reference,
        ));

        String remoteText = '';
        try {
          final raw = await TranslationRepositoryImpl(
            RemoteTranslationDataSourceImpl(client: client),
          ).translateCards(context: c.contextId, cards: c.glosses);
          remoteText = raw.generatedText;
          if (assembler.isBackendDegenerate(
              backendText: remoteText, glosses: c.glosses)) {
            degenerated++;
          }
        } catch (_) {
          remoteFailures++;
        }
        remote.add(scoreOutput(
          label: c.label,
          output: remoteText,
          glosses: c.glosses,
          reference: c.reference,
        ));

        // El híbrido es lo que el usuario recibe de verdad.
        final merged = await engine.generateDeclaration(
          contextId: c.contextId,
          glosses: c.glosses,
        );
        hybrid.add(scoreOutput(
          label: c.label,
          output: merged.generatedText,
          glosses: c.glosses,
          reference: c.reference,
        ));
      }

      _printReport(BenchmarkReport(variant: 'motor local', scores: local));
      _printReport(BenchmarkReport(variant: 'Bedrock solo', scores: remote));
      _printReport(BenchmarkReport(variant: 'híbrido (entregado)', scores: hybrid));

      // ignore: avoid_print
      print('Respuestas degeneradas del backend: $degenerated/${benchmarkCorpus.length}\n'
          'Fallos de red o error remoto:        $remoteFailures/${benchmarkCorpus.length}\n');

      // La tesis del módulo: el híbrido nunca queda por debajo del local.
      final localReport = BenchmarkReport(variant: 'local', scores: local);
      final hybridReport = BenchmarkReport(variant: 'híbrido', scores: hybrid);
      expect(hybridReport.glossRecall,
          greaterThanOrEqualTo(localReport.glossRecall),
          reason: 'El refinamiento remoto degradó la cobertura del motor local.');
    },
    skip: _runRemote
        ? false
        : 'Requiere backend: --dart-define=BENCHMARK_REMOTE=true',
  );
}

String _failing(List<CaseScore> scores, bool Function(CaseScore) predicate) =>
    scores.where(predicate).map((s) => s.label).join(', ');

void _printReport(BenchmarkReport report) {
  final buffer = StringBuffer()
    ..writeln('\n${'=' * 66}')
    ..writeln('INFORME — ${report.variant}')
    ..writeln('=' * 66);

  for (final s in report.scores) {
    buffer.writeln('· ${s.label}');
    buffer.writeln('    "${s.output}"');
    if (s.missingGlosses.isNotEmpty) {
      buffer.writeln('    ✗ glosas perdidas: ${s.missingGlosses.join(", ")}');
    }
    if (s.rawGlosses.isNotEmpty) {
      buffer.writeln('    ✗ glosas sin redactar: ${s.rawGlosses.join(", ")}');
    }
    if (s.formIssues.isNotEmpty) {
      buffer.writeln('    ✗ forma: ${s.formIssues.join(", ")}');
    }
    if (s.styleIssues.isNotEmpty) {
      buffer.writeln('    ~ estilo: ${s.styleIssues.join(", ")}');
    }
    if (s.tokenF1 != null) {
      buffer.writeln('    F1=${s.tokenF1!.toStringAsFixed(2)}'
          '  exacta=${s.exactMatch! ? "sí" : "no"}');
    }
  }

  buffer
    ..writeln('-' * 66)
    ..writeln('Casos                        ${report.total}')
    ..writeln('Cobertura total de glosas    ${_pct(report.coverageRate)}'
        '  (casos sin perder ninguna glosa)')
    ..writeln('Glosas representadas         ${_pct(report.glossRecall)}'
        '  (sobre el total de glosas)')
    ..writeln('Declaraciones bien formadas  ${_pct(report.wellFormedRate)}'
        '  (utilizables como documento)')
    ..writeln('Sin defecto alguno           ${_pct(report.cleanRate)}'
        '  (incluye estilo)');
  if (report.exactMatchRate != null) {
    buffer
      ..writeln('Coincidencia exacta          ${_pct(report.exactMatchRate!)}'
          '  (${report.withReference.length} casos con referencia)')
      ..writeln('F1 medio por palabra         '
          '${report.averageTokenF1!.toStringAsFixed(3)}');
  }
  buffer.writeln('=' * 66);

  // ignore: avoid_print
  print(buffer);
}

String _pct(double value) => '${(value * 100).toStringAsFixed(1)}%';

/// El banco solo evalúa la dirección LSB → texto; la contraria no se usa.
class _UnusedSignRepository implements AudioTranslationRepository {
  @override
  Future<LsbTranslation> translateText(String text, {String? situation}) =>
      throw UnimplementedError();
}
