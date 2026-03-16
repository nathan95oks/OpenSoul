import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/cards_provider.dart';

class CategoryFilter extends ConsumerWidget {
  const CategoryFilter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentCategory = ref.watch(currentCategoryProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      color: const Color(0xFF121212),
      child: categoriesAsync.when(
        data: (categoriasUnicas) => ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          itemCount: categoriasUnicas.length,
          itemBuilder: (context, index) {
            final categoria = categoriasUnicas[index];
            final isSelected = categoria == currentCategory;

            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ChoiceChip(
                label: Text(
                  categoria,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.black : Colors.white,
                  ),
                ),
                selected: isSelected,
                selectedColor: const Color(0xFFFFD700),
                backgroundColor: const Color(0xFF2C2C2C),
                onSelected: (bool selected) {
                  if (selected) {
                    ref.read(currentCategoryProvider.notifier).setCategory(categoria);
                  }
                },
              ),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
      ),
    );
  }
}
