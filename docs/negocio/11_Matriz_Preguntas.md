# Matriz maestra de preguntas

Generado por `tool/build_question_matrix.py` desde `config/banco_preguntas.json` y `config/acepciones.json`. **No editar a mano.**

Es el contrato que implementan la app (`lib/core/domain/guided/`) y la Lambda (`aws/guided_composer.py`). `test/guided/banco_aceptacion_test.dart` recorre todas las preguntas y todas sus opciones sobre el código real.

## Totales

| Qué | Cantidad |
|---|---:|
| Preguntas del banco | 143 |
| Recorridos (uno por contexto) | 8 |
| Opciones de respuesta | 528 |
| Enunciados del funcionario con pregunta asignada | 98 |

Leyenda: `[GLOSAS]` tarjetas del catálogo; `⟨editor⟩` valor escrito que se conserva literal; *(sin seña)* opción de texto sin glosa; *salida* = No sé / No recuerdo / Ninguno.

## Recorrido `denuncia_robo` — Robo, pérdida o daño

| # | Pregunta | Se muestra si | Obligatoria | Respuestas → frase |
|---|---|---|---|---|
| 1 | `Q.HEC.QUE_OCURRIO` ¿Qué ocurrió? | siempre | sí | Me robaron [ROBAR] → «Me robaron {Q.ROB.QUE\|algo}.»<br>Me falta algo (lo perdí o no sé) [PERDER] → (sin frase)<br>Dañaron algo mío [DAÑAR] → «Dañaron {Q.DAN.QUE\|algo mío}.»<br>Alguien escapó [ESCAPAR] → (sin frase) |
| 2 | `Q.ROB.QUE` ¿Qué le robaron? | Q.HEC.QUE_OCURRIO ∈ {robar} | no | Celular [CELULAR] → «el celular»<br>Dinero [BILLETES] ⟨monto⟩ → «{moneda} {monto} / sin valor: «dinero»»<br>Mochila [MOCHILA] → «la mochila»<br>Bolsa [BOLSA] → «la bolsa»<br>Chamarra [CHAMARRA] → «la chamarra»<br>Gorra [GORRA] → «la gorra»<br>Lentes [LENTES] → «los lentes»<br>Carnet de identidad [PAPEL · IDENTIDAD] → «mi carnet de identidad»<br>Un papel (no sé cómo se llama) [PAPEL] → «{Q.DOC.ACLARAR\|un papel}»<br>Otro objeto (escribir) ⟨texto_detalle⟩ → ««{texto}»»<br>No sé [NO_SABER] *salida* → «algo que no sé precisar» |
| 3 | `Q.DOC.ACLARAR` ¿Qué papel es? | Q.ROB.QUE ∈ {papel} | sí | Comprobante del banco [PAPEL · BANCO] → «el comprobante del banco»<br>Citación [PAPEL · CONVOCAR] → «una citación»<br>Resolución [RESOLUCIÓN] → «una resolución»<br>Certificado [CERTIFICADO] → «un certificado»<br>Fotocopia [FOTOCOPIA] → «una fotocopia»<br>Factura [FACTURA] → «una factura»<br>Otro (escribir cómo se llama) ⟨texto_detalle⟩ → «un documento: «{texto}»»<br>No sé [NO_SABER] *salida* → «un papel que no sé qué documento es» |
| 4 | `Q.FALTA.QUE` ¿Qué le falta? | Q.HEC.QUE_OCURRIO ∈ {perder} | no | Celular [CELULAR] → «el celular»<br>Dinero [BILLETES] ⟨monto⟩ → «{moneda} {monto} / sin valor: «dinero»»<br>Mochila [MOCHILA] → «la mochila»<br>Bolsa [BOLSA] → «la bolsa»<br>Chamarra [CHAMARRA] → «la chamarra»<br>Gorra [GORRA] → «la gorra»<br>Lentes [LENTES] → «los lentes»<br>Carnet de identidad [PAPEL · IDENTIDAD] → «mi carnet de identidad»<br>Un papel (no sé cómo se llama) [PAPEL] → «{Q.DOC.ACLARAR\|un papel}»<br>Otro objeto (escribir) ⟨texto_detalle⟩ → ««{texto}»»<br>No sé [NO_SABER] *salida* → «algo que no sé precisar» |
| 5 | `Q.HEC.PERDIDA_TIPO` ¿Lo perdió usted o cree que se lo quitaron? | Q.HEC.QUE_OCURRIO ∈ {perder} | sí | Lo perdí [PERDER] → «Perdí {Q.FALTA.QUE\|algo}.»<br>Creo que me lo robaron [ROBAR] → «Me falta {Q.FALTA.QUE\|algo}; creo que fue un robo, pero no estoy seguro.»<br>No sé [NO_SABER] *salida* → «Me falta {Q.FALTA.QUE\|algo} y no sé si fue una pérdida o un robo.» |
| 6 | `Q.DAN.QUE` ¿Qué dañaron? | Q.HEC.QUE_OCURRIO ∈ {danar} | no | Una puerta [PUERTA] → «la puerta»<br>Celular [CELULAR] → «el celular»<br>Mi casa [CASA] → «mi casa»<br>Mi tienda [TIENDA] → «mi tienda»<br>Otra cosa (escribir) ⟨texto_detalle⟩ → ««{texto}»»<br>No sé [NO_SABER] *salida* → «algo mío» |
| 7 | `Q.HEC.ESCAPE_ACTOR` ¿Quién escapó? | Q.HEC.QUE_OCURRIO ∈ {escapar} | sí | Yo logré escapar [YO · ESCAPAR] → «Logré escapar.»<br>La persona que me robó [LADRÓN · ESCAPAR] → «La persona que me robó escapó.»<br>Otra persona [ÉL · ESCAPAR] → «Otra persona escapó.»<br>No sé [NO_SABER] *salida* → «Alguien escapó, pero no sé quién.» |
| 8 | `Q.TIE.CUANDO` ¿Cuándo ocurrió? | siempre | no | Ahora mismo [AHORA] → «hace un momento»<br>Hoy [HOY] → «hoy»<br>Ayer [AYER] → «ayer»<br>Anteayer [ANTEAYER] → «anteayer»<br>Hace … minutos [MINUTO] ⟨entero⟩ → «hace {n} minutos»<br>Hace … horas [HORA] ⟨entero⟩ → «hace {n} horas»<br>Hace … días [DÍA] ⟨entero⟩ → «hace {n} días»<br>Hace … semanas [SEMANA] ⟨entero⟩ → «hace {n} semanas»<br>Hace … meses [MES] ⟨entero⟩ → «hace {n} meses»<br>Por la tarde [TARDE] → «por la tarde»<br>Temprano [TEMPRANO] → «temprano»<br>No recuerdo [RECORDAR · NO] *salida* → «No recuerdo cuándo ocurrió.» |
| 9 | `Q.LUG.DONDE` ¿Dónde ocurrió? | siempre | no | En la calle [CALLE] ⟨lugar_literal⟩ → «Ocurrió en la calle{?nombre}. / sin valor: «Ocurrió en la calle.»»<br>En una avenida [AVENIDA] ⟨lugar_literal⟩ → «Ocurrió en la avenida{?nombre}. / sin valor: «Ocurrió en la avenida.»»<br>En una plaza [PLAZA] ⟨lugar_literal⟩ → «Ocurrió en la plaza{?nombre}. / sin valor: «Ocurrió en la plaza.»»<br>En un mercado [MERCADO] ⟨lugar_literal⟩ → «Ocurrió en el mercado{?nombre}. / sin valor: «Ocurrió en el mercado.»»<br>En un barrio [BARRIO] ⟨lugar_literal⟩ → «Ocurrió en el barrio{?nombre}. / sin valor: «Ocurrió en el barrio.»»<br>En una tienda [TIENDA] ⟨lugar_literal⟩ → «Ocurrió en una tienda{?nombre}. / sin valor: «Ocurrió en una tienda.»»<br>En mi casa [CASA] → «Ocurrió en mi casa.»<br>Dentro de un micro [MICRO] → «Ocurrió dentro de un micro.»<br>Dentro de un trufi [TRUFI] → «Ocurrió dentro de un trufi.»<br>Otro lugar (escribir) ⟨texto_detalle⟩ → «Ocurrió en «{texto}».»<br>No sé [NO_SABER] *salida* → «No sé exactamente dónde ocurrió.» |
| 10 | `Q.LUG.RELACION` ¿Fue cerca de algún lugar que conozca? | Q.LUG.DONDE ∈ {afirmado} | no | Cerca de… [CERCA] ⟨referencia⟩ → «Fue cerca de este lugar: «{referencia}».»<br>Al lado de… [AL_LADO] ⟨referencia⟩ → «Fue al lado de este lugar: «{referencia}».»<br>Lejos de… [LEJOS] ⟨referencia⟩ → «Fue lejos de este lugar: «{referencia}».» |
| 11 | `Q.PER.CONOCE` ¿Conoce a la persona involucrada? | Q.HEC.QUE_OCURRIO ∈ {robar, danar} | no | Sí [SÍ] → «Sí, conozco a esa persona.»<br>No [NO] → «No conozco a esa persona.»<br>No sé [NO_SABER] → «No sé si la conozco.» |
| 12 | `Q.PER.VINCULO` ¿Qué relación tiene con esa persona? | Q.PER.CONOCE ∈ {si} | no | Mi pareja [PAREJA] → «Es mi pareja.»<br>Mi expareja [PAREJA · PASADO] → «Es mi expareja.»<br>Mi esposa [ESPOSA] → «Es mi esposa.»<br>Mi hermano [HERMANO] → «Es mi hermano.»<br>Mi hermana [HERMANA] → «Es mi hermana.»<br>Un pariente [PARIENTE] → «Es un pariente.»<br>Un amigo [AMIGO] → «Es un amigo.»<br>Un conocido [CONOCER] → «Es un conocido.»<br>Otra relación (escribir) ⟨texto_detalle⟩ → «Es {texto}.» |
| 13 | `Q.PER.NOMBRE_TERCERO` ¿Sabe cómo se llama esa persona? | Q.PER.CONOCE ∈ {si} | no | Escribir su nombre ⟨texto_nombre⟩ → «Se llama {nombre}.»<br>No sé [NO_SABER] *salida* → «No sé cómo se llama.» |
| 14 | `Q.PER.DESCRIBIR` ¿Quiere describir a la persona? | Q.HEC.QUE_OCURRIO ∈ {robar, danar} | no | Sí [SÍ] → (sin frase)<br>No [NO] → (sin frase) |
| 15 | `Q.PER.DESC.SEXO` ¿Era un hombre o una mujer? | Q.PER.DESCRIBIR ∈ {si} | no | Un hombre [HOMBRE] → «Era un hombre.»<br>Una mujer [MUJER] → «Era una mujer.»<br>No sé [NO_SABER] *salida* → «No sé si era hombre o mujer.» |
| 16 | `Q.PER.DESC.EDAD` ¿Qué edad aproximada tenía? | Q.PER.DESCRIBIR ∈ {si} | no | Escribir la edad ⟨edad⟩ → «Tenía {aprox}{n} años.»<br>Era joven [JOVEN] → «Era una persona joven.»<br>Era adulta [ADULTO] → «Era una persona adulta.»<br>No recuerdo [RECORDAR · NO] *salida* → «No recuerdo su edad.» |
| 17 | `Q.PER.DESC.ESTATURA` ¿Era alto o bajo? | Q.PER.DESCRIBIR ∈ {si} | no | Alta [ALTO] → «Era una persona alta.»<br>Baja [BAJO] → «Era una persona baja.»<br>No sé [NO_SABER] *salida* → «No recuerdo su estatura.» |
| 18 | `Q.PER.DESC.CONTEXTURA` ¿Era delgado o de contextura gruesa? | Q.PER.DESCRIBIR ∈ {si} | no | Delgada [FLACO] → «Era una persona delgada.»<br>De contextura gruesa [GORDO] → «Era una persona de contextura gruesa.»<br>No sé [NO_SABER] *salida* → «No recuerdo su contextura.» |
| 19 | `Q.PER.DESC.ROPA` ¿Qué ropa llevaba? | Q.PER.DESCRIBIR ∈ {si} | no | Polera [POLERA] → «una polera»<br>Pantalón [PANTALÓN] → «un pantalón»<br>Chamarra [CHAMARRA] → «una chamarra»<br>Gorra [GORRA] → «una gorra»<br>Mochila [MOCHILA] → «una mochila»<br>Otra prenda o color (escribir) ⟨texto_detalle⟩ → ««{texto}»»<br>No recuerdo [RECORDAR · NO] *salida* → «No recuerdo su ropa.» |
| 20 | `Q.TES.EXISTE` ¿Hay testigos? | siempre | no | Sí [SÍ] → «Sí, hay {Q.TES.CANTIDAD\|testigos}.»<br>No [NO] → «No hay testigos.»<br>No sé [NO_SABER] → «No sé si hay testigos.» |
| 21 | `Q.TES.CANTIDAD` ¿Cuántos testigos hay? | Q.TES.EXISTE ∈ {si} | no | Escribir cuántos ⟨entero⟩ → «{n} testigos»<br>No sé [NO_SABER] *salida* → «testigos, pero no sé cuántos» |
| 22 | `Q.EVI.FACTURA` ¿Tiene la factura del celular? | Q.ROB.QUE ∈ {celular} | no | Sí [SÍ] → «Sí, tengo la factura.»<br>No [NO] → «No tengo la factura.»<br>No sé [NO_SABER] → «No sé si tengo la factura.» |
| 23 | `Q.EVI.TRAE_COPIA` ¿La tiene aquí con usted? | Q.EVI.FACTURA ∈ {si} | no | Sí [SÍ] → «La tengo aquí.»<br>No [NO] → «No la tengo aquí.»<br>No sé [NO_SABER] → «No sé si la traje.» |
| 24 | `Q.EVI.QUE_TIENE` ¿Tiene fotos, video u otra cosa que pueda mostrar? | siempre | no | Sí [SÍ] → «Sí, tengo {Q.EVI.TIPOS\|algo que puedo mostrar}.»<br>No [NO] → «No tengo fotos, video ni otra cosa para mostrar.»<br>No sé [NO_SABER] → «No sé si tengo algo para mostrar.» |
| 25 | `Q.EVI.TIPOS` ¿Qué tiene? | Q.EVI.QUE_TIENE ∈ {si} | no | Fotos [FOTOS] → «fotos»<br>Video [VIDEO] → «un video»<br>Certificado [CERTIFICADO] → «un certificado»<br>Otra cosa (escribir) ⟨texto_detalle⟩ → ««{texto}»» |
| 26 | `Q.DEN.INTENCION` ¿Desea presentar una denuncia? | siempre | no | Sí [SÍ] → «Sí, quiero presentar una denuncia.»<br>No [NO] → «Por ahora no quiero presentar una denuncia.»<br>No sé [NO_SABER] → «Todavía no sé si quiero presentar una denuncia.» |
| 27 | `Q.DEN.AUTORIDAD` ¿Ante qué institución quiere presentarla? | Q.DEN.INTENCION ∈ {si}; sin perfil institucional | no | Policía [POLICÍA] → «Quiero presentarla ante la Policía.»<br>FELCC [FELCC] → «Quiero presentarla ante la FELCC.»<br>FELCV [FELCV] → «Quiero presentarla ante la FELCV.»<br>Fiscalía [FISCALIA] → «Quiero presentarla ante la Fiscalía.»<br>No sé [NO_SABER] *salida* → «No sé ante qué institución presentarla.» |

## Recorrido `violencia` — Violencia o agresión

| # | Pregunta | Se muestra si | Obligatoria | Respuestas → frase |
|---|---|---|---|---|
| 1 | `Q.VIO.TIPO` ¿Qué le hicieron? | siempre | sí | Me pegaron [PEGAR] → «Me pegaron.»<br>Me maltrataron [MALTRATAR] → «Me maltrataron.»<br>Me amenazaron [AMENAZAR] → «Me amenazaron.»<br>Me gritaron [GRITAR] → «Me gritaron.»<br>Abusaron de mí [ABUSAR] → «Abusaron de mí.»<br>Sufrí violencia [VIOLENCIA] → «Sufrí violencia.»<br>Dañaron mis cosas [DAÑAR] → «Dañaron mis cosas.» |
| 2 | `Q.RIE.AUXILIO` ¿Necesita auxilio ahora? | siempre | no | Sí [SÍ] → «Sí, necesito auxilio ahora.»<br>No [NO] → «No necesito auxilio ahora.»<br>No sé [NO_SABER] → «No lo sé.» |
| 3 | `Q.VIO.AGRESOR` ¿Quién le agredió? | siempre | no | Alguien que conozco [CONOCER] → «Fue alguien que conozco.»<br>Un hombre que no conozco [HOMBRE] → «Fue un hombre que no conozco.»<br>Una mujer que no conozco [MUJER] → «Fue una mujer que no conozco.»<br>No sé [NO_SABER] *salida* → «No sé quién fue.» |
| 4 | `Q.PER.VINCULO` ¿Qué relación tiene con esa persona? | Q.VIO.AGRESOR ∈ {conoce} | no | Mi pareja [PAREJA] → «Es mi pareja.»<br>Mi expareja [PAREJA · PASADO] → «Es mi expareja.»<br>Mi esposa [ESPOSA] → «Es mi esposa.»<br>Mi hermano [HERMANO] → «Es mi hermano.»<br>Mi hermana [HERMANA] → «Es mi hermana.»<br>Un pariente [PARIENTE] → «Es un pariente.»<br>Un amigo [AMIGO] → «Es un amigo.»<br>Un conocido [CONOCER] → «Es un conocido.»<br>Otra relación (escribir) ⟨texto_detalle⟩ → «Es {texto}.» |
| 5 | `Q.PER.NOMBRE_TERCERO` ¿Sabe cómo se llama esa persona? | Q.VIO.AGRESOR ∈ {conoce} | no | Escribir su nombre ⟨texto_nombre⟩ → «Se llama {nombre}.»<br>No sé [NO_SABER] *salida* → «No sé cómo se llama.» |
| 6 | `Q.TIE.CUANDO` ¿Cuándo ocurrió? | siempre | no | Ahora mismo [AHORA] → «hace un momento»<br>Hoy [HOY] → «hoy»<br>Ayer [AYER] → «ayer»<br>Anteayer [ANTEAYER] → «anteayer»<br>Hace … minutos [MINUTO] ⟨entero⟩ → «hace {n} minutos»<br>Hace … horas [HORA] ⟨entero⟩ → «hace {n} horas»<br>Hace … días [DÍA] ⟨entero⟩ → «hace {n} días»<br>Hace … semanas [SEMANA] ⟨entero⟩ → «hace {n} semanas»<br>Hace … meses [MES] ⟨entero⟩ → «hace {n} meses»<br>Por la tarde [TARDE] → «por la tarde»<br>Temprano [TEMPRANO] → «temprano»<br>No recuerdo [RECORDAR · NO] *salida* → «No recuerdo cuándo ocurrió.» |
| 7 | `Q.VIO.FRECUENCIA` ¿Es la primera vez o pasa seguido? | siempre | no | Es la primera vez [PRIMERA_VEZ] → «Es la primera vez.»<br>Pasa siempre [SIEMPRE] → «Pasa siempre.»<br>Pasa cada día [CADA_DÍA] → «Pasa todos los días.»<br>No sé [NO_SABER] *salida* → «No sé decirlo.» |
| 8 | `Q.LUG.DONDE` ¿Dónde ocurrió? | siempre | no | En la calle [CALLE] ⟨lugar_literal⟩ → «Ocurrió en la calle{?nombre}. / sin valor: «Ocurrió en la calle.»»<br>En una avenida [AVENIDA] ⟨lugar_literal⟩ → «Ocurrió en la avenida{?nombre}. / sin valor: «Ocurrió en la avenida.»»<br>En una plaza [PLAZA] ⟨lugar_literal⟩ → «Ocurrió en la plaza{?nombre}. / sin valor: «Ocurrió en la plaza.»»<br>En un mercado [MERCADO] ⟨lugar_literal⟩ → «Ocurrió en el mercado{?nombre}. / sin valor: «Ocurrió en el mercado.»»<br>En un barrio [BARRIO] ⟨lugar_literal⟩ → «Ocurrió en el barrio{?nombre}. / sin valor: «Ocurrió en el barrio.»»<br>En una tienda [TIENDA] ⟨lugar_literal⟩ → «Ocurrió en una tienda{?nombre}. / sin valor: «Ocurrió en una tienda.»»<br>En mi casa [CASA] → «Ocurrió en mi casa.»<br>Dentro de un micro [MICRO] → «Ocurrió dentro de un micro.»<br>Dentro de un trufi [TRUFI] → «Ocurrió dentro de un trufi.»<br>Otro lugar (escribir) ⟨texto_detalle⟩ → «Ocurrió en «{texto}».»<br>No sé [NO_SABER] *salida* → «No sé exactamente dónde ocurrió.» |
| 9 | `Q.SAL.HERIDO` ¿Está herido? | Q.VIO.TIPO ∈ {pegar, maltratar, abusar, violencia} | no | Sí [SÍ] → «Sí, estoy herido.»<br>No [NO] → «No estoy herido.»<br>No sé [NO_SABER] → «No estoy seguro de estar herido.» |
| 10 | `Q.SAL.PARTE` ¿Dónde tiene la herida? | Q.SAL.HERIDO ∈ {si} | no | En el brazo [BRAZO] → «Tengo una herida en el brazo.»<br>Otra parte (escribir) ⟨texto_detalle⟩ → «Tengo una herida en {texto}.» |
| 11 | `Q.SAL.ASISTENCIA` ¿Necesita asistencia médica? | Q.SAL.HERIDO ∈ {si} | no | Sí [SÍ] → «Sí, necesito atención médica.»<br>No [NO] → «No necesito atención médica.»<br>No sé [NO_SABER] → «No sé si necesito atención médica.» |
| 12 | `Q.RIE.MIEDO_CASA` ¿Tiene miedo de volver a su casa? | siempre | no | Sí [SÍ] → «Sí, tengo miedo de volver a mi casa.»<br>No [NO] → «No tengo miedo de volver a mi casa.»<br>No sé [NO_SABER] → «No lo sé.» |
| 13 | `Q.RIE.PIDE_PROTECCION` ¿Necesita protección? | siempre | no | Sí [SÍ] → «Sí, necesito protección.»<br>No [NO] → «No necesito protección.»<br>No sé [NO_SABER] → «No lo sé.» |
| 14 | `Q.RIE.PROTECCION_OTROS` ¿Hay niños u otras personas que necesiten protección? | siempre | no | Sí [SÍ] → «Sí, hay otras personas que necesitan protección.»<br>No [NO] → «No hay otras personas en riesgo.»<br>No sé [NO_SABER] → «No lo sé.» |
| 15 | `Q.RIE.QUIENES` ¿Quiénes necesitan protección? | Q.RIE.PROTECCION_OTROS ∈ {si} | no | Mi hijo [HIJO] → «mi hijo»<br>Mi hija [HIJA] → «mi hija»<br>Otra persona (escribir) ⟨texto_detalle⟩ → ««{texto}»» |
| 16 | `Q.EVI.QUE_TIENE` ¿Tiene fotos, video u otra cosa que pueda mostrar? | siempre | no | Sí [SÍ] → «Sí, tengo {Q.EVI.TIPOS\|algo que puedo mostrar}.»<br>No [NO] → «No tengo fotos, video ni otra cosa para mostrar.»<br>No sé [NO_SABER] → «No sé si tengo algo para mostrar.» |
| 17 | `Q.EVI.TIPOS` ¿Qué tiene? | Q.EVI.QUE_TIENE ∈ {si} | no | Fotos [FOTOS] → «fotos»<br>Video [VIDEO] → «un video»<br>Certificado [CERTIFICADO] → «un certificado»<br>Otra cosa (escribir) ⟨texto_detalle⟩ → ««{texto}»» |
| 18 | `Q.VIO.ASISTENCIA_ESPECIALIZADA` ¿Desea asistencia especializada? | siempre | no | Sí [SÍ] → «Sí, quiero asistencia.»<br>No [NO] → «Por ahora no quiero asistencia.»<br>No sé [NO_SABER] → «Todavía no lo sé.» |
| 19 | `Q.APO.TIPO` ¿Qué apoyo necesita? | Q.VIO.ASISTENCIA_ESPECIALIZADA ∈ {si} | no | Un abogado [ABOGADO] → «Necesito un abogado.»<br>Un abogado gratuito [ABOGADO · GRATIS] → «Necesito un abogado gratuito.»<br>Asistencia a la víctima (SEPDAVI) [ASISTENCIA · SEPDAVI] → «Quiero asistencia de SEPDAVI.»<br>FELCV [FELCV] → «Quiero acudir a la FELCV.»<br>No sé [NO_SABER] *salida* → «No sé qué apoyo necesito.» |
| 20 | `Q.DEN.INTENCION` ¿Desea presentar una denuncia? | siempre | no | Sí [SÍ] → «Sí, quiero presentar una denuncia.»<br>No [NO] → «Por ahora no quiero presentar una denuncia.»<br>No sé [NO_SABER] → «Todavía no sé si quiero presentar una denuncia.» |
| 21 | `Q.DEN.AUTORIDAD` ¿Ante qué institución quiere presentarla? | Q.DEN.INTENCION ∈ {si}; sin perfil institucional | no | Policía [POLICÍA] → «Quiero presentarla ante la Policía.»<br>FELCC [FELCC] → «Quiero presentarla ante la FELCC.»<br>FELCV [FELCV] → «Quiero presentarla ante la FELCV.»<br>Fiscalía [FISCALIA] → «Quiero presentarla ante la Fiscalía.»<br>No sé [NO_SABER] *salida* → «No sé ante qué institución presentarla.» |

## Recorrido `amenaza_digital` — Amenazas por mensajes

| # | Pregunta | Se muestra si | Obligatoria | Respuestas → frase |
|---|---|---|---|---|
| 1 | `Q.DIG.CONTENIDO` ¿Qué decían los mensajes? | siempre | sí | Me amenazaban [AMENAZAR] → «Recibí mensajes con amenazas.»<br>Otra cosa (escribir un resumen) ⟨texto_detalle⟩ → «Recibí mensajes que decían: «{texto}».» |
| 2 | `Q.DIG.CANAL` ¿Por dónde le llegaron los mensajes? | siempre | no | Por celular [CELULAR] → «por celular»<br>Por internet [INTERNET] → «por internet»<br>Otra aplicación (escribir) ⟨texto_detalle⟩ → «por «{texto}»»<br>No sé [NO_SABER] *salida* → «No sé por dónde llegaron los mensajes.» |
| 3 | `Q.DIG.REMITENTE` ¿Quién le envió los mensajes? | siempre | no | Sé quién es [CONOCER] → «Sé quién me envía los mensajes.»<br>Solo conozco el número ⟨telefono⟩ → «No conozco su nombre; el número que aparece es {telefono}.»<br>Un hombre (no sé quién) [HOMBRE] → «Me los envía un hombre; no sé quién es.»<br>Una mujer (no sé quién) [MUJER] → «Me los envía una mujer; no sé quién es.»<br>No sé [NO_SABER] *salida* → «No sé quién me envía los mensajes.» |
| 4 | `Q.PER.VINCULO` ¿Qué relación tiene con esa persona? | Q.DIG.REMITENTE ∈ {conoce} | no | Mi pareja [PAREJA] → «Es mi pareja.»<br>Mi expareja [PAREJA · PASADO] → «Es mi expareja.»<br>Mi esposa [ESPOSA] → «Es mi esposa.»<br>Mi hermano [HERMANO] → «Es mi hermano.»<br>Mi hermana [HERMANA] → «Es mi hermana.»<br>Un pariente [PARIENTE] → «Es un pariente.»<br>Un amigo [AMIGO] → «Es un amigo.»<br>Un conocido [CONOCER] → «Es un conocido.»<br>Otra relación (escribir) ⟨texto_detalle⟩ → «Es {texto}.» |
| 5 | `Q.PER.NOMBRE_TERCERO` ¿Sabe cómo se llama esa persona? | Q.DIG.REMITENTE ∈ {conoce} | no | Escribir su nombre ⟨texto_nombre⟩ → «Se llama {nombre}.»<br>No sé [NO_SABER] *salida* → «No sé cómo se llama.» |
| 6 | `Q.DIG.CONTINUA` ¿Sigue recibiendo mensajes? | siempre | no | Sí [SÍ] → «Sí, sigo recibiendo mensajes.»<br>No [NO] → «Ya no recibo mensajes.»<br>No sé [NO_SABER] → «No lo sé.» |
| 7 | `Q.DIG.GUARDO` ¿Guardó los mensajes? | siempre | no | Sí [SÍ] → «Sí, guardé los mensajes.»<br>No [NO] → «No guardé los mensajes.»<br>No sé [NO_SABER] → «No sé si se guardaron.»<br>Sí, todos [SÍ · TOTAL] → «Sí, guardé todos los mensajes.» |
| 8 | `Q.DIG.CAPTURAS` ¿Tiene fotos de la pantalla? | siempre | no | Sí [SÍ] → «Sí, tengo fotos de la pantalla.»<br>No [NO] → «No tengo fotos de la pantalla.»<br>No sé [NO_SABER] → «No sé si tengo fotos de la pantalla.» |
| 9 | `Q.DEN.INTENCION` ¿Desea presentar una denuncia? | siempre | no | Sí [SÍ] → «Sí, quiero presentar una denuncia.»<br>No [NO] → «Por ahora no quiero presentar una denuncia.»<br>No sé [NO_SABER] → «Todavía no sé si quiero presentar una denuncia.» |
| 10 | `Q.DEN.AUTORIDAD` ¿Ante qué institución quiere presentarla? | Q.DEN.INTENCION ∈ {si}; sin perfil institucional | no | Policía [POLICÍA] → «Quiero presentarla ante la Policía.»<br>FELCC [FELCC] → «Quiero presentarla ante la FELCC.»<br>FELCV [FELCV] → «Quiero presentarla ante la FELCV.»<br>Fiscalía [FISCALIA] → «Quiero presentarla ante la Fiscalía.»<br>No sé [NO_SABER] *salida* → «No sé ante qué institución presentarla.» |

## Recorrido `engano_dinero` — Engaño con dinero

| # | Pregunta | Se muestra si | Obligatoria | Respuestas → frase |
|---|---|---|---|---|
| 1 | `Q.DIN.MECANISMO` ¿Cómo entregó el dinero? | siempre | sí | En mano, en efectivo [DAR · BILLETES] → «Entregué {Q.DIN.MONTO\|dinero} en mano.»<br>Por un banco [BANCO · ENVIAR] → «Envié {Q.DIN.MONTO\|dinero} mediante un banco.»<br>Por internet [INTERNET · ENVIAR] → «Envié {Q.DIN.MONTO\|dinero} por internet.»<br>Desde el celular [CELULAR · ENVIAR] → «Envié {Q.DIN.MONTO\|dinero} desde el celular.»<br>Otra forma (escribir) ⟨texto_detalle⟩ → «Entregué {Q.DIN.MONTO\|dinero} de esta forma: «{texto}».»<br>No entregué dinero [NO] *salida* → «No entregué ni envié dinero.»<br>No recuerdo [RECORDAR · NO] *salida* → «No recuerdo cómo entregué el dinero.» |
| 2 | `Q.DIN.MONTO` ¿Cuánto dinero fue? | Q.DIN.MECANISMO ∈ {afirmado, desconocido} | no | Escribir el monto ⟨monto⟩ → «{moneda} {monto}»<br>No recuerdo [RECORDAR · NO] *salida* → «dinero» |
| 3 | `Q.DIN.RECEPTOR` ¿Quién recibió el dinero? | Q.DIN.MECANISMO ∈ {afirmado, desconocido} | no | Sé su nombre ⟨texto_nombre⟩ → «Recibió el dinero {nombre}.»<br>Solo tengo su número ⟨telefono⟩ → «No conozco su nombre; tengo su número: {telefono}.»<br>Un hombre (no sé quién) [HOMBRE] → «Lo recibió un hombre que no conozco.»<br>Una mujer (no sé quién) [MUJER] → «Lo recibió una mujer que no conozco.»<br>No sé [NO_SABER] *salida* → «No sé quién recibió el dinero.» |
| 4 | `Q.DIN.COMPROBANTE` ¿Tiene algún comprobante? | Q.DIN.MECANISMO ∈ {afirmado, desconocido} | no | Sí [SÍ] → «Sí, tengo {Q.DIN.COMPROBANTE_TIPO\|un comprobante}.»<br>No [NO] → «No tengo comprobante.»<br>No sé [NO_SABER] → «No sé si tengo comprobante.» |
| 5 | `Q.DIN.COMPROBANTE_TIPO` ¿Qué comprobante tiene? | Q.DIN.COMPROBANTE ∈ {si} | no | Comprobante del banco [PAPEL · BANCO] → «el comprobante del banco»<br>Factura [FACTURA] → «una factura»<br>Capturas en mi celular [FOTOS · CELULAR] → «capturas en mi celular»<br>Un papel (no sé cómo se llama) [PAPEL] → «{Q.DOC.ACLARAR\|un papel}» |
| 6 | `Q.DOC.ACLARAR` ¿Qué papel es? | Q.DIN.COMPROBANTE_TIPO ∈ {papel} | sí | Carnet de identidad [PAPEL · IDENTIDAD] → «mi carnet de identidad»<br>Citación [PAPEL · CONVOCAR] → «una citación»<br>Resolución [RESOLUCIÓN] → «una resolución»<br>Certificado [CERTIFICADO] → «un certificado»<br>Fotocopia [FOTOCOPIA] → «una fotocopia»<br>Otro (escribir cómo se llama) ⟨texto_detalle⟩ → «un documento: «{texto}»»<br>No sé [NO_SABER] *salida* → «un papel que no sé qué documento es» |
| 7 | `Q.DIN.CHAT` ¿Conserva toda la conversación? | siempre | no | Sí [SÍ] → «Sí, conservo toda la conversación.»<br>No [NO] → «No conservo la conversación.»<br>No sé [NO_SABER] → «No sé si la conservo.» |
| 8 | `Q.DIN.ENGANO` ¿Quiere decir que lo engañaron? | siempre | no | Sí, me engañaron [SÍ · ENGAÑAR] → «Me engañaron con dinero.»<br>Prefiero no decirlo así [NO] → (sin frase) |
| 9 | `Q.DEN.INTENCION` ¿Desea presentar una denuncia? | siempre | no | Sí [SÍ] → «Sí, quiero presentar una denuncia.»<br>No [NO] → «Por ahora no quiero presentar una denuncia.»<br>No sé [NO_SABER] → «Todavía no sé si quiero presentar una denuncia.» |
| 10 | `Q.DEN.AUTORIDAD` ¿Ante qué institución quiere presentarla? | Q.DEN.INTENCION ∈ {si}; sin perfil institucional | no | Policía [POLICÍA] → «Quiero presentarla ante la Policía.»<br>FELCC [FELCC] → «Quiero presentarla ante la FELCC.»<br>FELCV [FELCV] → «Quiero presentarla ante la FELCV.»<br>Fiscalía [FISCALIA] → «Quiero presentarla ante la Fiscalía.»<br>No sé [NO_SABER] *salida* → «No sé ante qué institución presentarla.» |

Orden de redacción: `Q.DIN.ENGANO` → `Q.DIN.MECANISMO` → `Q.DIN.MONTO` → `Q.DIN.RECEPTOR` → `Q.DIN.COMPROBANTE` → `Q.DIN.COMPROBANTE_TIPO` → `Q.DOC.ACLARAR` → `Q.DIN.CHAT` → `Q.DEN.INTENCION` → `Q.DEN.AUTORIDAD`.

## Recorrido `seguimiento` — Consultar trámite

| # | Pregunta | Se muestra si | Obligatoria | Respuestas → frase |
|---|---|---|---|---|
| 1 | `Q.SEG.MOTIVO` ¿Qué quiere consultar? | siempre | sí | El estado de mi caso [INVESTIGACIÓN · SABER · QUERER] → «Quiero saber cómo va la investigación de mi caso.»<br>Si la investigación continúa [INVESTIGACIÓN · CONTINUAR · SABER] → «Quiero saber si la investigación continúa.»<br>Cuándo debo volver [CUÁNDO · VOLVER] → «Quiero saber cuándo debo volver.»<br>Cuánto debo esperar [ESPERAR · CUÁNTOS] → «Quiero saber cuánto tiempo debo esperar.»<br>Una citación que recibí [PAPEL · CONVOCAR · RECIBIR] → «Recibí una citación y quiero consultar sobre ella.»<br>Una resolución que recibí [RESOLUCIÓN · RECIBIR] → «Recibí una resolución y quiero consultar sobre ella.»<br>Pedir una fotocopia [FOTOCOPIA · PEDIR] → «Quiero pedir una fotocopia.»<br>Hablar con alguien [HABLAR] → (sin frase)<br>Dónde queda una oficina [DÓNDE] → (sin frase)<br>Otra consulta (escribir) ⟨texto_detalle⟩ *(sin seña)* → «Quiero consultar esto: «{texto}».» |
| 2 | `I.PREG.HABLAR_CON` ¿Con quién quiere hablar? | Q.SEG.MOTIVO ∈ {hablar} | sí | Con el juez [JUEZ] → «¿Puedo hablar con el juez?»<br>Con un abogado [ABOGADO] → «¿Puedo hablar con un abogado?»<br>Con un intérprete [INTÉRPRETE] → «¿Aquí hay intérprete de LSB?»<br>Con el policía encargado [POLICÍA · HABLAR · PUEDO] → «¿Puedo hablar con el policía encargado?»<br>Con un oficial [OFICIAL] → «¿Puedo hablar con un oficial?»<br>Con la autoridad [AUTORIDAD] → «¿Puedo hablar con la autoridad?»<br>Con el asistente [ASISTENTE] → «¿Puedo hablar con el asistente?» |
| 3 | `I.PREG.DONDE_QUEDA` ¿Dónde queda…? | Q.SEG.MOTIVO ∈ {donde} | sí | La Fiscalía [FISCALIA · DÓNDE] → «¿Dónde está la Fiscalía?»<br>La FELCC [FELCC · DÓNDE] → «¿Dónde está la FELCC?»<br>La FELCV [FELCV · DÓNDE] → «¿Dónde está la FELCV?»<br>El juzgado [JUZGADO · DÓNDE] → «¿Dónde está el juzgado?»<br>El Órgano Judicial [ÓRGANO_JUDICIAL · DÓNDE] → «¿Dónde está el Órgano Judicial?»<br>SEPDAVI [SEPDAVI · DÓNDE] → «¿Dónde está SEPDAVI?»<br>SEPDEP [SEPDEP · DÓNDE] → «¿Dónde está SEPDEP?»<br>La Policía [POLICÍA · DÓNDE] → «¿Dónde está la Policía?»<br>La oficina [OFICINA · DÓNDE] → «¿Dónde está la oficina?» |
| 4 | `Q.SEG.FECHA_PROGRAMADA` ¿Para cuándo le dieron fecha? | Q.SEG.MOTIVO ∈ {citacion} | no | Hoy [HOY] → «Me dieron fecha para hoy.»<br>Mañana [MAÑANA] → «Me dieron fecha para mañana.»<br>La próxima semana [PRÓXIMO · SEMANA] → «Me dieron fecha para la próxima semana.»<br>Escribir la fecha [FECHA] ⟨texto_detalle⟩ → «Me dieron fecha para el {texto}.»<br>No sé [NO_SABER] *salida* → «No sé para cuándo es.» |
| 5 | `Q.SEG.NUM_REFERENCIA` ¿Tiene el número de referencia? | Q.SEG.MOTIVO ∈ {estado, continua, citacion, resolucion} | no | Sí [SÍ] ⟨documento_numero⟩ → «Sí, el número de referencia es {numero}. / sin valor: «Sí, tengo el número de referencia.»»<br>No [NO] → «No tengo el número de referencia.»<br>No sé [NO_SABER] → «No sé si lo tengo.» |
| 6 | `Q.SEG.AUTORIDAD` ¿Con qué institución es su trámite? | sin perfil institucional | no | Policía [POLICÍA] → «Mi trámite es con la Policía.»<br>FELCC [FELCC] → «Mi trámite es con la FELCC.»<br>FELCV [FELCV] → «Mi trámite es con la FELCV.»<br>Fiscalía [FISCALIA] → «Mi trámite es con la Fiscalía.»<br>Juzgado [JUZGADO] → «Mi trámite es con el juzgado.»<br>Órgano Judicial [ÓRGANO_JUDICIAL] → «Mi trámite es con el Órgano Judicial.»<br>SEPDAVI [SEPDAVI] → «Mi trámite es con SEPDAVI.»<br>SEPDEP [SEPDEP] → «Mi trámite es con SEPDEP.»<br>No sé [NO_SABER] *salida* → «No sé con qué institución es mi trámite.» |

## Recorrido `preguntas` — Preguntas

| # | Pregunta | Se muestra si | Obligatoria | Respuestas → frase |
|---|---|---|---|---|
| 1 | `I.PREG.ELEGIR` ¿Qué quieres preguntar? | siempre | sí | ¿Dónde…? [DÓNDE] → (sin frase)<br>¿Con quién puedo hablar? [QUIÉN] → (sin frase)<br>¿Cuándo…? [CUÁNDO] → (sin frase)<br>¿Cuánto tiempo…? [CUÁNTOS] → (sin frase)<br>Otra pregunta [QUÉ] → (sin frase) |
| 2 | `I.PREG.DONDE_QUEDA` ¿Dónde queda…? | I.PREG.ELEGIR ∈ {donde} | sí | La Fiscalía [FISCALIA · DÓNDE] → «¿Dónde está la Fiscalía?»<br>La FELCC [FELCC · DÓNDE] → «¿Dónde está la FELCC?»<br>La FELCV [FELCV · DÓNDE] → «¿Dónde está la FELCV?»<br>El juzgado [JUZGADO · DÓNDE] → «¿Dónde está el juzgado?»<br>El Órgano Judicial [ÓRGANO_JUDICIAL · DÓNDE] → «¿Dónde está el Órgano Judicial?»<br>SEPDAVI [SEPDAVI · DÓNDE] → «¿Dónde está SEPDAVI?»<br>SEPDEP [SEPDEP · DÓNDE] → «¿Dónde está SEPDEP?»<br>La Policía [POLICÍA · DÓNDE] → «¿Dónde está la Policía?»<br>La oficina [OFICINA · DÓNDE] → «¿Dónde está la oficina?» |
| 3 | `I.PREG.HABLAR_CON` ¿Con quién quiere hablar? | I.PREG.ELEGIR ∈ {hablar} | sí | Con el juez [JUEZ] → «¿Puedo hablar con el juez?»<br>Con un abogado [ABOGADO] → «¿Puedo hablar con un abogado?»<br>Con un intérprete [INTÉRPRETE] → «¿Aquí hay intérprete de LSB?»<br>Con el policía encargado [POLICÍA · HABLAR · PUEDO] → «¿Puedo hablar con el policía encargado?»<br>Con un oficial [OFICIAL] → «¿Puedo hablar con un oficial?»<br>Con la autoridad [AUTORIDAD] → «¿Puedo hablar con la autoridad?»<br>Con el asistente [ASISTENTE] → «¿Puedo hablar con el asistente?» |
| 4 | `I.PREG.CUANDO` ¿Qué quiere saber cuándo? | I.PREG.ELEGIR ∈ {cuando} | sí | Cuándo vuelvo [CUÁNDO · VOLVER] → «¿Cuándo debo volver?»<br>Cuándo me avisan [CUÁNDO · AVISAR] → «¿Cuándo me van a avisar?»<br>Cuánto tiempo espero [ESPERAR · CUÁNTOS] → «¿Cuánto tiempo debo esperar?» |
| 5 | `I.PREG.CUANTO` ¿Qué quiere saber cuánto? | I.PREG.ELEGIR ∈ {cuanto} | sí | Cuántos días espero [ESPERAR · DÍA · CUÁNTOS] → «¿Cuántos días debo esperar?»<br>Cuántas horas espero [ESPERAR · HORA · CUÁNTOS] → «¿Cuántas horas debo esperar?» |
| 6 | `I.PREG.SOBRE_TEMA` ¿Sobre qué quiere preguntar? | I.PREG.ELEGIR ∈ {tema} | sí | ¿Debo traer la factura? [FACTURA · TRAER · NECESITAR] → «¿Debo traer la factura del celular?»<br>¿Necesito fotocopias? [FOTOCOPIA · NECESITAR] → «¿Necesito fotocopias?»<br>¿Necesito un certificado? [CERTIFICADO · NECESITAR] → «¿Necesito un certificado?»<br>¿Pueden buscar mi celular? [CELULAR · BUSCAR · PUEDO] → «¿Pueden buscar mi celular?»<br>¿Dónde entrego las fotos? [FOTOS · DÓNDE · DAR] → «¿Dónde entrego las fotografías?»<br>¿Puedo traer el video mañana? [VIDEO · MAÑANA · TRAER · PUEDO] → «¿Puedo traer el video mañana?»<br>¿Me entregan un documento sellado? [PAPEL · SELLO · RECIBIR] → «¿Me entregan un documento sellado?»<br>¿La investigación continúa? [INVESTIGACIÓN · CONTINUAR] → «¿La investigación continúa?» |

## Recorrido `identificacion` — Mis datos

| # | Pregunta | Se muestra si | Obligatoria | Respuestas → frase |
|---|---|---|---|---|
| 1 | `Q.ID.NOMBRE` ¿Cuál es su nombre completo? | siempre | no | Escribir mi nombre ⟨texto_nombre⟩ → «Me llamo {nombre}.» |
| 2 | `Q.ID.DOC_TIPO` ¿Qué documento presenta? | siempre | no | Carnet de identidad [PAPEL · IDENTIDAD] → «Presento mi carnet de identidad.»<br>Pasaporte *(sin seña)* → «Presento mi pasaporte.»<br>Licencia de conducir *(sin seña)* → «Presento mi licencia de conducir.»<br>Otro documento (escribir) ⟨texto_detalle⟩ → «Presento este documento: «{texto}».»<br>No tengo un documento [NO] *salida* → «No tengo un documento conmigo.» |
| 3 | `Q.ID.DOC_NUMERO` ¿Cuál es el número de su documento? | Q.ID.DOC_TIPO ∈ {afirmado} | no | Escribir el número ⟨documento_numero⟩ → «El número de mi documento es {numero}.» |
| 4 | `Q.ID.TELEFONO_PROPIO` ¿Cuál es su número de celular? | siempre | no | Escribir mi número ⟨telefono⟩ → «Mi número de celular es {telefono}.» |
| 5 | `Q.ID.AVISO` ¿Prefiere recibir avisos por mensaje escrito? | siempre | no | Sí [SÍ] → «Sí, prefiero recibir avisos por mensaje escrito.»<br>No [NO] → «No quiero recibir avisos por mensaje escrito.»<br>No sé [NO_SABER] → «No sé qué prefiero.» |
| 6 | `Q.ID.ACOMPANANTE` ¿Vino solo o acompañado? | siempre | no | Vine solo/a [1] → «Vine sin acompañante.»<br>Vine con alguien [ACOMPAÑAR] → «Vine con {Q.ID.ACOMPANANTE_QUIEN\|otra persona}.» |
| 7 | `Q.ID.ACOMPANANTE_QUIEN` ¿Quién le acompaña? | Q.ID.ACOMPANANTE ∈ {acompanado} | no | Intérprete [INTÉRPRETE] → «un intérprete»<br>Mi mamá [MAMÁ] → «mi mamá»<br>Mi hermano [HERMANO] → «mi hermano»<br>Mi hermana [HERMANA] → «mi hermana»<br>Mi hijo [HIJO] → «mi hijo»<br>Mi hija [HIJA] → «mi hija»<br>Un amigo [AMIGO] → «un amigo»<br>Otra persona (escribir) ⟨texto_detalle⟩ → ««{texto}»» |
| 8 | `Q.ID.EDAD_PROPIA` ¿Qué edad tiene? | siempre | no | Escribir mi edad ⟨edad⟩ → «Tengo {n} años.» |
| 9 | `Q.ACC.INTERPRETE` ¿Necesita un intérprete de LSB? | siempre | no | Sí [SÍ] → «Sí, necesito un intérprete de LSB.»<br>No [NO] → «No necesito intérprete.»<br>No sé [NO_SABER] → «No sé si necesito intérprete.» |
| 10 | `Q.ACC.LECTURA` ¿Puede leer este texto? | siempre | no | Sí, puedo leerlo [SÍ] → «Sí, puedo leerlo.»<br>Leo poco [LEER · POCO] → «Leo poco.»<br>No puedo leerlo [NO] → «No puedo leerlo.» |

## Recorrido `otro` — Declaración de testigo

| # | Pregunta | Se muestra si | Obligatoria | Respuestas → frase |
|---|---|---|---|---|
| 1 | `Q.TES.QUE_VIO` ¿Qué vio o qué quiere declarar? | siempre | sí | Vi un robo [VER · ROBAR] → «Vi un robo.»<br>Vi una agresión [VER · PEGAR] → «Vi que golpearon a una persona.»<br>Vi que alguien escapó [VER · ESCAPAR] → «Vi que alguien escapó.»<br>Vi que dañaron algo [VER · DAÑAR] → «Vi que dañaron algo.»<br>Otra cosa que vi (escribir) ⟨texto_detalle⟩ → «Vi esto: «{texto}».»<br>Quiero agregar información a lo que dije [AUMENTAR · NARRAR · QUERER] → «Quiero agregar información a lo que dije.»<br>Quiero corregir algo de lo que dije [ARREGLAR] → «Quiero corregir algo de lo que dije.» |
| 2 | `Q.PER.OBSERVADA` ¿A quién vio? | Q.TES.QUE_VIO ∈ {robo, agresion, escape, dano, otro} | no | Un hombre [HOMBRE] → «Vi a un hombre.»<br>Una mujer [MUJER] → «Vi a una mujer.»<br>A la persona que robó [LADRÓN] → «Vi a la persona que robó.»<br>No sé [NO_SABER] *salida* → «No vi bien a la persona.» |
| 3 | `Q.TIE.CUANDO` ¿Cuándo ocurrió? | Q.TES.QUE_VIO ∈ {robo, agresion, escape, dano, otro} | no | Ahora mismo [AHORA] → «hace un momento»<br>Hoy [HOY] → «hoy»<br>Ayer [AYER] → «ayer»<br>Anteayer [ANTEAYER] → «anteayer»<br>Hace … minutos [MINUTO] ⟨entero⟩ → «hace {n} minutos»<br>Hace … horas [HORA] ⟨entero⟩ → «hace {n} horas»<br>Hace … días [DÍA] ⟨entero⟩ → «hace {n} días»<br>Hace … semanas [SEMANA] ⟨entero⟩ → «hace {n} semanas»<br>Hace … meses [MES] ⟨entero⟩ → «hace {n} meses»<br>Por la tarde [TARDE] → «por la tarde»<br>Temprano [TEMPRANO] → «temprano»<br>No recuerdo [RECORDAR · NO] *salida* → «No recuerdo cuándo ocurrió.» |
| 4 | `Q.LUG.DONDE` ¿Dónde ocurrió? | Q.TES.QUE_VIO ∈ {robo, agresion, escape, dano, otro} | no | En la calle [CALLE] ⟨lugar_literal⟩ → «Ocurrió en la calle{?nombre}. / sin valor: «Ocurrió en la calle.»»<br>En una avenida [AVENIDA] ⟨lugar_literal⟩ → «Ocurrió en la avenida{?nombre}. / sin valor: «Ocurrió en la avenida.»»<br>En una plaza [PLAZA] ⟨lugar_literal⟩ → «Ocurrió en la plaza{?nombre}. / sin valor: «Ocurrió en la plaza.»»<br>En un mercado [MERCADO] ⟨lugar_literal⟩ → «Ocurrió en el mercado{?nombre}. / sin valor: «Ocurrió en el mercado.»»<br>En un barrio [BARRIO] ⟨lugar_literal⟩ → «Ocurrió en el barrio{?nombre}. / sin valor: «Ocurrió en el barrio.»»<br>En una tienda [TIENDA] ⟨lugar_literal⟩ → «Ocurrió en una tienda{?nombre}. / sin valor: «Ocurrió en una tienda.»»<br>En mi casa [CASA] → «Ocurrió en mi casa.»<br>Dentro de un micro [MICRO] → «Ocurrió dentro de un micro.»<br>Dentro de un trufi [TRUFI] → «Ocurrió dentro de un trufi.»<br>Otro lugar (escribir) ⟨texto_detalle⟩ → «Ocurrió en «{texto}».»<br>No sé [NO_SABER] *salida* → «No sé exactamente dónde ocurrió.» |
| 5 | `Q.TES.PUEDE_TESTIMONIO` ¿Puede dar testimonio de lo que vio? | Q.TES.QUE_VIO ∈ {robo, agresion, escape, dano, otro} | no | Sí [SÍ] → «Sí, puedo dar testimonio de lo que vi.»<br>No [NO] → «No puedo dar testimonio.»<br>No sé [NO_SABER] → «No sé si puedo dar testimonio.» |

## Respuestas a preguntas del funcionario (modo respuesta)

| Enunciado del corpus §6 | Nodo | Pregunta del banco | Respuestas |
|---|---|---|---|
| ¿Comprende lo que le estoy explicando? | `n-s6-acceso_comunicativ-05` | `Q.ACC.COMPRENSION` | Sí, comprendo, No comprendo, Explíqueme despacio |
| ¿Prefiere que le escriba en papel? | `n-s6-acceso_comunicativ-03` | `Q.ACC.ESCRITO` | Sí, No, No sé |
| ¿Necesita un intérprete de LSB? | `n-s6-acceso_comunicativ-02` | `Q.ACC.INTERPRETE` | Sí, No, No sé |
| ¿Puede leer este texto? | `n-s6-acceso_comunicativ-04` | `Q.ACC.LECTURA` | Sí, puedo leerlo, Leo poco, No puedo leerlo |
| ¿Quiere que lo explique otra vez y más despacio? | `n-s6-acceso_comunicativ-06` | `Q.ACC.REPARACION` | Sí, No |
| ¿Usted es una persona sorda? | `n-s6-acceso_comunicativ-01` | `Q.ACC.SORDO` | Sí, No |
| ¿Desea presentar una denuncia? | `n-s6-inicio_de_denuncia-01` | `Q.DEN.INTENCION` | Sí, No, No sé |
| ¿Son uno o varios números? | `n-s6-amenazas_mensajes-07` | `Q.DIG.CANT_NUMEROS` | Un solo número, Varios números, No sé |
| ¿Tiene fotos de la pantalla? | `n-s6-amenazas_mensajes-05` | `Q.DIG.CAPTURAS` | Sí, No, No sé |
| ¿Sigue recibiendo mensajes? | `n-s6-amenazas_mensajes-06` | `Q.DIG.CONTINUA` | Sí, No, No sé |
| ¿Guardó los mensajes? | `n-s6-amenazas_mensajes-04` | `Q.DIG.GUARDO` | Sí, No, No sé, Sí, todos |
| ¿Puede mostrar el celular ahora? | `n-s6-amenazas_mensajes-08` | `Q.DIG.MOSTRAR` | Sí, No, No sé |
| ¿Conoce el número desde el que le escribieron? | `n-s6-amenazas_mensajes-03` | `Q.DIG.NUMERO_CONOCE` | Sí, No, No sé |
| ¿Las amenazas llegaron por celular? | `n-s6-amenazas_mensajes-01` | `Q.DIG.POR_CELULAR` | Sí, No, No sé |
| ¿Le escribieron por internet? | `n-s6-amenazas_mensajes-02` | `Q.DIG.POR_INTERNET` | Sí, No, No sé |
| ¿Conserva toda la conversación? | `n-s6-engaño_dinero_y_t-08` | `Q.DIN.CHAT` | Sí, No, No sé |
| ¿Tiene factura o papel del banco? | `n-s6-engaño_dinero_y_t-04` | `Q.DIN.COMPROBANTE` | Sí, No, No sé |
| ¿Entregó o envió dinero? | `n-s6-engaño_dinero_y_t-01` | `Q.DIN.ENTREGO` | Sí, No, No sé |
| ¿Se comunicaron por internet? | `n-s6-engaño_dinero_y_t-07` | `Q.DIN.INTERNET` | Sí, No, No sé |
| ¿Cuánto dinero entregó? | `n-s6-engaño_dinero_y_t-02` | `Q.DIN.MONTO` | Escribir el monto, No recuerdo |
| ¿Lo hizo mediante un banco? | `n-s6-engaño_dinero_y_t-03` | `Q.DIN.POR_BANCO` | Sí, No, No sé |
| ¿Conoce el nombre de la persona? | `n-s6-engaño_dinero_y_t-05` | `Q.DIN.RECEPTOR_NOMBRE` | Sí, No, No sé |
| ¿Tiene su número de celular? | `n-s6-engaño_dinero_y_t-06` | `Q.DIN.RECEPTOR_NUMERO` | Sí, No, No sé |
| ¿Hay cámaras o video del lugar? | `n-s6-robo_hurto_y_obje-09` | `Q.EVI.CAMARAS` | Sí, No, No sé |
| ¿Tiene un certificado? | `n-s6-testigos_fotos_v-08` | `Q.EVI.CERTIFICADO` | Sí, No, No sé |
| ¿Tiene la factura o la caja del celular? | `n-s6-robo_hurto_y_obje-08` | `Q.EVI.FACTURA_O_CAJA` | `Q.EVI.FACTURA` + `Q.EVI.CAJA` |
| ¿Tiene fotografías? | `n-s6-testigos_fotos_v-05` | `Q.EVI.FOTOS` | Sí, No, No sé |
| ¿Puede mostrarlo ahora? | `n-s6-testigos_fotos_v-07` | `Q.EVI.MOSTRAR_AHORA` | Sí, No, No sé |
| ¿Desea presentar estos elementos? | `n-s6-testigos_fotos_v-10` | `Q.EVI.PRESENTAR` | Sí, No, No sé |
| ¿Tiene una resolución o papel previo? | `n-s6-testigos_fotos_v-09` | `Q.EVI.RESOLUCION_PREVIA` | Sí, No, No sé |
| ¿Tiene video? | `n-s6-testigos_fotos_v-06` | `Q.EVI.VIDEO` | Sí, No, No sé |
| ¿Quiere agregar algo que no le pregunté? | `n-s6-inicio_de_denuncia-12` | `Q.HEC.AMPLIAR` | Sí, No |
| ¿Qué ocurrió? | `n-s6-inicio_de_denuncia-02` | `Q.HEC.QUE_OCURRIO` | Me robaron, Me falta algo (lo perdí o no sé), Dañaron algo mío, Alguien escapó |
| ¿Puede contarme lo sucedido desde el inicio? | `n-s6-inicio_de_denuncia-03` | `Q.HEC.RELATO_ORDENADO` | Sí, No |
| ¿Vino solo o acompañado? | `n-s6-acceso_comunicativ-12` | `Q.ID.ACOMPANANTE` | Vine solo/a, Vine con alguien |
| ¿Puede deletrear su apellido? | `n-s6-acceso_comunicativ-08` | `Q.ID.APELLIDO` | Escribir mi apellido |
| ¿Prefiere recibir avisos por mensaje escrito? | `n-s6-acceso_comunicativ-11` | `Q.ID.AVISO` | Sí, No, No sé |
| ¿Prefiere que le avisemos por escrito? | `n-s6-seguimiento_prelim-10` | `Q.ID.AVISO` | Sí, No, No sé |
| ¿Tiene su carnet de identidad? | `n-s6-acceso_comunicativ-09` | `Q.ID.DOC_TIENE` | Sí, No, No sé |
| ¿Cuál es su nombre completo? | `n-s6-acceso_comunicativ-07` | `Q.ID.NOMBRE` | Escribir mi nombre |
| ¿Este número de celular es suyo? | `n-s6-acceso_comunicativ-10` | `Q.ID.TELEFONO_VALIDA` | Sí, No, No sé |
| ¿Ocurrió dentro o fuera del lugar? | `n-s6-inicio_de_denuncia-08` | `Q.LUG.DENTRO_FUERA` | Dentro, Fuera, No sé |
| ¿Dónde ocurrió? | `n-s6-inicio_de_denuncia-07` | `Q.LUG.DONDE` | En la calle, En una avenida, En una plaza, En un mercado, En un barrio, En una tienda, En mi casa, Dentro de un micro, Dentro de un trufi, Otro lugar (escribir), No sé |
| ¿Desea orientación para recibir asistencia de SEPDAVI? | `n-s6-agresion_violenci-10` | `Q.ORI.SEPDAVI` | Sí, No, No sé |
| ¿Conoce a la persona involucrada? | `n-s6-inicio_de_denuncia-09` | `Q.PER.CONOCE` | Sí, No, No sé |
| ¿Qué color de cabello recuerda? | `n-s6-descripcion_de_per-05` | `Q.PER.DESC.CABELLO` | Negro, Otro color (escribir), No recuerdo |
| ¿Era delgado o de contextura gruesa? | `n-s6-descripcion_de_per-04` | `Q.PER.DESC.CONTEXTURA` | Delgada, De contextura gruesa, No sé |
| ¿Era joven o adulto? | `n-s6-descripcion_de_per-02` | `Q.PER.DESC.EDAD` | Escribir la edad, Era joven, Era adulta, No recuerdo |
| ¿Era alto o bajo? | `n-s6-descripcion_de_per-03` | `Q.PER.DESC.ESTATURA` | Alta, Baja, No sé |
| ¿Llevaba gorra? | `n-s6-descripcion_de_per-07` | `Q.PER.DESC.GORRA` | Sí, No, No sé |
| ¿Usaba lentes? | `n-s6-descripcion_de_per-09` | `Q.PER.DESC.LENTES` | Sí, No, No sé |
| ¿Llevaba mochila o bolsa? | `n-s6-descripcion_de_per-08` | `Q.PER.DESC.MOCHILA` | Una mochila, Una bolsa, Ninguna, No sé |
| ¿Recuerda alguna característica particular? | `n-s6-descripcion_de_per-10` | `Q.PER.DESC.RASGO` | Escribir la característica, No recuerdo |
| ¿Qué ropa llevaba? | `n-s6-descripcion_de_per-06` | `Q.PER.DESC.ROPA` | Polera, Pantalón, Chamarra, Gorra, Mochila, Otra prenda o color (escribir), No recuerdo |
| ¿Era un hombre o una mujer? | `n-s6-descripcion_de_per-01` | `Q.PER.DESC.SEXO` | Un hombre, Una mujer, No sé |
| ¿Había otras personas presentes? | `n-s6-inicio_de_denuncia-11` | `Q.PER.OTROS_PRESENTES` | Sí, No, No sé |
| ¿Puede identificarla si la vuelve a ver? | `n-s6-inicio_de_denuncia-10` | `Q.PER.RECONOCE` | Sí, No, No sé |
| ¿Recibió amenazas? | `n-s6-agresion_violenci-06` | `Q.RIE.AMENAZAS` | Sí, No, No sé |
| ¿Necesita auxilio ahora? | `n-s6-agresion_violenci-08` | `Q.RIE.AUXILIO` | Sí, No, No sé |
| ¿Tiene miedo de volver a su casa? | `n-s6-agresion_violenci-07` | `Q.RIE.MIEDO_CASA` | Sí, No, No sé |
| ¿Hay niños u otras personas que necesiten protección? | `n-s6-agresion_violenci-09` | `Q.RIE.PROTECCION_OTROS` | Sí, No, No sé |
| ¿Le robaron algún objeto? | `n-s6-robo_hurto_y_obje-01` | `Q.ROB.ALGO` | Sí, No, No sé |
| ¿Le robaron el celular? | `n-s6-robo_hurto_y_obje-03` | `Q.ROB.CONFIRMA_OBJETO` | Sí, No, No sé, Me robaron otra cosa |
| ¿Le falta su carnet de identidad? | `n-s6-robo_hurto_y_obje-04` | `Q.ROB.FALTA_CARNET` | Sí, No, No sé |
| ¿Le falta dinero? | `n-s6-robo_hurto_y_obje-05` | `Q.ROB.FALTA_DINERO` | Sí, No, No sé |
| ¿El ladrón escapó? | `n-s6-robo_hurto_y_obje-07` | `Q.ROB.LADRON_ESCAPO` | Sí, No, No sé |
| ¿Qué le robaron? | `n-s6-robo_hurto_y_obje-02` | `Q.ROB.QUE` | Celular, Dinero, Mochila, Bolsa, Chamarra, Gorra, Lentes, Carnet de identidad, Un papel (no sé cómo se llama), Otro objeto (escribir), No sé |
| ¿Vio al ladrón? | `n-s6-robo_hurto_y_obje-06` | `Q.ROB.VIO_LADRON` | Sí, No, No sé |
| ¿Necesita asistencia médica? | `n-s6-agresion_violenci-03` | `Q.SAL.ASISTENCIA` | Sí, No, No sé |
| ¿Tiene certificado del doctor? | `n-s6-agresion_violenci-05` | `Q.SAL.CERTIFICADO` | Sí, No, No sé |
| ¿Está herido? | `n-s6-agresion_violenci-02` | `Q.SAL.HERIDO` | Sí, No, No sé |
| ¿Fue al hospital? | `n-s6-agresion_violenci-04` | `Q.SAL.HOSPITAL` | Sí, No, No sé |
| ¿Recibió un papel de convocatoria? | `n-s6-seguimiento_prelim-08` | `Q.SEG.CITACION` | Sí, No, No sé |
| ¿Está de acuerdo con lo escrito? | `n-s6-interaccion_con_fi-08` | `Q.SEG.CONFORMIDAD` | Sí, estoy de acuerdo, No estoy de acuerdo, Quiero leerlo otra vez, No lo entiendo |
| ¿Necesita defensa pública gratuita? | `n-s6-seguimiento_prelim-06` | `Q.SEG.DEFENSA_PUBLICA` | Sí, No, No sé |
| ¿Le indicaron ir a la Fiscalía? | `n-s6-interaccion_con_fi-02` | `Q.SEG.DERIVACION_FISCALIA` | Sí, No, No sé |
| ¿Necesita saber dónde está la Fiscalía? | `n-s6-seguimiento_prelim-07` | `Q.SEG.DONDE_FISCALIA` | Sí, No |
| ¿Vino a consultar el estado de su caso? | `n-s6-seguimiento_prelim-01` | `Q.SEG.ESTADO_CASO` | Sí, No, No sé |
| ¿Cuándo presentó la denuncia? | `n-s6-seguimiento_prelim-03` | `Q.SEG.FECHA_DENUNCIA` | Hace … días, Hace … semanas, Hace … meses, Ayer, No recuerdo |
| ¿Necesita hablar con un abogado? | `n-s6-seguimiento_prelim-05` | `Q.SEG.HABLAR_ABOGADO` | Sí, No, No sé |
| ¿Necesita hablar con el fiscal? | `n-s6-interaccion_con_fi-01` | `Q.SEG.HABLAR_FISCAL` | Sí, No, No sé |
| ¿Quiere hablar con el policía encargado? | `n-s6-seguimiento_prelim-04` | `Q.SEG.HABLAR_POLICIA` | Sí, No, No sé |
| ¿Necesita intérprete para esa reunión? | `n-s6-interaccion_con_fi-06` | `Q.SEG.INTERPRETE_REUNION` | Sí, No, No sé |
| ¿Debe presentarse ante un juez? | `n-s6-interaccion_con_fi-04` | `Q.SEG.JUEZ` | Sí, No, No sé |
| ¿Quiere leer el papel antes de escribir su nombre? | `n-s6-interaccion_con_fi-07` | `Q.SEG.LEER_ANTES_FIRMAR` | Sí, No, No sé |
| ¿Tiene el número de referencia? | `n-s6-seguimiento_prelim-02` | `Q.SEG.NUM_REFERENCIA` | Sí, No, No sé |
| ¿Sabe dónde está el Órgano Judicial? | `n-s6-interaccion_con_fi-05` | `Q.SEG.ORGANO_JUDICIAL` | Sí, No |
| ¿Recibió una resolución? | `n-s6-interaccion_con_fi-03` | `Q.SEG.RESOLUCION` | Sí, No, No sé |
| ¿Tiene que volver otro día? | `n-s6-seguimiento_prelim-09` | `Q.SEG.RETORNO` | Sí, No, No sé |
| ¿Cuántos testigos hay? | `n-s6-testigos_fotos_v-02` | `Q.TES.CANTIDAD` | Escribir cuántos, No sé |
| ¿Hay testigos del robo? | `n-s6-robo_hurto_y_obje-10` | `Q.TES.EXISTE` | Sí, No, No sé |
| ¿Hay algún testigo? | `n-s6-testigos_fotos_v-01` | `Q.TES.EXISTE` | Sí, No, No sé |
| ¿Puede traer al testigo? | `n-s6-testigos_fotos_v-04` | `Q.TES.TRAER` | Sí, No, No sé |
| ¿El testigo vio todo? | `n-s6-testigos_fotos_v-03` | `Q.TES.VIO_TODO` | Sí, No, No sé |
| ¿Fue hoy, ayer o antes? | `n-s6-inicio_de_denuncia-05` | `Q.TIE.APROX` | Hoy, Ayer, Antes, No recuerdo |
| ¿Cuándo ocurrió? | `n-s6-inicio_de_denuncia-04` | `Q.TIE.CUANDO` | Ahora mismo, Hoy, Ayer, Anteayer, Hace … minutos, Hace … horas, Hace … días, Hace … semanas, Hace … meses, Por la tarde, Temprano, No recuerdo |
| ¿A qué hora aproximadamente? | `n-s6-inicio_de_denuncia-06` | `Q.TIE.HORA` | Escribir la hora, Por la tarde, Temprano, No recuerdo |
| ¿Alguien le pegó o maltrató? | `n-s6-agresion_violenci-01` | `Q.VIO.AGRESION` | Sí, No, No sé |
