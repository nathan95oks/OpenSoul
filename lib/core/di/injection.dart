import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'package:lsb_legal_app/core/data/datasources/asset_lexicon_datasource.dart';
import 'package:lsb_legal_app/core/data/datasources/lexicon_local_datasource.dart';
import 'package:lsb_legal_app/core/data/datasources/remote_audio_datasource.dart';
import 'package:lsb_legal_app/core/data/datasources/remote_lexicon_datasource.dart';
import 'package:lsb_legal_app/core/data/datasources/remote_suggestion_datasource.dart';
import 'package:lsb_legal_app/core/data/datasources/remote_translation_datasource.dart';
import 'package:lsb_legal_app/core/data/repositories/animation_repository_impl.dart';
import 'package:lsb_legal_app/core/data/repositories/audio_translation_repository_impl.dart';
import 'package:lsb_legal_app/core/data/repositories/caching_audio_translation_repository.dart';
import 'package:lsb_legal_app/core/data/repositories/lexicon_repository_impl.dart';
import 'package:lsb_legal_app/core/data/repositories/suggestion_repository_impl.dart';
import 'package:lsb_legal_app/core/data/repositories/translation_repository_impl.dart';
import 'package:lsb_legal_app/core/data/services/real_audio_output.dart';
import 'package:lsb_legal_app/core/domain/entities/lsb_card.dart';
import 'package:lsb_legal_app/core/domain/repositories/animation_repository.dart';
import 'package:lsb_legal_app/core/domain/repositories/audio_translation_repository.dart';
import 'package:lsb_legal_app/core/domain/repositories/lexicon_repository.dart';
import 'package:lsb_legal_app/core/domain/repositories/suggestion_repository.dart';
import 'package:lsb_legal_app/core/domain/repositories/translation_repository.dart';
import 'package:lsb_legal_app/core/domain/services/audio_output.dart';
import 'package:lsb_legal_app/core/domain/services/context_inference_engine.dart';
import 'package:lsb_legal_app/core/domain/services/conversation_bridge.dart';
import 'package:lsb_legal_app/core/domain/services/conversation_engine.dart';
import 'package:lsb_legal_app/core/domain/services/local_sentence_assembler.dart';

final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final remoteTranslationDataSourceProvider =
    Provider<RemoteTranslationDataSource>((ref) {
  return RemoteTranslationDataSourceImpl(client: ref.watch(httpClientProvider));
});

final translationRepositoryProvider = Provider<TranslationRepository>((ref) {
  return TranslationRepositoryImpl(ref.watch(remoteTranslationDataSourceProvider));
});

final remoteAudioDataSourceProvider = Provider<RemoteAudioDataSource>((ref) {
  return RemoteAudioDataSourceImpl(client: ref.watch(httpClientProvider));
});

final audioTranslationRepositoryProvider =
    Provider<AudioTranslationRepository>((ref) {
  return CachingAudioTranslationRepository(
    AudioTranslationRepositoryImpl(
      remoteDataSource: ref.watch(remoteAudioDataSourceProvider),
    ),
  );
});

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
    remoteDataSource: RemoteLexiconDataSource(client: ref.watch(httpClientProvider)),
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

final suggestionDataSourceProvider = Provider<RemoteSuggestionDataSource>(
  (ref) => RemoteSuggestionDataSource(client: ref.watch(httpClientProvider)),
);

final suggestionRepositoryProvider = Provider<SuggestionRepository>(
  (ref) => SuggestionRepositoryImpl(ref.watch(suggestionDataSourceProvider)),
);

final conversationBridgeProvider =
    Provider<ConversationBridge>((ref) => const NoConversationBridge());

final conversationEngineProvider = Provider<ConversationEngine>((ref) {
  return ConversationEngine(
    assembler: const LocalSentenceAssembler(),
    declarationRepository: ref.watch(translationRepositoryProvider),
    signRepository: ref.watch(audioTranslationRepositoryProvider),
    contextInference: ref.watch(contextInferenceEngineProvider),
  );
});
