import 'package:flutter/material.dart';

import 'package:lsb_legal_app/app/app_theme.dart';
import 'package:lsb_legal_app/core/domain/rag/rag_retriever.dart';
import 'package:lsb_legal_app/core/presentation/widgets/motion.dart';

/// Respuestas documentadas en situaciones reales parecidas a lo que dijo el
/// funcionario, cuando el grafo no lo reconoce.
///
/// Cada tarjeta muestra la frase y su secuencia LSB. La persona elige; nada
/// se envía solo. Se nombra la institución de la situación para que se vea
/// de dónde sale la sugerencia.
class RagSuggestionsBar extends StatelessWidget {
  final List<RagSuggestion> suggestions;
  final void Function(RagSuggestion suggestion) onReply;

  const RagSuggestionsBar({
    super.key,
    required this.suggestions,
    required this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    final institutions = {for (final s in suggestions) s.institution};
    return Padding(
      key: const Key('rag_situaciones'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            institutions.length == 1
                ? 'Situaciones parecidas · ${institutions.single}'
                : 'Situaciones parecidas',
            style: const TextStyle(
              fontSize: 11,
              letterSpacing: 0.6,
              fontWeight: FontWeight.w700,
              color: AppTheme.inkSub,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (i, s) in suggestions.indexed)
                StaggeredEntrance(
                  key: ValueKey('${s.scenarioId}#${s.text}'),
                  index: i,
                  child: PressableScale(
                    child: _SuggestionCard(
                      suggestion: s,
                      onTap: () => onReply(s),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  final RagSuggestion suggestion;
  final VoidCallback onTap;

  const _SuggestionCard({required this.suggestion, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: suggestion.text,
      excludeSemantics: true,
      child: Material(
        color: AppTheme.framedSurface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 260),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppTheme.lsbViolet.withValues(alpha: 0.45),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  suggestion.text,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  suggestion.glosses.join(' · '),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.lsbViolet,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
