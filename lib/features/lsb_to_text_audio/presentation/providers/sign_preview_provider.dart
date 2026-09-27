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

  bool get isShowing => _active?.isActive ?? false;

  /// Previsualiza [glosses] en su orden y termina cuando la capa se cierra.
  ///
  /// Si ninguna glosa tiene seña ni deletreo en el avatar, avisa con
  /// discreción y no abre nada. Una vista previa anterior se cierra antes de
  /// abrir esta.
  Future<void> show(BuildContext context, List<String> glosses) async {
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
