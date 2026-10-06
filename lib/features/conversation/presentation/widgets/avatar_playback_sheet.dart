import 'dart:async';
import 'package:flutter/material.dart';

import 'package:lsb_legal_app/app/app_theme.dart';
import 'package:lsb_legal_app/core/domain/services/animation_url_resolver.dart';
import 'package:lsb_legal_app/core/presentation/widgets/shared_avatar.dart';

class AvatarPlaybackSheet extends StatefulWidget {
  static const dismissDelay = Duration(milliseconds: 180);

  final List<String> glosses;
  final List<String> animationUrls;
  final List<String>? animationGlosses;
  final bool autoDismissOnFinish;
  final Duration animationDuration;

  const AvatarPlaybackSheet({
    super.key,
    required this.glosses,
    required this.animationUrls,
    this.animationGlosses,
    this.autoDismissOnFinish = true,
    this.animationDuration = const Duration(seconds: 3),
  });

  static Future<void> show(
    BuildContext context, {
    required List<String> glosses,
    required List<String> animationUrls,
    List<String>? animationGlosses,
    bool autoDismissOnFinish = true,
    Duration animationDuration = const Duration(seconds: 3),
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AvatarPlaybackSheet(
        glosses: glosses,
        animationUrls: animationUrls,
        animationGlosses: animationGlosses,
        autoDismissOnFinish: autoDismissOnFinish,
        animationDuration: animationDuration,
      ),
    );
  }

  @override
  State<AvatarPlaybackSheet> createState() => _AvatarPlaybackSheetState();
}

class _AvatarPlaybackSheetState extends State<AvatarPlaybackSheet> {
  bool _playbackStarted = false;
  Timer? _dismissTimer;

  // Calculadas una vez: el avatar compartido reinicia la seña si cambia la
  // lista (no su contenido), y la hoja se reconstruye mientras se desliza.
  late final List<String> _glosses = widget.animationGlosses?.isNotEmpty == true
      ? widget.animationGlosses!
      : widget.glosses;
  late final List<String> _animationUrls = widget.animationUrls.isNotEmpty
      ? widget.animationUrls
      : widget.glosses
            .expand((g) => const AnimationUrlResolver().resolveAll(gloss: g))
            .toList();

  void _onPlaybackStateChanged(bool playing) {
    if (playing) {
      _playbackStarted = true;
      _dismissTimer?.cancel();
    } else if (_playbackStarted && widget.autoDismissOnFinish) {
      _playbackStarted = false;
      _dismissTimer?.cancel();
      _dismissTimer = Timer(AvatarPlaybackSheet.dismissDelay, () {
        if (mounted) Navigator.of(context).maybePop();
      });
    }
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.75;
    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: AppTheme.darkBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
              child: Row(
                children: [
                  // Sin flecha: la hoja se cierra deslizándola o al terminar
                  // la seña. El hueco mantiene centrada la manija.
                  const SizedBox(width: 48),
                  const Spacer(),
                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.darkBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    color: AppTheme.darkSurface,
                    // El avatar compartido de la app: ya está cargado, no
                    // se vuelve a cargar el modelo cada vez que se abre.
                    child: SharedAvatarSlot(
                      key: const ValueKey('sheet_avatar_viewer'),
                      expandToFit: true,
                      request: AvatarRequest(
                        showControls: false,
                        // Esta hoja representa un turno, no el avatar en
                        // reposo: al terminar debe volver al chat sin ejecutar
                        // NEUTRO1..3 durante la transición de cierre.
                        isUserComposing: true,
                        animationDuration: widget.animationDuration,
                        playbackRequestId: 1,
                        onPlaybackStateChanged: _onPlaybackStateChanged,
                        onReturnToInput: () {
                          if (mounted) Navigator.of(context).maybePop();
                        },
                        glosses: _glosses,
                        animationUrls: _animationUrls,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
