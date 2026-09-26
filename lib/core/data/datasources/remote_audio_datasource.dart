import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:lsb_legal_app/core/data/models/lsb_translation_model.dart';
import 'package:lsb_legal_app/core/network/endpoint_uri.dart';
import 'package:lsb_legal_app/core/domain/services/animation_url_resolver.dart';

abstract class RemoteAudioDataSource {
  Future<LsbTranslationModel> translateText(
    String text, {
    String? situation,
    Map<String, String>? resolvedSenses,
  });
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
  Future<LsbTranslationModel> translateText(
    String text, {
    String? situation,
    Map<String, String>? resolvedSenses,
  }) async {
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
              if (resolvedSenses != null && resolvedSenses.isNotEmpty)
                'resolvedSenses': resolvedSenses,
            }),
          )
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        final decodedResponse = jsonDecode(response.body);

        final glossDetails = decodedResponse['glossDetails'] as List<dynamic>? ?? [];
        final sequence = decodedResponse['animationSequence'] as List<dynamic>? ?? [];
        final urls = <String>[];
        final animationGlosses = <String>[];

        if (sequence.isNotEmpty) {
          // El servidor lee los clips del propio .glb en S3 y ya decidio, por
          // glosa, si hay sena o si se deletrea (una letra sin clip viene sin
          // animationFile y va como placeholder). La URL no se toma de la
          // respuesta: siempre es el .glb de [baseUrl].
          for (final step in sequence) {
            final gloss = (step['gloss'] ?? '').toString();
            if (gloss.isEmpty) continue;
            final hasClip = (step['animationFile']?.toString() ?? '').isNotEmpty;
            urls.add(hasClip
                ? '${animationResolver.baseUrl}avatar_test.glb'
                : '${AnimationUrlResolver.placeholderScheme}'
                    '${AnimationUrlResolver.canonicalFor(gloss)}');
            animationGlosses.add(gloss);
          }
        } else if (glossDetails.isNotEmpty) {
          for (final detail in glossDetails) {
            final gloss = (detail['gloss'] ?? '').toString();
            final resolved = animationResolver.resolveAll(
              gloss: gloss,
              animationFile: detail['animationFile']?.toString(),
            );
            urls.addAll(resolved);
            final letters = AnimationUrlResolver.spelledLetters(gloss);
            animationGlosses.addAll(
              letters ?? List.filled(resolved.length, gloss),
            );
          }
        } else {
          final glossList = (decodedResponse['glosses'] as List<dynamic>? ?? [])
              .map((g) => g.toString().toUpperCase().trim())
              .toList();

          for (final gloss in glossList) {
            final resolved = animationResolver.resolveAll(gloss: gloss);
            urls.addAll(resolved);
            final letters = AnimationUrlResolver.spelledLetters(gloss);
            animationGlosses.addAll(
              letters ?? List.filled(resolved.length, gloss),
            );
          }
        }

        if (urls.isEmpty && text.trim().isNotEmpty) {
          final singleGloss = text.trim().toUpperCase();
          final resolved = animationResolver.resolveAll(gloss: singleGloss);
          urls.addAll(resolved);
          animationGlosses.add(singleGloss);
        }

        // Colapsar compuestos multipalabra (ej: "COMO" + deletreo "ESTAS" -> "COMO_ESTAS")
        // protegiendo contra respuestas fragmentadas o desactualizadas del backend.
        _collapseCompoundAnimations(animationGlosses, urls, text);

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

        final rawSemantic = (decodedResponse['glosses'] as List<dynamic>?)
                ?.map((e) => e.toString().toUpperCase().trim())
                .toList() ??
            effectiveGlosses;
        final semanticGlosses = _collapseSemanticCompounds(rawSemantic, text);

        return LsbTranslationModel.fromJson({
          'glosses': semanticGlosses,
          'animationUrl': finalUrls.isNotEmpty ? finalUrls.first : '',
          'animationUrls': finalUrls,
          'animationGlosses': effectiveGlosses,
          'disambiguation': decodedResponse['disambiguation'],
          'pendingClarifications': decodedResponse['pendingClarifications'],
          'semanticStatus': decodedResponse['semanticStatus'],
          'representationStatus': decodedResponse['representationStatus'],
        });
      } else {
        throw Exception('AWS API Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Network or Server error: $e');
    }
  }

  static final RegExp _punct = RegExp(r'[^\w\s]', unicode: true);

  static List<String> _textWords(String text) {
    final clean = AnimationUrlResolver.stripAccents(text.toUpperCase())
        .replaceAll(_punct, ' ');
    return clean.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  }

  static const List<(String, String, List<String>)> _compounds = [
    ('COMO ESTAS', 'COMO_ESTAS', ['COMO', 'ESTAS', 'ESTA', 'ESTAR', 'BIEN', 'TU', 'YO']),
    ('COMO ESTA', 'COMO_ESTAS', ['COMO', 'ESTAS', 'ESTA', 'ESTAR', 'BIEN', 'TU', 'YO']),
    ('POR FAVOR', 'POR_FAVOR', ['POR', 'FAVOR']),
    ('LO SIENTO', 'LO_SIENTO', ['LO', 'SIENTO', 'SENTIR']),
    ('NO PUEDO', 'NO_PUEDO', ['NO', 'PUEDO', 'PUEDE', 'PODER']),
    ('NO SE', 'NO_SABER', ['NO', 'SE', 'SABER', 'SABE']),
    ('NO SABER', 'NO_SABER', ['NO', 'SE', 'SABER', 'SABE']),
    ('PARA QUE', 'PARA_QUE', ['PARA', 'QUE']),
    ('POR QUE', 'POR_QUE', ['POR', 'QUE', 'PORQUE']),
    ('PRIMERA VEZ', 'PRIMERA_VEZ', ['PRIMERA', 'PRIMERO', 'VEZ']),
  ];

  static List<String> _collapseSemanticCompounds(
    List<String> glosses,
    String text,
  ) {
    final words = _textWords(text);
    final joined = words.join(' ');
    var result = List<String>.from(glosses);

    for (final (phrase, target, constituents) in _compounds) {
      if (!joined.contains(phrase)) continue;
      if (result.contains(target)) {
        result = result
            .where((g) =>
                !constituents.contains(AnimationUrlResolver.canonicalFor(g)) ||
                g == target)
            .toList();
        continue;
      }
      final firstIdx = result.indexWhere((g) =>
          constituents.contains(AnimationUrlResolver.canonicalFor(g)));
      if (firstIdx != -1) {
        result[firstIdx] = target;
        result = [
          for (int i = 0; i < result.length; i++)
            if (i == firstIdx ||
                !constituents
                    .contains(AnimationUrlResolver.canonicalFor(result[i])))
              result[i],
        ];
      }
    }
    return result;
  }

  void _collapseCompoundAnimations(
    List<String> animationGlosses,
    List<String> urls,
    String text,
  ) {
    final words = _textWords(text);
    final joined = words.join(' ');
    final modelUrl = '${animationResolver.baseUrl}avatar_test.glb';

    for (final (phrase, target, constituents) in _compounds) {
      if (!joined.contains(phrase)) continue;

      final targetIdx = animationGlosses.indexOf(target);
      if (targetIdx != -1) {
        final toRemove = <int>[];
        for (int i = 0; i < animationGlosses.length; i++) {
          if (i == targetIdx) continue;
          final g = AnimationUrlResolver.canonicalFor(animationGlosses[i]);
          if (constituents.contains(g)) {
            toRemove.add(i);
          }
        }
        for (final idx in toRemove.reversed) {
          animationGlosses.removeAt(idx);
          if (idx < urls.length) urls.removeAt(idx);
        }
        continue;
      }

      final constituentSet = constituents.toSet();
      int? firstOccurrence;
      final indicesToRemove = <int>[];

      int i = 0;
      while (i < animationGlosses.length) {
        final g = AnimationUrlResolver.canonicalFor(animationGlosses[i]);
        if (constituentSet.contains(g)) {
          if (firstOccurrence == null) {
            firstOccurrence = i;
          } else {
            indicesToRemove.add(i);
          }
          i++;
          continue;
        }

        bool matchedSpelling = false;
        final candidates = constituents.where((c) => c.length > 1).toList()
          ..sort((a, b) => b.length.compareTo(a.length));
        for (final c in candidates) {
          if (i + c.length <= animationGlosses.length) {
            final letters = c.split('');
            bool allMatch = true;
            for (int k = 0; k < letters.length; k++) {
              if (AnimationUrlResolver.canonicalFor(animationGlosses[i + k]) !=
                  letters[k]) {
                allMatch = false;
                break;
              }
            }
            if (allMatch) {
              if (firstOccurrence == null) {
                firstOccurrence = i;
                for (int k = 1; k < letters.length; k++) {
                  indicesToRemove.add(i + k);
                }
              } else {
                for (int k = 0; k < letters.length; k++) {
                  indicesToRemove.add(i + k);
                }
              }
              i += letters.length;
              matchedSpelling = true;
              break;
            }
          }
        }

        if (!matchedSpelling) {
          i++;
        }
      }

      if (firstOccurrence != null) {
        animationGlosses[firstOccurrence] = target;
        if (firstOccurrence < urls.length) {
          urls[firstOccurrence] = modelUrl;
        } else {
          urls.add(modelUrl);
        }
        for (final idx in indicesToRemove.reversed) {
          animationGlosses.removeAt(idx);
          if (idx < urls.length) urls.removeAt(idx);
        }
      }
    }
  }
}
