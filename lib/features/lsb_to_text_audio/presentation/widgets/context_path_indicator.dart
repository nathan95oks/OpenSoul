import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lsb_legal_app/app/theme.dart';
import '../../domain/entities/semantic_zone.dart';
import '../providers/context_provider.dart';
import '../providers/semantic_zones_provider.dart';

/// Indicador de ruta semántica — reemplaza SemanticZonesBar.
///
/// Diseño de breadcrumb minimalista (inspirado en Linear/Notion):
///   ● ME ROBARON  ›  ¿Qué pasó?           [URGENTE]
///
/// Debajo: chips compactos de zonas navegables (sin colores de urgencia,
/// solo estado activa/visitada distinguido por peso tipográfico y naranja).
class ContextPathIndicator extends ConsumerWidget {
  const ContextPathIndicator({super.key});

  static const _orange = AppTheme.brandPrimary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctx = ref.watch(contextProvider);
    final zonesState = ref.watch(semanticZonesProvider);

    if (ctx == null || zonesState.snapshot.orderedZones.isEmpty) {
      return const SizedBox.shrink();
    }

    final activeZone = zonesState.activeZone;
    final isUrgent = zonesState.snapshot.dominantUrgency.index >=
        UrgencyLevel.high.index;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Breadcrumb: Contexto › Zona activa › Pregunta
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: _orange,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                ctx.name.toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.lightTextSub,
                  letterSpacing: 1.0,
                ),
              ),
              if (activeZone != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    '›',
                    style: TextStyle(
                      color: AppTheme.lightTextSub.withValues(alpha: 0.6),
                      fontSize: 13,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    activeZone.question.isNotEmpty
                        ? activeZone.question
                        : activeZone.hint,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.lightText,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              if (isUrgent) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: _orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _orange.withValues(alpha: 0.4)),
                  ),
                  child: const Text(
                    'URGENTE',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: _orange,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 10),

          // Chips de zonas navegables
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: zonesState.snapshot.orderedZones.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final p = zonesState.snapshot.orderedZones[i];
                final isActive = p.zone.id == zonesState.activeZoneId;
                final isVisited =
                    zonesState.visitedZoneIds.contains(p.zone.id);
                return _ZoneChip(
                  zone: p.zone,
                  isActive: isActive,
                  isVisited: isVisited,
                  isSuggested: p.isSuggested,
                  onTap: () => ref
                      .read(semanticZonesProvider.notifier)
                      .activateZone(p.zone.id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ZoneChip extends StatelessWidget {
  final SemanticZone zone;
  final bool isActive;
  final bool isVisited;
  final bool isSuggested;
  final VoidCallback onTap;

  const _ZoneChip({
    required this.zone,
    required this.isActive,
    required this.isVisited,
    required this.isSuggested,
    required this.onTap,
  });

  static const _orange = AppTheme.brandPrimary;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? _orange : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? _orange
                : isSuggested
                    ? _orange.withValues(alpha: 0.35)
                    : AppTheme.lightBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(zone.emoji, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 5),
            Text(
              zone.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                color: isActive
                    ? Colors.white
                    : AppTheme.lightText.withValues(alpha: isVisited ? 0.55 : 0.85),
              ),
            ),
            if (isVisited && !isActive) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.check,
                size: 10,
                color: AppTheme.lightTextSub,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
