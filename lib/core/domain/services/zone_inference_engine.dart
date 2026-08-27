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
      final previous = marks[entry.value];
      if (previous == null || at < previous) marks[entry.value] = at;
    }
    if (marks.isEmpty) return const [];

    final hits = <String, int>{};
    for (final zone in context.zones) {
      final question = _normalize('${zone.question} ${zone.hint} ${zone.label}');
      for (final mark in marks.entries) {
        if (!question.contains(mark.key)) continue;
        final previous = hits[zone.id];
        if (previous == null || mark.value < previous) {
          hits[zone.id] = mark.value;
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
  'a que hora': 'cuando',
  'que hora': 'cuando',
  'cuando': 'cuando',
  'que dia': 'cuando',
  'en que momento': 'cuando',
  'donde': 'donde',
  'en que lugar': 'donde',
  'que lugar': 'donde',
  'en que calle': 'donde',
  'quien': 'quien',
  'quienes': 'quien',
  'como era': 'como era',
  'como eran': 'como era',
  'que aspecto': 'como era',
  'que se llevaron': 'llevaron',
  'que te llevaron': 'llevaron',
  'que te robaron': 'llevaron',
  'que le robaron': 'llevaron',
  'que te quitaron': 'llevaron',
  'que objetos': 'llevaron',
  'arma': 'daño',
  'cuchillo': 'daño',
  'te amenazo': 'daño',
  'te hizo daño': 'daño',
  'como se llama': 'nombre',
  'como te llamas': 'nombre',
  'cual es su nombre': 'nombre',
  'su nombre': 'nombre',
  'tu nombre': 'nombre',
  'nombre completo': 'nombre',
  'apellido': 'nombre',
  'que edad': 'edad',
  'cuantos anos': 'edad',
  'su edad': 'edad',
  'tu edad': 'edad',
  'edad tiene': 'edad',
  'carnet': 'identidad',
  'cedula': 'identidad',
  'identifica': 'identidad',
  'identidad': 'identidad',
  'que documento': 'documento',
  'documento': 'documento',
  'que papeles': 'documento',
  'documentacion': 'documento',
  'numero de su caso': 'numero',
  'numero de caso': 'numero',
  'numero de tu caso': 'numero',
  'codigo': 'numero',
  'nurej': 'numero',
  'su caso': 'caso',
  'tu caso': 'caso',
  'del caso': 'caso',
  'webid': 'numero',
  'que institucion': 'institucion',
  'que oficina': 'institucion',
  'ante quien': 'institucion',
  'interprete': 'interprete',
  'necesita apoyo': 'interprete',
  'necesitas apoyo': 'interprete',
  'que necesita hacer': 'necesitas hacer',
  'que necesitas hacer': 'necesitas hacer',
  'que tramite': 'tramite',
  'para cuando': 'para cuando',
  'conoce a la persona': 'conoces',
  'conoces a la persona': 'conoces',
  'la conoce': 'conoces',
  'lo conoce': 'conoces',
  'conoce al agresor': 'conoces',
  'persona involucrada': 'conoces',
  'hay testigos': 'testigos',
  'algun testigo': 'testigos',
  'habia testigos': 'testigos',
  'hubo testigos': 'testigos',
  'alguien vio': 'testigos',
  'desea realizar una denuncia': 'denuncia',
  'desea denunciar': 'denuncia',
  'quiere denunciar': 'denuncia',
  'realizar la denuncia': 'denuncia',
  'apoyo legal': 'apoyo legal',
  'asistencia legal': 'apoyo legal',
  'necesita abogado': 'apoyo legal',
  'necesita un abogado': 'apoyo legal',
  'describir a la persona': 'como era',
  'puede describir': 'como era',
  'pruebas': 'pruebas',
  'fotografias': 'pruebas',
  'fotografia': 'pruebas',
  'evidencia': 'pruebas',
  'atencion medica': 'ayuda',
  'esta herida': 'ayuda',
  'necesita un medico': 'ayuda',
  'necesita atencion': 'ayuda',
  'debo volver': 'cuando',
  'tiene que volver': 'cuando',
  'cuando vuelve': 'cuando',
  'necesita ayuda': 'ayuda',
  'necesitas ayuda': 'ayuda',
  'ayuda urgente': 'ayuda',
  'esta herido': 'ayuda',
  'estas herido': 'ayuda',
};
