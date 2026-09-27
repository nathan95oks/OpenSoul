import 'package:lsb_legal_app/core/domain/repositories/session_repository.dart';

/// Registra la apertura y decide si corresponde mostrar la bienvenida.
///
/// La pestaña y los borradores tienen su propio ciclo de vida. Esta marca solo
/// evita repetir el splash después de la primera ejecución del dispositivo.
Future<bool> prepareAppLaunch(SessionRepository repository) async {
  final config = await repository.loadConfig();
  if (config.hasOpened) return false;
  await repository.saveConfig(config.copyWith(hasOpened: true));
  return true;
}
