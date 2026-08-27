import 'dart:async';
import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'package:lsb_legal_app/core/data/datasources/animation_cache.dart';
import 'package:lsb_legal_app/core/domain/services/animation_url_resolver.dart';

class Avatar3DViewer extends StatefulWidget {
  final bool isProcessing;
  final List<String>? glosses;
  final List<String>? animationUrls;
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

  List<String>? _testUrls;
  List<String>? _testGlosses;
  List<String> _localUrls = [];

  String _activeViewer = 'A';
  String? _urlA;
  String? _urlB;
  bool _hasFinishedPlayingCurrent = false;

  AnimationController? _pulseController;

  final AnimationCache _cache = AnimationCache();

  dynamic _controllerA;
  dynamic _controllerB;

  Timer? _placeholderTimer;

  void _cancelPlaceholderTimer() {
    _placeholderTimer?.cancel();
    _placeholderTimer = null;
  }

  @override
  void initState() {
    super.initState();

    if (widget.animationUrls?.isNotEmpty ?? false) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startSequence();
      });
    }
  }

  @override
  void didUpdateWidget(Avatar3DViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
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

  void _startSequence({List<String>? overrideUrls, List<String>? overrideGlosses}) {
    if (!mounted) return;
    _cancelPlaceholderTimer();
    setState(() {
      _currentIndex = 0;
      _isPlayingSequence = false;
      _isDownloadingFiles = true;

      _activeViewer = 'A';
      _urlA = null;
      _urlB = null;
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
      final localPath = await _cache.localPathFor(urlStr, tempDir);
      if (localPath != null) {
        localPaths.add('file://$localPath');
      } else if (_cache.isAllowed(urlStr)) {
        localPaths.add(urlStr);
      } else {
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

          if (_localUrls.length > 1) {
            _urlB = _localUrls[1];
          } else {
            _urlB = null;
          }
        }
      });

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

    if (viewerId == _activeViewer &&
        _currentIndex == 0 &&
        !_hasFinishedPlayingCurrent &&
        _localUrls.isNotEmpty) {
      _playViewer(viewerId);
      return;
    }

    final nextViewerId = _activeViewer == 'A' ? 'B' : 'A';
    if (viewerId == nextViewerId && _hasFinishedPlayingCurrent) {
      _transitionTo(nextViewerId);
    }
  }

  void _handleFinished(String viewerId) {
    if (!mounted) return;

    if (_localUrls.length <= 1) {
      _hasFinishedPlayingCurrent = false;
      _playViewer(viewerId);
    }
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
        ? activeGlosses[_currentIndex].toUpperCase().trim()
        : null;

    final controller = id == 'A' ? _controllerA : _controllerB;
    if (controller != null) {
      final animJs = currentGloss != null
          ? """
            const mv = document.querySelector('model-viewer');
            if (mv) {
              mv.pause();
              mv.animationName = '$currentGloss';
              mv.currentTime = 0;
              mv.play({ repetitions: 1 });
            }
          """
          : """
            const mv = document.querySelector('model-viewer');
            if (mv) {
              mv.currentTime = 0;
              mv.play({ repetitions: 1 });
            }
          """;

      controller.runJavaScript(animJs).catchError((e) {
      });
    }
  }

  void _transitionTo(String nextViewerId) {
    if (!mounted) return;
    _cancelPlaceholderTimer();

    setState(() {
      _activeViewer = nextViewerId;
      _hasFinishedPlayingCurrent = false;

      _currentIndex = _currentIndex + 1;

      final otherViewerId = nextViewerId == 'A' ? 'B' : 'A';
      final nextNextIndex = _currentIndex + 1;

      if (nextNextIndex < _localUrls.length) {
        final nextNextUrl = _localUrls[nextNextIndex];
        if (otherViewerId == 'A') {
          _urlA = nextNextUrl;
          _controllerA = null;
        } else {
          _urlB = nextNextUrl;
          _controllerB = null;
        }
      }
    });

    _playViewer(nextViewerId);
  }

  @override
  void dispose() {
    _pulseController?.dispose();
    super.dispose();
  }

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

  Widget _buildModelViewerInstance(String id, String? url) {
    if (url == null || url.startsWith('placeholder://')) return const SizedBox.shrink();

    final activeGlosses = _testGlosses ?? widget.glosses;
    final currentGloss = (activeGlosses != null && _currentIndex < activeGlosses.length)
        ? activeGlosses[_currentIndex]
        : null;

    return ModelViewer(
      key: ValueKey('${id}_$url'),
      src: url,
      alt: 'Avatar LSB',
      animationName: currentGloss,
      autoPlay: true,
      autoRotate: false,
      cameraControls: false,
      disableZoom: true,
      backgroundColor: Colors.transparent,
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

  Widget _buildDualModelViewer() {
    final activeGlosses = _testGlosses ?? widget.glosses;
    final currentGloss = (activeGlosses != null && _currentIndex < activeGlosses.length)
        ? activeGlosses[_currentIndex]
        : '';

    final currentUrl = _currentIndex < _localUrls.length ? _localUrls[_currentIndex] : '';
    final isPlaceholder = currentUrl.startsWith('placeholder://');

    return Stack(
      children: [
        Positioned.fill(
          child: _buildModelViewerInstance('A', _localUrls.isNotEmpty ? _localUrls.first : _urlA),
        ),

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

  Widget _buildIdleState() {
    return Stack(
      children: [
        Positioned.fill(
          child: ModelViewer(
            key: const ValueKey('idle_avatar_viewer'),
            src: '${_s3Base}avatar_test.glb',
            alt: 'Avatar LSB Reposo',
            animationName: 'T-Pose',
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
                const SizedBox(height: 18),
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
