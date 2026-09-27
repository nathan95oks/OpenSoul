import 'package:flutter/material.dart';

import 'package:lsb_legal_app/app/app_theme.dart';
import 'package:lsb_legal_app/core/domain/rag/rag_corpus.dart';
import 'package:lsb_legal_app/core/domain/rag/rag_retriever.dart';
import 'package:lsb_legal_app/core/presentation/widgets/motion.dart';
import 'package:lsb_legal_app/features/conversation/presentation/widgets/rag_suggestions_bar.dart';

/// La persona sorda abre la conversación preguntando por un trámite.
///
/// Primero elige la institución; después ve, por trámite, las frases que
/// usaron otras personas sordas en situaciones reales documentadas, con su
/// secuencia LSB. Devuelve la frase elegida, o `null` si cierra sin elegir.
class RagTopicsSheet extends StatefulWidget {
  final List<RagTopic> topics;

  final ScrollController? controller;

  const RagTopicsSheet({super.key, required this.topics, this.controller});

  static Future<RagSuggestion?> show(
    BuildContext context,
    List<RagTopic> topics,
  ) => showModalBottomSheet<RagSuggestion>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.framedSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, controller) => RagTopicsSheet(
        key: const Key('rag_tramites'),
        topics: topics,
        controller: controller,
      ),
    ),
  );

  @override
  State<RagTopicsSheet> createState() => _RagTopicsSheetState();
}

class _RagTopicsSheetState extends State<RagTopicsSheet> {
  RagTopic? _topic;

  void _choose(RagProcedure procedure, RagTurn phrase) {
    Navigator.of(context).pop(
      RagSuggestion(
        text: phrase.text,
        glosses: phrase.glosses,
        scenarioId: procedure.scenarioId,
        institution: _topic!.institution,
        procedure: procedure.title,
        score: 1,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topic = _topic;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 16, 4),
          child: Row(
            children: [
              if (topic != null)
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: AppTheme.ink),
                  tooltip: 'Otras instituciones',
                  onPressed: () => setState(() => _topic = null),
                )
              else
                const SizedBox(width: 12),
              Expanded(
                child: Text(
                  topic?.institution ?? 'Preguntar sobre un trámite',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: topic == null
                ? ListView(
                    key: const ValueKey('instituciones'),
                    controller: widget.controller,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Situaciones reales de Cochabamba. Elija la '
                          'institución.',
                          style: TextStyle(color: AppTheme.inkSub),
                        ),
                      ),
                      for (final (i, t) in widget.topics.indexed)
                        StaggeredEntrance(
                          index: i,
                          child: ListTile(
                            key: ValueKey('rag_area_${t.area}'),
                            title: Text(
                              t.institution,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppTheme.ink,
                              ),
                            ),
                            subtitle: Text(
                              t.procedures.map((p) => p.title).join(' · '),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppTheme.inkSub),
                            ),
                            trailing: const Icon(
                              Icons.chevron_right,
                              color: AppTheme.inkSub,
                            ),
                            onTap: () => setState(() => _topic = t),
                          ),
                        ),
                    ],
                  )
                : ListView(
                    key: ValueKey('tramites_${topic.area}'),
                    controller: widget.controller,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    children: [
                      for (final p in topic.procedures) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 12, bottom: 6),
                          child: Text(
                            p.title,
                            style: const TextStyle(
                              fontSize: 12,
                              letterSpacing: 0.6,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.inkSub,
                            ),
                          ),
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final phrase in p.phrases)
                              PressableScale(
                                child: RagPhraseCard(
                                  text: phrase.text,
                                  glosses: phrase.glosses,
                                  onTap: () => _choose(p, phrase),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
