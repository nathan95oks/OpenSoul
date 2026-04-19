import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/cards_provider.dart';


/// Íconos y colores por categoría para el UI.
const _categoryMeta = <String, Map<String, dynamic>>{
  'Identificación': {'icon': Icons.person, 'color': 0xFF4FC3F7},
  'Acciones': {'icon': Icons.flash_on, 'color': 0xFFFFD54F},
  'Trámites': {'icon': Icons.assignment, 'color': 0xFFFF8A65},
  'Documentos': {'icon': Icons.description, 'color': 0xFF81C784},
  'Tiempo': {'icon': Icons.access_time, 'color': 0xFFCE93D8},
  'Instituciones': {'icon': Icons.account_balance, 'color': 0xFF64B5F6},
  'Servicios': {'icon': Icons.support_agent, 'color': 0xFF4DB6AC},
  'Estado/Urgencia': {'icon': Icons.crisis_alert, 'color': 0xFFFF5252},
};

/// Filtro horizontal de categorías ciudadanas con íconos.
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
