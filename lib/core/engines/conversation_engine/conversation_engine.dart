import '../../domain/entities/conversation.dart';
import '../../domain/entities/semantic_message.dart';
import '../../domain/repositories/audio_translation_repository.dart';
import '../../domain/repositories/translation_repository.dart';
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

  const ConversationEngine({
    required this.assembler,
    required this.declarationRepository,
    required this.signRepository,
  });

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
      final degenerate = assembler.isBackendDegenerate(
        backendText: remote.generatedText,
        glosses: glosses,
      );
      result = TranslationResult(
        baseSentence: safeLocal,
        generatedText: degenerate ? safeLocal : remote.generatedText,
        audioUrl: degenerate ? null : remote.audioUrl,
        cacheHit: remote.cacheHit,
        bedrockUsed: !degenerate && remote.bedrockUsed,
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
  /// Lanza si el backend no responde: sin diccionario remoto todavía no
  /// existe generación local de señas (llegará con el diccionario offline).
  Future<ConversationTurn> composeHearingTurn({
    required String text,
    MessageSource source = MessageSource.text,
  }) async {
    final translation = await signRepository.translateText(text);

    final message = SemanticMessage(
      id: _newId(),
      speaker: SpeakerRole.hearing,
      source: source,
      glosses: translation.glosses,
      text: text,
    );
    return ConversationTurn(
      message: message,
      outputs: GeneratedOutputs(
        text: text,
        animationUrls: translation.animationUrls,
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
  }) {
    final message = SemanticMessage(
      id: _newId(),
      speaker: SpeakerRole.deaf,
      source: MessageSource.cards,
      glosses: glosses,
      contextId: contextId,
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
