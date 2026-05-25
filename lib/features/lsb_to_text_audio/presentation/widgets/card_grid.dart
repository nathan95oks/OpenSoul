import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/lsb_card.dart';
import '../providers/cards_provider.dart';
import '../providers/semantic_zones_provider.dart';
import '../providers/sentence_provider.dart';

/// Cuántas opciones de respuesta se muestran por pregunta en modo guiado.
///
/// El docente sugirió un flujo encadenado pregunta → respuesta para
/// reducir la carga cognitiva del usuario sordo. Mostrar pocas opciones
/// (no toda la categoría) es la materialización directa de esa idea.
const int _kAnswersPerQuestion = 6;

/// Mapa de nombres de ícono a IconData para tarjetas.
const _iconMap = <String, IconData>{
  'person': Icons.person, 'child_care': Icons.child_care, 'woman': Icons.woman,
  'man': Icons.man, 'people': Icons.people, 'family_restroom': Icons.family_restroom,
  'front_hand': Icons.front_hand, 'record_voice_over': Icons.record_voice_over,
  'assignment': Icons.assignment, 'send': Icons.send, 'help': Icons.help,
  'payments': Icons.payments, 'autorenew': Icons.autorenew,
  'app_registration': Icons.app_registration, 'how_to_reg': Icons.how_to_reg,
  'download': Icons.download, 'upload': Icons.upload, 'draw': Icons.draw,
  'article': Icons.article, 'workspace_premium': Icons.workspace_premium,
  'description': Icons.description, 'badge': Icons.badge,
  'child_friendly': Icons.child_friendly, 'favorite': Icons.favorite,
  'sentiment_very_dissatisfied': Icons.sentiment_very_dissatisfied,
  'directions_car': Icons.directions_car, 'receipt_long': Icons.receipt_long,
  'content_copy': Icons.content_copy, 'flight': Icons.flight,
  'verified_user': Icons.verified_user,
  'question_answer': Icons.question_answer, 'feedback': Icons.feedback,
  'event': Icons.event, 'confirmation_number': Icons.confirmation_number,
  'today': Icons.today, 'access_time': Icons.access_time,
  'history': Icons.history, 'wb_sunny': Icons.wb_sunny,
  'wb_twilight': Icons.wb_twilight, 'date_range': Icons.date_range,
  'account_balance': Icons.account_balance, 'domain': Icons.domain,
  'menu_book': Icons.menu_book, 'request_quote': Icons.request_quote,
  'account_balance_wallet': Icons.account_balance_wallet,
  'local_hospital': Icons.local_hospital, 'school': Icons.school,
  'gavel': Icons.gavel, 'local_police': Icons.local_police,
  'shield': Icons.shield, 'business': Icons.business,
  'sign_language': Icons.sign_language, 'info': Icons.info,
  'medical_services': Icons.medical_services, 'balance': Icons.balance,
  'support_agent': Icons.support_agent, 'explore': Icons.explore,
  'emergency': Icons.emergency,
  'priority_high': Icons.priority_high, 'sos': Icons.sos,
  'crisis_alert': Icons.crisis_alert, 'sick': Icons.sick,
  'healing': Icons.healing, 'help_outline': Icons.help_outline,
  'location_off': Icons.location_off,
  'credit_card': Icons.credit_card,
  'search': Icons.search, 'report': Icons.report,
  'warning': Icons.warning, 'sports_mma': Icons.sports_mma,
  'back_hand': Icons.back_hand, 'waving_hand': Icons.waving_hand,
  'directions_run': Icons.directions_run, 'groups': Icons.groups,
  'nature_people': Icons.nature_people, 'person_off': Icons.person_off,
};

/// Provider local: si el usuario activó "ver todas las opciones",
/// dejamos de truncar la lista a 6.
class ExpandedAnswersNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void expand() => state = true;
  void collapse() => state = false;
}

final expandedAnswersProvider =
    NotifierProvider<ExpandedAnswersNotifier, bool>(ExpandedAnswersNotifier.new);

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

    return cardsAsync.when(
      data: (cards) {
        if (cards.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Text(
                'No hay opciones disponibles para esta pregunta.\nUsa "Saltar" o "Terminé y traducir".',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF8B949E), fontSize: 13),
              ),
            ),
          );
        }

        final visible = expanded
            ? cards
            : cards.take(_kAnswersPerQuestion).toList();
        final hasMore = !expanded && cards.length > _kAnswersPerQuestion;

        return Column(
          children: [
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: TextButton.icon(
                  onPressed: () =>
                      ref.read(expandedAnswersProvider.notifier).expand(),
                  icon: const Icon(Icons.expand_more,
                      size: 18, color: Color(0xFF8B949E)),
                  label: Text(
                    'Ver más opciones (${cards.length - _kAnswersPerQuestion})',
                    style: const TextStyle(
                      color: Color(0xFF8B949E),
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
          child: Text('Error al cargar opciones',
              style: TextStyle(color: Colors.red)),
        ),
      ),
    );
  }

  /// Añade la glosa al relato y dispara el avance automático.
  /// Se colapsa la vista expandida para que la siguiente pregunta
  /// vuelva a mostrar solo sus 6 opciones más relevantes.
  void _onAnswerPicked(WidgetRef ref, LsbCard card, List<LsbCard> allCards) {
    ref.read(sentenceProvider.notifier).addWord(card.displayText);
    ref.read(expandedAnswersProvider.notifier).collapse();
    ref.read(semanticZonesProvider.notifier).advanceFromCard(card, allCards);
  }
}

class _AnswerCard extends StatelessWidget {
  final LsbCard card;
  final VoidCallback onTap;
  const _AnswerCard({required this.card, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isEmergency = card.isEmergency;
    final accent =
        isEmergency ? Colors.redAccent : const Color(0xFFFFD700);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF21262D),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withValues(alpha: 0.35)),
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
                _iconMap[card.semanticIcon] ?? Icons.credit_card,
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
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
