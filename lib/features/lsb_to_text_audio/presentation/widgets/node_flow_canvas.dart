import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/context_provider.dart';
import '../providers/semantic_zones_provider.dart';
import 'card_grid.dart' show expandedAnswersProvider;
import 'suggested_gloss_panel.dart';

/// Canvas del árbol conceptual — flujo visual vertical de preguntas y respuestas.
///
/// Estructura por contexto activo:
///   [CONTEXTO ROOT] (naranja, grande)
///        ↓
///   "Pregunta 1"  →  RESPUESTA1  (naranja, clickable para editar)
///        ↓
///   "Pregunta 2"  →  RESPUESTA2
///        ↓
///   "Pregunta actual" (dimmed)  →  [opciones sin seleccionar]
class NodeFlowCanvas extends ConsumerWidget {
  const NodeFlowCanvas({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctx = ref.watch(contextProvider);
    final zonesState = ref.watch(semanticZonesProvider);

    if (ctx == null) return const SizedBox.shrink();

    final orderedVisited = zonesState.visitedZoneOrder
        .where((id) => id != zonesState.activeZoneId)
        .toList();
    final activeZone = zonesState.activeZone;

    // Progreso: zonas ya recorridas sobre el total de zonas del contexto.
    final totalZones = ctx.zones.length;
    final reachedZones = zonesState.visitedZoneIds.length.clamp(1, totalZones);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Contexto como chip discreto (breadcrumb) — ya no es el foco.
          _ContextChip(emoji: ctx.emoji, label: ctx.name),
          const SizedBox(height: 14),
          // Barra de progreso naranja: posición dentro del cuestionario.
          _ProgressBar(reached: reachedZones, total: totalZones),

          // Pares pregunta → respuesta de zonas ya visitadas (compactos).
          for (final zoneId in orderedVisited) ...[
            _DownArrow(dimmed: false),
            _QuestionAnswerRow(
              zoneId: zoneId,
              zonesState: zonesState,
              onEditTap: () {
                ref.read(expandedAnswersProvider.notifier).collapse();
                ref.read(semanticZonesProvider.notifier).activateZone(zoneId);
              },
            ),
          ],

          // Zona activa: pregunta PROTAGONISTA + opciones + controles.
          if (activeZone != null) ...[
            _DownArrow(dimmed: orderedVisited.isEmpty),
            const SizedBox(height: 6),
            _ActiveQuestion(
              question: activeZone.question.isNotEmpty
                  ? activeZone.question
                  : activeZone.hint,
            ),
            const SizedBox(height: 16),
            // Opciones: SuggestedGlossPanel
            const _OptionsPanel(),
            const SizedBox(height: 8),
            _NavControls(
              canGoBack: zonesState.canGoBack,
              hasNext: zonesState.hasNextQuestion,
              onBack: () {
                ref.read(expandedAnswersProvider.notifier).collapse();
                ref.read(semanticZonesProvider.notifier).goToPreviousZone();
              },
              onContinue: () {
                ref.read(expandedAnswersProvider.notifier).collapse();
                ref.read(semanticZonesProvider.notifier).goToNextZone();
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// Chip discreto del contexto activo — sustituye al antiguo nodo raíz
/// grande. Mantiene visible "dónde estoy" sin competir con la pregunta.
class _ContextChip extends StatelessWidget {
  final String emoji;
  final String label;
  const _ContextChip({required this.emoji, required this.label});

  static const _orange = Color(0xFFFF6B00);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: _orange.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _orange.withValues(alpha: 0.45), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _orange,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Barra de progreso horizontal naranja + etiqueta "Pregunta X de Y".
class _ProgressBar extends StatelessWidget {
  final int reached;
  final int total;
  const _ProgressBar({required this.reached, required this.total});

  static const _orange = Color(0xFFFF6B00);

  @override
  Widget build(BuildContext context) {
    final value = total == 0 ? 0.0 : (reached / total).clamp(0.0, 1.0);
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 5,
            backgroundColor: Colors.black.withValues(alpha: 0.08),
            valueColor: const AlwaysStoppedAnimation<Color>(_orange),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Pregunta $reached de $total',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.black.withValues(alpha: 0.45),
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

class _QuestionAnswerRow extends StatelessWidget {
  final String zoneId;
  final SemanticZonesState zonesState;
  final VoidCallback onEditTap;

  const _QuestionAnswerRow({
    required this.zoneId,
    required this.zonesState,
    required this.onEditTap,
  });

  static const _orange = Color(0xFFFF6B00);

  @override
  Widget build(BuildContext context) {
    final zone = zonesState.snapshot.orderedZones
        .cast<dynamic>()
        .firstWhere((p) => (p.zone.id as String) == zoneId, orElse: () => null);
    if (zone == null) return const SizedBox.shrink();

    final question = (zone.zone.question as String).isNotEmpty
        ? zone.zone.question as String
        : zone.zone.hint as String;
    final answers = zonesState.zoneAnswers[zoneId] ?? [];

    return Column(
      children: [
        // Pregunta
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.black.withValues(alpha: 0.12),
              width: 1.5,
            ),
          ),
          child: Text(
            question,
            style: const TextStyle(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: Color(0xFF555555),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 8),
        _RightArrow(dimmed: false),
        const SizedBox(height: 8),
        // Respuestas (clickable para editar)
        if (answers.isEmpty)
          _SkippedTag()
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: answers.map((gloss) => GestureDetector(
              onTap: onEditTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: _orange,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _orange, width: 2),
                ),
                child: Text(
                  gloss.replaceAll('_', ' ').toUpperCase(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            )).toList(),
          ),
      ],
    );
  }
}

class _SkippedTag extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black.withValues(alpha: 0.2)),
      ),
      child: Text(
        'Saltado',
        style: TextStyle(
          fontSize: 12,
          color: Colors.black.withValues(alpha: 0.4),
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}

/// Pregunta activa — elemento PRINCIPAL de la pantalla.
///
/// A diferencia de las preguntas ya respondidas (pequeñas, en gris), la
/// pregunta actual se muestra grande y en negro para que el foco visual
/// esté en lo que el usuario debe responder ahora, no en el contexto.
class _ActiveQuestion extends StatelessWidget {
  final String question;
  const _ActiveQuestion({required this.question});

  @override
  Widget build(BuildContext context) {
    return Text(
      question,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        color: Colors.black,
        height: 1.25,
        letterSpacing: -0.3,
      ),
    );
  }
}

/// Controles de navegación manual: "Volver" (atrás) y "Continuar".
///
/// Reemplazan al auto-avance: el usuario decide cuándo cambiar de pregunta,
/// pudiendo seleccionar varias glosas o corregir antes de avanzar.
class _NavControls extends StatelessWidget {
  final bool canGoBack;
  final bool hasNext;
  final VoidCallback onBack;
  final VoidCallback onContinue;

  const _NavControls({
    required this.canGoBack,
    required this.hasNext,
    required this.onBack,
    required this.onContinue,
  });

  static const _orange = Color(0xFFFF6B00);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          // Volver atrás
          Expanded(
            child: _NavButton(
              label: 'Volver',
              icon: Icons.arrow_back,
              filled: false,
              enabled: canGoBack,
              onTap: canGoBack ? onBack : null,
            ),
          ),
          const SizedBox(width: 12),
          // Continuar / aviso de relato completo
          Expanded(
            flex: 2,
            child: hasNext
                ? _NavButton(
                    label: 'Continuar',
                    icon: Icons.arrow_forward,
                    filled: true,
                    enabled: true,
                    onTap: onContinue,
                  )
                : Container(
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _orange.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                      border:
                          Border.all(color: _orange.withValues(alpha: 0.45)),
                    ),
                    child: const Text(
                      'Relato completo — pulsa TRADUCIR',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: _orange,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool filled;
  final bool enabled;
  final VoidCallback? onTap;

  const _NavButton({
    required this.label,
    required this.icon,
    required this.filled,
    required this.enabled,
    required this.onTap,
  });

  static const _orange = Color(0xFFFF6B00);

  @override
  Widget build(BuildContext context) {
    final bg = filled
        ? _orange
        : Colors.white;
    final fg = filled
        ? Colors.white
        : (enabled ? Colors.black : Colors.black.withValues(alpha: 0.3));
    final borderColor = filled
        ? _orange
        : (enabled ? Colors.black : Colors.black.withValues(alpha: 0.2));

    return SizedBox(
      height: 48,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor, width: filled ? 2 : 1.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 17, color: fg),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: fg,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OptionsPanel extends ConsumerWidget {
  const _OptionsPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const SuggestedGlossPanel();
  }
}

class _DownArrow extends StatelessWidget {
  final bool dimmed;
  const _DownArrow({required this.dimmed});

  @override
  Widget build(BuildContext context) {
    final color = Colors.black.withValues(alpha: dimmed ? 0.2 : 0.5);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          Container(width: 1.5, height: 20, color: color),
          ClipPath(
            clipper: _DownTriangle(),
            child: Container(width: 10, height: 7, color: color),
          ),
        ],
      ),
    );
  }
}

class _RightArrow extends StatelessWidget {
  final bool dimmed;
  const _RightArrow({required this.dimmed});

  @override
  Widget build(BuildContext context) {
    final color = Colors.black.withValues(alpha: dimmed ? 0.2 : 0.4);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(width: 24, height: 1.5, color: color),
        ClipPath(
          clipper: _RightTriangle(),
          child: Container(width: 7, height: 10, color: color),
        ),
      ],
    );
  }
}

class _DownTriangle extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
  }

  @override
  bool shouldReclip(_) => false;
}

class _RightTriangle extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(0, 0)
      ..lineTo(0, size.height)
      ..lineTo(size.width, size.height / 2)
      ..close();
  }

  @override
  bool shouldReclip(_) => false;
}
