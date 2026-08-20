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
class SignImage extends ConsumerWidget {
  final String gloss;
  final String semanticIcon;
  final double size;
  final Color color;

  const SignImage({
    super.key,
    required this.gloss,
    required this.semanticIcon,
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = ref.watch(signImagesEnabledProvider)
        ? ref.watch(signImageResolverProvider).urlFor(gloss)
        : null;

    if (url == null) return _icono();

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CachedNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        fit: BoxFit.contain,
        // El hueco mientras descarga tiene el tamaño final: sin esto la
        // cuadrícula se recoloca sola al llegar cada imagen.
        placeholder: (context, url) => SizedBox(
          width: size,
          height: size,
          child: Center(
            child: SizedBox(
              width: size * 0.3,
              height: size * 0.3,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: color.withValues(alpha: 0.4),
              ),
            ),
          ),
        ),
        errorWidget: (context, url, error) => _icono(),
      ),
    );
  }

  Widget _icono() => Icon(
        kLsbIconMap[semanticIcon] ?? Icons.circle_outlined,
        size: size * 0.55,
        color: color,
      );
}
