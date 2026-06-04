import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/context_provider.dart';
import '../providers/semantic_zones_provider.dart';
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

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Nodo raíz — contexto
          _RootNode(label: ctx.name.toUpperCase()),

          // Pares pregunta → respuesta de zonas ya visitadas
          for (final zoneId in orderedVisited) ...[
            _DownArrow(dimmed: false),
            _QuestionAnswerRow(
              zoneId: zoneId,
              zonesState: zonesState,
              onEditTap: () => ref
                  .read(semanticZonesProvider.notifier)
                  .activateZone(zoneId),
            ),
          ],

          // Zona activa: pregunta + opciones
          if (activeZone != null && !zonesState.isFlowComplete) ...[
            _DownArrow(dimmed: orderedVisited.isEmpty),
            _QuestionLabel(
              question: activeZone.question.isNotEmpty
                  ? activeZone.question
                  : activeZone.hint,
              dimmed: false,
            ),
            const SizedBox(height: 12),
            _RightArrow(dimmed: false),
            const SizedBox(height: 12),
            // Opciones: SuggestedGlossPanel
            const _OptionsPanel(),
          ],

          if (zonesState.isFlowComplete) ...[
            _DownArrow(dimmed: true),
            _FlowCompleteNode(),
          ],
        ],
      ),
    );
  }
}

class _RootNode extends StatelessWidget {
  final String label;
  const _RootNode({required this.label});

  static const _orange = Color(0xFFFF6B00);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      decoration: BoxDecoration(
        color: _orange,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _orange, width: 2),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
        textAlign: TextAlign.center,
      ),
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

class _QuestionLabel extends StatelessWidget {
  final String question;
  final bool dimmed;
  const _QuestionLabel({required this.question, required this.dimmed});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: dimmed ? 0.02 : 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.black.withValues(alpha: dimmed ? 0.08 : 0.14),
          width: 1.5,
        ),
      ),
      child: Text(
        question,
        style: TextStyle(
          fontSize: 13,
          fontStyle: FontStyle.italic,
          color: Colors.black.withValues(alpha: dimmed ? 0.35 : 0.65),
          fontWeight: FontWeight.w500,
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

class _FlowCompleteNode extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFF6B00), width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_outline, color: Color(0xFFFF6B00), size: 18),
          const SizedBox(width: 8),
          const Text(
            'Relato completo — Traducir',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFFFF6B00),
            ),
          ),
        ],
      ),
    );
  }
}
