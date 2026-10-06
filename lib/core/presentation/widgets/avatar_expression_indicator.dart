import 'package:flutter/material.dart';

import 'package:lsb_legal_app/core/domain/entities/avatar_facial_expression.dart';

/// Dibujo monocromático que acompaña una glosa emocional del avatar.
///
/// Se usa un [CustomPainter] en lugar de un emoji para conservar el mismo
/// trazo blanco en Android, iOS y web.
class AvatarExpressionIndicator extends StatelessWidget {
  final AvatarFacialExpression expression;

  const AvatarExpressionIndicator({super.key, required this.expression});

  @override
  Widget build(BuildContext context) {
    final label = expression.accessibleLabel;
    return Semantics(
      label: 'Expresión: $label',
      image: true,
      child: ExcludeSemantics(
        child: Container(
          key: ValueKey('avatar_expression_$label'),
          width: 58,
          height: 58,
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: const Color(0xFF111124).withValues(alpha: 0.72),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.9),
              width: 1.4,
            ),
          ),
          child: CustomPaint(painter: _ExpressionPainter(expression)),
        ),
      ),
    );
  }
}

class _ExpressionPainter extends CustomPainter {
  final AvatarFacialExpression expression;

  const _ExpressionPainter(this.expression);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final center = size.center(Offset.zero);
    final radius = size.shortestSide * 0.44;
    canvas.drawCircle(center, radius, stroke);

    switch (expression) {
      case AvatarFacialExpression.fear:
        _paintFear(canvas, size, stroke);
    }
  }

  void _paintFear(Canvas canvas, Size size, Paint stroke) {
    final w = size.width;
    final h = size.height;

    // Cejas elevadas hacia el centro.
    canvas.drawLine(
      Offset(w * 0.23, h * 0.31),
      Offset(w * 0.43, h * 0.25),
      stroke,
    );
    canvas.drawLine(
      Offset(w * 0.57, h * 0.25),
      Offset(w * 0.77, h * 0.31),
      stroke,
    );

    // Ojos abiertos.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.34, h * 0.45),
        width: w * 0.105,
        height: h * 0.17,
      ),
      stroke,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.66, h * 0.45),
        width: w * 0.105,
        height: h * 0.17,
      ),
      stroke,
    );

    // Boca pequeña y abierta de alarma.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.7),
        width: w * 0.22,
        height: h * 0.2,
      ),
      stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _ExpressionPainter oldDelegate) =>
      oldDelegate.expression != expression;
}
