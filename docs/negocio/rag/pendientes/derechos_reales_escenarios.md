<!-- Borrador generado por tool/rag_ingestar_documentos.py desde documentos/Derechos_Reales.pdf (huella: 9ebcaddc7f9150009c01b49e2cb7d4092fbcedad9ecdb7944f255e96a453e20c). Revísalo y muévelo a escenarios/ para incorporarlo; después ejecuta tool/rag_actualizar.py. «Escenarios posibles» es una nota narrativa: no crea ramificaciones; decláralas en «### Ramificaciones». -->
# Escenarios desde Derechos_Reales.pdf

## Fuentes
| ID | Institución | Título | URL | Consultado |
|---|---|---|---|---|
| F-DDRR-05 | Derechos Reales | Catálogo oficial de trámites en Derechos Reales | https://tramitesddrr.organojudicial.gob.bo/ | 2026-10-01 |
| F-DDRR-06 | Derechos Reales | Folio Real actualizado - requisitos publicados | https://cm.organojudicial.gob.bo/consejo/requisitosddrr/42_-folio-real-actualizado.html | 2026-10-01 |
| F-DDRR-07 | Derechos Reales | Certificado de gravámenes - manual publicado | https://cm.organojudicial.gob.bo/consejo/manualprocedimientosddrr/46_-certificado-de-gravamenes.html | 2026-10-01 |
| F-DDRR-08 | Derechos Reales | Compra venta - manual publicado | https://cm.organojudicial.gob.bo/consejo/manualprocedimientosddrr/4_-compra-venta.html | 2026-10-01 |
| F-DDRR-09 | Derechos Reales | Certificado alodial - requisitos publicados | https://cm.organojudicial.gob.bo/consejo/requisitosddrr/45_-certificado-alodial.html | 2026-10-01 |
| F-DDRR-10 | Derechos Reales | Consulta pública de estado de documentos | https://magistratura.organojudicial.gob.bo/consultaddrr/index.php?r=consulta/index | 2026-10-01 |

## Hechos verificados
| ID | Institución | Hecho | Tipo | Fuente | Vigencia |
|---|---|---|---|---|---|

## ESC-DDRR-05 — Folio Real actualizado: titular y matrícula

- **Institución:** Derechos Reales – Cochabamba
- **Trámite:** Folio Real actualizado: titular y matrícula
- **Tipo:** mixto
- **Inicia:** Usuario Sordo
- **Situación:** La persona solicita un Folio Real actualizado y necesita identificar el inmueble. No se presupone que sea titular.
- **Referencia:** F-DDRR-06
- **Documento:** documentos/Derechos_Reales.pdf#p=3

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Usuario Sordo | ¿Puedo solicitar el Folio Real actualizado de mi casa? | — | — |
| 2 | Funcionario | ¿La casa está registrada a su nombre? | — | — |
| 3 | Usuario Sordo | Sí, la casa está registrada a mi nombre. | — | — |
| 4 | Funcionario | ¿Tiene el número de matrícula de la casa? | — | — |
| 5 | Usuario Sordo | Sí, tengo la matrícula de la casa. | — | — |
| 6 | Funcionario | ¿Trajo su cédula de identidad? | — | — |
| 7 | Usuario Sordo | Sí, aquí tengo mi cédula de identidad. | — | — |
| 8 | Usuario Sordo | ¿Qué documento me falta para solicitar el Folio Real? | — | — |

### Variantes

- **Turno 2 (Funcionario):** «¿Usted figura como titular de la casa?» · «¿Su nombre aparece como propietario de la casa?»
- **Respuestas:** «Sí, la casa está registrada a mi nombre.» · «No, la casa está registrada a otro nombre.» · «No sé a nombre de quién está registrada.»
- **Turno 4 (Funcionario):** «¿Conoce la matrícula registral de la casa?» · «¿Puede mostrar la matrícula de esa casa?»
- **Respuestas:** «Sí, tengo la matrícula de la casa.» · «No, no tengo la matrícula de la casa.» · «No sé dónde encontrar la matrícula.»
- **Turno 6 (Funcionario):** «¿Tiene su cédula de identidad con usted?» · «¿Puede mostrar su cédula de identidad?»
- **Respuestas:** «Sí, aquí tengo mi cédula de identidad.» · «No, no traje mi cédula de identidad.» · «No sé si esta copia de mi cédula sirve.»

### Escenarios posibles

Nota narrativa del documento (no crea ramificaciones): Titular identificado: consultar la documentación aplicable. Otro titular o titular desconocido: aclarar la relación con el inmueble. Matrícula ausente: pasar a ESC-DDRR-06.

## ESC-DDRR-06 — No conoce la matrícula del inmueble

- **Institución:** Derechos Reales – Cochabamba
- **Trámite:** No conoce la matrícula del inmueble
- **Tipo:** mixto
- **Inicia:** Funcionario
- **Situación:** La persona no recuerda la matrícula y busca orientación para localizarla. No se garantiza una búsqueda por dirección o por nombre.
- **Referencia:** F-DDRR-05
- **Documento:** documentos/Derechos_Reales.pdf#p=4

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Funcionario | ¿Tiene algún Folio Real anterior del inmueble? | — | — |
| 2 | Usuario Sordo | Sí, tengo un Folio Real anterior. | — | — |
| 3 | Usuario Sordo | ¿Dónde encuentro la matrícula de mi inmueble? | — | — |
| 4 | Funcionario | ¿Trajo la escritura pública del inmueble? | — | — |
| 5 | Usuario Sordo | Sí, tengo la escritura pública del inmueble. | — | — |
| 6 | Funcionario | ¿Conoce el nombre del titular registrado? | — | — |
| 7 | Usuario Sordo | Sí, conozco el nombre del titular registrado. | — | — |
| 8 | Usuario Sordo | ¿Qué documento puedo mostrar para localizar la matrícula? | — | — |

### Variantes

- **Turno 1 (Funcionario):** «¿Conserva un Folio Real antiguo del inmueble?» · «¿Puede mostrar el Folio Real anterior del inmueble?»
- **Respuestas:** «Sí, tengo un Folio Real anterior.» · «No, no conservo un Folio Real anterior.» · «No sé cuál documento es el Folio Real.»
- **Turno 4 (Funcionario):** «¿Tiene la escritura pública de ese inmueble?» · «¿Puede mostrar el testimonio de la escritura del inmueble?»
- **Respuestas:** «Sí, tengo la escritura pública del inmueble.» · «No, no traje la escritura pública del inmueble.» · «No sé cuál es la escritura pública.»
- **Turno 6 (Funcionario):** «¿Sabe quién figura como titular del inmueble?» · «¿Recuerda el nombre del propietario registrado?»
- **Respuestas:** «Sí, conozco el nombre del titular registrado.» · «No, no conozco al titular registrado.» · «No sé quién figura como titular.»

### Escenarios posibles

Nota narrativa del documento (no crea ramificaciones): Existe un documento anterior: pedir orientación para identificar el dato. Sin documentos: consultar cómo acreditar la solicitud. Titular desconocido: mantener esa información como desconocida.

## ESC-DDRR-07 — Información rápida antes de comprar

- **Institución:** Derechos Reales – Cochabamba
- **Trámite:** Información rápida antes de comprar
- **Tipo:** mixto
- **Inicia:** Usuario Sordo
- **Situación:** Un posible comprador quiere consultar información registral de una casa antes de decidir una compra.
- **Referencia:** F-DDRR-05
- **Documento:** documentos/Derechos_Reales.pdf#p=5

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Usuario Sordo | ¿Puedo pedir información rápida de esta casa? | — | — |
| 2 | Funcionario | ¿La información es sobre una casa que piensa comprar? | — | — |
| 3 | Usuario Sordo | Sí, quiero consultar antes de comprar la casa. | — | — |
| 4 | Funcionario | ¿Tiene la matrícula de la casa que consulta? | — | — |
| 5 | Usuario Sordo | Sí, tengo la matrícula de esa casa. | — | — |
| 6 | Funcionario | ¿Trajo un documento que identifique esa casa? | — | — |
| 7 | Usuario Sordo | Sí, traje un documento de esa casa. | — | — |
| 8 | Usuario Sordo | ¿Qué datos puedo consultar con la información rápida? | — | — |

### Variantes

- **Turno 2 (Funcionario):** «¿Quiere consultar una casa antes de comprarla?» · «¿Está consultando como posible comprador de esa casa?»
- **Respuestas:** «Sí, quiero consultar antes de comprar la casa.» · «No, quiero información de mi propia casa.» · «No sé si compraré la casa todavía.»
- **Turno 4 (Funcionario):** «¿Conoce la matrícula registral de esa casa?» · «¿Puede mostrar la matrícula de la casa consultada?»
- **Respuestas:** «Sí, tengo la matrícula de esa casa.» · «No, no tengo la matrícula de esa casa.» · «No sé si este número es la matrícula.»
- **Turno 6 (Funcionario):** «¿Tiene un documento registral de la casa consultada?» · «¿Puede mostrar el documento de esa casa?»
- **Respuestas:** «Sí, traje un documento de esa casa.» · «No, no tengo documentos de esa casa.» · «No sé si el documento corresponde a esa casa.»

### Escenarios posibles

Nota narrativa del documento (no crea ramificaciones): Matrícula y documento coinciden: pedir la consulta que corresponda. Documento dudoso: confirmar el inmueble antes de consultar. Sin matrícula: pasar a ESC-DDRR-06.

## ESC-DDRR-08 — Certificado de gravámenes: hipoteca o anticresis

- **Institución:** Derechos Reales – Cochabamba
- **Trámite:** Certificado de gravámenes: hipoteca o anticresis
- **Tipo:** mixto
- **Inicia:** Funcionario
- **Situación:** La persona necesita saber qué gravámenes aparecen registrados. Ninguna respuesta afirma si el inmueble tiene una carga.
- **Referencia:** F-DDRR-07
- **Documento:** documentos/Derechos_Reales.pdf#p=6

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Funcionario | ¿Quiere consultar una posible hipoteca de la casa? | — | — |
| 2 | Usuario Sordo | Sí, quiero consultar una posible hipoteca de la casa. | — | — |
| 3 | Usuario Sordo | ¿Cómo solicito el certificado de gravámenes de mi casa? | — | — |
| 4 | Funcionario | ¿Tiene la matrícula del inmueble para esta consulta? | — | — |
| 5 | Usuario Sordo | Sí, tengo la matrícula del inmueble. | — | — |
| 6 | Funcionario | ¿Trajo su cédula para identificar la solicitud? | — | — |
| 7 | Usuario Sordo | Sí, traje mi cédula de identidad. | — | — |
| 8 | Usuario Sordo | ¿Dónde puedo consultar los gravámenes registrados de mi casa? | — | — |

### Variantes

- **Turno 1 (Funcionario):** «¿Su consulta es sobre una hipoteca de la casa?» · «¿Necesita información de una hipoteca sobre esa casa?»
- **Respuestas:** «Sí, quiero consultar una posible hipoteca de la casa.» · «No, quiero consultar una posible anticresis.» · «No sé qué gravamen podría tener la casa.»
- **Turno 4 (Funcionario):** «¿Conoce la matrícula del inmueble que quiere consultar?» · «¿Puede mostrar la matrícula del inmueble consultado?»
- **Respuestas:** «Sí, tengo la matrícula del inmueble.» · «No, no tengo la matrícula del inmueble.» · «No sé si esta matrícula corresponde al inmueble.»
- **Turno 6 (Funcionario):** «¿Tiene su cédula para esta solicitud?» · «¿Puede mostrar su cédula de identidad en esta consulta?»
- **Respuestas:** «Sí, traje mi cédula de identidad.» · «No, no traje mi cédula de identidad.» · «No sé si esta copia de mi cédula sirve.»

### Escenarios posibles

Nota narrativa del documento (no crea ramificaciones): Hipoteca, anticresis o carga desconocida: conservar la distinción. El resultado registral se consulta en la institución; no se deduce de las respuestas del solicitante.

## ESC-DDRR-09 — Certificado alodial solicitado por el titular

- **Institución:** Derechos Reales – Cochabamba
- **Trámite:** Certificado alodial solicitado por el titular
- **Tipo:** mixto
- **Inicia:** Usuario Sordo
- **Situación:** La persona solicita un certificado alodial. Se identifica al solicitante sin afirmar que el inmueble esté libre de gravámenes.
- **Referencia:** F-DDRR-09
- **Documento:** documentos/Derechos_Reales.pdf#p=7

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Usuario Sordo | ¿Cómo solicito el certificado alodial de mi casa? | — | — |
| 2 | Funcionario | ¿La solicitud del certificado alodial es para su inmueble? | — | — |
| 3 | Usuario Sordo | Sí, solicito el certificado para mi inmueble. | — | — |
| 4 | Funcionario | ¿Tiene el Folio Real de ese inmueble? | — | — |
| 5 | Usuario Sordo | Sí, tengo el Folio Real del inmueble. | — | — |
| 6 | Funcionario | ¿Tiene una solicitud escrita del certificado alodial? | — | — |
| 7 | Usuario Sordo | Sí, tengo la solicitud escrita del certificado. | — | — |
| 8 | Usuario Sordo | ¿Qué documentos debo presentar para solicitar el certificado alodial? | — | — |

### Variantes

- **Turno 2 (Funcionario):** «¿Solicita el certificado alodial de un inmueble suyo?» · «¿El certificado alodial corresponde a su propio inmueble?»
- **Respuestas:** «Sí, solicito el certificado para mi inmueble.» · «No, solicito el certificado para otro titular.» · «No sé quién figura como titular del inmueble.»
- **Turno 4 (Funcionario):** «¿Trajo el Folio Real del inmueble consultado?» · «¿Puede mostrar el Folio Real de ese inmueble?»
- **Respuestas:** «Sí, tengo el Folio Real del inmueble.» · «No, no traje el Folio Real del inmueble.» · «No sé cuál documento es el Folio Real.»
- **Turno 6 (Funcionario):** «¿Trajo una solicitud escrita para el certificado alodial?» · «¿Puede mostrar la solicitud escrita de ese certificado?»
- **Respuestas:** «Sí, tengo la solicitud escrita del certificado.» · «No, no tengo una solicitud escrita.» · «No sé cómo preparar la solicitud escrita.»

### Escenarios posibles

Nota narrativa del documento (no crea ramificaciones): Solicitud propia: confirmar requisitos actuales. Solicitud para otro titular: pasar a ESC-DDRR-34. No interpretar la intención de pedir el certificado como ausencia comprobada de cargas.

## ESC-DDRR-10 — Certificado de no propiedad a nivel nacional

- **Institución:** Derechos Reales – Cochabamba
- **Trámite:** Certificado de no propiedad a nivel nacional
- **Tipo:** mixto
- **Inicia:** Funcionario
- **Situación:** La persona pide orientación para solicitar un certificado de no propiedad de alcance nacional. No se presume el resultado.
- **Referencia:** F-DDRR-05
- **Documento:** documentos/Derechos_Reales.pdf#p=8

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Funcionario | ¿Le solicitaron un certificado de no propiedad nacional? | — | — |
| 2 | Usuario Sordo | Sí, me pidieron el certificado de no propiedad nacional. | — | — |
| 3 | Usuario Sordo | ¿Cómo solicito el certificado de no propiedad nacional? | — | — |
| 4 | Funcionario | ¿El certificado será emitido a su nombre? | — | — |
| 5 | Usuario Sordo | Sí, el certificado será a mi nombre. | — | — |
| 6 | Funcionario | ¿Trajo el documento donde le piden ese certificado? | — | — |
| 7 | Usuario Sordo | Sí, tengo el documento que solicita el certificado. | — | — |
| 8 | Usuario Sordo | ¿Qué necesito para solicitar el certificado de no propiedad nacional? | — | — |

### Variantes

- **Turno 1 (Funcionario):** «¿La institución le pidió un certificado de no propiedad nacional?» · «¿Necesita el certificado de no propiedad a nivel nacional?»
- **Respuestas:** «Sí, me pidieron el certificado de no propiedad nacional.» · «No, me pidieron el certificado departamental.» · «No sé qué alcance debe tener el certificado.»
- **Turno 4 (Funcionario):** «¿Solicita el certificado de no propiedad para usted?» · «¿Usted será la persona identificada en el certificado?»
- **Respuestas:** «Sí, el certificado será a mi nombre.» · «No, el certificado será para otra persona.» · «No sé a nombre de quién debe emitirse.»
- **Turno 6 (Funcionario):** «¿Tiene la solicitud de la institución que pide el certificado?» · «¿Puede mostrar el documento que solicita ese certificado?»
- **Respuestas:** «Sí, tengo el documento que solicita el certificado.» · «No, no tengo una solicitud escrita.» · «No sé cuál documento solicita el certificado.»

### Escenarios posibles

Nota narrativa del documento (no crea ramificaciones): Alcance nacional confirmado: consultar esa modalidad. Alcance departamental: pasar a ESC-DDRR-11. Alcance desconocido: pedir confirmación a quien solicita el documento.

## ESC-DDRR-11 — Certificado de no propiedad departamental

- **Institución:** Derechos Reales – Cochabamba
- **Trámite:** Certificado de no propiedad departamental
- **Tipo:** mixto
- **Inicia:** Usuario Sordo
- **Situación:** La persona debe precisar el departamento y el alcance del certificado solicitado, sin confundirlo con una búsqueda nacional.
- **Referencia:** F-DDRR-05
- **Documento:** documentos/Derechos_Reales.pdf#p=9

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Usuario Sordo | ¿Cómo solicito el certificado de no propiedad departamental? | — | — |
| 2 | Funcionario | ¿Necesita el certificado de no propiedad de Cochabamba? | — | — |
| 3 | Usuario Sordo | Sí, necesito el certificado de no propiedad de Cochabamba. | — | — |
| 4 | Funcionario | ¿Le indicaron que el alcance debe ser departamental? | — | — |
| 5 | Usuario Sordo | Sí, la solicitud indica alcance departamental. | — | — |
| 6 | Funcionario | ¿Trajo su cédula para identificar el certificado? | — | — |
| 7 | Usuario Sordo | Sí, tengo mi cédula de identidad. | — | — |
| 8 | Usuario Sordo | ¿Este certificado corresponde al departamento que me solicitaron? | — | — |

### Variantes

- **Turno 2 (Funcionario):** «¿Le pidieron el certificado de no propiedad para Cochabamba?» · «¿El departamento indicado para ese certificado es Cochabamba?»
- **Respuestas:** «Sí, necesito el certificado de no propiedad de Cochabamba.» · «No, necesito el certificado de otro departamento.» · «No sé qué departamento debe consultar el certificado.»
- **Turno 4 (Funcionario):** «¿La solicitud indica un alcance departamental?» · «¿El documento pedido es departamental y no nacional?»
- **Respuestas:** «Sí, la solicitud indica alcance departamental.» · «No, la solicitud indica alcance nacional.» · «No sé cuál es el alcance solicitado.»
- **Turno 6 (Funcionario):** «¿Tiene su cédula para la solicitud de ese certificado?» · «¿Puede mostrar su cédula de identidad para esta solicitud?»
- **Respuestas:** «Sí, tengo mi cédula de identidad.» · «No, no traje mi cédula de identidad.» · «No sé si mi documento está vigente.»

### Escenarios posibles

Nota narrativa del documento (no crea ramificaciones): Cochabamba confirmado: consultar el servicio departamental. Otro departamento: pedir orientación sobre jurisdicción. Alcance nacional: pasar a ESC-DDRR-10.

## ESC-DDRR-12 — Certificado de propiedad

- **Institución:** Derechos Reales – Cochabamba
- **Trámite:** Certificado de propiedad
- **Tipo:** mixto
- **Inicia:** Funcionario
- **Situación:** La persona necesita un certificado de propiedad y debe diferenciarlo del Folio Real y del certificado de no propiedad.
- **Referencia:** F-DDRR-05
- **Documento:** documentos/Derechos_Reales.pdf#p=10

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Funcionario | ¿Le pidieron específicamente un certificado de propiedad? | — | — |
| 2 | Usuario Sordo | Sí, me pidieron un certificado de propiedad. | — | — |
| 3 | Usuario Sordo | ¿Cómo solicito el certificado de propiedad de mi inmueble? | — | — |
| 4 | Funcionario | ¿Tiene un documento del inmueble que debe certificarse? | — | — |
| 5 | Usuario Sordo | Sí, tengo un documento del inmueble. | — | — |
| 6 | Funcionario | ¿Usted figura como titular en el documento? | — | — |
| 7 | Usuario Sordo | Sí, mi nombre aparece como titular. | — | — |
| 8 | Usuario Sordo | ¿Me pidieron certificado de propiedad o Folio Real? | — | — |

### Variantes

- **Turno 1 (Funcionario):** «¿El documento solicitado se llama certificado de propiedad?» · «¿La solicitud indica certificado de propiedad?»
- **Respuestas:** «Sí, me pidieron un certificado de propiedad.» · «No, me pidieron un Folio Real actualizado.» · «No sé cuál de esos documentos me pidieron.»
- **Turno 4 (Funcionario):** «¿Trajo un documento que identifique ese inmueble?» · «¿Puede mostrar el documento registral del inmueble consultado?»
- **Respuestas:** «Sí, tengo un documento del inmueble.» · «No, no tengo documentos del inmueble.» · «No sé si este documento identifica el inmueble.»
- **Turno 6 (Funcionario):** «¿Su nombre aparece como titular en ese documento?» · «¿El titular indicado en ese documento es usted?»
- **Respuestas:** «Sí, mi nombre aparece como titular.» · «No, aparece el nombre de otra persona.» · «No sé quién figura como titular.»

### Escenarios posibles

Nota narrativa del documento (no crea ramificaciones): Certificado de propiedad confirmado: consultar ese servicio. Folio actualizado: pasar a ESC-DDRR-05. Nombre de documento desconocido: aclararlo antes de sugerir un trámite.

## ESC-DDRR-13 — Inscripción de compra venta con documento incompleto

- **Institución:** Derechos Reales – Cochabamba
- **Trámite:** Inscripción de compra venta con documento incompleto
- **Tipo:** conocimiento_fijo
- **Inicia:** Usuario Sordo
- **Situación:** La persona compró un inmueble y busca registrar la compra venta. Se pregunta por documentos disponibles, sin fijar una lista de requisitos.
- **Referencia:** F-DDRR-08
- **Documento:** documentos/Derechos_Reales.pdf#p=11

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Usuario Sordo | ¿Cómo registro la compra de mi casa? | — | — |
| 2 | Funcionario | ¿Tiene la escritura pública de compra venta? | — | — |
| 3 | Usuario Sordo | Sí, tengo la escritura pública de compra venta. | — | — |
| 4 | Funcionario | ¿Trajo documentación del pago del impuesto a la transferencia? | — | — |
| 5 | Usuario Sordo | Sí, tengo el comprobante del impuesto a la transferencia. | — | — |
| 6 | Funcionario | ¿Tiene un documento catastral de la casa? | — | — |
| 7 | Usuario Sordo | Sí, tengo un documento catastral de la casa. | — | — |
| 8 | Usuario Sordo | ¿Qué documento me falta para registrar la compra venta? | — | — |

### Variantes

- **Turno 2 (Funcionario):** «¿Trajo el testimonio de la escritura pública de compra venta?» · «¿Puede mostrar la escritura pública de la compra?»
- **Respuestas:** «Sí, tengo la escritura pública de compra venta.» · «No, todavía no tengo la escritura pública.» · «No sé si este contrato es una escritura pública.»
- **Turno 4 (Funcionario):** «¿Tiene el comprobante del impuesto a la transferencia?» · «¿Puede mostrar el documento tributario de la transferencia?»
- **Respuestas:** «Sí, tengo el comprobante del impuesto a la transferencia.» · «No, no tengo el comprobante de ese impuesto.» · «No sé cuál es el comprobante del impuesto.»
- **Turno 6 (Funcionario):** «¿Trajo un documento catastral del inmueble comprado?» · «¿Puede mostrar la documentación catastral de esa casa?»
- **Respuestas:** «Sí, tengo un documento catastral de la casa.» · «No, no tengo un documento catastral de la casa.» · «No sé si este documento catastral está actualizado.»

### Escenarios posibles

Nota narrativa del documento (no crea ramificaciones): Documentos disponibles: pedir revisión. Documento ausente o dudoso: preguntar cómo obtenerlo o corregirlo. No equiparar contrato privado con escritura pública.

## ESC-DDRR-14 — Inscripción de aceptación de herencia

- **Institución:** Derechos Reales – Cochabamba
- **Trámite:** Inscripción de aceptación de herencia
- **Tipo:** conocimiento_fijo
- **Inicia:** Funcionario
- **Situación:** La persona solicita registrar una herencia. Debe distinguir la aceptación documentada de una intención todavía no formalizada.
- **Referencia:** F-DDRR-05
- **Documento:** documentos/Derechos_Reales.pdf#p=12

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Funcionario | ¿Tiene el documento de aceptación de herencia? | — | — |
| 2 | Usuario Sordo | Sí, tengo el documento de aceptación de herencia. | — | — |
| 3 | Usuario Sordo | ¿Cómo registro el inmueble que recibí por herencia? | — | — |
| 4 | Funcionario | ¿El documento de herencia identifica ese inmueble? | — | — |
| 5 | Usuario Sordo | Sí, el documento identifica el inmueble heredado. | — | — |
| 6 | Funcionario | ¿La herencia corresponde a varios herederos? | — | — |
| 7 | Usuario Sordo | Sí, hay otros herederos en el documento. | — | — |
| 8 | Usuario Sordo | ¿Qué documentos debo presentar para registrar la herencia? | — | — |

### Variantes

- **Turno 1 (Funcionario):** «¿Trajo el documento que acredita la aceptación de herencia?» · «¿Puede mostrar el documento de aceptación de esa herencia?»
- **Respuestas:** «Sí, tengo el documento de aceptación de herencia.» · «No, todavía no tengo ese documento.» · «No sé si este documento acredita la aceptación.»
- **Turno 4 (Funcionario):** «¿Ese inmueble aparece en el documento de herencia?» · «¿La documentación de herencia corresponde al inmueble consultado?»
- **Respuestas:** «Sí, el documento identifica el inmueble heredado.» · «No, ese inmueble no aparece en el documento.» · «No sé si el documento incluye ese inmueble.»
- **Turno 6 (Funcionario):** «¿Hay otros herederos mencionados en el documento?» · «¿El documento de herencia incluye más herederos?»
- **Respuestas:** «Sí, hay otros herederos en el documento.» · «No, el documento solo me menciona a mí.» · «No sé quiénes figuran como herederos.»

### Escenarios posibles

Nota narrativa del documento (no crea ramificaciones): Aceptación documentada: pedir revisión registral. Documento ausente: consultar cómo formalizarlo. Varios herederos: conservar esa condición y consultar el registro correspondiente.

## ESC-DDRR-15 — Registro de transmisión gratuita por donación

- **Institución:** Derechos Reales – Cochabamba
- **Trámite:** Registro de transmisión gratuita por donación
- **Tipo:** conocimiento_fijo
- **Inicia:** Usuario Sordo
- **Situación:** La persona recibió un inmueble por donación y busca orientación sobre su registro, sin confundirlo con una compra venta.
- **Referencia:** F-DDRR-05
- **Documento:** documentos/Derechos_Reales.pdf#p=13

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Usuario Sordo | ¿Cómo registro una casa que recibí por donación? | — | — |
| 2 | Funcionario | ¿Recibió la casa mediante una donación? | — | — |
| 3 | Usuario Sordo | Sí, recibí la casa por donación. | — | — |
| 4 | Funcionario | ¿Tiene la escritura pública de donación? | — | — |
| 5 | Usuario Sordo | Sí, tengo la escritura pública de donación. | — | — |
| 6 | Funcionario | ¿Usted aparece como beneficiario en la escritura? | — | — |
| 7 | Usuario Sordo | Sí, mi nombre aparece como beneficiario. | — | — |
| 8 | Usuario Sordo | ¿Qué documento necesito para registrar la donación? | — | — |

### Variantes

- **Turno 2 (Funcionario):** «¿La transferencia de esa casa fue una donación?» · «¿La casa que quiere registrar fue donada?»
- **Respuestas:** «Sí, recibí la casa por donación.» · «No, compré la casa.» · «No sé qué tipo de transferencia hicieron.»
- **Turno 4 (Funcionario):** «¿Trajo el testimonio de la donación del inmueble?» · «¿Puede mostrar la escritura pública de esa donación?»
- **Respuestas:** «Sí, tengo la escritura pública de donación.» · «No, no tengo la escritura pública de donación.» · «No sé si este documento es una donación.»
- **Turno 6 (Funcionario):** «¿Su nombre figura como beneficiario de la donación?» · «¿La escritura de donación identifica a usted como beneficiario?»
- **Respuestas:** «Sí, mi nombre aparece como beneficiario.» · «No, aparece otra persona como beneficiaria.» · «No sé quién figura como beneficiario.»

### Escenarios posibles

Nota narrativa del documento (no crea ramificaciones): Donación identificada: consultar transmisión gratuita. Compra venta: pasar a ESC-DDRR-13. Tipo de transferencia desconocido: pedir lectura o explicación del documento.

## ESC-DDRR-16 — Registro de anticipo de legítima

- **Institución:** Derechos Reales – Cochabamba
- **Trámite:** Registro de anticipo de legítima
- **Tipo:** conocimiento_fijo
- **Inicia:** Funcionario
- **Situación:** La persona consulta el registro de un anticipo de legítima y necesita identificar lo que dice la escritura.
- **Referencia:** F-DDRR-05
- **Documento:** documentos/Derechos_Reales.pdf#p=14

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Funcionario | ¿La escritura indica que es un anticipo de legítima? | — | — |
| 2 | Usuario Sordo | Sí, la escritura dice anticipo de legítima. | — | — |
| 3 | Usuario Sordo | ¿Cómo registro un anticipo de legítima? | — | — |
| 4 | Funcionario | ¿Tiene el testimonio de la escritura pública? | — | — |
| 5 | Usuario Sordo | Sí, tengo el testimonio de la escritura pública. | — | — |
| 6 | Funcionario | ¿Usted aparece como beneficiario del anticipo? | — | — |
| 7 | Usuario Sordo | Sí, aparezco como beneficiario del anticipo. | — | — |
| 8 | Usuario Sordo | ¿Qué documentos debo presentar para registrar el anticipo de legítima? | — | — |

### Variantes

- **Turno 1 (Funcionario):** «¿El documento presentado menciona anticipo de legítima?» · «¿La transferencia está descrita como anticipo de legítima?»
- **Respuestas:** «Sí, la escritura dice anticipo de legítima.» · «No, la escritura indica otra transferencia.» · «No sé qué transferencia indica la escritura.»
- **Turno 4 (Funcionario):** «¿Trajo el testimonio de ese anticipo de legítima?» · «¿Puede mostrar la escritura pública del anticipo?»
- **Respuestas:** «Sí, tengo el testimonio de la escritura pública.» · «No, no traje el testimonio de la escritura.» · «No sé cuál documento es el testimonio.»
- **Turno 6 (Funcionario):** «¿Su nombre figura como beneficiario del anticipo de legítima?» · «¿La escritura del anticipo identifica a usted como beneficiario?»
- **Respuestas:** «Sí, aparezco como beneficiario del anticipo.» · «No, el beneficiario es otra persona.» · «No sé quién aparece como beneficiario.»

### Escenarios posibles

Nota narrativa del documento (no crea ramificaciones): Tipo y beneficiario identificados: solicitar revisión. Tipo diferente: aclarar la transferencia. Beneficiario distinto: consultar representación.

## ESC-DDRR-17 — Inscripción de hipoteca

- **Institución:** Derechos Reales – Cochabamba
- **Trámite:** Inscripción de hipoteca
- **Tipo:** conocimiento_fijo
- **Inicia:** Usuario Sordo
- **Situación:** La persona quiere registrar una hipoteca. La conversación diferencia su inscripción de una cancelación y evita confundir deuda con registro.
- **Referencia:** F-DDRR-05
- **Documento:** documentos/Derechos_Reales.pdf#p=15

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Usuario Sordo | ¿Cómo solicito la inscripción de una hipoteca? | — | — |
| 2 | Funcionario | ¿Quiere registrar una hipoteca nueva? | — | — |
| 3 | Usuario Sordo | Sí, quiero registrar una hipoteca nueva. | — | — |
| 4 | Funcionario | ¿Tiene la escritura pública de hipoteca? | — | — |
| 5 | Usuario Sordo | Sí, tengo la escritura pública de hipoteca. | — | — |
| 6 | Funcionario | ¿Conoce la matrícula del inmueble que se hipotecará? | — | — |
| 7 | Usuario Sordo | Sí, conozco la matrícula de ese inmueble. | — | — |
| 8 | Usuario Sordo | ¿Qué documentos debo presentar para registrar la hipoteca? | — | — |

### Variantes

- **Turno 2 (Funcionario):** «¿Su solicitud es para inscribir una hipoteca?» · «¿Necesita una inscripción de hipoteca y no una cancelación?»
- **Respuestas:** «Sí, quiero registrar una hipoteca nueva.» · «No, quiero cancelar una hipoteca registrada.» · «No sé si corresponde inscripción o cancelación.»
- **Turno 4 (Funcionario):** «¿Trajo el testimonio de la hipoteca?» · «¿Puede mostrar la escritura pública de esa hipoteca?»
- **Respuestas:** «Sí, tengo la escritura pública de hipoteca.» · «No, no tengo la escritura pública de hipoteca.» · «No sé si este documento es una hipoteca.»
- **Turno 6 (Funcionario):** «¿Tiene la matrícula del inmueble de la hipoteca?» · «¿Puede mostrar la matrícula del inmueble que quiere hipotecar?»
- **Respuestas:** «Sí, conozco la matrícula de ese inmueble.» · «No, no tengo la matrícula de ese inmueble.» · «No sé si esta matrícula corresponde al inmueble.»

### Escenarios posibles

Nota narrativa del documento (no crea ramificaciones): Inscripción solicitada: pedir revisión de la escritura. Cancelación: pasar a ESC-DDRR-19. Matrícula dudosa: confirmar el inmueble antes de continuar.

## ESC-DDRR-18 — Inscripción de anticresis

- **Institución:** Derechos Reales – Cochabamba
- **Trámite:** Inscripción de anticresis
- **Tipo:** conocimiento_fijo
- **Inicia:** Funcionario
- **Situación:** La persona consulta el registro de una anticresis. Se conserva la diferencia entre anticresis, alquiler e hipoteca.
- **Referencia:** F-DDRR-05
- **Documento:** documentos/Derechos_Reales.pdf#p=16

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Funcionario | ¿El documento corresponde a una anticresis? | — | — |
| 2 | Usuario Sordo | Sí, el documento corresponde a una anticresis. | — | — |
| 3 | Usuario Sordo | ¿Cómo registro la anticresis de una casa? | — | — |
| 4 | Funcionario | ¿Tiene la escritura pública de anticresis? | — | — |
| 5 | Usuario Sordo | Sí, tengo la escritura pública de anticresis. | — | — |
| 6 | Funcionario | ¿Conoce la matrícula del inmueble de la anticresis? | — | — |
| 7 | Usuario Sordo | Sí, tengo la matrícula del inmueble. | — | — |
| 8 | Usuario Sordo | ¿Qué necesito para solicitar la inscripción de la anticresis? | — | — |

### Variantes

- **Turno 1 (Funcionario):** «¿El acuerdo que quiere registrar es una anticresis?» · «¿La escritura presentada indica anticresis?»
- **Respuestas:** «Sí, el documento corresponde a una anticresis.» · «No, el documento corresponde a un alquiler.» · «No sé qué tipo de contrato tengo.»
- **Turno 4 (Funcionario):** «¿Trajo el testimonio de la escritura de anticresis?» · «¿Puede mostrar la escritura pública de esa anticresis?»
- **Respuestas:** «Sí, tengo la escritura pública de anticresis.» · «No, solo tengo un contrato privado.» · «No sé si este documento es una escritura pública.»
- **Turno 6 (Funcionario):** «¿Tiene la matrícula del inmueble de ese contrato?» · «¿Puede mostrar la matrícula del inmueble de la anticresis?»
- **Respuestas:** «Sí, tengo la matrícula del inmueble.» · «No, no tengo la matrícula del inmueble.» · «No sé si esa matrícula corresponde al inmueble.»

### Escenarios posibles

Nota narrativa del documento (no crea ramificaciones): Anticresis identificada: consultar registro y documentación. Alquiler o contrato dudoso: pedir aclaración del tipo de contrato. Documento privado: consultar cómo formalizarlo.

## ESC-DDRR-19 — Cancelación registral de hipoteca

- **Institución:** Derechos Reales – Cochabamba
- **Trámite:** Cancelación registral de hipoteca
- **Tipo:** mixto
- **Inicia:** Usuario Sordo
- **Situación:** La persona afirma que pagó una obligación y quiere consultar la cancelación registral. El pago no se toma como prueba de cancelación.
- **Referencia:** F-DDRR-05
- **Documento:** documentos/Derechos_Reales.pdf#p=17

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Usuario Sordo | ¿Cómo solicito cancelar la hipoteca registrada de mi casa? | — | — |
| 2 | Funcionario | ¿Su solicitud es cancelar una hipoteca registrada? | — | — |
| 3 | Usuario Sordo | Sí, quiero cancelar la hipoteca registrada. | — | — |
| 4 | Funcionario | ¿Tiene un documento que solicite la cancelación de hipoteca? | — | — |
| 5 | Usuario Sordo | Sí, tengo un documento de cancelación de hipoteca. | — | — |
| 6 | Funcionario | ¿Tiene el Folio Real donde aparece esa hipoteca? | — | — |
| 7 | Usuario Sordo | Sí, tengo el Folio Real de ese inmueble. | — | — |
| 8 | Usuario Sordo | ¿Qué documento necesito para solicitar la cancelación de la hipoteca? | — | — |

### Variantes

- **Turno 2 (Funcionario):** «¿Quiere tramitar la cancelación registral de la hipoteca?» · «¿La solicitud se refiere a retirar una hipoteca del registro?»
- **Respuestas:** «Sí, quiero cancelar la hipoteca registrada.» · «No, solo quiero consultar la hipoteca.» · «No sé si la hipoteca sigue registrada.»
- **Turno 4 (Funcionario):** «¿Trajo un documento de cancelación de la hipoteca?» · «¿Puede mostrar el documento de cancelación de esa hipoteca?»
- **Respuestas:** «Sí, tengo un documento de cancelación de hipoteca.» · «No, solo tengo el comprobante del pago.» · «No sé si este documento solicita la cancelación.»
- **Turno 6 (Funcionario):** «¿Trajo el Folio Real del inmueble hipotecado?» · «¿Puede mostrar el Folio Real con esa hipoteca?»
- **Respuestas:** «Sí, tengo el Folio Real de ese inmueble.» · «No, no traje el Folio Real.» · «No sé dónde aparece la hipoteca en el Folio Real.»

### Escenarios posibles

Nota narrativa del documento (no crea ramificaciones): Documento de cancelación disponible: solicitar revisión. Solo comprobante de pago: consultar qué documento registral corresponde. No asegurar que la hipoteca desapareció.

## ESC-DDRR-20 — Inscripción de anotación preventiva judicial

- **Institución:** Derechos Reales – Cochabamba
- **Trámite:** Inscripción de anotación preventiva judicial
- **Tipo:** conocimiento_fijo
- **Inicia:** Funcionario
- **Situación:** La persona trae documentación judicial para una anotación preventiva. El registro no se presenta como resolución del conflicto.
- **Referencia:** F-DDRR-05
- **Documento:** documentos/Derechos_Reales.pdf#p=18

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Funcionario | ¿Tiene un documento judicial de anotación preventiva? | — | — |
| 2 | Usuario Sordo | Sí, tengo el documento judicial de anotación preventiva. | — | — |
| 3 | Usuario Sordo | ¿Cómo registro una anotación preventiva judicial? | — | — |
| 4 | Funcionario | ¿El documento judicial identifica la matrícula del inmueble? | — | — |
| 5 | Usuario Sordo | Sí, el documento judicial indica la matrícula. | — | — |
| 6 | Funcionario | ¿El documento judicial corresponde al inmueble que consulta? | — | — |
| 7 | Usuario Sordo | Sí, el documento corresponde a ese inmueble. | — | — |
| 8 | Usuario Sordo | ¿Qué falta para presentar la anotación preventiva? | — | — |

### Variantes

- **Turno 1 (Funcionario):** «¿Trajo la orden judicial para la anotación preventiva?» · «¿Puede mostrar el documento judicial de esa anotación?»
- **Respuestas:** «Sí, tengo el documento judicial de anotación preventiva.» · «No, todavía no tengo el documento judicial.» · «No sé si este documento ordena una anotación preventiva.»
- **Turno 4 (Funcionario):** «¿La matrícula aparece en el documento judicial?» · «¿El documento judicial señala el inmueble con su matrícula?»
- **Respuestas:** «Sí, el documento judicial indica la matrícula.» · «No, no encuentro la matrícula en el documento.» · «No sé si este número es la matrícula.»
- **Turno 6 (Funcionario):** «¿La orden presentada se refiere a ese inmueble?» · «¿El inmueble de la orden es el que quiere registrar?»
- **Respuestas:** «Sí, el documento corresponde a ese inmueble.» · «No, el documento menciona otro inmueble.» · «No sé si ambos documentos describen el mismo inmueble.»

### Escenarios posibles

Nota narrativa del documento (no crea ramificaciones): Orden e inmueble coinciden: pedir revisión. Documento ausente: consultar la vía correspondiente. Inmueble distinto o dudoso: aclararlo antes de presentar la solicitud.

## ESC-DDRR-21 — Cancelación de anotación preventiva

- **Institución:** Derechos Reales – Cochabamba
- **Trámite:** Cancelación de anotación preventiva
- **Tipo:** mixto
- **Inicia:** Usuario Sordo
- **Situación:** La persona desea retirar una anotación preventiva del registro y necesita identificar el documento que sustenta la solicitud.
- **Referencia:** F-DDRR-05
- **Documento:** documentos/Derechos_Reales.pdf#p=19

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Usuario Sordo | ¿Cómo solicito cancelar una anotación preventiva? | — | — |
| 2 | Funcionario | ¿La anotación preventiva aparece en el Folio Real? | — | — |
| 3 | Usuario Sordo | Sí, la anotación aparece en el Folio Real. | — | — |
| 4 | Funcionario | ¿Tiene un documento judicial para cancelar esa anotación? | — | — |
| 5 | Usuario Sordo | Sí, tengo el documento judicial de cancelación. | — | — |
| 6 | Funcionario | ¿El documento de cancelación corresponde a esa anotación? | — | — |
| 7 | Usuario Sordo | Sí, el documento corresponde a esa anotación. | — | — |
| 8 | Usuario Sordo | ¿Qué documento debo presentar para cancelar la anotación? | — | — |

### Variantes

- **Turno 2 (Funcionario):** «¿El Folio Real muestra la anotación que quiere cancelar?» · «¿Puede identificar esa anotación preventiva en el Folio Real?»
- **Respuestas:** «Sí, la anotación aparece en el Folio Real.» · «No, no encuentro la anotación en el Folio Real.» · «No sé cuál asiento corresponde a la anotación.»
- **Turno 4 (Funcionario):** «¿Trajo la orden de cancelación de la anotación preventiva?» · «¿Puede mostrar el documento judicial de cancelación?»
- **Respuestas:** «Sí, tengo el documento judicial de cancelación.» · «No, no tengo el documento judicial de cancelación.» · «No sé si este documento ordena la cancelación.»
- **Turno 6 (Funcionario):** «¿La orden de cancelación identifica esa misma anotación?» · «¿La anotación del documento coincide con la que consulta?»
- **Respuestas:** «Sí, el documento corresponde a esa anotación.» · «No, el documento menciona otra anotación.» · «No sé si ambos documentos se refieren a lo mismo.»

### Escenarios posibles

Nota narrativa del documento (no crea ramificaciones): Anotación y documento coinciden: consultar la cancelación. Documento diferente: pedir aclaración. No convertir el cierre de un proceso en una cancelación registral automática.

## ESC-DDRR-22 — Corrección de datos de identidad del titular

- **Institución:** Derechos Reales – Cochabamba
- **Trámite:** Corrección de datos de identidad del titular
- **Tipo:** conocimiento_fijo
- **Inicia:** Funcionario
- **Situación:** El titular detecta diferencias en sus datos personales del registro. Se separan estos datos de los datos técnicos del inmueble.
- **Referencia:** F-DDRR-05
- **Documento:** documentos/Derechos_Reales.pdf#p=20

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Funcionario | ¿El error está en el nombre del titular? | — | — |
| 2 | Usuario Sordo | Sí, mi nombre está escrito incorrectamente. | — | — |
| 3 | Usuario Sordo | ¿Cómo corrijo mi nombre en el Folio Real? | — | — |
| 4 | Funcionario | ¿Su cédula muestra el dato de identidad correcto? | — | — |
| 5 | Usuario Sordo | Sí, mi cédula muestra el dato correcto. | — | — |
| 6 | Funcionario | ¿Trajo el Folio Real con el dato que consulta? | — | — |
| 7 | Usuario Sordo | Sí, traje el Folio Real con ese dato. | — | — |
| 8 | Usuario Sordo | ¿Qué documento necesito para corregir mis datos de identidad? | — | — |

### Variantes

- **Turno 1 (Funcionario):** «¿Su nombre aparece escrito incorrectamente en el registro?» · «¿El dato que quiere corregir es su nombre?»
- **Respuestas:** «Sí, mi nombre está escrito incorrectamente.» · «No, el error está en mi número de cédula.» · «No sé cuál dato de identidad está incorrecto.»
- **Turno 4 (Funcionario):** «¿El dato correcto aparece en su cédula de identidad?» · «¿Puede mostrar el dato correcto en su cédula?»
- **Respuestas:** «Sí, mi cédula muestra el dato correcto.» · «No, mi cédula también tiene un error.» · «No sé cuál documento tiene el dato correcto.»
- **Turno 6 (Funcionario):** «¿Tiene el Folio Real donde aparece el error?» · «¿Puede mostrar el Folio Real con ese dato de identidad?»
- **Respuestas:** «Sí, traje el Folio Real con ese dato.» · «No, no traje el Folio Real.» · «No sé dónde aparece ese dato en el Folio Real.»

### Escenarios posibles

Nota narrativa del documento (no crea ramificaciones): Nombre o cédula: mantener el campo concreto. Datos contradictorios: pedir revisión. Error en superficie o ubicación: pasar a ESC-DDRR-23.

## ESC-DDRR-23 — Corrección de datos técnicos del inmueble

- **Institución:** Derechos Reales – Cochabamba
- **Trámite:** Corrección de datos técnicos del inmueble
- **Tipo:** conocimiento_fijo
- **Inicia:** Usuario Sordo
- **Situación:** La persona observa diferencias en superficie o ubicación. Se consulta el campo preciso sin afirmar qué vía de corrección corresponde.
- **Referencia:** F-DDRR-05
- **Documento:** documentos/Derechos_Reales.pdf#p=21

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Usuario Sordo | ¿Cómo consulto un error en los datos de mi inmueble? | — | — |
| 2 | Funcionario | ¿La diferencia está en la superficie del inmueble? | — | — |
| 3 | Usuario Sordo | Sí, la diferencia está en la superficie. | — | — |
| 4 | Funcionario | ¿Tiene un documento catastral para comparar ese dato? | — | — |
| 5 | Usuario Sordo | Sí, tengo un documento catastral para comparar. | — | — |
| 6 | Funcionario | ¿Trajo el Folio Real del inmueble que quiere revisar? | — | — |
| 7 | Usuario Sordo | Sí, tengo el Folio Real del inmueble. | — | — |
| 8 | Usuario Sordo | ¿Qué documento debo presentar para revisar los datos del inmueble? | — | — |

### Variantes

- **Turno 2 (Funcionario):** «¿El área del inmueble aparece con una diferencia?» · «¿El dato que quiere revisar es la superficie?»
- **Respuestas:** «Sí, la diferencia está en la superficie.» · «No, la diferencia está en la ubicación.» · «No sé qué dato técnico está incorrecto.»
- **Turno 4 (Funcionario):** «¿Trajo un documento catastral que muestre ese dato?» · «¿Puede mostrar el dato en su documentación catastral?»
- **Respuestas:** «Sí, tengo un documento catastral para comparar.» · «No, no tengo un documento catastral.» · «No sé si este documento sirve para comparar.»
- **Turno 6 (Funcionario):** «¿Tiene el Folio Real del inmueble con esa diferencia?» · «¿Puede mostrar el Folio Real del inmueble consultado?»
- **Respuestas:** «Sí, tengo el Folio Real del inmueble.» · «No, no traje el Folio Real del inmueble.» · «No sé si este Folio Real corresponde al inmueble.»

### Escenarios posibles

Nota narrativa del documento (no crea ramificaciones): Superficie o ubicación: conservar el dato específico. Sin documento comparativo: preguntar cómo obtener orientación. Error de identidad: pasar a ESC-DDRR-22.

## ESC-DDRR-24 — Matriculación desde un registro antiguo

- **Institución:** Derechos Reales – Cochabamba
- **Trámite:** Matriculación desde un registro antiguo
- **Tipo:** mixto
- **Inicia:** Funcionario
- **Situación:** La persona conserva documentos de un registro antiguo y pregunta por su actualización al sistema de Folio Real.
- **Referencia:** F-DDRR-05
- **Documento:** documentos/Derechos_Reales.pdf#p=22

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Funcionario | ¿Su documento tiene una partida de registro antiguo? | — | — |
| 2 | Usuario Sordo | Sí, mi documento tiene una partida antigua. | — | — |
| 3 | Usuario Sordo | ¿Cómo consulto la matriculación de un registro antiguo? | — | — |
| 4 | Funcionario | ¿Tiene la escritura con la que adquirió el inmueble? | — | — |
| 5 | Usuario Sordo | Sí, tengo la escritura de adquisición. | — | — |
| 6 | Funcionario | ¿Usted figura como titular en ese registro antiguo? | — | — |
| 7 | Usuario Sordo | Sí, mi nombre aparece en el registro antiguo. | — | — |
| 8 | Usuario Sordo | ¿Qué documentos debo presentar para consultar la matriculación? | — | — |

### Variantes

- **Turno 1 (Funcionario):** «¿El documento conserva una referencia de partida antigua?» · «¿El inmueble aparece registrado mediante una partida antigua?»
- **Respuestas:** «Sí, mi documento tiene una partida antigua.» · «No, mi documento ya tiene una matrícula.» · «No sé qué tipo de registro tiene mi documento.»
- **Turno 4 (Funcionario):** «¿Conserva la escritura de adquisición del inmueble?» · «¿Puede mostrar el documento con el que adquirió el inmueble?»
- **Respuestas:** «Sí, tengo la escritura de adquisición.» · «No, no conservo la escritura de adquisición.» · «No sé cuál documento acredita la adquisición.»
- **Turno 6 (Funcionario):** «¿Su nombre aparece en el registro antiguo del inmueble?» · «¿El titular del registro antiguo es usted?»
- **Respuestas:** «Sí, mi nombre aparece en el registro antiguo.» · «No, aparece el nombre de otra persona.» · «No sé quién figura en el registro antiguo.»

### Escenarios posibles

Nota narrativa del documento (no crea ramificaciones): Partida antigua: consultar matriculación. Matrícula existente: consultar el servicio actual necesario. Titular diferente: aclarar transferencia o representación.

## ESC-DDRR-25 — Inscripción de división y partición

- **Institución:** Derechos Reales – Cochabamba
- **Trámite:** Inscripción de división y partición
- **Tipo:** conocimiento_fijo
- **Inicia:** Usuario Sordo
- **Situación:** La persona desea registrar la división de un inmueble y debe distinguir el proyecto de división de la documentación formal disponible.
- **Referencia:** F-DDRR-05
- **Documento:** documentos/Derechos_Reales.pdf#p=23

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Usuario Sordo | ¿Cómo registro la división y partición de un inmueble? | — | — |
| 2 | Funcionario | ¿Tiene un documento de división y partición del inmueble? | — | — |
| 3 | Usuario Sordo | Sí, tengo el documento de división y partición. | — | — |
| 4 | Funcionario | ¿La división incluye a varios propietarios? | — | — |
| 5 | Usuario Sordo | Sí, hay otros propietarios en la división. | — | — |
| 6 | Funcionario | ¿Tiene un plano de la división del inmueble? | — | — |
| 7 | Usuario Sordo | Sí, tengo el plano de la división. | — | — |
| 8 | Usuario Sordo | ¿Qué documentos necesito para registrar la división? | — | — |

### Variantes

- **Turno 2 (Funcionario):** «¿Trajo la escritura de división y partición?» · «¿Puede mostrar el documento que formaliza la división?»
- **Respuestas:** «Sí, tengo el documento de división y partición.» · «No, solo tengo la intención de dividir el inmueble.» · «No sé si este documento formaliza la división.»
- **Turno 4 (Funcionario):** «¿Otros propietarios participan en la división?» · «¿El documento de división identifica más propietarios?»
- **Respuestas:** «Sí, hay otros propietarios en la división.» · «No, solo figuro yo como propietario.» · «No sé quiénes figuran como propietarios.»
- **Turno 6 (Funcionario):** «¿Trajo el plano que muestra la división?» · «¿Puede mostrar el plano de esa división?»
- **Respuestas:** «Sí, tengo el plano de la división.» · «No, no tengo el plano de la división.» · «No sé si este plano corresponde a la división.»

### Escenarios posibles

Nota narrativa del documento (no crea ramificaciones): Documento y plano disponibles: pedir revisión registral. Solo intención de dividir: consultar formalización. Varios propietarios: conservar esa condición.

## ESC-DDRR-26 — Inscripción de propiedad horizontal

- **Institución:** Derechos Reales – Cochabamba
- **Trámite:** Inscripción de propiedad horizontal
- **Tipo:** conocimiento_fijo
- **Inicia:** Funcionario
- **Situación:** La persona solicita orientación para registrar un departamento bajo propiedad horizontal y necesita identificar la unidad concreta.
- **Referencia:** F-DDRR-05
- **Documento:** documentos/Derechos_Reales.pdf#p=24

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Funcionario | ¿Su consulta es sobre un departamento en propiedad horizontal? | — | — |
| 2 | Usuario Sordo | Sí, consulto un departamento en propiedad horizontal. | — | — |
| 3 | Usuario Sordo | ¿Cómo consulto la inscripción de propiedad horizontal? | — | — |
| 4 | Funcionario | ¿Tiene un documento que identifique su departamento? | — | — |
| 5 | Usuario Sordo | Sí, tengo un documento de mi departamento. | — | — |
| 6 | Funcionario | ¿El documento identifica la unidad que quiere registrar? | — | — |
| 7 | Usuario Sordo | Sí, el documento identifica mi departamento. | — | — |
| 8 | Usuario Sordo | ¿Qué documentación necesito para registrar mi departamento? | — | — |

### Variantes

- **Turno 1 (Funcionario):** «¿El inmueble consultado es una unidad de propiedad horizontal?» · «¿Quiere registrar un departamento bajo propiedad horizontal?»
- **Respuestas:** «Sí, consulto un departamento en propiedad horizontal.» · «No, consulto una casa independiente.» · «No sé si mi departamento tiene ese régimen.»
- **Turno 4 (Funcionario):** «¿Trajo la escritura que identifica esa unidad?» · «¿Puede mostrar el documento de su departamento?»
- **Respuestas:** «Sí, tengo un documento de mi departamento.» · «No, no tengo el documento de mi departamento.» · «No sé si el documento identifica mi departamento.»
- **Turno 6 (Funcionario):** «¿La unidad indicada coincide con su departamento?» · «¿El departamento del documento es el que consulta?»
- **Respuestas:** «Sí, el documento identifica mi departamento.» · «No, el documento menciona otro departamento.» · «No sé si el documento corresponde a mi unidad.»

### Escenarios posibles

Nota narrativa del documento (no crea ramificaciones): Unidad identificada: consultar registro. Casa independiente: aclarar el trámite correspondiente. Unidad distinta o dudosa: pedir revisión antes de continuar.

## ESC-DDRR-27 — Registro de regularización de derecho propietario

- **Institución:** Derechos Reales – Cochabamba
- **Trámite:** Registro de regularización de derecho propietario
- **Tipo:** conocimiento_fijo
- **Inicia:** Usuario Sordo
- **Situación:** La persona pregunta por el registro de una regularización mediante Ley 247. No se evalúa si cumple las condiciones legales.
- **Referencia:** F-DDRR-05
- **Documento:** documentos/Derechos_Reales.pdf#p=25

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Usuario Sordo | ¿Cómo consulto el registro de mi regularización de propiedad? | — | — |
| 2 | Funcionario | ¿Su documento identifica una regularización mediante Ley 247? | — | — |
| 3 | Usuario Sordo | Sí, mi documento menciona esa ley. | — | — |
| 4 | Funcionario | ¿Tiene el documento judicial de la regularización? | — | — |
| 5 | Usuario Sordo | Sí, tengo el documento judicial de regularización. | — | — |
| 6 | Funcionario | ¿El documento identifica el inmueble que desea registrar? | — | — |
| 7 | Usuario Sordo | Sí, el documento identifica ese inmueble. | — | — |
| 8 | Usuario Sordo | ¿Qué documento necesito para registrar la regularización? | — | — |

### Variantes

- **Turno 2 (Funcionario):** «¿El documento presentado menciona la Ley 247?» · «¿La regularización indicada en su documento corresponde a la Ley 247?»
- **Respuestas:** «Sí, mi documento menciona esa ley.» · «No, mi documento indica otra vía de regularización.» · «No sé qué vía de regularización indica mi documento.»
- **Turno 4 (Funcionario):** «¿Trajo el documento judicial que respalda la regularización?» · «¿Puede mostrar el documento judicial de ese inmueble?»
- **Respuestas:** «Sí, tengo el documento judicial de regularización.» · «No, todavía no tengo el documento judicial.» · «No sé si este documento acredita la regularización.»
- **Turno 6 (Funcionario):** «¿El inmueble consultado aparece en el documento de regularización?» · «¿La regularización documentada corresponde a ese inmueble?»
- **Respuestas:** «Sí, el documento identifica ese inmueble.» · «No, el documento identifica otro inmueble.» · «No sé si el documento corresponde a mi inmueble.»

### Escenarios posibles

Nota narrativa del documento (no crea ramificaciones): Documento identificado: pedir revisión del registro. Otra vía: conservarla sin forzar Ley 247. Sin documento judicial: consultar orientación competente.

## ESC-DDRR-28 — Inscripción de usucapión con documentación judicial

- **Institución:** Derechos Reales – Cochabamba
- **Trámite:** Inscripción de usucapión con documentación judicial
- **Tipo:** conocimiento_fijo
- **Inicia:** Funcionario
- **Situación:** La persona consulta el registro de una usucapión documentada. La app no determina la propiedad ni resuelve el proceso judicial.
- **Referencia:** F-DDRR-05
- **Documento:** documentos/Derechos_Reales.pdf#p=26

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Funcionario | ¿Tiene un documento judicial referido a una usucapión? | — | — |
| 2 | Usuario Sordo | Sí, tengo el documento judicial de usucapión. | — | — |
| 3 | Usuario Sordo | ¿Cómo consulto la inscripción de una usucapión? | — | — |
| 4 | Funcionario | ¿El documento judicial identifica a usted como beneficiario? | — | — |
| 5 | Usuario Sordo | Sí, mi nombre aparece como beneficiario. | — | — |
| 6 | Funcionario | ¿El documento judicial corresponde al inmueble que consulta? | — | — |
| 7 | Usuario Sordo | Sí, el documento corresponde a ese inmueble. | — | — |
| 8 | Usuario Sordo | ¿Qué documentación judicial debo presentar para el registro? | — | — |

### Variantes

- **Turno 1 (Funcionario):** «¿Trajo la documentación judicial de la usucapión?» · «¿Puede mostrar el documento judicial de ese proceso?»
- **Respuestas:** «Sí, tengo el documento judicial de usucapión.» · «No, todavía no tengo el documento judicial.» · «No sé si este documento corresponde a una usucapión.»
- **Turno 4 (Funcionario):** «¿Su nombre aparece como beneficiario en ese documento?» · «¿El beneficiario mencionado en el documento judicial es usted?»
- **Respuestas:** «Sí, mi nombre aparece como beneficiario.» · «No, el beneficiario indicado es otra persona.» · «No sé quién aparece como beneficiario.»
- **Turno 6 (Funcionario):** «¿Ese inmueble aparece en el documento judicial?» · «¿El inmueble identificado coincide con el que quiere registrar?»
- **Respuestas:** «Sí, el documento corresponde a ese inmueble.» · «No, el documento identifica otro inmueble.» · «No sé si ambos documentos corresponden al mismo inmueble.»

### Escenarios posibles

Nota narrativa del documento (no crea ramificaciones): Documento e inmueble identificados: pedir revisión registral. Documento ausente: consultar la documentación judicial necesaria. No inferir propiedad por tiempo de ocupación.

## ESC-DDRR-29 — Reingreso de un trámite observado

- **Institución:** Derechos Reales – Cochabamba
- **Trámite:** Reingreso de un trámite observado
- **Tipo:** mixto
- **Inicia:** Usuario Sordo
- **Situación:** La persona recibió una observación y vuelve para consultar el reingreso. No se afirma que la observación ya esté subsanada.
- **Referencia:** F-DDRR-05
- **Documento:** documentos/Derechos_Reales.pdf#p=27

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Usuario Sordo | ¿Cómo vuelvo a presentar mi trámite observado? | — | — |
| 2 | Funcionario | ¿Tiene la boleta de observación de su trámite? | — | — |
| 3 | Usuario Sordo | Sí, tengo la boleta de observación. | — | — |
| 4 | Funcionario | ¿Trajo un documento para subsanar la observación? | — | — |
| 5 | Usuario Sordo | Sí, traje un documento para subsanar la observación. | — | — |
| 6 | Funcionario | ¿Tiene el comprobante de ingreso del trámite anterior? | — | — |
| 7 | Usuario Sordo | Sí, tengo el comprobante del ingreso anterior. | — | — |
| 8 | Usuario Sordo | ¿Dónde presento los documentos para revisar la observación? | — | — |

### Variantes

- **Turno 2 (Funcionario):** «¿Trajo el documento donde consta la observación?» · «¿Puede mostrar la observación escrita de su trámite?»
- **Respuestas:** «Sí, tengo la boleta de observación.» · «No, no tengo la boleta de observación.» · «No sé cuál documento contiene la observación.»
- **Turno 4 (Funcionario):** «¿Tiene documentación para corregir el punto observado?» · «¿Puede mostrar el documento que presenta para subsanar?»
- **Respuestas:** «Sí, traje un documento para subsanar la observación.» · «No, todavía no tengo el documento solicitado.» · «No sé si este documento subsana la observación.»
- **Turno 6 (Funcionario):** «¿Trajo la boleta de ingreso del trámite observado?» · «¿Puede mostrar el comprobante del ingreso anterior?»
- **Respuestas:** «Sí, tengo el comprobante del ingreso anterior.» · «No, no tengo el comprobante del ingreso anterior.» · «No sé cuál comprobante corresponde a ese trámite.»

### Escenarios posibles

Nota narrativa del documento (no crea ramificaciones): Observación identificada y documento disponible: solicitar revisión del reingreso. Observación desconocida: pedir explicación escrita. No asegurar que el documento presentado la corrige.

## ESC-DDRR-30 — Consulta del estado de un trámite

- **Institución:** Derechos Reales – Cochabamba
- **Trámite:** Consulta del estado de un trámite
- **Tipo:** mixto
- **Inicia:** Funcionario
- **Situación:** La persona desea conocer el estado de un trámite presentado. El estado y la fecha de entrega requieren consulta institucional.
- **Referencia:** F-DDRR-10
- **Documento:** documentos/Derechos_Reales.pdf#p=28

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Funcionario | ¿Tiene el comprobante de ingreso de ese trámite? | — | — |
| 2 | Usuario Sordo | Sí, tengo el comprobante de ingreso del trámite. | — | — |
| 3 | Usuario Sordo | ¿Cómo consulto el estado de mi trámite? | — | — |
| 4 | Funcionario | ¿El comprobante corresponde a esta oficina de Derechos Reales? | — | — |
| 5 | Usuario Sordo | Sí, presenté el trámite en esta oficina. | — | — |
| 6 | Funcionario | ¿Recibió alguna observación sobre ese trámite? | — | — |
| 7 | Usuario Sordo | Sí, recibí una observación del trámite. | — | — |
| 8 | Usuario Sordo | ¿Dónde puedo confirmar si mi trámite ya está listo? | — | — |

### Variantes

- **Turno 1 (Funcionario):** «¿Trajo la boleta con la que ingresó el trámite?» · «¿Puede mostrar el comprobante del trámite consultado?»
- **Respuestas:** «Sí, tengo el comprobante de ingreso del trámite.» · «No, no tengo el comprobante de ingreso.» · «No sé cuál comprobante corresponde a mi trámite.»
- **Turno 4 (Funcionario):** «¿Ingresó ese trámite en esta oficina?» · «¿Esta oficina es donde presentó el trámite?»
- **Respuestas:** «Sí, presenté el trámite en esta oficina.» · «No, presenté el trámite en otra oficina.» · «No sé en qué oficina ingresaron el trámite.»
- **Turno 6 (Funcionario):** «¿Le entregaron una observación de ese trámite?» · «¿Tiene una notificación de observación del trámite?»
- **Respuestas:** «Sí, recibí una observación del trámite.» · «No, no recibí una observación.» · «No sé si mi trámite tiene observaciones.»

### Escenarios posibles

Nota narrativa del documento (no crea ramificaciones): Trámite identificable: solicitar consulta institucional. Otra oficina: pedir orientación sobre la oficina responsable. Observación recibida: pasar a ESC-DDRR-29.

## ESC-DDRR-31 — Consulta para recoger documentos del trámite

- **Institución:** Derechos Reales – Cochabamba
- **Trámite:** Consulta para recoger documentos del trámite
- **Tipo:** mixto
- **Inicia:** Usuario Sordo
- **Situación:** La persona consulta la entrega de documentos. No se presupone que estén listos ni que quien consulta pueda retirarlos.
- **Referencia:** F-DDRR-08
- **Documento:** documentos/Derechos_Reales.pdf#p=29

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Usuario Sordo | ¿Puedo recoger los documentos de mi trámite? | — | — |
| 2 | Funcionario | ¿Trajo el comprobante del trámite que desea recoger? | — | — |
| 3 | Usuario Sordo | Sí, traje el comprobante de ese trámite. | — | — |
| 4 | Funcionario | ¿Usted es la persona identificada en ese comprobante? | — | — |
| 5 | Usuario Sordo | Sí, mi nombre aparece en el comprobante. | — | — |
| 6 | Funcionario | ¿Le comunicaron que los documentos pueden recogerse? | — | — |
| 7 | Usuario Sordo | Sí, recibí un aviso para recoger los documentos. | — | — |
| 8 | Usuario Sordo | ¿Qué debo presentar para recoger los documentos? | — | — |

### Variantes

- **Turno 2 (Funcionario):** «¿Tiene la boleta del trámite para consultar su entrega?» · «¿Puede mostrar el comprobante del trámite solicitado?»
- **Respuestas:** «Sí, traje el comprobante de ese trámite.» · «No, no traje el comprobante del trámite.» · «No sé cuál comprobante corresponde al trámite.»
- **Turno 4 (Funcionario):** «¿Su nombre aparece como solicitante en el comprobante?» · «¿El solicitante del comprobante es usted?»
- **Respuestas:** «Sí, mi nombre aparece en el comprobante.» · «No, el comprobante está a nombre de otra persona.» · «No sé quién figura como solicitante.»
- **Turno 6 (Funcionario):** «¿Recibió un aviso de entrega de esos documentos?» · «¿Le indicaron que esos documentos están disponibles para recoger?»
- **Respuestas:** «Sí, recibí un aviso para recoger los documentos.» · «No, todavía no recibí un aviso de entrega.» · «No sé si los documentos están listos.»

### Escenarios posibles

Nota narrativa del documento (no crea ramificaciones): Aviso recibido: confirmar disponibilidad y retiro. Sin aviso: consultar estado en ESC-DDRR-30. Solicitante diferente: consultar representación en ESC-DDRR-34.

## ESC-DDRR-32 — Desarchivo de documentos

- **Institución:** Derechos Reales – Cochabamba
- **Trámite:** Desarchivo de documentos
- **Tipo:** mixto
- **Inicia:** Funcionario
- **Situación:** La persona pregunta cómo solicitar el desarchivo de documentación de un trámite anterior.
- **Referencia:** F-DDRR-05
- **Documento:** documentos/Derechos_Reales.pdf#p=30

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Funcionario | ¿Le indicaron que los documentos del trámite están archivados? | — | — |
| 2 | Usuario Sordo | Sí, me indicaron que los documentos están archivados. | — | — |
| 3 | Usuario Sordo | ¿Cómo solicito el desarchivo de mis documentos? | — | — |
| 4 | Funcionario | ¿Tiene un comprobante que identifique ese trámite anterior? | — | — |
| 5 | Usuario Sordo | Sí, tengo el comprobante del trámite anterior. | — | — |
| 6 | Funcionario | ¿Tiene una solicitud escrita de desarchivo? | — | — |
| 7 | Usuario Sordo | Sí, tengo una solicitud escrita de desarchivo. | — | — |
| 8 | Usuario Sordo | ¿Qué necesito para solicitar el desarchivo de ese trámite? | — | — |

### Variantes

- **Turno 1 (Funcionario):** «¿Recibió información de que el trámite fue archivado?» · «¿La oficina le comunicó que su documentación está archivada?»
- **Respuestas:** «Sí, me indicaron que los documentos están archivados.» · «No, todavía no confirmé si están archivados.» · «No sé si mis documentos están archivados.»
- **Turno 4 (Funcionario):** «¿Conserva la boleta del trámite cuyos documentos busca?» · «¿Puede mostrar el comprobante del trámite archivado?»
- **Respuestas:** «Sí, tengo el comprobante del trámite anterior.» · «No, no conservo el comprobante del trámite.» · «No sé cuál comprobante identifica ese trámite.»
- **Turno 6 (Funcionario):** «¿Trajo una solicitud escrita para desarchivar documentos?» · «¿Puede mostrar su solicitud de desarchivo?»
- **Respuestas:** «Sí, tengo una solicitud escrita de desarchivo.» · «No, no tengo una solicitud escrita.» · «No sé cómo preparar la solicitud de desarchivo.»

### Escenarios posibles

Nota narrativa del documento (no crea ramificaciones): Archivo confirmado: consultar la solicitud aplicable. Archivo desconocido: consultar primero el estado. Sin identificación del trámite: pedir orientación para localizarlo.

## ESC-DDRR-33 — Resellado de nota marginal en segundo testimonio

- **Institución:** Derechos Reales – Cochabamba
- **Trámite:** Resellado de nota marginal en segundo testimonio
- **Tipo:** conocimiento_fijo
- **Inicia:** Usuario Sordo
- **Situación:** La persona tiene un segundo testimonio y consulta el resellado de la nota marginal, conservando el nombre específico del servicio.
- **Referencia:** F-DDRR-05
- **Documento:** documentos/Derechos_Reales.pdf#p=31

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Usuario Sordo | ¿Cómo solicito el resellado de mi segundo testimonio? | — | — |
| 2 | Funcionario | ¿El documento presentado es un segundo testimonio? | — | — |
| 3 | Usuario Sordo | Sí, traje un segundo testimonio. | — | — |
| 4 | Funcionario | ¿Tiene el Folio Real del inmueble de ese testimonio? | — | — |
| 5 | Usuario Sordo | Sí, tengo el Folio Real de ese inmueble. | — | — |
| 6 | Funcionario | ¿Tiene una solicitud escrita de resellado de nota marginal? | — | — |
| 7 | Usuario Sordo | Sí, tengo la solicitud escrita de resellado. | — | — |
| 8 | Usuario Sordo | ¿Qué documentos debo presentar para solicitar el resellado? | — | — |

### Variantes

- **Turno 2 (Funcionario):** «¿Trajo un segundo testimonio de la escritura?» · «¿El testimonio que quiere resellar es el segundo testimonio?»
- **Respuestas:** «Sí, traje un segundo testimonio.» · «No, traje el testimonio anterior.» · «No sé qué testimonio me entregaron.»
- **Turno 4 (Funcionario):** «¿Trajo el Folio Real vinculado con esa escritura?» · «¿Puede mostrar el Folio Real de ese inmueble?»
- **Respuestas:** «Sí, tengo el Folio Real de ese inmueble.» · «No, no tengo el Folio Real.» · «No sé si este Folio Real corresponde al testimonio.»
- **Turno 6 (Funcionario):** «¿Trajo la solicitud de resellado de la nota marginal?» · «¿Puede mostrar la solicitud escrita para ese resellado?»
- **Respuestas:** «Sí, tengo la solicitud escrita de resellado.» · «No, no tengo la solicitud escrita.» · «No sé cómo preparar la solicitud de resellado.»

### Escenarios posibles

Nota narrativa del documento (no crea ramificaciones): Segundo testimonio identificado: consultar el resellado. Testimonio diferente o desconocido: aclarar qué documento fue emitido. No sustituir nota marginal por certificado de propiedad.

## ESC-DDRR-34 — Solicitud en representación de otra persona

- **Institución:** Derechos Reales – Cochabamba
- **Trámite:** Solicitud en representación de otra persona
- **Tipo:** conocimiento_fijo
- **Inicia:** Funcionario
- **Situación:** La persona consulta un trámite de otro titular. Se distingue representación formal de acompañamiento familiar.
- **Referencia:** F-DDRR-06
- **Documento:** documentos/Derechos_Reales.pdf#p=32

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Funcionario | ¿Está solicitando el trámite para otro titular? | — | — |
| 2 | Usuario Sordo | Sí, solicito el trámite para otro titular. | — | — |
| 3 | Usuario Sordo | ¿Puedo solicitar este trámite para otra persona? | — | — |
| 4 | Funcionario | ¿Tiene un poder para representar a esa persona? | — | — |
| 5 | Usuario Sordo | Sí, tengo un poder del titular. | — | — |
| 6 | Funcionario | ¿El poder menciona el trámite que quiere solicitar? | — | — |
| 7 | Usuario Sordo | Sí, el poder menciona esta gestión. | — | — |
| 8 | Usuario Sordo | ¿Qué documento necesito para actuar en su representación? | — | — |

### Variantes

- **Turno 1 (Funcionario):** «¿La persona titular del trámite es distinta de usted?» · «¿Presenta esta solicitud en nombre de otra persona?»
- **Respuestas:** «Sí, solicito el trámite para otro titular.» · «No, el trámite es para mí.» · «No sé quién figura como titular del trámite.»
- **Turno 4 (Funcionario):** «¿Trajo un poder otorgado por el titular?» · «¿Puede mostrar el poder de representación del titular?»
- **Respuestas:** «Sí, tengo un poder del titular.» · «No, solo estoy acompañando al titular.» · «No sé si este documento es un poder.»
- **Turno 6 (Funcionario):** «¿El poder presentado incluye esa gestión?» · «¿Puede identificar esa gestión en el poder de representación?»
- **Respuestas:** «Sí, el poder menciona esta gestión.» · «No, el poder menciona otra gestión.» · «No sé si el poder incluye esta gestión.»

### Escenarios posibles

Nota narrativa del documento (no crea ramificaciones): Poder disponible: solicitar revisión de su alcance. Solo acompañamiento: conservar ese rol. Trámite propio: regresar al servicio solicitado. No aprobar poderes desde el corpus.

## ESC-DDRR-35 — Consulta del costo, pago y comprobante

- **Institución:** Derechos Reales – Cochabamba
- **Trámite:** Consulta del costo, pago y comprobante
- **Tipo:** mixto
- **Inicia:** Usuario Sordo
- **Situación:** La persona pregunta por aranceles y medios de pago de un trámite de Derechos Reales. No se fija monto, banco ni modalidad.
- **Referencia:** F-DDRR-08
- **Documento:** documentos/Derechos_Reales.pdf#p=33

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Usuario Sordo | ¿Cuánto cuesta el trámite que voy a solicitar? | — | — |
| 2 | Funcionario | ¿Ya le indicaron el nombre del trámite que pagará? | — | — |
| 3 | Usuario Sordo | Sí, conozco el nombre del trámite. | — | — |
| 4 | Funcionario | ¿Tiene una boleta con el concepto de pago? | — | — |
| 5 | Usuario Sordo | Sí, tengo la boleta con el concepto de pago. | — | — |
| 6 | Funcionario | ¿Ya realizó el pago de ese trámite? | — | — |
| 7 | Usuario Sordo | Sí, pagué y tengo el comprobante. | — | — |
| 8 | Usuario Sordo | ¿Dónde pago el arancel de este trámite? | — | — |

### Variantes

- **Turno 2 (Funcionario):** «¿Tiene identificado el trámite para el pago?» · «¿Conoce el nombre de la gestión que quiere pagar?»
- **Respuestas:** «Sí, conozco el nombre del trámite.» · «No, todavía no identificaron mi trámite.» · «No sé cuál trámite debo pagar.»
- **Turno 4 (Funcionario):** «¿Le entregaron una boleta para identificar el pago?» · «¿Puede mostrar la boleta con el concepto a pagar?»
- **Respuestas:** «Sí, tengo la boleta con el concepto de pago.» · «No, no tengo una boleta de pago.» · «No sé si esta boleta corresponde a mi trámite.»
- **Turno 6 (Funcionario):** «¿Pagó el arancel de ese trámite?» · «¿Tiene un comprobante del pago de ese trámite?»
- **Respuestas:** «Sí, pagué y tengo el comprobante.» · «No, todavía no realicé el pago.» · «No sé si el pago corresponde a ese trámite.»

### Escenarios posibles

Nota narrativa del documento (no crea ramificaciones): Trámite identificado: pedir monto y modalidad actuales. Pago realizado: solicitar revisión del comprobante. Sin pago: preguntar dónde y cómo pagar. No proponer cifras ni bancos.

## ESC-DDRR-36 — Atención accesible y explicación en Derechos Reales

- **Institución:** Derechos Reales – Cochabamba
- **Trámite:** Atención accesible y explicación en Derechos Reales
- **Tipo:** conocimiento_fijo
- **Inicia:** Funcionario
- **Situación:** La persona necesita comprender una pregunta o un documento registral y solicita una modalidad de comunicación accesible.
- **Referencia:** F-DDRR-05
- **Documento:** documentos/Derechos_Reales.pdf#p=34

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Funcionario | ¿Prefiere que escriba la explicación del trámite? | — | — |
| 2 | Usuario Sordo | Sí, prefiero la explicación por escrito. | — | — |
| 3 | Usuario Sordo | ¿Puede explicarme este trámite por escrito? | — | — |
| 4 | Funcionario | ¿Necesita apoyo de interpretación en LSB? | — | — |
| 5 | Usuario Sordo | Sí, necesito un intérprete de LSB. | — | — |
| 6 | Funcionario | ¿La parte que no entiende está en el documento registral? | — | — |
| 7 | Usuario Sordo | Sí, no entiendo una parte del documento registral. | — | — |
| 8 | Usuario Sordo | ¿Cómo solicito apoyo para comunicarme en LSB? | — | — |

### Variantes

- **Turno 1 (Funcionario):** «¿Le resulta más claro recibir la explicación por escrito?» · «¿Quiere leer la explicación escrita de este trámite?»
- **Respuestas:** «Sí, prefiero la explicación por escrito.» · «No, prefiero comunicarme en LSB.» · «No sé qué forma de explicación me ayudará más.»
- **Turno 4 (Funcionario):** «¿Quiere consultar por un intérprete de LSB?» · «¿Requiere apoyo para comunicarse mediante LSB?»
- **Respuestas:** «Sí, necesito un intérprete de LSB.» · «No, puedo comunicarme usando el texto.» · «No sé si hay apoyo de interpretación disponible.»
- **Turno 6 (Funcionario):** «¿Su duda está en un dato del documento registral?» · «¿Necesita aclarar una parte del documento de Derechos Reales?»
- **Respuestas:** «Sí, no entiendo una parte del documento registral.» · «No, mi duda es sobre el paso siguiente.» · «No sé qué significa el nombre de este documento.»

### Escenarios posibles

Nota narrativa del documento (no crea ramificaciones): Texto o LSB: respetar la preferencia expresada. Intérprete solicitado: consultar disponibilidad. Documento o paso desconocido: pedir aclaración concreta, sin asumir comprensión.
