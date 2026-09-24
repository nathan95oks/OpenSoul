# Auditoría e implementación: los tres modos del módulo LSB → texto/audio

Fecha: 2026-09-24 · Alcance: conversación bidireccional en la etapa preliminar
judicial (denuncias, consultas, trámites y orientación inicial), Cochabamba.

Este documento recoge lo que se encontró en el sistema, lo que se cambió y lo
que queda pendiente de validación humana. Las cifras salen de ejecutar las
herramientas del repositorio, no del documento de grado.

---

## 1. Qué se encontró

### 1.1. Los tres modos estaban colapsados en dos señales indirectas

El módulo de tarjetas se usaba para tres cosas distintas, pero el sistema solo
distinguía dos estados y los deducía de señales que no significan lo que se les
pedía significar:

| Señal | Qué decidía | Por qué no bastaba |
|---|---|---|
| `flowSurfaceProvider` | Si la pantalla «sirve a la conversación» | Solo tres valores, uno por pestaña. `_openCardsFlow()` cambiaba de pestaña **sin** tocarla, así que la superficie quedaba en `conversation` por omisión, no por decisión. |
| `Conversation.pendingReply` | Si había pregunta a la que responder | Se leía **en vivo** en cada recomposición. Un turno que entrara durante la edición cambiaba la pregunta bajo los pies de quien estaba respondiendo. |

Consecuencias verificadas en el código anterior:

- **Modo A contaminado.** `conversation_screen.dart:61-81` proponía el
  contexto de la charla guardada (`suggestedReplyContextId`) al abrir las
  tarjetas, y `home_screen.dart:155` mostraba la banda «Respondiendo a: …»
  siempre que la superficie fuera `conversation`.
- **Modo B inexistente como tal.** El botón decía siempre «Responder con
  tarjetas LSB», incluso sin ningún turno del oyente. La persona sorda que
  abría el turno ella misma veía una interfaz que afirmaba que estaba
  respondiendo.
- **`ReplyPrompt` sin identidad.** `conversation_bridge.dart` exponía
  `question`, `suggestion` y `activeContextId`; **no el id del turno**.
- **Enlace calculado al enviar.** `conversation_provider.dart:72` resolvía
  `replyToId: state.conversation.pendingReply?.message.id` en el momento del
  envío, no al abrir.

### 1.2. Fallo de corrección encontrado durante la implementación

`ConversationEngine._newId()` devolvía `DateTime.now().microsecondsSinceEpoch`.
Dos turnos creados dentro del mismo microsegundo recibían **el mismo
identificador**. Como `Conversation.replaceTurn` busca por id para completar
el turno del oyente cuando llega su traducción, reemplazaba al turno homónimo
anterior: **una declaración ya registrada de la persona sorda desaparecía del
chat**, y las respuestas siguientes se enlazaban a un turno que ya no era el
suyo.

No es hipotético: se reprodujo en un ciclo de seis turnos alternados
(`test/modos_abc_conversacion_test.dart`, «turnos seguidos reciben
identificadores distintos»). En la traza de depuración, la respuesta a
«¿Dónde ocurrió?» se perdió y el turno «¿Había testigos?» apareció duplicado.

### 1.3. Contextos legados sin catálogo

`resolveAssemblerContext()` (`context_catalog.dart:760-785`) enruta por los
contextos `'tramite'` y `'consulta'`, que **no existen** en
`allSelectableContexts`. Son ramas muertas. Los ocho contextos seleccionables
reales son: `denuncia_robo`, `violencia`, `amenaza_digital`, `engano_dinero`,
`seguimiento`, `otro`, `identificacion`, `preguntas`.

### 1.4. Límites de red frente a límites de interfaz

Se comprobó que **no** existía el problema que se sospechaba: la Lambda limita
a 8 (`MAX_SUGERENCIAS`) las glosas que el modelo puede **reordenar**, pero
`dynamicCardsProvider` ya conservaba el resto de tarjetas locales detrás de esa
reordenación. `MAX_CARDS = 64` es una salvaguarda de entrada de la petición y
no un tope de interfaz; se conserva intacta.

---

## 2. Tabla de discrepancias entre fuentes

Todas las cifras son ejecutables: salen de `tool/corpus_dialogue.py` y de leer
los archivos que la app empaqueta.

| Fuente | Entradas | Qué demuestra |
|---|---:|---|
| Corpus §12 (apéndice del documento) | **303** | Glosas documentadas con trazabilidad M1–M4 o Diccionario 2024. |
| `assets/dictionary/official_dictionary.json` | **346** | Lo que la app ofrece como tarjeta. = 303 del corpus + 27 letras + 10 dígitos + 6 nombres institucionales + 6 entradas `d(...)`. |
| `aws/lambda_text_to_lsb.py` → `AVAILABLE_GLOSSES` | **346** | Paridad exacta con el catálogo del cliente. |
| Léxico del ensamblador Dart | **397** claves | Incluye variantes y alias de redacción; no es un catálogo de señas. |
| `animationFile` no vacío en el catálogo | **37** | **No demuestra nada.** Es un campo de datos, no un recurso comprobado. |
| Animaciones realmente horneadas en `avatar_test.glb` | **41** | Lo que el avatar sabe ejecutar: **5 señas léxicas** (HOLA, PERMISO, GRACIAS, SÍ, NO), 25 letras y 11 números. |

**Lo que no se puede decir**, y que este trabajo corrige en el texto académico:

- «303 animaciones disponibles» — falso: son 303 **entradas documentadas**.
- «210 glosas» (apartado 4.4.4 del documento v1.4) — desactualizado: el
  catálogo tiene 346 entradas.
- «346 animaciones» — falso: el avatar ejecuta 5 señas léxicas. Todo lo demás
  se deletrea o se muestra como marcador de posición.
- `status: "official"` — las **346** entradas lo llevan. No distingue nada, y
  no prueba que exista una seña regional validada.

El alfabeto dactilológico tampoco está completo: faltan la **I** y la **K** en
el modelo, así que FISCALÍA se deletrea con un marcador en la I. Esto ya estaba
documentado en `animation_url_resolver.dart:12-17` y se conserva.

---

## 3. Qué se implementó

### 3.1. El propósito es dato, no inferencia

`lib/core/presentation/session/cards_flow_launch.dart` introduce
`CardsFlowPurpose` (`standaloneDeclaration` / `conversationInitiative` /
`conversationReply`) y `CardsFlowLaunch`, que congela al abrir:

- `conversationId` y `hearingTurnId` cuando proceden,
- `hearingText`: el texto **exacto** que se le mostró a la persona sorda,
- `hearingSpeechAct`, para no convertir una afirmación en pregunta de sí/no,
- el contexto propuesto, que en el modo A es deliberadamente `null`.

| Modo | Cómo se entra | `replyToId` | Encabezado |
|---|---|---|---|
| A | Pestaña «Tarjetas LSB» desde la barra inferior | `null` | Ninguno del chat |
| B | Botón «Iniciar con tarjetas LSB» en el chat | `null` | «Empiezas tú: elige qué quieres decir o preguntar» |
| C | Botón «Responder con tarjetas LSB» sobre un turno oyente | el id congelado | La frase exacta del oyente, sin recortes |

El botón del chat cambia de texto según cuál de los dos encargos corresponde
(`conversation_screen.dart`), y tras cada turno de la persona sorda aparece
**«Continuar como persona oyente»**, que solo enfoca el campo de texto: el
micrófono sigue necesitando que el oyente lo pulse.

### 3.2. El enlace ya no se recalcula

`ConversationNotifier.addDeafDeclaration` recibe `replyToId` y
`conversationId` desde el lanzamiento y devuelve un `SubmitOutcome`:

- `sent` — añadido con el enlace correcto;
- `staleReply` — el turno al que respondía ya no existe (chat nuevo, sesión
  restaurada, otro chat): **no se envía nada** y la pantalla lo dice;
- `noConversation` — modo A.

Una sesión restaurada vuelve siempre al modo A
(`main_navigation_screen.dart`): reanudar a ciegas una respuesta es colgarla
de la pregunta equivocada.

### 3.3. Borradores

Cambiar de encargo con un borrador a medias pide confirmación explícita
(`_confirmDiscardDraft`). Volver al **mismo** encargo no toca nada
(`CardsFlowLaunch.sameErrand`).

### 3.4. El grafo de diálogo

`tool/build_dialogue_graph.py` genera `assets/dialogue/dialogue_graph.json`
desde el corpus: **209 nodos** (98 + 60 + 51) con **99 intenciones distintas**.
Cada nodo declara id estable, versión, procedencia exacta (sección,
subsección, fila y frase original), ámbito, intención, acto comunicativo,
modos A/B/C en que puede activarse, ranuras de respuesta, opciones ya
resueltas contra el catálogo, opciones pendientes con su motivo, y
transiciones hacia nodos que aportan ranuras nuevas.

En el cliente, `DialogueGraph` empareja el español libre del oyente por
similitud léxica con raíz pobre (Dice-Sørensen sobre tokens). **Devolver
`null` es una respuesta válida**: si nada encaja con seguridad, hay
`candidates()` para proponer intenciones en vez de forzar un nodo cercano.
Las opciones del nodo pasan al frente de la grilla, delante de la
reordenación de Bedrock y del orden del catálogo, sin eliminar ninguna
tarjeta que ya fuera alcanzable.

---

## 4. Cobertura comprobada

`docs/Matriz_Cobertura_Corpus_209.md` lleva la matriz completa, entrada por
entrada, con modos aplicables y estado.

| Estado | Intervenciones | % |
|---|---:|---:|
| cubierta | 184 | 88.0 % |
| cubierta con dactilología | 20 | 9.6 % |
| cubierta por composición validada | 0 | 0.0 % |
| requiere validación | 0 | 0.0 % |
| no soportada | 5 | 2.4 % |
| **Total** | **209** | **100 %** |

Las cinco no soportadas, con su motivo exacto:

| Entrada | Frase | Concepto |
|---|---|---|
| `S6-ACCESO_COMUNICATIV-04` | ¿Puede leer este texto? | `TEXTO` |
| `S6-ACCESO_COMUNICATIV-08` | ¿Puede deletrear su apellido? | `DELETREAR` |
| `S6-DESCRIPCION_DE_PER-05` | ¿Qué color de cabello recuerda? | `COLOR` |
| `S6-ROBO,_HURTO_Y_OBJE-01` | ¿Le robaron algún objeto? | `OBJETO` |
| `S7-ROBO_Y_OBJETOS-06` | ¿Puedo agregar otro objeto robado? | `OBJETO` |

Los cuatro conceptos son genéricos y el corpus no los documenta. La sección 4
del propio corpus indica el camino —«preferir el objeto concreto»—, así que la
salida correcta es ofrecer los concretos (CELULAR, DINERO, MOCHILA…; los
colores del catálogo) en lugar de crear una seña genérica. **No se ha hecho:**
requiere una decisión de producto sobre qué conjunto concreto ofrecer en cada
caso, y se deja anotado en vez de inventarlo.

Ninguna opción del grafo inventa vocabulario: `test/dialogue_graph_test.dart`
comprueba que toda tarjeta ofrecida existe en `official_dictionary.json`, que
la dactilología se marca como tal, y que **DENUNCIA no aparece nunca como seña
directa** (sección 4 del corpus).

---

## 5. Pruebas

Ejecutadas en este repositorio, sin invocar servicios reales:

```
flutter analyze          → No issues found!
flutter test             → 452 tests, todos pasan (1 omitido, preexistente)
python -m unittest discover -s aws/tests  → 162 tests, OK
python tool/build_dialogue_graph.py --check → el grafo está al día
```

Línea base antes de este trabajo: 418 tests Dart, 162 Python. Los **34 nuevos**
están en `test/modos_abc_conversacion_test.dart` (12) y
`test/dialogue_graph_test.dart` (22).

Tres pruebas existentes cambiaron porque cambió el contrato, no porque
fallaran:

- `conversation_bidirectional_test.dart` — el enlace ahora lo aporta quien
  abrió el módulo.
- `module_isolation_test.dart` — volver a la pestaña del chat ya **no** rearma
  sola la respuesta; hay que volver a pulsar el botón, que restituye la
  pregunta exacta.
- `zone_inference_engine_test.dart` — `ReplyPrompt` exige ahora `turnId` y
  `conversationId`.

---

## 6. Qué queda pendiente

Honestamente, y sin presentarlo como terminado:

1. **Validación lingüística con señantes de Cochabamba e intérpretes.** Nada
   de lo aquí implementado valida una composición. Las 20 entradas resueltas
   por dactilología y las composiciones provisionales de la sección 4
   (QUEJAR + AUTORIDAD para DENUNCIA, NOMBRE + ESCRIBIR para FIRMA,
   ÓRGANO-JUDICIAL + OFICINA para JUZGADO) **siguen sin validar**.
2. **Los cinco conceptos genéricos** (OBJETO, TEXTO, COLOR, DELETREAR)
   necesitan una decisión de producto sobre el conjunto concreto a ofrecer.
3. **Cobertura del avatar.** Con 5 señas léxicas horneadas, la dirección
   español → LSB es hoy mayoritariamente dactilología y marcadores de
   posición. Ninguna cifra de este repositorio debe presentarse como
   «animaciones disponibles» sin esa aclaración.
4. **Contextos de consulta y trámite.** El enrutador los menciona y el corpus
   tiene 60 + 51 entradas que los pueblan, pero no existen como contextos
   seleccionables. Construirlos de extremo a extremo —zonas, entradas, salida—
   es trabajo aparte; reanimar las ramas muertas solo para pasar una prueba
   sería peor que dejarlas señaladas.
5. **Pruebas de interfaz sobre widgets.** Las pruebas nuevas ejercitan el ciclo
   A/B/C a través de `ConversationHandoff`, que es el camino real del producto,
   pero no montan la pantalla con `testWidgets`. Falta esa capa.
6. **Latencia en dispositivos modestos** y accesibilidad táctil de la grilla
   con el nuevo orden: no medidas en este trabajo.
