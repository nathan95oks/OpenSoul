import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme.dart';
import '../../domain/entities/lsb_card.dart';
import '../providers/cards_provider.dart';
import '../providers/semantic_zones_provider.dart';
import '../providers/sentence_provider.dart';
import 'lsb_icons.dart';

/// Cuántas opciones de respuesta se muestran por pregunta en modo guiado.
const int _kAnswersPerQuestion = 6;

/// Provider local: si el usuario activó "ver todas las opciones",
/// dejamos de truncar la lista a 6.
class ExpandedAnswersNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void expand() => state = true;
  void collapse() => state = false;
}

final expandedAnswersProvider = NotifierProvider<ExpandedAnswersNotifier, bool>(
  ExpandedAnswersNotifier.new,
);

/// Grid de respuestas guiadas a la pregunta activa.
///
/// Por defecto muestra hasta [_kAnswersPerQuestion] opciones (las más
/// relevantes según el motor semántico). Al tocar una tarjeta:
/// 1. La glosa se añade al relato.
/// 2. El motor avanza automáticamente a la siguiente pregunta.
///
/// Si el usuario no encuentra su respuesta, puede pulsar "Ver más
/// opciones" para expandir el catálogo completo de la categoría.
class CardGrid extends ConsumerWidget {
  const CardGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardsAsync = ref.watch(dynamicCardsProvider);
    final expanded = ref.watch(expandedAnswersProvider);
    final zonesState = ref.watch(semanticZonesProvider);
    final activeZone = zonesState.activeZone;
    final flowComplete = zonesState.isFlowComplete;
    final maxPicks = activeZone?.maxPicks ?? 1;
    final showPairHint = maxPicks > 1 && !flowComplete;

    return cardsAsync.when(
      data: (cards) {
        if (cards.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Text(
                'No hay opciones disponibles para esta pregunta.\nUsa "Saltar" o "Terminé y traducir".',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.lightTextSub, fontSize: 13),
              ),
            ),
          );
        }

        if (flowComplete) {
          return const _FlowCompleteBanner();
        }

        final visible = expanded
            ? cards
            : cards.take(_kAnswersPerQuestion).toList();
        final hasMore = !expanded && cards.length > _kAnswersPerQuestion;

        return Column(
          children: [
            if (showPairHint)
              _PairPickHint(
                current: zonesState.picksInActiveZone,
                max: maxPicks,
              ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.4,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: visible.length,
              itemBuilder: (context, index) {
                final card = visible[index];
                return _AnswerCard(
                  card: card,
                  onTap: () => _onAnswerPicked(ref, card, cards),
                );
              },
            ),
            if (hasMore)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: TextButton.icon(
                  onPressed: () =>
                      ref.read(expandedAnswersProvider.notifier).expand(),
                  icon: const Icon(
                    Icons.expand_more,
                    size: 18,
                    color: AppTheme.lightTextSub,
                  ),
                  label: Text(
                    'Ver más opciones (${cards.length - _kAnswersPerQuestion})',
                    style: const TextStyle(
                      color: AppTheme.lightTextSub,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Text(
            'Error al cargar opciones',
            style: TextStyle(color: AppTheme.errorLight),
          ),
        ),
      ),
    );
  }

  /// Selecciona/deselecciona la glosa en la zona activa, sin avanzar de
  /// pregunta (el avance es explícito vía "Continuar"). Tras el toggle
  /// reconstruye la secuencia en orden narrativo.
  ///
  /// Se almacena la GLOSA limpia (no el displayText), porque tanto el
  /// backend (GLOSS_LEXICON) como el LocalSentenceAssembler indexan por
  /// glosa.
  void _onAnswerPicked(WidgetRef ref, LsbCard card, List<LsbCard> allCards) {
    final notifier = ref.read(semanticZonesProvider.notifier);
    notifier.toggleAnswer(card.gloss);
    ref.read(sentenceProvider.notifier).setWords(notifier.orderedGlosses());
  }
}

/// Pista visible en zonas que permiten emparejar dos cards
/// (apariencia, vestimenta). Informa cuántos picks lleva el usuario en
/// la zona actual sin entorpecer la selección.
class _PairPickHint extends StatelessWidget {
  final int current;
  final int max;
  const _PairPickHint({required this.current, required this.max});

  @override
  Widget build(BuildContext context) {
    final remaining = max - current;
    final label = current == 0
        ? 'Puedes elegir hasta $max cards para describir mejor'
        : 'Card $current de $max — toca otra para complementar, o salta';
    final color = remaining > 0
        ? AppTheme.brandPrimary
        : AppTheme.lightTextSub;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Icon(Icons.add_circle_outline, size: 14, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Banner mostrado cuando el usuario terminó de responder todas las
/// preguntas. Reemplaza el grid de cards para impedir agregar más
/// glosas accidentalmente; invita a traducir o a editar respuestas
/// anteriores tocando un chip de pregunta en la barra superior.
class _FlowCompleteBanner extends StatelessWidget {
  const _FlowCompleteBanner();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.successLight.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppTheme.successLight.withValues(alpha: 0.4),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: AppTheme.successLight, size: 28),
            const SizedBox(height: 8),
            const Text(
              'Respondiste todas las preguntas',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppTheme.lightText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Pulsa "TERMINÉ Y TRADUCIR" o toca una pregunta de la barra para editar tu respuesta.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.lightTextSub,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnswerCard extends StatelessWidget {
  final LsbCard card;
  final VoidCallback onTap;
  const _AnswerCard({required this.card, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isEmergency = card.isEmergency;
    final accent = isEmergency ? AppTheme.errorLight : AppTheme.brandPrimary;

    // A11Y-01: el lector de pantalla anuncia la tarjeta como un botón con su
    // significado; el ícono es decorativo y se excluye (excludeSemantics).
    return Semantics(
      button: true,
      label: isEmergency
          ? '${card.displayText}, opción de emergencia'
          : card.displayText,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.lightSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accent.withValues(alpha: 0.35)),
            boxShadow: AppTheme.cardShadow,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  kLsbIconMap[card.semanticIcon] ?? Icons.credit_card,
                  size: 22,
                  color: accent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  card.displayText,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.lightText,
                    letterSpacing: 0.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
