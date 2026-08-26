import '../../domain/entities/semantic_context.dart';

/// Deduce por qué zonas del flujo guiado pregunta un enunciado del oyente.
///
/// Cuando alguien pregunta «¿a qué hora y dónde te robaron?», la persona sorda
/// no debería recorrer las nueve preguntas del contexto para contestar dos.
/// Este motor detecta esas dos —`tiempo` y `lugar`— y en qué orden se
/// preguntaron, para que el flujo abra directamente donde toca.
///
/// **A diferencia de [ContextInferenceEngine], aquí no basta el diccionario.**
/// La inferencia de contexto se apoya en las glosas del léxico LSB; una
/// pregunta como «a qué hora» no contiene ninguna glosa, sino un
/// **interrogativo**, que pertenece al español y no a la lengua de señas. Por
/// eso hay una tabla explícita de interrogativos: es una clase gramatical
/// cerrada —no crece con el vocabulario—, así que enumerarla es acotado y
/// estable.
///
/// El lado de las zonas sí es dirigido por datos: cada marcador se busca en la
/// `question` que la propia zona declara, de modo que añadir una zona nueva al
/// catálogo la hace detectable sin tocar este motor.
class ZoneInferenceEngine {
  const ZoneInferenceEngine();

  /// Zonas de [context] por las que pregunta [text], en el orden en que
  /// aparecen en la frase. Vacía si no se reconoce ninguna: entonces el flujo
  /// abre por su zona de entrada, como siempre.
  List<String> zonesFor({
    required SemanticContext context,
    required String text,
  }) {
    final haystack = _normalize(text);
    if (haystack.isEmpty) return const [];

    // marcador → posición más temprana en la frase
    final marks = <String, int>{};
    for (final entry in _interrogatives.entries) {
      final at = haystack.indexOf(entry.key);
      if (at < 0) continue;
      final previous = marks[entry.value];
      if (previous == null || at < previous) marks[entry.value] = at;
    }
    if (marks.isEmpty) return const [];

    // zoneId → posición del interrogativo que la reclama
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

/// Forma en que el oyente pregunta → marcador que aparece en la `question` de
/// la zona correspondiente.
///
/// Los marcadores no se inventan: son palabras que ya están en las preguntas
/// del catálogo («¿Cuándo pasó?», «¿Dónde ocurrió?», «¿Qué se llevaron?»).
const Map<String, String> _interrogatives = {
  // Tiempo
  'a que hora': 'cuando',
  'que hora': 'cuando',
  'cuando': 'cuando',
  'que dia': 'cuando',
  'en que momento': 'cuando',
  // Lugar
  'donde': 'donde',
  'en que lugar': 'donde',
  'que lugar': 'donde',
  'en que calle': 'donde',
  // Persona
  'quien': 'quien',
  'quienes': 'quien',
  // Apariencia
  'como era': 'como era',
  'como eran': 'como era',
  'que aspecto': 'como era',
  // La zona de vestimenta se retiró: el diccionario no tiene ninguna prenda,
  // así que "¿qué ropa llevaba?" no tenía respuesta posible. Sus marcadores
  // se van con ella — apuntaban a una zona inexistente y nunca acertaban.
  // Objetos sustraídos
  'que se llevaron': 'llevaron',
  'que te llevaron': 'llevaron',
  'que te robaron': 'llevaron',
  'que le robaron': 'llevaron',
  'que te quitaron': 'llevaron',
  'que objetos': 'llevaron',
  // Agravante (antes "arma"). No hay glosa de arma en el diccionario: la
  // pregunta del funcionario se responde en la zona de agravante, que sí
  // existe, y el arma concreta se deletrea.
  'arma': 'daño',
  'cuchillo': 'daño',
  'te amenazo': 'daño',
  'te hizo daño': 'daño',
  // ── Consultas y trámites: el funcionario dirige, y hasta ahora ninguna de
  // estas preguntas abría nada. Es el hueco por el que "¿sabes qué documento
  // debes llevar?" no llevaba a ningún sitio.
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
  // Ayuda urgente
  'necesita ayuda': 'ayuda',
  'necesitas ayuda': 'ayuda',
  'ayuda urgente': 'ayuda',
  'esta herido': 'ayuda',
  'estas herido': 'ayuda',
};
