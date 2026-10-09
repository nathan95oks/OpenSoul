# Flujos de conversación del módulo Conversación

Actualizado el 2026-10-09 jugando los 35 guiones de `test/qa/guiones_conversacion.json` con la app real y las respuestas grabadas de las Lambdas (`flutter test test/qa_conversacion_test.dart`, con `REPORTE_QA`). **Resultado: 35 de 35 conversaciones, 0 de 112 turnos con falla.** C30–C35 son los casos reportados el 2026-10-09; el detalle está en [QA_CONVERSACION_2026-10-09.md](QA_CONVERSACION_2026-10-09.md).

Cada flujo muestra el turno del funcionario (oyente), cómo lo clasificó el router, qué tarjetas abrió y qué responde la persona sorda. Complementa a [QA_CONVERSACION_2026-10-08.md](QA_CONVERSACION_2026-10-08.md), que explica las correcciones anteriores.

**Cómo leer las tablas:** *Ruta* = tipo de decisión del router (`contextSelector` pide elegir el motivo; `directContext` abre un contexto; `directQuestion` / `minimalGraphPath` abren preguntas; `noSafeRoute` no abre nada). *Contexto* = recorrido o trámite activo. *Abre* = preguntas que se muestran a la persona sorda (con sus hijas obligatorias, p. ej. nombre y celular del testigo). Donde la respuesta pide escribir un dato (nombre, celular), el QA no lo inventa y la persona sorda queda sin responder (—).

## Índice

- 1. Trámites e información
- 2. Consultas y seguimiento de un caso
- 3. Denuncias de delitos comunes (robo, estafa, testigo)
- 4. Violencia
- 5. Acoso (sexual, digital, escolar, discriminatorio, físico)
- 6. Trata y tráfico
- 7. Lenguaje natural y casos difíciles
- 8. La persona sorda inicia


## 1. Trámites e información

### C04 · Accesibilidad: intérprete y lectura

| # | Funcionario | Ruta | Contexto | Abre | Persona sorda |
|---|---|---|---|---|---|
| 1 | ¿Necesita un intérprete de lengua de señas? | `minimalGraphPath` | identificacion | ¿Necesita un intérprete de LSB? · ¿Necesita intérprete para esa reunión? | Sí, necesito un intérprete de LSB. Sí, necesito intérprete para esa reunión. |
| 2 | ¿Puede leer lo que le escribo? | `directQuestion` | identificacion | ¿Puede leer este texto? | Sí, puedo leerlo. |
| 3 | ¿Me entiende bien? | `noSafeRoute` | identificacion | — | — |

### C05 · Trámite SEGIP: cédula perdida

| # | Funcionario | Ruta | Contexto | Abre | Persona sorda |
|---|---|---|---|---|---|
| 1 | ¿Perdió su cédula de identidad? | `directQuestion` | tramite_segip_103 | ¿Cree que perdió el objeto? | Sí, creo que lo perdí. |
| 2 | ¿Trajo su certificado de nacimiento? | `directQuestion` | tramite_segip_01 | ¿Tiene certificado de nacimiento original computarizado? | Sí. Lo tengo aquí. |
| 3 | ¿Tiene la denuncia de pérdida? | `directQuestion` | tramite_segip_103 | ¿Ya presentó una denuncia por este hecho? | Sí, ya presenté una denuncia. |

### C06 · Certificado de nacimiento en SERECI

| # | Funcionario | Ruta | Contexto | Abre | Persona sorda |
|---|---|---|---|---|---|
| 1 | ¿Viene por un certificado de nacimiento? | `directQuestion` | tramite_sereci_201 | ¿Viene por un certificado de nacimiento? | Sí, necesito un certificado de nacimiento. |
| 2 | ¿El certificado es suyo o de otra persona? | `directQuestion` | tramite_sereci_201 | ¿El certificado es suyo? | Sí, es mi certificado. |

### C12 · Charla de ventanilla que no es trámite (no debe abrir nada raro)

| # | Funcionario | Ruta | Contexto | Abre | Persona sorda |
|---|---|---|---|---|---|
| 1 | Espere un momento, por favor. | `noSafeRoute` | — | — | — |
| 2 | Tome asiento, ya la atiendo. | `noSafeRoute` | — | — | — |
| 3 | ¿Hace frío afuera, no? | `noSafeRoute` | — | — | — |
| 4 | Gracias, eso sería todo por hoy. | `noSafeRoute` | — | — | — |

### C26 · Saludo de la tarde y de la noche (no es «buenos días»)

| # | Funcionario | Ruta | Contexto | Abre | Persona sorda |
|---|---|---|---|---|---|
| 1 | Buenas tardes, ¿en qué le puedo ayudar? | `contextSelector` | — | — | Me robaron algo. |
| 2 | Buenas noches. ¿Qué le robaron? | `directQuestion` | denuncia_robo | ¿Qué le robaron? · ¿Qué papel es? | Me robaron el celular. |


## 2. Consultas y seguimiento de un caso

### C18 · Seguimiento de una denuncia anterior

| # | Funcionario | Ruta | Contexto | Abre | Persona sorda |
|---|---|---|---|---|---|
| 1 | ¿Viene a ver cómo va su denuncia? | `directQuestion` | seguimiento | ¿Vino a consultar el estado de su caso? | Sí, vine a consultar el estado de mi caso. |
| 2 | ¿Tiene el número de su caso? | `directQuestion` | seguimiento | ¿Tiene el número de referencia? | Sí, tengo el número de referencia. |
| 3 | ¿Sabe quién es su fiscal? | `directQuestion` | seguimiento | ¿Sabe quién es su fiscal? | No sé quién es mi fiscal. |

### C31 · Seguimiento: quién investiga el caso y quién es su fiscal (sí o no)

| # | Funcionario | Ruta | Contexto | Abre | Persona sorda |
|---|---|---|---|---|---|
| 1 | ¿Viene a ver cómo va su denuncia? | `directQuestion` | seguimiento | ¿Vino a consultar el estado de su caso? | Sí, vine a consultar el estado de mi caso. |
| 2 | ¿Quiere saber quién investigará su caso? | `directQuestion` | seguimiento | ¿Quiere saber quién investigará su caso? | Sí, quiero saber quién investigará mi caso. |
| 3 | sabe quien es su fiscal | `directQuestion` | seguimiento | ¿Sabe quién es su fiscal? | No sé quién es mi fiscal. |


## 3. Denuncias de delitos comunes (robo, estafa, testigo)

### C01 · Denuncia de robo en ventanilla, de principio a fin

| # | Funcionario | Ruta | Contexto | Abre | Persona sorda |
|---|---|---|---|---|---|
| 1 | Buenos días, ¿en qué le puedo ayudar? | `contextSelector` | — | — | Me robaron algo. |
| 2 | ¿Qué le robaron? | `directQuestion` | denuncia_robo | ¿Qué le robaron? · ¿Qué papel es? | Me robaron el celular. |
| 3 | ¿Cuándo pasó? | `directQuestion` | denuncia_robo | ¿Cuándo ocurrió? | Ocurrió hace un momento. |
| 4 | ¿Y dónde fue? | `directQuestion` | denuncia_robo | ¿Dónde ocurrió? | Ocurrió en la calle. |
| 5 | ¿Conoce a la persona que le robó? | `directQuestion` | denuncia_robo | ¿Conoce a la persona involucrada? | Sí, conozco a esa persona. |
| 6 | ¿Me puede describir a esa persona? ¿Cómo era? | `minimalGraphPath` | denuncia_robo | ¿Era un hombre o una mujer? · ¿Qué edad aproximada tenía? · ¿Era alto o bajo? · ¿Era delgado o de contextura gruesa? · ¿Qué ropa llevaba? · ¿De qué color era la polera? · ¿De qué color era el pantalón? · ¿De qué color era la chamarra? · ¿De qué color era la gorra? · ¿De qué color era la mochila? · ¿De qué color era su ropa? | Era un hombre. Era una persona joven. Era una persona alta. Era una persona delgada. Llevaba una polera. La polera era de color negro. |
| 7 | ¿Qué ropa llevaba puesta? | `directQuestion` | denuncia_robo | ¿Qué ropa llevaba? · ¿De qué color era la polera? · ¿De qué color era el pantalón? · ¿De qué color era la chamarra? · ¿De qué color era la gorra? · ¿De qué color era la mochila? · ¿De qué color era su ropa? | Llevaba una polera. La polera era de color negro. |
| 8 | ¿Alguien vio lo que pasó? | `directQuestion` | denuncia_robo | ¿Hay testigos? | Sí, hay testigos. |
| 9 | ¿Tiene la factura o la caja del celular? | `directQuestion` | denuncia_robo | ¿Tiene la factura? | Sí, tengo la factura. |
| 10 | ¿Quiere presentar la denuncia formal? | `directQuestion` | denuncia_robo | ¿Desea presentar estos elementos? | Sí, quiero presentar estos elementos. |

### C30 · Testigos de un robo: si los conoce, su nombre y su celular; cámaras y a dónde ir

| # | Funcionario | Ruta | Contexto | Abre | Persona sorda |
|---|---|---|---|---|---|
| 1 | Buenos días, ¿en qué le puedo ayudar? | `contextSelector` | — | — | Me robaron algo. |
| 2 | ¿Hay testigos? | `directQuestion` | denuncia_robo | ¿Hay testigos? | Sí, hay testigos. |
| 3 | quienes son los testigos | `directQuestion` | denuncia_robo | ¿Conoce a los testigos? · ¿Cuál es el nombre del testigo? · ¿Cuál es el número de celular del testigo? | — |
| 4 | ¿Hay cámaras en esa calle? | `directQuestion` | denuncia_robo | ¿Hay cámaras o video del lugar? | Sí, hay video del lugar. |
| 5 | entiende a donde tiene que ir? | `directQuestion` | derivacion | ¿Sabe a dónde tiene que ir? | No sé a dónde tengo que ir. Dígame usted, por favor. |

### C11 · Estafa por transferencia

| # | Funcionario | Ruta | Contexto | Abre | Persona sorda |
|---|---|---|---|---|---|
| 1 | ¿Le engañaron para que deposite dinero? | `directQuestion` | engano_dinero | ¿Quiere decir que lo engañaron? | Me engañaron con dinero. |
| 2 | ¿Cuánto dinero transfirió? | `directQuestion` | engano_dinero | ¿Cuánto dinero fue? | — |
| 3 | ¿Tiene el comprobante? | `directQuestion` | engano_dinero | ¿Tiene algún comprobante? | Sí, tengo un comprobante. |

### C21 · Testigo de un hecho (contexto «otro»)

| # | Funcionario | Ruta | Contexto | Abre | Persona sorda |
|---|---|---|---|---|---|
| 1 | ¿Usted fue testigo de lo que pasó? | `directContext` | otro | ¿Qué vio o qué quiere declarar? | Vi un robo. |
| 2 | ¿Qué vio exactamente? | `directQuestion` | otro | ¿Qué vio o qué quiere declarar? | Vi un robo. |
| 3 | ¿Podría declarar como testigo? | `directQuestion` | otro | ¿Puede dar testimonio de lo que vio? | Sí, puedo dar testimonio de lo que vi. |

### C25 · Robo de celular en FELCC: pruebas y seguimiento

| # | Funcionario | Ruta | Contexto | Abre | Persona sorda |
|---|---|---|---|---|---|
| 1 | ¿Tiene la caja o la factura del celular? | `directQuestion` | tramite_felcc_01 | ¿Tiene la caja o la factura del celular? | Sí, tengo la caja del celular. |
| 2 | ¿Hay cámaras en esa calle? | `directQuestion` | tramite_felcc_01 | ¿Hay cámaras en esa calle? | Sí, hay cámaras en esa calle. |
| 3 | ¿Quiere saber quién investigará el robo? | `directQuestion` | tramite_felcc_01 | ¿Quiere saber quién investigará el robo? | Sí, quiero conocer al investigador. |

### C03 · Datos personales en medio de una denuncia (cambio de tema explícito)

| # | Funcionario | Ruta | Contexto | Abre | Persona sorda |
|---|---|---|---|---|---|
| 1 | ¿Quiere denunciar un robo? | `directContext` | denuncia_robo | ¿Qué ocurrió? | Me robaron algo. |
| 2 | Primero necesito sus datos. ¿Cuál es su nombre completo? | `directQuestion` | identificacion | ¿Cuál es su nombre completo? | — |
| 3 | ¿Trae su carnet de identidad? | `directQuestion` | identificacion | ¿Tiene su carnet de identidad? | Sí, tengo mi carnet de identidad. |
| 4 | ¿A qué número la podemos llamar? | `directQuestion` | identificacion | ¿Cuál es su número de celular? | — |
| 5 | Bien, volvamos al robo. ¿A qué hora pasó? | `directQuestion` | denuncia_robo | ¿A qué hora aproximadamente? | Fue por la tarde. |


## 4. Violencia

### C02 · Violencia de pareja: seguridad primero

| # | Funcionario | Ruta | Contexto | Abre | Persona sorda |
|---|---|---|---|---|---|
| 1 | Hola, ¿qué le pasó? Cuénteme con calma. | `contextSelector` | — | — | Me pegaron. |
| 2 | ¿Está en peligro ahora mismo? | `directQuestion` | violencia | ¿Necesita auxilio ahora? | Sí, necesito auxilio ahora. |
| 3 | ¿Quién le hizo esto? | `directQuestion` | violencia | ¿Quién le agredió? | Fue alguien que conozco. |
| 4 | ¿Está herida? ¿Le duele algo? | `directQuestion` | violencia | ¿Está herido? · ¿Qué le hicieron? | Me pegaron. |
| 5 | ¿Esto ya le pasó antes? | `directQuestion` | violencia | ¿Es la primera vez o pasa seguido? | Es la primera vez. |
| 6 | ¿Tiene miedo de volver a su casa? | `directQuestion` | violencia | ¿Tiene miedo de volver a su casa? | Sí, tengo miedo de volver a mi casa. |
| 7 | ¿Necesita que la llevemos al médico? | `directQuestion` | violencia | ¿Necesita asistencia médica? · ¿Qué le hicieron? · ¿Está herido? | Me pegaron. Sí, estoy herido. |

### C19 · Oficina equivocada: derivar a FELCV

| # | Funcionario | Ruta | Contexto | Abre | Persona sorda |
|---|---|---|---|---|---|
| 1 | Aquí atendemos robos. Para violencia tiene que ir a la FELCV. | `directQuestion` | tramite_felcc_202 | Para la violencia de pareja corresponde la FELCV. | Entendido. |
| 2 | ¿Entiende a dónde tiene que ir? | `directQuestion` | derivacion | ¿Sabe a dónde tiene que ir? | Tengo que ir a la FELCV. |


## 5. Acoso (sexual, digital, escolar, discriminatorio, físico)

### C07 · Acoso sexual en el trabajo (escenario nuevo)

| # | Funcionario | Ruta | Contexto | Abre | Persona sorda |
|---|---|---|---|---|---|
| 1 | ¿Quiere denunciar acoso sexual? | `directQuestion` | tramite_felcv_201 | ¿La acosaron sexualmente? | Sí, me acosaron sexualmente. |
| 2 | ¿Conoce a la persona que la acosa? | `directQuestion` | tramite_felcv_201 | ¿Conoce a la persona que la acosa? · ¿Quién es esa persona? | Sí, conozco a esa persona. Mi jefe. |
| 3 | ¿Esa persona la tocó sin su permiso? | `directQuestion` | tramite_felcv_201 | ¿Esa persona la tocó sin su permiso? | Sí, me tocó sin mi permiso. |
| 4 | ¿Tiene testigos? | `directQuestion` | tramite_felcv_201 | ¿Tiene testigos? | Sí, hay testigos. |

### C28 · Acoso sexual en la FELCV: sin datos inventados y sin «Entendido» suelto

| # | Funcionario | Ruta | Contexto | Abre | Persona sorda |
|---|---|---|---|---|---|
| 1 | ¿Quiere denunciar acoso sexual? | `directQuestion` | tramite_felcv_201 | ¿La acosaron sexualmente? | Sí, me acosaron sexualmente. |
| 2 | ¿Conoce a la persona que la acosa? | `directQuestion` | tramite_felcv_201 | ¿Conoce a la persona que la acosa? · ¿Quién es esa persona? | Sí, conozco a esa persona. Compañera. |
| 3 | La FELCV es la unidad especializada contra la violencia. | `directQuestion` | tramite_felcv_201 | La FELCV es la unidad especializada contra la violencia. | Entendido. |

### C32 · Acoso sexual sin decir «denunciar»: quién es y con quién habló

| # | Funcionario | Ruta | Contexto | Abre | Persona sorda |
|---|---|---|---|---|---|
| 1 | ¿La acosaron sexualmente? | `directQuestion` | tramite_felcv_201 | ¿La acosaron sexualmente? | Sí, me acosaron sexualmente. |
| 2 | ¿Conoce a la persona que lo acosa? | `directQuestion` | tramite_felcv_201 | ¿Conoce a la persona que la acosa? · ¿Quién es esa persona? | Sí, conozco a esa persona. Mi jefe. |
| 3 | ¿Habló con alguien más sobre este acoso? | `directQuestion` | tramite_felcv_201 | ¿Habló con alguien más sobre este acoso? · ¿Con quién habló? | Sí, hablé con alguien más. Mi mamá. |

### C08 · Ciberacoso por celular (escenario nuevo)

| # | Funcionario | Ruta | Contexto | Abre | Persona sorda |
|---|---|---|---|---|---|
| 1 | ¿Le están amenazando por internet? | `directContext` | amenaza_digital | ¿Qué decían los mensajes? | Recibí mensajes con amenazas. |
| 2 | ¿Publicaron sus fotos sin su permiso? | `directQuestion` | amenaza_digital | ¿Publicaron sus fotos sin su permiso? | Sí, publicaron mis fotos sin mi permiso. |
| 3 | ¿Guardó los mensajes? | `directQuestion` | amenaza_digital | ¿Guardó los mensajes? | Sí, guardé los mensajes. |

### C33 · Fotos publicadas sin permiso: «No» dice que no publicaron nada

| # | Funcionario | Ruta | Contexto | Abre | Persona sorda |
|---|---|---|---|---|---|
| 1 | ¿Le están amenazando por internet? | `directContext` | amenaza_digital | ¿Qué decían los mensajes? | Recibí mensajes con amenazas. |
| 2 | ¿Publicaron fotos suyas sin su permiso? | `directQuestion` | amenaza_digital | ¿Publicaron sus fotos sin su permiso? | No, no publicaron nada. |

### C09 · Bullying en la escuela (escenario nuevo)

| # | Funcionario | Ruta | Contexto | Abre | Persona sorda |
|---|---|---|---|---|---|
| 1 | ¿Su hijo sufre bullying en la escuela? | `directQuestion` | tramite_dna_201 | ¿Su hijo sufre bullying? | Sí, mi hijo sufre bullying. |
| 2 | ¿Otros niños le pegan a su hijo? | `directQuestion` | tramite_dna_201 | ¿Otros niños pegan a su hijo? | Sí, otros niños le pegan. |
| 3 | ¿Habló con el maestro? | `directQuestion` | tramite_dna_201 | ¿Habló con el maestro de la escuela? | Sí, hablé con el maestro. |

### C34 · Bullying: «¿Usted o su hijo…?» pregunta por el bullying, no por heridas

| # | Funcionario | Ruta | Contexto | Abre | Persona sorda |
|---|---|---|---|---|---|
| 1 | ¿Usted o su hijo sufre bullying? | `directQuestion` | tramite_dna_201 | ¿Su hijo sufre bullying? | Sí, mi hijo sufre bullying. |
| 2 | ¿Su hijo tiene heridas o dolor? | `directQuestion` | tramite_dna_201 | ¿Su hijo tiene heridas o dolor? | Sí, mi hijo tiene dolor. |

### C22 · Acoso discriminatorio en una oficina pública

| # | Funcionario | Ruta | Contexto | Abre | Persona sorda |
|---|---|---|---|---|---|
| 1 | ¿Un funcionario la discriminó por ser sorda? | `directQuestion` | tramite_lsb_201 | ¿Un funcionario público lo discrimina? | Sí, es un funcionario de una oficina. |
| 2 | ¿Se burlan de usted por ser sorda? | `directQuestion` | tramite_lsb_201 | ¿Se burlan de usted por ser sordo? | Sí, se burlan de mí. |

### C29 · Acoso físico: «¿Conoce a esa persona?» no agrega dónde vive

| # | Funcionario | Ruta | Contexto | Abre | Persona sorda |
|---|---|---|---|---|---|
| 1 | ¿Viene a denunciar acoso físico? | `directContext` | — | — | Sí, conozco a esa persona. Compañera. |
| 2 | ¿Conoce a esa persona? | `directQuestion` | tramite_felcc_202 | ¿Conoce a esa persona? · ¿Quién es esa persona? | Sí, conozco a esa persona. Compañera. |
| 3 | Para la violencia de pareja corresponde la FELCV. | `directQuestion` | tramite_felcc_202 | Para la violencia de pareja corresponde la FELCV. | Entendido. |


## 6. Trata y tráfico

### C10 · Trata y tráfico: familiar desaparecida (escenario nuevo)

| # | Funcionario | Ruta | Contexto | Abre | Persona sorda |
|---|---|---|---|---|---|
| 1 | ¿Quiere denunciar trata y tráfico de personas? | `directContext` | — | — | Sí. |
| 2 | ¿La persona desapareció? | `directQuestion` | tramite_felcc_203 | ¿La persona desapareció? | Sí, desapareció y no volvió. |
| 3 | ¿Tiene una foto de ella? | `directQuestion` | tramite_felcc_203 | ¿Tiene una foto de la persona? | Sí, tengo fotos. |


## 7. Lenguaje natural y casos difíciles

### C13 · Preguntas sueltas sin contexto (ambiguas)

| # | Funcionario | Ruta | Contexto | Abre | Persona sorda |
|---|---|---|---|---|---|
| 1 | ¿Dónde? | `contextSelector` | — | — | (elige contexto en el selector) |
| 2 | ¿Tiene testigos? | `directQuestion` | denuncia_robo | ¿Hay testigos? | Sí, hay testigos. |
| 3 | ¿Y eso cuándo fue? | `directQuestion` | denuncia_robo | ¿Cuándo ocurrió? | Ocurrió hace un momento. |

### C14 · Negaciones y presuposiciones

| # | Funcionario | Ruta | Contexto | Abre | Persona sorda |
|---|---|---|---|---|---|
| 1 | No le pregunto por el robo, le pregunto por su cédula. ¿La trae? | `directQuestion` | identificacion | ¿Tiene su carnet de identidad? | Sí, tengo mi carnet de identidad. |
| 2 | ¿Su pareja le pegó ayer? | `directContext` | violencia | ¿Qué le hicieron? | Me pegaron. |
| 3 | ¿No sabe quién fue? | `directQuestion` | violencia | ¿Quién le agredió? | Fue alguien que conozco. |

### C15 · Cambio de tema a mitad de la conversación

| # | Funcionario | Ruta | Contexto | Abre | Persona sorda |
|---|---|---|---|---|---|
| 1 | ¿Qué le robaron? | `directQuestion` | denuncia_robo | ¿Qué le robaron? · ¿Qué papel es? | Me robaron el celular. |
| 2 | ¿También le golpearon? | `directContext` | violencia | ¿Qué le hicieron? | Me pegaron. |
| 3 | ¿Necesita atención médica? | `directQuestion` | violencia | ¿Necesita asistencia médica? · ¿Qué le hicieron? · ¿Está herido? | Me pegaron. Sí, estoy herido. |

### C16 · Lenguaje coloquial y errores de tipeo

| # | Funcionario | Ruta | Contexto | Abre | Persona sorda |
|---|---|---|---|---|---|
| 1 | ¿Qué le chorearon? | `directQuestion` | denuncia_robo | ¿Qué le robaron? · ¿Qué papel es? | Me robaron el celular. |
| 2 | dnde paso eso | `directQuestion` | denuncia_robo | ¿Dónde ocurrió? | Ocurrió en la calle. |
| 3 | ¿a q hora fue? | `directQuestion` | denuncia_robo | ¿A qué hora aproximadamente? | Fue por la tarde. |

### C17 · Varias preguntas a la vez

| # | Funcionario | Ruta | Contexto | Abre | Persona sorda |
|---|---|---|---|---|---|
| 1 | ¿Cuándo, dónde y a qué hora le robaron? | `minimalGraphPath` | denuncia_robo | ¿Cuándo ocurrió? · ¿Dónde ocurrió? · ¿A qué hora aproximadamente? | Ocurrió hace un momento. Ocurrió en la calle. Fue por la tarde. |
| 2 | ¿Cómo se llama y cuántos años tiene? | `minimalGraphPath` | identificacion | ¿Cuál es su nombre completo? · ¿Qué edad tiene? | — |

### C20 · Entrada en otro idioma o sin sentido (control de calidad)

| # | Funcionario | Ruta | Contexto | Abre | Persona sorda |
|---|---|---|---|---|---|
| 1 | Where did it happen? | rechazado | — | — | Aviso: «Solo se traduce el español. Escribe o di el mensaje en español.» |
| 2 | asdfgh qwerty | rechazado | — | — | Aviso: «No entendí el texto. Revisa que las palabras estén bien escritas.» |

### C24 · Instrucciones del funcionario (no son preguntas)

| # | Funcionario | Ruta | Contexto | Abre | Persona sorda |
|---|---|---|---|---|---|
| 1 | Firme aquí, por favor. | `noSafeRoute` | — | — | — |
| 2 | Vuelva el lunes con su carnet. | `noSafeRoute` | — | — | — |
| 3 | Le voy a dar una copia de su denuncia. | `noSafeRoute` | — | — | — |

### C27 · «¿Cuándo y a qué hora?»: dos datos, dos preguntas

| # | Funcionario | Ruta | Contexto | Abre | Persona sorda |
|---|---|---|---|---|---|
| 1 | ¿Quiere denunciar un robo? | `directContext` | denuncia_robo | ¿Qué ocurrió? | Me robaron algo. |
| 2 | ¿Cuándo y a qué hora pasó? | `minimalGraphPath` | denuncia_robo | ¿Cuándo ocurrió? · ¿A qué hora aproximadamente? | Ocurrió hace un momento. Fue por la tarde. |

### C35 · Sin conversación previa: cámaras y a dónde ir (Derivación)

| # | Funcionario | Ruta | Contexto | Abre | Persona sorda |
|---|---|---|---|---|---|
| 1 | ¿Hay cámaras en esa calle? | `directQuestion` | tramite_felcc_01 | ¿Hay cámaras en esa calle? | Sí, hay cámaras en esa calle. |
| 2 | ¿Entiende a dónde tiene que ir? | `directQuestion` | derivacion | ¿Sabe a dónde tiene que ir? | Tengo que ir a la FELCC. |


## 8. La persona sorda inicia

### C23 · La persona sorda abre el turno y el funcionario sigue

| # | Funcionario | Ruta | Contexto | Abre | Persona sorda |
|---|---|---|---|---|---|
| 1 | *(la persona sorda abre)* | — | — | — | Me robaron algo. |
| 2 | Entiendo. ¿Qué le robaron exactamente? | `directQuestion` | denuncia_robo | ¿Qué le robaron? · ¿Qué papel es? | Me robaron el celular. |
| 3 | ¿Fue con violencia? | `directContext` | violencia | ¿Qué le hicieron? | Me pegaron. |
