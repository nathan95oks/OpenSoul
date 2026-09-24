import 'package:lsb_legal_app/core/domain/entities/dialogue_node.dart';
import 'package:lsb_legal_app/core/domain/entities/institution_profile.dart';
import 'package:lsb_legal_app/core/domain/entities/lsb_card.dart';
import 'package:lsb_legal_app/core/domain/services/local_sentence_assembler.dart';

/// Qué campo se está respondiendo.
///
/// Es lo que decide qué tipos de respuesta caben. Cambiar de categoría o usar
/// el buscador no puede meter una tarjeta incompatible: la pertinencia la fija
/// el campo, no el menú desde el que se llegó.
enum AnswerField {
  polarity,
  person,
  object,
  place,
  time,
  amount,
  institution,
  evidence,
  freeText;

  static AnswerField? bySlot(String slot) => switch (slot) {
        'polarity' => AnswerField.polarity,
        'person' => AnswerField.person,
        'object' => AnswerField.object,
        'place' => AnswerField.place,
        'time' => AnswerField.time,
        'amount' => AnswerField.amount,
        'institution' => AnswerField.institution,
        'evidence' => AnswerField.evidence,
        'free_text' => AnswerField.freeText,
        _ => null,
      };
}

/// Una opción ofrecida, con por qué está donde está.
///
/// La razón viaja para poder auditarla: sin ella no se puede distinguir una
/// tarjeta que responde la pregunta de una que salió por frecuencia.
class RankedCandidate {
  final LsbCard card;
  final double score;
  final String reason;

  const RankedCandidate({
    required this.card,
    required this.score,
    required this.reason,
  });
}

/// Ordena las respuestas válidas para la pregunta que se está contestando.
///
/// El orden lógico es el que fija la especificación de negocio:
///
///   1. propósito, acto comunicativo e intención,
///   2. campo concreto y entidad a la que pertenece,
///   3. glosas compatibles con ese campo,
///   4. coherencia, polaridad, incertidumbre y datos ya confirmados,
///   5. orden por relevancia, con institución y modo como señales de ayuda.
///
/// Dos reglas duras, que son las que este motor existe para garantizar:
///
///   - Una opción **no se vuelve válida** porque Bedrock la sugiera.
///   - Una respuesta correcta **no se elimina** por ser poco frecuente en esa
///     institución. El perfil ordena; no prohíbe.
class CandidateEngine {
  const CandidateEngine();

  /// Glosas que jamás deben desaparecer de una pregunta: decir que no se sabe
  /// es una respuesta, no un hueco.
  static const Set<String> alwaysAvailable = {'NO_SABER', 'NO_RECORDAR'};

  static const Set<String> polarityGlosses = {'SÍ', 'SI', 'NO'};

  List<RankedCandidate> rank({
    required List<LsbCard> available,
    DialogueNode? node,
    InstitutionProfile profile = InstitutionProfile.unknown,
    NeedId? need,
    Set<String> alreadyAnswered = const {},
    List<String> remoteSuggestion = const [],

    /// Campos que pide la zona activa. Se usan cuando no hay nodo —el modo A,
    /// o cuando el español libre del oyente no encaja con ninguno—, para que
    /// el buscador y las categorías tampoco puedan meter algo que la
    /// pregunta no admite.
    Set<String> zoneFields = const {},

    /// Glosas que la zona lista explícitamente para esta pregunta.
    ///
    /// Una lista curada a mano gana a cualquier clasificación inferida: si
    /// alguien decidió que JUEZ responde «¿quién…?» o que «escribir otro»
    /// cabe en evidencia, el filtro no está para desdecirlo.
    Set<String> zoneAllowlist = const {},
  }) {
    // El nodo es más preciso porque sale del enunciado real; la zona es el
    // respaldo cuando no lo hay.
    final campos = node != null && node.slots.isNotEmpty
        ? node.slots.toSet()
        : zoneFields;
    final delCorpus = <String, int>{};
    if (node != null) {
      final ofrecibles = node.offerableGlosses;
      for (var i = 0; i < ofrecibles.length; i++) {
        delCorpus[ofrecibles[i]] = i;
      }
    }

    final delModelo = <String, int>{};
    for (var i = 0; i < remoteSuggestion.length; i++) {
      // El modelo solo reordena lo que ya era alcanzable. Una glosa que no
      // esté en `available` no entra por venir sugerida.
      delModelo[remoteSuggestion[i]] = i;
    }

    final salida = <RankedCandidate>[];
    for (var i = 0; i < available.length; i++) {
      final card = available[i];
      final gloss = card.gloss;

      // Ya elegida: no se repite como si fuera una opción nueva.
      if (alreadyAnswered.contains(gloss)) continue;

      // Incompatible con el campo: fuera, venga de donde venga. Salvo que la
      // zona la liste a mano, que es una decisión tomada a propósito.
      if (!zoneAllowlist.contains(gloss) &&
          campos.isNotEmpty &&
          !fitsField(campos, gloss)) {
        continue;
      }

      // El orden de entrada ya viene curado: la lista blanca de la zona lo
      // fija a mano y el resto sale del catálogo ordenado por frecuencia y
      // prioridad. El motor es ADITIVO: conserva ese orden salvo que haya una
      // señal más fuerte que justifique mover algo. Reordenar por su cuenta
      // deshacía un trabajo de curación que nadie le pidió deshacer.
      double score = (available.length - i) * 0.001;
      var reason = 'orden del catálogo para esta pregunta';

      if (delCorpus.containsKey(gloss)) {
        // Lo que el corpus documenta como respuesta a esta intervención.
        score += 1000 - delCorpus[gloss]!;
        reason = 'responde a lo que se preguntó (corpus)';
      } else if (delModelo.containsKey(gloss)) {
        score += 500 - delModelo[gloss]!;
        reason = 'propuesta del modelo, dentro del vocabulario permitido';
      }

      if (alwaysAvailable.contains(gloss)) {
        // Se garantiza su PRESENCIA —nunca la filtra el campo—, pero sin
        // subirla: decir que no se sabe es una respuesta válida, no la que se
        // espera. El corpus ya la coloca al final de cada nodo.
        reason = 'salida segura ante lo que no se sabe';
      }

      // El perfil y la necesidad son señales de ORDEN. Suman poco a
      // propósito: mover una opción arriba es legítimo; quitarla, no.
      if (node != null && profile.prioritizes(node.intent)) {
        score += 30;
      }
      if (need != null && _servesNeed(profile, need)) {
        score += 10;
      }

      salida.add(RankedCandidate(card: card, score: score, reason: reason));
    }

    // Orden estable: a igualdad de puntuación se conserva el de entrada.
    final indices = {
      for (var i = 0; i < salida.length; i++) salida[i].card.id: i,
    };
    salida.sort((a, b) {
      final porPuntos = b.score.compareTo(a.score);
      if (porPuntos != 0) return porPuntos;
      return indices[a.card.id]!.compareTo(indices[b.card.id]!);
    });
    return salida;
  }

  /// Si [gloss] puede responder alguno de los campos que pide [node].
  ///
  /// Pertenecer al corpus es necesario pero no basta: PLAZA es una glosa
  /// perfectamente documentada y no responde «¿quién escapó?». La pertinencia
  /// la decide el campo que se está completando.
  ///
  /// Tres salvedades deliberadas, para no esconder respuestas correctas:
  ///
  ///   - Una glosa que el ensamblador no clasifica **no se filtra**: si el
  ///     sistema no sabe qué es, quien decide es la persona, no el filtro.
  ///   - Las respuestas de desconocimiento nunca se filtran.
  ///   - Un nodo sin campos reconocibles no filtra nada.
  static bool fitsField(Set<String> slots, String gloss) {
    final clave = gloss.trim().toUpperCase();
    if (alwaysAvailable.contains(clave)) return true;

    final campos = {
      for (final s in slots)
        if (AnswerField.bySlot(s) != null) AnswerField.bySlot(s)!,
    };
    if (campos.isEmpty) return true;

    // La polaridad solo cabe si de verdad se preguntó algo cerrado. Ofrecer
    // SÍ/NO ante «¿dónde ocurrió?» es poner una respuesta que nadie pidió.
    if (polarityGlosses.contains(clave)) {
      return campos.contains(AnswerField.polarity);
    }

    // Una pregunta cerrada admite además el detalle que la matiza: «¿le
    // robaron el celular?» puede responderse «sí» o directamente «celular».
    // Por eso la polaridad no excluye al resto.
    final soloPolaridad = campos.length == 1 &&
        campos.contains(AnswerField.polarity);
    if (soloPolaridad) return true;

    // Texto libre: la pregunta no acota qué tipo de respuesta cabe.
    if (campos.contains(AnswerField.freeText)) return true;

    final funcion = LocalSentenceAssembler.functionOf(gloss);
    if (funcion == null) return true;

    // Un marcador (cantidad, negación) acompaña a otra respuesta en vez de
    // ocupar un campo: no se filtra aquí, lo decide el editor de detalles.
    if (funcion.fields.isEmpty) return true;

    final nombresDeCampo = {
      for (final c in campos) _fieldName(c),
    };
    return funcion.fields.any(nombresDeCampo.contains);
  }

  static String _fieldName(AnswerField f) => switch (f) {
        AnswerField.polarity => 'polarity',
        AnswerField.person => 'person',
        AnswerField.object => 'object',
        AnswerField.place => 'place',
        AnswerField.time => 'time',
        AnswerField.amount => 'amount',
        AnswerField.institution => 'institution',
        AnswerField.evidence => 'evidence',
        AnswerField.freeText => 'free_text',
      };

  bool _servesNeed(InstitutionProfile profile, NeedId need) =>
      profile.priorityNeeds.contains(need);
}
