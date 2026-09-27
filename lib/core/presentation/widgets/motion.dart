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
