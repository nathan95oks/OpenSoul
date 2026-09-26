import 'package:lsb_legal_app/core/domain/entities/conversation.dart';
import 'package:lsb_legal_app/core/domain/entities/declaration_draft.dart';
import 'package:lsb_legal_app/core/domain/guided/guided_answer.dart';
import 'package:lsb_legal_app/core/domain/entities/semantic_message.dart';
import 'package:lsb_legal_app/core/domain/entities/speech_act.dart';
import 'package:lsb_legal_app/core/domain/repositories/audio_translation_repository.dart';
import 'package:lsb_legal_app/core/domain/repositories/translation_repository.dart';
import 'package:lsb_legal_app/core/domain/services/context_inference_engine.dart';
import 'package:lsb_legal_app/core/domain/services/local_sentence_assembler.dart';
import 'package:lsb_legal_app/core/domain/entities/translation_result.dart';
import 'package:lsb_legal_app/core/data/datasources/remote_translation_datasource.dart';
import 'package:lsb_legal_app/core/data/datasources/backend_capability.dart';

class ConversationEngine {
  final LocalSentenceAssembler assembler;
  final TranslationRepository declarationRepository;
  final AudioTranslationRepository signRepository;
  final ContextInferenceEngine contextInference;

  ConversationEngine({
    required this.assembler,
    required this.declarationRepository,
    required this.signRepository,
    ContextInferenceEngine? contextInference,
  }) : contextInference = contextInference ?? ContextInferenceEngine.empty();

  Future<ConversationTurn> composeDeafTurn({
    required String contextId,
    required List<String> glosses,
    String? assemblerContextId,
    String? replyToId,
    DeclarationDraft? declaration,
    BusinessSignals? business,
  }) async {
    final result = await generateDeclaration(
      contextId: contextId,
      glosses: glosses,
      assemblerContextId: assemblerContextId,
      declaration: declaration,
      business: business,
    );
    return turnFromDeclaration(
      result: result,
      glosses: glosses,
      contextId: contextId,
      replyToId: replyToId,
      speechAct: declaration == null
          ? null
          : _speechActFrom(declaration.speechAct),
    );
  }

  Future<TranslationResult> generateDeclaration({
    required String contextId,
    required List<String> glosses,
    String? assemblerContextId,
    DeclarationDraft? declaration,
    BusinessSignals? business,
  }) async {
    final localSentence = declaration != null
        ? assembler.assembleStructured(declaration)
        : assembler.assemble(
            contextId: assemblerContextId ?? contextId,
            glosses: glosses,
          );
    final safeLocal = localSentence.isNotEmpty
        ? localSentence
        : glosses.join(' ');

    TranslationResult result;
    try {
      final remote = await declarationRepository.translateCards(
        context: contextId,
        cards: glosses,
        declaration: declaration?.toJson(),
        speechAct: declaration?.speechAct,
        replyToId: declaration?.replyToId,
        business: business,
      );
      // Un backend que no conserva la colección de hechos devuelve una frase
      // plausible a la que le falta la mitad de lo declarado. No hay forma de
      // detectarlo mirando el texto —suena bien—, así que se decide por la
      // capacidad anunciada: si no puede conservarlos, manda la redacción
      // local, que sí los tiene todos.
      final pierdeHechos =
          declaration != null &&
          !BackendCompatibility.canSendWithoutLoss(
            declaration,
            RemoteTranslationDataSourceImpl.lastKnownCapability,
          );

      final degenerate =
          pierdeHechos ||
          (remote.coverageValidated
              ? remote.generatedText.trim().isEmpty
              : assembler.isBackendDegenerate(
                  backendText: remote.generatedText,
                  glosses: glosses,
                ));
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

  /// Declaración de una intervención guiada (contrato v4).
  ///
  /// [localText] sigue siendo el fallback determinista. El servidor puede
  /// devolver otra redacción natural solo cuando certifica
  /// [TranslationResult.coverageValidated]: esa bandera la emite el validador
  /// semántico, no el modelo. Sin ella, con texto vacío o ante error, gana la
  /// vista previa local y se descarta también el audio remoto.
  Future<TranslationResult> generateGuided({
    required GuidedIntervention intervention,
    required String localText,
    required List<String> glosses,
    String? speechAct,
    BusinessSignals? business,
  }) async {
    final local = TranslationResult(
      baseSentence: localText,
      generatedText: localText,
    );
    if (localText.trim().isEmpty) return local;
    try {
      final remote = await declarationRepository.translateCards(
        context: intervention.journeyId,
        cards: glosses,
        speechAct: speechAct,
        replyToId: intervention.hearingTurnId,
        business: business,
        guided: intervention.toJson(),
      );
      if (!remote.coverageValidated || remote.generatedText.trim().isEmpty) {
        return local;
      }
      return TranslationResult(
        baseSentence: localText,
        generatedText: remote.generatedText,
        audioUrl: remote.audioUrl,
        cacheHit: remote.cacheHit,
        bedrockUsed: remote.bedrockUsed,
        coverageValidated: true,
        intermediateRepresentation: remote.intermediateRepresentation,
        glossSequence: remote.glossSequence,
      );
    } catch (_) {
      return local;
    }
  }

  SpeechAct _speechActFrom(String name) => SpeechAct.values.firstWhere(
    (v) => v.name == name,
    orElse: () => SpeechAct.statement,
  );

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
        speechAct: classifySpeechAct(text),
        source: source,
        glosses: const [],
        text: text,
        replyToId: replyToId,
        contextSuggestion: contextInference.infer(text: text),
      ),
      outputs: GeneratedOutputs(text: text),
    );
  }

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
        speechAct: message.speechAct,
        glosses: translation.glosses,
        text: message.text,
        replyToId: message.replyToId,
        createdAt: message.createdAt,
        disambiguations: translation.disambiguations,
        contextSuggestion:
            contextInference.infer(
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

  ConversationTurn turnFromDeclaration({
    required TranslationResult result,
    required List<String> glosses,
    String? contextId,
    String? replyToId,
    SpeechAct? speechAct,
  }) {
    final message = SemanticMessage(
      id: _newId(),
      speaker: SpeakerRole.deaf,
      source: MessageSource.cards,
      speechAct: speechAct ?? classifySpeechAct(result.generatedText),
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

  /// Contador que rompe los empates del reloj.
  ///
  /// El identificador era solo `microsecondsSinceEpoch`, y dos turnos creados
  /// dentro del mismo microsegundo —responder y que el oyente escriba acto
  /// seguido, o un dispositivo rápido— recibían el mismo. `replaceTurn` busca
  /// por id, así que al completarse la traducción del turno del oyente
  /// reemplazaba al turno homónimo anterior: una declaración ya registrada de
  /// la persona sorda desaparecía del chat sin dejar rastro, y las respuestas
  /// posteriores se enlazaban a un turno que ya no era el suyo.
  static int _sequence = 0;

  static String _newId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_sequence++}';
}
