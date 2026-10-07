# Escenarios de trámites públicos y judiciales en Cochabamba — Corpus RAG

**Fecha de corte:** 2026-09-27  
**Ámbito:** Cochabamba, Bolivia  
**Uso previsto:** recuperación aumentada por generación (RAG) para una aplicación de comunicación LSB ↔ español.

**Regla temporal:** `Consultado` es la fecha en que se verificó una fuente; no implica que la fuente haya sido publicada o actualizada ese día. Cuando la vigencia real de un requisito, costo, horario o dirección no pudo probarse, se usa `[VERIFICAR]`.

**Regla de datos:** nombres, placas, matrículas, NUREJ, WebID, números de caso y otros datos personales usados dentro de escenarios son ficticios. Los estados reales de expedientes, deudas, audiencias, fiscales asignados y montos personales se marcan como `dato_en_vivo`.

---
# Escenarios de trámites en Cochabamba — Parte 1 de 7

## Fuentes
| ID | Institución | Título | URL | Consultado |
|---|---|---|---|---|
| F-DDRR-01 | Derechos Reales | Folio Real Actualizado — requisitos | https://cm.organojudicial.gob.bo/consejo/requisitosddrr/42_-folio-real-actualizado.html | 2026-09-27 |
| F-DDRR-02 | Derechos Reales | Certificado de Gravámenes | https://cm.organojudicial.gob.bo/consejo/manualprocedimientosddrr/46_-certificado-de-gravamenes.html | 2026-09-27 |
| F-DDRR-03 | Derechos Reales | Certificado Alodial — requisitos | https://cm.organojudicial.gob.bo/consejo/requisitosddrr/45_-certificado-alodial.html | 2026-09-27 |
| F-DDRR-04 | Derechos Reales | Compra Venta — procedimiento | https://cm.organojudicial.gob.bo/consejo/manualprocedimientosddrr/4_-compra-venta.html | 2026-09-27 |
| F-IMP-01 | GAM Cochabamba | Consulta de deudas | https://www.gob.bo/tramites/consulta-de-deudas | 2026-09-27 |
| F-IMP-02 | RUAT | Consulta deuda — vehículos | https://www.ruat.gob.bo/vehiculos/consultageneral/InicioBusquedaVehiculo.jsf | 2026-09-27 |
| F-IMP-03 | RUAT | Consulta deuda — inmuebles | https://www.ruat.gob.bo/inmuebles/consultageneral/InicioBusquedaInmueble.jsf | 2026-09-27 |
| F-IMP-04 | RUAT | Preguntas frecuentes | https://ns01.ruat.gob.bo/informaciongeneral/preguntasfrecuentes/InicioPreguntasFrecuentes.jsf | 2026-09-27 |
| F-IMP-05 | Opinión | Perdonazo y pronto pago 2026 | https://www.opinion.com.bo/cochabamba/amplia-perdonazo-octubre-habra-100-condonacion-multas-intereses/20260701171355992896.html | 2026-09-27 |

## Hechos verificados
| ID | Institución | Hecho | Tipo | Fuente | Vigencia |
|---|---|---|---|---|---|
| H-DDRR-01 | Derechos Reales | Para Folio Real actualizado, la página oficial publicada enumera Formulario 003 para el titular, Folio Real y cédula; señala entrega inmediata. | requisito/plazo | F-DDRR-01 | Página oficial sin fecha visible de actualización; [VERIFICAR] vigencia al 2026-09-27 |
| H-DDRR-02 | Derechos Reales | El certificado de gravámenes requiere cédula y número de matrícula según la publicación consultada; señala entrega inmediata. | requisito/plazo | F-DDRR-02 | Página oficial sin fecha visible de actualización; [VERIFICAR] vigencia al 2026-09-27 |
| H-DDRR-03 | Derechos Reales | Para certificado alodial se publica Formulario 003 al titular, cédula y memorial para terceras personas. | requisito | F-DDRR-03 | Página oficial sin fecha visible de actualización; [VERIFICAR] vigencia al 2026-09-27 |
| H-DDRR-04 | Derechos Reales | Para compra venta se publican escritura pública, impuestos correspondientes, documento catastral y documentos de identidad. | requisito | F-DDRR-04 | Página oficial sin fecha visible de actualización; [VERIFICAR] vigencia al 2026-09-27 |
| H-DDRR-05 | Derechos Reales | La publicación de compra venta señala un plazo de tres días hábiles. | plazo | F-DDRR-04 | Página oficial sin fecha visible de actualización; [VERIFICAR] vigencia al 2026-09-27 |
| H-DDRR-06 | Derechos Reales | [VERIFICAR] arancel vigente 2026 de los trámites descritos. | costo | — | [VERIFICAR] |
| H-DDRR-07 | Derechos Reales | [VERIFICAR] horario y dirección exactos vigentes de la oficina de Cochabamba. | horario/lugar | — | [VERIFICAR] |
| H-IMP-01 | GAM Cochabamba | La ficha estatal ofrece consulta virtual de obligaciones tributarias municipales y figura actualizada el 2026-08-05. | servicio | F-IMP-01 | Actualizado 2026-08-05; consultado 2026-09-27 |
| H-IMP-02 | RUAT | La consulta de vehículo permite placa PTA, póliza, placa anterior o COPO. | procedimiento | F-IMP-02 | Función verificada 2026-09-27; página sin fecha visible de actualización |
| H-IMP-03 | RUAT | La placa actual se introduce sin espacios ni guiones. | procedimiento | F-IMP-02 | Función verificada 2026-09-27; página sin fecha visible de actualización |
| H-IMP-04 | RUAT | La consulta de inmuebles admite número de inmueble o código catastral y selección del Gobierno Municipal. | procedimiento | F-IMP-03 | Función verificada 2026-09-27; página sin fecha visible de actualización |
| H-IMP-05 | RUAT | El número de inmueble o código catastral puede localizarse en una boleta de pago anterior. | orientación | F-IMP-03 | Función verificada 2026-09-27 |
| H-IMP-06 | GAM Cochabamba | Para la gestión 2025 se informó 10% de descuento por pronto pago hasta el 2026-12-28. | descuento | F-IMP-05 | Publicado 2026-07-01; vigente a fecha de corte según plazo informado |
| H-IMP-07 | GAM Cochabamba | Se informó condonación del 100% de multas e intereses para deudas 1995–2024 hasta el 2026-10-05. | beneficio temporal | F-IMP-05 | Publicado 2026-07-01; vigente a fecha de corte según plazo informado |
| H-IMP-08 | RUAT | Plan Cuotas de vehículo se solicita al municipio donde está radicado el vehículo. | procedimiento | F-IMP-04 | Consultado 2026-09-27 |
| H-IMP-09 | RUAT | Para Plan Cuotas se publican como básicos copia del CRPVA y documento de identidad; pueden pedir documentación adicional. | requisito | F-IMP-04 | Consultado 2026-09-27 |
| H-IMP-10 | RUAT | El cambio de propiedad actualiza los datos del vehículo y cambia el CRPVA. | procedimiento | F-IMP-04 | Consultado 2026-09-27 |
| H-IMP-11 | RUAT | Para impuesto a la transferencia se considera el mayor valor entre precio pagado y base imponible aplicable. | cálculo | F-IMP-04 | Consultado 2026-09-27 |
| H-IMP-12 | GAM Cochabamba | [VERIFICAR] requisitos completos, oficina, costos y secuencia presencial para transferencia vehicular en Cochabamba. | procedimiento | — | [VERIFICAR] |

## ESC-DDRR-01 — Folio Real actualizado

- **Institución:** Derechos Reales – Cochabamba
- **Trámite:** Folio Real actualizado
- **Tipo:** conocimiento_fijo
- **Inicia:** Usuario Sordo
- **Situación:** El propietario quiere un Folio actualizado, pero le falta un requisito.

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Usuario Sordo | Necesito un Folio Real actualizado de mi casa. | Iniciar | — |
| 2 | Funcionario | ¿Usted figura como titular del inmueble? | Verificar titularidad | H-DDRR-01 |
| 3 | Usuario Sordo | Sí. La casa está registrada a mi nombre. | Confirmar | — |
| 4 | Funcionario | ¿Trae cédula, Folio Real y Formulario 003? | Revisar requisitos | H-DDRR-01 |
| 5 | Usuario Sordo | Tengo cédula y Folio, pero no formulario. | Informar faltante | — |
| 6 | Funcionario | Complete el Formulario 003 antes de ingresar la solicitud. | Orientar | H-DDRR-01 |
| 7 | Usuario Sordo | ¿Después puedo volver hoy? | Consultar continuidad | — |
| 8 | Funcionario | La página señala entrega inmediata; horario actual está [VERIFICAR]. | Cerrar | H-DDRR-01, H-DDRR-07 |

### Variantes

- **Turno 2 (Funcionario):** «¿El inmueble está a nombre de usted?» · «¿Usted es titular registrado?»
- **Respuestas:** «Sí, está a mi nombre.» · «No, pertenece a otra persona.» · «No sé quién figura.»
- **Turno 4 (Funcionario):** «¿Tiene los tres documentos publicados?» · «¿Trajo el Formulario 003?»
- **Respuestas:** «Sí, tengo todo.» · «No tengo el formulario.» · «No sé cuál es.»

### Datos ficticios

- Matrícula: 3.01.1.99.0012345 (ficticia)

## ESC-DDRR-02 — Certificado de gravámenes

- **Institución:** Derechos Reales – Cochabamba
- **Trámite:** Certificado de gravámenes
- **Tipo:** mixto
- **Inicia:** Funcionario
- **Situación:** La persona quiere saber si existen gravámenes registrados.

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Funcionario | ¿Qué información necesita del inmueble? | Identificar necesidad | — |
| 2 | Usuario Sordo | Quiero saber si mi casa tiene hipoteca. | Expresar necesidad | — |
| 3 | Funcionario | ¿Tiene el número de matrícula? | Solicitar dato | H-DDRR-02 |
| 4 | Usuario Sordo | Sí. Lo tengo guardado en mi celular. | Confirmar | — |
| 5 | Funcionario | ¿Trae también su cédula de identidad? | Revisar requisito | H-DDRR-02 |
| 6 | Usuario Sordo | Sí, aquí está mi cédula. | Entregar requisito | — |
| 7 | Funcionario | El certificado informa gravámenes registrados del inmueble. | Explicar | H-DDRR-02 |
| 8 | Usuario Sordo | Quiero solicitar ese certificado. | Cerrar | — |

### Variantes

- **Turno 3 (Funcionario):** «¿Conoce la matrícula?» · «¿Trae el número del Folio?»
- **Respuestas:** «Sí, la tengo.» · «No la tengo.» · «No sé dónde verla.»
- **Turno 5 (Funcionario):** «¿Tiene su cédula?» · «¿Trajo documento de identidad?»
- **Respuestas:** «Sí, la tengo.» · «No la traje.» · «No sé si sirve copia.»

### Datos ficticios

- Matrícula: 3.01.1.01.0098765 (ficticia)

## ESC-DDRR-03 — Certificado alodial por tercera persona

- **Institución:** Derechos Reales – Cochabamba
- **Trámite:** Certificado alodial por tercera persona
- **Tipo:** conocimiento_fijo
- **Inicia:** Usuario Sordo
- **Situación:** La solicitante no es titular y desconoce el requisito adicional.

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Usuario Sordo | Necesito certificado del lote de mi hermana. | Iniciar | — |
| 2 | Funcionario | ¿Usted es titular del inmueble? | Clasificar solicitante | H-DDRR-03 |
| 3 | Usuario Sordo | No. El lote pertenece a mi hermana. | Responder | — |
| 4 | Funcionario | ¿Tiene memorial para solicitarlo como tercera persona? | Revisar requisito | H-DDRR-03 |
| 5 | Usuario Sordo | No tengo memorial. Solo traje mi cédula. | Informar faltante | — |
| 6 | Funcionario | La publicación exige memorial para terceras personas. | Orientar | H-DDRR-03 |
| 7 | Usuario Sordo | Volveré cuando tenga el memorial. | Cerrar | — |

### Variantes

- **Turno 2 (Funcionario):** «¿El inmueble está a su nombre?» · «¿Usted figura como propietaria?»
- **Respuestas:** «Sí, soy titular.» · «No, es de mi hermana.» · «No sé.»
- **Turno 4 (Funcionario):** «¿Trajo memorial de solicitud?» · «¿Tiene solicitud formal?»
- **Respuestas:** «Sí, lo traje.» · «No lo tengo.» · «No sé qué memorial.»

### Datos ficticios

- Titular mencionada: Ana Pérez Flores (ficticia)

## ESC-DDRR-04 — Inscripción de compra venta

- **Institución:** Derechos Reales – Cochabamba
- **Trámite:** Inscripción de compra venta
- **Tipo:** conocimiento_fijo
- **Inicia:** Funcionario
- **Situación:** El comprador tiene escritura, pero le falta documentación.

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Funcionario | ¿Qué trámite viene a registrar? | Identificar | — |
| 2 | Usuario Sordo | Compré una casa. Quiero ponerla a mi nombre. | Explicar | — |
| 3 | Funcionario | ¿Trae la escritura pública de compra venta? | Revisar requisito | H-DDRR-04 |
| 4 | Usuario Sordo | Sí. Aquí tengo la escritura. | Confirmar | — |
| 5 | Funcionario | ¿Tiene impuestos y documento catastral actualizado? | Revisar requisitos | H-DDRR-04 |
| 6 | Usuario Sordo | Me falta el certificado catastral. | Informar faltante | — |
| 7 | Funcionario | Complete los documentos antes de ingresar la inscripción. | Orientar | H-DDRR-04 |
| 8 | Usuario Sordo | Volveré cuando tenga todo. | Cerrar | — |
| 9 | Funcionario | La publicación señala tres días; vigencia actual está [VERIFICAR]. | Plazo | H-DDRR-05 |

### Variantes

- **Turno 3 (Funcionario):** «¿Tiene la escritura pública?» · «¿Trajo el testimonio de compra?»
- **Respuestas:** «Sí, lo tengo.» · «No lo traje.» · «No sé cuál es.»
- **Turno 5 (Funcionario):** «¿Trae impuestos y catastro?» · «¿Tiene documentación tributaria y catastral?»
- **Respuestas:** «Sí, tengo todo.» · «Me falta un documento.» · «No sé si están vigentes.»

### Datos ficticios

- Comprador: Carlos Rojas Lima (ficticio)
- Matrícula: 3.01.1.99.0045678 (ficticia)

## ESC-IMP-01 — Consulta de deuda de moto por placa

- **Institución:** GAM Cochabamba / RUAT
- **Trámite:** Consulta de deuda de moto por placa
- **Tipo:** mixto
- **Inicia:** Usuario Sordo
- **Situación:** La persona quiere conocer la deuda antes de pagar.

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Usuario Sordo | Quiero saber cuánto debo de mi moto. | Iniciar | — |
| 2 | Funcionario | ¿Tiene la placa actual del vehículo? | Identificar | H-IMP-02 |
| 3 | Usuario Sordo | Sí. La placa es 4821ABC. | Dato ficticio | — |
| 4 | Funcionario | RUAT permite consultar usando la placa actual. | Orientar | H-IMP-02 |
| 5 | Funcionario | Escríbala sin espacios ni guiones. | Indicar formato | H-IMP-03 |
| 6 | Usuario Sordo | ¿El monto aparece en línea? | Consultar | — |
| 7 | Funcionario | Sí; el monto concreto será un dato en vivo. | Separar dato vivo | H-IMP-01 |

### Variantes

- **Turno 2 (Funcionario):** «¿Conoce la placa?» · «¿Tiene la placa actual?»
- **Respuestas:** «Sí, la tengo.» · «No la tengo.» · «No sé cuál es.»

### Datos ficticios

- Placa: 4821ABC (ficticia)
- Monto: dato_en_vivo

## ESC-IMP-02 — Consulta de deuda de inmueble

- **Institución:** GAM Cochabamba / RUAT
- **Trámite:** Consulta de deuda de inmueble
- **Tipo:** mixto
- **Inicia:** Funcionario
- **Situación:** La persona tiene una boleta antigua, pero no recuerda el identificador.

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Funcionario | ¿Busca deuda de inmueble o vehículo? | Clasificar | H-IMP-01 |
| 2 | Usuario Sordo | Quiero revisar la deuda de mi casa. | Indicar | — |
| 3 | Funcionario | ¿Tiene número de inmueble o código catastral? | Solicitar dato | H-IMP-04 |
| 4 | Usuario Sordo | No recuerdo esos números. | Dificultad | — |
| 5 | Funcionario | Puede buscarlos en una boleta de pago anterior. | Orientar | H-IMP-05 |
| 6 | Usuario Sordo | Sí tengo mi última boleta. | Confirmar | — |
| 7 | Funcionario | Seleccione Cochabamba e ingrese el identificador. | Procedimiento | H-IMP-04 |

### Variantes

- **Turno 3 (Funcionario):** «¿Conoce el número de inmueble?» · «¿Tiene código catastral?»
- **Respuestas:** «Sí, lo tengo.» · «No lo tengo.» · «No sé dónde está.»

### Datos ficticios

- Número de inmueble: 0012345678 (ficticio)
- Deuda: dato_en_vivo

## ESC-IMP-03 — Descuento de pronto pago 2026

- **Institución:** GAM Cochabamba / RUAT
- **Trámite:** Descuento de pronto pago 2026
- **Tipo:** conocimiento_fijo
- **Inicia:** Usuario Sordo
- **Situación:** Consulta realizada en la fecha de corte del corpus.

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Usuario Sordo | ¿Todavía hay descuento si pago hoy? | Consultar | — |
| 2 | Funcionario | Para gestión 2025 se informó 10% hasta diciembre. | Informar | H-IMP-06 |
| 3 | Funcionario | ¿Su deuda corresponde solamente a 2025? | Diferenciar | H-IMP-06 |
| 4 | Usuario Sordo | Solo debo la gestión 2025. | Responder | — |
| 5 | Funcionario | Consulte primero el monto actualizado antes de pagar. | Evitar dato inventado | H-IMP-01 |
| 6 | Usuario Sordo | Haré la consulta en línea. | Cerrar | — |

### Variantes

- **Turno 3 (Funcionario):** «¿Debe solo 2025?» · «¿Tiene gestiones anteriores?»
- **Respuestas:** «Solo 2025.» · «También años anteriores.» · «No sé.»

### Datos ficticios

- Monto adeudado: dato_en_vivo

## ESC-IMP-04 — Perdonazo de deudas antiguas

- **Institución:** GAM Cochabamba / RUAT
- **Trámite:** Perdonazo de deudas antiguas
- **Tipo:** mixto
- **Inicia:** Funcionario
- **Situación:** La persona pregunta por deudas 2022 y 2023.

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Funcionario | ¿Su deuda es de vehículo, inmueble o actividad? | Clasificar | H-IMP-07 |
| 2 | Usuario Sordo | Tengo deuda antigua de mi casa. | Indicar | — |
| 3 | Funcionario | ¿De qué años son las deudas? | Determinar periodo | H-IMP-07 |
| 4 | Usuario Sordo | Debo las gestiones 2022 y 2023. | Dato ficticio | — |
| 5 | Funcionario | Se informó condonación de multas e intereses hasta octubre. | Informar | H-IMP-07 |
| 6 | Usuario Sordo | ¿Entonces no pago el impuesto? | Aclarar | — |
| 7 | Funcionario | No. Debe consultar el tributo principal pendiente. | Corregir | H-IMP-07 |

### Variantes

- **Turno 3 (Funcionario):** «¿Qué gestiones debe?» · «¿Desde qué año tiene deuda?»
- **Respuestas:** «2022 y 2023.» · «No debo años anteriores.» · «No sé.»

### Datos ficticios

- Gestiones: 2022 y 2023 (ficticias)
- Monto principal: dato_en_vivo

## ESC-IMP-05 — Plan de cuotas de vehículo

- **Institución:** GAM Cochabamba / RUAT
- **Trámite:** Plan de cuotas de vehículo
- **Tipo:** conocimiento_fijo
- **Inicia:** Usuario Sordo
- **Situación:** La persona no puede pagar todo inmediatamente.

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Usuario Sordo | No puedo pagar toda la deuda del auto. | Problema | — |
| 2 | Funcionario | ¿Quiere solicitar un Plan Cuotas? | Identificar | H-IMP-08 |
| 3 | Usuario Sordo | Sí. Quiero pagar en cuotas. | Confirmar | — |
| 4 | Funcionario | ¿El vehículo está radicado en Cochabamba? | Competencia | H-IMP-08 |
| 5 | Usuario Sordo | Sí. Está registrado aquí. | Confirmar | — |
| 6 | Funcionario | ¿Trae copia del CRPVA y su cédula? | Requisitos | H-IMP-09 |
| 7 | Usuario Sordo | Tengo cédula, pero no traje CRPVA. | Faltante | — |
| 8 | Funcionario | Vuelva con ese documento; pueden pedir otros adicionales. | Orientar | H-IMP-09 |

### Variantes

- **Turno 6 (Funcionario):** «¿Tiene CRPVA y cédula?» · «¿Trajo propiedad y documento?»
- **Respuestas:** «Sí, ambos.» · «No tengo CRPVA.» · «No sé cuál es.»

### Datos ficticios

- Placa: 3912XYZ (ficticia)

## ESC-IMP-06 — Transferencia de vehículo

- **Institución:** GAM Cochabamba / RUAT
- **Trámite:** Transferencia de vehículo
- **Tipo:** mixto
- **Inicia:** Usuario Sordo
- **Situación:** Compró un vehículo usado y necesita cambio de titularidad.

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Usuario Sordo | Compré un auto. Quiero pasarlo a mi nombre. | Iniciar | — |
| 2 | Funcionario | ¿Está radicado actualmente en Cochabamba? | Competencia | H-IMP-12 |
| 3 | Usuario Sordo | Sí. Está registrado en Cochabamba. | Confirmar | — |
| 4 | Funcionario | El cambio de propiedad actualiza datos y CRPVA. | Explicar | H-IMP-10 |
| 5 | Funcionario | ¿Ya firmaron el documento de compra venta? | Estado | H-IMP-12 |
| 6 | Usuario Sordo | Sí. Ya firmamos la compra. | Confirmar | — |
| 7 | Funcionario | [VERIFICAR] requisitos presenciales completos antes de venir. | Evitar inventar | H-IMP-12 |

### Variantes

- **Turno 2 (Funcionario):** «¿El auto está radicado aquí?» · «¿Cochabamba figura como radicatoria?»
- **Respuestas:** «Sí.» · «No.» · «No sé.»

### Datos ficticios

- Comprador: Mario Flores Rojas (ficticio)
- Placa: 5678KLM (ficticia)

CONTINÚA EN LA PARTE 2

---

# Escenarios de trámites en Cochabamba — Parte 2 de 7

## Fuentes
| ID | Institución | Título | URL | Consultado |
|---|---|---|---|---|
| F-FIS-01 | Ministerio Público | Código de Procedimiento Penal — denuncia | https://obs.organojudicial.gob.bo/wp-content/anexos/archivos/normativa/e0abc5c64b992ee58de451af9c9acde8.pdf | 2026-09-27 |
| F-FIS-02 | Ministerio Público | Fiscalía General del Estado / Fiscalía ROMA | https://www.fiscalia.gob.bo/ | 2026-09-27 |
| F-FIS-03 | Ministerio Público | Ecosistema ROMA en Expocruz 2026 | https://www.fiscalia.gob.bo/comunicacion/noticias/el-ministerio-publico-le-muestra-a-bolivia-el-rostro-tecnologico-del-ecosistema-roma-argo-y-ley-n1636-en-la-expocruz-2026 | 2026-09-27 |
| F-FIS-04 | Fiscalía Cochabamba | Puntos de información en plataformas | https://www.fiscalia.gob.bo/comunicacion/noticias/cochabamba-fiscalia-habilita-puntos-de-informacion-para-no-videntes-con-cartillas-informativas-braille-en-plataformas-de-atencion-al-publico | 2026-09-27 |
| F-OJ-01 | Órgano Judicial | SIREJ — consulta | https://magistratura.organojudicial.gob.bo/sirej/?r=consulta%2Findex | 2026-09-27 |
| F-OJ-02 | Órgano Judicial | SIREJ — forma de uso | https://magistratura.organojudicial.gob.bo/sirej/?r=formauso%2Findex | 2026-09-27 |
| F-OJ-03 | TDJ Cochabamba | Contactos y horarios | https://tdjcbba.organojudicial.gob.bo/Home/Contact | 2026-09-27 |
| F-OJ-04 | TDJ Cochabamba | Sede Los Ceibos | https://tdjcbba.organojudicial.gob.bo/Paper/Detail/13880 | 2026-09-27 |
| F-OJ-05 | TDJ Cochabamba | Sede EPI Sur | https://tdjcbba.organojudicial.gob.bo/Paper/Detail/13900 | 2026-09-27 |
| F-OJ-06 | Órgano Judicial | SIGC | https://justicia.organojudicial.gob.bo/login | 2026-09-27 |

## Hechos verificados
| ID | Institución | Hecho | Tipo | Fuente | Vigencia |
|---|---|---|---|---|---|
| H-FIS-01 | Ministerio Público | La denuncia puede presentarse por escrito o verbalmente; la verbal se registra en formulario oficial. | procedimiento | F-FIS-01 | Norma consultada 2026-09-27 |
| H-FIS-02 | Ministerio Público | La denuncia debe incluir, en lo posible, relación del hecho, tiempo, lugar y datos para su comprobación. | contenido | F-FIS-01 | Norma consultada 2026-09-27 |
| H-FIS-03 | Ministerio Público | Fiscalía ROMA permite seguimiento de procesos penales y consulta de información asociada a la causa. | servicio digital | F-FIS-02, F-FIS-03 | Funcionalidad verificada 2026-09-27 |
| H-FIS-04 | Fiscalía Cochabamba | En 2026 se informó que las plataformas brindan orientación sobre ruta y requisitos para denuncias o querellas. | orientación | F-FIS-04 | Publicado 2026-03-20 |
| H-FIS-05 | Fiscalía Cochabamba | El estado concreto del caso, fiscal asignado y actuaciones son datos en vivo del expediente. | dato_en_vivo | — | Depende del caso |
| H-OJ-01 | Órgano Judicial | SIREJ permite seguimiento de expedientes judiciales. | servicio digital | F-OJ-02 | Consultado 2026-09-27 |
| H-OJ-02 | Órgano Judicial | Para consulta se utiliza NUREJ, WebID y departamento donde radica el expediente. | procedimiento | F-OJ-02 | Consultado 2026-09-27 |
| H-OJ-03 | Órgano Judicial | NUREJ y WebID se encuentran en la carátula del expediente. | orientación | F-OJ-02 | Consultado 2026-09-27 |
| H-OJ-04 | Órgano Judicial | Si se desconocen NUREJ o WebID, SIREJ indica acudir a información o plataforma del Tribunal Departamental. | orientación | F-OJ-02 | Consultado 2026-09-27 |
| H-OJ-05 | TDJ Cochabamba | El portal institucional muestra Av. San Martín entre Jordán y Sucre como contacto. | lugar | F-OJ-03 | Página sin fecha visible de actualización; consultada 2026-09-27 |
| H-OJ-06 | TDJ Cochabamba | El portal muestra lunes a viernes 08:00–12:00 y 14:30–18:30. | horario | F-OJ-03 | Página sin fecha visible de actualización; consultada 2026-09-27 |
| H-OJ-07 | TDJ Cochabamba | Publicación de 2025 ubica Juzgados de Familia 7 y 8 en Los Ceibos. | lugar | F-OJ-04 | Publicado 2025-05-13; [VERIFICAR] antes de asistir |
| H-OJ-08 | TDJ Cochabamba | Publicación de 2025 ubica Juzgados de Familia 1 y 2 en EPI Sur. | lugar | F-OJ-05 | Publicado 2025-05-14; [VERIFICAR] antes de asistir |
| H-OJ-09 | Órgano Judicial | Fecha, hora y modalidad de una audiencia son datos en vivo del expediente. | dato_en_vivo | F-OJ-06 | Depende del caso |

## ESC-FIS-01 — Presentar denuncia verbal por robo

- **Institución:** Ministerio Público – Fiscalía Departamental de Cochabamba
- **Trámite:** Presentar denuncia verbal por robo
- **Tipo:** mixto
- **Inicia:** Usuario Sordo
- **Situación:** La persona no preparó denuncia escrita.

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Usuario Sordo | Quiero denunciar el robo de mi celular. | Iniciar | — |
| 2 | Funcionario | ¿Desea denunciar verbalmente o trae escrito? | Modalidad | H-FIS-01 |
| 3 | Usuario Sordo | Quiero hacerlo verbalmente. | Elegir | — |
| 4 | Funcionario | Puede hacerlo; se registrará en el formulario correspondiente. | Explicar | H-FIS-01 |
| 5 | Funcionario | ¿Cuándo y dónde ocurrió el robo? | Recabar hechos | H-FIS-02 |
| 6 | Usuario Sordo | Ayer, cerca de mi casa. | Relatar | — |
| 7 | Funcionario | Describa solo lo que recuerda con seguridad. | Orientar | H-FIS-02 |

### Variantes

- **Turno 2 (Funcionario):** «¿Quiere denunciar verbalmente?» · «¿Trajo una denuncia escrita?»
- **Respuestas:** «Verbalmente.» · «Ya la traje escrita.» · «No sé cómo hacerlo.»

### Datos ficticios

- Nombre: Diego Flores Rojas (ficticio)
- Número de caso posterior: dato_en_vivo

## ESC-FIS-02 — Orientación para denuncia escrita

- **Institución:** Ministerio Público – Fiscalía Departamental de Cochabamba
- **Trámite:** Orientación para denuncia escrita
- **Tipo:** conocimiento_fijo
- **Inicia:** Funcionario
- **Situación:** La persona tiene un relato incompleto.

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Funcionario | ¿Viene a denunciar o necesita orientación? | Identificar | H-FIS-04 |
| 2 | Usuario Sordo | Necesito ayuda para escribir mi denuncia. | Pedir apoyo | — |
| 3 | Funcionario | ¿Trajo algún relato de lo ocurrido? | Revisar | H-FIS-02 |
| 4 | Usuario Sordo | Sí, pero escribí muy poco. | Responder | — |
| 5 | Funcionario | Incluya qué pasó, cuándo y dónde, si lo sabe. | Orientar | H-FIS-02 |
| 6 | Usuario Sordo | No sé quién fue la persona. | Duda | — |
| 7 | Funcionario | Indique lo conocido; no complete datos que desconoce. | Evitar invención | H-FIS-02 |

### Variantes

- **Turno 3 (Funcionario):** «¿Ya escribió lo ocurrido?» · «¿Tiene un borrador?»
- **Respuestas:** «Sí.» · «No.» · «No sé cómo empezar.»

### Datos ficticios

- Hecho: robo de mochila (ficticio)

## ESC-FIS-03 — Seguimiento de denuncia

- **Institución:** Ministerio Público – Fiscalía Departamental de Cochabamba
- **Trámite:** Seguimiento de denuncia
- **Tipo:** dato_en_vivo
- **Inicia:** Usuario Sordo
- **Situación:** La denuncia ya fue registrada.

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Usuario Sordo | Quiero saber qué pasó con mi denuncia. | Consultar | — |
| 2 | Funcionario | ¿Su caso ya está registrado? | Identificar | — |
| 3 | Usuario Sordo | Sí. Denuncié un robo hace dos semanas. | Antecedente | — |
| 4 | Funcionario | Fiscalía ROMA permite seguimiento de procesos penales. | Herramienta | H-FIS-03 |
| 5 | Funcionario | ¿Puede ingresar a su cuenta? | Canal | H-FIS-03 |
| 6 | Usuario Sordo | Sí, pero no sé dónde revisar. | Dificultad | — |
| 7 | Funcionario | El estado concreto debe consultarse en su expediente. | Separar dato vivo | H-FIS-05 |

### Variantes

- **Turno 5 (Funcionario):** «¿Tiene acceso a ROMA?» · «¿Puede ingresar a su cuenta?»
- **Respuestas:** «Sí.» · «No.» · «No sé.»

### Datos ficticios

- Caso: CBBA-2026-000123 (ficticio)
- Estado: dato_en_vivo

## ESC-FIS-04 — Identificar fiscal asignado

- **Institución:** Ministerio Público – Fiscalía Departamental de Cochabamba
- **Trámite:** Identificar fiscal asignado
- **Tipo:** dato_en_vivo
- **Inicia:** Funcionario
- **Situación:** La persona desconoce quién lleva su caso.

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Funcionario | ¿Qué necesita consultar de su proceso? | Identificar | — |
| 2 | Usuario Sordo | Quiero saber quién es mi fiscal. | Solicitar dato vivo | — |
| 3 | Funcionario | ¿Tiene acceso a su proceso en ROMA? | Preparar consulta | H-FIS-03 |
| 4 | Usuario Sordo | Tengo el caso, pero no sé usarlo. | Dificultad | — |
| 5 | Funcionario | Debemos revisar la información de su expediente. | Consultar | H-FIS-05 |
| 6 | Usuario Sordo | ¿Puede ayudarme a encontrarlo? | Solicitar apoyo | — |
| 7 | Funcionario | Sí. No debemos asumir el nombre del fiscal. | Evitar invención | H-FIS-05 |

### Variantes

- **Turno 3 (Funcionario):** «¿Tiene acceso a ROMA?» · «¿Su causa aparece en ROMA?»
- **Respuestas:** «Sí.» · «No.» · «No sé usarlo.»

### Datos ficticios

- Caso: CBBA-2026-000456 (ficticio)
- Fiscal: dato_en_vivo

## ESC-OJ-01 — Consultar causa con NUREJ y WebID

- **Institución:** Órgano Judicial – TDJ Cochabamba
- **Trámite:** Consultar causa con NUREJ y WebID
- **Tipo:** mixto
- **Inicia:** Usuario Sordo
- **Situación:** La persona tiene la carátula del expediente.

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Usuario Sordo | Quiero saber cómo está mi proceso. | Consultar | — |
| 2 | Funcionario | ¿Tiene NUREJ y WebID? | Solicitar claves | H-OJ-02 |
| 3 | Usuario Sordo | Sí. Los tengo en este documento. | Confirmar | — |
| 4 | Funcionario | Esos datos están en la carátula del expediente. | Orientar | H-OJ-03 |
| 5 | Funcionario | ¿Su proceso está en Cochabamba? | Departamento | H-OJ-02 |
| 6 | Usuario Sordo | Sí. Está en Cochabamba. | Confirmar | — |
| 7 | Funcionario | Ingrese ambos códigos y seleccione Cochabamba en SIREJ. | Procedimiento | H-OJ-02 |

### Variantes

- **Turno 2 (Funcionario):** «¿Trae NUREJ y WebID?» · «¿Tiene los códigos del expediente?»
- **Respuestas:** «Sí.» · «No.» · «No sé cuáles son.»

### Datos ficticios

- NUREJ: 30123456 (ficticio)
- WebID: ABCD1234 (ficticio)

## ESC-OJ-02 — No conoce NUREJ ni WebID

- **Institución:** Órgano Judicial – TDJ Cochabamba
- **Trámite:** No conoce NUREJ ni WebID
- **Tipo:** mixto
- **Inicia:** Funcionario
- **Situación:** La persona no tiene la carátula.

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Funcionario | ¿Quiere consultar un expediente judicial? | Identificar | — |
| 2 | Usuario Sordo | Sí, pero no sé mi NUREJ. | Problema | — |
| 3 | Funcionario | ¿Tiene la carátula del expediente? | Buscar claves | H-OJ-03 |
| 4 | Usuario Sordo | No. No tengo ninguna carátula. | Responder | — |
| 5 | Funcionario | SIREJ indica acudir a información del Tribunal. | Orientar | H-OJ-04 |
| 6 | Usuario Sordo | ¿Dónde está el Tribunal Departamental? | Ubicación | — |
| 7 | Funcionario | El portal señala avenida San Martín entre Jordán y Sucre. | Informar | H-OJ-05 |

### Variantes

- **Turno 3 (Funcionario):** «¿Tiene la carátula?» · «¿Trajo algún documento del expediente?»
- **Respuestas:** «Sí.» · «No.» · «No sé cuál es.»

### Datos ficticios

- Nombre: Elena Vargas López (ficticio)

## ESC-OJ-03 — Ubicar juzgado de familia

- **Institución:** Órgano Judicial – TDJ Cochabamba
- **Trámite:** Ubicar juzgado de familia
- **Tipo:** mixto
- **Inicia:** Usuario Sordo
- **Situación:** La citación indica Juzgado de Familia 7.

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Usuario Sordo | Tengo audiencia familiar. No sé dónde ir. | Pedir orientación | — |
| 2 | Funcionario | ¿Qué número de juzgado aparece? | Identificar | — |
| 3 | Usuario Sordo | Dice Juzgado de Familia número siete. | Responder | — |
| 4 | Funcionario | Una publicación de 2025 lo ubica en Los Ceibos. | Ubicar | H-OJ-07 |
| 5 | Usuario Sordo | ¿Sigue funcionando allí? | Comprobar | — |
| 6 | Funcionario | [VERIFICAR] ubicación actual antes de asistir. | Cautela temporal | H-OJ-07 |

### Variantes

- **Turno 2 (Funcionario):** «¿Qué juzgado figura?» · «¿Conoce el número del juzgado?»
- **Respuestas:** «Familia 7.» · «No aparece.» · «No sé dónde mirar.»

### Datos ficticios

- NUREJ: 30246810 (ficticio)

## ESC-OJ-04 — Confirmar modalidad de audiencia

- **Institución:** Órgano Judicial – TDJ Cochabamba
- **Trámite:** Confirmar modalidad de audiencia
- **Tipo:** dato_en_vivo
- **Inicia:** Funcionario
- **Situación:** La persona no sabe si la audiencia será virtual.

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Funcionario | ¿Qué necesita saber sobre su audiencia? | Identificar | — |
| 2 | Usuario Sordo | No sé si mi audiencia es virtual. | Duda | — |
| 3 | Funcionario | ¿Tiene NUREJ y WebID? | Preparar consulta | H-OJ-02 |
| 4 | Usuario Sordo | Sí. Tengo ambos códigos. | Confirmar | — |
| 5 | Funcionario | La modalidad depende del señalamiento de su expediente. | Separar dato vivo | H-OJ-09 |
| 6 | Usuario Sordo | Quiero revisar fecha y modalidad. | Definir consulta | — |
| 7 | Funcionario | Debemos consultar el expediente; no se puede asumir. | Cerrar | H-OJ-09 |

### Variantes

- **Turno 3 (Funcionario):** «¿Tiene los códigos del expediente?» · «¿Cuenta con NUREJ y WebID?»
- **Respuestas:** «Sí.» · «No.» · «No sé.»

### Datos ficticios

- NUREJ: 30987654 (ficticio)
- Modalidad: dato_en_vivo

CONTINÚA EN LA PARTE 3

---

# Escenarios de trámites en Cochabamba — Parte 3 de 7

## Fuentes
| ID | Institución | Título | URL | Consultado |
|---|---|---|---|---|
| F-SEPDEP-01 | SEPDEP | Sitio institucional — misión y defensa penal gratuita | https://sepdep.gob.bo/ | 2026-09-27 |
| F-SEPDEP-02 | SEPDEP | Misión, visión y principios | https://sepdep.gob.bo/index.php/declaracion-de-la-mision-vision-valores-y-principios-de-la-entidad/ | 2026-09-27 |
| F-SEPDEP-03 | SEPDEP | Direcciones y horarios | https://sepdep.gob.bo/index.php/contacto2/ | 2026-09-27 |
| F-SEPDAVI-01 | SEPDAVI | Entidad y servicios | https://www.gob.bo/entidades/servicio-plurinacional-de-asistencia-a-la-victima | 2026-09-27 |
| F-SEPDAVI-02 | SEPDAVI | Asesoramiento a víctimas de lesiones | https://www.gob.bo/tramites/asesoramiento-y-representacion-legal-a-victimas-de-lesiones-graves-y-leves | 2026-09-27 |
| F-SEPDAVI-03 | SEPDAVI | Atención a víctimas de violencia familiar | https://www.gob.bo/tramites/apoyo-profesional-y-completo-a-victimas-de-violencia-familiar-o-domestica | 2026-09-27 |
| F-SEPDAVI-04 | SEPDAVI | Direcciones | https://sepdavi.gob.bo/?page_id=17608 | 2026-09-27 |
| F-SEPDAVI-05 | SEPDAVI | Ruta de atención y procesos | https://sepdavi.gob.bo/?page_id=17664 | 2026-09-27 |

## Hechos verificados
| ID | Institución | Hecho | Tipo | Fuente | Vigencia |
|---|---|---|---|---|---|
| H-SEPDEP-01 | SEPDEP | Presta defensa penal técnica gratuita a personas denunciadas, imputadas o procesadas carentes de recursos económicos y a quienes no designen abogado. | competencia | F-SEPDEP-01, F-SEPDEP-02 | Sitio oficial consultado 2026-09-27 |
| H-SEPDEP-02 | SEPDEP | SEPDEP es para la defensa penal de la persona denunciada/imputada/procesada; no es el servicio estatal de patrocinio de la víctima. | competencia | F-SEPDEP-01 | Consultado 2026-09-27 |
| H-SEPDEP-03 | SEPDEP | La oficina Cochabamba figura en calle Jordán Nº 672 entre Antezana y Lanza, Edificio Aly. | lugar | F-SEPDEP-03 | Portal consultado 2026-09-27 |
| H-SEPDEP-04 | SEPDEP | La oficina Cochabamba publica horario lunes a viernes 08:30–16:30 y teléfono 4508263. | horario/contacto | F-SEPDEP-03 | Portal consultado 2026-09-27 |
| H-SEPDEP-05 | SEPDEP | El portal institucional anuncia atención del servicio las 24 horas; debe distinguirse de la ventanilla administrativa publicada 08:30–16:30. | servicio/horario | F-SEPDEP-01, F-SEPDEP-03 | Consultado 2026-09-27 |
| H-SEPDEP-06 | SEPDEP | [VERIFICAR] lista documental exacta exigida en Cochabamba para apertura/asignación de defensa en cada situación procesal. | requisito | — | [VERIFICAR] |
| H-SEPDAVI-01 | SEPDAVI | Brinda asistencia jurídica penal, psicológica y social a personas de escasos recursos que sean víctimas de delito. | competencia | F-SEPDAVI-01 | Ficha oficial consultada 2026-09-27 |
| H-SEPDAVI-02 | SEPDAVI | Para los servicios publicados se exige cédula, estar en situación de víctima, no contar con patrocinante particular y carecer de recursos suficientes para patrocinio particular. | requisito | F-SEPDAVI-02, F-SEPDAVI-03 | Fichas actualizadas 2026-08-01 |
| H-SEPDAVI-03 | SEPDAVI | Los servicios consultados publican horario lunes a viernes 08:30–16:30. | horario | F-SEPDAVI-02, F-SEPDAVI-03 | Actualizado 2026-08-01 |
| H-SEPDAVI-04 | SEPDAVI | Coordinación Cochabamba figura en Av. Salamanca N°625, esquina Edif. Lanza, Centro Internacional de Convenciones, piso 1; contacto 75121388. | lugar/contacto | F-SEPDAVI-04 | Portal consultado 2026-09-27 |
| H-SEPDAVI-05 | SEPDAVI | También figura una representación en La Chimba, Av. Beijing, IC Norte, Centro Integral FELCV, con el mismo contacto. | lugar/contacto | F-SEPDAVI-04 | Portal consultado 2026-09-27 |
| H-SEPDAVI-06 | SEPDAVI | La ruta institucional indica que una víctima sin recursos puede acudir a SEPDAVI para patrocinio gratuito. | procedimiento | F-SEPDAVI-05 | Portal consultado 2026-09-27 |

## ESC-SEPDEP-01 — Solicitar defensor público tras una denuncia

- **Institución:** SEPDEP – Cochabamba
- **Trámite:** Solicitar defensor público tras una denuncia
- **Tipo:** mixto
- **Inicia:** Usuario Sordo
- **Situación:** La persona fue denunciada y no puede pagar abogado.

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Usuario Sordo | Me denunciaron y no tengo abogado. | Plantear situación | — |
| 2 | Funcionario | ¿Usted es la persona denunciada o la víctima? | Determinar competencia | H-SEPDEP-02 |
| 3 | Usuario Sordo | Soy la persona denunciada. | Confirmar | — |
| 4 | Funcionario | SEPDEP brinda defensa penal gratuita en estos casos. | Explicar competencia | H-SEPDEP-01 |
| 5 | Funcionario | ¿Ya tiene abogado particular? | Verificar | H-SEPDEP-01 |
| 6 | Usuario Sordo | No. No puedo pagar un abogado. | Confirmar necesidad | — |
| 7 | Funcionario | Revisaremos su situación para asignar defensa técnica. | Continuar | H-SEPDEP-01 |

### Variantes

- **Turno 2 (Funcionario):** «¿Usted fue denunciado?» · «¿Es víctima o persona denunciada?»
- **Respuestas:** «Soy denunciado.» · «Soy víctima.» · «No sé.»
- **Turno 5 (Funcionario):** «¿Tiene abogado particular?» · «¿Ya designó defensa?»
- **Respuestas:** «No tengo.» · «Sí tengo.» · «No sé si sigue representándome.»

### Datos ficticios

- Número de caso: SEP-2026-001 (ficticio)

## ESC-SEPDEP-02 — Persona víctima llega a SEPDEP por error

- **Institución:** SEPDEP – Cochabamba
- **Trámite:** Persona víctima llega a SEPDEP por error
- **Tipo:** conocimiento_fijo
- **Inicia:** Funcionario
- **Situación:** Una víctima busca abogado estatal, pero llegó al servicio incorrecto.

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Funcionario | ¿Qué ayuda necesita? | Identificar | — |
| 2 | Usuario Sordo | Fui víctima de robo. Necesito abogado gratuito. | Explicar | — |
| 3 | Funcionario | ¿Usted está denunciado o es víctima? | Clasificar | H-SEPDEP-02 |
| 4 | Usuario Sordo | Soy la víctima. | Confirmar | — |
| 5 | Funcionario | SEPDEP defiende a denunciados, imputados o procesados. | Explicar límite | H-SEPDEP-02 |
| 6 | Funcionario | Para víctimas, consulte SEPDAVI u otro servicio competente. | Derivar | H-SEPDAVI-01 |
| 7 | Usuario Sordo | Entiendo. Iré al servicio para víctimas. | Cerrar | — |

### Variantes

- **Turno 3 (Funcionario):** «¿Es la víctima?» · «¿El proceso es contra usted?»
- **Respuestas:** «Soy víctima.» · «El proceso es contra mí.» · «No sé.»

### Datos ficticios

- Hecho: robo de mochila (ficticio)

## ESC-SEPDEP-03 — Ubicar oficina SEPDEP Cochabamba

- **Institución:** SEPDEP – Cochabamba
- **Trámite:** Ubicar oficina SEPDEP Cochabamba
- **Tipo:** conocimiento_fijo
- **Inicia:** Usuario Sordo
- **Situación:** La persona necesita acudir a la oficina administrativa.

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Usuario Sordo | ¿Dónde está Defensa Pública en Cochabamba? | Ubicación | — |
| 2 | Funcionario | La oficina publicada está en calle Jordán 672. | Informar | H-SEPDEP-03 |
| 3 | Funcionario | Queda entre Antezana y Lanza, Edificio Aly. | Precisar | H-SEPDEP-03 |
| 4 | Usuario Sordo | ¿Puedo ir por la tarde? | Horario | — |
| 5 | Funcionario | La oficina publica atención hasta las 16:30. | Informar | H-SEPDEP-04 |
| 6 | Usuario Sordo | Iré antes de esa hora. | Cerrar | — |

### Variantes

- **Turno 5 (Funcionario):** «¿Necesita también el horario?» · «¿Quiere confirmar cuándo atienden?»
- **Respuestas:** «Sí.» · «No.» · «No sé si llegaré.»

### Datos ficticios

- Dirección usada: dato fijo de fuente oficial

## ESC-SEPDEP-04 — Atención fuera de horario de ventanilla

- **Institución:** SEPDEP – Cochabamba
- **Trámite:** Atención fuera de horario de ventanilla
- **Tipo:** mixto
- **Inicia:** Funcionario
- **Situación:** La persona necesita defensa urgente fuera del horario administrativo.

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Funcionario | ¿Su consulta es urgente y penal? | Identificar | H-SEPDEP-05 |
| 2 | Usuario Sordo | Sí. Me citaron y no tengo abogado. | Urgencia | — |
| 3 | Funcionario | El portal anuncia servicio de atención las 24 horas. | Informar | H-SEPDEP-05 |
| 4 | Usuario Sordo | ¿La oficina está abierta ahora? | Distinguir | — |
| 5 | Funcionario | La ventanilla publica horario 08:30 a 16:30. | Aclarar | H-SEPDEP-04 |
| 6 | Funcionario | Contacte SEPDEP para activar la atención correspondiente. | Orientar | H-SEPDEP-05 |
| 7 | Usuario Sordo | Llamaré para pedir orientación. | Cerrar | — |

### Variantes

- **Turno 1 (Funcionario):** «¿Necesita defensa penal urgente?» · «¿La citación es para hoy?»
- **Respuestas:** «Sí.» · «No.» · «No sé.»

### Datos ficticios

- Hora concreta: dato_en_vivo

## ESC-SEPDAVI-01 — Solicitar patrocinio como víctima de delito

- **Institución:** SEPDAVI – Cochabamba
- **Trámite:** Solicitar patrocinio como víctima de delito
- **Tipo:** mixto
- **Inicia:** Usuario Sordo
- **Situación:** La víctima no tiene abogado particular.

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Usuario Sordo | Soy víctima y necesito abogado gratuito. | Solicitar | — |
| 2 | Funcionario | ¿Tiene actualmente abogado particular? | Requisito | H-SEPDAVI-02 |
| 3 | Usuario Sordo | No. No tengo abogado. | Confirmar | — |
| 4 | Funcionario | ¿Tiene su cédula de identidad? | Requisito | H-SEPDAVI-02 |
| 5 | Usuario Sordo | Sí. La tengo conmigo. | Confirmar | — |
| 6 | Funcionario | SEPDAVI evaluará su acceso al patrocinio y apoyo integral. | Orientar | H-SEPDAVI-01, H-SEPDAVI-02 |
| 7 | Usuario Sordo | Quiero iniciar la atención. | Cerrar | — |

### Variantes

- **Turno 2 (Funcionario):** «¿Tiene patrocinante particular?» · «¿Ya contrató abogado?»
- **Respuestas:** «No.» · «Sí.» · «No sé si continúa.»
- **Turno 4 (Funcionario):** «¿Trajo su cédula?» · «¿Tiene documento de identidad?»
- **Respuestas:** «Sí.» · «No.» · «No sé si sirve copia.»

### Datos ficticios

- Nombre: Patricia Rojas Lima (ficticio)

## ESC-SEPDAVI-02 — Atención integral por violencia familiar

- **Institución:** SEPDAVI – Cochabamba
- **Trámite:** Atención integral por violencia familiar
- **Tipo:** mixto
- **Inicia:** Funcionario
- **Situación:** La víctima pide apoyo legal y psicológico.

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Funcionario | ¿Qué tipo de apoyo necesita? | Identificar | H-SEPDAVI-01 |
| 2 | Usuario Sordo | Necesito ayuda legal y psicológica. | Solicitar | — |
| 3 | Funcionario | SEPDAVI presta apoyo legal, psicológico y social a víctimas. | Explicar | H-SEPDAVI-01 |
| 4 | Funcionario | ¿Cuenta con abogado particular? | Requisito | H-SEPDAVI-02 |
| 5 | Usuario Sordo | No. No tengo abogado. | Responder | — |
| 6 | Funcionario | El servicio para violencia familiar figura actualizado en 2026. | Confirmar servicio | H-SEPDAVI-03 |
| 7 | Usuario Sordo | Quiero recibir orientación hoy. | Cerrar | — |

### Variantes

- **Turno 4 (Funcionario):** «¿Tiene abogado?» · «¿Alguien ya la patrocina?»
- **Respuestas:** «No.» · «Sí.» · «No sé.»

### Datos ficticios

- Caso y personas: ficticios

## ESC-SEPDAVI-03 — Ubicar SEPDAVI Cochabamba

- **Institución:** SEPDAVI – Cochabamba
- **Trámite:** Ubicar SEPDAVI Cochabamba
- **Tipo:** conocimiento_fijo
- **Inicia:** Usuario Sordo
- **Situación:** La persona quiere ir a la coordinación departamental.

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Usuario Sordo | ¿Dónde atiende SEPDAVI en Cochabamba? | Ubicación | — |
| 2 | Funcionario | La coordinación figura en avenida Salamanca 625. | Informar | H-SEPDAVI-04 |
| 3 | Funcionario | Está en el Centro Internacional de Convenciones, piso uno. | Precisar | H-SEPDAVI-04 |
| 4 | Usuario Sordo | ¿Qué horario tiene? | Horario | — |
| 5 | Funcionario | Las fichas publican lunes a viernes, 08:30 a 16:30. | Informar | H-SEPDAVI-03 |
| 6 | Usuario Sordo | Iré por la mañana. | Cerrar | — |

### Variantes

- **Turno 5 (Funcionario):** «¿Necesita el horario?» · «¿Quiere saber cuándo atienden?»
- **Respuestas:** «Sí.» · «No.» · «No sé cuándo podré ir.»

### Datos ficticios

- Dirección: dato fijo verificado

## ESC-SEPDAVI-04 — Atención en representación La Chimba

- **Institución:** SEPDAVI – Cochabamba
- **Trámite:** Atención en representación La Chimba
- **Tipo:** conocimiento_fijo
- **Inicia:** Funcionario
- **Situación:** La persona está cerca de La Chimba.

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Funcionario | ¿Le queda mejor la oficina central o La Chimba? | Elegir sede | H-SEPDAVI-04, H-SEPDAVI-05 |
| 2 | Usuario Sordo | Estoy cerca de La Chimba. | Preferencia | — |
| 3 | Funcionario | Existe representación en Centro Integral FELCV, avenida Beijing. | Informar | H-SEPDAVI-05 |
| 4 | Usuario Sordo | ¿Usa el mismo número de contacto? | Contacto | — |
| 5 | Funcionario | La página publica 75121388 para ambas referencias. | Informar | H-SEPDAVI-04, H-SEPDAVI-05 |
| 6 | Usuario Sordo | Llamaré antes de ir. | Cerrar | — |

### Variantes

- **Turno 1 (Funcionario):** «¿Qué sede le queda más cerca?» · «¿Prefiere La Chimba?»
- **Respuestas:** «La Chimba.» · «La central.» · «No sé.»

### Datos ficticios

- Ubicación de la persona: ficticia

CONTINÚA EN LA PARTE 4

---

# Escenarios de trámites en Cochabamba — Parte 4 de 7

## Fuentes
| ID | Institución | Título | URL | Consultado |
|---|---|---|---|---|
| F-FELCC-01 | Policía Boliviana / FELCC | Trámites FELCC | https://www.policia.bo/tramite-felcc/ | 2026-09-27 |
| F-FELCC-02 | Policía Boliviana | Direcciones Generales y Nacionales | https://www.policia.bo/direcciones-nacionales/ | 2026-09-27 |
| F-FELCV-01 | Policía Boliviana | Direcciones Generales — FELCV | https://www.policia.bo/direcciones-nacionales/ | 2026-09-27 |
| F-FELCV-02 | Policía Boliviana | Campaña Unidos contra la violencia | https://www.policia.bo/%F0%9D%97%96%F0%9D%97%94%F0%9D%97%A0%F0%9D%97%A3%F0%9D%97%94%F0%9D%97%A1%CC%83%F0%9D%97%94-%F0%9D%97%A8%F0%9D%97%A1%F0%9D%97%9C%F0%9D%97%97%F0%9D%97%A2%F0%9D%97%A6-%F0%9D%97%96%F0%9D%97%A2/ | 2026-09-27 |
| F-LSB-01 | Defensoría del Pueblo | Atención virtual a personas sordas en LSB | https://www.defensoria.gob.bo/noticias/defensoria-del-pueblo-facilita-atencion-virtual-a-personas-sordas-mediante-interpretacion-en-lengua-de-senyas-boliviana | 2026-09-27 |

## Hechos verificados
| ID | Institución | Hecho | Tipo | Fuente | Vigencia |
|---|---|---|---|---|---|
| H-FELCC-01 | FELCC | La Policía Boliviana identifica a FELCC como Dirección General especializada contra el crimen. | competencia | F-FELCC-02 | Portal consultado 2026-09-27 |
| H-FELCC-02 | FELCC | La página oficial indica que un delito informático debe denunciarse ante FELCC y recomienda conservar la información relacionada al hecho. | procedimiento | F-FELCC-01 | Página sin fecha visible; consultada 2026-09-27 |
| H-FELCC-03 | FELCC | Para certificación de extravío o robo/hurto de documentos, la página publica carta de solicitud, cédula y boleta de depósito de Bs 20. | requisito/costo | F-FELCC-01 | Página sin fecha visible; [VERIFICAR] tarifa antes de pagar |
| H-FELCC-04 | FELCC | La misma página publica 24 horas como plazo de entrega para ese certificado. | plazo | F-FELCC-01 | Página sin fecha visible; [VERIFICAR] vigencia |
| H-FELCC-05 | FELCC | [VERIFICAR] dirección y horario exactos vigentes de la plataforma FELCC Cochabamba para denuncias comunes. | lugar/horario | — | [VERIFICAR] |
| H-FELCV-01 | FELCV | La Policía Boliviana identifica a FELCV como Dirección General especializada contra la violencia. | competencia | F-FELCV-01 | Portal consultado 2026-09-27 |
| H-FELCV-02 | FELCV | En 2026 la Policía continuó difundiendo la ruta de atención de FELCV en el marco de la Ley 348. | orientación | F-FELCV-02 | Publicado 2026-05-04 |
| H-FELCV-03 | FELCV | La Ley 1658, según la Defensoría del Pueblo, reconoce LSB y respalda accesibilidad para personas sordas; en justicia se prevé interpretación. | accesibilidad | F-LSB-01 | Publicado 2026-02-23 |
| H-FELCV-04 | FELCV | [VERIFICAR] dirección, número de emergencia y horario exactos vigentes de FELCV Cochabamba antes de incorporarlos como dato fijo. | lugar/contacto | — | [VERIFICAR] |

## ESC-FELCC-01 — Robo de celular: pruebas y seguimiento

- **Institución:** Policía Boliviana – FELCC
- **Trámite:** Robo de celular: pruebas y seguimiento
- **Tipo:** mixto
- **Inicia:** Usuario Sordo
- **Situación:** La persona ya contó el robo (qué, cuándo y dónde se pregunta en Denuncias → Denunciar robo) y en la FELCC sigue con lo que ayuda a investigar: pruebas de que el celular es suyo, documentos robados, testigos, cámaras y el seguimiento de su denuncia.

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Usuario Sordo | Me robaron mi celular. Quiero denunciar. | Iniciar | — |
| 2 | Funcionario | ¿El hecho fue robo, estafa u otro delito? | Clasificar | H-FELCC-01 |
| 3 | Usuario Sordo | Fue robo. Me quitaron el celular. | Responder | — |
| 4 | Funcionario | ¿Tiene la caja o la factura del celular? | Recabar | — |
| 5 | Usuario Sordo | Sí, tengo la caja del celular. | Responder | — |
| 6 | Funcionario | ¿Sabe dónde está su celular ahora? | Recabar | — |
| 7 | Usuario Sordo | No, no sé dónde está. | Responder | — |
| 8 | Funcionario | ¿Le robaron documentos? | Recabar | — |
| 9 | Usuario Sordo | Sí, también robaron mi carnet. | Responder | — |
| 10 | Funcionario | ¿Hay testigos del robo? | Recabar | — |
| 11 | Usuario Sordo | Sí, hay un testigo. | Responder | — |
| 12 | Funcionario | ¿Hay cámaras en esa calle? | Recabar | — |
| 13 | Usuario Sordo | Sí, hay cámaras en esa calle. | Responder | — |
| 14 | Funcionario | Registraremos los datos que usted pueda aportar. | Continuar | H-FELCC-01 |
| 15 | Usuario Sordo | Quiero una copia de mi denuncia. | Cierre | — |
| 16 | Funcionario | ¿Quiere saber quién investigará el robo? | Seguimiento | — |
| 17 | Usuario Sordo | Sí, quiero conocer al investigador. | Responder | — |

### Variantes

- **Turno 2 (Funcionario):** «¿Fue robo o estafa?» · «¿Qué delito quiere denunciar?»
- **Respuestas:** «Fue robo.» · «No fue robo.» · «No sé cómo se llama.»
- **Turno 4 (Funcionario):** «¿Puede mostrar que el celular es suyo?» · «¿Guardó la caja del celular?»
- **Respuestas:** «Sí, tengo la caja del celular.» · «No, no tengo la caja.» · «No sé dónde está la caja.»
- **Turno 6 (Funcionario):** «¿Puede ver dónde está su celular?» · «¿Sabe dónde está el celular ahora?»
- **Respuestas:** «Sí, sé dónde está.» · «No, no sé dónde está.» · «No sé cómo buscarlo.»
- **Turno 8 (Funcionario):** «¿Le quitaron también documentos?» · «¿Robaron su carnet?»
- **Respuestas:** «Sí, también robaron mi carnet.» · «No, solo el celular.» · «No sé si robaron documentos.»
- **Turno 10 (Funcionario):** «¿Alguien vio el robo?» · «¿Otra persona vio lo que pasó?»
- **Respuestas:** «Sí, hay un testigo.» · «No, no hay testigos.» · «No sé si hay testigos.»
- **Turno 12 (Funcionario):** «¿Hay cámaras cerca?» · «¿El lugar tiene cámaras?»
- **Respuestas:** «Sí, hay cámaras en esa calle.» · «No, no hay cámaras.» · «No sé si hay cámaras.»
- **Turno 14 (Funcionario):** «Vamos a anotar todo lo que usted pueda aportar.»
- **Respuestas:** «Quiero una copia de mi denuncia.» · «¿Cuándo sabré algo de mi celular?»
- **Turno 16 (Funcionario):** «¿Quiere conocer al investigador?» · «¿Necesita el nombre del investigador?»
- **Respuestas:** «Sí, quiero conocer al investigador.» · «No, ahora no.» · «No sé qué es un investigador.»

### Datos ficticios

- Celular y lugar: ficticios

## ESC-FELCC-02 — Denunciar estafa digital

- **Institución:** Policía Boliviana – FELCC
- **Trámite:** Denunciar estafa digital
- **Tipo:** mixto
- **Inicia:** Funcionario
- **Situación:** La víctima conserva mensajes y comprobantes.

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Funcionario | ¿La estafa ocurrió por internet o presencialmente? | Clasificar | H-FELCC-02 |
| 2 | Usuario Sordo | Fue por internet. Envié dinero. | Responder | — |
| 3 | Funcionario | No borre ni modifique mensajes relacionados al hecho. | Preservar evidencia | H-FELCC-02 |
| 4 | Usuario Sordo | Tengo capturas y comprobante de transferencia. | Informar | — |
| 5 | Funcionario | Conserve esos elementos y siga instrucciones del investigador. | Orientar | H-FELCC-02 |
| 6 | Usuario Sordo | ¿Puedo entregarlos en la denuncia? | Consultar | — |
| 7 | Funcionario | El investigador indicará cómo incorporarlos correctamente. | Cerrar | H-FELCC-02 |

### Variantes

- **Turno 1 (Funcionario):** «¿Fue una estafa por internet?» · «¿El contacto fue digital?»
- **Respuestas:** «Sí.» · «No.» · «No sé.»

### Datos ficticios

- Monto transferido: dato ficticio omitido

## ESC-FELCC-03 — Certificado por documentos robados

- **Institución:** Policía Boliviana – FELCC
- **Trámite:** Certificado por documentos robados
- **Tipo:** conocimiento_fijo
- **Inicia:** Usuario Sordo
- **Situación:** La persona necesita certificación por documentos sustraídos.

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Usuario Sordo | Necesito certificado porque robaron mis documentos. | Solicitar | — |
| 2 | Funcionario | La página publica una carta dirigida al Director Departamental. | Requisito | H-FELCC-03 |
| 3 | Funcionario | También publica cédula y boleta de depósito. | Requisitos | H-FELCC-03 |
| 4 | Usuario Sordo | ¿Cuánto dice la página que cuesta? | Costo | — |
| 5 | Funcionario | Publica Bs 20, pero confirme la tarifa antes de pagar. | Cautela | H-FELCC-03 |
| 6 | Usuario Sordo | Primero confirmaré el monto. | Cerrar | — |

### Variantes

- **Turno 5 (Funcionario):** «¿Quiere confirmar el costo?» · «¿Necesita saber la tarifa publicada?»
- **Respuestas:** «Sí.» · «No.» · «No sé dónde pagar.»

### Datos ficticios

- Documentos robados: cédula y licencia (ficticios)

## ESC-FELCC-04 — Llegar a oficina incorrecta

- **Institución:** Policía Boliviana – FELCC
- **Trámite:** Llegar a oficina incorrecta
- **Tipo:** conocimiento_fijo
- **Inicia:** Funcionario
- **Situación:** La persona denuncia violencia de pareja, no un delito común de competencia típica FELCC.

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Funcionario | ¿Qué hecho quiere denunciar? | Clasificar | — |
| 2 | Usuario Sordo | Mi pareja me amenaza y me golpea. | Relatar | — |
| 3 | Funcionario | Para violencia corresponde activar la ruta de FELCV. | Derivar | H-FELCV-01, H-FELCV-02 |
| 4 | Usuario Sordo | ¿Entonces aquí no me atienden? | Confirmar | — |
| 5 | Funcionario | Debe ser derivado al servicio especializado contra la violencia. | Orientar | H-FELCV-01 |
| 6 | Usuario Sordo | ¿Dónde tengo que ir? | Cerrar | — |

### Variantes

- **Turno 1 (Funcionario):** «¿Qué ocurrió?» · «¿Es violencia de pareja?»
- **Respuestas:** «Sí.» · «No.» · «No sé dónde denunciar.»
- **Turno 3 (Funcionario):** «Para violencia corresponde la FELCV.»
- **Respuestas:** «¿Entonces aquí no me atienden?» · «Quiero ir a la FELCV.»
- **Turno 5 (Funcionario):** «Lo van a derivar al servicio contra la violencia.»
- **Respuestas:** «¿Dónde tengo que ir?» · «¿Me pueden ayudar a ir?»

### Datos ficticios

- Personas: ficticias

## ESC-FELCV-01 — Denunciar violencia familiar

- **Institución:** Policía Boliviana – FELCV
- **Trámite:** Denunciar violencia familiar
- **Tipo:** mixto
- **Inicia:** Usuario Sordo
- **Situación:** La persona busca iniciar una denuncia por violencia.

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Usuario Sordo | Quiero denunciar violencia de mi pareja. | Iniciar | — |
| 2 | Funcionario | ¿Está en un lugar seguro ahora? | Priorizar seguridad | H-FELCV-01 |
| 3 | Usuario Sordo | Sí. Estoy lejos de esa persona. | Responder | — |
| 4 | Funcionario | FELCV es la unidad especializada contra la violencia. | Explicar | H-FELCV-01 |
| 5 | Funcionario | Cuente lo ocurrido con sus propias palabras. | Recabar | H-FELCV-02 |
| 6 | Usuario Sordo | Necesito comunicarme usando lengua de señas. | Accesibilidad | — |
| 7 | Funcionario | Debe garantizarse accesibilidad e interpretación cuando corresponda. | Orientar | H-FELCV-03 |

### Variantes

- **Turno 2 (Funcionario):** «¿Está segura ahora?» · «¿Está lejos del agresor?»
- **Respuestas:** «Sí.» · «No.» · «No sé.»

### Datos ficticios

- Lugar seguro: ficticio

## ESC-FELCV-02 — Pedir intérprete de LSB

- **Institución:** Policía Boliviana – FELCV
- **Trámite:** Pedir intérprete de LSB
- **Tipo:** conocimiento_fijo
- **Inicia:** Funcionario
- **Situación:** La persona sorda no comprende la explicación oral.

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Funcionario | Necesito hacerle algunas preguntas sobre la denuncia. | Iniciar entrevista | — |
| 2 | Usuario Sordo | Necesito intérprete de Lengua de Señas Boliviana. | Solicitar accesibilidad | — |
| 3 | Funcionario | Registraremos su necesidad de interpretación. | Adecuar atención | H-FELCV-03 |
| 4 | Usuario Sordo | No quiero responder sin comprender bien. | Proteger comprensión | — |
| 5 | Funcionario | La atención debe permitir comunicación accesible. | Confirmar | H-FELCV-03 |
| 6 | Usuario Sordo | Gracias. Esperaré la asistencia adecuada. | Cerrar | — |

### Variantes

- **Turno 1 (Funcionario):** «¿Puede responder ahora?» · «¿Necesita apoyo de comunicación?»
- **Respuestas:** «Necesito intérprete.» · «Puedo responder.» · «No entiendo.»

### Datos ficticios

- Intérprete concreto: dato_en_vivo

## ESC-FELCV-03 — Violencia psicológica y amenazas

- **Institución:** Policía Boliviana – FELCV
- **Trámite:** Violencia psicológica y amenazas
- **Tipo:** mixto
- **Inicia:** Usuario Sordo
- **Situación:** La persona no presenta lesiones físicas, pero denuncia amenazas.

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Usuario Sordo | Mi expareja me amenaza todos los días. | Relatar | — |
| 2 | Funcionario | ¿Las amenazas continúan actualmente? | Evaluar situación | H-FELCV-02 |
| 3 | Usuario Sordo | Sí. Me escribe mensajes constantemente. | Responder | — |
| 4 | Funcionario | FELCV atiende hechos de violencia y activa la ruta correspondiente. | Orientar | H-FELCV-01, H-FELCV-02 |
| 5 | Usuario Sordo | Tengo los mensajes guardados. | Aportar información | — |
| 6 | Funcionario | Muéstrelos al personal que registre e investigue el caso. | Continuar | — |

### Variantes

- **Turno 2 (Funcionario):** «¿Las amenazas siguen?» · «¿Continúa recibiendo mensajes?»
- **Respuestas:** «Sí.» · «No.» · «No sé.»

### Datos ficticios

- Mensajes y nombres: ficticios

## ESC-FELCV-04 — Confirmar sede antes de acudir

- **Institución:** Policía Boliviana – FELCV
- **Trámite:** Confirmar sede antes de acudir
- **Tipo:** conocimiento_fijo
- **Inicia:** Funcionario
- **Situación:** La persona pregunta por una dirección exacta.

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Funcionario | ¿Busca la sede de FELCV en Cochabamba? | Identificar | H-FELCV-04 |
| 2 | Usuario Sordo | Sí. Quiero ir hoy. | Responder | — |
| 3 | Funcionario | La dirección exacta actual está [VERIFICAR]. | Evitar dato desactualizado | H-FELCV-04 |
| 4 | Usuario Sordo | ¿Puedo llamar antes de ir? | Consultar | — |
| 5 | Funcionario | Confirme el canal oficial vigente antes del traslado. | Orientar | H-FELCV-04 |
| 6 | Usuario Sordo | Primero confirmaré la sede. | Cerrar | — |

### Variantes

- **Turno 1 (Funcionario):** «¿Necesita la dirección actual?» · «¿Quiere ubicar la sede?»
- **Respuestas:** «Sí.» · «No.» · «No sé cuál me corresponde.»

### Datos ficticios

- Dirección específica: [VERIFICAR]

CONTINÚA EN LA PARTE 5

---

# Escenarios de trámites en Cochabamba — Parte 5 de 7

## Fuentes
| ID | Institución | Título | URL | Consultado |
|---|---|---|---|---|
| F-SLIM-01 | GAM Cochabamba | Observatorio Municipal de Violencia — SLIM | https://observatorioviolencia.cochabamba.bo/nosotros | 2026-09-27 |
| F-SLIM-02 | GAM Cochabamba | SLIM y líneas de atención | https://cochabamba.bo/noticias/slim-atendido-35-casos-de-violencia | 2026-09-27 |
| F-DNA-01 | GAM Cochabamba | Información municipal con línea DNA | https://cochabamba.bo/noticias/slim-atendido-35-casos-de-violencia | 2026-09-27 |
| F-DNA-02 | Defensoría del Pueblo | Continuidad de servicios municipales Cochabamba | https://www.defensoria.gob.bo/oficinas/prensa/defensoria-del-pueblo-exhorta-a-municipios-de-cochabamba-a-garantizar-atencion-continua-durante-transicion-de-autoridades | 2026-09-27 |

## Hechos verificados
| ID | Institución | Hecho | Tipo | Fuente | Vigencia |
|---|---|---|---|---|---|
| H-SLIM-01 | SLIM | El Observatorio municipal describe al SLIM como instancia que brinda atención gratuita e integral mediante equipos psicológico, social y legal. | servicio | F-SLIM-01 | Portal consultado 2026-09-27 |
| H-SLIM-02 | SLIM | El Observatorio publica Jefatura SLIM en Plazuela Colón entre Venezuela y Paccieri; teléfono 4208030 interno 4433 y emergencia 71742126. | lugar/contacto | F-SLIM-01 | Portal consultado 2026-09-27 |
| H-SLIM-03 | SLIM | El Observatorio publica horario 08:00–16:00 continuo y sábado/domingo cerrado para la jefatura. | horario | F-SLIM-01 | Portal consultado 2026-09-27 |
| H-SLIM-04 | SLIM | La Alcaldía publicó también el número 4321178 para denunciar hechos de violencia; corresponde a una publicación de 2024. | contacto | F-SLIM-02 | Publicado 2024-03-14; [VERIFICAR] vigencia si se usa como canal principal |
| H-DNA-01 | DNA | La publicación municipal de 2024 señala línea gratuita 800-14-02-06 para casos de niñas, niños o adolescentes. | contacto | F-DNA-01 | Publicado 2024-03-14; [VERIFICAR] vigencia 2026 |
| H-DNA-02 | DNA | La misma publicación ubica oficinas en calle Venezuela entre 16 de Julio y Antezana para casos pertinentes. | lugar | F-DNA-01 | Publicado 2024-03-14; [VERIFICAR] antes de asistir |
| H-DNA-03 | DNA | En abril de 2026 la Defensoría del Pueblo exigió continuidad de servicios municipales de protección durante transición de autoridades. | contexto institucional | F-DNA-02 | Publicado 2026-04-20 |
| H-DNA-04 | DNA | [VERIFICAR] horario exacto y distribución actual de plataformas DNA en Cercado para 2026. | horario/lugar | — | [VERIFICAR] |

## ESC-SLIM-01 — Solicitar apoyo por violencia de pareja

- **Institución:** SLIM – Gobierno Autónomo Municipal de Cochabamba
- **Trámite:** Solicitar apoyo por violencia de pareja
- **Tipo:** mixto
- **Inicia:** Usuario Sordo
- **Situación:** La persona busca apoyo municipal integral.

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Usuario Sordo | Necesito ayuda por violencia de mi pareja. | Solicitar | — |
| 2 | Funcionario | SLIM brinda atención legal, psicológica y social. | Explicar | H-SLIM-01 |
| 3 | Funcionario | ¿Necesita primero orientación legal o psicológica? | Identificar necesidad | H-SLIM-01 |
| 4 | Usuario Sordo | Necesito ambas. No sé qué hacer. | Responder | — |
| 5 | Funcionario | El equipo puede orientar su ruta de atención. | Orientar | H-SLIM-01 |
| 6 | Usuario Sordo | Quiero hablar con el equipo. | Cerrar | — |

### Variantes

- **Turno 3 (Funcionario):** «¿Necesita apoyo legal?» · «¿Prefiere hablar primero con psicología?»
- **Respuestas:** «Necesito ambos.» · «Solo legal.» · «No sé.»

### Datos ficticios

- Personas: ficticias

## ESC-SLIM-02 — Ubicar Jefatura SLIM

- **Institución:** SLIM – Gobierno Autónomo Municipal de Cochabamba
- **Trámite:** Ubicar Jefatura SLIM
- **Tipo:** conocimiento_fijo
- **Inicia:** Usuario Sordo
- **Situación:** La persona quiere acudir presencialmente.

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Usuario Sordo | ¿Dónde está la oficina del SLIM? | Ubicación | — |
| 2 | Funcionario | El Observatorio publica Plazuela Colón entre Venezuela y Paccieri. | Informar | H-SLIM-02 |
| 3 | Usuario Sordo | ¿Atienden por la tarde? | Horario | — |
| 4 | Funcionario | La página publica atención continua de 08:00 a 16:00. | Informar | H-SLIM-03 |
| 5 | Usuario Sordo | Iré antes de las cuatro. | Cerrar | — |

### Variantes

- **Turno 4 (Funcionario):** «¿Necesita el horario?» · «¿Quiere saber hasta qué hora atienden?»
- **Respuestas:** «Sí.» · «No.» · «No sé si llegaré.»

### Datos ficticios

- Dirección: dato fijo verificado

## ESC-SLIM-03 — Llamar por una situación urgente

- **Institución:** SLIM – Gobierno Autónomo Municipal de Cochabamba
- **Trámite:** Llamar por una situación urgente
- **Tipo:** mixto
- **Inicia:** Funcionario
- **Situación:** La persona no puede trasladarse inmediatamente.

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Funcionario | ¿Puede acudir presencialmente ahora? | Canal | — |
| 2 | Usuario Sordo | No. Primero necesito llamar. | Responder | — |
| 3 | Funcionario | El Observatorio publica emergencia 71742126. | Dar contacto | H-SLIM-02 |
| 4 | Usuario Sordo | ¿Ese número aparece en la página municipal? | Confirmar | — |
| 5 | Funcionario | Sí. Fue verificado en el portal consultado hoy. | Confirmar fuente | H-SLIM-02 |
| 6 | Usuario Sordo | Llamaré para pedir orientación. | Cerrar | — |

### Variantes

- **Turno 1 (Funcionario):** «¿Puede venir a la oficina?» · «¿Necesita contacto telefónico?»
- **Respuestas:** «Necesito llamar.» · «Puedo ir.» · «No sé.»

### Datos ficticios

- Situación concreta: ficticia

## ESC-SLIM-04 — Pedir atención accesible en LSB

- **Institución:** SLIM – Gobierno Autónomo Municipal de Cochabamba
- **Trámite:** Pedir atención accesible en LSB
- **Tipo:** conocimiento_fijo
- **Inicia:** Usuario Sordo
- **Situación:** La persona requiere comunicación accesible.

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Usuario Sordo | Necesito comunicarme en Lengua de Señas Boliviana. | Solicitar accesibilidad | — |
| 2 | Funcionario | Registraremos su necesidad de comunicación accesible. | Adecuar atención | — |
| 3 | Usuario Sordo | No entiendo bien explicaciones solo habladas. | Explicar barrera | — |
| 4 | Funcionario | La atención debe adaptarse para que comprenda el trámite. | Orientar | — |
| 5 | Usuario Sordo | Quiero recibir instrucciones claras por escrito también. | Solicitar apoyo | — |
| 6 | Funcionario | Podemos complementar la explicación por escrito. | Cerrar | — |

### Variantes

- **Turno 2 (Funcionario):** «¿Necesita apoyo de comunicación?» · «¿Prefiere explicación escrita?»
- **Respuestas:** «Necesito LSB.» · «Quiero texto.» · «Necesito ambos.»

### Datos ficticios

- Intérprete específico: dato_en_vivo

## ESC-DNA-01 — Reportar posible vulneración de derechos de un niño

- **Institución:** DNA – Gobierno Autónomo Municipal de Cochabamba
- **Trámite:** Reportar posible vulneración de derechos de un niño
- **Tipo:** mixto
- **Inicia:** Usuario Sordo
- **Situación:** Un familiar busca orientación municipal.

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Usuario Sordo | Necesito ayuda por un niño de mi familia. | Iniciar | — |
| 2 | Funcionario | ¿La situación involucra a una niña, niño o adolescente? | Competencia | H-DNA-01 |
| 3 | Usuario Sordo | Sí. Es un niño de diez años. | Confirmar | — |
| 4 | Funcionario | La DNA atiende situaciones de protección de esta población. | Orientar | H-DNA-03 |
| 5 | Usuario Sordo | Quiero saber dónde puedo informar el caso. | Solicitar canal | — |
| 6 | Funcionario | La publicación municipal muestra la línea 800-14-02-06. | Dar referencia | H-DNA-01 |
| 7 | Funcionario | Confirme vigencia si usará ese canal en 2026. | Cautela temporal | H-DNA-01 |

### Variantes

- **Turno 2 (Funcionario):** «¿Es menor de 18 años?» · «¿La persona afectada es adolescente?»
- **Respuestas:** «Sí.» · «No.» · «No sé.»

### Datos ficticios

- Edad: 10 años (ficticia)

## ESC-DNA-02 — Ubicar oficina publicada de DNA

- **Institución:** DNA – Gobierno Autónomo Municipal de Cochabamba
- **Trámite:** Ubicar oficina publicada de DNA
- **Tipo:** conocimiento_fijo
- **Inicia:** Funcionario
- **Situación:** La persona pide una dirección presencial.

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Funcionario | ¿Busca atención presencial de la Defensoría de la Niñez? | Identificar | H-DNA-02 |
| 2 | Usuario Sordo | Sí. Quiero ir personalmente. | Confirmar | — |
| 3 | Funcionario | Una publicación de 2024 señala calle Venezuela. | Referencia | H-DNA-02 |
| 4 | Funcionario | Indica el tramo entre 16 de Julio y Antezana. | Precisar | H-DNA-02 |
| 5 | Usuario Sordo | ¿La dirección sigue vigente? | Cautela | — |
| 6 | Funcionario | Debe confirmarse porque la publicación es de 2024. | Advertir | H-DNA-02 |

### Variantes

- **Turno 6 (Funcionario):** «¿Quiere confirmar la sede actual?» · «¿Necesita verificar antes de ir?»
- **Respuestas:** «Sí.» · «No.» · «No sé.»

### Datos ficticios

- Dirección actual final: [VERIFICAR]

## ESC-DNA-03 — Derivación desde SLIM a DNA

- **Institución:** DNA – Gobierno Autónomo Municipal de Cochabamba
- **Trámite:** Derivación desde SLIM a DNA
- **Tipo:** conocimiento_fijo
- **Inicia:** Usuario Sordo
- **Situación:** La situación afecta principalmente a un adolescente.

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Usuario Sordo | Vine por violencia contra mi sobrino adolescente. | Explicar | — |
| 2 | Funcionario | ¿Él es menor de dieciocho años? | Determinar competencia | H-DNA-01 |
| 3 | Usuario Sordo | Sí. Tiene quince años. | Confirmar | — |
| 4 | Funcionario | Debe activarse la atención de la Defensoría de la Niñez. | Derivar | H-DNA-03 |
| 5 | Usuario Sordo | ¿Pueden indicarme cómo contactarla? | Solicitar | — |
| 6 | Funcionario | Existe una línea publicada, pero confirme vigencia actual. | Orientar | H-DNA-01 |

### Variantes

- **Turno 2 (Funcionario):** «¿Es menor de edad?» · «¿Tiene menos de dieciocho?»
- **Respuestas:** «Sí.» · «No.» · «No sé.»

### Datos ficticios

- Edad: 15 años (ficticia)

## ESC-DNA-04 — Oficina cerrada o servicio trasladado

- **Institución:** DNA – Gobierno Autónomo Municipal de Cochabamba
- **Trámite:** Oficina cerrada o servicio trasladado
- **Tipo:** mixto
- **Inicia:** Funcionario
- **Situación:** La persona llegó a una dirección antigua.

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Funcionario | ¿Encontró cerrada la oficina que buscaba? | Identificar problema | H-DNA-04 |
| 2 | Usuario Sordo | Sí. La dirección que tenía estaba cerrada. | Responder | — |
| 3 | Funcionario | No asumiremos que el servicio dejó de funcionar. | Evitar conclusión | H-DNA-03 |
| 4 | Usuario Sordo | ¿Cómo confirmo la atención actual? | Consultar | — |
| 5 | Funcionario | Confirme la plataforma municipal o línea vigente antes de volver. | Orientar | H-DNA-04 |
| 6 | Usuario Sordo | Primero confirmaré la sede y horario. | Cerrar | — |

### Variantes

- **Turno 1 (Funcionario):** «¿La oficina estaba cerrada?» · «¿No encontró la plataforma?»
- **Respuestas:** «Estaba cerrada.» · «No encontré la dirección.» · «No sé si cambió.»

### Datos ficticios

- Sede concreta: dato_en_vivo/[VERIFICAR]

CONTINÚA EN LA PARTE 6

---

# Escenarios de trámites en Cochabamba — Parte 6 de 7

## Fuentes
| ID | Institución | Título | URL | Consultado |
|---|---|---|---|---|
| F-NOT-01 | DIRNOPLU | Arancel del Notariado Plurinacional | https://astro.dnp.gob.bo/paginas/aranceles/ | 2026-09-27 |
| F-NOT-02 | DIRNOPLU | Portal institucional y buscador de notarios | https://astro.dnp.gob.bo/ | 2026-09-27 |
| F-NOT-03 | DIRNOPLU | Normativa notarial | https://astro.dnp.gob.bo/paginas/normativa/ | 2026-09-27 |
| F-SEGIP-01 | SEGIP | Reglamento de Cédula de Identidad física/digital | https://www.segip.gob.bo/fuent/2025/09/REGLAMENTO-AL-D.S.-N%C2%B04861-Y-AUTORIZA-LA-ENTRADA-EN-VIGENCIA-Y-OPERACION-PLENA-DE-LA-C.I.-Y-LA-LICENCIA-PARA-CONDUCIR-EN-FORMATO-DIGITAL.pdf | 2026-09-27 |
| F-SERECI-01 | OEP / SERECI | Servicios de Registro Civil | https://web.oep.org.bo/registro-civico/servicios-registro-civil/ | 2026-09-27 |
| F-SERECI-02 | OEP / SERECI | Venta de certificados duplicados | https://web.oep.org.bo/registro-civico/servicios-registro-civil/venta-duplicados/ | 2026-09-27 |
| F-SERECI-03 | Gob.bo / SERECI | Duplicado de certificado de defunción | https://www.gob.bo/tramites/duplicado-de-certificado-de-defuncion-src-dcd-14 | 2026-09-27 |
| F-SERECI-04 | Gob.bo / SERECI | Registro de defunción | https://www.gob.bo/tramites/certificado-de-defuncion-ante-orc-src-ido-05 | 2026-09-27 |
| F-SERECI-05 | OEP | Contactos SERECI Cochabamba | https://www.oep.org.bo/wp-content/uploads/2023/08/contactos_sereci.pdf | 2026-09-27 |

## Hechos verificados
| ID | Institución | Hecho | Tipo | Fuente | Vigencia |
|---|---|---|---|---|---|
| H-NOT-01 | Notarías | DIRNOPLU publica Bs 50 para certificación de firmas por un formulario. | costo | F-NOT-01 | Arancel consultado 2026-09-27; portal indica última actualización institucional 2025-06-05 |
| H-NOT-02 | Notarías | DIRNOPLU publica Bs 180 para 'otras escrituras' incluyendo anticréticos, aclaraciones, modificaciones y otros conceptos listados. | costo | F-NOT-01 | Consultado 2026-09-27; confirmar aplicabilidad exacta al instrumento concreto |
| H-NOT-03 | Notarías | El portal permite buscar notario y verificar documentos notariales mediante SINPLU. | servicio digital | F-NOT-02 | Consultado 2026-09-27 |
| H-NOT-04 | Notarías | [VERIFICAR] arancel total y requisitos concretos para cada poder, contrato de alquiler o anticrético antes de prometer un precio único. | costo/requisito | F-NOT-01, F-NOT-03 | [VERIFICAR] según acto |
| H-SEGIP-01 | SEGIP | El reglamento consultado establece Bs 17 para la Cédula de Identidad física. | costo | F-SEGIP-01 | Documento alojado por SEGIP; consultado 2026-09-27 |
| H-SEGIP-02 | SEGIP | Para primera emisión, el reglamento exige certificado de nacimiento original computarizado y válido emitido por SERECI, con contrastación. | requisito | F-SEGIP-01 | Documento consultado 2026-09-27 |
| H-SEGIP-03 | SEGIP | La renovación física puede solicitarse desde seis meses antes del vencimiento. | procedimiento | F-SEGIP-01 | Documento consultado 2026-09-27 |
| H-SEGIP-04 | SEGIP | La reposición corresponde por extravío, robo, destrucción o deterioro y mantiene la fecha de vigencia del documento reemplazado. | procedimiento | F-SEGIP-01 | Documento consultado 2026-09-27 |
| H-SEGIP-05 | SEGIP | [VERIFICAR] dirección y horario exactos de la oficina SEGIP que el usuario elija en Cochabamba antes de incorporarlos como dato fijo. | lugar/horario | — | [VERIFICAR] |
| H-SERECI-01 | SERECI | SERECI expide certificados de nacimiento, matrimonio y defunción y ofrece duplicados. | servicio | F-SERECI-01, F-SERECI-02 | Portales consultados 2026-09-27 |
| H-SERECI-02 | SERECI | Gob.bo publica Bs 34 para duplicado de certificado de defunción y una duración referencial de 5 minutos. | costo/plazo | F-SERECI-03 | Ficha consultada 2026-09-27 |
| H-SERECI-03 | SERECI | La ficha de registro de defunción fue actualizada el 2026-09-04 y enumera documentos del declarante, certificado médico y documentos del fallecido/testigos. | requisito | F-SERECI-04 | Actualizado 2026-09-04 |
| H-SERECI-04 | SERECI | Un documento de contactos publicado en 2023 listó oficina desconcentrada Cercado en Av. 27 de Agosto entre Ollantay y Nanawa, Villa Coronilla. | lugar | F-SERECI-05 | Documento 2023; [VERIFICAR] antes de asistir |
| H-SERECI-05 | SERECI | [VERIFICAR] costo actual de duplicados de nacimiento y matrimonio en la oficina concreta si no aparece en la ficha oficial consultada. | costo | — | [VERIFICAR] |

## ESC-NOT-01 — Reconocimiento o certificación de firmas

- **Institución:** Notarías de Fe Pública / DIRNOPLU
- **Trámite:** Reconocimiento o certificación de firmas
- **Tipo:** conocimiento_fijo
- **Inicia:** Usuario Sordo
- **Situación:** Dos personas quieren certificar firmas en un documento privado.

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Usuario Sordo | Quiero certificar las firmas de este contrato. | Solicitar | — |
| 2 | Funcionario | DIRNOPLU publica Bs 50 por un formulario. | Informar arancel | H-NOT-01 |
| 3 | Funcionario | ¿Las personas firmantes están disponibles para el acto? | Verificar comparecencia | H-NOT-04 |
| 4 | Usuario Sordo | Sí. Ambos estamos aquí. | Confirmar | — |
| 5 | Funcionario | Revisaremos el documento y requisitos aplicables antes de certificar. | Continuar | H-NOT-04 |
| 6 | Usuario Sordo | Quiero confirmar el costo total primero. | Cerrar | — |

### Variantes

- **Turno 3 (Funcionario):** «¿Están presentes los firmantes?» · «¿Ambas partes pueden comparecer?»
- **Respuestas:** «Sí.» · «No.» · «No sé si la otra persona vendrá.»

### Datos ficticios

- Contrato: ficticio

## ESC-NOT-02 — Contrato de alquiler

- **Institución:** Notarías de Fe Pública / DIRNOPLU
- **Trámite:** Contrato de alquiler
- **Tipo:** mixto
- **Inicia:** Funcionario
- **Situación:** Las partes preguntan si deben certificar sus firmas.

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Funcionario | ¿Traen un contrato de alquiler ya redactado? | Identificar | H-NOT-04 |
| 2 | Usuario Sordo | Sí. Queremos reconocer nuestras firmas. | Responder | — |
| 3 | Funcionario | La certificación de firmas tiene arancel publicado específico. | Informar | H-NOT-01 |
| 4 | Usuario Sordo | ¿Eso incluye todo el contrato? | Aclarar | — |
| 5 | Funcionario | No asumiré otros costos; dependen del acto solicitado. | Evitar confusión | H-NOT-04 |
| 6 | Usuario Sordo | Entonces confirmaré el trámite exacto. | Cerrar | — |

### Variantes

- **Turno 1 (Funcionario):** «¿El contrato ya está redactado?» · «¿Solo necesitan certificar firmas?»
- **Respuestas:** «Sí.» · «No.» · «No sé qué trámite necesito.»

### Datos ficticios

- Canon de alquiler: dato ficticio omitido

## ESC-NOT-03 — Contrato de anticrético

- **Institución:** Notarías de Fe Pública / DIRNOPLU
- **Trámite:** Contrato de anticrético
- **Tipo:** mixto
- **Inicia:** Usuario Sordo
- **Situación:** La persona pregunta por el arancel antes de protocolizar.

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Usuario Sordo | Quiero hacer un documento de anticrético. | Solicitar | — |
| 2 | Funcionario | El arancel publicado incluye anticréticos entre otras escrituras. | Clasificar | H-NOT-02 |
| 3 | Usuario Sordo | ¿Cuánto aparece en el arancel? | Costo | — |
| 4 | Funcionario | La tabla muestra Bs 180 para esa categoría. | Informar | H-NOT-02 |
| 5 | Funcionario | Confirme si su acto requiere conceptos adicionales. | Cautela | H-NOT-04 |
| 6 | Usuario Sordo | Quiero revisar todo antes de pagar. | Cerrar | — |

### Variantes

- **Turno 5 (Funcionario):** «¿Quiere revisar costos adicionales?» · «¿Confirmamos el acto exacto primero?»
- **Respuestas:** «Sí.» · «No.» · «No sé qué incluye.»

### Datos ficticios

- Inmueble y monto: ficticios

## ESC-NOT-04 — Buscar una notaría habilitada

- **Institución:** Notarías de Fe Pública / DIRNOPLU
- **Trámite:** Buscar una notaría habilitada
- **Tipo:** conocimiento_fijo
- **Inicia:** Funcionario
- **Situación:** La persona no sabe a qué notaría acudir.

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Funcionario | ¿Busca una notaría específica? | Identificar | H-NOT-03 |
| 2 | Usuario Sordo | No. Quiero encontrar una cerca. | Responder | — |
| 3 | Funcionario | DIRNOPLU ofrece un buscador de notarios. | Orientar | H-NOT-03 |
| 4 | Usuario Sordo | ¿Puedo verificar también el documento después? | Consultar | — |
| 5 | Funcionario | El portal ofrece verificación de documentos mediante SINPLU. | Informar | H-NOT-03 |
| 6 | Usuario Sordo | Usaré el buscador oficial. | Cerrar | — |

### Variantes

- **Turno 1 (Funcionario):** «¿Ya eligió notaría?» · «¿Necesita buscar un notario?»
- **Respuestas:** «Necesito buscar.» · «Ya tengo una.» · «No sé.»

### Datos ficticios

- Notaría concreta: dato_en_vivo

## ESC-SEGIP-01 — Cédula por primera vez

- **Institución:** SEGIP
- **Trámite:** Cédula por primera vez
- **Tipo:** conocimiento_fijo
- **Inicia:** Usuario Sordo
- **Situación:** La persona tramita su primera cédula.

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Usuario Sordo | Necesito sacar mi cédula por primera vez. | Iniciar | — |
| 2 | Funcionario | ¿Tiene certificado de nacimiento original computarizado? | Requisito | H-SEGIP-02 |
| 3 | Usuario Sordo | Sí. Lo tengo aquí. | Confirmar | — |
| 4 | Funcionario | El reglamento exige validarlo con los datos de SERECI. | Explicar | H-SEGIP-02 |
| 5 | Usuario Sordo | ¿Cuánto cuesta la cédula física? | Costo | — |
| 6 | Funcionario | El reglamento consultado establece Bs 17. | Informar | H-SEGIP-01 |
| 7 | Usuario Sordo | Quiero continuar con el trámite. | Cerrar | — |

### Variantes

- **Turno 2 (Funcionario):** «¿Trajo certificado de nacimiento?» · «¿Tiene el certificado original computarizado?»
- **Respuestas:** «Sí.» · «No.» · «No sé si es válido.»

### Datos ficticios

- Nombre: Andrea López Rojas (ficticio)

## ESC-SEGIP-02 — Renovar cédula próxima a vencer

- **Institución:** SEGIP
- **Trámite:** Renovar cédula próxima a vencer
- **Tipo:** conocimiento_fijo
- **Inicia:** Funcionario
- **Situación:** La cédula vence dentro de cuatro meses.

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Funcionario | ¿Su cédula ya venció? | Estado | H-SEGIP-03 |
| 2 | Usuario Sordo | No. Vence dentro de cuatro meses. | Responder | — |
| 3 | Funcionario | La renovación puede solicitarse desde seis meses antes. | Informar | H-SEGIP-03 |
| 4 | Usuario Sordo | Entonces ya puedo renovarla. | Confirmar | — |
| 5 | Funcionario | Sí, según el reglamento consultado. | Confirmar | H-SEGIP-03 |
| 6 | Usuario Sordo | Quiero hacerlo hoy. | Cerrar | — |

### Variantes

- **Turno 1 (Funcionario):** «¿Cuándo vence su cédula?» · «¿Faltan menos de seis meses?»
- **Respuestas:** «Faltan cuatro meses.» · «Falta más tiempo.» · «No recuerdo.»

### Datos ficticios

- Fecha de vencimiento: ficticia

## ESC-SEGIP-03 — Reposición por pérdida

- **Institución:** SEGIP
- **Trámite:** Reposición por pérdida
- **Tipo:** conocimiento_fijo
- **Inicia:** Usuario Sordo
- **Situación:** La persona perdió su cédula vigente.

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Usuario Sordo | Perdí mi cédula. Necesito otra. | Solicitar | — |
| 2 | Funcionario | La reposición aplica por extravío, robo o deterioro. | Explicar | H-SEGIP-04 |
| 3 | Usuario Sordo | Fue extravío. No sé dónde quedó. | Confirmar | — |
| 4 | Funcionario | La reposición mantiene la vigencia del documento reemplazado. | Informar | H-SEGIP-04 |
| 5 | Usuario Sordo | ¿Cuesta lo mismo que la cédula física? | Consultar | — |
| 6 | Funcionario | El reglamento consultado fija Bs 17 para la cédula física. | Informar | H-SEGIP-01 |
| 7 | Usuario Sordo | Haré la reposición. | Cerrar | — |

### Variantes

- **Turno 2 (Funcionario):** «¿Fue pérdida o robo?» · «¿La cédula está dañada?»
- **Respuestas:** «La perdí.» · «Me la robaron.» · «Está deteriorada.»

### Datos ficticios

- Cédula perdida: ficticia

## ESC-SEGIP-04 — Confirmar oficina antes de ir

- **Institución:** SEGIP
- **Trámite:** Confirmar oficina antes de ir
- **Tipo:** conocimiento_fijo
- **Inicia:** Funcionario
- **Situación:** La persona quiere una dirección exacta en Cochabamba.

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Funcionario | ¿A qué zona de Cochabamba quiere acudir? | Ubicación | H-SEGIP-05 |
| 2 | Usuario Sordo | Quiero ir a una oficina en Cercado. | Responder | — |
| 3 | Funcionario | La sede exacta y horario están [VERIFICAR]. | Evitar desactualización | H-SEGIP-05 |
| 4 | Usuario Sordo | ¿Debo confirmar antes de salir? | Consultar | — |
| 5 | Funcionario | Sí. Confirme la oficina operativa vigente del SEGIP. | Orientar | H-SEGIP-05 |
| 6 | Usuario Sordo | Lo confirmaré primero. | Cerrar | — |

### Variantes

- **Turno 1 (Funcionario):** «¿Qué oficina busca?» · «¿Necesita una sede en Cercado?»
- **Respuestas:** «Sí.» · «No.» · «No sé cuál.»

### Datos ficticios

- Oficina específica: [VERIFICAR]

## ESC-SERECI-01 — Duplicado de certificado de nacimiento

- **Institución:** SERECI – Cochabamba
- **Trámite:** Duplicado de certificado de nacimiento
- **Tipo:** conocimiento_fijo
- **Inicia:** Usuario Sordo
- **Situación:** La persona perdió su certificado.

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Usuario Sordo | Perdí mi certificado de nacimiento. | Solicitar | — |
| 2 | Funcionario | SERECI ofrece venta de certificados duplicados. | Informar | H-SERECI-01 |
| 3 | Usuario Sordo | ¿Cuánto cuesta actualmente? | Costo | — |
| 4 | Funcionario | El costo específico de nacimiento está [VERIFICAR]. | Evitar cifra no confirmada | H-SERECI-05 |
| 5 | Usuario Sordo | Entonces quiero confirmar el precio primero. | Cerrar | — |

### Variantes

- **Turno 4 (Funcionario):** «¿Necesita conocer el costo?» · «¿Quiere confirmar la valorada?»
- **Respuestas:** «Sí.» · «No.» · «No sé.»

### Datos ficticios

- Partida: ficticia

## ESC-SERECI-02 — Duplicado de certificado de matrimonio

- **Institución:** SERECI – Cochabamba
- **Trámite:** Duplicado de certificado de matrimonio
- **Tipo:** conocimiento_fijo
- **Inicia:** Funcionario
- **Situación:** La persona necesita otra copia del certificado.

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Funcionario | ¿Necesita certificado de matrimonio duplicado? | Identificar | H-SERECI-01 |
| 2 | Usuario Sordo | Sí. Perdimos la copia anterior. | Responder | — |
| 3 | Funcionario | SERECI incluye ese servicio entre certificados duplicados. | Informar | H-SERECI-01 |
| 4 | Usuario Sordo | ¿El precio es igual al de defunción? | Comparar | — |
| 5 | Funcionario | No lo asumiré; confirme el valor específico vigente. | Cautela | H-SERECI-05 |
| 6 | Usuario Sordo | Confirmaré antes de pagar. | Cerrar | — |

### Variantes

- **Turno 1 (Funcionario):** «¿Busca duplicado de matrimonio?» · «¿Necesita otra copia?»
- **Respuestas:** «Sí.» · «No.» · «No sé cuál certificado.»

### Datos ficticios

- Nombres: ficticios

## ESC-SERECI-03 — Duplicado de certificado de defunción

- **Institución:** SERECI – Cochabamba
- **Trámite:** Duplicado de certificado de defunción
- **Tipo:** conocimiento_fijo
- **Inicia:** Usuario Sordo
- **Situación:** Un familiar solicita un duplicado.

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Usuario Sordo | Necesito otro certificado de defunción de mi padre. | Solicitar | — |
| 2 | Funcionario | Gob.bo publica Bs 34 para ese duplicado. | Costo | H-SERECI-02 |
| 3 | Funcionario | Debe acreditar la relación permitida y su identidad. | Requisito | H-SERECI-02 |
| 4 | Usuario Sordo | Soy su hijo y tengo mi cédula. | Confirmar | — |
| 5 | Funcionario | La ficha publica una duración referencial de cinco minutos. | Plazo | H-SERECI-02 |
| 6 | Usuario Sordo | Quiero solicitarlo ahora. | Cerrar | — |

### Variantes

- **Turno 3 (Funcionario):** «¿Qué parentesco tiene?» · «¿Es familiar del fallecido?»
- **Respuestas:** «Soy su hijo.» · «No soy familiar.» · «No sé si puedo pedirlo.»

### Datos ficticios

- Padre fallecido: nombre ficticio

## ESC-SERECI-04 — Registrar una defunción

- **Institución:** SERECI – Cochabamba
- **Trámite:** Registrar una defunción
- **Tipo:** conocimiento_fijo
- **Inicia:** Funcionario
- **Situación:** El declarante consulta qué documentos llevar.

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Funcionario | ¿Viene a registrar una defunción? | Identificar | H-SERECI-03 |
| 2 | Usuario Sordo | Sí. Necesito saber qué documentos llevar. | Consultar | — |
| 3 | Funcionario | La ficha exige identificación del declarante y certificado médico. | Informar | H-SERECI-03 |
| 4 | Funcionario | También enumera identificación del fallecido y dos testigos. | Completar | H-SERECI-03 |
| 5 | Usuario Sordo | Tengo el certificado médico original. | Confirmar | — |
| 6 | Funcionario | Revise la ficha completa antes de presentarse. | Cerrar | H-SERECI-03 |

### Variantes

- **Turno 1 (Funcionario):** «¿Es una inscripción de defunción?» · «¿Necesita registrar el fallecimiento?»
- **Respuestas:** «Sí.» · «No.» · «No sé el trámite.»

### Datos ficticios

- Personas: ficticias

CONTINÚA EN LA PARTE 7

---

# Escenarios de trámites en Cochabamba — Parte 7 de 7

## Fuentes
| ID | Institución | Título | URL | Consultado |
|---|---|---|---|---|
| F-DISC-01 | Ministerio de Salud y Deportes | Normas y Manuales — Discapacidad | https://minsalud.gob.bo/3147-unidad-discapacidad-reha | 2026-09-27 |
| F-DISC-02 | Ministerio de Salud y Deportes | Presentación Norma Nacional de Carnetización 2025 | https://minsalud.gob.bo/8458-gobierno-presenta-norma-nacional-para-la-carnetizacion-de-personas-con-discapacidad-que-reduce-tiempos-y-procedimientos | 2026-09-27 |
| F-DISC-03 | Ministerio de Salud y Deportes | Servicios y bonos para personas con discapacidad | https://www.minsalud.gob.bo/8845-mas-de-118-000-personas-con-discapacidad-acceden-a-servicios-y-bonos-en-bolivia | 2026-09-27 |
| F-DISC-04 | Ministerio de Salud y Deportes | Carnetización y beneficios 2025 | https://www.minsalud.gob.bo/8827-mas-de-118-000-personas-con-discapacidad-pasaron-de-la-exclusion-a-la-gratuidad-en-carnetizacion-salud-vivienda-y-educacion | 2026-09-27 |
| F-LSB-01 | Defensoría del Pueblo | Atención virtual a personas sordas en LSB | https://www.defensoria.gob.bo/noticias/defensoria-del-pueblo-facilita-atencion-virtual-a-personas-sordas-mediante-interpretacion-en-lengua-de-senyas-boliviana | 2026-09-27 |
| F-LSB-02 | Defensoría del Pueblo | Oficina Cochabamba | https://www.defensoria.gob.bo/oficinas?oficina_id=4 | 2026-09-27 |
| F-LSB-03 | Defensoría del Pueblo | Preguntas frecuentes | https://www.defensoria.gob.bo/contenido/preguntas-frecuentes | 2026-09-27 |
| F-LSB-04 | Defensoría del Pueblo | Reglamento de peritos, intérpretes y traductores — taller 2026 | https://www.defensoria.gob.bo/noticias/defensoria-del-pueblo-promueve-nuevo-reglamento-para-peritos%2C-interpretes-y-traductores-del-tsj-con-enfoque-interseccional | 2026-09-27 |
| F-LSB-05 | Referencia legal secundaria | Ley Nº 1658 de 31 de octubre de 2025 | https://www.lexivox.org/norms/BO-L-N1658.html | 2026-09-27 |

## Hechos verificados
| ID | Institución | Hecho | Tipo | Fuente | Vigencia |
|---|---|---|---|---|---|
| H-DISC-01 | Discapacidad | La Norma Nacional de Calificación, Registro y Carnetización fue aprobada por R.M. N°003 de 3 de enero de 2025. | norma | F-DISC-01 | Vigente como norma publicada por el Ministerio; consultada 2026-09-27 |
| H-DISC-02 | Discapacidad | La norma 2025 introdujo digitalización, renovación automática y reducción de tiempos; el Ministerio informó 4 días urbanos y 6 rurales. | procedimiento/plazo | F-DISC-02 | Publicado 2025-01-07 |
| H-DISC-03 | Discapacidad | El Ministerio informó en 2025 que el carnet y su renovación se gestionan bajo el nuevo esquema y que la carnetización es gratuita. | costo/procedimiento | F-DISC-03, F-DISC-04 | Publicado 2025; consultado 2026-09-27 |
| H-DISC-04 | Discapacidad | La Norma Nacional 2025 establece carnetización para personas con porcentaje de discapacidad igual o mayor a 25%. | criterio | F-DISC-01 | Norma 2025; sustituye referencias antiguas de 30% |
| H-DISC-05 | Discapacidad | El Ministerio informó que personas con discapacidad grave y muy grave reciben bono mensual de Bs 250; en 2025 se exigía presentar fotocopia del carnet al municipio. | beneficio | F-DISC-03, F-DISC-04 | Información publicada 2025; [VERIFICAR] procedimiento municipal exacto 2026 |
| H-DISC-06 | Discapacidad | [VERIFICAR] oficina, requisitos locales complementarios y calendario de calificación en Cochabamba antes de presentarlos como datos fijos. | lugar/requisito | — | [VERIFICAR] |
| H-LSB-01 | LSB | La Defensoría informó que la Ley Nº1658 de 31 de octubre de 2025 reconoce la Lengua de Señas Boliviana como idioma oficial de las personas sordas. | derecho lingüístico | F-LSB-01, F-LSB-05 | Ley promulgada 2025-10-31 |
| H-LSB-02 | LSB | La Ley Nº1658 contempla interpretación gratuita en el ámbito de justicia, incluyendo administración de justicia, Ministerio Público y Policía Boliviana. | derecho/accesibilidad | F-LSB-05 | Ley 1658; texto legal consultado mediante referencia secundaria |
| H-LSB-03 | LSB | La Defensoría del Pueblo implementó atención virtual en LSB mediante sus oficinas y publicó este servicio el 2026-02-23. | servicio accesible | F-LSB-01 | Publicado 2026-02-23 |
| H-LSB-04 | Defensoría del Pueblo | Oficina Cochabamba: calle 16 de Julio N°680, Plazuela Constitución; teléfonos 44140745 y 4-4140751, WhatsApp 71726434. | lugar/contacto | F-LSB-02 | Portal consultado 2026-09-27 |
| H-LSB-05 | Defensoría del Pueblo | Puede acudirse cuando una institución pública o servidor vulnera derechos individuales o colectivos. | competencia | F-LSB-03 | Portal consultado 2026-09-27 |
| H-LSB-06 | Defensoría del Pueblo | La institución recordó línea gratuita 800-10-8004 para denuncias de vulneraciones de derechos. | contacto | F-LSB-01, F-LSB-03 | Portal consultado 2026-09-27 |
| H-LSB-07 | LSB | En 2026 la Defensoría y el TSJ trabajaron en un reglamento para peritos, intérpretes y traductores con enfoque inclusivo. | contexto institucional | F-LSB-04 | Publicado 2026-04-01 |

## ESC-DISC-01 — Iniciar calificación y carnetización

- **Institución:** Registro y carnet de discapacidad
- **Trámite:** Iniciar calificación y carnetización
- **Tipo:** mixto
- **Inicia:** Usuario Sordo
- **Situación:** La persona quiere obtener carnet de discapacidad.

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Usuario Sordo | Quiero sacar mi carnet de discapacidad. | Iniciar | — |
| 2 | Funcionario | Primero debe seguir el proceso de calificación correspondiente. | Orientar | H-DISC-01 |
| 3 | Usuario Sordo | ¿El trámite sigue usando el sistema SIPRUNPCD? | Consultar | — |
| 4 | Funcionario | La norma 2025 mantiene el registro dentro del sistema nacional. | Explicar | H-DISC-01 |
| 5 | Usuario Sordo | ¿Cuánto tarda en ciudad? | Plazo | — |
| 6 | Funcionario | El Ministerio informó cuatro días para el área urbana. | Informar | H-DISC-02 |
| 7 | Usuario Sordo | Quiero saber dónde iniciar en Cochabamba. | Cerrar | — |
| 8 | Funcionario | La oficina local exacta está [VERIFICAR]. | Evitar desactualización | H-DISC-06 |

### Variantes

- **Turno 2 (Funcionario):** «¿Ya pasó por calificación?» · «¿Es su primera calificación?»
- **Respuestas:** «Es primera vez.» · «Ya me calificaron.» · «No sé.»

### Datos ficticios

- Porcentaje: dato_en_vivo

## ESC-DISC-02 — Aclarar porcentaje mínimo de carnetización

- **Institución:** Registro y carnet de discapacidad
- **Trámite:** Aclarar porcentaje mínimo de carnetización
- **Tipo:** conocimiento_fijo
- **Inicia:** Funcionario
- **Situación:** La persona recibió información antigua que hablaba de 30%.

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Funcionario | ¿Le dijeron que necesita treinta por ciento? | Detectar inconsistencia | H-DISC-04 |
| 2 | Usuario Sordo | Sí. Me dijeron mínimo treinta por ciento. | Relatar | — |
| 3 | Funcionario | La Norma Nacional 2025 establece desde veinticinco por ciento. | Corregir dato | H-DISC-04 |
| 4 | Usuario Sordo | Entonces el dato de treinta está antiguo. | Confirmar | — |
| 5 | Funcionario | Sí. Para este corpus usaremos el criterio actual de 25%. | Normalizar RAG | H-DISC-04 |
| 6 | Usuario Sordo | Entendido. | Cerrar | — |

### Variantes

- **Turno 1 (Funcionario):** «¿Le informaron un porcentaje mínimo?» · «¿Escuchó el dato de treinta por ciento?»
- **Respuestas:** «Sí.» · «No.» · «No recuerdo.»

### Datos ficticios

- Porcentaje individual: dato_en_vivo

## ESC-DISC-03 — Renovar carnet

- **Institución:** Registro y carnet de discapacidad
- **Trámite:** Renovar carnet
- **Tipo:** conocimiento_fijo
- **Inicia:** Usuario Sordo
- **Situación:** La persona tiene carnet que requiere renovación.

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Usuario Sordo | Mi carnet necesita renovación. | Solicitar | — |
| 2 | Funcionario | La norma 2025 incorporó mecanismos de renovación automática. | Informar | H-DISC-02, H-DISC-03 |
| 3 | Usuario Sordo | ¿Debo pagar por el nuevo carnet? | Costo | — |
| 4 | Funcionario | El Ministerio informa que la carnetización es gratuita. | Informar | H-DISC-03 |
| 5 | Usuario Sordo | ¿Debo volver a calificarme? | Consultar | — |
| 6 | Funcionario | Depende de su grado y situación; revise la norma aplicable. | Cautela | H-DISC-01 |
| 7 | Usuario Sordo | Confirmaré mi caso antes de ir. | Cerrar | — |

### Variantes

- **Turno 6 (Funcionario):** «¿Su carnet está vencido?» · «¿Conoce su grado registrado?»
- **Respuestas:** «Está vencido.» · «No está vencido.» · «No sé.»

### Datos ficticios

- Grado: dato_en_vivo

## ESC-DISC-04 — Consultar bono por discapacidad

- **Institución:** Registro y carnet de discapacidad
- **Trámite:** Consultar bono por discapacidad
- **Tipo:** mixto
- **Inicia:** Funcionario
- **Situación:** La persona pregunta por el bono mensual.

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Funcionario | ¿Su carnet registra discapacidad grave o muy grave? | Elegibilidad | H-DISC-05 |
| 2 | Usuario Sordo | No recuerdo el grado de mi carnet. | Duda | — |
| 3 | Funcionario | El Ministerio informó bono para grados grave y muy grave. | Explicar | H-DISC-05 |
| 4 | Usuario Sordo | ¿Cuánto informó el Ministerio? | Monto | — |
| 5 | Funcionario | La información publicada señala Bs 250 mensuales. | Informar | H-DISC-05 |
| 6 | Usuario Sordo | ¿Dónde lo tramito en Cochabamba? | Procedimiento local | — |
| 7 | Funcionario | El procedimiento municipal exacto 2026 está [VERIFICAR]. | Cautela | H-DISC-05, H-DISC-06 |

### Variantes

- **Turno 1 (Funcionario):** «¿Conoce su grado de discapacidad?» · «¿Su carnet dice grave o muy grave?»
- **Respuestas:** «Sí.» · «No.» · «No sé.»

### Datos ficticios

- Grado y pago concreto: dato_en_vivo

## ESC-LSB-01 — Pedir intérprete en una denuncia policial

- **Institución:** Derechos lingüísticos LSB / Defensoría del Pueblo
- **Trámite:** Pedir intérprete en una denuncia policial
- **Tipo:** conocimiento_fijo
- **Inicia:** Usuario Sordo
- **Situación:** La persona sorda necesita denunciar ante la Policía.

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Usuario Sordo | Necesito un intérprete de Lengua de Señas Boliviana. | Solicitar derecho | — |
| 2 | Funcionario | La Ley 1658 contempla interpretación gratuita en justicia. | Reconocer derecho | H-LSB-02 |
| 3 | Usuario Sordo | Quiero entender todas las preguntas de la denuncia. | Explicar necesidad | — |
| 4 | Funcionario | Debe garantizarse comunicación accesible durante la atención. | Aplicar derecho | H-LSB-02 |
| 5 | Usuario Sordo | No responderé cosas que no comprendo. | Evitar error | — |
| 6 | Funcionario | La entrevista debe realizarse con apoyo adecuado. | Cerrar | H-LSB-02 |

### Variantes

- **Turno 2 (Funcionario):** «¿Necesita intérprete de LSB?» · «¿Requiere apoyo de comunicación?»
- **Respuestas:** «Sí.» · «No.» · «Necesito texto e intérprete.»

### Datos ficticios

- Intérprete asignado: dato_en_vivo

## ESC-LSB-02 — Pedir intérprete en un juzgado

- **Institución:** Derechos lingüísticos LSB / Defensoría del Pueblo
- **Trámite:** Pedir intérprete en un juzgado
- **Tipo:** conocimiento_fijo
- **Inicia:** Funcionario
- **Situación:** Una parte del proceso solicita LSB.

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Funcionario | ¿Necesita una medida de accesibilidad para la audiencia? | Detectar necesidad | H-LSB-02 |
| 2 | Usuario Sordo | Sí. Necesito intérprete de LSB. | Solicitar | — |
| 3 | Funcionario | La Ley 1658 incluye el ámbito de administración de justicia. | Base legal | H-LSB-02 |
| 4 | Usuario Sordo | Quiero participar directamente en mi audiencia. | Ejercer derecho | — |
| 5 | Funcionario | Debe tramitarse la interpretación conforme al procedimiento aplicable. | Orientar | H-LSB-02, H-LSB-07 |
| 6 | Usuario Sordo | Quiero que quede registrada mi solicitud. | Cerrar | — |

### Variantes

- **Turno 1 (Funcionario):** «¿Necesita intérprete?» · «¿Requiere atención en LSB?»
- **Respuestas:** «Sí.» · «No.» · «No sé cómo solicitarlo.»

### Datos ficticios

- Audiencia: dato_en_vivo

## ESC-LSB-03 — Reclamar por negativa de accesibilidad

- **Institución:** Derechos lingüísticos LSB / Defensoría del Pueblo
- **Trámite:** Reclamar por negativa de accesibilidad
- **Tipo:** mixto
- **Inicia:** Usuario Sordo
- **Situación:** Una institución pública no proporcionó atención accesible.

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Usuario Sordo | Me negaron atención porque necesito lengua de señas. | Relatar vulneración | — |
| 2 | Funcionario | Puede acudir a la Defensoría por posible vulneración de derechos. | Competencia | H-LSB-05 |
| 3 | Usuario Sordo | ¿Dónde está la oficina de Cochabamba? | Ubicación | — |
| 4 | Funcionario | Está en calle 16 de Julio 680, Plazuela Constitución. | Informar | H-LSB-04 |
| 5 | Usuario Sordo | Quiero presentar mi reclamo. | Cerrar | — |

### Variantes

- **Turno 2 (Funcionario):** «¿La negativa fue de una institución pública?» · «¿Quiere denunciar vulneración de derechos?»
- **Respuestas:** «Sí.» · «No.» · «No sé.»

### Datos ficticios

- Institución reclamada: ficticia

## ESC-LSB-04 — Atención virtual de Defensoría en LSB

- **Institución:** Derechos lingüísticos LSB / Defensoría del Pueblo
- **Trámite:** Atención virtual de Defensoría en LSB
- **Tipo:** conocimiento_fijo
- **Inicia:** Funcionario
- **Situación:** La persona no puede acudir presencialmente.

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Funcionario | ¿Puede venir a la oficina de la Defensoría? | Canal | — |
| 2 | Usuario Sordo | No. Necesito atención a distancia. | Responder | — |
| 3 | Funcionario | Desde 2026 existe atención virtual en LSB. | Informar | H-LSB-03 |
| 4 | Usuario Sordo | ¿También tienen línea gratuita? | Consultar | — |
| 5 | Funcionario | La Defensoría publica 800-10-8004 para vulneraciones de derechos. | Dar contacto | H-LSB-06 |
| 6 | Usuario Sordo | Usaré un canal accesible. | Cerrar | — |

### Variantes

- **Turno 1 (Funcionario):** «¿Necesita atención virtual?» · «¿Le resulta difícil venir?»
- **Respuestas:** «Sí.» · «No.» · «Necesito orientación.»

### Datos ficticios

- Canal concreto elegido: dato_en_vivo

FIN DEL CORPUS
