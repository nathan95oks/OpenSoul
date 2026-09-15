import 'package:lsb_legal_app/core/domain/entities/semantic_message.dart';

class LsbTranslation {
  final List<String> glosses;
  final String animationUrl;
  final List<String> animationUrls;
  final List<String> animationGlosses;
  final List<SemanticDisambiguation> disambiguations;

  /// Términos con más de un significado plausible que la persona emisora
  /// tiene que resolver. Mientras esta lista no esté vacía, la traducción no
  /// afirma ningún sentido para esos términos y no debería reproducirse
  /// como si estuviera terminada.
  final List<PendingClarification> pendingClarifications;
  final SemanticStatus semanticStatus;
  final RepresentationStatus representationStatus;

  bool get needsClarification =>
      semanticStatus == SemanticStatus.needsClarification ||
      pendingClarifications.isNotEmpty;

  LsbTranslation({
    required this.glosses,
    required this.animationUrl,
    this.animationUrls = const [],
    this.animationGlosses = const [],
    this.disambiguations = const [],
    this.pendingClarifications = const [],
    this.semanticStatus = SemanticStatus.resolved,
    this.representationStatus = RepresentationStatus.complete,
  });
}
