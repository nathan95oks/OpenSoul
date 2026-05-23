import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/semantic_zone.dart';
import '../../domain/services/semantic_navigation_engine.dart';
import '../providers/context_provider.dart';
import '../providers/semantic_zones_provider.dart';

/// Barra de zonas semánticas — exploración libre por chips.
///
/// Cada chip representa una [SemanticZone] del contexto activo. El usuario
/// puede tocar cualquier zona en cualquier momento; el motor resalta las
/// sugeridas y eleva visualmente las que tienen urgencia activa.
///
/// Diseño deliberadamente NO secuencial: no hay botones "Anterior /
/// Siguiente" ni indicadores de paso. La narrativa se construye de manera
/// asociativa, compatible con la naturaleza viso-gestual de la LSB.
class SemanticZonesBar extends ConsumerWidget {
  const SemanticZonesBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctx = ref.watch(contextProvider);
    final zonesState = ref.watch(semanticZonesProvider);

    if (ctx == null || zonesState.snapshot.orderedZones.isEmpty) {
      return const SizedBox.shrink();
    }

    final activeZone = zonesState.activeZone;
    final urgency = zonesState.snapshot.dominantUrgency;
    final tags = zonesState.snapshot.activeTags;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _urgencyBorder(urgency),
          width: urgency == UrgencyLevel.critical ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header con contexto y badge de urgencia
          Row(
            children: [
              Text(ctx.emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ctx.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    if (activeZone != null)
                      Text(
                        '${activeZone.emoji}  ${activeZone.label} · ${activeZone.hint}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF8B949E),
                        ),
                      ),
                  ],
                ),
              ),
              if (urgency.index >= UrgencyLevel.high.index)
                _UrgencyBadge(level: urgency),
            ],
          ),
          // Etiquetas emocionales activas
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: tags.map((t) => _TagPill(label: t)).toList(),
            ),
          ],
          const SizedBox(height: 12),
          // Chips de zonas — navegación libre
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: zonesState.snapshot.orderedZones.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final p = zonesState.snapshot.orderedZones[i];
                final isActive = p.zone.id == zonesState.activeZoneId;
                final isVisited =
                    zonesState.visitedZoneIds.contains(p.zone.id);
                return _ZoneChip(
                  priority: p,
                  isActive: isActive,
                  isVisited: isVisited,
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

  Color _urgencyBorder(UrgencyLevel level) {
    switch (level) {
      case UrgencyLevel.critical:
        return Colors.redAccent.withValues(alpha: 0.7);
      case UrgencyLevel.high:
        return Colors.orangeAccent.withValues(alpha: 0.6);
      case UrgencyLevel.medium:
        return const Color(0xFF00ADB5).withValues(alpha: 0.4);
      default:
        return const Color(0xFF30363D);
    }
  }
}

class _ZoneChip extends StatelessWidget {
  final ZonePriority priority;
  final bool isActive;
  final bool isVisited;
  final VoidCallback onTap;

  const _ZoneChip({
    required this.priority,
    required this.isActive,
    required this.isVisited,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final zone = priority.zone;
    final isUrgent = priority.urgency.index >= UrgencyLevel.high.index;
    final isSuggested = priority.isSuggested;

    final Color baseColor = isActive
        ? const Color(0xFFFFD700)
        : isUrgent
            ? Colors.redAccent
            : isSuggested
                ? const Color(0xFF00ADB5)
                : const Color(0xFF30363D);

    final Color textColor = isActive
        ? Colors.black
        : isUrgent
            ? Colors.redAccent
            : isSuggested
                ? const Color(0xFF00ADB5)
                : Colors.white70;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? baseColor : baseColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: baseColor.withValues(alpha: isActive ? 1.0 : 0.6),
            width: isActive ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(zone.emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              zone.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: textColor,
                letterSpacing: 0.2,
              ),
            ),
            if (isVisited && !isActive) ...[
              const SizedBox(width: 4),
              Icon(Icons.check_circle,
                  size: 12, color: textColor.withValues(alpha: 0.7)),
            ],
            if (zone.optional && !isActive) ...[
              const SizedBox(width: 4),
              Text(
                '·',
                style: TextStyle(color: textColor.withValues(alpha: 0.6)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _UrgencyBadge extends StatelessWidget {
  final UrgencyLevel level;
  const _UrgencyBadge({required this.level});

  @override
  Widget build(BuildContext context) {
    final isCritical = level == UrgencyLevel.critical;
    final color = isCritical ? Colors.redAccent : Colors.orangeAccent;
    final label = isCritical ? 'URGENTE' : 'ATENCIÓN';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.priority_high, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _TagPill extends StatelessWidget {
  final String label;
  const _TagPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF21262D),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
      ),
      child: Text(
        '#$label',
        style: const TextStyle(
          fontSize: 10,
          color: Colors.redAccent,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
