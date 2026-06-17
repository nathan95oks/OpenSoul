// ignore_for_file: avoid_print
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/domain/services/local_sentence_assembler.dart';

void main() {
  test('Generar corpus completo y verificar ausencia de frases-cola', () {
    final assembler = LocalSentenceAssembler();
    
    // Extraer glosas directamente del codigo fuente de assembler
    final file = File('lib/features/lsb_to_text_audio/domain/services/local_sentence_assembler.dart');
    final content = file.readAsStringSync();
    
    final regex = RegExp(r"'([A-Z0-Z_]+)':\s*_Lex\(");
    final allGlosses = regex.allMatches(content).map((m) => m.group(1)!).toList();
    print('Encontradas ${allGlosses.length} glosas');
    
    final contexts = ['denuncia_robo', 'violencia', 'accidente', 'tramite_id', 'orientacion', 'perdida', 'otro'];
    
    final forbiddenPhrases = [
      'Asimismo, menciono',
      'También menciono',
      'Detalles:',
      'Consulto sobre:',
      'Involucra'
    ];
    
    int errors = 0;
    
    for (final ctx in contexts) {
      print('=== CONTEXTO: $ctx ===');
      
      // Probar cada glosa individualmente
      for (final gloss in allGlosses) {
        final result = assembler.assemble(contextId: ctx, glosses: [gloss]);
        
        bool hasForbidden = false;
        for (final phrase in forbiddenPhrases) {
          if (result.contains(phrase)) {
            hasForbidden = true;
            break;
          }
        }
        
        if (hasForbidden || !result.endsWith('.') || result.contains(' ,')) {
          print('ERROR [$ctx] [$gloss] -> $result');
          errors++;
        }
      }
      
      // Probar pares de glosas
      for (int i = 0; i < allGlosses.length; i += 7) {
        for (int j = i + 1; j < allGlosses.length; j += 7) {
          final result = assembler.assemble(contextId: ctx, glosses: [allGlosses[i], allGlosses[j]]);
          
          bool hasForbidden = false;
          for (final phrase in forbiddenPhrases) {
            if (result.contains(phrase)) {
              hasForbidden = true;
              break;
            }
          }
          
          if (hasForbidden || !result.endsWith('.') || result.contains(' ,')) {
            print('ERROR [$ctx] [${allGlosses[i]}, ${allGlosses[j]}] -> $result');
            errors++;
          }
        }
      }
    }
    
    print('Total de errores detectados: $errors');
    expect(errors, 0, reason: 'Hay oraciones mal formadas o con frases cola');
  });
}
