import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/cards_provider.dart';
import 'confirm_video_modal.dart';

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
};
/// Grid de tarjetas LSB con íconos semánticos por categoría.
class CardGrid extends ConsumerWidget {
  const CardGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardsAsync = ref.watch(cardsByCategoryProvider);

    return cardsAsync.when(
      data: (cards) => GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.85,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: cards.length,
          itemBuilder: (context, index) {
            final card = cards[index];
            final isEmergency = card.isEmergency;

            return InkWell(
              onTap: () => mostrarVideoConfirmacion(
                context, ref, card.displayText, card.videoUrl,
              ),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF21262D),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isEmergency
                        ? Colors.redAccent.withValues(alpha: 0.4)
                        : const Color(0xFF30363D),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isEmergency
                            ? Colors.redAccent.withValues(alpha: 0.15)
                            : const Color(0xFF161B22),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _iconMap[card.semanticIcon] ?? Icons.credit_card,
                        size: 22,
                        color: isEmergency
                            ? Colors.redAccent
                            : const Color(0xFFFFD700),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        card.displayText,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Error al cargar tarjetas', style: const TextStyle(color: Colors.red)),
      ),
    );
  }
}
