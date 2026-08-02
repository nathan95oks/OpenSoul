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
  └─ ContextSelectionWidget
       ├─ «¿Le robaron su celular?»                (la pregunta, a la vista)
       ├─ 🚨 Denunciar robo  [SUGERIDO]            (primero, resaltado)
       │     Detectado: ROBAR · CELULAR            (evidencia explicable)
       └─ el resto de contextos debajo             (la decisión sigue siendo suya)
            └─ flujo guiado → "Enviar a la conversación"
                 └─ turno sordo con contextId confirmado + replyToId
                      └─ el siguiente turno oyente ya viaja con ese contexto
```

## Decisiones de diseño

1. **Sugerir y confirmar, no auto-entrar.** Un toque de más a cambio de que la
   persona sorda nunca quede atrapada en un contexto que ella no eligió.
2. **La sugerencia debe ser explicable.** Se muestra la evidencia ("Detectado:
   ROBAR · CELULAR"): una propuesta que no puede justificarse no debería hacerse.
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

## Verificación

- `flutter analyze`: 0 errores, 0 warnings.
- `flutter test`: **82/82 en verde** (68 previos + 14 nuevos, sin tocar ninguno
  existente: los campos nuevos son opcionales y el catálogo se re-exporta).
  - `context_inference_engine_test.dart` — 9 casos auditados **contra el
    diccionario canónico real**, no contra un léxico de laboratorio: si las
    etiquetas del diccionario se degradan, la prueba falla.
  - `conversation_bidirectional_test.dart` — 5 casos del ciclo completo, con un
    espía sobre el repositorio que confirma que `situation` llega de verdad al
    backend en el segundo turno.
- Lambda auditado localmente con Bedrock simulado: sin `situation` la respuesta
  es idéntica campo a campo a la actual; con `situation` cambia el prompt y la
  clave de caché.

## Deuda y siguientes pasos

- **Fase 5 — Portal web de validación + IA asistente** (duplicados, sugerencias,
  prioridad; nunca aprueba automáticamente).
- La `confidence` de la sugerencia se calcula y se guarda, pero la UI todavía no
  la muestra; podría usarse para diferenciar una propuesta fuerte de una débil.
- El caché de DynamoDB sigue desactivado en el lambda; la clave ya contempla la
  situación para cuando se active.
- Sigue pendiente de la Fase 1: retirar las pestañas "Tarjetas LSB" y "Voz a LSB"
  cuando la conversación absorba ambos flujos por completo.
