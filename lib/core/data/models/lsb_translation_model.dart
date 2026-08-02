import 'package:lsb_legal_app/core/domain/entities/lsb_translation.dart';
import 'package:lsb_legal_app/core/domain/entities/semantic_message.dart';

class LsbTranslationModel extends LsbTranslation {
  LsbTranslationModel({
    required super.glosses,
    required super.animationUrl,
    super.animationUrls = const [],
    super.disambiguations = const [],
  });

  factory LsbTranslationModel.fromJson(Map<String, dynamic> json) {
    return LsbTranslationModel(
      glosses: List<String>.from(json['glosses'] ?? []),
      animationUrl: json['animationUrl'] ?? '',
      animationUrls: List<String>.from(json['animationUrls'] ?? []),
      disambiguations: [
        for (final item in (json['disambiguation'] as List? ?? const []))
          SemanticDisambiguation.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
      ],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'glosses': glosses,
      'animationUrl': animationUrl,
      'animationUrls': animationUrls,
      'disambiguation': [
        for (final d in disambiguations)
          {'original': d.original, 'meaning': d.meaning, 'reason': d.reason},
      ],
    };
  }
}
