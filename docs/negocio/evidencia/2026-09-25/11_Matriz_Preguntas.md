# Matriz maestra de preguntas

Generado por `tool/build_question_matrix.py` desde `config/banco_preguntas.json`, contrastado con el catálogo, la tabla léxica, `context_catalog.dart`, el motor de inferencia de zonas y `dialogue_graph.json`. **No editar a mano.**

Es la especificación **propuesta**. La columna «Soporte» dice cuánto existe hoy: `parcial` = hay pantalla o dato, pero con defectos documentados; `diseño` = no existe.

## Totales

| Qué | Cantidad |
|---|---:|
| Preguntas del banco (`Q.*`) | 136 |
| Intervenciones propias (`I.*`) | 10 |
| Zonas de `context_catalog.dart` | 46 |
| Pares zona-glosa de hoy | 374 |
| Nodos del grafo | 209 |

## Veredicto sobre las glosas que se muestran hoy

Cada glosa de cada lista blanca, contra el dato que pide su pregunta.

| Veredicto | Significado | Pares |
|---|---|---:|
| `valida` | Responde el dato pedido | 225 |
| `condicional` | Solo cuando se activa un hecho concreto | 9 |
| `mover` | Dato correcto, pero de otra pregunta | 52 |
| `modificador` | Matiza otra respuesta; no responde por sí sola | 15 |
| `formulacion` | Glosa de la propia pregunta, no una respuesta | 16 |
| `invalida` | No responde el dato pedido | 39 |
| `inalcanzable` | La zona nunca se activa | 18 |

De los 374 pares, **73** serían retirados por el filtro por campo si la lista blanca no lo eximiera (`candidate_engine.dart:127-131`). El filtro, además, deja pasar cualquier glosa cuando la zona pide `free_text` o solo polaridad, así que no detecta la mayoría de los veredictos `invalida`/`formulacion` de esta tabla. Detalle en `matriz_zonas_actuales.csv`.

## Diagnóstico de los 209 nodos del grafo

| Diagnóstico | Nodos |
|---|---:|
| `disyuntiva_tratada_como_si_no` | 16 |
| `glosas_del_enunciado_como_respuesta` | 98 |
| `interrogativa_como_respuesta` | 21 |
| `opcion_fuera_de_ranura` | 94 |

De los 98 nodos del funcionario (§6), **81** llevan hoy a la persona sorda a una pregunta de pantalla que no es la que el banco asigna a ese enunciado (réplica de `ZoneInferenceEngine`, asumiendo el contexto del nodo). Detalle en `matriz_nodos_grafo.csv`, columnas `zonaMostradaHoy` y `preguntaMostradaHoy`.

## Banco por dominio

### acceso

| Id | Formulación | Control | Respuestas → frase | Fuente | Soporte |
|---|---|---|---|---|---|
| `Q.ACC.SORDO` | ¿Usted es una persona sorda? | polar2 | Sí [SÍ] → «Sí, soy una persona sorda.»<br>No [NO] → «No soy una persona sorda.» | `n-s6-acceso_comunicativ-01` | diseño |
| `Q.ACC.INTERPRETE` | ¿Necesita un intérprete de LSB? | polar3 | Sí [SÍ] → «Sí, necesito un intérprete de LSB.»<br>No [NO] → «No necesito intérprete.»<br>No sé [NO_SABER] → «No sé si necesito intérprete.» | `n-s6-acceso_comunicativ-02` | diseño |
| `Q.ACC.ESCRITO` | ¿Prefiere que le escriba en papel? | polar3 | Sí [SÍ] → «Sí, prefiero que me escriba.»<br>No [NO] → «No quiero que me escriba en papel.»<br>No sé [NO_SABER] → «No sé qué prefiero.» | `n-s6-acceso_comunicativ-03` | diseño |
| `Q.ACC.LECTURA` | ¿Puede leer este texto? | alternativa | Sí, puedo leerlo [SÍ] → «Sí, puedo leerlo.»<br>Leo poco [LEER · POCO] → «Leo poco.»<br>No puedo leerlo [NO] → «No puedo leerlo.» | `n-s6-acceso_comunicativ-04` | diseño |
| `Q.ACC.COMPRENSION` | ¿Comprende lo que le estoy explicando? | alternativa | Sí, comprendo [SÍ] → «Sí, comprendo.»<br>No comprendo [NO · COMPRENDER] → «No comprendo.»<br>Explíqueme despacio [LENTO · EXPLICAR · POR_FAVOR] → «No comprendo. Explíqueme despacio, por favor.» | `n-s6-acceso_comunicativ-05` | diseño |
| `Q.ACC.REPARACION` | ¿Quiere que lo explique otra vez y más despacio? | polar2 | Sí [SÍ] → «Sí, explíquelo otra vez más despacio, por favor.»<br>No [NO] → «No hace falta, entendí.» | `n-s6-acceso_comunicativ-06` | diseño |

### identificacion

| Id | Formulación | Control | Respuestas → frase | Fuente | Soporte |
|---|---|---|---|---|---|
| `Q.ID.NOMBRE` | ¿Cuál es su nombre completo? | texto_nombre | Escribir mi nombre ⟨texto_nombre⟩ → «Me llamo {nombre}.»<br>Omitir | `n-s6-acceso_comunicativ-07` | parcial |
| `Q.ID.APELLIDO` | ¿Puede deletrear su apellido? | texto_nombre | Escribir mi apellido ⟨texto_nombre⟩ → «Mi apellido es {apellido}.»<br>Omitir | `n-s6-acceso_comunicativ-08` | diseño |
| `Q.ID.DOC_TIENE` | ¿Tiene su carnet de identidad? | polar3 | Sí [SÍ] → «Sí, tengo mi carnet de identidad.»<br>No [NO] → «No tengo mi carnet de identidad.»<br>No sé [NO_SABER] → «No sé si lo tengo conmigo.» | `n-s6-acceso_comunicativ-09` | diseño |
| `Q.ID.DOC_TIPO` | ¿Qué documento presenta? | seleccion_unica | Carnet de identidad [PAPEL · IDENTIDAD] → «Presento mi carnet de identidad.»<br>Pasaporte *(literal)* → «Presento mi pasaporte.»<br>Licencia de conducir *(literal)* → «Presento mi licencia de conducir.»<br>Otro documento (escribir) ⟨texto_detalle⟩ → «Presento este documento: «{texto}».»<br>Ninguno [NO] → «No tengo un documento conmigo.»<br>Omitir | `identificacion/identidad` | parcial |
| `Q.ID.DOC_NUMERO` | ¿Cuál es el número de su documento? | documento_numero | Escribir el número ⟨documento_numero⟩ → «El número de mi documento es {numero}.»<br>Omitir | — | diseño |
| `Q.ID.TELEFONO_VALIDA` | ¿Este número de celular es suyo? | polar3 | Sí [SÍ] → «Sí, ese número es mío.»<br>No [NO] → «No, ese número no es mío.»<br>No sé [NO_SABER] → «No estoy seguro de que sea mi número.» | `n-s6-acceso_comunicativ-10` | diseño |
| `Q.ID.TELEFONO_PROPIO` | ¿Cuál es su número de celular? | telefono | Escribir mi número ⟨telefono⟩ → «Mi número de celular es {telefono}.»<br>Omitir | `identificacion/contacto` | parcial |
| `Q.ID.AVISO` | ¿Prefiere recibir avisos por mensaje escrito? | polar3 | Sí [SÍ] → «Sí, prefiero recibir avisos por mensaje escrito.»<br>No [NO] → «No quiero recibir avisos por mensaje escrito.»<br>No sé [NO_SABER] → «No sé qué prefiero.» | `n-s6-acceso_comunicativ-11`, `n-s6-seguimiento_prelim-10` | diseño |
| `Q.ID.ACOMPANANTE` | ¿Vino solo o acompañado? | alternativa | Vine solo/a [1] → «Vine solo.»<br>Vine acompañado/a [ACOMPAÑAR] → «Vine acompañado.» | `n-s6-acceso_comunicativ-12` | parcial |
| `Q.ID.ACOMPANANTE_QUIEN` | ¿Quién le acompaña? | seleccion_unica | Intérprete [INTÉRPRETE] → «Vine con un intérprete.»<br>Mi mamá [MAMÁ] → «Vine con mi mamá.»<br>Mi hermano [HERMANO] → «Vine con mi hermano.»<br>Mi hermana [HERMANA] → «Vine con mi hermana.»<br>Mi hijo [HIJO] → «Vine con mi hijo.»<br>Mi hija [HIJA] → «Vine con mi hija.»<br>Un amigo [AMIGO] → «Vine con un amigo.»<br>Otra persona (escribir) ⟨texto_detalle⟩ → «Vine con {texto}.»<br>Omitir | `identificacion/acompanante` | parcial |
| `Q.ID.EDAD_PROPIA` | ¿Qué edad tiene? | entero | Escribir mi edad ⟨entero⟩ → «Tengo {n} años.»<br>Omitir | `identificacion/edad` | parcial |

### denuncia

| Id | Formulación | Control | Respuestas → frase | Fuente | Soporte |
|---|---|---|---|---|---|
| `Q.DEN.INTENCION` | ¿Desea presentar una denuncia? | polar3 | Sí [SÍ] → «Sí, quiero presentar una denuncia.»<br>No [NO] → «Por ahora no quiero presentar una denuncia.»<br>No sé [NO_SABER] → «Todavía no sé si quiero presentar una denuncia.» | `n-s6-inicio_de_denuncia-01` | parcial |
| `Q.DEN.AUTORIDAD` | ¿Ante qué institución quiere presentarla? | seleccion_unica | Policía [POLICÍA] → «Quiero presentarla ante la Policía.»<br>FELCC [FELCC] → «Quiero presentarla ante la FELCC.»<br>FELCV [FELCV] → «Quiero presentarla ante la FELCV.»<br>Fiscalía [FISCALIA] → «Quiero presentarla ante la Fiscalía.»<br>No sé [NO_SABER] → «No sé ante qué institución presentarla.»<br>Omitir | `denuncia_robo/institucion` | diseño |

### relato

| Id | Formulación | Control | Respuestas → frase | Fuente | Soporte |
|---|---|---|---|---|---|
| `Q.HEC.QUE_OCURRIO` | ¿Qué ocurrió? | seleccion_multiple | Me robaron [ROBAR] → «Me robaron{objeto}.»<br>Perdí algo [PERDER] → «(según Q.HEC.PERDIDA_TIPO)»<br>Dañaron algo [DAÑAR] → «Dañaron{objeto}.»<br>Me engañaron [ENGAÑAR] → «Me engañaron.»<br>Alguien escapó [ESCAPAR] → «(según Q.HEC.ESCAPE_ACTOR)» | `n-s6-inicio_de_denuncia-02` | parcial |
| `Q.HEC.RELATO_ORDENADO` | ¿Puede contarme lo sucedido desde el inicio? | polar2 | Sí [SÍ] → «Sí. Quiero explicar lo sucedido desde el principio.»<br>No [NO] → «Ahora no puedo contarlo.» | `n-s6-inicio_de_denuncia-03` | diseño |
| `Q.HEC.ESCAPE_ACTOR` | ¿Quién escapó? | seleccion_unica | Yo logré escapar [YO · ESCAPAR] → «Logré escapar.»<br>La persona que lo hizo [LADRÓN · ESCAPAR] → «La persona que me robó escapó.»<br>Otra persona [ÉL · ESCAPAR] → «Otra persona escapó.»<br>No sé [NO_SABER] → «Alguien escapó, pero no sé quién.» | `denuncia_robo/hecho` | parcial |
| `Q.HEC.PERDIDA_TIPO` | ¿Lo perdió usted o cree que se lo quitaron? | alternativa | Lo perdí [PERDER] → «Perdí{objeto}.»<br>Creo que me lo robaron [ROBAR] → «Creo que me robaron{objeto}, pero no estoy seguro.»<br>No sé [NO_SABER] → «No sé si lo perdí o me lo robaron.» | `denuncia_robo/hecho` | parcial |
| `Q.HEC.AMPLIAR` | ¿Quiere agregar algo que no le pregunté? | polar2 | Sí [SÍ] → «Sí, quiero agregar información.»<br>No [NO] → «No, eso es todo.» | `n-s6-inicio_de_denuncia-12` | diseño |

### tiempo

| Id | Formulación | Control | Respuestas → frase | Fuente | Soporte |
|---|---|---|---|---|---|
| `Q.TIE.CUANDO` | ¿Cuándo ocurrió? | tiempo | Ahora mismo [AHORA] → «Ocurrió hace un momento.»<br>Hoy [HOY] → «Ocurrió hoy.»<br>Ayer [AYER] → «Ocurrió ayer.»<br>Anteayer [ANTEAYER] → «Ocurrió anteayer.»<br>Hace … minutos [MINUTO] ⟨entero⟩ → «Ocurrió hace {n} minutos.»<br>Hace … horas [HORA] ⟨entero⟩ → «Ocurrió hace {n} horas.»<br>Hace … días [DÍA] ⟨entero⟩ → «Ocurrió hace {n} días.»<br>Hace … semanas [SEMANA] ⟨entero⟩ → «Ocurrió hace {n} semanas.»<br>Hace … meses [MES] ⟨entero⟩ → «Ocurrió hace {n} meses.»<br>Por la tarde [TARDE] → «Fue por la tarde.»<br>Temprano [TEMPRANO] → «Fue temprano.»<br>No recuerdo [RECORDAR · NO] → «No recuerdo cuándo ocurrió.»<br>Omitir | `n-s6-inicio_de_denuncia-04` | parcial |
| `Q.TIE.APROX` | ¿Fue hoy, ayer o antes? | alternativa | Hoy [HOY] → «Fue hoy.»<br>Ayer [AYER] → «Fue ayer.»<br>Antes [PASADO] → «Fue antes de ayer o hace más tiempo.»<br>No recuerdo [RECORDAR · NO] → «No recuerdo cuándo fue.» | `n-s6-inicio_de_denuncia-05` | diseño |
| `Q.TIE.HORA` | ¿A qué hora aproximadamente? | hora | Escribir la hora ⟨hora⟩ → «Fue aproximadamente a las {hora}.»<br>Por la tarde [TARDE] → «Fue por la tarde.»<br>Temprano [TEMPRANO] → «Fue temprano.»<br>No recuerdo [RECORDAR · NO] → «No recuerdo la hora exacta.» | `n-s6-inicio_de_denuncia-06` | diseño |

### lugar

| Id | Formulación | Control | Respuestas → frase | Fuente | Soporte |
|---|---|---|---|---|---|
| `Q.LUG.DONDE` | ¿Dónde ocurrió? | lugar | En la calle [CALLE] ⟨lugar_literal⟩ → «Ocurrió en la calle{nombre}.»<br>En una avenida [AVENIDA] ⟨lugar_literal⟩ → «Ocurrió en la avenida{nombre}.»<br>En una plaza [PLAZA] ⟨lugar_literal⟩ → «Ocurrió en la plaza{nombre}.»<br>En un mercado [MERCADO] ⟨lugar_literal⟩ → «Ocurrió en el mercado{nombre}.»<br>En mi barrio / un barrio [BARRIO] ⟨lugar_literal⟩ → «Ocurrió en el barrio{nombre}.»<br>En una tienda [TIENDA] ⟨lugar_literal⟩ → «Ocurrió en una tienda{nombre}.»<br>En mi casa [CASA] → «Ocurrió en mi casa.»<br>En un micro [MICRO] → «Ocurrió dentro de un micro.»<br>En un trufi [TRUFI] → «Ocurrió dentro de un trufi.»<br>En Cochabamba [COCHABAMBA] → «Ocurrió en Cochabamba.»<br>Otro lugar (escribir) ⟨lugar_literal⟩ → «Ocurrió en «{texto}».»<br>No sé [NO_SABER] → «No sé exactamente dónde ocurrió.»<br>Omitir | `n-s6-inicio_de_denuncia-07` | parcial |
| `Q.LUG.RELACION` | ¿Cerca de qué lugar? | lugar | Cerca de… [CERCA] ⟨lugar_literal⟩ → «cerca de {referencia}»<br>Lejos de… [LEJOS] ⟨lugar_literal⟩ → «lejos de {referencia}»<br>Al lado de… [AL_LADO] ⟨lugar_literal⟩ → «al lado de {referencia}»<br>Pendiente → «(la relación sin referencia no se redacta)» | `denuncia_robo/lugar` | parcial |
| `Q.LUG.DENTRO_FUERA` | ¿Ocurrió dentro o fuera del lugar? | alternativa | Dentro [DENTRO] → «Ocurrió dentro.»<br>Fuera [FUERA] → «Ocurrió fuera.»<br>No sé [NO_SABER] → «No sé si fue dentro o fuera.» | `n-s6-inicio_de_denuncia-08` | diseño |

### persona

| Id | Formulación | Control | Respuestas → frase | Fuente | Soporte |
|---|---|---|---|---|---|
| `Q.PER.CONOCE` | ¿Conoce a la persona involucrada? | polar3 | Sí [SÍ] → «Sí, conozco a esa persona.»<br>No [NO] → «No conozco a esa persona.»<br>No sé [NO_SABER] → «No sé si la conozco.» | `n-s6-inicio_de_denuncia-09` | parcial |
| `Q.PER.VINCULO` | ¿Qué relación tiene con esa persona? | seleccion_unica | Mi pareja [PAREJA] → «Es mi pareja.»<br>Mi expareja [PAREJA · PASADO] → «Es mi expareja.»<br>Mi esposa [ESPOSA] → «Es mi esposa.»<br>Mi hermano [HERMANO] → «Es mi hermano.»<br>Mi hermana [HERMANA] → «Es mi hermana.»<br>Un pariente [PARIENTE] → «Es un pariente.»<br>Un amigo [AMIGO] → «Es un amigo.»<br>Un conocido [CONOCER] → «Es un conocido.»<br>Otra relación (escribir) ⟨texto_detalle⟩ → «Es {texto}.»<br>Omitir | `denuncia_robo/conocimiento`, `violencia/persona`, `amenaza_digital/persona` | parcial |
| `Q.PER.NOMBRE_TERCERO` | ¿Sabe cómo se llama esa persona? | texto_nombre | Escribir su nombre ⟨texto_nombre⟩ → «Se llama {nombre}.»<br>No sé [NO_SABER] → «No sé cómo se llama.»<br>Omitir | — | diseño |
| `Q.PER.RECONOCE` | ¿Puede identificarla si la vuelve a ver? | polar3 | Sí [SÍ] → «Sí, si la vuelvo a ver puedo identificarla.»<br>No [NO] → «No podría identificarla.»<br>No sé [NO_SABER] → «No sé si podría identificarla.» | `n-s6-inicio_de_denuncia-10` | diseño |
| `Q.PER.OTROS_PRESENTES` | ¿Había otras personas presentes? | polar3 | Sí [SÍ] → «Sí, había otras personas.»<br>No [NO] → «No había otras personas.»<br>No sé [NO_SABER] → «No sé si había otras personas.» | `n-s6-inicio_de_denuncia-11` | diseño |

### descripcion

| Id | Formulación | Control | Respuestas → frase | Fuente | Soporte |
|---|---|---|---|---|---|
| `Q.PER.DESC.SEXO` | ¿Era un hombre o una mujer? | alternativa | Un hombre [HOMBRE] → «Era un hombre.»<br>Una mujer [MUJER] → «Era una mujer.»<br>No sé [NO_SABER] → «No sé si era hombre o mujer.» | `n-s6-descripcion_de_per-01` | parcial |
| `Q.PER.DESC.EDAD` | ¿Qué edad aproximada tenía? | entero | Escribir una edad aproximada ⟨entero⟩ → «Tenía aproximadamente {n} años.»<br>Era joven [JOVEN] → «Era joven.»<br>Era adulto [ADULTO] → «Era adulto.»<br>No recuerdo [RECORDAR · NO] → «No recuerdo su edad.» | `n-s6-descripcion_de_per-02` | diseño |
| `Q.PER.DESC.ESTATURA` | ¿Era alto o bajo? | alternativa | Alto/a [ALTO] → «Era alto.»<br>Bajo/a [BAJO] → «Era bajo.»<br>No sé [NO_SABER] → «No recuerdo su estatura.» | `n-s6-descripcion_de_per-03` | parcial |
| `Q.PER.DESC.CONTEXTURA` | ¿Era delgado o de contextura gruesa? | alternativa | Delgado/a [FLACO] → «Era delgado.»<br>De contextura gruesa [GORDO] → «Era de contextura gruesa.»<br>No sé [NO_SABER] → «No recuerdo su contextura.» | `n-s6-descripcion_de_per-04` | parcial |
| `Q.PER.DESC.CABELLO` | ¿Qué color de cabello recuerda? | seleccion_unica | Negro [CABELLO · NEGRO] → «Tenía el cabello negro.»<br>Otro color (escribir) ⟨texto_detalle⟩ → «Tenía el cabello {texto}.»<br>No recuerdo [RECORDAR · NO] → «No recuerdo el color de su cabello.» | `n-s6-descripcion_de_per-05` | diseño |
| `Q.PER.DESC.ROPA` | ¿Qué ropa llevaba? | seleccion_multiple | Polera [POLERA] → «una polera{color}»<br>Pantalón [PANTALÓN] → «un pantalón{color}»<br>Chamarra [CHAMARRA] → «una chamarra{color}»<br>Gorra [GORRA] → «una gorra{color}»<br>Otra prenda (escribir) ⟨texto_detalle⟩ → «{texto}»<br>No recuerdo [RECORDAR · NO] → «No recuerdo su ropa.» | `n-s6-descripcion_de_per-06` | parcial |
| `Q.PER.DESC.GORRA` | ¿Llevaba gorra? | polar3 | Sí [SÍ] → «Sí, llevaba gorra.»<br>No [NO] → «No llevaba gorra.»<br>No sé [NO_SABER] → «No recuerdo si llevaba gorra.» | `n-s6-descripcion_de_per-07` | parcial |
| `Q.PER.DESC.MOCHILA` | ¿Llevaba mochila o bolsa? | alternativa | Una mochila [MOCHILA] → «Llevaba una mochila.»<br>Una bolsa [BOLSA] → «Llevaba una bolsa.»<br>Ninguna [NO] → «No llevaba mochila ni bolsa.»<br>No sé [NO_SABER] → «No recuerdo si llevaba mochila o bolsa.» | `n-s6-descripcion_de_per-08` | parcial |
| `Q.PER.DESC.LENTES` | ¿Usaba lentes? | polar3 | Sí [SÍ] → «Sí, usaba lentes.»<br>No [NO] → «No usaba lentes.»<br>No sé [NO_SABER] → «No recuerdo si usaba lentes.» | `n-s6-descripcion_de_per-09` | parcial |
| `Q.PER.DESC.RASGO` | ¿Recuerda alguna característica particular? | texto_detalle | Escribir la característica ⟨texto_detalle⟩ → «Recuerdo esto de esa persona: «{texto}».»<br>No recuerdo [RECORDAR · NO] → «No recuerdo ninguna característica particular.» | `n-s6-descripcion_de_per-10` | diseño |

### robo

| Id | Formulación | Control | Respuestas → frase | Fuente | Soporte |
|---|---|---|---|---|---|
| `Q.ROB.ALGO` | ¿Le robaron algún objeto? | polar3 | Sí [SÍ] → «Sí, me robaron algo.»<br>No [NO] → «No me robaron nada.»<br>No sé [NO_SABER] → «No sé si me robaron algo.» | `n-s6-robo_hurto_y_obje-01` | diseño |
| `Q.ROB.QUE` | ¿Qué le robaron? | seleccion_multiple | Celular [CELULAR] → «el celular»<br>Dinero [BILLETES] ⟨monto⟩ → «{moneda} {monto}»<br>Mochila [MOCHILA] → «la mochila»<br>Bolsa [BOLSA] → «la bolsa»<br>Una caja [CAJA] → «una caja»<br>Chamarra [CHAMARRA] → «la chamarra»<br>Gorra [GORRA] → «la gorra»<br>Lentes [LENTES] → «los lentes»<br>Carnet de identidad [PAPEL · IDENTIDAD] → «mi carnet de identidad»<br>Un papel (no sé cómo se llama) [PAPEL] → «(según Q.DOC.ACLARAR)»<br>Un vehículo (micro/trufi) [MICRO] → «el micro»<br>Otro objeto (escribir) ⟨texto_detalle⟩ → «{texto}»<br>No sé [NO_SABER] → «No sé exactamente qué me falta.» | `n-s6-robo_hurto_y_obje-02` | parcial |
| `Q.ROB.CONFIRMA_OBJETO` | ¿Le robaron el celular? | polar3 | Sí [SÍ] → «Sí, me robaron el celular.»<br>No [NO] → «No me robaron el celular.»<br>No sé [NO_SABER] → «No sé si me robaron el celular.»<br>Me robaron otra cosa → «No me robaron el celular; me robaron {objetos}.» | `n-s6-robo_hurto_y_obje-03` | diseño |
| `Q.ROB.FALTA_CARNET` | ¿Le falta su carnet de identidad? | polar3 | Sí [SÍ] → «Sí, me falta mi carnet de identidad.»<br>No [NO] → «No me falta mi carnet.»<br>No sé [NO_SABER] → «No sé si me falta mi carnet.» | `n-s6-robo_hurto_y_obje-04` | diseño |
| `Q.ROB.FALTA_DINERO` | ¿Le falta dinero? | polar3 | Sí [SÍ] → «Sí, me falta dinero.»<br>No [NO] → «No me falta dinero.»<br>No sé [NO_SABER] → «No sé si me falta dinero.» | `n-s6-robo_hurto_y_obje-05` | diseño |
| `Q.ROB.VIO_LADRON` | ¿Vio al ladrón? | polar3 | Sí [SÍ] → «Sí, vi a la persona que me robó.»<br>No [NO] → «No vi a la persona que me robó.»<br>No sé [NO_SABER] → «No estoy seguro de haberla visto.» | `n-s6-robo_hurto_y_obje-06` | diseño |
| `Q.ROB.LADRON_ESCAPO` | ¿El ladrón escapó? | polar3 | Sí [SÍ] → «Sí, la persona que me robó escapó.»<br>No [NO] → «No, no escapó.»<br>No sé [NO_SABER] → «No sé si escapó.» | `n-s6-robo_hurto_y_obje-07` | diseño |

### evidencia

| Id | Formulación | Control | Respuestas → frase | Fuente | Soporte |
|---|---|---|---|---|---|
| `Q.EVI.FACTURA_O_CAJA` | ¿Tiene la factura o la caja del celular? | derivacion |  | `n-s6-robo_hurto_y_obje-08` | diseño |
| `Q.EVI.FACTURA` | ¿Tiene una factura? | polar3 | Sí [SÍ] → «Sí, tengo una factura.»<br>No [NO] → «No tengo factura.»<br>No sé [NO_SABER] → «No sé si tengo la factura.» | `denuncia_robo/evidencia`, `engano_dinero/comprobante` | diseño |
| `Q.EVI.TRAE_COPIA` | ¿La tiene aquí con usted? | polar3 | Sí [SÍ] → «La tengo aquí.»<br>No [NO] → «No la tengo aquí.»<br>No sé [NO_SABER] → «No sé si la traje.» | — | diseño |
| `Q.EVI.CAJA` | ¿Tiene la caja del celular? | polar3 | Sí [SÍ] → «Sí, tengo la caja del celular.»<br>No [NO] → «No tengo la caja del celular.»<br>No sé [NO_SABER] → «No sé si tengo la caja.» | — | diseño |
| `Q.EVI.CAMARAS` | ¿Hay cámaras o video del lugar? | polar3 | Sí [SÍ] → «Sí, hay video del lugar.»<br>No [NO] → «No hay cámaras en ese lugar.»<br>No sé [NO_SABER] → «No sé si hay cámaras.» | `n-s6-robo_hurto_y_obje-09` | diseño |
| `Q.EVI.FOTOS` | ¿Tiene fotografías? | polar3 | Sí [SÍ] → «Sí, tengo fotos.»<br>No [NO] → «No tengo fotos.»<br>No sé [NO_SABER] → «No sé si tengo fotos.» | `n-s6-testigos_fotos_v-05` | diseño |
| `Q.EVI.VIDEO` | ¿Tiene video? | polar3 | Sí [SÍ] → «Sí, tengo un video.»<br>No [NO] → «No tengo video.»<br>No sé [NO_SABER] → «No sé si tengo video.» | `n-s6-testigos_fotos_v-06` | diseño |
| `Q.EVI.MOSTRAR_AHORA` | ¿Puede mostrarlo ahora? | polar3 | Sí [SÍ] → «Sí, puedo mostrarlo ahora.»<br>No [NO] → «No puedo mostrarlo ahora.»<br>No sé [NO_SABER] → «No sé si puedo mostrarlo ahora.» | `n-s6-testigos_fotos_v-07` | diseño |
| `Q.EVI.CERTIFICADO` | ¿Tiene un certificado? | polar3 | Sí [SÍ] → «Sí, tengo un certificado.»<br>No [NO] → «No tengo certificado.»<br>No sé [NO_SABER] → «No sé si tengo un certificado.» | `n-s6-testigos_fotos_v-08` | diseño |
| `Q.EVI.RESOLUCION_PREVIA` | ¿Tiene una resolución o papel previo? | polar3 | Sí [SÍ] → «Sí, tengo un documento anterior.»<br>No [NO] → «No tengo ningún documento anterior.»<br>No sé [NO_SABER] → «No sé si tengo un documento anterior.» | `n-s6-testigos_fotos_v-09` | diseño |
| `Q.EVI.PRESENTAR` | ¿Desea presentar estos elementos? | polar3 | Sí [SÍ] → «Sí, quiero presentar estos elementos.»<br>No [NO] → «Por ahora no quiero presentarlos.»<br>No sé [NO_SABER] → «Todavía no lo sé.» | `n-s6-testigos_fotos_v-10` | diseño |
| `Q.EVI.QUE_TIENE` | ¿Tiene fotos, video u otra cosa que pueda mostrar? | polar3 | Sí [SÍ] → «(según las elegidas)»<br>No [NO] → «No tengo fotos, video ni otra cosa para mostrar.»<br>No sé [NO_SABER] → «No sé si tengo algo para mostrar.» | `denuncia_robo/evidencia` | diseño |
| `Q.EVI.TIPOS` | ¿Qué tiene? | seleccion_multiple | Fotos [FOTOS] → «fotos»<br>Video [VIDEO] → «un video»<br>Factura [FACTURA] → «una factura»<br>Certificado [CERTIFICADO] → «un certificado»<br>Otra cosa (escribir) ⟨texto_detalle⟩ → «{texto}» | `denuncia_robo/evidencia`, `violencia/evidencia` | parcial |

### testigos

| Id | Formulación | Control | Respuestas → frase | Fuente | Soporte |
|---|---|---|---|---|---|
| `Q.TES.EXISTE` | ¿Hay testigos? | polar3 | Sí [SÍ] → «Sí, hay testigos.»<br>No [NO] → «No hay testigos.»<br>No sé [NO_SABER] → «No sé si hay testigos.» | `n-s6-robo_hurto_y_obje-10`, `n-s6-testigos_fotos_v-01` | parcial |
| `Q.TES.CANTIDAD` | ¿Cuántos testigos hay? | entero | Escribir cuántos ⟨entero⟩ → «Hay {n} testigos.»<br>No sé [NO_SABER] → «No sé cuántos testigos hay.» | `n-s6-testigos_fotos_v-02` | diseño |
| `Q.TES.VIO_TODO` | ¿El testigo vio todo? | polar3 | Sí [SÍ] → «Sí, el testigo vio todo.»<br>No [NO] → «No, el testigo no vio todo.»<br>No sé [NO_SABER] → «No sé si el testigo vio todo.» | `n-s6-testigos_fotos_v-03` | diseño |
| `Q.TES.TRAER` | ¿Puede traer al testigo? | polar3 | Sí [SÍ] → «Sí, puedo traer al testigo.»<br>No [NO] → «No puedo traer al testigo.»<br>No sé [NO_SABER] → «No sé si puedo traerlo.» | `n-s6-testigos_fotos_v-04` | diseño |
| `Q.TES.RELATO` | ¿Qué vio? | seleccion_multiple | Vi lo que pasó [OBSERVAR] → «Vi que {hecho en tercera persona}.»<br>Puedo dar testimonio [OBSERVAR · TESTIMONIO · PUEDO] → «Vi lo ocurrido y puedo dar testimonio.» | `otro/relato` | diseño |
| `Q.PER.OBSERVADA` | ¿A quién vio? | persona_identidad | Un hombre [HOMBRE] → «Vi a un hombre.»<br>Una mujer [MUJER] → «Vi a una mujer.»<br>Al ladrón [LADRÓN] → «Vi a la persona que robó.»<br>No sé [NO_SABER] → «No vi bien a la persona.» | `otro/persona` | parcial |

### documento

| Id | Formulación | Control | Respuestas → frase | Fuente | Soporte |
|---|---|---|---|---|---|
| `Q.DOC.ACLARAR` | ¿Qué papel es? | seleccion_unica | Carnet de identidad [PAPEL · IDENTIDAD] → «mi carnet de identidad»<br>Comprobante del banco [PAPEL · BANCO] → «el comprobante del banco»<br>Citación [PAPEL · CONVOCAR] → «una citación»<br>Resolución [RESOLUCIÓN] → «una resolución»<br>Certificado [CERTIFICADO] → «un certificado»<br>Fotocopia [FOTOCOPIA] → «una fotocopia»<br>Factura [FACTURA] → «una factura»<br>Otro (escribir cómo se llama) ⟨texto_detalle⟩ → «un documento: «{texto}»»<br>No sé [NO_SABER] → «Tengo un papel, pero no sé qué documento es.» | `engano_dinero/comprobante`, `denuncia_robo/objetos`, `identificacion/identidad`, `seguimiento/tramite`, `preguntas/tema_pregunta` | parcial |

### violencia

| Id | Formulación | Control | Respuestas → frase | Fuente | Soporte |
|---|---|---|---|---|---|
| `Q.VIO.AGRESION` | ¿Alguien le pegó o maltrató? | polar3 | Sí [SÍ] → «Sí, me agredieron.»<br>No [NO] → «No, nadie me pegó ni me maltrató.»<br>No sé [NO_SABER] → «No estoy seguro.» | `n-s6-agresion_violenci-01` | diseño |
| `Q.VIO.TIPO` | ¿Qué le hicieron? | seleccion_multiple | Me pegaron [PEGAR] → «Me pegaron.»<br>Me maltrataron [MALTRATAR] → «Me maltrataron.»<br>Me amenazaron [AMENAZAR] → «Me amenazaron.»<br>Me gritaron [GRITAR] → «Me gritaron.»<br>Abusaron de mí [ABUSAR] → «Abusaron de mí.»<br>Sufrí violencia [VIOLENCIA] → «Sufrí violencia.»<br>Dañaron mis cosas [DAÑAR] → «Dañaron mis cosas.» | `violencia/hecho` | parcial |
| `Q.VIO.AGRESOR` | ¿Quién le agredió? | persona_identidad | Alguien que conozco → «Fue mi {vinculo}.»<br>Un hombre que no conozco [HOMBRE] → «Fue un hombre que no conozco.»<br>Una mujer que no conozco [MUJER] → «Fue una mujer que no conozco.»<br>No sé [NO_SABER] → «No sé quién fue.» | `violencia/persona` | parcial |
| `Q.VIO.FRECUENCIA` | ¿Es la primera vez o pasa seguido? | alternativa | Es la primera vez [PRIMERA_VEZ] → «Es la primera vez.»<br>Pasa siempre [SIEMPRE] → «Pasa siempre.»<br>Pasa cada día [CADA_DÍA] → «Pasa todos los días.»<br>No sé [NO_SABER] → «No sé decirlo.» | `violencia/tiempo` | parcial |

### salud

| Id | Formulación | Control | Respuestas → frase | Fuente | Soporte |
|---|---|---|---|---|---|
| `Q.SAL.HERIDO` | ¿Está herido? | polar3 | Sí [SÍ] → «Sí, estoy herido.»<br>No [NO] → «No estoy herido.»<br>No sé [NO_SABER] → «No estoy seguro de estar herido.» | `n-s6-agresion_violenci-02` | parcial |
| `Q.SAL.PARTE` | ¿Dónde tiene la herida? | seleccion_unica | En el brazo [BRAZO] → «Tengo una herida en el brazo.»<br>Otra parte (escribir) ⟨texto_detalle⟩ → «Tengo una herida en {texto}.»<br>Omitir | `violencia/salud_urgencia` | parcial |
| `Q.SAL.ASISTENCIA` | ¿Necesita asistencia médica? | polar3 | Sí [SÍ] → «Sí, necesito atención médica.»<br>No [NO] → «No necesito atención médica.»<br>No sé [NO_SABER] → «No sé si necesito atención médica.» | `n-s6-agresion_violenci-03` | diseño |
| `Q.SAL.HOSPITAL` | ¿Fue al hospital? | polar3 | Sí [SÍ] → «Sí, fui al hospital.»<br>No [NO] → «No fui al hospital.»<br>No sé [NO_SABER] → «No lo recuerdo.» | `n-s6-agresion_violenci-04` | diseño |
| `Q.SAL.CERTIFICADO` | ¿Tiene certificado del doctor? | polar3 | Sí [SÍ] → «Sí, tengo certificado del doctor.»<br>No [NO] → «No tengo certificado del doctor.»<br>No sé [NO_SABER] → «No sé si tengo el certificado.» | `n-s6-agresion_violenci-05` | diseño |

### riesgo

| Id | Formulación | Control | Respuestas → frase | Fuente | Soporte |
|---|---|---|---|---|---|
| `Q.RIE.AMENAZAS` | ¿Recibió amenazas? | polar3 | Sí [SÍ] → «Sí, recibí amenazas.»<br>No [NO] → «No recibí amenazas.»<br>No sé [NO_SABER] → «No estoy seguro.» | `n-s6-agresion_violenci-06` | diseño |
| `Q.RIE.MIEDO_CASA` | ¿Tiene miedo de volver a su casa? | polar3 | Sí [SÍ] → «Sí, tengo miedo de volver a mi casa.»<br>No [NO] → «No tengo miedo de volver a mi casa.»<br>No sé [NO_SABER] → «No lo sé.» | `n-s6-agresion_violenci-07` | diseño |
| `Q.RIE.AUXILIO` | ¿Necesita auxilio ahora? | polar3 | Sí [SÍ] → «Sí, necesito auxilio ahora.»<br>No [NO] → «No necesito auxilio ahora.»<br>No sé [NO_SABER] → «No lo sé.» | `n-s6-agresion_violenci-08` | diseño |
| `Q.RIE.PROTECCION_OTROS` | ¿Hay niños u otras personas que necesiten protección? | polar3 | Sí [SÍ] → «Sí, hay otras personas que necesitan protección.»<br>No [NO] → «No hay otras personas en riesgo.»<br>No sé [NO_SABER] → «No lo sé.» | `n-s6-agresion_violenci-09` | diseño |
| `Q.RIE.QUIENES` | ¿Quiénes necesitan protección? | seleccion_multiple | Mi hijo [HIJO] → «mi hijo»<br>Mi hija [HIJA] → «mi hija»<br>Otra persona (escribir) ⟨texto_detalle⟩ → «{texto}» | `violencia/emocion_riesgo` | diseño |
| `Q.RIE.MIEDO` | ¿Tiene miedo o necesita protección? | derivacion |  | `violencia/emocion_riesgo` | diseño |
| `Q.RIE.PIDE_PROTECCION` | ¿Necesita protección? | polar3 | Sí [SÍ] → «Sí, necesito protección.»<br>No [NO] → «No necesito protección.»<br>No sé [NO_SABER] → «No lo sé.» | `violencia/emocion_riesgo` | diseño |

### apoyo

| Id | Formulación | Control | Respuestas → frase | Fuente | Soporte |
|---|---|---|---|---|---|
| `Q.ORI.SEPDAVI` | ¿Desea orientación para recibir asistencia de SEPDAVI? | polar3 | Sí [SÍ] → «Sí, quiero orientación de SEPDAVI.»<br>No [NO] → «Por ahora no.»<br>No sé [NO_SABER] → «No lo sé todavía.» | `n-s6-agresion_violenci-10` | diseño |
| `Q.VIO.ASISTENCIA_ESPECIALIZADA` | ¿Desea asistencia especializada? | polar3 | Sí [SÍ] → «Sí, quiero asistencia.»<br>No [NO] → «Por ahora no quiero asistencia.»<br>No sé [NO_SABER] → «Todavía no lo sé.» | `violencia/institucion` | diseño |
| `Q.APO.LEGAL` | ¿Necesita apoyo legal? | polar3 | Sí [SÍ] → «Sí, necesito apoyo legal.»<br>No [NO] → «No necesito apoyo legal.»<br>No sé [NO_SABER] → «No sé si lo necesito.» | `denuncia_robo/apoyo_legal` | parcial |
| `Q.APO.TIPO` | ¿Qué apoyo necesita? | seleccion_unica | Un abogado [ABOGADO] → «Necesito un abogado.»<br>Un abogado gratuito [ABOGADO · GRATIS] → «Necesito un abogado gratuito.»<br>Asistencia a la víctima (SEPDAVI) [ASISTENCIA · SEPDAVI] → «Quiero asistencia de SEPDAVI.»<br>FELCV [FELCV] → «Quiero acudir a la FELCV.»<br>No sé [NO_SABER] → «No sé qué apoyo necesito.» | `denuncia_robo/apoyo_legal`, `violencia/institucion` | parcial |

### mensajes

| Id | Formulación | Control | Respuestas → frase | Fuente | Soporte |
|---|---|---|---|---|---|
| `Q.DIG.POR_CELULAR` | ¿Las amenazas llegaron por celular? | polar3 | Sí [SÍ] → «Sí, llegaron por celular.»<br>No [NO] → «No llegaron por celular.»<br>No sé [NO_SABER] → «No lo sé.» | `n-s6-amenazas_mensajes-01` | diseño |
| `Q.DIG.POR_INTERNET` | ¿Le escribieron por internet? | polar3 | Sí [SÍ] → «Sí, me escribieron por internet.»<br>No [NO] → «No me escribieron por internet.»<br>No sé [NO_SABER] → «No lo sé.» | `n-s6-amenazas_mensajes-02` | diseño |
| `Q.DIG.CANAL` | ¿Por dónde le llegaron los mensajes? | seleccion_multiple | Por celular [CELULAR] → «por celular»<br>Por internet [INTERNET] → «por internet»<br>Otra aplicación (escribir) ⟨texto_detalle⟩ → «por «{texto}»»<br>No sé [NO_SABER] → «No sé por dónde llegaron.» | `amenaza_digital/hecho` | diseño |
| `Q.DIG.CONTENIDO` | ¿Qué decían los mensajes? | seleccion_unica | Me amenazaban [AMENAZAR] → «Me amenazaban.»<br>Otra cosa (escribir un resumen) ⟨texto_detalle⟩ → «Los mensajes decían: «{texto}».»<br>Omitir | `amenaza_digital/hecho` | parcial |
| `Q.DIG.REMITENTE` | ¿Quién le envió los mensajes? | persona_identidad | Sé quién es [CONOCER] → «Los mensajes me los envía {vinculo_o_nombre}.»<br>Solo conozco el número ⟨telefono⟩ → «No conozco su nombre; el número que aparece es {telefono}.»<br>Un hombre (no sé quién) [HOMBRE] → «Me los envía un hombre; no sé quién es.»<br>Una mujer (no sé quién) [MUJER] → «Me los envía una mujer; no sé quién es.»<br>No sé [NO_SABER] → «No sé quién me envía los mensajes.» | `amenaza_digital/persona` | diseño |
| `Q.DIG.NUMERO_CONOCE` | ¿Conoce el número desde el que le escribieron? | polar3 | Sí [SÍ] → «Sí, conozco el número: {telefono}.»<br>No [NO] → «No conozco el número.»<br>No sé [NO_SABER] → «No estoy seguro del número.» | `n-s6-amenazas_mensajes-03` | diseño |
| `Q.DIG.GUARDO` | ¿Guardó los mensajes? | polar3 | Sí [SÍ] → «Sí, guardé los mensajes.»<br>No [NO] → «No guardé los mensajes.»<br>No sé [NO_SABER] → «No sé si se guardaron.»<br>Sí, todos [GUARDAR · TOTAL] → «Guardé todos los mensajes.» | `n-s6-amenazas_mensajes-04` | diseño |
| `Q.DIG.CAPTURAS` | ¿Tiene fotos de la pantalla? | polar3 | Sí [SÍ] → «Sí, tengo fotos de la pantalla.»<br>No [NO] → «No tengo fotos de la pantalla.»<br>No sé [NO_SABER] → «No sé si tengo fotos de la pantalla.» | `n-s6-amenazas_mensajes-05` | diseño |
| `Q.DIG.GUARDO_O_CAPTURAS` | ¿Guardó los mensajes o tiene fotos de pantalla? | derivacion |  | `amenaza_digital/evidencia` | diseño |
| `Q.DIG.CONTINUA` | ¿Sigue recibiendo mensajes? | polar3 | Sí [SÍ] → «Sí, sigo recibiendo mensajes.»<br>No [NO] → «Ya no recibo mensajes.»<br>No sé [NO_SABER] → «No lo sé.» | `n-s6-amenazas_mensajes-06` | diseño |
| `Q.DIG.CANT_NUMEROS` | ¿Son uno o varios números? | alternativa | Un solo número [1] → «Es un solo número.»<br>Varios números ⟨entero⟩ → «Son {n} números.»<br>No sé [NO_SABER] → «No sé cuántos números son.» | `n-s6-amenazas_mensajes-07` | diseño |
| `Q.DIG.MOSTRAR` | ¿Puede mostrar el celular ahora? | polar3 | Sí [SÍ] → «Sí, puedo mostrar el celular ahora.»<br>No [NO] → «No puedo mostrarlo ahora.»<br>No sé [NO_SABER] → «No lo sé.» | `n-s6-amenazas_mensajes-08` | diseño |
| `Q.DIG.PRESENTAR_PRUEBA` | ¿Desea presentar los mensajes como prueba? | polar3 | Sí [SÍ] → «Sí, quiero presentar los mensajes como prueba.»<br>No [NO] → «Por ahora no quiero presentarlos.»<br>No sé [NO_SABER] → «Todavía no lo sé.» | `amenaza_digital/institucion` | diseño |

### dinero

| Id | Formulación | Control | Respuestas → frase | Fuente | Soporte |
|---|---|---|---|---|---|
| `Q.DIN.ENTREGO` | ¿Entregó o envió dinero? | polar3 | Sí [SÍ] → «Sí, entregué dinero.»<br>No [NO] → «No entregué ni envié dinero.»<br>No sé [NO_SABER] → «No estoy seguro.» | `n-s6-engaño_dinero_y_t-01` | diseño |
| `Q.DIN.MECANISMO` | ¿Cómo entregó el dinero? | seleccion_unica | En mano, en efectivo [DAR · BILLETES] → «Entregué{monto} en mano.»<br>Por un banco [ENVIAR · BANCO] → «Envié{monto} mediante un banco.»<br>Por internet [ENVIAR · INTERNET] → «Envié{monto} por internet.»<br>Desde el celular [ENVIAR · CELULAR] → «Envié{monto} desde el celular.»<br>Otra forma (escribir) ⟨texto_detalle⟩ → «Entregué{monto} de esta forma: «{texto}».»<br>No recuerdo [RECORDAR · NO] → «No recuerdo cómo entregué el dinero.» | `engano_dinero/hecho`, `engano_dinero/medio_banco` | diseño |
| `Q.DIN.MONTO` | ¿Cuánto dinero fue? | monto | Escribir el monto ⟨monto⟩ → «{moneda} {monto}»<br>No recuerdo [RECORDAR · NO] → «No recuerdo el monto exacto.»<br>Omitir | `n-s6-engaño_dinero_y_t-02` | parcial |
| `Q.DIN.POR_BANCO` | ¿Lo hizo mediante un banco? | polar3 | Sí [SÍ] → «Sí, lo envié mediante un banco.»<br>No [NO] → «No fue mediante un banco.»<br>No sé [NO_SABER] → «No lo sé.» | `n-s6-engaño_dinero_y_t-03` | diseño |
| `Q.DIN.COMPROBANTE` | ¿Tiene algún comprobante? | polar3 | Sí [SÍ] → «(según Q.DIN.COMPROBANTE_TIPO)»<br>No [NO] → «No tengo comprobante.»<br>No sé [NO_SABER] → «No sé si tengo comprobante.» | `n-s6-engaño_dinero_y_t-04` | diseño |
| `Q.DIN.COMPROBANTE_TIPO` | ¿Qué comprobante tiene? | seleccion_multiple | Comprobante del banco [PAPEL · BANCO] → «el comprobante del banco»<br>Factura [FACTURA] → «una factura»<br>Capturas en mi celular [FOTOS · CELULAR] → «capturas en mi celular»<br>Un papel (no sé cómo se llama) [PAPEL] → «(según Q.DOC.ACLARAR)» | `engano_dinero/comprobante` | diseño |
| `Q.DIN.RECEPTOR_NOMBRE` | ¿Conoce el nombre de la persona? | polar3 | Sí [SÍ] → «Sí, se llama {nombre}.»<br>No [NO] → «No conozco su nombre.»<br>No sé [NO_SABER] → «No estoy seguro de su nombre.» | `n-s6-engaño_dinero_y_t-05` | diseño |
| `Q.DIN.RECEPTOR_NUMERO` | ¿Tiene su número de celular? | polar3 | Sí [SÍ] → «Sí, su número es {telefono}.»<br>No [NO] → «No tengo su número.»<br>No sé [NO_SABER] → «No estoy seguro de tenerlo.» | `n-s6-engaño_dinero_y_t-06` | diseño |
| `Q.DIN.RECEPTOR` | ¿Quién recibió el dinero? | persona_identidad | Sé su nombre [NOMBRE] ⟨texto_nombre⟩ → «Recibió el dinero {nombre}.»<br>Solo tengo su número [CELULAR] ⟨telefono⟩ → «No conozco su nombre; tengo su número: {telefono}.»<br>Un hombre (no sé quién) [HOMBRE] → «Lo recibió un hombre que no conozco.»<br>Una mujer (no sé quién) [MUJER] → «Lo recibió una mujer que no conozco.»<br>No sé [NO_SABER] → «No sé quién recibió el dinero.» | `engano_dinero/persona` | diseño |
| `Q.DIN.INTERNET` | ¿Se comunicaron por internet? | polar3 | Sí [SÍ] → «Sí, nos comunicamos por internet.»<br>No [NO] → «No nos comunicamos por internet.»<br>No sé [NO_SABER] → «No lo sé.» | `n-s6-engaño_dinero_y_t-07` | diseño |
| `Q.DIN.CHAT` | ¿Conserva toda la conversación? | polar3 | Sí [SÍ] → «Sí, conservo toda la conversación.»<br>No [NO] → «No conservo la conversación.»<br>No sé [NO_SABER] → «No sé si la conservo.» | `n-s6-engaño_dinero_y_t-08` | diseño |

### seguimiento

| Id | Formulación | Control | Respuestas → frase | Fuente | Soporte |
|---|---|---|---|---|---|
| `Q.SEG.ESTADO_CASO` | ¿Vino a consultar el estado de su caso? | polar3 | Sí [SÍ] → «Sí, vine a consultar el estado de mi caso.»<br>No [NO] → «No, vine por otra cosa.»<br>No sé [NO_SABER] → «No estoy seguro.» | `n-s6-seguimiento_prelim-01` | diseño |
| `Q.SEG.NUM_REFERENCIA` | ¿Tiene el número de referencia? | polar3 | Sí [SÍ] → «Sí, el número es {referencia}.»<br>No [NO] → «No tengo el número de referencia.»<br>No sé [NO_SABER] → «No sé si lo tengo.» | `n-s6-seguimiento_prelim-02` | diseño |
| `Q.SEG.FECHA_DENUNCIA` | ¿Cuándo presentó la denuncia? | tiempo | Hace … días [DÍA] ⟨entero⟩ → «La presenté hace {n} días.»<br>Hace … semanas [SEMANA] ⟨entero⟩ → «La presenté hace {n} semanas.»<br>Hace … meses [MES] ⟨entero⟩ → «La presenté hace {n} meses.»<br>Ayer [AYER] → «La presenté ayer.»<br>No recuerdo [RECORDAR · NO] → «No recuerdo cuándo la presenté.» | `n-s6-seguimiento_prelim-03` | diseño |
| `Q.SEG.HABLAR_POLICIA` | ¿Quiere hablar con el policía encargado? | polar3 | Sí [SÍ] → «Sí, quiero hablar con el policía encargado.»<br>No [NO] → «No hace falta.»<br>No sé [NO_SABER] → «No lo sé.» | `n-s6-seguimiento_prelim-04` | diseño |
| `Q.SEG.HABLAR_ABOGADO` | ¿Necesita hablar con un abogado? | polar3 | Sí [SÍ] → «Sí, necesito hablar con un abogado.»<br>No [NO] → «No necesito hablar con un abogado.»<br>No sé [NO_SABER] → «No lo sé.» | `n-s6-seguimiento_prelim-05` | diseño |
| `Q.SEG.DEFENSA_PUBLICA` | ¿Necesita defensa pública gratuita? | polar3 | Sí [SÍ] → «Sí, necesito defensa pública gratuita.»<br>No [NO] → «No la necesito.»<br>No sé [NO_SABER] → «No lo sé.» | `n-s6-seguimiento_prelim-06` | diseño |
| `Q.SEG.DONDE_FISCALIA` | ¿Necesita saber dónde está la Fiscalía? | polar2 | Sí [SÍ] → «Sí, necesito saber dónde está la Fiscalía.»<br>No [NO] → «No, ya sé dónde está.» | `n-s6-seguimiento_prelim-07` | diseño |
| `Q.SEG.CITACION` | ¿Recibió un papel de convocatoria? | polar3 | Sí [SÍ] → «Sí, recibí una citación.»<br>No [NO] → «No recibí ninguna citación.»<br>No sé [NO_SABER] → «No sé si es una citación.» | `n-s6-seguimiento_prelim-08` | diseño |
| `Q.SEG.RETORNO` | ¿Tiene que volver otro día? | polar3 | Sí [SÍ] → «Sí, tengo que volver otro día.»<br>No [NO] → «No tengo que volver.»<br>No sé [NO_SABER] → «No sé si tengo que volver.» | `n-s6-seguimiento_prelim-09` | diseño |
| `Q.SEG.HABLAR_FISCAL` | ¿Necesita hablar con el fiscal? | polar3 | Sí [SÍ] → «Sí, necesito hablar con el fiscal.»<br>No [NO] → «No necesito hablar con el fiscal.»<br>No sé [NO_SABER] → «No lo sé.» | `n-s6-interaccion_con_fi-01` | diseño |
| `Q.SEG.DERIVACION_FISCALIA` | ¿Le indicaron ir a la Fiscalía? | polar3 | Sí [SÍ] → «Sí, me indicaron que debo ir a la Fiscalía.»<br>No [NO] → «No me indicaron eso.»<br>No sé [NO_SABER] → «No estoy seguro.» | `n-s6-interaccion_con_fi-02` | diseño |
| `Q.SEG.RESOLUCION` | ¿Recibió una resolución? | polar3 | Sí [SÍ] → «Sí, recibí una resolución.»<br>No [NO] → «No recibí ninguna resolución.»<br>No sé [NO_SABER] → «No sé si es una resolución.» | `n-s6-interaccion_con_fi-03` | diseño |
| `Q.SEG.JUEZ` | ¿Debe presentarse ante un juez? | polar3 | Sí [SÍ] → «Sí, tengo que presentarme ante un juez.»<br>No [NO] → «No tengo que presentarme ante un juez.»<br>No sé [NO_SABER] → «No sé si tengo que presentarme.» | `n-s6-interaccion_con_fi-04` | diseño |
| `Q.SEG.ORGANO_JUDICIAL` | ¿Sabe dónde está el Órgano Judicial? | polar2 | Sí [SÍ] → «Sí, sé dónde está.»<br>No [NO] → «No sé dónde está el Órgano Judicial.» | `n-s6-interaccion_con_fi-05` | diseño |
| `Q.SEG.INTERPRETE_REUNION` | ¿Necesita intérprete para esa reunión? | polar3 | Sí [SÍ] → «Sí, necesito intérprete para esa reunión.»<br>No [NO] → «No necesito intérprete para esa reunión.»<br>No sé [NO_SABER] → «No lo sé.» | `n-s6-interaccion_con_fi-06` | diseño |
| `Q.SEG.LEER_ANTES_FIRMAR` | ¿Quiere leer el papel antes de escribir su nombre? | polar3 | Sí [SÍ] → «Sí, quiero leer el papel antes de escribir mi nombre.»<br>No [NO] → «No hace falta.»<br>No sé [NO_SABER] → «No lo sé.» | `n-s6-interaccion_con_fi-07` | diseño |
| `Q.SEG.CONFORMIDAD` | ¿Está de acuerdo con lo escrito? | alternativa | Sí, estoy de acuerdo [ESTAR_DE_ACUERDO] → «Sí, estoy de acuerdo con lo escrito.»<br>No estoy de acuerdo [NO · ESTAR_DE_ACUERDO] → «No estoy de acuerdo con lo escrito.»<br>Quiero leerlo otra vez [LEER] → «Quiero leerlo otra vez.»<br>No lo entiendo [NO · COMPRENDER] → «No entiendo lo escrito.» | `n-s6-interaccion_con_fi-08` | diseño |

### consulta

| Id | Formulación | Control | Respuestas → frase | Fuente | Soporte |
|---|---|---|---|---|---|
| `Q.SEG.MOTIVO` | ¿Qué quiere consultar? | seleccion_unica | El estado de mi caso [INVESTIGACIÓN · SABER · QUERER] → «Quiero saber cómo va la investigación de mi caso.»<br>Si la investigación continúa [INVESTIGACIÓN · CONTINUAR · SABER] → «Quiero saber si la investigación continúa.»<br>Cuándo debo volver [CUÁNDO · VOLVER] → «Quiero saber cuándo debo volver.»<br>Cuánto debo esperar [ESPERAR · CUÁNTOS] → «Quiero saber cuánto tiempo debo esperar.»<br>Una citación que recibí [PAPEL · CONVOCAR · RECIBIR] → «Recibí una citación y quiero consultar sobre ella.»<br>Una resolución que recibí [RESOLUCIÓN · RECIBIR] → «Recibí una resolución y quiero consultar sobre ella.»<br>Pedir una fotocopia [FOTOCOPIA · PEDIR] → «Quiero pedir una fotocopia.»<br>Hablar con alguien → «(según I.PREG.HABLAR_CON)»<br>Dónde queda una oficina → «(según I.PREG.DONDE_QUEDA)»<br>Otra consulta (escribir) ⟨texto_detalle⟩ → «Quiero consultar esto: «{texto}».» | `seguimiento/tramite`, `seguimiento/accion`, `preguntas/tema_pregunta`, `preguntas/tiempo_pregunta` | diseño |
| `Q.SEG.AUTORIDAD` | ¿Con qué institución es su trámite? | seleccion_unica | Policía [POLICÍA] → «con la Policía»<br>FELCC [FELCC] → «con la FELCC»<br>FELCV [FELCV] → «con la FELCV»<br>Fiscalía [FISCALIA] → «con la Fiscalía»<br>Juzgado [JUZGADO] → «con el juzgado»<br>Órgano Judicial [ÓRGANO_JUDICIAL] → «con el Órgano Judicial»<br>SEPDAVI [SEPDAVI] → «con SEPDAVI»<br>SEPDEP [SEPDEP] → «con SEPDEP»<br>No sé [NO_SABER] → «No sé con qué institución es.»<br>Omitir | `seguimiento/institucion_autoridad` | parcial |
| `Q.SEG.FECHA_PROGRAMADA` | ¿Para cuándo le dieron fecha? | tiempo | Hoy [HOY] → «Me dieron fecha para hoy.»<br>Mañana [MAÑANA] → «Me dieron fecha para mañana.»<br>La próxima semana [PRÓXIMO · SEMANA] → «Me dieron fecha para la próxima semana.»<br>Escribir la fecha [FECHA] ⟨texto_detalle⟩ → «Me dieron fecha para el {texto}.»<br>No sé [NO_SABER] → «No sé para cuándo es.» | `seguimiento/tiempo` | parcial |

### intervencion_propia

| Id | Formulación | Control | Respuestas → frase | Fuente | Soporte |
|---|---|---|---|---|---|
| `I.PREG.ELEGIR` | ¿Qué quieres preguntar? | seleccion_unica | ¿Dónde…? [DÓNDE] → «(plantilla)»<br>¿Con quién…? / ¿Quién…? [QUIÉN] → «(plantilla)»<br>¿Cuándo…? [CUÁNDO] → «(plantilla)»<br>¿Qué…? / ¿Cuál…? [QUÉ] → «(plantilla)»<br>¿Cuánto…? [CUÁNTOS] → «(plantilla)»<br>¿Cómo…? [CÓMO] → «(plantilla)» | `preguntas/interrogativa` | parcial |
| `I.PREG.DONDE_QUEDA` | ¿Dónde queda…? | seleccion_unica | La Fiscalía [FISCALIA · DÓNDE] → «¿Dónde está la Fiscalía?»<br>La FELCC [FELCC · DÓNDE] → «¿Dónde está la FELCC?»<br>La FELCV [FELCV · DÓNDE] → «¿Dónde está la FELCV?»<br>El juzgado [JUZGADO · DÓNDE] → «¿Dónde está el juzgado?»<br>El Órgano Judicial [ÓRGANO_JUDICIAL · DÓNDE] → «¿Dónde está el Órgano Judicial?»<br>SEPDAVI [SEPDAVI · DÓNDE] → «¿Dónde está SEPDAVI?»<br>SEPDEP [SEPDEP · DÓNDE] → «¿Dónde está SEPDEP?»<br>La Policía [POLICÍA · DÓNDE] → «¿Dónde está la Policía?»<br>La oficina [OFICINA · DÓNDE] → «¿Dónde está la oficina?»<br>El hospital [HOSPITAL · DÓNDE] → «¿Dónde está el hospital?» | `preguntas/lugar_pregunta` | parcial |
| `I.PREG.HABLAR_CON` | ¿Con quién quiere hablar? | seleccion_unica | Con el juez [JUEZ] → «¿Puedo hablar con el juez?»<br>Con un abogado [ABOGADO] → «¿Puedo hablar con un abogado?»<br>Con un intérprete [INTÉRPRETE] → «¿Aquí hay intérprete de LSB?»<br>Con el policía encargado [POLICÍA · HABLAR · PUEDO] → «¿Puedo hablar con el policía encargado?»<br>Con un oficial [OFICIAL] → «¿Puedo hablar con un oficial?»<br>Con la autoridad [AUTORIDAD] → «¿Puedo hablar con la autoridad?»<br>Con el asistente [ASISTENTE] → «¿Puedo hablar con el asistente?» | `preguntas/persona_pregunta` | parcial |
| `I.PREG.CUANDO` | ¿Qué quiere saber cuándo? | seleccion_unica | Cuándo vuelvo [CUÁNDO · VOLVER] → «¿Cuándo debo volver?»<br>Cuándo me avisan [CUÁNDO · AVISAR] → «¿Cuándo me van a avisar?»<br>Cuánto tiempo espero [ESPERAR · CUÁNTOS] → «¿Cuánto tiempo debo esperar?» | `preguntas/tiempo_pregunta` | parcial |
| `I.PREG.CUANTO` | ¿Qué quiere saber cuánto? | seleccion_unica | Cuántos días espero [ESPERAR · DÍA · CUÁNTOS] → «¿Cuántos días debo esperar?»<br>Cuántas horas espero [ESPERAR · HORA · CUÁNTOS] → «¿Cuántas horas debo esperar?» | `preguntas/tiempo_pregunta`, `preguntas/cantidad_pregunta` | diseño |
| `I.PREG.SOBRE_TEMA` | ¿Sobre qué quiere preguntar? | seleccion_unica | ¿Debo traer la factura? [FACTURA · TRAER · NECESITAR] → «¿Debo traer la factura del celular?»<br>¿Necesito fotocopias? [FOTOCOPIA · NECESITAR] → «¿Necesito fotocopias?»<br>¿Necesito un certificado? [CERTIFICADO · NECESITAR] → «¿Necesito un certificado?»<br>¿Pueden buscar mi celular? [CELULAR · BUSCAR · PUEDO] → «¿Pueden buscar mi celular?»<br>¿Dónde entrego las fotos? [FOTOS · DÓNDE · DAR] → «¿Dónde entrego las fotografías?»<br>¿Puedo traer el video mañana? [VIDEO · MAÑANA · TRAER · PUEDO] → «¿Puedo traer el video mañana?»<br>¿Me entregan un documento sellado? [PAPEL · SELLO · RECIBIR] → «¿Me entregan un documento sellado?»<br>¿La investigación continúa? [INVESTIGACIÓN · CONTINUAR] → «¿La investigación continúa?» | `preguntas/tema_pregunta` | parcial |
| `I.PREG.TRAER_TESTIGO` | ¿Puedo traer al testigo mañana? | intervencion | ¿Puedo traer al testigo mañana? [TESTIGO · MAÑANA · TRAER · PUEDO] → «¿Puedo traer al testigo mañana?» | `preguntas/persona_pregunta` | diseño |
| `I.DECL.CAMBIO_CONTACTO` | Cambié de dirección / de número | seleccion_unica | Cambié de dirección [DIRECCIÓN · CAMBIAR] ⟨texto_detalle⟩ → «Cambié de dirección. Ahora vivo en «{texto}».»<br>Cambié de número de celular [CELULAR · CAMBIAR] ⟨telefono⟩ → «Cambié de número de celular. Mi número nuevo es {telefono}.» | `identificacion/contacto` | diseño |
| `I.DECL.AGREGAR_INFORMACION` | Quiero agregar información | intervencion | Quiero agregar información [AUMENTAR · NARRAR · QUERER] → «Quiero agregar información a lo que dije.» | `otro/relato` | parcial |
| `I.DECL.CORREGIR` | Quiero corregir algo | intervencion | Quiero corregir algo [ARREGLAR] → «Quiero corregir algo de lo que dije.» | `otro/relato` | diseño |

## Qué ve hoy la persona sorda cuando el funcionario pregunta (modo C)

Solo los enunciados del corpus §6 cuya pregunta en pantalla no corresponde a la del banco.

| Nodo | Enunciado del funcionario | Pregunta del banco | Pregunta que se muestra hoy |
|---|---|---|---|
| `n-s6-acceso_comunicativ-03` | ¿Prefiere que le escriba en papel? | `Q.ACC.ESCRITO` | `identificacion/identidad` — ¿Cuál es su nombre e identidad? |
| `n-s6-acceso_comunicativ-05` | ¿Comprende lo que le estoy explicando? | `Q.ACC.COMPRENSION` | `identificacion/identidad` — ¿Cuál es su nombre e identidad? |
| `n-s6-acceso_comunicativ-06` | ¿Quiere que lo explique otra vez y más despacio? | `Q.ACC.REPARACION` | `identificacion/identidad` — ¿Cuál es su nombre e identidad? |
| `n-s6-acceso_comunicativ-08` | ¿Puede deletrear su apellido? | `Q.ID.APELLIDO` | `identificacion/identidad` — ¿Cuál es su nombre e identidad? |
| `n-s6-acceso_comunicativ-09` | ¿Tiene su carnet de identidad? | `Q.ID.DOC_TIENE` | `identificacion/identidad` — ¿Cuál es su nombre e identidad? |
| `n-s6-acceso_comunicativ-10` | ¿Este número de celular es suyo? | `Q.ID.TELEFONO_VALIDA` | `identificacion/identidad` — ¿Cuál es su nombre e identidad? |
| `n-s6-acceso_comunicativ-11` | ¿Prefiere recibir avisos por mensaje escrito? | `Q.ID.AVISO` | `identificacion/identidad` — ¿Cuál es su nombre e identidad? |
| `n-s6-acceso_comunicativ-12` | ¿Vino solo o acompañado? | `Q.ID.ACOMPANANTE` | `identificacion/identidad` — ¿Cuál es su nombre e identidad? |
| `n-s6-inicio_de_denuncia-03` | ¿Puede contarme lo sucedido desde el inicio? | `Q.HEC.RELATO_ORDENADO` | `denuncia_robo/hecho` — ¿Qué le ocurrió? |
| `n-s6-inicio_de_denuncia-05` | ¿Fue hoy, ayer o antes? | `Q.TIE.APROX` | `denuncia_robo/hecho` — ¿Qué le ocurrió? |
| `n-s6-inicio_de_denuncia-06` | ¿A qué hora aproximadamente? | `Q.TIE.HORA` | `denuncia_robo/tiempo` — ¿Cuándo ocurrió el hecho? |
| `n-s6-inicio_de_denuncia-08` | ¿Ocurrió dentro o fuera del lugar? | `Q.LUG.DENTRO_FUERA` | `denuncia_robo/hecho` — ¿Qué le ocurrió? |
| `n-s6-inicio_de_denuncia-10` | ¿Puede identificarla si la vuelve a ver? | `Q.PER.RECONOCE` | `denuncia_robo/hecho` — ¿Qué le ocurrió? |
| `n-s6-inicio_de_denuncia-11` | ¿Había otras personas presentes? | `Q.PER.OTROS_PRESENTES` | `denuncia_robo/hecho` — ¿Qué le ocurrió? |
| `n-s6-inicio_de_denuncia-12` | ¿Quiere agregar algo que no le pregunté? | `Q.HEC.AMPLIAR` | `denuncia_robo/hecho` — ¿Qué le ocurrió? |
| `n-s6-descripcion_de_per-01` | ¿Era un hombre o una mujer? | `Q.PER.DESC.SEXO` | `denuncia_robo/hecho` — ¿Qué le ocurrió? |
| `n-s6-descripcion_de_per-02` | ¿Era joven o adulto? | `Q.PER.DESC.EDAD` | `denuncia_robo/hecho` — ¿Qué le ocurrió? |
| `n-s6-descripcion_de_per-03` | ¿Era alto o bajo? | `Q.PER.DESC.ESTATURA` | `denuncia_robo/hecho` — ¿Qué le ocurrió? |
| `n-s6-descripcion_de_per-04` | ¿Era delgado o de contextura gruesa? | `Q.PER.DESC.CONTEXTURA` | `denuncia_robo/hecho` — ¿Qué le ocurrió? |
| `n-s6-descripcion_de_per-05` | ¿Qué color de cabello recuerda? | `Q.PER.DESC.CABELLO` | `denuncia_robo/hecho` — ¿Qué le ocurrió? |
| `n-s6-descripcion_de_per-09` | ¿Usaba lentes? | `Q.PER.DESC.LENTES` | `denuncia_robo/hecho` — ¿Qué le ocurrió? |
| `n-s6-descripcion_de_per-10` | ¿Recuerda alguna característica particular? | `Q.PER.DESC.RASGO` | `denuncia_robo/hecho` — ¿Qué le ocurrió? |
| `n-s6-robo_hurto_y_obje-01` | ¿Le robaron algún objeto? | `Q.ROB.ALGO` | `denuncia_robo/hecho` — ¿Qué le ocurrió? |
| `n-s6-robo_hurto_y_obje-03` | ¿Le robaron el celular? | `Q.ROB.CONFIRMA_OBJETO` | `denuncia_robo/objetos` — ¿Qué objetos están involucrados? |
| `n-s6-robo_hurto_y_obje-04` | ¿Le falta su carnet de identidad? | `Q.ROB.FALTA_CARNET` | `denuncia_robo/objetos` — ¿Qué objetos están involucrados? |
| `n-s6-robo_hurto_y_obje-05` | ¿Le falta dinero? | `Q.ROB.FALTA_DINERO` | `denuncia_robo/objetos` — ¿Qué objetos están involucrados? |
| `n-s6-robo_hurto_y_obje-06` | ¿Vio al ladrón? | `Q.ROB.VIO_LADRON` | `denuncia_robo/hecho` — ¿Qué le ocurrió? |
| `n-s6-robo_hurto_y_obje-07` | ¿El ladrón escapó? | `Q.ROB.LADRON_ESCAPO` | `denuncia_robo/hecho` — ¿Qué le ocurrió? |
| `n-s6-robo_hurto_y_obje-08` | ¿Tiene la factura o la caja del celular? | `Q.EVI.FACTURA_O_CAJA` | `denuncia_robo/hecho` — ¿Qué le ocurrió? |
| `n-s6-robo_hurto_y_obje-09` | ¿Hay cámaras o video del lugar? | `Q.EVI.CAMARAS` | `denuncia_robo/evidencia` — ¿Tiene fotos, video u otro elemento de prueba? |
| `n-s6-agresion_violenci-01` | ¿Alguien le pegó o maltrató? | `Q.VIO.AGRESION` | `violencia/hecho` — ¿Qué agresión o maltrato sufrió? |
| `n-s6-agresion_violenci-02` | ¿Está herido? | `Q.SAL.HERIDO` | `violencia/hecho` — ¿Qué agresión o maltrato sufrió? |
| `n-s6-agresion_violenci-03` | ¿Necesita asistencia médica? | `Q.SAL.ASISTENCIA` | `violencia/hecho` — ¿Qué agresión o maltrato sufrió? |
| `n-s6-agresion_violenci-04` | ¿Fue al hospital? | `Q.SAL.HOSPITAL` | `violencia/hecho` — ¿Qué agresión o maltrato sufrió? |
| `n-s6-agresion_violenci-05` | ¿Tiene certificado del doctor? | `Q.SAL.CERTIFICADO` | `violencia/hecho` — ¿Qué agresión o maltrato sufrió? |
| `n-s6-agresion_violenci-06` | ¿Recibió amenazas? | `Q.RIE.AMENAZAS` | `violencia/hecho` — ¿Qué agresión o maltrato sufrió? |
| `n-s6-agresion_violenci-07` | ¿Tiene miedo de volver a su casa? | `Q.RIE.MIEDO_CASA` | `violencia/hecho` — ¿Qué agresión o maltrato sufrió? |
| `n-s6-agresion_violenci-08` | ¿Necesita auxilio ahora? | `Q.RIE.AUXILIO` | `violencia/hecho` — ¿Qué agresión o maltrato sufrió? |
| `n-s6-agresion_violenci-09` | ¿Hay niños u otras personas que necesiten protección? | `Q.RIE.PROTECCION_OTROS` | `violencia/hecho` — ¿Qué agresión o maltrato sufrió? |
| `n-s6-agresion_violenci-10` | ¿Desea orientación para recibir asistencia de SEPDAVI? | `Q.ORI.SEPDAVI` | `violencia/hecho` — ¿Qué agresión o maltrato sufrió? |
| `n-s6-amenazas_mensajes-01` | ¿Las amenazas llegaron por celular? | `Q.DIG.POR_CELULAR` | `amenaza_digital/hecho` — ¿Qué tipo de mensajes recibió? |
| `n-s6-amenazas_mensajes-02` | ¿Le escribieron por internet? | `Q.DIG.POR_INTERNET` | `amenaza_digital/hecho` — ¿Qué tipo de mensajes recibió? |
| `n-s6-amenazas_mensajes-03` | ¿Conoce el número desde el que le escribieron? | `Q.DIG.NUMERO_CONOCE` | `amenaza_digital/hecho` — ¿Qué tipo de mensajes recibió? |
| `n-s6-amenazas_mensajes-04` | ¿Guardó los mensajes? | `Q.DIG.GUARDO` | `amenaza_digital/hecho` — ¿Qué tipo de mensajes recibió? |
| `n-s6-amenazas_mensajes-07` | ¿Son uno o varios números? | `Q.DIG.CANT_NUMEROS` | `amenaza_digital/hecho` — ¿Qué tipo de mensajes recibió? |
| `n-s6-amenazas_mensajes-08` | ¿Puede mostrar el celular ahora? | `Q.DIG.MOSTRAR` | `amenaza_digital/hecho` — ¿Qué tipo de mensajes recibió? |
| `n-s6-engaño_dinero_y_t-01` | ¿Entregó o envió dinero? | `Q.DIN.ENTREGO` | `engano_dinero/hecho` — ¿Cómo ocurrió el engaño con el dinero? |
| `n-s6-engaño_dinero_y_t-03` | ¿Lo hizo mediante un banco? | `Q.DIN.POR_BANCO` | `engano_dinero/hecho` — ¿Cómo ocurrió el engaño con el dinero? |
| `n-s6-engaño_dinero_y_t-04` | ¿Tiene factura o papel del banco? | `Q.DIN.COMPROBANTE` | `engano_dinero/hecho` — ¿Cómo ocurrió el engaño con el dinero? |
| `n-s6-engaño_dinero_y_t-05` | ¿Conoce el nombre de la persona? | `Q.DIN.RECEPTOR_NOMBRE` | `engano_dinero/hecho` — ¿Cómo ocurrió el engaño con el dinero? |
| `n-s6-engaño_dinero_y_t-06` | ¿Tiene su número de celular? | `Q.DIN.RECEPTOR_NUMERO` | `engano_dinero/hecho` — ¿Cómo ocurrió el engaño con el dinero? |
| `n-s6-engaño_dinero_y_t-07` | ¿Se comunicaron por internet? | `Q.DIN.INTERNET` | `engano_dinero/hecho` — ¿Cómo ocurrió el engaño con el dinero? |
| `n-s6-engaño_dinero_y_t-08` | ¿Conserva toda la conversación? | `Q.DIN.CHAT` | `engano_dinero/hecho` — ¿Cómo ocurrió el engaño con el dinero? |
| `n-s6-testigos_fotos_v-01` | ¿Hay algún testigo? | `Q.TES.EXISTE` | `otro/relato` — ¿Qué presenció o desea declarar? |
| `n-s6-testigos_fotos_v-02` | ¿Cuántos testigos hay? | `Q.TES.CANTIDAD` | `otro/relato` — ¿Qué presenció o desea declarar? |
| `n-s6-testigos_fotos_v-03` | ¿El testigo vio todo? | `Q.TES.VIO_TODO` | `otro/relato` — ¿Qué presenció o desea declarar? |
| `n-s6-testigos_fotos_v-04` | ¿Puede traer al testigo? | `Q.TES.TRAER` | `otro/relato` — ¿Qué presenció o desea declarar? |
| `n-s6-testigos_fotos_v-05` | ¿Tiene fotografías? | `Q.EVI.FOTOS` | `otro/relato` — ¿Qué presenció o desea declarar? |
| `n-s6-testigos_fotos_v-06` | ¿Tiene video? | `Q.EVI.VIDEO` | `otro/relato` — ¿Qué presenció o desea declarar? |
| `n-s6-testigos_fotos_v-07` | ¿Puede mostrarlo ahora? | `Q.EVI.MOSTRAR_AHORA` | `otro/relato` — ¿Qué presenció o desea declarar? |
| `n-s6-testigos_fotos_v-08` | ¿Tiene un certificado? | `Q.EVI.CERTIFICADO` | `otro/relato` — ¿Qué presenció o desea declarar? |
| `n-s6-testigos_fotos_v-09` | ¿Tiene una resolución o papel previo? | `Q.EVI.RESOLUCION_PREVIA` | `otro/relato` — ¿Qué presenció o desea declarar? |
| `n-s6-testigos_fotos_v-10` | ¿Desea presentar estos elementos? | `Q.EVI.PRESENTAR` | `otro/relato` — ¿Qué presenció o desea declarar? |
| `n-s6-seguimiento_prelim-01` | ¿Vino a consultar el estado de su caso? | `Q.SEG.ESTADO_CASO` | `seguimiento/tramite` — ¿Qué gestión o trámite viene a consultar? |
| `n-s6-seguimiento_prelim-02` | ¿Tiene el número de referencia? | `Q.SEG.NUM_REFERENCIA` | `seguimiento/tramite` — ¿Qué gestión o trámite viene a consultar? |
| `n-s6-seguimiento_prelim-03` | ¿Cuándo presentó la denuncia? | `Q.SEG.FECHA_DENUNCIA` | `seguimiento/tiempo` — ¿Para cuándo está programada la actuación? |
| `n-s6-seguimiento_prelim-04` | ¿Quiere hablar con el policía encargado? | `Q.SEG.HABLAR_POLICIA` | `seguimiento/institucion_autoridad` — ¿Con qué autoridad o institución debe coordinar? |
| `n-s6-seguimiento_prelim-05` | ¿Necesita hablar con un abogado? | `Q.SEG.HABLAR_ABOGADO` | `seguimiento/institucion_autoridad` — ¿Con qué autoridad o institución debe coordinar? |
| `n-s6-seguimiento_prelim-06` | ¿Necesita defensa pública gratuita? | `Q.SEG.DEFENSA_PUBLICA` | `seguimiento/institucion_autoridad` — ¿Con qué autoridad o institución debe coordinar? |
| `n-s6-seguimiento_prelim-07` | ¿Necesita saber dónde está la Fiscalía? | `Q.SEG.DONDE_FISCALIA` | `seguimiento/institucion_autoridad` — ¿Con qué autoridad o institución debe coordinar? |
| `n-s6-seguimiento_prelim-08` | ¿Recibió un papel de convocatoria? | `Q.SEG.CITACION` | `seguimiento/tramite` — ¿Qué gestión o trámite viene a consultar? |
| `n-s6-seguimiento_prelim-09` | ¿Tiene que volver otro día? | `Q.SEG.RETORNO` | `seguimiento/tramite` — ¿Qué gestión o trámite viene a consultar? |
| `n-s6-seguimiento_prelim-10` | ¿Prefiere que le avisemos por escrito? | `Q.ID.AVISO` | `seguimiento/tramite` — ¿Qué gestión o trámite viene a consultar? |
| `n-s6-interaccion_con_fi-01` | ¿Necesita hablar con el fiscal? | `Q.SEG.HABLAR_FISCAL` | `seguimiento/institucion_autoridad` — ¿Con qué autoridad o institución debe coordinar? |
| `n-s6-interaccion_con_fi-02` | ¿Le indicaron ir a la Fiscalía? | `Q.SEG.DERIVACION_FISCALIA` | `seguimiento/institucion_autoridad` — ¿Con qué autoridad o institución debe coordinar? |
| `n-s6-interaccion_con_fi-03` | ¿Recibió una resolución? | `Q.SEG.RESOLUCION` | `seguimiento/tramite` — ¿Qué gestión o trámite viene a consultar? |
| `n-s6-interaccion_con_fi-04` | ¿Debe presentarse ante un juez? | `Q.SEG.JUEZ` | `seguimiento/institucion_autoridad` — ¿Con qué autoridad o institución debe coordinar? |
| `n-s6-interaccion_con_fi-05` | ¿Sabe dónde está el Órgano Judicial? | `Q.SEG.ORGANO_JUDICIAL` | `seguimiento/tramite` — ¿Qué gestión o trámite viene a consultar? |
| `n-s6-interaccion_con_fi-06` | ¿Necesita intérprete para esa reunión? | `Q.SEG.INTERPRETE_REUNION` | `seguimiento/institucion_autoridad` — ¿Con qué autoridad o institución debe coordinar? |
| `n-s6-interaccion_con_fi-07` | ¿Quiere leer el papel antes de escribir su nombre? | `Q.SEG.LEER_ANTES_FIRMAR` | `seguimiento/tramite` — ¿Qué gestión o trámite viene a consultar? |
| `n-s6-interaccion_con_fi-08` | ¿Está de acuerdo con lo escrito? | `Q.SEG.CONFORMIDAD` | `seguimiento/tramite` — ¿Qué gestión o trámite viene a consultar? |
