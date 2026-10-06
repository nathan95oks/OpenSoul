import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lsb_legal_app/core/presentation/widgets/avatar_3d_viewer.dart';

/// Lo que un lugar de la pantalla le pide al avatar compartido: las mismas
/// opciones que [Avatar3DViewer], salvo las de tamaño (las pone el lugar).
class AvatarRequest {
  final List<String>? glosses;
  final List<String>? animationUrls;
  final int playbackRequestId;
  final bool isProcessing;
  final bool isUserComposing;
  final bool showControls;
  final bool showBackButton;

  /// Ver [Avatar3DViewer.describePendingSigns].
  final bool describePendingSigns;
  final Duration animationDuration;
  final ValueChanged<bool>? onPlaybackStateChanged;
  final VoidCallback? onReturnToInput;

  const AvatarRequest({
    this.glosses,
    this.animationUrls,
    this.playbackRequestId = 0,
    this.isProcessing = false,
    this.isUserComposing = false,
    this.showControls = true,
    this.showBackButton = true,
    this.describePendingSigns = false,
    this.animationDuration = const Duration(seconds: 3),
    this.onPlaybackStateChanged,
    this.onReturnToInput,
  });
}

/// Un lugar que pidió el avatar.
class _Claim {
  final Object owner;
  LayerLink link;
  Size size;
  AvatarRequest request;
  bool visible;

  /// Cambia cada vez que este lugar pasa a tener el avatar: aunque pida las
  /// mismas señas que el anterior, el avatar las vuelve a empezar.
  int generation = 0;

  _Claim(this.owner, this.link, this.size, this.request, this.visible);
}

/// Reparte el único avatar 3D de la app entre los lugares que lo piden.
///
/// El avatar lo tiene el último lugar visible que lo pidió (una hoja que se
/// abre encima gana al de debajo). Los demás esperan: al cerrarse la hoja, el
/// de debajo lo recupera.
class SharedAvatarController extends ChangeNotifier {
  final List<_Claim> _claims = [];
  int _generation = 0;
  _Claim? _active;

  /// Hay un [SharedAvatarHost] en la app que dibuja el avatar.
  bool hostMounted = false;

  _Claim? get _visible {
    for (final c in _claims.reversed) {
      if (c.visible) return c;
    }
    return null;
  }

  void _publish(
    Object owner,
    LayerLink link,
    Size size,
    AvatarRequest request,
    bool visible,
  ) {
    var claim = _claims.where((c) => identical(c.owner, owner)).firstOrNull;
    if (claim == null) {
      claim = _Claim(owner, link, size, request, visible);
      _claims.add(claim);
    } else {
      claim
        ..link = link
        ..size = size
        ..request = request
        ..visible = visible;
    }
    _refresh();
  }

  void _withdraw(Object owner) {
    _claims.removeWhere((c) => identical(c.owner, owner));
    _refresh();
  }

  bool _avisoPendiente = false;
  bool _desechado = false;

  void _refresh() {
    final next = _visible;
    if (!identical(next, _active) && next != null) {
      next.generation = ++_generation;
    }
    _active = next;
    // Un lugar puede irse mientras el árbol se está cerrando (su dispose):
    // ahí no se puede reconstruir al anfitrión, así que se avisa tras el
    // cuadro.
    final fase = SchedulerBinding.instance.schedulerPhase;
    if (fase == SchedulerPhase.idle ||
        fase == SchedulerPhase.postFrameCallbacks) {
      notifyListeners();
      return;
    }
    if (_avisoPendiente) return;
    _avisoPendiente = true;
    SchedulerBinding.instance
      ..addPostFrameCallback((_) {
        _avisoPendiente = false;
        if (!_desechado) notifyListeners();
      })
      ..ensureVisualUpdate();
  }

  @override
  void dispose() {
    _desechado = true;
    super.dispose();
  }
}

final sharedAvatarControllerProvider = Provider<SharedAvatarController>((ref) {
  final controller = SharedAvatarController();
  ref.onDispose(controller.dispose);
  return controller;
});

/// El único avatar 3D de la app, montado en la raíz y cargado desde que se
/// abre.
///
/// Cargar el modelo (un WebView con WebGL y el .glb) es lo lento; antes cada
/// pantalla creaba el suyo y lo cargaba de cero: la hoja de Conversación cada
/// vez que se abría, la vista previa de las tarjetas y Voz a LSB. Ahora hay
/// uno solo, siempre cargado, y cada pantalla solo marca con un
/// [SharedAvatarSlot] dónde va y qué seña hace. El avatar sigue a ese lugar
/// cuadro a cuadro (también mientras una hoja se desliza) con
/// [CompositedTransformFollower]; sin lugar visible se queda escondido,
/// quieto y cargado.
class SharedAvatarHost extends ConsumerStatefulWidget {
  final Widget child;

  const SharedAvatarHost({super.key, required this.child});

  @override
  ConsumerState<SharedAvatarHost> createState() => _SharedAvatarHostState();
}

class _SharedAvatarHostState extends ConsumerState<SharedAvatarHost> {
  /// Enlace sin líder: mientras nadie pide el avatar, no se dibuja.
  final LayerLink _sinLugar = LayerLink();
  late final SharedAvatarController _controller = ref.read(
    sharedAvatarControllerProvider,
  );

  @override
  void initState() {
    super.initState();
    _controller.hostMounted = true;
  }

  @override
  void dispose() {
    _controller.hostMounted = false;
    super.dispose();
  }

  /// El visor vive en una entrada fija de su propio [Overlay]: el anfitrión
  /// está por encima del navegador de la app, donde no hay Overlay, y los
  /// botones del visor (repetir, volver) lo necesitan para sus tooltips. La
  /// entrada es siempre la misma, así que el visor nunca se vuelve a crear.
  late final OverlayEntry _entrada = OverlayEntry(
    builder: (context) => ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => _visor(),
    ),
  );

  Widget _visor() {
    final claim = _controller._active;
    final request = claim?.request;
    final visible = claim != null;
    return Material(
      type: MaterialType.transparency,
      child: Avatar3DViewer(
        key: const ValueKey('avatar_compartido'),
        isActive: true,
        expandToFit: true,
        isProcessing: request?.isProcessing ?? false,
        // Escondido, sin movimientos de reposo.
        isUserComposing: !visible || (request?.isUserComposing ?? false),
        showControls: request?.showControls ?? false,
        showBackButton: request?.showBackButton ?? true,
        describePendingSigns: request?.describePendingSigns ?? false,
        animationDuration:
            request?.animationDuration ?? const Duration(seconds: 3),
        playbackRequestId: visible
            ? claim.generation * 100000 + request!.playbackRequestId
            : 0,
        glosses: visible ? request!.glosses : null,
        animationUrls: visible ? request!.animationUrls : null,
        onPlaybackStateChanged: (playing) =>
            _controller._active?.request.onPlaybackStateChanged?.call(playing),
        onReturnToInput: () =>
            _controller._active?.request.onReturnToInput?.call(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        Positioned(
          left: 0,
          top: 0,
          child: ListenableBuilder(
            listenable: _controller,
            builder: (context, child) {
              final claim = _controller._active;
              return CompositedTransformFollower(
                link: claim?.link ?? _sinLugar,
                showWhenUnlinked: false,
                child: IgnorePointer(
                  ignoring: claim == null,
                  child: SizedBox.fromSize(
                    size: claim?.size ?? const Size(320, 480),
                    child: child,
                  ),
                ),
              );
            },
            // Siempre el mismo visor, en el mismo sitio del árbol: cambiar
            // de lugar o de seña nunca lo vuelve a cargar.
            child: Overlay(initialEntries: [_entrada]),
          ),
        ),
      ],
    );
  }
}

/// El lugar de una pantalla donde va el avatar compartido.
///
/// Ocupa lo mismo que ocupaba [Avatar3DViewer] (300 px de alto, o todo el
/// espacio con [expandToFit]) y le pide al [SharedAvatarHost] que se ponga
/// encima con [request]. Solo lo pide mientras está a la vista: [active], su
/// pestaña visible (un `IndexedStack` envuelve las ocultas en un
/// `Visibility` apagado) y su pantalla sin nada encima.
///
/// Sin anfitrión en la app (algunas pruebas), dibuja su propio visor como
/// antes.
class SharedAvatarSlot extends ConsumerStatefulWidget {
  final AvatarRequest request;
  final bool expandToFit;
  final bool active;

  const SharedAvatarSlot({
    super.key,
    required this.request,
    this.expandToFit = false,
    this.active = true,
  });

  @override
  ConsumerState<SharedAvatarSlot> createState() => _SharedAvatarSlotState();
}

class _SharedAvatarSlotState extends ConsumerState<SharedAvatarSlot> {
  final LayerLink _link = LayerLink();
  late final SharedAvatarController _controller = ref.read(
    sharedAvatarControllerProvider,
  );
  Size _size = Size.zero;
  bool _visible = false;
  bool _pendiente = false;

  /// Tras el cuadro: avisar durante un build reconstruiría al anfitrión en
  /// medio de otro build.
  void _publicar() {
    if (_pendiente) return;
    _pendiente = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pendiente = false;
      if (!mounted) return;
      _controller._publish(this, _link, _size, widget.request, _visible);
    });
  }

  @override
  void dispose() {
    _controller._withdraw(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context);
    _visible =
        widget.active && Visibility.of(context) && (route?.isCurrent ?? true);

    final alto = widget.expandToFit ? double.infinity : 300.0;
    if (!_controller.hostMounted) {
      final r = widget.request;
      return Avatar3DViewer(
        isActive: widget.active,
        expandToFit: widget.expandToFit,
        isProcessing: r.isProcessing,
        isUserComposing: r.isUserComposing,
        showControls: r.showControls,
        showBackButton: r.showBackButton,
        describePendingSigns: r.describePendingSigns,
        animationDuration: r.animationDuration,
        playbackRequestId: r.playbackRequestId,
        glosses: r.glosses,
        animationUrls: r.animationUrls,
        onPlaybackStateChanged: r.onPlaybackStateChanged,
        onReturnToInput: r.onReturnToInput,
      );
    }
    return SizedBox(
      width: double.infinity,
      height: alto,
      child: LayoutBuilder(
        builder: (context, constraints) {
          _size = constraints.biggest;
          _publicar();
          return CompositedTransformTarget(
            link: _link,
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }
}
