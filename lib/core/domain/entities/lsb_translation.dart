import 'package:lsb_legal_app/core/domain/entities/semantic_message.dart';

class LsbTranslation {
  final List<String> glosses;
  final String animationUrl;
  final List<String> animationUrls;
  final List<String> animationGlosses;
  final List<SemanticDisambiguation> disambiguations;

  LsbTranslation({
    required this.glosses,
    required this.animationUrl,
    this.animationUrls = const [],
    this.animationGlosses = const [],
    this.disambiguations = const [],
  });
}
