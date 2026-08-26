import '../../domain/entities/conversation.dart';
import '../../domain/entities/semantic_message.dart';
import '../../domain/repositories/audio_translation_repository.dart';
import '../../domain/repositories/translation_repository.dart';
import '../context_engine/context_inference_engine.dart';
import '../semantic_engine/local_sentence_assembler.dart';

/// Motor de conversación: única puerta de entrada para convertir cualquier
/// canal de entrada en un [ConversationTurn] completo (mensaje semántico +
/// salidas generadas).
///
/// Centraliza la estrategia híbrida que antes vivía en la capa de
/// presentación (`TranslationController`):
///   1. El motor semántico local ([LocalSentenceAssembler]) siempre produce
///      una oración base fiel a las glosas.
///   2. El backend (Bedrock + Polly) refina texto y genera audio cuando
///      responde correctamente; si cae o degenera, el turno se completa
///      con el motor local — la conversación nunca se bloquea.
///
/// Ningún generador (texto, audio, avatar) debe invocarse fuera de este
/// motor: así se garantiza que toda salida nace de la misma representación
/// semántica.
class ConversationEngine {
  final LocalSentenceAssembler assembler;

  /// Generación remota para el sentido LSB → texto/audio.
  final TranslationRepository declarationRepository;

  /// Generación remota para el sentido texto/voz → glosas/avatar.
  final AudioTranslationRepository signRepository;

  /// Deduce de qué se está hablando para que el turno del oyente pueda
  /// proponer un contexto a la persona sorda.
  final ContextInferenceEngine contextInference;

  ConversationEngine({
    required this.assembler,
    required this.declarationRepository,
    required this.signRepository,
    ContextInferenceEngine? contextInference,
  }) : contextInference = contextInference ?? ContextInferenceEngine.empty();

  /// Turno de la persona sorda: tarjetas (glosas) → texto + audio.
  ///
  /// Nunca lanza: ante fallo remoto degrada al motor local sin audio.
  Future<ConversationTurn> composeDeafTurn({
    required String contextId,
    required List<String> glosses,
    String? assemblerContextId,
  }) async {
    final result = await generateDeclaration(
      contextId: contextId,
      glosses: glosses,
      assemblerContextId: assemblerContextId,
    );
    return turnFromDeclaration(
      result: result,
      glosses: glosses,
      contextId: contextId,
    );
  }

  /// Fusión híbrida local/remota que produce la declaración completa.
  ///
  /// [assemblerContextId] permite enrutar el compositor local a un
  /// sub-contexto ('perdida', 'tramite_id') sin contaminar la llamada
  /// remota con ids internos no contractuales.
  ///
  /// Nunca lanza: ante fallo remoto degrada al motor local sin audio.
  Future<TranslationResult> generateDeclaration({
    required String contextId,
    required List<String> glosses,
    String? assemblerContextId,
  }) async {
    final localSentence = assembler.assemble(
      contextId: assemblerContextId ?? contextId,
      glosses: glosses,
    );
    final safeLocal =
        localSentence.isNotEmpty ? localSentence : glosses.join(' ');

    TranslationResult result;
    try {
      final remote = await declarationRepository.translateCards(
        context: contextId,
        cards: glosses,
      );
      // El backend REDACTA, ya no pule: su texto no coincide literalmente con
      // el lexicón y exigirlo aquí descartaría toda redacción natural
      // —"resulté con una herida" no contiene "tengo una herida"—. Cuando el
      // servidor declara que él mismo validó la cobertura contra los hechos
      // verificados, esa comprobación ya se hizo y repetirla sobra. Si no lo
      // declara, el cliente la hace: es la ruta de una Lambda antigua o de un
      // texto que el propio servidor no pudo garantizar.
      final degenerate = remote.coverageValidated
          ? remote.generatedText.trim().isEmpty
          : assembler.isBackendDegenerate(
              backendText: remote.generatedText,
              glosses: glosses,
            );
      result = TranslationResult(
        baseSentence: safeLocal,
        generatedText: degenerate ? safeLocal : remote.generatedText,
        audioUrl: degenerate ? null : remote.audioUrl,
        cacheHit: remote.cacheHit,
        bedrockUsed: !degenerate && remote.bedrockUsed,
        coverageValidated: !degenerate && remote.coverageValidated,
        intermediateRepresentation: remote.intermediateRepresentation,
        glossSequence: remote.glossSequence,
      );
    } catch (_) {
      result = TranslationResult(
        baseSentence: safeLocal,
        generatedText: safeLocal,
      );
    }
    return result;
  }

  /// Turno de la persona oyente: voz/texto → glosas + animaciones del avatar.
  ///
  /// [activeContextId] es el contexto vigente de la conversación: viaja al
  /// motor remoto para acotar el vocabulario de la traducción. En el primer
  /// turno es nulo y el backend se comporta como siempre.
  ///
  /// [replyToId] enlaza este turno con el mensaje al que responde.
  ///
  /// Además de traducir, infiere de qué se está hablando: esa sugerencia es
  /// la que después permite a la persona sorda responder sin volver a
  /// declarar el contexto desde cero.
  ///
  /// Lanza si el backend no responde: sin diccionario remoto todavía no
  /// existe generación local de señas (llegará con el diccionario offline).
  Future<ConversationTurn> composeHearingTurn({
    required String text,
    MessageSource source = MessageSource.text,
    String? activeContextId,
    String? replyToId,
  }) {
    return translateHearingTurn(
      draftHearingTurn(text: text, source: source, replyToId: replyToId),
      activeContextId: activeContextId,
    );
  }

  /// Turno del oyente listo para mostrarse **ya**, sin esperar al backend.
  ///
  /// Un enunciado vale desde que se dice, no desde que el motor remoto
  /// contesta. Antes el turno no existía hasta que Bedrock respondía, así que
  /// durante uno o dos segundos no había ni burbuja en el hilo ni pregunta
  /// pendiente: la persona sorda **no podía siquiera empezar a responder**
  /// aunque ya hubiera entendido la pregunta. Ese tiempo muerto estaba en el
  /// centro de la conversación, no en un borde.
  ///
  /// El contexto se infiere aquí mismo con el diccionario local —el motor de
  /// inferencia ya acepta el texto en español como señal—, de modo que el
  /// enrutado a la pregunta concreta funciona sin red. Cuando llegue la
  /// traducción, [translateHearingTurn] la reemplaza por la inferida sobre
  /// las glosas, que es más fiable.
  ConversationTurn draftHearingTurn({
    required String text,
    MessageSource source = MessageSource.text,
    String? replyToId,
  }) {
    return ConversationTurn(
      pending: true,
      message: SemanticMessage(
        id: _newId(),
        speaker: SpeakerRole.hearing,
        source: source,
        glosses: const [],
        text: text,
        replyToId: replyToId,
        contextSuggestion: contextInference.infer(text: text),
      ),
      outputs: GeneratedOutputs(text: text),
    );
  }

  /// Completa [draft] con las señas del motor remoto, conservando su id.
  ///
  /// [activeContextId] es el contexto vigente de la conversación: viaja al
  /// motor remoto para acotar el vocabulario de la traducción. En el primer
  /// turno es nulo y el backend se comporta como siempre.
  Future<ConversationTurn> translateHearingTurn(
    ConversationTurn draft, {
    String? activeContextId,
  }) async {
    final message = draft.message;
    final translation = await signRepository.translateText(
      message.text,
      situation: activeContextId,
    );

    return ConversationTurn(
      pending: false,
      message: SemanticMessage(
        id: message.id,
        speaker: message.speaker,
        source: message.source,
        glosses: translation.glosses,
        text: message.text,
        replyToId: message.replyToId,
        createdAt: message.createdAt,
        disambiguations: translation.disambiguations,
        // Las glosas ya vienen desambiguadas: son mejor señal que el texto
        // crudo con el que se infirió el borrador.
        contextSuggestion: contextInference.infer(
              glosses: translation.glosses,
              text: message.text,
            ) ??
            message.contextSuggestion,
      ),
      outputs: GeneratedOutputs(
        text: message.text,
        animationUrls: translation.animationUrls,
        animationGlosses: translation.animationGlosses,
      ),
    );
  }

  /// Construye el turno sordo a partir de un [TranslationResult] ya
  /// generado. Lo usa tanto [composeDeafTurn] como el flujo guiado de
  /// tarjetas existente, que genera el resultado con su propio controlador.
  ConversationTurn turnFromDeclaration({
    required TranslationResult result,
    required List<String> glosses,
    String? contextId,
    String? replyToId,
  }) {
    final message = SemanticMessage(
      id: _newId(),
      speaker: SpeakerRole.deaf,
      source: MessageSource.cards,
      glosses: glosses,
      contextId: contextId,
      replyToId: replyToId,
      text: result.generatedText,
      intermediateRepresentation: result.intermediateRepresentation,
    );
    return ConversationTurn(
      message: message,
      outputs: GeneratedOutputs(
        text: result.generatedText,
        baseText: result.baseSentence,
        audioUrl: result.audioUrl,
        refinedByAi: result.bedrockUsed,
      ),
    );
  }

  static String _newId() => DateTime.now().microsecondsSinceEpoch.toString();
}
