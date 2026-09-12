import 'package:lsb_legal_app/core/domain/entities/conversation.dart';
import 'package:lsb_legal_app/core/domain/entities/declaration_draft.dart';
import 'package:lsb_legal_app/core/domain/entities/semantic_message.dart';
import 'package:lsb_legal_app/core/domain/entities/speech_act.dart';
import 'package:lsb_legal_app/core/domain/repositories/audio_translation_repository.dart';
import 'package:lsb_legal_app/core/domain/repositories/translation_repository.dart';
import 'package:lsb_legal_app/core/domain/services/context_inference_engine.dart';
import 'package:lsb_legal_app/core/domain/services/local_sentence_assembler.dart';
import 'package:lsb_legal_app/core/domain/entities/translation_result.dart';

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
  }) async {
    final result = await generateDeclaration(
      contextId: contextId,
      glosses: glosses,
      assemblerContextId: assemblerContextId,
      declaration: declaration,
    );
    return turnFromDeclaration(
      result: result,
      glosses: glosses,
      contextId: contextId,
      replyToId: replyToId,
      speechAct: declaration == null ? null : _speechActFrom(declaration.speechAct),
    );
  }

  Future<TranslationResult> generateDeclaration({
    required String contextId,
    required List<String> glosses,
    String? assemblerContextId,
    DeclarationDraft? declaration,
  }) async {
    final localSentence = declaration != null
        ? assembler.assembleStructured(declaration)
        : assembler.assemble(
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
        declaration: declaration?.toJson(),
        speechAct: declaration?.speechAct,
        replyToId: declaration?.replyToId,
      );
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

  static String _newId() => DateTime.now().microsecondsSinceEpoch.toString();
}
