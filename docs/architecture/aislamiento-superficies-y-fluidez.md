# Aislamiento de superficies y fluidez conversacional

**Fecha:** 2026-08-03 · **Sobre:** [fase-4-contexto-conversacional.md](fase-4-contexto-conversacional.md)

> No es una fase del roadmap —la Fase 5 es el portal web de validación— sino
> una corrección de dos problemas que la Fase 4 destapó al poner la
> conversación en el centro de la app.

## Objetivo

Dos cosas que la Fase 4 dejó abiertas al convertir la conversación en el centro
de la app:

1. **Aislamiento.** La conversación integra los dos módulos de traducción, pero
   cada uno sigue existiendo como herramienta suelta. Compartir el
   `ProviderScope` raíz hacía que compartieran también *sesión*.
2. **Fluidez.** Un turno del oyente no existía hasta que Bedrock contestaba, así
   que el camino crítico de la conversación incluía un viaje de red completo.

## Problema 1 — El estado se colaba entre superficies

`MainNavigationScreen` monta las tres pantallas en un `IndexedStack`, y las tres
leen los mismos providers globales (`sentenceProvider`, `contextProvider`,
`semanticZonesProvider`, `translationControllerProvider`,
`audioTranslationControllerProvider`). Consecuencias observadas:

- Una respuesta a medio construir dentro de un turno reaparecía en la pestaña
  "Tarjetas LSB".
- `pendingReplyProvider` estaba sobrescrito de forma global: la pestaña
  autónoma mostraba la franja «respondiendo a…» y **enrutaba su recorrido de
  zonas** por una pregunta que nadie le había hecho.
- El módulo del avatar conservaba la última traducción entre visitas.
- Al revés: lo construido como herramienta suelta podía terminar enviado a la
  conversación con "Enviar a la conversación".

### Diseño implementado

**`core/session/flow_surface.dart` — `FlowSurface`**
Declara desde qué superficie se está usando la app: `conversation`,
`standaloneCards`, `standaloneAvatar`. Vive en el núcleo porque lo consulta
`pendingReplyProvider`, pero **no sabe limpiar nada**.

**`app/surface_session.dart` — `SurfaceSession`**
La raíz de composición (única capa autorizada a conocer los tres módulos, ver
`test/module_boundaries_test.dart`) aplica una regla deliberadamente simple:

> **Los módulos de traducción no guardan nada entre superficies; solo la
> conversación tiene memoria.**

Limpiar únicamente al *entrar* en una pestaña autónoma dejaría la fuga
invertida, así que el estado se descarta en **cada cruce**. El orden importa: la
superficie se fija antes de limpiar, porque el recorrido de zonas se reconstruye
a partir de `pendingReplyProvider`, que depende de ella.

**`CardsFlowSession`** (`lsb_to_text_audio/presentation/providers/`)
La secuencia de limpieza estaba copiada en tres pantallas ("Cambiar contexto",
"Nueva declaración", "Enviar a la conversación") y ninguna copia reponía la
categoría del filtro avanzado. Al no existir una sola operación de «empezar
limpio», tampoco había forma de invocarla al cambiar de superficie — que es
justo cuando más falta hacía. `reset(keepContext:)` cubre los dos matices.

**`pendingReplyProvider`** devuelve `null` fuera de la conversación, y
"Enviar a la conversación" solo aparece cuando el flujo sirve a un diálogo.

### Precio asumido

Salir de la conversación a una pestaña autónoma **descarta una respuesta a medio
construir**. Se prefiere a la alternativa —que reaparezca donde no
corresponde—: una respuesta que se cuela en otro contexto no es un
inconveniente, es una declaración falsa. El historial de la conversación nunca
se toca.

## Problema 2 — El camino crítico incluía a Bedrock

Antes, `sendHearingMessage` esperaba la respuesta remota **antes** de añadir el
turno. Durante ese tiempo (1–3 s típicos):

- no había burbuja en el hilo,
- no había `pendingReply`, así que el botón "Responder con tarjetas" no llevaba
  a ninguna pregunta concreta,
- la persona sorda no podía empezar a responder **aunque ya hubiera entendido
  la pregunta**.

Ese tiempo muerto estaba en el centro de la conversación, no en un borde.

### Diseño implementado

**Turno inmediato (`ConversationEngine.draftHearingTurn`).**
El turno entra en el hilo al instante, marcado `pending`, con el contexto ya
inferido **en local**: `ContextInferenceEngine` acepta el texto en español como
señal, así que el enrutado a la pregunta concreta funciona sin esperar a las
glosas — y sin red. Cuando la traducción llega,
`translateHearingTurn` completa **el mismo turno** (`Conversation.replaceTurn`,
que conserva id y posición) y sustituye la inferencia por la calculada sobre
las glosas, que es más fiable.

Si el backend cae, el turno se queda: lo dicho se dijo, y con el contexto
deducido en local todavía se puede responder. Antes el enunciado desaparecía
del hilo por completo.

**Caché de sesión (`CachingAudioTranslationRepository`).**
Una toma de declaración repite las mismas preguntas constantemente. Decorador
sobre el repositorio, con clave `(texto normalizado, situación)` — la misma que
ya calcula `generate_cache_key` en `lambda_text_to_lsb.py`, cuya caché en
DynamoDB sigue declarada como trabajo futuro. Las traducciones vacías no se
recuerdan: cachear un fallo del modelo lo congelaría toda la sesión.

**Timeout en el datasource de señas.**
`RemoteAudioDataSourceImpl.translateText` no tenía ninguno, a diferencia del
datasource de declaración (RDS-01). Una petición colgada dejaba la conversación
en «Traduciendo a señas…» *para siempre*: `processing` no bajaba nunca y no se
podía ni reintentar ni escribir otra cosa. Ahora corta a los 12 s, igual que su
gemelo.

**Indicador por turno.** El aviso global de «Traduciendo a señas…» se retiró: con
el turno ya visible, sugería que la conversación estaba bloqueada cuando en
realidad ya se podía responder. Ahora lo dice la propia burbuja.

## Verificación

- `flutter analyze`: 0 errores/warnings · `flutter test`: **132/132** (eran 117).
- `flutter build apk --debug`: OK.
- Pruebas nuevas:
  - `test/module_isolation_test.dart` (7) — aislamiento en ambos sentidos y
    conservación del historial. Comprobado que **4 de ellas fallan** si se
    neutraliza el arreglo, es decir, auditan comportamiento real.
  - `test/conversation_fluidity_test.dart` (8) — turno visible y respondible
    antes de la traducción, completado sin duplicar, degradación sin red,
    caché por `(texto, situación)` y corte por timeout.

## Deuda declarada

1. La caché es **por sesión y en memoria**: se pierde al cerrar la app. La
   caché persistente sigue correspondiendo a DynamoDB en la Lambda.
2. El aislamiento se consigue descartando estado en cada cruce de superficie.
   La alternativa —un `ProviderScope` anidado por pestaña— no encaja hoy porque
   las pantallas de resultado se abren como rutas de `GoRouter`, fuera del
   subárbol de la pestaña, y leerían providers de otro ámbito.
3. `composeHearingTurn` se conserva como composición de borrador + traducción
   para los consumidores existentes; la app real usa las dos mitades por
   separado.
