import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../controllers/audio_translation_controller.dart';

class TextInputWidget extends ConsumerStatefulWidget {
  final Function(String) onSubmit;

  /// Callback específico para texto proveniente del dictado por voz.
  /// Si no se provee, se usa [onSubmit]. Permite al dueño del widget
  /// distinguir el canal de entrada (voz vs. texto) sin duplicar el widget.
  final Function(String)? onSpeechSubmit;

  /// Texto de ayuda del campo. El widget lo comparten el módulo de voz y el
  /// chat, y cada uno pide algo distinto a quien escribe, así que la etiqueta
  /// es del llamador y no del widget.
  final String hintText;

  const TextInputWidget({
    super.key,
    required this.onSubmit,
    this.onSpeechSubmit,
    this.hintText = 'Ingresar texto',
  });

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
          // `listen(localeId:)` quedó obsoleto en speech_to_text 7. Este
          // objeto es equivalente al que construía internamente la ruta
          // antigua: el resto de opciones conserva sus valores por defecto
          // (partialResults true, onDevice false, ListenMode.confirmation),
          // que son los mismos en ambos caminos.
          listenOptions: stt.SpeechListenOptions(localeId: 'es_ES'),
        );
      } else {
        _warn('Reconocimiento de voz no disponible');
      }
    } catch (_) {
      if (mounted) setState(() => _isRecording = false);
      _warn('No se pudo iniciar el dictado. Escribe el mensaje.');
    }
  }

  /// Avisa al usuario de un fallo del dictado.
  ///
  /// La alternativa —registrarlo por consola— deja a quien usa la aplicación
  /// esperando un micrófono que nunca se activó.
  void _warn(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;
    try {
      await _speechToText.stop();
      setState(() {
        _isRecording = false;
      });

      final text = _controller.text.trim();
      _controller.clear();
      if (text.isEmpty) {
        // Dictado vacío: solo salimos del estado de grabación.
        ref
            .read(audioTranslationControllerProvider.notifier)
            .processAudioAsText('');
      } else {
        // El destino del mensaje lo decide el dueño del widget (pantalla
        // clásica o conversación), igual que con el texto escrito.
        (widget.onSpeechSubmit ?? widget.onSubmit)(text);
      }
    } catch (_) {
      if (mounted) setState(() => _isRecording = false);
      _warn('No se pudo completar el dictado. Intenta de nuevo.');
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
        color: const Color(0xFF1F1F1F).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
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
              decoration: InputDecoration(
                hintText: widget.hintText,
                hintStyle: const TextStyle(color: Colors.white54),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
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
                      ? Colors.red.withValues(alpha: 0.15 + (_animationController.value * 0.2))
                      : Colors.transparent,
                  boxShadow: _isRecording
                      ? [
                          BoxShadow(
                            color: Colors.redAccent.withValues(alpha: 0.3),
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
