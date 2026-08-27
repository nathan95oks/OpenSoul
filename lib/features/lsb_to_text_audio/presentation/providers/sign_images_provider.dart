import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lsb_legal_app/features/lsb_to_text_audio/data/datasources/sign_image_resolver.dart';

final signImageResolverProvider = Provider<SignImageResolver>(
  (ref) => const SignImageResolver(),
);

const _clavePreferencia = 'lsb.mostrarImagenesDeSenas';

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
