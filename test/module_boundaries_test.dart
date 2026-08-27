import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lsb_legal_app/core/di/injection.dart';
import 'package:lsb_legal_app/core/domain/services/conversation_bridge.dart';
import 'package:lsb_legal_app/core/domain/entities/translation_result.dart';

/// Fronteras entre módulos.
///
/// El proyecto sostiene que cada persona desarrolló un módulo de traducción
/// independiente y que el de conversación los integra. Esa afirmación es
/// verificable, así que se verifica: los módulos de traducción no pueden
/// conocer al de conversación, ni entre sí.
///
/// La dirección permitida es una sola —el integrador conoce a sus partes, no
/// al revés—, y se garantiza invirtiendo la dependencia con los puertos de
/// `core/domain/ports`.
void main() {
  const translationModules = ['lsb_to_text_audio', 'audio_to_lsb'];

  List<File> dartFilesOf(String module) =>
      Directory('lib/features/$module')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();

  group('los módulos de traducción no conocen a la conversación', () {
    for (final module in translationModules) {
      test(module, () {
        final offenders = <String>[];
        for (final file in dartFilesOf(module)) {
          if (file.readAsStringSync().contains('features/conversation')) {
            offenders.add(file.path);
          }
        }
        expect(offenders, isEmpty,
            reason: 'Estos archivos rompen la inversión de dependencia y '
                'reintroducen el ciclo entre módulos:\n${offenders.join("\n")}');
      });
    }
  });

  test('los módulos de traducción no se conocen entre sí', () {
    final offenders = <String>[];
    for (final module in translationModules) {
      final others = translationModules.where((m) => m != module);
      for (final file in dartFilesOf(module)) {
        final source = file.readAsStringSync();
        for (final other in others) {
          if (source.contains('features/$other')) offenders.add(file.path);
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  group('sin conversación, el flujo de tarjetas funciona por su cuenta', () {
    test('no hay ninguna pregunta pendiente', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(pendingReplyProvider), isNull);
    });

    test('entregar una declaración no falla ni exige un hilo', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final bridge = container.read(conversationBridgeProvider);
      expect(bridge, isA<NoConversationBridge>());

      // El puerto inerte acepta la declaración sin efecto: la pantalla de
      // resultado sigue generando texto y audio en uso autónomo.
      expect(
        () => bridge.submitDeclaration(
          result: TranslationResult(
            baseSentence: 'Me robaron el celular.',
            generatedText: 'Me robaron el celular.',
          ),
          glosses: const ['ROBAR', 'CELULAR'],
          contextId: 'denuncia_robo',
        ),
        returnsNormally,
      );
    });
  });
}
