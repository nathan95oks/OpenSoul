import '../../domain/entities/lsb_translation.dart';

class LsbTranslationModel extends LsbTranslation {
  LsbTranslationModel({
    required super.glosses,
    required super.animationUrl,
    super.animationUrls = const [],
  });

  factory LsbTranslationModel.fromJson(Map<String, dynamic> json) {
    return LsbTranslationModel(
      glosses: List<String>.from(json['glosses'] ?? []),
      animationUrl: json['animationUrl'] ?? '',
      animationUrls: List<String>.from(json['animationUrls'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'glosses': glosses,
      'animationUrl': animationUrl,
      'animationUrls': animationUrls,
    };
  }
}
