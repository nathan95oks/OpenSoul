import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lsb_legal_app/core/domain/entities/semantic_context.dart';
import 'package:lsb_legal_app/core/domain/rag/rag_tramites.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/context_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/context_selection_widget.dart';

/// «Trámites» se ordena por institución: la persona elige primero dónde
/// está (SEGIP, SERECI…) y después el trámite.
void main() {
  const instituciones = [
    'Derechos Reales',
    'GAM Cochabamba',
    'Ministerio Público – Fiscalía',
    'Órgano Judicial',
    'SEPDEP',
    'SEPDAVI',
    'FELCC',
    'FELCV',
    'SLIM – Gobierno Autónomo Municipal Cbba',
    'DNA – Gobierno Autónomo Municipal Cbba',
    'Notarías de Fe Pública DIRNOPLU',
    'SEGIP',
    'SERECI',
    'Registro y carnet de discapacidad',
    'Derechos lingüísticos LSB',
  ];

  group('secciones', () {
    test('una por institución, en este orden', () {
      expect(RagTramites.sections.map((s) => s.name), instituciones);
    });

    test('cada trámite está en una sola sección, y ninguno falta', () {
      final agrupados = [for (final s in RagTramites.sections) ...s.contextIds];
      expect(agrupados, unorderedEquals(RagTramites.contextIds));
      expect(agrupados.toSet(), hasLength(agrupados.length));
    });

    test('ordenar no cambia los contextos ni el enrutamiento', () {
      final tramites = contextFamilies.firstWhere((f) => f.id == 'tramites');
      expect(tramites.contextIds, ['identificacion']);
      expect(
        contextsOfFamily(tramites).map((c) => c.id),
        containsAll(RagTramites.contextIds),
      );
    });
  });

  group('la lista de Trámites', () {
    late ProviderContainer container;

    setUp(() => container = ProviderContainer());
    tearDown(() => container.dispose());

    Future<void> seleccion(WidgetTester tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: ContextSelectionWidget()),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> tocar(WidgetTester tester, String texto) async {
      await tester.ensureVisible(find.text(texto));
      await tester.pumpAndSettle();
      await tester.tap(find.text(texto));
      await tester.pumpAndSettle();
    }

    testWidgets('muestra las instituciones, no los trámites sueltos', (
      tester,
    ) async {
      await seleccion(tester);
      await tocar(tester, 'Trámites');

      expect(find.text('Mis datos'), findsOneWidget);
      for (final nombre in instituciones) {
        expect(find.text(nombre), findsOneWidget, reason: nombre);
      }
      expect(find.text('Duplicado de certificado de matrimonio'), findsNothing);
    });

    testWidgets('una institución abre sus trámites; la flecha vuelve', (
      tester,
    ) async {
      await seleccion(tester);
      await tocar(tester, 'Trámites');
      await tocar(tester, 'SERECI');

      expect(find.text('SERECI'), findsOneWidget, reason: 'es el título');
      for (final tramite in const [
        'Duplicado de certificado de nacimiento',
        'Duplicado de certificado de matrimonio',
        'Duplicado de certificado de defunción',
        'Registrar una defunción',
      ]) {
        expect(find.text(tramite), findsOneWidget, reason: tramite);
      }
      expect(find.text('Cédula por primera vez'), findsNothing);
      expect(find.text('Mis datos'), findsNothing);

      // Entrar a un trámite y volver deja la institución abierta.
      await tester.pumpWidget(const SizedBox());
      await seleccion(tester);
      expect(find.text('Registrar una defunción'), findsOneWidget);

      // La flecha de arriba cierra la institución: de vuelta a Trámites.
      container.read(openSectionProvider.notifier).clear();
      await tester.pumpAndSettle();
      expect(find.text('Mis datos'), findsOneWidget);
      expect(find.text('Registrar una defunción'), findsNothing);
    });

    testWidgets('cerrar Trámites olvida también la institución', (
      tester,
    ) async {
      await seleccion(tester);
      await tocar(tester, 'Trámites');
      await tocar(tester, 'SEGIP');
      expect(container.read(openSectionProvider), isNotNull);

      container.read(openFamilyProvider.notifier).clear();
      await tester.pumpAndSettle();
      expect(container.read(openSectionProvider), isNull);

      await tocar(tester, 'Trámites');
      expect(find.text('Mis datos'), findsOneWidget);
      expect(find.text('Cédula por primera vez'), findsNothing);
    });
  });
}
