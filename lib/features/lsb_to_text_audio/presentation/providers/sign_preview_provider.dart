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
  ref.onDispose(controller.close);
  return controller;
});

/// Muestra al avatar haciendo la seña de una tarjeta, de una en una.
///
/// Es una comprobación visual para la persona sorda antes de comunicar la
/// glosa: todo se resuelve en el dispositivo (sin traducir, sin Lambda ni
/// Bedrock) y no toca la selección ni la navegación del flujo guiado.
class SignPreviewController {
  final Ref ref;

  SignPreviewController(this.ref);

  Route<void>? _active;

  /// La vista previa que se está preparando mientras se mantiene la tarjeta.
  _Preparada? _prepared;

  bool get isShowing =>
      (_active?.isActive ?? false) || (_prepared?.visible.value ?? false);

  /// Empieza a cargar el avatar de [glosses] sin mostrarlo: la persona está
  /// manteniendo la tarjeta. Si la llena, [show] solo lo hace visible y la
  /// seña empieza sin la espera de cargar el visor; si suelta antes,
  /// [cancelPrepared] lo descarta sin que se note.
  ///
  /// Se carga en una capa superpuesta, no en una ruta: abrir una ruta cancela
  /// los gestos en curso y cortaba la pulsación que se estaba manteniendo.
  void prepare(BuildContext context, List<String> glosses) {
    final plan = ref.read(signPreviewPlannerProvider).plan(glosses);
    if (!plan.isPlayable) return;
    cancelPrepared();
    close();
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    final player = ref.read(signPreviewPlayerProvider);
    final preparada = _Preparada(
      glosses.join('|'),
      ModalRoute.of(context),
      overlay,
    );
    preparada.entry = OverlayEntry(
      builder: (_) => SignPreviewOverlay(
        plan: plan,
        player: player,
        visible: preparada.visible,
        onFinished: () => _cerrar(preparada),
      ),
    );
    _prepared = preparada;
    overlay.insert(preparada.entry!);
  }

  /// Descarta la vista previa preparada si no llegó a mostrarse.
  void cancelPrepared() {
    final preparada = _prepared;
    if (preparada != null && !preparada.visible.value) _cerrar(preparada);
  }

  void _cerrar(_Preparada preparada) {
    if (identical(_prepared, preparada)) _prepared = null;
    // Si la pantalla entera se está cerrando, la capa ya se va con ella.
    if (preparada.overlay.mounted) preparada.entry?.remove();
    preparada.entry = null;
    final historial = preparada.historial;
    preparada.historial = null;
    if (historial != null) preparada.route?.removeLocalHistoryEntry(historial);
    if (!preparada.cerrada.isCompleted) preparada.cerrada.complete();
  }

  /// Previsualiza [glosses] en su orden y termina cuando la capa se cierra.
  ///
  /// Si ninguna glosa tiene seña ni deletreo en el avatar, avisa con
  /// discreción y no abre nada. Una vista previa anterior se cierra antes de
  /// abrir esta.
  Future<void> show(BuildContext context, List<String> glosses) async {
    final preparada = _prepared;
    if (preparada != null &&
        preparada.key == glosses.join('|') &&
        preparada.entry != null) {
      // Ya cargado mientras se mantenía la tarjeta: solo se muestra. El botón
      // atrás del sistema la cierra, como a la vista previa de siempre.
      preparada.visible.value = true;
      final historial = LocalHistoryEntry(
        onRemove: () {
          preparada.historial = null;
          _cerrar(preparada);
        },
      );
      preparada.historial = historial;
      preparada.route?.addLocalHistoryEntry(historial);
      await preparada.cerrada.future;
      return;
    }
    cancelPrepared();
    final plan = ref.read(signPreviewPlannerProvider).plan(glosses);
    if (!plan.isPlayable) {
      AppToastManager.showInfo(context, 'Seña no disponible');
      return;
    }
    close();

    final player = ref.read(signPreviewPlayerProvider);
    late final DialogRoute<void> route;
    route = DialogRoute<void>(
      context: context,
      barrierLabel: 'Cerrar vista previa',
      builder: (_) => SignPreviewOverlay(
        plan: plan,
        player: player,
        onFinished: () => _dismiss(route),
      ),
    );
    _active = route;
    await Navigator.of(context, rootNavigator: true).push(route);
    if (identical(_active, route)) _active = null;
  }

  /// Cierra la vista previa abierta, si la hay.
  void close() {
    final preparada = _prepared;
    if (preparada != null) _cerrar(preparada);
    final route = _active;
    _active = null;
    if (route != null) _dismiss(route);
  }

  static void _dismiss(Route<void> route) {
    final navigator = route.navigator;
    if (navigator == null || !route.isActive) return;
    if (route.isCurrent) {
      navigator.pop();
    } else {
      navigator.removeRoute(route);
    }
  }
}

/// Una vista previa cargándose en una capa superpuesta.
class _Preparada {
  final String key;
  final ModalRoute<Object?>? route;
  final OverlayState overlay;
  final ValueNotifier<bool> visible = ValueNotifier(false);
  final Completer<void> cerrada = Completer<void>();
  OverlayEntry? entry;
  LocalHistoryEntry? historial;

  _Preparada(this.key, this.route, this.overlay);
}
