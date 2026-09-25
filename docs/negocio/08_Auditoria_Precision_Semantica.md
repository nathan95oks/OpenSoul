# Auditoría de precisión semántica: preguntas, respuestas y frases

Fase 1 — especificación verificable. **No se ha modificado código de producción.**
Fecha: 2026-09-25.

Documentos de esta fase:

| Archivo | Contenido | Origen |
|---|---|---|
| `08_Auditoria_Precision_Semantica.md` | Este documento: base, diagnóstico, contrato de interacción, modelo de datos, modos, DDRR/Notaría/GAMC, reconciliación | escrito |
| `09_Recorridos_A_I.md` | Recorridos A–I, consultas y trámites cubiertos, conversación de tres turnos, combinaciones lícitas e ilícitas | escrito |
| `10_Defectos_Priorizados.md` | 36 defectos con causa raíz, evidencia y prueba de aceptación observable | escrito |
| `11_Matriz_Preguntas.md` | Matriz maestra revisable | generado |
| `12_Brechas_Lexicas_Animacion.md` | Brechas de vocabulario y de animación | generado |
| `config/banco_preguntas.json` | **Fuente editable** del banco semántico, veredictos por glosa, comparativa de modos, brechas | escrito |
| `matriz_preguntas.json` · `.csv` | Matriz procesable: una entrada por pregunta; una fila por respuesta | generado |
| `matriz_zonas_actuales.csv` | Las 374 combinaciones zona-glosa de hoy, con su veredicto | generado |
| `matriz_nodos_grafo.csv` | Los 209 nodos del grafo, con diagnóstico y la pregunta que se muestra hoy | generado |
| `matriz_modos.csv` | Comparativa personal / ventanilla | generado |
| `evidencia/2026-09-25/` | Sondas ejecutadas contra el código real y sus resultados | escrito |

Lo generado se regenera con `python tool/build_question_matrix.py`, que valida el banco
contra el catálogo, la tabla léxica, `context_catalog.dart`, la inferencia de zonas y el grafo,
y no escribe nada si encuentra una contradicción.

---

## 0. Base de la auditoría

### 0.1. Qué código se auditó

| Fuente | Estado |
|---|---|
| `OpenSoul-main (5).zip` (Descargas, 25-09 12:52) | Extraído y comparado archivo por archivo |
| Repositorio local `C:\Users\LENOVO\OpenSoul\OpenSoul` | HEAD `031b821` (25-09 03:47, «unify purple selection theme…») |
| `OpenSoul-main-2976277.zip` | **No usado**, como se pidió |

**ZIP = HEAD**, ignorando finales de línea. Las únicas diferencias son tres cambios sin
confirmar del árbol local: `AndroidManifest.xml`, `Info.plist` y `lib/main.dart`, que fijan
la orientación vertical. No afectan a ninguna ruta semántica. La auditoría se basa en HEAD.

**Cambios concurrentes durante la auditoría.** Entre las 13:45 y las 13:55, mientras corrían
las pruebas, aparecieron modificaciones sin confirmar que no hice yo, en
`animation_cache.dart`, `animation_repository*.dart`, `avatar_3d_viewer.dart`,
`animation_url_resolver.dart` (añade `PRIMERA_VEZ` a los clips declarados),
`aws/lambda_text_to_lsb.py`, `aws/tests/test_animaciones_glb.py` y
`test/animation_repository_test.dart`. Son de la ruta texto→LSB (avatar). No los he tocado.
El inventario de animación de este documento corresponde a HEAD.

### 0.2. Capturas

Doce fotos (`Pictures/telegram/photo_2026-09-25_13-16-11.jpg` … `13-17-21.jpg`). Las diez de
`Downloads/Telegram Desktop` son copias idénticas (mismo MD5) de diez de ellas.

| Id | Hora | Contexto | Pregunta en pantalla | Tarjetas | Zona en código |
|---|---|---|---|---|---|
| C01 | 12:59 | Engaño con dinero | ¿Cómo ocurrió el engaño con el dinero? | ENGAÑAR✓ BILLETES ENVIAR DAR PERDER | `engano_dinero/hecho` (`context_catalog.dart:557-568`) |
| C02 | 13:00 | Engaño con dinero | ¿Cómo entregó o envió el dinero? + hoja «¿Cuánto dinero fue?» con teclado | BANCO CELULAR (fondo); Bs/USD; campo tapado por el teclado | `medio_banco` + `amount_input_sheet.dart` |
| C03 | 13:00 | Engaño con dinero | ídem, sin teclado | 0 · 50/100/200/500/1000 Bs · «DIGITA UN MONTO» · «No recuerdo la cifra exacta (Omitir)» | ídem |
| C04 | 13:00 | Engaño con dinero | ¿Tiene el papel del banco o factura? | PAPEL BANCO FACTURA ESCRIBIR TOTAL GUARDAR MOSTRAR PUEDO | `comprobante` (`:593-606`) |
| C05 | 13:01 | Engaño con dinero | ¿Conoce el nombre o número de la persona? | CELULAR✓ → asistente «1. Género 2. Edad 3. Rasgos 4. Ropa», «No identificado / Omitir» marcado | `persona` (`:581-592`) + `entity_editor_sheets.dart:388` |
| C06 | 13:01 | Engaño con dinero | ídem | NOMBRE✓ → el mismo asistente | ídem |
| C07 | 13:01 | Engaño con dinero | ¿Desea presentar la denuncia formal? | POLICÍA FELCC FISCALÍA SEPDAVI ABOGADO✓ · botón «EMITIR DECLARA…» con mazo | `institucion` (`:607-619`) |
| C08 | 13:02 | Amenazas digitales | ¿Qué tipo de mensajes recibió? | AMENAZAR CELULAR✓ INTERNET ESCRIBIR ENVIAR RECIBIR AÚN | `amenaza_digital/hecho` (`:491-504`) |
| C09 | 13:02 | Amenazas digitales | ¿Guardó los mensajes o tiene fotos de pantalla? | ESCRIBIR TOTAL GUARDAR FOTOS CELULAR VIDEO MOSTRAR PUEDO (AHORA fuera de vista) | `evidencia` (`:518-531`) |
| C10 | 13:02 | Amenazas digitales | ¿Quién le envía los mensajes? | PAREJA HOMBRE MUJER CONOCIDO CELULAR✓ | `persona` (`:505-517`) |
| C11 | 13:03 | Declaración y testimonio | ¿Qué presenció o desea declarar? | TOTAL NARRAR EXPLICAR EMPEZAR AUMENTAR✓ ARREGLAR (OBSERVAR, TESTIGO, TESTIMONIO, VER fuera de vista) | `otro/relato` (`:697-709`) |
| C12 | 13:04 | Mis datos (emoji sin renderizar) | ¿Cuál es su nombre e identidad? | NOMBRE PAPEL✓ IDENTIDAD SORDO LEER POCO (INTÉRPRETE fuera de vista) | `identificacion/identidad` (`:115-130`) |

En las doce, las tarjetas muestran icono genérico y glosa: no se ve la imagen de la seña
(`iconUrl` vacío en las 346 entradas; las imágenes dependen de una URL externa no incluida).

### 0.3. Comandos ejecutados y resultados

| Comando | Resultado | Lectura |
|---|---|---|
| `flutter analyze` | **10 avisos** | `07_Estado_Implementacion.md` dice «No issues found!» (24-09). Los introdujo `031b821`, entre ellos `yaRespondidas` sin usar. |
| `flutter test` | **614 aprobadas, 1 omitida, 4 fallidas** | 3 fallan porque `031b821` quitó la frase previa del panel de construcción; 1 porque `3f40c8e` declara glosas de avatar que no son tarjetas. |
| `python -m unittest discover -s aws/tests` | 234 aprobadas | Solo dobles de boto3. |
| `python tool/build_dialogue_graph.py --check` | Grafo al día con el corpus | El grafo reproduce fielmente el corpus… y sus defectos de generación (§4.10). |
| Sonda Dart `probe_semantica_test.dart` (17 casos) | Ejecutada contra el código real, con toques simulados sobre `elegirGlosa` | Resultados en `evidencia/2026-09-25/probe_dart.json`. |
| Sonda Python `probe_lambda.py` | `generate_structured_sentence` con los borradores que envía la app | `evidencia/2026-09-25/probe_lambda.json`. |
| `python tool/build_question_matrix.py --check` | 0 errores | El banco nuevo es coherente con el repositorio. |

Una prueba verde no demuestra adecuación semántica: las 614 pruebas en verde conviven con
todos los defectos de este documento.

---

## 1. Conclusiones para decidir

1. **La precisión no la decide el filtro, sino las listas blancas, y las listas blancas se
   copiaron de la formulación de la pregunta.** Las zonas se construyeron con la columna
   «conceptos LSB objetivo» del corpus §6, que es la glosa **de la pregunta del funcionario**,
   no de su respuesta: «¿Conserva toda la conversación?» = ESCRIBIR · TOTAL · GUARDAR;
   «¿Puede mostrar el celular ahora?» = CELULAR · AHORA · MOSTRAR · PUEDO. Por eso C04 y C09
   ofrecen TOTAL, GUARDAR, MOSTRAR, PUEDO. El generador del grafo hace lo mismo en los 98 nodos
   del funcionario (`build_dialogue_graph.py:208`), incluida la interrogativa DÓNDE como
   respuesta a «¿Dónde ocurrió?».
2. **El filtro por campo no retira nada en ninguna de las 12 pantallas observadas.** Las
   tarjetas salen solo de la lista blanca (`cards_provider.dart:130-136`) y la lista blanca
   está exenta del filtro (`candidate_engine.dart:127`). Sin esa exención retiraría 73 de 374
   pares, pero seguiría dejando pasar todo en zonas `free_text` o solo-polaridad (la mayoría
   de los errores de C01, C08, C11).
3. **La bonificación de perfil y necesidad no cambia el orden**: suma +30/+10 a todas las
   tarjetas del mismo cálculo (sonda P13: diferencia constante de 30,000).
4. **Personal y ventanilla recorren exactamente las mismas 46 preguntas.** La única diferencia
   real es la pantalla de necesidades del modo personal. La necesidad no filtra contextos, el
   perfil no ordena, `ambitosIniciales` no se usa y `intentId` nunca se asigna, así que los
   avisos de «falta vocabulario» de DDRR, Notaría y GAMC son inalcanzables.
5. **En modo respuesta, 81 de las 98 preguntas del funcionario llevan a otra pregunta de
   pantalla** (p. ej. «¿Guardó los mensajes?» → «¿Qué tipo de mensajes recibió?»;
   «¿Le robaron el celular?» → «¿Qué objetos…?» sin Sí/No).
6. **Las aclaraciones se pierden o se invierten.** Elegir «Yo logré escapar» se descarta
   (D-01, sonda P01); «Sospecho de robo» termina en «perdí» (D-02); cancelar una hoja añade la
   tarjeta igualmente (D-03).
7. **La frase no refleja lo elegido.** La interfaz siempre redacta con `assembleStructured`,
   que tiene frases fijas por contexto: Preguntas → siempre «¿Dónde debo realizar esta
   consulta…?» (aunque se eligió CUÁNDO + VOLVER); Declaración → siempre «testigo presencial»;
   Mis datos → pierde nombre y edad; Engaño → pierde el monto; Amenazas → inventa «WhatsApp».
   Las 139 frases del corpus de `_matchDirectIdioms` no se alcanzan desde las tarjetas.
8. **`031b821`, presentado como cambio de tema visual, rompió reglas semánticas**: ignora
   `maxPicks` (SÍ y NO a la vez → «confirmado»), quita la frase previa y deja
   `alreadyAnswered` vacío.
9. **El modelo de datos no puede guardar lo que el encargo pide**: una persona no tiene nombre,
   teléfono ni edad numérica; el monto vive en un objeto «robado»; herido/atención/apoyo son
   booleanos que no distinguen «no» de «no contestado».
10. **Se afirma formalidad que no existe**: «EMITIR DECLARACIÓN» con mazo, «Tu declaración
    formal ha sido consolidada», «Texto formal para autoridades», «Denuncio…» en la Lambda,
    «Selecciona la categoría exacta para el acta formal».

---

## 2. Verificación de la evidencia aportada

| Afirmación del encargo | Veredicto | Precisión |
|---|---|---|
| «¿Quién le envía los mensajes?» incluye CELULAR | **Confirmada** | `context_catalog.dart:512-515`; C10. Además, tocarla abre el asistente de **sospechoso** (`qualifier_sheets.dart:399-414`, `entity_editor_sheets.dart:402`), sonda P07. |
| «¿Tiene el papel del banco o factura?» mezcla PAPEL, FACTURA, ESCRIBIR, TOTAL, GUARDAR, PUEDO | **Confirmada**, y también BANCO y MOSTRAR | `:601-604`; C04. Ninguna de estas respuestas llega al borrador: `buildFullDeclarationDraft` solo lee la zona `evidencia`, no `comprobante` (sonda P03). |
| «¿Cómo ocurrió el engaño…?» ofrece ENGAÑAR con BILLETES, ENVIAR, DAR, PERDER | **Confirmada** | `:564-566`; C01. Elegir BILLETES crea el hecho `BILLETES` (sonda P04). |
| `zoneAllowlist` evita el filtro por campo | **Confirmada**, y es peor | Es la única fuente de tarjetas; no hay categorías ni buscador montados en la interfaz actual (`CardGrid`, `ConfiguredEntityChips`, `CoherenceBanner` no se usan). |
| El filtro deja pasar glosas no clasificadas, marcadores y cualquier glosa en zonas solo-polaridad | **Confirmada** | `candidate_engine.dart:201-224`. También deja pasar todo en `free_text` (`:217`). Los dígitos 0–9 (y las letras) están clasificados como `verboAccion` (`local_sentence_assembler.dart:2197-2206`). |
| La bonificación por perfil/necesidad es igual para todas las tarjetas | **Confirmada**: no reordena | `:159-164`; `_servesNeed` ni siquiera depende de la tarjeta. Sonda P13. |
| Algunas rutas seleccionan la glosa tras un modal aunque se cierre sin confirmar | **Confirmada** en 8 despachos | ESCAPAR, PERDER, PAPEL, IDENTIDAD, CAJA/BOLSA/MOCHILA, MICRO/TRUFI, BILLETES y las tres zonas de entidad (`qualifier_sheets.dart:328-414`). Sondas P03 y P12. |
| El editor de monto combina campo e importes rápidos y se recarga con el teclado | **Confirmada**; causa concreta | La hoja no suma `viewInsets.bottom` (`amount_input_sheet.dart:148`): el teclado tapa el campo (C02). Además, rol fijo «stolen» y texto «monto sustraído/entregado». |
| «¿Conoce el nombre o número…?» → asistente de género, edad, rasgos y ropa | **Confirmada** | No existe campo de nombre ni teléfono de terceros: `PersonEntity` no los tiene (`declaration_draft.dart:38-59`). Sonda P08. |
| La categoría «Edad» muestra EDAD, JOVEN, ADULTO; el asistente usa rangos | **Confirmada**, con matiz | En «Mis datos», EDAD abre un teclado de dígitos, pero el valor no llega a la frase (sonda P09). El asistente de persona ofrece Niño/Anciano, que no existen en el catálogo ni en la tabla léxica: desaparecen de la frase. |
| Rutina médica en varias zonas | **Confirmada** | Robo: `emergencia` en el recorrido de 12 preguntas; violencia: `salud_urgencia` y `emocion_riesgo` **obligatorias** (sonda P17). |
| «¿Desea presentar una denuncia formal?» ofrece instituciones | **Matiz**: es la zona de **engaño** («…**la** denuncia formal», C07) y la de amenazas («¿Desea presentar los mensajes como prueba?»). La de robo sí ofrece SÍ/NO/NO_SABER/AHORA, pero su zona siguiente pregunta «¿Ante qué autoridad…?» con SEPDAVI, ABOGADO e INTÉRPRETE. |
| «¿Dónde ocurrió?» en el grafo ofrece DÓNDE | **Confirmada** | `n-s6-inicio_de_denuncia-07`: opciones `[DÓNDE, NO_SABER]`. 21 nodos ofrecen una interrogativa como respuesta. |
| «¿Qué presenció…?» ofrece TOTAL, NARRAR, EXPLICAR, EMPEZAR, AUMENTAR, ARREGLAR | **Confirmada** | Ninguna introduce contenido declarable (§4.1). La frase resultante es siempre «El declarante se presenta en calidad de testigo presencial de los hechos.» |
| Contextos y zonas compartidos entre modos | **Confirmada** | §6 y `matriz_modos.csv`. |

---

## 3. Inventario de rutas

### 3.1. Contextos, zonas y orden real

Orden obtenido pulsando CONTINUAR sucesivamente en el código real (sonda P17). «Nunca» =
zona declarada que la navegación no activa.

| Contexto (familia en el selector) | Preguntas en orden | Obligatorias | Nunca |
|---|---|---|---|
| `denuncia_robo` (Denuncias) | hecho → objetos → persona → lugar → tiempo → conocimiento → testigos → evidencia → emergencia → denuncia → apoyo_legal → institucion | hecho, objetos, lugar | cantidad |
| `violencia` (Denuncias) | hecho → persona → salud_urgencia → emocion_riesgo → institucion → tiempo → evidencia (con PEGAR: hecho → salud_urgencia → emocion_riesgo → persona…) | hecho, persona, salud_urgencia, emocion_riesgo, institucion | — |
| `amenaza_digital` (Denuncias) | hecho → evidencia → persona → institucion | hecho, persona, evidencia | — |
| `engano_dinero` (Denuncias) | hecho → medio_banco → comprobante → persona → institucion | hecho, medio_banco, persona, comprobante | — |
| `otro` (Denuncias) | relato → persona → acceso | todas | — |
| `seguimiento` (Consultas) | tramite → institucion_autoridad → accion → tiempo | tramite, accion, institucion_autoridad | — |
| `identificacion` (Trámites) | identidad → contacto → acompanante → edad | identidad | — |
| `preguntas` (Preguntas) | interrogativa → lugar_pregunta → persona_pregunta → tema_pregunta → tiempo_pregunta, **aunque se haya elegido DÓNDE** | interrogativa | cantidad_pregunta |

«Obligatoria» no tiene efecto: la tarjeta de pregunta recibe `isOptional` pero no lo muestra
(`node_flow_canvas.dart`), y CONTINUAR se habilita en cuanto hay **cualquier** respuesta en el
borrador, así que después de la primera zona todas se pueden saltar sin dejar constancia
(sin_respuesta ≡ omitido).

### 3.2. Rutas de interfaz que muestran preguntas

| Ruta | Cómo se llega | Qué pregunta se muestra | Evidencia |
|---|---|---|---|
| **A personal** | Pestaña Tarjetas → necesidades → selector de 4 familias → contexto | Zona de entrada del contexto y luego el orden de §3.1 | `home_screen.dart:37-50` |
| **A ventanilla** | Pestaña Tarjetas → selector de 4 familias | Ídem, sin necesidades | `home_screen.dart:37-50` |
| **B** (inicia la persona sorda en el chat) | Conversación sin turno oyente pendiente → tarjetas | Contexto activo del chat o selector; mismas zonas | `conversation_handoff.dart:40-47` |
| **C** (responde al funcionario) | Conversación con turno oyente → «Responder con tarjetas» | `ZoneInferenceEngine` elige la zona por subcadenas del enunciado; si no reconoce nada, la zona de **entrada** del contexto | `semantic_zones_provider.dart:136-143`; §4.9 |
| Respuesta rápida | Barra «Responder rápido» ante una instrucción | 5 frases fijas («Sí, entendido», «¿Dónde queda?»…) | `quick_reply_bar.dart` |
| Grafo | Solo en C: reconoce el enunciado y **reordena** la lista blanca; nunca añade tarjetas | — | `injection.dart:146-159`; `nextFrom`, `candidates`, `forIntent` sin uso |

La columna `preguntaMostradaHoy` de `matriz_nodos_grafo.csv` da, para cada una de las 98
preguntas del funcionario, la pregunta de pantalla que aparece hoy en C.

---

## 4. Diagnóstico por mecanismo (causas raíz)

### 4.1. Glosas de la formulación presentadas como respuestas

Una pregunta tiene dos vocabularios: el que la **formula** y el que la **responde**. El
corpus §6 da el primero. Las listas blancas y el grafo lo usaron como segundo.

| Pregunta en pantalla | Glosas que son formulación (corpus §6) | Qué debería ofrecerse |
|---|---|---|
| ¿Tiene el papel del banco o factura? (C04) | PAPEL, BANCO, TENER · ESCRIBIR, TOTAL, GUARDAR (fila «¿Conserva toda la conversación?») · MOSTRAR, PUEDO (fila «¿Puede mostrarlo ahora?») | Sí / No / No sé → si Sí: comprobante del banco (PAPEL·BANCO), factura, capturas, «un papel, no sé cuál» |
| ¿Guardó los mensajes o tiene fotos de pantalla? (C09) | ESCRIBIR, GUARDAR, TOTAL, FOTOS·CELULAR, MOSTRAR, PUEDO, AHORA | Dos preguntas Sí/No/No sé independientes |
| ¿Qué tipo de mensajes recibió? (C08) | ENVIAR, RECIBIR, AÚN (fila «¿Sigue recibiendo mensajes?») | Canal (CELULAR, INTERNET) y contenido (AMENAZAR) por separado |
| ¿Qué presenció o desea declarar? (C11) | NARRAR, EXPLICAR, EMPEZAR, TOTAL (verbos del acto de relatar) · AUMENTAR, ARREGLAR (solicitudes procedimentales) | El contenido observado (qué acción, a quién) |
| ¿Dónde ocurrió? (grafo) | DÓNDE | Tipo de lugar + nombre literal |

`matriz_zonas_actuales.csv` marca 16 pares como `formulacion`, 15 como `modificador`
(TOTAL, POCO, GRATIS…) y 39 como `invalida`.

### 4.2. El filtro por campo no actúa

Tres vías lo neutralizan, en este orden:

1. **Fuente única = lista blanca** (`cards_provider.dart:130-136`): nada fuera de ella llega.
2. **La lista blanca está exenta** (`candidate_engine.dart:127-131`).
3. **Las reglas del propio filtro**: `free_text` acepta todo (`:217`), una zona solo-polaridad
   acepta todo (`:212-214`), una glosa sin clasificar pasa (`:219-220`) y un marcador pasa
   (`:224`). Las zonas `hecho`, `relato`, `accion`, `tramite`, `denuncia`, `emergencia`,
   `salud_urgencia`, `emocion_riesgo`, `interrogativa` y `tema_pregunta` son `free_text`.

Además, la clasificación que usa (`functionOf`) tiene errores de base: dígitos como verbo,
BANCO como lugar (no pasa en «¿Cómo envió?»), NOMBRE e IDENTIDAD como marcadores.

**Conclusión**: el filtro por campo no puede ser la garantía de precisión. La garantía es el
banco de respuestas por pregunta (`config/banco_preguntas.json`); el filtro queda como red.

### 4.3. Perfil y necesidad no ordenan

`score += 30` si el perfil prioriza la intención del nodo y `+= 10` si el perfil prioriza la
necesidad: ambos términos son iguales para todas las tarjetas de una llamada
(`candidate_engine.dart:159-164`). El orden resultante es idéntico con y sin perfil (sonda P13).

### 4.4. Las hojas añaden la tarjeta al cancelar

`elegirGlosa` hace `await hoja; toggleAnswer(glosa)` sin mirar el resultado en ocho ramas
(`qualifier_sheets.dart:328-414`). Cancelar deja la glosa en la frase sin su dato; si la
tarjeta ya estaba elegida, tocarla la **quita** después de abrir la hoja. La hoja de persona
además crea la persona (rol `suspect`) antes de cualquier elección
(`entity_editor_sheets.dart:499-509`). Sondas P03 (PAPEL queda) y P12 (HOMBRE y una persona
quedan).

### 4.5. Aclaración y borrador desconectados

- **ESCAPAR**: la hoja busca el hecho ESCAPAR en el borrador de entidades
  (`disambiguation_modal.dart:38`), pero la interfaz nunca lo crea allí (`toggleFactAction`
  no tiene llamadas en `lib/`): la elección se descarta sin aviso. Sonda P01: «Una persona me
  robó. Hubo una huida, sin precisar de quién.»
- **PERDER**: «Sospecho de robo» crea ROBAR en el borrador de entidades; al combinar,
  `retainWhere` elimina todo hecho que no esté en la zona (solo PERDER) y queda PERDER sin
  aclaración (`denuncia_robo_draft_provider.dart:531-534`). «No lo sé» crea… ROBAR
  (`:112`). Sonda P02: «No sé con certeza qué ocurrió; puede que haya perdido algo.»

### 4.6. `maxPicks` ignorado desde `031b821`

`toggleAnswer` ya no consulta `maxPicks` (`semantic_zones_provider.dart:207-215`). Sonda P06:
SÍ y NO a la vez en «¿Desea presentar…?» → `willFileComplaint = confirmed`; tres hechos
aceptados en la zona y el tercero descartado en silencio al redactar.

### 4.7. Redacción fija por contexto

La interfaz **siempre** envía el borrador, así que el texto local es siempre
`assembleStructured` (`conversation_engine.dart:57-62`). Sus ramas por contexto ignoran las
respuestas (`local_sentence_assembler.dart:351-395`):

| Contexto | Frase local (sonda) | Frase de la Lambda (sonda) |
|---|---|---|
| preguntas (CUÁNDO + VOLVER) | ¿Dónde debo realizar esta consulta o presentar el trámite? | ídem |
| otro (AUMENTAR) | El declarante se presenta en calidad de testigo presencial de los hechos. | ídem |
| seguimiento | El ciudadano consulta el estado de su trámite o investigación. | ídem |
| identificacion (nombre Juan, edad 24) | El declarante se identifica ante la autoridad competente. | Datos de identificación: |
| violencia (AMENAZAR) | El declarante denuncia haber sufrido amenazar. | Denuncio agresión física y violencia sufrida. |
| amenaza_digital (CELULAR) | El declarante refiere haber recibido amenazas a través de WhatsApp. | Denuncio la recepción de mensajes hostiles… Canal utilizado: WhatsApp. |
| engano_dinero (ENVIAR, BANCO, 150 Bs) | El declarante denuncia haber sido víctima de engaño económico mediante banco. | Denuncio un engaño económico / engaño económico. |
| denuncia_robo (ROBAR+ESCAPAR yo, celular) | *(inalcanzable desde la interfaz: D-01)* | Denuncio el robo de mi celular. Logré escapar. |

El texto final puede venir de Bedrock, pero parte de estas bases y su comportamiento real no
está medido. Las 139 frases del corpus de `_matchDirectIdioms` (`:499-884`) solo las usa
`assemble()`, que la interfaz no llama.

### 4.8. Datos que no llegan al borrador o al servidor

| Dato | Dónde se pierde |
|---|---|
| Nombre, edad, contacto, acompañante («Mis datos») | `buildFullDeclarationDraft` no lee esas zonas; las letras viajan solo como glosas sueltas |
| Comprobante (engaño) | Solo se lee la zona `evidencia`, no `comprobante` |
| Monto de engaño | Se guarda como objeto `BILLETES` con rol `stolen`; `FraudDetails.amount` nunca se llena |
| Medio, receptor, comprobante (Lambda) | El cliente envía `deliveryMethod`, `recipientName`, `receiptDoc`; la Lambda lee `delivery_method`, `recipient_name`, `receipt_doc` (`lambda_function.py:2324-2331`) |
| Atención médica/protección (Lambda) | Cliente: `medicalCareRequested`, `protectionRequested`; Lambda: `atencion_medica`/`medical_care_requested`, `solicita_medidas_proteccion`/`protection_requested` |
| Cantidad de testigos | La zona `cantidad` nunca se activa y SÍ no abre el selector |

### 4.9. Inferencia de zona en modo respuesta

`ZoneInferenceEngine` busca subcadenas («donde», «quien», «nombre», «documento»…) y, si la
zona no existe en el contexto, compara el **id de la zona destino** con el texto de las otras
zonas (`zone_inference_engine.dart:271-282`). Resultado, replicado para los 98 enunciados del
corpus y contrastado con el Dart real en 20 casos sin discrepancias: **81 muestran otra
pregunta**. Ejemplos: «¿Cómo se llama?» en robo → «¿Qué objetos están involucrados?»;
«¿Conoce el nombre de la persona?» en engaño → «¿Cómo ocurrió el engaño…?».

### 4.10. Generador del grafo

- `build_options` convierte los conceptos de la fila en opciones (`build_dialogue_graph.py:140-181, 208`).
- `is_polar_question` considera sí/no toda pregunta que no empieza por interrogativa
  (`:96-100`): «¿Era un hombre o una mujer?», «¿Vino solo o acompañado?», «¿Fue hoy, ayer o
  antes?», «¿A qué hora…?» reciben SÍ/NO. 16 disyuntivas afectadas.
- `slots_for` por expresiones regulares: «¿Conoce el número…?» → solo polaridad; «¿Cuál es su
  nombre completo?» → `free_text`.

### 4.11. Modelo de datos insuficiente

`PersonEntity` sin nombre, teléfono, edad numérica ni conocimiento propio; `injured`,
`medicalHelpRequested`, `needsLegalSupport` booleanos (no distinguen «no» de «no
contestado»); `EvidenceItem` sin tipo cerrado; `ObjectInvolved` hace de transacción;
`copyWith` con `??` impide volver a `null` (quitar una institución o un `replyToId`).

### 4.12. Sin frase previa ni controles de salida

`031b821` eliminó la frase previa del panel de construcción: la versión anterior mostraba
`liveText = assembleStructured(draft)` (tres pruebas de interfaz lo detectan). La tarjeta de pregunta anuncia «acciones rápidas (No lo sé / Omitir)» en su
comentario (`node_flow_canvas.dart:10`) pero no las tiene.

### 4.13. Borrador que sobrevive al encargo

`openCards` con un encargo nuevo limpia frase y zonas pero no el borrador de entidades
(`conversation_handoff.dart:80-92`). Si el contexto propuesto es el mismo, `contextProvider`
no notifica y personas, objetos y hechos del turno anterior siguen ahí (sonda P16).

---

## 5. Especificación: contrato de interacción

### 5.1. Principios

| # | Principio |
|---|---|
| P1 | **Una pregunta pide un dato de una clase.** Si importan dos datos, son dos preguntas (se pueden mostrar juntas, pero se responden por separado). |
| P2 | **Cada opción cambia un dato interpretable** del borrador y aparece fielmente en la frase. Una opción que no cambia nada no se ofrece. |
| P3 | **La glosa que formula no responde.** Las glosas del enunciado del funcionario sirven para reconocerlo, nunca como tarjetas de respuesta. Las interrogativas solo son opciones cuando la persona sorda formula su propia pregunta (A/B). |
| P4 | **Texto literal ≠ glosa.** Nombres, números de teléfono o documento, edades, cantidades, montos y nombres de lugar se escriben en un editor del tipo adecuado, se guardan literales y no se convierten en señas. La dactilología en el avatar solo se ofrece si el recurso existe y la ruta lo soporta. |
| P5 | **Estados distintos**: afirmado, negado, desconocido, omitido, sin respuesta, no preguntado, pendiente de confirmación. Solo los tres primeros producen frase. |
| P6 | **«No» niega lo preguntado y nada más.** No se infiere la inexistencia de categorías no consultadas. |
| P7 | **No se infiere**: ni canal (WhatsApp), ni transferencia, ni fraude consumado, ni receptor, ni edad por rango, ni robo por pérdida. |
| P8 | **Cancelar no añade**; retroceder conserva; cambiar Sí→No elimina los dependientes tras una confirmación que los enumera; cambiar de caso no arrastra personas, documentos ni montos. |
| P9 | **El orden de pulsación no es orden temporal.** Dos hechos se redactan como dos oraciones sin «primero/luego». |
| P10 | **Primera persona de quien habla**, en ambos modos. Sin «El declarante…». |
| P11 | **Ningún performativo no elegido.** «Denuncio…», «Quiero presentar una denuncia», «Solicito…» solo si la persona eligió esa intención. Nunca «presentada», «registrada», «acta», «formal», «consolidada», «emitir». |
| P12 | **La frase previa es visible en todo momento** y marca lo pendiente; la definitiva solo contiene datos confirmados y es la que se reproduce. |
| P13 | **El perfil ordena y omite lo ya conocido, nunca prohíbe.** |

### 5.2. Estados de respuesta

| Estado | Cómo se produce | En la frase previa | En la definitiva |
|---|---|---|---|
| afirmado | SÍ o un valor | el valor | se redacta |
| negado | NO | «No …» | se redacta solo sobre lo preguntado |
| desconocido | «No sé» / «No recuerdo» | «No sé …» | se redacta |
| omitido | botón «Omitir» | «(omitido)» atenuado | nada |
| sin_respuesta | se avanzó sin tocar | «(sin responder)» | nada |
| no_preguntado | condición no activada o dato ya conocido | nada | nada |
| pendiente_confirmacion | dato mencionado por el funcionario, o hoja abierta sin confirmar | «¿…?» destacado | nada; bloquea el envío si es el dato principal |

### 5.3. Clases de control

| Control | Cuándo | Interfaz | Validación | Valor guardado |
|---|---|---|---|---|
| `polar3` | Pregunta cerrada | Sí · No · No sé (+ Omitir) | exactamente una | `{estado}` |
| `polar2` | Cerrada en la que «no sé» no tiene sentido («¿Sabe dónde…?») | Sí · No | una | `{estado}` |
| `alternativa` | Disyuntiva «¿X o Y?» | X · Y · No sé | una | valor |
| `seleccion_unica` / `seleccion_multiple` | Dato de una clase | tarjetas de esa clase + «Otro (escribir)» + salida | máximo declarado | valores |
| `persona_identidad` | «¿Quién…?» | Sé quién es · Solo conozco el número · Puedo describirla · No lo sé | una rama | referencia a Persona |
| `texto_nombre` | Nombre propio | campo de texto; mayúscula inicial; tildes | 1–80 caracteres | literal |
| `telefono` | Número de teléfono | teclado telefónico nativo | 7–8 dígitos (+591 opcional); se relee agrupado «7123 4567» | literal |
| `documento_numero` | Carnet, referencia | alfanumérico | 1–20 | literal |
| `entero` | Edad, cantidad | teclado numérico | rango de la pregunta | número |
| `monto` | Dinero | un campo numérico + Bs/USD | > 0; hasta 2 decimales | `{monto, moneda}` |
| `tiempo` / `hora` | Momento / hora | glosas de momento; «hace N unidad»; hora editable | — | valor |
| `lugar` | Dónde | tipo de lugar + nombre literal opcional + relación con referencia | relación sin referencia = pendiente | valor + literal |
| `texto_detalle` | «Otro» | campo libre | 1–200 | literal, entre comillas en la frase |

Toda hoja con editor tiene «Confirmar» y «Cancelar» explícitos, respeta el teclado
(`viewInsets`) y **no** añade la tarjeta si se cancela.

### 5.4. Contrato de un paso

```
estado previo  → borrador + qué preguntas ya tienen estado + condición de la pregunta
pregunta       → id del banco + formulación visible (en C: además el texto exacto del funcionario)
respuesta      → { preguntaId, estado, valores[], glosas[], literal?, origen: tarjeta|editor|funcionario }
validación     → clase de dato, máximo, rango del editor, dependencia (p. ej. relación sin referencia)
siguiente      → reglas `siguiente` del banco, filtradas por `omitirSi` y por datos ya confirmados
frase previa   → plantilla con marcas de pendiente
frase definitiva → solo datos afirmados/negados/desconocidos; primera persona; sin performativos no elegidos
```

Ejemplo (Q.DIN.MONTO tras Q.DIN.MECANISMO = banco):

```json
{
  "preguntaId": "Q.DIN.MONTO",
  "estado": "afirmado",
  "valores": [{"campo": "Transaccion.monto", "valor": "150", "moneda": "Bs"}],
  "glosas": [],
  "origen": "editor",
  "frasePrevia": "Envié Bs 150 mediante un banco. [¿Comprobante? pendiente]",
  "fraseDefinitiva": "Envié Bs 150 mediante un banco."
}
```

### 5.5. Cuándo no se muestra una pregunta

1. El dato ya tiene estado afirmado, negado o desconocido en esta intervención o fue
   confirmado en un turno anterior de la misma atención (con opción visible «Cambiar»).
2. En C, el enunciado del funcionario ya fija el dato: se muestra la confirmación
   (Q.ROB.CONFIRMA_OBJETO), no la selección.
3. En ventanilla con perfil, no se pregunta la institución que atiende (Q.DEN.AUTORIDAD,
   Q.SEG.AUTORIDAD).
4. Su condición no está activada (preguntas médicas, descripción de persona, cantidad de
   testigos sin «Sí»).
5. La pregunta padre recibió «No» o «No sé» (no se pregunta el tipo de un comprobante que no
   se tiene).

### 5.6. Preguntas compuestas

Se dividen: «¿Guardó los mensajes o tiene fotos de pantalla?» → Q.DIG.GUARDO + Q.DIG.CAPTURAS;
«¿Tiene la factura o la caja?» → Q.EVI.FACTURA + Q.EVI.CAJA; «¿Está herido o necesita atención?»
→ Q.SAL.HERIDO + Q.SAL.ASISTENCIA; «¿Tiene miedo o requiere protección?» → Q.RIE.MIEDO_CASA +
Q.RIE.PIDE_PROTECCION; «¿Conoce el nombre o número?» → Q.DIN.RECEPTOR (ramas); «¿Cuál es su
nombre e identidad?» → Q.ID.NOMBRE + Q.ID.DOC_TIPO.

Las dos respuestas pueden presentarse en la misma pantalla, cada una con su Sí/No/No sé. Las
cuatro combinaciones son lícitas.

### 5.7. PAPEL

PAPEL solo aparece como «Un papel (no sé cómo se llama)». Abre Q.DOC.ACLARAR, que **no repite**
las opciones que ya estaban en el nivel anterior. Si FACTURA ya es opción, PAPEL no es su
sinónimo. El papel robado o perdido conserva su rol (no se convierte en «prueba»).
PAPEL·IDENTIDAD = carnet; PAPEL·BANCO = comprobante del banco; PAPEL·CONVOCAR = citación.

### 5.8. «¿Quién…?»

`persona_identidad` con cuatro ramas: **Sé quién es** (vínculo + nombre literal opcional),
**Solo conozco el número** (teléfono literal), **Puedo describirla** (HOMBRE/MUJER y, solo si
se pide, edad/estatura/ropa), **No lo sé**. CELULAR nunca responde «¿quién?». Con solo número:
«No conozco su nombre; el número que aparece es 71234567.» Ninguna rama abre por defecto el
asistente de género/edad/rasgos/ropa. El rol (autor, receptor, remitente, observado) lo fija
la pregunta, no un valor por defecto «sospechoso».

### 5.9. Dinero

Mecanismo (en mano / por banco / por internet / desde el celular / otra forma escrita / no
recuerdo) → monto (editor único) → receptor (si importa) → comprobante (Sí/No/No sé → tipo).
ENGAÑAR no es un mecanismo: el contexto ya fija el hecho. Frase con moneda: «Envié Bs 150
mediante un banco.» «Desde el celular» no se redacta como «transferencia».

**Editor de monto propuesto** (sustituye al de C02/C03): un campo numérico con teclado
nativo, el selector Bs/USD como segmento a la izquierda del campo, «Confirmar monto» y
«No recuerdo el monto» como botones distintos; sin fila de importes rápidos; la hoja suma
`viewInsets.bottom`; el título dice «¿Cuánto dinero fue?» sin «sustraído»; el monto se guarda
en la transacción, no en un objeto «robado».

### 5.10. Dos hechos

Cada hecho: acción, protagonista (`victim` | `suspect` | `thirdParty` | `unknown` | pendiente),
objetos propios, negación y certeza. ESCAPAR exige protagonista. Quitar un hecho no altera el
otro. La frase es una sola intervención con dos oraciones: «Me robaron el celular. Logré escapar.»

### 5.11. Salud y descripción

Fuera del recorrido habitual de denuncias, consultas y trámites. Se activan por un hecho
(agresión declarada), por la persona («Necesito atención») o porque el funcionario lo pregunta.
AUXILIO queda como salida urgente siempre accesible. La descripción de persona solo se abre
con «Puedo describirla» o por pregunta del funcionario, y cada rasgo es una pregunta propia.

### 5.12. Modelo de datos propuesto (contrato v4)

Cada campo guarda `{valor, estado, origen}`, con `estado` de §5.2 y `origen` ∈ `tarjeta`,
`editor`, `funcionario`.

```
Intervencion  { acto, proposito, replyToId?, preguntaId? }
Hecho[≤2]     { accion, protagonista, objetos[], negado, certeza, tipoSustraccion? }
Persona[]     { rol: autor|receptor|remitente|observada|acompanante,
                conocida, vinculo?, nombreLiteral?, telefonoLiteral?,
                descripcion { sexo?, edadNumero?, edadRango?, estatura?, contextura?, ropa[]? } }
Objeto[]      { concepto, rol: robado|perdido|danado|llevado_por, contenido?, documentoTipo? }
Transaccion   { mecanismo, monto?, moneda?, receptor→Persona?, comprobantes[] }
Evidencia[]   { tipo: factura|comprobante_banco|fotos|capturas|video|certificado|mensajes|otro,
                estado, literal?, presente? }
Lugar         { tipo, nombreLiteral?, relacion?, referenciaLiteral? }
Tiempo        { momento?, haceN?, unidad?, hora?, estado }
Testigos      { estado, cantidad? }
Salud         { herido, parteCuerpo?, pideAtencion, fueHospital, certificado }      (tri-estado)
Intencion     { presentarDenuncia, institucionDestino?, presentarElementos? }         (tri-estado)
Ciudadano     { nombreLiteral?, apellidoLiteral?, documento{tipo, numero?}?, telefono?,
                edad?, acompanante?, preferenciaAviso? }
Consulta      { motivo, institucionMencionada?, referencia?, fecha? }
```

La Lambda debe leer exactamente las mismas claves (camelCase) y validar los enumerados
cerrados; un contrato distinto por lado es la causa de §4.8.

### 5.13. Reglas de redacción

- Monto: «Bs 150», «USD 20»; sin monto: «dinero».
- Teléfono y números de documento: tal como se escribieron, sin reinterpretar.
- Nombres: tal como se escribieron. Texto de «Otro»: entre comillas latinas.
- Respuesta a una pregunta polar: empieza por «Sí,» / «No,» cuando la intervención es
  respuesta (C).
- Hechos incompletos: la frase previa dice «[falta: quién escapó]»; la definitiva no se emite
  hasta resolver o elegir «No sé».

---

## 6. Modos personal y ventanilla

Tabla completa en `matriz_modos.csv` (13 aspectos, con evidencia). Resumen:

| Aspecto | Hoy | Diseño | ¿Diferencia justificada? |
|---|---|---|---|
| Banco de preguntas | El mismo en ambos (46 zonas) | El mismo banco semántico | No debe haber diferencia |
| Quién inicia | Personal: la persona sorda. Ventanilla: cualquiera | Igual | Sí |
| Institución | Personal opcional; ventanilla configurada pero sin efecto | Ventanilla: no se pregunta y ordena; personal: opcional | Sí |
| Necesidad | Personal la elige, pero no filtra | Filtra intenciones, cambiable | Sí |
| Preparar vs responder | C conserva el texto exacto y el turno, pero muestra otra pregunta en 81/98 casos | En C, la pregunta del banco sale del nodo reconocido; lo mencionado se confirma | Sí |
| Ya respondido | Se repregunta; el borrador persiste entre encargos | `omitirSi`; reutilizar solo con confirmación | No debe haber diferencia |
| Persona gramatical | Mezcla «El declarante» y primera persona | Primera persona | No debe haber diferencia |
| Envío | A personal sin «Iniciar conversación» | Añadirlo (R19) | Sí |
| Dispositivo compartido | Ventanilla borra al finalizar | Igual + ningún dato personal cruza de caso | Sí |

---

## 7. Derechos Reales, Notaría y GAMC

| Pregunta | Respuesta verificada |
|---|---|
| ¿Existe el perfil? | Sí: `derechos_reales`, `notaria`, `gamc` en `institution_profiles.json`. |
| ¿Hay glosas para FOLIO, PROPIEDAD, ESCRITURA, REGISTRAR, RENOVAR, DOCUMENTO, TERRENO, IMPUESTO? | **No**: ni en el catálogo ni en el corpus §12. PAGAR solo existe en la tabla léxica. ALCALDÍA sí es tarjeta. |
| ¿Llega a la interfaz el aviso de «falta vocabulario»? | **No**: exige `intentId`, que ninguna ruta asigna. En ventanilla DDRR la persona ve las mismas cuatro familias que en Policía. |
| ¿Qué se puede comunicar hoy con fidelidad? | Identificación, acceso comunicativo (intérprete, lectura, despacio), consulta genérica de estado, cuándo volver, pedir fotocopia (frases del banco `Q.SEG.MOTIVO`, `I.PREG.*`). |
| ¿Qué no? | «Quiero un folio actualizado», «certificado de propiedad / no propiedad», «escritura», «pagar un impuesto», «renovar un registro». |

**Mensaje literal accesible ≠ seña validada.** Para lo que no tiene vocabulario, el diseño
ofrece «Otra consulta (escribir)»: la persona escribe o elige un texto, la pantalla lo muestra
como texto, el audio lo lee y la interfaz **dice** que no es una seña («Mensaje escrito: no
tiene seña validada»). No se deletrea automáticamente en el avatar como si fuera LSB y no se
crea ninguna glosa. Que se pueda redactar una frase en español no demuestra cobertura en LSB.

---

## 8. Reconciliación con las fuentes

Ningún asset se corrige a mano: cada cambio va a su fuente y se regenera.

| Artefacto | Fuente | Herramienta | Cambio propuesto (fase 2) |
|---|---|---|---|
| `assets/dialogue/dialogue_graph.json` | corpus (2) §6-8 | `tool/build_dialogue_graph.py` | Separar `formulationGlosses` de `answerOptions`; tomar las respuestas del banco (`config/banco_preguntas.json`, por nodo); no emitir interrogativas como respuesta; detectar disyuntivas; ranuras de número, nombre y teléfono. |
| `assets/dictionary/official_dictionary.json` | corpus (2) §12 | `tool/generate_official_dictionary.dart` | AL-LADO con significado «El» (fila 597 del corpus): corregir en el corpus tras validar la fuente M2-T20-06; decidir la acepción de CONOCER («conocido» vs «conozco»). |
| `docs/negocio/vocabulario.*`, `01_…` | catálogo + grafo | `tool/build_vocabulary_matrix.py` | Se regenera tras los dos anteriores. |
| `lib/core/domain/services/context_catalog.dart` | escrito a mano | — | Derivar las listas blancas del banco o añadir una prueba que compare ambas; hoy son la causa de §4.1. |
| `assets/business/institution_profiles.json` | `config/perfiles_institucionales.json` | `tool/build_business_assets.py` | Usar `ambitosIniciales` e intenciones para ordenar y para el aviso de vocabulario ausente. |
| `matriz_*`, `11_…`, `12_…` | `config/banco_preguntas.json` | `tool/build_question_matrix.py` | — |

---

## 9. Lo que no se ha verificado

1. Comportamiento en dispositivo más allá de las 12 capturas: accesibilidad, TalkBack, texto
   ampliado, teclados de otros fabricantes.
2. Bedrock: las frases finales pueden diferir de las bases; ninguna prueba usa el servicio real.
3. El `.glb` del avatar y la URL de imágenes de señas: no están en el repositorio.
4. Variabilidad real del español de los funcionarios: la inferencia se evaluó con los 98
   enunciados del corpus.
5. **Validación lingüística**: ninguna composición propuesta (PAPEL·BANCO, NÚM(1) = solo,
   PAREJA·PASADO…) está validada con señantes de Cochabamba ni con intérpretes. Las que ya
   estaban en el corpus se marcan así; las nuevas, como «requiere validación».
