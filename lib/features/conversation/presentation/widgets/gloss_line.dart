import 'package:flutter/material.dart';

import 'package:lsb_legal_app/core/domain/services/pending_sign.dart';

/// La secuencia LSB de un mensaje. Las palabras sin seña en el catálogo van
/// con [pendingColor] y la palabra en español, no deletreadas.
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
                  TextSpan(
                    text: PendingSign.wordOf(g),
                    style: TextStyle(color: pendingColor),
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
              'En azul: ${PendingSign.label.toLowerCase()}',
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
