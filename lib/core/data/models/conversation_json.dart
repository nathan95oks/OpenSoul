import 'package:lsb_legal_app/core/domain/entities/context_suggestion.dart';
import 'package:lsb_legal_app/core/domain/entities/conversation.dart';
import 'package:lsb_legal_app/core/domain/entities/semantic_message.dart';
import 'package:lsb_legal_app/core/domain/entities/speech_act.dart';

/// Serialización de una conversación para guardarla entre arranques.
///
/// Vive en la capa de datos y no en las entidades a propósito: el dominio no
/// tiene por qué saber que existe un formato de almacenamiento. Así las
/// entidades siguen siendo Dart puro y cambiar de formato no las toca.
///
/// Se guarda lo dicho, no lo derivado: `pendingReply`, `activeContextId` y
/// demás se recalculan a partir de los turnos.
class ConversationJson {
  const ConversationJson._();

  static Map<String, dynamic> encode(Conversation conversation) => {
        'id': conversation.id,
        'startedAt': conversation.startedAt.toIso8601String(),
        'turns': [for (final t in conversation.turns) _encodeTurn(t)],
      };

  /// Devuelve `null` si lo guardado no se puede reconstruir. Una conversación
  /// a medio leer sería peor que ninguna: mostraría turnos sueltos sin el hilo
  /// que los une.
  static Conversation? decode(Map<String, dynamic> json) {
    try {
      final turnos = <ConversationTurn>[];
      for (final crudo in (json['turns'] as List? ?? const [])) {
        final turno = _decodeTurn(Map<String, dynamic>.from(crudo as Map));
        if (turno != null) turnos.add(turno);
      }
      return Conversation(
        id: (json['id'] ?? '').toString(),
        startedAt:
            DateTime.tryParse((json['startedAt'] ?? '').toString()) ??
                DateTime.now(),
        turns: turnos,
      );
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic> _encodeTurn(ConversationTurn turn) => {
        'pending': turn.pending,
        'message': {
          'id': turn.message.id,
          'speaker': turn.message.speaker.name,
          'source': turn.message.source.name,
          'speechAct': turn.message.speechAct.name,
          'glosses': turn.message.glosses,
          'text': turn.message.text,
          'contextId': turn.message.contextId,
          'replyToId': turn.message.replyToId,
          'createdAt': turn.message.createdAt.toIso8601String(),
          'contextSuggestion': turn.message.contextSuggestion == null
              ? null
              : {
                  'contextId': turn.message.contextSuggestion!.contextId,
                  'confidence': turn.message.contextSuggestion!.confidence,
                  'evidence': turn.message.contextSuggestion!.evidence,
                },
          'disambiguations': [
            for (final d in turn.message.disambiguations)
              {'original': d.original, 'meaning': d.meaning, 'reason': d.reason},
          ],
        },
        'outputs': {
          'text': turn.outputs.text,
          'baseText': turn.outputs.baseText,
          'audioUrl': turn.outputs.audioUrl,
          'animationUrls': turn.outputs.animationUrls,
          'animationGlosses': turn.outputs.animationGlosses,
          'refinedByAi': turn.outputs.refinedByAi,
        },
      };

  static ConversationTurn? _decodeTurn(Map<String, dynamic> json) {
    final m = json['message'];
    final o = json['outputs'];
    if (m is! Map || o is! Map) return null;
    final mensaje = Map<String, dynamic>.from(m);
    final salidas = Map<String, dynamic>.from(o);

    final sugerencia = mensaje['contextSuggestion'];

    return ConversationTurn(
      pending: json['pending'] == true,
      message: SemanticMessage(
        id: (mensaje['id'] ?? '').toString(),
        speaker: _porNombre(
            SpeakerRole.values, mensaje['speaker'], SpeakerRole.hearing),
        source: _porNombre(
            MessageSource.values, mensaje['source'], MessageSource.text),
        speechAct: _porNombre(
            SpeechAct.values, mensaje['speechAct'], SpeechAct.statement),
        glosses: _textos(mensaje['glosses']),
        text: (mensaje['text'] ?? '').toString(),
        contextId: mensaje['contextId'] as String?,
        replyToId: mensaje['replyToId'] as String?,
        createdAt:
            DateTime.tryParse((mensaje['createdAt'] ?? '').toString()),
        contextSuggestion: sugerencia is Map
            ? ContextSuggestion(
                contextId: (sugerencia['contextId'] ?? '').toString(),
                confidence:
                    (sugerencia['confidence'] as num?)?.toDouble() ?? 0,
                evidence: _textos(sugerencia['evidence']),
              )
            : null,
        disambiguations: [
          for (final d in (mensaje['disambiguations'] as List? ?? const []))
            SemanticDisambiguation.fromJson(Map<String, dynamic>.from(d as Map)),
        ],
      ),
      outputs: GeneratedOutputs(
        text: (salidas['text'] ?? '').toString(),
        baseText: (salidas['baseText'] ?? '').toString(),
        audioUrl: salidas['audioUrl'] as String?,
        animationUrls: _textos(salidas['animationUrls']),
        animationGlosses: _textos(salidas['animationGlosses']),
        refinedByAi: salidas['refinedByAi'] == true,
      ),
    );
  }

  static List<String> _textos(dynamic valor) =>
      [for (final v in (valor as List? ?? const [])) v.toString()];

  /// Un valor desconocido —porque se guardó con otra versión— cae al
  /// predeterminado en vez de tumbar toda la conversación.
  static T _porNombre<T extends Enum>(
      List<T> valores, dynamic nombre, T porDefecto) {
    final texto = nombre?.toString();
    for (final v in valores) {
      if (v.name == texto) return v;
    }
    return porDefecto;
  }
}
