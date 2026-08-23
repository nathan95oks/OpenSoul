import 'dart:convert';
import 'package:http/http.dart' as http;

import 'endpoint_uri.dart';

/// Pregunta y opciones que el modelo propone para el siguiente paso.
class GeneratedStep {
  /// Enunciado que presenta las opciones. Vacío si el modelo no lo redactó.
  final String question;

  /// Glosas propuestas, en orden de relevancia. Siempre un subconjunto de las
  /// candidatas que se enviaron.
  final List<String> options;

  const GeneratedStep({required this.question, required this.options});

  static const vacio = GeneratedStep(question: '', options: []);

  bool get isEmpty => options.isEmpty;
}

/// Pide al backend qué ofrecer a continuación.
///
/// El flujo guiado ofrecía las tarjetas de la categoría de la zona ordenadas
/// por prioridad, así que ante "¿Qué pasó?" en un robo proponía ARRESTAR y
/// ASISTENCIA —que no responden la pregunta— y enterraba ROBAR por orden
/// alfabético. Era un árbol escrito a mano: no sabía reaccionar a lo que
/// llegara desde la conversación.
///
/// El modelo elige y ordena, pero **solo dentro de las candidatas que se le
/// mandan**. La restricción no depende de que obedezca el prompt: el backend
/// descarta lo que no venga en esa lista, así que una seña inventada no puede
/// llegar a la pantalla.
class RemoteSuggestionDataSource {
  static const String _envUrl = String.fromEnvironment('LSB_API_URL');
  static const String defaultApiUrl = _envUrl;

  /// Tope corto a propósito: esto se pide mientras la persona mira la
  /// pantalla. Si tarda más, se ofrece el orden local antes que hacerla
  /// esperar por una mejora de presentación.
  static const Duration requestTimeout = Duration(seconds: 6);

  final http.Client client;
  final String apiUrl;

  RemoteSuggestionDataSource({required this.client, this.apiUrl = defaultApiUrl});

  bool get isConfigured {
    final uri = Uri.tryParse(apiUrl);
    return uri != null && uri.hasScheme && uri.host.isNotEmpty;
  }

  /// Devuelve el paso propuesto, o [GeneratedStep.vacio] si no se pudo generar.
  ///
  /// Nunca lanza: quien llama se queda con su orden determinista y el flujo
  /// sigue. Una sugerencia es una mejora, no un requisito para declarar.
  Future<GeneratedStep> suggest({
    required String contextId,
    required List<String> selected,
    required List<String> candidates,
    String? replyingTo,
  }) async {
    if (!isConfigured || candidates.isEmpty) return GeneratedStep.vacio;

    try {
      final response = await client
          .post(
            requireAbsoluteUrl(apiUrl, 'LSB_API_URL'),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'action': 'suggest',
              'context': contextId,
              'selected': selected,
              'candidates': candidates,
              if (replyingTo != null && replyingTo.isNotEmpty)
                'question': replyingTo,
            }),
          )
          .timeout(requestTimeout);

      if (response.statusCode != 200) return GeneratedStep.vacio;

      final cuerpo = jsonDecode(response.body);
      if (cuerpo is! Map || cuerpo['generated'] != true) {
        return GeneratedStep.vacio;
      }

      // Segunda comprobación, en el cliente: aunque el backend ya filtra, la
      // pantalla no muestra nada que no estuviera entre las candidatas.
      final permitidas = candidates.toSet();
      final opciones = [
        for (final o in (cuerpo['options'] as List? ?? const []))
          if (o is String && permitidas.contains(o)) o,
      ];
      if (opciones.isEmpty) return GeneratedStep.vacio;

      return GeneratedStep(
        question: (cuerpo['question'] as String? ?? '').trim(),
        options: opciones,
      );
    } catch (_) {
      return GeneratedStep.vacio;
    }
  }
}
