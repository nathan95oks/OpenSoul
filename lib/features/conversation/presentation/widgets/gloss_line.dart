import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lsb_legal_app/core/di/injection.dart'
    show pendingSignCatalogProvider;
import 'package:lsb_legal_app/core/domain/services/pending_sign.dart';
import 'package:lsb_legal_app/core/presentation/widgets/pending_sign_info_sheet.dart';

/// La secuencia LSB de un mensaje. Las palabras sin seña en el catálogo van
/// con [pendingColor] y la palabra en español, no deletreadas; tocarlas o
/// deslizarlas explica qué son.
class GlossLine extends StatelessWidget {
  final List<String> glosses;
  final TextStyle style;
  final Color pendingColor;
  final String separator;

  const GlossLine({
    super.key,
    required this.glosses,
    required this.style,
    required this.pendingColor,
    this.separator = ' • ',
  });

  @override
  Widget build(BuildContext context) {
    final pendientes = glosses.any(PendingSign.isPending);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(
          TextSpan(
            children: [
              for (final (i, g) in glosses.indexed) ...[
                if (i > 0) TextSpan(text: separator),
                if (PendingSign.isPending(g))
                  WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: Consumer(
                      builder: (context, ref, _) {
                        Future<void> explicar() => showPendingSignInfo(
                          context,
                          ref.read(pendingSignCatalogProvider.future),
                          [g],
                        );
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: explicar,
                          onHorizontalDragEnd: (_) => explicar(),
                          child: Text(
                            PendingSign.wordOf(g),
                            style: style.copyWith(
                              color: pendingColor,
                              decoration: TextDecoration.underline,
                              decorationColor: pendingColor,
                            ),
                          ),
                        );
                      },
                    ),
                  )
                else
                  TextSpan(text: g.replaceAll('_', ' ')),
              ],
            ],
          ),
          style: style,
        ),
        if (pendientes)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              'En azul: ${PendingSign.label.toLowerCase()} (tóquela para '
              'ver qué es)',
              style: style.copyWith(
                color: pendingColor,
                fontSize: (style.fontSize ?? 11) - 1,
                fontWeight: FontWeight.w500,
                letterSpacing: 0,
              ),
            ),
          ),
      ],
    );
  }
}
