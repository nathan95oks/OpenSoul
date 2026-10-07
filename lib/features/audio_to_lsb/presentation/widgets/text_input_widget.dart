import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:lsb_legal_app/app/app_theme.dart';
import 'package:lsb_legal_app/core/domain/services/input_validator.dart';
import 'package:lsb_legal_app/features/audio_to_lsb/presentation/controllers/audio_translation_controller.dart';

class TextInputWidget extends ConsumerStatefulWidget {
  final Function(String) onSubmit;

  final Function(String)? onSpeechSubmit;

  final String hintText;

  /// `false` cuando el modulo dejo de estar visible: se corta el dictado en
  /// curso para que el microfono no siga escuchando en segundo plano.
  final bool isActive;

  /// Permite que otra parte de la pantalla devuelva el turno al oyente
  /// poniendo el cursor aqui. Solo enfoca: el dictado sigue necesitando que
  /// el oyente pulse el microfono.
  final FocusNode? focusNode;
  final ValueChanged<bool>? onComposingChanged;

  /// `true`: lo dictado se envía solo en cuanto el micrófono termina de
  /// escuchar, sin esperar al botón de enviar (Texto/Audio → LSB). Con
  /// `false` queda en el campo para revisarlo y enviarlo a mano.
  final bool sendSpeechAutomatically;

  /// Lo que se ve escrito al aparecer el campo: el mensaje que se envió,
  /// cuando la persona vuelve atrás desde el avatar para corregirlo.
  final String? initialText;

  const TextInputWidget({
    super.key,
    required this.onSubmit,
    this.onSpeechSubmit,
    this.hintText = 'Ingresar texto',
    this.isActive = true,
    this.focusNode,
    this.onComposingChanged,
    this.sendSpeechAutomatically = false,
    this.initialText,
  });

  @override
  ConsumerState<TextInputWidget> createState() => _TextInputWidgetState();
}

class _TextInputWidgetState extends ConsumerState<TextInputWidget>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  bool _isRecording = false;
  late stt.SpeechToText _speechToText;
  late AnimationController _animationController;

  void _notifyComposing() {
    widget.onComposingChanged?.call(
      _isRecording || _controller.text.trim().isNotEmpty,
    );
  }

  @override
  void initState() {
    super.initState();
    _speechToText = stt.SpeechToText();
    final inicial = widget.initialText?.trim() ?? '';
    if (inicial.isNotEmpty) {
      _controller.text = inicial;
      _controller.selection = TextSelection.collapsed(offset: inicial.length);
      // Hay texto para corregir: el avatar queda quieto mientras tanto.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _notifyComposing();
      });
    }
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
    _notifyComposing();
    try {
      await _speechToText.cancel();
    } catch (_) {}
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
        onStatus: _onSpeechStatus,
        onError: _onSpeechError,
      );
      // El motor es uno solo para toda la app y `initialize` solo registra
      // los avisos la primera vez: sin esto, tras dictar en otro módulo,
      // «terminé de oír» le llegaría a ese otro campo y este seguiría
      // esperando.
      _speechToText.statusListener = _onSpeechStatus;
      _speechToText.errorListener = _onSpeechError;

      if (available) {
        setState(() {
          _isRecording = true;
          _controller.clear();
        });
        _notifyComposing();

        ref
            .read(audioTranslationControllerProvider.notifier)
            .setRecordingState();

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
            _notifyComposing();
            ref
                .read(audioTranslationControllerProvider.notifier)
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

  void _onSpeechStatus(String status) {
    if ((status == 'done' || status == 'notListening') && _isRecording) {
      _stopRecording();
    }
  }

  void _onSpeechError(Object _) {
    if (_isRecording) _stopRecording(porError: true);
  }

  void _warn(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _lastRecognizedWords = '';

  /// Detiene el dictado. Terminar de grabar —por el botón o porque el motor
  /// decidió que ya terminó ("done"/"notListening")— envía lo reconocido si
  /// [TextInputWidget.sendSpeechAutomatically]; si no, queda en el campo,
  /// editable, hasta el botón de enviar. Un error de reconocimiento nunca
  /// envía solo: una transcripción cortada o equivocada no puede pasar por lo
  /// que se dijo, así que queda en el campo para revisarla.
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
    _notifyComposing();

    if (text.isEmpty) {
      ref
          .read(audioTranslationControllerProvider.notifier)
          .processAudioAsText('');
      // Un audio vacío nunca pasa: se avisa siempre, no solo si falló el
      // reconocimiento.
      _warn(
        porError
            ? 'No se reconoció nada. Puedes intentar de nuevo o escribir el '
                  'mensaje.'
            : 'No escuché nada. Habla otra vez o escribe el mensaje.',
      );
    } else if (porError) {
      _warn(
        'Revisa el texto reconocido antes de enviarlo: puede tener errores.',
      );
    } else if (widget.sendSpeechAutomatically && mounted) {
      _controller.clear();
      _notifyComposing();
      (widget.onSpeechSubmit ?? widget.onSubmit)(text);
    }
    // Sin envío automático: se deja tal cual en el campo para que la persona
    // lo revise y confirme con el botón de enviar.
  }

  void _submit() {
    if (_isRecording) {
      _stopRecording();
      return;
    }
    if (_controller.text.trim().isNotEmpty) {
      final text = _controller.text.trim();
      _controller.clear();
      _notifyComposing();
      FocusScope.of(context).unfocus();
      FocusManager.instance.primaryFocus?.unfocus();
      SystemChannels.textInput.invokeMethod('TextInput.hide');
      widget.onSubmit(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('hearing_input_box'),
      decoration: BoxDecoration(
        color: AppTheme.lightInputBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.lightInputBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppTheme.brandPrimary.withValues(alpha: 0.10),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: widget.focusNode,
              enabled: !_isRecording,
              style: const TextStyle(
                color: AppTheme.lightInputText,
                fontSize: 16,
              ),
              cursorColor: AppTheme.lightInputCursor,
              decoration: InputDecoration(
                hintText: widget.hintText,
                hintStyle: const TextStyle(color: AppTheme.lightInputHint),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
              inputFormatters: [
                LengthLimitingTextInputFormatter(InputValidator.maxLength),
              ],
              onChanged: (_) => _notifyComposing(),
              onSubmitted: (_) => _submit(),
            ),
          ),
          // Sin círculos de fondo: el color va en el propio ícono
          // (audio azul, enviar morado). Al grabar, el ícono de detener
          // parpadea en rojo.
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return IconButton(
                icon: Opacity(
                  opacity: _isRecording
                      ? 0.6 + (_animationController.value * 0.4)
                      : 1,
                  // Micrófono ↔ detener gira y escala en lugar de saltar.
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    transitionBuilder: (child, animation) => RotationTransition(
                      turns: Tween<double>(
                        begin: 0.75,
                        end: 1,
                      ).animate(animation),
                      child: ScaleTransition(scale: animation, child: child),
                    ),
                    child: Icon(
                      _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                      key: ValueKey(
                        _isRecording ? 'hearing_stop' : 'hearing_audio_action',
                      ),
                      color: _isRecording
                          ? AppTheme.errorLight
                          : AppTheme.audioActionBlue,
                      size: 26,
                    ),
                  ),
                ),
                onPressed: _toggleRecording,
                tooltip: _isRecording ? 'Detener grabación' : 'Grabar voz',
              );
            },
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(
              Icons.send_rounded,
              key: Key('hearing_send_action'),
              color: AppTheme.lsbViolet,
              size: 26,
            ),
            onPressed: _submit,
            tooltip: 'Enviar mensaje',
          ),
        ],
      ),
    );
  }
}
