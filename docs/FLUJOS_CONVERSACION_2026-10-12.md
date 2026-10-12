# Flujos reales del módulo Conversación

Qué escribe el funcionario en la caja de texto, qué glosas hace el avatar, qué tarjetas toca la persona sorda y qué texto vuelve al chat. Cada flujo salió de jugar la app real en una prueba automatizada, no de un guion escrito a mano.

## Cómo se obtuvieron

- Prueba: `test/qa_conversacion_test.dart`, con los 35 guiones de `test/qa/guiones_conversacion.json`. Resultado: **35 de 35 conversaciones pasan** (2026-10-12).
- La traducción del funcionario a glosas es la **respuesta real de la Lambda Texto→LSB desplegada**, grabada en `test/qa/lambda_respuestas.json` (capturas del 8 y 9 de octubre). Con la Lambda nueva desplegada, algunas palabras deletreadas pasarán a tener seña.
- Las tarjetas y el texto de la persona sorda salen del banco de preguntas y del redactor local de la app (el mismo que valida la Lambda).
- 4 consultas de ruteo no estaban grabadas (C13 y una de C07); ahí la app usó su ruteo local, como hace sin conexión.
- Para repetirlo:

  ```bash
  REPORTE_QA=reporte.json flutter test test/qa_conversacion_test.dart \
    --dart-define=LSB_API_URL=https://api.qa.invalid/translate \
    --dart-define=LSB_TEXT_API_URL=https://texto.qa.invalid/translate
  ```

## Cómo leer cada turno

- **Caja de texto (funcionario):** lo que escribe o dicta el oyente.
- **Glosas del avatar:** lo que el avatar señala. «deletreo P-A-S-A-R» es una palabra sin seña que se hace letra por letra.
- **Se abre:** el caso de las tarjetas que la app abre para responder, y la pregunta que muestra.
- **Tarjetas que toca la persona sorda:** cada tarjeta con sus glosas entre corchetes.
- **Vuelve al chat:** el texto que aparece como respuesta de la persona sorda y que se escucha en voz alta.

## Índice

- **Denuncias:** [C01](#c01) Denuncia de robo en ventanilla, de principio a fin, [C02](#c02) Violencia de pareja: seguridad primero, [C23](#c23) La persona sorda abre el turno y el funcionario sigue, [C26](#c26) Saludo de la tarde y de la noche (no es «buenos días»), [C27](#c27) «¿Cuándo y a qué hora?»: dos datos, dos preguntas, [C15](#c15) Cambio de tema a mitad de la conversación, [C16](#c16) Lenguaje coloquial y errores de tipeo, [C17](#c17) Varias preguntas a la vez, [C14](#c14) Negaciones y presuposiciones, [C07](#c07) Acoso sexual en el trabajo (escenario nuevo), [C28](#c28) Acoso sexual en la FELCV: sin datos inventados y sin «Entendido» suelto, [C32](#c32) Acoso sexual sin decir «denunciar»: quién es y con quién habló, [C29](#c29) Acoso físico: «¿Conoce a esa persona?» no agrega dónde vive, [C08](#c08) Ciberacoso por celular (escenario nuevo), [C33](#c33) Fotos publicadas sin permiso: «No» dice que no publicaron nada, [C09](#c09) Bullying en la escuela (escenario nuevo), [C34](#c34) Bullying: «¿Usted o su hijo…?» pregunta por el bullying, no por heridas, [C10](#c10) Trata y tráfico: familiar desaparecida (escenario nuevo), [C11](#c11) Estafa por transferencia, [C21](#c21) Testigo de un hecho (contexto «otro»), [C25](#c25) Robo de celular en FELCC: pruebas y seguimiento, [C30](#c30) Testigos de un robo: si los conoce, su nombre y su celular; cámaras y a dónde ir
- **Consultas:** [C18](#c18) Seguimiento de una denuncia anterior, [C31](#c31) Seguimiento: quién investiga el caso y quién es su fiscal (sí o no), [C04](#c04) Accesibilidad: intérprete y lectura, [C19](#c19) Oficina equivocada: derivar a FELCV, [C35](#c35) Sin conversación previa: cámaras y a dónde ir (Derivación), [C13](#c13) Preguntas sueltas sin contexto (ambiguas), [C12](#c12) Charla de ventanilla que no es trámite (no debe abrir nada raro), [C24](#c24) Instrucciones del funcionario (no son preguntas), [C20](#c20) Entrada en otro idioma o sin sentido (control de calidad)
- **Trámites:** [C05](#c05) Trámite SEGIP: cédula perdida, [C06](#c06) Certificado de nacimiento en SERECI, [C22](#c22) Acoso discriminatorio en una oficina pública, [C03](#c03) Datos personales en medio de una denuncia (cambio de tema explícito)

## Denuncias

La persona sorda denuncia un hecho: robo, violencia, acoso, ciberacoso, bullying, trata, estafa.

### C01

**Denuncia de robo en ventanilla, de principio a fin**

**Turno 1**

- Caja de texto (funcionario): «Buenos días, ¿en qué le puedo ayudar?»
- Glosas del avatar: BUENOS_DIAS · AYUDAR · PUEDO
- Se abre: el selector de casos; la persona sorda elige «Denunciar robo»
- Tarjeta: «Me robaron» [ROBAR] — responde a «¿Qué ocurrió?»
- Vuelve al chat: «Me robaron algo.»
  - glosas de la respuesta: ROBAR

**Turno 2**

- Caja de texto (funcionario): «¿Qué le robaron?»
- Glosas del avatar: ROBAR · QUE
- Se abre: «Denunciar robo», pregunta «¿Qué le robaron?»
  - también: «¿Qué papel es?»
- Tarjeta: «Celular» [CELULAR] — responde a «¿Qué le robaron?»
- Vuelve al chat: «Me robaron el celular.»
  - glosas de la respuesta: CELULAR

**Turno 3**

- Caja de texto (funcionario): «¿Cuándo pasó?»
- Glosas del avatar: CUANDO · deletreo P-A-S-A-R
- Se abre: «Denunciar robo», pregunta «¿Cuándo ocurrió?»
- Tarjeta: «Ahora mismo» [AHORA] — responde a «¿Cuándo ocurrió?»
- Vuelve al chat: «Ocurrió hace un momento.»
  - glosas de la respuesta: AHORA

**Turno 4**

- Caja de texto (funcionario): «¿Y dónde fue?»
- Glosas del avatar: DONDE · deletreo F-U-E
- Se abre: «Denunciar robo», pregunta «¿Dónde ocurrió?»
- Tarjeta: «En la calle» [CALLE] — responde a «¿Dónde ocurrió?»
- Vuelve al chat: «Ocurrió en la calle.»
  - glosas de la respuesta: CALLE

**Turno 5**

- Caja de texto (funcionario): «¿Conoce a la persona que le robó?»
- Glosas del avatar: CONOCER · deletreo P-E-R-S-O-N-A · ROBAR · TU
- Se abre: «Denunciar robo», pregunta «¿Conoce a la persona involucrada?»
- Tarjeta: «Sí» [SÍ] — responde a «¿Conoce a la persona involucrada?»
- Vuelve al chat: «Sí, conozco a esa persona.»
  - glosas de la respuesta: SÍ

**Turno 6**

- Caja de texto (funcionario): «¿Me puede describir a esa persona? ¿Cómo era?»
- Glosas del avatar: deletreo P-E-R-S-O-N-A · deletreo D-E-S-C-R-I-B-I-R · COMO_ESTAS
- Se abre: «Denunciar robo», pregunta «¿Era un hombre o una mujer?»
  - también: «¿Qué edad aproximada tenía?»
  - también: «¿Era alto o bajo?»
  - también: «¿Era delgado o de contextura gruesa?»
  - también: «¿Qué ropa llevaba?»
  - también: «¿De qué color era la polera?»
  - también: «¿De qué color era el pantalón?»
  - también: «¿De qué color era la chamarra?»
  - también: «¿De qué color era la gorra?»
  - también: «¿De qué color era la mochila?»
  - también: «¿De qué color era su ropa?»
- Tarjeta: «Un hombre» [HOMBRE] — responde a «¿Era un hombre o una mujer?»
- Tarjeta: «Era joven» [JOVEN] — responde a «¿Qué edad aproximada tenía?»
- Tarjeta: «Alta» [ALTO] — responde a «¿Era alto o bajo?»
- Tarjeta: «Delgada» [FLACO] — responde a «¿Era delgado o de contextura gruesa?»
- Tarjeta: «Polera» [POLERA] — responde a «¿Qué ropa llevaba?»
- Tarjeta: «Negro» [NEGRO] — responde a «¿De qué color era la polera?»
- Vuelve al chat: «Era un hombre. Era una persona joven. Era una persona alta. Era una persona delgada. Llevaba una polera. La polera era de color negro.»
  - glosas de la respuesta: HOMBRE · JOVEN · ALTO · FLACO · POLERA · NEGRO

**Turno 7**

- Caja de texto (funcionario): «¿Qué ropa llevaba puesta?»
- Glosas del avatar: deletreo R-O-P-A · LLEVAR · deletreo P-U-E-S-T-A
- Se abre: «Denunciar robo», pregunta «¿Qué ropa llevaba?»
  - también: «¿De qué color era la polera?»
  - también: «¿De qué color era el pantalón?»
  - también: «¿De qué color era la chamarra?»
  - también: «¿De qué color era la gorra?»
  - también: «¿De qué color era la mochila?»
  - también: «¿De qué color era su ropa?»
- Tarjeta: «Polera» [POLERA] — responde a «¿Qué ropa llevaba?»
- Tarjeta: «Negro» [NEGRO] — responde a «¿De qué color era la polera?»
- Vuelve al chat: «Llevaba una polera. La polera era de color negro.»
  - glosas de la respuesta: POLERA · NEGRO

**Turno 8**

- Caja de texto (funcionario): «¿Alguien vio lo que pasó?»
- Glosas del avatar: deletreo P-A-S-A-R · VER · QUIEN
- Se abre: «Denunciar robo», pregunta «¿Hay testigos?»
- Tarjeta: «Sí» [SÍ] — responde a «¿Hay testigos?»
- Vuelve al chat: «Sí, hay testigos.»
  - glosas de la respuesta: SÍ

**Turno 9**

- Caja de texto (funcionario): «¿Tiene la factura o la caja del celular?»
- Glosas del avatar: CELULAR · FACTURA · CAJA · TENER
- Se abre: «Denunciar robo», pregunta «¿Tiene la factura?»
- Tarjeta: «Sí» [SÍ] — responde a «¿Tiene la factura?»
- Vuelve al chat: «Sí, tengo la factura.»
  - glosas de la respuesta: SÍ

**Turno 10**

- Caja de texto (funcionario): «¿Quiere presentar la denuncia formal?»
- Glosas del avatar: PRESENTAR · deletreo D-E-N-U-N-C-I-A · deletreo F-O-R-M-A-L · QUERER
- Se abre: «Denunciar robo», pregunta «¿Desea presentar estos elementos?»
- Tarjeta: «Sí» [SÍ] — responde a «¿Desea presentar estos elementos?»
- Vuelve al chat: «Sí, quiero presentar estos elementos.»
  - glosas de la respuesta: SÍ

### C02

**Violencia de pareja: seguridad primero**

**Turno 1**

- Caja de texto (funcionario): «Hola, ¿qué le pasó? Cuénteme con calma.»
- Glosas del avatar: HOLA · deletreo C-U-E-N-T-A-M-E · deletreo C-A-L-M-A
- Se abre: el selector de casos; la persona sorda elige «Denunciar violencia»
- Tarjeta: «Me pegaron» [PEGAR] — responde a «¿Qué le hicieron?»
- Vuelve al chat: «Me pegaron.»
  - glosas de la respuesta: PEGAR

**Turno 2**

- Caja de texto (funcionario): «¿Está en peligro ahora mismo?»
- Glosas del avatar: AHORA · deletreo P-E-L-I-G-R-O · deletreo E-S-T-A-R
- Se abre: «Denunciar violencia», pregunta «¿Necesita auxilio ahora?»
- Tarjeta: «Sí» [SÍ] — responde a «¿Necesita auxilio ahora?»
- Vuelve al chat: «Sí, necesito auxilio ahora.»
  - glosas de la respuesta: SÍ

**Turno 3**

- Caja de texto (funcionario): «¿Quién le hizo esto?»
- Glosas del avatar: PEGAR · QUIEN
- Se abre: «Denunciar violencia», pregunta «¿Quién le agredió?»
- Tarjeta: «Alguien que conozco» [CONOCER] — responde a «¿Quién le agredió?»
- Vuelve al chat: «Fue alguien que conozco.»
  - glosas de la respuesta: CONOCER

**Turno 4**

- Caja de texto (funcionario): «¿Está herida? ¿Le duele algo?»
- Glosas del avatar: HERIDA · DOLOR
- Se abre: «Denunciar violencia», pregunta «¿Está herido?»
  - también: «¿Qué le hicieron?»
- Tarjeta: «Me pegaron» [PEGAR] — responde a «¿Qué le hicieron?»
- Vuelve al chat: «Me pegaron.»
  - glosas de la respuesta: PEGAR

**Turno 5**

- Caja de texto (funcionario): «¿Esto ya le pasó antes?»
- Glosas del avatar: deletreo A-N-T-E-S · deletreo P-A-S-A-R-Y-A · TU
- Se abre: «Denunciar violencia», pregunta «¿Es la primera vez o pasa seguido?»
- Tarjeta: «Es la primera vez» [PRIMERA_VEZ] — responde a «¿Es la primera vez o pasa seguido?»
- Vuelve al chat: «Es la primera vez.»
  - glosas de la respuesta: PRIMERA_VEZ

**Turno 6**

- Caja de texto (funcionario): «¿Tiene miedo de volver a su casa?»
- Glosas del avatar: deletreo C-A-S-O · MIEDO · VOLVER · CASA · NO
- Se abre: «Denunciar violencia», pregunta «¿Tiene miedo de volver a su casa?»
- Tarjeta: «Sí» [SÍ] — responde a «¿Tiene miedo de volver a su casa?»
- Vuelve al chat: «Sí, tengo miedo de volver a mi casa.»
  - glosas de la respuesta: SÍ

**Turno 7**

- Caja de texto (funcionario): «¿Necesita que la llevemos al médico?»
- Glosas del avatar: NECESITAR · deletreo M-E-D-I-C-O · LLEVAR
- Se abre: «Denunciar violencia», pregunta «¿Necesita asistencia médica?»
  - también: «¿Qué le hicieron?»
  - también: «¿Está herido?»
- Tarjeta: «Me pegaron» [PEGAR] — responde a «¿Qué le hicieron?»
- Tarjeta: «Sí» [SÍ] — responde a «¿Está herido?»
- Vuelve al chat: «Me pegaron. Sí, estoy herido.»
  - glosas de la respuesta: PEGAR · SÍ

### C23

**La persona sorda abre el turno y el funcionario sigue**

**Turno 1 — empieza la persona sorda**

- Toca «Tarjetas LSB» y elige el caso «Denunciar robo».
- Tarjeta: «Me robaron» [ROBAR] — responde a «¿Qué ocurrió?»
- Vuelve al chat: «Me robaron algo.»

**Turno 2**

- Caja de texto (funcionario): «Entiendo. ¿Qué le robaron exactamente?»
- Glosas del avatar: ROBAR · QUE
- Se abre: «Denunciar robo», pregunta «¿Qué le robaron?»
  - también: «¿Qué papel es?»
- Tarjeta: «Celular» [CELULAR] — responde a «¿Qué le robaron?»
- Vuelve al chat: «Me robaron el celular.»
  - glosas de la respuesta: CELULAR

**Turno 3**

- Caja de texto (funcionario): «¿Fue con violencia?»
- Glosas del avatar: VIOLENCIA · deletreo C-O-N
- Se abre: «Denunciar violencia», pregunta «¿Qué le hicieron?»
- Tarjeta: «Me pegaron» [PEGAR] — responde a «¿Qué le hicieron?»
- Vuelve al chat: «Me pegaron.»
  - glosas de la respuesta: PEGAR

### C26

**Saludo de la tarde y de la noche (no es «buenos días»)**

**Turno 1**

- Caja de texto (funcionario): «Buenas tardes, ¿en qué le puedo ayudar?»
- Glosas del avatar: BUENAS_TARDES · PUEDO · AYUDAR
- Se abre: el selector de casos; la persona sorda elige «Denunciar robo»
- Tarjeta: «Me robaron» [ROBAR] — responde a «¿Qué ocurrió?»
- Vuelve al chat: «Me robaron algo.»
  - glosas de la respuesta: ROBAR

**Turno 2**

- Caja de texto (funcionario): «Buenas noches. ¿Qué le robaron?»
- Glosas del avatar: BUENAS_NOCHES · ROBAR · QUE
- Se abre: «Denunciar robo», pregunta «¿Qué le robaron?»
  - también: «¿Qué papel es?»
- Tarjeta: «Celular» [CELULAR] — responde a «¿Qué le robaron?»
- Vuelve al chat: «Me robaron el celular.»
  - glosas de la respuesta: CELULAR

### C27

**«¿Cuándo y a qué hora?»: dos datos, dos preguntas**

**Turno 1**

- Caja de texto (funcionario): «¿Quiere denunciar un robo?»
- Glosas del avatar: ROBAR · deletreo D-E-N-U-N-C-I-A-R · QUE
- Se abre: «Denunciar robo», pregunta «¿Qué ocurrió?»
- Tarjeta: «Me robaron» [ROBAR] — responde a «¿Qué ocurrió?»
- Vuelve al chat: «Me robaron algo.»
  - glosas de la respuesta: ROBAR

**Turno 2**

- Caja de texto (funcionario): «¿Cuándo y a qué hora pasó?»
- Glosas del avatar: CUANDO · HORA · deletreo P-A-S-A-R
- Se abre: «Denunciar robo», pregunta «¿Cuándo ocurrió?»
  - también: «¿A qué hora aproximadamente?»
- Tarjeta: «Ahora mismo» [AHORA] — responde a «¿Cuándo ocurrió?»
- Tarjeta: «Por la tarde» [TARDE] — responde a «¿A qué hora aproximadamente?»
- Vuelve al chat: «Ocurrió hace un momento. Fue por la tarde.»
  - glosas de la respuesta: TARDE · AHORA

### C15

**Cambio de tema a mitad de la conversación**

**Turno 1**

- Caja de texto (funcionario): «¿Qué le robaron?»
- Glosas del avatar: ROBAR · QUE
- Se abre: «Denunciar robo», pregunta «¿Qué le robaron?»
  - también: «¿Qué papel es?»
- Tarjeta: «Celular» [CELULAR] — responde a «¿Qué le robaron?»
- Vuelve al chat: «Me robaron el celular.»
  - glosas de la respuesta: CELULAR

**Turno 2**

- Caja de texto (funcionario): «¿También le golpearon?»
- Glosas del avatar: PEGAR · TU · deletreo T-A-M-B-I-E-N
- Se abre: «Denunciar violencia», pregunta «¿Qué le hicieron?»
- Tarjeta: «Me pegaron» [PEGAR] — responde a «¿Qué le hicieron?»
- Vuelve al chat: «Me pegaron.»
  - glosas de la respuesta: PEGAR

**Turno 3**

- Caja de texto (funcionario): «¿Necesita atención médica?»
- Glosas del avatar: deletreo A-T-E-N-C-I-O-N · deletreo M-E-D-I-C-A · NECESITAR
- Se abre: «Denunciar violencia», pregunta «¿Necesita asistencia médica?»
  - también: «¿Qué le hicieron?»
  - también: «¿Está herido?»
- Tarjeta: «Me pegaron» [PEGAR] — responde a «¿Qué le hicieron?»
- Tarjeta: «Sí» [SÍ] — responde a «¿Está herido?»
- Vuelve al chat: «Me pegaron. Sí, estoy herido.»
  - glosas de la respuesta: PEGAR · SÍ

### C16

**Lenguaje coloquial y errores de tipeo**

**Turno 1**

- Caja de texto (funcionario): «¿Qué le chorearon?»
- Glosas del avatar: ROBAR · QUIEN
- Se abre: «Denunciar robo», pregunta «¿Qué le robaron?»
  - también: «¿Qué papel es?»
- Tarjeta: «Celular» [CELULAR] — responde a «¿Qué le robaron?»
- Vuelve al chat: «Me robaron el celular.»
  - glosas de la respuesta: CELULAR

**Turno 2**

- Caja de texto (funcionario): «dnde paso eso»
- Glosas del avatar: DONDE · deletreo P-A-S-A-R
- Se abre: «Denunciar robo», pregunta «¿Dónde ocurrió?»
- Tarjeta: «En la calle» [CALLE] — responde a «¿Dónde ocurrió?»
- Vuelve al chat: «Ocurrió en la calle.»
  - glosas de la respuesta: CALLE

**Turno 3**

- Caja de texto (funcionario): «¿a q hora fue?»
- Glosas del avatar: HORA · deletreo F-U-E
- Se abre: «Denunciar robo», pregunta «¿A qué hora aproximadamente?»
- Tarjeta: «Por la tarde» [TARDE] — responde a «¿A qué hora aproximadamente?»
- Vuelve al chat: «Fue por la tarde.»
  - glosas de la respuesta: TARDE

### C17

**Varias preguntas a la vez**

**Turno 1**

- Caja de texto (funcionario): «¿Cuándo, dónde y a qué hora le robaron?»
- Glosas del avatar: ROBAR · CUANDO · DONDE · HORA · QUE
- Se abre: «Denunciar robo», pregunta «¿Cuándo ocurrió?»
  - también: «¿Dónde ocurrió?»
  - también: «¿A qué hora aproximadamente?»
- Tarjeta: «Ahora mismo» [AHORA] — responde a «¿Cuándo ocurrió?»
- Tarjeta: «En la calle» [CALLE] — responde a «¿Dónde ocurrió?»
- Tarjeta: «Por la tarde» [TARDE] — responde a «¿A qué hora aproximadamente?»
- Vuelve al chat: «Ocurrió hace un momento. Ocurrió en la calle. Fue por la tarde.»
  - glosas de la respuesta: TARDE · AHORA · CALLE

**Turno 2**

- Caja de texto (funcionario): «¿Cómo se llama y cuántos años tiene?»
- Glosas del avatar: COMO · LLAMAR · CUANTOS · AÑO · TENER
- Se abre: «Mis datos», pregunta «¿Cuál es su nombre completo?»
  - también: «¿Qué edad tiene?»
- Vuelve al chat: la persona sorda tiene que escribir el dato en la tarjeta (nombre, número, monto…); la prueba no lo escribe.

### C14

**Negaciones y presuposiciones**

**Turno 1**

- Caja de texto (funcionario): «No le pregunto por el robo, le pregunto por su cédula. ¿La trae?»
- Glosas del avatar: deletreo S-U · deletreo C-E-D-U-L-A · TRAER · deletreo P-R-E-G-U-N-T-A-R
- Se abre: «Mis datos», pregunta «¿Tiene su carnet de identidad?»
- Tarjeta: «Sí» [SÍ] — responde a «¿Tiene su carnet de identidad?»
- Vuelve al chat: «Sí, tengo mi carnet de identidad.»
  - glosas de la respuesta: SÍ

**Turno 2**

- Caja de texto (funcionario): «¿Su pareja le pegó ayer?»
- Glosas del avatar: AYER · PAREJA · PEGAR · TU
- Se abre: «Denunciar violencia», pregunta «¿Qué le hicieron?»
- Tarjeta: «Me pegaron» [PEGAR] — responde a «¿Qué le hicieron?»
- Vuelve al chat: «Me pegaron.»
  - glosas de la respuesta: PEGAR

**Turno 3**

- Caja de texto (funcionario): «¿No sabe quién fue?»
- Glosas del avatar: QUIEN · deletreo F-U-E · NO_SABER
- Se abre: «Denunciar violencia», pregunta «¿Quién le agredió?»
- Tarjeta: «Alguien que conozco» [CONOCER] — responde a «¿Quién le agredió?»
- Vuelve al chat: «Fue alguien que conozco.»
  - glosas de la respuesta: CONOCER

### C07

**Acoso sexual en el trabajo (escenario nuevo)**

**Turno 1**

- Caja de texto (funcionario): «¿Quiere denunciar acoso sexual?»
- Glosas del avatar: QUERER · deletreo D-E-N-U-N-C-I-A-R · ACOSO · deletreo S-E-X-U-A-L
- Se abre: «Denunciar acoso sexual (Policía Boliviana – FELCV)», pregunta «¿La acosaron sexualmente?»
- Tarjeta: «Sí» [SÍ] — responde a «¿La acosaron sexualmente?»
- Vuelve al chat: «Sí, me acosaron sexualmente.»
  - glosas de la respuesta: SÍ

**Turno 2**

- Caja de texto (funcionario): «¿Conoce a la persona que la acosa?»
- Glosas del avatar: CONOCER · deletreo P-E-R-S-O-N-A · deletreo A-C-O-S-A · QUIEN
- Se abre: «Denunciar acoso sexual (Policía Boliviana – FELCV)», pregunta «¿Conoce a la persona que la acosa?»
  - también: «¿Quién es esa persona?»
- Tarjeta: «Sí» [SÍ] — responde a «¿Conoce a la persona que la acosa?»
- Tarjeta: «Jefe» [JEFE] — responde a «¿Quién es esa persona?»
- Vuelve al chat: «Sí, conozco a esa persona. Mi jefe.»
  - glosas de la respuesta: SÍ · JEFE

**Turno 3**

- Caja de texto (funcionario): «¿Esa persona la tocó sin su permiso?»
- Glosas del avatar: deletreo P-E-R-S-O-N-A · deletreo T-O-C-A-R · PERMISO · NO
- Se abre: «Denunciar acoso sexual (Policía Boliviana – FELCV)», pregunta «¿Esa persona la tocó sin su permiso?»
- Tarjeta: «Sí» [SÍ] — responde a «¿Esa persona la tocó sin su permiso?»
- Vuelve al chat: «Sí, me tocó sin mi permiso.»
  - glosas de la respuesta: SÍ

**Turno 4**

- Caja de texto (funcionario): «¿Tiene testigos?»
- Glosas del avatar: TESTIGO · TENER · QUIEN
- Se abre: «Denunciar acoso sexual (Policía Boliviana – FELCV)», pregunta «¿Tiene testigos?»
- Tarjeta: «Sí» [SÍ] — responde a «¿Tiene testigos?»
- Vuelve al chat: «Sí, hay testigos.»
  - glosas de la respuesta: SÍ

### C28

**Acoso sexual en la FELCV: sin datos inventados y sin «Entendido» suelto**

**Turno 1**

- Caja de texto (funcionario): «¿Quiere denunciar acoso sexual?»
- Glosas del avatar: QUERER · deletreo D-E-N-U-N-C-I-A-R · ACOSO · deletreo S-E-X-U-A-L
- Se abre: «Denunciar acoso sexual (Policía Boliviana – FELCV)», pregunta «¿La acosaron sexualmente?»
- Tarjeta: «Sí» [SÍ] — responde a «¿La acosaron sexualmente?»
- Vuelve al chat: «Sí, me acosaron sexualmente.»
  - glosas de la respuesta: SÍ

**Turno 2**

- Caja de texto (funcionario): «¿Conoce a la persona que la acosa?»
- Glosas del avatar: CONOCER · deletreo P-E-R-S-O-N-A · deletreo A-C-O-S-A · QUIEN
- Se abre: «Denunciar acoso sexual (Policía Boliviana – FELCV)», pregunta «¿Conoce a la persona que la acosa?»
  - también: «¿Quién es esa persona?»
- Tarjeta: «Sí» [SÍ] — responde a «¿Conoce a la persona que la acosa?»
- Tarjeta: «Compañera» [COMPAÑERO] — responde a «¿Quién es esa persona?»
- Vuelve al chat: «Sí, conozco a esa persona. Compañera.»
  - glosas de la respuesta: SÍ · COMPAÑERO

**Turno 3**

- Caja de texto (funcionario): «La FELCV es la unidad especializada contra la violencia.»
- Glosas del avatar: FELCV · deletreo U-N-I-D-A-D · deletreo E-S-P-E-C-I-A-L-I-Z-A-D-A · deletreo C-O-N-T-R-A · VIOLENCIA
- Se abre: «Denunciar acoso sexual (Policía Boliviana – FELCV)», pregunta «La FELCV es la unidad especializada contra la violencia.»
- Tarjeta: «Entendido» [COMPRENDER] — responde a «La FELCV es la unidad especializada contra la violencia.»
- Vuelve al chat: «Entendido.»
  - glosas de la respuesta: COMPRENDER

### C32

**Acoso sexual sin decir «denunciar»: quién es y con quién habló**

**Turno 1**

- Caja de texto (funcionario): «¿La acosaron sexualmente?»
- Glosas del avatar: deletreo A-C-O-S-A-R · deletreo S-E-X-U-A-L-M-E-N-T-E · ELLA · NO
- Se abre: «Denunciar acoso sexual (Policía Boliviana – FELCV)», pregunta «¿La acosaron sexualmente?»
- Tarjeta: «Sí» [SÍ] — responde a «¿La acosaron sexualmente?»
- Vuelve al chat: «Sí, me acosaron sexualmente.»
  - glosas de la respuesta: SÍ

**Turno 2**

- Caja de texto (funcionario): «¿Conoce a la persona que lo acosa?»
- Glosas del avatar: CONOCER · deletreo P-E-R-S-O-N-A · deletreo A-C-O-S-A · TU
- Se abre: «Denunciar acoso sexual (Policía Boliviana – FELCV)», pregunta «¿Conoce a la persona que la acosa?»
  - también: «¿Quién es esa persona?»
- Tarjeta: «Sí» [SÍ] — responde a «¿Conoce a la persona que la acosa?»
- Tarjeta: «Jefe» [JEFE] — responde a «¿Quién es esa persona?»
- Vuelve al chat: «Sí, conozco a esa persona. Mi jefe.»
  - glosas de la respuesta: SÍ · JEFE

**Turno 3**

- Caja de texto (funcionario): «¿Habló con alguien más sobre este acoso?»
- Glosas del avatar: HABLAR · deletreo A-L-G-U-I-E-N · deletreo M-A-S · ACOSO · deletreo E-S-T-E · deletreo S-O-B-R-E
- Se abre: «Denunciar acoso sexual (Policía Boliviana – FELCV)», pregunta «¿Habló con alguien más sobre este acoso?»
  - también: «¿Con quién habló?»
- Tarjeta: «Sí» [SÍ] — responde a «¿Habló con alguien más sobre este acoso?»
- Tarjeta: «Mamá» [MAMÁ] — responde a «¿Con quién habló?»
- Vuelve al chat: «Sí, hablé con alguien más. Mi mamá.»
  - glosas de la respuesta: SÍ · MAMÁ

### C29

**Acoso físico: «¿Conoce a esa persona?» no agrega dónde vive**

**Turno 1**

- Caja de texto (funcionario): «¿Viene a denunciar acoso físico?»
- Glosas del avatar: deletreo V-I-E-N-I-R · deletreo D-E-N-U-N-C-I-A-R · ACOSO · deletreo F-I-S-I-C-O
- Se abre: el selector de casos; la persona sorda elige «Acoso físico: una persona me sigue y me toca (Policía Boliviana – FELCC)»
- Tarjeta: «Sí» [SÍ] — responde a «¿Conoce a esa persona?»
- Tarjeta: «Compañera» [COMPAÑERO] — responde a «¿Quién es esa persona?»
- Vuelve al chat: «Sí, conozco a esa persona. Compañera.»
  - glosas de la respuesta: SÍ · COMPAÑERO

**Turno 2**

- Caja de texto (funcionario): «¿Conoce a esa persona?»
- Glosas del avatar: CONOCER · deletreo P-E-R-S-O-N-A
- Se abre: «Acoso físico: una persona me sigue y me toca (Policía Boliviana – FELCC)», pregunta «¿Conoce a esa persona?»
  - también: «¿Quién es esa persona?»
- Tarjeta: «Sí» [SÍ] — responde a «¿Conoce a esa persona?»
- Tarjeta: «Compañera» [COMPAÑERO] — responde a «¿Quién es esa persona?»
- Vuelve al chat: «Sí, conozco a esa persona. Compañera.»
  - glosas de la respuesta: SÍ · COMPAÑERO

**Turno 3**

- Caja de texto (funcionario): «Para la violencia de pareja corresponde la FELCV.»
- Glosas del avatar: PAREJA · VIOLENCIA · FELCV
- Se abre: «Acoso físico: una persona me sigue y me toca (Policía Boliviana – FELCC)», pregunta «Para la violencia de pareja corresponde la FELCV.»
- Tarjeta: «Entendido» [COMPRENDER] — responde a «Para la violencia de pareja corresponde la FELCV.»
- Vuelve al chat: «Entendido.»
  - glosas de la respuesta: COMPRENDER

### C08

**Ciberacoso por celular (escenario nuevo)**

**Turno 1**

- Caja de texto (funcionario): «¿Le están amenazando por internet?»
- Glosas del avatar: INTERNET · AMENAZAR · QUIEN
- Se abre: «Amenazas digitales», pregunta «¿Qué decían los mensajes?»
- Tarjeta: «Me amenazaban» [AMENAZAR] — responde a «¿Qué decían los mensajes?»
- Vuelve al chat: «Recibí mensajes con amenazas.»
  - glosas de la respuesta: AMENAZAR

**Turno 2**

- Caja de texto (funcionario): «¿Publicaron sus fotos sin su permiso?»
- Glosas del avatar: FOTOS · deletreo P-U-B-L-I-C-A-R · PERMISO · NO · SUYO
- Se abre: «Amenazas digitales», pregunta «¿Publicaron sus fotos sin su permiso?»
- Tarjeta: «Sí» [SÍ] — responde a «¿Publicaron sus fotos sin su permiso?»
- Vuelve al chat: «Sí, publicaron mis fotos sin mi permiso.»
  - glosas de la respuesta: SÍ

**Turno 3**

- Caja de texto (funcionario): «¿Guardó los mensajes?»
- Glosas del avatar: deletreo M-E-N-S-A-J-E · GUARDAR
- Se abre: «Amenazas digitales», pregunta «¿Guardó los mensajes?»
- Tarjeta: «Sí» [SÍ] — responde a «¿Guardó los mensajes?»
- Vuelve al chat: «Sí, guardé los mensajes.»
  - glosas de la respuesta: SÍ

### C33

**Fotos publicadas sin permiso: «No» dice que no publicaron nada**

**Turno 1**

- Caja de texto (funcionario): «¿Le están amenazando por internet?»
- Glosas del avatar: INTERNET · AMENAZAR · QUIEN
- Se abre: «Amenazas digitales», pregunta «¿Qué decían los mensajes?»
- Tarjeta: «Me amenazaban» [AMENAZAR] — responde a «¿Qué decían los mensajes?»
- Vuelve al chat: «Recibí mensajes con amenazas.»
  - glosas de la respuesta: AMENAZAR

**Turno 2**

- Caja de texto (funcionario): «¿Publicaron fotos suyas sin su permiso?»
- Glosas del avatar: FOTOS · SUYO · deletreo P-U-B-L-I-C-A-R · PERMISO · NO
- Se abre: «Amenazas digitales», pregunta «¿Publicaron sus fotos sin su permiso?»
- Tarjeta: «No» [NO] — responde a «¿Publicaron sus fotos sin su permiso?»
- Vuelve al chat: «No, no publicaron nada.»
  - glosas de la respuesta: NO

### C09

**Bullying en la escuela (escenario nuevo)**

**Turno 1**

- Caja de texto (funcionario): «¿Su hijo sufre bullying en la escuela?»
- Glosas del avatar: YO · HIJO · ESCUELA · BULLYING · deletreo S-U · deletreo F-R-I-R
- Se abre: «Bullying en la escuela (DNA – Gobierno Autónomo Municipal de Cochabamba)», pregunta «¿Su hijo sufre bullying?»
- Tarjeta: «Sí» [SÍ] — responde a «¿Su hijo sufre bullying?»
- Vuelve al chat: «Sí, mi hijo sufre bullying.»
  - glosas de la respuesta: SÍ

**Turno 2**

- Caja de texto (funcionario): «¿Otros niños le pegan a su hijo?»
- Glosas del avatar: deletreo O-T-R-O-S · deletreo N-I-Ñ-O-S · PEGAR · deletreo S-U · HIJO · QUIEN
- Se abre: «Bullying en la escuela (DNA – Gobierno Autónomo Municipal de Cochabamba)», pregunta «¿Otros niños pegan a su hijo?»
- Tarjeta: «Sí» [SÍ] — responde a «¿Otros niños pegan a su hijo?»
- Vuelve al chat: «Sí, otros niños le pegan.»
  - glosas de la respuesta: SÍ

**Turno 3**

- Caja de texto (funcionario): «¿Habló con el maestro?»
- Glosas del avatar: HABLAR · deletreo M-A-E-S-T-R-O · deletreo C-O-N · TU
- Se abre: «Bullying en la escuela (DNA – Gobierno Autónomo Municipal de Cochabamba)», pregunta «¿Habló con el maestro de la escuela?»
- Tarjeta: «Sí» [SÍ] — responde a «¿Habló con el maestro de la escuela?»
- Vuelve al chat: «Sí, hablé con el maestro.»
  - glosas de la respuesta: SÍ

### C34

**Bullying: «¿Usted o su hijo…?» pregunta por el bullying, no por heridas**

**Turno 1**

- Caja de texto (funcionario): «¿Usted o su hijo sufre bullying?»
- Glosas del avatar: deletreo U-S-T-E-D · HIJO · BULLYING · deletreo S-U · deletreo F-R-I-R
- Se abre: «Bullying en la escuela (DNA – Gobierno Autónomo Municipal de Cochabamba)», pregunta «¿Su hijo sufre bullying?»
- Tarjeta: «Sí» [SÍ] — responde a «¿Su hijo sufre bullying?»
- Vuelve al chat: «Sí, mi hijo sufre bullying.»
  - glosas de la respuesta: SÍ

**Turno 2**

- Caja de texto (funcionario): «¿Su hijo tiene heridas o dolor?»
- Glosas del avatar: HIJO · HERIDA · DOLOR · TENER · NO
- Se abre: «Bullying en la escuela (DNA – Gobierno Autónomo Municipal de Cochabamba)», pregunta «¿Su hijo tiene heridas o dolor?»
- Tarjeta: «Sí» [SÍ] — responde a «¿Su hijo tiene heridas o dolor?»
- Vuelve al chat: «Sí, mi hijo tiene dolor.»
  - glosas de la respuesta: SÍ

### C10

**Trata y tráfico: familiar desaparecida (escenario nuevo)**

**Turno 1**

- Caja de texto (funcionario): «¿Quiere denunciar trata y tráfico de personas?»
- Glosas del avatar: QUERER · deletreo D-E-N-U-N-C-I-A-R · deletreo T-R-A-T-A · deletreo T-R-A-F-I-C-O · deletreo P-E-R-S-O-N-A
- Se abre: el selector de casos; la persona sorda elige «Denunciar trata y tráfico de personas (Policía Boliviana – FELCC)»
- Tarjeta: «Sí» [SÍ] — responde a «¿La persona es su familiar?»
- Vuelve al chat: «Sí.»
  - glosas de la respuesta: SÍ

**Turno 2**

- Caja de texto (funcionario): «¿La persona desapareció?»
- Glosas del avatar: deletreo P-E-R-S-O-N-A · deletreo D-E-S-A-P-A-R-E-C-E-R
- Se abre: «Denunciar trata y tráfico de personas (Policía Boliviana – FELCC)», pregunta «¿La persona desapareció?»
- Tarjeta: «Sí» [SÍ] — responde a «¿La persona desapareció?»
- Vuelve al chat: «Sí, desapareció y no volvió.»
  - glosas de la respuesta: SÍ

**Turno 3**

- Caja de texto (funcionario): «¿Tiene una foto de ella?»
- Glosas del avatar: ELLA · FOTOS · TENER
- Se abre: «Denunciar trata y tráfico de personas (Policía Boliviana – FELCC)», pregunta «¿Tiene una foto de la persona?»
- Tarjeta: «Sí» [SÍ] — responde a «¿Tiene una foto de la persona?»
- Vuelve al chat: «Sí, tengo fotos.»
  - glosas de la respuesta: SÍ

### C11

**Estafa por transferencia**

**Turno 1**

- Caja de texto (funcionario): «¿Le engañaron para que deposite dinero?»
- Glosas del avatar: deletreo D-E-P-O-S-I-T-A-R · deletreo D-I-N-E-R-O · ENGAÑAR · PARA_QUE
- Se abre: «Engaño con dinero», pregunta «¿Quiere decir que lo engañaron?»
- Tarjeta: «Sí, me engañaron» [SÍ · ENGAÑAR] — responde a «¿Quiere decir que lo engañaron?»
- Vuelve al chat: «Me engañaron con dinero.»
  - glosas de la respuesta: SÍ · ENGAÑAR

**Turno 2**

- Caja de texto (funcionario): «¿Cuánto dinero transfirió?»
- Glosas del avatar: CUANTOS · BILLETES · deletreo T-R-A-N-S-F-E-R-I-R
- Se abre: «Engaño con dinero», pregunta «¿Cuánto dinero fue?»
- Vuelve al chat: la persona sorda tiene que escribir el dato en la tarjeta (nombre, número, monto…); la prueba no lo escribe.

**Turno 3**

- Caja de texto (funcionario): «¿Tiene el comprobante?»
- Glosas del avatar: deletreo C-O-M-P-R-O-B-A-N-T-E · TENER
- Se abre: «Engaño con dinero», pregunta «¿Tiene algún comprobante?»
- Tarjeta: «Sí» [SÍ] — responde a «¿Tiene algún comprobante?»
- Vuelve al chat: «Sí, tengo un comprobante.»
  - glosas de la respuesta: SÍ

### C21

**Testigo de un hecho (contexto «otro»)**

**Turno 1**

- Caja de texto (funcionario): «¿Usted fue testigo de lo que pasó?»
- Glosas del avatar: TESTIGO · PASADO · deletreo L-O · deletreo F-U-E · deletreo U-S-T-E-D
- Se abre: «Declaración y testimonio», pregunta «¿Qué vio o qué quiere declarar?»
- Tarjeta: «Vi un robo» [VER · ROBAR] — responde a «¿Qué vio o qué quiere declarar?»
- Vuelve al chat: «Vi un robo.»
  - glosas de la respuesta: VER · ROBAR

**Turno 2**

- Caja de texto (funcionario): «¿Qué vio exactamente?»
- Glosas del avatar: VER · deletreo E-X-A-C-T-A-M-E-N-T-E · QUE
- Se abre: «Declaración y testimonio», pregunta «¿Qué vio o qué quiere declarar?»
- Tarjeta: «Vi un robo» [VER · ROBAR] — responde a «¿Qué vio o qué quiere declarar?»
- Vuelve al chat: «Vi un robo.»
  - glosas de la respuesta: VER · ROBAR

**Turno 3**

- Caja de texto (funcionario): «¿Podría declarar como testigo?»
- Glosas del avatar: TESTIGO · deletreo D-E-C-L-A-R-A-R · deletreo P-O-D-E-R
- Se abre: «Declaración y testimonio», pregunta «¿Puede dar testimonio de lo que vio?»
- Tarjeta: «Sí» [SÍ] — responde a «¿Puede dar testimonio de lo que vio?»
- Vuelve al chat: «Sí, puedo dar testimonio de lo que vi.»
  - glosas de la respuesta: SÍ

### C25

**Robo de celular en FELCC: pruebas y seguimiento**

**Turno 1**

- Caja de texto (funcionario): «¿Tiene la caja o la factura del celular?»
- Glosas del avatar: CELULAR · CAJA · FACTURA · TENER
- Se abre: «Robo de celular: pruebas y seguimiento (Policía Boliviana – FELCC)», pregunta «¿Tiene la caja o la factura del celular?»
- Tarjeta: «Sí» [SÍ] — responde a «¿Tiene la caja o la factura del celular?»
- Vuelve al chat: «Sí, tengo la caja del celular.»
  - glosas de la respuesta: SÍ

**Turno 2**

- Caja de texto (funcionario): «¿Hay cámaras en esa calle?»
- Glosas del avatar: CALLE · CAMARA_FOTOGRAFICA · deletreo E-S-T-A-R
- Se abre: «Robo de celular: pruebas y seguimiento (Policía Boliviana – FELCC)», pregunta «¿Hay cámaras en esa calle?»
- Tarjeta: «Sí» [SÍ] — responde a «¿Hay cámaras en esa calle?»
- Vuelve al chat: «Sí, hay cámaras en esa calle.»
  - glosas de la respuesta: SÍ

**Turno 3**

- Caja de texto (funcionario): «¿Quiere saber quién investigará el robo?»
- Glosas del avatar: INVESTIGACION · ROBAR · QUIEN · SABER · QUERER
- Se abre: «Robo de celular: pruebas y seguimiento (Policía Boliviana – FELCC)», pregunta «¿Quiere saber quién investigará el robo?»
- Tarjeta: «Sí» [SÍ] — responde a «¿Quiere saber quién investigará el robo?»
- Vuelve al chat: «Sí, quiero conocer al investigador.»
  - glosas de la respuesta: SÍ

### C30

**Testigos de un robo: si los conoce, su nombre y su celular; cámaras y a dónde ir**

**Turno 1**

- Caja de texto (funcionario): «Buenos días, ¿en qué le puedo ayudar?»
- Glosas del avatar: BUENOS_DIAS · AYUDAR · PUEDO
- Se abre: el selector de casos; la persona sorda elige «Denunciar robo»
- Tarjeta: «Me robaron» [ROBAR] — responde a «¿Qué ocurrió?»
- Vuelve al chat: «Me robaron algo.»
  - glosas de la respuesta: ROBAR

**Turno 2**

- Caja de texto (funcionario): «¿Hay testigos?»
- Glosas del avatar: TESTIGO · deletreo H-A-Y
- Se abre: «Denunciar robo», pregunta «¿Hay testigos?»
- Tarjeta: «Sí» [SÍ] — responde a «¿Hay testigos?»
- Vuelve al chat: «Sí, hay testigos.»
  - glosas de la respuesta: SÍ

**Turno 3**

- Caja de texto (funcionario): «quienes son los testigos»
- Glosas del avatar: TESTIGO · QUIEN
- Se abre: «Denunciar robo», pregunta «¿Conoce a los testigos?»
  - también: «¿Cuál es el nombre del testigo?»
  - también: «¿Cuál es el número de celular del testigo?»
- Tarjeta: «Sí» [SÍ] — responde a «¿Conoce a los testigos?»
- Vuelve al chat: la persona sorda tiene que escribir el dato en la tarjeta (nombre, número, monto…); la prueba no lo escribe.

**Turno 4**

- Caja de texto (funcionario): «¿Hay cámaras en esa calle?»
- Glosas del avatar: CALLE · CAMARA_FOTOGRAFICA · deletreo E-S-T-A-R
- Se abre: «Denunciar robo», pregunta «¿Hay cámaras o video del lugar?»
- Tarjeta: «Sí» [SÍ] — responde a «¿Hay cámaras o video del lugar?»
- Vuelve al chat: «Sí, hay video del lugar.»
  - glosas de la respuesta: SÍ

**Turno 5**

- Caja de texto (funcionario): «entiende a donde tiene que ir?»
- Glosas del avatar: DONDE · IR
- Se abre: «derivacion», pregunta «¿Sabe a dónde tiene que ir?»
- Tarjeta: «No sé, dígame usted» [NO_SABER] — responde a «¿Sabe a dónde tiene que ir?»
- Vuelve al chat: «No sé a dónde tengo que ir. Dígame usted, por favor.»
  - glosas de la respuesta: NO_SABER

## Consultas

Seguimiento de un caso, accesibilidad, derivación a otra oficina y charla de ventanilla que no debe abrir tarjetas.

### C18

**Seguimiento de una denuncia anterior**

**Turno 1**

- Caja de texto (funcionario): «¿Viene a ver cómo va su denuncia?»
- Glosas del avatar: deletreo D-E-N-U-N-C-I-A · deletreo E-S-T-A-R-B-I-E-N · TU · VER · VENIR
- Se abre: «Consultar trámite», pregunta «¿Vino a consultar el estado de su caso?»
- Tarjeta: «Sí» [SÍ] — responde a «¿Vino a consultar el estado de su caso?»
- Vuelve al chat: «Sí, vine a consultar el estado de mi caso.»
  - glosas de la respuesta: SÍ

**Turno 2**

- Caja de texto (funcionario): «¿Tiene el número de su caso?»
- Glosas del avatar: deletreo C-A-S-O · deletreo N-U-M-E-R-O · TENER · TU
- Se abre: «Consultar trámite», pregunta «¿Tiene el número de referencia?»
- Tarjeta: «Sí» [SÍ] — responde a «¿Tiene el número de referencia?»
- Vuelve al chat: «Sí, tengo el número de referencia.»
  - glosas de la respuesta: SÍ

**Turno 3**

- Caja de texto (funcionario): «¿Sabe quién es su fiscal?»
- Glosas del avatar: SABER · QUIEN · deletreo S-U · deletreo F-I-S-C-A-L
- Se abre: «Consultar trámite», pregunta «¿Sabe quién es su fiscal?»
- Tarjeta: «No» [NO] — responde a «¿Sabe quién es su fiscal?»
- Vuelve al chat: «No sé quién es mi fiscal.»
  - glosas de la respuesta: NO

### C31

**Seguimiento: quién investiga el caso y quién es su fiscal (sí o no)**

**Turno 1**

- Caja de texto (funcionario): «¿Viene a ver cómo va su denuncia?»
- Glosas del avatar: deletreo D-E-N-U-N-C-I-A · deletreo E-S-T-A-R-B-I-E-N · TU · VER · VENIR
- Se abre: «Consultar trámite», pregunta «¿Vino a consultar el estado de su caso?»
- Tarjeta: «Sí» [SÍ] — responde a «¿Vino a consultar el estado de su caso?»
- Vuelve al chat: «Sí, vine a consultar el estado de mi caso.»
  - glosas de la respuesta: SÍ

**Turno 2**

- Caja de texto (funcionario): «¿Quiere saber quién investigará su caso?»
- Glosas del avatar: deletreo C-A-S-O · deletreo S-U · INVESTIGACION · QUIEN · SABER · QUERER
- Se abre: «Consultar trámite», pregunta «¿Quiere saber quién investigará su caso?»
- Tarjeta: «Sí» [SÍ] — responde a «¿Quiere saber quién investigará su caso?»
- Vuelve al chat: «Sí, quiero saber quién investigará mi caso.»
  - glosas de la respuesta: SÍ

**Turno 3**

- Caja de texto (funcionario): «sabe quien es su fiscal»
- Glosas del avatar: SABER · QUIEN · deletreo E-S · deletreo S-U · deletreo F-I-S-C-A-L
- Se abre: «Consultar trámite», pregunta «¿Sabe quién es su fiscal?»
- Tarjeta: «No» [NO] — responde a «¿Sabe quién es su fiscal?»
- Vuelve al chat: «No sé quién es mi fiscal.»
  - glosas de la respuesta: NO

### C04

**Accesibilidad: intérprete y lectura**

**Turno 1**

- Caja de texto (funcionario): «¿Necesita un intérprete de lengua de señas?»
- Glosas del avatar: NECESITAR · INTERPRETE · deletreo L-E-N-G-U-A · deletreo S-E-Ñ-A-S
- Se abre: «Mis datos», pregunta «¿Necesita un intérprete de LSB?»
  - también: «¿Necesita intérprete para esa reunión?»
- Tarjeta: «Sí» [SÍ] — responde a «¿Necesita un intérprete de LSB?»
- Tarjeta: «Sí» [SÍ] — responde a «¿Necesita intérprete para esa reunión?»
- Vuelve al chat: «Sí, necesito un intérprete de LSB. Sí, necesito intérprete para esa reunión.»
  - glosas de la respuesta: SÍ · SÍ

**Turno 2**

- Caja de texto (funcionario): «¿Puede leer lo que le escribo?»
- Glosas del avatar: LEER · ESCRIBIR · YO · TU
- Se abre: «Mis datos», pregunta «¿Puede leer este texto?»
- Tarjeta: «Sí, puedo leerlo» [SÍ] — responde a «¿Puede leer este texto?»
- Vuelve al chat: «Sí, puedo leerlo.»
  - glosas de la respuesta: SÍ

**Turno 3**

- Caja de texto (funcionario): «¿Me entiende bien?»
- Glosas del avatar: deletreo E-N-T-E-N-D-E-R · deletreo B-I-E-N · YO · SI
- Se abre: nada. Es una instrucción o charla, no una pregunta que la persona sorda deba responder con tarjetas.

### C19

**Oficina equivocada: derivar a FELCV**

**Turno 1**

- Caja de texto (funcionario): «Aquí atendemos robos. Para violencia tiene que ir a la FELCV.»
- Glosas del avatar: AQUI · ATENDER · ROBAR · VIOLENCIA · IR · FELCV
- Se abre: «Acoso físico: una persona me sigue y me toca (Policía Boliviana – FELCC)», pregunta «Para la violencia de pareja corresponde la FELCV.»
- Tarjeta: «Entendido» [COMPRENDER] — responde a «Para la violencia de pareja corresponde la FELCV.»
- Vuelve al chat: «Entendido.»
  - glosas de la respuesta: COMPRENDER

**Turno 2**

- Caja de texto (funcionario): «¿Entiende a dónde tiene que ir?»
- Glosas del avatar: IR · DONDE · NECESITAR
- Se abre: «derivacion», pregunta «¿Sabe a dónde tiene que ir?»
- Tarjeta: «La FELCV» [FELCV] — responde a «¿Sabe a dónde tiene que ir?»
- Vuelve al chat: «Tengo que ir a la FELCV.»
  - glosas de la respuesta: FELCV

### C35

**Sin conversación previa: cámaras y a dónde ir (Derivación)**

**Turno 1**

- Caja de texto (funcionario): «¿Hay cámaras en esa calle?»
- Glosas del avatar: CALLE · CAMARA_FOTOGRAFICA · deletreo E-S-T-A-R
- Se abre: «Robo de celular: pruebas y seguimiento (Policía Boliviana – FELCC)», pregunta «¿Hay cámaras en esa calle?»
- Tarjeta: «Sí» [SÍ] — responde a «¿Hay cámaras en esa calle?»
- Vuelve al chat: «Sí, hay cámaras en esa calle.»
  - glosas de la respuesta: SÍ

**Turno 2**

- Caja de texto (funcionario): «¿Entiende a dónde tiene que ir?»
- Glosas del avatar: IR · DONDE · NECESITAR
- Se abre: «derivacion», pregunta «¿Sabe a dónde tiene que ir?»
- Tarjeta: «La FELCC» [FELCC] — responde a «¿Sabe a dónde tiene que ir?»
- Vuelve al chat: «Tengo que ir a la FELCC.»
  - glosas de la respuesta: FELCC

### C13

**Preguntas sueltas sin contexto (ambiguas)**

**Turno 1**

- Caja de texto (funcionario): «¿Dónde?»
- Glosas del avatar: DONDE
- Se abre: el selector de casos (la pregunta sola no dice de qué caso se trata)

**Turno 2**

- Caja de texto (funcionario): «¿Tiene testigos?»
- Glosas del avatar: TESTIGO · TENER · QUIEN
- Se abre: el selector de casos (la pregunta sola no dice de qué caso se trata)

**Turno 3**

- Caja de texto (funcionario): «¿Y eso cuándo fue?»
- Glosas del avatar: CUANDO · deletreo F-U-E
- Se abre: el selector de casos (la pregunta sola no dice de qué caso se trata)

### C12

**Charla de ventanilla que no es trámite (no debe abrir nada raro)**

**Turno 1**

- Caja de texto (funcionario): «Espere un momento, por favor.»
- Glosas del avatar: MOMENTO · ESPERAR · POR_FAVOR
- Se abre: nada. Es una instrucción o charla, no una pregunta que la persona sorda deba responder con tarjetas.

**Turno 2**

- Caja de texto (funcionario): «Tome asiento, ya la atiendo.»
- Glosas del avatar: deletreo T-O-M-E · deletreo A-S-I-E-N-T-O · deletreo Y-A · ATENDER
- Se abre: nada. Es una instrucción o charla, no una pregunta que la persona sorda deba responder con tarjetas.

**Turno 3**

- Caja de texto (funcionario): «¿Hace frío afuera, no?»
- Glosas del avatar: deletreo A-F-U-E-R-A · deletreo F-R-I-O · NO
- Se abre: nada. Es una instrucción o charla, no una pregunta que la persona sorda deba responder con tarjetas.

**Turno 4**

- Caja de texto (funcionario): «Gracias, eso sería todo por hoy.»
- Glosas del avatar: GRACIAS · deletreo T-O-D-O · HOY
- Se abre: nada. Es una instrucción o charla, no una pregunta que la persona sorda deba responder con tarjetas.

### C24

**Instrucciones del funcionario (no son preguntas)**

**Turno 1**

- Caja de texto (funcionario): «Firme aquí, por favor.»
- Glosas del avatar: deletreo F-I-R-M-A-R · AQUI · POR_FAVOR
- Se abre: nada. Es una instrucción o charla, no una pregunta que la persona sorda deba responder con tarjetas.

**Turno 2**

- Caja de texto (funcionario): «Vuelva el lunes con su carnet.»
- Glosas del avatar: LUNES · VOLVER · PAPEL · IDENTIDAD · TUYO · TRAER
- Se abre: nada. Es una instrucción o charla, no una pregunta que la persona sorda deba responder con tarjetas.

**Turno 3**

- Caja de texto (funcionario): «Le voy a dar una copia de su denuncia.»
- Glosas del avatar: YO · deletreo D-E-N-U-N-C-I-A · deletreo C-O-P-I-A · DAR
- Se abre: nada. Es una instrucción o charla, no una pregunta que la persona sorda deba responder con tarjetas.

### C20

**Entrada en otro idioma o sin sentido (control de calidad)**

**Turno 1**

- Caja de texto (funcionario): «Where did it happen?»
- La app no lo envía y avisa: «Solo se traduce el español. Escribe o di el mensaje en español.»

**Turno 2**

- Caja de texto (funcionario): «asdfgh qwerty»
- La app no lo envía y avisa: «No entendí el texto. Revisa que las palabras estén bien escritas.»

## Trámites

Trámites documentados (SEGIP, SERECI, defensa de la persona sorda) y los datos personales que piden.

### C05

**Trámite SEGIP: cédula perdida**

**Turno 1**

- Caja de texto (funcionario): «¿Perdió su cédula de identidad?»
- Glosas del avatar: TU · PAPEL · IDENTIDAD · PERDER · NO
- Se abre: «Reposición por pérdida o robo (SEGIP)», pregunta «¿Cree que perdió el objeto?»
- Tarjeta: «Sí» [SÍ] — responde a «¿Cree que perdió el objeto?»
- Vuelve al chat: «Sí, creo que lo perdí.»
  - glosas de la respuesta: SÍ

**Turno 2**

- Caja de texto (funcionario): «¿Trajo su certificado de nacimiento?»
- Glosas del avatar: CERTIFICADO · deletreo N-A-C-I-M-I-E-N-T-O · TRAER · SUYO
- Se abre: «Cédula por primera vez (SEGIP)», pregunta «¿Tiene certificado de nacimiento original computarizado?»
- Tarjeta: «Sí» [SÍ] — responde a «¿Tiene certificado de nacimiento original computarizado?»
- Vuelve al chat: «Sí. Lo tengo aquí.»
  - glosas de la respuesta: SÍ

**Turno 3**

- Caja de texto (funcionario): «¿Tiene la denuncia de pérdida?»
- Glosas del avatar: deletreo D-E-N-U-N-C-I-A · deletreo P-E-R-D-I-D-A · TENER
- Se abre: «Reposición por pérdida o robo (SEGIP)», pregunta «¿Ya presentó una denuncia por este hecho?»
- Tarjeta: «Sí» [SÍ] — responde a «¿Ya presentó una denuncia por este hecho?»
- Vuelve al chat: «Sí, ya presenté una denuncia.»
  - glosas de la respuesta: SÍ

### C06

**Certificado de nacimiento en SERECI**

**Turno 1**

- Caja de texto (funcionario): «¿Viene por un certificado de nacimiento?»
- Glosas del avatar: CERTIFICADO · deletreo N-A-C-I-M-I-E-N-T-O · VENIR
- Se abre: «Pedir un certificado de nacimiento (SERECI – Cochabamba)», pregunta «¿Viene por un certificado de nacimiento?»
- Tarjeta: «Sí» [SÍ] — responde a «¿Viene por un certificado de nacimiento?»
- Vuelve al chat: «Sí, necesito un certificado de nacimiento.»
  - glosas de la respuesta: SÍ

**Turno 2**

- Caja de texto (funcionario): «¿El certificado es suyo o de otra persona?»
- Glosas del avatar: CERTIFICADO · SUYO · deletreo P-E-R-S-O-N-A · deletreo O · deletreo T-R-O
- Se abre: «Pedir un certificado de nacimiento (SERECI – Cochabamba)», pregunta «¿El certificado es suyo?»
- Tarjeta: «Sí» [SÍ] — responde a «¿El certificado es suyo?»
- Vuelve al chat: «Sí, es mi certificado.»
  - glosas de la respuesta: SÍ

### C22

**Acoso discriminatorio en una oficina pública**

**Turno 1**

- Caja de texto (funcionario): «¿Un funcionario la discriminó por ser sorda?»
- Glosas del avatar: deletreo F-U-N-C-I-O-N-A-R-I-O · deletreo D-I-S-C-I-M-I-N-A-C-I-O-N · SORDO · deletreo S-E-R · NO
- Se abre: «Acoso discriminatorio por ser sordo (Derechos lingüísticos LSB / Defensoría del Pueblo)», pregunta «¿Un funcionario público lo discrimina?»
- Tarjeta: «Sí» [SÍ] — responde a «¿Un funcionario público lo discrimina?»
- Vuelve al chat: «Sí, es un funcionario de una oficina.»
  - glosas de la respuesta: SÍ

**Turno 2**

- Caja de texto (funcionario): «¿Se burlan de usted por ser sorda?»
- Glosas del avatar: SORDO · BURLAR · TU
- Se abre: «Acoso discriminatorio por ser sordo (Derechos lingüísticos LSB / Defensoría del Pueblo)», pregunta «¿Se burlan de usted por ser sordo?»
- Tarjeta: «Sí» [SÍ] — responde a «¿Se burlan de usted por ser sordo?»
- Vuelve al chat: «Sí, se burlan de mí.»
  - glosas de la respuesta: SÍ

### C03

**Datos personales en medio de una denuncia (cambio de tema explícito)**

**Turno 1**

- Caja de texto (funcionario): «¿Quiere denunciar un robo?»
- Glosas del avatar: ROBAR · deletreo D-E-N-U-N-C-I-A-R · QUE
- Se abre: «Denunciar robo», pregunta «¿Qué ocurrió?»
- Tarjeta: «Me robaron» [ROBAR] — responde a «¿Qué ocurrió?»
- Vuelve al chat: «Me robaron algo.»
  - glosas de la respuesta: ROBAR

**Turno 2**

- Caja de texto (funcionario): «Primero necesito sus datos. ¿Cuál es su nombre completo?»
- Glosas del avatar: NECESITAR · deletreo D-A-T-O-S · deletreo S-U · NOMBRE · deletreo C-O-M-P-L-E-T-O · CUAL
- Se abre: «Mis datos», pregunta «¿Cuál es su nombre completo?»
- Vuelve al chat: la persona sorda tiene que escribir el dato en la tarjeta (nombre, número, monto…); la prueba no lo escribe.

**Turno 3**

- Caja de texto (funcionario): «¿Trae su carnet de identidad?»
- Glosas del avatar: TU · PAPEL · IDENTIDAD · TRAER
- Se abre: «Mis datos», pregunta «¿Tiene su carnet de identidad?»
- Tarjeta: «Sí» [SÍ] — responde a «¿Tiene su carnet de identidad?»
- Vuelve al chat: «Sí, tengo mi carnet de identidad.»
  - glosas de la respuesta: SÍ

**Turno 4**

- Caja de texto (funcionario): «¿A qué número la podemos llamar?»
- Glosas del avatar: LLAMAR · deletreo N-U-M-E-R-O · PUEDO
- Se abre: «Mis datos», pregunta «¿Cuál es su número de celular?»
- Vuelve al chat: la persona sorda tiene que escribir el dato en la tarjeta (nombre, número, monto…); la prueba no lo escribe.

**Turno 5**

- Caja de texto (funcionario): «Bien, volvamos al robo. ¿A qué hora pasó?»
- Glosas del avatar: ROBAR · HORA · CUANDO
- Se abre: «Denunciar robo», pregunta «¿A qué hora aproximadamente?»
- Tarjeta: «Por la tarde» [TARDE] — responde a «¿A qué hora aproximadamente?»
- Vuelve al chat: «Fue por la tarde.»
  - glosas de la respuesta: TARDE

## Observaciones de la prueba

Las 35 conversaciones abren el caso y las preguntas esperadas, pero los flujos muestran cosas de la Lambda desplegada que conviene revisar:

1. **Muchas palabras comunes se deletrean** porque no tienen seña en el catálogo: PASAR, PERSONA, ROPA, PELIGRO, MÉDICO, SEXUAL… DENUNCIA y DENUNCIAR se deletrean por norma (términos judiciales).
2. **Señas animadas que la Lambda desplegada todavía deletrea**, por dos causas distintas. La app ya las convierte en su seña (cambio del 2026-10-12), por eso aquí aparecen como seña:
   - ACOSO y BULLYING no estaban en el catálogo de la Lambda.
   - Al `.glb` de S3 que lee la Lambda le faltaban clips que el avatar de la app sí tiene, según las respuestas grabadas: BUENOS_DIAS, BUENAS_TARDES, BUENAS_NOCHES, CONOCER, HACER, HIJO, IR, LLEVAR, PASADO, PERDER, TENER, TUYO y VIOLENCIA. Conviene subir a S3 el `assets/models/avatar_test.glb` actual. TRATA_TRAFICO sigue deletreada (T-R-A-T-A · T-R-A-F-I-C-O) hasta desplegar la Lambda nueva, que se la ofrece al modelo.
3. **Traducciones dudosas del modelo desplegado:**
   - «¿Cómo era?» sale COMO_ESTAS (C01, turno 6).
   - «¿Tiene testigos?» agrega QUIEN: TESTIGO · TENER · QUIEN (C07).
   - «¿Su hijo…?» sale YO · HIJO en vez de SUYO · HIJO (C09).
   - «¿Hay testigos?» deja HAY deletreado (H-A-Y) aunque HAY debería volverse TENER.
4. **Preguntas que piden un dato** (nombre completo, número de celular, monto, nombre de los testigos): la persona sorda lo escribe en la tarjeta. La prueba no escribe datos, por eso esos turnos no traen texto de respuesta (C03, C11, C17, C30).
5. **C10, turno 1:** la tarjeta «Sí» a «¿La persona es su familiar?» vuelve al chat solo como «Sí.», sin la frase completa.
6. **Charla e instrucciones** («Espere un momento», «Firme aquí, por favor», «Vuelva el lunes con su carnet») no abren tarjetas, como corresponde (C12, C24). Una pregunta suelta sin contexto («¿Dónde?», «¿Tiene testigos?») abre el selector de casos (C13). El inglés y el texto sin sentido no se envían (C20).
