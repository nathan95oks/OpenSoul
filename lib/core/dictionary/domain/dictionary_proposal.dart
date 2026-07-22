/// Propuesta de la comunidad para el diccionario evolutivo.
///
/// Nace en la app cuando una palabra o seña no existe en el lexicón.
/// Se envía a `POST /dictionary/proposals` y queda almacenada como
/// `pending`: NUNCA modifica el diccionario oficial ni el comunitario.
/// La aprobación ocurre exclusivamente en el Portal Web de validación
/// (Fase 4), donde validadores no técnicos revisan, editan, prueban en el
/// avatar y aprueban o rechazan.
class DictionaryProposal {
  /// Palabra o glosa propuesta (obligatoria).
  final String word;

  /// Qué significa y cuándo se usa, en palabras del proponente.
  final String description;

  /// Categoría semántica sugerida (opcional; el validador puede corregirla).
  final String? categoryId;

  /// Contextos situacionales donde surgió la necesidad ('violencia', …).
  final List<String> contexts;

  /// Video de la seña (URL) si el proponente lo tiene. La grabación
  /// dentro de la app llegará después; el contrato ya lo transporta.
  final String? videoUrl;

  final String dialect;

  /// Nombre libre del proponente (opcional; no hay cuentas en la app).
  final String? proposedBy;

  final DateTime createdAt;

  DictionaryProposal({
    required this.word,
    required this.description,
    this.categoryId,
    this.contexts = const [],
    this.videoUrl,
    this.dialect = 'cochabamba',
    this.proposedBy,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'word': word,
        'description': description,
        if (categoryId != null && categoryId!.isNotEmpty)
          'categoryId': categoryId,
        if (contexts.isNotEmpty) 'contexts': contexts,
        if (videoUrl != null && videoUrl!.isNotEmpty) 'videoUrl': videoUrl,
        'dialect': dialect,
        if (proposedBy != null && proposedBy!.isNotEmpty)
          'proposedBy': proposedBy,
        'clientCreatedAt': createdAt.toUtc().toIso8601String(),
      };

  factory DictionaryProposal.fromJson(Map<String, dynamic> json) {
    return DictionaryProposal(
      word: json['word'] as String,
      description: json['description'] as String? ?? '',
      categoryId: json['categoryId'] as String?,
      contexts: List<String>.from(json['contexts'] as List? ?? const []),
      videoUrl: json['videoUrl'] as String?,
      dialect: json['dialect'] as String? ?? 'cochabamba',
      proposedBy: json['proposedBy'] as String?,
      createdAt: DateTime.tryParse(json['clientCreatedAt'] as String? ?? ''),
    );
  }
}

/// Desenlace del envío de una propuesta.
///
/// - [sent]: llegó al backend y quedó `pending`.
/// - [queued]: sin conexión (o sin endpoint); quedó en la cola local y se
///   reenviará automáticamente en la próxima sincronización.
/// - [failed]: no se pudo enviar NI encolar (fallo de disco). El usuario
///   debe reintentar.
enum ProposalSubmissionResult { sent, queued, failed }
