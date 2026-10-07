import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lsb_legal_app/core/di/injection.dart';
import 'package:lsb_legal_app/app/app_theme.dart';
import 'package:lsb_legal_app/core/domain/entities/avatar_facial_expression.dart';
import 'package:lsb_legal_app/core/domain/services/animation_url_resolver.dart';
import 'package:lsb_legal_app/core/domain/services/pending_sign.dart';
import 'package:lsb_legal_app/core/domain/services/pending_sign_info.dart';
import 'package:lsb_legal_app/core/domain/services/spelling_help.dart';
import 'package:lsb_legal_app/core/presentation/widgets/pending_sign_info_sheet.dart';
import 'package:lsb_legal_app/core/presentation/widgets/avatar_expression_indicator.dart';

class Avatar3DViewer extends ConsumerStatefulWidget {
  final bool isProcessing;
  final List<String>? glosses;
  final List<String>? animationUrls;
  final Duration animationDuration;
  final bool expandToFit;
  final ValueChanged<bool>? onPlaybackStateChanged;
  final VoidCallback? onReturnToInput;
  final int playbackRequestId;
  final bool isUserComposing;

  /// Muestra las flechas de volver a escribir y de repetir la seña. La hoja
  /// del avatar de Conversación las oculta: allí la seña se cierra sola al
  /// terminar o deslizando la hoja. Voz a LSB y la vista previa las usan.
  final bool showControls;

  /// Muestra la flecha de volver a escribir. Voz a LSB la quita (al terminar
  /// la seña el campo de texto ya vuelve) y lleva el botón de repetir debajo
  /// de la glosa de la esquina superior derecha.
  final bool showBackButton;

  /// Cuando es `false` el visor detiene la reproduccion y libera el WebView.
  /// Lo usan las superficies que quedan vivas en segundo plano (IndexedStack)
  /// para que el avatar no siga senando al cambiar de modulo.
  final bool isActive;

  /// Una palabra sin seña con descripción (`SENA_PENDIENTE:…`) se explica:
  /// un bloque con su descripción se desliza delante del avatar el tiempo de
  /// leerla y, al terminar, se va y el avatar sigue. Lo usa el Traductor a
  /// LSB; las demás vistas siguen con el aviso «En espera para su avatar».
  final bool describePendingSigns;

  /// Qué es cada paso `SENA_PENDIENTE:…` que no está en las descripciones
  /// de la app: una seña que existe en LSB pero el avatar no tiene animada
  /// («realizar» → HACER). Se mira antes que el catálogo.
  final Map<String, PendingSignInfo> stepDescriptions;

  /// Las palabras que se deletrean en [glosses], con su sinónimo o su
  /// descripción: mientras el avatar deletrea una, abajo aparece qué es y un
  /// botón «Siguiente» para saltar el resto del deletreo. Lo usa Voz a LSB.
  final List<SpellingHelp> spellingHelp;

  const Avatar3DViewer({
    super.key,
    required this.isProcessing,
    this.glosses,
    this.animationUrls,
    this.animationDuration = const Duration(milliseconds: 2500),
    this.isActive = true,
    this.expandToFit = false,
    this.onPlaybackStateChanged,
    this.onReturnToInput,
    this.playbackRequestId = 0,
    this.isUserComposing = false,
    this.showControls = true,
    this.showBackButton = true,
    this.describePendingSigns = false,
    this.stepDescriptions = const {},
    this.spellingHelp = const [],
  });

  @override
  ConsumerState<Avatar3DViewer> createState() => _Avatar3DViewerState();

  /// Lo que se deja una descripción delante del avatar: lo que tarda en
  /// leerse, entre 5 y 15 segundos.
  static Duration readingTimeFor(PendingSignInfo info) {
    final palabras = info.lsbDescription.isNotEmpty
        ? info.lsbDescription.length
        : info.description.split(RegExp(r'\s+')).length;
    final ms = 3000 + 700 * palabras;
    return Duration(milliseconds: ms.clamp(5000, 15000));
  }
}

/// Margen sobre la duracion de una sena antes de dar el paso por perdido.
/// Cubre el caso de una glosa que no existe dentro del .glb: el visor no
/// emite 'finished' y sin este reloj la secuencia no avanzaria nunca.
///
/// La sena mas larga del modelo dura 4,92 s (PERMISO), asi que 6 s dejaban
/// solo un segundo de margen y en un equipo cargado habrian cortado senas
/// buenas. El reloj es una red de seguridad, no un temporizador: conviene que
/// tarde de mas antes que quitarle tiempo a una sena que se esta viendo bien.
const _stepWatchdog = Duration(seconds: 6);

/// Lo que una sena espera a que el modelo termine de cargar antes de darse
/// por perdida. Mientras el modelo no esta, el reloj de [_stepWatchdog] no
/// corre: se cortaba la primera sena en un telefono que tarda en cargar el
/// .glb y la persona veia el visor sin ninguna animacion. En cuanto carga, la
/// sena se reproduce con su reloj normal.
const _loadWatchdog = Duration(seconds: 25);

/// Pixeles por punto con que se dibuja el avatar. Un telefono de densidad
/// alta (2,75 en un Redmi Note 8) hacia que el visor dibujara casi el triple
/// de pixeles de los que se notan en un recuadro pequeno, en cada fotograma.
/// Con 1,5 se dibuja ~70 % menos y el avatar sigue viendose nitido.
const _maxRenderPixelRatio = 1.5;

/// Suelo por debajo del cual un aviso de fin no es creible. Protege del caso
/// en que el visor arranca una sena ya terminada y avisa en el acto.
const _minStepDuration = Duration(milliseconds: 300);
const _neutralAnimations = ['NEUTRO1', 'NEUTRO2', 'NEUTRO3'];

class _Avatar3DViewerState extends ConsumerState<Avatar3DViewer>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  bool _isPlayingSequence = false;

  List<String>? _testUrls;
  List<String>? _testGlosses;
  List<String> _localUrls = [];

  /// Identifica el paso que se esta reproduciendo. El visor lo devuelve en
  /// cada aviso de fin y los avisos de un paso anterior se descartan.
  int _playToken = 0;

  /// Cuando arranco el paso en curso. Un 'finished' que llega antes de
  /// [_minStepDuration] no puede venir de una sena reproducida de verdad.
  DateTime? _stepStartedAt;

  /// El paso en curso ya se dio por cerrado. El visor puede avisar de que
  /// termino mas de una vez —el evento 'loop' se reenvia como 'finished'— y
  /// ademas esta el reloj de seguridad, asi que cerrar el paso es idempotente.
  bool _stepSettled = false;

  /// Identifica la secuencia en curso. Si se pide otra, o se corta, mientras
  /// se preparan las señas de la anterior, esa preparación se descarta en vez
  /// de pisar el estado de la nueva.
  int _sequenceId = 0;
  bool _reportedPlaying = false;
  bool _modelLoaded = false;
  bool _returnRequested = false;

  AnimationController? _pulseController;

  dynamic _controllerA;

  /// Fuente del unico modelo 3D, resuelta una vez. Todas las senas estan
  /// horneadas dentro, asi que el visor no cambia de `src` en toda la sesion:
  /// es lo que evita recargar y reparsear 8,5 MB en cada traduccion.
  static const _modelSource = AnimationUrlResolver.bundledModelAsset;

  /// Vence el paso en curso si el visor no avisa: un placeholder no tiene
  /// `model-viewer` que emita 'finished', y una glosa que no exista dentro
  /// del .glb tampoco lo emite. Sin esto la secuencia se queda clavada.
  Timer? _placeholderTimer;
  Timer? _neutralTimer;

  /// El último movimiento de reposo: el siguiente se elige al azar entre
  /// los demás, para que el avatar no repita el mismo gesto.
  int _lastNeutral = -1;
  final _random = math.Random();

  void _cancelPlaceholderTimer() {
    _placeholderTimer?.cancel();
    _placeholderTimer = null;
  }

  bool get _canPlayNeutral =>
      widget.isActive &&
      !widget.isProcessing &&
      !widget.isUserComposing &&
      !_isPlayingSequence &&
      // Entre el envio y el primer paso la secuencia aun se descarga
      // (`_isPlayingSequence` es false): el reposo pisaba la primera sena.
      !_reportedPlaying;

  void _cancelNeutral({bool pause = true}) {
    _neutralTimer?.cancel();
    _neutralTimer = null;
    if (!pause) return;
    final controller = _controllerA;
    if (controller == null) return;
    try {
      controller
          .runJavaScript('''
        const mv = document.querySelector('model-viewer');
        window.__lsbMode = 'idle';
        window.__lsbStep = -1;
        if (mv) mv.pause();
      ''')
          .catchError((e) {});
    } catch (_) {}
  }

  void _startNeutral() {
    _neutralTimer?.cancel();
    _neutralTimer = null;
    if (!_canPlayNeutral || !_modelLoaded) return;
    final controller = _controllerA;
    if (controller == null) return;
    // Al azar entre NEUTRO1..3, sin repetir el anterior.
    var preferred = _random.nextInt(_neutralAnimations.length);
    if (preferred == _lastNeutral) {
      preferred =
          (preferred + 1 + _random.nextInt(_neutralAnimations.length - 1)) %
          _neutralAnimations.length;
    }
    _lastNeutral = preferred;
    try {
      controller
          .runJavaScript('''
        (async () => {
          const mv = document.querySelector('model-viewer');
          if (!mv) return;
          const candidates = ${_neutralAnimations.map((e) => "'$e'").toList()};
          const available = mv.availableAnimations || [];
          const neutrals = candidates.filter((name) => available.includes(name));
          // El elegido si el modelo lo trae; si no, otro de los que tenga.
          const wanted = candidates[$preferred];
          if (neutrals.length === 0) {
            if (window.ModelViewerChannel) {
              window.ModelViewerChannel.postMessage('neutral-unavailable');
            }
            return;
          }
          const name = neutrals.includes(wanted)
            ? wanted
            : neutrals[$preferred % neutrals.length];
          window.__lsbMode = 'neutral';
          window.__lsbStep = -1;
          mv.animationName = name;
          if (mv.updateComplete) await mv.updateComplete;
          // Si arranco una sena mientras tanto, el reposo no la pisa.
          if (window.__lsbMode !== 'neutral') return;
          const duration = mv.duration;
          if (!duration || duration <= 0) return;
          mv.currentTime = 0;
          mv.play({ repetitions: 1 });
          setTimeout(() => {
            if (window.__lsbMode === 'neutral' && window.ModelViewerChannel) {
              window.ModelViewerChannel.postMessage('neutral-finished');
            }
          }, Math.round(duration * 1000) + 80);
        })();
      ''')
          .catchError((e) {});
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();

    if (widget.isActive && (widget.animationUrls?.isNotEmpty ?? false)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startSequence();
      });
    }
  }

  @override
  void didUpdateWidget(Avatar3DViewer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.isActive && !widget.isActive) {
      _stopPlayback();
      return;
    }

    if (!oldWidget.isActive && widget.isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startNeutral();
      });
    }

    if (widget.isProcessing && !oldWidget.isProcessing) {
      _cancelNeutral();
    } else if (widget.isUserComposing != oldWidget.isUserComposing) {
      if (widget.isUserComposing) {
        _cancelNeutral();
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _startNeutral();
        });
      }
    }

    if (_testUrls == null && _hasNothingToPlay && _isBusy) {
      _stopPlayback();
      return;
    }

    if (!widget.isActive) return;

    final hasNewUrls =
        widget.animationUrls != oldWidget.animationUrls &&
        widget.animationUrls != null &&
        widget.animationUrls!.isNotEmpty;
    final hasNewGlosses =
        widget.glosses != oldWidget.glosses &&
        widget.glosses != null &&
        widget.glosses!.isNotEmpty;
    final hasNewRequest =
        widget.playbackRequestId != oldWidget.playbackRequestId &&
        ((widget.animationUrls?.isNotEmpty ?? false) ||
            (widget.glosses?.isNotEmpty ?? false));

    if (hasNewRequest || hasNewUrls || hasNewGlosses) {
      _startSequence();
    }
  }

  bool get _hasNothingToPlay =>
      (widget.animationUrls?.isEmpty ?? true) &&
      (widget.glosses?.isEmpty ?? true);

  bool get _isBusy => _localUrls.isNotEmpty || _isPlayingSequence;

  /// Corta la secuencia en curso: pausa el `model-viewer`, cancela el timer de
  /// los placeholders y devuelve el visor a reposo.
  void _stopPlayback() {
    _sequenceId++;
    _returnRequested = false;
    _cancelPlaceholderTimer();
    _cancelNeutral();
    _pauseViewers();
    _resetToIdle();
  }

  void _returnToInput() {
    FocusManager.instance.primaryFocus?.unfocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');
    if (_isPlayingSequence) {
      setState(() => _returnRequested = true);
      return;
    }
    _finishReturnToInput();
  }

  void _finishReturnToInput() {
    if (!mounted) return;
    _returnRequested = false;
    _resetToIdle();
    widget.onReturnToInput?.call();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startNeutral();
    });
  }

  void _replaySequence() {
    FocusManager.instance.primaryFocus?.unfocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');
    _startSequence();
  }

  void _reportPlayback(bool playing) {
    if (_reportedPlaying == playing) return;
    _reportedPlaying = playing;
    final callback = widget.onPlaybackStateChanged;
    if (callback == null) return;
    // didUpdateWidget puede iniciar o detener una secuencia mientras el padre
    // aun se esta construyendo. Notificar al final del frame evita setState
    // durante build y descarta transiciones que ya quedaron obsoletas.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _reportedPlaying == playing) callback(playing);
    });
  }

  void _pauseViewers() {
    const pauseJs = """
      const mv = document.querySelector('model-viewer');
      if (mv) {
        window.__lsbMode = 'idle';
        window.__lsbStep = -1;
        mv.pause();
        mv.currentTime = 0;
      }
    """;

    final controller = _controllerA;
    if (controller == null) return;
    try {
      controller.runJavaScript(pauseJs).catchError((e) {});
    } catch (_) {}
  }

  void _startSequence({
    List<String>? overrideUrls,
    List<String>? overrideGlosses,
  }) {
    if (!mounted) return;
    _returnRequested = false;
    _sequenceId++;
    // Un paso nuevo: ningún aviso de «terminó» del anterior (el reposo, o la
    // última seña de la frase pasada) puede cerrarlo ni adelantar el índice
    // mientras se preparan las señas. Sin esto, un aviso atrasado se comía la
    // primera seña («quiero realizar un trámite» salía «trámite realizar»).
    _playToken++;
    _cancelPlaceholderTimer();
    _cancelNeutral();
    _reportPlayback(true);
    setState(() {
      _currentIndex = 0;
      _isPlayingSequence = false;
      _stepSettled = true;

      if (overrideUrls != null) {
        _testUrls = overrideUrls;
        _testGlosses = overrideGlosses;
      } else {
        _testUrls = null;
        _testGlosses = null;
      }
    });
    _downloadAndStartSequence();
  }

  void _resetToIdle() {
    if (!mounted) return;
    _sequenceId++;
    _cancelPlaceholderTimer();
    _reportPlayback(false);
    setState(() {
      _localUrls = [];
      _testUrls = null;
      _testGlosses = null;
      _currentIndex = 0;
      _isPlayingSequence = false;
      // Mantener cerrado el ultimo token evita que un evento `finished`
      // duplicado vuelva a entrar despues de haber regresado al modo neutral.
      _stepSettled = true;
    });
  }

  Future<void> _downloadAndStartSequence() async {
    final secuencia = _sequenceId;
    final urlsToDownload = _testUrls ?? widget.animationUrls;
    if (urlsToDownload == null || urlsToDownload.isEmpty) {
      _reportPlayback(false);
      return;
    }

    List<String> localPaths;
    try {
      localPaths = await ref
          .read(animationRepositoryProvider)
          .playableSources(urlsToDownload);
    } catch (_) {
      if (secuencia == _sequenceId) _reportPlayback(false);
      return;
    }

    // Se pidió otra secuencia (o se cortó) mientras se preparaba esta.
    if (secuencia != _sequenceId) return;

    if (mounted) {
      setState(() {
        _localUrls = localPaths;
        _currentIndex = 0;
        _isPlayingSequence = true;
      });

      if (_localUrls.isNotEmpty) _playCurrentStep();
    }
  }

  void _handleJsMessage(String viewerId, String message) {
    if (!widget.isActive) return;

    if (!kReleaseMode) {
      debugPrint('[avatar] paso=$_currentIndex token=$_playToken msg=$message');
    }

    if (message == 'loaded') {
      _handleLoaded(viewerId);
      return;
    }

    if (message == 'neutral-finished') {
      _neutralTimer = Timer(const Duration(milliseconds: 350), _startNeutral);
      return;
    }
    if (message == 'neutral-unavailable') return;

    if (message.startsWith('diag:')) return;

    if (!message.startsWith('finished')) return;

    // El aviso viene sellado con el paso que lo produjo: 'finished:3'. Sin
    // sello (la reproduccion automatica del propio widget al cargar) o con
    // uno viejo, no cierra nada — de eso se encarga el paso en curso.
    final sello = message.split(':');
    final token = sello.length > 1 ? int.tryParse(sello[1]) : null;
    if (token != _playToken) return;

    // Una sena que 'termina' nada mas empezar no se ha reproducido: se ignora
    // y el reloj de seguridad decide.
    final inicio = _stepStartedAt;
    if (inicio != null &&
        DateTime.now().difference(inicio) < _minStepDuration) {
      if (!kReleaseMode) debugPrint('[avatar] fin instantaneo ignorado');
      return;
    }

    _handleFinished(viewerId);
  }

  void _handleLoaded(String viewerId) {
    if (!mounted) return;
    // Con setState: se quita el aviso de «Cargando avatar…».
    setState(() => _modelLoaded = true);
    // El WebView acaba de existir. Si el paso en curso quedo sin reproducir
    // por no haber controller todavia, este es el momento de lanzarlo. Con
    // la secuencia todavía preparándose no hay paso que lanzar.
    if (_isPlayingSequence) _playCurrentStep();
    if (_localUrls.isEmpty) _startNeutral();
  }

  void _handleFinished(String viewerId) => _finishCurrentStep();

  /// El paso sin clip se cierra solo: una descripción, cuando la persona
  /// termina de leerla; lo demás, en [Avatar3DViewer.animationDuration].
  void _armPlaceholderTimer(String gloss) {
    final descrita = _describedInfo(gloss);
    _placeholderTimer = Timer(
      descrita == null
          ? widget.animationDuration
          : Avatar3DViewer.readingTimeFor(descrita),
      _finishCurrentStep,
    );
  }

  String _rawGlossAt(int index) {
    final glosses = _testGlosses ?? widget.glosses;
    if (glosses == null || index < 0 || index >= glosses.length) return '';
    return glosses[index];
  }

  /// La descripción que se muestra delante del avatar para [gloss], o `null`
  /// si no es una palabra sin seña con descripción (o esta vista no las
  /// explica).
  PendingSignInfo? _describedInfo(String gloss) {
    if (!widget.describePendingSigns || !PendingSign.isPending(gloss)) {
      return null;
    }
    final propia = widget.stepDescriptions[gloss];
    if (propia != null) return propia;
    final catalog = ref.read(pendingSignCatalogProvider).asData?.value;
    final info = catalog?.infoOf(gloss);
    if (info == null || info.description.isEmpty) return null;
    return info;
  }

  String? _glossAt(int index) {
    final glosses = _testGlosses ?? widget.glosses;
    if (glosses == null || index < 0 || index >= glosses.length) return null;
    // La glosa y el nombre de la animacion no siempre coinciden: la ene se
    // llama 'ENE' dentro del .glb.
    return AnimationUrlResolver.animationNameFor(glosses[index]);
  }

  /// Reproduce el paso [_currentIndex] de la secuencia.
  ///
  /// Que un paso sea placeholder o animacion se decide por *su* URL. Antes se
  /// decidia por una `_urlA` que solo se asignaba al empezar, asi que una
  /// frase cuya primera palabra no tiene sena dejaba a toda la secuencia en la
  /// rama del placeholder: el avatar se quedaba en la sena con la que arranco
  /// —repitiendola— mientras el indice avanzaba por debajo.
  void _playCurrentStep() {
    if (!mounted || _currentIndex >= _localUrls.length) return;

    _cancelPlaceholderTimer();
    _cancelNeutral();
    _stepSettled = false;
    _playToken++;

    final url = _localUrls[_currentIndex];

    if (!kReleaseMode) {
      final tipo = url.startsWith(AnimationUrlResolver.placeholderScheme)
          ? 'placeholder'
          : 'modelo';
      debugPrint(
        '[avatar] PLAY paso=$_currentIndex token=$_playToken '
        'tipo=$tipo gloss=${_glossAt(_currentIndex)} '
        'controller=${_controllerA == null ? "NULL" : "ok"}',
      );
    }

    if (url.startsWith(AnimationUrlResolver.placeholderScheme)) {
      _stepStartedAt = DateTime.now();
      final gloss = _rawGlossAt(_currentIndex);
      if (widget.describePendingSigns &&
          PendingSign.isPending(gloss) &&
          !widget.stepDescriptions.containsKey(gloss) &&
          !ref.read(pendingSignCatalogProvider).hasValue) {
        // Las descripciones todavía se están leyendo del paquete de la app:
        // el paso las espera, en vez de pasar de largo sin explicarla.
        final token = _playToken;
        _placeholderTimer = Timer(_loadWatchdog, _finishCurrentStep);
        void seguir(Object? _) {
          if (!mounted || token != _playToken || _stepSettled) return;
          _cancelPlaceholderTimer();
          setState(() {});
          _armPlaceholderTimer(gloss);
        }

        ref
            .read(pendingSignCatalogProvider.future)
            .then(seguir, onError: seguir);
        return;
      }
      _armPlaceholderTimer(gloss);
      return;
    }

    // El reloj se arma siempre, tambien cuando no hay controller: el WebView
    // puede tardar en existir o no cargar, y la secuencia no puede depender
    // de que 'finished' llegue. Sin modelo todavia, la sena espera a que
    // cargue (con un limite mas largo) en vez de darse por perdida: al
    // cargar, [_handleLoaded] vuelve a llamar aqui y arma el reloj normal.
    final controller = _controllerA;
    if (controller == null || !_modelLoaded) {
      _placeholderTimer = Timer(_loadWatchdog, _finishCurrentStep);
      return;
    }
    _placeholderTimer = Timer(_stepWatchdog, _finishCurrentStep);

    // El paquete construye el HTML una sola vez y no reacciona a cambios de
    // props, asi que cambiar `animationName` en el widget no llega al visor
    // vivo: la sena solo se puede cambiar por JavaScript.
    final gloss = _glossAt(_currentIndex);
    final seleccion = gloss != null ? "mv.animationName = '$gloss';" : '';
    final token = _playToken;
    _stepStartedAt = DateTime.now();
    try {
      // `animationName` es una propiedad reactiva de lit: asignarla encola un
      // `updated()` que vuelve a llamar a changeAnimation() SIN opciones, es
      // decir con repeticiones infinitas. Si play({repetitions:1}) se llama
      // antes de que ese ciclo se vacie, el infinito lo pisa y un bucle
      // infinito no emite 'finished' nunca: la secuencia se quedaba esperando
      // un aviso que no llegaba y solo avanzaba por el reloj de seguridad.
      // Esperar a `updateComplete` deja que el cambio se aplique y solo
      // entonces se fija la reproduccion unica.
      //
      // Tampoco se llama a pause(): playAnimation hace
      // `if (element.paused) mixer.stopAllAction()`, que congela el avatar.
      controller
          .runJavaScript('''
        (async () => {
          const mv = document.querySelector('model-viewer');
          if (!mv) return;
          window.__lsbMode = 'sign';
          window.__lsbStep = $token;
          $seleccion
          if (mv.updateComplete) { await mv.updateComplete; }

          let dur = mv.duration;
          if (!dur || dur <= 0) {
            if (window.ModelViewerChannel) {
              window.ModelViewerChannel.postMessage('finished:' + $token);
            }
            return;
          }

          mv.currentTime = 0;
          mv.play({ repetitions: 1 });

          if (window.ModelViewerChannel) {
            window.ModelViewerChannel.postMessage(
              'diag:' + $token + ':' + mv.animationName + ':' + dur
            );
          }

          setTimeout(() => {
            if (window.__lsbStep === $token && window.ModelViewerChannel) {
              window.ModelViewerChannel.postMessage('finished:' + $token);
            }
          }, Math.round(dur * 1000) + 60);
        })();
      ''')
          .catchError((e) {});
    } catch (_) {}
  }

  /// Cierra el paso en curso y encadena el siguiente. Idempotente.
  void _finishCurrentStep() {
    if (!mounted || _stepSettled) return;
    _stepSettled = true;
    _cancelPlaceholderTimer();

    if (!kReleaseMode) {
      final ms = _stepStartedAt == null
          ? -1
          : DateTime.now().difference(_stepStartedAt!).inMilliseconds;
      debugPrint(
        '[avatar] FIN  paso=$_currentIndex token=$_playToken '
        'tras=${ms}ms',
      );
    }

    if (_returnRequested) {
      _finishReturnToInput();
      return;
    }

    if (_currentIndex >= _localUrls.length - 1) {
      // Una reproduccion por envio. El boton de repetir sigue disponible, pero
      // el campo de texto vuelve al terminar la frase completa.
      setState(() => _isPlayingSequence = false);
      _reportPlayback(false);
      _neutralTimer = Timer(const Duration(milliseconds: 350), _startNeutral);
      return;
    }

    setState(() => _currentIndex++);
    _playCurrentStep();
  }

  /// «Siguiente» durante un deletreo: se salta el resto de las letras y el
  /// avatar sigue con la seña de después (o termina, si era la última).
  void _skipSpelling(SpellingHelp ayuda) {
    if (!mounted || !_isPlayingSequence || !ayuda.contains(_currentIndex)) {
      return;
    }
    _cancelPlaceholderTimer();
    _stepSettled = false;
    setState(() => _currentIndex = ayuda.end);
    _finishCurrentStep();
  }

  @override
  void dispose() {
    _cancelPlaceholderTimer();
    _cancelNeutral(pause: false);
    _pauseViewers();
    _pulseController?.dispose();
    super.dispose();
  }

  Widget _buildProcessingState() {
    return const SizedBox.shrink(key: ValueKey('processing'));
  }

  /// El visor 3D, montado una sola vez y compartido por todos los estados.
  ///
  /// `autoPlay` va en falso a proposito: el avatar se queda en reposo hasta
  /// que [_playCurrentStep] le pide una sena. Con autoPlay el visor arrancaba
  /// reproduciendo por su cuenta la primera sena de la secuencia, que se veia
  /// antes de tiempo y encima emitia avisos de fin que no eran de ningun paso.
  Widget _buildPersistentViewer() {
    return ModelViewer(
      key: ValueKey('avatar_viewer_${widget.key ?? hashCode}'),
      src: _modelSource,
      alt: 'Avatar LSB',
      autoPlay: false,
      autoRotate: false,
      cameraControls: false,
      disableZoom: true,
      backgroundColor: Colors.transparent,
      cameraTarget: "0m 1.25m 0m",
      cameraOrbit: "0deg 90deg 1.7m",
      fieldOfView: "30deg",
      onWebViewCreated: (controller) {
        _controllerA = controller;
        _modelLoaded = false;
      },
      javascriptChannels: {
        JavascriptChannel(
          'ModelViewerChannel',
          onMessageReceived: (message) {
            _handleJsMessage('A', message.message);
          },
        ),
      },
      relatedJs:
          '''
        // Antes de que arranque model-viewer (su modulo se ejecuta despues de
        // este script): menos pixeles por fotograma.
        (() => {
          const tope = Math.min(window.devicePixelRatio || 1, $_maxRenderPixelRatio);
          try {
            Object.defineProperty(window, 'devicePixelRatio', {
              get: () => tope,
              configurable: true,
            });
          } catch (e) {}
        })();

        const modelViewer = document.querySelector('model-viewer');

        modelViewer.addEventListener('load', () => {
          if (window.ModelViewerChannel) {
            window.ModelViewerChannel.postMessage('loaded');
          }
        });

        const avisarFin = () => {
          if (window.__lsbMode === 'neutral') return;
          if (window.ModelViewerChannel) {
            window.ModelViewerChannel.postMessage(
              'finished:' + (window.__lsbStep === undefined ? '' : window.__lsbStep)
            );
          }
        };

        modelViewer.addEventListener('finished', avisarFin);
        modelViewer.addEventListener('loop', avisarFin);
      ''',
    );
  }

  Widget _buildDualModelViewer() {
    final activeGlosses = _testGlosses ?? widget.glosses;
    final currentGloss =
        (activeGlosses != null && _currentIndex < activeGlosses.length)
        ? activeGlosses[_currentIndex]
        : '';

    final currentUrl = _currentIndex < _localUrls.length
        ? _localUrls[_currentIndex]
        : '';
    final isPlaceholder = currentUrl.startsWith(
      AnimationUrlResolver.placeholderScheme,
    );
    final facialExpression = AvatarFacialExpressions.forGloss(currentGloss);
    if (widget.describePendingSigns) {
      // Se lee empaquetado con la app; al llegar, se redibuja.
      ref.watch(pendingSignCatalogProvider);
    }
    final descrita = isPlaceholder ? _describedInfo(currentGloss) : null;
    final ayuda = widget.spellingHelp
        .where((h) => h.contains(_currentIndex))
        .firstOrNull;

    // Solo los rotulos: el visor vive debajo, en [build], y no se desmonta al
    // cambiar de estado.
    return Stack(
      key: const ValueKey('playing'),
      children: [
        // La sena espera al modelo: se dice, en vez de un visor vacio.
        if (!isPlaceholder && !_modelLoaded)
          Positioned.fill(child: _LoadingAvatarNotice(gloss: currentGloss)),
        // Una palabra descrita no lleva aviso: la explica el bloque de abajo.
        if (isPlaceholder &&
            descrita == null &&
            PendingSign.isPending(currentGloss))
          Positioned.fill(child: _PendingSignNotice(gloss: currentGloss))
        else if (isPlaceholder && descrita == null)
          Positioned.fill(
            child: Container(
              color: const Color(0xFF1E1E2F).withValues(alpha: 0.9),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.amber, width: 2),
                      ),
                      child: const Icon(
                        Icons.text_fields_rounded,
                        color: Colors.amber,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'ANIMACION PALABRA: $currentGloss.glb',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Seña no disponible en 3D (Simulación)',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),

        if (_localUrls.length > 1)
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_localUrls.length, (i) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _currentIndex ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    color: i == _currentIndex
                        ? Colors.deepPurpleAccent
                        : Colors.white24,
                  ),
                );
              }),
            ),
          ),

        Positioned(
          top: 14,
          left: 14,
          right: 14,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.showControls && widget.showBackButton) ...[
                IconButton(
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                  ),
                  tooltip: 'Volver a escribir',
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                  onPressed: _returnToInput,
                ),
                const SizedBox(width: 18),
                IconButton(
                  icon: const Icon(Icons.replay_rounded, color: Colors.white),
                  tooltip: 'Volver a hacer la seña',
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                  onPressed: _replaySequence,
                ),
              ],
              // La expresion no manual comparte la franja informativa con la
              // glosa: queda cerca del rostro, pero fuera del area central en
              // la que se mueven las manos. En Conversacion ocupa el espacio
              // libre de la esquina; en las otras vistas respeta los controles.
              if (facialExpression != null) ...[
                if (widget.showControls && widget.showBackButton)
                  const SizedBox(width: 14),
                AvatarExpressionIndicator(expression: facialExpression),
              ],
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildGlossBadge(activeGlosses, _currentIndex),
                  // Sin flecha de volver, repetir va debajo de la glosa.
                  if (widget.showControls && !widget.showBackButton) ...[
                    const SizedBox(height: 10),
                    IconButton(
                      icon: const Icon(
                        Icons.replay_rounded,
                        color: Colors.white,
                      ),
                      tooltip: 'Volver a hacer la seña',
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                      onPressed: _replaySequence,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),

        // Una palabra sin seña (o sin animación) con descripción: una
        // pantalla con el violeta de LSB entra barriendo desde la derecha y tapa
        // todo el avatar; leída, sigue hacia la izquierda y el avatar
        // continúa. Si la palabra siguiente también se describe, la pantalla
        // se queda y solo cambia la tarjeta.
        Positioned.fill(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 420),
            reverseDuration: const Duration(milliseconds: 380),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            layoutBuilder: (actual, anteriores) =>
                Stack(fit: StackFit.expand, children: [...anteriores, ?actual]),
            transitionBuilder: _barrido,
            child: descrita != null && _isPlayingSequence
                ? _DescriptionCurtain(
                    key: const ValueKey('cortina'),
                    step: _currentIndex,
                    info: descrita,
                    readingTime: Avatar3DViewer.readingTimeFor(descrita),
                    onContinue: _finishCurrentStep,
                  )
                : const SizedBox.shrink(key: ValueKey('sin_cortina')),
          ),
        ),

        // Mientras se deletrea una palabra: abajo, su sinónimo o qué es, y
        // «Siguiente» para no esperar todas las letras.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) => SlideTransition(
              position: Tween(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
            child: ayuda != null && _isPlayingSequence
                ? _SpellingHelpPanel(
                    key: ValueKey('deletreo_${ayuda.start}'),
                    help: ayuda,
                    onNext: () => _skipSpelling(ayuda),
                  )
                : const SizedBox.shrink(key: ValueKey('sin_deletreo')),
          ),
        ),
      ],
    );
  }

  Widget _buildGlossBadge(List<String>? activeGlosses, int currentIndex) {
    if (activeGlosses == null ||
        currentIndex < 0 ||
        currentIndex >= activeGlosses.length) {
      return const SizedBox.shrink();
    }

    final currentGloss = activeGlosses[currentIndex];

    // Detectar si la glosa actual forma parte de una palabra deletreada (dactilologia)
    if (currentGloss.length == 1) {
      int start = currentIndex;
      while (start > 0 && activeGlosses[start - 1].length == 1) {
        start--;
      }
      int end = currentIndex;
      while (end < activeGlosses.length - 1 &&
          activeGlosses[end + 1].length == 1) {
        end++;
      }

      if (end > start) {
        final letters = activeGlosses.sublist(start, end + 1);
        final activeLetterIdx = currentIndex - start;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1B4B).withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.deepPurpleAccent.withValues(alpha: 0.7),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.deepPurpleAccent.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(letters.length, (idx) {
              final isCurrent = idx == activeLetterIdx;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? Colors.deepPurpleAccent
                      : Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isCurrent
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.2),
                    width: isCurrent ? 1.5 : 1,
                  ),
                  boxShadow: isCurrent
                      ? [
                          BoxShadow(
                            color: Colors.deepPurpleAccent.withValues(
                              alpha: 0.7,
                            ),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  letters[idx],
                  style: TextStyle(
                    color: isCurrent ? Colors.white : Colors.white60,
                    fontWeight: isCurrent ? FontWeight.w900 : FontWeight.w500,
                    fontSize: isCurrent ? 14 : 12,
                  ),
                ),
              );
            }),
          ),
        );
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.deepPurpleAccent.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        // Una palabra sin seña se rotula en español, sin la marca interna.
        PendingSign.isPending(currentGloss)
            ? PendingSign.wordOf(currentGloss)
            : currentGloss,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14,
          letterSpacing: 1,
        ),
      ),
    );
  }

  /// Estado que se muestra cuando el modulo quedo en segundo plano: sin
  /// `ModelViewer`, para que ningun WebView siga animando fuera de pantalla.
  Widget _buildPausedState() {
    return Column(
      key: const ValueKey('paused'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.deepPurpleAccent.withValues(alpha: 0.12),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.deepPurpleAccent.withValues(alpha: 0.35),
            ),
          ),
          child: const Icon(
            Icons.pause_rounded,
            size: 34,
            color: Colors.deepPurpleAccent,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Avatar en pausa',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  /// Reposo: solo el degradado y el rotulo. El avatar que se ve debajo es el
  /// visor permanente de [build].
  ///
  /// Antes este estado montaba su *propio* ModelViewer apuntando a la URL de
  /// S3 en vez de al archivo ya cacheado, asi que cada vuelta a reposo volvia
  /// a bajar 8,5 MB por red.
  Widget _buildIdleState() {
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    Widget bodyContent;

    if (!widget.isActive) {
      bodyContent = _buildPausedState();
    } else if (widget.isProcessing) {
      bodyContent = _buildProcessingState();
    } else if (_localUrls.isNotEmpty) {
      bodyContent = _buildDualModelViewer();
    } else {
      bodyContent = _buildIdleState();
    }

    return Container(
      width: double.infinity,
      height: widget.expandToFit ? double.infinity : 300,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.deepPurpleAccent.withValues(alpha: 0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurpleAccent.withValues(alpha: 0.1),
            blurRadius: 30,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // El visor va al fondo y no se desmonta al cambiar de estado: los
            // estados son capas por encima. Mientras el modulo esta en segundo
            // plano se suelta del todo, que es lo que evita que el WebView
            // siga vivo detras.
            if (widget.isActive)
              Positioned.fill(child: _buildPersistentViewer()),
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: bodyContent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Barrido de un solo sentido: entra desde la derecha y, al irse, sigue
/// hacia la izquierda.
Widget _barrido(Widget child, Animation<double> animation) => AnimatedBuilder(
  animation: animation,
  child: child,
  builder: (context, child) {
    final saliendo = animation.status == AnimationStatus.reverse;
    final dx = saliendo ? -(1 - animation.value) : 1 - animation.value;
    return FractionalTranslation(translation: Offset(dx, 0), child: child);
  },
);

/// Qué es una palabra sin seña (o sin animación), tapando al avatar: una
/// pantalla con el violeta de LSB y la misma tarjeta de la hoja «¿Qué es?» de
/// las tarjetas LSB. La barra muestra cuánto queda para leerla; «Entendido»
/// la cierra antes. Cada palabra trae su tarjeta, que entra con el mismo
/// barrido.
class _DescriptionCurtain extends StatelessWidget {
  final int step;
  final PendingSignInfo info;
  final Duration readingTime;
  final VoidCallback onContinue;

  const _DescriptionCurtain({
    super.key,
    required this.step,
    required this.info,
    required this.readingTime,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const Key('avatar_descripcion'),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.describeCurtain, AppTheme.describeCurtainEdge],
        ),
      ),
      child: ClipRect(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 380),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: _barrido,
          child: _Tarjeta(
            key: ValueKey('tarjeta_$step'),
            info: info,
            readingTime: readingTime,
            onContinue: onContinue,
          ),
        ),
      ),
    );
  }
}

class _Tarjeta extends StatelessWidget {
  final PendingSignInfo info;
  final Duration readingTime;
  final VoidCallback onContinue;

  const _Tarjeta({
    super.key,
    required this.info,
    required this.readingTime,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Material(
            color: AppTheme.pageBg,
            elevation: 8,
            shadowColor: Colors.black38,
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PendingSignInfoView(info: info, showReviewNote: false),
                  const SizedBox(height: 18),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: readingTime,
                      builder: (context, v, _) => LinearProgressIndicator(
                        key: const Key('avatar_descripcion_lectura'),
                        value: v,
                        minHeight: 6,
                        color: AppTheme.lsbViolet,
                        backgroundColor: AppTheme.glossCardBg,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: onContinue,
                    child: const Text('Entendido'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Abajo, mientras el avatar deletrea una palabra: el sinónimo en LSB o, si
/// no hay, la misma descripción de la hoja «¿Qué es?» de las tarjetas LSB; y
/// «Siguiente» para pasar a la seña de después.
class _SpellingHelpPanel extends StatelessWidget {
  final SpellingHelp help;
  final VoidCallback onNext;

  const _SpellingHelpPanel({
    super.key,
    required this.help,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme.apply(
      bodyColor: AppTheme.lightText,
      displayColor: AppTheme.lightText,
    );
    final descripcion = help.description;
    return Container(
      key: const Key('avatar_deletreo_ayuda'),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.45,
      ),
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      decoration: BoxDecoration(
        color: AppTheme.pageBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.glossCardBorder),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 16,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.spellcheck_rounded,
                        size: 18,
                        color: AppTheme.lightTextSub,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Deletreando',
                        style: tema.bodySmall?.copyWith(
                          color: AppTheme.lightTextSub,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (help.synonyms.isNotEmpty) ...[
                    Text(
                      help.word,
                      style: tema.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Sinónimo en LSB:',
                      style: tema.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      help.synonyms
                          .map((g) => g.replaceAll('_', ' '))
                          .join(' · '),
                      key: const Key('avatar_deletreo_sinonimo'),
                      style: tema.titleMedium?.copyWith(
                        color: AppTheme.lsbViolet,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ] else if (descripcion != null)
                    PendingSignInfoView(
                      info: descripcion,
                      showReviewNote: false,
                    )
                  else
                    Text(
                      help.word,
                      style: tema.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
            child: FilledButton.icon(
              onPressed: onNext,
              icon: const Icon(Icons.skip_next_rounded),
              label: const Text('Siguiente'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Una palabra sin seña en el catálogo: se dice que falta, no se inventa.
class _PendingSignNotice extends StatelessWidget {
  final String gloss;

  const _PendingSignNotice({required this.gloss});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('avatar_sena_a_incorporar'),
      color: const Color(0xFF1E1E2F).withValues(alpha: 0.9),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.pendingSignOnDark.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.pendingSignOnDark, width: 2),
              ),
              child: const Icon(
                Icons.add_circle_outline_rounded,
                color: AppTheme.pendingSignOnDark,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              PendingSign.wordOf(gloss),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.pendingSignOnDark,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              PendingSign.avatarLabel,
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

/// El modelo del avatar todavia se esta cargando: la sena empieza en cuanto
/// este listo.
class _LoadingAvatarNotice extends StatelessWidget {
  final String gloss;

  const _LoadingAvatarNotice({required this.gloss});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: const Key('avatar_cargando'),
      liveRegion: true,
      label: 'Cargando avatar',
      child: Container(
        color: const Color(0xFF1E1E2F).withValues(alpha: 0.85),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Colors.deepPurpleAccent,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Cargando avatar…',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (gloss.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  gloss.replaceAll('_', ' '),
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
