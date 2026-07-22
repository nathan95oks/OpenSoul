# Fase 3 — Propuestas de la comunidad

**Fecha:** 2026-07-22 · **Rama:** Update1 · **Fases previas:** [Fase 1](fase-1-nucleo-conversacional.md) · [Fase 2](fase-2-diccionario-evolutivo.md)

## Objetivo

Que el diccionario deje de depender de desarrolladores: cuando una palabra
o seña no exista, cualquier usuario puede proponerla desde la app. La
propuesta queda `pending` en el backend (que la Fase 2 ya aceptaba) y espera
la revisión de validadores no técnicos en el Portal Web (Fase 4). Nunca
modifica el diccionario oficial ni el comunitario.

## Qué se implementó

### Dominio (`core/dictionary/domain`)

- **`DictionaryProposal`**: palabra, significado/descripción, categoría
  sugerida, contextos donde surgió la necesidad, video (URL), dialecto y
  nombre libre del proponente. Serializa al contrato de
  `POST /dictionary/proposals`.
- **`ProposalSubmissionResult`**: `sent | queued | failed` — todo desenlace
  es explícito; nada falla en silencio.
- `LexiconRepository` gana `submitProposal(...)`; `refresh()` además
  reintenta la cola offline.

### Datos (`core/dictionary/data`)

- **`ProposalOutbox`** (patrón outbox): cola en disco de propuestas
  redactadas sin conexión. Regla central: **una propuesta escrita nunca se
  pierde** — si no hay red se persiste y se reenvía sola en la próxima
  sincronización (al `refresh()` de fondo del arranque o antes del próximo
  envío). Solo si fallan red Y disco se devuelve `failed` y la UI pide
  reintentar.
- `RemoteLexiconDataSource.postProposal(...)` → `POST <apiUrl>/proposals`.

### UI (`features/dictionary_proposals`)

- **`ProposeSignSheet`**: formulario modal (palabra*, significado*, categoría
  sugerida desde el propio lexicón, video-URL y nombre opcionales). Informa
  el desenlace con verdad: "enviada", "guardada, se enviará sola" o error.
- **Puntos de entrada:**
  1. Flujo de tarjetas (`HomeScreen`, AppBar): "Proponer palabra o seña",
     pre-llenando el contexto situacional activo.
  2. **Hoja del avatar** (`AvatarPlaybackSheet`): las glosas que el avatar
     tuvo que deletrear (sin animación, URLs `placeholder://`) aparecen como
     chips "Sin seña — proponla", pre-llenando la palabra. Es el circuito de
     retroalimentación clave: cada carencia real detectada en una
     conversación se convierte en una propuesta a un toque.

## Ciclo completo (estado tras esta fase)

```
Conversación → el avatar deletrea una palabra          (detección)
→ chip "proponer" → ProposeSignSheet                   (captura)
→ submitProposal → sent | queued(outbox) → PENDING     (esta fase) ✅
→ Portal Web: revisar, editar, probar avatar, aprobar  (Fase 4) ⏳
→ ENTRY community/official + META.version++            (Fase 4) ⏳
→ app refresh() ve versión mayor → palabra disponible  (ya operativo, Fase 2) ✅
→ lambda_text_to_lsb lee la tabla → el avatar la seña  (ya operativo, Fase 2) ✅
```

## Decisiones y deuda declarada

1. **Official vs Community:** la app ya muestra entradas `community` y el
   contrato las transporta; decidir si una aprobación entra como `community`
   u `official` es política del portal (Fase 4), no de la app.
2. **Video de la seña:** el contrato transporta `videoUrl`; la grabación
   dentro de la app (cámara + subida a S3 presignada) queda para una
   iteración posterior — no bloquea el ciclo de validación, porque el portal
   podrá adjuntar/reemplazar el video.
3. **Sin cuentas de usuario:** `proposedBy` es texto libre opcional. La
   identidad/reputación de proponentes llegará con el portal.
4. La IA asistente (duplicados, sugerencia de glosas/contexto, prioridad)
   pertenece al portal (Fase 4); el backend ya almacena todo lo necesario.

## Verificación

- `flutter analyze`: 0 errores/warnings.
- `flutter test`: 68/68 — incluye 7 pruebas nuevas del ciclo de propuestas:
  envío directo, cola sin red, cola sin endpoint, reenvío en `refresh()`,
  permanencia en cola ante fallo parcial, desenlace `failed` y round-trip
  JSON del outbox.
