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

  /// La palabra existe en LSB (es una seña, o equivale a una), pero el avatar
  /// todavía no tiene su animación: [lsbDescription] dice con qué seña se
  /// dice.
  final bool hasLsbSign;

  /// Dónde está la seña: «M3 · General I · p.111». Vacío si no se sabe.
  final String source;

  const PendingSignInfo({
    required this.word,
    this.description = '',
    this.lsbDescription = const [],
    this.example = '',
    this.isProperName = false,
    this.reviewed = false,
    this.hasLsbSign = false,
    this.source = '',
  });
}

/// Las descripciones generadas por `tool/build_rag_corpus.py`
/// (`assets/dictionary/senas_sin_sena.json`).
class PendingSignCatalog {
  final Map<String, PendingSignInfo> _byKey;

  /// Palabra → señas equivalentes aprobadas (`COMPROBANTE` → FACTURA): la
  /// palabra se seña con ellas, igual que en las tarjetas.
  final Map<String, List<String>> _equivalents;

  const PendingSignCatalog._(this._byKey, [this._equivalents = const {}]);

  static const PendingSignCatalog empty = PendingSignCatalog._({});

  factory PendingSignCatalog.fromJsonString(String raw) {
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final words = (data['palabras'] as Map<String, dynamic>? ?? const {});
    return PendingSignCatalog._(
      {
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
      },
      {
        for (final MapEntry(key: key, value: v)
            in (data['equivalencias'] as Map<String, dynamic>? ?? const {})
                .entries)
          _plain(key): [for (final g in v as List) '$g'],
      },
    );
  }

  /// Las señas con que se dice [word] cuando tiene una equivalencia aprobada
  /// («comprobante» → FACTURA), o `null`.
  List<String>? equivalentSigns(String word) => _equivalents[_plain(word)];

  /// Lo que se sabe de [gloss] (`SENA_PENDIENTE:FOLIO_REAL`). Una palabra sin
  /// descripción da al menos su nombre: la app dice que no tiene seña.
  PendingSignInfo infoOf(String gloss) {
    final key = PendingSign.isPending(gloss)
        ? gloss.substring(PendingSign.prefix.length)
        : gloss;
    return _byKey[key] ??
        PendingSignInfo(word: PendingSign.wordOf(PendingSign.prefix + key));
  }

  /// La glosa pendiente con que se explica [word], tal como la escribió el
  /// backend («Hipoteca», «FOLIO REAL», «catastro»), o `null` si no hay
  /// descripción que mostrar: entonces la palabra se deletrea. Un nombre
  /// propio también se deletrea.
  String? describedGloss(String word) {
    final key = _byPlainKey[_plain(word)];
    final info = key == null ? null : _byKey[key];
    if (info == null ||
        (info.description.isEmpty && info.lsbDescription.isEmpty) ||
        info.isProperName) {
      return null;
    }
    return PendingSign.prefix + key!;
  }

  // El catálogo es const (tiene [empty]): el índice se guarda aparte.
  static final Expando<Map<String, String>> _indices = Expando();

  Map<String, String> get _byPlainKey =>
      _indices[this] ??= {for (final key in _byKey.keys) _plain(key): key};

  /// Mayúsculas, sin tildes (la Ñ se queda: es otra letra) y con `_` entre
  /// palabras, como las claves del catálogo.
  static String _plain(String word) {
    const from = 'ÁÀÄÂÉÈËÊÍÌÏÎÓÒÖÔÚÙÜÛ';
    const to = 'AAAAEEEEIIIIOOOOUUUU';
    var out = word.toUpperCase().trim();
    for (var i = 0; i < from.length; i++) {
      out = out.replaceAll(from[i], to[i]);
    }
    return out.replaceAll(RegExp(r'[\s_]+'), '_');
  }
}
