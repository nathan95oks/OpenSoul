import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lsb_legal_app/core/domain/services/context_catalog.dart';

/// Ninguna pregunta guiada puede quedarse sin opciones.
///
/// Es la regresión que faltaba. Cuando el corpus judicial sustituyó el
/// vocabulario, las subcategorías del diccionario pasaron a ser gramaticales
/// (`personaDesc`, `rasgo`, `emocion`) pero el catálogo de contextos siguió
/// filtrando por las del esquema anterior —`Género`, `Edad`, `Físico`,
/// `Vestimenta`, `Color`, `Negativa`…—. Diecisiete de las veintitrés
/// subcategorías en uso dejaron de existir y **siete zonas se quedaron
/// mudas**: mostraban la pregunta y ninguna tarjeta.
///
/// No falló nada. Ni una excepción, ni un log. Por eso estuvo así hasta que
/// alguien lo miró a mano. Estas pruebas lo convierten en un fallo de CI.
void main() {
  final entradas = (jsonDecode(
    File('assets/dictionary/official_dictionary.json').readAsStringSync(),
  ) as Map<String, dynamic>)['entries'] as List;

  final glosas = {
    for (final e in entradas.cast<Map<String, dynamic>>()) e['gloss'] as String,
  };
  final porCategoria = <String, Set<String>>{};
  final porSubcategoria = <String, Set<String>>{};
  for (final e in entradas.cast<Map<String, dynamic>>()) {
    porCategoria
        .putIfAbsent(e['categoryId'] as String, () => <String>{})
        .add(e['gloss'] as String);
    porSubcategoria
        .putIfAbsent((e['subcategoryId'] ?? '') as String, () => <String>{})
        .add(e['gloss'] as String);
  }

  test('toda zona de todo contexto puede ofrecer al menos una glosa', () {
    final mudas = <String>[];

    for (final ctx in allSelectableContexts) {
      for (final zona in ctx.zones) {
        // Lista blanca: basta con que sus glosas existan de verdad.
        if (zona.glossAllowlist.isNotEmpty) {
          final reales = zona.glossAllowlist.where(glosas.contains);
          if (reales.isEmpty) mudas.add('${ctx.id}/${zona.id} (lista blanca)');
          continue;
        }

        // Filtro por categoría: alguna glosa debe sobrevivir al cruce con las
        // subcategorías declaradas.
        final deCategoria = <String>{
          for (final c in zona.cardCategories) ...?porCategoria[c],
        };
        final candidatas = zona.cardSubcategories.isEmpty
            ? deCategoria
            : deCategoria.where((g) {
                for (final s in zona.cardSubcategories) {
                  if (porSubcategoria[s]?.contains(g) ?? false) return true;
                }
                return false;
              }).toSet();
        if (candidatas.isEmpty) mudas.add('${ctx.id}/${zona.id}');
      }
    }

    expect(mudas, isEmpty,
        reason: 'Estas preguntas se mostrarían sin ninguna opción:\n'
            '  ${mudas.join('\n  ')}');
  });

  test('ninguna zona filtra por una subcategoría inexistente', () {
    final reales = porSubcategoria.keys.toSet();
    final fantasma = <String>{};

    for (final ctx in allSelectableContexts) {
      for (final zona in ctx.zones) {
        for (final s in zona.cardSubcategories) {
          if (!reales.contains(s)) fantasma.add('${ctx.id}/${zona.id} → $s');
        }
      }
    }

    expect(fantasma, isEmpty,
        reason: 'Subcategorías que el diccionario ya no tiene; su zona filtra '
            'a cero:\n  ${fantasma.join('\n  ')}');
  });

  test('toda glosa de una lista blanca existe en el diccionario', () {
    final inventadas = <String>{};

    for (final ctx in allSelectableContexts) {
      for (final zona in ctx.zones) {
        for (final g in zona.glossAllowlist) {
          if (!glosas.contains(g)) inventadas.add('${ctx.id}/${zona.id} → $g');
        }
      }
    }

    expect(inventadas, isEmpty,
        reason: 'Una lista blanca solo puede nombrar glosas reales. Estas no '
            'existen:\n  ${inventadas.join('\n  ')}');
  });

  test('las zonas que encadenan apuntan a una zona que existe', () {
    final rotas = <String>[];

    for (final ctx in allSelectableContexts) {
      final ids = {for (final z in ctx.zones) z.id};
      for (final zona in ctx.zones) {
        if (zona.chainTriggers.isEmpty) continue;
        if (zona.chainZoneId == null || !ids.contains(zona.chainZoneId)) {
          rotas.add('${ctx.id}/${zona.id} → ${zona.chainZoneId}');
          continue;
        }
        // Un disparador que no está entre las opciones de su propia zona no
        // se puede elegir, así que la cadena nunca arrancaría.
        for (final t in zona.chainTriggers) {
          if (!zona.glossAllowlist.contains(t)) {
            rotas.add('${ctx.id}/${zona.id}: $t dispara la cadena pero no se '
                'ofrece en la zona');
          }
        }
      }
    }

    expect(rotas, isEmpty, reason: rotas.join('\n'));
  });
}
