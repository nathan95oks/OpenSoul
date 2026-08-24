import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/sign_images_provider.dart';
import 'lsb_icons.dart';

/// Imagen de la seña de una glosa, con el ícono como respaldo.
///
/// Nunca deja hueco ni rompe la tarjeta: si la preferencia está apagada, si no
/// hay almacén configurado o si el archivo no existe en él, se dibuja el ícono
/// que la tarjeta ya usaba. Una seña sin fotografía sigue siendo seleccionable
/// —el módulo tiene que funcionar con el catálogo incompleto que hay hoy.
///
/// Cuando la seña tiene movimiento son varias fotografías y se alternan en
/// bucle. Una sola imagen dejaría fuera justo el parámetro que la distingue de
/// otra seña con la misma configuración manual, y mostrar la primera parte de
/// un movimiento como si fuera la seña entera enseña mal la seña.
class SignImage extends ConsumerStatefulWidget {
  final String gloss;
  final String semanticIcon;
  final int frames;
  final double size;
  final Color color;

  const SignImage({
    super.key,
    required this.gloss,
    required this.semanticIcon,
    required this.size,
    required this.color,
    this.frames = 1,
  });

  @override
  ConsumerState<SignImage> createState() => _SignImageState();
}

class _SignImageState extends ConsumerState<SignImage> {
  /// Ritmo del bucle. Bastante lento para distinguir cada posición de la mano
  /// y bastante rápido para que se lea como un movimiento y no como dos
  /// tarjetas parpadeando.
  static const _porFotograma = Duration(milliseconds: 900);

  Timer? _timer;
  int _actual = 0;

  @override
  void didUpdateWidget(SignImage anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.gloss != widget.gloss || anterior.frames != widget.frames) {
      _actual = 0;
      _reprogramar();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _reprogramar() {
    _timer?.cancel();
    if (widget.frames <= 1) return;
    _timer = Timer.periodic(_porFotograma, (_) {
      if (mounted) setState(() => _actual = (_actual + 1) % widget.frames);
    });
  }

  @override
  Widget build(BuildContext context) {
    final urls = ref.watch(signImagesEnabledProvider)
        ? ref
            .watch(signImageResolverProvider)
            .urlsFor(widget.gloss, frames: widget.frames)
        : const <String>[];

    if (urls.isEmpty) return _icono();
    if (urls.length > 1 && _timer == null) {
      // Se arranca aquí y no en initState porque hasta este punto no se sabe
      // si la preferencia está encendida ni si hay almacén configurado.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _reprogramar();
      });
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: CachedNetworkImage(
            // La clave incluye el fotograma: sin ella AnimatedSwitcher trata
            // todas las imágenes como el mismo widget y no hay transición.
            key: ValueKey(urls[_actual % urls.length]),
            imageUrl: urls[_actual % urls.length],
            width: widget.size,
            height: widget.size,
            fit: BoxFit.contain,
            // El hueco mientras descarga tiene el tamaño final: sin esto la
            // cuadrícula se recoloca sola al llegar cada imagen.
            placeholder: (context, url) => Center(
              child: SizedBox(
                width: widget.size * 0.3,
                height: widget.size * 0.3,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: widget.color.withValues(alpha: 0.4),
                ),
              ),
            ),
            errorWidget: (context, url, error) => _icono(),
          ),
        ),
      ),
    );
  }

  Widget _icono() => Icon(
        kLsbIconMap[widget.semanticIcon] ?? Icons.circle_outlined,
        size: widget.size * 0.55,
        color: widget.color,
      );
}
