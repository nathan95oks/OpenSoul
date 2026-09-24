# Contratos de datos propuestos

Propuesta de la fase de organización. **Ninguno está implementado.** Los tipos
se expresan en Dart porque es donde vivirán; el contrato de red se expresa en
JSON y debe validarse en ambos lados.

Principio rector: **un dato, un dueño**. Si el modo de uso vive en la sesión
de dispositivo, no se repite dentro del borrador; si el acto comunicativo vive
en el mensaje, no se deduce otra vez del propósito.

---

## 1. Modo de uso y sesión

```dart
enum UsageMode { personal, counter }

/// Configuración del dispositivo. Sobrevive a finalizar una atención.
class DeviceConfig {
  final UsageMode mode;
  final String? institutionProfileId;   // null en personal sin perfil
  final AppTabId lastTab;               // identificador estable, no índice
  final int schemaVersion;              // 1
}

/// Contenido de una atención o de una sesión personal. Se borra al finalizar.
class SessionContent {
  final String sessionId;
  final Conversation? conversation;
  final DeclarationDraft? draft;
  final List<PendingClarification> clarifications;
  final int schemaVersion;              // 1
}
```

**Regla C1.** Dos claves de almacenamiento distintas: `device_config_v1` y
`session_content_v1`. Hoy ambas cosas viven juntas en `session_snapshot_v1`.

**Regla C2 (migración).** Al leer `session_snapshot_v1`:
`tabIndex` → `lastTab` según `{0: conversation, 1: cards, 2: avatar}`;
`contextId`/`sentence`/`conversation` → `SessionContent`; `mode` ausente →
`personal`, porque es el uso que un dispositivo ya en marcha estaba teniendo.
La clave antigua se elimina tras migrar.

---

## 2. Identificadores de pestaña

```dart
enum AppTabId {
  cards('cards'),
  conversation('conversation'),
  avatar('avatar');

  final String id;   // lo que se persiste
  const AppTabId(this.id);
}

/// Orden visual, separado del orden de declaración del enum.
const List<AppTabId> kTabOrder = [
  AppTabId.cards,
  AppTabId.conversation,
  AppTabId.avatar,
];
```

**Regla C3.** Lo persistido es `id`, nunca `index`. El `IndexedStack` se
indexa con `kTabOrder.indexOf(tab)`, de modo que reordenar la barra no toca la
persistencia ni el enum.

---

## 3. Perfil institucional

```dart
class InstitutionProfile {
  final String id;                 // 'derechos_reales'
  final String name;
  final String? unitId;            // 'felcc' dentro de 'policia'
  final String serviceType;
  final List<NeedId> priorityNeeds;
  final List<String> initialScopes;   // ids reales de context_catalog.dart
  final List<ProposedIntent> intents;
  final NameSource nameSource;        // official | toVerify | internal
}

enum NeedId { complaints, procedures, inquiries }   // denuncias/tramites/consultas
```

**Regla C4.** `initialScopes` se valida contra `context_catalog.dart`. Un
ámbito inexistente es error de configuración, no un aviso.
`tool/validate_business_config.py` ya lo comprueba.

**Regla C5.** `nameSource == toVerify` impide mostrar la denominación larga en
la interfaz hasta contrastarla con fuente oficial.

---

## 4. Propósito y acto comunicativo, separados

```dart
enum CardsFlowPurpose {
  standaloneIntervention,   // antes standaloneDeclaration
  conversationInitiative,
  conversationReply,
}

enum CommunicativeAct { statement, question, request, answer, instruction }
```

**Regla C6.** El lanzamiento transporta ambos:

```dart
class CardsFlowLaunch {
  final CardsFlowPurpose purpose;
  final CommunicativeAct intendedAct;   // NUEVO
  final NeedId? need;                   // NUEVO
  final String? intentId;               // NUEVO
  final String? institutionProfileId;   // NUEVO
  // ya existentes:
  final String? conversationId;
  final String? hearingTurnId;
  final String? hearingText;
  final SpeechAct hearingSpeechAct;
  final ContextSuggestion? suggestion;
  final String? activeContextId;
}
```

**Regla C7.** `standaloneIntervention` + `intendedAct = question` es una
combinación **válida y esperada** (Consultas en modo personal). Ningún
componente puede asumir que un propósito independiente produce una afirmación.

**Regla C8 (compatibilidad).** El propósito no se persiste hoy, así que el
renombrado no rompe sesiones. Si se persistiera, `"standaloneDeclaration"` se
lee como alias de entrada de `standaloneIntervention`; nunca se escribe.

---

## 5. Turno y conversación

```dart
class TurnRef {
  final String conversationId;
  final String turnId;
  final int messageVersion;   // NUEVO: sube si el turno se corrige
}
```

**Regla C9.** La respuesta transporta `TurnRef` completo más el sentido
confirmado y las aclaraciones pendientes. Si llega un turno nuevo durante la
edición, el `TurnRef` congelado manda. Ya implementado para
`conversationId`/`turnId`; `messageVersion` es nuevo.

---

## 6. Colección de hechos

El cambio de modelo más grande. Hoy `FactInfo.action` es un `String?` único
(`declaration_draft.dart:450`) y la segunda acción sobrescribe la primera.

```dart
enum ActorRole { suspect, victim, thirdParty, unknown }

class Fact {
  final String id;                 // estable, para editar o quitar uno solo
  final String action;             // ROBAR, ESCAPAR, ... del catálogo
  final ActorRole actorRole;       // tipado, ya no String libre
  final String? actorEntityId;     // referencia a la persona del borrador
  final List<String> objectEntityIds;
  final bool negated;
  final Certainty certainty;       // confirmed | uncertain | unknown
  final Map<String, String> details;
}

enum Certainty { confirmed, uncertain, unknown }

class DeclarationDraft {
  final List<Fact> facts;          // 0, 1 o 2 en «¿Qué ocurrió?»
  // ... resto igual
}
```

**Regla C10.** Hasta dos hechos en «¿Qué ocurrió?»; uno solo sigue siendo
válido.

**Regla C11.** Editar o quitar un hecho no toca los demás: por eso `Fact.id`.

**Regla C12.** El orden de la lista es orden de selección, **no** orden
temporal ni causal. Ningún generador puede derivar «primero X y luego Y».

**Regla C13.** Cancelar una aclaración deja el hecho sin registrar, no a
medias. Un `Fact` sin `actorRole` resuelto no entra en la colección.

**Regla C14.** `ESCAPAR` sin `ROBAR` no autoriza a redactar un robo. Esto es
hoy un defecto vivo del backend (`lambda_function.py:2226`).

---

## 7. Contrato de red

Ampliación del contrato v2 actual. Campos nuevos marcados **N**.

```json
{
  "contractVersion": 3,
  "context": "denuncia_robo",
  "cards": ["ROBAR", "CELULAR"],
  "speechAct": "statement",
  "replyToId": "1790…-3",
  "conversationId": "1790…",
  "messageVersion": 1,
  "usageMode": "counter",
  "institutionProfileId": "policia",
  "need": "complaints",
  "intentId": "ROBO_CELULAR",
  "declaration": {
    "facts": [
      {"id": "f1", "action": "ROBAR", "actorRole": "suspect",
       "objectEntityIds": ["o1"], "negated": false, "certainty": "confirmed"},
      {"id": "f2", "action": "ESCAPAR", "actorRole": "suspect",
       "objectEntityIds": [], "negated": false, "certainty": "confirmed"}
    ]
  }
}
```

**Regla C15 (nombres).** Una sola convención: `camelCase` en el JSON de red,
en cliente y backend. El desajuste actual `actorRole` (cliente) frente a
`actor_role` (backend, `lambda_function.py:2241`) hace que el campo nunca se
lea. Al migrar, el backend acepta ambos durante una versión y registra el uso
de la forma antigua.

**Regla C16 (sin puerta por contexto).** `uses_structured` no puede exigir
`context_type == "denuncia_robo"` (`lambda_function.py:2867`). Una declaración
estructurada es válida en cualquier contexto; si un contexto no sabe
redactarla, cae al camino determinista **y lo declara**, en vez de descartar
los campos en silencio.

**Regla C17 (validación en backend).** `usageMode`, `need`, `intentId`,
`institutionProfileId`, `actorRole` y `certainty` se validan contra conjuntos
cerrados. Un valor desconocido es 400, no un campo ignorado. La configuración
de interfaz no sustituye esta validación.

**Regla C18 (sin duplicar).** `need` e `intentId` no se repiten dentro de
`declaration`. `context` se conserva por compatibilidad v2; si `intentId`
viene, manda `intentId`.

---

## 8. Lo que este contrato NO hace

- No transporta datos personales del ciudadano fuera de la declaración que la
  propia persona confirmó.
- No transporta el perfil institucional como **contenido** del mensaje: es una
  señal de organización. El generador no puede escribir el nombre de la
  institución en la declaración porque venga en `institutionProfileId`.
- No añade ningún campo de conformidad, consentimiento ni aceptación.
