import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lsb_legal_app/app/app_theme.dart';
import 'package:lsb_legal_app/core/domain/guided/guided_answer.dart';
import 'package:lsb_legal_app/core/domain/guided/question_bank.dart';
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
}
