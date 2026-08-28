import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:lsb_legal_app/app/app_theme.dart';
import 'package:lsb_legal_app/features/audio_to_lsb/presentation/controllers/audio_translation_controller.dart';

class TextInputWidget extends ConsumerStatefulWidget {
  final Function(String) onSubmit;

  final Function(String)? onSpeechSubmit;

  final String hintText;

  /// `false` cuando el modulo dejo de estar visible: se corta el dictado en
  /// curso para que el microfono no siga escuchando en segundo plano.
  final bool isActive;

  const TextInputWidget({
    super.key,
    required this.onSubmit,
    this.onSpeechSubmit,
    this.hintText = 'Ingresar texto',
    this.isActive = true,
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
  void didUpdateWidget(TextInputWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive && !widget.isActive) {
      _cancelRecording();
    }
  }

  @override
  void dispose() {
    if (_isRecording) _speechToText.cancel();
    _controller.dispose();
    _animationController.dispose();
    super.dispose();
  }

  /// Aborta el dictado sin traducir lo que se alcanzo a escuchar.
  Future<void> _cancelRecording() async {
    if (!_isRecording) return;
    _isRecording = false;
    _lastRecognizedWords = '';
    _controller.clear();
    try {
      await _speechToText.cancel();
    } catch (_) {
    }
    if (mounted) setState(() {});
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
            _lastRecognizedWords = result.recognizedWords;
            setState(() {
              _controller.text = result.recognizedWords;
              _controller.selection = TextSelection.fromPosition(
                TextPosition(offset: _controller.text.length),
              );
            });
            ref.read(audioTranslationControllerProvider.notifier)
                .updateRecognizedText(result.recognizedWords);
          },
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

  void _warn(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _lastRecognizedWords = '';

  Future<void> _stopRecording() async {
    if (!_isRecording) return;
    try {
      await _speechToText.stop();
      setState(() {
        _isRecording = false;
      });

      final text = _controller.text.trim().isNotEmpty
          ? _controller.text.trim()
          : _lastRecognizedWords.trim();

      _controller.clear();
      _lastRecognizedWords = '';

      if (text.isEmpty) {
        ref
            .read(audioTranslationControllerProvider.notifier)
            .processAudioAsText('');
      } else {
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
                            color: AppTheme.errorDark.withValues(alpha: 0.3),
                            spreadRadius: _animationController.value * 6,
                            blurRadius: 8,
                          )
                        ]
                      : null,
                ),
                child: IconButton(
                  icon: Icon(
                    _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                    color:
                        _isRecording ? AppTheme.errorDark : AppTheme.brandLight,
                  ),
                  onPressed: _toggleRecording,
                  tooltip: _isRecording ? 'Detener grabación' : 'Grabar voz',
                ),
              );
            },
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.send_rounded, color: AppTheme.brandLight),
            onPressed: _submit,
            tooltip: 'Enviar mensaje',
          ),
        ],
      ),
    );
  }
}
