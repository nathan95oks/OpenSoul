import 'package:lsb_legal_app/core/domain/conversation/semantic_turn.dart';
import 'package:lsb_legal_app/core/domain/entities/semantic_message.dart';
import 'package:lsb_legal_app/core/domain/services/pending_sign_info.dart';

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

  /// Qué pide el mensaje, leído en la misma traducción (sin otra llamada al
  /// modelo). `null` si el backend todavía no lo envía.
  final BackendSemanticTurn? semanticTurn;

  /// Las palabras que no son una seña del catálogo y por eso el backend
  /// deletreó (`fidelityFixes` con «concepto_sin_catalogo»), en el orden en
  /// que las informó. Con ellas se sabe qué letras de [animationGlosses]
  /// forman una palabra que se puede explicar en vez de deletrear.
  final List<String> spelledWords;

  /// Señas del catálogo que el backend deletreó porque el avatar no tiene su
  /// clip (`glossDetails` con «available»: false): existen en LSB.
  final List<String> unanimatedSigns;

  /// Qué mostrar delante del avatar en cada paso `SENA_PENDIENTE:…` de
  /// [animationGlosses] (ver `DescribedWordSteps`).
  final Map<String, PendingSignInfo> stepDescriptions;

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
    this.semanticTurn,
    this.spelledWords = const [],
    this.unanimatedSigns = const [],
    this.stepDescriptions = const {},
  });
}
