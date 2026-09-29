import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lsb_legal_app/app/app_theme.dart';
import 'package:lsb_legal_app/core/domain/entities/lsb_card.dart';
import 'package:lsb_legal_app/core/domain/services/pending_sign.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/di/injection.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/sign_images_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/sign_image.dart';

/// Las respuestas de la pregunta activa, una debajo de otra.
///
/// Filas compactas sobre blanco con separadores finos: la lista entera cabe
/// de un vistazo y se recorre desplazando, sin bloques grandes.
class GlossRowList extends StatelessWidget {
  final List<LsbCard> cards;

  /// Selección por identificador de opción: dos opciones pueden compartir
  /// glosa («Cuándo vuelvo» y «Cuándo me avisan» empiezan por CUÁNDO).
  final Set<String> selectedIds;

  /// Resalta las opciones como un campo obligatorio pendiente.
  final bool requiresSelection;

  /// Elegir o quitar la opción (tocar la fila). Devuelve si quedó elegida.
  final Future<bool> Function(LsbCard card) onToggle;

  /// Ver la seña en el avatar 3D (deslizar la fila o su flecha). No elige.
  final void Function(LsbCard card)? onPreview;

  /// Opciones cuya seña el avatar todavía no sabe hacer.
  final Set<String> unavailableAnimationIds;

  /// Opciones sugeridas (mencionadas por el oyente o propuestas por un
  /// clasificador) con el texto que lo explica. No están elegidas.
  final Map<String, String> suggestionLabels;

  const GlossRowList({
    super.key,
    required this.cards,
    required this.onToggle,
    this.onPreview,
    this.selectedIds = const {},
    this.requiresSelection = false,
    this.unavailableAnimationIds = const {},
    this.suggestionLabels = const {},
  });

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) return const SizedBox.shrink();
    final preview = onPreview;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppTheme.pageBg,
        border: Border.symmetric(
          horizontal: BorderSide(color: AppTheme.lightBorder),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, card) in cards.indexed) ...[
            if (i > 0)
              const Divider(
                height: 1,
                thickness: 1,
                indent: 16,
                color: AppTheme.lightBorder,
              ),
            GlossRow(
              key: ValueKey(card.id),
              card: card,
              isSelected: selectedIds.contains(card.id),
              requiresSelection: requiresSelection,
              animationUnavailable: unavailableAnimationIds.contains(card.id),
              suggestionLabel: suggestionLabels[card.id],
              onToggle: () => onToggle(card),
              onPreview: preview == null ? null : () => preview(card),
            ),
          ],
        ],
      ),
    );
  }
}

/// Una respuesta como fila horizontal: recurso visual, glosa y flecha.
///
/// Tres gestos que no se confunden:
///   * **tocar** la fila la elige; tocarla otra vez, ya elegida, la quita;
///   * **deslizarla a la derecha** más allá de [previewThreshold] y soltar
///     muestra al avatar 3D haciendo la seña; soltar antes la devuelve a su
///     sitio sin abrir nada. Deslizar nunca elige ni quita;
///   * la **flecha** abre también el avatar, sin deslizar (lector de
///     pantalla, teclado, o quien no pueda arrastrar).
///
/// Desplazar la lista en vertical no hace ninguna de las tres: el
/// desplazamiento se queda el gesto y el toque y el arrastre se retiran.
class GlossRow extends ConsumerStatefulWidget {
  final LsbCard card;
  final bool isSelected;

  /// La pregunta es obligatoria y se intentó avanzar sin elegir.
  final bool requiresSelection;

  /// El avatar no tiene animación para esta seña: abrirlo avisa en vez de
  /// mostrar el visor, y la fila lo dice antes.
  final bool animationUnavailable;

  /// Por qué se sugiere esta fila («Mencionado por el oyente»), o `null`.
  /// Una sugerencia no es una selección: se confirma tocándola.
  final String? suggestionLabel;

  /// Elegir o quitar. Devuelve si la opción quedó elegida (un editor
  /// cancelado o una regla del banco pueden impedirlo).
  final Future<bool> Function() onToggle;

  /// Ver la seña en el avatar 3D. Sin él, deslizar no hace nada.
  final VoidCallback? onPreview;

  /// Fracción del ancho que hay que deslizar para abrir el avatar.
  static const previewThreshold = 0.35;

  /// Cuánto dura el destello tras elegir.
  static const confirmDuration = Duration(milliseconds: 900);

  /// Color de una pregunta obligatoria sin responder. Ámbar, no rojo: no es
  /// un error, es un campo pendiente.
  static const requiredSelectionColor = Color(0xFFF59E0B);

  const GlossRow({
    super.key,
    required this.card,
    required this.onToggle,
    this.onPreview,
    this.isSelected = false,
    this.requiresSelection = false,
    this.animationUnavailable = false,
    this.suggestionLabel,
  });

  @override
  ConsumerState<GlossRow> createState() => _GlossRowState();
}

class _GlossRowState extends ConsumerState<GlossRow>
    with TickerProviderStateMixin {
  /// Cuánto se deslizó la fila, como fracción de su ancho.
  late final AnimationController _slide;

  /// Destello tras elegir: sube y se apaga solo.
  late final AnimationController _confirm;

  double _width = 1;

  /// El arrastre en curso ya pasó el umbral: soltar abre el avatar.
  bool _armed = false;

  /// Una elección en curso (p. ej. su editor abierto): otro toque no la
  /// cambia otra vez.
  bool _busy = false;

  /// Lo más que se deja arrastrar la fila, para que no salga de la pantalla.
  static const _maxSlide = 0.6;

  @override
  void initState() {
    super.initState();
    _slide = AnimationController(vsync: this);
    _confirm = AnimationController(
      vsync: this,
      duration: GlossRow.confirmDuration,
    );
  }

  @override
  void dispose() {
    _slide.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _dragStart(DragStartDetails _) {
    _width = context.size?.width ?? 1;
    if (_width <= 0) _width = 1;
    _slide.stop();
    _armed = false;
  }

  void _dragUpdate(DragUpdateDetails details) {
    final next = (_slide.value + details.primaryDelta! / _width).clamp(
      0.0,
      _maxSlide,
    );
    _slide.value = next;
    final armed = next >= GlossRow.previewThreshold;
    if (armed != _armed) {
      setState(() => _armed = armed);
      if (armed) HapticFeedback.selectionClick();
    }
  }

  void _dragEnd(DragEndDetails _) {
    final abrir = _armed;
    _release();
    if (abrir) widget.onPreview?.call();
  }

  void _dragCancel() => _release();

  /// La fila vuelve a su sitio, se abra o no el avatar.
  void _release() {
    if (_armed && mounted) setState(() => _armed = false);
    _armed = false;
    _slide.animateTo(
      0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _toggle() async {
    if (_busy) return;
    _busy = true;
    try {
      final chosen = await widget.onToggle();
      if (!mounted || !chosen) return;
      HapticFeedback.lightImpact();
      _confirm.forward(from: 0);
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final gestureSettings = MediaQuery.maybeGestureSettingsOf(context);
    final preview = widget.onPreview;
    final label = _legible(widget.card.displayText);

    final fila = RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: {
        TapGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
              () => TapGestureRecognizer(debugOwner: this),
              (tap) => tap
                ..onTap = _toggle
                ..gestureSettings = gestureSettings,
            ),
        if (preview != null)
          HorizontalDragGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<
                HorizontalDragGestureRecognizer
              >(
                () => HorizontalDragGestureRecognizer(debugOwner: this),
                (drag) => drag
                  ..onStart = _dragStart
                  ..onUpdate = _dragUpdate
                  ..onEnd = _dragEnd
                  ..onCancel = _dragCancel
                  ..gestureSettings = gestureSettings,
              ),
      },
      // Solo el toque llega al lector de pantalla como acción de la fila;
      // deslizar se ofrece como la acción «Ver en avatar 3D» y con la flecha.
      semantics: _TapOnlySemantics(_toggle),
      child: Stack(
        children: [
          Positioned.fill(child: _pista()),
          AnimatedBuilder(
            animation: _slide,
            builder: (context, child) => FractionalTranslation(
              translation: Offset(_slide.value, 0),
              child: child,
            ),
            child: _contenido(label),
          ),
        ],
      ),
    );

    return Semantics(
      container: true,
      selected: widget.isSelected,
      label: [
        label,
        if (widget.isSelected) 'elegida',
        if (widget.suggestionLabel != null) widget.suggestionLabel!,
        if (widget.animationUnavailable) 'sin animación en el avatar',
      ].join(', '),
      hint: widget.requiresSelection
          ? 'Selecciona una opción obligatoria'
          : null,
      onTapHint: widget.isSelected ? 'quitar' : 'elegir',
      customSemanticsActions: {
        const CustomSemanticsAction(label: 'Ver en avatar 3D'): ?preview,
      },
      child: fila,
    );
  }

  /// Lo que se descubre detrás de la fila al deslizarla: el avance hacia
  /// abrir el avatar. Solo ocupa lo que la fila deja al descubierto.
  Widget _pista() {
    return AnimatedBuilder(
      animation: _slide,
      builder: (context, _) {
        final progreso = (_slide.value / GlossRow.previewThreshold).clamp(
          0.0,
          1.0,
        );
        if (_slide.value == 0) return const SizedBox.shrink();
        return ColoredBox(
          key: const Key('pista_avatar'),
          color: _armed
              ? AppTheme.lsbViolet
              : AppTheme.lsbViolet.withValues(alpha: 0.12 + 0.28 * progreso),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 18),
              child: Opacity(
                opacity: 0.4 + 0.6 * progreso,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.view_in_ar_rounded,
                      size: 24,
                      color: _armed ? Colors.white : AppTheme.lsbVioletDeep,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _armed ? 'Suelta para ver el avatar' : 'Avatar 3D',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: _armed ? Colors.white : AppTheme.lsbVioletDeep,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _contenido(String label) {
    final conImagen =
        ref.watch(signImagesEnabledProvider) &&
        ref.watch(signImageResolverProvider).isConfigured;
    final selected = widget.isSelected;
    final marca = widget.requiresSelection
        ? GlossRow.requiredSelectionColor
        : selected
        ? AppTheme.lsbViolet
        : Colors.transparent;

    return AnimatedBuilder(
      animation: _confirm,
      builder: (context, child) {
        // Sube rápido y se apaga despacio: una respuesta breve, no un
        // estado. La fila elegida sigue blanca.
        final t = _confirm.value;
        final destello = t == 0 || t == 1
            ? 0.0
            : (t < 0.2 ? t / 0.2 : 1 - (t - 0.2) / 0.8);
        return ColoredBox(
          color: Color.lerp(AppTheme.pageBg, AppTheme.glossCardBg, destello)!,
          child: child,
        );
      },
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: conImagen ? 64 : 56),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // La selección y lo obligatorio no dependen solo del color:
              // la marca acompaña al icono de elegida y al aviso.
              Container(key: const Key('marca_fila'), width: 4, color: marca),
              const SizedBox(width: 12),
              if (conImagen) ...[
                Center(
                  child: SignImage(
                    gloss: widget.card.gloss,
                    semanticIcon: widget.card.semanticIcon,
                    frames: widget.card.imageFrames,
                    size: 40,
                    color: AppTheme.lightText,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ExcludeSemantics(child: _etiqueta(selected)),
                      if (widget.suggestionLabel != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: ExcludeSemantics(
                            child: Text(
                              widget.suggestionLabel!,
                              key: const Key('fila_sugerida'),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.lsbViolet,
                              ),
                            ),
                          ),
                        ),
                      if (widget.animationUnavailable)
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: ExcludeSemantics(
                            child: Text(
                              'Sin animación en el avatar',
                              key: Key('sin_animacion'),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.lightTextSub,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (selected)
                const Center(
                  child: Icon(
                    Icons.check_circle_rounded,
                    key: Key('fila_elegida'),
                    size: 24,
                    color: AppTheme.lsbViolet,
                  ),
                ),
              if (widget.onPreview != null) _flecha(),
              if (widget.onPreview == null) const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }

  /// La flecha abre el avatar sin deslizar. Un círculo violeta con la flecha
  /// en blanco: se distingue del texto y apunta hacia donde se desliza.
  Widget _flecha() {
    return Center(
      child: IconButton(
        key: ValueKey('avatar_${widget.card.id}'),
        tooltip: 'Ver en avatar 3D',
        onPressed: widget.onPreview,
        icon: Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(
            color: AppTheme.lsbViolet,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.arrow_forward_rounded,
            key: Key('flecha_avatar'),
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }

  /// La secuencia de la opción. Una palabra sin seña en el catálogo va en
  /// azul y en español, no con su marca.
  Widget _etiqueta(bool selected) {
    final style = TextStyle(
      fontSize: 17,
      fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
      color: AppTheme.lightText,
      letterSpacing: 0.3,
      height: 1.25,
    );
    final texto = widget.card.displayText;
    if (!texto.contains(PendingSign.prefix)) {
      return Text(texto.replaceAll('_', ' '), softWrap: true, style: style);
    }
    final piezas = texto.split(' · ');
    return Text.rich(
      TextSpan(
        children: [
          for (final (i, p) in piezas.indexed) ...[
            if (i > 0) const TextSpan(text: ' · '),
            PendingSign.isPending(p)
                ? TextSpan(
                    text: PendingSign.wordOf(p),
                    style: const TextStyle(color: AppTheme.pendingSign),
                  )
                : TextSpan(text: p.replaceAll('_', ' ')),
          ],
        ],
      ),
      softWrap: true,
      style: style,
    );
  }
}

/// Las dos indicaciones de cómo usar las filas, con una animación breve:
/// una mano que presiona («Presiona para seleccionar») y una que desliza
/// («Desliza para avatar 3D»).
///
/// La animación se repite unas pocas veces al aparecer y se queda quieta:
/// enseña el gesto sin distraer mientras se responde. Con las animaciones
/// del sistema desactivadas se muestra quieta desde el principio.
class GlossGestureHints extends StatefulWidget {
  /// Veces que se repite la animación al aparecer.
  static const cycles = 3;

  static const cycleDuration = Duration(milliseconds: 1600);

  const GlossGestureHints({super.key});

  @override
  State<GlossGestureHints> createState() => _GlossGestureHintsState();
}

class _GlossGestureHintsState extends State<GlossGestureHints>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: GlossGestureHints.cycleDuration,
  )..addStatusListener(_repetir);

  int _vueltas = 0;
  bool _arrancada = false;

  void _repetir(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _vueltas++;
    if (_vueltas < GlossGestureHints.cycles) _ctrl.forward(from: 0);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_arrancada) return;
    _arrancada = true;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return;
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const Key('indicaciones_filas'),
      children: [
        Expanded(
          child: _Indicacion(
            key: const Key('pista_presionar'),
            texto: 'Presiona para seleccionar',
            icono: AnimatedBuilder(
              animation: _ctrl,
              builder: (context, child) {
                // Baja y sube como un dedo que presiona, con una onda.
                final t = _ctrl.value;
                final presion = t < 0.25
                    ? t / 0.25
                    : t < 0.5
                    ? 1 - (t - 0.25) / 0.25
                    : 0.0;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 26 * (0.6 + 0.6 * presion),
                      height: 26 * (0.6 + 0.6 * presion),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.lsbViolet.withValues(
                          alpha: 0.18 * presion,
                        ),
                      ),
                    ),
                    Transform.scale(scale: 1 - 0.15 * presion, child: child),
                  ],
                );
              },
              child: const Icon(
                Icons.touch_app_rounded,
                size: 22,
                color: AppTheme.lsbViolet,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Indicacion(
            key: const Key('pista_deslizar'),
            texto: 'Desliza para avatar 3D',
            icono: AnimatedBuilder(
              animation: _ctrl,
              builder: (context, child) {
                // Se desplaza a la derecha y vuelve, como la fila.
                final t = _ctrl.value;
                final dx = t < 0.6 ? t / 0.6 : 1 - (t - 0.6) / 0.4;
                return Transform.translate(
                  offset: Offset(-4 + 10 * Curves.easeInOut.transform(dx), 0),
                  child: child,
                );
              },
              child: const Icon(
                Icons.swipe_right_rounded,
                size: 22,
                color: AppTheme.lsbViolet,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Indicacion extends StatelessWidget {
  final String texto;
  final Widget icono;

  const _Indicacion({super.key, required this.texto, required this.icono});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: texto,
      excludeSemantics: true,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: AppTheme.glossCardBg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            SizedBox(width: 30, child: Center(child: icono)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                texto,
                maxLines: 2,
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.lightText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Texto legible de una opción: sin guiones bajos ni marcas de seña
/// pendiente.
String _legible(String texto) => texto
    .split(' · ')
    .map(
      (p) => PendingSign.isPending(p)
          ? PendingSign.wordOf(p)
          : p.replaceAll('_', ' '),
    )
    .join(' · ');

/// Acciones de accesibilidad de la fila: solo tocar (elegir o quitar). Sin
/// esto, el arrastre horizontal se anunciaría como «desplazar».
class _TapOnlySemantics extends SemanticsGestureDelegate {
  final VoidCallback onTap;

  const _TapOnlySemantics(this.onTap);

  @override
  void assignSemantics(RenderSemanticsGestureHandler renderObject) {
    renderObject.onTap = onTap;
  }
}
