import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:lsb_legal_app/app/app_theme.dart';

/// Fondo del chat con dibujitos de trazo fino, como los de WhatsApp o
/// Telegram: bocadillos, manos, corazones, estrellas… repetidos en mosaico.
///
/// Va debajo de los mensajes y no se toca ni se lee: es decoración. El color
/// es el violeta de LSB muy transparente, para que el fondo siga viéndose
/// blanco y los mensajes no pierdan contraste.
class ChatDoodleBackground extends StatelessWidget {
  final Widget child;

  const ChatDoodleBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const Positioned.fill(
          child: IgnorePointer(
            child: ExcludeSemantics(
              // Se pinta una vez: desplazar el chat no lo vuelve a dibujar.
              child: RepaintBoundary(
                child: CustomPaint(
                  key: Key('fondo_chat_dibujos'),
                  painter: _DoodlePainter(),
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

typedef _Motivo = void Function(Canvas canvas, Paint paint);

/// Un dibujito dentro del mosaico: qué es, dónde va, girado y a qué escala.
class _Colocado {
  final _Motivo motivo;
  final Offset centro;
  final double giro;
  final double escala;

  const _Colocado(this.motivo, this.centro, this.giro, [this.escala = 1]);
}

class _DoodlePainter extends CustomPainter {
  const _DoodlePainter();

  /// Las posiciones de [_mosaico] están en una baldosa de 260 px; se juntan
  /// a [_lado] para que los dibujos queden apretados, como en WhatsApp.
  static const double _lado = 215;
  static const double _junta = _lado / 260;

  static final List<_Colocado> _mosaico = [
    const _Colocado(_bocadillo, Offset(34, 30), -0.18),
    const _Colocado(_corazon, Offset(104, 22), 0.25, 0.8),
    const _Colocado(_destello, Offset(160, 44), 0, 0.9),
    const _Colocado(_mano, Offset(222, 34), 0.2),
    const _Colocado(_flor, Offset(70, 82), 0.1),
    const _Colocado(_planeta, Offset(138, 98), -0.3),
    const _Colocado(_estrella, Offset(206, 92), 0.35, 0.8),
    const _Colocado(_microfono, Offset(24, 132), -0.25),
    const _Colocado(_sobre, Offset(92, 150), 0.18),
    const _Colocado(_nota, Offset(176, 150), -0.15),
    const _Colocado(_puntos, Offset(234, 140), 0, 0.9),
    const _Colocado(_luna, Offset(44, 196), 0.4, 0.9),
    const _Colocado(_sonrisa, Offset(120, 208), -0.1),
    const _Colocado(_bocadillo, Offset(196, 214), 0.22, 0.85),
    const _Colocado(_destello, Offset(248, 246), 0, 0.6),
    const _Colocado(_corazon, Offset(4, 244), -0.3, 0.7),
    const _Colocado(_estrella, Offset(70, 244), -0.2, 0.6),
    const _Colocado(_destello, Offset(150, 248), 0, 0.5),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.lsbViolet.withValues(alpha: 0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    canvas.clipRect(Offset.zero & size);
    // Cada fila se corre media baldosa: la repetición se nota menos.
    for (var fila = 0; fila * _lado < size.height + _lado; fila++) {
      final desfase = fila.isOdd ? -_lado / 2 : 0.0;
      for (var x = desfase - _lado; x < size.width + _lado; x += _lado) {
        final origen = Offset(x, fila * _lado - 20);
        for (final c in _mosaico) {
          canvas
            ..save()
            ..translate(
              origen.dx + c.centro.dx * _junta,
              origen.dy + c.centro.dy * _junta,
            )
            ..rotate(c.giro)
            ..scale(c.escala);
          c.motivo(canvas, paint);
          canvas.restore();
        }
      }
    }
  }

  @override
  bool shouldRepaint(_DoodlePainter oldDelegate) => false;

  // Los motivos se dibujan centrados en el origen, en unos 26 px.

  static void _bocadillo(Canvas canvas, Paint paint) {
    final cuerpo = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-14, -10, 28, 18),
      const Radius.circular(7),
    );
    final path = Path()
      ..addRRect(cuerpo)
      ..moveTo(-6, 8)
      ..lineTo(-10, 14)
      ..lineTo(-1, 8);
    canvas.drawPath(path, paint);
    final punto = Paint()
      ..color = paint.color
      ..style = PaintingStyle.fill;
    for (final dx in [-6.0, 0.0, 6.0]) {
      canvas.drawCircle(Offset(dx, -1), 1.4, punto);
    }
  }

  static void _corazon(Canvas canvas, Paint paint) {
    final path = Path()
      ..moveTo(0, 9)
      ..cubicTo(-14, -1, -9, -13, 0, -5)
      ..cubicTo(9, -13, 14, -1, 0, 9);
    canvas.drawPath(path, paint);
  }

  static void _destello(Canvas canvas, Paint paint) {
    final path = Path()
      ..moveTo(0, -11)
      ..quadraticBezierTo(1.5, -1.5, 11, 0)
      ..quadraticBezierTo(1.5, 1.5, 0, 11)
      ..quadraticBezierTo(-1.5, 1.5, -11, 0)
      ..quadraticBezierTo(-1.5, -1.5, 0, -11);
    canvas.drawPath(path, paint);
  }

  static void _estrella(Canvas canvas, Paint paint) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final r = i.isEven ? 11.0 : 4.8;
      final a = -math.pi / 2 + i * math.pi / 5;
      final p = Offset(r * math.cos(a), r * math.sin(a));
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  /// Una mano abierta: la seña está en el centro de la app.
  static void _mano(Canvas canvas, Paint paint) {
    final palma = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-7, -1, 14, 13),
      const Radius.circular(5),
    );
    canvas.drawRRect(palma, paint);
    for (final (dx, alto) in [
      (-5.0, 9.0),
      (-1.7, 12.0),
      (1.7, 12.0),
      (5.0, 9.0),
    ]) {
      canvas.drawLine(Offset(dx, -1), Offset(dx, -1 - alto), paint);
    }
    // El pulgar.
    canvas.drawLine(const Offset(-7, 5), const Offset(-12, -1), paint);
  }

  static void _flor(Canvas canvas, Paint paint) {
    for (var i = 0; i < 5; i++) {
      final a = i * 2 * math.pi / 5;
      canvas.drawCircle(
        Offset(6.5 * math.cos(a), 6.5 * math.sin(a)),
        4.5,
        paint,
      );
    }
    canvas.drawCircle(Offset.zero, 2.2, paint);
  }

  static void _planeta(Canvas canvas, Paint paint) {
    canvas.drawCircle(Offset.zero, 7.5, paint);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 30, height: 9),
      paint,
    );
  }

  static void _microfono(Canvas canvas, Paint paint) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-4.5, -12, 9, 15),
        const Radius.circular(4.5),
      ),
      paint,
    );
    canvas.drawArc(
      const Rect.fromLTWH(-8, -6, 16, 14),
      0,
      math.pi,
      false,
      paint,
    );
    canvas.drawLine(const Offset(0, 8), const Offset(0, 12), paint);
    canvas.drawLine(const Offset(-4, 12), const Offset(4, 12), paint);
  }

  static void _sobre(Canvas canvas, Paint paint) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-12, -8, 24, 16),
        const Radius.circular(2.5),
      ),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(-11, -7)
        ..lineTo(0, 2)
        ..lineTo(11, -7),
      paint,
    );
  }

  static void _nota(Canvas canvas, Paint paint) {
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(-5, 8), width: 8, height: 6),
      paint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(7, 5), width: 8, height: 6),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(-1, 8)
        ..lineTo(-1, -9)
        ..lineTo(11, -12)
        ..lineTo(11, 5),
      paint,
    );
  }

  static void _puntos(Canvas canvas, Paint paint) {
    canvas.drawCircle(const Offset(-6, 0), 2.2, paint);
    canvas.drawCircle(const Offset(1, -5), 3, paint);
    canvas.drawCircle(const Offset(6, 4), 1.8, paint);
  }

  static void _luna(Canvas canvas, Paint paint) {
    final path = Path()
      ..moveTo(2, -11)
      ..arcToPoint(
        const Offset(2, 11),
        radius: const Radius.circular(11),
        clockwise: false,
      )
      ..arcToPoint(const Offset(2, -11), radius: const Radius.circular(13));
    canvas.drawPath(path, paint);
  }

  static void _sonrisa(Canvas canvas, Paint paint) {
    canvas.drawCircle(Offset.zero, 10, paint);
    final ojo = Paint()
      ..color = paint.color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(-3.5, -2.5), 1.3, ojo);
    canvas.drawCircle(const Offset(3.5, -2.5), 1.3, ojo);
    canvas.drawArc(
      const Rect.fromLTWH(-5, -3, 10, 9),
      0.3,
      math.pi - 0.6,
      false,
      paint,
    );
  }
}
