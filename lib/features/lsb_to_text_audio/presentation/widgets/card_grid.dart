import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/cards_provider.dart';
import 'confirm_video_modal.dart';

/// Mapa de nombres de ícono a IconData para tarjetas.
const _iconMap = <String, IconData>{
  'person': Icons.person, 'child_care': Icons.child_care, 'woman': Icons.woman,
  'man': Icons.man, 'people': Icons.people, 'family_restroom': Icons.family_restroom,
  'person_outline': Icons.person_outline, 'help_outline': Icons.help_outline,
  'warning': Icons.warning, 'dangerous': Icons.dangerous, 'groups': Icons.groups,
  'gavel': Icons.gavel, 'report': Icons.report, 'front_hand': Icons.front_hand,
  'swipe_left': Icons.swipe_left, 'sports_mma': Icons.sports_mma,
  'warning_amber': Icons.warning_amber, 'search_off': Icons.search_off,
  'description': Icons.description, 'directions_walk': Icons.directions_walk,
  'record_voice_over': Icons.record_voice_over, 'directions_run': Icons.directions_run,
  'exit_to_app': Icons.exit_to_app, 'backpack': Icons.backpack,
  'smartphone': Icons.smartphone, 'payments': Icons.payments, 'article': Icons.article,
  'account_balance_wallet': Icons.account_balance_wallet, 'badge': Icons.badge,
  'vpn_key': Icons.vpn_key, 'directions_car': Icons.directions_car,
  'local_police': Icons.local_police, 'personal_injury': Icons.personal_injury,
  'dark_mode': Icons.dark_mode, 'light_mode': Icons.light_mode,
  'history': Icons.history, 'today': Icons.today, 'access_time': Icons.access_time,
  'wb_sunny': Icons.wb_sunny, 'wb_twilight': Icons.wb_twilight,
  'add_road': Icons.add_road, 'directions_bus': Icons.directions_bus,
  'home': Icons.home, 'park': Icons.park, 'storefront': Icons.storefront,
  'local_hospital': Icons.local_hospital, 'work': Icons.work,
  'balance': Icons.balance, 'medical_services': Icons.medical_services,
  'emergency': Icons.emergency, 'account_balance': Icons.account_balance,
  'sign_language': Icons.sign_language, 'fire_truck': Icons.fire_truck,
  'priority_high': Icons.priority_high, 'sos': Icons.sos,
  'crisis_alert': Icons.crisis_alert, 'report_problem': Icons.report_problem,
  'mood_bad': Icons.mood_bad, 'healing': Icons.healing, 'credit_card': Icons.credit_card,
};
/// Grid de tarjetas LSB con íconos semánticos por categoría.
class CardGrid extends ConsumerWidget {
  const CardGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardsAsync = ref.watch(cardsByCategoryProvider);

    return Expanded(
      child: cardsAsync.when(
        data: (cards) => GridView.builder(
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
      ),
    );
  }
}
