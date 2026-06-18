import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../domain/entities/semantic_zone.dart';
import '../../domain/services/semantic_navigation_engine.dart';
import '../providers/context_provider.dart';
import '../providers/semantic_zones_provider.dart';

/// Barra de zonas semánticas — motor de preguntas guiadas + navegación libre.
///
/// La zona activa muestra una **pregunta guiada en primera persona**
/// ("¿Qué pasó?", "¿Quién te robó?", "¿Dónde ocurrió?") como prompt
/// principal. El usuario sordo "responde" tocando tarjetas (entrada
/// visual-táctil definida en el perfil de proyecto). Cada chip representa
/// otra pregunta a la que puede saltar libremente — sin orden obligatorio.
///
/// El motor [SemanticNavigationEngine] sugiere qué pregunta hacer a
/// continuación según las glosas ya seleccionadas y las etiquetas
/// emocionales detectadas (urgencia, peligro, dolor). Esto convierte la
/// navegación en un cuestionario asistido sin perder el carácter
/// asociativo y no secuencial propio de la LSB.
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
        color: AppTheme.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _urgencyBorder(urgency),
          width: urgency == UrgencyLevel.critical ? 1.5 : 1.0,
        ),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabecera: contexto + badge de urgencia
          Row(
            children: [
              Text(ctx.emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  ctx.name.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.lightTextSub,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              if (urgency.index >= UrgencyLevel.high.index)
                _UrgencyBadge(level: urgency),
            ],
          ),
          const SizedBox(height: 10),
          // Prompt — pregunta guiada de la zona activa
          if (activeZone != null) _ActiveQuestion(zone: activeZone),
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
          // Chips de zonas — saltar a otra pregunta
          const _OtherQuestionsLabel(),
          const SizedBox(height: 6),
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
        return AppTheme.errorLight.withValues(alpha: 0.7);
      case UrgencyLevel.high:
        return AppTheme.warningLight.withValues(alpha: 0.6);
      case UrgencyLevel.medium:
        return AppTheme.brandPrimary.withValues(alpha: 0.4);
      default:
        return AppTheme.lightBorder;
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
        ? AppTheme.brandPrimary
        : isUrgent
            ? AppTheme.errorLight
            : isSuggested
                ? AppTheme.brandPrimary
                : AppTheme.lightBorder;

    final Color textColor = isActive
        ? Colors.white
        : isUrgent
            ? AppTheme.errorLight
            : isSuggested
                ? AppTheme.brandPrimary
                : AppTheme.lightTextSub;

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
    final color = isCritical ? AppTheme.errorLight : AppTheme.warningLight;
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

/// Renderiza la pregunta guiada activa como prompt principal.
///
/// Es la materialización de la sugerencia pedagógica del docente:
/// transformar la grilla de tarjetas en un cuestionario asistido, donde
/// cada pregunta enfoca cognitivamente al usuario sordo en una sola
/// dimensión del relato. Las tarjetas siguen siendo la respuesta —
/// alineado con el módulo de entrada visual-táctil del perfil de proyecto.
class _ActiveQuestion extends StatelessWidget {
  final SemanticZone zone;
  const _ActiveQuestion({required this.zone});

  @override
  Widget build(BuildContext context) {
    final question = zone.question.isNotEmpty ? zone.question : zone.hint;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: AppTheme.brandPrimary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.brandPrimary.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(zone.emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PREGUNTA  ·  ${zone.label.toUpperCase()}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppTheme.brandPrimary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  question,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.lightText,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Toca las tarjetas para responder',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.lightTextSub,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OtherQuestionsLabel extends StatelessWidget {
  const _OtherQuestionsLabel();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'OTRAS PREGUNTAS',
      style: TextStyle(
        fontSize: 10,
        color: AppTheme.lightTextSub,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
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
        color: AppTheme.lightSubtle,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.errorLight.withValues(alpha: 0.3)),
      ),
      child: Text(
        '#$label',
        style: const TextStyle(
          fontSize: 10,
          color: AppTheme.errorLight,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
