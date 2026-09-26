import 'dart:async';
import 'package:flutter/material.dart';

import 'package:lsb_legal_app/app/app_theme.dart';
import 'package:lsb_legal_app/core/domain/services/animation_url_resolver.dart';
import 'package:lsb_legal_app/core/presentation/widgets/avatar_3d_viewer.dart';

class AvatarPlaybackSheet extends StatefulWidget {
  final List<String> glosses;
  final List<String> animationUrls;
  final List<String>? animationGlosses;
  final bool autoDismissOnFinish;

  const AvatarPlaybackSheet({
    super.key,
    required this.glosses,
    required this.animationUrls,
    this.animationGlosses,
    this.autoDismissOnFinish = true,
  });

  static Future<void> show(
    BuildContext context, {
    required List<String> glosses,
    required List<String> animationUrls,
    List<String>? animationGlosses,
    bool autoDismissOnFinish = true,
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
      ),
    );
  }

  @override
  State<AvatarPlaybackSheet> createState() => _AvatarPlaybackSheetState();
}

class _AvatarPlaybackSheetState extends State<AvatarPlaybackSheet> {
  DateTime? _playbackStartedAt;
  Timer? _dismissTimer;

  void _onPlaybackStateChanged(bool playing) {
    if (playing) {
      _playbackStartedAt = DateTime.now();
      _dismissTimer?.cancel();
    } else if (_playbackStartedAt != null && widget.autoDismissOnFinish) {
      final elapsed = DateTime.now().difference(_playbackStartedAt!).inMilliseconds;
      // Solo auto-descartar si realmente se reprodujo la animación (al menos 1.8s)
      if (elapsed >= 1800) {
        _dismissTimer?.cancel();
        _dismissTimer = Timer(const Duration(milliseconds: 1500), () {
          if (mounted) {
            Navigator.of(context).maybePop();
          }
        });
      }
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
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    tooltip: 'Atrás',
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
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
                    child: Avatar3DViewer(
                      key: const ValueKey('sheet_avatar_viewer'),
                      isActive: true,
                      isProcessing: false,
                      expandToFit: true,
                      playbackRequestId: 1,
                      onPlaybackStateChanged: _onPlaybackStateChanged,
                      onReturnToInput: () {
                        if (mounted) Navigator.of(context).maybePop();
                      },
                      glosses: widget.animationGlosses?.isNotEmpty == true
                          ? widget.animationGlosses
                          : widget.glosses,
                      animationUrls: widget.animationUrls.isNotEmpty
                          ? widget.animationUrls
                          : widget.glosses
                              .expand((g) => const AnimationUrlResolver().resolveAll(gloss: g))
                              .toList(),
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
