import 'package:flutter_tts/flutter_tts.dart';
import 'package:lsb_legal_app/features/translation/domain/repositories/translation_repository.dart';

class TranslationRepositoryImpl implements TranslationRepository {
  final FlutterTts _flutterTts;

  TranslationRepositoryImpl(this._flutterTts);

  @override
  Future<TranslationResult> translateCards({
    required String context,
    required List<String> cards,
  }) async {
    // Aquí conectamos con la lógica real de TTS (audio local).
    await _flutterTts.setLanguage("es-ES");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setPitch(1.0);
    
    String textToSpeak = cards.join(" ");
    await _flutterTts.speak(textToSpeak);
    
    // Retornamos el texto generado temporalmente sin URL de audio
    return TranslationResult(
      generatedText: textToSpeak,
      audioUrl: null, 
    );
  }
}
