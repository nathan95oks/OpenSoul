import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:lsb_legal_app/core/data/models/lsb_translation_model.dart';
import 'package:lsb_legal_app/core/data/datasources/endpoint_uri.dart';
import 'package:lsb_legal_app/core/generators/avatar_generator/animation_url_resolver.dart';

abstract class RemoteAudioDataSource {
  Future<LsbTranslationModel> translateAudio(String audioPath);

  /// [situation] es el contexto situacional vigente en la conversación
  /// ('denuncia_robo', 'violencia'…). Viaja aparte del dominio para que el
  /// motor remoto afine el vocabulario. Nulo en el primer turno, cuando
  /// todavía no se ha declarado ningún contexto.
  Future<LsbTranslationModel> translateText(String text, {String? situation});
}

class RemoteAudioDataSourceImpl implements RemoteAudioDataSource {
  /// Endpoint del API Gateway. Se inyecta en compilación desde `.env` vía
  /// `run.ps1` / `run.sh`, misma convención que el datasource de
  /// declaración. Sin la variable el valor es `''` y el POST falla al
  /// parsear el URI.
  static const String defaultApiGatewayUrl =
      String.fromEnvironment('LSB_TEXT_API_URL');

  /// Tope de espera de la llamada remota, igual que en el datasource de
  /// declaración (RDS-01). Sin él, un turno colgado dejaba la conversación
  /// en «Traduciendo a señas…» **para siempre**: `processing` no bajaba nunca
  /// y la persona oyente no podía ni reintentar ni escribir otra cosa.
  static const Duration requestTimeout = Duration(seconds: 12);

  final http.Client client;
  final String apiGatewayUrl;
  final AnimationUrlResolver animationResolver;

  RemoteAudioDataSourceImpl({
    required this.client,
    this.apiGatewayUrl = defaultApiGatewayUrl,
    this.animationResolver = const AnimationUrlResolver(),
  });

  @override
  Future<LsbTranslationModel> translateAudio(String audioPath) async {
    // Note: Pending implementation for real audio upload,
    // since the current flow uses SpeechToText on device.
    throw UnimplementedError('translateAudio is not used when using On-Device Speech-to-Text.');
  }

  @override
  Future<LsbTranslationModel> translateText(String text,
      {String? situation}) async {
    // Fuera del try: sin `.env` la URL llega vacía y `http` aborta con
    // «Invalid argument(s): No host specified in URI», que el catch de abajo
    // presentaba como caída de red y mandaba a buscar el fallo en la nube.
    // Es un arranque mal configurado, y el mensaje debe decirlo.
    final uri = requireAbsoluteUrl(apiGatewayUrl, 'LSB_TEXT_API_URL');

    try {
      final response = await client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'text': text,
              // Dominio de la aplicación: fijo. De él dependen las reglas de
              // desambiguación jurídica del backend, así que no se sustituye
              // por el contexto situacional — este viaja en 'situation'.
              'context': 'legal',
              if (situation != null && situation.isNotEmpty)
                'situation': situation,
            }),
          )
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        final decodedResponse = jsonDecode(response.body);

        final glossDetails = decodedResponse['glossDetails'] as List<dynamic>? ?? [];

        // Una seña compuesta (`F.glb+ABOGADO.glb`) son varias animaciones de
        // una sola glosa. El visor avanza por índice, así que la glosa se
        // repite tantas veces como animaciones tenga: si las dos listas se
        // desalinean, el avatar acaba rotulando cada seña con el nombre de
        // otra.
        final urls = <String>[];
        final animationGlosses = <String>[];

        if (glossDetails.isNotEmpty) {
          for (final detail in glossDetails) {
            final gloss = (detail['gloss'] ?? '').toString();
            final resolved = animationResolver.resolveAll(
              gloss: gloss,
              animationFile: detail['animationFile']?.toString(),
            );
            urls.addAll(resolved);
            if (AnimationUrlResolver.wordsToSpell.contains(gloss.toUpperCase().trim()) && gloss.trim().length > 1) {
              final letters = gloss.toUpperCase().trim().split('').where((c) => AnimationUrlResolver.available3DGlosses.contains(c)).toList();
              animationGlosses.addAll(letters.isNotEmpty ? letters : List.filled(resolved.length, gloss));
            } else {
              animationGlosses.addAll(List.filled(resolved.length, gloss));
            }
          }
        } else {
          // Si el backend devuelve solo la lista de 'glosses' (ej: ["SI"] o ["HOLA"])
          final glossList = (decodedResponse['glosses'] as List<dynamic>? ?? [])
              .map((g) => g.toString().toUpperCase().trim())
              .toList();

          for (final gloss in glossList) {
            final resolved = animationResolver.resolveAll(gloss: gloss);
            urls.addAll(resolved);
            if (AnimationUrlResolver.wordsToSpell.contains(gloss) && gloss.length > 1) {
              final letters = gloss.split('').where((c) => AnimationUrlResolver.available3DGlosses.contains(c)).toList();
              animationGlosses.addAll(letters.isNotEmpty ? letters : List.filled(resolved.length, gloss));
            } else {
              animationGlosses.addAll(List.filled(resolved.length, gloss));
            }
          }
        }

        // Si aún así no hay URLs pero sí texto original
        if (urls.isEmpty && text.trim().isNotEmpty) {
          final singleGloss = text.trim().toUpperCase();
          final resolved = animationResolver.resolveAll(gloss: singleGloss);
          urls.addAll(resolved);
          animationGlosses.add(singleGloss);
        }

        // Si el backend devolvió glosses múltiples (ej. ["HOLA", "SI"]) pero no en glossDetails
        final effectiveGlosses = animationGlosses.isNotEmpty
            ? animationGlosses
            : (decodedResponse['glosses'] as List<dynamic>? ?? [])
                .map((e) => e.toString().toUpperCase())
                .toList();

        // Garantizar que la lista de URLs coincida 1:1 con la cantidad de glosas
        final finalUrls = <String>[];
        for (int i = 0; i < effectiveGlosses.length; i++) {
          if (i < urls.length) {
            finalUrls.add(urls[i]);
          } else {
            finalUrls.add('${animationResolver.baseUrl}avatar_test.glb');
          }
        }

        // 'glosses' es la lista semántica (una entrada por glosa real, para
        // la inferencia de contexto); 'animationGlosses' es la expandida
        // (una entrada por animación, alineada con animationUrls). Una seña
        // compuesta (FISCAL = F.glb+ABOGADO.glb) tiene dos animaciones pero
        // sigue siendo UNA glosa: usar effectiveGlosses para ambas contaba
        // FISCAL dos veces en la lista semántica. El backend ya manda la
        // lista semántica correcta en 'glosses'; solo se cae a la expandida
        // cuando esa lista no vino (por ejemplo, el respaldo de solo-texto).
        final semanticGlosses = (decodedResponse['glosses'] as List<dynamic>?)
                ?.map((e) => e.toString().toUpperCase().trim())
                .toList() ??
            effectiveGlosses;

        // Decodificamos el JSON que viene de AWS Lambda (Bedrock)
        return LsbTranslationModel.fromJson({
          'glosses': semanticGlosses,
          'animationUrl': finalUrls.isNotEmpty ? finalUrls.first : '',
          'animationUrls': finalUrls,
          'animationGlosses': effectiveGlosses,
          'disambiguation': decodedResponse['disambiguation'],
        });
      } else {
        throw Exception('AWS API Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Network or Server error: $e');
    }
  }
}
