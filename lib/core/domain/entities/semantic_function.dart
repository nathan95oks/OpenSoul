/// Qué papel puede jugar una glosa dentro de una frase.
///
/// No es una clasificación nueva: es la que el ensamblador ya usa para
/// redactar (`_Role`), expuesta para que la selección de respuestas y la
/// redacción no puedan discrepar. Si una glosa se ofrece como respuesta de
/// lugar pero el ensamblador la trata como verbo, la frase saldrá rara y
/// nadie sabrá por qué; con una sola tabla eso no puede pasar.
enum SemanticFunction {
  /// Quién realiza o padece: YO, ÉL, HOMBRE, TESTIGO, AMIGO…
  participant,

  /// Cómo es alguien: ALTO, JOVEN, MOCHILA (como prenda)…
  trait,

  /// Qué ocurrió: ROBAR, ESCAPAR, GOLPEAR…
  action,

  /// Qué cosa: CELULAR, BILLETES, MOCHILA…
  object,

  /// Papeles y comprobantes: PAPEL, FOTOS, CERTIFICADO…
  document,

  /// Dónde: CALLE, PLAZA, AQUÍ, CERCA…
  place,

  /// Quién atiende: POLICÍA, FISCALÍA, ALCALDÍA…
  institution,

  /// Qué se pide o gestiona: ABOGADO, INTÉRPRETE, TRÁMITE…
  service,

  /// Cómo se siente o cuánto urge: MIEDO, URGENTE…
  state,

  /// Por qué: los motivos declarados.
  reason,

  /// Cuándo: HOY, AYER, NOCHE, HORA…
  time,

  /// Piezas que modifican a otra respuesta: cantidades, negación, marcas.
  marker,

  /// Palabras interrogativas: ¿DÓNDE?, ¿QUIÉN?, ¿CUÁNDO?…
  interrogative;

  /// Los campos de respuesta que esta función puede rellenar.
  ///
  /// Una glosa puede servir a más de uno: CELULAR es objeto de un robo y
  /// también medio de contacto. La pertinencia la decide el campo que se está
  /// respondiendo, no la glosa por sí sola.
  Set<String> get fields => switch (this) {
        SemanticFunction.participant => {'person'},
        SemanticFunction.trait => {'person'},
        SemanticFunction.action => {'free_text'},
        SemanticFunction.object => {'object', 'evidence'},
        SemanticFunction.document => {'evidence', 'object'},
        SemanticFunction.place => {'place'},
        SemanticFunction.institution => {'institution', 'place'},
        SemanticFunction.service => {'institution', 'free_text'},
        SemanticFunction.state => {'free_text'},
        SemanticFunction.reason => {'free_text'},
        SemanticFunction.time => {'time'},
        // Los marcadores acompañan a otra respuesta (cantidad, negación), así
        // que no se restringen: el editor de detalles decide si caben.
        SemanticFunction.marker => const {},
        SemanticFunction.interrogative => {'free_text'},
      };
}
