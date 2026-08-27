import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:lsb_legal_app/core/data/models/lsb_translation_model.dart';
import 'package:lsb_legal_app/core/network/endpoint_uri.dart';
import 'package:lsb_legal_app/core/data/datasources/animation_url_resolver.dart';

abstract class RemoteAudioDataSource {
  Future<LsbTranslationModel> translateText(String text, {String? situation});
}

class RemoteAudioDataSourceImpl implements RemoteAudioDataSource {
  static const String defaultApiGatewayUrl =
      String.fromEnvironment('LSB_TEXT_API_URL');

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
  Future<LsbTranslationModel> translateText(String text,
      {String? situation}) async {
    final uri = requireAbsoluteUrl(apiGatewayUrl, 'LSB_TEXT_API_URL');

    try {
      final response = await client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'text': text,
              'context': 'legal',
              if (situation != null && situation.isNotEmpty)
                'situation': situation,
            }),
          )
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        final decodedResponse = jsonDecode(response.body);

        final glossDetails = decodedResponse['glossDetails'] as List<dynamic>? ?? [];
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
            animationGlosses.addAll(List.filled(resolved.length, gloss));
          }
        } else {
          final glossList = (decodedResponse['glosses'] as List<dynamic>? ?? [])
              .map((g) => g.toString().toUpperCase().trim())
              .toList();

          for (final gloss in glossList) {
            final resolved = animationResolver.resolveAll(gloss: gloss);
            urls.addAll(resolved);
            animationGlosses.addAll(List.filled(resolved.length, gloss));
          }
        }

        if (urls.isEmpty && text.trim().isNotEmpty) {
          final singleGloss = text.trim().toUpperCase();
          final resolved = animationResolver.resolveAll(gloss: singleGloss);
          urls.addAll(resolved);
          animationGlosses.add(singleGloss);
        }

        final effectiveGlosses = animationGlosses.isNotEmpty
            ? animationGlosses
            : (decodedResponse['glosses'] as List<dynamic>? ?? [])
                .map((e) => e.toString().toUpperCase())
                .toList();

        final finalUrls = <String>[];
        for (int i = 0; i < effectiveGlosses.length; i++) {
          if (i < urls.length) {
            finalUrls.add(urls[i]);
          } else {
            finalUrls.add('${animationResolver.baseUrl}avatar_test.glb');
          }
        }

        final semanticGlosses = (decodedResponse['glosses'] as List<dynamic>?)
                ?.map((e) => e.toString().toUpperCase().trim())
                .toList() ??
            effectiveGlosses;

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
