import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/data/datasources/local_cards_datasource.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/domain/services/local_sentence_assembler.dart';

void main() {
  test('Find missing glosses in lexicon', () {
    final assembler = LocalSentenceAssembler();
    final dataSource = LocalCardsDataSource();
    
    final file = File('lib/features/lsb_to_text_audio/domain/services/local_sentence_assembler.dart');
    final content = file.readAsStringSync();
    
    final regex = RegExp(r"'([A-Z0-Z_]+)':\s*_Lex\(");
    final lexiconKeys = regex.allMatches(content).map((m) => m.group(1)!).toSet();
    
    final allCards = dataSource.cards;
    final missing = <String>[];
    
    for (final card in allCards) {
      if (!lexiconKeys.contains(card.gloss)) {
        missing.add(card.gloss);
        print('MISSING: ${card.gloss} (${card.categoryId})');
      }
    }
    print('Total missing: ${missing.length}');
  });
}
