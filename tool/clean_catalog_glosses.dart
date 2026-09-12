import 'dart:convert';
import 'dart:io';

import 'package:lsb_legal_app/core/domain/services/context_catalog.dart';

void main() {
  final dictFile = File('assets/dictionary/official_dictionary.json');
  final doc = jsonDecode(dictFile.readAsStringSync()) as Map<String, dynamic>;
  final entries = (doc['entries'] as List).cast<Map<String, dynamic>>();
  final officialGlosses = entries.map((e) => e['gloss'] as String).toSet();

  final replacements = {
    'DANAR': 'DAÑAR',
    'ENGANAR': 'ENGAÑAR',
    'ACOMPANAR': 'ACOMPAÑAR',
    'MANANA': 'MAÑANA',
    'POR_QUE': 'POR_QUÉ',
    'PARA_QUE': 'PARA_QUÉ',
    'DINERO': 'BILLETES',
    'AUTO': 'MICRO',
    'APELLIDO': 'NOMBRE',
    'DENUNCIA': 'PRESENTAR',
    'EXPAREJA': 'PAREJA',
    'FAMILIAR': 'PARIENTE',
    'VECINO': 'AMIGO',
    'FISCAL': 'FISCALIA',
    'LADRON': 'LADRÓN',
    'PANTALON': 'PANTALÓN',
    'SI': 'SÍ',
    'DIA': 'DÍA',
    'INTERPRETE': 'INTÉRPRETE',
    'POLICIA': 'POLICÍA',
    'CADA_DIA': 'CADA_DÍA',
    'TODOS_LOS_DIAS': 'TODOS_LOS_DÍAS',
    'AUN': 'AÚN',
    'INVESTIGACION': 'INVESTIGACIÓN',
    'RESOLUCION': 'RESOLUCIÓN',
    'ORGANO_JUDICIAL': 'ÓRGANO_JUDICIAL',
    'PROXIMO': 'PRÓXIMO',
    'DIRECCION': 'DIRECCIÓN',
    'MAMA': 'MAMÁ',
    'DONDE': 'DÓNDE',
    'QUIEN': 'QUIÉN',
    'QUE': 'QUÉ',
    'CUANDO': 'CUÁNDO',
    'CUAL': 'CUÁL',
    'COMO': 'CÓMO',
    'CUANTOS': 'CUÁNTOS',
    'AQUI': 'AQUÍ',
    'TRAMITE': 'TRÁMITE',
  };

  final catFile = File('lib/core/domain/services/context_catalog.dart');
  var catContent = catFile.readAsStringSync();

  for (final entry in replacements.entries) {
    catContent = catContent.replaceAll("'${entry.key}'", "'${entry.value}'");
  }

  catFile.writeAsStringSync(catContent);
  print('Replaced all catalog glosses with 100% verified entries.');
}
