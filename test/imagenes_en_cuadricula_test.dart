import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lsb_legal_app/core/domain/entities/lsb_card.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/sign_image.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/card_grid.dart';

/// Regresión: `SignImage` existía y estaba probado, pero solo lo usaba el
/// flujo guiado. En la cuadrícula de respuestas las tarjetas se dibujaban con
/// su ícono y NINGUNA seña se veía, por más que estuviera subida a S3.
void main() {
  testWidgets('la cuadrícula pide la imagen de la seña, no solo el ícono',
      (tester) async {
    final card = LsbCard(
      id: 'g001',
      gloss: 'HOMBRE',
      displayText: 'HOMBRE',
      iconUrl: '',
      categoryId: 'Identificación',
      subcategoryId: 'personaDesc',
      contexts: ['denuncia_robo'],
      priority: 1,
      suggestedNextCardIds: [],
      isFrequent: true,
      isEmergency: false,
      semanticIcon: 'person',
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: AnswerCardForTest(card: card, onTap: () {}),
          ),
        ),
      ),
    );

    expect(find.byType(SignImage), findsOneWidget,
        reason: 'sin SignImage la tarjeta nunca consulta el almacén de S3');
  });
}
