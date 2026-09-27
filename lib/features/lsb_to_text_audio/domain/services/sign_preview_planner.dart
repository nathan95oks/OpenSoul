import 'package:lsb_legal_app/core/domain/services/animation_url_resolver.dart';

/// Lo que el avatar reproduce para previsualizar una tarjeta.
///
/// [glosses] es la secuencia de la tarjeta, en el orden en que se muestra.
/// [animationUrls] y [animationGlosses] van paso a paso, una entrada por
/// animación: una glosa que se deletrea ocupa un paso por letra, rotulado con
/// la letra que el avatar está haciendo.
class SignPreviewPlan {
  final List<String> glosses;
  final List<String> animationUrls;
  final List<String> animationGlosses;

  const SignPreviewPlan({
    required this.glosses,
    required this.animationUrls,
    required this.animationGlosses,
  });

  /// Hay al menos una seña que el avatar sabe hacer. Una secuencia hecha solo
  /// de marcadores de posición no tiene nada que enseñar.
  bool get isPlayable => animationUrls.any(
    (url) => !url.startsWith(AnimationUrlResolver.placeholderScheme),
  );
}

/// Pasa una secuencia de glosas a los pasos del avatar, en el dispositivo.
///
/// Usa el mismo [AnimationUrlResolver] que el avatar de audio/texto → LSB:
/// seña horneada en el modelo, deletreo de los términos que el sistema ya
/// deletrea o marcador de posición. No consulta la red ni inventa clips.
class SignPreviewPlanner {
  final AnimationUrlResolver resolver;

  const SignPreviewPlanner({this.resolver = const AnimationUrlResolver()});

  SignPreviewPlan plan(List<String> glosses) {
    final urls = <String>[];
    final steps = <String>[];
    for (final gloss in glosses) {
      final resolved = resolver.resolveAll(gloss: gloss);
      final letters = AnimationUrlResolver.spelledLetters(gloss);
      urls.addAll(resolved);
      // Un rótulo por animación: si no casaran, el avatar rotularía una
      // glosa mientras hace otra.
      steps.addAll(
        letters != null && letters.length == resolved.length
            ? letters
            : List.filled(resolved.length, gloss),
      );
    }
    return SignPreviewPlan(
      glosses: List.unmodifiable(glosses),
      animationUrls: List.unmodifiable(urls),
      animationGlosses: List.unmodifiable(steps),
    );
  }
}
