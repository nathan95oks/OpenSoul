import 'package:lsb_legal_app/core/domain/entities/lsb_translation.dart';
import 'package:lsb_legal_app/core/domain/entities/semantic_message.dart';

class LsbTranslationModel extends LsbTranslation {
  LsbTranslationModel({
    required super.glosses,
    required super.animationUrl,
    super.animationUrls = const [],
    super.animationGlosses = const [],
    super.disambiguations = const [],
    super.pendingClarifications = const [],
    super.semanticStatus = SemanticStatus.resolved,
    super.representationStatus = RepresentationStatus.complete,
  });

  factory LsbTranslationModel.fromJson(Map<String, dynamic> json) {
    return LsbTranslationModel(
      glosses: List<String>.from(json['glosses'] ?? []),
      animationUrl: json['animationUrl'] ?? '',
      animationUrls: List<String>.from(json['animationUrls'] ?? []),
      animationGlosses: List<String>.from(json['animationGlosses'] ?? []),
      disambiguations: [
        for (final item in (json['disambiguation'] as List? ?? const []))
          SemanticDisambiguation.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
      ],
      pendingClarifications: [
        for (final item in (json['pendingClarifications'] as List? ?? const []))
          PendingClarification.fromJson(Map<String, dynamic>.from(item as Map)),
      ],
      semanticStatus: semanticStatusFromJson(json['semanticStatus']?.toString()),
      representationStatus:
          representationStatusFromJson(json['representationStatus']?.toString()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'glosses': glosses,
      'animationUrl': animationUrl,
      'animationUrls': animationUrls,
      'animationGlosses': animationGlosses,
      'disambiguation': [
        for (final d in disambiguations)
          {'original': d.original, 'meaning': d.meaning, 'reason': d.reason},
      ],
      'pendingClarifications': [
        for (final p in pendingClarifications)
          {
            'term': p.term,
            'question': p.question,
            'options': [
              for (final o in p.options) {'id': o.id, 'label': o.label},
            ],
          },
      ],
      'semanticStatus': semanticStatus == SemanticStatus.needsClarification
          ? 'needs_clarification'
          : 'resolved',
      'representationStatus':
          representationStatus == RepresentationStatus.partial ? 'partial' : 'complete',
    };
  }
}
