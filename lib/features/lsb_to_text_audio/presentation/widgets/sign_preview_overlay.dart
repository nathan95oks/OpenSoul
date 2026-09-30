import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:lsb_legal_app/app/app_theme.dart';
import 'package:lsb_legal_app/core/domain/services/pending_sign.dart';
import 'package:lsb_legal_app/core/presentation/widgets/shared_avatar.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/domain/services/sign_preview_planner.dart';

/// Construye el reproductor de la vista previa. Llama a `onFinished` cuando
/// la secuencia termina o no se puede reproducir.
typedef SignPreviewPlayerBuilder =
    Widget Function(
      BuildContext context,
      SignPreviewPlan plan,
      VoidCallback onFinished,
    );

/// El avatar compartido de la app haciendo el plan una sola vez.
///
/// El visor avisa del fin con `onPlaybackStateChanged(false)`, tanto al
/// acabar la secuencia como si no llega a arrancar; su reloj de seguridad
/// garantiza que ese aviso llegue aunque el modelo no cargue. Sin seña (la
/// capa está escondida) no pide el avatar.
Widget avatarSignPreviewPlayer(
  BuildContext context,
  SignPreviewPlan plan,
  VoidCallback onFinished,
) {
  return SharedAvatarSlot(
    key: const ValueKey('sign_preview_avatar'),
    expandToFit: true,
    active: plan.glosses.isNotEmpty,
    request: AvatarRequest(
      // Sin volver ni repetir: la vista previa se cierra con su cruz,
      // tocando fuera o sola al terminar la seña.
      showControls: false,
      playbackRequestId: 1,
      isUserComposing: plan.glosses.isEmpty,
      glosses: plan.animationGlosses,
      animationUrls: plan.animationUrls,
      onPlaybackStateChanged: (playing) {
        if (!playing) onFinished();
      },
      onReturnToInput: onFinished,
    ),
  );
}

/// Capa temporal con el avatar haciendo la seña de una tarjeta.
///
/// Solo muestra: no elige ni quita la tarjeta. Se cierra sola al terminar la
/// seña; tocar fuera o el botón atrás también la cierran.
class SignPreviewOverlay extends StatefulWidget {
  final SignPreviewPlan plan;
  final SignPreviewPlayerBuilder player;
  final VoidCallback onFinished;

  /// Si la capa se ve. Mientras es `false` el avatar está cargado e
  /// invisible, sin enseñar nada; al pasar a `true` aparece con su velo y
  /// hace la seña de [plan]. Sin él, se ve desde el principio.
  final ValueListenable<bool>? visible;

  /// El plan de un visor que está cargado pero no enseña nada.
  static const emptyPlan = SignPreviewPlan(
    glosses: [],
    animationUrls: [],
    animationGlosses: [],
  );

  /// Pausa entre el final de la seña y el cierre, para que el último gesto
  /// no se corte en seco.
  static const closeDelay = Duration(milliseconds: 450);

  const SignPreviewOverlay({
    super.key,
    required this.plan,
    required this.player,
    required this.onFinished,
    this.visible,
  });

  @override
  State<SignPreviewOverlay> createState() => _SignPreviewOverlayState();
}

class _SignPreviewOverlayState extends State<SignPreviewOverlay> {
  Timer? _closeTimer;

  bool get _visible => widget.visible?.value ?? true;

  @override
  void initState() {
    super.initState();
    widget.visible?.addListener(_nuevaVista);
  }

  @override
  void didUpdateWidget(SignPreviewOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.visible, widget.visible)) {
      oldWidget.visible?.removeListener(_nuevaVista);
      widget.visible?.addListener(_nuevaVista);
    }
    // El mismo visor enseña otra seña: su cierre es otro.
    if (!identical(oldWidget.plan, widget.plan)) _nuevaVista();
  }

  /// Cada vez que se muestra o se esconde, el cierre de la anterior ya no
  /// cuenta.
  void _nuevaVista() {
    _closeTimer?.cancel();
    _closeTimer = null;
  }

  void _playerFinished() {
    // Mientras se prepara no hay seña que terminar.
    if (!_visible || _closeTimer != null) return;
    _closeTimer = Timer(SignPreviewOverlay.closeDelay, () {
      if (mounted) widget.onFinished();
    });
  }

  @override
  void dispose() {
    widget.visible?.removeListener(_nuevaVista);
    _closeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.visible;
    if (visible == null) return _capa(context, widget.plan);
    return ValueListenableBuilder<bool>(
      valueListenable: visible,
      builder: (context, seVe, _) => IgnorePointer(
        ignoring: !seVe,
        child: Opacity(
          opacity: seVe ? 1 : 0,
          child: Stack(
            children: [
              // El velo y el cierre al tocar fuera, como el de un diálogo.
              if (seVe)
                Positioned.fill(
                  child: GestureDetector(
                    onTap: widget.onFinished,
                    child: const ColoredBox(color: Colors.black54),
                  ),
                ),
              // El mismo visor antes y después: carga invisible sin glosas y
              // hace la seña al verse.
              _capa(context, seVe ? widget.plan : SignPreviewOverlay.emptyPlan),
            ],
          ),
        ),
      ),
    );
  }

  static String _legible(String gloss) => PendingSign.isPending(gloss)
      ? PendingSign.wordOf(gloss)
      : gloss.replaceAll('_', ' ');

  Widget _capa(BuildContext context, SignPreviewPlan plan) {
    final secuencia = plan.glosses.map(_legible).join(' · ');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
          child: Semantics(
            key: const Key('vista_previa_sena'),
            liveRegion: true,
            label: 'Vista previa de la seña: $secuencia',
            child: Material(
              color: AppTheme.darkBg,
              borderRadius: BorderRadius.circular(24),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.visibility_rounded,
                          size: 18,
                          color: Color(0xFFC084FC),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ExcludeSemantics(
                            child: Text(
                              secuencia,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.darkText,
                                letterSpacing: 0.25,
                                height: 1.2,
                              ),
                            ),
                          ),
                        ),
                        // Cerrar a la vista, además de tocar fuera o Atrás.
                        IconButton(
                          key: const Key('cerrar_vista_previa'),
                          tooltip: 'Cerrar vista previa',
                          onPressed: widget.onFinished,
                          icon: const Icon(
                            Icons.close_rounded,
                            color: AppTheme.darkText,
                          ),
                        ),
                      ],
                    ),
                    if (plan.missingGlosses.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Sin animación en el avatar: '
                          '${plan.missingGlosses.map(_legible).join(', ')}',
                          key: const Key('vista_previa_sin_animacion'),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.darkTextSub,
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),
                    Flexible(
                      child: SizedBox(
                        height: 460,
                        child: widget.player(context, plan, _playerFinished),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
