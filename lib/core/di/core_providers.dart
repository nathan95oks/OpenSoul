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
import '../domain/entities/lsb_card.dart';
import '../domain/ports/conversation_bridge.dart';
import '../domain/repositories/audio_translation_repository.dart';
import '../domain/repositories/translation_repository.dart';
import '../engines/context_engine/context_inference_engine.dart';
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

/// Entradas visibles del diccionario, en crudo. Alimentan la inferencia de
/// contexto, que necesita el vocabulario completo y no el filtrado por zona
/// que hacen los providers de tarjetas.
final lexiconEntriesProvider = FutureProvider<List<LsbCard>>((ref) {
  return ref.watch(lexiconRepositoryProvider).getEntries();
});

// ── Motor de contexto ─────────────────────────────────────────────────────

/// Inferencia de contexto construida sobre el diccionario ya cargado.
/// Mientras el diccionario carga, el motor vacío no sugiere nada: la
/// conversación funciona igual, solo sin preselección de contexto.
final contextInferenceEngineProvider = Provider<ContextInferenceEngine>((ref) {
  final entries = ref.watch(lexiconEntriesProvider).value;
  return entries == null || entries.isEmpty
      ? ContextInferenceEngine.empty()
      : ContextInferenceEngine.fromLexicon(entries);
});

// ── Puente con la conversación (dependencia invertida) ────────────────────
//
// Ambos providers vienen desactivados: con estos valores el flujo de tarjetas
// es una aplicación autónoma. El módulo de conversación los sobrescribe al
// componer la app (`main.dart`), y solo entonces el flujo pasa a responder
// preguntas y a entregar sus declaraciones a un hilo.
//
// Es lo que rompe el ciclo entre features: `lsb_to_text_audio` depende de
// estas abstracciones del núcleo, nunca del módulo de conversación.

/// Pregunta de la persona oyente pendiente de responder, si hay conversación.
final pendingReplyProvider = Provider<ReplyPrompt?>((ref) => null);

/// Destino de una declaración terminada.
final conversationBridgeProvider =
    Provider<ConversationBridge>((ref) => const NoConversationBridge());

// ── Motor de conversación ─────────────────────────────────────────────────

final conversationEngineProvider = Provider<ConversationEngine>((ref) {
  return ConversationEngine(
    assembler: const LocalSentenceAssembler(),
    declarationRepository: ref.watch(translationRepositoryProvider),
    signRepository: ref.watch(audioTranslationRepositoryProvider),
    contextInference: ref.watch(contextInferenceEngineProvider),
  );
});
