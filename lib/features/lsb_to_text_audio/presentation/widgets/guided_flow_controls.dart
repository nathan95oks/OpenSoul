import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/context_provider.dart';
import '../providers/semantic_zones_provider.dart';

/// Controles inline para el flujo guiado: saltar la pregunta actual y
/// ver el progreso de preguntas respondidas.
///
/// El botón "Saltar" marca la zona como visitada y avanza a la
/// siguiente sin obligar al usuario a responder. Si no quedan más
/// preguntas pendientes, el botón se oculta y queda solo el indicador.
class GuidedFlowControls extends ConsumerWidget {
  const GuidedFlowControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctx = ref.watch(contextProvider);
    final zonesState = ref.watch(semanticZonesProvider);

    if (ctx == null || zonesState.snapshot.orderedZones.isEmpty) {
      return const SizedBox.shrink();
    }

    final total = ctx.zones.length;
    final answered = zonesState.visitedZoneIds.length;
    final hasNextPending = zonesState.snapshot.orderedZones.any((p) =>
        p.zone.id != zonesState.activeZoneId &&
        !zonesState.visitedZoneIds.contains(p.zone.id));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          // Indicador de progreso de preguntas
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF30363D)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_outline,
                    size: 14, color: Color(0xFF3FB950)),
                const SizedBox(width: 6),
                Text(
                  'Pregunta $answered de $total',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF8B949E),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          // Botón saltar (sólo si quedan preguntas pendientes)
          if (hasNextPending)
            TextButton.icon(
              onPressed: () => ref
                  .read(semanticZonesProvider.notifier)
                  .skipCurrentQuestion(),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF8B949E),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              ),
              icon: const Icon(Icons.skip_next, size: 16),
              label: const Text(
                'Saltar pregunta',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}
