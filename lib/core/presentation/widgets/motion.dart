import 'package:flutter/material.dart';

/// Hunde levemente su contenido mientras se mantiene pulsado.
///
/// Solo escucha el puntero, no lo consume: el `InkWell` o el botón de dentro
/// sigue recibiendo el toque igual que antes.
class PressableScale extends StatefulWidget {
  final Widget child;
  final double pressedScale;

  const PressableScale({
    super.key,
    required this.child,
    this.pressedScale = 0.96,
  });

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pulsado = false;

  void _set(bool valor) {
    if (_pulsado != valor) setState(() => _pulsado = valor);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _pulsado ? widget.pressedScale : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Entrada con fundido y un leve ascenso, escalonada por [index].
///
/// Se reproduce una sola vez, al montarse. Para que vuelva a entrar con otro
/// contenido, el llamador le da otra `key`.
class StaggeredEntrance extends StatefulWidget {
  final int index;
  final Widget child;

  /// Retardo entre un elemento y el siguiente. Se limita para que una lista
  /// larga no tarde en terminar de aparecer.
  static const Duration step = Duration(milliseconds: 35);
  static const int maxSteps = 8;

  const StaggeredEntrance({
    super.key,
    required this.index,
    required this.child,
  });

  @override
  State<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<StaggeredEntrance>
    with SingleTickerProviderStateMixin {
  static const _entrada = Duration(milliseconds: 260);

  // El retardo va dentro de la propia animación (un `Interval`), sin timers.
  late final Duration _retardo =
      StaggeredEntrance.step *
      widget.index.clamp(0, StaggeredEntrance.maxSteps);
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _entrada + _retardo,
  )..forward();
  late final Animation<double> _curva = CurvedAnimation(
    parent: _controller,
    curve: Interval(
      _retardo.inMicroseconds / (_entrada + _retardo).inMicroseconds,
      1,
      curve: Curves.easeOutCubic,
    ),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curva,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(_curva),
        child: widget.child,
      ),
    );
  }
}

/// Pulsación de burbuja: se hunde al apoyar el dedo y, al soltar, vuelve con
/// un pequeño rebote.
///
/// Como [PressableScale], solo escucha el puntero: el toque sigue llegando al
/// botón de dentro igual que antes.
class BubblePress extends StatefulWidget {
  final Widget child;

  const BubblePress({super.key, required this.child});

  @override
  State<BubblePress> createState() => _BubblePressState();
}

class _BubblePressState extends State<BubblePress> {
  bool _pulsado = false;

  void _set(bool valor) {
    if (_pulsado != valor) setState(() => _pulsado = valor);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _pulsado ? 0.94 : 1,
        // Hundirse es rápido; volver, con el rebote de una burbuja.
        duration: Duration(milliseconds: _pulsado ? 90 : 420),
        curve: _pulsado ? Curves.easeOut : Curves.elasticOut,
        child: widget.child,
      ),
    );
  }
}

/// Entrada de burbuja: crece desde un poco más chica con un leve rebote,
/// escalonada por [index]. Se reproduce una vez, al montarse; para que
/// vuelva a entrar, el llamador le da otra `key`.
class BubbleEntrance extends StatefulWidget {
  final int index;
  final Widget child;

  const BubbleEntrance({super.key, required this.index, required this.child});

  @override
  State<BubbleEntrance> createState() => _BubbleEntranceState();
}

class _BubbleEntranceState extends State<BubbleEntrance>
    with SingleTickerProviderStateMixin {
  static const _entrada = Duration(milliseconds: 380);

  late final Duration _retardo =
      StaggeredEntrance.step *
      widget.index.clamp(0, StaggeredEntrance.maxSteps);
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _entrada + _retardo,
  )..forward();
  late final double _inicio =
      _retardo.inMicroseconds / (_entrada + _retardo).inMicroseconds;
  late final Animation<double> _escala = Tween<double>(begin: 0.86, end: 1)
      .animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(_inicio, 1, curve: Curves.easeOutBack),
        ),
      );
  late final Animation<double> _opacidad = CurvedAnimation(
    parent: _controller,
    curve: Interval(_inicio, 1, curve: Curves.easeOut),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacidad,
      child: ScaleTransition(scale: _escala, child: widget.child),
    );
  }
}

/// Transición de burbuja para un `AnimatedSwitcher`: lo nuevo crece desde un
/// poco más chico mientras aparece.
Widget bubbleSwitcherTransition(Widget child, Animation<double> animation) {
  return FadeTransition(
    opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
    child: ScaleTransition(
      scale: Tween<double>(
        begin: 0.94,
        end: 1,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutBack)),
      child: child,
    ),
  );
}
