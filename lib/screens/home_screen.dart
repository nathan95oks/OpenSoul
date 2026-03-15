// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../features/cards/presentation/providers/cards_provider.dart';
import '../features/translation/presentation/providers/sentence_provider.dart';
import '../features/translation/presentation/providers/translation_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  void _mostrarVideoConfirmacion(BuildContext context, WidgetRef ref, String word, String videoUrl) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1F1F1F),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return ReproductorSenaWidget(
          word: word,
          videoUrl: videoUrl,
          onConfirm: () {
            ref.read(sentenceProvider.notifier).addWord(word);
            Navigator.pop(context);
          },
          onCancel: () {
            Navigator.pop(context);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Escuchamos las palabras combinadas seleccionadas (Sentence)
    final selectedWords = ref.watch(sentenceProvider);
    
    // 2. Escuchamos la categoría actual para mantener el estado UI
    final currentCategory = ref.watch(currentCategoryProvider);

    // 3. Consumimos las tarjetas agrupadas por categoría (de capa de Domain)
    final categoriesAsync = ref.watch(categoriesProvider);
    final cardsAsync = ref.watch(cardsByCategoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Comisaría / Juzgado', style: TextStyle(fontWeight: FontWeight.bold)),
        actions:[
          if (selectedWords.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.white),
              onPressed: () => ref.read(sentenceProvider.notifier).clearSentence(),
              tooltip: 'Borrar todo',
            ),
        ],
      ),
      body: Column(
        children:[
          // ==========================================
          // ZONA 1: Constructor de frases (Arriba)
          // ==========================================
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            decoration: const BoxDecoration(
              color: Color(0xFF1F1F1F),
              border: Border(bottom: BorderSide(color: Color(0xFFFFD700), width: 2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children:[
                const Text('Mensaje a generar:', style: TextStyle(color: Colors.grey, fontSize: 14)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8.0,
                  children: selectedWords.isEmpty
                      ?[const Text('Selecciona tarjetas abajo...', style: TextStyle(fontStyle: FontStyle.italic))]
                      : selectedWords.map((word) => Chip(
                          label: Text(word.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                          backgroundColor: const Color(0xFFFFD700),
                          deleteIconColor: Colors.black,
                          onDeleted: () {
                            ref.read(sentenceProvider.notifier).removeWord(word);
                          },
                        )).toList(),
                ),
              ],
            ),
          ),

          // ==========================================
          // ZONA 2: Barra de Filtro de Categorías (Medio)
          // ==========================================
          Container(
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
          ),

          // ==========================================
          // ZONA 3: Grid de Tarjetas Reales (Abajo)
          // ==========================================
          Expanded(
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
                    onTap: () => _mostrarVideoConfirmacion(context, ref, tarjeta.displayText, tarjeta.videoUrl),
                    child: Card(
                      color: const Color(0xFF2C2C2C),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 4,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children:[
                          // Fallback si no hay iconUrl (reemplazar la clase IconData por network images despues)
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
          ),

          // ==========================================
          // BOTÓN DE TRADUCCIÓN E IA
          // ==========================================
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton.icon(
                onPressed: selectedWords.isEmpty ? null : () async {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Generando audio...')));
                  
                  final translateUseCase = ref.read(translateCardsUseCaseProvider);
                  await translateUseCase(
                    context: 'legal',
                    cards: selectedWords,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD700),
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: Colors.grey[800],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.volume_up, size: 28),
                label: const Text('GENERAR VOZ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// WIDGET REPRODUCTOR DE VIDEO
// =========================================================================
class ReproductorSenaWidget extends StatefulWidget {
  final String word;
  final String videoUrl;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const ReproductorSenaWidget({
    super.key,
    required this.word,
    required this.videoUrl,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  State<ReproductorSenaWidget> createState() => _ReproductorSenaWidgetState();
}

class _ReproductorSenaWidgetState extends State<ReproductorSenaWidget> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        _controller.setLooping(true);
        _controller.play();
        setState(() {}); 
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children:[
          Text(
            'Confirmar seña: ${widget.word}',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 20),
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFD700), width: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: _controller.value.isInitialized
                  ? AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: VideoPlayer(_controller),
                    )
                  : const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700))),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children:[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: widget.onCancel,
                  icon: const Icon(Icons.close, color: Colors.white),
                  label: const Text('Cancelar', style: TextStyle(color: Colors.white)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: Colors.grey),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: widget.onConfirm,
                  icon: const Icon(Icons.check, color: Colors.black),
                  label: const Text('Añadir', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD700),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}