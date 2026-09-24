import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lsb_legal_app/app/navigation_provider.dart';
import 'package:lsb_legal_app/core/data/repositories/session_repository_impl.dart';
import 'package:lsb_legal_app/core/domain/entities/session_snapshot.dart';

/// Orden de la barra, identificadores estables y separación de almacenes.
///
/// La versión anterior persistía la posición de la pestaña (`0` conversación,
/// `1` tarjetas, `2` avatar) y sacaba el orden visual de una lista paralela.
/// Reordenar la barra hacía que una sesión guardada reabriera otro módulo sin
/// que nada lo avisara. Y guardaba configuración y contenido en la misma
/// clave, así que en una ventanilla no se podía limpiar al ciudadano anterior
/// sin perder el perfil de la institución.
SessionRepositoryImpl _repo() =>
    SessionRepositoryImpl(preferences: SharedPreferences.getInstance);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('orden de la barra inferior', () {
    test('Tarjetas a la izquierda, Conversación al centro, Voz a la derecha',
        () {
      expect(kTabOrder, [AppTabId.cards, AppTabId.conversation, AppTabId.avatar]);
      expect(visualIndexOf(AppTabId.conversation), 1,
          reason: 'Conversación va en el centro en ambos modos de uso.');
    });

    test('el orden del enum no es el orden visual', () {
      // Se declaran en distinto orden a propósito: si alguien vuelve a
      // indexar por `AppTabId.index`, la pantalla se desalinea de inmediato
      // en vez de funcionar por casualidad hasta el siguiente reordenamiento.
      expect(visualIndexOf(AppTabId.cards), isNot(AppTabId.cards.index));
      expect(visualIndexOf(AppTabId.conversation),
          isNot(AppTabId.conversation.index));
    });

    test('los identificadores son estables y legibles', () {
      // Se comprueban como conjunto: el orden de declaración es libre y no
      // debe significar nada.
      expect(AppTabId.values.map((t) => t.id).toSet(),
          {'cards', 'conversation', 'avatar'});
      expect(kTabOrder.map((t) => t.id),
          ['cards', 'conversation', 'avatar'],
          reason: 'El orden visual sí es el de la barra.');
      expect(AppTabId.byId('conversation'), AppTabId.conversation);
      expect(AppTabId.byId('inventada'), isNull);
      expect(AppTabId.byId(null), isNull);
    });
  });

  group('migración de la pestaña persistida', () {
    test('los índices antiguos abren el módulo correcto, no el de su posición',
        () {
      // El orden anterior era conversación, tarjetas, avatar.
      expect(AppTabId.fromLegacyIndex(0), AppTabId.conversation);
      expect(AppTabId.fromLegacyIndex(1), AppTabId.cards);
      expect(AppTabId.fromLegacyIndex(2), AppTabId.avatar);
      expect(AppTabId.fromLegacyIndex(7), isNull);
      expect(AppTabId.fromLegacyIndex(null), isNull);
    });

    test('un índice antiguo de tarjetas no abre la conversación', () {
      // Con el orden nuevo, la posición 1 es conversación. Leer el índice
      // guardado como posición habria abierto el módulo equivocado.
      final migrado = AppTabId.fromLegacyIndex(1);
      expect(migrado, AppTabId.cards);
      expect(migrado, isNot(kTabOrder[1]));
    });

    test('una sesión guardada con el esquema anterior se migra al abrir',
        () async {
      SharedPreferences.setMockInitialValues({
        'session_snapshot_v1': jsonEncode({
          'tabIndex': 1, // tarjetas, en el orden antiguo
          'contextId': 'denuncia_robo',
          'sentence': ['ROBAR', 'CELULAR'],
          'resultVisible': false,
          'conversation': null,
        }),
      });

      final repo = _repo();
      final config = await repo.loadConfig();
      final content = await repo.loadContent();

      expect(config.lastTabId, AppTabId.cards.id);
      expect(config.mode, UsageMode.personal,
          reason: 'Un dispositivo ya en marcha se venía usando en personal.');
      expect(content!.contextId, 'denuncia_robo');
      expect(content.sentence, ['ROBAR', 'CELULAR']);

      // La clave antigua se retira para no migrar dos veces.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('session_snapshot_v1'), isNull);
    });

    test('una sesión ilegible no impide abrir la aplicación', () async {
      SharedPreferences.setMockInitialValues({
        'device_config_v1': 'esto no es json',
        'session_content_v1': '{{{',
      });

      final repo = _repo();
      await expectLater(repo.loadConfig(), completion(isA<DeviceConfig>()));
      await expectLater(repo.loadContent(), completion(isNull));
    });
  });

  group('configuración y contenido se guardan por separado', () {
    test('finalizar atención borra lo dicho y conserva la institución',
        () async {
      final repo = _repo();
      await repo.saveConfig(const DeviceConfig(
        mode: UsageMode.counter,
        institutionProfileId: 'derechos_reales',
        lastTabId: 'conversation',
      ));
      await repo.saveContent(const SessionContent(
        contextId: 'denuncia_robo',
        sentence: ['ROBAR'],
      ));

      await repo.clearContent();

      final config = await repo.loadConfig();
      expect(config.mode, UsageMode.counter);
      expect(config.institutionProfileId, 'derechos_reales',
          reason: 'El perfil de la institución no es dato del ciudadano.');
      expect(await repo.loadContent(), isNull,
          reason: 'Lo que dijo la persona anterior no puede seguir ahí.');
    });

    test('clearAll sí se lleva la configuración', () async {
      final repo = _repo();
      await repo.saveConfig(const DeviceConfig(mode: UsageMode.personal));
      await repo.clearAll();
      expect((await repo.loadConfig()).mode, isNull);
    });

    test('sin nada guardado no hay modo elegido', () async {
      final config = await _repo().loadConfig();
      expect(config.hasMode, isFalse,
          reason: 'Al entrar por primera vez toca el selector de modo.');
    });

    test('el contenido vacío no merece restaurarse', () {
      expect(SessionContent.empty.isWorthRestoring, isFalse);
      expect(const SessionContent(contextId: 'denuncia_robo').isWorthRestoring,
          isTrue);
    });
  });
}
