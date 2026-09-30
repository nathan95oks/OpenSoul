import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lsb_legal_app/features/lsb_to_text_audio/domain/services/sign_preview_planner.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/app_toast_manager.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/sign_preview_overlay.dart';

final signPreviewPlannerProvider = Provider<SignPreviewPlanner>(
  (ref) => const SignPreviewPlanner(),
);

/// Reproductor de la vista previa. Las pruebas lo sustituyen por un doble
/// para no depender del WebView ni del modelo 3D.
final signPreviewPlayerProvider = Provider<SignPreviewPlayerBuilder>(
  (ref) => avatarSignPreviewPlayer,
);

final signPreviewControllerProvider = Provider<SignPreviewController>((ref) {
  final controller = SignPreviewController(ref);
  ref.onDispose(controller.release);
  return controller;
});

/// Muestra al avatar haciendo la seña de una tarjeta, de una en una.
///
/// Es una comprobación visual para la persona sorda antes de comunicar la
/// glosa: todo se resuelve en el dispositivo (sin traducir, sin Lambda ni
/// Bedrock) y no toca la selección ni la navegación del flujo guiado.
///
/// Todas las señas están horneadas en un mismo modelo (`avatar_test.glb`,
/// ~24 MB): lo lento es abrir el visor y cargar ese modelo, no cada seña.
/// Por eso hay **un solo visor**, en una capa superpuesta: se carga al entrar
/// a una sección ([warmUp]) y se queda invisible y quieto entre pantalla y
/// pantalla. Cada vista previa solo le cambia la seña y lo muestra; al
/// terminar vuelve a esconderse, cargado para la siguiente. Al salir de la
/// sección, abrir el resultado o cambiar de pestaña se suelta ([release]).
///
/// Es una capa y no una ruta: abrir una ruta cancela el gesto en curso, y el
/// visor dentro de una ruta nueva tardaba en cargar el modelo y la seña no
/// llegaba a verse.
class SignPreviewController {
  final Ref ref;

  SignPreviewController(this.ref);

  _Visor? _visor;

  /// La vista previa a la vista, si la hay.
  _Mostrada? _mostrada;

  bool get isShowing => _visor?.visible.value ?? false;

  /// Si hay un visor cargado (o cargándose), a la vista o no.
  bool get isLoaded => _visor != null;

  /// Deja el avatar cargado e invisible para las vistas previas que vengan:
  /// se llama al entrar a una sección. Se queda aunque se cambie de pantalla
  /// hasta [release].
  void warmUp(BuildContext context) {
    final visor = _abrir(context);
    visor?.keep = true;
  }

  /// Empieza a cargar el avatar porque se está deslizando una fila. Si la
  /// sección ya lo tenía cargado, no hace nada: está listo.
  void prepare(BuildContext context, List<String> glosses) {
    if (!ref.read(signPreviewPlannerProvider).plan(glosses).isPlayable) return;
    _abrir(context);
  }

  /// El deslizamiento no llegó al umbral. Un visor que la sección mantiene
  /// cargado se queda; uno abierto solo para este gesto se suelta.
  void cancelPrepared() {
    final visor = _visor;
    if (visor != null && !visor.keep && !visor.visible.value) release();
  }

  /// Previsualiza [glosses] en su orden y termina cuando la capa se cierra.
  ///
  /// Si ninguna glosa tiene seña ni deletreo en el avatar, avisa con
  /// discreción y no abre nada. Una vista previa anterior se cierra antes.
  Future<void> show(BuildContext context, List<String> glosses) async {
    final plan = ref.read(signPreviewPlannerProvider).plan(glosses);
    if (!plan.isPlayable) {
      cancelPrepared();
      AppToastManager.showInfo(context, 'Seña no disponible');
      return;
    }
    close();
    final visor = _abrir(context);
    if (visor == null) return;

    final mostrada = _Mostrada(ModalRoute.of(context));
    _mostrada = mostrada;
    visor.plan = plan;
    visor.entry?.markNeedsBuild();
    visor.visible.value = true;
    // El botón atrás del sistema la cierra.
    final historial = LocalHistoryEntry(
      onRemove: () {
        mostrada.historial = null;
        _terminar(mostrada);
      },
    );
    mostrada.historial = historial;
    mostrada.route?.addLocalHistoryEntry(historial);
    await mostrada.cerrada.future;
  }

  /// Cierra la vista previa a la vista, si la hay. El visor que la sección
  /// mantiene cargado se queda; uno abierto solo para ella se suelta.
  void close() {
    final mostrada = _mostrada;
    if (mostrada != null) _terminar(mostrada);
  }

  /// Suelta el visor por completo (sale de la sección, cambia de pestaña).
  void release() {
    close();
    final visor = _visor;
    _visor = null;
    if (visor == null) return;
    if (visor.overlay.mounted) visor.entry?.remove();
    visor.entry = null;
  }

  /// El visor cargado o, si no lo hay, uno nuevo e invisible.
  _Visor? _abrir(BuildContext context) {
    final actual = _visor;
    if (actual != null && actual.overlay.mounted && actual.entry != null) {
      return actual;
    }
    _visor = null;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return null;
    final player = ref.read(signPreviewPlayerProvider);
    final visor = _Visor(overlay);
    visor.entry = OverlayEntry(
      builder: (_) => SignPreviewOverlay(
        plan: visor.plan,
        player: player,
        visible: visor.visible,
        onFinished: () {
          final mostrada = _mostrada;
          if (mostrada != null) _terminar(mostrada);
        },
      ),
    );
    _visor = visor;
    overlay.insert(visor.entry!);
    return visor;
  }

  void _terminar(_Mostrada mostrada) {
    if (identical(_mostrada, mostrada)) _mostrada = null;
    final visor = _visor;
    if (visor != null) {
      visor.visible.value = false;
      visor.plan = SignPreviewOverlay.emptyPlan;
      if (visor.overlay.mounted) visor.entry?.markNeedsBuild();
      if (!visor.keep) release();
    }
    final historial = mostrada.historial;
    mostrada.historial = null;
    final route = mostrada.route;
    // Con la pantalla ya destruida no hay historial que limpiar.
    if (historial != null &&
        route != null &&
        (visor?.overlay.mounted ?? false) &&
        route.isActive) {
      route.removeLocalHistoryEntry(historial);
    }
    if (!mostrada.cerrada.isCompleted) mostrada.cerrada.complete();
  }
}

/// El visor de la vista previa en su capa: invisible y quieto mientras no se
/// muestra nada.
class _Visor {
  final OverlayState overlay;
  final ValueNotifier<bool> visible = ValueNotifier(false);
  SignPreviewPlan plan = SignPreviewOverlay.emptyPlan;
  OverlayEntry? entry;

  /// La sección lo mantiene cargado entre vistas previas.
  bool keep = false;

  _Visor(this.overlay);
}

/// Una vista previa a la vista.
class _Mostrada {
  final ModalRoute<Object?>? route;
  final Completer<void> cerrada = Completer<void>();
  LocalHistoryEntry? historial;

  _Mostrada(this.route);
}
