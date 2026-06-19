import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../controllers/audio_translation_controller.dart';

class TextInputWidget extends ConsumerStatefulWidget {
  final Function(String) onSubmit;

  const TextInputWidget({Key? key, required this.onSubmit}) : super(key: key);

  @override
  ConsumerState<TextInputWidget> createState() => _TextInputWidgetState();
}

class _TextInputWidgetState extends ConsumerState<TextInputWidget> with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  bool _isRecording = false;
  late stt.SpeechToText _speechToText;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _speechToText = stt.SpeechToText();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    try {
      FocusScope.of(context).unfocus();
      bool available = await _speechToText.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (_isRecording) {
              _stopRecording();
            }
          }
        },
        onError: (error) {
          debugPrint('Speech recognition error: $error');
          if (_isRecording) _stopRecording();
        },
      );

      if (available) {
        setState(() {
          _isRecording = true;
          _controller.clear();
        });
        
        ref.read(audioTranslationControllerProvider.notifier).setRecordingState();
        
        await _speechToText.listen(
          onResult: (result) {
            setState(() {
              _controller.text = result.recognizedWords;
              _controller.selection = TextSelection.fromPosition(
                TextPosition(offset: _controller.text.length),
              );
            });
            ref.read(audioTranslationControllerProvider.notifier)
                .updateRecognizedText(result.recognizedWords);
          },
          localeId: 'es_ES',
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reconocimiento de voz no disponible')),
        );
      }
    } catch (e) {
      debugPrint("Error starting speech to text: $e");
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;
    try {
      await _speechToText.stop();
      setState(() {
        _isRecording = false;
      });

      final text = _controller.text.trim();
      ref.read(audioTranslationControllerProvider.notifier).processAudioAsText(text);
      _controller.clear();
    } catch (e) {
      debugPrint("Error stopping speech to text: $e");
    }
  }

  void _submit() {
    if (_isRecording) {
      _stopRecording();
      return;
    }
    if (_controller.text.trim().isNotEmpty) {
      widget.onSubmit(_controller.text.trim());
      _controller.clear();
      FocusScope.of(context).unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F).withOpacity(0.8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              enabled: !_isRecording,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: "Escribe o usa el micrófono...",
                hintStyle: TextStyle(color: Colors.white54),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
              onSubmitted: (_) => _submit(),
            ),
          ),
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isRecording
                      ? Colors.red.withOpacity(0.15 + (_animationController.value * 0.2))
                      : Colors.transparent,
                  boxShadow: _isRecording
                      ? [
                          BoxShadow(
                            color: Colors.redAccent.withOpacity(0.3),
                            spreadRadius: _animationController.value * 6,
                            blurRadius: 8,
                          )
                        ]
                      : null,
                ),
                child: IconButton(
                  icon: Icon(
                    _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                    color: _isRecording ? Colors.redAccent : const Color(0xFFFFD700),
                  ),
                  onPressed: _toggleRecording,
                  tooltip: _isRecording ? 'Detener grabación' : 'Grabar voz',
                ),
              );
            },
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.send_rounded, color: Color(0xFFFFD700)),
            onPressed: _submit,
            tooltip: 'Enviar mensaje',
          ),
        ],
      ),
    );
  }
}
