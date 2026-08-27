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

  List<LsbCard> get visibleEntries => entries
      .where((e) => e.status != DictionaryStatus.pending)
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
