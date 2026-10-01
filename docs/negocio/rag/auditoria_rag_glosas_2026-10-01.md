# Auditoría RAG ↔ glosas ↔ flujo guiado — 2026-10-01

Estado: diagnóstico, correcciones y **verificación final** (al final del
documento). Los hallazgos se escribieron antes de corregir y no se
reescribieron; su estado final está en «Verificación final».

## Alcance y método

- Código revisado: `tool/build_rag_corpus.py`, `tool/rag_ingestar_documentos.py`,
  `lib/core/domain/rag/rag_retriever.dart`,
  `lib/features/conversation/presentation/providers/rag_suggestions_provider.dart`,
  `conversation_handoff.dart`, `guided_flow_provider.dart`,
  `lib/core/domain/guided/guided_session.dart`, `guided_composer.dart`,
  `suggested_gloss_panel.dart`, `node_flow_canvas.dart`, `gloss_row.dart`.
- Arnés de recuperación (Dart, `RagRetriever`) sobre dos corpus:
  - **activo**: `assets/rag/escenarios_cbba.json` (62 escenarios);
  - **auditoría**: activo + borrador `pendientes/derechos_reales_escenarios.md`
    (32 escenarios de Derechos Reales). El borrador **no tiene glosas**
    (traducirlo exige la Lambda real, que no se llamó): para medir solo la
    recuperación por texto se les puso la glosa simulada `MOCK` en un
    archivo temporal que no está en el repositorio.
- Arnés de conversación completa (Dart, el mismo contenedor de
  `test/rag_tramites_test.dart`: grafo real, RAG local, Lambda y backend
  simulados): mensaje del oyente → ruta → apertura de tarjetas → opciones →
  selección → texto compuesto → glosas emitidas → mensaje en el hilo.
- Barridos: estados de las opciones contra sus glosas, glosas sin animación
  (`SignPreviewPlanner`), sintaxis de PDF y caracteres dañados en lo
  generado, validez de la caché de glosas.
- Todo con dobles: **ninguna** llamada a AWS. Lo que necesita la Lambda o el
  índice semántico real se marca como límite de infraestructura.

Clasificación: **E** = error confirmado del código, **D** = dato del corpus,
**K** = brecha del catálogo/animaciones, **I** = límite de infraestructura,
**G** = fuera del RAG (grafo de Conversación).

## Resumen

| ID | Tipo | Gravedad | Hallazgo |
|---|---|---|---|
| H1 | E | Alta | En una atención de Derechos Reales, «¿Trajo su cédula de identidad?» abre el trámite de SEPDAVI |
| H2 | E | Alta | La negación del oyente se pierde: «¿No trajo su cédula?» = «¿Trajo su cédula?» |
| H3 | E | Alta | Respuestas de otra intención: «¿El inmueble tiene hipoteca?» ofrece «Sí, conozco la matrícula de ese inmueble.» |
| H4 | E | Media | Sin contexto, una pregunta genérica abre el trámite de una institución cualquiera y muestra otra pregunta |
| H5 | E | Alta (latente) | Una pregunta con ramificación que el oyente hace directamente queda inalcanzable |
| H6 | E | Media | Las preguntas de sí o no del RAG no se pueden responder con las unidades SÍ / NO / NO SÉ |
| H7 | E | Baja | Glosas sin su forma canónica del catálogo (SI, DONDE, CUAL) junto a SÍ, DÓNDE en otras pantallas |
| H8 | D | Media | DISC-03: variantes de dos preguntas distintas colgadas de un turno que no es pregunta |
| H9 | D | Baja | Respuestas mixtas («Sí, pero no sé mi NUREJ.») se clasifican como afirmadas |
| H10 | G | Media | «¿Su trámite fue observado?» abre Identificación y pide el nombre |
| H11 | K | Media | Glosas del catálogo sin animación (LLAMAR, AMBOS, HACER, IR, COCHABAMBA, GRATIS) |
| H12 | I | — | El borrador de Derechos Reales no se puede incorporar sin la Lambda; el índice semántico no se auditó en real |

Comprobado **sin hallazgo**: lo generado no contiene sintaxis de PDF ni
caracteres dañados; la caché de glosas no tiene elementos inválidos; las
preguntas exactas del corpus se recuperan en su escenario (100 de 100 en el
activo, 196 de 196 con el borrador); la selección, la vista previa, las
glosas emitidas, el texto compuesto y el mensaje enviado coinciden en los
12 recorridos de conversación probados; las señas a incorporar se ven como
pendientes (azul, «seña a incorporar»), no como señas disponibles.

## Hallazgos

### H1 — Cambio de institución dentro de una atención (E, alta)

- **Entrada:** conversación de Derechos Reales: «¿Usted figura como titular
  del inmueble?» y después «¿Trajo su cédula de identidad?».
- **Esperado:** seguir en Derechos Reales (o, si ese trámite no tiene la
  pregunta, dejar la ruta del grafo).
- **Observado:** `directQuestion ctx=tramite_sepdavi_01 q=[R.ESC-SEPDAVI-01.4]
  reason=rag:ESC-SEPDAVI-01#4`; la persona sorda ve el trámite «Solicitar
  patrocinio como víctima de delito». Con `preferArea: 'DDRR'` el arnés de
  recuperación devuelve igual `ESC-SEPDAVI-01#4 0.77`.
- **Causa raíz (confirmada):** `RagRetriever.suggest` solo suma
  `topicBonus = 0.05` al área de la conversación; el área ganadora es la del
  primer resultado aunque el área actual tenga una coincidencia válida
  (DDRR-02, variante «¿Trajo documento de identidad?»).
- **Efecto:** la persona responde dentro del trámite de otra institución.
- **Corrección propuesta:** si el área de la conversación tiene una
  coincidencia suficiente en esa oración, solo cuenta esa área, salvo que el
  oyente nombre otra institución (`_retrievalSwitchCues`).

### H2 — Negación perdida (E, alta)

- **Entrada:** «¿No trajo su cédula?» (sin contexto).
- **Esperado:** no tratarla como «¿Trajo su cédula?»: un «Sí.» a una
  pregunta negativa es ambiguo en español.
- **Observado:** `ESC-SEPDAVI-01#4 1.00 «Sí.»`, se abre la pregunta
  «¿Tiene su cédula de identidad?» y se envía «No.».
- **Causa raíz (confirmada):** `DialogueGraph.tokensOf` descarta las
  palabras de 3 letras o menos, «no» incluido; `RagRetriever._score` compara
  conjuntos sin polaridad.
- **Corrección propuesta:** la polaridad (no, nunca, tampoco, ningún…) de lo
  dicho y de la pregunta documentada debe coincidir; si no, esa pregunta no
  se recupera (el grafo sigue respondiendo).

### H3 — Respuestas de otra intención (E, alta)

- **Entradas y observado** (corpus de auditoría):
  - «¿El inmueble tiene hipoteca?» → `ESC-DDRR-17#6 0.82` «Sí, conozco la
    matrícula de ese inmueble.» (la pregunta documentada es «¿Tiene la
    matrícula del inmueble de la hipoteca?»);
  - «¿Su trámite fue observado?» → `ESC-DDRR-29#6 0.64` «Sí, tengo el
    comprobante del ingreso anterior.»;
  - «¿Viene a inscribir una compra venta?» → `ESC-DDRR-13#2 0.53` «Sí, tengo
    la escritura pública de compra venta.»;
  - «¿Me muestra su carnet de identidad?» → `ESC-DDRR-22#4 0.47` «Sí, mi
    cédula muestra el dato correcto.».
  En el activo: «¿Su trámite fue observado?» → `ESC-DDRR-04#1 0.47`
  «Compré una casa. Quiero ponerla a mi nombre.» (respuesta a «¿Qué trámite
  viene a registrar?»).
- **Causa raíz (confirmada):** el parecido F1 de `_score` premia que lo
  dicho esté contenido en la pregunta documentada; si a esta le sobra
  justamente el objeto por el que pregunta («matrícula», «comprobante»,
  «escritura»), sus respuestas hablan de ese objeto que el oyente no
  mencionó.
- **Efecto:** la persona afirmaría algo sobre otro documento u otro hecho.
- **Corrección propuesta:** descartar una pregunta documentada cuando una de
  sus palabras que el oyente no dijo aparece en sus respuestas documentadas
  (las respuestas tratan de algo que no se preguntó). Es una regla de
  pertinencia, no un cambio de umbral.

### H4 — Pregunta genérica sin contexto (E, media)

- **Entradas:** «¿Trajo su cédula de identidad?» y «¿Tiene algún
  documento?» al empezar una conversación.
- **Observado:** abren `tramite_sepdavi_01` y `tramite_oj_02`; en el
  segundo, la cabecera muestra «¿Tiene la carátula del expediente?» y la
  respuesta «Sí.» se envía al oyente como respuesta a «¿Tiene algún
  documento?».
- **Causa raíz (confirmada):** sin área de conversación, `suggest` toma el
  área del mejor resultado aunque la misma pregunta exista en varias
  instituciones con un parecido casi igual; la cabecera
  (`node_flow_canvas.dart`, `formulationOf`) muestra la pregunta
  documentada.
- **Corrección propuesta:** sin área de conversación, si las coincidencias
  dentro del margen son de instituciones distintas, la pregunta es ambigua:
  el RAG no elige trámite y queda la ruta del grafo.

### H5 — Pregunta con ramificación preguntada directamente (E, alta, latente)

- **Pasos:** banco de prueba `test/fixtures/rag_tramite_ramificado.json`;
  abrir como lo hace la ruta del RAG (`onlySteps: [R.ESC-DDRR-90.5]`, sin
  `presupposedQuestionIds`).
- **Observado:** `actual=null acepta=false SelectionRejection.unreachable`.
  Con la pregunta presupuesta: `actual=R.ESC-DDRR-90.5 acepta=true`.
- **Causa raíz (confirmada):** `ragTramiteRoute` no rellena
  `presupposedQuestionIds`; `GuidedFlow.isReachable` exige entonces la
  condición del paso.
- **Efecto:** en cuanto un escenario declare ramificaciones, el oyente
  podría preguntar algo que la persona sorda no puede contestar. Hoy ningún
  escenario activo declara ramificaciones (latente).
- **Corrección propuesta:** la pregunta que encontró el RAG es la que hizo el
  oyente: va presupuesta.

### H6 — Sin unidades SÍ / NO / NO SÉ en las preguntas del RAG (E, media)

- **Entrada:** «¿Necesita un duplicado del certificado de matrimonio?».
- **Observado:** opciones `r1 «Sí. Perdimos la copia anterior.»`, `r2 «Sí.»`,
  `r3 «No.»`, `r4 «No sé cuál certificado.»`: hay «Sí.» porque el escenario
  lo documentó; en otras preguntas solo hay oraciones completas (p. ej.
  «¿Tiene la placa actual del vehículo?»: «Sí, la tengo.», «No la tengo.»,
  «No sé cuál es.»). El banco del grafo, en cambio, responde «¿Tiene su
  carnet de identidad?» con SÍ / NO / NO_SABER (`Q.ID.DOC_TIENE`, `polar3`).
- **Causa raíz:** `banco_tramites` solo convierte respuestas documentadas en
  opciones.
- **Corrección propuesta:** en una pregunta de sí o no (no abierta, no
  disyuntiva), ofrecer primero las unidades del catálogo SÍ, NO y NO_SABER,
  cada una solo si el escenario documenta una respuesta de ese estado que
  empieza con esa partícula y cuya traducción la contiene; su frase es la
  propia partícula («Sí.», «No.», «No sé.»): no se atribuye a la persona
  nada que no señó. Las oraciones documentadas siguen como alternativas
  exclusivas.

### H7 — Forma de las glosas (E, baja)

- **Observado:** las opciones del RAG muestran `SI`, `DONDE`, `CUAL`, `AQUI`
  (salida sin tildes de la Lambda); el banco del grafo y el catálogo usan
  `SÍ`, `DÓNDE`, `CUÁL`, `AQUÍ` (C12 frente a C2 del arnés).
- **Causa:** el constructor copia la glosa de la caché tal cual.
- **Corrección propuesta:** escribir en el banco la forma canónica del
  catálogo cuando la correspondencia es única (las letras sueltas, como N y
  Ñ, no se tocan).

### H8 — Variantes mal colgadas en DISC-03 (D, media)

- **Evidencia:** `ESC-DISC-03`, turno 6 («Depende de su grado y situación;
  revise la norma aplicable.», no es pregunta) tiene como variantes
  «¿Su carnet está vencido?» y «¿Conoce su grado registrado?» con las
  respuestas «Está vencido.», «No está vencido.», «No sé.». «¿Tiene su
  carnet?» recupera «Está vencido.», y «¿Conoce su grado registrado?»
  también.
- **Causa:** dato de origen. El constructor no avisa.
- **Corrección propuesta:** aviso del constructor; la corrección del texto es
  de quien mantiene el escenario (no se modifica aquí para no inventar).

### H9 — Respuestas mixtas (D, baja)

- **Evidencia:** «Tengo cédula, pero no traje CRPVA.», «Sí, pero no sé mi
  NUREJ.», «Tengo el caso, pero no sé usarlo.» quedan `afirmado`.
- **Efecto:** solo importaría en una ramificación por estado; hoy no hay.
- **Propuesta:** documentarlo; declarar esas ramas por respuesta («= «…»»)
  y no por estado.

### H10 — «Trámite» abre Identificación (G, media)

- **Entrada:** «¿Su trámite fue observado?».
- **Observado:** `directContext ctx=identificacion reason=familia nombrada:
  tramites`; se pregunta «¿Cuál es su nombre completo?».
- **Causa:** el grafo de Conversación interpreta la palabra «trámite» como
  la familia Trámites. No es el RAG.
- **Propuesta:** fuera de este alcance; queda abierto para el grafo.

### H11 — Señas del catálogo sin animación (K, media)

- **Evidencia:** `SignPreviewPlanner` no encuentra clip para LLAMAR (5
  opciones), AMBOS (5), HACER (4), IR (4), COCHABAMBA (3), GRATIS (2). Las
  filas ya dicen «Sin animación en el avatar».
- **Propuesta:** incorporar las animaciones; no es un fallo del RAG.

### H12 — Límites de infraestructura (I)

- Incorporar el borrador de Derechos Reales (425 frases) necesita la Lambda
  Texto→LSB (`tool/rag_actualizar.py`); no se ejecutó.
- La búsqueda por significado (Lambda + embeddings) no se auditó en real. Sin
  ella, el RAG local sigue funcionando (comprobado con `remoteRagProvider`
  nulo).

## Comandos del diagnóstico

```bash
python <scratchpad>/corpus_auditoria.py <scratchpad>/corpus_auditoria.json
AUDIT_CORPUS=<scratchpad>/corpus_auditoria.json flutter test test/zz_exploracion_auditoria_test.dart
flutter test test/zz_conversaciones_auditoria_test.dart
```

(Arneses temporales; los casos reproducidos pasan a pruebas de regresión.)

## Verificación final

Se reejecutaron los arneses del diagnóstico (mismos corpus y mismas
entradas) y las suites. Todo con dobles: **ninguna** llamada a AWS.

| ID | Estado | Corrección | Evidencia tras corregir |
|---|---|---|---|
| H1 | Corregido | `RagRetriever.suggest`: con tema, solo cuenta su institución salvo que el oyente nombre otra; si otra encaja claramente mejor (más del margen), no se responde | «¿Trajo su cédula de identidad?» tras «¿Usted figura como titular…?» ya no abre SEPDAVI; «¿Su cédula ya venció?» con tema DDRR ya no recibe «Sí, la tengo.» |
| H2 | Corregido | La negación de la oración y la de la pregunta documentada deben coincidir (`RagRetriever.isNegated`) | «¿No trajo su cédula?» → sin RAG (ruta del grafo); una pregunta negativa documentada sí se encuentra (corpus mínimo de prueba) |
| H3 | Corregido en el corpus activo; **pendiente** un caso del borrador | Una pregunta abierta y una de sí o no no se intercambian; en una de sí o no, las respuestas no pueden hablar de lo que el oyente no dijo | «¿Su trámite fue observado?» ya no recibe «Compré una casa…»; en el borrador, hipoteca→matrícula, observado→comprobante, compra venta→escritura y carnet→dato correcto ya no se recuperan. Sigue: «¿El inmueble tiene hipoteca?» → «Sí, tengo la escritura pública de hipoteca.» (variante «¿Trajo el testimonio de la hipoteca?»; los pesos de «testimonio» e «hipoteca» son casi iguales). Solo en el borrador, que aún no está en la app |
| H4 | Corregido | Sin tema, el RAG solo elige institución si lo dicho la identifica (solo ella encaja, es exactamente una pregunta suya, o comparte una palabra que solo ella usa) | «¿Trajo su cédula de identidad?» y «¿Tiene algún documento?» sin tema → sin RAG; «¿Tiene la placa de su moto?», «¿Está en un lugar seguro?» y «¿Usted es el denunciado o acusado en el caso?» se siguen encontrando |
| H5 | Corregido | `ragTramiteRoute` presupone la pregunta encontrada | La ruta lleva `presupposedQuestionIds = pathQuestionIds`; la pregunta hija del banco de prueba se responde |
| H6 | Corregido | `banco_tramites`: unidades SÍ / NO / NO_SABER (`polar: true`, control `polar3`/`polar2`) fundadas en respuestas documentadas que empiezan con esa partícula; frase = la partícula | 18 preguntas `polar3`, 2 `polar2`; «¿Necesita certificado de matrimonio duplicado?» → si, no, no_se, r1, r4; responder NO envía «No.» con glosas `[NO]` |
| H7 | Corregido | `glosas_canonicas`: forma del catálogo si la correspondencia es única | `SI`→`SÍ`, `CUAL`→`CUÁL`, `DONDE`→`DÓNDE` en el banco generado |
| H8 | Aviso añadido; dato **pendiente** | El constructor avisa de variantes-pregunta colgadas de un turno que no pregunta | 15 avisos (DISC-03, SEPDAVI-03, SLIM-02…); el texto de los escenarios no se modificó |
| H9 | Pendiente (documentado) | Declarar las ramas de esas preguntas por respuesta, no por estado | Sin ramificaciones activas que dependan de ello |
| H10 | Pendiente (grafo) | Fuera del RAG | Igual que en el diagnóstico |
| H11 | Pendiente (catálogo) | Faltan animaciones | Igual; las filas lo dicen |
| H12 | Límite | — | El borrador valida sin errores junto al corpus (425 frases por traducir); no se tradujo ni se activó |

### Observaciones nuevas de la reauditoría

- **Menos tarjetas específicas cuando el RAG no está seguro (consecuencia
  de H1/H2/H4).** «¿Trajo su cédula de identidad?» sin tema o en Derechos
  Reales, «¿No trajo su cédula?», «¿Tiene algún documento?» y «¿Tiene
  abogado?» en una atención de FELCV quedan ahora en la ruta del grafo
  (`noSafeRoute`): la persona no recibe tarjetas de un trámite, en vez de
  recibir las de otro. Propuesta (no implementada): una respuesta mínima
  SÍ / NO / NO SÉ para cualquier pregunta de sí o no sin ruta.
- **Turnos no mostrables con variantes recuperables (dato).** DDRR-01 turno
  2 y DDRR-02 turnos 3 y 5 dependen de una vigencia `[VERIFICAR]`: el RAG
  encuentra sus variantes, pero no hay pregunta en el banco y no se abre
  trámite. Correcto por diseño; se corrige confirmando la vigencia.
- **Traducción (Lambda).** «Sí, la tengo.» → `YO TENER` (sin SÍ; por eso la
  unidad SÍ se funda en el texto y no en la traducción) y «sigo» →
  `SENA_PENDIENTE:SIGUIR`. Requiere revisar la caché con
  `tool/rag_corregir_glosas.py`; no se tocó.
- **Respuestas mixtas** (H9): ocho opciones `afirmado` contienen una
  negación («Tengo cédula, pero no traje CRPVA.»).

### Qué se comprobó con dobles y qué no

- Con dobles (sin red): recuperación local, rutas de Conversación con el
  grafo real, apertura de tarjetas, selección, composición, glosas emitidas
  y mensaje en el hilo; el backend de traducción y la Lambda Texto→LSB son
  falsos; el corpus del borrador usa glosas simuladas (`MOCK`).
- **No comprobado en real:** traducción de las 425 frases del borrador, la
  búsqueda por significado (Lambda + embeddings), el avatar en un teléfono.

### Pruebas de regresión añadidas

- `test/rag_auditoria_regresion_test.dart` — H1 a H5 sobre el corpus activo
  y un corpus mínimo.
- `test/rag_tramites_test.dart` — conversación completa: unidad NO
  (selección = glosas = texto = mensaje), Derechos Reales sin salto a
  SEPDAVI, pregunta negativa.
- `test/rag_ramificaciones_test.dart` — unidades, rama por estado con
  unidad, rama por respuesta concreta, hija presupuesta.
- `tool/tests/test_rag_ingesta_y_ramas.py` — unidades fundadas, `polar2`,
  disyuntivas.
- `test/rag_retriever_test.dart` — dos expectativas cambiadas porque
  describían H4 y H1 como correctas (variante idéntica en dos instituciones
  sin tema; pregunta genérica en un mismo mensaje).

### Comandos de la verificación

```bash
python -m pytest tool/tests -q                       # 77 pasan
python -m pytest aws/tests -q                        # 426 pasan, 1 omitida
python tool/build_rag_corpus.py --check              # al día
python tool/rag_ingestar_documentos.py               # sin cambios, exit 0
flutter analyze                                      # sin problemas
flutter test                                         # 981 pasan, 1 omitida
```
