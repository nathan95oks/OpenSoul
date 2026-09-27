import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lsb_legal_app/app/app_theme.dart';
import 'package:lsb_legal_app/core/domain/entities/lsb_card.dart';
import 'package:lsb_legal_app/core/domain/services/pending_sign.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/di/injection.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/sign_images_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/sign_image.dart';

class SemanticNode extends ConsumerStatefulWidget {
  final LsbCard card;
  final VoidCallback onTap;
  final bool isSelected;

  /// La pregunta es obligatoria y se intentó avanzar sin elegir.
  final bool requiresSelection;

  /// Color del borde y del aviso cuando una pregunta obligatoria queda sin
  /// responder. Ámbar, no rojo: no es un error, es un campo pendiente.
  static const requiredSelectionColor = Color(0xFFF59E0B);

  /// Vista previa de la seña. Se dispara al mantener la tarjeta
  /// [holdDuration] y no cambia la selección; el relleno se vacía cuando el
  /// futuro termina. Sin ella la tarjeta solo responde al toque.
  final Future<void> Function()? onPreview;

  /// Lo que hay que mantener la tarjeta para ver su seña.
  static const holdDuration = Duration(milliseconds: 1500);

  const SemanticNode({
    super.key,
    required this.card,
    required this.onTap,
    this.isSelected = false,
    this.requiresSelection = false,
    this.onPreview,
  });

  @override
  ConsumerState<SemanticNode> createState() => _SemanticNodeState();
}

/// En qué quedó la pulsación en curso. Solo un toque corto ([_Hold.none])
/// elige o quita la tarjeta: mantenerla nunca cambia la selección, llegue o no
/// a abrir la vista previa.
enum _Hold { none, pressing, abandoned, preview }

class _SemanticNodeState extends ConsumerState<SemanticNode>
    with TickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  /// Relleno morado de la pulsación mantenida. Arranca al apoyar el dedo, no
  /// al cumplirse el plazo, y su valor es también el tiempo que se lleva.
  late final AnimationController _fill;
  _Hold _hold = _Hold.none;

  /// A partir de esta fracción del relleno, soltar ya no es un toque: es el
  /// mismo umbral con el que la plataforma separa un toque de una pulsación
  /// larga.
  static final double _tapLimit =
      kLongPressTimeout.inMilliseconds /
      SemanticNode.holdDuration.inMilliseconds;

  static const _paddingH = 12.0;
  static const _radio = 14.0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _fill = AnimationController(
      vsync: this,
      duration: SemanticNode.holdDuration,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _fill.dispose();
    super.dispose();
  }

  void _tapDown(TapDownDetails _) {
    // La pulsación mantenida marca [_hold] antes que el toque. Si al llegar
    // aquí no está en curso, es un resto del gesto anterior: el toque que
    // llega por accesibilidad no pasa por la pulsación larga.
    if (_hold != _Hold.pressing) _hold = _Hold.none;
    _ctrl.forward();
  }

  void _tapUp(TapUpDetails _) {
    _ctrl.reverse();
    if (_hold == _Hold.preview || _hold == _Hold.abandoned) return;
    widget.onTap();
  }

  void _holdDown(LongPressDownDetails _) {
    _hold = _Hold.pressing;
    _fill.forward(from: 0);
  }

  /// La pulsación no llegó a la vista previa: se soltó, se movió el dedo o el
  /// desplazamiento se quedó con el gesto.
  void _holdCancelled() {
    if (_hold != _Hold.pressing) return;
    _hold = _fill.value < _tapLimit ? _Hold.none : _Hold.abandoned;
    _drain();
  }

  Future<void> _holdCompleted(LongPressStartDetails _) async {
    final preview = widget.onPreview;
    if (preview == null || _hold == _Hold.preview) return;
    // Desde aquí el gesto es la vista previa: al soltar no hay toque.
    _hold = _Hold.preview;
    _fill.value = 1;
    await preview();
    if (mounted) _drain();
  }

  void _drain() => _fill.animateBack(
    0,
    duration: const Duration(milliseconds: 220),
    curve: Curves.easeOut,
  );

  @override
  Widget build(BuildContext context) {
    final selected = widget.isSelected;
    final colorContenido = selected ? Colors.white : AppTheme.lightText;
    // La imagen solo si existe una seña que enseñar: sin almacén de imágenes
    // la tarjeta es la glosa sola, sin un icono genérico en su lugar.
    final conImagen =
        ref.watch(signImagesEnabledProvider) &&
        ref.watch(signImageResolverProvider).isConfigured;
    final paddingV = conImagen ? 8.0 : 11.0;
    final conVistaPrevia = widget.onPreview != null;
    final gestureSettings = MediaQuery.maybeGestureSettingsOf(context);

    final tarjeta = RawGestureDetector(
      gestures: {
        TapGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
              () => TapGestureRecognizer(debugOwner: this),
              (tap) => tap
                ..onTapDown = _tapDown
                ..onTapUp = _tapUp
                ..onTapCancel = _ctrl.reverse
                ..gestureSettings = gestureSettings,
            ),
        if (conVistaPrevia)
          _HoldRecognizer:
              GestureRecognizerFactoryWithHandlers<_HoldRecognizer>(
                () => _HoldRecognizer(debugOwner: this),
                (hold) => hold
                  ..onLongPressDown = _holdDown
                  ..onLongPressCancel = _holdCancelled
                  ..onArenaLost = _holdCancelled
                  ..onLongPressStart = _holdCompleted
                  ..gestureSettings = gestureSettings,
              ),
      },
      // Con la pulsación propia, las acciones de accesibilidad se declaran a
      // mano: tocar elige como siempre y mantener abre la vista previa.
      semantics: conVistaPrevia
          ? _TapOrHoldSemantics(
              onTap: () {
                _tapDown(TapDownDetails());
                _tapUp(TapUpDetails(kind: PointerDeviceKind.unknown));
              },
              onLongPress: () {
                _holdDown(const LongPressDownDetails());
                _holdCompleted(const LongPressStartDetails());
              },
            )
          : null,
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          constraints: BoxConstraints(minHeight: conImagen ? 86 : 60),
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFF660066)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            // Plana y sin borde: la glosa es lo único que se ve.
            color: selected ? null : AppTheme.lightSurface,
            borderRadius: BorderRadius.circular(_radio),
            border: Border.all(
              color: selected
                  ? const Color(0xFFC084FC)
                  : widget.requiresSelection
                  ? SemanticNode.requiredSelectionColor
                  : Colors.transparent,
              width: selected || widget.requiresSelection ? 2 : 1.2,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : widget.requiresSelection
                ? [
                    BoxShadow(
                      color: SemanticNode.requiredSelectionColor.withValues(
                        alpha: 0.2,
                      ),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: _paddingH,
            vertical: paddingV,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (conVistaPrevia) _relleno(selected, paddingV),
              conImagen
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SignImage(
                            gloss: widget.card.gloss,
                            semanticIcon: widget.card.semanticIcon,
                            frames: widget.card.imageFrames,
                            size: 36,
                            color: colorContenido,
                          ),
                          const SizedBox(height: 8),
                          _etiqueta(colorContenido, selected),
                        ],
                      ),
                    )
                  : Center(child: _etiqueta(colorContenido, selected)),
              // La selección no depende solo del color.
              if (selected)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Color(0xFFC084FC),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 13,
                      color: Color(0xFF3B0764),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    if (!conVistaPrevia && !widget.requiresSelection) return tarjeta;
    return Semantics(
      hint: widget.requiresSelection
          ? 'Selecciona una opción obligatoria'
          : null,
      onLongPressHint: conVistaPrevia ? 'previsualizar la seña' : null,
      child: tarjeta,
    );
  }

  /// Relleno morado que sube desde abajo, como agua, mientras se mantiene la
  /// tarjeta. Va debajo de la glosa y cubre el interior del borde: el Stack
  /// vive dentro del padding, de ahí los márgenes negativos.
  Widget _relleno(bool selected, double paddingV) {
    final radio = _radio - (selected ? 2.0 : 1.2);
    // Con una palabra sin seña el agua es celeste, como la palabra: lo que se
    // verá es que esa seña está en espera para el avatar.
    final pendiente = _tienePendientes;
    final color = pendiente
        ? AppTheme.pendingSignOnDark.withValues(alpha: selected ? 0.4 : 0.6)
        : selected
        ? const Color(0xFFC084FC).withValues(alpha: 0.38)
        : const Color(0xFF7C3AED).withValues(alpha: 0.45);
    final linea = pendiente
        ? AppTheme.pendingSign.withValues(alpha: 0.8)
        : selected
        ? Colors.white.withValues(alpha: 0.75)
        : const Color(0xFFC084FC).withValues(alpha: 0.9);
    return Positioned(
      left: -_paddingH,
      right: -_paddingH,
      top: -paddingV,
      bottom: -paddingV,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _fill,
          builder: (context, _) {
            final progreso = _fill.value;
            if (progreso == 0) return const SizedBox.shrink();
            return RepaintBoundary(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(radio),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: FractionallySizedBox(
                    key: const Key('relleno_vista_previa'),
                    widthFactor: 1,
                    heightFactor: progreso,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: color,
                        border: Border(top: BorderSide(color: linea, width: 2)),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  bool get _tienePendientes =>
      widget.card.displayText.contains(PendingSign.prefix);

  /// La secuencia de la tarjeta. Una palabra sin seña en el catálogo va en
  /// azul claro y en español, no con su marca.
  Widget _etiqueta(Color color, bool selected) {
    final style = TextStyle(
      fontSize: 18,
      fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
      color: color,
      letterSpacing: 0.5,
      height: 1.2,
    );
    if (!_tienePendientes) {
      return Text(
        widget.card.displayText.replaceAll('_', ' '),
        textAlign: TextAlign.center,
        softWrap: true,
        style: style,
      );
    }
    final azul = selected ? AppTheme.pendingSignOnDark : AppTheme.pendingSign;
    final piezas = widget.card.displayText.split(' · ');
    return Text.rich(
      TextSpan(
        children: [
          for (final (i, p) in piezas.indexed) ...[
            if (i > 0) const TextSpan(text: ' · '),
            PendingSign.isPending(p)
                ? TextSpan(
                    text: PendingSign.wordOf(p),
                    style: TextStyle(color: azul),
                  )
                : TextSpan(text: p.replaceAll('_', ' ')),
          ],
        ],
      ),
      textAlign: TextAlign.center,
      softWrap: true,
      style: style,
    );
  }
}

/// Pulsación larga que también avisa cuando pierde la arena ante otro gesto.
///
/// [LongPressGestureRecognizer] solo llama a `onLongPressCancel` cuando se
/// rechaza a sí misma: soltar antes de tiempo o mover el dedo, que es lo que
/// pasa al desplazar la lista. Si otro gesto se queda la arena sin que ella se
/// retire (uno que acepta al instante, o con un margen menor), se va en
/// silencio y el relleno seguiría subiendo sin abrir nada.
class _HoldRecognizer extends LongPressGestureRecognizer {
  _HoldRecognizer({super.debugOwner})
    : super(duration: SemanticNode.holdDuration);

  VoidCallback? onArenaLost;

  @override
  void rejectGesture(int pointer) {
    final pendiente =
        pointer == primaryPointer && state == GestureRecognizerState.possible;
    super.rejectGesture(pointer);
    if (pendiente) onArenaLost?.call();
  }
}

/// Acciones de accesibilidad de una tarjeta con vista previa.
class _TapOrHoldSemantics extends SemanticsGestureDelegate {
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _TapOrHoldSemantics({required this.onTap, required this.onLongPress});

  @override
  void assignSemantics(RenderSemanticsGestureHandler renderObject) {
    renderObject
      ..onTap = onTap
      ..onLongPress = onLongPress;
  }
}

class AnswerNode extends StatelessWidget {
  final String gloss;
  final VoidCallback? onTap;

  const AnswerNode({super.key, required this.gloss, this.onTap});

  static const _orange = AppTheme.brandPrimary;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: _orange,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _orange, width: 2),
        ),
        child: Text(
          gloss.replaceAll('_', ' ').toUpperCase(),
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

class QuestionNode extends StatelessWidget {
  final String question;
  final bool dimmed;

  const QuestionNode({super.key, required this.question, this.dimmed = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.lightSubtle.withValues(alpha: dimmed ? 0.5 : 1.0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.lightBorder, width: 1.5),
      ),
      child: Text(
        question,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppTheme.lightText.withValues(alpha: dimmed ? 0.4 : 0.75),
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}
