import 'dart:convert';

import 'package:lsb_legal_app/core/domain/entities/lsb_card.dart';

class DictionaryDocument {
  final int version;
  final String dialect;
  final List<String> categoryOrder;
  final List<LsbCard> entries;

  const DictionaryDocument({
    required this.version,
    required this.dialect,
    required this.categoryOrder,
    required this.entries,
  });

  /// Tarjetas listas para mostrarse en la interfaz.
  ///
  /// Excluye `pending` (propuestas sin aprobar) y `unknown` (un `status` del
  /// JSON que esta versión no reconoce): un estado que no se pudo interpretar
  /// no debe aprobarse automáticamente mostrándolo como si fuera oficial.
  List<LsbCard> get visibleEntries => entries
      .where((e) =>
          e.status != DictionaryStatus.pending &&
          e.status != DictionaryStatus.unknown)
      .toList(growable: false);

  factory DictionaryDocument.fromJson(Map<String, dynamic> json) {
    return DictionaryDocument(
      version: json['version'] as int? ?? 0,
      dialect: json['dialect'] as String? ?? 'cochabamba',
      categoryOrder:
          List<String>.from(json['categoryOrder'] as List? ?? const []),
      entries: [
        for (final e in (json['entries'] as List? ?? const []))
          LsbCard.fromJson(Map<String, dynamic>.from(e as Map)),
      ],
    );
  }

  factory DictionaryDocument.fromJsonString(String source) =>
      DictionaryDocument.fromJson(
          Map<String, dynamic>.from(jsonDecode(source) as Map));

  Map<String, dynamic> toJson() => {
        'version': version,
        'dialect': dialect,
        'categoryOrder': categoryOrder,
        'entries': [for (final e in entries) e.toJson()],
      };

  String toJsonString({bool pretty = false}) => pretty
      ? const JsonEncoder.withIndent('  ').convert(toJson())
      : jsonEncode(toJson());
}
