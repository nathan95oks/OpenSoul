import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:lsb_legal_app/app/navigation_provider.dart';
import 'package:lsb_legal_app/core/domain/entities/session_snapshot.dart';
import 'package:lsb_legal_app/core/domain/repositories/session_repository.dart';

/// Guarda la sesión en las preferencias del dispositivo.
///
/// Android puede matar el proceso en cuanto la aplicación pasa a segundo plano
/// —en un equipo con poca memoria, casi siempre—, y entonces al volver arranca
/// de cero. Guardar en memoria no sirve para eso: tiene que sobrevivir a la
/// muerte del proceso.
///
/// Dos claves y no una. En una ventanilla el dispositivo pasa de una persona a
/// la siguiente: hay que poder borrar lo que dijo la anterior sin perder la
/// configuración de la institución. Con una sola clave, «finalizar atención»
/// obligaba a elegir entre las dos cosas.
class SessionRepositoryImpl implements SessionRepository {
  static const _claveConfig = 'device_config_v1';
  static const _claveContenido = 'session_content_v1';

  /// Clave de la versión anterior, que mezclaba ambas cosas. Se lee una vez
  /// para migrar y se borra; nunca se vuelve a escribir.
  static const _claveLegado = 'session_snapshot_v1';

  final Future<SharedPreferences> Function() _preferences;

  SessionRepositoryImpl({Future<SharedPreferences> Function()? preferences})
      : _preferences = preferences ?? SharedPreferences.getInstance;

  Future<Map<String, dynamic>?> _leer(SharedPreferences prefs, String clave) {
    try {
      final crudo = prefs.getString(clave);
      if (crudo == null || crudo.isEmpty) return Future.value(null);
      final json = jsonDecode(crudo);
      return Future.value(json is Map ? Map<String, dynamic>.from(json) : null);
    } catch (_) {
      // Un dato ilegible es un dato que no hay: se empieza limpio en vez de
      // impedir que la aplicación abra.
      return Future.value(null);
    }
  }

  /// Traslada la clave antigua a las dos nuevas, una sola vez.
  ///
  /// El `tabIndex` era posicional con el orden anterior —0 conversación,
  /// 1 tarjetas, 2 avatar—, que ya no coincide con el orden visual. Leerlo
  /// como posición abriría otro módulo, así que se traduce por identificador.
  Future<void> _migrarSiHaceFalta(SharedPreferences prefs) async {
    final legado = await _leer(prefs, _claveLegado);
    if (legado == null) return;

    if (prefs.getString(_claveConfig) == null) {
      final tab = AppTabId.fromLegacyIndex((legado['tabIndex'] as num?)?.toInt());
      await prefs.setString(
        _claveConfig,
        jsonEncode(DeviceConfig(
          // Un dispositivo que ya estaba en marcha se venía usando en
          // personal: es el uso que existía antes de que hubiera modos.
          mode: UsageMode.personal,
          lastTabId: tab?.id,
        ).toJson()),
      );
    }

    if (prefs.getString(_claveContenido) == null) {
      await prefs.setString(
        _claveContenido,
        jsonEncode(SessionContent.fromJson(legado).toJson()),
      );
    }

    await prefs.remove(_claveLegado);
  }

  @override
  Future<DeviceConfig> loadConfig() async {
    try {
      final prefs = await _preferences();
      await _migrarSiHaceFalta(prefs);
      final json = await _leer(prefs, _claveConfig);
      return json == null ? DeviceConfig.empty : DeviceConfig.fromJson(json);
    } catch (_) {
      return DeviceConfig.empty;
    }
  }

  @override
  Future<void> saveConfig(DeviceConfig config) async {
    try {
      final prefs = await _preferences();
      await prefs.setString(_claveConfig, jsonEncode(config.toJson()));
    } catch (_) {
      // Perder la continuidad es molesto; impedir que la persona siga
      // declarando, no. Un fallo al guardar no interrumpe nada.
    }
  }

  @override
  Future<SessionContent?> loadContent() async {
    try {
      final prefs = await _preferences();
      await _migrarSiHaceFalta(prefs);
      final json = await _leer(prefs, _claveContenido);
      return json == null ? null : SessionContent.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveContent(SessionContent content) async {
    try {
      final prefs = await _preferences();
      await prefs.setString(_claveContenido, jsonEncode(content.toJson()));
    } catch (_) {}
  }

  @override
  Future<void> clearContent() async {
    try {
      final prefs = await _preferences();
      await prefs.remove(_claveContenido);
    } catch (_) {}
  }

  @override
  Future<void> clearAll() async {
    try {
      final prefs = await _preferences();
      await prefs.remove(_claveContenido);
      await prefs.remove(_claveConfig);
      await prefs.remove(_claveLegado);
    } catch (_) {}
  }
}
