/// Corpus de evaluación del motor semántico LSB → español.
///
/// Cada caso es una secuencia de glosas tal como la construiría una persona
/// sorda en el flujo guiado, con el contexto desde el que la declara.
///
/// `reference` es el **estándar de oro**: la oración que un hablante nativo
/// considera correcta para esas glosas. Empieza vacío a propósito — nadie
/// puede inventar el estándar de oro de una lengua desde el código. Mientras
/// esté vacío, el banco solo reporta las métricas que no dependen de una
/// referencia humana (cobertura, buena formación, degeneración), que ya dan
/// cifras defendibles. En cuanto se rellena, se activan además la coincidencia
/// exacta y el F1 por palabra para ese caso.
///
/// Para rellenarlo: ejecuta `flutter test test/benchmark/engine_benchmark_test.dart`,
/// mira la salida del motor para cada caso y escribe en `reference` la oración
/// que consideres correcta (idealmente validada con una persona sorda usuaria
/// de LSB o con un intérprete).
class BenchmarkCase {
  /// Contexto del flujo guiado ('denuncia_robo', 'violencia'…).
  final String contextId;

  /// Secuencia de glosas seleccionada con las tarjetas.
  final List<String> glosses;

  /// Oración correcta según revisión humana. Vacía = aún sin validar.
  final String reference;

  /// Etiqueta corta para el informe.
  final String label;

  const BenchmarkCase({
    required this.contextId,
    required this.glosses,
    required this.label,
    this.reference = '',
  });

  bool get hasReference => reference.trim().isNotEmpty;
}

/// Casos heredados de `semantic_coverage_test.dart`, que ya auditaban
/// cobertura, más los del contexto fusionado. Se reutilizan para no mantener
/// dos corpus distintos del mismo dominio.
const benchmarkCorpus = <BenchmarkCase>[
  // ── Denuncia de robo ────────────────────────────────────────────────
  BenchmarkCase(
    label: 'robo mínimo',
    contextId: 'denuncia_robo',
    glosses: ['ROBAR'],
  ),
  BenchmarkCase(
    label: 'robo simple',
    contextId: 'denuncia_robo',
    glosses: ['HOMBRE', 'ROBAR', 'CELULAR'],
  ),
  BenchmarkCase(
    label: 'robo con descripción y lugar',
    contextId: 'denuncia_robo',
    glosses: [
      'HOMBRE', 'ALTO', 'TATUAJE', 'ROBAR', 'CELULAR', 'CALLE', 'NOCHE'
    ],
  ),
  BenchmarkCase(
    label: 'robo con emoción y autoridad',
    contextId: 'denuncia_robo',
    glosses: ['ROBAR', 'CELULAR', 'DINERO', 'POLICIA', 'MIEDO', 'HOY'],
  ),

  // ── Violencia ───────────────────────────────────────────────────────
  BenchmarkCase(
    label: 'amenaza mínima',
    contextId: 'violencia',
    glosses: ['AMENAZAR'],
  ),
  BenchmarkCase(
    label: 'amenaza con descripción',
    contextId: 'violencia',
    glosses: ['AMENAZAR', 'AYUDA', 'PELO_CORTO', 'POLICIA', 'ASUSTADO'],
  ),
  BenchmarkCase(
    label: 'abuso con urgencia',
    contextId: 'violencia',
    glosses: ['ABUSO', 'TATUAJE', 'DEFENSORIA', 'TRISTE', 'URGENTE', 'HOY'],
  ),
  BenchmarkCase(
    label: 'agresión física',
    contextId: 'violencia',
    glosses: ['PEGAR', 'HOMBRE', 'ALTO', 'MIEDO', 'POLICIA', 'ABOGADO'],
  ),

  // ── Accidente ───────────────────────────────────────────────────────
  BenchmarkCase(
    label: 'dolor mínimo',
    contextId: 'accidente',
    glosses: ['DOLOR'],
  ),
  BenchmarkCase(
    label: 'accidente en la calle',
    contextId: 'accidente',
    glosses: ['DOLOR', 'AMBULANCIA', 'CALLE', 'HOY'],
  ),
  BenchmarkCase(
    label: 'accidente urgente',
    contextId: 'accidente',
    glosses: ['DOLOR', 'ASUSTADO', 'AMBULANCIA', 'HOSPITAL', 'URGENTE'],
  ),

  // ── Emergencia ──────────────────────────────────────────────────────
  BenchmarkCase(
    label: 'emergencia mínima',
    contextId: 'emergencia',
    glosses: ['EMERGENCIA'],
  ),
  BenchmarkCase(
    label: 'enfermedad urgente',
    contextId: 'emergencia',
    glosses: ['ENFERMEDAD', 'AMBULANCIA', 'URGENTE', 'HOSPITAL'],
  ),

  // ── Trámites de identidad ───────────────────────────────────────────
  BenchmarkCase(
    label: 'trámite de carnet',
    contextId: 'tramite_id',
    glosses: ['TRAMITAR', 'CARNET', 'SEGIP'],
  ),
  BenchmarkCase(
    label: 'renovación con pago',
    contextId: 'tramite_id',
    glosses: ['RENOVAR', 'LICENCIA', 'PAGO', 'SEGIP', 'HIJO'],
  ),
  BenchmarkCase(
    label: 'antecedentes',
    contextId: 'tramite_id',
    glosses: ['ANTECEDENTES', 'FISCAL'],
  ),
  BenchmarkCase(
    label: 'antecedentes con intérprete',
    contextId: 'tramite_id',
    glosses: [
      'TRAMITAR', 'ANTECEDENTES', 'DENUNCIA', 'FISCAL', 'INTERPRETE', 'HOY'
    ],
  ),
  BenchmarkCase(
    label: 'copia de denuncia',
    contextId: 'tramite_id',
    glosses: ['PEDIR', 'COPIA_DENUNCIA', 'PODER', 'JUZGADO', 'ABOGADO'],
  ),
  BenchmarkCase(
    label: 'corrección de declaración',
    contextId: 'tramite_id',
    glosses: ['CORREGIR', 'DECLARACION_JURADA', 'NOTARIA', 'HIJO', 'AHORA'],
  ),

  // ── Orientación ─────────────────────────────────────────────────────
  BenchmarkCase(
    label: 'orientación mínima',
    contextId: 'orientacion',
    glosses: ['ABOGADO', 'DEFENSORIA'],
  ),
  BenchmarkCase(
    label: 'consulta con intérprete',
    contextId: 'orientacion',
    glosses: ['CONSULTAR', 'INTERPRETE', 'DEFENSORIA', 'HOY'],
  ),

  // ── Pérdida ─────────────────────────────────────────────────────────
  BenchmarkCase(
    label: 'pérdida de carnet',
    contextId: 'perdida',
    glosses: ['PERDER', 'CARNET'],
  ),
  BenchmarkCase(
    label: 'pérdida en la calle',
    contextId: 'perdida',
    glosses: ['PAPEL', 'CALLE', 'AYER', 'POLICIA', 'URGENTE'],
  ),

  // ── Testigo ─────────────────────────────────────────────────────────
  BenchmarkCase(
    label: 'testigo mínimo',
    contextId: 'otro',
    glosses: ['ROBAR'],
  ),
  BenchmarkCase(
    label: 'testigo completo',
    contextId: 'otro',
    glosses: [
      'HOMBRE', 'TATUAJE', 'PEGAR', 'CALLE', 'NOCHE', 'DEFENSORIA'
    ],
  ),
];
