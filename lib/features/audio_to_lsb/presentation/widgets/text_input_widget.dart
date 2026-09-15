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

  /// Locale a usar con `speech_to_text`. Se resuelve contra lo que el
  /// dispositivo realmente ofrece (`_speechToText.locales()`): antes estaba
  /// fijo en 'es_ES' sin comprobar si existía, y un 'es_BO' disponible en el
  /// dispositivo nunca se usaba porque nada lo pedía.
  Future<String?> _resolveLocaleId() async {
    try {
      final locales = await _speechToText.locales();
      String? porPrefijo(String prefijo) {
        for (final l in locales) {
          if (l.localeId.toLowerCase().startsWith(prefijo)) return l.localeId;
        }
        return null;
      }

      final systemLocale = await _speechToText.systemLocale();
      return porPrefijo('es_bo') ??
          porPrefijo('es_es') ??
          porPrefijo('es') ??
          systemLocale?.localeId;
    } catch (_) {
      // Sin lista de locales disponible, se deja que el motor use su
      // predeterminado en vez de fijar uno que puede no existir en este
      // dispositivo.
      return null;
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
          if (_isRecording) _stopRecording(porError: true);
        },
      );

      if (available) {
        setState(() {
          _isRecording = true;
          _controller.clear();
        });

        ref.read(audioTranslationControllerProvider.notifier).setRecordingState();

        final localeId = await _resolveLocaleId();

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
          listenOptions: localeId == null
              ? null
              : stt.SpeechListenOptions(localeId: localeId),
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

  /// Detiene el dictado SIN enviar la traducción. Antes, terminar de grabar
  /// —por el botón, porque el motor decidió que ya terminó ("done"/
  /// "notListening"), o por un error de reconocimiento— confirmaba y enviaba
  /// el texto reconocido directamente, sin darle a la persona oportunidad de
  /// revisarlo o corregirlo; un error de reconocimiento podía así enviar una
  /// transcripción incorrecta como si fuera lo que se dijo (sección 10 del
  /// encargo "Audio/Texto -> LSB"). Ahora el texto reconocido queda en el
  /// campo, editable, y hace falta el botón de enviar para traducirlo — igual
  /// que si se hubiera escrito a mano.
  Future<void> _stopRecording({bool porError = false}) async {
    if (!_isRecording) return;
    try {
      await _speechToText.stop();
    } catch (_) {
      // Aunque falle al detener el motor, el estado local de grabación debe
      // reflejar que ya no se está escuchando.
    }

    final text = _controller.text.trim().isNotEmpty
        ? _controller.text.trim()
        : _lastRecognizedWords.trim();

    if (mounted) {
      setState(() {
        _isRecording = false;
        _controller.text = text;
        _controller.selection = TextSelection.fromPosition(
          TextPosition(offset: _controller.text.length),
        );
      });
    }
    _lastRecognizedWords = '';

    if (text.isEmpty) {
      ref.read(audioTranslationControllerProvider.notifier).processAudioAsText('');
      if (porError) {
        _warn('No se reconoció nada. Puedes intentar de nuevo o escribir el mensaje.');
      }
    } else if (porError) {
      _warn('Revisa el texto reconocido antes de enviarlo: puede tener errores.');
    }
    // Sin error y con texto: se deja tal cual en el campo para que la
    // persona lo revise y confirme con el botón de enviar.
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
