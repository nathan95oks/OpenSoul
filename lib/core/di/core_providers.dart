import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../data/datasources/remote_audio_datasource.dart';
import '../data/datasources/remote_translation_datasource.dart';
import '../data/repositories/audio_translation_repository_impl.dart';
import '../data/repositories/translation_repository_impl.dart';
import '../dictionary/data/asset_lexicon_datasource.dart';
import '../dictionary/data/lexicon_cache.dart';
import '../dictionary/data/lexicon_repository_impl.dart';
import '../dictionary/data/remote_lexicon_datasource.dart';
import '../dictionary/domain/lexicon_repository.dart';
import '../domain/repositories/audio_translation_repository.dart';
import '../domain/repositories/translation_repository.dart';
import '../engines/conversation_engine/conversation_engine.dart';
import '../engines/semantic_engine/local_sentence_assembler.dart';
import '../generators/audio_generator/audio_output.dart';

/// Composición de dependencias del núcleo (composition root).
///
/// Antes cada feature construía su propio `http.Client`, datasource y
/// repositorio; ahora ambas direcciones de la conversación comparten una
/// única cadena de dependencias. Las features solo consumen estos
/// providers (o los re-exportan por compatibilidad).

final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

// ── Sentido LSB (tarjetas) → texto + audio ────────────────────────────────

final remoteTranslationDataSourceProvider =
    Provider<RemoteTranslationDataSource>((ref) {
  return RemoteTranslationDataSourceImpl(client: ref.watch(httpClientProvider));
});

final translationRepositoryProvider = Provider<TranslationRepository>((ref) {
  return TranslationRepositoryImpl(ref.watch(remoteTranslationDataSourceProvider));
});

// ── Sentido voz/texto → glosas + avatar ───────────────────────────────────

final remoteAudioDataSourceProvider = Provider<RemoteAudioDataSource>((ref) {
  return RemoteAudioDataSourceImpl(client: ref.watch(httpClientProvider));
});

final audioTranslationRepositoryProvider =
    Provider<AudioTranslationRepository>((ref) {
  return AudioTranslationRepositoryImpl(
    remoteDataSource: ref.watch(remoteAudioDataSourceProvider),
  );
});

// ── Generadores ───────────────────────────────────────────────────────────

/// Salida de audio (Polly remoto / TTS local). El provider posee el ciclo de
/// vida y libera los plugins nativos al destruirse (RVP-02); los tests lo
/// sobrescriben con un doble (TST-01).
final audioOutputProvider = Provider<AudioOutput>((ref) {
  final output = RealAudioOutput();
  ref.onDispose(output.dispose);
  return output;
});

// ── Diccionario evolutivo ─────────────────────────────────────────────────

/// Única fuente de vocabulario de la app (offline-first: caché → asset,
/// con sincronización remota en segundo plano cuando hay endpoint).
final lexiconRepositoryProvider = Provider<LexiconRepository>((ref) {
  return LexiconRepositoryImpl(
    assetDataSource: AssetLexiconDataSource(),
    remoteDataSource: RemoteLexiconDataSource(client: ref.watch(httpClientProvider)),
    cache: LexiconCache(),
  );
});

// ── Motor de conversación ─────────────────────────────────────────────────

final conversationEngineProvider = Provider<ConversationEngine>((ref) {
  return ConversationEngine(
    assembler: const LocalSentenceAssembler(),
    declarationRepository: ref.watch(translationRepositoryProvider),
    signRepository: ref.watch(audioTranslationRepositoryProvider),
  );
});
