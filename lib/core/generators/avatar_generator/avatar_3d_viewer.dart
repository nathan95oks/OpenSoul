import 'dart:async';
import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'animation_cache.dart';
import 'animation_url_resolver.dart';

/// Widget que reproduce secuencialmente animaciones 3D de Lengua de Señas
/// Boliviana (LSB) cargando archivos .GLB desde el Bucket S3 de OpenSoul.
///
/// Implementa una arquitectura de DOBLE VISOR en Stack para evitar vacíos visuales
/// (black flashes) al cambiar de modelo:
///   - Viewer A y Viewer B se alternan en la pantalla con Opacity.
///   - Mientras uno se reproduce, el otro precarga la siguiente animación en segundo plano.
///   - Se usan canales JS directos al WebGL para detectar carga y término de animación de forma exacta.
class Avatar3DViewer extends StatefulWidget {
  final bool isProcessing;
  final List<String>? glosses;
  final List<String>? animationUrls;

  /// Duración mínima de cada seña antes de avanzar a la siguiente.
  /// (Mantenido por compatibilidad de firma, ya no se usa para cortar animaciones).
  final Duration animationDuration;

  const Avatar3DViewer({
    super.key,
    required this.isProcessing,
    this.glosses,
    this.animationUrls,
    this.animationDuration = const Duration(milliseconds: 2500),
  });

  @override
  State<Avatar3DViewer> createState() => _Avatar3DViewerState();
}

const _s3Base = AnimationUrlResolver.defaultBaseUrl;

class _Avatar3DViewerState extends State<Avatar3DViewer>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  bool _isPlayingSequence = false;
  bool _isDownloadingFiles = false;

  // URLs internas de prueba
  List<String>? _testUrls;
  List<String>? _testGlosses;
  List<String> _localUrls = [];

  // Lógica del Visor 3D Continuo
  String _activeViewer = 'A';
  String? _urlA;
  String? _urlB;
  bool _isLoadedA = false;
  bool _isLoadedB = false;
  bool _hasFinishedPlayingCurrent = false;

  /// Política de descarga de animaciones: allowlist de origen, nombre local
  /// derivado de un hash y tope de tamaño. Ver [AnimationCache].
  final AnimationCache _cache = AnimationCache();

  dynamic _controllerA;
  dynamic _controllerB;

  Timer? _placeholderTimer;

  void _cancelPlaceholderTimer() {
    _placeholderTimer?.cancel();
    _placeholderTimer = null;
  }

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // El visor puede montarse con las URLs **ya resueltas**: es justo lo que
    // pasa al abrir el panel del avatar desde un mensaje ya traducido, donde
    // la secuencia existe antes que el widget. `didUpdateWidget` no llega a
    // dispararse nunca en ese camino —no hay widget anterior con el que
    // comparar—, así que la secuencia no arrancaba y el visor se quedaba en
    // reposo mostrando «Habla o escribe para ver las señas», con las glosas
    // visibles en la cabecera. Post-frame porque `_startSequence` hace
    // `setState`, que no puede ejecutarse durante `initState`.
    if (widget.animationUrls?.isNotEmpty ?? false) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startSequence();
      });
    }
  }

  @override
  void didUpdateWidget(Avatar3DViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Cuando llegan nuevas animationUrls, comenzar la secuencia desde el inicio
    if (widget.animationUrls != oldWidget.animationUrls &&
        widget.animationUrls != null &&
        widget.animationUrls!.isNotEmpty) {
      _startSequence();
    }
  }

  void _startSequence({List<String>? overrideUrls, List<String>? overrideGlosses}) {
    if (!mounted) return;
    _cancelPlaceholderTimer();
    setState(() {
      _currentIndex = 0;
      _isPlayingSequence = false;
      _isDownloadingFiles = true;

      // Reiniciar estado del reproductor dual
      _activeViewer = 'A';
      _urlA = null;
      _urlB = null;
      _isLoadedA = false;
      _isLoadedB = false;
      _controllerA = null;
      _controllerB = null;
      _hasFinishedPlayingCurrent = false;

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

  /// Devuelve el visor a reposo y lo deja listo para una interacción nueva.
  ///
  /// No es lo mismo que volver a reproducir: descarta la secuencia cargada,
  /// suelta los dos visores y limpia el progreso. Sirve cuando la frase
  /// anterior ya no interesa y se va a dictar otra — sin esto, el avatar se
  /// quedaba congelado en la última seña de un mensaje que ya nadie estaba
  /// leyendo.
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
      _hasFinishedPlayingCurrent = false;
      _activeViewer = 'A';
      _urlA = null;
      _urlB = null;
      _isLoadedA = false;
      _isLoadedB = false;
      _controllerA = null;
      _controllerB = null;
    });
  }

  Future<void> _downloadAndStartSequence() async {
    final urlsToDownload = _testUrls ?? widget.animationUrls;
    if (urlsToDownload == null || urlsToDownload.isEmpty) {
      if (mounted) setState(() => _isDownloadingFiles = false);
      return;
    }

    List<String> localPaths = [];
    final tempDir = await getTemporaryDirectory();

    for (var urlStr in urlsToDownload) {
      if (urlStr.startsWith(AnimationUrlResolver.placeholderScheme)) {
        localPaths.add(urlStr);
        continue;
      }
      // El nombre del archivo local ya no sale del URL: lo decide
      // [AnimationCache] a partir de un hash. Ver esa clase para el porqué.
      final localPath = await _cache.localPathFor(urlStr, tempDir);
      if (localPath != null) {
        // Scheme file:// para que ModelViewer lo lea de la caché local.
        localPaths.add('file://$localPath');
      } else if (_cache.isAllowed(urlStr)) {
        // El origen es legítimo y solo falló la descarga (red intermitente,
        // disco lleno). Se carga desde la red, como se hacía antes de existir
        // la caché: degradar aquí a texto dejaría sin señas a quien esté en
        // una comisaría con mala cobertura, que es justo el escenario de uso.
        // Es seguro porque el esquema y el host ya pasaron la política.
        localPaths.add(urlStr);
      } else {
        // Origen rechazado: la glosa se rotula como texto en vez de apuntar
        // a un destino que no pasó la política.
        localPaths.add('${AnimationUrlResolver.placeholderScheme}$urlStr');
      }
    }

    if (mounted) {
      setState(() {
        _localUrls = localPaths;
        _isDownloadingFiles = false;
        _isPlayingSequence = true;

        if (_localUrls.isNotEmpty) {
          _urlA = _localUrls[0];
          _isLoadedA = _urlA!.startsWith('placeholder://');

          if (_localUrls.length > 1) {
            _urlB = _localUrls[1];
            _isLoadedB = _urlB!.startsWith('placeholder://');
          } else {
            _urlB = null;
          }
        }
      });

      // Si la primera seña es un placeholder, debemos disparar la simulación de inmediato
      if (_localUrls.isNotEmpty && _localUrls[0].startsWith('placeholder://')) {
        _playViewer('A');
      }
    }
  }

  void _handleJsMessage(String viewerId, String message) {
    if (message == 'loaded') {
      _handleLoaded(viewerId);
    } else if (message == 'finished') {
      _handleFinished(viewerId);
    }
  }

  void _handleLoaded(String viewerId) {
    if (!mounted) return;
    setState(() {
      if (viewerId == 'A') {
        _isLoadedA = true;
      } else {
        _isLoadedB = true;
      }
    });

    // Si es el visor activo que carga el primer elemento del recorrido, iniciamos reproducción
    if (viewerId == _activeViewer &&
        _currentIndex == 0 &&
        !_hasFinishedPlayingCurrent &&
        _localUrls.isNotEmpty) {
      _playViewer(viewerId);
      return;
    }

    // Si el visor activo ya terminó de reproducir y el de fondo se acaba de cargar
    final nextViewerId = _activeViewer == 'A' ? 'B' : 'A';
    if (viewerId == nextViewerId && _hasFinishedPlayingCurrent) {
      _transitionTo(nextViewerId);
    }
  }

  void _handleFinished(String viewerId) {
    if (!mounted) return;

    // Si solo hay un elemento, lo reproducimos en bucle en el mismo visor
    if (_localUrls.length <= 1) {
      _hasFinishedPlayingCurrent = false;
      _playViewer(viewerId);
    }
    // Última seña de la frase: el avatar se detiene y queda inactivo.
    //
    // Antes se repetía indefinidamente —la secuencia de un solo elemento
    // rearrancaba el mismo visor y la de varios volvía al índice 0—, y esa
    // repetición borraba el límite del mensaje: quien mira no distingue si el
    // avatar sigue diciendo algo o ya empezó otra vez. Ahora el final se ve, y
    // repetir es una decisión de quien lee, no del reproductor.
    if (_currentIndex >= _localUrls.length - 1) {
      _cancelPlaceholderTimer();
      setState(() {
        _isPlayingSequence = false;
        _hasFinishedPlayingCurrent = true;
      });
      return;
    }

    _advanceToNextAction();
  }

  void _advanceToNextAction() {
    if (!mounted) return;
    _cancelPlaceholderTimer();

    setState(() {
      _currentIndex = (_currentIndex + 1) % _localUrls.length;
      _hasFinishedPlayingCurrent = false;
    });

    _playViewer('A');
  }

  void _playViewer(String id) {
    final currentUrl = id == 'A' ? _urlA : _urlB;
    if (currentUrl != null && currentUrl.startsWith('placeholder://')) {
      _cancelPlaceholderTimer();
      _placeholderTimer = Timer(widget.animationDuration, () {
        _handleFinished(id);
      });
      return;
    }

    final activeGlosses = _testGlosses ?? widget.glosses;
    final currentGloss = (activeGlosses != null && _currentIndex < activeGlosses.length)
        ? activeGlosses[_currentIndex]
        : null;

    final controller = id == 'A' ? _controllerA : _controllerB;
    if (controller != null) {
      final animJs = currentGloss != null ? "document.querySelector('model-viewer').animationName = '$currentGloss';" : "";
      controller.runJavaScript(
        "$animJs document.querySelector('model-viewer').currentTime = 0; document.querySelector('model-viewer').play();"
      ).catchError((e) {
      });
    }
  }

  void _transitionTo(String nextViewerId) {
    if (!mounted) return;
    _cancelPlaceholderTimer();

    setState(() {
      _activeViewer = nextViewerId;
      _hasFinishedPlayingCurrent = false;

      // Avanzar índice global secuencial. Sin módulo: el desbordamiento ya
      // no existe porque `_handleFinished` corta en la última seña, y
      // envolverlo aquí era justo lo que reiniciaba la frase.
      _currentIndex = _currentIndex + 1;

      // Precargar la siguiente animación en el visor que ahora pasa a fondo.
      // Si no hay siguiente, no se precarga nada: el visor de fondo se queda
      // como está y la secuencia termina en el activo.
      final otherViewerId = nextViewerId == 'A' ? 'B' : 'A';
      final nextNextIndex = _currentIndex + 1;

      if (nextNextIndex < _localUrls.length) {
        final nextNextUrl = _localUrls[nextNextIndex];
        if (otherViewerId == 'A') {
          _urlA = nextNextUrl;
          _isLoadedA = nextNextUrl.startsWith('placeholder://');
          _controllerA = null;
        } else {
          _urlB = nextNextUrl;
          _isLoadedB = nextNextUrl.startsWith('placeholder://');
          _controllerB = null;
        }
      }
    });

    // Reproducir inmediatamente el nuevo visor activo
    _playViewer(nextViewerId);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // ESTADO 1: Procesando (Spinner + texto)
  // ─────────────────────────────────────────────
  Widget _buildProcessingState() {
    final title = _isDownloadingFiles ? 'Descargando animaciones 3D...' : 'Analizando con IA...';
    final subtitle = _isDownloadingFiles ? 'Guardando en caché local para fluidez' : 'Desambiguando contexto LSB';

    return Column(
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
    );
  }

  // Instancia individual de ModelViewer
  Widget _buildModelViewerInstance(String id, String? url) {
    if (url == null || url.startsWith('placeholder://')) return const SizedBox.shrink();

    final activeGlosses = _testGlosses ?? widget.glosses;
    final currentGloss = (activeGlosses != null && _currentIndex < activeGlosses.length)
        ? activeGlosses[_currentIndex]
        : null;

    return ModelViewer(
      key: ValueKey('${id}_$url'), // Mantiene vivo el WebView del modelo sin destruirlo
      src: url,
      alt: 'Avatar LSB',
      animationName: currentGloss, // Seña específica (ej: 'HOLA' o 'SI')
      autoPlay: true,
      autoRotate: false,
      cameraControls: false,
      disableZoom: true,
      backgroundColor: Colors.transparent,
      // Plano medio: Enfoca torso, brazos, manos y rostro
      cameraTarget: "0m 1.25m 0m",
      cameraOrbit: "0deg 90deg 1.7m",
      fieldOfView: "30deg",
      onWebViewCreated: (controller) {
        if (id == 'A') {
          _controllerA = controller;
        } else {
          _controllerB = controller;
        }
      },
      javascriptChannels: {
        JavascriptChannel(
          'ModelViewerChannel',
          onMessageReceived: (message) {
            _handleJsMessage(id, message.message);
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

        modelViewer.addEventListener('finished', () => {
          if (window.ModelViewerChannel) {
            window.ModelViewerChannel.postMessage('finished');
          }
        });

        modelViewer.addEventListener('loop', () => {
          if (window.ModelViewerChannel) {
            window.ModelViewerChannel.postMessage('finished');
          }
        });
      ''',
    );
  }


  // ─────────────────────────────────────────────
  // ESTADO 2: Reproducción en visor 3D continuo (Multi-Action sin pantalla negra)
  // ─────────────────────────────────────────────
  Widget _buildDualModelViewer() {
    final activeGlosses = _testGlosses ?? widget.glosses;
    final currentGloss = (activeGlosses != null && _currentIndex < activeGlosses.length)
        ? activeGlosses[_currentIndex]
        : '';

    final currentUrl = _currentIndex < _localUrls.length ? _localUrls[_currentIndex] : '';
    final isPlaceholder = currentUrl.startsWith('placeholder://');

    return Stack(
      children: [
        // Visor 3D Principal Único y Continuo (Evita parpadeos o pantallas negras)
        Positioned.fill(
          child: _buildModelViewerInstance('A', _localUrls.isNotEmpty ? _localUrls.first : _urlA),
        ),

        // Overlay de Simulación si es Placeholder
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

        // Barra inferior con botón "Siguiente" y bolitas de progreso
        Positioned(
          bottom: 10,
          left: 0,
          right: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_localUrls.length > 1)
                GestureDetector(
                  onTap: () => _advanceToNextAction(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.deepPurpleAccent.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text('Siguiente',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                        SizedBox(width: 4),
                        Icon(Icons.skip_next_rounded,
                            color: Colors.white, size: 16),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_localUrls.length, (i) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _currentIndex ? 20 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: i == _currentIndex
                          ? Colors.deepPurpleAccent
                          : Colors.white24,
                    ),
                  );
                }),
              ),
            ],
          ),
        ),

        // Indicador de glosa actual y estado
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

  // ─────────────────────────────────────────────
  // ESTADO 3: Resultado mostrado (secuencia terminada)
  // Nota: En reproducción en bucle continuo, este estado no se alcanza a menos que se fuerce.
  // ─────────────────────────────────────────────
  Widget _buildFinishedState() {
    return Column(
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
    );
  }

  // ─────────────────────────────────────────────
  // ESTADO 4: Reposo / Inicial (Avatar siempre visible en reposo)
  // ─────────────────────────────────────────────
  Widget _buildIdleState() {
    return Stack(
      children: [
        // Avatar 3D cargado de fondo en pose neutra/espera (Nunca pantalla vacía)
        Positioned.fill(
          child: ModelViewer(
            key: const ValueKey('idle_avatar_viewer'),
            src: '${_s3Base}avatar_test.glb',
            alt: 'Avatar LSB Reposo',
            animationName: 'T-Pose', // Pose neutra o quieta exportada
            autoPlay: false,
            autoRotate: false,
            cameraControls: false,
            disableZoom: true,
            backgroundColor: Colors.transparent,
            cameraTarget: "0m 1.25m 0m",
            cameraOrbit: "0deg 90deg 1.7m",
            fieldOfView: "30deg",
          ),
        ),

        // Overlay suave con información y botones de acción
        Positioned.fill(
          child: Container(
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
                const SizedBox(height: 8),
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
                const SizedBox(height: 12),
                // ── Botones de prueba ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                onPressed: () => _startSequence(
                  overrideUrls: [
                    '${_s3Base}YO.glb',
                    '${_s3Base}POLICIA.glb',
                    'placeholder://LLAMAR',
                  ],
                  overrideGlosses: ['YO', 'POLICIA', 'LLAMAR'],
                ),
                icon: const Icon(Icons.play_circle_outline,
                    color: Colors.greenAccent, size: 18),
                label: const Text(
                  'Probar: YO + POLICÍA + LLAMAR',
                  style: TextStyle(color: Colors.greenAccent, fontSize: 11),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                      color: Colors.greenAccent.withValues(alpha: 0.5)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _startSequence(
                  overrideUrls: [
                    '${_s3Base}JUEZ.glb',
                    'placeholder://FUEGO-LLAMA',
                    'placeholder://VER',
                  ],
                  overrideGlosses: ['JUEZ', 'FUEGO-LLAMA', 'VER'],
                ),
                icon: const Icon(Icons.play_circle_outline,
                    color: Colors.amberAccent, size: 18),
                label: const Text(
                  'Probar: JUEZ + FUEGO-LLAMA + VER (Placeholder)',
                  style: TextStyle(color: Colors.amberAccent, fontSize: 11),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                      color: Colors.amberAccent.withValues(alpha: 0.5)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _startSequence(
                  overrideUrls: [
                    '${_s3Base}avatar_test.glb',
                  ],
                  overrideGlosses: ['HOLA'],
                ),
                icon: const Icon(Icons.touch_app_rounded,
                    color: Colors.lightGreenAccent, size: 18),
                label: const Text(
                  'Probar Seña: Solo HOLA',
                  style: TextStyle(color: Colors.lightGreenAccent, fontSize: 11, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                      color: Colors.lightGreenAccent.withValues(alpha: 0.7)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _startSequence(
                  overrideUrls: [
                    '${_s3Base}avatar_test.glb',
                    '${_s3Base}avatar_test.glb',
                  ],
                  overrideGlosses: ['HOLA', 'SI'],
                ),
                icon: const Icon(Icons.star_rounded,
                    color: Colors.cyanAccent, size: 18),
                label: const Text(
                  'Probar Secuencia: HOLA + SI (Multi-Action)',
                  style: TextStyle(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                      color: Colors.cyanAccent.withValues(alpha: 0.7)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
        ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget bodyContent;

    if (widget.isProcessing || _isDownloadingFiles) {
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
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: bodyContent,
        ),
      ),
    );
  }
}
