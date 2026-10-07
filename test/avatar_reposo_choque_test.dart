import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'package:lsb_legal_app/core/di/injection.dart'
    show animationRepositoryProvider;
import 'package:lsb_legal_app/core/domain/repositories/animation_repository.dart';
import 'package:lsb_legal_app/core/presentation/widgets/avatar_3d_viewer.dart';

import 'support/fake_webview_platform.dart';

class _Repo implements AnimationRepository {
  @override
  Future<List<String>> playableSources(List<String> animationUrls) async =>
      animationUrls;

  @override
  Future<bool> isCached(String url) async => true;

  @override
  Future<void> precacheDefaultModel() async {}
}

const _glosas = ['QUERER', 'TRAMITE', 'FIN'];
const _urls = ['m.glb', 'm.glb', 'm.glb'];

/// Un `model-viewer` de mentira, para correr el JavaScript que manda la app.
/// Como el de verdad, `play()` reproduce la animación que esté puesta en
/// `animationName`, y aplicar un cambio de nombre termina en otra tarea (el
/// peor caso: otro JavaScript puede colarse en medio).
const _visorJs = r'''
const log = [];
class Visor {
  constructor() {
    this._name = null;
    this.paused = true;
    this._pendiente = null;
    this.availableAnimations = ['NEUTRO1', 'NEUTRO2', 'NEUTRO3',
      'QUERER', 'TRAMITE', 'FIN'];
    this.duration = 0.01;
    this.currentTime = 0;
  }
  set animationName(v) {
    if (v === this._name) return;
    this._name = v;
    if (!this._pendiente) {
      this._pendiente = new Promise((listo) => setTimeout(() => {
        this._pendiente = null;
        listo();
      }, 5));
    }
  }
  get animationName() { return this._name; }
  get updateComplete() { return this._pendiente || Promise.resolve(); }
  pause() { this.paused = true; log.push('pause'); }
  play() { this.paused = false; log.push('play:' + this._name); }
}
const mv = new Visor();
globalThis.window = globalThis;
globalThis.ModelViewerChannel = { postMessage: () => {} };
globalThis.document = { querySelector: () => mv };

const pasos = JSON.parse(require('fs').readFileSync(process.argv[2], 'utf8'));
(async () => {
  for (const paso of pasos) {
    if (paso.js) (0, eval)(paso.js);
    if (paso.esperar) await new Promise((r) => setTimeout(r, paso.esperar));
  }
  await new Promise((r) => setTimeout(r, 60));
  console.log(JSON.stringify(log));
})();
''';

bool _hayNode() {
  try {
    return Process.runSync('node', ['--version']).exitCode == 0;
  } catch (_) {
    return false;
  }
}

/// Corre [pasos] (`{js, esperar}`) en el visor de mentira y devuelve lo que
/// hizo: 'pause' y «play:» con el nombre de la animación, en orden.
Future<List<String>> _correr(List<Map<String, Object>> pasos) async {
  final dir = Directory.systemTemp.createTempSync('visor_');
  try {
    final visor = File('${dir.path}/visor.js')..writeAsStringSync(_visorJs);
    final datos = File('${dir.path}/pasos.json')
      ..writeAsStringSync(jsonEncode(pasos));
    final r = await Process.run('node', [visor.path, datos.path]);
    expect(r.exitCode, 0, reason: '${r.stderr}');
    return (jsonDecode((r.stdout as String).trim()) as List).cast<String>();
  } finally {
    dir.deleteSync(recursive: true);
  }
}

bool _esReposo(String s) => s.contains("window.__lsbMode = 'neutral'");

void main() {
  WebViewPlatform.instance = FakeWebViewPlatform();
  setUp(FakeWebViewPlatform.reset);

  Future<void> montar(WidgetTester tester, {bool frase = false}) =>
      tester.pumpWidget(
        ProviderScope(
          overrides: [animationRepositoryProvider.overrideWithValue(_Repo())],
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 700,
                child: Avatar3DViewer(
                  isProcessing: false,
                  expandToFit: true,
                  playbackRequestId: frase ? 1 : 0,
                  glosses: frase ? _glosas : null,
                  animationUrls: frase ? _urls : null,
                ),
              ),
            ),
          ),
        ),
      );

  /// El paso en curso, según el último JavaScript de seña.
  int? pasoEnCurso() {
    for (final s in FakeWebViewPlatform.scripts.reversed) {
      final m = RegExp(r'window\.__lsbStep = (-?\d+);').firstMatch(s);
      if (m != null && s.contains("window.__lsbMode = 'sign'")) {
        return int.parse(m.group(1)!);
      }
    }
    return null;
  }

  /// Lo que la app le manda al visor: el reposo con el avatar quieto, el
  /// comienzo de la frase y lo que sigue hasta el reposo de después.
  Future<(String, List<String>, List<String>)> grabar(
    WidgetTester tester,
  ) async {
    await montar(tester);
    await tester.pump();
    FakeWebViewPlatform.emit('loaded');
    await tester.pump();
    final reposo = FakeWebViewPlatform.scripts.lastWhere(_esReposo);

    FakeWebViewPlatform.scripts.clear();
    await montar(tester, frase: true);
    await tester.pump();
    await tester.pump();
    final inicio = List<String>.of(FakeWebViewPlatform.scripts);

    final desde = FakeWebViewPlatform.scripts.length;
    for (var i = 0; i < _glosas.length; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 330)),
      );
      FakeWebViewPlatform.emit('finished:${pasoEnCurso()}');
      await tester.pump();
    }
    await tester.pump(const Duration(seconds: 1));
    final fin = FakeWebViewPlatform.scripts.sublist(desde);
    return (reposo, inicio, fin);
  }

  testWidgets('un reposo que se cuela al empezar la frase no reemplaza a la '
      'seña: el avatar hace QUERER, no el reposo', (tester) async {
    final (reposo, inicio, fin) = await grabar(tester);
    expect(inicio.where((s) => s.contains("'QUERER'")), isNotEmpty);

    final hecho = (await tester.runAsync(
      () => _correr([
        // El avatar está en reposo…
        {'js': reposo, 'esperar': 20},
        // …empieza la frase y, mientras el visor aplica QUERER, llega un
        // reposo atrasado.
        for (final s in inicio) {'js': s},
        {'js': reposo, 'esperar': 30},
      ]),
    ))!;
    final desdeLaFrase = hecho.sublist(hecho.lastIndexOf('pause'));
    expect(desdeLaFrase.where((e) => e.startsWith('play:')), [
      'play:QUERER',
    ], reason: '$hecho');
    await tester.pump(const Duration(seconds: 8));
  }, skip: !_hayNode());

  testWidgets('al terminar la frase el reposo vuelve, desde quieto', (
    tester,
  ) async {
    final (reposo, inicio, fin) = await grabar(tester);
    expect(fin.where(_esReposo), isNotEmpty);

    final hecho = (await tester.runAsync(
      () => _correr([
        {'js': reposo, 'esperar': 20},
        for (final s in inicio) {'js': s},
        {'esperar': 20},
        for (final s in fin) {'js': s, 'esperar': 20},
      ]),
    ))!;
    final jugadas = hecho.where((e) => e.startsWith('play:')).toList();
    expect(jugadas.sublist(jugadas.length - 4, jugadas.length - 1), [
      'play:QUERER',
      'play:TRAMITE',
      'play:FIN',
    ]);
    // El último, el reposo; y el avatar se detuvo antes de empezarlo (sin el
    // fundido con la seña anterior).
    expect(jugadas.last, startsWith('play:NEUTRO'));
    final i = hecho.lastIndexOf(jugadas.last);
    expect(hecho[i - 1], 'pause', reason: '$hecho');
    await tester.pump(const Duration(seconds: 8));
  }, skip: !_hayNode());
}
