import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/generators/sign_image/sign_image_resolver.dart';

/// Resolutor de imágenes de señas, inyectable para pruebas.
final signImageResolverProvider = Provider<SignImageResolver>(
  (ref) => const SignImageResolver(),
);

const _clavePreferencia = 'lsb.mostrarImagenesDeSenas';

/// Si las tarjetas muestran la imagen de la seña sobre la palabra.
///
/// Empieza activado porque la imagen es la vía de entrada natural del módulo,
/// pero se puede apagar: quien ya reconoce las señas lee más rápido una
/// cuadrícula de palabras, y con la imagen caben menos tarjetas en pantalla.
///
/// La preferencia se recuerda entre sesiones. Cambiarla en cada arranque es
/// justo la fricción que el ajuste pretende quitar.
class SignImagesNotifier extends Notifier<bool> {
  @override
  bool build() {
    _restaurar();
    return true;
  }

  Future<void> _restaurar() async {
    final prefs = await SharedPreferences.getInstance();
    final guardada = prefs.getBool(_clavePreferencia);
    if (guardada != null && guardada != state) state = guardada;
  }

  Future<void> alternar() async {
    state = !state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_clavePreferencia, state);
  }
}

final signImagesEnabledProvider =
    NotifierProvider<SignImagesNotifier, bool>(SignImagesNotifier.new);
