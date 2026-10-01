import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Las imágenes de señas (S3) están desactivadas: las tarjetas muestran
/// su emoji/icono semántico. Nada vuelve a activarlas.
class SignImagesNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  Future<void> alternar() async {}
}

final signImagesEnabledProvider =
    NotifierProvider<SignImagesNotifier, bool>(SignImagesNotifier.new);
