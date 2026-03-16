import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/cards_provider.dart';
import 'confirm_video_modal.dart';

class CardGrid extends ConsumerWidget {
  const CardGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardsAsync = ref.watch(cardsByCategoryProvider);

    return Expanded(
      child: cardsAsync.when(
        data: (tarjetasFiltradas) => GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.9,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: tarjetasFiltradas.length,
          itemBuilder: (context, index) {
            final tarjeta = tarjetasFiltradas[index]; 
            
            return InkWell(
              onTap: () => mostrarVideoConfirmacion(context, ref, tarjeta.displayText, tarjeta.videoUrl),
              child: Card(
                color: const Color(0xFF2C2C2C),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 4,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.credit_card, size: 60, color: Colors.white),
                    const SizedBox(height: 16),
                    Text(tarjeta.displayText, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                  ],
                ),
              ),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error al cargar tarjetas', style: const TextStyle(color: Colors.red))),
      ),
    );
  }
}
