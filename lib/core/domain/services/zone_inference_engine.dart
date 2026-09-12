import 'package:lsb_legal_app/core/domain/entities/semantic_context.dart';

class ZoneInferenceEngine {
  const ZoneInferenceEngine();

  List<String> zonesFor({
    required SemanticContext context,
    required String text,
  }) {
    final haystack = _normalize(text);
    if (haystack.isEmpty) return const [];

    final marks = <String, int>{};
    for (final entry in _interrogatives.entries) {
      final at = haystack.indexOf(entry.key);
      if (at < 0) continue;
      final target = entry.value;
      final previous = marks[target];
      if (previous == null || at < previous) marks[target] = at;
    }
    if (marks.isEmpty) return const [];

    final hits = <String, int>{};
    for (final zone in context.zones) {
      // 1. Direct zone ID match
      if (marks.containsKey(zone.id)) {
        hits[zone.id] = marks[zone.id]!;
      }
    }

    if (hits.isNotEmpty) {
      final ordered = hits.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));
      return [for (final e in ordered) e.key];
    }

    // 2. Fallback to gloss/question semantic matching for unmapped aliases
    for (final zone in context.zones) {
      final question = _normalize('${zone.question} ${zone.hint} ${zone.label} ${zone.glossAllowlist.join(" ")}');
      for (final mark in marks.entries) {
        if (question.contains(mark.key) || zone.glossAllowlist.contains(mark.key.toUpperCase())) {
          final previous = hits[zone.id];
          if (previous == null || mark.value < previous) {
            hits[zone.id] = mark.value;
          }
        }
      }
    }
    if (hits.isEmpty) return const [];

    final ordered = hits.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return [for (final e in ordered) e.key];
  }

  static String _normalize(String input) {
    const from = 'áàäâéèëêíìïîóòöôúùüûñ';
    const to = 'aaaaeeeeiiiioooouuuun';
    var out = input.toLowerCase();
    for (var i = 0; i < from.length; i++) {
      out = out.replaceAll(from[i], to[i]);
    }
    return out.replaceAll(RegExp(r'[^a-z0-9 ]'), ' ').replaceAll(RegExp(r'\s+'), ' ');
  }
}

const Map<String, String> _interrogatives = {
  // Tiempo
  'a que hora': 'tiempo',
  'que hora': 'tiempo',
  'cuando ocurrio': 'tiempo',
  'cuando': 'tiempo',
  'que dia': 'tiempo',
  'en que momento': 'tiempo',

  // Lugar
  'donde ocurrio': 'lugar',
  'donde': 'lugar',
  'en que lugar': 'lugar',
  'que lugar': 'lugar',
  'en que calle': 'lugar',

  // Conocimiento / Persona
  'conoce a la persona': 'conocimiento',
  'conoce': 'conocimiento',
  'quien': 'persona',
  'quienes': 'persona',

  // Apariencia (fusionada con la entidad "persona")
  'puede describir': 'persona',
  'describir a la persona': 'persona',
  'como era': 'persona',
  'como eran': 'persona',
  'que aspecto': 'persona',
  'que ropa': 'persona',
  'llevaba gorra': 'persona',
  'llevaba mochila': 'persona',

  // Objetos sustraídos
  'que se llevaron': 'objetos',
  'que le robaron': 'objetos',
  'que le falta': 'objetos',
  'robaron el celular': 'objetos',
  'falta dinero': 'objetos',

  // Testigos y evidencia
  'hay testigos': 'testigos',
  'algun testigo': 'testigos',
  'testigo': 'testigos',
  'fotografias o documentos': 'evidencia',
  'fotografias': 'evidencia',
  'fotos': 'evidencia',
  'documentos': 'evidencia',
  'pruebas': 'evidencia',
  'video': 'evidencia',
  'camaras': 'evidencia',

  // Emergencia y salud
  'esta herido': 'emergencia',
  'atencion medica': 'emergencia',
  'necesita atencion medica': 'emergencia',
  'asistencia medica': 'emergencia',
  'al hospital': 'emergencia',
  'herido': 'emergencia',

  // Denuncia y apoyo legal / autoridad institucional
  'desea realizar una denuncia': 'denuncia',
  'realizar una denuncia': 'denuncia',
  'denuncia': 'denuncia',
  'apoyo legal': 'apoyo_legal',
  'necesita apoyo legal': 'apoyo_legal',
  'abogado': 'institucion_autoridad',
  'interprete': 'institucion_autoridad',
  'defensa publica': 'institucion_autoridad',
  'sepdep': 'institucion_autoridad',
  'sepdavi': 'institucion_autoridad',
  'fiscal': 'institucion_autoridad',
  'juez': 'institucion_autoridad',
  'policia': 'institucion_autoridad',

  // Identificación
  'como se llama': 'identidad',
  'como te llamas': 'identidad',
  'cual es su nombre': 'identidad',
  'su nombre': 'identidad',
  'tu nombre': 'identidad',
  'nombre completo': 'identidad',
  'nombre': 'identidad',
  'apellido': 'identidad',
  'mostrar su documento': 'identidad',
  'carnet': 'identidad',
  'cedula': 'identidad',
  'documento': 'identidad',
  'que edad': 'edad',
  'cuantos anos': 'edad',
  'edad': 'edad',
};
