import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

/// Visor de avatar 3D para representación visual de señas LSB.
///
/// Utiliza un modelo glTF/GLB renderizado con model_viewer_plus.
/// Soporta reproducción de animaciones por nombre (una por glosa)
/// y reproducción secuencial de la secuencia completa.
class AvatarSignViewer extends StatefulWidget {
  /// Lista de glosas a reproducir (nombres de animación en el modelo GLB).
  final List<String> glosses;

  /// URL o asset path del modelo 3D del avatar.
  final String modelSrc;

  /// Si true, reproduce automáticamente la secuencia de animaciones.
  final bool autoPlay;

  /// Altura del visor.
  final double height;

  const AvatarSignViewer({
    super.key,
    required this.glosses,
    this.modelSrc = 'https://modelviewer.dev/shared-assets/models/RobotExpressive.glb',
    this.autoPlay = true,
    this.height = 220,
  });

  @override
  State<AvatarSignViewer> createState() => _AvatarSignViewerState();
}

class _AvatarSignViewerState extends State<AvatarSignViewer> {
  int _currentGlossIndex = 0;
  bool _isPlaying = false;

  // Mapa de glosas a nombres de animación en el modelo GLB.
  // En producción, cada glosa tendría su propia animación rigged.
  // Para el demo, se usan animaciones genéricas del modelo placeholder.
  static const _animationMap = <String, String>{
    'YO': 'Wave',
    'DENUNCIAR': 'Pointing',
    'ROBO': 'ThumbDown',
    'NECESITAR': 'Wave',
    'AYUDA': 'Wave',
    'GOLPEAR': 'Punch',
    'POLICIA': 'Pointing',
    'ABOGADO': 'Pointing',
    'DOCTOR': 'Wave',
    'HOMBRE': 'Idle',
    'MUJER': 'Idle',
    'CORRER': 'Running',
    'HUIR': 'Running',
    'MOCHILA': 'Idle',
    'CELULAR': 'Idle',
    'NOCHE': 'Idle',
    'CALLE': 'Walking',
    'PARADA': 'Idle',
    'URGENTE': 'Jump',
    'EMERGENCIA': 'Jump',
    'PELIGRO': 'Death',
  };

  String get _currentAnimation {
    if (_currentGlossIndex >= widget.glosses.length) return 'Idle';
    final gloss = widget.glosses[_currentGlossIndex].toUpperCase();
    return _animationMap[gloss] ?? 'Idle';
  }

  String get _currentGloss {
    if (_currentGlossIndex >= widget.glosses.length) return '';
    return widget.glosses[_currentGlossIndex];
  }

  void _playSequence() {
    setState(() {
      _currentGlossIndex = 0;
      _isPlaying = true;
    });
    _advanceAnimation();
  }

  void _advanceAnimation() {
    if (!_isPlaying || _currentGlossIndex >= widget.glosses.length) {
      setState(() => _isPlaying = false);
      return;
    }
    // Cada animación dura ~2 segundos, luego avanza
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted && _isPlaying) {
        setState(() => _currentGlossIndex++);
        _advanceAnimation();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    if (widget.autoPlay && widget.glosses.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 500), _playSequence);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        children: [
          // 3D viewer
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              child: ModelViewer(
                src: widget.modelSrc,
                alt: 'Avatar 3D de Lengua de Señas Boliviana',
                autoPlay: true,
                animationName: _currentAnimation,
                animationCrossfadeDuration: 300,
                cameraControls: false,
                disableZoom: true,
                autoRotate: false,
                backgroundColor: const Color(0xFF0D1117),
              ),
            ),
          ),

          // Progress bar & gloss indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF161B22),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
            ),
            child: Row(
              children: [
                // Play/replay button
                InkWell(
                  onTap: _playSequence,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _isPlaying ? Icons.replay : Icons.play_arrow,
                      size: 18,
                      color: const Color(0xFFFFD700),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Current gloss label
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isPlaying && _currentGloss.isNotEmpty
                            ? 'Seña: $_currentGloss'
                            : _isPlaying ? 'Completado' : 'Avatar 3D — Secuencia LSB',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Progress bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: widget.glosses.isEmpty
                              ? 0
                              : (_currentGlossIndex / widget.glosses.length).clamp(0.0, 1.0),
                          backgroundColor: const Color(0xFF30363D),
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
                          minHeight: 4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // Counter
                Text(
                  '${_currentGlossIndex.clamp(0, widget.glosses.length)}/${widget.glosses.length}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF8B949E),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
