import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import '../../../translation/presentation/providers/sentence_provider.dart';

void mostrarVideoConfirmacion(BuildContext context, WidgetRef ref, String word, String videoUrl) {
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
        children: [
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
            children: [
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
