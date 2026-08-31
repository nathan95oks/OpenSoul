import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Si el módulo está mostrando la declaración terminada o el armado de tarjetas.
///
/// El resultado era una ruta empujada sobre el `MainNavigationScreen`, así que
/// tapaba la barra inferior: al llegar ahí no se podía saltar a otro módulo ni
/// cambiar de contexto sin deshacer el trabajo. Es un paso del flujo, no un
/// destino de la aplicación, y por eso pasa a ser un estado dentro de la
/// pestaña en lugar de una pantalla encima de todo.
class ResultVisibilityNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void show() => state = true;

  void hide() => state = false;
}

final resultVisibleProvider =
    NotifierProvider<ResultVisibilityNotifier, bool>(
  ResultVisibilityNotifier.new,
);
