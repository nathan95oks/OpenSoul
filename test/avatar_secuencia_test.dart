import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'package:lsb_legal_app/core/di/injection.dart'
    show animationRepositoryProvider;
import 'package:lsb_legal_app/core/domain/repositories/animation_repository.dart';
import 'package:lsb_legal_app/core/presentation/widgets/avatar_3d_viewer.dart';

import 'support/fake_webview_platform.dart';

/// Descarga que se puede demorar a voluntad.
class _Repo implements AnimationRepository {
  Completer<void>? espera;

  @override
  Future<List<String>> playableSources(List<String> animationUrls) async {
    await espera?.future;
    return animationUrls;
  }

  @override
  Future<bool> isCached(String url) async => true;

  @override
  Future<void> precacheDefaultModel() async {}
}

const _glosas = ['QUERER', 'TRAMITE', 'FIN'];
const _urls = ['m.glb', 'm.glb', 'm.glb'];

void main() {
  WebViewPlatform.instance = FakeWebViewPlatform();
  setUp(FakeWebViewPlatform.reset);

  late _Repo repo;

  Future<void> montar(WidgetTester tester, int pedido) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [animationRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 700,
              child: Avatar3DViewer(
                isProcessing: false,
                expandToFit: true,
                playbackRequestId: pedido,
                glosses: _glosas,
                animationUrls: _urls,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// El número del paso que el visor está reproduciendo, según el último
  /// JavaScript de seña que recibió.
  int? pasoEnCurso() {
    for (final s in FakeWebViewPlatform.scripts.reversed) {
      final m = RegExp(r'window\.__lsbStep = (-?\d+);').firstMatch(s);
      if (m != null && s.contains("window.__lsbMode = 'sign'")) {
        return int.parse(m.group(1)!);
      }
    }
    return null;
  }

  String? glosaEnCurso() {
    for (final s in FakeWebViewPlatform.scripts.reversed) {
      final m = RegExp(r"mv\.animationName = '([^']+)';").firstMatch(s);
      if (m != null && s.contains("window.__lsbMode = 'sign'")) {
        return m.group(1);
      }
    }
    return null;
  }

  /// El visor avisa que terminó la seña en curso. El visor ignora un «fin»
  /// que llega antes de 300 ms de real: se espera ese tiempo de verdad.
  Future<void> terminar(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 330)),
    );
    FakeWebViewPlatform.emit('finished:${pasoEnCurso()}');
    await tester.pump();
  }

  testWidgets('la secuencia pasa por todas las señas, en orden', (
    tester,
  ) async {
    repo = _Repo();
    await montar(tester, 1);
    await tester.pump();
    FakeWebViewPlatform.emit('loaded');
    await tester.pump();
    final vistas = <String?>[];
    for (var i = 0; i < _glosas.length; i++) {
      vistas.add(glosaEnCurso());
      await terminar(tester);
    }
    expect(vistas, _glosas);
    await tester.pumpAndSettle(const Duration(seconds: 8));
  });

  testWidgets('un aviso viejo del reposo no se come la primera seña de la '
      'siguiente frase', (tester) async {
    repo = _Repo();
    await montar(tester, 1);
    await tester.pump();
    FakeWebViewPlatform.emit('loaded');
    await tester.pump();
    // Se reproduce la primera frase completa.
    for (var i = 0; i < _glosas.length; i++) {
      await terminar(tester);
    }
    final tokenViejo = pasoEnCurso();
    FakeWebViewPlatform.scripts.clear();

    // Segunda frase: la descarga se demora…
    repo.espera = Completer<void>();
    await montar(tester, 2);
    await tester.pump();
    // …y justo entonces llega un «finished» atrasado del paso anterior (el
    // reposo o la última seña de la frase pasada).
    FakeWebViewPlatform.emit('finished:$tokenViejo');
    await tester.pump(const Duration(milliseconds: 50));
    repo.espera!.complete();
    await tester.pump();
    await tester.pump();

    // Empieza por la primera seña, no por la segunda.
    expect(glosaEnCurso(), 'QUERER');
    await tester.pumpAndSettle(const Duration(seconds: 8));
  });

  testWidgets('el reposo no arranca en medio de una frase', (tester) async {
    repo = _Repo();
    await montar(tester, 1);
    await tester.pump();
    FakeWebViewPlatform.emit('loaded');
    await tester.pump();
    final desde = FakeWebViewPlatform.scripts.length;

    // Llega el fin de un reposo anterior mientras se hace la primera seña.
    FakeWebViewPlatform.emit('neutral-finished');
    await tester.pump(const Duration(seconds: 1));
    expect(
      FakeWebViewPlatform.scripts
          .skip(desde)
          .where((s) => s.contains("window.__lsbMode = 'neutral'")),
      isEmpty,
    );
    expect(glosaEnCurso(), 'QUERER');

    // Entre una seña y otra tampoco.
    await terminar(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(
      FakeWebViewPlatform.scripts
          .skip(desde)
          .where((s) => s.contains("window.__lsbMode = 'neutral'")),
      isEmpty,
    );
    expect(glosaEnCurso(), 'TRAMITE');
    await tester.pumpAndSettle(const Duration(seconds: 8));
  });

  testWidgets('el reposo ya no deja un paso en curso para los avisos '
      'atrasados', (tester) async {
    repo = _Repo();
    await montar(tester, 1);
    await tester.pump();
    FakeWebViewPlatform.emit('loaded');
    await tester.pump();
    for (var i = 0; i < _glosas.length; i++) {
      await terminar(tester);
    }
    // Termina la frase: el reposo marca «sin paso» (-1) en el visor.
    await tester.pump(const Duration(seconds: 1));
    final reposo = FakeWebViewPlatform.scripts.where(
      (s) => s.contains("window.__lsbMode = 'neutral'"),
    );
    expect(reposo, isNotEmpty);
    expect(reposo.every((s) => s.contains('window.__lsbStep = -1;')), isTrue);
    await tester.pumpAndSettle(const Duration(seconds: 8));
  });
}
