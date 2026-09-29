import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:lsb_legal_app/app/app_theme.dart';
import 'package:lsb_legal_app/core/domain/services/pending_sign.dart';
import 'package:lsb_legal_app/core/presentation/widgets/avatar_3d_viewer.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/domain/services/sign_preview_planner.dart';

/// Construye el reproductor de la vista previa. Llama a `onFinished` cuando
/// la secuencia termina o no se puede reproducir.
typedef SignPreviewPlayerBuilder =
    Widget Function(
      BuildContext context,
      SignPreviewPlan plan,
      VoidCallback onFinished,
    );

/// El avatar de siempre haciendo el plan una sola vez.
///
/// [Avatar3DViewer] avisa del fin con `onPlaybackStateChanged(false)`, tanto
/// al acabar la secuencia como si no llega a arrancar; su reloj de seguridad
/// por paso garantiza que ese aviso llegue aunque el modelo no cargue.
Widget avatarSignPreviewPlayer(
  BuildContext context,
  SignPreviewPlan plan,
  VoidCallback onFinished,
) {
  return Avatar3DViewer(
    key: const ValueKey('sign_preview_avatar'),
    isProcessing: false,
    expandToFit: true,
    // Sin volver ni repetir: la vista previa se cierra con su cruz, tocando
    // fuera o sola al terminar la seña.
    showControls: false,
    playbackRequestId: 1,
    glosses: plan.animationGlosses,
    animationUrls: plan.animationUrls,
    onPlaybackStateChanged: (playing) {
      if (!playing) onFinished();
    },
    onReturnToInput: onFinished,
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

  /// Si la capa se ve. Mientras es `false` el avatar se carga invisible y
  /// sin enseñar nada (se está manteniendo la tarjeta); al pasar a `true`
  /// aparece con su velo y hace la seña. Sin él, se ve desde el principio.
  final ValueListenable<bool>? visible;

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

  void _playerFinished() {
    // Mientras se prepara no hay seña que terminar.
    if (!_visible || _closeTimer != null) return;
    _closeTimer = Timer(SignPreviewOverlay.closeDelay, () {
      if (mounted) widget.onFinished();
    });
  }

  @override
  void dispose() {
    _closeTimer?.cancel();
    super.dispose();
  }

  static const _vacio = SignPreviewPlan(
    glosses: [],
    animationUrls: [],
    animationGlosses: [],
  );

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
              _capa(context, seVe ? widget.plan : _vacio),
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
