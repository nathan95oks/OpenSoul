import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lsb_legal_app/app/app_theme.dart';
import 'package:lsb_legal_app/core/domain/guided/guided_answer.dart';
import 'package:lsb_legal_app/core/domain/guided/question_bank.dart';
import 'package:lsb_legal_app/features/audio_to_lsb/presentation/widgets/text_input_widget.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/guided_value_editor.dart';

void main() {
  testWidgets('el editor de nombre mantiene texto oscuro sobre fondo claro', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        // Reproduce el tema global oscuro bajo el que se abren las hojas LSB.
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: GuidedValueEditor(
            option: BankOption(
              id: 'nombre',
              label: 'Mi nombre',
              glosses: ['NOMBRE'],
              state: GuidedAnswerState.affirmed,
              editor: 'texto_nombre',
            ),
            question: 'TUYO NOMBRE ¿CUÁL?',
          ),
        ),
      ),
    );
    await tester.pump();

    final field = tester.widget<TextField>(
      find.byKey(const Key('editor_campo_nombre')),
    );
    final decoration = field.decoration!;

    expect(field.style!.color, AppTheme.lightInputText);
    expect(field.cursorColor, AppTheme.lightInputCursor);
    expect(decoration.fillColor, AppTheme.lightInputBg);
    expect(decoration.labelStyle!.color, AppTheme.lightInputHint);
    expect(field.style!.color, isNot(decoration.fillColor));
    expect(decoration.labelStyle!.color, isNot(decoration.fillColor));
  });

  testWidgets(
    'el input compartido usa blanco, texto oscuro, audio azul y envío morado',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(body: TextInputWidget(onSubmit: (_) {})),
          ),
        ),
      );
      await tester.pump();

      final box = tester.widget<Container>(
        find.byKey(const Key('hearing_input_box')),
      );
      final boxDecoration = box.decoration! as BoxDecoration;
      final field = tester.widget<TextField>(find.byType(TextField));
      final audio = tester.widget<Icon>(
        find.byKey(const Key('hearing_audio_action')),
      );
      final send = tester.widget<Icon>(
        find.byKey(const Key('hearing_send_action')),
      );

      expect(boxDecoration.color, AppTheme.lightInputBg);
      expect(field.style!.color, AppTheme.lightInputText);
      expect(field.cursorColor, AppTheme.lightInputCursor);
      expect(field.decoration!.hintStyle!.color, AppTheme.lightInputHint);
      expect(field.style!.color, isNot(boxDecoration.color));
      // Íconos coloreados, sin círculos de fondo.
      expect(audio.color, AppTheme.audioActionBlue);
      expect(send.color, AppTheme.lsbViolet);
      expect(
        find.ancestor(
          of: find.byKey(const Key('hearing_send_action')),
          matching: find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration! as BoxDecoration).shape == BoxShape.circle,
          ),
        ),
        findsNothing,
      );
    },
  );
}
