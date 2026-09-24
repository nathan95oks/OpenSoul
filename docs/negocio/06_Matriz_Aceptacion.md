# Matriz de aceptación

Generado por `tool/build_business_docs.py` desde `config/matriz_aceptacion.json`. No editar a mano.

Se separan dos cosas que no deben mezclarse:

- **Comprobable sobre las configuraciones de esta fase** (2 casos): se verifica con `tool/validate_business_config.py` y con los datos generados.
- **Pendiente de prueba de interfaz** (13 casos): exige código que todavía no existe. **Ninguno está aprobado.**

## Resumen

| Caso | Título | Modo | Institución | Comprobación |
|---|---|---|---|---|
| `AC-01` | Entrada con selector de modo y Conversación al centro | — | `—` | interfaz_pendiente |
| `AC-02` | Modo personal sin institución, mensaje inicial de la persona sorda | personal | `sin_institucion` | interfaz_pendiente |
| `AC-03` | Pregunta propia desde Consultas en propósito independiente | personal | `sin_institucion` | interfaz_pendiente |
| `AC-04` | Ventanilla DDRR con pregunta de identificación | ventanilla | `derechos_reales` | interfaz_pendiente |
| `AC-05` | Ventanilla con inicio por la persona sorda | ventanilla | `policia` | interfaz_pendiente |
| `AC-06` | Ventanilla con inicio por el oyente | ventanilla | `policia` | interfaz_pendiente |
| `AC-07` | Mención de otra institución sin cambio del perfil activo | ventanilla | `derechos_reales` | interfaz_pendiente |
| `AC-08` | Consulta sobre un documento en Policía | ventanilla | `policia` | interfaz_pendiente |
| `AC-09` | Pregunta con alternativas, abierta, negativa e intención no reconocida | ventanilla | `derechos_reales` | configuracion |
| `AC-10` | Término ausente del corpus nunca aparece como seña oficial | — | `—` | configuracion |
| `AC-11` | ROBAR + ESCAPAR con protagonistas distintos, edición y cancelación | ventanilla | `policia` | interfaz_pendiente |
| `AC-12` | Reanudación del mismo borrador, cambio de modo y turno nuevo | ventanilla | `policia` | interfaz_pendiente |
| `AC-13` | Fin de atención seguido de otro ciudadano | ventanilla | `derechos_reales` | interfaz_pendiente |
| `AC-14` | Migración de pestañas persistidas y persistencia separada | — | `—` | interfaz_pendiente |
| `AC-15` | Igualdad de significado entre vista previa, texto, audio y representación semántica | — | `—` | interfaz_pendiente |

## Detalle

### `AC-01` — Entrada con selector de modo y Conversación al centro

- **Entrada**: Primera apertura de la aplicación, sin sesión previa.
- **Modo**: cualquiera
- **Institución**: `—`
- **Necesidad**: `—`
- **Salida esperada**:
  - Se muestra el selector con dos opciones: uso personal y atención en ventanilla.
  - No se muestra ninguna conversación antes de decidir la sesión.
  - Tras elegir, la barra inferior presenta Tarjetas LSB · Conversación · Texto/voz a LSB, con Conversación en la posición central.
  - El modo activo queda visible y hay un control para cambiarlo.
- **Contenido y comportamiento prohibidos**:
  - Decidir el modo por el tamaño de pantalla.
  - Abrir automáticamente la conversación anterior.
  - Exigir cuenta, autenticación institucional o geolocalización.
- **Comprobación**: interfaz_pendiente

### `AC-02` — Modo personal sin institución, mensaje inicial de la persona sorda

- **Entrada**: Modo personal; elige Denuncias; no elige institución.
- **Modo**: personal
- **Institución**: `sin_institucion`
- **Necesidad**: `denuncias`
- **Intención**: `RELATO_ABIERTO`
- **Salida esperada**:
  - El recorrido parte de lo sucedido, no de la institución.
  - «No sé / aún no elegí» está disponible y no bloquea nada.
  - Al pulsar «Iniciar conversación con este mensaje», el contenido confirmado se conserva y se convierte en turno propio con replyToId nulo.
  - El mensaje no se reconstruye desde cero ni se envía dos veces.
- **Contenido y comportamiento prohibidos**:
  - Enlazar el turno con una pregunta de un chat guardado.
  - Exigir institución para narrar un hecho.
- **Comprobación**: interfaz_pendiente

### `AC-03` — Pregunta propia desde Consultas en propósito independiente

- **Entrada**: Modo personal; elige Consultas; quiere preguntar dónde consultar su trámite.
- **Modo**: personal
- **Institución**: `sin_institucion`
- **Necesidad**: `consultas`
- **Intención**: `CONSULTA_ESTADO`
- **Salida esperada**:
  - El acto comunicativo resultante es pregunta, no declaración.
  - El texto se redacta como pregunta y el audio la reproduce como tal.
  - El propósito sigue siendo independiente: no hay turno oyente al que responder.
- **Contenido y comportamiento prohibidos**:
  - Forzar la salida a una afirmación por llamarse el propósito 'standaloneDeclaration'.
  - Redactar «Denuncio…» a partir de una consulta.
- **Comprobación**: interfaz_pendiente

### `AC-04` — Ventanilla DDRR con pregunta de identificación

- **Entrada**: Modo ventanilla, perfil Derechos Reales. El funcionario escribe «¿Cuál es su nombre?».
- **Modo**: ventanilla
- **Institución**: `derechos_reales`
- **Necesidad**: `tramites`
- **Intención**: `IDENTIFICACION_NOMBRE`
- **Salida esperada**:
  - Se reconoce identificación, no un trámite registral.
  - Las opciones ofrecidas corresponden al campo nombre, incluida la dactilología.
  - El encabezado conserva la frase exacta del funcionario.
- **Glosas prohibidas entre las primeras opciones**: `TRÁMITE`, `CERTIFICADO`, `SELLO`
- **Contenido y comportamiento prohibidos**:
  - Anteponer opciones registrales porque el perfil sea DDRR.
  - Ofrecer FOLIO, que no existe en el catálogo, como si estuviera cubierto.
- **Comprobación**: interfaz_pendiente

### `AC-05` — Ventanilla con inicio por la persona sorda

- **Entrada**: Modo ventanilla, perfil Policía. Nadie ha hablado. La persona sorda abre con tarjetas.
- **Modo**: ventanilla
- **Institución**: `policia`
- **Necesidad**: `denuncias`
- **Salida esperada**:
  - El propósito es inicio en conversación; replyToId nulo.
  - El perfil institucional ordena las prioridades, sin inventar una pregunta del funcionario.
  - Tras enviar, aparece «Continuar como persona oyente».
- **Contenido y comportamiento prohibidos**:
  - Mostrar un encabezado «Respondiendo a…» sin turno oyente.
  - Poner el nombre de la institución en boca de la persona sorda como contenido declarado.
- **Comprobación**: interfaz_pendiente

### `AC-06` — Ventanilla con inicio por el oyente

- **Entrada**: Modo ventanilla, perfil Policía. El funcionario dicta «¿Qué le ocurrió?».
- **Modo**: ventanilla
- **Institución**: `policia`
- **Necesidad**: `denuncias`
- **Intención**: `RELATO_ABIERTO`
- **Salida esperada**:
  - Se conserva la transcripción original íntegra.
  - «Responder con tarjetas» abre una respuesta dirigida a ese turno, con su ID.
  - Las opciones corresponden a un relato abierto, no a un sí/no.
- **Glosas prohibidas entre las primeras opciones**: `SÍ`, `NO`
- **Contenido y comportamiento prohibidos**:
  - Convertir una pregunta abierta en pregunta cerrada.
- **Comprobación**: interfaz_pendiente

### `AC-07` — Mención de otra institución sin cambio del perfil activo

- **Entrada**: Modo ventanilla, perfil Derechos Reales. La persona sorda dice «Traje un documento del juzgado».
- **Modo**: ventanilla
- **Institución**: `derechos_reales`
- **Necesidad**: `tramites`
- **Salida esperada**:
  - JUZGADO se registra como institución mencionada.
  - El perfil de la atención sigue siendo Derechos Reales.
  - Si el sistema cree que hay conflicto, propone una aclaración breve; no cambia solo.
- **Contenido y comportamiento prohibidos**:
  - Cambiar el perfil activo por una mención incidental.
- **Comprobación**: interfaz_pendiente

### `AC-08` — Consulta sobre un documento en Policía

- **Entrada**: Modo ventanilla, perfil Policía. La persona sorda pregunta por un papel que le pidieron.
- **Modo**: ventanilla
- **Institución**: `policia`
- **Necesidad**: `consultas`
- **Salida esperada**:
  - Las opciones corresponden a una consulta documental.
  - La necesidad puede cambiarse sin salir de la atención.
- **Glosas prohibidas entre las primeras opciones**: `ROBAR`
- **Contenido y comportamiento prohibidos**:
  - Priorizar ROBAR por el nombre de la institución.
- **Comprobación**: interfaz_pendiente

### `AC-09` — Pregunta con alternativas, abierta, negativa e intención no reconocida

- **Entrada**: Cuatro enunciados del oyente: alternativa («¿Viene a solicitar un folio o a presentar un requisito?»), abierta («¿Dónde ocurrió?»), negativa («No trajo el documento») e irreconocible («El parqueo cierra a medianoche»).
- **Modo**: ventanilla
- **Institución**: `derechos_reales`
- **Necesidad**: `consultas`
- **Salida esperada**:
  - La alternativa ofrece elegir entre intenciones, no un sí/no.
  - La abierta no ofrece polaridad.
  - La negativa no se convierte en afirmación.
  - La irreconocible no empareja ningún nodo: se proponen intenciones candidatas y se conserva el texto original.
  - En la alternativa se declara la ausencia de cobertura del concepto folio.
- **Contenido y comportamiento prohibidos**:
  - Emparejar la frase irreconocible con el nodo más parecido.
  - Presentar el concepto folio como cubierto.
- **Comprobación**: configuracion

### `AC-10` — Término ausente del corpus nunca aparece como seña oficial

- **Entrada**: Recorridos que necesitan FOLIO, BILLETERA, ARMA, NOCHE, PAGAR, CÉDULA, ESCRITURA, PROPIEDAD, DOCUMENTO, JUICIO, ENTREGAR, REGISTRAR, CORREGIR o RENOVAR.
- **Modo**: cualquiera
- **Institución**: `—`
- **Necesidad**: `—`
- **Salida esperada**:
  - Ninguno aparece como tarjeta con seña.
  - Se declara qué parte del mensaje sí puede comunicarse hoy.
  - Si el término literal es imprescindible, se usa dactilología declarada como tal.
- **Contenido y comportamiento prohibidos**:
  - Sustituir BILLETERA por BILLETES.
  - Sustituir PAGAR por una tarjeta de dinero.
  - Sustituir FOLIO REAL por PAPEL.
  - Deducir «mi derecho propietario» de una selección genérica de certificado.
  - Introducir la palabra ausente como «opción especial» sin declarar su tipo.
- **Comprobación**: configuracion

### `AC-11` — ROBAR + ESCAPAR con protagonistas distintos, edición y cancelación

- **Entrada**: En «¿Qué ocurrió?» se eligen dos acciones: ROBAR y ESCAPAR, con protagonistas distintos.
- **Modo**: ventanilla
- **Institución**: `policia`
- **Necesidad**: `denuncias`
- **Intención**: `RELATO_ABIERTO`
- **Salida esperada**:
  - Se conservan los dos hechos, cada uno con su protagonista.
  - Se aclara quién escapó.
  - Quitar o editar un hecho no borra el otro.
  - Cancelar la aclaración no registra una acción incompleta.
  - Usar una sola acción sigue siendo válido.
- **Contenido y comportamiento prohibidos**:
  - Sobrescribir la primera acción con la segunda.
  - Inventar una secuencia temporal o causal a partir del orden de selección.
  - Redactar una denuncia de robo cuando solo se seleccionó ESCAPAR.
- **Comprobación**: interfaz_pendiente

### `AC-12` — Reanudación del mismo borrador, cambio de modo y turno nuevo

- **Entrada**: Se abre una respuesta, se arma medio mensaje, se vuelve al chat y se reabre el mismo encargo; después llega un turno nuevo durante la edición.
- **Modo**: ventanilla
- **Institución**: `policia`
- **Necesidad**: `denuncias`
- **Salida esperada**:
  - Reabrir el MISMO encargo conserva el borrador.
  - Cambiar de encargo pide confirmación explícita antes de descartarlo.
  - La respuesta enviada se enlaza al turno que se tenía delante, no al que llegó después.
  - Cambiar de modo de uso no arrastra el borrador a la otra sesión.
- **Contenido y comportamiento prohibidos**:
  - Perder el borrador en silencio al reabrir el mismo encargo.
  - Asociar la respuesta a otro turno.
- **Comprobación**: interfaz_pendiente

### `AC-13` — Fin de atención seguido de otro ciudadano

- **Entrada**: Modo ventanilla. Se pulsa «Finalizar atención» y entra la siguiente persona.
- **Modo**: ventanilla
- **Institución**: `derechos_reales`
- **Necesidad**: `—`
- **Salida esperada**:
  - Mensajes, borradores, aclaraciones y resultados reproducibles de la atención anterior quedan eliminados.
  - La configuración institucional se conserva.
  - La nueva atención empieza limpia.
- **Contenido y comportamiento prohibidos**:
  - Mostrar contenido del ciudadano anterior.
  - Heredar el historial personal del propietario del dispositivo.
  - Restaurar automáticamente la conversación anterior al reabrir la app.
- **Comprobación**: interfaz_pendiente

### `AC-14` — Migración de pestañas persistidas y persistencia separada

- **Entrada**: Sesión guardada con el esquema anterior (tabIndex 0 = conversación, 1 = tarjetas, 2 = avatar) y el orden visual nuevo.
- **Modo**: cualquiera
- **Institución**: `—`
- **Necesidad**: `—`
- **Salida esperada**:
  - La sesión antigua restaura la pestaña correcta según el identificador estable, no según la posición.
  - La configuración institucional y el contenido del ciudadano se guardan en claves distintas.
  - Una sesión ilegible no impide abrir la aplicación.
- **Contenido y comportamiento prohibidos**:
  - Restaurar la pestaña por índice posicional tras reordenar la barra.
  - Guardar configuración y contenido en la misma clave.
- **Comprobación**: interfaz_pendiente

### `AC-15` — Igualdad de significado entre vista previa, texto, audio y representación semántica

- **Entrada**: Un mismo mensaje confirmado en modo personal y en modo ventanilla.
- **Modo**: cualquiera
- **Institución**: `—`
- **Necesidad**: `—`
- **Salida esperada**:
  - Vista previa, texto enviado, audio y representación intermedia corresponden a la misma versión confirmada.
  - La acción, el protagonista, la negación y la intención se conservan en ambos modos.
  - La reproducción y la revisión siguen siendo explícitas.
- **Contenido y comportamiento prohibidos**:
  - Reproducir audio automáticamente al cambiar de modo.
  - Activar el micrófono al cambiar de modo.
  - Convertir toda frase en un acta o en tercera persona por estar en ventanilla.
- **Comprobación**: interfaz_pendiente
