import 'package:flutter/material.dart';

import 'package:lsb_legal_app/app/app_theme.dart';

class QuickReplyBar extends StatelessWidget {
  final void Function(List<String> glosses, String text) onReply;

  const QuickReplyBar({super.key, required this.onReply});

  static const _respuestas = <({String etiqueta, IconData icono, List<String> glosas, String texto})>[
    (
      etiqueta: 'Entendido',
      icono: Icons.check_circle_outline,
      glosas: ['SI'],
      texto: 'Sí, entendido.',
    ),
    (
      etiqueta: '¿Dónde queda?',
      icono: Icons.place_outlined,
      glosas: ['DONDE'],
      texto: '¿Dónde queda?',
    ),
    (
      etiqueta: '¿Puede repetir?',
      icono: Icons.replay,
      glosas: ['PUEDE_REPETIR'],
      texto: '¿Puede repetir, por favor?',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Responder rápido',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 0.6,
              fontWeight: FontWeight.w700,
              color: AppTheme.darkTextSub,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final r in _respuestas)
                ActionChip(
                  avatar: Icon(r.icono, size: 18, color: AppTheme.brandLight),
                  label: Text(r.etiqueta),
                  onPressed: () => onReply(r.glosas, r.texto),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
