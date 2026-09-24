import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lsb_legal_app/core/di/injection.dart';
import 'package:lsb_legal_app/core/domain/entities/session_snapshot.dart';

/// Cómo se está usando la aplicación ahora mismo.
///
/// Es una decisión de la persona, no algo que se infiera: ni del tamaño de la
/// pantalla, ni de una discapacidad supuesta del propietario, ni de quién
/// hablara primero. Se pregunta al entrar y se puede cambiar desde un control
/// visible.
class UsageSession {
  final UsageMode? mode;
  final String? institutionProfileId;

  /// `true` mientras no se haya leído la configuración guardada: la pantalla
  /// no debe decidir nada todavía.
  final bool loading;

  const UsageSession({
    this.mode,
    this.institutionProfileId,
    this.loading = true,
  });

  bool get needsSelection => !loading && mode == null;
  bool get isCounter => mode == UsageMode.counter;
  bool get isPersonal => mode == UsageMode.personal;

  UsageSession copyWith({
    UsageMode? mode,
    String? institutionProfileId,
    bool? loading,
    bool clearMode = false,
    bool clearInstitution = false,
  }) =>
      UsageSession(
        mode: clearMode ? null : (mode ?? this.mode),
        institutionProfileId: clearInstitution
            ? null
            : (institutionProfileId ?? this.institutionProfileId),
        loading: loading ?? this.loading,
      );
}

class UsageSessionNotifier extends Notifier<UsageSession> {
  @override
  UsageSession build() {
    _cargar();
    return const UsageSession();
  }

  Future<void> _cargar() async {
    final config = await ref.read(sessionRepositoryProvider).loadConfig();
    state = UsageSession(
      mode: config.mode,
      institutionProfileId: config.institutionProfileId,
      loading: false,
    );
  }

  /// Elige el modo y lo deja guardado.
  ///
  /// Cambiar de modo **no** arrastra el contenido de la sesión anterior: lo
  /// que se dijo en una atención no tiene por qué seguir ahí cuando el
  /// dispositivo vuelve a ser personal, ni al revés.
  Future<void> choose(UsageMode mode, {String? institutionProfileId}) async {
    final repo = ref.read(sessionRepositoryProvider);
    final anterior = state.mode;

    state = UsageSession(
      mode: mode,
      institutionProfileId: institutionProfileId ?? state.institutionProfileId,
      loading: false,
    );

    final config = await repo.loadConfig();
    await repo.saveConfig(config.copyWith(
      mode: mode,
      institutionProfileId: institutionProfileId,
    ));

    if (anterior != null && anterior != mode) {
      await repo.clearContent();
    }
  }

  Future<void> setInstitution(String? profileId) async {
    state = state.copyWith(
      institutionProfileId: profileId,
      clearInstitution: profileId == null,
    );
    final repo = ref.read(sessionRepositoryProvider);
    final config = await repo.loadConfig();
    await repo.saveConfig(config.copyWith(
      institutionProfileId: profileId,
      clearInstitution: profileId == null,
    ));
  }

  /// Vuelve al selector sin borrar nada todavía.
  ///
  /// Lo que se dijo sigue guardado: si la persona vuelve al mismo modo, se
  /// reanuda. Solo se descarta al elegir un modo distinto, en [choose].
  void reopenSelection() =>
      state = state.copyWith(clearMode: true, loading: false);
}

final usageSessionProvider =
    NotifierProvider<UsageSessionNotifier, UsageSession>(
  UsageSessionNotifier.new,
);
