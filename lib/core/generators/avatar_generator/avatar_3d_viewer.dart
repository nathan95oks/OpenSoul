import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

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
    Key? key,
    required this.isProcessing,
    this.glosses,
    this.animationUrls,
    this.animationDuration = const Duration(milliseconds: 2500),
  }) : super(key: key);

  @override
  State<Avatar3DViewer> createState() => _Avatar3DViewerState();
}

const _s3Base = 'https://opensoul-3d-animations.s3.us-east-1.amazonaws.com/';

class _Avatar3DViewerState extends State<Avatar3DViewer>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  bool _isPlayingSequence = false;
  bool _isDownloadingFiles = false;

  // URLs internas de prueba
  List<String>? _testUrls;
  List<String>? _testGlosses;
  List<String> _localUrls = [];

  // Lógica del Doble Visor
  String _activeViewer = 'A'; // 'A' o 'B'
  String? _urlA;
  String? _urlB;
  bool _isLoadedA = false;
  bool _isLoadedB = false;
  bool _hasFinishedPlayingCurrent = false;

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

  Future<void> _downloadAndStartSequence() async {
    final urlsToDownload = _testUrls ?? widget.animationUrls;
    if (urlsToDownload == null || urlsToDownload.isEmpty) {
      if (mounted) setState(() => _isDownloadingFiles = false);
      return;
    }

    List<String> localPaths = [];
    final tempDir = await getTemporaryDirectory();

    for (var urlStr in urlsToDownload) {
      if (urlStr.startsWith('placeholder://')) {
        localPaths.add(urlStr);
        continue;
      }
      try {
        final uri = Uri.parse(urlStr);
        final fileName = uri.pathSegments.last;
        final file = File('${tempDir.path}/$fileName');

        if (!await file.exists()) {
          final response = await http.get(uri);
          if (response.statusCode == 200) {
            await file.writeAsBytes(response.bodyBytes);
          }
        }
        // Usar scheme file:// para que ModelViewer lo lea de la caché local
        localPaths.add('file://${file.path}');
      } catch (e) {
        // Fallback al URL original si falla la descarga
        localPaths.add(urlStr);
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
    debugPrint('Mensaje JS recibido de Visor $viewerId: $message');
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
    if (_localUrls.length == 1) {
      _hasFinishedPlayingCurrent = false;
      _playViewer(viewerId);
      return;
    }

    setState(() {
      _hasFinishedPlayingCurrent = true;
    });

    final nextViewerId = _activeViewer == 'A' ? 'B' : 'A';
    final isNextLoaded = nextViewerId == 'A' ? _isLoadedA : _isLoadedB;

    if (isNextLoaded) {
      _transitionTo(nextViewerId);
    }
  }

  void _playViewer(String id) {
    final currentUrl = id == 'A' ? _urlA : _urlB;
    if (currentUrl != null && currentUrl.startsWith('placeholder://')) {
      debugPrint('Visor $id es un placeholder: $currentUrl. Programando temporizador.');
      _cancelPlaceholderTimer();
      _placeholderTimer = Timer(widget.animationDuration, () {
        _handleFinished(id);
      });
      return;
    }

    final controller = id == 'A' ? _controllerA : _controllerB;
    if (controller != null) {
      debugPrint('Enviando play JS a Visor $id');
      controller.runJavaScript(
        "document.querySelector('model-viewer').currentTime = 0; document.querySelector('model-viewer').play();"
      ).catchError((e) {
        debugPrint('Error ejecutando play JS: $e');
      });
    } else {
      debugPrint('Controlador nulo para Visor $id en _playViewer.');
    }
  }

  void _transitionTo(String nextViewerId) {
    if (!mounted) return;
    _cancelPlaceholderTimer();
    debugPrint('Transicionando a Visor: $nextViewerId');

    setState(() {
      _activeViewer = nextViewerId;
      _hasFinishedPlayingCurrent = false;

      // Avanzar índice global secuencial
      _currentIndex = (_currentIndex + 1) % _localUrls.length;

      // Precargar la siguiente animación en el visor que ahora pasa a fondo
      final otherViewerId = nextViewerId == 'A' ? 'B' : 'A';
      final nextNextIndex = (_currentIndex + 1) % _localUrls.length;

      if (_localUrls.length > 1) {
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
            color: Colors.white.withOpacity(0.4),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  // Instancia individual de ModelViewer
  Widget _buildModelViewerInstance(String id, String? url) {
    if (url == null || url.startsWith('placeholder://')) return const SizedBox.shrink();

    return ModelViewer(
      key: ValueKey('${id}_$url'), // Recrea el WebView al cambiar el URL
      src: url,
      alt: 'Avatar LSB',
      autoPlay: true, // Debe ser true para enlazar la animación al cargarse
      autoRotate: false,
      cameraControls: false,
      disableZoom: true,
      backgroundColor: Colors.transparent,
      cameraTarget: "0m 0.9m 0m",   // Cara / pecho
      cameraOrbit: "0deg 90deg 3.0m", // Más zoom
      onWebViewCreated: (controller) {
        debugPrint('WebView Creada para Visor $id con URL: $url');
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
          modelViewer.pause();
          modelViewer.currentTime = 0;
          if (window.ModelViewerChannel) {
            window.ModelViewerChannel.postMessage('loaded');
          }
        });

        modelViewer.addEventListener('finished', () => {
          modelViewer.pause();
          if (window.ModelViewerChannel) {
            window.ModelViewerChannel.postMessage('finished');
          }
        });

        modelViewer.addEventListener('loop', () => {
          modelViewer.pause();
          if (window.ModelViewerChannel) {
            window.ModelViewerChannel.postMessage('finished');
          }
        });
      ''',
    );
  }


  // ─────────────────────────────────────────────
  // ESTADO 2: Reproducción en doble visor
  // ─────────────────────────────────────────────
  Widget _buildDualModelViewer() {
    final activeGlosses = _testGlosses ?? widget.glosses;
    final currentGloss = (activeGlosses != null && _currentIndex < activeGlosses.length)
        ? activeGlosses[_currentIndex]
        : '';

    final nextViewerId = _activeViewer == 'A' ? 'B' : 'A';
    final isNextLoaded = nextViewerId == 'A' ? _isLoadedA : _isLoadedB;
    final canAdvance = _localUrls.length > 1 && isNextLoaded;

    final currentUrl = _currentIndex < _localUrls.length ? _localUrls[_currentIndex] : '';
    final isPlaceholder = currentUrl.startsWith('placeholder://');

    return Stack(
      children: [
        // Visor A
        Positioned.fill(
          child: Opacity(
            opacity: _activeViewer == 'A' ? 1.0 : 0.0,
            child: IgnorePointer(
              ignoring: _activeViewer != 'A',
              child: _buildModelViewerInstance('A', _urlA),
            ),
          ),
        ),

        // Visor B
        Positioned.fill(
          child: Opacity(
            opacity: _activeViewer == 'B' ? 1.0 : 0.0,
            child: IgnorePointer(
              ignoring: _activeViewer != 'B',
              child: _buildModelViewerInstance('B', _urlB),
            ),
          ),
        ),

        // Overlay de Simulación si es Placeholder
        if (isPlaceholder)
          Positioned.fill(
            child: Container(
              color: const Color(0xFF1E1E2F).withOpacity(0.9),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.1),
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
                AnimatedOpacity(
                  opacity: canAdvance ? 1.0 : 0.3,
                  duration: const Duration(milliseconds: 400),
                  child: GestureDetector(
                    onTap: canAdvance ? () => _transitionTo(nextViewerId) : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.deepPurpleAccent.withOpacity(0.85),
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

        // Indicador de glosa actual y estado de debug
        Positioned(
          top: 14,
          left: 14,
          right: 14,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.deepPurpleAccent.withOpacity(0.85),
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
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  // Botón de repetición manual
                  IconButton(
                    icon: const Icon(Icons.replay_rounded, color: Colors.white),
                    tooltip: 'Repetir secuencia',
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                    onPressed: () => _startSequence(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // DEBUG URL
              Visibility(
                visible: false,
                child: Text(
                  'DEBUG: Visor=$_activeViewer | Seña=$_currentIndex | LoadedA=$_isLoadedA | LoadedB=$_isLoadedB',
                  style: const TextStyle(
                    color: Colors.amber,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 3,
                ),
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
            color: Colors.deepPurpleAccent.withOpacity(0.15),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.deepPurpleAccent.withOpacity(0.4),
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
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: Colors.white.withOpacity(0.15)),
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
        TextButton.icon(
          onPressed: () => _startSequence(),
          icon: const Icon(Icons.replay_rounded,
              color: Colors.deepPurpleAccent),
          label: const Text(
            'Reproducir de nuevo',
            style: TextStyle(color: Colors.deepPurpleAccent),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // ESTADO 4: Reposo / Sin datos aún
  // ─────────────────────────────────────────────
  Widget _buildIdleState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ScaleTransition(
          scale: _pulseAnimation,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.deepPurpleAccent.withOpacity(0.3),
                  Colors.transparent,
                ],
              ),
            ),
            child: Icon(
              Icons.person_outline_rounded,
              size: 70,
              color: Colors.white.withOpacity(0.25),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Avatar LSB',
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Habla o escribe para ver las señas',
          style: TextStyle(
            color: Colors.white.withOpacity(0.3),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 16),
        // ── Botones de prueba offline de desambiguación y simulación ──
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
                      color: Colors.greenAccent.withOpacity(0.5)),
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
                      color: Colors.amberAccent.withOpacity(0.5)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
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
          color: Colors.deepPurpleAccent.withOpacity(0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurpleAccent.withOpacity(0.1),
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
