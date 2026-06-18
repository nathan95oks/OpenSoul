import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme.dart';
import '../providers/cards_provider.dart';


/// Íconos y colores por categoría para el UI.
///
/// Los colores por categoría son funcionales (diferencian categorías) y se
/// conservan; el resto del chrome usa los tokens del design system.
const _categoryMeta = <String, Map<String, dynamic>>{
  'Sugerencias': {'icon': Icons.auto_awesome, 'color': 0xFF2563EB},
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
      decoration: const BoxDecoration(
        color: AppTheme.lightBg,
        border: Border(bottom: BorderSide(color: AppTheme.lightBorder)),
      ),
      child: categoriesAsync.when(
        data: (cats) {
          final allCats = ['Sugerencias', ...cats];
          return ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: allCats.length,
            itemBuilder: (context, index) {
              final cat = allCats[index];
              final isSelected = cat == currentCategory;
            final meta = _categoryMeta[cat];
            final catColor = Color(meta?['color'] as int? ?? 0xFF2563EB);
            final catIcon = meta?['icon'] as IconData? ?? Icons.label;

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                avatar: Icon(catIcon, size: 16, color: isSelected ? AppTheme.lightText : catColor),
                label: Text(
                  cat,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? AppTheme.lightText : AppTheme.lightTextSub,
                  ),
                ),
                selected: isSelected,
                selectedColor: catColor,
                backgroundColor: AppTheme.lightSurface,
                checkmarkColor: AppTheme.lightText,
                side: BorderSide(color: isSelected ? catColor : AppTheme.lightBorder),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                onSelected: (_) => ref.read(currentCategoryProvider.notifier).setCategory(cat),
              ),
            );
          },
        );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppTheme.errorLight))),
      ),
    );
  }
}
