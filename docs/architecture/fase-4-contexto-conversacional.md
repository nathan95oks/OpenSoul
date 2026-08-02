# Fase 4 — Contexto conversacional: comunicación real entre módulos

**Fecha:** 2026-08-02 · **Rama:** Update1

## Objetivo

Cerrar el ciclo que la Fase 1 dejó a medias. Tras aquella fase ambos módulos ya
compartían `Conversation` y `ConversationEngine`, pero **el turno de la persona
oyente moría en el avatar**: su frase no llegaba al módulo de tarjetas, y la
persona sorda tenía que declarar el contexto desde cero como si no hubiera
habido pregunta.

Esta fase hace que **cada turno condicione al siguiente**, que es lo que
distingue una conversación de dos módulos compartiendo pantalla.

## Problemas que corrige esta fase

| # | Problema | Corrección |
|---|---|---|
| P7 | `Conversation.activeContextId` existía desde la Fase 1 pero **ningún consumidor lo usaba** (0 referencias en `lib/` y `test/`) | Se consume al abrir el flujo de tarjetas, junto con el contexto inferido del enunciado |
| P8 | El contexto enviado a Bedrock estaba **fijo en `'legal'`**: el motor remoto no sabía de qué se hablaba | Nuevo campo `situation` con el contexto vigente de la conversación |
| P9 | La **desambiguación se descartaba**: el lambda la calculaba y el datasource la tiraba | Se conserva en `SemanticMessage.disambiguations` y se muestra en la burbuja |
| P10 | El catálogo de contextos vivía en la capa de presentación de un feature, inaccesible para el núcleo | Promovido a `core/engines/context_engine/context_catalog.dart`, re-exportado desde su ubicación histórica |
| P11 | (Backend) Si `context` no era exactamente `"legal"`, **se perdían en silencio todas las reglas de desambiguación de "LLAMA"** | Las reglas jurídicas pasan a ser el comportamiento por defecto del dominio |
| P12 | El título de la AppBar del flujo de tarjetas **desbordaba 4 px** (franja de depuración a la vista) al coincidir la flecha de volver con las dos acciones | Título `Flexible` con elipsis y etiqueta de acción más corta |

## Inferencia de contexto: dirigida por datos, no por palabras clave

`ContextInferenceEngine` (`core/engines/context_engine/`) deduce de qué se habla
sin ninguna lista de palabras escrita a mano. El corpus es el propio diccionario
evolutivo, donde cada entrada ya declara sus contextos (`LsbCard.contexts`).

Cada glosa se pondera por su **poder discriminativo (IDF)**:

```
peso(glosa) = ln( nº de contextos / nº de contextos que contienen la glosa )
```

- `HOMBRE`, `MUJER` — presentes en los 5 contextos → peso **0**, no informan.
- `ROBAR`, `PEGAR`, `TRAMITAR` — exclusivas de un contexto → peso máximo, deciden.

Los contextos de tarjeta que no son contextos de UI (`tramite_id`, `perdida`)
se resuelven a su contexto padre reutilizando `cardSourceContexts`, sin duplicar
ese conocimiento.

La señal principal son las **glosas devueltas por el motor de traducción** (ya
normalizadas y desambiguadas). Como respaldo —cuando el backend cae y no hay
glosas— se comparan las raíces léxicas del texto en español, con un lematizador
mínimo que reduce las flexiones más comunes (`robaron`, `robar`, `robo` → `rob`).

**El motor devuelve `null` ante evidencia insuficiente o empate.** Es una
decisión deliberada: encerrar a la persona sorda en un contexto equivocado es
peor que pedirle que elija.

## Inferencia ≠ declaración

`SemanticMessage.contextId` sigue significando *contexto confirmado por una
persona*. La inferencia vive aparte, en `contextSuggestion`. Así una suposición
del sistema nunca se hace pasar por una declaración del usuario, y la precedencia
queda explícita en `Conversation.suggestedReplyContextId`:

```
contexto inferido del enunciado que se responde
  ?? último contexto confirmado en la conversación
  ?? nada (la persona elige, como siempre)
```

En la UI se distinguen con distintivos diferentes: **SUGERIDO** (inferido, con la
evidencia que lo justifica) y **CONTEXTO ACTUAL** (heredado de un turno previo).

## Flujo bidireccional resultante

```
Oyente habla o escribe
  └─ composeHearingTurn(text, activeContextId)
       ├─ translateText(text, situation: activeContextId)   → contexto al backend
       ├─ ContextInferenceEngine.infer(glosses, text)       → ContextSuggestion
       └─ SemanticMessage{glosses, disambiguations, contextSuggestion, replyToId}
            └─ burbuja: "Ver en avatar" + chips de desambiguación

Sorda pulsa "Responder con tarjetas LSB"
  └─ con contexto propuesto → DIRECTO a la primera pregunta
  │    ├─ «Le robaron su celular»                  (la pregunta, a la vista)
  │    ├─ Contexto sugerido: Denunciar robo        (se declara la suposición)
  │    └─ ¿Qué pasó?  [ROBAR] [AMENAZAR] [QUITAR]  (responder ya, sin escalas)
  │         ├─ "Cambiar contexto" → pantalla de selección, sugerido primero
  │         │                        con la evidencia (Detectado: ROBAR · CELULAR)
  │         └─ ← volver            → de vuelta a la conversación
  └─ sin propuesta → pantalla de selección, como siempre
       └─ flujo guiado → "Enviar a la conversación"
            └─ turno sordo con contextId confirmado + replyToId
                 └─ el siguiente turno oyente ya viaja con ese contexto
```

## Decisiones de diseño

1. **Directo a la pregunta, con la suposición declarada y reversible.** En un
   diálogo real, una pantalla de confirmación entre cada turno vuelve lenta la
   comunicación: un solo toque lleva de la conversación a «¿Qué pasó?». Para que
   eso no se convierta en decidir por la persona sorda, el contexto supuesto se
   anuncia en la franja superior ("Contexto sugerido: Denunciar robo") y hay dos
   salidas siempre visibles: *Cambiar contexto* abre la selección con el
   propuesto primero, y la flecha de volver regresa a la conversación para
   preguntar o escribir otra cosa. Sin propuesta, se elige contexto como siempre.
2. **La sugerencia debe ser explicable.** Al elegir contexto se muestra la
   evidencia ("Detectado: ROBAR · CELULAR"): una propuesta que no puede
   justificarse no debería hacerse. Solo se enseñan glosas reales — las raíces
   léxicas internas del lematizador puntúan, pero no significan nada para quien
   lee la pantalla.
3. **`context` y `situation` son cosas distintas en el backend.** `context` es el
   dominio de la aplicación (siempre `legal`, y de él dependen las reglas de
   desambiguación jurídica); `situation` es la situación de la conversación. No
   sustituir el primero por el segundo fue lo que evitó una regresión silenciosa.
4. **Compatibilidad hacia atrás en todo el contrato.** Todos los campos nuevos
   son opcionales: sin `situation` el lambda produce exactamente el prompt de
   antes, y la app funciona aunque el lambda no esté redesplegado.
5. **Degradación limpia.** Si el diccionario aún no ha cargado,
   `ContextInferenceEngine.empty()` no sugiere nada y la conversación funciona
   igual, solo sin preselección.
6. **Empezar una respuesta nueva suelta el contexto anterior.** `contextProvider`
   sobrevive a la conversación, así que sin esto el flujo entraba directo al
   contexto de la respuesta previa y la propuesta no llegaba a verse nunca
   (detectado al ejecutar la app, no por las pruebas). Una declaración a medias
   —con glosas ya elegidas— se respeta y se conserva intacta.

## Verificación

- `flutter analyze`: 0 errores, 0 warnings.
- `flutter test`: **85/85 en verde** (68 previos + 17 nuevos, sin tocar ninguno
  existente: los campos nuevos son opcionales y el catálogo se re-exporta).
  - `context_inference_engine_test.dart` — 12 casos auditados **contra el
    diccionario canónico real**, no contra un léxico de laboratorio: si las
    etiquetas del diccionario se degradan, la prueba falla.
  - `conversation_bidirectional_test.dart` — 5 casos del ciclo completo, con un
    espía sobre el repositorio que confirma que `situation` llega de verdad al
    backend en el segundo turno.
- Lambda auditado localmente con Bedrock simulado: sin `situation` la respuesta
  es idéntica campo a campo a la actual; con `situation` cambia el prompt y la
  clave de caché.
- **Ciclo completo ejecutado en emulador Android** contra el backend real:
  «Le robaron su celular» → glosas `PASADO · SUYO · CELULAR · ROBAR` → un toque
  lleva directo a «¿Qué pasó?» en *Denunciar robo*, con la suposición declarada →
  declaración con audio de Polly → de vuelta al hilo. Verificadas las dos
  salidas: *Cambiar contexto* abre la selección con el sugerido y su evidencia,
  y volver deja el cursor listo para escribir en la conversación. Un turno sin
  evidencia («Recuerda la hora») cae al distintivo CONTEXTO ACTUAL.

## Deuda y siguientes pasos

- **Fase 5 — Portal web de validación + IA asistente** (duplicados, sugerencias,
  prioridad; nunca aprueba automáticamente).
- La `confidence` de la sugerencia se calcula y se guarda, pero la UI todavía no
  la muestra; podría usarse para diferenciar una propuesta fuerte de una débil.
- El caché de DynamoDB sigue desactivado en el lambda; la clave ya contempla la
  situación para cuando se active.
- Sigue pendiente de la Fase 1: retirar las pestañas "Tarjetas LSB" y "Voz a LSB"
  cuando la conversación absorba ambos flujos por completo.
