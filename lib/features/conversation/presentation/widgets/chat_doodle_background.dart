import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Fondo del chat con dibujos de trazo fino, como los de WhatsApp o
/// Telegram: una ballena, un globo aerostático, una mariposa, un casete…
///
/// No es un mosaico: los dibujos se reparten sueltos por todo el fondo, sin
/// patrón que se repita, y dos iguales nunca quedan cerca. El reparto es fijo
/// (no cambia al abrir el teclado ni al volver al chat).
///
/// Va debajo de los mensajes y no se toca ni se lee: es decoración. El gris
/// es suave para que el fondo siga viéndose blanco y los mensajes no pierdan
/// contraste.
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

typedef _Dibujo = void Function(Canvas canvas, Paint trazo, Paint relleno);

/// Los dibujos grandes del fondo: dónde va cada uno y cuál es (un índice).
/// Solo para las pruebas.
@visibleForTesting
List<(Offset, int)> chatDoodleLayout() => [
  for (final c in _DoodlePainter._reparto)
    if (_DoodlePainter._grandes.contains(c.dibujo))
      (c.centro, _DoodlePainter._grandes.indexOf(c.dibujo)),
];

/// Un dibujo en su sitio del fondo, girado y a su escala.
class _Colocado {
  final _Dibujo dibujo;
  final Offset centro;
  final double giro;
  final double escala;

  const _Colocado(this.dibujo, this.centro, this.giro, this.escala);
}

class _DoodlePainter extends CustomPainter {
  const _DoodlePainter();

  /// Gris plomo, algo transparente sobre el blanco del chat.
  static const Color color = Color(0x667A8089);

  /// Superficie sobre la que se reparten los dibujos, mayor que cualquier
  /// pantalla: lo que no entra se recorta.
  static const Size _lienzo = Size(1600, 2600);

  /// Distancia mínima entre dos dibujos cualesquiera, y entre dos grandes.
  static const double _separacion = 60;
  static const double _separacionGrandes = 88;

  static const List<_Dibujo> _grandes = [
    _ballena,
    _sobre,
    _carta,
    _planeta,
    _globoAerostatico,
    _mariposa,
    _arcoiris,
    _lupa,
    _casete,
    _taza,
    _flor,
    _nube,
    _rama,
    _lapiz,
    _disco,
    _polaroid,
    _globo,
    _notas,
    _luna,
    _paraguas,
    _cactus,
    _avionDePapel,
    _mano,
    _bocadillo,
    _libro,
    _camara,
    _llave,
    _casa,
    _pez,
    _caracol,
    _gafas,
    _bombilla,
    _reloj,
    _ancla,
    _barco,
    _cometa,
    _arbol,
    _campana,
    _cohete,
    _tijeras,
  ];

  // Más espirales y puntos que destellos: el fondo es de dibujos.
  static const List<_Dibujo> _pequenos = [
    _espiral,
    _puntos,
    _espiral,
    _puntos,
    _chispa,
  ];

  /// El reparto, calculado una sola vez con una semilla fija.
  static final List<_Colocado> _reparto = _repartir();

  /// Muestreo de Poisson (Bridson): puntos sueltos, a [_separacion] como
  /// mínimo, sin la cuadrícula de un mosaico. Los que tienen sitio son
  /// dibujos grandes; los que quedan entre ellos, adornos pequeños.
  static List<_Colocado> _repartir() {
    final azar = math.Random(20261012);
    const r = _separacion;
    final celda = r / math.sqrt2;
    final columnas = (_lienzo.width / celda).ceil();
    final filas = (_lienzo.height / celda).ceil();
    final rejilla = List<Offset?>.filled(columnas * filas, null);
    final puntos = <Offset>[];
    final activos = <Offset>[];

    int indice(Offset p) =>
        (p.dy / celda).floor() * columnas + (p.dx / celda).floor();

    bool cabe(Offset p) {
      if (p.dx < 0 ||
          p.dy < 0 ||
          p.dx >= _lienzo.width ||
          p.dy >= _lienzo.height) {
        return false;
      }
      final cx = (p.dx / celda).floor();
      final cy = (p.dy / celda).floor();
      for (var y = math.max(0, cy - 2); y <= math.min(filas - 1, cy + 2); y++) {
        for (
          var x = math.max(0, cx - 2);
          x <= math.min(columnas - 1, cx + 2);
          x++
        ) {
          final otro = rejilla[y * columnas + x];
          if (otro != null && (otro - p).distance < r) return false;
        }
      }
      return true;
    }

    void anadir(Offset p) {
      puntos.add(p);
      activos.add(p);
      rejilla[indice(p)] = p;
    }

    anadir(Offset(azar.nextDouble() * 200, azar.nextDouble() * 200));
    while (activos.isNotEmpty) {
      final i = azar.nextInt(activos.length);
      final base = activos[i];
      var encontrado = false;
      for (var intento = 0; intento < 24; intento++) {
        final angulo = azar.nextDouble() * 2 * math.pi;
        final distancia = r * (1 + azar.nextDouble());
        final p = base + Offset.fromDirection(angulo, distancia);
        if (cabe(p)) {
          anadir(p);
          encontrado = true;
          break;
        }
      }
      if (!encontrado) activos.removeAt(i);
    }

    // A cada sitio le toca el dibujo que más lejos tiene a su igual más
    // cercano: en una pantalla de teléfono no se repite ninguno, y en una
    // tableta los iguales quedan en extremos opuestos.
    final colocados = <_Colocado>[];
    final grandes = <Offset>[];
    final sitios = <_Dibujo, List<Offset>>{};

    for (final p in puntos) {
      final hayHueco = grandes.every(
        (g) => (g - p).distance >= _separacionGrandes,
      );
      if (!hayHueco) {
        colocados.add(
          _Colocado(
            _pequenos[azar.nextInt(_pequenos.length)],
            p,
            azar.nextDouble() * 2 * math.pi,
            0.55 + azar.nextDouble() * 0.2,
          ),
        );
        continue;
      }
      double igualMasCercano(_Dibujo d) {
        var minimo = double.infinity;
        for (final o in sitios[d] ?? const <Offset>[]) {
          minimo = math.min(minimo, (o - p).distance);
        }
        return minimo;
      }

      // Barajados antes, para que un empate no favorezca siempre al primero.
      final candidatos = [..._grandes]..shuffle(azar);
      var elegido = candidatos.first;
      var mejor = igualMasCercano(elegido);
      for (final d in candidatos.skip(1)) {
        final distancia = igualMasCercano(d);
        if (distancia > mejor) {
          elegido = d;
          mejor = distancia;
        }
      }
      sitios.putIfAbsent(elegido, () => []).add(p);
      grandes.add(p);
      colocados.add(
        _Colocado(
          elegido,
          p,
          (azar.nextDouble() - 0.5) * 0.7,
          1.15 + azar.nextDouble() * 0.25,
        ),
      );
    }
    return colocados;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final trazo = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final relleno = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.clipRect(Offset.zero & size);
    final visible = (Offset.zero & size).inflate(24);
    for (final c in _reparto) {
      if (!visible.contains(c.centro)) continue;
      canvas
        ..save()
        ..translate(c.centro.dx, c.centro.dy)
        ..rotate(c.giro)
        ..scale(c.escala);
      c.dibujo(canvas, trazo, relleno);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_DoodlePainter oldDelegate) => false;

  // Cada dibujo va centrado en el origen y ocupa unos 32 px.

  static void _ballena(Canvas c, Paint t, Paint f) {
    c.drawPath(
      Path()
        ..moveTo(-15, 1)
        ..cubicTo(-15, -11, 8, -12, 11, -1)
        ..lineTo(16, -7)
        ..lineTo(15, 4)
        ..lineTo(11, 3)
        ..cubicTo(7, 11, -15, 11, -15, 1)
        ..close(),
      t,
    );
    c.drawPath(
      Path()
        ..moveTo(-14, 4)
        ..quadraticBezierTo(-3, 8, 9, 4),
      t,
    );
    c.drawCircle(const Offset(-9, -2), 1.2, f);
    c.drawPath(
      Path()
        ..moveTo(-6, -10)
        ..quadraticBezierTo(-8, -15, -11, -15)
        ..moveTo(-6, -10)
        ..quadraticBezierTo(-4, -15, -1, -15),
      t,
    );
  }

  static void _sobre(Canvas c, Paint t, Paint f) {
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-14, -9, 28, 19),
        const Radius.circular(2.5),
      ),
      t,
    );
    c.drawPath(
      Path()
        ..moveTo(-13, -8)
        ..lineTo(0, 3)
        ..lineTo(13, -8),
      t,
    );
    // El lacre: un corazoncito donde se cierra la solapa.
    c.drawPath(
      Path()
        ..moveTo(0, 6)
        ..cubicTo(-5, 2, -3, -2, 0, 1)
        ..cubicTo(3, -2, 5, 2, 0, 6),
      t,
    );
  }

  static void _carta(Canvas c, Paint t, Paint f) {
    c.drawPath(
      Path()
        ..moveTo(-10, -14)
        ..lineTo(5, -14)
        ..lineTo(11, -8)
        ..lineTo(11, 14)
        ..lineTo(-10, 14)
        ..close()
        ..moveTo(5, -14)
        ..lineTo(5, -8)
        ..lineTo(11, -8),
      t,
    );
    for (final y in [-5.0, 0.0, 5.0, 10.0]) {
      c.drawLine(Offset(-6, y), Offset(y == 10 ? 2 : 7, y), t);
    }
  }

  static void _planeta(Canvas c, Paint t, Paint f) {
    c.drawCircle(Offset.zero, 8, t);
    c.drawArc(
      Rect.fromCenter(center: Offset.zero, width: 32, height: 10),
      -0.25,
      math.pi + 0.5,
      false,
      t,
    );
    c.drawCircle(const Offset(13, -11), 1.4, f);
    c.drawCircle(const Offset(-14, 10), 1, f);
  }

  static void _globoAerostatico(Canvas c, Paint t, Paint f) {
    c.drawPath(
      Path()
        ..moveTo(-5, 5)
        ..cubicTo(-16, -3, -12, -17, 0, -17)
        ..cubicTo(12, -17, 16, -3, 5, 5)
        ..close()
        ..moveTo(0, -17)
        ..quadraticBezierTo(-7, -6, -2, 5)
        ..moveTo(0, -17)
        ..quadraticBezierTo(7, -6, 2, 5)
        ..moveTo(-5, 5)
        ..lineTo(-3.5, 10)
        ..moveTo(5, 5)
        ..lineTo(3.5, 10),
      t,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-4, 10, 8, 6),
        const Radius.circular(1.2),
      ),
      t,
    );
  }

  static void _mariposa(Canvas c, Paint t, Paint f) {
    void ala() {
      c.drawPath(
        Path()
          ..moveTo(0, -2)
          ..cubicTo(-6, -14, -17, -12, -14, -3)
          ..cubicTo(-12, 2, -5, 1, 0, -2)
          ..moveTo(0, 0)
          ..cubicTo(-10, 2, -12, 11, -6, 11)
          ..cubicTo(-3, 11, -1, 6, 0, 0)
          ..moveTo(0, -6)
          ..quadraticBezierTo(-2, -11, -5, -13),
        t,
      );
    }

    ala();
    c
      ..save()
      ..scale(-1, 1);
    ala();
    c.restore();
    c.drawLine(const Offset(0, -6), const Offset(0, 8), t);
  }

  static void _nubePath(Canvas c, Paint t, Offset en, double escala) {
    c
      ..save()
      ..translate(en.dx, en.dy)
      ..scale(escala);
    c.drawPath(
      Path()
        ..moveTo(-9, 4)
        ..cubicTo(-14, 4, -14, -3, -8, -2)
        ..cubicTo(-8, -8, 0, -9, 1, -3)
        ..cubicTo(4, -7, 11, -4, 9, 0)
        ..cubicTo(13, 1, 12, 4, 8, 4)
        ..close(),
      t,
    );
    c.restore();
  }

  static void _arcoiris(Canvas c, Paint t, Paint f) {
    for (final r in [15.0, 11.0, 7.0]) {
      c.drawArc(
        Rect.fromCircle(center: const Offset(0, 6), radius: r),
        math.pi,
        math.pi,
        false,
        t,
      );
    }
    _nubePath(c, t, const Offset(-12, 7), 0.6);
    _nubePath(c, t, const Offset(12, 7), 0.6);
  }

  static void _lupa(Canvas c, Paint t, Paint f) {
    c.drawCircle(const Offset(-3, -3), 9, t);
    c.drawArc(
      Rect.fromCircle(center: const Offset(-3, -3), radius: 5.5),
      math.pi * 1.05,
      math.pi * 0.45,
      false,
      t,
    );
    c.drawPath(
      Path()
        ..moveTo(3.5, 3.5)
        ..lineTo(13, 13)
        ..lineTo(15, 11)
        ..lineTo(5.5, 1.5),
      t,
    );
  }

  static void _casete(Canvas c, Paint t, Paint f) {
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-15, -10, 30, 20),
        const Radius.circular(2.5),
      ),
      t,
    );
    c.drawRect(const Rect.fromLTWH(-11, -7, 22, 9), t);
    c.drawCircle(const Offset(-5, -2.5), 2.5, t);
    c.drawCircle(const Offset(5, -2.5), 2.5, t);
    c.drawPath(
      Path()
        ..moveTo(-9, 10)
        ..lineTo(-7, 5)
        ..lineTo(7, 5)
        ..lineTo(9, 10),
      t,
    );
  }

  static void _taza(Canvas c, Paint t, Paint f) {
    c.drawPath(
      Path()
        ..moveTo(-11, -2)
        ..lineTo(8, -2)
        ..cubicTo(8, 7, 3, 11, -1.5, 11)
        ..cubicTo(-6, 11, -11, 7, -11, -2)
        ..close(),
      t,
    );
    c.drawArc(const Rect.fromLTWH(4, 0, 9, 7), -math.pi / 2, math.pi, false, t);
    c.drawLine(const Offset(-14, 14), const Offset(11, 14), t);
    c.drawPath(
      Path()
        ..moveTo(-5, -5)
        ..cubicTo(-8, -8, -2, -10, -5, -14)
        ..moveTo(1, -5)
        ..cubicTo(-2, -8, 4, -10, 1, -14),
      t,
    );
  }

  static void _flor(Canvas c, Paint t, Paint f) {
    for (var i = 0; i < 5; i++) {
      final a = -math.pi / 2 + i * 2 * math.pi / 5;
      c.drawCircle(const Offset(0, -8) + Offset.fromDirection(a, 4.6), 3.4, t);
    }
    c.drawCircle(const Offset(0, -8), 1.6, f);
    c.drawPath(
      Path()
        ..moveTo(0, -2)
        ..quadraticBezierTo(1.5, 8, 0, 16)
        ..moveTo(0.6, 8)
        ..quadraticBezierTo(7, 1, 10, 5)
        ..quadraticBezierTo(6, 10, 0.6, 8),
      t,
    );
  }

  static void _nube(Canvas c, Paint t, Paint f) {
    _nubePath(c, t, Offset.zero, 1.5);
    c.drawLine(const Offset(-6, 11), const Offset(-8, 15), t);
    c.drawLine(const Offset(1, 11), const Offset(-1, 15), t);
    c.drawLine(const Offset(8, 11), const Offset(6, 15), t);
  }

  static void _hojaEn(Canvas c, Paint t, Offset en, double giro) {
    c
      ..save()
      ..translate(en.dx, en.dy)
      ..rotate(giro);
    c.drawPath(
      Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(4, -5, 0, -10)
        ..quadraticBezierTo(-4, -5, 0, 0)
        ..moveTo(0, -1)
        ..lineTo(0, -7),
      t,
    );
    c.restore();
  }

  static void _rama(Canvas c, Paint t, Paint f) {
    c.drawPath(
      Path()
        ..moveTo(-10, 15)
        ..quadraticBezierTo(0, 3, 8, -15),
      t,
    );
    _hojaEn(c, t, const Offset(-5, 8), -0.9);
    _hojaEn(c, t, const Offset(-3, 6), 0.7);
    _hojaEn(c, t, const Offset(2, -2), -0.8);
    _hojaEn(c, t, const Offset(3, -4), 0.9);
    _hojaEn(c, t, const Offset(8, -15), 0.3);
  }

  static void _lapiz(Canvas c, Paint t, Paint f) {
    c.drawPath(
      Path()
        ..moveTo(-15, -3.5)
        ..lineTo(7, -3.5)
        ..lineTo(15, 0)
        ..lineTo(7, 3.5)
        ..lineTo(-15, 3.5)
        ..close()
        ..moveTo(7, -3.5)
        ..lineTo(7, 3.5)
        ..moveTo(-10, -3.5)
        ..lineTo(-10, 3.5),
      t,
    );
    c.drawCircle(const Offset(13.2, 0), 0.9, f);
  }

  static void _disco(Canvas c, Paint t, Paint f) {
    c.drawCircle(Offset.zero, 13, t);
    c.drawCircle(Offset.zero, 4, t);
    c.drawCircle(Offset.zero, 1.2, f);
    c.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: 9),
      -2.6,
      1.1,
      false,
      t,
    );
    c.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: 9),
      0.5,
      1.1,
      false,
      t,
    );
  }

  static void _polaroid(Canvas c, Paint t, Paint f) {
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-12, -14, 24, 28),
        const Radius.circular(2),
      ),
      t,
    );
    c.drawRect(const Rect.fromLTWH(-9, -11, 18, 17), t);
    c.drawCircle(const Offset(4, -6), 2, t);
    c.drawPath(
      Path()
        ..moveTo(-9, 5)
        ..lineTo(-3, -2)
        ..lineTo(1, 2)
        ..lineTo(4, -1)
        ..lineTo(9, 4),
      t,
    );
  }

  static void _globo(Canvas c, Paint t, Paint f) {
    c.drawOval(
      Rect.fromCenter(center: const Offset(0, -7), width: 17, height: 21),
      t,
    );
    c.drawArc(
      Rect.fromCenter(center: const Offset(0, -7), width: 11, height: 15),
      math.pi * 1.1,
      math.pi * 0.35,
      false,
      t,
    );
    c.drawPath(
      Path()
        ..moveTo(-1.8, 5)
        ..lineTo(1.8, 5)
        ..lineTo(0, 3.3)
        ..close()
        ..moveTo(0, 5)
        ..cubicTo(-5, 9, 5, 12, 0, 17),
      t,
    );
  }

  static void _notas(Canvas c, Paint t, Paint f) {
    c.drawOval(
      Rect.fromCenter(center: const Offset(-6, 9), width: 8, height: 6),
      f,
    );
    c.drawOval(
      Rect.fromCenter(center: const Offset(7, 6), width: 8, height: 6),
      f,
    );
    c.drawPath(
      Path()
        ..moveTo(-2.2, 9)
        ..lineTo(-2.2, -9)
        ..lineTo(10.8, -12)
        ..lineTo(10.8, 6)
        ..moveTo(-2.2, -4)
        ..lineTo(10.8, -7),
      t,
    );
  }

  static void _luna(Canvas c, Paint t, Paint f) {
    c.drawPath(
      Path()
        ..moveTo(2, -12)
        ..arcToPoint(
          const Offset(2, 12),
          radius: const Radius.circular(12),
          clockwise: false,
        )
        ..arcToPoint(const Offset(2, -12), radius: const Radius.circular(14)),
      t,
    );
    c.drawCircle(const Offset(11, -8), 1.3, f);
    c.drawCircle(const Offset(13, 3), 0.9, f);
  }

  static void _paraguas(Canvas c, Paint t, Paint f) {
    c.drawPath(
      Path()
        ..moveTo(-15, 0)
        ..quadraticBezierTo(-15, -14, 0, -14)
        ..quadraticBezierTo(15, -14, 15, 0)
        ..quadraticBezierTo(11.25, -4, 7.5, 0)
        ..quadraticBezierTo(3.75, -4, 0, 0)
        ..quadraticBezierTo(-3.75, -4, -7.5, 0)
        ..quadraticBezierTo(-11.25, -4, -15, 0)
        ..moveTo(0, -14)
        ..lineTo(0, -16)
        ..moveTo(0, 0)
        ..lineTo(0, 12)
        ..arcToPoint(const Offset(-6, 12), radius: const Radius.circular(3)),
      t,
    );
  }

  static void _cactus(Canvas c, Paint t, Paint f) {
    c.drawPath(
      Path()
        ..moveTo(-8, 6)
        ..lineTo(8, 6)
        ..lineTo(6, 15)
        ..lineTo(-6, 15)
        ..close(),
      t,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-3.5, -13, 7, 19),
        const Radius.circular(3.5),
      ),
      t,
    );
    c.drawPath(
      Path()
        ..moveTo(-3.5, 1)
        ..quadraticBezierTo(-9, 1, -9, -6)
        ..moveTo(3.5, -2)
        ..quadraticBezierTo(9, -2, 9, -9),
      t,
    );
  }

  static void _avionDePapel(Canvas c, Paint t, Paint f) {
    c.drawPath(
      Path()
        ..moveTo(-14, 0)
        ..lineTo(14, -10)
        ..lineTo(4, 12)
        ..lineTo(0, 3)
        ..close()
        ..moveTo(0, 3)
        ..lineTo(14, -10),
      t,
    );
    // La estela, a trazos.
    for (var i = 0; i < 3; i++) {
      final x = -16.0 - i * 5;
      c.drawLine(Offset(x, 6 + i * 2.0), Offset(x - 2.5, 7 + i * 2.0), t);
    }
  }

  /// Una mano abierta: la seña está en el centro de la app.
  static void _mano(Canvas c, Paint t, Paint f) {
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-7, -1, 14, 14),
        const Radius.circular(5),
      ),
      t,
    );
    for (final (dx, alto) in [
      (-5.0, 9.0),
      (-1.7, 12.0),
      (1.7, 12.0),
      (5.0, 9.0),
    ]) {
      c.drawLine(Offset(dx, -1), Offset(dx, -1 - alto), t);
    }
    c.drawLine(const Offset(-7, 6), const Offset(-12, 0), t);
  }

  static void _bocadillo(Canvas c, Paint t, Paint f) {
    c.drawPath(
      Path()
        ..addRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(-15, -11, 30, 19),
            const Radius.circular(7),
          ),
        )
        ..moveTo(-7, 8)
        ..lineTo(-11, 14)
        ..lineTo(-1, 8),
      t,
    );
    for (final dx in [-6.0, 0.0, 6.0]) {
      c.drawCircle(Offset(dx, -1.5), 1.5, f);
    }
  }

  static void _libro(Canvas c, Paint t, Paint f) {
    c.drawPath(
      Path()
        ..moveTo(0, -8)
        ..quadraticBezierTo(-7, -12, -15, -9)
        ..lineTo(-15, 9)
        ..quadraticBezierTo(-7, 6, 0, 10)
        ..quadraticBezierTo(7, 6, 15, 9)
        ..lineTo(15, -9)
        ..quadraticBezierTo(7, -12, 0, -8)
        ..lineTo(0, 10),
      t,
    );
    for (final y in [-4.0, 0.0, 4.0]) {
      c.drawLine(Offset(-11, y), Offset(-4, y + 0.5), t);
      c.drawLine(Offset(4, y + 0.5), Offset(11, y), t);
    }
  }

  static void _camara(Canvas c, Paint t, Paint f) {
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-15, -8, 30, 20),
        const Radius.circular(3),
      ),
      t,
    );
    c.drawPath(
      Path()
        ..moveTo(-6, -8)
        ..lineTo(-4, -12)
        ..lineTo(4, -12)
        ..lineTo(6, -8),
      t,
    );
    c.drawCircle(const Offset(0, 2), 6, t);
    c.drawCircle(const Offset(0, 2), 2.5, t);
    c.drawCircle(const Offset(10, -4), 1.2, f);
  }

  static void _llave(Canvas c, Paint t, Paint f) {
    c.drawCircle(const Offset(-9, 0), 5.5, t);
    c.drawCircle(const Offset(-9, 0), 1.6, t);
    c.drawPath(
      Path()
        ..moveTo(-3.5, 0)
        ..lineTo(15, 0)
        ..moveTo(9, 0)
        ..lineTo(9, 5)
        ..moveTo(13, 0)
        ..lineTo(13, 4),
      t,
    );
  }

  static void _casa(Canvas c, Paint t, Paint f) {
    c.drawPath(
      Path()
        ..moveTo(-13, -1)
        ..lineTo(0, -13)
        ..lineTo(13, -1)
        ..moveTo(-9, -4)
        ..lineTo(-9, 12)
        ..lineTo(9, 12)
        ..lineTo(9, -4)
        ..moveTo(6, -7)
        ..lineTo(6, -13)
        ..lineTo(9.5, -13)
        ..lineTo(9.5, -4)
        ..moveTo(-3, 12)
        ..lineTo(-3, 4)
        ..lineTo(3, 4)
        ..lineTo(3, 12),
      t,
    );
    c.drawCircle(const Offset(0, -4), 2, t);
  }

  static void _pez(Canvas c, Paint t, Paint f) {
    c.drawPath(
      Path()
        ..moveTo(-13, 0)
        ..quadraticBezierTo(-2, -11, 8, 0)
        ..quadraticBezierTo(-2, 11, -13, 0)
        ..moveTo(8, 0)
        ..lineTo(15, -6)
        ..lineTo(15, 6)
        ..close()
        ..moveTo(-5, -5)
        ..quadraticBezierTo(-2, 0, -5, 5),
      t,
    );
    c.drawCircle(const Offset(-9, -1.5), 1.2, f);
  }

  static void _caracol(Canvas c, Paint t, Paint f) {
    final espiral = Path();
    const centro = Offset(3, -2);
    for (var i = 0; i <= 60; i++) {
      final a = i / 60 * 3.2 * math.pi;
      final r = 1 + a * 0.85;
      final p = centro + Offset.fromDirection(a + math.pi, r);
      i == 0 ? espiral.moveTo(p.dx, p.dy) : espiral.lineTo(p.dx, p.dy);
    }
    c.drawPath(espiral, t);
    c.drawPath(
      Path()
        ..moveTo(-15, 9)
        ..lineTo(13, 9)
        ..quadraticBezierTo(16, 9, 14, 6)
        ..moveTo(-15, 9)
        ..quadraticBezierTo(-17, 2, -11, 2)
        ..lineTo(-6, 4)
        ..moveTo(-13, 2)
        ..lineTo(-15, -5)
        ..moveTo(-11, 2)
        ..lineTo(-10, -6),
      t,
    );
    c.drawCircle(const Offset(-15, -5.5), 1, f);
    c.drawCircle(const Offset(-10, -6.5), 1, f);
  }

  static void _gafas(Canvas c, Paint t, Paint f) {
    c.drawCircle(const Offset(-7, 0), 5.5, t);
    c.drawCircle(const Offset(7, 0), 5.5, t);
    c.drawPath(
      Path()
        ..moveTo(-1.5, -1)
        ..quadraticBezierTo(0, -3, 1.5, -1)
        ..moveTo(-12.5, -1)
        ..lineTo(-16, -5)
        ..moveTo(12.5, -1)
        ..lineTo(16, -5),
      t,
    );
  }

  static void _bombilla(Canvas c, Paint t, Paint f) {
    c.drawPath(
      Path()
        ..moveTo(-4, 5)
        ..cubicTo(-12, -2, -8, -14, 0, -14)
        ..cubicTo(8, -14, 12, -2, 4, 5)
        ..moveTo(-2, 4)
        ..lineTo(-2, -2)
        ..lineTo(0, 0)
        ..lineTo(2, -2)
        ..lineTo(2, 4),
      t,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-4, 5, 8, 6),
        const Radius.circular(1.5),
      ),
      t,
    );
    c.drawLine(const Offset(-4, 8), const Offset(4, 8), t);
    c.drawLine(const Offset(-1.5, 13), const Offset(1.5, 13), t);
  }

  static void _reloj(Canvas c, Paint t, Paint f) {
    c.drawCircle(const Offset(0, 1), 10.5, t);
    c.drawPath(
      Path()
        ..moveTo(0, 1)
        ..lineTo(0, -5)
        ..moveTo(0, 1)
        ..lineTo(4.5, 3.5)
        ..moveTo(-7, 10)
        ..lineTo(-9.5, 14)
        ..moveTo(7, 10)
        ..lineTo(9.5, 14),
      t,
    );
    c.drawArc(
      Rect.fromCircle(center: const Offset(-8, -10), radius: 4),
      math.pi * 0.8,
      math.pi * 0.95,
      false,
      t,
    );
    c.drawArc(
      Rect.fromCircle(center: const Offset(8, -10), radius: 4),
      math.pi * 1.25,
      math.pi * 0.95,
      false,
      t,
    );
  }

  static void _ancla(Canvas c, Paint t, Paint f) {
    c.drawCircle(const Offset(0, -12), 3, t);
    c.drawPath(
      Path()
        ..moveTo(0, -9)
        ..lineTo(0, 13)
        ..moveTo(-6, -5)
        ..lineTo(6, -5)
        ..moveTo(-10, 3)
        ..lineTo(-7, 5)
        ..moveTo(10, 3)
        ..lineTo(7, 5),
      t,
    );
    c.drawArc(
      Rect.fromCircle(center: const Offset(0, 3), radius: 10),
      0,
      math.pi,
      false,
      t,
    );
  }

  static void _barco(Canvas c, Paint t, Paint f) {
    c.drawPath(
      Path()
        ..moveTo(-15, 2)
        ..lineTo(15, 2)
        ..lineTo(10, 9)
        ..lineTo(-10, 9)
        ..close()
        ..moveTo(-2, 2)
        ..lineTo(-2, -15)
        ..lineTo(9, 2)
        ..moveTo(-14, 14)
        ..quadraticBezierTo(-10, 11, -6, 14)
        ..quadraticBezierTo(-2, 17, 2, 14)
        ..quadraticBezierTo(6, 11, 10, 14),
      t,
    );
  }

  static void _cometa(Canvas c, Paint t, Paint f) {
    c.drawPath(
      Path()
        ..moveTo(0, -15)
        ..lineTo(9, -4)
        ..lineTo(0, 6)
        ..lineTo(-9, -4)
        ..close()
        ..moveTo(0, -15)
        ..lineTo(0, 6)
        ..moveTo(-9, -4)
        ..lineTo(9, -4)
        ..moveTo(0, 6)
        ..cubicTo(-5, 9, 5, 12, 0, 16)
        ..moveTo(-3, 10)
        ..lineTo(3, 8)
        ..moveTo(-3, 14)
        ..lineTo(3, 13),
      t,
    );
  }

  static void _arbol(Canvas c, Paint t, Paint f) {
    c.drawPath(
      Path()
        ..moveTo(-3, 6)
        ..cubicTo(-14, 7, -15, -6, -7, -8)
        ..cubicTo(-7, -16, 7, -16, 7, -8)
        ..cubicTo(15, -6, 14, 7, 3, 6)
        ..moveTo(-2.5, 6)
        ..lineTo(-2.5, 15)
        ..moveTo(2.5, 6)
        ..lineTo(2.5, 15)
        ..moveTo(0, 6)
        ..lineTo(4, 1)
        ..moveTo(-7, 17)
        ..lineTo(7, 17),
      t,
    );
  }

  static void _campana(Canvas c, Paint t, Paint f) {
    c.drawPath(
      Path()
        ..moveTo(-11, 7)
        ..quadraticBezierTo(-8, 4, -8, -3)
        ..cubicTo(-8, -13, 8, -13, 8, -3)
        ..quadraticBezierTo(8, 4, 11, 7)
        ..close(),
      t,
    );
    c.drawCircle(const Offset(0, 10), 2.2, t);
    c.drawCircle(const Offset(0, -12.5), 1.6, t);
    c.drawArc(
      Rect.fromCircle(center: const Offset(0, -2), radius: 4.5),
      math.pi * 1.05,
      math.pi * 0.4,
      false,
      t,
    );
  }

  static void _cohete(Canvas c, Paint t, Paint f) {
    c.drawPath(
      Path()
        ..moveTo(0, -16)
        ..cubicTo(7, -10, 7, 0, 5, 8)
        ..lineTo(-5, 8)
        ..cubicTo(-7, 0, -7, -10, 0, -16)
        ..close()
        ..moveTo(-5.5, 1)
        ..lineTo(-10, 10)
        ..lineTo(-5, 8)
        ..moveTo(5.5, 1)
        ..lineTo(10, 10)
        ..lineTo(5, 8)
        ..moveTo(-3, 9)
        ..quadraticBezierTo(0, 17, 3, 9),
      t,
    );
    c.drawCircle(const Offset(0, -5), 2.8, t);
  }

  static void _tijeras(Canvas c, Paint t, Paint f) {
    c.drawCircle(const Offset(-6, 10), 4, t);
    c.drawCircle(const Offset(6, 10), 4, t);
    c.drawPath(
      Path()
        ..moveTo(-4, 6.5)
        ..lineTo(6, -15)
        ..moveTo(4, 6.5)
        ..lineTo(-6, -15),
      t,
    );
    c.drawCircle(const Offset(0, -2.2), 1.2, f);
  }

  // Adornos pequeños entre los dibujos.

  static void _espiral(Canvas c, Paint t, Paint f) {
    final p = Path();
    for (var i = 0; i <= 40; i++) {
      final a = i / 40 * 2.6 * math.pi;
      final punto = Offset.fromDirection(a, 1 + a * 1.2);
      i == 0 ? p.moveTo(punto.dx, punto.dy) : p.lineTo(punto.dx, punto.dy);
    }
    c.drawPath(p, t);
  }

  static void _puntos(Canvas c, Paint t, Paint f) {
    c.drawCircle(const Offset(-7, 1), 2.4, t);
    c.drawCircle(const Offset(1, -6), 3.2, t);
    c.drawCircle(const Offset(7, 5), 2, t);
  }

  static void _chispa(Canvas c, Paint t, Paint f) {
    c.drawPath(
      Path()
        ..moveTo(0, -11)
        ..quadraticBezierTo(1.5, -1.5, 11, 0)
        ..quadraticBezierTo(1.5, 1.5, 0, 11)
        ..quadraticBezierTo(-1.5, 1.5, -11, 0)
        ..quadraticBezierTo(-1.5, -1.5, 0, -11),
      t,
    );
  }
}
