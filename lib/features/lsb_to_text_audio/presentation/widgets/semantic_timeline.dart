import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme.dart';
import '../providers/context_provider.dart';
import '../providers/semantic_zones_provider.dart';

/// Línea de tiempo semántica — muestra el progreso de zonas como una
/// secuencia vertical compacta, similar a los timelines de FigJam/Whimsical.
///
/// Cada zona es un punto en la línea; las visitadas se muestran sólidas,
/// la activa con el indicador naranja, las pendientes dimmed.
class SemanticTimeline extends ConsumerWidget {
  const SemanticTimeline({super.key});

  static const _orange = AppTheme.brandPrimary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctx = ref.watch(contextProvider);
    final zonesState = ref.watch(semanticZonesProvider);

    if (ctx == null || ctx.zones.isEmpty) return const SizedBox.shrink();

    final zones = zonesState.snapshot.orderedZones;
    if (zones.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Línea vertical
          Column(
            children: [
              for (int i = 0; i < zones.length; i++) ...[
                _TimelinePoint(
                  zone: zones[i],
                  isActive: zones[i].zone.id == zonesState.activeZoneId,
                  isVisited: zonesState.visitedZoneIds.contains(zones[i].zone.id),
                ),
                if (i < zones.length - 1)
                  Container(
                    width: 1,
                    height: 16,
                    color: AppTheme.lightBorder,
                  ),
              ],
            ],
          ),
          const SizedBox(width: 12),
          // Labels
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < zones.length; i++) ...[
                SizedBox(
                  height: 20,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      zones[i].zone.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: zones[i].zone.id == zonesState.activeZoneId
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: zones[i].zone.id == zonesState.activeZoneId
                            ? _orange
                            : zonesState.visitedZoneIds
                                    .contains(zones[i].zone.id)
                                ? AppTheme.lightTextSub
                                : AppTheme.lightTextSub.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
                if (i < zones.length - 1) const SizedBox(height: 16),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _TimelinePoint extends StatelessWidget {
  final dynamic zone;
  final bool isActive;
  final bool isVisited;

  const _TimelinePoint({
    required this.zone,
    required this.isActive,
    required this.isVisited,
  });

  static const _orange = AppTheme.brandPrimary;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 20,
      alignment: Alignment.center,
      child: Container(
        width: isActive ? 8 : 6,
        height: isActive ? 8 : 6,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive
              ? _orange
              : isVisited
                  ? AppTheme.lightTextSub
                  : AppTheme.lightBorder,
        ),
      ),
    );
  }
}
