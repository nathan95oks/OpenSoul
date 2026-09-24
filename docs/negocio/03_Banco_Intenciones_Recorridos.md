# Banco de intenciones y recorridos

Generado por `tool/build_intent_bank.py` desde `assets/dialogue/dialogue_graph.json` y `config/perfiles_institucionales.json`. No editar a mano.

**Representar la pregunta no es ofrecer respuestas a ella.** Un nodo de la sección 6 sirve para que la persona sorda conteste: su enunciado es la entrada y sus opciones son la respuesta. Que exista el nodo no demuestra que la pregunta del funcionario tenga representación en señas.

Los 209 ejemplos del corpus son **referencias**, no un límite de mensajes ni prueba de que todo el grafo sea alcanzable desde la interfaz.

## Resumen

| Indicador | Valor |
|---|---:|
| Intenciones distintas | 99 |
| Intenciones sin perfil que las priorice | 75 |
| Intenciones con conceptos pendientes | 5 |

## Intenciones

### `ACOMPAÑANTE`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: identificacion
- **Necesidades**: consultas, denuncias, tramites
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: person, polarity
- **Tarjetas válidas** (5): `NO`, `NO_SABER`, `SÍ`, `TÚ`, `VENIR`
- **Aclaraciones necesarias**:
  - Admite respuesta cerrada y detalle: el detalle solo se pide si la persona lo elige, no por omisión.
- **Transiciones**: `IDENTIFICACION_NOMBRE`, `VALIDAR_CONTACTO`
- **Perfiles que la priorizan**: ninguno
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Vino solo o acompañado?

### `AGRESION`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: violencia
- **Necesidades**: denuncias
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: polarity
- **Tarjetas válidas** (5): `MALTRATAR`, `NO`, `NO_SABER`, `PEGAR`, `SÍ`
- **Transiciones**: `CERTIFICADO_MEDICO`, `DERIVACION_SEPDAVI`, `PROTECCION_OTROS`, `SIN_INTENCION`
- **Perfiles que la priorizan**: `dna`, `policia`, `slim`
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Alguien le pegó o maltrató?

### `ALTURA`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: denuncia_robo
- **Necesidades**: denuncias
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: polarity
- **Tarjetas válidas** (6): `ALTO`, `BAJO`, `CUÁL`, `NO`, `NO_SABER`, `SÍ`
- **Transiciones**: `CABELLO`, `OBJETO_PERSONA`, `PROPIEDAD_CELULAR`, `RELATO_ABIERTO`, `RELATO_ORDENADO`, `SEXO_DESCRIPCION`, `SIN_INTENCION`, `TESTIGOS_ROBO`, `VESTIMENTA`, `VIDEO_LUGAR`
- **Perfiles que la priorizan**: ninguno
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Era alto o bajo?

### `AMENAZA`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: violencia
- **Necesidades**: denuncias
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: polarity
- **Tarjetas válidas** (5): `AMENAZAR`, `NO`, `NO_SABER`, `RECIBIR`, `SÍ`
- **Transiciones**: `CERTIFICADO_MEDICO`, `DERIVACION_SEPDAVI`, `PROTECCION_OTROS`, `SIN_INTENCION`
- **Perfiles que la priorizan**: `slim`
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Recibió amenazas?

### `AMENAZA_CELULAR`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: amenaza_digital
- **Necesidades**: denuncias
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: object, polarity
- **Tarjetas válidas** (6): `AMENAZAR`, `CELULAR`, `ENVIAR`, `NO`, `NO_SABER`, `SÍ`
- **Aclaraciones necesarias**:
  - Admite respuesta cerrada y detalle: el detalle solo se pide si la persona lo elige, no por omisión.
- **Transiciones**: `CAPTURAS`
- **Perfiles que la priorizan**: ninguno
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Las amenazas llegaron por celular?

### `AMPLIACION_RELATO`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: denuncia_robo
- **Necesidades**: denuncias
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: free_text, polarity
- **Tarjetas válidas** (6): `AUMENTAR`, `NARRAR`, `NO`, `NO_SABER`, `QUERER`, `SÍ`
- **Aclaraciones necesarias**:
  - Admite respuesta cerrada y detalle: el detalle solo se pide si la persona lo elige, no por omisión.
- **Transiciones**: `CABELLO`, `HORA_HECHO`, `OBJETO_PERSONA`, `PROPIEDAD_CELULAR`, `SEXO_DESCRIPCION`, `SIN_INTENCION`, `TESTIGOS_ROBO`, `TIEMPO_APROX`, `TIEMPO_HECHO`, `VESTIMENTA`
- **Perfiles que la priorizan**: ninguno
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Quiere agregar algo que no le pregunté?

### `ASISTENCIA_MEDICA`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: violencia
- **Necesidades**: denuncias
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: polarity
- **Tarjetas válidas** (6): `ASISTENCIA`, `DOCTOR`, `NECESITAR`, `NO`, `NO_SABER`, `SÍ`
- **Transiciones**: `CERTIFICADO_MEDICO`, `DERIVACION_SEPDAVI`, `PROTECCION_OTROS`, `SIN_INTENCION`
- **Perfiles que la priorizan**: `sepdavi`
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Necesita asistencia médica?

### `ATENCION_HOSPITAL`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: violencia
- **Necesidades**: denuncias
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: polarity
- **Tarjetas válidas** (5): `HOSPITAL`, `IR`, `NO`, `NO_SABER`, `SÍ`
- **Transiciones**: `CERTIFICADO_MEDICO`, `DERIVACION_SEPDAVI`, `PROTECCION_OTROS`, `SIN_INTENCION`
- **Perfiles que la priorizan**: ninguno
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Fue al hospital?

### `AUXILIO_INMEDIATO`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: violencia
- **Necesidades**: denuncias
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: polarity
- **Tarjetas válidas** (6): `AHORA`, `AUXILIO`, `NECESITAR`, `NO`, `NO_SABER`, `SÍ`
- **Transiciones**: `CERTIFICADO_MEDICO`, `DERIVACION_SEPDAVI`, `PROTECCION_OTROS`, `SIN_INTENCION`
- **Perfiles que la priorizan**: `policia`
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Necesita auxilio ahora?

### `AVISO_ESCRITO`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: seguimiento
- **Necesidades**: consultas, tramites
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: polarity
- **Tarjetas válidas** (7): `AVISAR`, `ENVIAR`, `ESCRIBIR`, `MEJOR`, `NO`, `NO_SABER`, `SÍ`
- **Transiciones**: `DERIVACION_FISCALIA`, `FECHA_DENUNCIA`, `FISCALIA`, `HABLAR_FISCAL`, `HABLAR_POLICIA`, `LECTURA_ANTES_FIRMA`, `ORGANO_JUDICIAL`, `SIN_INTENCION`
- **Perfiles que la priorizan**: ninguno
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Prefiere que le avisemos por escrito?

### `BANCO`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: engano_dinero
- **Necesidades**: denuncias
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: polarity
- **Tarjetas válidas** (6): `BANCO`, `BILLETES`, `ENVIAR`, `NO`, `NO_SABER`, `SÍ`
- **Transiciones**: `COMPROBANTE`, `CONTACTO_PERSONA`, `DINERO_ENTREGADO`, `MONTO`, `NOMBRE_PERSONA`
- **Perfiles que la priorizan**: ninguno
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Lo hizo mediante un banco?

### `CABELLO`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: denuncia_robo
- **Necesidades**: denuncias
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: person
- **Tarjetas válidas** (3): `CABELLO`, `CUÁL`, `NO_SABER`
- **Conceptos pendientes**: `COLOR`
- **Aclaraciones necesarias**:
  - Conceptos sin cobertura en esta intención: COLOR.
- **Transiciones**: `AMPLIACION_RELATO`, `HORA_HECHO`, `OBJETO_PERSONA`, `POSICION_LUGAR`, `PROPIEDAD_CELULAR`, `RELATO_ORDENADO`, `ROBO_CELULAR`, `ROBO_OBJETO`, `SIN_INTENCION`, `TIEMPO_APROX`
- **Perfiles que la priorizan**: ninguno
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Qué color de cabello recuerda?

### `CANAL_ESCRITO`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: identificacion
- **Necesidades**: consultas, denuncias, tramites
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: polarity
- **Tarjetas válidas** (6): `ESCRIBIR`, `MEJOR`, `NO`, `NO_SABER`, `PAPEL`, `SÍ`
- **Transiciones**: `ACOMPAÑANTE`, `CONFIRMAR_ACCESO`, `IDENTIFICACION_NOMBRE`, `VALIDAR_CONTACTO`
- **Perfiles que la priorizan**: ninguno
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Prefiere que le escriba en papel?

### `CANTIDAD_NUMEROS`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: amenaza_digital
- **Necesidades**: denuncias
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: polarity
- **Tarjetas válidas** (5): `CELULAR`, `CUÁNTOS`, `NO`, `NO_SABER`, `SÍ`
- **Transiciones**: `AMENAZA_CELULAR`, `CAPTURAS`, `MOSTRAR_CELULAR`
- **Perfiles que la priorizan**: ninguno
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Son uno o varios números?

### `CAPTURAS`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: amenaza_digital
- **Necesidades**: denuncias
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: evidence, polarity
- **Tarjetas válidas** (6): `CELULAR`, `FOTOS`, `NO`, `NO_SABER`, `SÍ`, `TENER`
- **Aclaraciones necesarias**:
  - Admite respuesta cerrada y detalle: el detalle solo se pide si la persona lo elige, no por omisión.
- **Transiciones**: `AMENAZA_CELULAR`, `MOSTRAR_CELULAR`
- **Perfiles que la priorizan**: ninguno
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Tiene fotos de la pantalla?

### `CERTIFICADO`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: otro
- **Necesidades**: consultas, denuncias, tramites
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: evidence, polarity
- **Tarjetas válidas** (5): `CERTIFICADO`, `NO`, `NO_SABER`, `SÍ`, `TENER`
- **Aclaraciones necesarias**:
  - Admite respuesta cerrada y detalle: el detalle solo se pide si la persona lo elige, no por omisión.
- **Transiciones**: `SIN_INTENCION`, `TESTIGO_CANTIDAD`, `TESTIGO_EXISTE`, `TESTIGO_TRAER`, `TESTIGO_VIO`
- **Perfiles que la priorizan**: ninguno
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Tiene un certificado?

### `CERTIFICADO_MEDICO`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: violencia
- **Necesidades**: denuncias
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: evidence, polarity
- **Tarjetas válidas** (6): `CERTIFICADO`, `DOCTOR`, `NO`, `NO_SABER`, `SÍ`, `TENER`
- **Aclaraciones necesarias**:
  - Admite respuesta cerrada y detalle: el detalle solo se pide si la persona lo elige, no por omisión.
- **Transiciones**: `DERIVACION_SEPDAVI`, `PROTECCION_OTROS`, `SIN_INTENCION`
- **Perfiles que la priorizan**: ninguno
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Tiene certificado del doctor?

### `CITACION`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: seguimiento
- **Necesidades**: consultas, tramites
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: polarity
- **Tarjetas válidas** (6): `CONVOCAR`, `NO`, `NO_SABER`, `PAPEL`, `RECIBIR`, `SÍ`
- **Transiciones**: `DERIVACION_FISCALIA`, `FECHA_DENUNCIA`, `FISCALIA`, `HABLAR_FISCAL`, `HABLAR_POLICIA`, `LECTURA_ANTES_FIRMA`, `ORGANO_JUDICIAL`, `SIN_INTENCION`
- **Perfiles que la priorizan**: `fiscalia`, `ventanilla_juzgados`
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Recibió un papel de convocatoria?

### `COMPRENSION`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: identificacion
- **Necesidades**: consultas, denuncias, tramites
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: polarity
- **Tarjetas válidas** (6): `COMPRENDER`, `EXPLICAR`, `NO`, `NO_SABER`, `SÍ`, `TÚ`
- **Transiciones**: `ACOMPAÑANTE`, `CONFIRMAR_ACCESO`, `IDENTIFICACION_NOMBRE`, `VALIDAR_CONTACTO`
- **Perfiles que la priorizan**: ninguno
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Comprende lo que le estoy explicando?

### `COMPROBANTE`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: engano_dinero
- **Necesidades**: denuncias
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: evidence, polarity
- **Tarjetas válidas** (6): `BANCO`, `FACTURA`, `NO`, `NO_SABER`, `SÍ`, `TENER`
- **Aclaraciones necesarias**:
  - Admite respuesta cerrada y detalle: el detalle solo se pide si la persona lo elige, no por omisión.
- **Transiciones**: `CONTACTO_PERSONA`, `DINERO_ENTREGADO`, `MONTO`, `NOMBRE_PERSONA`
- **Perfiles que la priorizan**: ninguno
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Tiene factura o papel del banco?

### `CONFIRMAR_ACCESO`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: identificacion
- **Necesidades**: consultas, denuncias, tramites
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: person, polarity
- **Tarjetas válidas** (5): `NO`, `NO_SABER`, `SORDO`, `SÍ`, `TÚ`
- **Aclaraciones necesarias**:
  - Admite respuesta cerrada y detalle: el detalle solo se pide si la persona lo elige, no por omisión.
- **Transiciones**: `IDENTIFICACION_NOMBRE`, `VALIDAR_CONTACTO`
- **Perfiles que la priorizan**: ninguno
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Usted es una persona sorda?

### `CONFORMIDAD`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: seguimiento
- **Necesidades**: consultas, tramites
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: polarity
- **Tarjetas válidas** (5): `ESCRIBIR`, `ESTAR_DE_ACUERDO`, `NO`, `NO_SABER`, `SÍ`
- **Transiciones**: `DERIVACION_FISCALIA`, `FECHA_DENUNCIA`, `FISCALIA`, `HABLAR_FISCAL`, `HABLAR_POLICIA`, `LECTURA_ANTES_FIRMA`, `ORGANO_JUDICIAL`, `SIN_INTENCION`
- **Perfiles que la priorizan**: ninguno
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Está de acuerdo con lo escrito?

### `CONOCIMIENTO_PERSONA`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: denuncia_robo
- **Necesidades**: denuncias
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: person, polarity
- **Tarjetas válidas** (6): `CONOCER`, `NO`, `NO_SABER`, `SÍ`, `TÚ`, `ÉL`
- **Aclaraciones necesarias**:
  - Admite respuesta cerrada y detalle: el detalle solo se pide si la persona lo elige, no por omisión.
- **Transiciones**: `HORA_HECHO`, `LUGAR_HECHO`, `OBJETO_PERSONA`, `PROPIEDAD_CELULAR`, `RELATO_ABIERTO`, `RELATO_ORDENADO`, `SIN_INTENCION`, `TIEMPO_APROX`, `TIEMPO_HECHO`, `VIDEO_LUGAR`
- **Perfiles que la priorizan**: ninguno
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Conoce a la persona involucrada?

### `CONSERVAR_CHAT`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: engano_dinero
- **Necesidades**: denuncias
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: polarity
- **Tarjetas válidas** (6): `ESCRIBIR`, `GUARDAR`, `NO`, `NO_SABER`, `SÍ`, `TOTAL`
- **Transiciones**: `COMPROBANTE`, `CONTACTO_PERSONA`, `DINERO_ENTREGADO`, `MONTO`, `NOMBRE_PERSONA`
- **Perfiles que la priorizan**: ninguno
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Conserva toda la conversación?

### `CONSULTA_ESTADO`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: seguimiento
- **Necesidades**: consultas, tramites
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: polarity
- **Tarjetas válidas** (6): `BUSCAR`, `INVESTIGACIÓN`, `NO`, `NO_SABER`, `SÍ`, `VENIR`
- **Transiciones**: `DERIVACION_FISCALIA`, `FECHA_DENUNCIA`, `FISCALIA`, `HABLAR_FISCAL`, `HABLAR_POLICIA`, `LECTURA_ANTES_FIRMA`, `ORGANO_JUDICIAL`, `SIN_INTENCION`
- **Perfiles que la priorizan**: `derechos_reales`, `fiscalia`, `gamc`, `policia`
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Vino a consultar el estado de su caso?

### `CONTACTO_INTERNET`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: engano_dinero
- **Necesidades**: denuncias
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: polarity
- **Tarjetas válidas** (5): `ESCRIBIR`, `INTERNET`, `NO`, `NO_SABER`, `SÍ`
- **Transiciones**: `COMPROBANTE`, `CONTACTO_PERSONA`, `DINERO_ENTREGADO`, `MONTO`, `NOMBRE_PERSONA`
- **Perfiles que la priorizan**: ninguno
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Se comunicaron por internet?

### `CONTACTO_PERSONA`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: engano_dinero
- **Necesidades**: denuncias
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: object, polarity
- **Tarjetas válidas** (6): `CELULAR`, `NO`, `NO_SABER`, `SÍ`, `TENER`, `ÉL`
- **Aclaraciones necesarias**:
  - Admite respuesta cerrada y detalle: el detalle solo se pide si la persona lo elige, no por omisión.
- **Transiciones**: `COMPROBANTE`, `MONTO`, `NOMBRE_PERSONA`
- **Perfiles que la priorizan**: ninguno
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Tiene su número de celular?

### `CONTEXTURA`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: denuncia_robo
- **Necesidades**: denuncias
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: polarity
- **Tarjetas válidas** (6): `CUÁL`, `FLACO`, `GORDO`, `NO`, `NO_SABER`, `SÍ`
- **Transiciones**: `CABELLO`, `OBJETO_PERSONA`, `PROPIEDAD_CELULAR`, `RELATO_ABIERTO`, `RELATO_ORDENADO`, `SEXO_DESCRIPCION`, `SIN_INTENCION`, `TESTIGOS_ROBO`, `VESTIMENTA`, `VIDEO_LUGAR`
- **Perfiles que la priorizan**: ninguno
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Era delgado o de contextura gruesa?

### `CONTINUIDAD_MENSAJES`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: amenaza_digital
- **Necesidades**: denuncias
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: polarity
- **Tarjetas válidas** (6): `AÚN`, `ESCRIBIR`, `NO`, `NO_SABER`, `RECIBIR`, `SÍ`
- **Transiciones**: `AMENAZA_CELULAR`, `CAPTURAS`, `MOSTRAR_CELULAR`
- **Perfiles que la priorizan**: ninguno
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Sigue recibiendo mensajes?

### `DERIVACION_FISCALIA`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: seguimiento
- **Necesidades**: consultas, tramites
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: institution, polarity
- **Tarjetas válidas** (4): `IR`, `NO`, `NO_SABER`, `SÍ`
- **Aclaraciones necesarias**:
  - Admite respuesta cerrada y detalle: el detalle solo se pide si la persona lo elige, no por omisión.
- **Transiciones**: `FECHA_DENUNCIA`, `FISCALIA`, `LECTURA_ANTES_FIRMA`, `ORGANO_JUDICIAL`, `SIN_INTENCION`
- **Perfiles que la priorizan**: `fiscalia`
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Le indicaron ir a la Fiscalía?

### `DERIVACION_SEPDAVI`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: violencia
- **Necesidades**: denuncias
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: institution, polarity
- **Tarjetas válidas** (5): `ASISTENCIA`, `NO`, `NO_SABER`, `QUERER`, `SÍ`
- **Aclaraciones necesarias**:
  - Admite respuesta cerrada y detalle: el detalle solo se pide si la persona lo elige, no por omisión.
- **Transiciones**: `CERTIFICADO_MEDICO`, `PROTECCION_OTROS`, `SIN_INTENCION`
- **Perfiles que la priorizan**: `sepdavi`
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Desea orientación para recibir asistencia de SEPDAVI?

### `DINERO_ENTREGADO`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: engano_dinero
- **Necesidades**: denuncias
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: object, polarity
- **Tarjetas válidas** (5): `BILLETES`, `DAR`, `NO`, `NO_SABER`, `SÍ`
- **Aclaraciones necesarias**:
  - Admite respuesta cerrada y detalle: el detalle solo se pide si la persona lo elige, no por omisión.
- **Transiciones**: `COMPROBANTE`, `MONTO`, `NOMBRE_PERSONA`
- **Perfiles que la priorizan**: ninguno
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Entregó o envió dinero?

### `EDAD_APROX`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: denuncia_robo
- **Necesidades**: denuncias
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: polarity
- **Tarjetas válidas** (6): `ADULTO`, `CUÁL`, `JOVEN`, `NO`, `NO_SABER`, `SÍ`
- **Transiciones**: `CABELLO`, `OBJETO_PERSONA`, `PROPIEDAD_CELULAR`, `RELATO_ABIERTO`, `RELATO_ORDENADO`, `SEXO_DESCRIPCION`, `SIN_INTENCION`, `TESTIGOS_ROBO`, `VESTIMENTA`, `VIDEO_LUGAR`
- **Perfiles que la priorizan**: ninguno
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Era joven o adulto?

### `ESCAPE`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: denuncia_robo
- **Necesidades**: denuncias
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: polarity
- **Tarjetas válidas** (5): `ESCAPAR`, `LADRÓN`, `NO`, `NO_SABER`, `SÍ`
- **Transiciones**: `CABELLO`, `OBJETO_PERSONA`, `PROPIEDAD_CELULAR`, `RELATO_ABIERTO`, `RELATO_ORDENADO`, `SEXO_DESCRIPCION`, `SIN_INTENCION`, `TESTIGOS_ROBO`, `VESTIMENTA`, `VIDEO_LUGAR`
- **Perfiles que la priorizan**: ninguno
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿El ladrón escapó?

### `FALTA_DINERO`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: denuncia_robo
- **Necesidades**: denuncias
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: object, polarity
- **Tarjetas válidas** (5): `BILLETES`, `NO`, `NO_SABER`, `PERDER`, `SÍ`
- **Aclaraciones necesarias**:
  - Admite respuesta cerrada y detalle: el detalle solo se pide si la persona lo elige, no por omisión.
- **Transiciones**: `CABELLO`, `HORA_HECHO`, `LUGAR_HECHO`, `RELATO_ABIERTO`, `RELATO_ORDENADO`, `SEXO_DESCRIPCION`, `SIN_INTENCION`, `TESTIGOS_ROBO`, `TIEMPO_APROX`, `TIEMPO_HECHO`
- **Perfiles que la priorizan**: ninguno
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Le falta dinero?

### `FALTA_IDENTIDAD`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: denuncia_robo
- **Necesidades**: denuncias
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: polarity
- **Tarjetas válidas** (6): `IDENTIDAD`, `NO`, `NO_SABER`, `PAPEL`, `PERDER`, `SÍ`
- **Transiciones**: `CABELLO`, `OBJETO_PERSONA`, `PROPIEDAD_CELULAR`, `RELATO_ABIERTO`, `RELATO_ORDENADO`, `SEXO_DESCRIPCION`, `SIN_INTENCION`, `TESTIGOS_ROBO`, `VESTIMENTA`, `VIDEO_LUGAR`
- **Perfiles que la priorizan**: ninguno
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Le falta su carnet de identidad?

### `FECHA_DENUNCIA`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: seguimiento
- **Necesidades**: consultas, tramites
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: time
- **Tarjetas válidas** (2): `CUÁNDO`, `NO_SABER`
- **Transiciones**: `DERIVACION_FISCALIA`, `FISCALIA`, `HABLAR_FISCAL`, `HABLAR_POLICIA`, `ORGANO_JUDICIAL`, `SIN_INTENCION`
- **Perfiles que la priorizan**: ninguno
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Cuándo presentó la denuncia?

### `FISCALIA`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: seguimiento
- **Necesidades**: consultas, tramites
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: institution, place, polarity
- **Tarjetas válidas** (4): `DÓNDE`, `NO`, `NO_SABER`, `SÍ`
- **Aclaraciones necesarias**:
  - Admite respuesta cerrada y detalle: el detalle solo se pide si la persona lo elige, no por omisión.
- **Transiciones**: `FECHA_DENUNCIA`, `LECTURA_ANTES_FIRMA`, `SIN_INTENCION`
- **Perfiles que la priorizan**: ninguno
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Necesita saber dónde está la Fiscalía?

### `FOTOS`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: otro
- **Necesidades**: consultas, denuncias, tramites
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: polarity
- **Tarjetas válidas** (5): `FOTOS`, `NO`, `NO_SABER`, `SÍ`, `TENER`
- **Transiciones**: `SIN_INTENCION`, `TESTIGO_CANTIDAD`, `TESTIGO_EXISTE`, `TESTIGO_TRAER`, `TESTIGO_VIO`
- **Perfiles que la priorizan**: ninguno
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Tiene fotografías?

### `GORRA`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: denuncia_robo
- **Necesidades**: denuncias
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: polarity
- **Tarjetas válidas** (5): `GORRA`, `NO`, `NO_SABER`, `SÍ`, `TENER`
- **Transiciones**: `CABELLO`, `OBJETO_PERSONA`, `PROPIEDAD_CELULAR`, `RELATO_ABIERTO`, `RELATO_ORDENADO`, `SEXO_DESCRIPCION`, `SIN_INTENCION`, `TESTIGOS_ROBO`, `VESTIMENTA`, `VIDEO_LUGAR`
- **Perfiles que la priorizan**: ninguno
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Llevaba gorra?

### `GUARDAR_MENSAJES`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: amenaza_digital
- **Necesidades**: denuncias
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: polarity
- **Tarjetas válidas** (5): `ESCRIBIR`, `GUARDAR`, `NO`, `NO_SABER`, `SÍ`
- **Transiciones**: `AMENAZA_CELULAR`, `CAPTURAS`, `MOSTRAR_CELULAR`
- **Perfiles que la priorizan**: ninguno
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Guardó los mensajes?

### `HABLAR_ABOGADO`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: seguimiento
- **Necesidades**: consultas, tramites
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: polarity
- **Tarjetas válidas** (6): `ABOGADO`, `HABLAR`, `NECESITAR`, `NO`, `NO_SABER`, `SÍ`
- **Transiciones**: `DERIVACION_FISCALIA`, `FECHA_DENUNCIA`, `FISCALIA`, `HABLAR_FISCAL`, `HABLAR_POLICIA`, `LECTURA_ANTES_FIRMA`, `ORGANO_JUDICIAL`, `SIN_INTENCION`
- **Perfiles que la priorizan**: `sepdep`
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Necesita hablar con un abogado?

### `HABLAR_FISCAL`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: seguimiento
- **Necesidades**: consultas, tramites
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: institution, polarity
- **Tarjetas válidas** (5): `HABLAR`, `NECESITAR`, `NO`, `NO_SABER`, `SÍ`
- **Aclaraciones necesarias**:
  - Admite respuesta cerrada y detalle: el detalle solo se pide si la persona lo elige, no por omisión.
- **Transiciones**: `FECHA_DENUNCIA`, `FISCALIA`, `LECTURA_ANTES_FIRMA`, `ORGANO_JUDICIAL`, `SIN_INTENCION`
- **Perfiles que la priorizan**: `fiscalia`
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Necesita hablar con el fiscal?

### `HABLAR_POLICIA`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: seguimiento
- **Necesidades**: consultas, tramites
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: institution, polarity
- **Tarjetas válidas** (6): `HABLAR`, `NO`, `NO_SABER`, `POLICÍA`, `QUERER`, `SÍ`
- **Aclaraciones necesarias**:
  - Admite respuesta cerrada y detalle: el detalle solo se pide si la persona lo elige, no por omisión.
- **Transiciones**: `FECHA_DENUNCIA`, `FISCALIA`, `LECTURA_ANTES_FIRMA`, `ORGANO_JUDICIAL`, `SIN_INTENCION`
- **Perfiles que la priorizan**: ninguno
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Quiere hablar con el policía encargado?

### `HERIDA`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: violencia
- **Necesidades**: denuncias
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: polarity
- **Tarjetas válidas** (5): `HERIDA`, `NO`, `NO_SABER`, `SÍ`, `TENER`
- **Transiciones**: `CERTIFICADO_MEDICO`, `DERIVACION_SEPDAVI`, `PROTECCION_OTROS`, `SIN_INTENCION`
- **Perfiles que la priorizan**: ninguno
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Está herido?

### `HORA_HECHO`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: denuncia_robo
- **Necesidades**: denuncias
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: polarity, time
- **Tarjetas válidas** (6): `CUÁNTOS`, `HORA`, `MÁS_O_MENOS`, `NO`, `NO_SABER`, `SÍ`
- **Aclaraciones necesarias**:
  - Admite respuesta cerrada y detalle: el detalle solo se pide si la persona lo elige, no por omisión.
- **Transiciones**: `CABELLO`, `OBJETO_PERSONA`, `PROPIEDAD_CELULAR`, `RELATO_ABIERTO`, `RELATO_ORDENADO`, `SEXO_DESCRIPCION`, `SIN_INTENCION`, `TESTIGOS_ROBO`, `VESTIMENTA`, `VIDEO_LUGAR`
- **Perfiles que la priorizan**: ninguno
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿A qué hora aproximadamente?

### `IDENTIFICACION_DELETREO`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: identificacion
- **Necesidades**: consultas, denuncias, tramites
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: polarity
- **Tarjetas válidas** (5): `NO`, `NOMBRE`, `NO_SABER`, `PUEDO`, `SÍ`
- **Conceptos pendientes**: `DELETREAR`
- **Aclaraciones necesarias**:
  - Conceptos sin cobertura en esta intención: DELETREAR.
- **Transiciones**: `ACOMPAÑANTE`, `CONFIRMAR_ACCESO`, `IDENTIFICACION_NOMBRE`, `VALIDAR_CONTACTO`
- **Perfiles que la priorizan**: ninguno
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Puede deletrear su apellido?

### `IDENTIFICACION_DOCUMENTO`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: identificacion
- **Necesidades**: consultas, denuncias, tramites
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: polarity
- **Tarjetas válidas** (6): `IDENTIDAD`, `NO`, `NO_SABER`, `PAPEL`, `SÍ`, `TENER`
- **Transiciones**: `ACOMPAÑANTE`, `CONFIRMAR_ACCESO`, `IDENTIFICACION_NOMBRE`, `VALIDAR_CONTACTO`
- **Perfiles que la priorizan**: `derechos_reales`, `notaria`
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Tiene su carnet de identidad?

### `IDENTIFICACION_NOMBRE`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: identificacion
- **Necesidades**: consultas, denuncias, tramites
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: free_text
- **Tarjetas válidas** (4): `CUÁL`, `NOMBRE`, `NO_SABER`, `TUYO`
- **Transiciones**: `ACOMPAÑANTE`, `CANAL_ESCRITO`, `COMPRENSION`, `CONFIRMAR_ACCESO`, `IDENTIFICACION_DELETREO`, `IDENTIFICACION_DOCUMENTO`, `LECTURA`, `NECESIDAD_INTERPRETE`, `PREFERENCIA_AVISO`, `REPARACION`
- **Perfiles que la priorizan**: `derechos_reales`, `sin_institucion`
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Cuál es su nombre completo?

### `INTENCION_DENUNCIA`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: denuncia_robo
- **Necesidades**: denuncias
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: polarity
- **Tarjetas válidas** (4): `NO`, `NO_SABER`, `PRESENTAR`, `SÍ`
- **Transiciones**: `CABELLO`, `OBJETO_PERSONA`, `PROPIEDAD_CELULAR`, `RELATO_ABIERTO`, `RELATO_ORDENADO`, `SEXO_DESCRIPCION`, `SIN_INTENCION`, `TESTIGOS_ROBO`, `VESTIMENTA`, `VIDEO_LUGAR`
- **Perfiles que la priorizan**: `policia`
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Desea presentar una denuncia?

### `INTERPRETE_REUNION`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: seguimiento
- **Necesidades**: consultas, tramites
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: polarity
- **Tarjetas válidas** (6): `INTÉRPRETE`, `NECESITAR`, `NO`, `NO_SABER`, `REUNIÓN`, `SÍ`
- **Transiciones**: `DERIVACION_FISCALIA`, `FECHA_DENUNCIA`, `FISCALIA`, `HABLAR_FISCAL`, `HABLAR_POLICIA`, `LECTURA_ANTES_FIRMA`, `ORGANO_JUDICIAL`, `SIN_INTENCION`
- **Perfiles que la priorizan**: `fiscalia`, `sepdep`
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Necesita intérprete para esa reunión?

### `JUEZ`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: seguimiento
- **Necesidades**: consultas, tramites
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: polarity
- **Tarjetas válidas** (5): `JUEZ`, `NO`, `NO_SABER`, `PRESENTAR`, `SÍ`
- **Transiciones**: `DERIVACION_FISCALIA`, `FECHA_DENUNCIA`, `FISCALIA`, `HABLAR_FISCAL`, `HABLAR_POLICIA`, `LECTURA_ANTES_FIRMA`, `ORGANO_JUDICIAL`, `SIN_INTENCION`
- **Perfiles que la priorizan**: `ventanilla_juzgados`
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Debe presentarse ante un juez?

### `LECTURA`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: identificacion
- **Necesidades**: consultas, denuncias, tramites
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: polarity
- **Tarjetas válidas** (6): `LEER`, `NO`, `NO_SABER`, `PUEDO`, `SÍ`, `TÚ`
- **Conceptos pendientes**: `TEXTO`
- **Aclaraciones necesarias**:
  - Conceptos sin cobertura en esta intención: TEXTO.
- **Transiciones**: `ACOMPAÑANTE`, `CONFIRMAR_ACCESO`, `IDENTIFICACION_NOMBRE`, `VALIDAR_CONTACTO`
- **Perfiles que la priorizan**: ninguno
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Puede leer este texto?

### `LECTURA_ANTES_FIRMA`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: seguimiento
- **Necesidades**: consultas, tramites
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: polarity, time
- **Tarjetas válidas** (8): `ESCRIBIR`, `LEER`, `NO`, `NOMBRE`, `NO_SABER`, `PAPEL`, `QUERER`, `SÍ`
- **Aclaraciones necesarias**:
  - Admite respuesta cerrada y detalle: el detalle solo se pide si la persona lo elige, no por omisión.
- **Transiciones**: `DERIVACION_FISCALIA`, `FISCALIA`, `HABLAR_FISCAL`, `HABLAR_POLICIA`, `ORGANO_JUDICIAL`, `SIN_INTENCION`
- **Perfiles que la priorizan**: `ventanilla_juzgados`
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Quiere leer el papel antes de escribir su nombre?

### `LENTES`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: denuncia_robo
- **Necesidades**: denuncias
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: polarity
- **Tarjetas válidas** (5): `LENTES`, `NO`, `NO_SABER`, `SÍ`, `TENER`
- **Transiciones**: `CABELLO`, `OBJETO_PERSONA`, `PROPIEDAD_CELULAR`, `RELATO_ABIERTO`, `RELATO_ORDENADO`, `SEXO_DESCRIPCION`, `SIN_INTENCION`, `TESTIGOS_ROBO`, `VESTIMENTA`, `VIDEO_LUGAR`
- **Perfiles que la priorizan**: ninguno
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Usaba lentes?

### `LUGAR_HECHO`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: denuncia_robo
- **Necesidades**: denuncias
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: place
- **Tarjetas válidas** (2): `DÓNDE`, `NO_SABER`
- **Transiciones**: `AMPLIACION_RELATO`, `CONOCIMIENTO_PERSONA`, `HORA_HECHO`, `OBJETO_PERSONA`, `PRESENCIA_OTROS`, `PROPIEDAD_CELULAR`, `RELATO_ORDENADO`, `SEXO_DESCRIPCION`, `SIN_INTENCION`, `TESTIGOS_ROBO`
- **Perfiles que la priorizan**: ninguno
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Dónde ocurrió?

### `MENSAJE_INTERNET`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: amenaza_digital
- **Necesidades**: denuncias
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: polarity
- **Tarjetas válidas** (6): `ENVIAR`, `ESCRIBIR`, `INTERNET`, `NO`, `NO_SABER`, `SÍ`
- **Transiciones**: `AMENAZA_CELULAR`, `CAPTURAS`, `MOSTRAR_CELULAR`
- **Perfiles que la priorizan**: ninguno
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Le escribieron por internet?

### `MONTO`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: engano_dinero
- **Necesidades**: denuncias
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: amount, object
- **Tarjetas válidas** (3): `BILLETES`, `CUÁNTOS`, `NO_SABER`
- **Transiciones**: `BANCO`, `COMPROBANTE`, `CONSERVAR_CHAT`, `CONTACTO_INTERNET`, `CONTACTO_PERSONA`, `DINERO_ENTREGADO`, `NOMBRE_PERSONA`
- **Perfiles que la priorizan**: ninguno
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Cuánto dinero entregó?

### `MOSTRAR`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: otro
- **Necesidades**: consultas, denuncias, tramites
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: polarity
- **Tarjetas válidas** (6): `AHORA`, `MOSTRAR`, `NO`, `NO_SABER`, `PUEDO`, `SÍ`
- **Transiciones**: `SIN_INTENCION`, `TESTIGO_CANTIDAD`, `TESTIGO_EXISTE`, `TESTIGO_TRAER`, `TESTIGO_VIO`
- **Perfiles que la priorizan**: ninguno
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Puede mostrarlo ahora?

### `MOSTRAR_CELULAR`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: amenaza_digital
- **Necesidades**: denuncias
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: object, polarity
- **Tarjetas válidas** (7): `AHORA`, `CELULAR`, `MOSTRAR`, `NO`, `NO_SABER`, `PUEDO`, `SÍ`
- **Aclaraciones necesarias**:
  - Admite respuesta cerrada y detalle: el detalle solo se pide si la persona lo elige, no por omisión.
- **Transiciones**: `CAPTURAS`
- **Perfiles que la priorizan**: ninguno
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Puede mostrar el celular ahora?

### `NECESIDAD_INTERPRETE`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: identificacion
- **Necesidades**: consultas, denuncias, tramites
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: polarity
- **Tarjetas válidas** (5): `INTÉRPRETE`, `NECESITAR`, `NO`, `NO_SABER`, `SÍ`
- **Transiciones**: `ACOMPAÑANTE`, `CONFIRMAR_ACCESO`, `IDENTIFICACION_NOMBRE`, `VALIDAR_CONTACTO`
- **Perfiles que la priorizan**: `sin_institucion`
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Necesita un intérprete de LSB?

### `NOMBRE_PERSONA`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: engano_dinero
- **Necesidades**: denuncias
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: person, polarity
- **Tarjetas válidas** (6): `CONOCER`, `NO`, `NOMBRE`, `NO_SABER`, `SÍ`, `ÉL`
- **Aclaraciones necesarias**:
  - Admite respuesta cerrada y detalle: el detalle solo se pide si la persona lo elige, no por omisión.
- **Transiciones**: `COMPROBANTE`, `CONTACTO_PERSONA`, `DINERO_ENTREGADO`, `MONTO`
- **Perfiles que la priorizan**: ninguno
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Conoce el nombre de la persona?

### `NUMERO_ORIGEN`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: amenaza_digital
- **Necesidades**: denuncias
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: polarity
- **Tarjetas válidas** (5): `CELULAR`, `CONOCER`, `NO`, `NO_SABER`, `SÍ`
- **Transiciones**: `AMENAZA_CELULAR`, `CAPTURAS`, `MOSTRAR_CELULAR`
- **Perfiles que la priorizan**: ninguno
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Conoce el número desde el que le escribieron?

### `NUMERO_REFERENCIA`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: seguimiento
- **Necesidades**: consultas, tramites
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: polarity
- **Tarjetas válidas** (4): `NO`, `NO_SABER`, `SÍ`, `TENER`
- **Transiciones**: `DERIVACION_FISCALIA`, `FECHA_DENUNCIA`, `FISCALIA`, `HABLAR_FISCAL`, `HABLAR_POLICIA`, `LECTURA_ANTES_FIRMA`, `ORGANO_JUDICIAL`, `SIN_INTENCION`
- **Perfiles que la priorizan**: `policia`
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Tiene el número de referencia?

### `OBJETO_PERSONA`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: denuncia_robo
- **Necesidades**: denuncias
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: object, polarity
- **Tarjetas válidas** (6): `BOLSA`, `CUÁL`, `MOCHILA`, `NO`, `NO_SABER`, `SÍ`
- **Aclaraciones necesarias**:
  - Admite respuesta cerrada y detalle: el detalle solo se pide si la persona lo elige, no por omisión.
- **Transiciones**: `CABELLO`, `HORA_HECHO`, `LUGAR_HECHO`, `RELATO_ABIERTO`, `RELATO_ORDENADO`, `SEXO_DESCRIPCION`, `SIN_INTENCION`, `TESTIGOS_ROBO`, `TIEMPO_APROX`, `TIEMPO_HECHO`
- **Perfiles que la priorizan**: ninguno
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Llevaba mochila o bolsa?

### `OBJETO_ROBADO`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: denuncia_robo
- **Necesidades**: denuncias
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: object
- **Tarjetas válidas** (3): `NO_SABER`, `QUÉ`, `ROBAR`
- **Transiciones**: `AMPLIACION_RELATO`, `CONOCIMIENTO_PERSONA`, `HORA_HECHO`, `POSICION_LUGAR`, `PRESENCIA_OTROS`, `PROPIEDAD_CELULAR`, `RELATO_ORDENADO`, `SEXO_DESCRIPCION`, `SIN_INTENCION`, `TESTIGOS_ROBO`
- **Perfiles que la priorizan**: ninguno
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Qué le robaron?

### `ORGANO_JUDICIAL`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: seguimiento
- **Necesidades**: consultas, tramites
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: place, polarity
- **Tarjetas válidas** (5): `DÓNDE`, `NO`, `NO_SABER`, `SÍ`, `ÓRGANO_JUDICIAL`
- **Aclaraciones necesarias**:
  - Admite respuesta cerrada y detalle: el detalle solo se pide si la persona lo elige, no por omisión.
- **Transiciones**: `DERIVACION_FISCALIA`, `FECHA_DENUNCIA`, `FISCALIA`, `HABLAR_FISCAL`, `HABLAR_POLICIA`, `LECTURA_ANTES_FIRMA`, `SIN_INTENCION`
- **Perfiles que la priorizan**: `ventanilla_juzgados`
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Sabe dónde está el Órgano Judicial?

### `POSICION_LUGAR`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: denuncia_robo
- **Necesidades**: denuncias
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: place, polarity
- **Tarjetas válidas** (6): `CUÁL`, `DENTRO`, `FUERA`, `NO`, `NO_SABER`, `SÍ`
- **Aclaraciones necesarias**:
  - Admite respuesta cerrada y detalle: el detalle solo se pide si la persona lo elige, no por omisión.
- **Transiciones**: `CABELLO`, `OBJETO_PERSONA`, `PROPIEDAD_CELULAR`, `RELATO_ABIERTO`, `RELATO_ORDENADO`, `SEXO_DESCRIPCION`, `SIN_INTENCION`, `TESTIGOS_ROBO`, `TIEMPO_APROX`, `TIEMPO_HECHO`
- **Perfiles que la priorizan**: ninguno
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Ocurrió dentro o fuera del lugar?

### `PREFERENCIA_AVISO`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: identificacion
- **Necesidades**: consultas, denuncias, tramites
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: polarity
- **Tarjetas válidas** (7): `AVISAR`, `ENVIAR`, `ESCRIBIR`, `MEJOR`, `NO`, `NO_SABER`, `SÍ`
- **Transiciones**: `ACOMPAÑANTE`, `CONFIRMAR_ACCESO`, `IDENTIFICACION_NOMBRE`, `VALIDAR_CONTACTO`
- **Perfiles que la priorizan**: ninguno
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Prefiere recibir avisos por mensaje escrito?

### `PRESENCIA_OTROS`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: denuncia_robo
- **Necesidades**: denuncias
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: person, polarity
- **Tarjetas válidas** (7): `ALLÍ`, `HOMBRE`, `MUJER`, `NO`, `NO_SABER`, `SÍ`, `TENER`
- **Aclaraciones necesarias**:
  - Admite respuesta cerrada y detalle: el detalle solo se pide si la persona lo elige, no por omisión.
- **Transiciones**: `HORA_HECHO`, `LUGAR_HECHO`, `OBJETO_PERSONA`, `PROPIEDAD_CELULAR`, `RELATO_ABIERTO`, `RELATO_ORDENADO`, `SIN_INTENCION`, `TIEMPO_APROX`, `TIEMPO_HECHO`, `VIDEO_LUGAR`
- **Perfiles que la priorizan**: ninguno
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Había otras personas presentes?

### `PRESENTAR_ELEMENTOS`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: otro
- **Necesidades**: consultas, denuncias, tramites
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: polarity
- **Tarjetas válidas** (6): `FOTOS`, `NO`, `NO_SABER`, `PRESENTAR`, `QUERER`, `SÍ`
- **Transiciones**: `SIN_INTENCION`, `TESTIGO_CANTIDAD`, `TESTIGO_EXISTE`, `TESTIGO_TRAER`, `TESTIGO_VIO`
- **Perfiles que la priorizan**: ninguno
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Desea presentar estos elementos?

### `PROPIEDAD_CELULAR`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: denuncia_robo
- **Necesidades**: denuncias
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: evidence, object, polarity
- **Tarjetas válidas** (7): `CAJA`, `CELULAR`, `FACTURA`, `NO`, `NO_SABER`, `SÍ`, `TENER`
- **Aclaraciones necesarias**:
  - Admite respuesta cerrada y detalle: el detalle solo se pide si la persona lo elige, no por omisión.
- **Transiciones**: `CABELLO`, `CONOCIMIENTO_PERSONA`, `HORA_HECHO`, `LUGAR_HECHO`, `POSICION_LUGAR`, `PRESENCIA_OTROS`, `RELATO_ABIERTO`, `RELATO_ORDENADO`, `SEXO_DESCRIPCION`, `TIEMPO_APROX`
- **Perfiles que la priorizan**: ninguno
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Tiene la factura o la caja del celular?

### `PROTECCION_OTROS`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: violencia
- **Necesidades**: denuncias
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: person, polarity
- **Tarjetas válidas** (6): `HIJO`, `NECESITAR`, `NO`, `NO_SABER`, `PROTEGER`, `SÍ`
- **Aclaraciones necesarias**:
  - Admite respuesta cerrada y detalle: el detalle solo se pide si la persona lo elige, no por omisión.
- **Transiciones**: `CERTIFICADO_MEDICO`, `DERIVACION_SEPDAVI`, `SIN_INTENCION`
- **Perfiles que la priorizan**: `dna`, `sepdavi`, `slim`
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Hay niños u otras personas que necesiten protección?

### `RASGO_DISTINTIVO`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: denuncia_robo
- **Necesidades**: denuncias
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: polarity
- **Tarjetas válidas** (5): `NO`, `NO_SABER`, `QUÉ`, `RECORDAR`, `SÍ`
- **Transiciones**: `CABELLO`, `OBJETO_PERSONA`, `PROPIEDAD_CELULAR`, `RELATO_ABIERTO`, `RELATO_ORDENADO`, `SEXO_DESCRIPCION`, `SIN_INTENCION`, `TESTIGOS_ROBO`, `VESTIMENTA`, `VIDEO_LUGAR`
- **Perfiles que la priorizan**: ninguno
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Recuerda alguna característica particular?

### `RECIBIR_RESOLUCION`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: seguimiento
- **Necesidades**: consultas, tramites
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: polarity
- **Tarjetas válidas** (5): `NO`, `NO_SABER`, `RECIBIR`, `RESOLUCIÓN`, `SÍ`
- **Transiciones**: `DERIVACION_FISCALIA`, `FECHA_DENUNCIA`, `FISCALIA`, `HABLAR_FISCAL`, `HABLAR_POLICIA`, `LECTURA_ANTES_FIRMA`, `ORGANO_JUDICIAL`, `SIN_INTENCION`
- **Perfiles que la priorizan**: `ventanilla_juzgados`
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Recibió una resolución?

### `RECONOCIMIENTO`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: denuncia_robo
- **Necesidades**: denuncias
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: polarity
- **Tarjetas válidas** (7): `IDENTIFICAR`, `NO`, `NO_SABER`, `PUEDO`, `SÍ`, `VER`, `VOLVER`
- **Transiciones**: `CABELLO`, `OBJETO_PERSONA`, `PROPIEDAD_CELULAR`, `RELATO_ABIERTO`, `RELATO_ORDENADO`, `SEXO_DESCRIPCION`, `SIN_INTENCION`, `TESTIGOS_ROBO`, `VESTIMENTA`, `VIDEO_LUGAR`
- **Perfiles que la priorizan**: ninguno
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Puede identificarla si la vuelve a ver?

### `RELATO_ABIERTO`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: denuncia_robo
- **Necesidades**: denuncias
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: free_text
- **Tarjetas válidas** (4): `NARRAR`, `NO_SABER`, `QUÉ`, `TÚ`
- **Transiciones**: `CONOCIMIENTO_PERSONA`, `HORA_HECHO`, `OBJETO_PERSONA`, `POSICION_LUGAR`, `PRESENCIA_OTROS`, `PROPIEDAD_CELULAR`, `ROBO_OBJETO`, `SEXO_DESCRIPCION`, `SIN_INTENCION`, `TESTIGOS_ROBO`
- **Perfiles que la priorizan**: `policia`, `sin_institucion`
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Qué ocurrió?

### `RELATO_ORDENADO`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: denuncia_robo
- **Necesidades**: denuncias
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: free_text, polarity
- **Tarjetas válidas** (6): `EMPEZAR`, `NARRAR`, `NO`, `NO_SABER`, `PRIMERA_VEZ`, `SÍ`
- **Aclaraciones necesarias**:
  - Admite respuesta cerrada y detalle: el detalle solo se pide si la persona lo elige, no por omisión.
- **Transiciones**: `CABELLO`, `HORA_HECHO`, `OBJETO_PERSONA`, `PROPIEDAD_CELULAR`, `SEXO_DESCRIPCION`, `SIN_INTENCION`, `TESTIGOS_ROBO`, `TIEMPO_APROX`, `TIEMPO_HECHO`, `VESTIMENTA`
- **Perfiles que la priorizan**: ninguno
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Puede contarme lo sucedido desde el inicio?

### `REPARACION`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: identificacion
- **Necesidades**: consultas, denuncias, tramites
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: polarity
- **Tarjetas válidas** (7): `EXPLICAR`, `LENTO`, `NO`, `NO_SABER`, `QUERER`, `SÍ`, `VOLVER`
- **Transiciones**: `ACOMPAÑANTE`, `CONFIRMAR_ACCESO`, `IDENTIFICACION_NOMBRE`, `VALIDAR_CONTACTO`
- **Perfiles que la priorizan**: ninguno
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Quiere que lo explique otra vez y más despacio?

### `RESOLUCION`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: otro
- **Necesidades**: consultas, denuncias, tramites
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: polarity
- **Tarjetas válidas** (5): `NO`, `NO_SABER`, `RESOLUCIÓN`, `SÍ`, `TENER`
- **Transiciones**: `SIN_INTENCION`, `TESTIGO_CANTIDAD`, `TESTIGO_EXISTE`, `TESTIGO_TRAER`, `TESTIGO_VIO`
- **Perfiles que la priorizan**: ninguno
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Tiene una resolución o papel previo?

### `RETORNO`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: seguimiento
- **Necesidades**: consultas, tramites
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: polarity
- **Tarjetas válidas** (6): `DÍA`, `NECESITAR`, `NO`, `NO_SABER`, `SÍ`, `VOLVER`
- **Transiciones**: `DERIVACION_FISCALIA`, `FECHA_DENUNCIA`, `FISCALIA`, `HABLAR_FISCAL`, `HABLAR_POLICIA`, `LECTURA_ANTES_FIRMA`, `ORGANO_JUDICIAL`, `SIN_INTENCION`
- **Perfiles que la priorizan**: ninguno
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Tiene que volver otro día?

### `RIESGO_RETORNO`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: violencia
- **Necesidades**: denuncias
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: polarity
- **Tarjetas válidas** (6): `CASA`, `MIEDO`, `NO`, `NO_SABER`, `SÍ`, `VOLVER`
- **Transiciones**: `CERTIFICADO_MEDICO`, `DERIVACION_SEPDAVI`, `PROTECCION_OTROS`, `SIN_INTENCION`
- **Perfiles que la priorizan**: ninguno
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Tiene miedo de volver a su casa?

### `ROBO_CELULAR`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: denuncia_robo
- **Necesidades**: denuncias
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: object, polarity
- **Tarjetas válidas** (5): `CELULAR`, `NO`, `NO_SABER`, `ROBAR`, `SÍ`
- **Aclaraciones necesarias**:
  - Admite respuesta cerrada y detalle: el detalle solo se pide si la persona lo elige, no por omisión.
- **Transiciones**: `CABELLO`, `HORA_HECHO`, `LUGAR_HECHO`, `RELATO_ABIERTO`, `RELATO_ORDENADO`, `SEXO_DESCRIPCION`, `SIN_INTENCION`, `TESTIGOS_ROBO`, `TIEMPO_APROX`, `TIEMPO_HECHO`
- **Perfiles que la priorizan**: `policia`
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Le robaron el celular?

### `ROBO_OBJETO`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: denuncia_robo
- **Necesidades**: denuncias
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: object, polarity
- **Tarjetas válidas** (4): `NO`, `NO_SABER`, `ROBAR`, `SÍ`
- **Conceptos pendientes**: `OBJETO`
- **Aclaraciones necesarias**:
  - Conceptos sin cobertura en esta intención: OBJETO.
  - Admite respuesta cerrada y detalle: el detalle solo se pide si la persona lo elige, no por omisión.
- **Transiciones**: `CABELLO`, `HORA_HECHO`, `LUGAR_HECHO`, `RELATO_ABIERTO`, `RELATO_ORDENADO`, `SEXO_DESCRIPCION`, `SIN_INTENCION`, `TESTIGOS_ROBO`, `TIEMPO_APROX`, `TIEMPO_HECHO`
- **Perfiles que la priorizan**: ninguno
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Le robaron algún objeto?

### `SEPDEP`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: seguimiento
- **Necesidades**: consultas, tramites
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: polarity
- **Tarjetas válidas** (6): `ABOGADO`, `GRATIS`, `NECESITAR`, `NO`, `NO_SABER`, `SÍ`
- **Transiciones**: `DERIVACION_FISCALIA`, `FECHA_DENUNCIA`, `FISCALIA`, `HABLAR_FISCAL`, `HABLAR_POLICIA`, `LECTURA_ANTES_FIRMA`, `ORGANO_JUDICIAL`, `SIN_INTENCION`
- **Perfiles que la priorizan**: `sepdep`
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Necesita defensa pública gratuita?

### `SEXO_DESCRIPCION`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: denuncia_robo
- **Necesidades**: denuncias
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: person, polarity
- **Tarjetas válidas** (6): `CUÁL`, `HOMBRE`, `MUJER`, `NO`, `NO_SABER`, `SÍ`
- **Aclaraciones necesarias**:
  - Admite respuesta cerrada y detalle: el detalle solo se pide si la persona lo elige, no por omisión.
- **Transiciones**: `HORA_HECHO`, `LUGAR_HECHO`, `OBJETO_PERSONA`, `PROPIEDAD_CELULAR`, `RELATO_ABIERTO`, `RELATO_ORDENADO`, `SIN_INTENCION`, `TIEMPO_APROX`, `TIEMPO_HECHO`, `VIDEO_LUGAR`
- **Perfiles que la priorizan**: ninguno
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Era un hombre o una mujer?

### `SIN_INTENCION`

- **Procedencia**: secciones 7, 8 del corpus · 111 nodo(s)
- **Ámbitos**: denuncia_robo, identificacion, otro, seguimiento, violencia
- **Necesidades**: consultas, denuncias, tramites
- **Propósitos en que se activa**: independiente, inicio_conversacion, respuesta
- **Actos comunicativos**: question, statement
- **Datos requeridos**: amount, evidence, free_text, institution, object, person, place, polarity, time
- **Tarjetas válidas** (119): `ABOGADO`, `ACOMPAÑAR`, `AHORA`, `AMENAZAR`, `AQUÍ`, `ARREGLAR`, `ASISTENCIA`, `AUMENTAR`, `AUXILIO`, `AVISAR`, `AYER`, `AYUDAR`, `AÚN`, `BANCO`, `BILLETES`, `BRAZO`, `BUSCAR`, `CAJA`, `CALLE`, `CAMBIAR`, `CASA`, `CELULAR`, `CERCA`, `CERTIFICADO`, `COMPRENDER`, `CONOCER`, `CONTINUAR`, `CUÁNDO`, `CUÁNTOS`, `DAR`, `DAÑAR`, `DESPUÉS`, `DIRECCIÓN`, `DOCTOR`, `DÓNDE`, `ELLOS`, `EMPEZAR`, `ENGAÑAR`, `ENVIAR`, `ESCRIBIR`, `ESPERAR`, `EXPLICAR`, `FACTURA`, `FILMAR`, `FOTOCOPIA`, `FOTOS`, `GRACIAS`, `GRATIS`, `GUARDAR`, `HABLAR`, `HACER`, `HERIDA`, `HOMBRE`, `HORA`, `HOSPITAL`, `IDENTIDAD`, `IDENTIFICAR`, `INTÉRPRETE`, `INVESTIGACIÓN`, `IR`, `JOVEN`, `JUEZ`, `LEER`, `LENTO`, `MAL`, `MAÑANA`, `MEJOR`, `MERCADO`, `MIEDO`, `MOCHILA`, `MOSTRAR`, `MÍO`, `NARRAR`, `NECESITAR`, `NO`, `NOMBRE`, `NO_SABER`, `OBSERVAR`, `PAPEL`, `PAREJA`, `PASADO`, `PEDIR`, `PEGAR`, `PERDER`, `POCO`, `POLICÍA`, `POR_FAVOR`, `PRESENTAR`, `PRIMERA_VEZ`, `PROTEGER`, `PUEDO`, `PUERTA`, `QUERER`, `QUIÉN`, `QUÉ`, `RECIBIR`, `RECORDAR`, `RESOLUCIÓN`, `ROBAR`, `SABER`, `SELLO`, `SORDO`, `SÍ`, `TARDE`, `TENER`, `TERMINAR`, `TESTIGO`, `TESTIMONIO`, `TIENDA`, `TOTAL`, `TRAER`, `TÚ`, `VENIR`, `VER`, `VIDEO`, `VOLVER`, `YO`, `ÉL`, `ÓRGANO_JUDICIAL`
- **Conceptos pendientes**: `OBJETO`
- **Aclaraciones necesarias**:
  - La misma intención aparece como pregunta y como declaración: confirmar el acto antes de redactar.
  - Conceptos sin cobertura en esta intención: OBJETO.
  - Admite respuesta cerrada y detalle: el detalle solo se pide si la persona lo elige, no por omisión.
- **Transiciones**: `ACOMPAÑANTE`, `AGRESION`, `AMENAZA`, `AMPLIACION_RELATO`, `ASISTENCIA_MEDICA`, `ATENCION_HOSPITAL`, `AUXILIO_INMEDIATO`, `CABELLO`, `CERTIFICADO`, `CERTIFICADO_MEDICO`
- **Perfiles que la priorizan**: ninguno
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Aquí hay intérprete de LSB?
  - ¿Puede escribir lo que me pregunta?
  - ¿Puede hablar más despacio?
  - ¿Puede mostrarme otra vez?
  - ¿Puedo leer primero?
  - ¿Me entiende?

### `TESTIGOS_ROBO`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: denuncia_robo
- **Necesidades**: denuncias
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: evidence, person, polarity
- **Tarjetas válidas** (5): `NO`, `NO_SABER`, `SÍ`, `TENER`, `TESTIGO`
- **Aclaraciones necesarias**:
  - Admite respuesta cerrada y detalle: el detalle solo se pide si la persona lo elige, no por omisión.
- **Transiciones**: `AMPLIACION_RELATO`, `HORA_HECHO`, `LUGAR_HECHO`, `OBJETO_PERSONA`, `OBJETO_ROBADO`, `POSICION_LUGAR`, `RELATO_ABIERTO`, `RELATO_ORDENADO`, `ROBO_OBJETO`, `SIN_INTENCION`
- **Perfiles que la priorizan**: ninguno
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Hay testigos del robo?

### `TESTIGO_CANTIDAD`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: otro
- **Necesidades**: consultas, denuncias, tramites
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: amount, evidence, person
- **Tarjetas válidas** (3): `CUÁNTOS`, `NO_SABER`, `TESTIGO`
- **Transiciones**: `CERTIFICADO`, `FOTOS`, `MOSTRAR`, `PRESENTAR_ELEMENTOS`, `RESOLUCION`, `SIN_INTENCION`, `TESTIGO_EXISTE`, `TESTIGO_TRAER`, `TESTIGO_VIO`, `VIDEO`
- **Perfiles que la priorizan**: ninguno
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Cuántos testigos hay?

### `TESTIGO_EXISTE`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: otro
- **Necesidades**: consultas, denuncias, tramites
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: evidence, person, polarity
- **Tarjetas válidas** (5): `NO`, `NO_SABER`, `SÍ`, `TENER`, `TESTIGO`
- **Aclaraciones necesarias**:
  - Admite respuesta cerrada y detalle: el detalle solo se pide si la persona lo elige, no por omisión.
- **Transiciones**: `SIN_INTENCION`, `TESTIGO_CANTIDAD`
- **Perfiles que la priorizan**: ninguno
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Hay algún testigo?

### `TESTIGO_TRAER`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: otro
- **Necesidades**: consultas, denuncias, tramites
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: evidence, person, polarity
- **Tarjetas válidas** (6): `NO`, `NO_SABER`, `PUEDO`, `SÍ`, `TESTIGO`, `TRAER`
- **Aclaraciones necesarias**:
  - Admite respuesta cerrada y detalle: el detalle solo se pide si la persona lo elige, no por omisión.
- **Transiciones**: `SIN_INTENCION`, `TESTIGO_CANTIDAD`
- **Perfiles que la priorizan**: ninguno
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Puede traer al testigo?

### `TESTIGO_VIO`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: otro
- **Necesidades**: consultas, denuncias, tramites
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: evidence, person, polarity
- **Tarjetas válidas** (6): `NO`, `NO_SABER`, `SÍ`, `TESTIGO`, `TOTAL`, `VER`
- **Aclaraciones necesarias**:
  - Admite respuesta cerrada y detalle: el detalle solo se pide si la persona lo elige, no por omisión.
- **Transiciones**: `SIN_INTENCION`, `TESTIGO_CANTIDAD`
- **Perfiles que la priorizan**: ninguno
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿El testigo vio todo?

### `TIEMPO_APROX`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: denuncia_robo
- **Necesidades**: denuncias
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: polarity, time
- **Tarjetas válidas** (6): `AYER`, `HOY`, `NO`, `NO_SABER`, `PASADO`, `SÍ`
- **Aclaraciones necesarias**:
  - Admite respuesta cerrada y detalle: el detalle solo se pide si la persona lo elige, no por omisión.
- **Transiciones**: `CABELLO`, `OBJETO_PERSONA`, `PROPIEDAD_CELULAR`, `RELATO_ABIERTO`, `RELATO_ORDENADO`, `SEXO_DESCRIPCION`, `SIN_INTENCION`, `TESTIGOS_ROBO`, `VESTIMENTA`, `VIDEO_LUGAR`
- **Perfiles que la priorizan**: ninguno
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Fue hoy, ayer o antes?

### `TIEMPO_HECHO`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: denuncia_robo
- **Necesidades**: denuncias
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: time
- **Tarjetas válidas** (4): `CUÁNDO`, `FECHA`, `HORA`, `NO_SABER`
- **Transiciones**: `AMPLIACION_RELATO`, `CONOCIMIENTO_PERSONA`, `OBJETO_PERSONA`, `POSICION_LUGAR`, `PRESENCIA_OTROS`, `PROPIEDAD_CELULAR`, `RELATO_ORDENADO`, `SEXO_DESCRIPCION`, `SIN_INTENCION`, `TESTIGOS_ROBO`
- **Perfiles que la priorizan**: ninguno
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Cuándo ocurrió?

### `VALIDAR_CONTACTO`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: identificacion
- **Necesidades**: consultas, denuncias, tramites
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: object, polarity
- **Tarjetas válidas** (6): `CELULAR`, `NO`, `NO_SABER`, `SÍ`, `TUYO`, `VERDAD`
- **Aclaraciones necesarias**:
  - Admite respuesta cerrada y detalle: el detalle solo se pide si la persona lo elige, no por omisión.
- **Transiciones**: `ACOMPAÑANTE`, `CONFIRMAR_ACCESO`, `IDENTIFICACION_NOMBRE`
- **Perfiles que la priorizan**: ninguno
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Este número de celular es suyo?

### `VER_LADRON`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: denuncia_robo
- **Necesidades**: denuncias
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: polarity
- **Tarjetas válidas** (5): `LADRÓN`, `NO`, `NO_SABER`, `SÍ`, `VER`
- **Transiciones**: `CABELLO`, `OBJETO_PERSONA`, `PROPIEDAD_CELULAR`, `RELATO_ABIERTO`, `RELATO_ORDENADO`, `SEXO_DESCRIPCION`, `SIN_INTENCION`, `TESTIGOS_ROBO`, `VESTIMENTA`, `VIDEO_LUGAR`
- **Perfiles que la priorizan**: ninguno
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Vio al ladrón?

### `VESTIMENTA`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: denuncia_robo
- **Necesidades**: denuncias
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: person
- **Tarjetas válidas** (5): `CHAMARRA`, `CUÁL`, `NO_SABER`, `PANTALÓN`, `POLERA`
- **Transiciones**: `AMPLIACION_RELATO`, `HORA_HECHO`, `OBJETO_PERSONA`, `POSICION_LUGAR`, `PROPIEDAD_CELULAR`, `RELATO_ORDENADO`, `ROBO_CELULAR`, `ROBO_OBJETO`, `SIN_INTENCION`, `TIEMPO_APROX`
- **Perfiles que la priorizan**: ninguno
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Qué ropa llevaba?

### `VIDEO`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: otro
- **Necesidades**: consultas, denuncias, tramites
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: evidence, polarity
- **Tarjetas válidas** (5): `NO`, `NO_SABER`, `SÍ`, `TENER`, `VIDEO`
- **Aclaraciones necesarias**:
  - Admite respuesta cerrada y detalle: el detalle solo se pide si la persona lo elige, no por omisión.
- **Transiciones**: `SIN_INTENCION`, `TESTIGO_CANTIDAD`, `TESTIGO_EXISTE`, `TESTIGO_TRAER`, `TESTIGO_VIO`
- **Perfiles que la priorizan**: ninguno
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Tiene video?

### `VIDEO_LUGAR`

- **Procedencia**: secciones 6 del corpus · 1 nodo(s)
- **Ámbitos**: denuncia_robo
- **Necesidades**: denuncias
- **Propósitos en que se activa**: respuesta
- **Actos comunicativos**: question
- **Datos requeridos**: evidence, place, polarity
- **Tarjetas válidas** (6): `FILMAR`, `NO`, `NO_SABER`, `SÍ`, `TENER`, `VIDEO`
- **Aclaraciones necesarias**:
  - Admite respuesta cerrada y detalle: el detalle solo se pide si la persona lo elige, no por omisión.
- **Transiciones**: `CABELLO`, `CONOCIMIENTO_PERSONA`, `HORA_HECHO`, `OBJETO_PERSONA`, `PRESENCIA_OTROS`, `RELATO_ABIERTO`, `RELATO_ORDENADO`, `SEXO_DESCRIPCION`, `SIN_INTENCION`, `TIEMPO_APROX`
- **Perfiles que la priorizan**: ninguno
- **Finaliza cuando**: Todos los campos requeridos tienen valor, o la persona elige finalizar. Un campo sin responder no equivale a una negación.
- **Enunciados de entrada**:
  - ¿Hay cámaras o video del lugar?
