import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lsb_legal_app/core/di/injection.dart';
import 'package:lsb_legal_app/core/domain/services/animation_url_resolver.dart';

class Avatar3DViewer extends ConsumerStatefulWidget {
  final bool isProcessing;
  final List<String>? glosses;
  final List<String>? animationUrls;
  final Duration animationDuration;

  /// Cuando es `false` el visor detiene la reproduccion y libera el WebView.
  /// Lo usan las superficies que quedan vivas en segundo plano (IndexedStack)
  /// para que el avatar no siga senando al cambiar de modulo.
  final bool isActive;

  const Avatar3DViewer({
    super.key,
    required this.isProcessing,
    this.glosses,
    this.animationUrls,
    this.animationDuration = const Duration(milliseconds: 2500),
    this.isActive = true,
  });

  @override
  ConsumerState<Avatar3DViewer> createState() => _Avatar3DViewerState();
}

const _s3Base = AnimationUrlResolver.defaultBaseUrl;

/// Margen sobre la duracion de una sena antes de dar el paso por perdido.
/// Cubre el caso de una glosa que no existe dentro del .glb: el visor no
/// emite 'finished' y sin este reloj la secuencia no avanzaria nunca.
///
/// La sena mas larga del modelo dura 4,92 s (PERMISO), asi que 6 s dejaban
/// solo un segundo de margen y en un equipo cargado habrian cortado senas
/// buenas. El reloj es una red de seguridad, no un temporizador: conviene que
/// tarde de mas antes que quitarle tiempo a una sena que se esta viendo bien.
const _stepWatchdog = Duration(seconds: 10);

/// Suelo por debajo del cual un aviso de fin no es creible. Protege del caso
/// en que el visor arranca una sena ya terminada y avisa en el acto.
const _minStepDuration = Duration(milliseconds: 300);

class _Avatar3DViewerState extends ConsumerState<Avatar3DViewer>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  bool _isPlayingSequence = false;
  bool _isDownloadingFiles = false;

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

  AnimationController? _pulseController;

  dynamic _controllerA;

  /// Fuente del unico modelo 3D, resuelta una vez. Todas las senas estan
  /// horneadas dentro, asi que el visor no cambia de `src` en toda la sesion:
  /// es lo que evita recargar y reparsear 8,5 MB en cada traduccion.
  String? _modelSource;

  /// Vence el paso en curso si el visor no avisa: un placeholder no tiene
  /// `model-viewer` que emita 'finished', y una glosa que no exista dentro
  /// del .glb tampoco lo emite. Sin esto la secuencia se queda clavada.
  Timer? _placeholderTimer;

  void _cancelPlaceholderTimer() {
    _placeholderTimer?.cancel();
    _placeholderTimer = null;
  }

  @override
  void initState() {
    super.initState();
    _resolveModelSource();

    if (widget.isActive && (widget.animationUrls?.isNotEmpty ?? false)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startSequence();
      });
    }
  }

  /// Deja el modelo listo en local antes de que haga falta, para que la
  /// primera traduccion no pague la descarga.
  Future<void> _resolveModelSource() async {
    const remoto = '${_s3Base}avatar_test.glb';
    try {
      final fuentes = await ref
          .read(animationRepositoryProvider)
          .playableSources(const [remoto]);
      final local = fuentes.firstWhere(
        (f) => !f.startsWith(AnimationUrlResolver.placeholderScheme),
        orElse: () => remoto,
      );
      if (mounted) setState(() => _modelSource = local);
    } catch (_) {
      if (mounted) setState(() => _modelSource = remoto);
    }
  }

  @override
  void didUpdateWidget(Avatar3DViewer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.isActive && !widget.isActive) {
      _stopPlayback();
      return;
    }

    if (_testUrls == null && _hasNothingToPlay && _isBusy) {
      _stopPlayback();
      return;
    }

    if (!widget.isActive) return;

    final hasNewUrls = widget.animationUrls != oldWidget.animationUrls &&
        widget.animationUrls != null &&
        widget.animationUrls!.isNotEmpty;
    final hasNewGlosses = widget.glosses != oldWidget.glosses &&
        widget.glosses != null &&
        widget.glosses!.isNotEmpty;

    if (hasNewUrls || hasNewGlosses) {
      _startSequence();
    }
  }

  bool get _hasNothingToPlay =>
      (widget.animationUrls?.isEmpty ?? true) && (widget.glosses?.isEmpty ?? true);

  bool get _isBusy =>
      _localUrls.isNotEmpty || _isPlayingSequence || _isDownloadingFiles;

  /// Corta la secuencia en curso: pausa el `model-viewer`, cancela el timer de
  /// los placeholders y devuelve el visor a reposo.
  void _stopPlayback() {
    _cancelPlaceholderTimer();
    _pauseViewers();
    _resetToIdle();
  }

  void _pauseViewers() {
    const pauseJs = """
      const mv = document.querySelector('model-viewer');
      if (mv) {
        mv.pause();
        mv.currentTime = 0;
      }
    """;

    final controller = _controllerA;
    if (controller == null) return;
    try {
      controller.runJavaScript(pauseJs).catchError((e) {});
    } catch (_) {
    }
  }

  void _startSequence({List<String>? overrideUrls, List<String>? overrideGlosses}) {
    if (!mounted) return;
    _cancelPlaceholderTimer();
    setState(() {
      _currentIndex = 0;
      _isPlayingSequence = false;
      _isDownloadingFiles = true;

      _stepSettled = false;

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
    _cancelPlaceholderTimer();
    setState(() {
      _localUrls = [];
      _testUrls = null;
      _testGlosses = null;
      _currentIndex = 0;
      _isPlayingSequence = false;
      _isDownloadingFiles = false;
      _stepSettled = false;
    });
  }

  Future<void> _downloadAndStartSequence() async {
    final urlsToDownload = _testUrls ?? widget.animationUrls;
    if (urlsToDownload == null || urlsToDownload.isEmpty) {
      if (mounted) setState(() => _isDownloadingFiles = false);
      return;
    }

    final localPaths = await ref
        .read(animationRepositoryProvider)
        .playableSources(urlsToDownload);

    if (mounted) {
      setState(() {
        _localUrls = localPaths;
        _isDownloadingFiles = false;
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
    // El WebView acaba de existir. Si el paso en curso quedo sin reproducir
    // por no haber controller todavia, este es el momento de lanzarlo.
    _playCurrentStep();
  }

  void _handleFinished(String viewerId) => _finishCurrentStep();

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
    _stepSettled = false;
    _playToken++;

    final url = _localUrls[_currentIndex];

    if (!kReleaseMode) {
      final tipo = url.startsWith(AnimationUrlResolver.placeholderScheme)
          ? 'placeholder'
          : 'modelo';
      debugPrint('[avatar] PLAY paso=$_currentIndex token=$_playToken '
          'tipo=$tipo gloss=${_glossAt(_currentIndex)} '
          'controller=${_controllerA == null ? "NULL" : "ok"}');
    }

    if (url.startsWith(AnimationUrlResolver.placeholderScheme)) {
      _stepStartedAt = DateTime.now();
      _placeholderTimer = Timer(widget.animationDuration, _finishCurrentStep);
      return;
    }

    // El reloj se arma siempre, tambien cuando no hay controller: el WebView
    // puede tardar en existir o no cargar, y la secuencia no puede depender
    // de que 'finished' llegue.
    _placeholderTimer = Timer(_stepWatchdog, _finishCurrentStep);

    final controller = _controllerA;
    if (controller == null) return;

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
      controller.runJavaScript('''
        (async () => {
          const mv = document.querySelector('model-viewer');
          if (!mv) return;
          window.__lsbStep = $token;
          $seleccion
          if (mv.updateComplete) { await mv.updateComplete; }
          mv.currentTime = 0;
          mv.play({ repetitions: 1 });
          if (window.ModelViewerChannel) {
            window.ModelViewerChannel.postMessage(
              'diag:' + $token + ':' + mv.animationName + ':' + mv.duration
            );
          }
        })();
      ''').catchError((e) {});
    } catch (_) {
    }
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
      debugPrint('[avatar] FIN  paso=$_currentIndex token=$_playToken '
          'tras=${ms}ms');
    }

    if (_currentIndex >= _localUrls.length - 1) {
      setState(() => _isPlayingSequence = false);
      return;
    }

    setState(() => _currentIndex++);
    _playCurrentStep();
  }

  @override
  void dispose() {
    _cancelPlaceholderTimer();
    _pauseViewers();
    _pulseController?.dispose();
    super.dispose();
  }

  Widget _buildProcessingState() {
    final title = _isDownloadingFiles ? 'Descargando animaciones 3D...' : 'Analizando con IA...';
    final subtitle = _isDownloadingFiles ? 'Guardando en caché local para fluidez' : 'Desambiguando contexto LSB';

    return Container(
      key: const ValueKey('processing'),
      color: const Color(0xFF1A1A2E).withValues(alpha: 0.92),
      child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 60,
          height: 60,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(
              Colors.deepPurpleAccent.shade200,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 16,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 12,
          ),
        ),
      ],
      ),
    );
  }

  /// El visor 3D, montado una sola vez y compartido por todos los estados.
  ///
  /// `autoPlay` va en falso a proposito: el avatar se queda en reposo hasta
  /// que [_playCurrentStep] le pide una sena. Con autoPlay el visor arrancaba
  /// reproduciendo por su cuenta la primera sena de la secuencia, que se veia
  /// antes de tiempo y encima emitia avisos de fin que no eran de ningun paso.
  Widget _buildPersistentViewer() {
    final src = _modelSource;
    if (src == null) return const SizedBox.shrink();

    return ModelViewer(
      key: const ValueKey('avatar_viewer'),
      src: src,
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
      },
      javascriptChannels: {
        JavascriptChannel(
          'ModelViewerChannel',
          onMessageReceived: (message) {
            _handleJsMessage('A', message.message);
          },
        ),
      },
      relatedJs: '''
        const modelViewer = document.querySelector('model-viewer');

        modelViewer.addEventListener('load', () => {
          if (window.ModelViewerChannel) {
            window.ModelViewerChannel.postMessage('loaded');
          }
        });

        const avisarFin = () => {
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
    final currentGloss = (activeGlosses != null && _currentIndex < activeGlosses.length)
        ? activeGlosses[_currentIndex]
        : '';

    final currentUrl = _currentIndex < _localUrls.length ? _localUrls[_currentIndex] : '';
    final isPlaceholder =
        currentUrl.startsWith(AnimationUrlResolver.placeholderScheme);

    // Solo los rotulos: el visor vive debajo, en [build], y no se desmonta al
    // cambiar de estado.
    return Stack(
      key: const ValueKey('playing'),
      children: [
        if (isPlaceholder)
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
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
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
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.deepPurpleAccent.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  currentGloss,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_currentIndex + 1} / ${_localUrls.length}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.replay_rounded, color: Colors.white),
                tooltip: 'Repetir secuencia',
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
                onPressed: () => _startSequence(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFinishedState() {
    return Container(
      key: const ValueKey('finished'),
      // Velo sobre el avatar, que ahora sigue montado detras: sin el, el
      // texto cae encima del modelo y no se lee.
      color: const Color(0xFF1A1A2E).withValues(alpha: 0.92),
      child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.deepPurpleAccent.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.deepPurpleAccent.withValues(alpha: 0.4),
              width: 2,
            ),
          ),
          child: const Icon(
            Icons.check_circle_outline_rounded,
            size: 50,
            color: Colors.deepPurpleAccent,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Señas reproducidas',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 6,
          runSpacing: 6,
          children: ((_testGlosses ?? widget.glosses) ?? []).map((g) {
            return Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: Text(
                g,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton.icon(
              onPressed: _resetToIdle,
              icon: const Icon(Icons.refresh_rounded,
                  color: Colors.white54, size: 20),
              label: const Text(
                'Refrescar',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            const SizedBox(width: 4),
            TextButton.icon(
              onPressed: () => _startSequence(),
              icon: const Icon(Icons.replay_rounded,
                  color: Colors.deepPurpleAccent),
              label: const Text(
                'Reproducir',
                style: TextStyle(color: Colors.deepPurpleAccent),
              ),
            ),
          ],
        ),
      ],
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
    return Container(
      key: const ValueKey('idle'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            const Color(0xFF1A1A2E).withValues(alpha: 0.85),
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            'Avatar LSB Listo',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 15,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Habla o escribe para ver las señas',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 18),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget bodyContent;

    if (!widget.isActive) {
      bodyContent = _buildPausedState();
    } else if (widget.isProcessing || _isDownloadingFiles) {
      bodyContent = _buildProcessingState();
    } else if (_localUrls.isNotEmpty && _isPlayingSequence) {
      bodyContent = _buildDualModelViewer();
    } else if (_localUrls.isNotEmpty && !_isPlayingSequence) {
      bodyContent = _buildFinishedState();
    } else {
      bodyContent = _buildIdleState();
    }

    return Container(
      width: double.infinity,
      height: 300,
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
