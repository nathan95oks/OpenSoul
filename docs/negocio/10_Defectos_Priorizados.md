# Defectos priorizados y pruebas de aceptación

Base: HEAD `031b821`. Cada defecto trae su evidencia (archivo:línea, captura o sonda), su
causa raíz y una prueba de aceptación **observable**: lo que una prueba automática o una
persona en el dispositivo debe ver. Las sondas están en `evidencia/2026-09-25/`.

Prioridad:

- **P0** — la frase pierde, invierte o inventa lo declarado, o afirma un trámite.
- **P1** — se pide o se acepta un dato de la clase equivocada; la pregunta no es la que se hizo.
- **P2** — léxico, presentación o deuda que degrada la precisión sin invertirla.

## Resumen

| Id | P | Defecto | Recorridos | Evidencia |
|---|---|---|---|---|
| D-01 | P0 | Se descarta quién escapó | A | P01 |
| D-02 | P0 | «Sospecho de robo» se redacta como pérdida; «No lo sé» crea un robo | A, I | P02 |
| D-03 | P0 | Cancelar una hoja añade la tarjeta (y crea la persona) | I, C, E | P03, P12 |
| D-04 | P0 | `maxPicks` ignorado: Sí y No a la vez; tercer hecho descartado | A, I | P06 |
| D-05 | P0 | Frases fijas por contexto que ignoran las respuestas | G, H | P09, P10, P14 |
| D-06 | P0 | «WhatsApp» y «texto» inventados a partir de CELULAR | C | P07, C08 |
| D-07 | P0 | Monto, medio, receptor y comprobante de engaño perdidos | E | P04, P05, Lambda |
| D-08 | P0 | «¿Le robaron el celular?» sin Sí/No y sin frase | B | P11, P15 |
| D-09 | P0 | Nombre, edad y contacto no llegan a la frase | H | P09, Lambda |
| D-10 | P0 | Se afirma formalidad o trámite no realizado | todos | C07, código |
| D-11 | P0 | Institución como respuesta a sí/no y «Deseo presentar esto ante un abogado» | E | C07, P14 |
| D-12 | P1 | Filtro por campo inoperante | todos | P13 |
| D-13 | P1 | Glosas de la formulación ofrecidas como respuesta | C, D, E | C04, C08, C09, C11 |
| D-14 | P1 | «¿Quién…?» / «nombre o número» abren el asistente de sospechoso sin nombre ni teléfono | C, E | C05, C06, C10, P07, P08 |
| D-15 | P1 | Asistente de persona: omitir preseleccionado, rol fijo, Niño/Anciano perdidos, sin edad numérica | F | C05, código |
| D-16 | P1 | Editor de monto tapado por el teclado, importes rápidos, rol «sustraído» | E | C02, C03 |
| D-17 | P1 | Teclados no pertinentes (CELULAR, BANCO) | C, E | P05, P07 |
| D-18 | P1 | PAPEL/IDENTIDAD siempre «prueba»; PAPEL equivalente a FACTURA | D, H | C04, C12 |
| D-19 | P1 | `comprobante` no alimenta evidencia; TOTAL/AHORA redactados como prueba | D | P03, P07 |
| D-20 | P1 | Preguntas compuestas con una sola respuesta | D, C | C05, C09, C12 |
| D-21 | P1 | Rutina médica/emocional obligatoria o de rutina | — | P17 |
| D-22 | P1 | En C, 81 de 98 preguntas del funcionario muestran otra pregunta | B, H, E | P15, matriz |
| D-23 | P1 | Grafo: disyuntivas como sí/no, interrogativas como respuesta, ranuras erróneas | — | matriz de nodos |
| D-24 | P1 | Personal = ventanilla; perfil sin efecto; `intentId` nunca asignado | G | P13, código |
| D-25 | P1 | Sin frase previa durante la construcción | todos | 3 pruebas fallidas |
| D-26 | P1 | Sin «No lo sé» ni «Omitir» por pregunta; avanzar ≡ omitir | todos | C01–C12 |
| D-27 | P1 | El borrador de entidades sobrevive a un encargo nuevo del mismo contexto | I | P16 |
| D-28 | P1 | Zonas encadenadas inalcanzables; cantidad de testigos nunca preguntada | — | P17 |
| D-29 | P1 | Personal A sin «Iniciar conversación con este mensaje» | A | código |
| D-30 | P1 | En «Preguntas», elegir DÓNDE no evita persona/tema/tiempo | G | P17 |
| D-31 | P2 | AL_LADO rotulada «EL»; CONOCER rotulada «CONOCIDO» y redactada «conozco…» | C | catálogo, corpus |
| D-32 | P2 | Dígitos y letras clasificados como verbos | — | código |
| D-33 | P2 | Colores sin glosa ofrecidos como tarjetas | F | código |
| D-34 | P2 | Emoji de «Mis datos» sin renderizar | H | C12 |
| D-35 | P2 | `flutter analyze` con 10 avisos; `alreadyAnswered` vacío | — | analyze |
| D-36 | P2 | La Lambda texto→LSB declara glosas que no son tarjetas | — | prueba fallida |

---

## P0

### D-01 · Se descarta quién escapó

- **Evidencia**: sonda P01 → facts `[ROBAR:unknown, ESCAPAR:unknown]`, frase «Una persona me robó.
  Hubo una huida, sin precisar de quién.» tras elegir «La víctima / Yo logré escapar».
- **Causa raíz**: `elegirGlosa` abre la hoja **antes** de registrar la tarjeta
  (`qualifier_sheets.dart:328-333`); la hoja busca el hecho en `declarationDraftProvider`
  (`disambiguation_modal.dart:38-39`), donde la interfaz nunca lo crea (`toggleFactAction` no
  tiene llamadas en `lib/`). Los hechos solo existen al combinar zonas en
  `buildFullDeclarationDraft`, sin protagonista.
- **Prueba de aceptación**: con `denuncia_robo`, tocar ROBAR y ESCAPAR y elegir «Yo logré
  escapar» → la frase previa contiene «Logré escapar», no contiene «sin precisar»; el
  `declaration.facts[1]` enviado es `{action: ESCAPAR, actorRole: victim}`. Repetir con «La persona
  que lo hizo» → «La persona que me robó escapó.»

### D-02 · Pérdida y robo invertidos

- **Evidencia**: sonda P02 → borrador de entidades `ROBAR:theft`, hechos finales `PERDER:null`,
  frase «No sé con certeza qué ocurrió; puede que haya perdido algo.»
- **Causa raíz**: `retainWhere` conserva solo las acciones de la zona
  (`denuncia_robo_draft_provider.dart:531-534`) y borra el ROBAR que creó la aclaración;
  `setLossDisambiguation` convierte «unknown» en ROBAR (`:112`).
- **Prueba**: PERDER + «Creo que me lo robaron» + CELULAR → «Creo que me robaron el celular, pero
  no estoy seguro.»; PERDER + «No sé» → «No sé si lo perdí o me lo robaron.» y ningún hecho
  ROBAR en el borrador; PERDER + «Lo perdí» → «Perdí el celular.»

### D-03 · Cancelar añade

- **Evidencia**: sonda P03 (PAPEL queda en la zona, 0 objetos); sonda P12 (HOMBRE queda y existe
  1 persona). Afecta a ESCAPAR, PERDER, PAPEL, IDENTIDAD, CAJA/BOLSA/MOCHILA, MICRO/TRUFI,
  BILLETES, persona, objetos y lugar (`qualifier_sheets.dart:328-414`); la hoja de persona crea
  la persona en su primer fotograma (`entity_editor_sheets.dart:499-509`).
- **Prueba**: para cada una de esas tarjetas, abrir la hoja y cerrarla tocando fuera → la
  respuesta de la zona, la frase previa y el borrador quedan idénticos a antes de tocar.

### D-04 · `maxPicks` ignorado

- **Evidencia**: sonda P06 → `denuncia = [SÍ, NO]`, `willFileComplaint = confirmed`; `hecho =
  [ROBAR, DAÑAR, ENGAÑAR]` → hechos `[ROBAR, DAÑAR]`.
- **Causa raíz**: `031b821` eliminó el control de `maxPicks` en `toggleAnswer`
  (`semantic_zones_provider.dart:207-215`).
- **Prueba**: en cualquier zona de máximo 1, tocar SÍ y luego NO deja solo NO; en `hecho`, el
  tercer toque no cambia nada y muestra «Puedes elegir hasta dos».

### D-05 · Frases fijas por contexto

- **Evidencia**: sondas P09, P10, P14 y Lambda (tabla de `08 §4.7`).
- **Causa raíz**: la interfaz siempre envía el borrador, así que la base local es siempre
  `assembleStructured` (`conversation_engine.dart:57-62`), cuyas ramas por contexto no leen las
  respuestas (`local_sentence_assembler.dart:351-395`); la Lambda replica el patrón
  (`lambda_function.py:2292-2395`).
- **Prueba**: «Preguntas» con CUÁNDO + VOLVER → «¿Cuándo debo volver?»; «Declaración» con
  OBSERVAR sin contenido → no se emite frase de testigo; violencia AMENAZAR → «Me amenazaron.»;
  ninguna frase contiene «El declarante» ni «El ciudadano».

### D-06 · Canal inventado

- **Evidencia**: sonda P07 → `digitalThreat.channel = WhatsApp`, frase «…a través de WhatsApp.»
- **Causa raíz**: `denuncia_robo_draft_provider.dart:679-680` fija `WhatsApp`/`Internet` y
  `messageType: 'texto'` por defecto.
- **Prueba**: amenazas con CELULAR como canal → la frase dice «por celular» y el `declaration` no
  contiene «WhatsApp», «SMS» ni `messageType` salvo que la persona los escriba.

### D-07 · Datos de engaño perdidos

- **Evidencia**: sondas P04/P05: objeto `BILLETES:stolen:150:bolivianos`, `fraud.amount = null`,
  frase sin monto; Lambda «Denuncio un engaño económico / engaño económico.»
- **Causa raíz**: el monto se guarda como objeto robado (`amount_input_sheet.dart:114-119`);
  `FraudDetails.amount` nunca se llena (`denuncia_robo_draft_provider.dart:664-674`); la Lambda lee
  claves snake_case distintas de las que envía el cliente (`lambda_function.py:2324-2331`).
- **Prueba**: Q.DIN.MECANISMO = banco + 150 Bs → local y Lambda redactan «Envié Bs 150 mediante un
  banco.»; prueba de contrato cliente↔Lambda con el JSON real de la app que verifica monto,
  moneda, mecanismo, receptor y comprobante.

### D-08 · Respuesta a «¿Le robaron el celular?»

- **Evidencia**: sondas P11/P15 → zona `objetos`, `zona_tiene_SI = false`, frase «Quiero comunicar
  lo siguiente, aunque todavía no completé los detalles.»
- **Causa raíz**: `ZoneInferenceEngine` mapea «robaron el celular» a `objetos`
  (`zone_inference_engine.dart:337`); el objeto robado sin hecho ROBAR no se redacta
  (`local_sentence_assembler.dart:404-407`).
- **Prueba**: turno oyente «¿Le robaron el celular?» → la pantalla muestra Sí · No · No sé ·
  «Me robaron otra cosa»; Sí → «Sí, me robaron el celular.» con `replyToId` del turno; No → la
  frase no contiene «me robaron».

### D-09 · Identificación sin datos

- **Evidencia**: sonda P09 → glosas `NOMBRE, J, U, A, N, EDAD, 2, 4`; frase local «El declarante se
  identifica ante la autoridad competente.»; Lambda «Datos de identificación:».
- **Causa raíz**: `buildFullDeclarationDraft` no lee las zonas de `identificacion`; el nombre se
  convierte en letras-glosa (`qualifier_sheets.dart:422-438`).
- **Prueba**: «Mis datos» con nombre «María Quispe» y edad 24 → «Me llamo María Quispe. Tengo 24
  años.»; el `declaration` lleva `ciudadano.nombreLiteral = "María Quispe"` y ninguna glosa de letra.

### D-10 · Formalidad no realizada

- **Evidencia**: C07 («EMITIR DECLARA…» con mazo, `live_declaration_preview_panel.dart:189, 206`);
  «Tu declaración formal ha sido consolidada» y «Texto formal para autoridades»
  (`declaration_result_screen.dart:106, 115`); «Selecciona la categoría exacta para el acta
  formal» (`disambiguation_modal.dart:117`); «Denuncio…» en la Lambda (`:2414, 2416`).
- **Prueba**: búsqueda automática de «formal», «acta», «consolidad», «emitir», «denuncio» en los
  textos de interfaz y en las frases generadas sin intención elegida → cero apariciones. El botón
  final dice «Revisar mensaje».

### D-11 · Institución como respuesta a sí/no

- **Evidencia**: C07; zonas `engano_dinero/institucion` y `amenaza_digital/institucion`
  (`context_catalog.dart:532-543, 607-619`); sonda P14 «…Deseo presentar esto ante un abogado.»
- **Causa raíz**: listas blancas copiadas; `receivingInstitution = institucionAns.first`
  (`denuncia_robo_draft_provider.dart:627-630`) redactado en `local_sentence_assembler.dart:486-490`.
- **Prueba**: «¿Desea presentar la denuncia formal?» solo ofrece Sí · No · No sé; ABOGADO nunca
  produce «presentar ante»; en ventanilla no se pregunta la institución.

---

## P1

### D-12 · Filtro por campo inoperante

- **Evidencia**: sonda P13: en las zonas de las 12 capturas se muestran todas las tarjetas; sin
  lista blanca se retirarían, p. ej., CONOCER y CELULAR en «¿Quién le envía…?»; 73 de 374 pares en
  total.
- **Causa raíz**: `cards_provider.dart:130-136` (fuente = lista blanca) + `candidate_engine.dart:127`
  (exención) + reglas permisivas (`:201-224`).
- **Prueba**: con el banco como fuente, una prueba recorre todas las preguntas y comprueba que cada
  tarjeta ofrecida pertenece a `respuestas` de su pregunta (no a `noOfrecer`).

### D-13 · Formulación como respuesta

- **Evidencia**: `matriz_zonas_actuales.csv` (16 `formulacion`, 15 `modificador`, 39 `invalida`);
  98 nodos con `glosas_del_enunciado_como_respuesta`.
- **Causa raíz**: listas blancas tomadas de «conceptos LSB objetivo» del corpus §6;
  `build_dialogue_graph.py:208`.
- **Prueba**: ninguna tarjeta de la columna `noOfrecer` aparece en su pregunta; ningún nodo §6
  ofrece una interrogativa.

### D-14 · «¿Quién…?» sin identidad

- **Evidencia**: C05, C06, C10; sondas P07/P08 (`hay_campo_nombre = false`, persona `suspect`).
- **Causa raíz**: la zona `persona` despacha siempre al asistente
  (`qualifier_sheets.dart:399-414`); `PersonEntity` sin nombre/teléfono
  (`declaration_draft.dart:38-59`).
- **Prueba**: «¿Quién envió los mensajes?» → cuatro ramas; «Solo conozco el número» abre un teclado
  telefónico; la frase es «No conozco su nombre; el número que aparece es 71234567.»; no se abre el
  asistente de género/ropa.

### D-15 · Asistente de persona

- **Evidencia**: C05/C06 («No identificado / Omitir» marcado sin tocar); rol por defecto `suspect`
  (`entity_editor_sheets.dart:402`); Niño/Anciano (`:738-764`) sin glosa ni lexema (se pierden en
  `local_sentence_assembler.dart:215-218`).
- **Prueba**: abrir la descripción no marca ninguna opción; Q.PER.DESC.EDAD acepta «24» →
  «Tenía aproximadamente 24 años.»; ninguna opción sin representación.

### D-16 · Editor de monto

- **Evidencia**: C02 (campo tapado), C03 (importes rápidos); `amount_input_sheet.dart:148` sin
  `viewInsets`, `:268-307` importes, `:22/59` rol `stolen`, `:181` «sustraído», `:343-353`
  «(Omitir)».
- **Prueba**: con el teclado abierto en un teléfono de 6", el campo, la moneda y «Confirmar» son
  visibles; no hay importes rápidos; «No recuerdo el monto» y «Cancelar» son controles distintos;
  el monto se guarda en `transaccion.monto`.

### D-17 · Teclados no pertinentes

- **Evidencia**: sonda P07 (CELULAR en «tipo de mensajes» abre «Escribe el número»); sonda P05
  (BANCO abre «Deletrea el nombre de la banco»).
- **Causa raíz**: `_admiteDetalle` global, sin mirar la pregunta (`local_sentence_assembler.dart:1045-1054`;
  `qualifier_sheets.dart:300-312`).
- **Prueba**: un editor solo se abre si la respuesta del banco declara `editor`.

### D-18 · PAPEL e IDENTIDAD

- **Evidencia**: `disambiguation_modal.dart:110-192` (rol `evidenceSupport` siempre; «Factura o
  recibo» en la misma pantalla que FACTURA; dos hojas para el carnet).
- **Prueba**: carnet robado → «Me robaron mi carnet de identidad.»; en `comprobante`, PAPEL solo
  como «no sé cómo se llama» y su aclaración no muestra FACTURA.

### D-19 · Evidencia mal registrada

- **Evidencia**: sonda P03 (`comprobante` no llega); sonda P07 («Cuento con total y ahora mismo
  como prueba.»).
- **Causa raíz**: `denuncia_robo_draft_provider.dart:572-593` solo excluye MOSTRAR/PUEDO.
- **Prueba**: solo los tipos del banco (factura, comprobante del banco, fotos, capturas, video,
  certificado, mensajes, otro) llegan a `evidencia[]`.

### D-20 · Preguntas compuestas

- **Evidencia**: 8 zonas (`08 §5.6`).
- **Prueba**: cada pregunta compuesta se presenta como dos controles independientes y las cuatro
  combinaciones producen frases distintas (tabla D2 de `09`).

### D-21 · Rutina médica

- **Evidencia**: sonda P17 (robo: `emergencia` en el recorrido; violencia: `salud_urgencia` y
  `emocion_riesgo` obligatorias).
- **Prueba**: robo, engaño, amenazas, consultas y trámites no muestran preguntas médicas salvo que
  se declare una agresión o la persona lo pida; AUXILIO sigue accesible.

### D-22 · Inferencia de zona en C

- **Evidencia**: `matriz_nodos_grafo.csv`: 81 de 98 enunciados muestran otra pregunta; réplica
  contrastada con el Dart en 20 casos.
- **Causa raíz**: subcadenas + comparación del id de destino con el texto de otras zonas
  (`zone_inference_engine.dart:257-282`).
- **Prueba**: para los 98 enunciados del corpus, la pregunta mostrada es la del banco asignada a su
  nodo (tabla de `11_Matriz_Preguntas.md` vacía).

### D-23 · Generador del grafo

- **Evidencia**: 16 disyuntivas tratadas como sí/no, 21 nodos con interrogativa como respuesta, 94
  con opciones fuera de ranura.
- **Causa raíz**: `build_dialogue_graph.py:96-108, 140-181, 208`.
- **Prueba**: `build_dialogue_graph.py --check` y una prueba que exige, para cada nodo §6,
  `answerOptions ⊆ respuestas del banco` y `formulationGlosses` separadas.

### D-24 · Modos sin diferencia real

- **Evidencia**: sonda P13 (+30 constante); `context_selection_widget.dart:66`; `initialScopes` sin
  uso; `intentId` sin asignación en `lib/`.
- **Prueba**: ventanilla con perfil Fiscalía no pregunta la institución que atiende; personal con
  necesidad «Consultas» no ofrece recorridos de denuncia salvo que se pida «Otra cosa»; DDRR con una
  consulta de folio muestra el aviso de vocabulario ausente.

### D-25 · Sin frase previa

- **Evidencia**: `031b821` quitó `liveText = assembleStructured(draft)` del panel; fallan
  `misc_ux_fixes_test.dart:116, 136` y `person_full_traits_ui_test.dart:87`.
- **Prueba**: tras cada respuesta, la frase previa se actualiza y marca lo pendiente.

### D-26 · Sin salidas por pregunta

- **Evidencia**: C01–C12 sin «No lo sé»/«Omitir»; `node_flow_canvas.dart:10-12`.
- **Prueba**: cada pregunta muestra las salidas de su entrada del banco; el borrador distingue
  `omitido` de `sin_respuesta`.

### D-27 · Borrador que sobrevive

- **Evidencia**: sonda P16 (`CELULAR` sigue tras un encargo nuevo del mismo contexto).
- **Causa raíz**: `openCards` no reinicia `declarationDraftProvider` (`conversation_handoff.dart:80-92`).
- **Prueba**: abrir la respuesta a un turno nuevo deja personas, objetos y hechos vacíos, salvo
  reutilización confirmada.

### D-28 · Zonas encadenadas inalcanzables

- **Evidencia**: sonda P17 (`cantidad`, `cantidad_pregunta` nunca visitadas);
  `semantic_zones_provider.dart:371-378`; SÍ en testigos no abre cantidad (no está en el mapa de
  unidades de `:267-270`).
- **Prueba**: «¿Hay testigos?» = Sí ofrece «¿Cuántos?» con editor numérico.

### D-29 · Sin «Iniciar conversación» en personal A

- **Evidencia**: `declaration_result_screen.dart:186` (solo con `servesConversation`).
- **Prueba**: en personal A, el resultado ofrece «Iniciar conversación con este mensaje»; el turno
  creado tiene `replyToId = null` y el mismo texto, sin reconstruirlo.

### D-30 · «Preguntas» en serie

- **Evidencia**: sonda P17 (con DÓNDE se visitan igual persona, tema y tiempo).
- **Prueba**: tras elegir DÓNDE solo aparece «¿Dónde queda…?».

---

## P2

| Id | Evidencia | Prueba |
|---|---|---|
| D-31 | AL-LADO con significado «El» en la fila 597 del corpus; CONOCER rotulada «CONOCIDO» y redactada «conozco a esa persona» | Tras corregir el corpus y regenerar, la tarjeta dice «AL LADO»; CONOCER tiene una sola acepción documentada por uso |
| D-32 | `local_sentence_assembler.dart:2197-2206` (0–9 y letras como `verboAccion`) | `functionOf('7')` devuelve `marker` |
| D-33 | `entity_editor_sheets.dart` (10 colores; solo NEGRO, AZUL, ROJO en el catálogo) | Los colores sin glosa aparecen como «texto» y no como tarjeta |
| D-34 | C12 (🪪 sin glifo) | La cabecera muestra un icono con glifo disponible |
| D-35 | `flutter analyze`: 10 avisos (`yaRespondidas` sin usar, `_PairHint`, importaciones) | `flutter analyze` sin avisos |
| D-36 | `vocabulario_unico_test.dart`: la Lambda texto→LSB declara CERO…DIEZ, CONTESTAR, PARA_QUÉ… | La prueba vuelve a pasar tras `dart run tool/sync_vocabulary.dart` o separando «clips del avatar» de «tarjetas» |
