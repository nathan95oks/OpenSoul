/// Expresiones visuales no manuales que la interfaz puede mostrar junto al
/// avatar. No modifican el clip 3D ni sustituyen una validación lingüística.
enum AvatarFacialExpression { fear, sadness, worry, confidence, pain }

extension AvatarFacialExpressionInfo on AvatarFacialExpression {
  String get accessibleLabel => switch (this) {
    AvatarFacialExpression.fear => 'miedo',
    AvatarFacialExpression.sadness => 'tristeza',
    AvatarFacialExpression.worry => 'preocupación',
    AvatarFacialExpression.confidence => 'confianza',
    AvatarFacialExpression.pain => 'dolor',
  };

  String get keyName => switch (this) {
    AvatarFacialExpression.fear => 'miedo',
    AvatarFacialExpression.sadness => 'tristeza',
    AvatarFacialExpression.worry => 'preocupacion',
    AvatarFacialExpression.confidence => 'confianza',
    AvatarFacialExpression.pain => 'dolor',
  };
}

/// Asociación explícita entre glosas y expresiones.
///
/// Se mantiene deliberadamente pequeña: una expresión solo entra aquí después
/// de revisar su significado y probarla visualmente. No se infieren emociones
/// a partir de otras palabras de la frase.
abstract final class AvatarFacialExpressions {
  static const Map<String, AvatarFacialExpression> _byGloss = {
    'MIEDO': AvatarFacialExpression.fear,
    'TRISTE': AvatarFacialExpression.sadness,
    'PREOCUPAR': AvatarFacialExpression.worry,
    'CONFIANZA': AvatarFacialExpression.confidence,
    'DOLOR': AvatarFacialExpression.pain,
  };

  static AvatarFacialExpression? forGloss(String gloss) {
    final canonical = gloss.trim().toUpperCase().replaceAll(' ', '_');
    return _byGloss[canonical];
  }
}
