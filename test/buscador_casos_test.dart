import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lsb_legal_app/core/domain/rag/rag_tramites.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/domain/services/case_search.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/case_search_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/context_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/case_search_view.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/context_selection_widget.dart';

/// El buscador de la selección de contexto: filtra poco a poco, como el del
/// sistema, y lleva directo al caso.
void main() {
  final buscador = CaseSearch.fromCatalog(RagTramites.bankWithTramites());

  /// Los casos encontrados para [q], en orden.
  List<String> casos(String q) => [
    for (final g in buscador.search(q, perGroup: 1000))
      for (final h in g.hits)
        if (h.entry.kind == CaseHitKind.context) h.entry.title,
  ];

  group('qué encuentra', () {
    test('como lo diría la persona: conjugado, coloquial, sin tildes', () {
      for (final (q, caso) in [
        ('me robaron el celular', 'Denunciar robo de celular'),
        ('robaron mi celu', 'Denunciar robo'),
        ('me pegaron', 'Denunciar violencia'),
        ('me estafaron', 'Estafa y transferencia de dinero'),
        ('plata', 'Engaño con dinero'),
        ('perdi mi carnet', 'Reposición por pérdida'),
        ('CERTIFICADO NACIMIENTO', 'Duplicado de certificado de nacimiento'),
        ('interprete juzgado', 'Pedir intérprete en un juzgado'),
      ]) {
        expect(casos(q), contains(caso), reason: q);
      }
    });

    test('con un error de tipeo encuentra lo que se le parece, y solo si no '
        'hay nada exacto', () {
      expect(casos('selular'), contains('Denunciar robo de celular'));
      // «cédula» existe tal cual: no trae lo que solo se le parece.
      expect(casos('cedula'), isNot(contains('Denunciar robo de celular')));
    });

    test('filtra poco a poco: desde 3 letras, cada letra deja lo mismo o '
        'menos', () {
      // Con 1 o 2 letras se busca solo en nombres y descripciones; desde 3,
      // también en lo que se pregunta dentro del caso.
      final rob = casos('rob').toSet();
      final robo = casos('robo').toSet();
      final roboCel = casos('robo cel').toSet();
      final roboCelular = casos('robo celular').toSet();
      expect(rob.containsAll(robo), isTrue);
      expect(robo.containsAll(roboCel), isTrue);
      expect(roboCel.containsAll(roboCelular), isTrue);
      expect(roboCelular, contains('Denunciar robo de celular'));
      expect(
        roboCelular,
        isNot(contains('Presentar denuncia verbal por robo')),
      );
      expect(casos('ro'), isNot(contains('Declaración y testimonio')));
      expect(rob, contains('Declaración y testimonio'));
    });

    test('si se encontró por lo que hay dentro del caso, dice qué frase', () {
      final hit = [
        for (final g in buscador.search('golpearon'))
          ...g.hits.where((h) => h.entry.title == 'Declaración y testimonio'),
      ].single;
      expect(hit.snippet, contains('golpearon'));
    });

    test('sin nada que se parezca, no hay resultados', () {
      expect(buscador.search('xyzw'), isEmpty);
      expect(buscador.search('   '), isEmpty);
      expect(buscador.search('de la el'), isEmpty);
    });

    test('cada sugerencia para empezar lleva a algún caso', () {
      for (final s in kCaseSearchSuggestions) {
        expect(casos(s), isNotEmpty, reason: s);
      }
    });

    test('resalta el comienzo de cada palabra buscada, con o sin tildes', () {
      const texto = 'Pedir intérprete en un juzgado';
      final rangos = CaseSearch.highlights(texto, 'interp juz');
      expect(
        [for (final (a, b) in rangos) texto.substring(a, b)],
        ['intérp', 'juz'],
      );
    });
  });

  group('en la pantalla', () {
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

    Finder campo() => find.byKey(const Key('buscador_campo'));

    String escrito(WidgetTester tester) =>
        tester.widget<TextField>(campo()).controller!.text;

    testWidgets('al tocar la barra se pliega el título y aparecen '
        'sugerencias; una sugerencia queda escrita y editable', (tester) async {
      await seleccion(tester);
      expect(find.text('Selecciona el contexto'), findsOneWidget);
      expect(find.byKey(const Key('buscador_lupa')), findsOneWidget);

      await tester.tap(campo());
      await tester.pumpAndSettle();
      expect(find.text('Selecciona el contexto'), findsNothing);
      expect(find.byKey(const Key('buscador_salir')), findsOneWidget);
      expect(find.byKey(const Key('buscador_sugerencias')), findsOneWidget);

      await tester.tap(find.byKey(const Key('buscador_sugerencia_Cédula')));
      await tester.pumpAndSettle();
      expect(escrito(tester), 'Cédula');
      expect(find.text('Primera cédula de identidad'), findsOneWidget);

      // Sigue siendo texto de la persona: lo puede cambiar.
      await tester.enterText(campo(), 'Cédula renovar');
      await tester.pumpAndSettle();
      expect(find.text('Primera cédula de identidad'), findsNothing);
      expect(find.text('Renovar cédula próxima a vencer'), findsOneWidget);
    });

    testWidgets('lo que deja de coincidir se va con una animación, no de '
        'golpe', (tester) async {
      await seleccion(tester);
      await tester.enterText(campo(), 'rob');
      await tester.pumpAndSettle();
      const sale = 'Presentar denuncia verbal por robo';
      expect(find.text(sale), findsOneWidget);

      await tester.enterText(campo(), 'rob cel');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.text(sale), findsOneWidget, reason: 'todavía saliendo');
      await tester.pumpAndSettle();
      expect(find.text(sale), findsNothing);
      expect(find.text('Denunciar robo de celular'), findsOneWidget);
    });

    testWidgets('un caso encontrado entra directo; al volver, la búsqueda '
        'sigue escrita para corregirla', (tester) async {
      await seleccion(tester);
      await tester.enterText(campo(), 'robaron mi celu');
      await tester.pumpAndSettle();
      expect(find.text('TRÁMITES · FELCC'), findsOneWidget);

      await tester.tap(find.text('Denunciar robo de celular'));
      await tester.pumpAndSettle();
      expect(
        container.read(contextProvider)?.name,
        'Denunciar robo de celular',
      );

      // Volver (la pantalla se vuelve a montar): ahí sigue lo escrito.
      container.read(contextProvider.notifier).clearContext();
      await tester.pumpWidget(const SizedBox());
      await seleccion(tester);
      expect(escrito(tester), 'robaron mi celu');
      expect(find.text('Denunciar robo de celular'), findsOneWidget);
    });

    testWidgets('Enter abre el primer caso', (tester) async {
      await seleccion(tester);
      await tester.enterText(campo(), 'certificado nacimiento');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(container.read(contextProvider)?.name, contains('nacimiento'));
    });

    testWidgets('una institución encontrada abre su lista', (tester) async {
      await seleccion(tester);
      await tester.enterText(campo(), 'sereci');
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('buscador_section_tramites:SERECI')),
      );
      await tester.pumpAndSettle();
      expect(container.read(openSectionProvider), 'tramites:SERECI');
      expect(container.read(caseSearchQueryProvider), isEmpty);
      expect(find.text('Registrar una defunción'), findsOneWidget);
    });

    testWidgets('sin resultados lo dice y ofrece por dónde empezar', (
      tester,
    ) async {
      await seleccion(tester);
      await tester.enterText(campo(), 'xyzw');
      await tester.pumpAndSettle();
      expect(find.text('No encontramos «xyzw»'), findsOneWidget);
      expect(find.byKey(const Key('buscador_sugerencias')), findsOneWidget);
    });

    testWidgets('la × borra y deja seguir escribiendo; la flecha sale de la '
        'búsqueda', (tester) async {
      await seleccion(tester);
      await tester.enterText(campo(), 'violencia');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('buscador_borrar')));
      await tester.pumpAndSettle();
      expect(escrito(tester), isEmpty);
      expect(find.byKey(const Key('buscador_sugerencias')), findsOneWidget);

      await tester.tap(find.byKey(const Key('buscador_salir')));
      await tester.pumpAndSettle();
      expect(find.text('Selecciona el contexto'), findsOneWidget);
      expect(find.text('Denuncias'), findsOneWidget);
    });

    for (final (ancho, alto) in [(320.0, 640.0), (393.0, 851.0)]) {
      for (final escala in [1.0, 1.6, 2.0]) {
        testWidgets('${ancho.toInt()}×${alto.toInt()}, letra ×$escala: sin '
            'franja de desborde', (tester) async {
          tester.view.physicalSize = Size(ancho, alto);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                home: MediaQuery(
                  data: MediaQueryData(
                    size: Size(ancho, alto),
                    textScaler: TextScaler.linear(escala),
                  ),
                  child: const Scaffold(body: ContextSelectionWidget()),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(campo());
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: 'sugerencias');
          for (final q in [
            'interprete juzgado',
            'certificado',
            'violencia',
            'xyzw',
          ]) {
            await tester.enterText(campo(), q);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: q);
          }
        });
      }
    }
  });
}
