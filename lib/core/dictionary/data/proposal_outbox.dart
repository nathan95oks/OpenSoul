import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../domain/dictionary_proposal.dart';

/// Cola en disco de propuestas pendientes de envío (patrón outbox).
///
/// Una propuesta redactada sin conexión no puede perderse: se persiste
/// aquí y el repositorio la reenvía en la siguiente sincronización.
/// A diferencia de la caché del diccionario, escribir aquí SÍ importa:
/// los métodos devuelven éxito/fracaso para que la UI informe con verdad.
class ProposalOutbox {
  static const String fileName = 'proposal_outbox.json';

  Future<File?> _file() async {
    try {
      final dir = await getApplicationSupportDirectory();
      return File('${dir.path}/$fileName');
    } catch (_) {
      return null;
    }
  }

  Future<List<DictionaryProposal>> readAll() async {
    try {
      final file = await _file();
      if (file == null || !await file.exists()) return const [];
      final decoded = jsonDecode(await file.readAsString()) as List;
      return [
        for (final item in decoded)
          DictionaryProposal.fromJson(Map<String, dynamic>.from(item as Map)),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Persiste la cola completa. Devuelve `false` si no pudo escribirse.
  Future<bool> writeAll(List<DictionaryProposal> proposals) async {
    try {
      final file = await _file();
      if (file == null) return false;
      await file.writeAsString(
        jsonEncode([for (final p in proposals) p.toJson()]),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Añade una propuesta al final de la cola.
  Future<bool> add(DictionaryProposal proposal) async {
    final current = await readAll();
    return writeAll([...current, proposal]);
  }
}
