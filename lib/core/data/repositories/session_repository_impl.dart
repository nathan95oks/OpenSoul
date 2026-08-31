import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:lsb_legal_app/core/domain/entities/session_snapshot.dart';
import 'package:lsb_legal_app/core/domain/repositories/session_repository.dart';

/// Guarda la sesión en las preferencias del dispositivo.
///
/// Android puede matar el proceso en cuanto la aplicación pasa a segundo plano
/// —en un equipo con poca memoria, casi siempre—, y entonces al volver arranca
/// de cero. Guardar en memoria no sirve para eso: tiene que sobrevivir a la
/// muerte del proceso.
class SessionRepositoryImpl implements SessionRepository {
  static const _clave = 'session_snapshot_v1';

  final Future<SharedPreferences> Function() _preferences;

  SessionRepositoryImpl({Future<SharedPreferences> Function()? preferences})
      : _preferences = preferences ?? SharedPreferences.getInstance;

  @override
  Future<SessionSnapshot?> load() async {
    try {
      final prefs = await _preferences();
      final crudo = prefs.getString(_clave);
      if (crudo == null || crudo.isEmpty) return null;
      final json = jsonDecode(crudo);
      if (json is! Map) return null;
      return SessionSnapshot.fromJson(Map<String, dynamic>.from(json));
    } catch (_) {
      // Una sesión ilegible es una sesión que no hay: se empieza limpio en vez
      // de impedir que la aplicación abra.
      return null;
    }
  }

  @override
  Future<void> save(SessionSnapshot snapshot) async {
    try {
      final prefs = await _preferences();
      await prefs.setString(_clave, jsonEncode(snapshot.toJson()));
    } catch (_) {
      // Perder la continuidad es molesto; impedir que la persona siga
      // declarando, no. Un fallo al guardar no interrumpe nada.
    }
  }

  @override
  Future<void> clear() async {
    try {
      final prefs = await _preferences();
      await prefs.remove(_clave);
    } catch (_) {}
  }
}
