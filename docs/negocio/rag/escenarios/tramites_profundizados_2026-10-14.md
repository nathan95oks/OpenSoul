<!-- Escenarios de Trámites profundizados (2026-10-14). Usan SOLO hechos y fuentes ya documentados en el corpus y solo el vocabulario que la app ya tiene: no agregan datos oficiales ni palabras sin seña nuevas. Cada uno cubre inicio, requisitos, documento faltante, costo (sin inventar montos), derivación y cierre, con ramificaciones por estado de respuesta. -->
# Escenarios de trámites profundizados — Conversación

## ESC-IMP-301 — Transferencia de una moto

- **Institución:** GAM Cochabamba / RUAT
- **Trámite:** Transferencia de una moto
- **Tipo:** mixto
- **Inicia:** Usuario Sordo
- **Situación:** La persona vendió su moto y quiere transferirla. Se confirman titularidad, CRPVA y precio, se ofrece ayuda si falta el CRPVA y se explica sin montos cómo se considera el valor para el impuesto.
- **Referencia:** F-IMP-04

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Usuario Sordo | Quiero hacer la transferencia de mi moto. | Iniciar el trámite | — |
| 2 | Funcionario | ¿La moto está registrada a su nombre? | Titularidad | — |
| 3 | Usuario Sordo | Sí, la moto está a mi nombre. | Respuesta | — |
| 4 | Funcionario | ¿Tiene el CRPVA de la moto? | Documento del vehículo | H-IMP-10 |
| 5 | Usuario Sordo | Sí, tengo el CRPVA de la moto. | Respuesta | — |
| 6 | Funcionario | ¿Quiere ayuda con el CRPVA? | Documento faltante | H-IMP-10 |
| 7 | Usuario Sordo | Sí, quiero ayuda con el CRPVA. | Respuesta | — |
| 8 | Funcionario | ¿Ya tiene el precio de venta? | Precio de venta | — |
| 9 | Usuario Sordo | Sí, ya tengo el precio de venta. | Respuesta | — |
| 10 | Funcionario | Para el impuesto a la transferencia se considera el mayor valor entre el precio pagado y la base imponible aplicable. | Costo sin monto | H-IMP-11 |
| 11 | Funcionario | Al transferir se actualizan los datos de la moto y se cambia el CRPVA. Confirme los requisitos antes de pagar. | Cierre | H-IMP-10 |

### Variantes

- **Turno 2 (Funcionario):** «¿Usted figura como dueño de la moto?» · «¿La moto está a nombre suyo?»
- **Respuestas:** «Sí, la moto está a mi nombre.» · «No, la moto no está a mi nombre.» · «No sé si la moto está a mi nombre.»
- **Turno 4 (Funcionario):** «¿Conserva el CRPVA de la moto?» · «¿Trae el CRPVA del vehículo?»
- **Respuestas:** «Sí, tengo el CRPVA de la moto.» · «No, no tengo el CRPVA de la moto.» · «No sé si tengo el CRPVA de la moto.»
- **Turno 6 (Funcionario):** «¿Desea ayuda con el CRPVA?» · «¿Necesita ayuda para el CRPVA?»
- **Respuestas:** «Sí, quiero ayuda con el CRPVA.» · «No, no quiero ayuda con el CRPVA.» · «No sé si quiero ayuda con el CRPVA.»
- **Turno 8 (Funcionario):** «¿Ya tiene definido el precio de venta?» · «¿Ya sabe el precio de venta?»
- **Respuestas:** «Sí, ya tengo el precio de venta.» · «No, no tengo el precio de venta.» · «No sé el precio de venta.»

### Ramificaciones

- **Turno 6:** si Turno 4 es negado o desconocido
- **Turno 8:** si Turno 2 es afirmado

## ESC-OJ-301 — Consultar un proceso y qué hacer sin NUREJ o WebID

- **Institución:** Órgano Judicial – TDJ Cochabamba
- **Trámite:** Consultar un proceso y qué hacer sin NUREJ o WebID
- **Tipo:** mixto
- **Inicia:** Usuario Sordo
- **Situación:** La persona quiere saber cómo va su proceso de familia. Con NUREJ y WebID consulta en el sistema; sin ellos se la orienta al Tribunal Departamental. El estado del proceso es un dato en vivo.
- **Referencia:** F-OJ-02, F-OJ-03

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Usuario Sordo | Quiero saber cómo va mi proceso de familia. | Iniciar la consulta | — |
| 2 | Funcionario | ¿Tiene el NUREJ de su proceso? | Dato de búsqueda | H-OJ-02 |
| 3 | Usuario Sordo | Sí, tengo el NUREJ de mi proceso. | Respuesta | — |
| 4 | Funcionario | ¿Tiene también el WebID de su proceso? | Dato de búsqueda | H-OJ-02 |
| 5 | Usuario Sordo | Sí, tengo el WebID de mi proceso. | Respuesta | — |
| 6 | Funcionario | Para consultar se usan el NUREJ, el WebID y el departamento donde está el proceso. | Cómo consultar | H-OJ-02 |
| 7 | Funcionario | ¿Entendió? | Cómo consultar | H-OJ-02 |
| 8 | Usuario Sordo | Sí, entendí la consulta. | Respuesta | — |
| 9 | Funcionario | ¿Quiere pedir información en el Tribunal Departamental? | Derivación presencial | H-OJ-04 |
| 10 | Usuario Sordo | Sí, quiero ir al Tribunal. | Respuesta | — |
| 11 | Funcionario | El Tribunal está en Av. San Martín entre Jordán y Sucre. Atiende de lunes a viernes, 08:00–12:00 y 14:30–18:30. | Lugar y horario | H-OJ-05, H-OJ-06 |
| 12 | Funcionario | Si tiene la carátula del expediente, llévela: allí están el NUREJ y el WebID. La fecha de la audiencia depende de su expediente. | Cierre y dato en vivo | H-OJ-03, H-OJ-09 |

### Variantes

- **Turno 2 (Funcionario):** «¿Conoce el NUREJ de su expediente?» · «¿Tiene el número NUREJ del proceso?»
- **Respuestas:** «Sí, tengo el NUREJ de mi proceso.» · «No, no tengo el NUREJ de mi proceso.» · «No sé cuál es el NUREJ de mi proceso.»
- **Turno 4 (Funcionario):** «¿Conoce también el WebID del expediente?» · «¿Tiene el WebID de su proceso?»
- **Respuestas:** «Sí, tengo el WebID de mi proceso.» · «No, no tengo el WebID de mi proceso.» · «No sé cuál es el WebID de mi proceso.»
- **Turno 7 (Funcionario):** «¿Comprendió?» · «¿Entendió qué datos se usan para consultar el proceso?»
- **Respuestas:** «Sí, entendí la consulta.» · «No, no entendí la consulta.» · «No sé cómo consultar.»
- **Turno 9 (Funcionario):** «¿Desea ir al Tribunal Departamental a pedir información?» · «¿Quiere pedir información en el Tribunal?»
- **Respuestas:** «Sí, quiero ir al Tribunal.» · «No, no quiero ir al Tribunal.» · «No sé si quiero ir al Tribunal.»

### Ramificaciones

- **Turno 7:** si Turno 2 es afirmado
- **Turno 9:** si Turno 2 es negado o desconocido

### Datos editables

- **Turno 2:** documento_numero · «Sí, mi NUREJ es {numero}.»
- **Turno 4:** documento_numero · «Sí, mi WebID es {numero}.»

## ESC-SEPDEP-301 — Soy víctima y llegué a SEPDEP: orientación a SEPDAVI

- **Institución:** SEPDEP – Cochabamba
- **Trámite:** Soy víctima y llegué a SEPDEP: orientación a SEPDAVI
- **Tipo:** conocimiento_fijo
- **Inicia:** Usuario Sordo
- **Situación:** Una persona víctima de un delito llega a SEPDEP, que defiende a personas denunciadas. Se aclara la competencia y se la orienta a SEPDAVI con su requisito, sin prometer el servicio.
- **Referencia:** F-SEPDEP-01, F-SEPDAVI-02, F-SEPDAVI-03, F-SEPDAVI-04, F-SEPDAVI-05

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Usuario Sordo | Fui víctima de un delito y busco abogado gratis. | Iniciar la consulta | — |
| 2 | Funcionario | ¿Alguien lo denunció a usted por un delito? | Distinguir quién consulta | H-SEPDEP-01 |
| 3 | Usuario Sordo | No, nadie me denunció por un delito. | Respuesta | — |
| 4 | Funcionario | ¿Ya tiene un abogado de defensa en su proceso? | Defensa de la persona denunciada | H-SEPDEP-01 |
| 5 | Usuario Sordo | No, todavía no tengo abogado de defensa. | Respuesta | — |
| 6 | Funcionario | SEPDEP es la defensa pública para el denunciado, no para la víctima. | Competencia | H-SEPDEP-02 |
| 7 | Funcionario | ¿Entendió? | Competencia | H-SEPDEP-02 |
| 8 | Usuario Sordo | Sí, entendí que SEPDEP no es para mí. | Respuesta | — |
| 9 | Funcionario | ¿Quiere ir a SEPDAVI, el servicio para la víctima? | Derivación | H-SEPDAVI-06 |
| 10 | Usuario Sordo | Sí, quiero ir a SEPDAVI. | Respuesta | — |
| 11 | Funcionario | SEPDAVI exige la cédula para atender. | Requisito | H-SEPDAVI-02 |
| 12 | Funcionario | ¿Tiene su cédula para ir a SEPDAVI? | Requisito | H-SEPDAVI-02 |
| 13 | Usuario Sordo | Sí, tengo mi cédula para ir a SEPDAVI. | Respuesta | — |
| 14 | Funcionario | SEPDAVI Cochabamba está en Av. Salamanca N° 625, piso 1. Atiende de lunes a viernes, 08:30–16:30. | Lugar y horario | H-SEPDAVI-04, H-SEPDAVI-03 |
| 15 | Funcionario | Si tiene abogado particular o dinero para pagarlo, SEPDAVI no corresponde. Pregunte allí si cumple. | Condición del servicio | H-SEPDAVI-02 |

### Variantes

- **Turno 2 (Funcionario):** «¿Lo denunciaron a usted por algún delito?» · «¿Hay una denuncia en su contra?»
- **Respuestas:** «Sí, me denunciaron por un delito.» · «No, nadie me denunció por un delito.» · «No sé si hay una denuncia en mi contra.»
- **Turno 4 (Funcionario):** «¿Tiene un abogado de defensa para el proceso?» · «¿Ya nombró un abogado de defensa?»
- **Respuestas:** «Sí, ya tengo abogado de defensa.» · «No, todavía no tengo abogado de defensa.» · «No sé si tengo abogado de defensa.»
- **Turno 7 (Funcionario):** «¿Comprendió?» · «¿Entendió que SEPDEP es para la persona denunciada?»
- **Respuestas:** «Sí, entendí que SEPDEP no es para mí.» · «No, no entendí qué hace SEPDEP.» · «No sé qué hace SEPDEP.»
- **Turno 9 (Funcionario):** «¿Desea ir a SEPDAVI, que atiende a la víctima?» · «¿Quiere que le indiquen SEPDAVI?»
- **Respuestas:** «Sí, quiero ir a SEPDAVI.» · «No, no quiero ir a SEPDAVI.» · «No sé si quiero ir a SEPDAVI.»
- **Turno 12 (Funcionario):** «¿Trae su cédula para SEPDAVI?» · «¿Cuenta con la cédula que pide SEPDAVI?»
- **Respuestas:** «Sí, tengo mi cédula para ir a SEPDAVI.» · «No, no tengo mi cédula para ir a SEPDAVI.» · «No sé dónde está mi cédula para SEPDAVI.»

### Ramificaciones

- **Turno 4:** si Turno 2 es afirmado
- **Turno 7:** si Turno 2 es negado o desconocido
- **Turno 9:** si Turno 7 es afirmado
- **Turno 12:** si Turno 9 es afirmado

## ESC-SEGIP-301 — Cédula por primera vez sin certificado de nacimiento

- **Institución:** SEGIP
- **Trámite:** Cédula por primera vez sin certificado de nacimiento
- **Tipo:** conocimiento_fijo
- **Inicia:** Usuario Sordo
- **Situación:** La persona quiere su primera cédula pero no tiene el certificado de nacimiento. Se aclara cuál certificado se necesita, se la orienta a SERECI, se informa el costo documentado y se cierra con el siguiente paso.
- **Referencia:** F-SEGIP-01, F-SERECI-01

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Usuario Sordo | Quiero sacar mi cédula por primera vez. | Iniciar el trámite | — |
| 2 | Funcionario | ¿Tiene el certificado de nacimiento original? | Documento principal | H-SEGIP-02 |
| 3 | Usuario Sordo | No, no tengo el certificado de nacimiento. | Respuesta | — |
| 4 | Funcionario | ¿Su certificado es computarizado y no una fotocopia? | Validez del documento | H-SEGIP-02 |
| 5 | Usuario Sordo | Sí, mi certificado es computarizado. | Respuesta | — |
| 6 | Funcionario | El certificado debe ser original, computarizado y emitido por SERECI. | Documento faltante | H-SEGIP-02 |
| 7 | Funcionario | ¿Entendió? | Documento faltante | H-SEGIP-02 |
| 8 | Usuario Sordo | Sí, entendí qué certificado necesito. | Respuesta | — |
| 9 | Funcionario | ¿Quiere pedir el duplicado del certificado en SERECI? | Derivación | H-SERECI-01 |
| 10 | Usuario Sordo | Sí, quiero pedir el duplicado en SERECI. | Respuesta | — |
| 11 | Funcionario | La cédula física cuesta Bs 17. | Costo documentado | H-SEGIP-01 |
| 12 | Funcionario | ¿Entendió el costo? | Costo documentado | H-SEGIP-01 |
| 13 | Usuario Sordo | Sí, entendí el costo. | Respuesta | — |
| 14 | Funcionario | Vuelva a SEGIP con el certificado. Allí le confirmarán el siguiente paso. | Cierre | — |

### Variantes

- **Turno 2 (Funcionario):** «¿Trae el certificado de nacimiento original?» · «¿Cuenta con su certificado de nacimiento?»
- **Respuestas:** «Sí, tengo el certificado de nacimiento.» · «No, no tengo el certificado de nacimiento.» · «No sé si tengo el certificado de nacimiento.»
- **Turno 4 (Funcionario):** «¿Su certificado es computarizado?» · «¿El certificado de nacimiento es una fotocopia?»
- **Respuestas:** «Sí, mi certificado es computarizado.» · «No, mi certificado no es computarizado.» · «No sé si mi certificado es computarizado.»
- **Turno 7 (Funcionario):** «¿Comprendió?» · «¿Entendió qué certificado necesita?»
- **Respuestas:** «Sí, entendí qué certificado necesito.» · «No, no entendí qué certificado necesito.» · «No sé qué certificado necesito.»
- **Turno 9 (Funcionario):** «¿Desea pedir el duplicado en SERECI?» · «¿Quiere que le orienten para pedir el certificado en SERECI?»
- **Respuestas:** «Sí, quiero pedir el duplicado en SERECI.» · «No, no quiero pedir el duplicado en SERECI.» · «No sé si quiero pedir el duplicado en SERECI.»
- **Turno 12 (Funcionario):** «¿Comprendió cuánto cuesta la cédula física?» · «¿Entendió?»
- **Respuestas:** «Sí, entendí el costo.» · «No, no entendí el costo.» · «No sé cuánto cuesta.»

### Ramificaciones

- **Turno 4:** si Turno 2 es afirmado
- **Turno 7:** si Turno 2 es negado o desconocido
- **Turno 9:** si Turno 7 es afirmado

## ESC-SERECI-301 — Registro de defunción con documento faltante

- **Institución:** SERECI – Cochabamba
- **Trámite:** Registro de defunción con documento faltante
- **Tipo:** conocimiento_fijo
- **Inicia:** Usuario Sordo
- **Situación:** Un familiar registra una defunción. Se piden los documentos que la ficha enumera (certificado médico, documentos del fallecido y de quien declara); si falta uno, se indica volver con él. El duplicado tiene costo documentado.
- **Referencia:** F-SERECI-03, F-SERECI-04

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Usuario Sordo | Mi familiar murió. Quiero registrar la defunción. | Iniciar el trámite | — |
| 2 | Funcionario | ¿Tiene el certificado médico de la defunción? | Documento requerido | H-SERECI-03 |
| 3 | Usuario Sordo | No, no tengo el certificado médico. | Respuesta | — |
| 4 | Funcionario | ¿Tiene los documentos del fallecido? | Documento requerido | H-SERECI-03 |
| 5 | Usuario Sordo | Sí, tengo los documentos del fallecido. | Respuesta | — |
| 6 | Funcionario | ¿Tiene sus propios documentos de identidad, como persona que declara? | Documento requerido | H-SERECI-03 |
| 7 | Usuario Sordo | Sí, tengo mis documentos de identidad. | Respuesta | — |
| 8 | Funcionario | Falta el certificado médico. | Documento faltante | H-SERECI-03 |
| 9 | Funcionario | ¿Puede traer el certificado y volver? | Documento faltante | H-SERECI-03 |
| 10 | Usuario Sordo | Sí, puedo traer el certificado y volver. | Respuesta | — |
| 11 | Funcionario | ¿Necesita también un duplicado del certificado de defunción? | Servicio relacionado | H-SERECI-02 |
| 12 | Usuario Sordo | Sí, necesito también el duplicado. | Respuesta | — |
| 13 | Funcionario | El duplicado cuesta Bs 34 y tarda unos 5 minutos. | Costo documentado | H-SERECI-02 |
| 14 | Funcionario | ¿Entendió? | Costo documentado | H-SERECI-02 |

### Variantes

- **Turno 2 (Funcionario):** «¿Trae el certificado médico del fallecimiento?» · «¿Cuenta con el certificado médico de la defunción?»
- **Respuestas:** «Sí, tengo el certificado médico.» · «No, no tengo el certificado médico.» · «No sé si tengo el certificado médico.»
- **Turno 4 (Funcionario):** «¿Trae los documentos de la persona fallecida?» · «¿Cuenta con los documentos del fallecido?»
- **Respuestas:** «Sí, tengo los documentos del fallecido.» · «No, no tengo los documentos del fallecido.» · «No sé si tengo los documentos del fallecido.»
- **Turno 6 (Funcionario):** «¿Trae sus documentos de identidad para declarar?» · «¿Tiene su cédula como persona que declara?»
- **Respuestas:** «Sí, tengo mis documentos de identidad.» · «No, no tengo mis documentos de identidad.» · «No sé si tengo mis documentos de identidad.»
- **Turno 9 (Funcionario):** «¿Puede traer el certificado?» · «¿Puede traer el certificado médico y volver?»
- **Respuestas:** «Sí, puedo traer el certificado y volver.» · «No, no puedo traer el certificado y volver.» · «No sé si puedo traer el certificado y volver.»
- **Turno 11 (Funcionario):** «¿Quiere también un duplicado del certificado de defunción?» · «¿Desea pedir un duplicado del certificado?»
- **Respuestas:** «Sí, necesito también el duplicado.» · «No, no necesito el duplicado.» · «No sé si necesito el duplicado.»
- **Turno 14 (Funcionario):** «¿Comprendió el costo?» · «¿Entendió cuánto cuesta el duplicado y cuánto tarda?»
- **Respuestas:** «Sí, entendí el costo.» · «No, no entendí el costo.» · «No sé cuánto cuesta.»

### Ramificaciones

- **Turno 9:** si Turno 2 es negado o desconocido
- **Turno 14:** si Turno 11 es afirmado

## ESC-DISC-301 — Carnet de discapacidad: porcentaje y plazo

- **Institución:** Registro y carnet de discapacidad
- **Trámite:** Carnet de discapacidad: porcentaje y plazo
- **Tipo:** conocimiento_fijo
- **Inicia:** Usuario Sordo
- **Situación:** La persona quiere saber si le corresponde el carnet. Se pregunta por su calificación y el porcentaje, se informa que la carnetización es gratuita y el plazo informado, y si falta la calificación se ofrece una explicación.
- **Referencia:** F-DISC-01, F-DISC-02, F-DISC-03

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Usuario Sordo | Quiero saber si puedo tener carnet de discapacidad. | Iniciar la consulta | — |
| 2 | Funcionario | ¿Tiene una calificación con su porcentaje de discapacidad? | Requisito previo | H-DISC-01 |
| 3 | Usuario Sordo | Sí, tengo la calificación con mi porcentaje. | Respuesta | — |
| 4 | Funcionario | ¿Su porcentaje es de 25 % o más? | Criterio de la norma | H-DISC-04 |
| 5 | Usuario Sordo | Sí, mi porcentaje es ese o más. | Respuesta | — |
| 6 | Funcionario | La carnetización es gratuita. | Costo documentado | H-DISC-03 |
| 7 | Funcionario | ¿Quiere iniciar el trámite? | Costo documentado | H-DISC-03 |
| 8 | Usuario Sordo | Sí, quiero iniciar el trámite. | Respuesta | — |
| 9 | Funcionario | ¿Quiere que le expliquen cómo obtener la calificación? | Documento faltante | H-DISC-01 |
| 10 | Usuario Sordo | Sí, quiero esa explicación. | Respuesta | — |
| 11 | Funcionario | El Ministerio informó 4 días en zonas urbanas para el trámite. | Plazo informado | H-DISC-02 |
| 12 | Funcionario | El lugar y las fechas de calificación se confirman en la oficina antes de ir. | Cierre | — |

### Variantes

- **Turno 2 (Funcionario):** «¿Cuenta con la calificación de su discapacidad?» · «¿Ya le calificaron su porcentaje de discapacidad?»
- **Respuestas:** «Sí, tengo la calificación con mi porcentaje.» · «No, no tengo la calificación con mi porcentaje.» · «No sé si tengo la calificación con mi porcentaje.»
- **Turno 4 (Funcionario):** «¿Su porcentaje llega a 25 %?» · «¿Su porcentaje de discapacidad es 25 % o mayor?»
- **Respuestas:** «Sí, mi porcentaje es ese o más.» · «No, mi porcentaje no llega.» · «No sé cuál es mi porcentaje.»
- **Turno 7 (Funcionario):** «¿Desea iniciar el trámite?» · «¿Quiere comenzar el trámite del carnet?»
- **Respuestas:** «Sí, quiero iniciar el trámite.» · «No, no quiero iniciar el trámite.» · «No sé si quiero iniciar el trámite.»
- **Turno 9 (Funcionario):** «¿Desea que le expliquen cómo conseguir la calificación?» · «¿Quiere saber cómo obtener la calificación?»
- **Respuestas:** «Sí, quiero esa explicación.» · «No, no quiero esa explicación.» · «No sé si quiero esa explicación.»

### Ramificaciones

- **Turno 4:** si Turno 2 es afirmado
- **Turno 7:** si Turno 4 es afirmado
- **Turno 9:** si Turno 2 es negado o desconocido

## ESC-NOT-301 — Certificar una firma: notaría habilitada y arancel

- **Institución:** Notarías de Fe Pública / DIRNOPLU
- **Trámite:** Certificar una firma: notaría habilitada y arancel
- **Tipo:** mixto
- **Inicia:** Usuario Sordo
- **Situación:** La persona necesita certificar su firma. Se ofrece verificar la notaría (SINPLU), se informa el arancel documentado por formulario y, si hay otra escritura, el arancel de referencia, sin prometer un precio único.
- **Referencia:** F-NOT-01, F-NOT-02

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Usuario Sordo | Necesito certificar mi firma en un documento. | Iniciar el trámite | — |
| 2 | Funcionario | ¿Quiere verificar primero la notaría? | Verificar notaría | H-NOT-03 |
| 3 | Usuario Sordo | Sí, quiero verificar la notaría. | Respuesta | — |
| 4 | Funcionario | ¿Sabe usar el sistema SINPLU para buscar al notario? | Servicio digital | H-NOT-03 |
| 5 | Usuario Sordo | No, no sé usar el sistema SINPLU. | Respuesta | — |
| 6 | Funcionario | ¿Quiere que le ayuden a buscar al notario en SINPLU? | Ayuda accesible | H-NOT-03 |
| 7 | Usuario Sordo | Sí, quiero esa ayuda. | Respuesta | — |
| 8 | Funcionario | La certificación de firmas cuesta Bs 50 por formulario. | Costo documentado | H-NOT-01 |
| 9 | Funcionario | ¿Entendió el costo? | Costo documentado | H-NOT-01 |
| 10 | Usuario Sordo | Sí, entendí el costo. | Respuesta | — |
| 11 | Funcionario | ¿Necesita también una escritura, como un anticrético? | Otro instrumento | H-NOT-02 |
| 12 | Usuario Sordo | Sí, necesito también una escritura. | Respuesta | — |
| 13 | Funcionario | Para otras escrituras, como el anticrético, el arancel de referencia es Bs 180. | Costo de referencia | H-NOT-02 |
| 14 | Funcionario | Antes de pagar, confirme con la notaría el arancel total de su documento. | Cierre | — |

### Variantes

- **Turno 2 (Funcionario):** «¿Desea verificar primero la notaría?» · «¿Quiere confirmar la notaría?»
- **Respuestas:** «Sí, quiero verificar la notaría.» · «No, no quiero verificar la notaría.» · «No sé si quiero verificar la notaría.»
- **Turno 4 (Funcionario):** «¿Usa el sistema SINPLU para buscar notarios?» · «¿Sabe buscar un notario en SINPLU?»
- **Respuestas:** «Sí, sé usar el sistema SINPLU.» · «No, no sé usar el sistema SINPLU.» · «No sé si sé usar el sistema SINPLU.»
- **Turno 6 (Funcionario):** «¿Desea ayuda para buscar al notario en SINPLU?» · «¿Quiere que busquen al notario con usted?»
- **Respuestas:** «Sí, quiero esa ayuda.» · «No, no quiero esa ayuda.» · «No sé si quiero esa ayuda.»
- **Turno 9 (Funcionario):** «¿Comprendió cuánto cuesta certificar la firma por formulario?» · «¿Entendió?»
- **Respuestas:** «Sí, entendí el costo.» · «No, no entendí el costo.» · «No sé cuánto cuesta.»
- **Turno 11 (Funcionario):** «¿También requiere una escritura, por ejemplo un anticrético?» · «¿Quiere hacer además otra escritura?»
- **Respuestas:** «Sí, necesito también una escritura.» · «No, no necesito otra escritura.» · «No sé si necesito otra escritura.»

### Ramificaciones

- **Turno 4:** si Turno 2 es afirmado
- **Turno 6:** si Turno 4 es negado o desconocido

## ESC-SLIM-301 — Llegar al SLIM: emergencia, ubicación y horario

- **Institución:** SLIM – Gobierno Autónomo Municipal de Cochabamba
- **Trámite:** Llegar al SLIM: emergencia, ubicación y horario
- **Tipo:** conocimiento_fijo
- **Inicia:** Usuario Sordo
- **Situación:** La persona pide ayuda por violencia. Primero se distingue si está en peligro; si lo está, se da el número de emergencia; si no, se la orienta a la sede con su ubicación y horario.
- **Referencia:** F-SLIM-01

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Usuario Sordo | Necesito ayuda del SLIM por violencia. | Iniciar la consulta | — |
| 2 | Funcionario | ¿Está en peligro en este momento? | Riesgo inmediato | — |
| 3 | Usuario Sordo | No, no estoy en peligro en este momento. | Respuesta | — |
| 4 | Funcionario | ¿Puede llamar o escribir ahora? | Medio de contacto | — |
| 5 | Usuario Sordo | Sí, puedo llamar o escribir ahora. | Respuesta | — |
| 6 | Funcionario | ¿Quiere ir a la sede del SLIM? | Orientación presencial | H-SLIM-01 |
| 7 | Usuario Sordo | Sí, quiero ir a la sede. | Respuesta | — |
| 8 | Funcionario | ¿Quiere la dirección y las horas de atención? | Ubicación y horario | H-SLIM-02 |
| 9 | Usuario Sordo | Sí, quiero la dirección y las horas. | Respuesta | — |
| 10 | Funcionario | Si está en peligro, llame ahora a la emergencia del SLIM: 71742126. | Emergencia | H-SLIM-02 |
| 11 | Funcionario | La Jefatura está en Plazuela Colón, entre Venezuela y Paccieri. Atiende de lunes a viernes, 08:00–16:00; sábado y domingo cerrada. | Ubicación y horario | H-SLIM-02, H-SLIM-03 |
| 12 | Funcionario | El SLIM da atención gratuita con equipos psicológico, social y legal. | Cierre | H-SLIM-01 |

### Variantes

- **Turno 2 (Funcionario):** «¿Corre peligro ahora mismo?» · «¿Su vida está en riesgo en este momento?»
- **Respuestas:** «Sí, estoy en peligro en este momento.» · «No, no estoy en peligro en este momento.» · «No sé si estoy en peligro en este momento.»
- **Turno 4 (Funcionario):** «¿Puede usar el teléfono o escribir ahora?» · «¿Puede llamar por teléfono ahora?»
- **Respuestas:** «Sí, puedo llamar o escribir ahora.» · «No, no puedo llamar ni escribir ahora.» · «No sé si puedo llamar o escribir ahora.»
- **Turno 6 (Funcionario):** «¿Desea ir a la sede del SLIM?» · «¿Quiere que le indiquen cómo llegar a la sede?»
- **Respuestas:** «Sí, quiero ir a la sede.» · «No, no quiero ir a la sede.» · «No sé si quiero ir a la sede.»
- **Turno 8 (Funcionario):** «¿Desea la dirección y el horario de atención?» · «¿Quiere saber dónde queda y a qué hora atienden?»
- **Respuestas:** «Sí, quiero la dirección y las horas.» · «No, no quiero la dirección ni las horas.» · «No sé si quiero la dirección y las horas.»

### Ramificaciones

- **Turno 4:** si Turno 2 es afirmado
- **Turno 6:** si Turno 2 es negado o desconocido
- **Turno 8:** si Turno 6 es afirmado

## ESC-SEPDAVI-301 — Requisitos del patrocinio gratuito para la víctima

- **Institución:** SEPDAVI – Cochabamba
- **Trámite:** Requisitos del patrocinio gratuito para la víctima
- **Tipo:** conocimiento_fijo
- **Inicia:** Usuario Sordo
- **Situación:** La FELCV envió a la persona a SEPDAVI. Se revisan los requisitos uno por uno; si falta la cédula se indica volver con ella, y si cumple se informa el horario.
- **Referencia:** F-SEPDAVI-01, F-SEPDAVI-02, F-SEPDAVI-03

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Usuario Sordo | La FELCV me envió a SEPDAVI. | Iniciar el trámite | — |
| 2 | Funcionario | ¿Es víctima de un delito? | Situación de víctima | H-SEPDAVI-02 |
| 3 | Usuario Sordo | Sí, soy víctima de un delito. | Respuesta | — |
| 4 | Funcionario | ¿Trajo su cédula para el patrocinio de SEPDAVI? | Requisito | H-SEPDAVI-02 |
| 5 | Usuario Sordo | Sí, traje mi cédula para el patrocinio. | Respuesta | — |
| 6 | Funcionario | ¿Tiene un abogado particular para su caso de víctima? | Requisito | H-SEPDAVI-02 |
| 7 | Usuario Sordo | No, no tengo abogado particular para mi caso. | Respuesta | — |
| 8 | Funcionario | ¿Puede pagar un abogado para su caso de víctima? | Requisito | H-SEPDAVI-02 |
| 9 | Usuario Sordo | No, no puedo pagar un abogado para mi caso. | Respuesta | — |
| 10 | Funcionario | ¿Puede volver a SEPDAVI con su cédula? | Documento faltante | H-SEPDAVI-02 |
| 11 | Usuario Sordo | Sí, puedo volver a SEPDAVI con mi cédula. | Respuesta | — |
| 12 | Funcionario | Puede pedir patrocinio gratuito. SEPDAVI atiende de lunes a viernes, 08:30–16:30. | Horario | H-SEPDAVI-01, H-SEPDAVI-03 |
| 13 | Funcionario | Si algún requisito no se cumple, pregunte por otra ruta de ayuda. | Cierre | — |

### Variantes

- **Turno 2 (Funcionario):** «¿Usted es víctima de un delito?» · «¿Sufrió un delito y quiere apoyo?»
- **Respuestas:** «Sí, soy víctima de un delito.» · «No, no soy víctima de un delito.» · «No sé si soy víctima de un delito.»
- **Turno 4 (Funcionario):** «¿Trae su cédula para el patrocinio de SEPDAVI?» · «¿Cuenta con la cédula que SEPDAVI pide a la víctima?»
- **Respuestas:** «Sí, traje mi cédula para el patrocinio.» · «No, no traje mi cédula para el patrocinio.» · «No sé si traje mi cédula para el patrocinio.»
- **Turno 6 (Funcionario):** «¿Hay un abogado particular en su caso de víctima?» · «¿Un abogado particular lleva su caso de víctima?»
- **Respuestas:** «Sí, tengo abogado particular para mi caso.» · «No, no tengo abogado particular para mi caso.» · «No sé si tengo abogado particular para mi caso.»
- **Turno 8 (Funcionario):** «¿Puede contratar un abogado para su caso de víctima?» · «¿Tiene dinero para un abogado en su caso de víctima?»
- **Respuestas:** «Sí, puedo pagar un abogado para mi caso.» · «No, no puedo pagar un abogado para mi caso.» · «No sé si puedo pagar un abogado para mi caso.»
- **Turno 10 (Funcionario):** «¿Puede regresar a SEPDAVI con su cédula?» · «¿Puede traer su cédula otro día a SEPDAVI?»
- **Respuestas:** «Sí, puedo volver a SEPDAVI con mi cédula.» · «No, no puedo volver a SEPDAVI con mi cédula.» · «No sé si puedo volver a SEPDAVI con mi cédula.»

### Ramificaciones

- **Turno 4:** si Turno 2 es afirmado
- **Turno 6:** si Turno 4 es afirmado
- **Turno 8:** si Turno 6 es negado
- **Turno 10:** si Turno 4 es negado o desconocido

## ESC-FIS-301 — Seguimiento del caso con o sin número de caso

- **Institución:** Ministerio Público – Fiscalía Departamental de Cochabamba
- **Trámite:** Seguimiento del caso con o sin número de caso
- **Tipo:** dato_en_vivo
- **Inicia:** Usuario Sordo
- **Situación:** La persona quiere saber cómo va su denuncia. Con el número de caso puede seguirla en Fiscalía ROMA; sin él se pregunta por datos que ayuden a ubicarla. El estado del caso es un dato en vivo del expediente.
- **Referencia:** F-FIS-02, F-FIS-03, F-FIS-04

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Usuario Sordo | Quiero saber cómo va mi denuncia. | Iniciar la consulta | — |
| 2 | Funcionario | ¿Tiene el número de su caso? | Dato de búsqueda | H-FIS-03 |
| 3 | Usuario Sordo | Sí, tengo el número de mi caso. | Respuesta | — |
| 4 | Funcionario | Con el número puede seguir su caso en Fiscalía ROMA. | Servicio digital | H-FIS-03 |
| 5 | Funcionario | ¿Sabe usar ROMA? | Servicio digital | H-FIS-03 |
| 6 | Usuario Sordo | No, no sé usar ROMA. | Respuesta | — |
| 7 | Funcionario | ¿Quiere que le orienten sobre cómo usar ROMA? | Orientación accesible | H-FIS-04 |
| 8 | Usuario Sordo | Sí, quiero esa orientación. | Respuesta | — |
| 9 | Funcionario | ¿Recuerda en qué fecha presentó la denuncia? | Dato para ubicar el caso | — |
| 10 | Usuario Sordo | No, no recuerdo la fecha. | Respuesta | — |
| 11 | Funcionario | ¿Tiene el papel o la constancia de su denuncia? | Documento de respaldo | — |
| 12 | Usuario Sordo | Sí, tengo la constancia. | Respuesta | — |
| 13 | Funcionario | El estado del caso, el fiscal asignado y las actuaciones dependen de su expediente. Pregunte en la plataforma de atención. | Dato en vivo y cierre | H-FIS-05 |

### Variantes

- **Turno 2 (Funcionario):** «¿Conoce el número de su caso?» · «¿Trae el número de caso de su denuncia?»
- **Respuestas:** «Sí, tengo el número de mi caso.» · «No, no tengo el número de mi caso.» · «No sé cuál es el número de mi caso.»
- **Turno 5 (Funcionario):** «¿Usa Fiscalía ROMA para seguir su caso?» · «¿Sabe seguir su caso en ROMA?»
- **Respuestas:** «Sí, sé usar ROMA.» · «No, no sé usar ROMA.» · «No sé si sé usar ROMA.»
- **Turno 7 (Funcionario):** «¿Desea orientación para usar ROMA?» · «¿Quiere que le expliquen cómo usar ROMA?»
- **Respuestas:** «Sí, quiero esa orientación.» · «No, no quiero esa orientación.» · «No sé si quiero esa orientación.»
- **Turno 9 (Funcionario):** «¿Recuerda cuándo presentó su denuncia?» · «¿Sabe la fecha de su denuncia?»
- **Respuestas:** «Sí, recuerdo la fecha.» · «No, no recuerdo la fecha.» · «No sé la fecha.»
- **Turno 11 (Funcionario):** «¿Conserva la constancia de su denuncia?» · «¿Tiene algún papel de su denuncia?»
- **Respuestas:** «Sí, tengo la constancia.» · «No, no tengo la constancia.» · «No sé si tengo la constancia.»

### Ramificaciones

- **Turno 5:** si Turno 2 es afirmado
- **Turno 7:** si Turno 5 es negado o desconocido
- **Turno 9:** si Turno 2 es negado o desconocido
- **Turno 11:** si Turno 2 es negado o desconocido

### Datos editables

- **Turno 2:** documento_numero · «Sí, mi número de caso es {numero}.»

## ESC-LSB-301 — Reclamo por falta de intérprete: dónde acudir

- **Institución:** Derechos lingüísticos LSB / Defensoría del Pueblo
- **Trámite:** Reclamo por falta de intérprete: dónde acudir
- **Tipo:** conocimiento_fijo
- **Inicia:** Usuario Sordo
- **Situación:** A la persona sorda le negaron la interpretación en una institución pública. Se explica que la ley contempla interpretación gratuita en justicia y se la orienta a la Defensoría del Pueblo, por atención virtual en LSB, en persona o por la línea gratuita.
- **Referencia:** F-LSB-01, F-LSB-02, F-LSB-03, F-LSB-05

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Usuario Sordo | En la fiscalía no me dieron intérprete de LSB. | Iniciar el reclamo | — |
| 2 | Funcionario | ¿Le negaron la interpretación en una institución pública? | Confirmar el hecho | H-LSB-05 |
| 3 | Usuario Sordo | Sí, me negaron la interpretación. | Respuesta | — |
| 4 | Funcionario | La ley contempla interpretación gratuita en justicia, en el Ministerio Público y en la Policía. | Derecho | H-LSB-02 |
| 5 | Funcionario | ¿Entendió? | Derecho | H-LSB-02 |
| 6 | Usuario Sordo | Sí, entendí que es gratuita. | Respuesta | — |
| 7 | Funcionario | ¿Quiere presentar un reclamo en la Defensoría del Pueblo? | Derivación | H-LSB-05 |
| 8 | Usuario Sordo | Sí, quiero presentar un reclamo. | Respuesta | — |
| 9 | Funcionario | ¿Prefiere hacerlo por atención virtual en LSB? | Canal accesible | H-LSB-03 |
| 10 | Usuario Sordo | No, prefiero ir a la oficina. | Respuesta | — |
| 11 | Funcionario | La oficina de Cochabamba está en la calle 16 de Julio N° 680, Plazuela Constitución. | Lugar | H-LSB-04 |
| 12 | Funcionario | También puede llamar a la línea gratuita 800-10-8004 para denunciar vulneraciones de derechos. | Contacto | H-LSB-06 |
| 13 | Funcionario | Pida que le confirmen por escrito que recibieron su reclamo. | Cierre | — |

### Variantes

- **Turno 2 (Funcionario):** «¿Una institución pública le negó la interpretación?» · «¿Le dijeron que no había intérprete en una oficina pública?»
- **Respuestas:** «Sí, me negaron la interpretación.» · «No, no me negaron la interpretación.» · «No sé si me negaron la interpretación.»
- **Turno 5 (Funcionario):** «¿Comprendió?» · «¿Entendió que la ley contempla interpretación gratuita en justicia?»
- **Respuestas:** «Sí, entendí que es gratuita.» · «No, no entendí si es gratuita.» · «No sé si es gratuita.»
- **Turno 7 (Funcionario):** «¿Desea presentar un reclamo ante la Defensoría del Pueblo?» · «¿Quiere reclamar en la Defensoría del Pueblo?»
- **Respuestas:** «Sí, quiero presentar un reclamo.» · «No, no quiero presentar un reclamo.» · «No sé si quiero presentar un reclamo.»
- **Turno 9 (Funcionario):** «¿Desea usar la atención virtual en LSB?» · «¿Quiere el reclamo por atención virtual en LSB?»
- **Respuestas:** «Sí, prefiero la atención virtual.» · «No, prefiero ir a la oficina.» · «No sé si prefiero la atención virtual.»

### Ramificaciones

- **Turno 5:** si Turno 2 es afirmado
- **Turno 7:** si Turno 2 es afirmado
- **Turno 9:** si Turno 7 es afirmado

## ESC-FELCV-301 — Dónde pedir ayuda por violencia: FELCV o SLIM

- **Institución:** Policía Boliviana – FELCV
- **Trámite:** Dónde pedir ayuda por violencia: FELCV o SLIM
- **Tipo:** conocimiento_fijo
- **Inicia:** Usuario Sordo
- **Situación:** La persona sufre violencia y no sabe dónde acudir. Se distingue la ayuda policial de FELCV del apoyo gratuito del SLIM, y se recuerda que puede pedir intérprete de LSB.
- **Referencia:** F-FELCV-01, F-SLIM-01, F-LSB-01

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Usuario Sordo | Sufro violencia y no sé dónde pedir ayuda. | Iniciar la consulta | — |
| 2 | Funcionario | ¿Necesita ayuda policial para denunciar? | Elegir la ruta | H-FELCV-01 |
| 3 | Usuario Sordo | Sí, necesito ayuda policial. | Respuesta | — |
| 4 | Funcionario | La FELCV es la unidad policial especializada contra la violencia. | Competencia | H-FELCV-01 |
| 5 | Funcionario | ¿Entendió? | Competencia | H-FELCV-01 |
| 6 | Usuario Sordo | Sí, entendí qué es la FELCV. | Respuesta | — |
| 7 | Funcionario | ¿Prefiere apoyo psicológico, social y legal gratuito del SLIM? | Ruta alternativa | H-SLIM-01 |
| 8 | Usuario Sordo | Sí, prefiero ese apoyo gratuito. | Respuesta | — |
| 9 | Funcionario | ¿Necesita un intérprete de LSB para su atención? | Accesibilidad | H-FELCV-03 |
| 10 | Usuario Sordo | Sí, necesito un intérprete de LSB. | Respuesta | — |
| 11 | Funcionario | La ley contempla interpretación en justicia. | Derecho | H-FELCV-03 |
| 12 | Funcionario | ¿Puede pedirla al llegar? | Derecho | H-FELCV-03 |
| 13 | Usuario Sordo | Sí, puedo pedirla al llegar. | Respuesta | — |
| 14 | Funcionario | Si el riesgo es inmediato, vaya hoy al lugar de atención más cercano. | Cierre | — |

### Variantes

- **Turno 2 (Funcionario):** «¿Quiere denunciar con ayuda de la Policía?» · «¿Desea que la Policía la ayude a denunciar?»
- **Respuestas:** «Sí, necesito ayuda policial.» · «No, no necesito ayuda policial.» · «No sé si necesito ayuda policial.»
- **Turno 5 (Funcionario):** «¿Comprendió qué hace la FELCV?» · «¿Entendió?»
- **Respuestas:** «Sí, entendí qué es la FELCV.» · «No, no entendí qué es la FELCV.» · «No sé qué es la FELCV.»
- **Turno 7 (Funcionario):** «¿Desea apoyo gratuito del SLIM?» · «¿Quiere ayuda psicológica y legal del SLIM?»
- **Respuestas:** «Sí, prefiero ese apoyo gratuito.» · «No, no quiero ese apoyo gratuito.» · «No sé si quiero ese apoyo gratuito.»
- **Turno 9 (Funcionario):** «¿Quiere un intérprete de LSB?» · «¿Le hace falta un intérprete de LSB?»
- **Respuestas:** «Sí, necesito un intérprete de LSB.» · «No, no necesito un intérprete de LSB.» · «No sé si necesito un intérprete de LSB.»
- **Turno 12 (Funcionario):** «¿Puede pedir la interpretación al llegar?» · «¿Sabe que puede pedirla al llegar?»
- **Respuestas:** «Sí, puedo pedirla al llegar.» · «No, no puedo pedirla al llegar.» · «No sé si puedo pedirla al llegar.»

### Ramificaciones

- **Turno 5:** si Turno 2 es afirmado
- **Turno 7:** si Turno 2 es negado o desconocido
- **Turno 12:** si Turno 9 es afirmado

