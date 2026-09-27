import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lsb_legal_app/app/conversation_restoration.dart';
import 'package:lsb_legal_app/core/domain/entities/conversation.dart';
import 'package:lsb_legal_app/core/domain/entities/semantic_message.dart';
import 'package:lsb_legal_app/features/conversation/presentation/providers/conversation_provider.dart';

ConversationTurn _turno(String id, String texto, {bool pending = false}) =>
    ConversationTurn(
      pending: pending,
      message: SemanticMessage(
        id: id,
        speaker: SpeakerRole.hearing,
        source: MessageSource.text,
        glosses: const ['ROBAR'],
        text: texto,
      ),
      outputs: GeneratedOutputs(text: texto),
    );

/// Muestra el estado del chat para poder leerlo desde el test.
class _Sonda extends ConsumerWidget {
  const _Sonda();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final turnos = ref.watch(conversationProvider).conversation.turns;
    return Column(
      children: [
        for (final t in turnos)
          Text('${t.message.text}|${t.pending}|${t.failed}'),
      ],
    );
  }
}

Widget _app() => ProviderScope(
  child: MaterialApp(
    restorationScopeId: 'app',
    builder: (context, child) => ConversationRestoration(child: child!),
    home: const Scaffold(body: _Sonda()),
  ),
);

void main() {
  testWidgets('el chat vuelve si Android mató el proceso en segundo plano', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    final contenedor = ProviderScope.containerOf(
      tester.element(find.byType(_Sonda)),
    );
    contenedor
        .read(conversationProvider.notifier)
        .replaceConversation(
          Conversation(
            id: 'c1',
            startedAt: DateTime(2026, 9, 27),
            turns: [
              _turno('t1', '¿Dónde te robaron?'),
              _turno('t2', 'En curso', pending: true),
            ],
          ),
        );
    await tester.pump();

    await tester.restartAndRestore();
    await tester.pump();

    expect(find.text('¿Dónde te robaron?|false|false'), findsOneWidget);
    // Una traducción a medias no queda cargando para siempre.
    expect(find.text('En curso|false|true'), findsOneWidget);
  });

  testWidgets('un chat vaciado no se repone', (tester) async {
    await tester.pumpWidget(_app());
    final notifier = ProviderScope.containerOf(
      tester.element(find.byType(_Sonda)),
    ).read(conversationProvider.notifier);
    notifier.replaceConversation(
      Conversation(
        id: 'c1',
        startedAt: DateTime(2026, 9, 27),
        turns: [_turno('t1', 'Hola')],
      ),
    );
    await tester.pump();
    notifier.startNew();
    await tester.pump();

    await tester.restartAndRestore();
    await tester.pump();

    expect(find.textContaining('Hola'), findsNothing);
  });
}
