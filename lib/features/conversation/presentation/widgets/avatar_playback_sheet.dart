import 'package:flutter/material.dart';

import 'package:lsb_legal_app/app/theme.dart';
import 'package:lsb_legal_app/core/generators/avatar_generator/avatar_3d_viewer.dart';

/// Hoja modal que reproduce en el avatar 3D las señas de un turno de la
/// persona oyente. Reutiliza el visor de doble buffer del núcleo; no
/// duplica lógica de reproducción.
class AvatarPlaybackSheet extends StatelessWidget {
  final List<String> glosses;
  final List<String> animationUrls;

  const AvatarPlaybackSheet({
    super.key,
    required this.glosses,
    required this.animationUrls,
  });

  static Future<void> show(
    BuildContext context, {
    required List<String> glosses,
    required List<String> animationUrls,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AvatarPlaybackSheet(
        glosses: glosses,
        animationUrls: animationUrls,
      ),
    );
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
            const SizedBox(height: 10),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.darkBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 8, 6),
              child: Row(
                children: [
                  const Icon(Icons.sign_language,
                      color: AppTheme.brandElectric, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      glosses.join(' • '),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    color: AppTheme.darkSurface,
                    child: Avatar3DViewer(
                      isProcessing: false,
                      glosses: glosses,
                      animationUrls: animationUrls,
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
