import 'dart:async';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

class RecordButton extends StatefulWidget {
  final Function(String) onStopRecording;
  final VoidCallback onStartRecording;
  final Function(String) onTextRecognized;

  const RecordButton({
    Key? key,
    required this.onStopRecording,
    required this.onStartRecording,
    required this.onTextRecognized,
  }) : super(key: key);

  @override
  State<RecordButton> createState() => _RecordButtonState();
}

class _RecordButtonState extends State<RecordButton> with SingleTickerProviderStateMixin {
  bool _isRecording = false;
  late stt.SpeechToText _speechToText;
  late AnimationController _animationController;
  String _recognizedText = "";

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
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      // In web and some environments, permission is handled inside initialize
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
          _recognizedText = "";
        });
        widget.onStartRecording();
        
        await _speechToText.listen(
          onResult: (result) {
            setState(() {
              _recognizedText = result.recognizedWords;
            });
            widget.onTextRecognized(_recognizedText);
          },
          localeId: 'es_ES', // Spanish recognition
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

      widget.onStopRecording(_recognizedText);
      _recognizedText = "";
    } catch (e) {
      debugPrint("Error stopping speech to text: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _isRecording ? _stopRecording : _startRecording,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isRecording 
                ? Colors.red.withOpacity(0.5 + (_animationController.value * 0.5))
                : Theme.of(context).primaryColor,
              boxShadow: _isRecording ? [
                BoxShadow(
                  color: Colors.red.withOpacity(0.4),
                  spreadRadius: _animationController.value * 15,
                  blurRadius: 10,
                )
              ] : null,
            ),
            child: Icon(
              _isRecording ? Icons.stop : Icons.mic,
              color: Colors.white,
              size: 40,
            ),
          );
        },
      ),
    );
  }
}
