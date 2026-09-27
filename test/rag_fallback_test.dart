import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lsb_legal_app/core/data/datasources/rag_corpus_datasource.dart';
import 'package:lsb_legal_app/core/domain/conversation/conversation_graph_catalog.dart';
import 'package:lsb_legal_app/core/domain/conversation/conversation_graph_router.dart';
import 'package:lsb_legal_app/core/domain/conversation/semantic_turn_builder.dart';
import 'package:lsb_legal_app/core/domain/guided/question_bank.dart';
import 'package:lsb_legal_app/core/domain/rag/rag_corpus.dart';
import 'package:lsb_legal_app/core/domain/rag/rag_retriever.dart';
import 'package:lsb_legal_app/core/domain/services/dialogue_graph.dart';

class _Bundle extends CachingAssetBundle {
  final String? value;

  _Bundle(this.value);

  @override
  Future<ByteData> load(String key) async {
    if (value == null) throw StateError('asset ausente');
    final bytes = Uint8List.fromList(utf8.encode(value!));
    return ByteData.sublistView(bytes);
  }
}

void main() {
  late ConversationGraphRouter router;
  late SemanticTurnBuilder builder;

  setUpAll(() {
    final raw = File('assets/dialogue/dialogue_graph.json').readAsStringSync();
    final catalog = ConversationGraphCatalog(
      bank: QuestionBank.generated(),
      graph: DialogueGraph.fromJsonString(raw),
    );
    router = ConversationGraphRouter(catalog);
    builder = SemanticTurnBuilder(catalog);
  });

  test(
    'índice vacío, asset ausente o corpus corrupto no detienen el grafo',
    () async {
      expect(RagRetriever(RagCorpus.empty).suggest('¿Dónde ocurrió?'), isEmpty);
      final empty = RagRetriever(
        await RagCorpusDataSource(bundle: _Bundle(null)).load(),
      );
      final corrupt = RagRetriever(
        await RagCorpusDataSource(bundle: _Bundle('{no-json')).load(),
      );
      expect(empty.suggest('¿Dónde ocurrió?'), isEmpty);
      expect(corrupt.suggest('¿Dónde ocurrió?'), isEmpty);

      final semantic = builder.build(
        turnId: 'fallback',
        text: '¿Dónde te robaron?',
      );
      final route = router.routeDeterministic(semantic);
      expect(route.targetContextId, 'denuncia_robo');
      expect(route.targetQuestionIds, contains('Q.LUG.DONDE'));
    },
  );
}
