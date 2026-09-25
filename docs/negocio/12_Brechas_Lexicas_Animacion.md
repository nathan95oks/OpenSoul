# Brechas lexicográficas y de animación

Generado por `tool/build_question_matrix.py`. **No editar a mano.**

Cinco cosas distintas: (1) que la glosa exista en el catálogo; (2) su acepción en el contexto (`config/acepciones.json`); (3) que responda el campo preguntado; (4) si la opción es texto escrito por la persona; (5) si el avatar tiene una animación declarada.

## Conceptos que el banco necesita y el catálogo no documenta

| Concepto | Lo necesita | Estado | Tratamiento en la app |
|---|---|---|---|
| DINERO | Q.DIN.*, Q.ROB.QUE | El corpus usa DINERO/BILLETES; el catálogo solo tiene BILLETES | Usar BILLETES; no crear DINERO |
| NÚMERO / TELÉFONO | Q.ID.TELEFONO_PROPIO, Q.DIG.REMITENTE, Q.DIN.RECEPTOR_NUMERO | Sin glosa; el corpus usa CELULAR · NÚM(...) | Texto numérico literal; en texto→LSB, dígitos (0–9 declarados en el resolutor) |
| Nombre propio | Q.ID.NOMBRE, Q.PER.NOMBRE_TERCERO, Q.DIN.RECEPTOR_NOMBRE | Mecanismo de dactilología; letras I y K sin clip en el resolutor | Texto literal; en texto→LSB, deletreo con marcador de posición para letras sin clip |
| APELLIDO, CARNET, ANOS_EDAD | Q.ID.* | En la tabla léxica pero no en el catálogo | No ofrecer como tarjeta; CARNET = PAPEL·IDENTIDAD (composición del corpus) |
| PASAPORTE, LICENCIA | Q.ID.DOC_TIPO | Sin glosa (PASAPORTE solo en la tabla léxica) | Opción de texto literal declarada |
| COMPROBANTE | Q.DIN.COMPROBANTE_TIPO | Sin glosa; corpus §8 #29 «PAPEL · BANCO · TENER» | Composición PAPEL·BANCO |
| TRANSFERENCIA, QR, CUENTA, DEPÓSITO, EFECTIVO | Q.DIN.MECANISMO | Sin glosa | No redactar «transferencia»; «Otra forma (escribir)» literal |
| MENSAJE, CAPTURA, PANTALLA, CHAT | Q.DIG.* | Sin glosa; corpus: ESCRIBIR (mensajes), FOTOS·CELULAR (capturas), ESCRIBIR·TOTAL (conversación) | Composiciones del corpus; nunca inferir canal |
| WHATSAPP, SMS, FACEBOOK | Q.DIG.CANAL | Sin glosa; WHATSAPP solo en la tabla léxica | Solo texto literal escrito por la persona |
| NIÑO, ANCIANO | Q.PER.DESC.EDAD, Q.RIE.QUIENES | Sin glosa ni lexema; el asistente los ofrece y se pierden en la frase | Retirar del asistente o marcarlos como texto literal |
| COLOR y colores BLANCO, VERDE, CAFÉ, GRIS, AMARILLO, NARANJA, MORADO | Q.PER.DESC.ROPA, Q.PER.DESC.CABELLO | Solo NEGRO, AZUL y ROJO tienen glosa | Texto literal declarado para el resto |
| DENUNCIA / DENUNCIAR | Q.DEN.INTENCION | Concepto pendiente (corpus §4); composición QUEJAR+AUTORIDAD sin validar | Responder con SÍ/NO; en texto→LSB, dactilología o composición marcada como provisional |
| FIRMA / FIRMAR | Q.SEG.LEER_ANTES_FIRMAR | Composición provisional NOMBRE·ESCRIBIR | No afirmar firma |
| DOCUMENTO (genérico) | Q.DOC.ACLARAR | Sin glosa (corpus §4: preferir el objeto concreto) | PAPEL + aclaración; nunca «documento» como seña |
| FOLIO, PROPIEDAD, ESCRITURA, REGISTRAR, RENOVAR, PAGAR, TERRENO, IMPUESTO | Derechos Reales, Notaría, GAMC | Sin glosa en catálogo ni en §12 (PAGAR solo en la tabla léxica) | Mensaje literal accesible declarado como tal; sin tarjetas |
| NOTARÍA, DERECHOS_REALES, SEGIP, SERECI | perfiles | Sin glosa ni entrada d(...) en el catálogo | Nombre institucional por dactilología solo si se valida; hoy texto literal |
| SOLO (vine solo) | Q.ID.ACOMPANANTE | Sin glosa; corpus NÚM(1) | Tarjeta «Solo/a» con glosa 1 marcada como composición a validar |
| NO RECORDAR | salidas no_recuerda | Sin entrada propia; corpus «RECORDAR /neg/» | RECORDAR + NO |
| NOCHE, MADRUGADA | Q.TIE.HORA | Sin glosa | Editor de hora |
| EXPAREJA | Q.PER.VINCULO | Solo en la tabla léxica; corpus PAREJA · PASADO | Composición PAREJA·PASADO |
| LSB (lengua) | Q.ACC.INTERPRETE | Aparece en §12 pero no en el catálogo | Texto; INTÉRPRETE cubre la necesidad |
| CÁMARA | Q.EVI.CAMARAS | Sin glosa en el catálogo; corpus VIDEO·FILMAR | Composición VIDEO·FILMAR |
| AL_LADO rotulada «EL» | Q.LUG.RELACION | Error en la fila del corpus §12 (línea 597: significado «El») | Corregir en el corpus y regenerar el diccionario; no editar el JSON a mano |
| CONOCER rotulada «CONOCIDO» | Q.PER.VINCULO, Q.DIG.REMITENTE | El corpus documenta «Conocido»; el ensamblador redacta «conozco a esa persona» | Decidir acepción; no usar la misma glosa para «conozco» y «un conocido» sin validación |

## Opciones sin seña (la interfaz las rotula como texto)

| Pregunta | Opción | Frase |
|---|---|---|
| `Q.ID.DOC_TIPO` | Pasaporte | Presento mi pasaporte. |
| `Q.ID.DOC_TIPO` | Licencia de conducir | Presento mi licencia de conducir. |
| `Q.SEG.MOTIVO` | Otra consulta (escribir) | Quiero consultar esto: «{texto}». |

## Editores de valor literal

El valor escrito se guarda y se redacta tal cual; no se convierte en glosas.

| Editor | Opciones que lo usan |
|---|---:|
| `documento_numero` | 2 |
| `edad` | 2 |
| `entero` | 10 |
| `hora` | 1 |
| `lugar_literal` | 6 |
| `monto` | 3 |
| `referencia` | 3 |
| `telefono` | 5 |
| `texto_detalle` | 20 |
| `texto_nombre` | 5 |

## Animación de las glosas del banco

Solo cuenta para mostrar una frase en el avatar (texto/voz → LSB). La salida de las tarjetas es texto y audio en español.

- Glosas distintas en respuestas del banco: **145**.
- Con clip declarado en `available3DGlosses` (árbol de trabajo al generar): **4** — SÍ, NO, 1, PRIMERA_VEZ.
- El resto se deletrea o queda como marcador en el avatar. La lista real de clips vive en el `.glb` de S3, que no está en el repositorio: **no se ha verificado en dispositivo**.
