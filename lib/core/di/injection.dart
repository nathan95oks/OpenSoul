import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'package:lsb_legal_app/core/data/datasources/asset_lexicon_datasource.dart';
import 'package:lsb_legal_app/core/data/datasources/lexicon_local_datasource.dart';
import 'package:lsb_legal_app/core/data/datasources/remote_audio_datasource.dart';
import 'package:lsb_legal_app/core/data/datasources/remote_graph_route_datasource.dart';
import 'package:lsb_legal_app/core/data/datasources/remote_lexicon_datasource.dart';
import 'package:lsb_legal_app/core/data/datasources/remote_suggestion_datasource.dart';
import 'package:lsb_legal_app/core/data/datasources/remote_translation_datasource.dart';
import 'package:lsb_legal_app/core/data/datasources/dialogue_graph_datasource.dart';
import 'package:lsb_legal_app/core/data/datasources/business_catalog_datasource.dart';
import 'package:lsb_legal_app/core/data/repositories/animation_repository_impl.dart';
import 'package:lsb_legal_app/core/data/repositories/audio_translation_repository_impl.dart';
import 'package:lsb_legal_app/core/data/repositories/caching_audio_translation_repository.dart';
import 'package:lsb_legal_app/core/data/repositories/lexicon_repository_impl.dart';
import 'package:lsb_legal_app/core/data/repositories/suggestion_repository_impl.dart';
import 'package:lsb_legal_app/core/data/repositories/translation_repository_impl.dart';
import 'package:lsb_legal_app/core/data/services/real_audio_output.dart';
import 'package:lsb_legal_app/core/domain/conversation/conversation_graph_catalog.dart';
import 'package:lsb_legal_app/core/domain/conversation/conversation_graph_router.dart';
import 'package:lsb_legal_app/core/domain/conversation/semantic_turn_builder.dart';
import 'package:lsb_legal_app/core/domain/entities/lsb_card.dart';
import 'package:lsb_legal_app/core/domain/guided/question_bank.dart';
import 'package:lsb_legal_app/core/domain/repositories/animation_repository.dart';
import 'package:lsb_legal_app/core/domain/repositories/session_repository.dart';
import 'package:lsb_legal_app/core/data/repositories/session_repository_impl.dart';
import 'package:lsb_legal_app/core/domain/repositories/audio_translation_repository.dart';
import 'package:lsb_legal_app/core/domain/repositories/lexicon_repository.dart';
import 'package:lsb_legal_app/core/domain/repositories/suggestion_repository.dart';
import 'package:lsb_legal_app/core/domain/repositories/translation_repository.dart';
import 'package:lsb_legal_app/core/domain/services/audio_output.dart';
import 'package:lsb_legal_app/core/domain/services/context_inference_engine.dart';
import 'package:lsb_legal_app/core/domain/services/conversation_bridge.dart';
import 'package:lsb_legal_app/core/domain/services/conversation_engine.dart';
import 'package:lsb_legal_app/core/domain/entities/institution_profile.dart';
import 'package:lsb_legal_app/core/domain/services/dialogue_graph.dart';
import 'package:lsb_legal_app/core/domain/services/local_sentence_assembler.dart';
export 'package:lsb_legal_app/core/presentation/session/active_need_provider.dart'
    show activeNeedProvider, ActiveNeedNotifier;
import 'package:lsb_legal_app/core/presentation/session/cards_flow_launch.dart';
import 'package:lsb_legal_app/core/presentation/session/usage_mode_provider.dart';

final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final remoteTranslationDataSourceProvider =
    Provider<RemoteTranslationDataSource>((ref) {
      return RemoteTranslationDataSourceImpl(
        client: ref.watch(httpClientProvider),
      );
    });

final translationRepositoryProvider = Provider<TranslationRepository>((ref) {
  return TranslationRepositoryImpl(
    ref.watch(remoteTranslationDataSourceProvider),
  );
});

final remoteAudioDataSourceProvider = Provider<RemoteAudioDataSource>((ref) {
  return RemoteAudioDataSourceImpl(client: ref.watch(httpClientProvider));
});

final audioTranslationRepositoryProvider = Provider<AudioTranslationRepository>(
  (ref) {
    return CachingAudioTranslationRepository(
      AudioTranslationRepositoryImpl(
        remoteDataSource: ref.watch(remoteAudioDataSourceProvider),
      ),
    );
  },
);

final sessionRepositoryProvider = Provider<SessionRepository>(
  (ref) => SessionRepositoryImpl(),
);

final animationRepositoryProvider = Provider<AnimationRepository>(
  (ref) => AnimationRepositoryImpl(),
);

final audioOutputProvider = Provider<AudioOutput>((ref) {
  final output = RealAudioOutput();
  ref.onDispose(output.dispose);
  return output;
});

final lexiconRepositoryProvider = Provider<LexiconRepository>((ref) {
  return LexiconRepositoryImpl(
    assetDataSource: AssetLexiconDataSource(),
    remoteDataSource: RemoteLexiconDataSource(
      client: ref.watch(httpClientProvider),
    ),
    localDataSource: LexiconLocalDataSource(),
  );
});

final lexiconEntriesProvider = FutureProvider<List<LsbCard>>((ref) {
  return ref.watch(lexiconRepositoryProvider).getEntries();
});

final contextInferenceEngineProvider = Provider<ContextInferenceEngine>((ref) {
  final entries = ref.watch(lexiconEntriesProvider).value;
  return entries == null || entries.isEmpty
      ? ContextInferenceEngine.empty()
      : ContextInferenceEngine.fromLexicon(entries);
});

final pendingReplyProvider = Provider<ReplyPrompt?>((ref) => null);

final dialogueGraphDataSourceProvider = Provider<DialogueGraphDataSource>(
  (ref) => DialogueGraphDataSource(),
);

final businessCatalogDataSourceProvider = Provider<BusinessCatalogDataSource>(
  (ref) => BusinessCatalogDataSource(),
);

/// Perfiles institucionales y necesidades, cargados una sola vez.
///
/// Se sirve vacío mientras carga y ante un asset ilegible: sin perfiles se
/// trabaja como atención general, que es un uso válido y no un error.
final businessCatalogProvider = FutureProvider<BusinessCatalog>(
  (ref) => ref.watch(businessCatalogDataSourceProvider).load(),
);

/// El perfil de la institución que atiende ahora mismo.
final activeProfileProvider = Provider<InstitutionProfile>((ref) {
  final catalogo = ref.watch(businessCatalogProvider).asData?.value;
  if (catalogo == null) return InstitutionProfile.unknown;
  return catalogo.profileById(ref.watch(activeProfileIdProvider));
});

/// Id del perfil activo. Lo fija el modo ventanilla; en personal es opcional
/// y puede quedarse en `null` sin que eso bloquee nada.
final activeProfileIdProvider = Provider<String?>(
  (ref) => ref.watch(usageSessionProvider).institutionProfileId,
);

/// El banco de nodos conversacionales, cargado una sola vez.
///
/// Se sirve vacío mientras carga y ante un asset ilegible: la navegación por
/// zonas del catálogo es la base, y el grafo es lo que la afina cuando hay
/// una intervención concreta a la que responder.
final dialogueGraphProvider = FutureProvider<DialogueGraph>(
  (ref) => ref.watch(dialogueGraphDataSourceProvider).load(),
);

/// El nodo que corresponde al turno que se está respondiendo, si alguno.
///
/// `null` significa que el español libre del oyente no encaja con seguridad
/// en ningún nodo. No es un fallo: es la señal de que hay que ofrecer
/// intenciones candidatas o dejar seguir con las tarjetas del contexto, en
/// vez de fingir que había una respuesta preparada.
final dialogueMatchProvider = Provider<DialogueMatch?>((ref) {
  final prompt = ref.watch(pendingReplyProvider);
  if (prompt == null || prompt.question.trim().isEmpty) return null;

  final graph = ref.watch(dialogueGraphProvider).asData?.value;
  if (graph == null || graph.isEmpty) return null;

  return graph.match(
    prompt.question,
    mode: CardsFlowPurpose.conversationReply,
    scope: prompt.proposedContextId,
  );
});

final suggestionDataSourceProvider = Provider<RemoteSuggestionDataSource>(
  (ref) => RemoteSuggestionDataSource(client: ref.watch(httpClientProvider)),
);

final suggestionRepositoryProvider = Provider<SuggestionRepository>(
  (ref) => SuggestionRepositoryImpl(ref.watch(suggestionDataSourceProvider)),
);

final conversationBridgeProvider = Provider<ConversationBridge>(
  (ref) => const NoConversationBridge(),
);

final conversationEngineProvider = Provider<ConversationEngine>((ref) {
  return ConversationEngine(
    assembler: const LocalSentenceAssembler(),
    declarationRepository: ref.watch(translationRepositoryProvider),
    signRepository: ref.watch(audioTranslationRepositoryProvider),
    contextInference: ref.watch(contextInferenceEngineProvider),
  );
});

// ---- Ruteo de conversación hacia el grafo de LSB→Texto/Audio -------------

/// Catálogo del router: banco guiado + grafo de diálogo + contextos. Espera
/// al grafo, que es un asset; mientras carga no hay router y Conversation
/// abre las tarjetas como siempre.
final conversationGraphCatalogProvider =
    FutureProvider<ConversationGraphCatalog>((ref) async {
      final graph = await ref.watch(dialogueGraphProvider.future);
      return ConversationGraphCatalog(
        bank: QuestionBank.generated(),
        graph: graph,
      );
    });

final semanticTurnBuilderProvider = Provider<SemanticTurnBuilder?>((ref) {
  final catalog = ref.watch(conversationGraphCatalogProvider).asData?.value;
  return catalog == null ? null : SemanticTurnBuilder(catalog);
});

/// El Bedrock de LSB→Texto/Audio como desempate del router. `null` si no hay
/// endpoint configurado: el router se queda con las reglas deterministas.
final graphRouteModelProvider = Provider<GraphRouteModel?>((ref) {
  final catalog = ref.watch(conversationGraphCatalogProvider).asData?.value;
  if (catalog == null) return null;
  final remote = RemoteGraphRouteDataSource(
    client: ref.watch(httpClientProvider),
    catalog: catalog,
  );
  return remote.isConfigured ? remote : null;
});

final conversationGraphRouterProvider = Provider<ConversationGraphRouter?>((
  ref,
) {
  final catalog = ref.watch(conversationGraphCatalogProvider).asData?.value;
  if (catalog == null) return null;
  return ConversationGraphRouter(
    catalog,
    model: ref.watch(graphRouteModelProvider),
  );
});
