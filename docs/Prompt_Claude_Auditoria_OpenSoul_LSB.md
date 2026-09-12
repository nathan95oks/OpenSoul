# Prompt para auditar y corregir las tarjetas LSB de OpenSoul

Actúa como ingeniero de software responsable de auditar e implementar mejoras en OpenSoul. Analiza el código real antes de cambiarlo. Trabaja con Flutter, Riverpod, la arquitectura existente y las Lambdas Python. Necesito una implementación completa y verificable del flujo de tarjetas LSB para construir declaraciones, respuestas y preguntas precisas en español. La aplicación está destinada a personas sordas reales que se comunican durante la atención preliminar ante la policía, en Cochabamba, Bolivia, en los contextos de denuncias, consultas y trámites.

El objetivo principal es preservar exactamente lo que la persona comunica: quién interviene, qué sucede, qué objeto está involucrado, dónde, cuándo, qué conoce, qué desconoce y qué desea preguntar o solicitar. El español debe ser formal, claro y natural. La corrección gramatical nunca debe agregar hechos o resolver incertidumbres por cuenta del sistema.

Quiero que audites y modifiques el código de trabajo, con cambios revisables y pruebas. Este encargo cubre implementación y verificación local. La publicación, el despliegue en AWS y la incorporación de cambios a la rama principal quedan fuera de esta ejecución.

## 1 Fuentes y punto de partida

Repositorio: [OpenSoul](https://github.com/nathan95oks/OpenSoul).

La revisión que motiva este encargo corresponde al commit `78580befc3a1cb3469ac2b19ced747555649c993`, del 12 de septiembre de 2026. Comprueba el commit de tu copia: si cambió, confirma qué hallazgos siguen vigentes y adapta las rutas sin asumir que el código es idéntico.

Documento adjunto: `Corpus_Maestro_Unificado_LSB_v4_Auditado(2).docx`. También existe `docs/Corpus_Maestro_Unificado_LSB_v4_Auditado.md` en el repositorio. Contrasta ambos cuando estén disponibles. El corpus es un documento de trabajo con referencias y propuestas; no constituye por sí mismo una validación lingüística de toda la aplicación.

El corpus remite a los módulos oficiales M1–M4 y al II Diccionario Bilingüe LSB–Castellano de 2024. Usa los PDF originales cuando estén disponibles para verificar cada seña, su sentido y su representación visual. Si falta un PDF, registra qué no puedes comprobar y solicita ese material de manera específica; continúa las correcciones de software que no dependan de inventar una seña. Nunca afirmes haber revisado archivos o validado señas que no has podido examinar.

Mantén esta distribución de responsabilidades:

- Audio/Texto → LSB: entrada del funcionario, incluyendo sus preguntas, explicaciones e indicaciones.
- LSB → Texto/Audio: declaraciones, respuestas, solicitudes y preguntas de la persona sorda.
- Conversación: coordinación de los turnos y enlace entre pregunta y respuesta.
- Diccionario compartido: identidad y representación de los conceptos LSB; los dos módulos no necesitan aceptar el mismo tipo de entrada.

Las preguntas que guían la selección de tarjetas son controles de la interfaz. No deben convertirse automáticamente en parte de la declaración del ciudadano.

## 2 Hallazgos que debes reproducir y resolver

La aplicación usa Flutter y Riverpod. Las tarjetas proceden del repositorio de léxico, cuyo respaldo empaquetado es `assets/dictionary/official_dictionary.json`. El flujo recorre zonas del catálogo, conserva respuestas por zona, las convierte en una lista de glosas y genera texto local y remoto. El backend construye su propia oración base, utiliza Bedrock para redactar y Polly para el audio. El motor cliente elige entre la respuesta remota y su alternativa local.

Revisa estos puntos concretos:

| Parte del código | Hallazgo en la revisión inicial | Resultado requerido |
| --- | --- | --- |
| `lib/core/domain/services/context_catalog.dart` | La zona `hecho` de `denuncia_robo` mezcla ROBAR, LADRÓN, PERDER, ESCAPAR, DAÑAR y ENGAÑAR. Hay duplicados explícitos en ocho listas de zonas, incluidos BILLETES y MICRO. | Preguntas con respuestas del tipo correcto, listas únicas y ramas pertinentes. |
| `lib/features/lsb_to_text_audio/presentation/providers/cards_provider.dart` | La lista permitida se recorre sin deduplicar y se corta a 12 opciones. Una sugerencia remota puede reemplazar las opciones locales por un subconjunto. | Todas las opciones válidas deben seguir accesibles, sin repeticiones ni desapariciones inesperadas. |
| `lib/features/lsb_to_text_audio/presentation/widgets/card_grid.dart` y `suggested_gloss_panel.dart` | `CardGrid` contiene un límite inicial de seis, pero el flujo principal revisado usa `HomeScreen → NodeFlowCanvas → SuggestedGlossPanel` y muestra todas las opciones recibidas del provider. En ese flujo opera el corte previo a 12 y, si hay sugerencia remota, su subconjunto de hasta ocho. | Corregir el camino activo y distinguir componentes antiguos de los utilizados; ampliar un widget no recupera opciones descartadas por el provider. |
| `semantic_zones_provider.dart`, dentro de `presentation/providers` | Las respuestas y sus calificadores comparten `List<String>`. `appendQualifiers` elimina todo lo que sigue a la glosa editada. Los calificadores cuentan dentro de `maxPicks`; quitar una glosa no elimina necesariamente sus detalles. | Respuestas estructuradas y edición localizada, sin datos huérfanos ni eliminación de otras respuestas. |
| `presentation/widgets/qualifier_sheets.dart` | Hay teclado y calificadores básicos, pero no las ramas solicitadas para relaciones espaciales o prenda y color. El texto escrito se convierte en letras y pierde espacios y tildes. CELULAR puede abrir un mensaje sobre el número del caso. | Complementos por intención y entidad, con conservación del texto original y etiquetas correctas. |
| `lib/core/domain/services/local_sentence_assembler.dart` | Clasifica glosas mediante roles generales y patrones; puede completar verbos por contexto y agregar palabras restantes entre paréntesis. | Redacción a partir de hechos relacionados y confirmados, sin completar acciones por suposición. |
| `aws/lambda_function.py` y `lib/core/domain/services/conversation_engine.dart` | `_generation_is_safe` usa coincidencias léxicas y longitud. El cliente confía en `coverageValidated` para saltarse su propia comprobación salvo texto vacío. | Una coincidencia de palabras no debe certificar fidelidad factual ni equivalencia entre pregunta y afirmación. |
| `remote_translation_datasource.dart`, dentro de `lib/core/data/datasources` | Envía contexto y tarjetas; no transmite las relaciones por entidad, la pregunta respondida ni un acto comunicativo explícito del ciudadano. | Contrato estructurado y versionado que preserve esas relaciones en ambos motores. |
| `lib/core/domain/entities/lsb_card.dart` | El JSON contiene `source`, `audit` y `canonicalGloss`, pero el modelo no los conserva al leer y serializar. Un estado desconocido puede caer en `official`. | Conservar trazabilidad y tratar estados desconocidos sin aprobarlos automáticamente. |

En el commit revisado hay ocho contextos seleccionables y 48 zonas. La sección 12 contiene la auditoría ampliada de las 48 preguntas, sus restricciones y las correcciones por contexto. Audita todo ese recorrido, las familias de `semantic_context.dart`, la inferencia de contextos y preguntas, y los caminos de edición. No te limites a la primera pantalla de robo. Hay referencias antiguas a contextos y zonas en pruebas y resolución de contexto; distingue comportamiento deseado, código obsoleto y regresiones.

El diccionario empaquetado tiene 346 entradas sin IDs ni glosas exactas duplicadas. El apéndice maestro del DOCX contiene 303 entradas. No borres automáticamente la diferencia: hay letras, dígitos, conceptos institucionales y cambios de guiones a guiones bajos que deben reconciliarse con trazabilidad. La repetición de BILLETES y MICRO observada en las tarjetas nace en las listas de preguntas, no en entradas idénticas del diccionario empaquetado.

La revisión local del backend, sin llamar a AWS, reprodujo lo siguiente:

- PERDER y CELULAR dentro de `denuncia_robo` producen una construcción que atribuye la pérdida a otra persona y conjuga incorrectamente el verbo.
- ROBAR, CELULAR y CERCA producen una referencia genérica al lugar sin preguntar cerca de qué.
- ROBAR, CELULAR, HOMBRE, POLERA, ROJO, PANTALÓN y NEGRO atribuyen colores al hombre, incorporan la polera entre sus pertenencias robadas y dejan el pantalón como información suelta.
- DÓNDE, PRESENTAR y PAPEL, en `preguntas`, no conservan correctamente la interrogación en la oración base del backend.
- NO y TESTIGO, en `denuncia_robo`, añaden una afirmación de robo que no se encuentra en esas dos respuestas.
- El validador acepta agregar ayer y una plaza a una frase sobre un celular robado, introducir 500 bolivianos en una frase sobre billetes y transformar una afirmación en pregunta, manteniendo las mismas palabras relevantes.

Estas son comprobaciones del código local, no observaciones de una sesión de la aplicación desplegada ni de una respuesta real de Bedrock.

La suite existente de Python se ejecutó con sus dobles de AWS: 96 pruebas descubiertas, con resumen `FAILED (failures=63, errors=3)`, que incluye fallos de subpruebas. Algunas expectativas usan vocabulario anterior. Reproduce la línea base y clasifica cada problema; no elimines pruebas ni debilites verificaciones para obtener un resultado verde. Flutter y Dart no estaban disponibles en el entorno de esa revisión, por lo que no se verificaron allí la compilación ni la interfaz ejecutada.

## 3 Modelo de respuestas y navegación

Sustituye la dependencia de una bolsa de palabras por una representación de hechos y preguntas. Reutiliza y amplía las entidades existentes cuando tenga sentido; no crees un segundo sistema desconectado.

Cada respuesta debe conservar, al menos:

- ID estable de respuesta, contexto, pregunta o campo y entidad a la que pertenece.
- Concepto canónico y referencia a las tarjetas seleccionadas.
- Tipo de valor: concepto, texto literal, número, fecha, relación, desconocimiento u omisión.
- Papel semántico: hecho, objeto involucrado, persona descrita, prenda, atributo, lugar, evidencia, documento o intención.
- Respuesta padre cuando depende de otra: color de una prenda, prenda de una persona, lugar de referencia de una relación espacial.
- Negación, incertidumbre y estado de confirmación, sin equiparar ausencia de respuesta con NO.
- Texto original escrito por la persona, separado de cualquier secuencia de dactilología.

Una representación posible es un mensaje con `speechAct`, `replyToId`, contexto, hechos, personas, objetos, ubicaciones y documentos identificados. Los nombres son orientativos. Lo obligatorio es conservar las relaciones desde la selección hasta el texto, la conversación y el audio.

Configura los pasos de manera declarativa: pregunta, tipo de respuesta, opciones canónicas, selección única o múltiple, dependencias, condición de activación, regla de completitud y regreso. Evita una cadena de condiciones dispersas en widgets.

Las selecciones únicas corresponden a un atributo de una entidad, por ejemplo su estatura aproximada. La selección múltiple corresponde a conjuntos, por ejemplo varios objetos o prendas. Agregar letras o completar un color no consume cupos de objetos.

Al cambiar una respuesta padre, elimina o invalida solo los descendientes incompatibles y permite revisarlos. Conserva las otras personas, objetos y respuestas. Cancelar un complemento no debe confirmar datos parciales ni fabricar una respuesta. Una respuesta recibida después de cambiar de contexto no debe insertarse en el nuevo caso.

## 4 Reglas de las tarjetas por pregunta

### Hecho que se desea comunicar

Cambia la formulación que exige identificar un delito por una pregunta comprensible sobre lo sucedido. La persona debe poder indicar lo que sabe sin tener que clasificarlo jurídicamente.

- ROBAR puede representar la acción comunicada cuando ese es el significado escogido.
- LADRÓN es una referencia a una persona; no responde al tipo de hecho. Consérvalo en el léxico con su sentido documentado, pero no lo muestres como una acción ni lo asignes automáticamente a alguien.
- PERDER debe llevar a pérdida o extravío, o a la aclaración de que la persona desconoce qué ocurrió. Nunca debe convertirse en una afirmación de robo por haber entrado antes a ese menú.
- ESCAPAR puede aparecer como acción adicional de una persona vinculada a un hecho; necesita un sujeto y no reemplaza el hecho principal.
- DAÑAR y ENGAÑAR pertenecen a sus flujos cuando la persona los comunica. No deben agregarse a la pregunta solo para aumentar opciones.

Elegir un menú organiza la navegación; no prueba que haya ocurrido todo lo que ese menú presupone. Ofrece cambiar el motivo cuando sea necesario y distingue ese cambio de añadir un segundo hecho al relato. No descartes respuestas silenciosamente.

### Objetos involucrados

Muestra una sola opción por concepto en cada campo y sentido. Usa el diccionario canónico y aliases auditados; no fusiones objetos diferentes por tener etiquetas parecidas.

Diferencia el objeto robado, el objeto perdido, la pertenencia que llevaba otra persona y el soporte de una evidencia. Una mochila o un celular pueden aparecer legítimamente en diferentes papeles. Deduplicar opciones no debe impedir que se mencionen dos mochilas distintas ni que una misma glosa se use para dos personas.

MICRO y TRUFI pueden ser pertinentes como transporte o como vehículos sustraídos. Para el robo de vehículo, abre una rama explícita y permite identificarlo sin exigir una placa desconocida. Para un hecho ocurrido dentro de un micro, consérvalo como ubicación o medio de transporte, nunca como objeto robado por defecto.

Ofrece añadir otro objeto con detalle. Cantidad y monto deben capturarse con su unidad cuando corresponda; no supongas una moneda ni una cifra. CELULAR debe pedir un detalle coherente con su papel: contacto, descripción del aparato o dato que la persona quiera aportar; no el número del caso por una regla genérica.

## 5 Ubicación con referencia y teclado

Cuando se seleccione CERCA, LEJOS, DENTRO, FUERA o AL LADO, abre inmediatamente un apartado de complemento. Incluye una pregunta específica como «¿Cerca de qué lugar?» y opciones claras como «Mi casa», un lugar previamente indicado y «Otro lugar», además del acceso al teclado.

Si se elige Otro lugar, activa el teclado para escribir la referencia exacta. También permite detallar Mi casa si la persona desea hacerlo. El usuario debe poder escribir nombres con espacios, tildes, números y signos necesarios para una dirección. No conviertas el campo de ubicación en una lista de letras que luego haya que reconstruir para redactar.

Guarda por separado relación, tipo de referencia, nombre literal, dirección opcional y vínculo con el hecho. Si hay un lugar principal y una referencia, preserva ambos, por ejemplo calle indicada y cercanía a un mercado.

Ejemplos de redacción, exclusivamente si esos datos fueron aportados:

- CERCA + Mi casa: «Ocurrió cerca de mi casa».
- FUERA + Otro lugar + Mercado Calatayud: «Ocurrió fuera del Mercado Calatayud».
- DENTRO + micro: «Ocurrió dentro de un micro».

No completes CERCA con una referencia vaga inventada. Si falta la referencia, conserva ese campo como pendiente y ofrece completarlo, quitarlo o señalar que no lo recuerda. Permite guardar un borrador y comunicar otros datos completos; no presentes una cláusula incompleta como una declaración confirmada.

## 6 Descripción de personas y prendas

Crea una entidad por persona descrita, vinculada a su papel en el relato: persona observada o involucrada, testigo u otro papel que el ciudadano haya indicado. Describe a alguien sin atribuirle automáticamente la autoría de un hecho.

El recorrido debe permitir:

1. Indicar hombre, mujer u otra descripción disponible, o señalar que no pudo identificar ese rasgo.
2. Abrir apartados independientes de edad aproximada, complexión y estatura, todos omitibles si no los conoce.
3. Seleccionar las prendas o accesorios que recuerda.
4. Al elegir POLERA, PANTALÓN, GORRA u otra prenda, abrir su color y detalle, con posibilidad de desconocerlos.
5. Agregar otra prenda o persona y revisar el conjunto.

Puedes mostrar etiquetas respetuosas como complexión delgada o robusta donde correspondan al sentido de la seña documentada, conservando la identidad léxica original. No infieras identidad, edad exacta ni otros atributos a partir de una selección distinta.

Cada color debe pertenecer a una prenda concreta. Por ejemplo, una persona puede llevar una polera roja y un pantalón negro; otra puede llevar una polera azul. Deben ser tres relaciones independientes. Cambiar el pantalón negro por azul no cambia ninguna polera.

Si la persona dijo que lo vio, una salida posible es «Vi a un hombre alto que llevaba una polera roja y un pantalón negro». Si además indicó que ese hombre le robó el celular, puede redactarse esa relación. Sin esa atribución explícita, no la agregues.

No exijas describir a una persona desconocida para continuar. Distingue «No lo vi», «No lo recuerdo», «No lo sé» y «Prefiero omitirlo». Estos son estados diferentes y no deben transformarse en características ni afirmaciones negativas equivalentes.

## 7 Documentos y trámites

PAPEL debe abrir un apartado para precisar qué documento se quiere mencionar. El tipo de documento y el trámite o acción que la persona necesita son campos diferentes.

Ofrece tipos sustentados por el corpus, como certificado, factura, fotocopia o resolución, y una opción para escribir otro tipo. Para documento de identidad, verifica cómo se representa el concepto en las fuentes; no declares una nueva seña directa solo porque la etiqueta en español sea útil.

Pregunta por la acción únicamente cuando no esté ya definida: lo perdió, se lo robaron, lo necesita, lo recibió, quiere presentarlo, obtener una copia o consultar sobre él. Si corresponde, permite precisar de qué certificado, resolución o trámite se trata. No interpretes PAPEL como documento de identidad por defecto.

Ejemplos de salidas condicionadas a datos aportados:

- «Perdí mi documento de identidad».
- «Necesito una fotocopia de la resolución».
- «¿Qué documento debo presentar para este trámite?».

No inventes requisitos, competencias institucionales ni procedimientos administrativos a partir del nombre del documento. La app comunica la solicitud del ciudadano.

## 8 Declaraciones respuestas preguntas y generación de texto

Permite que el ciudadano elija si quiere relatar, responder, preguntar o solicitar algo dentro de denuncias, consultas y trámites. No hagas depender todas las preguntas de una pestaña separada. Las preguntas frecuentes deben ser intenciones revisadas con campos editables; también debe poder construir preguntas adicionales con las opciones disponibles.

Conserva el acto comunicativo de extremo a extremo. Una pregunta como «¿Dónde puedo presentar este documento?» no puede convertirse en la afirmación de que ya lo presentó. Una respuesta breve sobre lugar o testigos no implica que esté iniciando una nueva denuncia.

Cuando exista una pregunta previa del funcionario, conserva `replyToId` y usa esa pregunta para identificar qué se responde. Las presuposiciones de la pregunta no pasan a ser hechos declarados. Si se preguntó «¿A qué hora y dónde?», recoge ambos campos en un solo turno, con acceso a añadir otros datos. No obligues a completar todo el cuestionario.

Genera primero texto determinista desde el modelo estructurado. El resultado debe conservar:

- Acciones y participantes con su relación exacta.
- Objetos con propietario o papel solo cuando se conozca.
- Asociación entre personas, prendas y atributos.
- Ubicación, referencias, fechas, horas, cantidades y unidades.
- Negaciones con alcance propio: no conocer a una persona es distinto de negar que existan testigos.
- Incertidumbre, aproximaciones, alternativas y omisiones explícitas.
- Secuencia de varios hechos cuando el usuario la haya indicado.
- Intención y perspectiva del ciudadano, sin convertirlo siempre en víctima, autor o testigo.

No deduzcas el tiempo verbal solo del contexto. Debe poder relatar un hecho pasado, una situación que continúa y una necesidad futura sin inventar fechas. No inventes conectores de causalidad u orden temporal. El registro formal no exige vocabulario jurídico que el ciudadano no haya comunicado.

Elimina la práctica de añadir glosas sueltas entre paréntesis o mediante frases genéricas para aparentar cobertura. Si una respuesta carece de relación semántica, solicita una aclaración breve y localizada o mantenla pendiente.

La representación estructurada debe viajar al backend. Versiona el contrato y define una migración compatible de los mensajes y clientes anteriores. Revisa también los datos almacenados de conversaciones, el diccionario remoto y las claves de caché: relaciones, acto comunicativo, valores literales y versiones del generador deben distinguir resultados diferentes. Dos mensajes con las mismas glosas y diferentes relaciones no pueden compartir una salida cacheada.

Bedrock, si se conserva en este camino, puede mejorar la redacción dentro de restricciones verificables. No basta pedirle que sea preciso. Una segunda opinión del mismo modelo tampoco constituye validación independiente de los hechos.

Para esta versión prioriza un generador determinista con cobertura explícita de los campos. Solo acepta refinamiento si puedes demostrar que conserva los hechos, sus relaciones, polaridad y acto comunicativo, y que no agrega contenido. Si no puedes garantizarlo con el diseño implementado, usa el texto determinista para esa salida y registra la limitación. No marques `coverageValidated` por coincidencia de raíces, longitud o aparición de palabras.

El audio debe corresponder exactamente al texto vigente que la persona confirma. Antes de comunicarlo, ofrece revisión accesible, corrección por campo y confirmación; no reproduzcas automáticamente una declaración recién generada. La revisión no puede depender exclusivamente de leer español. Usa las representaciones LSB verificadas disponibles y un resumen visual de las selecciones. No uses una retraducción no validada como única prueba de equivalencia.

## 9 Diccionario y accesibilidad lingüística

Conserva una fuente canónica de conceptos y señas. Separa:

- Identificador estable, glosa canónica y sentido.
- Aliases de entrada y etiqueta comprensible en español.
- Fuente, edición, página o entrada y estado de revisión.
- Seña directa documentada, composición validada, representación por deletreo y concepto pendiente de representación.
- Recurso visual, versión, disponibilidad y revisión lingüística o regional.

No uses una composición provisional como una seña oficial ni inventes animaciones o imágenes. El propio corpus distingue propuestas de representaciones documentadas y señala que la seña FISCAL de sentido escolar no debe reutilizarse para el funcionario jurídico.

No trates la LSB como español representado palabra por palabra ni impongas un orden sintáctico único a todas las secuencias. Que las señas individuales estén documentadas no valida automáticamente una oración, una composición o su ejecución por el avatar. Distingue la precisión del texto español de la comprensión y naturalidad de las representaciones LSB completas, que requieren validación con señantes.

Los botones de navegación, las intenciones de consulta y las etiquetas auxiliares no se convierten automáticamente en nuevas entradas del diccionario. Si el español necesita una etiqueta más clara, conserva separada la equivalencia LSB que realmente está documentada.

Resuelve tildes, guiones, guiones bajos y aliases de manera consistente entre catálogo, tarjetas, ensambladores, backend y recursos visuales, preservando el sentido y la letra Ñ. No cambies IDs ni nombres de archivos existentes sin una migración revisada. La clave de búsqueda puede normalizarse; el texto literal introducido debe conservarse.

Audita los recursos de las tarjetas. En la copia revisada, `iconUrl` está vacío en todas las entradas del JSON empaquetado y las imágenes pueden resolverse desde una URL base configurada. Esto no demuestra que las imágenes remotas falten: comprueba su disponibilidad real cuando tengas acceso. Un icono de camiseta o de ubicación no constituye una seña LSB validada. Si falta la representación, comunícalo sin atribuirle oficialidad al sustituto.

No establezcas un máximo arbitrario de seis glosas por pregunta o de una palabra por respuesta. Usa grupos, desplazamiento o paginación según el campo. Mantén límites técnicos razonables para el tamaño total de entrada, separados de la cantidad de conceptos visibles y de las letras de un detalle.

Las sugerencias automáticas no pueden agregar opciones incompatibles, cambiar el sentido de la pregunta ni ocultar permanentemente respuestas válidas. Una vez que la persona está leyendo o seleccionando, conserva el orden del paso. No prohíbas globalmente una glosa por haberla usado en otra entidad.

Incluye botones claros para volver, corregir, añadir, no saber, omitir y terminar. Conserva tamaño legible, controles táctiles adecuados y adaptación al teclado y a pantallas pequeñas. El color debe tener también una etiqueta; las señas o imágenes deben poder inspeccionarse con claridad.

## 10 Pruebas de aceptación

Implementa pruebas significativas del modelo, providers, widgets, serialización y backend. Además de las regresiones existentes pertinentes, verifica estos escenarios con datos ficticios:

| Caso | Comportamiento que debe demostrarse |
| --- | --- |
| Listas de todas las preguntas | No hay opciones duplicadas por concepto y sentido; todas las opciones llevan a un campo compatible. |
| Elección de PERDER desde el recorrido de robo | Se aclara o cambia el motivo y la salida expresa pérdida sin atribuir robo ni autor. |
| CERCA, FUERA, DENTRO o LEJOS | Se abre el complemento y la referencia queda vinculada; Otro lugar permite escribirla. |
| Nombre Mercado Calatayud y dirección con números | Texto y espacios se conservan en estado, envío, generación y corrección. |
| Cancelar una referencia espacial | No se introduce una referencia inventada ni queda un detalle confirmado sin padre. |
| Polera roja y pantalón negro de la persona 1 | Cada color modifica su prenda; ninguna prenda pasa a objeto robado. |
| Segunda persona con polera azul | Los atributos de ambas personas permanecen separados. |
| Mochila robada y mochila que llevaba otra persona | Son entidades con papeles distintos aunque compartan concepto léxico. |
| Cambiar o quitar una prenda ya detallada | Solo se modifican esa prenda y sus atributos; las demás respuestas se conservan. |
| PAPEL seguido de tipo y acción | Distingue documento perdido, documento sustraído, documento requerido y consulta sobre él. |
| MICRO como lugar y MICRO como vehículo robado | Produce dos relaciones diferentes y no comparte indebidamente la caché. |
| No conoce a una persona y sí hay testigos | Conserva ambas polaridades sin trasladar la negación. |
| No sabe si hay testigos | No redacta que no hay testigos. |
| Pregunta del ciudadano | Mantiene interrogación, intención, tema y destinatario, sin afirmar el hecho preguntado. |
| Respuesta a una pregunta del funcionario | Conserva el vínculo con el turno y solo comunica lo respondido. |
| Refinamiento con una fecha o plaza nueva | Se rechaza aunque conserve todas las palabras originales. |
| Refinamiento que agrega 500 bolivianos | Se rechaza si no existe un monto declarado. |
| Refinamiento que cambia afirmación por pregunta | Se rechaza aunque conserve los conceptos. |
| Respuesta remota con `coverageValidated` | El indicador no permite eludir la verificación factual del contrato. |
| Caída de red o Bedrock | El texto local sigue siendo preciso y editable; no se recupera una redacción de otro borrador. |
| Corrección después de generar | El texto y audio anteriores quedan invalidados; se confirma y reproduce la versión actual. |
| Teclado abierto y cambio de contexto | No se introducen detalles tardíos en otro caso ni se pierde contenido de entidades ajenas. |
| Serialización del diccionario | Fuente, estado de revisión e identidad canónica sobreviven a lectura, caché y escritura. |
| Más opciones de las que caben en pantalla | Todas las pertinentes son accesibles sin corte silencioso. |
| Cambio entre módulos y conversación | Se conserva el aislamiento de sesiones y las fronteras arquitectónicas existentes. |

Agrega pruebas del recorrido completo para al menos una denuncia, una consulta y un trámite, incluyendo edición y confirmación del resultado. Comprueba que los resultados locales y remotos son semánticamente equivalentes aunque su redacción pueda variar.

Usa datos ficticios en pruebas y evita registrar declaraciones completas, identificadores personales o texto libre en logs de diagnóstico. La Lambda actual registra tarjetas y oraciones; revisa esos puntos al modificar el flujo para usuarios reales. Conserva las protecciones de entrada y trata los campos escritos como datos, nunca como instrucciones para el modelo.

Ejecuta los comandos apropiados del repositorio, incluyendo análisis y pruebas Flutter cuando tengas el SDK, y `python3 -m unittest discover -s aws/tests -v`. Informa fallos previos, regresiones introducidas y pruebas no ejecutadas. No declares que una compilación correcta demuestra validación lingüística.

## 11 Orden de implementación y entrega

1. Lee las instrucciones del repositorio y comprueba el estado de trabajo. Identifica la línea base y las rutas reales de la entrada a la salida.
2. Presenta un diagnóstico breve con los problemas reproducidos y diseña el modelo de respuestas, las reglas por campo y el contrato con el backend. Continúa con la implementación sin detenerte en un plan genérico.
3. Implementa el modelo estructurado, navegación condicional, edición de dependencias y preservación de texto literal.
4. Revisa todas las preguntas de denuncias, consultas y trámites; corrige duplicados y compatibilidad semántica. Amplía lo que sea necesario dentro de este alcance, sin convertir la aplicación en un catálogo de trámites ajenos.
5. Actualiza generación local, contrato remoto, backend, caché, conservación del acto comunicativo, revisión y reproducción de audio.
6. Integra trazabilidad y disponibilidad de recursos LSB; deja identificadas las representaciones pendientes que requieran los PDF originales o validación humana.
7. Ejecuta las pruebas y verifica los recorridos completos con edición y fallos de red simulados.

Entrega cambios concretos, un resumen de archivos modificados y su propósito, la matriz final de preguntas y ramas, ejemplos de entrada estructurada y salida, resultados de pruebas y limitaciones comprobadas. Distingue lo que quedó implementado de lo que requiere validación de señantes de Cochabamba, intérpretes y usuarios del entorno de atención.

Mi criterio de éxito es que cada elección conserve su significado y relación durante todo el flujo. Una declaración larga puede usar varias oraciones, y una pregunta puede ser breve. En ambos casos, el sistema debe comunicar únicamente lo que la persona quiso expresar y permitirle revisarlo y corregirlo antes de transmitirlo.

## 12 Auditoría ampliada de los ocho contextos

Esta ampliación revisó las 48 preguntas existentes en el catálogo del mismo commit, sus opciones, límites de selección, dependencias, ruta de pantalla activa, preparación de la entrada y funciones de generación. Se ejecutaron 407 sondas de reconocimiento y generación con una opción única por zona, además de 16 combinaciones de diagnóstico, usando el backend Python y sus dobles de AWS. Las sondas incluyen opciones declaradas que el corte de pantalla puede dejar inaccesibles y los marcadores que agrega el cliente.

Estos recorridos son una auditoría del código y diagnósticos locales. No son 407 pruebas de aceptación aprobadas ni una exploración exhaustiva de todas las combinaciones. No se ejecutó Flutter, no se consultó Bedrock ni se verificaron los recursos remotos o la aplicación desplegada. Las correcciones propuestas aún deben implementarse y validarse.

La columna Tope indica el `maxPicks` actual de cada pregunta, cuyo valor predeterminado es 1. Permitir más selecciones solo resuelve una parte del problema: cada selección necesita conservar su campo y relación.
### 12 1 Denunciar robo

Contexto `denuncia_robo`. Se revisaron sus 15 preguntas.

| Zona o pregunta | Tope | Hallazgo | Corrección requerida |
| --- | --- | --- | --- |
| `hecho` | 1 | Mezcla acción, persona, pérdida y huida; el contexto puede imponer robo antes de aclarar qué ocurrió. | Separar hecho, participantes y acciones posteriores. Permitir pérdida o desconocimiento sin atribuir robo. |
| `objetos` | 3 | Repite BILLETES y MICRO; incluye vehículos sin precisar su papel. El corte de 12 deja fuera CHAMARRA, GORRA y LENTES. | Deduplicar opciones; identificar cada bien y abrir subtipos. Separar vehículos sustraídos y transporte usado como ubicación. |
| `persona` | 3 | Mezcla persona, edad, complexión, estatura, prendas y colores en tres selecciones. Varios detalles quedan tras el corte de 12. | Una entidad por persona, con apartados de descripción y prendas; cada atributo conserva su dueño. |
| `conocimiento` | 1 | La pregunta admite sí/no, pero mezcla vínculos y VER; repite AMIGO y PAREJA y permite una sola selección. | Capturar si conoce a esa persona y, después, el vínculo o cómo la identifica. Vincular la negación a ese campo. |
| `apariencia` | 1 | Repite prácticamente la descripción de persona, pero solo admite una selección y también recorta detalles. | Reutilizar la misma persona ya descrita; permitir editar o ampliar atributos sin crear otra persona ni otra lista suelta. |
| `lugar` | 1 | Una selección mezcla lugares y relaciones espaciales. AL_LADO queda fuera del corte de 12 y las relaciones no piden referencia. | Lugar principal y referencia relacionada, con selección conocida o teclado; dirección opcional y texto literal. |
| `tiempo` | 1 | Mezcla fecha, momento del día y duración en una selección. DÍA aparece acentuado en el catálogo, pero el selector temporal usa DIA. | Separar fecha, hora, momento aproximado y tiempo transcurrido. Unificar IDs y tratar fecha desconocida de forma explícita. |
| `testigos` | 1 | Mezcla existencia, persona, cantidad y acción en una respuesta. SÍ o NO aislados pierden el vínculo con la existencia de testigos. | Existencia sí/no/no sabe, seguida de cantidad e identificación opcionales. No convertir un número aislado en dactilología sin significado. |
| `pruebas` | 1 | Pregunta por posesión, pero ofrece objetos y acciones sin sí/no; comparte función con evidencia y testigos. | Unificar la captura de evidencias por entidad, tipo y disponibilidad, con acciones posteriores separadas. |
| `evidencia` | 3 | Agrupa testigos, documentos, acciones y soportes en tres selecciones. Añade PRUEBA_MARCADOR, no reconocido por el analizador Python actual. | Transmitir evidencia como campo estructurado; separar testimonio y soportes, y eliminar la dependencia de un marcador textual sin contrato. |
| `emergencia` | 1 | Una misma pregunta combina estar herido y necesitar atención; HOSPITAL no distingue atención recibida de atención solicitada. | Dos respuestas separadas, opcionales y sin diagnóstico automático: estado comunicado y ayuda solicitada o recibida. |
| `denuncia` | 1 | Repite PRESENTAR y mezcla sí/no, intención y tiempo. NO no conserva aquí a qué voluntad se refiere. | Guardar la voluntad de presentar denuncia como campo propio; no inferirla de entrar al menú o elegir AHORA. |
| `apoyo_legal` | 1 | Mezcla respuesta sí/no, abogado, intérprete, instituciones y gratuidad en una selección. | Separar necesidad de apoyo, tipo de apoyo y consulta sobre disponibilidad o costo. No asumir que un servicio fue prestado. |
| `institucion` | 1 | Mezcla instituciones y profesionales bajo una pregunta sobre autoridad receptora. | Distinguir destinatario de la comunicación y persona de apoyo. No deducir competencias institucionales desde una glosa. |
| `cantidad` | 1 | Solo contiene 1–9 y depende de cadenas temporales; el recuento de pasos también incluye esta zona aunque la navegación la salte. | Cantidad tipada con unidad y teclado; los pasos alcanzables y el indicador de finalización deben usar las mismas reglas. |

Además de corregir las 15 zonas, distinguir bien perdido, sustraído, llevado por otra persona y aportado como evidencia. La descripción de persona no debe duplicarse entre persona y apariencia. Las decisiones sobre denuncia, apoyo y testigos requieren campos de polaridad propios.

### 12 2 Denunciar violencia

Contexto `violencia`. Se revisaron sus 7 preguntas.

| Zona o pregunta | Tope | Hallazgo | Corrección requerida |
| --- | --- | --- | --- |
| `hecho` | 1 | Admite un solo término y la pregunta presupone el papel de persona afectada. No distingue relato propio, observación o consulta. | Registrar el papel del ciudadano y la acción comunicada; permitir más de un hecho relacionado, sin agregar categorías jurídicas. |
| `persona` | 2 | PAREJA y PARIENTE están repetidos. Se mezclan vínculo, género y edad en dos selecciones. | Separar vínculo, identificación y descripción; permitir desconocimiento. No tratar dos referencias a pareja como dos personas. |
| `salud_urgencia` | 3 | Combina estado físico, parte del cuerpo, atención médica, documentación y pedido de ayuda en tres selecciones. | Campos separados para lo que la persona informa, cuándo ocurrió y si pide o recibió atención; documento médico con tipo confirmado. |
| `emocion_riesgo` | 1 | Permite una sola palabra, aunque expresiones como miedo de volver a casa o pedir protección para un hijo requieren relaciones. | Relacionar emoción o necesidad con su motivo y persona destinataria; nunca atribuir a otra persona la necesidad expresada. |
| `tiempo` | 1 | Fecha y frecuencia compiten por una sola selección. Algunas formas acentuadas de frecuencia no se reconocen en Python. | Guardar momento, repetición y continuidad por separado; normalizar aliases sin perder su significado. |
| `evidencia` | 3 | Mezcla existencia de certificado, emisor, mensajes, conservación y testigos; no permite contestar claramente que no tiene esos elementos. | Evidencia por tipo y disponibilidad; emisor del documento, conservación y ofrecimiento son campos distintos. Resolver el marcador compartido. |
| `institucion` | 1 | La pregunta pide una decisión sobre asistencia; las opciones mezclan destinos, profesionales, gratuidad y asistencia genérica. | Capturar qué ayuda solicita y, si la conoce, a quién se dirige. Ofrecer no saber o no necesitar sin bloquear el relato. |

El recorrido carece de una zona de lugar del hecho y de campos explícitos para diferenciar lo ocurrido antes de lo que continúa. Incorporarlos como detalles opcionales pertinentes. La descripción y el vínculo de cada persona, el estado comunicado, la atención recibida y la ayuda solicitada deben quedar separados.

### 12 3 Amenazas digitales

Contexto `amenaza_digital`. Se revisaron sus 4 preguntas.

| Zona o pregunta | Tope | Hallazgo | Corrección requerida |
| --- | --- | --- | --- |
| `hecho` | 1 | La pregunta habla del tipo de mensaje, pero ofrece también dispositivo, canal, envío, recepción y continuidad en una sola selección. | Separar contenido o acción comunicada, canal, dirección del mensaje y si continúa. Permitir texto literal opcional sin interpretarlo como instrucciones. |
| `persona` | 1 | Repite PAREJA y mezcla identidad, vínculo, reconocimiento y CELULAR; no distingue un número conocido de una persona identificada. | Remitente con identidad conocida, supuesta o desconocida; número o cuenta como dato independiente, nunca como prueba automática de identidad. |
| `evidencia` | 3 | Fotografía, dispositivo, mensajes, conservación y posibilidad de mostrarlos comparten tres cupos. El marcador de evidencia llega como desconocido al backend. | Separar mensaje, captura y dispositivo que lo contiene; conservar disponibilidad y acción de mostrar. No convertir el celular en objeto robado. |
| `institucion` | 1 | Se pregunta si desea presentar mensajes, pero solo se ofrecen instituciones o profesionales; no hay una respuesta directa a esa decisión. | Primero voluntad de presentar los elementos; luego destino opcional. Separar ambos campos y admitir sí/no/no sabe. |

Faltan campos propios de fecha, hora y continuidad, contenido opcional del mensaje y contacto o cuenta remitente. La conservación de una captura no prueba quién envió el mensaje; registrar solo la atribución que la persona conoce o supone.

### 12 4 Engaño con dinero

Contexto `engano_dinero`. Se revisaron sus 5 preguntas.

| Zona o pregunta | Tope | Hallazgo | Corrección requerida |
| --- | --- | --- | --- |
| `hecho` | 1 | Repite BILLETES y mezcla engaño, entrega, envío y pérdida. No basta para explicar qué acuerdo existía y qué sucedió. | Capturar acción y motivo del relato; permitir explicar el acuerdo mediante conceptos disponibles y detalle escrito opcional, sin inventarlo. |
| `medio_banco` | 1 | Confunde dinero, banco, dispositivo, canal y escribir. BANCO puede redactarse como lugar aunque se seleccionó como medio de envío. | Guardar forma de entrega, entidad financiera y canal por separado. No inferir dónde estaba la persona ni confirmar un pago que solo consulta. |
| `persona` | 1 | La pregunta se refiere a quien recibió el dinero, pero NOMBRE abre el teclado para el nombre propio del ciudadano; CELULAR muestra una etiqueta sobre el caso. | Vincular nombre y contacto a la persona receptora; preguntar cada dato por separado y permitir identificador desconocido. |
| `comprobante` | 3 | Mezcla documento, banco emisor, factura, registro de mensajes y acciones. No hay una respuesta explícita de falta de comprobante. | Tipo de constancia, emisor o referencia, disponibilidad y acción de aportar como campos distintos; aclarar si PAPEL es comprobante bancario. |
| `institucion` | 1 | Se pregunta por voluntad de denunciar, pero las opciones solo nombran instituciones o abogado. | Guardar la intención de denunciar y el destinatario como respuestas diferentes; no convertir elegir un abogado en consentimiento de denuncia. |

Faltan campos de monto, moneda, fecha y hora, identificación o referencia de la operación y detalle de la entrega o acuerdo. No inferir lugar desde el nombre del banco ni atribuir al ciudadano el nombre de la persona receptora.

### 12 5 Consultar trámite

Contexto `seguimiento`. Se revisaron sus 4 preguntas.

| Zona o pregunta | Tope | Hallazgo | Corrección requerida |
| --- | --- | --- | --- |
| `tramite` | 1 | Mezcla tema, documento, acción y estado. Una selección no distingue preguntar si terminó de afirmar que terminó. | Elegir intención y tema; añadir referencia de caso o documento si se conoce. Mantener estado interrogado separado de estado confirmado. |
| `accion` | 1 | Contiene NOMBRE como si fuera acción y no solicita siempre el objeto de presentar, leer o comprender. | Acción con su destinatario u objeto; pedir repetición o aclaración cuando esa sea la intención. No interpretar escribir el nombre como firma validada. |
| `institucion_autoridad` | 1 | Repite FISCALIA y mezcla funcionarios, instituciones, gratuidad e intérprete. | Separar persona, dependencia y apoyo solicitado. No fusionar fiscal y Fiscalía por compartir una etiqueta o alias. |
| `tiempo` | 1 | Ofrece FECHA y unidades temporales, pero no tiene cadena de cantidad ni selector de fecha; tampoco diferencia una cita conocida de preguntar cuándo volver. | Modo fecha/hora comunicada o consulta de fecha desconocida; selector adecuado, precisión e incertidumbre explícitas. |

La familia Consultas contiene únicamente este contexto de cuatro zonas. Falta diferenciar consultar estado, pedir copia, entregar documentación, preguntar por retorno y aclarar una comunicación recibida. Añadir solo subflujos pertinentes al alcance preliminar y conservar las referencias que el ciudadano realmente proporcione.

### 12 6 Declaración y testimonio

Contexto `otro`. Se revisaron sus 3 preguntas.

| Zona o pregunta | Tope | Hallazgo | Corrección requerida |
| --- | --- | --- | --- |
| `relato` | 1 | Ofrece verbos de comunicación y conceptos de testigo; no ofrece la acción del hecho que se pretende contar. Una selección no construye el relato. | Separar observar, relatar, agregar o corregir; después abrir hechos y circunstancias. No afirmar que vio todo por elegir TESTIGO o NARRAR. |
| `persona` | 1 | Mezcla persona, edad, LADRÓN y conocimiento en una selección. No distingue a quien actúa de quien resulta afectado. | Entidades con papeles explícitos: persona observada, participante y persona afectada, si se conocen; identidad y descripción por separado. |
| `acceso` | 1 | Combina lengua, lectura, velocidad, gratitud y conformidad. La conformidad puede confundirse con aceptación del contenido completo. | Peticiones de comunicación y comprensión separadas; señalar exactamente qué texto confirma y permitir desacuerdo o corrección. |

Este contexto tiene únicamente relato, persona y acceso. Faltan hecho observado, lugar, tiempo, objeto, persona afectada y límites de lo visto o sabido. Debe permitir una declaración general o una corrección sin afirmar automáticamente que el ciudadano fue testigo presencial de todo.

### 12 7 Mis datos

Contexto `identificacion`. Se revisaron sus 4 preguntas.

| Zona o pregunta | Tope | Hallazgo | Corrección requerida |
| --- | --- | --- | --- |
| `identidad` | 3 | NOMBRE está duplicado; identificación, lectura y necesidad de intérprete compiten por tres cupos. No hay un campo de apellido separado. | Nombre y apellidos como datos literales, documento con tipo y número, y preferencias de comunicación independientes. No deducir otros datos personales. |
| `contacto` | 2 | Número, dirección, canal escrito y actualización comparten dos selecciones. CELULAR puede pedir número de caso y DIRECCIÓN no abre un detalle específico. | Teléfono y dirección con teclado apropiado, canal preferido y acción de actualizar vinculada al dato correcto. |
| `acompanante` | 1 | No hay una respuesta inequívoca para haber llegado solo. ACOMPAÑAR, familiar y 1 compiten por una sola selección. | Solo/acompañado/no indica, seguido del vínculo o identificación opcional. Permitir varios acompañantes sin convertir el número 1 en otra afirmación. |
| `edad` | 1 | Existe teclado para EDAD, pero JOVEN y ADULTO son aproximaciones sin un estado formal de precisión. | Distinguir edad exacta y aproximación declarada; validación del número sin inferir fecha de nacimiento ni cambiar quién tiene esa edad. |

La familia Trámites conduce exclusivamente a Mis datos. Eso no cubre por sí solo pérdida o necesidad de documentos, entrega de constancias o solicitud de copias. El modelo incluye código para contextos antiguos como perdida y tramite_id, pero no aparecen como contextos seleccionables actuales. Definir explícitamente los subflujos que requiere el alcance, con una migración coherente.

### 12 8 Preguntas

Contexto `preguntas`. Se revisaron sus 6 preguntas.

| Zona o pregunta | Tope | Hallazgo | Corrección requerida |
| --- | --- | --- | --- |
| `interrogativa` | 1 | Solo ofrece interrogativos; las preguntas de sí/no, permiso, posibilidad o disponibilidad no tienen una entrada equivalente. | Intenciones interrogativas completas con campos: ubicación, identidad, momento, cantidad, permiso, disponibilidad y aclaración, sustentadas en el corpus. |
| `lugar_pregunta` | 1 | La pregunta sobre ubicación se recorre como otra zona aunque el usuario haya elegido preguntar quién o cuándo. | Activar solo si el lugar es objeto de la pregunta o un complemento pertinente; separar destino, ubicación de una dependencia y lugar del hecho. |
| `persona_pregunta` | 1 | La pregunta presupone querer hablar con alguien, pero elegir QUIÉN podría significar quién recibe o quién investiga. Incluye FISCALIA como persona. | Destinatario o participante asociado a una acción específica; institución y profesional conservan identidades distintas. |
| `tema_pregunta` | 1 | Mezcla proceso, documento, objeto y evidencia sin pedir la acción requerida para relacionarlos. | Tema tipado y acción de preguntar: presentar, recibir, consultar, traer u otra intención documentada. No generar una necesidad por defecto. |
| `tiempo_pregunta` | 1 | Una selección mezcla acción, fecha conocida y duración. Preguntar cuánto esperar no requiere que el ciudadano invente cuántos días. | Separar pregunta de tiempo desconocido y dato temporal aportado; activar cantidad solo cuando el usuario realmente declara una. |
| `cantidad_pregunta` | 1 | Ofrece 1–9 incluso cuando la cantidad es precisamente lo que se pregunta; no garantiza la relación entre número y unidad. | Distinguir variable interrogada de cantidad conocida; vincular unidad, permitir otros números y mantener la cadena fuera de pasos irrelevantes. |

La lista separada de interrogativos no cubre el banco de preguntas ciudadanas del corpus. Integrar intenciones de pregunta dentro de los tres contextos principales, mantener preguntas abiertas y cerradas, y conservar el acto interrogativo en el turno, la serialización y ambos motores.

### 12 9 Problemas comunes confirmados en la ampliación

1. **El límite de seis no pertenece al camino principal actual.** El flujo activo usa `SuggestedGlossPanel` y presenta lo que recibe de `dynamicCardsProvider`. El corte relevante ocurre a 12 opciones en el provider; una sugerencia remota puede reducirlas a ocho. Hay código antiguo de `CardGrid` con límite de seis, pero no se encontró una instancia suya en el flujo principal. Revisa las referencias antes de modificar un componente que no esté en uso.
2. **Se pierden glosas válidas por discrepancias de representación.** El cliente envía formas como DÓNDE, CUÁNDO, POLICÍA, RESOLUCIÓN y DÍA; el analizador Python busca claves exactas sin la normalización de acentos que realiza el motor Dart. Las sondas detectaron glosas no reconocidas en los ocho contextos. Algunas, como COMPRENDER, también requieren reconciliar el vocabulario, no solo quitar tildes. Una lista permitida que existe en el JSON no garantiza que el generador entienda sus entradas.
3. **El marcador de evidencia no tiene paridad.** `orderedGlossesMarked` antepone `PRUEBA_MARCADOR` en cuatro zonas: evidencia de robo, violencia y amenazas digitales, y comprobante de engaño con dinero. El analizador Python lo devuelve como desconocido y puede incorporarlo al texto. Debe reemplazarse por una estructura reconocida o una migración explícita, sin filtrarlo perdiendo el papel de la evidencia.
4. **El contexto puede cambiar por palabras auxiliares.** `resolveAssemblerContext` puede resolver NOMBRE o PAPEL como identificación, aunque pertenezcan a otra persona o a un trámite. AMENAZAR puede dirigir el motor local a violencia desde amenazas digitales. El backend sigue recibiendo el contexto original. Es necesario conservar intención y campos explícitos y verificar paridad de la resolución entre cliente y servidor.
5. **Las zonas opcionales no son verdaderas ramas condicionales.** El motor puntúa todas las zonas; `optional` reduce prioridad y no constituye una condición de exclusión. Las preguntas de lugar, persona o tiempo pueden aparecer aunque no pertenezcan a la intención escogida. En los recorridos con cantidad encadenada, `hasNextQuestion` cuenta zonas que `goToNextZone` puede saltarse. Define una lista única de pasos alcanzables para navegar, contar progreso y finalizar.
6. **La inferencia no cubre todos los nombres de campos.** `ZoneInferenceEngine` usa destinos como emergencia o conocimiento, mientras otros contextos usan salud_urgencia o persona. Su alternativa busca el nombre de ese destino dentro de la pregunta, etiqueta y ayuda; eso no garantiza equivalencia de significado. Agrega mapeos explícitos por contexto y pruebas de las preguntas del funcionario que deben llevar a cada campo.
7. **La finalización refleja visita y navegación, no completitud.** Se puede avanzar sin respuesta y la interfaz muestra un relato completo según si quedan pasos, no según la validación del contenido. Además, el historial resumido de selecciones se muestra condicionado a que ya exista una traducción. La revisión debe estar disponible antes de generar y transmitir; una omisión voluntaria es válida, pero no equivale a una respuesta confirmada.
8. **El turno del ciudadano pierde su acto comunicativo.** `turnFromDeclaration` construye `SemanticMessage` sin pasar un `speechAct`, por lo que queda con el valor predeterminado statement incluso si el texto es una pregunta. El serializador sí guarda ese campo, pero conservaría el valor equivocado. Define el acto antes de generar y propágalo hasta el historial.

### 12 10 Evidencias de generación por contexto

Estas evidencias se obtuvieron invocando el analizador, la representación intermedia y el generador base Python. La redacción final de la aplicación puede tomar otra ruta o usar el resultado local; esta tabla demuestra problemas en funciones concretas, sin atribuirlos a una sesión desplegada.

| Contexto | Entrada de diagnóstico | Resultado observado e implicación |
| --- | --- | --- |
| Robo | ROBAR, CELULAR, CERCA | Añade una referencia genérica al lugar; no dispone del punto respecto del cual ocurrió cerca. |
| Violencia | HOSPITAL | Agrega una agresión y una voluntad de acudir al hospital. Elegir el lugar por sí solo no proporciona ninguno de esos dos hechos. |
| Amenazas digitales | AMENAZAR, CELULAR, PRUEBA_MARCADOR, FOTOS | El celular y las fotografías quedan ligados incorrectamente al verbo y el marcador se incorpora como palabra desconocida. |
| Engaño con dinero | NOMBRE y el deletreo de Luis | Presenta Luis como el nombre del ciudadano, aunque la pregunta de origen trata sobre la persona receptora del dinero, y repite esa información. |
| Consulta de trámite | INVESTIGACIÓN, HABLAR, POLICÍA | Produce una intención genérica de hablar y deja investigación y policía como referencias sueltas. |
| Declaración y testimonio | VER, HOMBRE | Produce una frase de haber visto sin conservar a quién se observó. |
| Identificación | CELULAR y un número de ocho dígitos | El número queda separado, sin una relación de contacto claramente redactada. El caso sencillo de NOMBRE con el deletreo de Ana sí produce una identificación coherente. |
| Preguntas | CUÁNDO, VOLVER | Produce una obligación de volver y trata el interrogativo como referencia suelta; no conserva la pregunta. |

### 12 11 Casos adicionales obligatorios para cerrar la auditoría

- **Violencia:** expresar que necesita atención sin declarar automáticamente una agresión; describir lugar y momento; diferenciar situación pasada y situación que continúa. No hace falta contenido gráfico para estas pruebas.
- **Amenazas digitales:** mensaje asociado a canal, remitente conocido o desconocido, fecha y evidencia guardada; mantener separados el contenido recibido y la acción de enviarlo o mostrarlo.
- **Engaño con dinero:** nombre y número de la persona receptora separados de los datos del ciudadano; monto y moneda declarados; banco como medio distinto de ubicación.
- **Consultas:** preguntar si la investigación terminó sin afirmar que terminó; solicitud de copia con documento identificado; preguntar por una cita desconocida sin inventar fecha ni hora.
- **Testimonio:** conservar actor, persona afectada, objeto y límites de observación; añadir o corregir un dato sin afirmar que el ciudadano vio todo el hecho.
- **Mis datos y trámites:** acompañamiento solo o con otra persona, actualización del número correcto y solicitud de un documento; demostrar que la familia Trámites puede cubrir las acciones que anuncia el producto.
- **Preguntas:** preguntas abiertas, cerradas, de permiso y de disponibilidad; `speechAct` correcto en ambos motores y después de guardar y restaurar una conversación.
- **Los ocho contextos:** glosas acentuadas y aliases, negaciones por campo, edición de detalles, opciones recortadas, marcador de evidencia, navegación condicional y ausencia de datos de otro contexto.

Para dar por cerrada la implementación, devuelve una matriz con las 48 zonas originales y su destino final: conservada, corregida, dividida, unificada con otra o retirada por redundancia. Identifica los nuevos subflujos y demuestra qué necesidad cubren. No es obligatorio conservar 48 pantallas: sí conservar todas las necesidades pertinentes con preguntas coherentes y sin repeticiones.
