# Recorridos de referencia A–I

Comportamiento **deseado**, trazado contra el banco (`config/banco_preguntas.json`) y
contrastado con lo que el código hace hoy. Nada de lo marcado «Diseño» está implementado.

Convenciones:

- **Pregunta**: id del banco. **Glosas**: tarjetas del catálogo; `⟨editor⟩` = valor escrito.
- **Previa**: frase visible mientras se construye. **Definitiva**: la que se muestra, se envía
  y se reproduce.
- **Hoy**: lo observado con la sonda sobre el código real (`evidencia/2026-09-25/probe_dart.json`)
  o derivado directamente del código cuando se indica.
- Estados de respuesta de `08 §5.2`.

---

## A. Personal · inicia la persona sorda · sin institución

**Dimensiones**: modo personal · propósito A (independiente) · institución sin elegir ·
necesidad Denuncias · intención RELATO_ABIERTO · acto declaración · sin `replyToId`.

| # | Estado previo | Pregunta | Respuesta estructurada | Validación | Siguiente | Previa |
|---|---|---|---|---|---|---|
| 1 | vacío | Necesidad | Denuncias | una | intención | — |
| 2 | necesidad | Intención | «Contar lo que me pasó» | soportada | Q.HEC.QUE_OCURRIO | — |
| 3 | — | Q.HEC.QUE_OCURRIO | `hechos=[ROBAR, ESCAPAR]` [ROBAR · ESCAPAR] | ≤ 2 | Q.ROB.QUE (por ROBAR), Q.HEC.ESCAPE_ACTOR (por ESCAPAR) | «Me robaron [¿qué?]. [¿Quién escapó?]» |
| 4 | ROBAR sin objeto | Q.ROB.QUE | `ROBAR.objetos=[CELULAR]` [CELULAR] | ≥ 1 o «No sé» | — | «Me robaron el celular. [¿Quién escapó?]» |
| 5 | ESCAPAR pendiente | Q.HEC.ESCAPE_ACTOR | `ESCAPAR.protagonista=victim` [YO · ESCAPAR] | una | opcionales | «Me robaron el celular. Logré escapar.» |
| 6 | opcional | Q.PER.CONOCE | omitido | — | — | igual |
| 7 | opcional | Q.TIE.CUANDO / Q.LUG.DONDE | omitido | — | revisión | igual |
| 8 | completo | Revisión | Reproducir · Mostrar · **Iniciar conversación con este mensaje** | — | conversación con turno propio, `replyToId = null` | — |

**Definitiva**: «Me robaron el celular. Logré escapar.»

```json
{"intervencion": {"acto": "statement", "proposito": "standaloneIntervention", "replyToId": null},
 "hechos": [
   {"accion": "ROBAR", "protagonista": "suspect", "objetos": ["o1"], "negado": false, "certeza": "confirmed"},
   {"accion": "ESCAPAR", "protagonista": "victim", "objetos": [], "negado": false, "certeza": "confirmed"}],
 "objetos": [{"id": "o1", "concepto": "CELULAR", "rol": "robado"}],
 "tiempo": {"estado": "omitido"}, "lugar": {"estado": "omitido"}}
```

**Ramas**

| Situación | Definitiva |
|---|---|
| Paso 5 = «La persona que lo hizo» | Me robaron el celular. La persona que me robó escapó. |
| Paso 5 = «Otra persona» | Me robaron el celular. Otra persona escapó. |
| Paso 5 = «No sé» | Me robaron el celular. Alguien escapó, pero no sé quién. |
| Paso 5 cancelado | No se emite; la previa dice «[Falta: quién escapó]». |
| Paso 4 = «No sé exactamente qué me falta» | Me robaron algo; no sé exactamente qué. Logré escapar. |
| Quitar ESCAPAR | Me robaron el celular. (ROBAR conserva su objeto.) |
| Quitar ROBAR (con confirmación «También se quita: el celular») | Logré escapar. |
| Intentar un tercer hecho | Bloqueado: «Puedes elegir hasta dos hechos». |
| Paso 6 = «No» | … No conozco a la persona que me robó. |

**Hoy** (sonda P01): tocar ROBAR y ESCAPAR y elegir «La víctima / Yo logré escapar» produce
«Una persona me robó. Hubo una huida, sin precisar de quién.» La elección se descarta (D-01).
No existe «Iniciar conversación con este mensaje» en A (D-29). El orden de pulsación no se
usa como orden temporal (correcto hoy).

---

## B. Ventanilla · el funcionario pregunta «¿Le robaron el celular?»

**Dimensiones**: ventanilla · propósito C · perfil Policía · acto respuesta · `replyToId` = turno
del funcionario · objeto CELULAR **mencionado por el funcionario** (pendiente de confirmación).

| # | Estado previo | Pregunta | Respuesta | Siguiente | Previa |
|---|---|---|---|---|---|
| 1 | turno oyente congelado | Q.ROB.CONFIRMA_OBJETO (nodo `n-s6-robo_hurto_y_obje-03`) | Sí [SÍ] | enviar; lo demás lo pregunta el funcionario | «Sí, me robaron el celular.» |

**Ramas**

| Respuesta | Datos | Definitiva |
|---|---|---|
| Sí | ROBAR confirmado; CELULAR confirmado (origen: funcionario) | Sí, me robaron el celular. |
| No | ningún hecho | No me robaron el celular. |
| No sé | ROBAR con certeza `unknown`, sin afirmar | No sé si me robaron el celular. |
| «Me robaron otra cosa» → Q.ROB.QUE = MOCHILA | ROBAR + MOCHILA | No me robaron el celular; me robaron la mochila. |
| Omitir | nada | (no se envía) |
| El funcionario escribe otro mensaje mientras se responde | el `replyToId` sigue siendo el congelado | igual |

Nunca: «No» → «me robaron…»; «No» → deducir otro hecho; volver a pedir que elija CELULAR.

**Hoy** (sondas P11, P15): la zona inferida es `objetos` («¿Qué objetos están involucrados?»),
sin Sí/No. Elegir CELULAR → «Me lo robaron» produce «Quiero comunicar lo siguiente, aunque
todavía no completé los detalles.», porque no existe el hecho ROBAR (D-08).

---

## C. Mensajes · «¿Quién envió los mensajes?»

**Dimensiones**: ventanilla o personal · amenazas digitales · Q.DIG.REMITENTE.

| Rama | Respuesta estructurada | Definitiva |
|---|---|---|
| Sé quién es → vínculo PAREJA | `Persona{rol: remitente, conocida: sí, vinculo: PAREJA}` [CONOCER · PAREJA] | Los mensajes me los envía mi pareja. |
| Sé quién es → vínculo + nombre ⟨texto_nombre⟩ | `+ nombreLiteral: "Carlos Rojas"` | Los mensajes me los envía mi pareja, Carlos Rojas. |
| **Solo conozco el número** ⟨telefono⟩ | `Persona{rol: remitente, conocida: no, telefonoLiteral: "71234567"}` | **No conozco su nombre; el número que aparece es 71234567.** |
| Puedo describirla → HOMBRE | `Persona{rol: remitente, descripcion: {sexo: HOMBRE}}` | Me los envía un hombre; no sé quién es. |
| No lo sé | `Persona{rol: remitente, estado: desconocido}` | No sé quién me envía los mensajes. |

Validación del teléfono: 7–8 dígitos; si hay menos, «Solo sé una parte» guarda «parte del
número: 7123» y la frase lo dice así. El editor se relee agrupado antes de confirmar.

**Separado**: Q.DIG.CANAL = CELULAR → «Me llegaron mensajes por celular.» Esto no responde
«¿quién?» y no crea ninguna persona.

**Hoy** (C10, sonda P07): CELULAR está en «¿Quién le envía los mensajes?»; tocarlo abre el
asistente de persona con rol «sospechoso» y «No identificado / Omitir» preseleccionado. No hay
campo de teléfono. En «¿Qué tipo de mensajes recibió?», CELULAR abre «Escribe el número», se
convierte en el hecho `CELULAR` y en el canal «WhatsApp» (D-06, D-14, D-17).

---

## D. Evidencia · factura, mensajes guardados y capturas

**D1. «¿Tiene una factura?»** (Q.EVI.FACTURA)

| Respuesta | Siguiente | Definitiva |
|---|---|---|
| Sí | Q.EVI.TRAE_COPIA (si es útil) → Sí | Sí, tengo una factura. La tengo aquí. |
| Sí → No la trae | — | Sí, tengo una factura. No la tengo aquí. |
| No | — | No tengo factura. *(no dice nada de otras pruebas)* |
| No sé | — | No sé si tengo la factura. |

«Tengo una factura» solo con «Sí». FACTURA y PAPEL no aparecen como sinónimos: si la persona
no sabe qué documento tiene, elige «Un papel (no sé cómo se llama)» y Q.DOC.ACLARAR no repite
FACTURA.

**D2. «¿Guardó los mensajes?» y «¿Tiene fotos de la pantalla?»** — independientes, en la
misma pantalla si el funcionario hizo la pregunta compuesta.

| Q.DIG.GUARDO | Q.DIG.CAPTURAS | Definitiva |
|---|---|---|
| Sí | Sí | Sí, guardé los mensajes. Sí, tengo fotos de la pantalla. |
| Sí | No | Sí, guardé los mensajes. No tengo fotos de la pantalla. |
| No | Sí | No guardé los mensajes. Sí, tengo fotos de la pantalla. |
| No | No | No guardé los mensajes. No tengo fotos de la pantalla. |
| No sé | omitido | No sé si se guardaron. |
| «Sí, todos» [GUARDAR · TOTAL] | — | Guardé todos los mensajes. |

**Hoy** (C04, C09, sondas P03, P07): una sola pregunta con ESCRIBIR, TOTAL, GUARDAR, FOTOS,
CELULAR, VIDEO, MOSTRAR, PUEDO, AHORA; sin No ni No sé. En engaño, las respuestas de
`comprobante` no llegan al borrador; en amenazas, TOTAL y AHORA se redactan como pruebas:
«Cuento con total y ahora mismo como prueba.» (D-19, D-20).

---

## E. Dinero · «¿Cómo entregó el dinero?»

**Dimensiones**: engaño con dinero · C (el funcionario pregunta) o A · Q.DIN.MECANISMO →
Q.DIN.MONTO.

| # | Pregunta | Respuesta | Previa |
|---|---|---|---|
| 1 | Q.DIN.MECANISMO | Por un banco [ENVIAR · BANCO] | «Envié [¿cuánto?] mediante un banco.» |
| 2 | Q.DIN.MONTO | ⟨monto⟩ 150 · Bs | «Envié Bs 150 mediante un banco.» |

**Definitiva**: «Envié Bs 150 mediante un banco.» — solo si se eligieron ENVIAR, el medio
banco y el monto.

```json
{"transaccion": {"mecanismo": {"valor": "banco", "estado": "afirmado", "origen": "tarjeta"},
                 "monto": {"valor": "150", "moneda": "Bs", "estado": "afirmado", "origen": "editor"},
                 "receptor": null, "comprobantes": []}}
```

**Ramas**

| Situación | Definitiva |
|---|---|
| En mano + 150 Bs | Entregué Bs 150 en mano. |
| Banco + monto «No recuerdo» | Envié dinero mediante un banco. No recuerdo el monto exacto. |
| Banco + USD 20 | Envié USD 20 mediante un banco. |
| Desde el celular + 150 Bs | Envié Bs 150 desde el celular. *(nunca «transferí»)* |
| Mecanismo «No recuerdo» + 150 Bs | No recuerdo cómo entregué el dinero. Fueron Bs 150. |
| Hoja de monto cancelada | Envié dinero mediante un banco. *(sin monto; nada inventado)* |
| Monto 0 o vacío | «Confirmar» deshabilitado |

**Ilícitas**: BILLETES → «me robaron Bs 150»; CELULAR → «transferencia»; cualquier dato →
«fui víctima de estafa» o «recibió el dinero X» si nadie lo dijo.

**Hoy** (C01–C03, sondas P04, P05; Lambda): BILLETES en «¿Cómo ocurrió…?» crea el hecho
`BILLETES` y un objeto `BILLETES` con rol `stolen`; la hoja no respeta el teclado (C02); la
frase local es «El declarante denuncia haber sido víctima de engaño económico mediante banco.»
sin el monto; la de la Lambda, «Denuncio un engaño económico / engaño económico.» (D-07, D-16).

---

## F. Persona · «¿Qué edad aproximada tenía?»

**Dimensiones**: descripción, **solo** porque el funcionario lo pregunta · Q.PER.DESC.EDAD.

| Respuesta | Definitiva |
|---|---|
| ⟨entero⟩ 24 | Tenía aproximadamente 24 años. |
| «Era joven» [JOVEN] | Era joven. |
| «Era adulto» [ADULTO] | Era adulto. |
| No recuerdo | No recuerdo su edad. |

Nunca: 24 → «joven». No se piden género, ropa ni complexión por defecto: cada rasgo es su
propia pregunta y solo aparece si se pregunta.

**Hoy**: «¿Qué edad aproximada tenía?» en robo no activa ninguna zona (sonda P15) y se muestra
«¿Qué le ocurrió?». La edad solo existe como paso 2 del asistente de persona, con rangos; Niño
y Anciano no tienen glosa ni lexema y desaparecen de la frase (D-15).

---

## G. Consulta o trámite · «¿Qué quiere consultar?»

**Dimensiones**: necesidad Consultas · acto pregunta/solicitud · Q.SEG.MOTIVO.

| Modo | Diferencia | Pregunta | Respuesta | Definitiva |
|---|---|---|---|---|
| Personal, sin institución | no se fuerza institución; la frase no la nombra | Q.SEG.MOTIVO | «Cuándo debo volver» [CUÁNDO · VOLVER] | Quiero saber cuándo debo volver. |
| Ventanilla, perfil Fiscalía | no se pregunta la institución que atiende | Q.SEG.MOTIVO | «Si la investigación continúa» | Quiero saber si la investigación continúa. |
| Personal A, pregunta propia | interrogativas como formulación propia | I.PREG.ELEGIR → I.PREG.CUANDO | «Cuándo vuelvo» | ¿Cuándo debo volver? |
| Cualquiera | consulta sin opción | Q.SEG.MOTIVO → «Otra consulta (escribir)» | ⟨texto⟩ | Quiero consultar esto: «…». *(mensaje escrito, sin seña)* |

**Hoy** (sondas P10, P17): en «Preguntas», elegir CUÁNDO + VOLVER redacta «¿Dónde debo
realizar esta consulta o presentar el trámite?» (D-05); el recorrido muestra además
«¿Dónde queda…?», «¿Con quién deseo hablar?» y «¿Sobre qué tema…?» (D-30). En «Consultar
trámite», se pregunta siempre «¿Con qué autoridad o institución debe coordinar?», también en
ventanilla (D-24).

---

## H. Identificación · nombre y documento

| # | Pregunta | Respuesta | Definitiva |
|---|---|---|---|
| 1 | Q.ID.NOMBRE («¿Cómo se llama?») | ⟨texto_nombre⟩ María Quispe | Me llamo María Quispe. |
| 2 | Q.ID.DOC_TIPO («¿Qué documento presenta?») | Carnet de identidad [PAPEL · IDENTIDAD] | Presento mi carnet de identidad. |
| 3 | Q.ID.DOC_NUMERO (si se pide) | ⟨documento_numero⟩ 4567890 CB | El número de mi documento es 4567890 CB. |

**Regla de destinatario**: «¿Cómo se llama?» dirigido a la persona sorda llena
`Ciudadano.nombreLiteral`. «¿Conoce el nombre de la persona?» llena `Persona[receptor|autor]
.nombreLiteral`. Nunca se cruzan, y ninguno se precarga en ventanilla.

**Ramas**: Omitir el nombre → nada; documento «Pasaporte» → «Presento mi pasaporte.» *(texto
literal: sin glosa)*; «No tengo un documento conmigo.»

**Hoy** (C12, sondas P09, P15): NOMBRE abre «Deletrea tu nombre», que guarda J · U · A · N como
glosas sueltas; la frase local es «El declarante se identifica ante la autoridad competente.» y
la de la Lambda «Datos de identificación:» (D-09). En el contexto de robo, «¿Cómo se llama?»
muestra «¿Qué objetos están involucrados?» (D-22). PAPEL e IDENTIDAD abren dos hojas que
registran lo mismo.

---

## I. Incertidumbre y edición

| Caso | Esperado | Hoy |
|---|---|---|
| Cancelar cualquier hoja | No se añade tarjeta, hecho, persona ni objeto | Se añade la tarjeta en 8 despachos; la hoja de persona crea la persona (sondas P03, P12) |
| Retroceder | Conserva respuestas y detalles | Conserva (correcto) |
| Cambiar «Sí» por «No» en Q.EVI.FACTURA con Q.EVI.TRAE_COPIA respondida | Diálogo «Se quitará: “La tengo aquí”. ¿Continuar?»; al confirmar, se borra | No existe la dependencia |
| Elegir «Sí» y «No» a la vez | Imposible: una sola respuesta | Posible desde `031b821`; se redacta «Quiero presentar una denuncia formal.» (sonda P06) |
| Cambiar de contexto o de caso | Borrador vacío | Vacío si cambia el contexto; si el caso nuevo usa el mismo contexto, personas/objetos/hechos del anterior siguen ahí (sonda P16) |
| Salir de la hoja de persona sin elegir | Nada | «No identificado / Omitir» aparece ya marcado y la persona existe |

---

## Consultas y trámites cubiertos hoy por el corpus

Frases con respaldo en el corpus §7/§8 y glosas en el catálogo. Son alcanzables con el banco
propuesto; hoy la redacción de «Preguntas» y «Consultar trámite» no las produce (D-05).

| Intervención | Glosas | Fuente |
|---|---|---|
| ¿Dónde está la Fiscalía? | d(FISCALÍA) · DÓNDE | §7 Fiscalía #1 |
| Recibí una citación y quiero consultar sobre ella. | PAPEL · CONVOCAR · RECIBIR | §6 Seguimiento #8 (composición) |
| Quiero saber si la investigación continúa. | INVESTIGACIÓN · CONTINUAR · SABER · QUERER | §8 #39 |
| ¿Hay abogado gratis? | ABOGADO · GRATIS · TENER | §7 Fiscalía #5 |
| Necesito un intérprete de LSB para hablar con el juez. | JUEZ · INTÉRPRETE · NECESITAR | §8 #47 |
| ¿Me entregan una fotocopia? | FOTOCOPIA · YO · RECIBIR | §7 |
| ¿Puedo leer lo escrito antes de firmar? | PAPEL · LEER · NOMBRE · ESCRIBIR · PUEDO | §7 (firma = composición provisional) |

**No cubierto** (Derechos Reales): «Quiero un folio actualizado.» → no hay FOLIO ni PROPIEDAD.
Con el diseño: «Otra consulta (escribir)» → mensaje escrito mostrado como texto, audio que lo
lee y aviso «Mensaje escrito: no tiene seña validada». Nunca tarjetas inventadas.

---

## Conversación de tres turnos (ventanilla Policía)

| Turno | Quién | Entrada | Pregunta del banco | Respuesta | Definitiva (`replyToId`) | Hoy: pregunta que se muestra |
|---|---|---|---|---|---|---|
| 1 | Funcionario (voz) | «Buenas tardes. ¿Qué ocurrió?» | Q.HEC.QUE_OCURRIO | ROBAR → Q.ROB.QUE = CELULAR | «Me robaron el celular.» (T1) | `hecho` «¿Qué le ocurrió?» — por ser la zona de entrada |
| 2 | Funcionario (texto) | «¿Dónde ocurrió?» | Q.LUG.DONDE | AVENIDA ⟨Heroínas⟩ | «Ocurrió en la avenida Heroínas.» (T2) | `lugar` «¿Dónde ocurrió?» ✓ |
| 3 | Funcionario (voz) | «¿Conoce a la persona?» | Q.PER.CONOCE | No | «No conozco a esa persona.» (T3) | `conocimiento` ✓ |
| 4 | Funcionario | «¿Tiene la factura del celular?» | Q.EVI.FACTURA (objeto del enunciado) | Sí | «Sí, tengo la factura del celular.» (T4) | `hecho` «¿Qué le ocurrió?» ✗ |

Reglas del ciclo: cada respuesta es una intervención nueva con su `replyToId`; tras «Enviar al
chat» el borrador se vacía (hoy correcto); un dato ya confirmado (CELULAR) no se vuelve a
preguntar; «Continuar como persona oyente» devuelve el foco al funcionario; «Finalizar
atención» borra todo el contenido y conserva el perfil.

---

## Combinaciones lícitas e ilícitas

| Dominio | Lícita | Ilícita (no debe poder producirse) |
|---|---|---|
| Hechos | ROBAR + ESCAPAR(yo); ESCAPAR sola con protagonista | Tres hechos; ESCAPAR emitido sin protagonista como «el ladrón escapó»; «primero… luego» |
| Polaridad | Sí / No / No sé, uno solo | Sí y No a la vez; una institución como respuesta a sí/no |
| Evidencia | Factura = Sí y capturas = No | «No» a la factura → «No tengo pruebas»; TOTAL, GUARDAR o PUEDO como prueba |
| Documento | FACTURA o «Un papel (no sé cuál)» → aclarar | PAPEL y FACTURA como opciones equivalentes en el mismo nivel; carnet robado registrado como prueba |
| Persona | Solo número conocido → «No conozco su nombre; el número…» | CELULAR como respuesta a «¿quién?»; nombre del receptor en la ficha del ciudadano; rol «sospechoso» por defecto |
| Edad | 24 → «aproximadamente 24 años»; «Era joven» elegido | 24 → «joven»; Niño/Anciano sin representación |
| Dinero | Mecanismo sin monto; monto sin mecanismo | BILLETES → «me robaron»; CELULAR → «transferencia»; monto en otra moneda que la elegida |
| Denuncia | «Sí, quiero presentar una denuncia» | «Denuncio…» sin haberlo elegido; «presentada», «registrada», «acta» |
| Salud | Herido = Sí → «¿Necesita atención médica?» | Pregunta médica de rutina en robo, engaño, consultas o trámites |
| Consulta | Motivo elegido → frase del corpus | Frase fija «¿Dónde debo realizar esta consulta…?» para cualquier motivo |
| Institución | Ventanilla con perfil: no se pregunta la que atiende | Deducir la institución mencionada del perfil activo |
| Sesión | Caso nuevo con borrador vacío | Persona, documento o monto del caso anterior en el nuevo |
