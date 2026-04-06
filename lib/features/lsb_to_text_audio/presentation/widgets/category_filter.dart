import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/cards_provider.dart';

/// Mapa de íconos semánticos por nombre de string.
const _iconMap = <String, IconData>{
  'person': Icons.person,
  'child_care': Icons.child_care,
  'woman': Icons.woman,
  'man': Icons.man,
  'people': Icons.people,
  'family_restroom': Icons.family_restroom,
  'person_outline': Icons.person_outline,
  'help_outline': Icons.help_outline,
  'warning': Icons.warning,
  'dangerous': Icons.dangerous,
  'groups': Icons.groups,
  'gavel': Icons.gavel,
  'report': Icons.report,
  'front_hand': Icons.front_hand,
  'swipe_left': Icons.swipe_left,
  'sports_mma': Icons.sports_mma,
  'warning_amber': Icons.warning_amber,
  'search_off': Icons.search_off,
  'description': Icons.description,
  'directions_walk': Icons.directions_walk,
  'record_voice_over': Icons.record_voice_over,
  'directions_run': Icons.directions_run,
  'exit_to_app': Icons.exit_to_app,
  'backpack': Icons.backpack,
  'smartphone': Icons.smartphone,
  'payments': Icons.payments,
  'article': Icons.article,
  'account_balance_wallet': Icons.account_balance_wallet,
  'badge': Icons.badge,
  'vpn_key': Icons.vpn_key,
  'directions_car': Icons.directions_car,
  'local_police': Icons.local_police,
  'personal_injury': Icons.personal_injury,
  'dark_mode': Icons.dark_mode,
  'light_mode': Icons.light_mode,
  'history': Icons.history,
  'today': Icons.today,
  'access_time': Icons.access_time,
  'wb_sunny': Icons.wb_sunny,
  'wb_twilight': Icons.wb_twilight,
  'add_road': Icons.add_road,
  'directions_bus': Icons.directions_bus,
  'home': Icons.home,
  'park': Icons.park,
  'storefront': Icons.storefront,
  'local_hospital': Icons.local_hospital,
  'work': Icons.work,
  'balance': Icons.balance,
  'medical_services': Icons.medical_services,
  'emergency': Icons.emergency,
  'account_balance': Icons.account_balance,
  'sign_language': Icons.sign_language,
  'fire_truck': Icons.fire_truck,
  'priority_high': Icons.priority_high,
  'sos': Icons.sos,
  'crisis_alert': Icons.crisis_alert,
  'report_problem': Icons.report_problem,
  'mood_bad': Icons.mood_bad,
  'healing': Icons.healing,
  'credit_card': Icons.credit_card,
};

/// Íconos y colores por categoría para el UI.
const _categoryMeta = <String, Map<String, dynamic>>{
  'Identificación': {'icon': Icons.person, 'color': 0xFF4FC3F7},
  'Agresores': {'icon': Icons.warning, 'color': 0xFFFF7043},
  'Acciones': {'icon': Icons.flash_on, 'color': 0xFFFFD54F},
  'Objetos': {'icon': Icons.inventory_2, 'color': 0xFF81C784},
  'Delitos': {'icon': Icons.gavel, 'color': 0xFFEF5350},
  'Tiempo': {'icon': Icons.access_time, 'color': 0xFFCE93D8},
  'Lugares': {'icon': Icons.place, 'color': 0xFF4DB6AC},
  'Servicios': {'icon': Icons.account_balance, 'color': 0xFF64B5F6},
  'Urgencia': {'icon': Icons.crisis_alert, 'color': 0xFFFF5252},
};

/// Filtro horizontal de categorías jurídicas con íconos.
class CategoryFilter extends ConsumerWidget {
  const CategoryFilter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentCategory = ref.watch(currentCategoryProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
      ),
      child: categoriesAsync.when(
        data: (cats) => ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: cats.length,
          itemBuilder: (context, index) {
            final cat = cats[index];
            final isSelected = cat == currentCategory;
            final meta = _categoryMeta[cat];
            final catColor = Color(meta?['color'] as int? ?? 0xFFFFD700);
            final catIcon = meta?['icon'] as IconData? ?? Icons.label;

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                avatar: Icon(catIcon, size: 16, color: isSelected ? Colors.black : catColor),
                label: Text(
                  cat,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.black : Colors.white70,
                  ),
                ),
                selected: isSelected,
                selectedColor: catColor,
                backgroundColor: const Color(0xFF21262D),
                checkmarkColor: Colors.black,
                side: BorderSide(color: isSelected ? catColor : const Color(0xFF30363D)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                onSelected: (_) => ref.read(currentCategoryProvider.notifier).setCategory(cat),
              ),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.red))),
      ),
    );
  }
}
