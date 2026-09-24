# Matriz de cobertura del corpus conversacional (209 intervenciones)

Generado por `tool/build_dialogue_graph.py` desde `Corpus_Maestro_Unificado_LSB_v4_Auditado (2).md`. No editar a mano.

Cada fila es una intervención de ejemplo de los bancos 6, 7 y 8 del corpus, con los modos A/B/C en que su nodo puede activarse y el estado de cobertura con los recursos que la app tiene hoy.

**Qué significa cada estado**

| Estado | Significado |
|---|---|
| cubierta | Todos sus conceptos resuelven contra el catálogo que carga la app. |
| cubierta con dactilología | Algún concepto se representa deletreando, porque no hay seña directa documentada. |
| requiere validación | Algún concepto está documentado en el corpus pero no es elegible en la app, o el corpus lo marca como pendiente. |
| no soportada | Algún concepto no está ni en el catálogo, ni en el apéndice 12, ni es deletreable. |

**Resumen**

| Estado | Intervenciones | % |
|---|---:|---:|
| cubierta | 184 | 88.0% |
| cubierta con dactilología | 20 | 9.6% |
| cubierta por composición validada | 0 | 0.0% |
| requiere validación | 0 | 0.0% |
| no soportada | 5 | 2.4% |
| **Total** | **209** | **100%** |

## Pendientes, una por una

Las intervenciones que no quedan cubiertas del todo, con el motivo exacto. Ninguna se presenta como terminada.

| Entrada | Frase | Concepto | Motivo |
|---|---|---|---|
| `S6-ACCESO_COMUNICATIV-04` | ¿Puede leer este texto? | `TEXTO` | ni en el catálogo, ni en el corpus, ni deletreable |
| `S6-ACCESO_COMUNICATIV-08` | ¿Puede deletrear su apellido? | `DELETREAR` | ni en el catálogo, ni en el corpus, ni deletreable |
| `S6-DESCRIPCION_DE_PER-05` | ¿Qué color de cabello recuerda? | `COLOR` | ni en el catálogo, ni en el corpus, ni deletreable |
| `S6-ROBO,_HURTO_Y_OBJE-01` | ¿Le robaron algún objeto? | `OBJETO` | ni en el catálogo, ni en el corpus, ni deletreable |
| `S7-ROBO_Y_OBJETOS-06` | ¿Puedo agregar otro objeto robado? | `OBJETO` | ni en el catálogo, ni en el corpus, ni deletreable |

## Sección 6 — preguntas del funcionario (98)

| # | Frase en español | Intención | Modos | Ámbito | Estado | Nodo |
|---|---|---|---|---|---|---|
| 1 | ¿Usted es una persona sorda? | `CONFIRMAR_ACCESO` | C | `identificacion` | cubierta | `n-s6-acceso_comunicativ-01` |
| 2 | ¿Necesita un intérprete de LSB? | `NECESIDAD_INTERPRETE` | C | `identificacion` | cubierta | `n-s6-acceso_comunicativ-02` |
| 3 | ¿Prefiere que le escriba en papel? | `CANAL_ESCRITO` | C | `identificacion` | cubierta | `n-s6-acceso_comunicativ-03` |
| 4 | ¿Puede leer este texto? | `LECTURA` | C | `identificacion` | no soportada | `n-s6-acceso_comunicativ-04` |
| 5 | ¿Comprende lo que le estoy explicando? | `COMPRENSION` | C | `identificacion` | cubierta | `n-s6-acceso_comunicativ-05` |
| 6 | ¿Quiere que lo explique otra vez y más despacio? | `REPARACION` | C | `identificacion` | cubierta | `n-s6-acceso_comunicativ-06` |
| 7 | ¿Cuál es su nombre completo? | `IDENTIFICACION_NOMBRE` | C | `identificacion` | cubierta | `n-s6-acceso_comunicativ-07` |
| 8 | ¿Puede deletrear su apellido? | `IDENTIFICACION_DELETREO` | C | `identificacion` | no soportada | `n-s6-acceso_comunicativ-08` |
| 9 | ¿Tiene su carnet de identidad? | `IDENTIFICACION_DOCUMENTO` | C | `identificacion` | cubierta | `n-s6-acceso_comunicativ-09` |
| 10 | ¿Este número de celular es suyo? | `VALIDAR_CONTACTO` | C | `identificacion` | cubierta | `n-s6-acceso_comunicativ-10` |
| 11 | ¿Prefiere recibir avisos por mensaje escrito? | `PREFERENCIA_AVISO` | C | `identificacion` | cubierta | `n-s6-acceso_comunicativ-11` |
| 12 | ¿Vino solo o acompañado? | `ACOMPAÑANTE` | C | `identificacion` | cubierta | `n-s6-acceso_comunicativ-12` |
| 1 | ¿Desea presentar una denuncia? | `INTENCION_DENUNCIA` | C | `denuncia_robo` | cubierta con dactilología | `n-s6-inicio_de_denuncia-01` |
| 2 | ¿Qué ocurrió? | `RELATO_ABIERTO` | C | `denuncia_robo` | cubierta | `n-s6-inicio_de_denuncia-02` |
| 3 | ¿Puede contarme lo sucedido desde el inicio? | `RELATO_ORDENADO` | C | `denuncia_robo` | cubierta | `n-s6-inicio_de_denuncia-03` |
| 4 | ¿Cuándo ocurrió? | `TIEMPO_HECHO` | C | `denuncia_robo` | cubierta | `n-s6-inicio_de_denuncia-04` |
| 5 | ¿Fue hoy, ayer o antes? | `TIEMPO_APROX` | C | `denuncia_robo` | cubierta | `n-s6-inicio_de_denuncia-05` |
| 6 | ¿A qué hora aproximadamente? | `HORA_HECHO` | C | `denuncia_robo` | cubierta | `n-s6-inicio_de_denuncia-06` |
| 7 | ¿Dónde ocurrió? | `LUGAR_HECHO` | C | `denuncia_robo` | cubierta | `n-s6-inicio_de_denuncia-07` |
| 8 | ¿Ocurrió dentro o fuera del lugar? | `POSICION_LUGAR` | C | `denuncia_robo` | cubierta | `n-s6-inicio_de_denuncia-08` |
| 9 | ¿Conoce a la persona involucrada? | `CONOCIMIENTO_PERSONA` | C | `denuncia_robo` | cubierta | `n-s6-inicio_de_denuncia-09` |
| 10 | ¿Puede identificarla si la vuelve a ver? | `RECONOCIMIENTO` | C | `denuncia_robo` | cubierta | `n-s6-inicio_de_denuncia-10` |
| 11 | ¿Había otras personas presentes? | `PRESENCIA_OTROS` | C | `denuncia_robo` | cubierta | `n-s6-inicio_de_denuncia-11` |
| 12 | ¿Quiere agregar algo que no le pregunté? | `AMPLIACION_RELATO` | C | `denuncia_robo` | cubierta | `n-s6-inicio_de_denuncia-12` |
| 1 | ¿Era un hombre o una mujer? | `SEXO_DESCRIPCION` | C | `denuncia_robo` | cubierta | `n-s6-descripcion_de_per-01` |
| 2 | ¿Era joven o adulto? | `EDAD_APROX` | C | `denuncia_robo` | cubierta | `n-s6-descripcion_de_per-02` |
| 3 | ¿Era alto o bajo? | `ALTURA` | C | `denuncia_robo` | cubierta | `n-s6-descripcion_de_per-03` |
| 4 | ¿Era delgado o de contextura gruesa? | `CONTEXTURA` | C | `denuncia_robo` | cubierta | `n-s6-descripcion_de_per-04` |
| 5 | ¿Qué color de cabello recuerda? | `CABELLO` | C | `denuncia_robo` | no soportada | `n-s6-descripcion_de_per-05` |
| 6 | ¿Qué ropa llevaba? | `VESTIMENTA` | C | `denuncia_robo` | cubierta | `n-s6-descripcion_de_per-06` |
| 7 | ¿Llevaba gorra? | `GORRA` | C | `denuncia_robo` | cubierta | `n-s6-descripcion_de_per-07` |
| 8 | ¿Llevaba mochila o bolsa? | `OBJETO_PERSONA` | C | `denuncia_robo` | cubierta | `n-s6-descripcion_de_per-08` |
| 9 | ¿Usaba lentes? | `LENTES` | C | `denuncia_robo` | cubierta | `n-s6-descripcion_de_per-09` |
| 10 | ¿Recuerda alguna característica particular? | `RASGO_DISTINTIVO` | C | `denuncia_robo` | cubierta | `n-s6-descripcion_de_per-10` |
| 1 | ¿Le robaron algún objeto? | `ROBO_OBJETO` | C | `denuncia_robo` | no soportada | `n-s6-robo_hurto_y_obje-01` |
| 2 | ¿Qué le robaron? | `OBJETO_ROBADO` | C | `denuncia_robo` | cubierta | `n-s6-robo_hurto_y_obje-02` |
| 3 | ¿Le robaron el celular? | `ROBO_CELULAR` | C | `denuncia_robo` | cubierta | `n-s6-robo_hurto_y_obje-03` |
| 4 | ¿Le falta su carnet de identidad? | `FALTA_IDENTIDAD` | C | `denuncia_robo` | cubierta | `n-s6-robo_hurto_y_obje-04` |
| 5 | ¿Le falta dinero? | `FALTA_DINERO` | C | `denuncia_robo` | cubierta | `n-s6-robo_hurto_y_obje-05` |
| 6 | ¿Vio al ladrón? | `VER_LADRON` | C | `denuncia_robo` | cubierta | `n-s6-robo_hurto_y_obje-06` |
| 7 | ¿El ladrón escapó? | `ESCAPE` | C | `denuncia_robo` | cubierta | `n-s6-robo_hurto_y_obje-07` |
| 8 | ¿Tiene la factura o la caja del celular? | `PROPIEDAD_CELULAR` | C | `denuncia_robo` | cubierta | `n-s6-robo_hurto_y_obje-08` |
| 9 | ¿Hay cámaras o video del lugar? | `VIDEO_LUGAR` | C | `denuncia_robo` | cubierta | `n-s6-robo_hurto_y_obje-09` |
| 10 | ¿Hay testigos del robo? | `TESTIGOS_ROBO` | C | `denuncia_robo` | cubierta | `n-s6-robo_hurto_y_obje-10` |
| 1 | ¿Alguien le pegó o maltrató? | `AGRESION` | C | `violencia` | cubierta | `n-s6-agresion_violenci-01` |
| 2 | ¿Está herido? | `HERIDA` | C | `violencia` | cubierta | `n-s6-agresion_violenci-02` |
| 3 | ¿Necesita asistencia médica? | `ASISTENCIA_MEDICA` | C | `violencia` | cubierta | `n-s6-agresion_violenci-03` |
| 4 | ¿Fue al hospital? | `ATENCION_HOSPITAL` | C | `violencia` | cubierta | `n-s6-agresion_violenci-04` |
| 5 | ¿Tiene certificado del doctor? | `CERTIFICADO_MEDICO` | C | `violencia` | cubierta | `n-s6-agresion_violenci-05` |
| 6 | ¿Recibió amenazas? | `AMENAZA` | C | `violencia` | cubierta | `n-s6-agresion_violenci-06` |
| 7 | ¿Tiene miedo de volver a su casa? | `RIESGO_RETORNO` | C | `violencia` | cubierta | `n-s6-agresion_violenci-07` |
| 8 | ¿Necesita auxilio ahora? | `AUXILIO_INMEDIATO` | C | `violencia` | cubierta | `n-s6-agresion_violenci-08` |
| 9 | ¿Hay niños u otras personas que necesiten protección? | `PROTECCION_OTROS` | C | `violencia` | cubierta | `n-s6-agresion_violenci-09` |
| 10 | ¿Desea orientación para recibir asistencia de SEPDAVI? | `DERIVACION_SEPDAVI` | C | `violencia` | cubierta con dactilología | `n-s6-agresion_violenci-10` |
| 1 | ¿Las amenazas llegaron por celular? | `AMENAZA_CELULAR` | C | `amenaza_digital` | cubierta | `n-s6-amenazas_mensajes-01` |
| 2 | ¿Le escribieron por internet? | `MENSAJE_INTERNET` | C | `amenaza_digital` | cubierta | `n-s6-amenazas_mensajes-02` |
| 3 | ¿Conoce el número desde el que le escribieron? | `NUMERO_ORIGEN` | C | `amenaza_digital` | cubierta | `n-s6-amenazas_mensajes-03` |
| 4 | ¿Guardó los mensajes? | `GUARDAR_MENSAJES` | C | `amenaza_digital` | cubierta | `n-s6-amenazas_mensajes-04` |
| 5 | ¿Tiene fotos de la pantalla? | `CAPTURAS` | C | `amenaza_digital` | cubierta | `n-s6-amenazas_mensajes-05` |
| 6 | ¿Sigue recibiendo mensajes? | `CONTINUIDAD_MENSAJES` | C | `amenaza_digital` | cubierta | `n-s6-amenazas_mensajes-06` |
| 7 | ¿Son uno o varios números? | `CANTIDAD_NUMEROS` | C | `amenaza_digital` | cubierta | `n-s6-amenazas_mensajes-07` |
| 8 | ¿Puede mostrar el celular ahora? | `MOSTRAR_CELULAR` | C | `amenaza_digital` | cubierta | `n-s6-amenazas_mensajes-08` |
| 1 | ¿Entregó o envió dinero? | `DINERO_ENTREGADO` | C | `engano_dinero` | cubierta | `n-s6-engaño_dinero_y_t-01` |
| 2 | ¿Cuánto dinero entregó? | `MONTO` | C | `engano_dinero` | cubierta | `n-s6-engaño_dinero_y_t-02` |
| 3 | ¿Lo hizo mediante un banco? | `BANCO` | C | `engano_dinero` | cubierta | `n-s6-engaño_dinero_y_t-03` |
| 4 | ¿Tiene factura o papel del banco? | `COMPROBANTE` | C | `engano_dinero` | cubierta | `n-s6-engaño_dinero_y_t-04` |
| 5 | ¿Conoce el nombre de la persona? | `NOMBRE_PERSONA` | C | `engano_dinero` | cubierta | `n-s6-engaño_dinero_y_t-05` |
| 6 | ¿Tiene su número de celular? | `CONTACTO_PERSONA` | C | `engano_dinero` | cubierta | `n-s6-engaño_dinero_y_t-06` |
| 7 | ¿Se comunicaron por internet? | `CONTACTO_INTERNET` | C | `engano_dinero` | cubierta | `n-s6-engaño_dinero_y_t-07` |
| 8 | ¿Conserva toda la conversación? | `CONSERVAR_CHAT` | C | `engano_dinero` | cubierta | `n-s6-engaño_dinero_y_t-08` |
| 1 | ¿Hay algún testigo? | `TESTIGO_EXISTE` | C | `otro` | cubierta | `n-s6-testigos_fotos_v-01` |
| 2 | ¿Cuántos testigos hay? | `TESTIGO_CANTIDAD` | C | `otro` | cubierta | `n-s6-testigos_fotos_v-02` |
| 3 | ¿El testigo vio todo? | `TESTIGO_VIO` | C | `otro` | cubierta | `n-s6-testigos_fotos_v-03` |
| 4 | ¿Puede traer al testigo? | `TESTIGO_TRAER` | C | `otro` | cubierta | `n-s6-testigos_fotos_v-04` |
| 5 | ¿Tiene fotografías? | `FOTOS` | C | `otro` | cubierta | `n-s6-testigos_fotos_v-05` |
| 6 | ¿Tiene video? | `VIDEO` | C | `otro` | cubierta | `n-s6-testigos_fotos_v-06` |
| 7 | ¿Puede mostrarlo ahora? | `MOSTRAR` | C | `otro` | cubierta | `n-s6-testigos_fotos_v-07` |
| 8 | ¿Tiene un certificado? | `CERTIFICADO` | C | `otro` | cubierta | `n-s6-testigos_fotos_v-08` |
| 9 | ¿Tiene una resolución o papel previo? | `RESOLUCION` | C | `otro` | cubierta | `n-s6-testigos_fotos_v-09` |
| 10 | ¿Desea presentar estos elementos? | `PRESENTAR_ELEMENTOS` | C | `otro` | cubierta | `n-s6-testigos_fotos_v-10` |
| 1 | ¿Vino a consultar el estado de su caso? | `CONSULTA_ESTADO` | C | `seguimiento` | cubierta | `n-s6-seguimiento_prelim-01` |
| 2 | ¿Tiene el número de referencia? | `NUMERO_REFERENCIA` | C | `seguimiento` | cubierta | `n-s6-seguimiento_prelim-02` |
| 3 | ¿Cuándo presentó la denuncia? | `FECHA_DENUNCIA` | C | `seguimiento` | cubierta con dactilología | `n-s6-seguimiento_prelim-03` |
| 4 | ¿Quiere hablar con el policía encargado? | `HABLAR_POLICIA` | C | `seguimiento` | cubierta | `n-s6-seguimiento_prelim-04` |
| 5 | ¿Necesita hablar con un abogado? | `HABLAR_ABOGADO` | C | `seguimiento` | cubierta | `n-s6-seguimiento_prelim-05` |
| 6 | ¿Necesita defensa pública gratuita? | `SEPDEP` | C | `seguimiento` | cubierta con dactilología | `n-s6-seguimiento_prelim-06` |
| 7 | ¿Necesita saber dónde está la Fiscalía? | `FISCALIA` | C | `seguimiento` | cubierta con dactilología | `n-s6-seguimiento_prelim-07` |
| 8 | ¿Recibió un papel de convocatoria? | `CITACION` | C | `seguimiento` | cubierta | `n-s6-seguimiento_prelim-08` |
| 9 | ¿Tiene que volver otro día? | `RETORNO` | C | `seguimiento` | cubierta | `n-s6-seguimiento_prelim-09` |
| 10 | ¿Prefiere que le avisemos por escrito? | `AVISO_ESCRITO` | C | `seguimiento` | cubierta | `n-s6-seguimiento_prelim-10` |
| 1 | ¿Necesita hablar con el fiscal? | `HABLAR_FISCAL` | C | `seguimiento` | cubierta con dactilología | `n-s6-interaccion_con_fi-01` |
| 2 | ¿Le indicaron ir a la Fiscalía? | `DERIVACION_FISCALIA` | C | `seguimiento` | cubierta con dactilología | `n-s6-interaccion_con_fi-02` |
| 3 | ¿Recibió una resolución? | `RECIBIR_RESOLUCION` | C | `seguimiento` | cubierta | `n-s6-interaccion_con_fi-03` |
| 4 | ¿Debe presentarse ante un juez? | `JUEZ` | C | `seguimiento` | cubierta | `n-s6-interaccion_con_fi-04` |
| 5 | ¿Sabe dónde está el Órgano Judicial? | `ORGANO_JUDICIAL` | C | `seguimiento` | cubierta | `n-s6-interaccion_con_fi-05` |
| 6 | ¿Necesita intérprete para esa reunión? | `INTERPRETE_REUNION` | C | `seguimiento` | cubierta | `n-s6-interaccion_con_fi-06` |
| 7 | ¿Quiere leer el papel antes de escribir su nombre? | `LECTURA_ANTES_FIRMA` | C | `seguimiento` | cubierta | `n-s6-interaccion_con_fi-07` |
| 8 | ¿Está de acuerdo con lo escrito? | `CONFORMIDAD` | C | `seguimiento` | cubierta | `n-s6-interaccion_con_fi-08` |

## Sección 7 — preguntas del ciudadano sordo (60)

| # | Frase en español | Intención | Modos | Ámbito | Estado | Nodo |
|---|---|---|---|---|---|---|
| 1 | ¿Aquí hay intérprete de LSB? | `SIN_INTENCION` | A/B | `identificacion` | cubierta | `n-s7-acceso_y_comunicac-01` |
| 2 | ¿Puede escribir lo que me pregunta? | `SIN_INTENCION` | A/B | `identificacion` | cubierta | `n-s7-acceso_y_comunicac-02` |
| 3 | ¿Puede hablar más despacio? | `SIN_INTENCION` | A/B | `identificacion` | cubierta | `n-s7-acceso_y_comunicac-03` |
| 4 | ¿Puede mostrarme otra vez? | `SIN_INTENCION` | A/B | `identificacion` | cubierta | `n-s7-acceso_y_comunicac-04` |
| 5 | ¿Puedo leer primero? | `SIN_INTENCION` | A/B | `identificacion` | cubierta | `n-s7-acceso_y_comunicac-05` |
| 6 | ¿Me entiende? | `SIN_INTENCION` | A/B | `identificacion` | cubierta | `n-s7-acceso_y_comunicac-06` |
| 7 | ¿Puedo venir con mi intérprete? | `SIN_INTENCION` | A/B | `identificacion` | cubierta | `n-s7-acceso_y_comunicac-07` |
| 8 | ¿Pueden avisarme por mensaje escrito? | `SIN_INTENCION` | A/B | `identificacion` | cubierta | `n-s7-acceso_y_comunicac-08` |
| 1 | ¿Puedo presentar mi denuncia aquí? | `SIN_INTENCION` | A/B | `denuncia_robo` | cubierta con dactilología | `n-s7-denuncia_y_relato-01` |
| 2 | ¿Quién va a recibir mi denuncia? | `SIN_INTENCION` | A/B | `denuncia_robo` | cubierta con dactilología | `n-s7-denuncia_y_relato-02` |
| 3 | ¿Tengo que contar todo ahora? | `SIN_INTENCION` | A/B | `denuncia_robo` | cubierta | `n-s7-denuncia_y_relato-03` |
| 4 | ¿Puedo explicar despacio? | `SIN_INTENCION` | A/B | `denuncia_robo` | cubierta | `n-s7-denuncia_y_relato-04` |
| 5 | ¿Puedo agregar información después? | `SIN_INTENCION` | A/B | `denuncia_robo` | cubierta | `n-s7-denuncia_y_relato-05` |
| 6 | ¿Puedo corregir algo si está mal escrito? | `SIN_INTENCION` | A/B | `denuncia_robo` | cubierta | `n-s7-denuncia_y_relato-06` |
| 7 | ¿Puedo leer lo escrito antes de poner mi nombre? | `SIN_INTENCION` | A/B | `denuncia_robo` | cubierta | `n-s7-denuncia_y_relato-07` |
| 8 | ¿Me dan una copia? | `SIN_INTENCION` | A/B | `denuncia_robo` | cubierta | `n-s7-denuncia_y_relato-08` |
| 1 | ¿Pueden buscar mi celular? | `SIN_INTENCION` | A/B | `denuncia_robo` | cubierta | `n-s7-robo_y_objetos-01` |
| 2 | ¿Traigo la factura del celular? | `SIN_INTENCION` | A/B | `denuncia_robo` | cubierta | `n-s7-robo_y_objetos-02` |
| 3 | ¿Traigo la caja del celular? | `SIN_INTENCION` | A/B | `denuncia_robo` | cubierta | `n-s7-robo_y_objetos-03` |
| 4 | ¿Dónde entrego las fotos? | `SIN_INTENCION` | A/B | `denuncia_robo` | cubierta | `n-s7-robo_y_objetos-04` |
| 5 | ¿Puedo traer el video mañana? | `SIN_INTENCION` | A/B | `denuncia_robo` | cubierta | `n-s7-robo_y_objetos-05` |
| 6 | ¿Puedo agregar otro objeto robado? | `SIN_INTENCION` | A/B | `denuncia_robo` | no soportada | `n-s7-robo_y_objetos-06` |
| 7 | ¿Me avisan si encuentran mi celular? | `SIN_INTENCION` | A/B | `denuncia_robo` | cubierta | `n-s7-robo_y_objetos-07` |
| 8 | ¿La investigación continúa? | `SIN_INTENCION` | A/B | `denuncia_robo` | cubierta | `n-s7-robo_y_objetos-08` |
| 1 | ¿Puedo pedir ayuda ahora? | `SIN_INTENCION` | A/B | `violencia` | cubierta | `n-s7-violencia_amenaza-01` |
| 2 | ¿Pueden ayudarme a estar protegido? | `SIN_INTENCION` | A/B | `violencia` | cubierta | `n-s7-violencia_amenaza-02` |
| 3 | ¿Necesito ir al hospital? | `SIN_INTENCION` | A/B | `violencia` | cubierta | `n-s7-violencia_amenaza-03` |
| 4 | ¿Necesito certificado del doctor? | `SIN_INTENCION` | A/B | `violencia` | cubierta | `n-s7-violencia_amenaza-04` |
| 5 | ¿Dónde entrego el certificado? | `SIN_INTENCION` | A/B | `violencia` | cubierta | `n-s7-violencia_amenaza-05` |
| 6 | ¿Qué hago si vuelve a amenazarme? | `SIN_INTENCION` | A/B | `violencia` | cubierta | `n-s7-violencia_amenaza-06` |
| 7 | ¿Puedo mostrar los mensajes del celular? | `SIN_INTENCION` | A/B | `violencia` | cubierta | `n-s7-violencia_amenaza-07` |
| 8 | ¿SEPDAVI puede ayudarme? | `SIN_INTENCION` | A/B | `violencia` | cubierta con dactilología | `n-s7-violencia_amenaza-08` |
| 1 | ¿Puedo traer al testigo mañana? | `SIN_INTENCION` | A/B | `otro` | cubierta | `n-s7-testigos_y_evidenc-01` |
| 2 | ¿El testigo necesita su carnet? | `SIN_INTENCION` | A/B | `otro` | cubierta | `n-s7-testigos_y_evidenc-02` |
| 3 | ¿Puedo enviar las fotos? | `SIN_INTENCION` | A/B | `otro` | cubierta | `n-s7-testigos_y_evidenc-03` |
| 4 | ¿Puedo mostrar el video desde mi celular? | `SIN_INTENCION` | A/B | `otro` | cubierta | `n-s7-testigos_y_evidenc-04` |
| 5 | ¿Necesito fotocopias? | `SIN_INTENCION` | A/B | `otro` | cubierta | `n-s7-testigos_y_evidenc-05` |
| 6 | ¿Me dan un papel con sello? | `SIN_INTENCION` | A/B | `otro` | cubierta | `n-s7-testigos_y_evidenc-06` |
| 7 | ¿Puedo presentar un certificado después? | `SIN_INTENCION` | A/B | `otro` | cubierta | `n-s7-testigos_y_evidenc-07` |
| 8 | ¿Qué más tengo que traer? | `SIN_INTENCION` | A/B | `otro` | cubierta | `n-s7-testigos_y_evidenc-08` |
| 1 | ¿Quién investiga mi denuncia? | `SIN_INTENCION` | A/B | `seguimiento` | cubierta con dactilología | `n-s7-consulta_y_seguimi-01` |
| 2 | ¿Puedo hablar con el policía encargado? | `SIN_INTENCION` | A/B | `seguimiento` | cubierta | `n-s7-consulta_y_seguimi-02` |
| 3 | ¿Cuándo vuelvo? | `SIN_INTENCION` | A/B | `seguimiento` | cubierta | `n-s7-consulta_y_seguimi-03` |
| 4 | ¿Cuánto tiempo debo esperar? | `SIN_INTENCION` | A/B | `seguimiento` | cubierta | `n-s7-consulta_y_seguimi-04` |
| 5 | ¿Me van a avisar? | `SIN_INTENCION` | A/B | `seguimiento` | cubierta | `n-s7-consulta_y_seguimi-05` |
| 6 | ¿Pueden escribirme al celular? | `SIN_INTENCION` | A/B | `seguimiento` | cubierta | `n-s7-consulta_y_seguimi-06` |
| 7 | ¿La investigación ya terminó? | `SIN_INTENCION` | A/B | `seguimiento` | cubierta | `n-s7-consulta_y_seguimi-07` |
| 8 | ¿Encontraron a la persona? | `SIN_INTENCION` | A/B | `seguimiento` | cubierta | `n-s7-consulta_y_seguimi-08` |
| 9 | ¿Puedo cambiar mi dirección? | `SIN_INTENCION` | A/B | `seguimiento` | cubierta | `n-s7-consulta_y_seguimi-09` |
| 10 | ¿Puedo cambiar mi número de celular? | `SIN_INTENCION` | A/B | `seguimiento` | cubierta | `n-s7-consulta_y_seguimi-10` |
| 1 | ¿Dónde está la Fiscalía? | `SIN_INTENCION` | A/B | `seguimiento` | cubierta con dactilología | `n-s7-fiscalia_asistenc-01` |
| 2 | ¿Tengo que ir a la Fiscalía? | `SIN_INTENCION` | A/B | `seguimiento` | cubierta con dactilología | `n-s7-fiscalia_asistenc-02` |
| 3 | ¿Puedo hablar con el fiscal? | `SIN_INTENCION` | A/B | `seguimiento` | cubierta con dactilología | `n-s7-fiscalia_asistenc-03` |
| 4 | ¿Necesito abogado? | `SIN_INTENCION` | A/B | `seguimiento` | cubierta | `n-s7-fiscalia_asistenc-04` |
| 5 | ¿Hay abogado gratis? | `SIN_INTENCION` | A/B | `seguimiento` | cubierta | `n-s7-fiscalia_asistenc-05` |
| 6 | ¿SEPDEP puede darme defensa gratuita? | `SIN_INTENCION` | A/B | `seguimiento` | cubierta con dactilología | `n-s7-fiscalia_asistenc-06` |
| 7 | ¿SEPDAVI puede orientarme? | `SIN_INTENCION` | A/B | `seguimiento` | cubierta con dactilología | `n-s7-fiscalia_asistenc-07` |
| 8 | ¿Dónde está el Órgano Judicial? | `SIN_INTENCION` | A/B | `seguimiento` | cubierta | `n-s7-fiscalia_asistenc-08` |
| 9 | ¿Tengo que presentarme ante un juez? | `SIN_INTENCION` | A/B | `seguimiento` | cubierta | `n-s7-fiscalia_asistenc-09` |
| 10 | ¿Necesito intérprete para hablar con el juez? | `SIN_INTENCION` | A/B | `seguimiento` | cubierta | `n-s7-fiscalia_asistenc-10` |

## Sección 8 — declaraciones y respuestas (51)

| # | Frase en español | Intención | Modos | Ámbito | Estado | Nodo |
|---|---|---|---|---|---|---|
| 1 | Soy sordo y necesito intérprete. | `SIN_INTENCION` | A/B/C | `otro` | cubierta | `n-s8-declaraciones_y_re-01` |
| 2 | Leo poco; prefiero LSB. | `SIN_INTENCION` | A/B/C | `otro` | cubierta | `n-s8-declaraciones_y_re-02` |
| 3 | Quiero presentar una denuncia. | `SIN_INTENCION` | A/B/C | `otro` | cubierta con dactilología | `n-s8-declaraciones_y_re-03` |
| 4 | Quiero explicar lo que pasó desde el principio. | `SIN_INTENCION` | A/B/C | `otro` | cubierta | `n-s8-declaraciones_y_re-04` |
| 5 | Ayer por la tarde ocurrió. | `SIN_INTENCION` | A/B/C | `otro` | cubierta | `n-s8-declaraciones_y_re-05` |
| 6 | No recuerdo la hora exacta. | `SIN_INTENCION` | A/B/C | `otro` | cubierta | `n-s8-declaraciones_y_re-06` |
| 7 | Ocurrió en la calle cerca del mercado. | `SIN_INTENCION` | A/B/C | `otro` | cubierta | `n-s8-declaraciones_y_re-07` |
| 8 | No conozco a la persona. | `SIN_INTENCION` | A/B/C | `otro` | cubierta | `n-s8-declaraciones_y_re-08` |
| 9 | Si la vuelvo a ver, puedo identificarla. | `SIN_INTENCION` | A/B/C | `otro` | cubierta | `n-s8-declaraciones_y_re-09` |
| 10 | Vi a un hombre joven con mochila. | `SIN_INTENCION` | A/B/C | `otro` | cubierta | `n-s8-declaraciones_y_re-10` |
| 11 | Me robaron el celular. | `SIN_INTENCION` | A/B/C | `otro` | cubierta | `n-s8-declaraciones_y_re-11` |
| 12 | También perdí mi carnet. | `SIN_INTENCION` | A/B/C | `otro` | cubierta | `n-s8-declaraciones_y_re-12` |
| 13 | Tengo la factura del celular. | `SIN_INTENCION` | A/B/C | `otro` | cubierta | `n-s8-declaraciones_y_re-13` |
| 14 | Hay un testigo. | `SIN_INTENCION` | A/B/C | `otro` | cubierta | `n-s8-declaraciones_y_re-14` |
| 15 | El testigo vio todo. | `SIN_INTENCION` | A/B/C | `otro` | cubierta | `n-s8-declaraciones_y_re-15` |
| 16 | Tengo fotos en mi celular. | `SIN_INTENCION` | A/B/C | `otro` | cubierta | `n-s8-declaraciones_y_re-16` |
| 17 | Tengo un video. | `SIN_INTENCION` | A/B/C | `otro` | cubierta | `n-s8-declaraciones_y_re-17` |
| 18 | Un hombre me pegó. | `SIN_INTENCION` | A/B/C | `otro` | cubierta | `n-s8-declaraciones_y_re-18` |
| 19 | Tengo una herida en el brazo. | `SIN_INTENCION` | A/B/C | `otro` | cubierta | `n-s8-declaraciones_y_re-19` |
| 20 | Fui al hospital. | `SIN_INTENCION` | A/B/C | `otro` | cubierta | `n-s8-declaraciones_y_re-20` |
| 21 | Tengo certificado del doctor. | `SIN_INTENCION` | A/B/C | `otro` | cubierta | `n-s8-declaraciones_y_re-21` |
| 22 | Mi expareja me amenaza. | `SIN_INTENCION` | A/B/C | `otro` | cubierta | `n-s8-declaraciones_y_re-22` |
| 23 | Tengo miedo de volver a mi casa. | `SIN_INTENCION` | A/B/C | `otro` | cubierta | `n-s8-declaraciones_y_re-23` |
| 24 | Necesito auxilio ahora. | `SIN_INTENCION` | A/B/C | `otro` | cubierta | `n-s8-declaraciones_y_re-24` |
| 25 | Guardé todos los mensajes. | `SIN_INTENCION` | A/B/C | `otro` | cubierta | `n-s8-declaraciones_y_re-25` |
| 26 | Tengo fotos de la pantalla. | `SIN_INTENCION` | A/B/C | `otro` | cubierta | `n-s8-declaraciones_y_re-26` |
| 27 | Me engañaron con dinero. | `SIN_INTENCION` | A/B/C | `otro` | cubierta | `n-s8-declaraciones_y_re-27` |
| 28 | Envié dinero por el banco. | `SIN_INTENCION` | A/B/C | `otro` | cubierta | `n-s8-declaraciones_y_re-28` |
| 29 | Tengo el papel del banco. | `SIN_INTENCION` | A/B/C | `otro` | cubierta | `n-s8-declaraciones_y_re-29` |
| 30 | Dañaron la puerta de mi tienda. | `SIN_INTENCION` | A/B/C | `otro` | cubierta | `n-s8-declaraciones_y_re-30` |
| 31 | Tengo el video de la cámara. | `SIN_INTENCION` | A/B/C | `otro` | cubierta | `n-s8-declaraciones_y_re-31` |
| 32 | Vi lo ocurrido y puedo dar testimonio. | `SIN_INTENCION` | A/B/C | `otro` | cubierta | `n-s8-declaraciones_y_re-32` |
| 33 | Quiero agregar información. | `SIN_INTENCION` | A/B/C | `otro` | cubierta | `n-s8-declaraciones_y_re-33` |
| 34 | Aquí hay un error en mi nombre. | `SIN_INTENCION` | A/B/C | `otro` | cubierta | `n-s8-declaraciones_y_re-34` |
| 35 | Quiero leer antes de escribir mi nombre. | `SIN_INTENCION` | A/B/C | `otro` | cubierta | `n-s8-declaraciones_y_re-35` |
| 36 | Prefiero recibir mensajes escritos. | `SIN_INTENCION` | A/B/C | `otro` | cubierta | `n-s8-declaraciones_y_re-36` |
| 37 | Cambié de dirección. | `SIN_INTENCION` | A/B/C | `otro` | cubierta | `n-s8-declaraciones_y_re-37` |
| 38 | Cambié de número de celular. | `SIN_INTENCION` | A/B/C | `otro` | cubierta | `n-s8-declaraciones_y_re-38` |
| 39 | Quiero saber si la investigación continúa. | `SIN_INTENCION` | A/B/C | `otro` | cubierta | `n-s8-declaraciones_y_re-39` |
| 40 | Necesito un abogado. | `SIN_INTENCION` | A/B/C | `otro` | cubierta | `n-s8-declaraciones_y_re-40` |
| 41 | No tengo dinero para un abogado. | `SIN_INTENCION` | A/B/C | `otro` | cubierta | `n-s8-declaraciones_y_re-41` |
| 42 | Quiero asistencia de SEPDAVI. | `SIN_INTENCION` | A/B/C | `otro` | cubierta con dactilología | `n-s8-declaraciones_y_re-42` |
| 43 | Necesito defensa pública. | `SIN_INTENCION` | A/B/C | `otro` | cubierta con dactilología | `n-s8-declaraciones_y_re-43` |
| 44 | Me dijeron que debo ir a la Fiscalía. | `SIN_INTENCION` | A/B/C | `otro` | cubierta con dactilología | `n-s8-declaraciones_y_re-44` |
| 45 | Recibí una resolución. | `SIN_INTENCION` | A/B/C | `otro` | cubierta | `n-s8-declaraciones_y_re-45` |
| 46 | Tengo que presentarme ante un juez. | `SIN_INTENCION` | A/B/C | `otro` | cubierta | `n-s8-declaraciones_y_re-46` |
| 47 | Necesito intérprete para hablar con el juez. | `SIN_INTENCION` | A/B/C | `otro` | cubierta | `n-s8-declaraciones_y_re-47` |
| 48 | No entiendo este papel. | `SIN_INTENCION` | A/B/C | `otro` | cubierta | `n-s8-declaraciones_y_re-48` |
| 49 | Explíqueme despacio, por favor. | `SIN_INTENCION` | A/B/C | `otro` | cubierta | `n-s8-declaraciones_y_re-49` |
| 50 | Ahora sí entiendo. | `SIN_INTENCION` | A/B/C | `otro` | cubierta | `n-s8-declaraciones_y_re-50` |
| 51 | Gracias por su ayuda. | `SIN_INTENCION` | A/B/C | `otro` | cubierta | `n-s8-declaraciones_y_re-51` |
