import 'dart:convert';

import 'package:lsb_legal_app/core/domain/services/pending_sign.dart';
import 'package:lsb_legal_app/core/domain/text/spanish_text.dart';

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

  /// Una sigla (FELCC, NUREJ): se deletrea, pero tiene descripción.
  final bool isAcronym;

  /// Una persona confirmó la descripción. Si no, es un borrador.
  final bool reviewed;

  /// La palabra existe en LSB (es una seña, o equivale a una), pero el avatar
  /// todavía no tiene su animación: [lsbDescription] dice con qué seña se
  /// dice.
  final bool hasLsbSign;

  /// Dónde está la seña: «M3 · General I · p.111». Vacío si no se sabe.
  final String source;

  /// Los sentidos de una palabra que cambia según la frase («pasar»: ocurrir,
  /// entrar, cambiar de dueño). Vacía si la palabra tiene un solo sentido.
  final List<PendingSignContext> contexts;

  const PendingSignInfo({
    required this.word,
    this.description = '',
    this.lsbDescription = const [],
    this.example = '',
    this.isProperName = false,
    this.isAcronym = false,
    this.reviewed = false,
    this.hasLsbSign = false,
    this.source = '',
    this.contexts = const [],
  });

  /// Lo que es la palabra en la frase [sentence]: el primer sentido cuya
  /// palabra o frase aparece en ella. Sin frase, o si ninguno aparece, la
  /// descripción general (que nombra los sentidos), no uno que no se dijo.
  PendingSignInfo inContext(String? sentence) {
    if (sentence == null || contexts.isEmpty) return this;
    // Solo palabras, separadas por un espacio: «¿Qué pasó?» es « QUE PASO ».
    final dicho =
        ' ${SpanishText.stripAccents(sentence.toUpperCase()).replaceAll(RegExp(r'[^A-ZÑ0-9]+'), ' ').trim()} ';
    for (final c in contexts) {
      if (c.when.any((w) => dicho.contains(' $w '))) {
        return PendingSignInfo(
          word: word,
          description: c.description,
          lsbDescription: c.lsbDescription,
          example: example,
          isProperName: isProperName,
          isAcronym: isAcronym,
          reviewed: reviewed,
          hasLsbSign: hasLsbSign,
          source: source,
        );
      }
    }
    return this;
  }
}

/// Un sentido de una palabra que cambia según la frase.
class PendingSignContext {
  /// Palabras o frases (sin tildes, en mayúsculas, con espacios) de las que
  /// basta una en lo que se dijo: «PASE ADELANTE», «DENUNCIA».
  final List<String> when;
  final String description;
  final List<String> lsbDescription;

  const PendingSignContext({
    required this.when,
    required this.description,
    this.lsbDescription = const [],
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
            isAcronym: v['tipo'] == 'sigla',
            reviewed: v['revisada'] == true,
            contexts: [
              for (final c in (v['contextos'] as List? ?? const []))
                PendingSignContext(
                  when: [
                    for (final w
                        in (c as Map<String, dynamic>)['cuando'] as List)
                      plain('$w').replaceAll('_', ' '),
                  ],
                  description: '${c['descripcion'] ?? ''}',
                  lsbDescription: [
                    for (final g in (c['descripcionLsb'] as List? ?? const []))
                      '$g',
                  ],
                ),
            ],
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
  ///
  /// Con [sentence] (lo que se dijo), una palabra con varios sentidos da el
  /// de esa frase: «pasar» en «¿qué está pasando?» no es «pasar a mi nombre».
  PendingSignInfo infoOf(String gloss, {String? sentence}) {
    final key = PendingSign.isPending(gloss)
        ? gloss.substring(PendingSign.prefix.length)
        : gloss;
    final info =
        _byKey[key] ??
        PendingSignInfo(word: PendingSign.wordOf(PendingSign.prefix + key));
    return info.inContext(sentence);
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
  static String plain(String word) => _plain(word);

  static String _plain(String word) => SpanishText.stripAccents(
    word.toUpperCase().trim(),
  ).replaceAll(RegExp(r'[\s_]+'), '_');
}
