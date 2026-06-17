// Prueba de humo exhaustiva — genera una frase para cada glosa
// en cada uno de los 5 contextos oficiales y vuelca la salida.
//
// Ahora valida CALIDAD (no solo "no vacío"): cada frase debe estar
// bien formada — empieza en mayúscula, termina en punto, tiene al menos
// 3 palabras y no filtra guiones bajos de las glosas crudas.
//
// Ejecutar:
//   flutter test test/full_gloss_smoke_test.dart --reporter expanded 2>&1 | tee /tmp/gloss_smoke.txt
import 'package:flutter_test/flutter_test.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/domain/services/local_sentence_assembler.dart';

void main() {
  const asm = LocalSentenceAssembler();

  /// Una oración "bien formada": no vacía, inicia en mayúscula, termina en
  /// punto, tiene al menos 3 palabras y no filtra guiones bajos.
  void expectWellFormed(String s) {
    expect(s.trim(), isNotEmpty, reason: 'no debe estar vacía');
    expect(s.trim().endsWith('.'), true, reason: 'debe terminar en punto: "$s"');
    expect(s[0], s[0].toUpperCase(), reason: 'debe iniciar en mayúscula: "$s"');
    expect(s.contains('_'), false,
        reason: 'no deben filtrarse guiones bajos: "$s"');
    expect(s.split(RegExp(r'\s+')).length, greaterThanOrEqualTo(3),
        reason: 'debe tener al menos 3 palabras: "$s"');
  }

  // Los 5 contextos oficiales de la app
  const contexts = [
    'denuncia_robo',
    'violencia',
    'accidente',
    'otro',
    'orientacion',
  ];

  // ── Todas las glosas del catálogo, agrupadas por categoría ──────────────
  final allGlosses = <String, List<String>>{
    'Identificación': [
      'YO', 'FAMILIA', 'HIJO', 'ESPOSO', 'MAMA', 'PAPA', 'HERMANO',
    ],
    'Descripción-TipoPersona': [
      'HOMBRE', 'MUJER', 'JOVEN', 'NIÑO', 'DESCONOCIDO',
      'VECINO', 'GRUPO', 'ADULTO', 'ABUELO', 'SOLO', 'DOS', 'TRES', 'CONOCIDO',
    ],
    'Descripción-Físico': [
      'ALTO', 'BAJO', 'FLACO', 'GORDO', 'FUERTE', 'MORENO', 'BLANCO_PIEL',
    ],
    'Descripción-Cabello': [
      'PELO_CORTO', 'PELO_LARGO', 'CALVO', 'BARBA', 'BIGOTE',
    ],
    'Descripción-Marcas': [
      'TATUAJE', 'CICATRIZ', 'LENTES', 'MASCARA',
    ],
    'Descripción-Vestimenta': [
      'GORRA', 'CAPUCHA', 'CHOMPA', 'CASCO',
      'CAMISA', 'PANTALON', 'ZAPATOS', 'MOCHILA_USADA',
    ],
    'Descripción-Color': [
      'NEGRO', 'BLANCO', 'AZUL', 'ROJO', 'GRIS', 'VERDE', 'OSCURO', 'CLARO',
    ],
    'Agresión': [
      'ROBAR', 'PEGAR', 'AMENAZAR', 'EMPUJAR', 'GRITAR',
      'QUITAR', 'PERSEGUIR', 'ASALTAR', 'ACOSAR', 'ABUSO', 'SECUESTRAR',
    ],
    'Acciones': [
      'TRAMITAR', 'PEDIR', 'CONSULTAR', 'NECESITAR', 'PAGAR',
      'RENOVAR', 'RECOGER', 'DAR', 'PERDER', 'CORREGIR',
    ],
    'Emociones': [
      'MIEDO', 'ENOJO', 'TRISTE', 'ASUSTADO', 'NERVIOSO',
    ],
    'Estado/Urgencia': [
      'URGENTE', 'AYUDA', 'EMERGENCIA', 'ENFERMEDAD', 'DOLOR', 'CONFUNDIDO',
    ],
    'Objetos': [
      'CELULAR', 'GANAR_DINERO', 'MOCHILA', 'BOLSA', 'LLAVE',
      'CUCHILLO', 'AUTO', 'MOTOCICLETA', 'BILLETERA', 'TARJETA',
      'RELOJ', 'CADENA', 'ANILLO', 'COLLAR', 'ARETES',
      'COMPUTADORA', 'AUDIFONOS', 'LENTES_SOL', 'BICICLETA',
    ],
    'Documentos': [
      'CARNE', 'PAPEL', 'CERTIFICADO', 'PARTIDA_NACIMIENTO', 'LICENCIA',
      'FACTURA', 'ANTECEDENTES', 'COPIA_DENUNCIA', 'COPIA_SENTENCIA',
      'PODER', 'DECLARACION_JURADA',
    ],
    'Lugares': [
      'CALLE', 'CASA', 'MERCADO', 'PARADA', 'MICRO', 'PARQUE',
      'TRABAJO', 'CAJERO', 'BANCO', 'TAXI', 'PLAZA', 'ESQUINA', 'PUENTE',
    ],
    'Instituciones': [
      'POLICIA', 'DEFENSORIA', 'SEGIP', 'HOSPITAL', 'ALCALDIA',
      'REGISTRO_CIVIL', 'FISCAL', 'JUZGADO', 'NOTARIA',
    ],
    'Servicios': [
      'INTERPRETE', 'AMBULANCIA', 'DOCTOR', 'ABOGADO',
      'INFORMACION', 'ORIENTACION',
    ],
    'Consultas/Trámites': [
      'DENUNCIA', 'CONSULTA', 'QUEJAR', 'RENOVACION', 'PAGO', 'DUPLICADO',
    ],
    'Tiempo': [
      'HOY', 'AHORA', 'AYER', 'MAÑANA', 'TARDE', 'NOCHE',
    ],
  };

  // ── Prueba por categoría × contexto ──────────────────────────────────────
  for (final ctx in contexts) {
    group('Contexto: $ctx', () {
      for (final entry in allGlosses.entries) {
        final category = entry.key;
        final glosses = entry.value;

        group('  Categoría: $category', () {
          for (final gloss in glosses) {
            test('    $gloss', () {
              final sentence = asm.assemble(
                contextId: ctx,
                glosses: [gloss],
              );
              // ignore: avoid_print
              print('[$ctx][$category] $gloss\n   → "$sentence"\n');

              // Validación de calidad: la frase debe estar bien formada.
              expectWellFormed(sentence);
            });
          }
        });
      }

      // ── Combinaciones representativas por contexto ────────────────────
      test('  [COMBO] Descripción completa del agresor', () {
        final glosses = ['HOMBRE', 'ALTO', 'MORENO', 'GORRA', 'NEGRO', 'TATUAJE'];
        final s = asm.assemble(contextId: ctx, glosses: glosses);
        // ignore: avoid_print
        print('[$ctx][COMBO] ${glosses.join('+')} → "$s"\n');
        expectWellFormed(s);
      });

      test('  [COMBO] Robo con objetos múltiples', () {
        final glosses = ['ROBAR', 'CELULAR', 'GANAR_DINERO', 'RELOJ', 'CALLE', 'NOCHE'];
        final s = asm.assemble(contextId: ctx, glosses: glosses);
        // ignore: avoid_print
        print('[$ctx][COMBO] ${glosses.join('+')} → "$s"\n');
        expectWellFormed(s);
      });

      test('  [COMBO] Violencia con emoción y urgencia', () {
        final glosses = ['PEGAR', 'MIEDO', 'URGENTE', 'POLICIA'];
        final s = asm.assemble(contextId: ctx, glosses: glosses);
        // ignore: avoid_print
        print('[$ctx][COMBO] ${glosses.join('+')} → "$s"\n');
        expectWellFormed(s);
      });

      test('  [COMBO] Trámite con documentos e institución', () {
        final glosses = ['TRAMITAR', 'CARNE', 'SEGIP', 'HOY'];
        final s = asm.assemble(contextId: ctx, glosses: glosses);
        // ignore: avoid_print
        print('[$ctx][COMBO] ${glosses.join('+')} → "$s"\n');
        expectWellFormed(s);
      });
    });
  }
}
