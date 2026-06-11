import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

/// Widget que reproduce secuencialmente animaciones 3D de Lengua de Señas
/// Boliviana (LSB) cargando archivos .GLB desde el Bucket S3 de OpenSoul.
///
/// Flujo:
///   1. Recibe [animationUrls] → lista de URLs de S3 (ej: DENUNCIAR.glb, ROBO.glb)
///   2. Muestra el primer modelo y lo reproduce automáticamente.
///   3. Tras [animationDuration], carga el siguiente en la secuencia.
///   4. Al terminar todos, muestra el estado de reposo.
class Avatar3DViewer extends StatefulWidget {
  final bool isProcessing;
  final List<String>? glosses;
  final List<String>? animationUrls;

  /// Duración estimada de cada animación de seña (ajustable según los .glb)
  final Duration animationDuration;

  const Avatar3DViewer({
    Key? key,
    required this.isProcessing,
    this.glosses,
    this.animationUrls,
    this.animationDuration = const Duration(seconds: 2),
  }) : super(key: key);

  @override
  State<Avatar3DViewer> createState() => _Avatar3DViewerState();
}

const _s3Base = 'https://opensoul-3d-animations.s3.us-east-1.amazonaws.com/';

class _Avatar3DViewerState extends State<Avatar3DViewer>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  bool _isPlayingSequence = false;

  // URLs internas de prueba (se usan cuando el usuario pulsa el botón de test)
  List<String>? _testUrls;
  List<String>? _testGlosses;

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
    setState(() {
      _currentIndex = 0;
      _isPlayingSequence = true;
      if (overrideUrls != null) {
        _testUrls = overrideUrls;
        _testGlosses = overrideGlosses;
      } else {
        _testUrls = null;
        _testGlosses = null;
      }
    });
    _playNext();
  }

  void _playNext() async {
    final urls = _testUrls ?? widget.animationUrls;
    if (urls == null || _currentIndex >= urls.length) {
      if (mounted) {
        setState(() {
          _isPlayingSequence = false;
          _testUrls = null;
          _testGlosses = null;
        });
      }
      return;
    }

    // Esperar duración de la animación antes de pasar a la siguiente
    await Future.delayed(widget.animationDuration);

    if (mounted) {
      setState(() => _currentIndex++);
      _playNext();
    }
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
        const Text(
          'Analizando con IA...',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 16,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Desambiguando contexto jurídico',
          style: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // ESTADO 2: Reproduciendo animación 3D
  // ─────────────────────────────────────────────
  Widget _buildModelViewer(String url) {
    final urls = _testUrls ?? widget.animationUrls!;
    final activeGlosses = _testGlosses ?? widget.glosses;
    final currentGloss = (activeGlosses != null && _currentIndex < activeGlosses.length)
        ? activeGlosses[_currentIndex]
        : '';

    return Stack(
      children: [
        // Visor 3D principal
        Positioned.fill(
          child: ModelViewer(
            src: url,
            alt: 'Avatar LSB realizando la seña: $currentGloss',
            autoPlay: true,
            autoRotate: false,
            cameraControls: false,    // Desactivado para mejor rendimiento
            disableZoom: true,
            backgroundColor: Colors.transparent,
            // ar: false,             // Desactivar AR reduce carga GPU
          ),
        ),

        // Indicador de progreso de la secuencia (bolitas)
        Positioned(
          bottom: 14,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(urls.length, (i) {
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
        ),

        // Chip con el nombre de la glosa actual
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
                '${_currentIndex + 1} / ${urls.length}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 12,
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
          onPressed: _startSequence,
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
        // ── Botón de prueba directa con S3 ──
        OutlinedButton.icon(
          onPressed: () => _startSequence(
            overrideUrls: ['${_s3Base}ABOGADO.glb'],
            overrideGlosses: ['ABOGADO'],
          ),
          icon: const Icon(Icons.play_circle_outline,
              color: Colors.deepPurpleAccent, size: 18),
          label: const Text(
            'Probar ABOGADO.glb (S3)',
            style: TextStyle(color: Colors.deepPurpleAccent, fontSize: 12),
          ),
          style: OutlinedButton.styleFrom(
            side: BorderSide(
                color: Colors.deepPurpleAccent.withOpacity(0.5)),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final urls = widget.animationUrls;

    // Determinar el estado actual del widget
    Widget bodyContent;

    // Combinar las URLs reales con las de test
    final activeUrls = _testUrls ?? urls;

    if (widget.isProcessing) {
      bodyContent = _buildProcessingState();
    } else if (activeUrls != null &&
        activeUrls.isNotEmpty &&
        _isPlayingSequence &&
        _currentIndex < activeUrls.length) {
      bodyContent = _buildModelViewer(activeUrls[_currentIndex]);
    } else if (activeUrls != null && activeUrls.isNotEmpty && !_isPlayingSequence) {
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
