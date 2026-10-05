import 'dart:convert';

import 'package:lsb_legal_app/core/domain/services/pending_sign.dart';

/// Qué es una palabra sin seña propia en los módulos M1–M4 ni en el II
/// Diccionario 2024: lo que la app muestra al deslizar o tocar esa palabra,
/// en lugar de una seña que no existe.
class PendingSignInfo {
  /// La palabra en español, como se muestra: «FOLIO REAL».
  final String word;

  /// Qué es, en pocas palabras. Vacío si nadie la describió todavía.
  final String description;

  /// [description] en LSB: la secuencia de glosas que dio la Lambda
  /// Texto→LSB con la frase entera (`tool/rag_descripciones_lsb.py`). Vacía
  /// si aún no se tradujo; entonces se muestra el español.
  final List<String> lsbDescription;

  /// Una frase del trámite donde aparece.
  final String example;

  /// Un nombre propio (calle, edificio, institución): se deletrea.
  final bool isProperName;

  /// Una persona confirmó la descripción. Si no, es un borrador.
  final bool reviewed;

  const PendingSignInfo({
    required this.word,
    this.description = '',
    this.lsbDescription = const [],
    this.example = '',
    this.isProperName = false,
    this.reviewed = false,
  });
}

/// Las descripciones generadas por `tool/build_rag_corpus.py`
/// (`assets/dictionary/senas_sin_sena.json`).
class PendingSignCatalog {
  final Map<String, PendingSignInfo> _byKey;

  const PendingSignCatalog._(this._byKey);

  static const PendingSignCatalog empty = PendingSignCatalog._({});

  factory PendingSignCatalog.fromJsonString(String raw) {
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final words = (data['palabras'] as Map<String, dynamic>? ?? const {});
    return PendingSignCatalog._({
      for (final MapEntry(key: key, value: v) in words.entries)
        key: PendingSignInfo(
          word: key.replaceAll('_', ' '),
          description: '${(v as Map<String, dynamic>)['descripcion'] ?? ''}',
          lsbDescription: [
            for (final g in (v['descripcionLsb'] as List? ?? const [])) '$g',
          ],
          example: '${v['ejemplo'] ?? ''}',
          isProperName: v['tipo'] == 'nombre_propio',
          reviewed: v['revisada'] == true,
        ),
    });
  }

  /// Lo que se sabe de [gloss] (`SENA_PENDIENTE:FOLIO_REAL`). Una palabra sin
  /// descripción da al menos su nombre: la app dice que no tiene seña.
  PendingSignInfo infoOf(String gloss) {
    final key = PendingSign.isPending(gloss)
        ? gloss.substring(PendingSign.prefix.length)
        : gloss;
    return _byKey[key] ??
        PendingSignInfo(word: PendingSign.wordOf(PendingSign.prefix + key));
  }
}
