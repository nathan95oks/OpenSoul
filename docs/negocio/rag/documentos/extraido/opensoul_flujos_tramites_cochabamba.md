<!-- origen: documentos/OpenSoul_Flujos_Tramites_Cochabamba.pdf · huella: 3f7714818b718622be13d1cd112a02eedd03d2d54edbc8ebe76e9ae78bb7b3cd · formato: pdf · texto extraído para leer y citar; no es un archivo de escenarios -->
# OpenSoul_Flujos_Tramites_Cochabamba.pdf

## Página 1

Flujos de trámites en Cochabamba para
OpenSoul
Corpus propuesto para comunicación entre una persona sorda y un funcionario. Incluye 70
escenarios en 16 áreas, preguntas alternativas, respuestas posibles y 44 dependencias entre
pasos.
Cubre GAM Cochabamba, Ministerio Público Fiscalía, Órgano Judicial, SEPDEP, SEPDAVI,
FELCC y FELCV. También incluye impuestos municipales, Derechos Reales, SLIM, DNA,
notarías, SEGIP, SERECI, discapacidad y derechos lingüísticos.
Las conversaciones son propuestas de orientación. Las fuentes respaldan competencias y
servicios generales; no certifican cada pregunta como protocolo institucional. Costos,
requisitos completos, horarios, disponibilidad y direcciones operativas deben confirmarse
para el trámite concreto.
SEPDAVI es el nombre correcto del servicio mencionado como DEPDAVI. SEPDEP atiende
defensa penal de personas denunciadas, imputadas o procesadas; SEPDAVI brinda asistencia
a víctimas según las condiciones del servicio.
El listado de turnos registra alternativas de un escenario, no declaraciones simultáneas de
una persona. Las preguntas condicionadas aparecen únicamente cuando se cumple su
ramificación. El usuario elige qué respuesta representa su situación.
Repositorio estudiado: https://github.com/nathan95oks/OpenSoul.git. Revisión del código:
0e42ee6dff3c4837bce8a95ccb5d3f5e44c9f353. Fuentes consultadas el 2026-10-04, según la
fecha local de Cochabamba.
El documento no incorpora señas nuevas. Las glosas definitivas deben generarse y
verificarse mediante el léxico y los mecanismos de OpenSoul. La validez del formato no
certifica equivalencia lingüística ni disponibilidad del avatar.
OpenSoul | Documento de escenarios | 2026-10-04
1

## Página 2

Cómo cargar los escenarios en OpenSoul
Ruta recomendada: copiar OpenSoul_Flujos_Tramites_Cochabamba.md a
docs/negocio/rag/escenarios/. Este archivo conserva las dependencias explícitas y los
identificadores nuevos desde 101, sin colisiones con la revisión examinada.
Desde la raíz del proyecto, ejecutar python tool/rag_actualizar.py. El comando revisa el
léxico, valida escenarios, genera el corpus y solicita traducciones de las frases nuevas a la
Lambda Texto a LSB configurada en .env.
La generación completa necesita la Lambda y sus credenciales o configuración vigentes. Se
entregan frases en español y relaciones entre pasos; las traducciones nuevas no fueron
solicitadas a AWS durante esta preparación.
Si se usa el PDF: guardarlo en docs/negocio/rag/documentos/ y ejecutar python
tool/rag_ingestar_documentos.py. Revisar el borrador de pendientes/ antes de incorporarlo a
escenarios/. Un archivo DOCX no figura entre los formatos aceptados por este importador.
Limitación verificada del importador PDF: conserva turnos y variantes, pero la sección
Escenarios posibles queda como narrativa. El convertidor no crea la sección Ramificaciones
del Markdown. Usar las condiciones del archivo MD suministrado para conservar el flujo.
GAM es un área administrativa nueva frente al corpus examinado. Si el borrador automático
del PDF asigna [VERIFICAR] a su institución, completar Gobierno Autónomo Municipal de
Cochabamba. El archivo MD ya contiene ese nombre.
Cargar una sola versión de estos escenarios. El PDF convertido y el MD entregado comparten
IDs; incorporarlos juntos produce duplicados. Antes de integrar en una revisión futura, volver
a comprobar identificadores libres.
Para la búsqueda remota, después de generar el corpus, seguir el empaquetado y despliegue
de aws/deploy/README.md; luego ejecutar python tool/rag_indexar_embeddings.py. La
búsqueda local y el corpus de Lambda deben compartir la misma versión.
OpenSoul | Documento de escenarios | 2026-10-04
2

## Página 3

Reglas de comunicación y ramificación
Una pregunta consulta una idea. Cuándo, dónde y quién se responden por separado. No
interpretar no sé como no. Una respuesta negativa solo niega el contenido de esa pregunta;
no niega todos los hechos del caso.
Las respuestas son posibilidades, no datos preseleccionados. Nombres, cantidades, fechas
precisas, domicilios, códigos, estados procesales y contactos reales se solicitan al usuario o a
la institución; no se completan con ejemplos.
Cuando existe riesgo, lesión o necesidad de protección, facilitar atención humana de
inmediato. Las preguntas de atención médica permanecen disponibles aunque la persona
diga que ya no existe peligro. No exigir terminar el recorrido para pedir ayuda.
La persona puede pedir intérprete de LSB, repetición o explicación escrita en cualquier
contexto. Confirmar que la alternativa de comunicación sea comprensible. No presentar la
aplicación como sustituto certificado de interpretación profesional.
No convertir todos los términos españoles en una sola glosa. OpenSoul usa señas del léxico,
partículas y zonas de respuesta. Las tarjetas de sí o no deben seguir la lógica polar; las
preguntas abiertas usan las zonas pertinentes.
Los cambios de institución se describen en las notas. El formato actual permite dependencias
entre turnos anteriores del mismo escenario, pero no enlaces automáticos a otro escenario.
El usuario debe confirmar la nueva ruta.
Cada ramificación indicada en este documento aparece también en la sección Ramificaciones
del MD. Los turnos sin condición permanecen disponibles en su orden. Las condiciones solo
añaden o retiran la pregunta a la que se refieren.
Para una palabra sin seña disponible, conservar el significado original y aplicar el mecanismo
previsto por el léxico y la revisión de OpenSoul. No declarar oficial una equivalencia
generada. Las formulaciones del banco RAG quedan sujetas a validación LSB.
OpenSoul | Documento de escenarios | 2026-10-04
3

## Página 4

Áreas y escenarios incluidos
Área
Casos incluidos
Identificadores ESC
GAM
Licencia, catastro, planos, seguimiento y observaciones.
GAM-101 a GAM-106
FIS
Denuncia, caso fiscal, fiscal asignado, información y
citación.
FIS-101 a FIS-105
OJ
Expediente, audiencia, asistencia familiar, memorial y
REJAP.
OJ-101 a OJ-105
SEPDEP
Defensa penal, detención, audiencia y recursos
económicos.
SEPDEP-101 a SEPDEP-104
SEPDAVI
Asistencia a víctima, apoyo psicológico, familiares y
seguimiento.
SEPDAVI-101 a SEPDAVI-104
FELCC
Robo, estafa, desaparición, amenazas y seguimiento
policial.
FELCC-101 a FELCC-105
FELCV
Violencia familiar, psicológica, sexual, protección y
seguimiento.
FELCV-101 a FELCV-105
IMP
Deuda de vehículo o inmueble, pagos y opciones de pago.
IMP-101 a IMP-104
DDRR
Folio, gravámenes, compra venta y documentos
observados.
DDRR-101 a DDRR-104
SLIM
Orientación, denuncia, apoyo y medidas de protección.
SLIM-101 a SLIM-104
DNA
Riesgo, violencia, viaje de menor y seguimiento.
DNA-101 a DNA-104
NOT
Firmas, poder, contrato y documento anterior.
NOT-101 a NOT-104
SEGIP
Primera cédula, renovación, pérdida y corrección.
SEGIP-101 a SEGIP-104
SERECI
Nacimiento, estado civil, defunción y saneamiento.
SERECI-101 a SERECI-104
DISC
Calificación, carnet, registro y beneficios municipales.
DISC-101 a DISC-104
LSB
Interpretación, barrera comunicativa, firma y oficina
correcta.
LSB-101 a LSB-104
Los identificadores incluyen el prefijo ESC. Los demás casos se orientan mediante la ruta LSB-104, sin
atribuir una competencia institucional por semejanza de palabras.
OpenSoul | Documento de escenarios | 2026-10-04
4

## Página 5

ESC-GAM-101 / GAM
Consulta inicial de trámite municipal
Situación: Propuesta de conversación para consulta inicial de trámite municipal. Las respuestas son
alternativas que el usuario debe elegir; no describen hechos ya confirmados.
PREGUNTAS EN UNA SECUENCIA POSIBLE
1
Persona usuaria
Quiero orientación para un trámite municipal.
2
Funcionario
¿Trajo algún documento relacionado con su solicitud?
3
Persona usuaria
Sí, traje documentos.
4
Funcionario
¿Tiene el número de su trámite?
5
Persona usuaria
Sí, tengo el número.
6
Funcionario
¿Le entregaron observaciones por escrito?
7
Persona usuaria
Sí, tengo las observaciones escritas.
8
Funcionario
¿Necesita un intérprete de Lengua de Señas Boliviana?
9
Persona usuaria
Sí, necesito un intérprete de LSB.
10
Funcionario
Pida que le confirmen por escrito el siguiente paso.
VARIANTES Y RESPUESTAS POSIBLES
P1. ¿Trajo algún documento relacionado con su solicitud?
Variantes: ¿Tiene documentos de su solicitud? / ¿Trae algún papel sobre este trámite?
Respuestas: Sí, traje documentos. / No, no traje documentos. / No sé qué documento corresponde.
P2. ¿Tiene el número de su trámite?
Variantes: ¿Conoce el código del trámite? / ¿Trajo el número de la solicitud?
Respuestas: Sí, tengo el número. / No, no tengo el número. / No sé cuál es el número.
P3. ¿Le entregaron observaciones por escrito?
Variantes: ¿Tiene una lista escrita de observaciones? / ¿Recibió una observación escrita del trámite?
Respuestas: Sí, tengo las observaciones escritas. / No, no tengo observaciones escritas. / No sé cuáles
son las observaciones.
P4. ¿Necesita un intérprete de Lengua de Señas Boliviana?
Variantes: ¿Requiere interpretación en LSB? / ¿Necesita apoyo de un intérprete de LSB?
Respuestas: Sí, necesito un intérprete de LSB. / No, no necesito un intérprete. / No sé cómo solicitar un
intérprete.
ESCENARIOS POSIBLES
Con documento: identificar trámite. Sin documento: precisar la gestión sin adivinarla. Catastro municipal
y registro de propiedad en DDRR son distintos.
Referencia temática: F-GAM-101, F-GAM-102 · Tipo: mixto
OpenSoul | Documento de escenarios | 2026-10-04
5

## Página 6

ESC-GAM-102 / GAM
Licencia de funcionamiento nueva o renovación
Situación: Propuesta de conversación para licencia de funcionamiento nueva o renovación. Las
respuestas son alternativas que el usuario debe elegir; no describen hechos ya confirmados.
PREGUNTAS EN UNA SECUENCIA POSIBLE
1
Persona usuaria
Quiero consultar la licencia de mi negocio.
2
Funcionario
¿Tiene una licencia de funcionamiento anterior?
3
Persona usuaria
Sí, tengo licencia anterior.
4
Funcionario
¿La solicitud corresponde a su negocio?
5
Persona usuaria
Sí, es para mi negocio.
6
Funcionario
¿Trajo algún documento relacionado con su solicitud?
7
Persona usuaria
Sí, traje documentos.
8
Funcionario
¿Prefiere recibir la explicación por escrito?
9
Persona usuaria
Sí, prefiero la explicación por escrito.
10
Funcionario
Pida que le confirmen por escrito el siguiente paso.
VARIANTES Y RESPUESTAS POSIBLES
P1. ¿Tiene una licencia de funcionamiento anterior?
Variantes: ¿Conserva su licencia anterior? / ¿Ya tuvo licencia de funcionamiento?
Respuestas: Sí, tengo licencia anterior. / No, no tengo licencia anterior. / No sé si existe una licencia
anterior.
P2. ¿La solicitud corresponde a su negocio?
Variantes: ¿Este trámite es para su actividad económica? / ¿La gestión se refiere a su negocio?
Respuestas: Sí, es para mi negocio. / No, no es para mi negocio. / No sé si corresponde a mi negocio.
P3. ¿Trajo algún documento relacionado con su solicitud?
Variantes: ¿Tiene documentos de su solicitud? / ¿Trae algún papel sobre este trámite?
Respuestas: Sí, traje documentos. / No, no traje documentos. / No sé qué documento corresponde.
P4. ¿Prefiere recibir la explicación por escrito?
Variantes: ¿Quiere una explicación escrita? / ¿Le ayuda que escriba la explicación?
Respuestas: Sí, prefiero la explicación por escrito. / No, no prefiero la explicación escrita. / No sé si la
explicación escrita me ayuda.
ESCENARIOS POSIBLES
Con licencia anterior: consultar renovación o modificación. Sin licencia: consultar apertura. Requisitos,
costo e inspecciones se confirman para el rubro concreto.
Referencia temática: F-GAM-101, F-GAM-102 · Tipo: mixto
OpenSoul | Documento de escenarios | 2026-10-04
6

## Página 7

ESC-GAM-103 / GAM
Catastro y corrección de datos municipales
Situación: Propuesta de conversación para catastro y corrección de datos municipales. Las respuestas
son alternativas que el usuario debe elegir; no describen hechos ya confirmados.
PREGUNTAS EN UNA SECUENCIA POSIBLE
1
Persona usuaria
Quiero consultar los datos de mi casa.
2
Funcionario
¿Tiene el código catastral del inmueble?
3
Persona usuaria
Sí, tengo el código catastral.
4
Funcionario
¿Encontró un error en sus datos?
5
Persona usuaria
Sí, encontré un error.
6
Funcionario
¿Trajo algún documento relacionado con su solicitud?
7
Persona usuaria
Sí, traje documentos.
8
Funcionario
¿Necesita un intérprete de Lengua de Señas Boliviana?
9
Persona usuaria
Sí, necesito un intérprete de LSB.
10
Funcionario
Pida que le confirmen por escrito el siguiente paso.
VARIANTES Y RESPUESTAS POSIBLES
P1. ¿Tiene el código catastral del inmueble?
Variantes: ¿Conoce el código catastral de su casa? / ¿Trajo el dato catastral del inmueble?
Respuestas: Sí, tengo el código catastral. / No, no tengo el código catastral. / No sé cuál es el código
catastral.
P2. ¿Encontró un error en sus datos?
Variantes: ¿Algún dato del documento está equivocado? / ¿Necesita corregir información personal?
Respuestas: Sí, encontré un error. / No, no encontré un error. / No sé si el dato está equivocado.
P3. ¿Trajo algún documento relacionado con su solicitud?
Variantes: ¿Tiene documentos de su solicitud? / ¿Trae algún papel sobre este trámite?
Respuestas: Sí, traje documentos. / No, no traje documentos. / No sé qué documento corresponde.
P4. ¿Necesita un intérprete de Lengua de Señas Boliviana?
Variantes: ¿Requiere interpretación en LSB? / ¿Necesita apoyo de un intérprete de LSB?
Respuestas: Sí, necesito un intérprete de LSB. / No, no necesito un intérprete. / No sé cómo solicitar un
intérprete.
ESCENARIOS POSIBLES
Con código: ubicar registro municipal. Sin código: pedir orientación para búsqueda. No concluir derecho
propietario con el registro catastral.
Referencia temática: F-GAM-101, F-GAM-102 · Tipo: mixto
OpenSoul | Documento de escenarios | 2026-10-04
7

## Página 8

ESC-GAM-104 / GAM
Planos y consulta sobre construcción
Situación: Propuesta de conversación para planos y consulta sobre construcción. Las respuestas son
alternativas que el usuario debe elegir; no describen hechos ya confirmados.
PREGUNTAS EN UNA SECUENCIA POSIBLE
1
Persona usuaria
Quiero orientación sobre los planos de mi casa.
2
Funcionario
¿Trajo los planos que tiene del inmueble?
3
Persona usuaria
Sí, traje los planos.
4
Funcionario
¿Le entregaron observaciones por escrito?
5
Persona usuaria
Sí, tengo las observaciones escritas.
6
Funcionario
¿Trajo algún documento relacionado con su solicitud?
7
Persona usuaria
Sí, traje documentos.
8
Funcionario
¿Prefiere recibir la explicación por escrito?
9
Persona usuaria
Sí, prefiero la explicación por escrito.
10
Funcionario
Pida que le confirmen por escrito el siguiente paso.
VARIANTES Y RESPUESTAS POSIBLES
P1. ¿Trajo los planos que tiene del inmueble?
Variantes: ¿Tiene planos de su inmueble? / ¿Conserva algún plano de la construcción?
Respuestas: Sí, traje los planos. / No, no traje planos. / No sé si estos planos corresponden.
P2. ¿Le entregaron observaciones por escrito?
Variantes: ¿Tiene una lista escrita de observaciones? / ¿Recibió una observación escrita del trámite?
Respuestas: Sí, tengo las observaciones escritas. / No, no tengo observaciones escritas. / No sé cuáles
son las observaciones.
P3. ¿Trajo algún documento relacionado con su solicitud?
Variantes: ¿Tiene documentos de su solicitud? / ¿Trae algún papel sobre este trámite?
Respuestas: Sí, traje documentos. / No, no traje documentos. / No sé qué documento corresponde.
P4. ¿Prefiere recibir la explicación por escrito?
Variantes: ¿Quiere una explicación escrita? / ¿Le ayuda que escriba la explicación?
Respuestas: Sí, prefiero la explicación por escrito. / No, no prefiero la explicación escrita. / No sé si la
explicación escrita me ayuda.
ESCENARIOS POSIBLES
Con planos: solicitar revisión del tipo de gestión. Sin planos: consultar requisitos. No autorizar construir
ni afirmar aprobación desde el RAG.
Referencia temática: F-GAM-101, F-GAM-102 · Tipo: mixto
OpenSoul | Documento de escenarios | 2026-10-04
8

## Página 9

ESC-GAM-105 / GAM
Seguimiento de trámite en subalcaldía
Situación: Propuesta de conversación para seguimiento de trámite en subalcaldía. Las respuestas son
alternativas que el usuario debe elegir; no describen hechos ya confirmados.
PREGUNTAS EN UNA SECUENCIA POSIBLE
1
Persona usuaria
Quiero conocer el estado de mi trámite municipal.
2
Funcionario
¿Tiene el número de su trámite?
3
Persona usuaria
Sí, tengo el número.
4
Funcionario
¿Tiene una constancia de recepción de documentos?
5
Persona usuaria
Sí, tengo constancia de recepción.
6
Funcionario
¿Trajo algún documento relacionado con su solicitud?
7
Persona usuaria
Sí, traje documentos.
8
Funcionario
¿Entendió el siguiente paso?
9
Persona usuaria
Sí, entendí el siguiente paso.
10
Funcionario
Pida que le confirmen por escrito el siguiente paso.
VARIANTES Y RESPUESTAS POSIBLES
P1. ¿Tiene el número de su trámite?
Variantes: ¿Conoce el código del trámite? / ¿Trajo el número de la solicitud?
Respuestas: Sí, tengo el número. / No, no tengo el número. / No sé cuál es el número.
P2. ¿Tiene una constancia de recepción de documentos?
Variantes: ¿Le dieron un cargo de recepción? / ¿Conserva prueba de entrega de sus documentos?
Respuestas: Sí, tengo constancia de recepción. / No, no tengo constancia. / No sé si este papel es la
constancia.
P3. ¿Trajo algún documento relacionado con su solicitud?
Variantes: ¿Tiene documentos de su solicitud? / ¿Trae algún papel sobre este trámite?
Respuestas: Sí, traje documentos. / No, no traje documentos. / No sé qué documento corresponde.
P4. ¿Entendió el siguiente paso?
Variantes: ¿Comprendió qué debe hacer después? / ¿Está claro el paso siguiente?
Respuestas: Sí, entendí el siguiente paso. / No, no entendí el siguiente paso. / No sé cuál es el siguiente
paso.
ESCENARIOS POSIBLES
Con número: consultar seguimiento. Sin número: pedir búsqueda con la constancia disponible. Estado,
funcionario y fecha de entrega son datos en vivo.
Condiciones del MD: Turno 4: si Turno 2 es negado o desconocido.
Referencia temática: F-GAM-101, F-GAM-102 · Tipo: mixto
OpenSoul | Documento de escenarios | 2026-10-04
9

## Página 10

ESC-GAM-106 / GAM
Trámite observado o falta de documento
Situación: Propuesta de conversación para trámite observado o falta de documento. Las respuestas son
alternativas que el usuario debe elegir; no describen hechos ya confirmados.
PREGUNTAS EN UNA SECUENCIA POSIBLE
1
Persona usuaria
No entiendo las observaciones de mi trámite.
2
Funcionario
¿Le entregaron observaciones por escrito?
3
Persona usuaria
Sí, tengo las observaciones escritas.
4
Funcionario
¿Trajo algún documento relacionado con su solicitud?
5
Persona usuaria
Sí, traje documentos.
6
Funcionario
¿Tiene una constancia de recepción de documentos?
7
Persona usuaria
Sí, tengo constancia de recepción.
8
Funcionario
¿Prefiere recibir la explicación por escrito?
9
Persona usuaria
Sí, prefiero la explicación por escrito.
10
Funcionario
Pida que le confirmen por escrito el siguiente paso.
VARIANTES Y RESPUESTAS POSIBLES
P1. ¿Le entregaron observaciones por escrito?
Variantes: ¿Tiene una lista escrita de observaciones? / ¿Recibió una observación escrita del trámite?
Respuestas: Sí, tengo las observaciones escritas. / No, no tengo observaciones escritas. / No sé cuáles
son las observaciones.
P2. ¿Trajo algún documento relacionado con su solicitud?
Variantes: ¿Tiene documentos de su solicitud? / ¿Trae algún papel sobre este trámite?
Respuestas: Sí, traje documentos. / No, no traje documentos. / No sé qué documento corresponde.
P3. ¿Tiene una constancia de recepción de documentos?
Variantes: ¿Le dieron un cargo de recepción? / ¿Conserva prueba de entrega de sus documentos?
Respuestas: Sí, tengo constancia de recepción. / No, no tengo constancia. / No sé si este papel es la
constancia.
P4. ¿Prefiere recibir la explicación por escrito?
Variantes: ¿Quiere una explicación escrita? / ¿Le ayuda que escriba la explicación?
Respuestas: Sí, prefiero la explicación por escrito. / No, no prefiero la explicación escrita. / No sé si la
explicación escrita me ayuda.
ESCENARIOS POSIBLES
Con observaciones escritas: explicar cada observación por separado. Sin ellas: pedir detalle escrito. No
inventar requisitos ni decir que una copia sustituye al original.
Referencia temática: F-GAM-101, F-GAM-102 · Tipo: mixto
OpenSoul | Documento de escenarios | 2026-10-04
10

## Página 11

ESC-FIS-101 / FIS
Presentar denuncia y comunicar los hechos
Situación: Propuesta de conversación para presentar denuncia y comunicar los hechos. Las respuestas
son alternativas que el usuario debe elegir; no describen hechos ya confirmados.
PREGUNTAS EN UNA SECUENCIA POSIBLE
1
Persona usuaria
Quiero presentar una denuncia.
2
Funcionario
¿Ya presentó una denuncia por este hecho?
3
Persona usuaria
Sí, ya presenté una denuncia.
4
Funcionario
¿Tiene el código de su caso en Fiscalía?
5
Persona usuaria
Sí, tengo el código fiscal.
6
Funcionario
¿Está en peligro ahora?
7
Persona usuaria
Sí, estoy en peligro ahora.
8
Funcionario
¿Cuándo ocurrió el hecho?
9
Persona usuaria
Ocurrió hoy.
10
Funcionario
¿Dónde ocurrió el hecho?
11
Persona usuaria
Ocurrió en mi casa.
12
Funcionario
¿Tiene documentos o mensajes sobre lo ocurrido?
13
Persona usuaria
Sí, tengo mensajes.
14
Funcionario
Pida que le confirmen por escrito el siguiente paso.
VARIANTES Y RESPUESTAS POSIBLES
P1. ¿Ya presentó una denuncia por este hecho?
Variantes: ¿Ya denunció lo ocurrido? / ¿Este hecho ya fue denunciado?
Respuestas: Sí, ya presenté una denuncia. / No, todavía no presenté una denuncia. / No sé si existe una
denuncia.
P2. ¿Tiene el código de su caso en Fiscalía?
Variantes: ¿Conoce el código fiscal de su caso? / ¿Trajo el código del caso fiscal?
Respuestas: Sí, tengo el código fiscal. / No, no tengo el código fiscal. / No sé cuál es el código fiscal.
P3. ¿Está en peligro ahora?
Variantes: ¿Corre peligro en este momento? / ¿Existe peligro inmediato para usted?
Respuestas: Sí, estoy en peligro ahora. / No, no estoy en peligro ahora. / No sé si estoy en peligro.
P4. ¿Cuándo ocurrió el hecho?
Variantes: ¿En qué momento sucedió? / ¿Cuándo pasó lo ocurrido?
Respuestas: Ocurrió hoy. / Ocurrió ayer. / Ocurrió antes. / No sé cuándo ocurrió.
P5. ¿Dónde ocurrió el hecho?
Variantes: ¿En qué lugar sucedió? / ¿Dónde pasó lo ocurrido?
Respuestas: Ocurrió en mi casa. / Ocurrió en la calle. / Ocurrió en mi trabajo. / No sé dónde ocurrió.
P6. ¿Tiene documentos o mensajes sobre lo ocurrido?
Variantes: ¿Conserva mensajes o documentos del hecho? / ¿Tiene material relacionado con lo ocurrido?
Respuestas: Sí, tengo mensajes. / No, no tengo ese material. / No sé si tengo ese material.
ESCENARIOS POSIBLES
Denuncia previa: ubicar caso y ampliar solo si corresponde. Sin denuncia: pedir atención de recepción.
Riesgo actual: priorizar ayuda; no completar todo el cuestionario.
Condiciones del MD: Turno 4: si Turno 2 es afirmado.
Referencia temática: F-FIS-101 · Tipo: mixto
OpenSoul | Documento de escenarios | 2026-10-04
11

## Página 12

ESC-FIS-102 / FIS
Seguimiento y búsqueda del caso fiscal
Situación: Propuesta de conversación para seguimiento y búsqueda del caso fiscal. Las respuestas son
alternativas que el usuario debe elegir; no describen hechos ya confirmados.
PREGUNTAS EN UNA SECUENCIA POSIBLE
1
Persona usuaria
Quiero saber cómo va mi caso en Fiscalía.
2
Funcionario
¿Tiene el código de su caso en Fiscalía?
3
Persona usuaria
Sí, tengo el código fiscal.
4
Funcionario
¿Recibió una notificación?
5
Persona usuaria
Sí, recibí una notificación.
6
Funcionario
¿Trajo algún documento relacionado con su solicitud?
7
Persona usuaria
Sí, traje documentos.
8
Funcionario
¿Necesita un intérprete de Lengua de Señas Boliviana?
9
Persona usuaria
Sí, necesito un intérprete de LSB.
10
Funcionario
Pida que le confirmen por escrito el siguiente paso.
VARIANTES Y RESPUESTAS POSIBLES
P1. ¿Tiene el código de su caso en Fiscalía?
Variantes: ¿Conoce el código fiscal de su caso? / ¿Trajo el código del caso fiscal?
Respuestas: Sí, tengo el código fiscal. / No, no tengo el código fiscal. / No sé cuál es el código fiscal.
P2. ¿Recibió una notificación?
Variantes: ¿Le entregaron una notificación? / ¿Tiene una notificación de este caso?
Respuestas: Sí, recibí una notificación. / No, no recibí una notificación. / No sé si es una notificación.
P3. ¿Trajo algún documento relacionado con su solicitud?
Variantes: ¿Tiene documentos de su solicitud? / ¿Trae algún papel sobre este trámite?
Respuestas: Sí, traje documentos. / No, no traje documentos. / No sé qué documento corresponde.
P4. ¿Necesita un intérprete de Lengua de Señas Boliviana?
Variantes: ¿Requiere interpretación en LSB? / ¿Necesita apoyo de un intérprete de LSB?
Respuestas: Sí, necesito un intérprete de LSB. / No, no necesito un intérprete. / No sé cómo solicitar un
intérprete.
ESCENARIOS POSIBLES
Con código fiscal: consultar el caso. Sin código: solicitar búsqueda orientada. CUD o código fiscal y NUREJ
judicial no se sustituyen automáticamente.
Condiciones del MD: Turno 4: si Turno 2 es negado o desconocido.
Referencia temática: F-FIS-101 · Tipo: mixto
OpenSoul | Documento de escenarios | 2026-10-04
12

## Página 13

ESC-FIS-103 / FIS
Ubicar al fiscal y consultar atención
Situación: Propuesta de conversación para ubicar al fiscal y consultar atención. Las respuestas son
alternativas que el usuario debe elegir; no describen hechos ya confirmados.
PREGUNTAS EN UNA SECUENCIA POSIBLE
1
Persona usuaria
Necesito hablar con el fiscal de mi caso.
2
Funcionario
¿Tiene el código de su caso en Fiscalía?
3
Persona usuaria
Sí, tengo el código fiscal.
4
Funcionario
¿Recibió una notificación?
5
Persona usuaria
Sí, recibí una notificación.
6
Funcionario
¿Trajo algún documento relacionado con su solicitud?
7
Persona usuaria
Sí, traje documentos.
8
Funcionario
¿Prefiere recibir la explicación por escrito?
9
Persona usuaria
Sí, prefiero la explicación por escrito.
10
Funcionario
Pida que le confirmen por escrito el siguiente paso.
VARIANTES Y RESPUESTAS POSIBLES
P1. ¿Tiene el código de su caso en Fiscalía?
Variantes: ¿Conoce el código fiscal de su caso? / ¿Trajo el código del caso fiscal?
Respuestas: Sí, tengo el código fiscal. / No, no tengo el código fiscal. / No sé cuál es el código fiscal.
P2. ¿Recibió una notificación?
Variantes: ¿Le entregaron una notificación? / ¿Tiene una notificación de este caso?
Respuestas: Sí, recibí una notificación. / No, no recibí una notificación. / No sé si es una notificación.
P3. ¿Trajo algún documento relacionado con su solicitud?
Variantes: ¿Tiene documentos de su solicitud? / ¿Trae algún papel sobre este trámite?
Respuestas: Sí, traje documentos. / No, no traje documentos. / No sé qué documento corresponde.
P4. ¿Prefiere recibir la explicación por escrito?
Variantes: ¿Quiere una explicación escrita? / ¿Le ayuda que escriba la explicación?
Respuestas: Sí, prefiero la explicación por escrito. / No, no prefiero la explicación escrita. / No sé si la
explicación escrita me ayuda.
ESCENARIOS POSIBLES
Con código: pedir ubicación del fiscal asignado. Sin código: buscar recepción previa. Nombre del fiscal,
oficina, agenda y atención efectiva requieren confirmación.
Condiciones del MD: Turno 4: si Turno 2 es negado o desconocido.
Referencia temática: F-FIS-101 · Tipo: mixto
OpenSoul | Documento de escenarios | 2026-10-04
13

## Página 14

ESC-FIS-104 / FIS
Entregar información adicional o mensajes
Situación: Propuesta de conversación para entregar información adicional o mensajes. Las respuestas
son alternativas que el usuario debe elegir; no describen hechos ya confirmados.
PREGUNTAS EN UNA SECUENCIA POSIBLE
1
Persona usuaria
Quiero entregar información sobre mi denuncia.
2
Funcionario
¿Tiene el código de su caso en Fiscalía?
3
Persona usuaria
Sí, tengo el código fiscal.
4
Funcionario
¿Tiene documentos o mensajes sobre lo ocurrido?
5
Persona usuaria
Sí, tengo mensajes.
6
Funcionario
¿Ya presentó una denuncia por este hecho?
7
Persona usuaria
Sí, ya presenté una denuncia.
8
Funcionario
¿Necesita un intérprete de Lengua de Señas Boliviana?
9
Persona usuaria
Sí, necesito un intérprete de LSB.
10
Funcionario
Pida que le confirmen por escrito el siguiente paso.
VARIANTES Y RESPUESTAS POSIBLES
P1. ¿Tiene el código de su caso en Fiscalía?
Variantes: ¿Conoce el código fiscal de su caso? / ¿Trajo el código del caso fiscal?
Respuestas: Sí, tengo el código fiscal. / No, no tengo el código fiscal. / No sé cuál es el código fiscal.
P2. ¿Tiene documentos o mensajes sobre lo ocurrido?
Variantes: ¿Conserva mensajes o documentos del hecho? / ¿Tiene material relacionado con lo ocurrido?
Respuestas: Sí, tengo mensajes. / No, no tengo ese material. / No sé si tengo ese material.
P3. ¿Ya presentó una denuncia por este hecho?
Variantes: ¿Ya denunció lo ocurrido? / ¿Este hecho ya fue denunciado?
Respuestas: Sí, ya presenté una denuncia. / No, todavía no presenté una denuncia. / No sé si existe una
denuncia.
P4. ¿Necesita un intérprete de Lengua de Señas Boliviana?
Variantes: ¿Requiere interpretación en LSB? / ¿Necesita apoyo de un intérprete de LSB?
Respuestas: Sí, necesito un intérprete de LSB. / No, no necesito un intérprete. / No sé cómo solicitar un
intérprete.
ESCENARIOS POSIBLES
Con caso: consultar el canal de presentación. Sin caso: aclarar si es denuncia inicial. Conservar material
original; el investigador determina cómo recibirlo.
Referencia temática: F-FIS-101 · Tipo: mixto
OpenSoul | Documento de escenarios | 2026-10-04
14

## Página 15

ESC-FIS-105 / FIS
Citación y pedido de asistencia
Situación: Propuesta de conversación para citación y pedido de asistencia. Las respuestas son
alternativas que el usuario debe elegir; no describen hechos ya confirmados.
PREGUNTAS EN UNA SECUENCIA POSIBLE
1
Persona usuaria
Recibí un papel de Fiscalía y necesito ayuda.
2
Funcionario
¿Recibió una notificación?
3
Persona usuaria
Sí, recibí una notificación.
4
Funcionario
¿La denuncia es contra usted?
5
Persona usuaria
Sí, me denunciaron.
6
Funcionario
¿Usted fue afectado por el hecho?
7
Persona usuaria
Sí, fui afectado.
8
Funcionario
¿Necesita un intérprete de Lengua de Señas Boliviana?
9
Persona usuaria
Sí, necesito un intérprete de LSB.
10
Funcionario
Pida que le confirmen por escrito el siguiente paso.
VARIANTES Y RESPUESTAS POSIBLES
P1. ¿Recibió una notificación?
Variantes: ¿Le entregaron una notificación? / ¿Tiene una notificación de este caso?
Respuestas: Sí, recibí una notificación. / No, no recibí una notificación. / No sé si es una notificación.
P2. ¿La denuncia es contra usted?
Variantes: ¿Usted es la persona denunciada? / ¿Lo denunciaron a usted?
Respuestas: Sí, me denunciaron. / No, no me denunciaron. / No sé si me denunciaron.
P3. ¿Usted fue afectado por el hecho?
Variantes: ¿Usted sufrió lo ocurrido? / ¿El hecho lo afectó a usted?
Respuestas: Sí, fui afectado. / No, no fui afectado. / No sé si fui afectado.
P4. ¿Necesita un intérprete de Lengua de Señas Boliviana?
Variantes: ¿Requiere interpretación en LSB? / ¿Necesita apoyo de un intérprete de LSB?
Respuestas: Sí, necesito un intérprete de LSB. / No, no necesito un intérprete. / No sé cómo solicitar un
intérprete.
ESCENARIOS POSIBLES
Aclarar rol antes de orientar. Persona denunciada sin defensa: SEPDEP. Víctima que necesita asistencia:
SEPDAVI. Testigo: no tratar como imputado.
Condiciones del MD: Turno 4: si Turno 2 es afirmado; Turno 6: si Turno 2 es afirmado.
Referencia temática: F-FIS-101 · Tipo: mixto
OpenSoul | Documento de escenarios | 2026-10-04
15

## Página 16

ESC-OJ-101 / OJ
Consulta de expediente mediante NUREJ y WebID
Situación: Propuesta de conversación para consulta de expediente mediante nurej y webid. Las
respuestas son alternativas que el usuario debe elegir; no describen hechos ya confirmados.
PREGUNTAS EN UNA SECUENCIA POSIBLE
1
Persona usuaria
Quiero consultar mi expediente judicial.
2
Funcionario
¿Tiene el NUREJ de su expediente judicial?
3
Persona usuaria
Sí, tengo el NUREJ.
4
Funcionario
¿Tiene el WebID de su expediente?
5
Persona usuaria
Sí, tengo el WebID.
6
Funcionario
¿Trajo algún documento relacionado con su solicitud?
7
Persona usuaria
Sí, traje documentos.
8
Funcionario
¿Necesita un intérprete de Lengua de Señas Boliviana?
9
Persona usuaria
Sí, necesito un intérprete de LSB.
10
Funcionario
Pida que le confirmen por escrito el siguiente paso.
VARIANTES Y RESPUESTAS POSIBLES
P1. ¿Tiene el NUREJ de su expediente judicial?
Variantes: ¿Conoce el número de su expediente judicial? / ¿Trajo el NUREJ?
Respuestas: Sí, tengo el NUREJ. / No, no tengo el NUREJ. / No sé cuál es el NUREJ.
P2. ¿Tiene el WebID de su expediente?
Variantes: ¿Conoce el código WebID? / ¿Trajo el WebID?
Respuestas: Sí, tengo el WebID. / No, no tengo el WebID. / No sé cuál es el WebID.
P3. ¿Trajo algún documento relacionado con su solicitud?
Variantes: ¿Tiene documentos de su solicitud? / ¿Trae algún papel sobre este trámite?
Respuestas: Sí, traje documentos. / No, no traje documentos. / No sé qué documento corresponde.
P4. ¿Necesita un intérprete de Lengua de Señas Boliviana?
Variantes: ¿Requiere interpretación en LSB? / ¿Necesita apoyo de un intérprete de LSB?
Respuestas: Sí, necesito un intérprete de LSB. / No, no necesito un intérprete. / No sé cómo solicitar un
intérprete.
ESCENARIOS POSIBLES
Con NUREJ: consultar también WebID y radicatoria. Sin NUREJ: pedir ayuda en informaciones. No
convertir código fiscal en NUREJ.
Condiciones del MD: Turno 4: si Turno 2 es afirmado; Turno 6: si Turno 2 es negado o desconocido.
Referencia temática: F-OJ-101 · Tipo: mixto
OpenSoul | Documento de escenarios | 2026-10-04
16

## Página 17

ESC-OJ-102 / OJ
Audiencia y confirmación de modalidad
Situación: Propuesta de conversación para audiencia y confirmación de modalidad. Las respuestas son
alternativas que el usuario debe elegir; no describen hechos ya confirmados.
PREGUNTAS EN UNA SECUENCIA POSIBLE
1
Persona usuaria
Quiero confirmar mi audiencia.
2
Funcionario
¿Tiene una audiencia señalada?
3
Persona usuaria
Sí, tengo una audiencia señalada.
4
Funcionario
¿Le indicaron que la audiencia será virtual?
5
Persona usuaria
Sí, indicaron audiencia virtual.
6
Funcionario
¿Recibió una notificación?
7
Persona usuaria
Sí, recibí una notificación.
8
Funcionario
¿Necesita un intérprete de Lengua de Señas Boliviana?
9
Persona usuaria
Sí, necesito un intérprete de LSB.
10
Funcionario
Pida que le confirmen por escrito el siguiente paso.
VARIANTES Y RESPUESTAS POSIBLES
P1. ¿Tiene una audiencia señalada?
Variantes: ¿Le comunicaron una audiencia? / ¿Existe una convocatoria a audiencia?
Respuestas: Sí, tengo una audiencia señalada. / No, no tengo audiencia señalada. / No sé si hay
audiencia señalada.
P2. ¿Le indicaron que la audiencia será virtual?
Variantes: ¿La convocatoria dice audiencia virtual? / ¿Le informaron participación por internet?
Respuestas: Sí, indicaron audiencia virtual. / No, no indicaron audiencia virtual. / No sé cuál es la
modalidad.
P3. ¿Recibió una notificación?
Variantes: ¿Le entregaron una notificación? / ¿Tiene una notificación de este caso?
Respuestas: Sí, recibí una notificación. / No, no recibí una notificación. / No sé si es una notificación.
P4. ¿Necesita un intérprete de Lengua de Señas Boliviana?
Variantes: ¿Requiere interpretación en LSB? / ¿Necesita apoyo de un intérprete de LSB?
Respuestas: Sí, necesito un intérprete de LSB. / No, no necesito un intérprete. / No sé cómo solicitar un
intérprete.
ESCENARIOS POSIBLES
Con audiencia: verificar modalidad y convocatoria. Sin audiencia confirmada: consultar señalamiento.
Fecha, hora, sala y enlace son datos en vivo.
Condiciones del MD: Turno 4: si Turno 2 es afirmado; Turno 6: si Turno 2 es negado o desconocido.
Referencia temática: F-OJ-101 · Tipo: mixto
OpenSoul | Documento de escenarios | 2026-10-04
17

## Página 18

ESC-OJ-103 / OJ
Asistencia familiar y ubicación del juzgado
Situación: Propuesta de conversación para asistencia familiar y ubicación del juzgado. Las respuestas
son alternativas que el usuario debe elegir; no describen hechos ya confirmados.
PREGUNTAS EN UNA SECUENCIA POSIBLE
1
Persona usuaria
Necesito orientación sobre asistencia familiar.
2
Funcionario
¿Tiene el NUREJ de su expediente judicial?
3
Persona usuaria
Sí, tengo el NUREJ.
4
Funcionario
¿Recibió una notificación?
5
Persona usuaria
Sí, recibí una notificación.
6
Funcionario
¿Trajo algún documento relacionado con su solicitud?
7
Persona usuaria
Sí, traje documentos.
8
Funcionario
¿Tiene abogado para este caso?
9
Persona usuaria
Sí, tengo abogado.
10
Funcionario
Pida que le confirmen por escrito el siguiente paso.
VARIANTES Y RESPUESTAS POSIBLES
P1. ¿Tiene el NUREJ de su expediente judicial?
Variantes: ¿Conoce el número de su expediente judicial? / ¿Trajo el NUREJ?
Respuestas: Sí, tengo el NUREJ. / No, no tengo el NUREJ. / No sé cuál es el NUREJ.
P2. ¿Recibió una notificación?
Variantes: ¿Le entregaron una notificación? / ¿Tiene una notificación de este caso?
Respuestas: Sí, recibí una notificación. / No, no recibí una notificación. / No sé si es una notificación.
P3. ¿Trajo algún documento relacionado con su solicitud?
Variantes: ¿Tiene documentos de su solicitud? / ¿Trae algún papel sobre este trámite?
Respuestas: Sí, traje documentos. / No, no traje documentos. / No sé qué documento corresponde.
P4. ¿Tiene abogado para este caso?
Variantes: ¿Cuenta con una abogada o abogado? / ¿Un abogado lleva este caso?
Respuestas: Sí, tengo abogado. / No, no tengo abogado. / No sé quién es mi abogado.
ESCENARIOS POSIBLES
Con expediente: consultar juzgado y actuación. Sin expediente: pedir orientación de inicio. No calcular
deuda ni asegurar una pensión con el documento RAG.
Referencia temática: F-OJ-101 · Tipo: mixto
OpenSoul | Documento de escenarios | 2026-10-04
18

## Página 19

ESC-OJ-104 / OJ
Presentación o seguimiento de memorial
Situación: Propuesta de conversación para presentación o seguimiento de memorial. Las respuestas son
alternativas que el usuario debe elegir; no describen hechos ya confirmados.
PREGUNTAS EN UNA SECUENCIA POSIBLE
1
Persona usuaria
Quiero consultar la entrega de mi memorial.
2
Funcionario
¿Tiene una constancia de recepción de documentos?
3
Persona usuaria
Sí, tengo constancia de recepción.
4
Funcionario
¿Tiene el NUREJ de su expediente judicial?
5
Persona usuaria
Sí, tengo el NUREJ.
6
Funcionario
¿Trajo algún documento relacionado con su solicitud?
7
Persona usuaria
Sí, traje documentos.
8
Funcionario
¿Prefiere recibir la explicación por escrito?
9
Persona usuaria
Sí, prefiero la explicación por escrito.
10
Funcionario
Pida que le confirmen por escrito el siguiente paso.
VARIANTES Y RESPUESTAS POSIBLES
P1. ¿Tiene una constancia de recepción de documentos?
Variantes: ¿Le dieron un cargo de recepción? / ¿Conserva prueba de entrega de sus documentos?
Respuestas: Sí, tengo constancia de recepción. / No, no tengo constancia. / No sé si este papel es la
constancia.
P2. ¿Tiene el NUREJ de su expediente judicial?
Variantes: ¿Conoce el número de su expediente judicial? / ¿Trajo el NUREJ?
Respuestas: Sí, tengo el NUREJ. / No, no tengo el NUREJ. / No sé cuál es el NUREJ.
P3. ¿Trajo algún documento relacionado con su solicitud?
Variantes: ¿Tiene documentos de su solicitud? / ¿Trae algún papel sobre este trámite?
Respuestas: Sí, traje documentos. / No, no traje documentos. / No sé qué documento corresponde.
P4. ¿Prefiere recibir la explicación por escrito?
Variantes: ¿Quiere una explicación escrita? / ¿Le ayuda que escriba la explicación?
Respuestas: Sí, prefiero la explicación por escrito. / No, no prefiero la explicación escrita. / No sé si la
explicación escrita me ayuda.
ESCENARIOS POSIBLES
Con cargo: preguntar recepción y seguimiento. Sin cargo: consultar cómo verificar entrega. No
garantizar admisión, resolución ni plazo.
Referencia temática: F-OJ-101 · Tipo: mixto
OpenSoul | Documento de escenarios | 2026-10-04
19

## Página 20

ESC-OJ-105 / OJ
REJAP y diferenciación de certificado
Situación: Propuesta de conversación para rejap y diferenciación de certificado. Las respuestas son
alternativas que el usuario debe elegir; no describen hechos ya confirmados.
PREGUNTAS EN UNA SECUENCIA POSIBLE
1
Persona usuaria
Quiero consultar un certificado de antecedentes penales.
2
Funcionario
¿Trajo algún documento relacionado con su solicitud?
3
Persona usuaria
Sí, traje documentos.
4
Funcionario
¿Conserva el comprobante de pago?
5
Persona usuaria
Sí, tengo el comprobante.
6
Funcionario
¿Trajo su cédula de identidad?
7
Persona usuaria
Sí, traje mi cédula.
8
Funcionario
¿Necesita un intérprete de Lengua de Señas Boliviana?
9
Persona usuaria
Sí, necesito un intérprete de LSB.
10
Funcionario
Pida que le confirmen por escrito el siguiente paso.
VARIANTES Y RESPUESTAS POSIBLES
P1. ¿Trajo algún documento relacionado con su solicitud?
Variantes: ¿Tiene documentos de su solicitud? / ¿Trae algún papel sobre este trámite?
Respuestas: Sí, traje documentos. / No, no traje documentos. / No sé qué documento corresponde.
P2. ¿Conserva el comprobante de pago?
Variantes: ¿Tiene la boleta de pago? / ¿Guardó el recibo?
Respuestas: Sí, tengo el comprobante. / No, no tengo el comprobante. / No sé dónde está el
comprobante.
P3. ¿Trajo su cédula de identidad?
Variantes: ¿Tiene su carnet con usted? / ¿Trae su documento de identidad?
Respuestas: Sí, traje mi cédula. / No, no traje mi cédula. / No sé si la traje.
P4. ¿Necesita un intérprete de Lengua de Señas Boliviana?
Variantes: ¿Requiere interpretación en LSB? / ¿Necesita apoyo de un intérprete de LSB?
Respuestas: Sí, necesito un intérprete de LSB. / No, no necesito un intérprete. / No sé cómo solicitar un
intérprete.
ESCENARIOS POSIBLES
Precisar REJAP judicial frente a certificado policial. Consultar requisitos actuales del servicio; no afirmar
que un documento reemplaza al otro.
Referencia temática: F-OJ-101 · Tipo: mixto
OpenSoul | Documento de escenarios | 2026-10-04
20

## Página 21

ESC-SEPDEP-101 / SEPDEP
Solicitar defensor por denuncia contra la persona
Situación: Propuesta de conversación para solicitar defensor por denuncia contra la persona. Las
respuestas son alternativas que el usuario debe elegir; no describen hechos ya confirmados.
PREGUNTAS EN UNA SECUENCIA POSIBLE
1
Persona usuaria
Me denunciaron y necesito defensa.
2
Funcionario
¿La denuncia es contra usted?
3
Persona usuaria
Sí, me denunciaron.
4
Funcionario
¿Tiene abogado para este caso?
5
Persona usuaria
Sí, tengo abogado.
6
Funcionario
¿Usted fue afectado por el hecho?
7
Persona usuaria
Sí, fui afectado.
8
Funcionario
¿Necesita un intérprete de Lengua de Señas Boliviana?
9
Persona usuaria
Sí, necesito un intérprete de LSB.
10
Funcionario
Pida que le confirmen por escrito el siguiente paso.
VARIANTES Y RESPUESTAS POSIBLES
P1. ¿La denuncia es contra usted?
Variantes: ¿Usted es la persona denunciada? / ¿Lo denunciaron a usted?
Respuestas: Sí, me denunciaron. / No, no me denunciaron. / No sé si me denunciaron.
P2. ¿Tiene abogado para este caso?
Variantes: ¿Cuenta con una abogada o abogado? / ¿Un abogado lleva este caso?
Respuestas: Sí, tengo abogado. / No, no tengo abogado. / No sé quién es mi abogado.
P3. ¿Usted fue afectado por el hecho?
Variantes: ¿Usted sufrió lo ocurrido? / ¿El hecho lo afectó a usted?
Respuestas: Sí, fui afectado. / No, no fui afectado. / No sé si fui afectado.
P4. ¿Necesita un intérprete de Lengua de Señas Boliviana?
Variantes: ¿Requiere interpretación en LSB? / ¿Necesita apoyo de un intérprete de LSB?
Respuestas: Sí, necesito un intérprete de LSB. / No, no necesito un intérprete. / No sé cómo solicitar un
intérprete.
ESCENARIOS POSIBLES
Denuncia contra la persona: evaluar asistencia de SEPDEP. Si únicamente es víctima: orientar a SEPDAVI.
No negar defensa por falta de un papel sin evaluación institucional.
Condiciones del MD: Turno 4: si Turno 2 es afirmado; Turno 6: si Turno 2 es negado o desconocido.
Referencia temática: F-SEPDEP-101 · Tipo: mixto
OpenSoul | Documento de escenarios | 2026-10-04
21

## Página 22

ESC-SEPDEP-102 / SEPDEP
Detención o intervención urgente del defensor
Situación: Propuesta de conversación para detención o intervención urgente del defensor. Las
respuestas son alternativas que el usuario debe elegir; no describen hechos ya confirmados.
PREGUNTAS EN UNA SECUENCIA POSIBLE
1
Persona usuaria
Estoy detenido y necesito un abogado.
2
Funcionario
¿La denuncia es contra usted?
3
Persona usuaria
Sí, me denunciaron.
4
Funcionario
¿Tiene abogado para este caso?
5
Persona usuaria
Sí, tengo abogado.
6
Funcionario
¿Recibió una notificación?
7
Persona usuaria
Sí, recibí una notificación.
8
Funcionario
¿Necesita un intérprete de Lengua de Señas Boliviana?
9
Persona usuaria
Sí, necesito un intérprete de LSB.
10
Funcionario
Pida que le confirmen por escrito el siguiente paso.
VARIANTES Y RESPUESTAS POSIBLES
P1. ¿La denuncia es contra usted?
Variantes: ¿Usted es la persona denunciada? / ¿Lo denunciaron a usted?
Respuestas: Sí, me denunciaron. / No, no me denunciaron. / No sé si me denunciaron.
P2. ¿Tiene abogado para este caso?
Variantes: ¿Cuenta con una abogada o abogado? / ¿Un abogado lleva este caso?
Respuestas: Sí, tengo abogado. / No, no tengo abogado. / No sé quién es mi abogado.
P3. ¿Recibió una notificación?
Variantes: ¿Le entregaron una notificación? / ¿Tiene una notificación de este caso?
Respuestas: Sí, recibí una notificación. / No, no recibí una notificación. / No sé si es una notificación.
P4. ¿Necesita un intérprete de Lengua de Señas Boliviana?
Variantes: ¿Requiere interpretación en LSB? / ¿Necesita apoyo de un intérprete de LSB?
Respuestas: Sí, necesito un intérprete de LSB. / No, no necesito un intérprete. / No sé cómo solicitar un
intérprete.
ESCENARIOS POSIBLES
Priorizar contacto con defensa y comunicación accesible. No pedir confesiones ni convertir silencio en
aceptación. No prometer liberación.
Referencia temática: F-SEPDEP-101 · Tipo: mixto
OpenSoul | Documento de escenarios | 2026-10-04
22

## Página 23

ESC-SEPDEP-103 / SEPDEP
Audiencia y coordinación con defensor
Situación: Propuesta de conversación para audiencia y coordinación con defensor. Las respuestas son
alternativas que el usuario debe elegir; no describen hechos ya confirmados.
PREGUNTAS EN UNA SECUENCIA POSIBLE
1
Persona usuaria
Necesito hablar con mi defensor para la audiencia.
2
Funcionario
¿Tiene abogado para este caso?
3
Persona usuaria
Sí, tengo abogado.
4
Funcionario
¿Tiene una audiencia señalada?
5
Persona usuaria
Sí, tengo una audiencia señalada.
6
Funcionario
¿Recibió una notificación?
7
Persona usuaria
Sí, recibí una notificación.
8
Funcionario
¿Necesita un intérprete de Lengua de Señas Boliviana?
9
Persona usuaria
Sí, necesito un intérprete de LSB.
10
Funcionario
Pida que le confirmen por escrito el siguiente paso.
VARIANTES Y RESPUESTAS POSIBLES
P1. ¿Tiene abogado para este caso?
Variantes: ¿Cuenta con una abogada o abogado? / ¿Un abogado lleva este caso?
Respuestas: Sí, tengo abogado. / No, no tengo abogado. / No sé quién es mi abogado.
P2. ¿Tiene una audiencia señalada?
Variantes: ¿Le comunicaron una audiencia? / ¿Existe una convocatoria a audiencia?
Respuestas: Sí, tengo una audiencia señalada. / No, no tengo audiencia señalada. / No sé si hay
audiencia señalada.
P3. ¿Recibió una notificación?
Variantes: ¿Le entregaron una notificación? / ¿Tiene una notificación de este caso?
Respuestas: Sí, recibí una notificación. / No, no recibí una notificación. / No sé si es una notificación.
P4. ¿Necesita un intérprete de Lengua de Señas Boliviana?
Variantes: ¿Requiere interpretación en LSB? / ¿Necesita apoyo de un intérprete de LSB?
Respuestas: Sí, necesito un intérprete de LSB. / No, no necesito un intérprete. / No sé cómo solicitar un
intérprete.
ESCENARIOS POSIBLES
Con defensor: pedir coordinación. Sin defensor: consultar asignación. Fecha y preparación se revisan con
la defensa, sin prometer resultados.
Referencia temática: F-SEPDEP-101 · Tipo: mixto
OpenSoul | Documento de escenarios | 2026-10-04
23

## Página 24

ESC-SEPDEP-104 / SEPDEP
Falta de recursos y evaluación del servicio
Situación: Propuesta de conversación para falta de recursos y evaluación del servicio. Las respuestas son
alternativas que el usuario debe elegir; no describen hechos ya confirmados.
PREGUNTAS EN UNA SECUENCIA POSIBLE
1
Persona usuaria
No puedo pagar abogado para mi defensa.
2
Funcionario
¿La denuncia es contra usted?
3
Persona usuaria
Sí, me denunciaron.
4
Funcionario
¿Necesita ayuda porque no puede pagar abogado?
5
Persona usuaria
Sí, no puedo pagar abogado.
6
Funcionario
¿Usted fue afectado por el hecho?
7
Persona usuaria
Sí, fui afectado.
8
Funcionario
¿Prefiere recibir la explicación por escrito?
9
Persona usuaria
Sí, prefiero la explicación por escrito.
10
Funcionario
Pida que le confirmen por escrito el siguiente paso.
VARIANTES Y RESPUESTAS POSIBLES
P1. ¿La denuncia es contra usted?
Variantes: ¿Usted es la persona denunciada? / ¿Lo denunciaron a usted?
Respuestas: Sí, me denunciaron. / No, no me denunciaron. / No sé si me denunciaron.
P2. ¿Necesita ayuda porque no puede pagar abogado?
Variantes: ¿Le falta dinero para contratar abogado? / ¿Tiene dificultad para pagar defensa legal?
Respuestas: Sí, no puedo pagar abogado. / No, puedo pagar abogado. / No sé cuánto puedo pagar.
P3. ¿Usted fue afectado por el hecho?
Variantes: ¿Usted sufrió lo ocurrido? / ¿El hecho lo afectó a usted?
Respuestas: Sí, fui afectado. / No, no fui afectado. / No sé si fui afectado.
P4. ¿Prefiere recibir la explicación por escrito?
Variantes: ¿Quiere una explicación escrita? / ¿Le ayuda que escriba la explicación?
Respuestas: Sí, prefiero la explicación por escrito. / No, no prefiero la explicación escrita. / No sé si la
explicación escrita me ayuda.
ESCENARIOS POSIBLES
La institución evalúa el servicio y sus condiciones. No afirmar concesión automática por indicar falta de
dinero. Si es víctima, aclarar la derivación.
Condiciones del MD: Turno 4: si Turno 2 es afirmado; Turno 6: si Turno 2 es negado o desconocido.
Referencia temática: F-SEPDEP-101 · Tipo: mixto
OpenSoul | Documento de escenarios | 2026-10-04
24

## Página 25

ESC-SEPDAVI-101 / SEPDAVI
Solicitar asistencia para víctima de delito
Situación: Propuesta de conversación para solicitar asistencia para víctima de delito. Las respuestas son
alternativas que el usuario debe elegir; no describen hechos ya confirmados.
PREGUNTAS EN UNA SECUENCIA POSIBLE
1
Persona usuaria
Soy víctima y necesito asistencia.
2
Funcionario
¿Usted fue afectado por el hecho?
3
Persona usuaria
Sí, fui afectado.
4
Funcionario
¿Tiene abogado para este caso?
5
Persona usuaria
Sí, tengo abogado.
6
Funcionario
¿La denuncia es contra usted?
7
Persona usuaria
Sí, me denunciaron.
8
Funcionario
¿Necesita un intérprete de Lengua de Señas Boliviana?
9
Persona usuaria
Sí, necesito un intérprete de LSB.
10
Funcionario
Pida que le confirmen por escrito el siguiente paso.
VARIANTES Y RESPUESTAS POSIBLES
P1. ¿Usted fue afectado por el hecho?
Variantes: ¿Usted sufrió lo ocurrido? / ¿El hecho lo afectó a usted?
Respuestas: Sí, fui afectado. / No, no fui afectado. / No sé si fui afectado.
P2. ¿Tiene abogado para este caso?
Variantes: ¿Cuenta con una abogada o abogado? / ¿Un abogado lleva este caso?
Respuestas: Sí, tengo abogado. / No, no tengo abogado. / No sé quién es mi abogado.
P3. ¿La denuncia es contra usted?
Variantes: ¿Usted es la persona denunciada? / ¿Lo denunciaron a usted?
Respuestas: Sí, me denunciaron. / No, no me denunciaron. / No sé si me denunciaron.
P4. ¿Necesita un intérprete de Lengua de Señas Boliviana?
Variantes: ¿Requiere interpretación en LSB? / ¿Necesita apoyo de un intérprete de LSB?
Respuestas: Sí, necesito un intérprete de LSB. / No, no necesito un intérprete. / No sé cómo solicitar un
intérprete.
ESCENARIOS POSIBLES
Persona afectada: consultar asistencia penal y apoyos disponibles. Si busca defensa por denuncia en su
contra: SEPDEP. La admisión se evalúa institucionalmente.
Condiciones del MD: Turno 4: si Turno 2 es afirmado; Turno 6: si Turno 2 es negado o desconocido.
Referencia temática: F-SEPDAVI-101 · Tipo: mixto
OpenSoul | Documento de escenarios | 2026-10-04
25

## Página 26

ESC-SEPDAVI-102 / SEPDAVI
Apoyo psicológico y social
Situación: Propuesta de conversación para apoyo psicológico y social. Las respuestas son alternativas
que el usuario debe elegir; no describen hechos ya confirmados.
PREGUNTAS EN UNA SECUENCIA POSIBLE
1
Persona usuaria
Necesito apoyo después de lo ocurrido.
2
Funcionario
¿Está en peligro ahora?
3
Persona usuaria
Sí, estoy en peligro ahora.
4
Funcionario
¿Necesita atención médica ahora?
5
Persona usuaria
Sí, necesito atención médica.
6
Funcionario
¿Desea apoyo psicológico?
7
Persona usuaria
Sí, quiero apoyo psicológico.
8
Funcionario
¿Desea orientación de trabajo social?
9
Persona usuaria
Sí, quiero orientación social.
10
Funcionario
Pida que le confirmen por escrito el siguiente paso.
VARIANTES Y RESPUESTAS POSIBLES
P1. ¿Está en peligro ahora?
Variantes: ¿Corre peligro en este momento? / ¿Existe peligro inmediato para usted?
Respuestas: Sí, estoy en peligro ahora. / No, no estoy en peligro ahora. / No sé si estoy en peligro.
P2. ¿Necesita atención médica ahora?
Variantes: ¿Necesita ayuda médica inmediata? / ¿Requiere atención de salud en este momento?
Respuestas: Sí, necesito atención médica. / No, no necesito atención médica. / No sé si necesito atención
médica.
P3. ¿Desea apoyo psicológico?
Variantes: ¿Quiere hablar con un profesional de psicología? / ¿Necesita orientación psicológica?
Respuestas: Sí, quiero apoyo psicológico. / No, no quiero apoyo psicológico. / No sé si necesito ese
apoyo.
P4. ¿Desea orientación de trabajo social?
Variantes: ¿Quiere orientación social? / ¿Necesita hablar con trabajo social?
Respuestas: Sí, quiero orientación social. / No, no quiero orientación social. / No sé si necesito
orientación social.
ESCENARIOS POSIBLES
Peligro: priorizar ayuda inmediata. Sin peligro actual: preguntar apoyo psicológico y social por separado.
No diagnosticar ni asegurar disponibilidad de profesionales.
Referencia temática: F-SEPDAVI-101 · Tipo: mixto
OpenSoul | Documento de escenarios | 2026-10-04
26

## Página 27

ESC-SEPDAVI-103 / SEPDAVI
Asistencia a familiares de persona afectada
Situación: Propuesta de conversación para asistencia a familiares de persona afectada. Las respuestas
son alternativas que el usuario debe elegir; no describen hechos ya confirmados.
PREGUNTAS EN UNA SECUENCIA POSIBLE
1
Persona usuaria
Necesito ayuda por lo ocurrido a mi familiar.
2
Funcionario
¿Usted es familiar de la persona afectada?
3
Persona usuaria
Sí, soy familiar.
4
Funcionario
¿Ya presentó una denuncia por este hecho?
5
Persona usuaria
Sí, ya presenté una denuncia.
6
Funcionario
¿Usted fue afectado por el hecho?
7
Persona usuaria
Sí, fui afectado.
8
Funcionario
¿Necesita un intérprete de Lengua de Señas Boliviana?
9
Persona usuaria
Sí, necesito un intérprete de LSB.
10
Funcionario
Pida que le confirmen por escrito el siguiente paso.
VARIANTES Y RESPUESTAS POSIBLES
P1. ¿Usted es familiar de la persona afectada?
Variantes: ¿La persona afectada es de su familia? / ¿Tiene parentesco con la persona afectada?
Respuestas: Sí, soy familiar. / No, no soy familiar. / No sé cómo explicar el parentesco.
P2. ¿Ya presentó una denuncia por este hecho?
Variantes: ¿Ya denunció lo ocurrido? / ¿Este hecho ya fue denunciado?
Respuestas: Sí, ya presenté una denuncia. / No, todavía no presenté una denuncia. / No sé si existe una
denuncia.
P3. ¿Usted fue afectado por el hecho?
Variantes: ¿Usted sufrió lo ocurrido? / ¿El hecho lo afectó a usted?
Respuestas: Sí, fui afectado. / No, no fui afectado. / No sé si fui afectado.
P4. ¿Necesita un intérprete de Lengua de Señas Boliviana?
Variantes: ¿Requiere interpretación en LSB? / ¿Necesita apoyo de un intérprete de LSB?
Respuestas: Sí, necesito un intérprete de LSB. / No, no necesito un intérprete. / No sé cómo solicitar un
intérprete.
ESCENARIOS POSIBLES
Aclarar relación con la persona afectada y necesidad de apoyo. No publicar nombres ni detalles íntimos;
confirmar procedencia de representación y asistencia.
Referencia temática: F-SEPDAVI-101 · Tipo: mixto
OpenSoul | Documento de escenarios | 2026-10-04
27

## Página 28

ESC-SEPDAVI-104 / SEPDAVI
Seguimiento del acompañamiento legal
Situación: Propuesta de conversación para seguimiento del acompañamiento legal. Las respuestas son
alternativas que el usuario debe elegir; no describen hechos ya confirmados.
PREGUNTAS EN UNA SECUENCIA POSIBLE
1
Persona usuaria
Quiero consultar el apoyo para mi caso.
2
Funcionario
¿Tiene el código de su caso en Fiscalía?
3
Persona usuaria
Sí, tengo el código fiscal.
4
Funcionario
¿Tiene abogado para este caso?
5
Persona usuaria
Sí, tengo abogado.
6
Funcionario
¿Ya presentó una denuncia por este hecho?
7
Persona usuaria
Sí, ya presenté una denuncia.
8
Funcionario
¿Prefiere recibir la explicación por escrito?
9
Persona usuaria
Sí, prefiero la explicación por escrito.
10
Funcionario
Pida que le confirmen por escrito el siguiente paso.
VARIANTES Y RESPUESTAS POSIBLES
P1. ¿Tiene el código de su caso en Fiscalía?
Variantes: ¿Conoce el código fiscal de su caso? / ¿Trajo el código del caso fiscal?
Respuestas: Sí, tengo el código fiscal. / No, no tengo el código fiscal. / No sé cuál es el código fiscal.
P2. ¿Tiene abogado para este caso?
Variantes: ¿Cuenta con una abogada o abogado? / ¿Un abogado lleva este caso?
Respuestas: Sí, tengo abogado. / No, no tengo abogado. / No sé quién es mi abogado.
P3. ¿Ya presentó una denuncia por este hecho?
Variantes: ¿Ya denunció lo ocurrido? / ¿Este hecho ya fue denunciado?
Respuestas: Sí, ya presenté una denuncia. / No, todavía no presenté una denuncia. / No sé si existe una
denuncia.
P4. ¿Prefiere recibir la explicación por escrito?
Variantes: ¿Quiere una explicación escrita? / ¿Le ayuda que escriba la explicación?
Respuestas: Sí, prefiero la explicación por escrito. / No, no prefiero la explicación escrita. / No sé si la
explicación escrita me ayuda.
ESCENARIOS POSIBLES
Con código: consultar coordinación con el equipo. Sin código: identificar recepción o solicitud previa. No
atribuir a SEPDAVI las decisiones de Fiscalía o juzgado.
Referencia temática: F-SEPDAVI-101 · Tipo: mixto
OpenSoul | Documento de escenarios | 2026-10-04
28

## Página 29

ESC-FELCC-101 / FELCC
Robo o posible extravío de celular
Situación: Propuesta de conversación para robo o posible extravío de celular. Las respuestas son
alternativas que el usuario debe elegir; no describen hechos ya confirmados.
PREGUNTAS EN UNA SECUENCIA POSIBLE
1
Persona usuaria
No encuentro mi celular y necesito ayuda.
2
Funcionario
¿Usaron violencia para quitarle el objeto?
3
Persona usuaria
Sí, usaron violencia.
4
Funcionario
¿Conoce a la persona que participó?
5
Persona usuaria
Sí, conozco a esa persona.
6
Funcionario
¿Cree que perdió el objeto?
7
Persona usuaria
Sí, creo que lo perdí.
8
Funcionario
¿Cuándo ocurrió el hecho?
9
Persona usuaria
Ocurrió hoy.
10
Funcionario
¿Dónde ocurrió el hecho?
11
Persona usuaria
Ocurrió en mi casa.
12
Funcionario
¿Tiene documentos o mensajes sobre lo ocurrido?
13
Persona usuaria
Sí, tengo mensajes.
14
Funcionario
Pida que le confirmen por escrito el siguiente paso.
VARIANTES Y RESPUESTAS POSIBLES
P1. ¿Usaron violencia para quitarle el objeto?
Variantes: ¿Lo agredieron al quitarle el objeto? / ¿Hubo agresión durante el hecho?
Respuestas: Sí, usaron violencia. / No, no usaron violencia. / No sé si hubo violencia.
P2. ¿Conoce a la persona que participó?
Variantes: ¿Sabe quién fue esa persona? / ¿Reconoce a la persona involucrada?
Respuestas: Sí, conozco a esa persona. / No, no conozco a esa persona. / No sé quién fue.
P3. ¿Cree que perdió el objeto?
Variantes: ¿Piensa que el objeto se extravió? / ¿Puede haber perdido el objeto?
Respuestas: Sí, creo que lo perdí. / No, no creo haberlo perdido. / No sé si lo perdí o lo robaron.
P4. ¿Cuándo ocurrió el hecho?
Variantes: ¿En qué momento sucedió? / ¿Cuándo pasó lo ocurrido?
Respuestas: Ocurrió hoy. / Ocurrió ayer. / Ocurrió antes. / No sé cuándo ocurrió.
P5. ¿Dónde ocurrió el hecho?
Variantes: ¿En qué lugar sucedió? / ¿Dónde pasó lo ocurrido?
Respuestas: Ocurrió en mi casa. / Ocurrió en la calle. / Ocurrió en mi trabajo. / No sé dónde ocurrió.
P6. ¿Tiene documentos o mensajes sobre lo ocurrido?
Variantes: ¿Conserva mensajes o documentos del hecho? / ¿Tiene material relacionado con lo ocurrido?
Respuestas: Sí, tengo mensajes. / No, no tengo ese material. / No sé si tengo ese material.
ESCENARIOS POSIBLES
Con violencia: describir agresión y solicitar atención. Sin certeza: distinguir robo de extravío mediante
relato; no calificar jurídicamente desde una respuesta.
Condiciones del MD: Turno 6: si Turno 2 es negado o desconocido.
Referencia temática: F-FELCC-101 · Tipo: mixto
OpenSoul | Documento de escenarios | 2026-10-04
29

## Página 30

ESC-FELCC-102 / FELCC
Estafa y transferencia de dinero
Situación: Propuesta de conversación para estafa y transferencia de dinero. Las respuestas son
alternativas que el usuario debe elegir; no describen hechos ya confirmados.
PREGUNTAS EN UNA SECUENCIA POSIBLE
1
Persona usuaria
Creo que me estafaron.
2
Funcionario
¿Realizó una transferencia de dinero?
3
Persona usuaria
Sí, realicé una transferencia.
4
Funcionario
¿Conserva el comprobante de pago?
5
Persona usuaria
Sí, tengo el comprobante.
6
Funcionario
¿Tiene documentos o mensajes sobre lo ocurrido?
7
Persona usuaria
Sí, tengo mensajes.
8
Funcionario
¿Cuándo ocurrió el hecho?
9
Persona usuaria
Ocurrió hoy.
10
Funcionario
¿Dónde ocurrió el hecho?
11
Persona usuaria
Ocurrió en mi casa.
12
Funcionario
Pida que le confirmen por escrito el siguiente paso.
VARIANTES Y RESPUESTAS POSIBLES
P1. ¿Realizó una transferencia de dinero?
Variantes: ¿Envió dinero mediante transferencia? / ¿Tiene una transferencia relacionada con el hecho?
Respuestas: Sí, realicé una transferencia. / No, no realicé una transferencia. / No sé si la transferencia se
completó.
P2. ¿Conserva el comprobante de pago?
Variantes: ¿Tiene la boleta de pago? / ¿Guardó el recibo?
Respuestas: Sí, tengo el comprobante. / No, no tengo el comprobante. / No sé dónde está el
comprobante.
P3. ¿Tiene documentos o mensajes sobre lo ocurrido?
Variantes: ¿Conserva mensajes o documentos del hecho? / ¿Tiene material relacionado con lo ocurrido?
Respuestas: Sí, tengo mensajes. / No, no tengo ese material. / No sé si tengo ese material.
P4. ¿Cuándo ocurrió el hecho?
Variantes: ¿En qué momento sucedió? / ¿Cuándo pasó lo ocurrido?
Respuestas: Ocurrió hoy. / Ocurrió ayer. / Ocurrió antes. / No sé cuándo ocurrió.
P5. ¿Dónde ocurrió el hecho?
Variantes: ¿En qué lugar sucedió? / ¿Dónde pasó lo ocurrido?
Respuestas: Ocurrió en mi casa. / Ocurrió en la calle. / Ocurrió en mi trabajo. / No sé dónde ocurrió.
ESCENARIOS POSIBLES
Transferencia: consultar comprobante. Sin transferencia: describir engaño sin presumir pago. Separar
problema comercial de posible delito; autoridad valora el relato.
Condiciones del MD: Turno 4: si Turno 2 es afirmado.
Referencia temática: F-FELCC-101 · Tipo: mixto
OpenSoul | Documento de escenarios | 2026-10-04
30

## Página 31

ESC-FELCC-103 / FELCC
Persona desaparecida y última información
Situación: Propuesta de conversación para persona desaparecida y última información. Las respuestas
son alternativas que el usuario debe elegir; no describen hechos ya confirmados.
PREGUNTAS EN UNA SECUENCIA POSIBLE
1
Persona usuaria
No sé dónde está mi familiar.
2
Funcionario
¿Desconoce el paradero actual de esa persona?
3
Persona usuaria
Sí, desconozco su paradero.
4
Funcionario
¿Hay un niño o adolescente afectado?
5
Persona usuaria
Sí, hay un niño afectado.
6
Funcionario
¿Tiene un contacto seguro para recibir información?
7
Persona usuaria
Sí, tengo un contacto seguro.
8
Funcionario
¿Cuándo ocurrió el hecho?
9
Persona usuaria
Ocurrió hoy.
10
Funcionario
¿Dónde ocurrió el hecho?
11
Persona usuaria
Ocurrió en mi casa.
12
Funcionario
Pida que le confirmen por escrito el siguiente paso.
VARIANTES Y RESPUESTAS POSIBLES
P1. ¿Desconoce el paradero actual de esa persona?
Variantes: ¿No sabe dónde está esa persona? / ¿La persona está desaparecida?
Respuestas: Sí, desconozco su paradero. / No, conozco su paradero. / No sé si está desaparecida.
P2. ¿Hay un niño o adolescente afectado?
Variantes: ¿Lo ocurrido afecta a una persona menor de edad? / ¿Hay una niña, niño o adolescente
involucrado?
Respuestas: Sí, hay un niño afectado. / No, no hay un niño afectado. / No sé si hay un niño afectado.
P3. ¿Tiene un contacto seguro para recibir información?
Variantes: ¿Puede indicar un medio seguro de contacto? / ¿Cuenta con un contacto que sea seguro?
Respuestas: Sí, tengo un contacto seguro. / No, no tengo un contacto seguro. / No sé qué contacto es
seguro.
P4. ¿Cuándo ocurrió el hecho?
Variantes: ¿En qué momento sucedió? / ¿Cuándo pasó lo ocurrido?
Respuestas: Ocurrió hoy. / Ocurrió ayer. / Ocurrió antes. / No sé cuándo ocurrió.
P5. ¿Dónde ocurrió el hecho?
Variantes: ¿En qué lugar sucedió? / ¿Dónde pasó lo ocurrido?
Respuestas: Ocurrió en mi casa. / Ocurrió en la calle. / Ocurrió en mi trabajo. / No sé dónde ocurrió.
ESCENARIOS POSIBLES
Paradero desconocido: pedir atención inmediata de búsqueda. Si es menor: comunicarlo. No indicar
esperas obligatorias de horas para denunciar.
Condiciones del MD: Turno 4: si Turno 2 es afirmado; Turno 6: si Turno 2 es afirmado.
Referencia temática: F-FELCC-101 · Tipo: mixto
OpenSoul | Documento de escenarios | 2026-10-04
31

## Página 32

ESC-FELCC-104 / FELCC
Amenazas fuera de la relación de pareja
Situación: Propuesta de conversación para amenazas fuera de la relación de pareja. Las respuestas son
alternativas que el usuario debe elegir; no describen hechos ya confirmados.
PREGUNTAS EN UNA SECUENCIA POSIBLE
1
Persona usuaria
Una persona me está amenazando.
2
Funcionario
¿Está en peligro ahora?
3
Persona usuaria
Sí, estoy en peligro ahora.
4
Funcionario
¿Necesita atención médica ahora?
5
Persona usuaria
Sí, necesito atención médica.
6
Funcionario
¿La persona que lo agrede es su pareja?
7
Persona usuaria
Sí, es mi pareja.
8
Funcionario
¿Tiene documentos o mensajes sobre lo ocurrido?
9
Persona usuaria
Sí, tengo mensajes.
10
Funcionario
Pida que le confirmen por escrito el siguiente paso.
VARIANTES Y RESPUESTAS POSIBLES
P1. ¿Está en peligro ahora?
Variantes: ¿Corre peligro en este momento? / ¿Existe peligro inmediato para usted?
Respuestas: Sí, estoy en peligro ahora. / No, no estoy en peligro ahora. / No sé si estoy en peligro.
P2. ¿Necesita atención médica ahora?
Variantes: ¿Necesita ayuda médica inmediata? / ¿Requiere atención de salud en este momento?
Respuestas: Sí, necesito atención médica. / No, no necesito atención médica. / No sé si necesito atención
médica.
P3. ¿La persona que lo agrede es su pareja?
Variantes: ¿Su pareja realiza la agresión? / ¿La agresión proviene de su pareja?
Respuestas: Sí, es mi pareja. / No, no es mi pareja. / No sé cómo explicar esa relación.
P4. ¿Tiene documentos o mensajes sobre lo ocurrido?
Variantes: ¿Conserva mensajes o documentos del hecho? / ¿Tiene material relacionado con lo ocurrido?
Respuestas: Sí, tengo mensajes. / No, no tengo ese material. / No sé si tengo ese material.
ESCENARIOS POSIBLES
Peligro: atención urgente. Sin riesgo actual: aclarar contexto de amenazas. Si hay violencia de pareja o
familiar, consultar ruta FELCV; autoridad define competencia.
Referencia temática: F-FELCC-101 · Tipo: mixto
OpenSoul | Documento de escenarios | 2026-10-04
32

## Página 33

ESC-FELCC-105 / FELCC
Seguimiento con investigador policial
Situación: Propuesta de conversación para seguimiento con investigador policial. Las respuestas son
alternativas que el usuario debe elegir; no describen hechos ya confirmados.
PREGUNTAS EN UNA SECUENCIA POSIBLE
1
Persona usuaria
Quiero consultar mi denuncia en la Policía.
2
Funcionario
¿Ya presentó una denuncia por este hecho?
3
Persona usuaria
Sí, ya presenté una denuncia.
4
Funcionario
¿Tiene el código de su caso en Fiscalía?
5
Persona usuaria
Sí, tengo el código fiscal.
6
Funcionario
¿Trajo algún documento relacionado con su solicitud?
7
Persona usuaria
Sí, traje documentos.
8
Funcionario
¿Necesita un intérprete de Lengua de Señas Boliviana?
9
Persona usuaria
Sí, necesito un intérprete de LSB.
10
Funcionario
Pida que le confirmen por escrito el siguiente paso.
VARIANTES Y RESPUESTAS POSIBLES
P1. ¿Ya presentó una denuncia por este hecho?
Variantes: ¿Ya denunció lo ocurrido? / ¿Este hecho ya fue denunciado?
Respuestas: Sí, ya presenté una denuncia. / No, todavía no presenté una denuncia. / No sé si existe una
denuncia.
P2. ¿Tiene el código de su caso en Fiscalía?
Variantes: ¿Conoce el código fiscal de su caso? / ¿Trajo el código del caso fiscal?
Respuestas: Sí, tengo el código fiscal. / No, no tengo el código fiscal. / No sé cuál es el código fiscal.
P3. ¿Trajo algún documento relacionado con su solicitud?
Variantes: ¿Tiene documentos de su solicitud? / ¿Trae algún papel sobre este trámite?
Respuestas: Sí, traje documentos. / No, no traje documentos. / No sé qué documento corresponde.
P4. ¿Necesita un intérprete de Lengua de Señas Boliviana?
Variantes: ¿Requiere interpretación en LSB? / ¿Necesita apoyo de un intérprete de LSB?
Respuestas: Sí, necesito un intérprete de LSB. / No, no necesito un intérprete. / No sé cómo solicitar un
intérprete.
ESCENARIOS POSIBLES
Denuncia previa: consultar investigador y constancia. Sin denuncia: aclarar recepción inicial. Código
policial y código fiscal pueden diferir; no inventar equivalencias.
Condiciones del MD: Turno 4: si Turno 2 es afirmado.
Referencia temática: F-FELCC-101 · Tipo: mixto
OpenSoul | Documento de escenarios | 2026-10-04
33

## Página 34

ESC-FELCV-101 / FELCV
Violencia familiar y riesgo inmediato
Situación: Propuesta de conversación para violencia familiar y riesgo inmediato. Las respuestas son
alternativas que el usuario debe elegir; no describen hechos ya confirmados.
PREGUNTAS EN UNA SECUENCIA POSIBLE
1
Persona usuaria
Mi pareja me agrede y necesito ayuda.
2
Funcionario
¿Está en peligro ahora?
3
Persona usuaria
Sí, estoy en peligro ahora.
4
Funcionario
¿Necesita atención médica ahora?
5
Persona usuaria
Sí, necesito atención médica.
6
Funcionario
¿Puede comunicarse aquí sin ponerse en peligro?
7
Persona usuaria
Sí, puedo hablar aquí con seguridad.
8
Funcionario
¿Ya presentó una denuncia por este hecho?
9
Persona usuaria
Sí, ya presenté una denuncia.
10
Funcionario
¿Necesita un intérprete de Lengua de Señas Boliviana?
11
Persona usuaria
Sí, necesito un intérprete de LSB.
12
Funcionario
Pida que le confirmen por escrito el siguiente paso.
VARIANTES Y RESPUESTAS POSIBLES
P1. ¿Está en peligro ahora?
Variantes: ¿Corre peligro en este momento? / ¿Existe peligro inmediato para usted?
Respuestas: Sí, estoy en peligro ahora. / No, no estoy en peligro ahora. / No sé si estoy en peligro.
P2. ¿Necesita atención médica ahora?
Variantes: ¿Necesita ayuda médica inmediata? / ¿Requiere atención de salud en este momento?
Respuestas: Sí, necesito atención médica. / No, no necesito atención médica. / No sé si necesito atención
médica.
P3. ¿Puede comunicarse aquí sin ponerse en peligro?
Variantes: ¿Es seguro para usted conversar aquí? / ¿Puede responder aquí con seguridad?
Respuestas: Sí, puedo hablar aquí con seguridad. / No, aquí no estoy seguro. / No sé si este lugar es
seguro.
P4. ¿Ya presentó una denuncia por este hecho?
Variantes: ¿Ya denunció lo ocurrido? / ¿Este hecho ya fue denunciado?
Respuestas: Sí, ya presenté una denuncia. / No, todavía no presenté una denuncia. / No sé si existe una
denuncia.
P5. ¿Necesita un intérprete de Lengua de Señas Boliviana?
Variantes: ¿Requiere interpretación en LSB? / ¿Necesita apoyo de un intérprete de LSB?
Respuestas: Sí, necesito un intérprete de LSB. / No, no necesito un intérprete. / No sé cómo solicitar un
intérprete.
ESCENARIOS POSIBLES
Priorizar seguridad y salud. No condicionar atención a completar el diálogo. Sin riesgo inmediato
declarado: orientar denuncia y apoyo sin minimizar la violencia.
Referencia temática: F-FELCV-101 · Tipo: mixto
OpenSoul | Documento de escenarios | 2026-10-04
34

## Página 35

ESC-FELCV-102 / FELCV
Violencia psicológica y amenazas
Situación: Propuesta de conversación para violencia psicológica y amenazas. Las respuestas son
alternativas que el usuario debe elegir; no describen hechos ya confirmados.
PREGUNTAS EN UNA SECUENCIA POSIBLE
1
Persona usuaria
Recibo amenazas y tengo miedo.
2
Funcionario
¿Está en peligro ahora?
3
Persona usuaria
Sí, estoy en peligro ahora.
4
Funcionario
¿Necesita atención médica ahora?
5
Persona usuaria
Sí, necesito atención médica.
6
Funcionario
¿La persona que lo agrede es su pareja?
7
Persona usuaria
Sí, es mi pareja.
8
Funcionario
¿Tiene documentos o mensajes sobre lo ocurrido?
9
Persona usuaria
Sí, tengo mensajes.
10
Funcionario
Pida que le confirmen por escrito el siguiente paso.
VARIANTES Y RESPUESTAS POSIBLES
P1. ¿Está en peligro ahora?
Variantes: ¿Corre peligro en este momento? / ¿Existe peligro inmediato para usted?
Respuestas: Sí, estoy en peligro ahora. / No, no estoy en peligro ahora. / No sé si estoy en peligro.
P2. ¿Necesita atención médica ahora?
Variantes: ¿Necesita ayuda médica inmediata? / ¿Requiere atención de salud en este momento?
Respuestas: Sí, necesito atención médica. / No, no necesito atención médica. / No sé si necesito atención
médica.
P3. ¿La persona que lo agrede es su pareja?
Variantes: ¿Su pareja realiza la agresión? / ¿La agresión proviene de su pareja?
Respuestas: Sí, es mi pareja. / No, no es mi pareja. / No sé cómo explicar esa relación.
P4. ¿Tiene documentos o mensajes sobre lo ocurrido?
Variantes: ¿Conserva mensajes o documentos del hecho? / ¿Tiene material relacionado con lo ocurrido?
Respuestas: Sí, tengo mensajes. / No, no tengo ese material. / No sé si tengo ese material.
ESCENARIOS POSIBLES
Peligro: ayuda inmediata. Sin riesgo declarado: aclarar vínculo y mensajes. La ausencia de lesión visible
no convierte el caso en irrelevante.
Referencia temática: F-FELCV-101 · Tipo: mixto
OpenSoul | Documento de escenarios | 2026-10-04
35

## Página 36

ESC-FELCV-103 / FELCV
Violencia sexual y atención accesible
Situación: Propuesta de conversación para violencia sexual y atención accesible. Las respuestas son
alternativas que el usuario debe elegir; no describen hechos ya confirmados.
PREGUNTAS EN UNA SECUENCIA POSIBLE
1
Persona usuaria
Necesito ayuda por violencia sexual.
2
Funcionario
¿Está en peligro ahora?
3
Persona usuaria
Sí, estoy en peligro ahora.
4
Funcionario
¿Necesita atención médica ahora?
5
Persona usuaria
Sí, necesito atención médica.
6
Funcionario
¿Puede comunicarse aquí sin ponerse en peligro?
7
Persona usuaria
Sí, puedo hablar aquí con seguridad.
8
Funcionario
¿Hay un niño o adolescente afectado?
9
Persona usuaria
Sí, hay un niño afectado.
10
Funcionario
¿Necesita un intérprete de Lengua de Señas Boliviana?
11
Persona usuaria
Sí, necesito un intérprete de LSB.
12
Funcionario
Pida que le confirmen por escrito el siguiente paso.
VARIANTES Y RESPUESTAS POSIBLES
P1. ¿Está en peligro ahora?
Variantes: ¿Corre peligro en este momento? / ¿Existe peligro inmediato para usted?
Respuestas: Sí, estoy en peligro ahora. / No, no estoy en peligro ahora. / No sé si estoy en peligro.
P2. ¿Necesita atención médica ahora?
Variantes: ¿Necesita ayuda médica inmediata? / ¿Requiere atención de salud en este momento?
Respuestas: Sí, necesito atención médica. / No, no necesito atención médica. / No sé si necesito atención
médica.
P3. ¿Puede comunicarse aquí sin ponerse en peligro?
Variantes: ¿Es seguro para usted conversar aquí? / ¿Puede responder aquí con seguridad?
Respuestas: Sí, puedo hablar aquí con seguridad. / No, aquí no estoy seguro. / No sé si este lugar es
seguro.
P4. ¿Hay un niño o adolescente afectado?
Variantes: ¿Lo ocurrido afecta a una persona menor de edad? / ¿Hay una niña, niño o adolescente
involucrado?
Respuestas: Sí, hay un niño afectado. / No, no hay un niño afectado. / No sé si hay un niño afectado.
P5. ¿Necesita un intérprete de Lengua de Señas Boliviana?
Variantes: ¿Requiere interpretación en LSB? / ¿Necesita apoyo de un intérprete de LSB?
Respuestas: Sí, necesito un intérprete de LSB. / No, no necesito un intérprete. / No sé cómo solicitar un
intérprete.
ESCENARIOS POSIBLES
Facilitar atención sin interrogatorio detallado. No exigir relato íntimo para orientar. Si es menor, activar
coordinación de protección correspondiente.
Referencia temática: F-FELCV-101 · Tipo: mixto
OpenSoul | Documento de escenarios | 2026-10-04
36

## Página 37

ESC-FELCV-104 / FELCV
Medidas de protección y posible incumplimiento
Situación: Propuesta de conversación para medidas de protección y posible incumplimiento. Las
respuestas son alternativas que el usuario debe elegir; no describen hechos ya confirmados.
PREGUNTAS EN UNA SECUENCIA POSIBLE
1
Persona usuaria
Quiero informar sobre mis medidas de protección.
2
Funcionario
¿Le comunicaron medidas de protección?
3
Persona usuaria
Sí, me comunicaron medidas de protección.
4
Funcionario
¿La persona incumplió las medidas de protección?
5
Persona usuaria
Sí, incumplió las medidas.
6
Funcionario
¿Recibió una notificación?
7
Persona usuaria
Sí, recibí una notificación.
8
Funcionario
¿Está en peligro ahora?
9
Persona usuaria
Sí, estoy en peligro ahora.
10
Funcionario
Pida que le confirmen por escrito el siguiente paso.
VARIANTES Y RESPUESTAS POSIBLES
P1. ¿Le comunicaron medidas de protección?
Variantes: ¿Recibió información sobre medidas de protección? / ¿Tiene un documento sobre medidas de
protección?
Respuestas: Sí, me comunicaron medidas de protección. / No, no me comunicaron medidas de
protección. / No sé si tengo medidas de protección.
P2. ¿La persona incumplió las medidas de protección?
Variantes: ¿La persona desobedeció esas medidas? / ¿Ocurrió un incumplimiento de las medidas?
Respuestas: Sí, incumplió las medidas. / No, no incumplió las medidas. / No sé si lo ocurrido es
incumplimiento.
P3. ¿Recibió una notificación?
Variantes: ¿Le entregaron una notificación? / ¿Tiene una notificación de este caso?
Respuestas: Sí, recibí una notificación. / No, no recibí una notificación. / No sé si es una notificación.
P4. ¿Está en peligro ahora?
Variantes: ¿Corre peligro en este momento? / ¿Existe peligro inmediato para usted?
Respuestas: Sí, estoy en peligro ahora. / No, no estoy en peligro ahora. / No sé si estoy en peligro.
ESCENARIOS POSIBLES
Con medidas comunicadas: preguntar incumplimiento. Sin medidas conocidas: pedir aclaración del
documento. Si existe peligro actual, priorizar ayuda sin esperar comprobantes.
Condiciones del MD: Turno 4: si Turno 2 es afirmado; Turno 6: si Turno 2 es negado o desconocido.
Referencia temática: F-FELCV-101 · Tipo: mixto
OpenSoul | Documento de escenarios | 2026-10-04
37

## Página 38

ESC-FELCV-105 / FELCV
Seguimiento y apoyo de SLIM o SEPDAVI
Situación: Propuesta de conversación para seguimiento y apoyo de slim o sepdavi. Las respuestas son
alternativas que el usuario debe elegir; no describen hechos ya confirmados.
PREGUNTAS EN UNA SECUENCIA POSIBLE
1
Persona usuaria
Quiero consultar mi denuncia por violencia.
2
Funcionario
¿Ya presentó una denuncia por este hecho?
3
Persona usuaria
Sí, ya presenté una denuncia.
4
Funcionario
¿Tiene el código de su caso en Fiscalía?
5
Persona usuaria
Sí, tengo el código fiscal.
6
Funcionario
¿Desea apoyo psicológico?
7
Persona usuaria
Sí, quiero apoyo psicológico.
8
Funcionario
¿Necesita un intérprete de Lengua de Señas Boliviana?
9
Persona usuaria
Sí, necesito un intérprete de LSB.
10
Funcionario
Pida que le confirmen por escrito el siguiente paso.
VARIANTES Y RESPUESTAS POSIBLES
P1. ¿Ya presentó una denuncia por este hecho?
Variantes: ¿Ya denunció lo ocurrido? / ¿Este hecho ya fue denunciado?
Respuestas: Sí, ya presenté una denuncia. / No, todavía no presenté una denuncia. / No sé si existe una
denuncia.
P2. ¿Tiene el código de su caso en Fiscalía?
Variantes: ¿Conoce el código fiscal de su caso? / ¿Trajo el código del caso fiscal?
Respuestas: Sí, tengo el código fiscal. / No, no tengo el código fiscal. / No sé cuál es el código fiscal.
P3. ¿Desea apoyo psicológico?
Variantes: ¿Quiere hablar con un profesional de psicología? / ¿Necesita orientación psicológica?
Respuestas: Sí, quiero apoyo psicológico. / No, no quiero apoyo psicológico. / No sé si necesito ese
apoyo.
P4. ¿Necesita un intérprete de Lengua de Señas Boliviana?
Variantes: ¿Requiere interpretación en LSB? / ¿Necesita apoyo de un intérprete de LSB?
Respuestas: Sí, necesito un intérprete de LSB. / No, no necesito un intérprete. / No sé cómo solicitar un
intérprete.
ESCENARIOS POSIBLES
Denuncia previa: consultar caso. Sin denuncia: pedir recepción. SLIM y SEPDAVI pueden apoyar según
competencia; no reemplazan decisiones fiscales o judiciales.
Condiciones del MD: Turno 4: si Turno 2 es afirmado.
Referencia temática: F-FELCV-101 · Tipo: mixto
OpenSoul | Documento de escenarios | 2026-10-04
38

## Página 39

ESC-IMP-101 / IMP
Deuda de vehículo por placa
Situación: Propuesta de conversación para deuda de vehículo por placa. Las respuestas son alternativas
que el usuario debe elegir; no describen hechos ya confirmados.
PREGUNTAS EN UNA SECUENCIA POSIBLE
1
Persona usuaria
Quiero consultar la deuda de mi vehículo.
2
Funcionario
¿Tiene la placa de su vehículo?
3
Persona usuaria
Sí, tengo la placa.
4
Funcionario
¿Conserva el comprobante de pago?
5
Persona usuaria
Sí, tengo el comprobante.
6
Funcionario
¿Trajo algún documento relacionado con su solicitud?
7
Persona usuaria
Sí, traje documentos.
8
Funcionario
¿Prefiere recibir la explicación por escrito?
9
Persona usuaria
Sí, prefiero la explicación por escrito.
10
Funcionario
Pida que le confirmen por escrito el siguiente paso.
VARIANTES Y RESPUESTAS POSIBLES
P1. ¿Tiene la placa de su vehículo?
Variantes: ¿Conoce la placa del vehículo? / ¿Trajo el dato de la placa?
Respuestas: Sí, tengo la placa. / No, no tengo la placa. / No sé cuál es la placa.
P2. ¿Conserva el comprobante de pago?
Variantes: ¿Tiene la boleta de pago? / ¿Guardó el recibo?
Respuestas: Sí, tengo el comprobante. / No, no tengo el comprobante. / No sé dónde está el
comprobante.
P3. ¿Trajo algún documento relacionado con su solicitud?
Variantes: ¿Tiene documentos de su solicitud? / ¿Trae algún papel sobre este trámite?
Respuestas: Sí, traje documentos. / No, no traje documentos. / No sé qué documento corresponde.
P4. ¿Prefiere recibir la explicación por escrito?
Variantes: ¿Quiere una explicación escrita? / ¿Le ayuda que escriba la explicación?
Respuestas: Sí, prefiero la explicación por escrito. / No, no prefiero la explicación escrita. / No sé si la
explicación escrita me ayuda.
ESCENARIOS POSIBLES
Con placa: consultar vehículo. Sin placa: preguntar cómo localizar el identificador. Monto y gestiones
adeudadas se consultan en vivo.
Referencia temática: F-IMP-101 · Tipo: mixto
OpenSoul | Documento de escenarios | 2026-10-04
39

## Página 40

ESC-IMP-102 / IMP
Deuda de inmueble y registro municipal
Situación: Propuesta de conversación para deuda de inmueble y registro municipal. Las respuestas son
alternativas que el usuario debe elegir; no describen hechos ya confirmados.
PREGUNTAS EN UNA SECUENCIA POSIBLE
1
Persona usuaria
Quiero consultar los impuestos de mi casa.
2
Funcionario
¿Tiene el código catastral del inmueble?
3
Persona usuaria
Sí, tengo el código catastral.
4
Funcionario
¿Conserva el comprobante de pago?
5
Persona usuaria
Sí, tengo el comprobante.
6
Funcionario
¿Trajo algún documento relacionado con su solicitud?
7
Persona usuaria
Sí, traje documentos.
8
Funcionario
¿Prefiere recibir la explicación por escrito?
9
Persona usuaria
Sí, prefiero la explicación por escrito.
10
Funcionario
Pida que le confirmen por escrito el siguiente paso.
VARIANTES Y RESPUESTAS POSIBLES
P1. ¿Tiene el código catastral del inmueble?
Variantes: ¿Conoce el código catastral de su casa? / ¿Trajo el dato catastral del inmueble?
Respuestas: Sí, tengo el código catastral. / No, no tengo el código catastral. / No sé cuál es el código
catastral.
P2. ¿Conserva el comprobante de pago?
Variantes: ¿Tiene la boleta de pago? / ¿Guardó el recibo?
Respuestas: Sí, tengo el comprobante. / No, no tengo el comprobante. / No sé dónde está el
comprobante.
P3. ¿Trajo algún documento relacionado con su solicitud?
Variantes: ¿Tiene documentos de su solicitud? / ¿Trae algún papel sobre este trámite?
Respuestas: Sí, traje documentos. / No, no traje documentos. / No sé qué documento corresponde.
P4. ¿Prefiere recibir la explicación por escrito?
Variantes: ¿Quiere una explicación escrita? / ¿Le ayuda que escriba la explicación?
Respuestas: Sí, prefiero la explicación por escrito. / No, no prefiero la explicación escrita. / No sé si la
explicación escrita me ayuda.
ESCENARIOS POSIBLES
Con código: consultar inmueble. Sin código: pedir orientación con documentos anteriores. No inferir que
deuda pagada demuestra propiedad.
Referencia temática: F-IMP-101 · Tipo: mixto
OpenSoul | Documento de escenarios | 2026-10-04
40

## Página 41

ESC-IMP-103 / IMP
Pago realizado que no aparece registrado
Situación: Propuesta de conversación para pago realizado que no aparece registrado. Las respuestas son
alternativas que el usuario debe elegir; no describen hechos ya confirmados.
PREGUNTAS EN UNA SECUENCIA POSIBLE
1
Persona usuaria
Pagué mis impuestos y todavía aparece deuda.
2
Funcionario
¿Conserva el comprobante de pago?
3
Persona usuaria
Sí, tengo el comprobante.
4
Funcionario
¿Ya realizó un pago relacionado con este trámite?
5
Persona usuaria
Sí, ya realicé un pago.
6
Funcionario
¿Trajo algún documento relacionado con su solicitud?
7
Persona usuaria
Sí, traje documentos.
8
Funcionario
¿Prefiere recibir la explicación por escrito?
9
Persona usuaria
Sí, prefiero la explicación por escrito.
10
Funcionario
Pida que le confirmen por escrito el siguiente paso.
VARIANTES Y RESPUESTAS POSIBLES
P1. ¿Conserva el comprobante de pago?
Variantes: ¿Tiene la boleta de pago? / ¿Guardó el recibo?
Respuestas: Sí, tengo el comprobante. / No, no tengo el comprobante. / No sé dónde está el
comprobante.
P2. ¿Ya realizó un pago relacionado con este trámite?
Variantes: ¿Pagó por esta gestión? / ¿Hizo un pago para este trámite?
Respuestas: Sí, ya realicé un pago. / No, no realicé ningún pago. / No sé si el pago fue registrado.
P3. ¿Trajo algún documento relacionado con su solicitud?
Variantes: ¿Tiene documentos de su solicitud? / ¿Trae algún papel sobre este trámite?
Respuestas: Sí, traje documentos. / No, no traje documentos. / No sé qué documento corresponde.
P4. ¿Prefiere recibir la explicación por escrito?
Variantes: ¿Quiere una explicación escrita? / ¿Le ayuda que escriba la explicación?
Respuestas: Sí, prefiero la explicación por escrito. / No, no prefiero la explicación escrita. / No sé si la
explicación escrita me ayuda.
ESCENARIOS POSIBLES
Con recibo: pedir verificación del pago. Sin recibo: consultar recuperación de constancia. No declarar
cancelada la deuda desde el relato.
Referencia temática: F-IMP-101 · Tipo: mixto
OpenSoul | Documento de escenarios | 2026-10-04
41

## Página 42

ESC-IMP-104 / IMP
Consulta sobre cuotas o descuentos vigentes
Situación: Propuesta de conversación para consulta sobre cuotas o descuentos vigentes. Las respuestas
son alternativas que el usuario debe elegir; no describen hechos ya confirmados.
PREGUNTAS EN UNA SECUENCIA POSIBLE
1
Persona usuaria
Quiero consultar opciones para pagar mi deuda.
2
Funcionario
¿Quiere consultar una deuda pendiente?
3
Persona usuaria
Sí, quiero consultar la deuda.
4
Funcionario
¿Tiene la placa de su vehículo?
5
Persona usuaria
Sí, tengo la placa.
6
Funcionario
¿Tiene el código catastral del inmueble?
7
Persona usuaria
Sí, tengo el código catastral.
8
Funcionario
¿Prefiere recibir la explicación por escrito?
9
Persona usuaria
Sí, prefiero la explicación por escrito.
10
Funcionario
Pida que le confirmen por escrito el siguiente paso.
VARIANTES Y RESPUESTAS POSIBLES
P1. ¿Quiere consultar una deuda pendiente?
Variantes: ¿Desea conocer si tiene deuda? / ¿Busca información sobre una deuda?
Respuestas: Sí, quiero consultar la deuda. / No, no busco consultar deuda. / No sé si tengo deuda.
P2. ¿Tiene la placa de su vehículo?
Variantes: ¿Conoce la placa del vehículo? / ¿Trajo el dato de la placa?
Respuestas: Sí, tengo la placa. / No, no tengo la placa. / No sé cuál es la placa.
P3. ¿Tiene el código catastral del inmueble?
Variantes: ¿Conoce el código catastral de su casa? / ¿Trajo el dato catastral del inmueble?
Respuestas: Sí, tengo el código catastral. / No, no tengo el código catastral. / No sé cuál es el código
catastral.
P4. ¿Prefiere recibir la explicación por escrito?
Variantes: ¿Quiere una explicación escrita? / ¿Le ayuda que escriba la explicación?
Respuestas: Sí, prefiero la explicación por escrito. / No, no prefiero la explicación escrita. / No sé si la
explicación escrita me ayuda.
ESCENARIOS POSIBLES
Separar vehículo e inmueble antes de orientar. Planes y beneficios requieren confirmación actual; no
repetir porcentajes de campañas anteriores.
Condiciones del MD: Turno 4: si Turno 2 es afirmado; Turno 6: si Turno 2 es afirmado.
Referencia temática: F-IMP-101 · Tipo: mixto
OpenSoul | Documento de escenarios | 2026-10-04
42

## Página 43

ESC-DDRR-101 / DDRR
Solicitar Folio Real actualizado
Situación: Propuesta de conversación para solicitar folio real actualizado. Las respuestas son alternativas
que el usuario debe elegir; no describen hechos ya confirmados.
PREGUNTAS EN UNA SECUENCIA POSIBLE
1
Persona usuaria
Quiero consultar el Folio Real de mi casa.
2
Funcionario
¿Tiene la matrícula de Derechos Reales?
3
Persona usuaria
Sí, tengo la matrícula.
4
Funcionario
¿Trajo un Folio Real anterior?
5
Persona usuaria
Sí, traje el Folio Real.
6
Funcionario
¿Trajo algún documento relacionado con su solicitud?
7
Persona usuaria
Sí, traje documentos.
8
Funcionario
¿Necesita un intérprete de Lengua de Señas Boliviana?
9
Persona usuaria
Sí, necesito un intérprete de LSB.
10
Funcionario
Pida que le confirmen por escrito el siguiente paso.
VARIANTES Y RESPUESTAS POSIBLES
P1. ¿Tiene la matrícula de Derechos Reales?
Variantes: ¿Conoce la matrícula del inmueble? / ¿Trajo el número de matrícula registral?
Respuestas: Sí, tengo la matrícula. / No, no tengo la matrícula. / No sé cuál es la matrícula.
P2. ¿Trajo un Folio Real anterior?
Variantes: ¿Tiene un Folio Real del inmueble? / ¿Conserva el Folio Real antiguo?
Respuestas: Sí, traje el Folio Real. / No, no traje el Folio Real. / No sé si este documento es Folio Real.
P3. ¿Trajo algún documento relacionado con su solicitud?
Variantes: ¿Tiene documentos de su solicitud? / ¿Trae algún papel sobre este trámite?
Respuestas: Sí, traje documentos. / No, no traje documentos. / No sé qué documento corresponde.
P4. ¿Necesita un intérprete de Lengua de Señas Boliviana?
Variantes: ¿Requiere interpretación en LSB? / ¿Necesita apoyo de un intérprete de LSB?
Respuestas: Sí, necesito un intérprete de LSB. / No, no necesito un intérprete. / No sé cómo solicitar un
intérprete.
ESCENARIOS POSIBLES
Con matrícula: pedir servicio correspondiente. Sin matrícula: consultar búsqueda. Arancel y requisitos
actuales se confirman en la oficina.
Condiciones del MD: Turno 4: si Turno 2 es afirmado; Turno 6: si Turno 2 es negado o desconocido.
Referencia temática: F-DDRR-101 · Tipo: mixto
OpenSoul | Documento de escenarios | 2026-10-04
43

## Página 44

ESC-DDRR-102 / DDRR
Consultar gravámenes o certificado alodial
Situación: Propuesta de conversación para consultar gravámenes o certificado alodial. Las respuestas
son alternativas que el usuario debe elegir; no describen hechos ya confirmados.
PREGUNTAS EN UNA SECUENCIA POSIBLE
1
Persona usuaria
Quiero saber si mi casa tiene gravámenes.
2
Funcionario
¿Tiene la matrícula de Derechos Reales?
3
Persona usuaria
Sí, tengo la matrícula.
4
Funcionario
¿Usted figura como titular del trámite?
5
Persona usuaria
Sí, soy el titular.
6
Funcionario
¿Trajo algún documento relacionado con su solicitud?
7
Persona usuaria
Sí, traje documentos.
8
Funcionario
¿Prefiere recibir la explicación por escrito?
9
Persona usuaria
Sí, prefiero la explicación por escrito.
10
Funcionario
Pida que le confirmen por escrito el siguiente paso.
VARIANTES Y RESPUESTAS POSIBLES
P1. ¿Tiene la matrícula de Derechos Reales?
Variantes: ¿Conoce la matrícula del inmueble? / ¿Trajo el número de matrícula registral?
Respuestas: Sí, tengo la matrícula. / No, no tengo la matrícula. / No sé cuál es la matrícula.
P2. ¿Usted figura como titular del trámite?
Variantes: ¿El trámite está a su nombre? / ¿Usted es el titular registrado?
Respuestas: Sí, soy el titular. / No, no soy el titular. / No sé quién figura como titular.
P3. ¿Trajo algún documento relacionado con su solicitud?
Variantes: ¿Tiene documentos de su solicitud? / ¿Trae algún papel sobre este trámite?
Respuestas: Sí, traje documentos. / No, no traje documentos. / No sé qué documento corresponde.
P4. ¿Prefiere recibir la explicación por escrito?
Variantes: ¿Quiere una explicación escrita? / ¿Le ayuda que escriba la explicación?
Respuestas: Sí, prefiero la explicación por escrito. / No, no prefiero la explicación escrita. / No sé si la
explicación escrita me ayuda.
ESCENARIOS POSIBLES
Precisar si solicita certificado de gravámenes o alodial. No afirmar ausencia de cargas sin certificado
vigente y verificación registral.
Referencia temática: F-DDRR-101 · Tipo: mixto
OpenSoul | Documento de escenarios | 2026-10-04
44

## Página 45

ESC-DDRR-103 / DDRR
Inscripción de compra venta de inmueble
Situación: Propuesta de conversación para inscripción de compra venta de inmueble. Las respuestas son
alternativas que el usuario debe elegir; no describen hechos ya confirmados.
PREGUNTAS EN UNA SECUENCIA POSIBLE
1
Persona usuaria
Quiero consultar el registro de compra de mi casa.
2
Funcionario
¿Trajo el contrato que quiere revisar?
3
Persona usuaria
Sí, traje el contrato.
4
Funcionario
¿Tiene la matrícula de Derechos Reales?
5
Persona usuaria
Sí, tengo la matrícula.
6
Funcionario
¿Trajo algún documento relacionado con su solicitud?
7
Persona usuaria
Sí, traje documentos.
8
Funcionario
¿Necesita un intérprete de Lengua de Señas Boliviana?
9
Persona usuaria
Sí, necesito un intérprete de LSB.
10
Funcionario
Pida que le confirmen por escrito el siguiente paso.
VARIANTES Y RESPUESTAS POSIBLES
P1. ¿Trajo el contrato que quiere revisar?
Variantes: ¿Tiene el contrato con usted? / ¿Cuenta con el documento del contrato?
Respuestas: Sí, traje el contrato. / No, no traje el contrato. / No sé cuál documento es el contrato.
P2. ¿Tiene la matrícula de Derechos Reales?
Variantes: ¿Conoce la matrícula del inmueble? / ¿Trajo el número de matrícula registral?
Respuestas: Sí, tengo la matrícula. / No, no tengo la matrícula. / No sé cuál es la matrícula.
P3. ¿Trajo algún documento relacionado con su solicitud?
Variantes: ¿Tiene documentos de su solicitud? / ¿Trae algún papel sobre este trámite?
Respuestas: Sí, traje documentos. / No, no traje documentos. / No sé qué documento corresponde.
P4. ¿Necesita un intérprete de Lengua de Señas Boliviana?
Variantes: ¿Requiere interpretación en LSB? / ¿Necesita apoyo de un intérprete de LSB?
Respuestas: Sí, necesito un intérprete de LSB. / No, no necesito un intérprete. / No sé cómo solicitar un
intérprete.
ESCENARIOS POSIBLES
Revisar identificación del trámite y documentos disponibles. No asegurar registro automático ni usar
catastro como sustituto del registro en DDRR.
Referencia temática: F-DDRR-101 · Tipo: mixto
OpenSoul | Documento de escenarios | 2026-10-04
45

## Página 46

ESC-DDRR-104 / DDRR
Reingreso de documentos observados
Situación: Propuesta de conversación para reingreso de documentos observados. Las respuestas son
alternativas que el usuario debe elegir; no describen hechos ya confirmados.
PREGUNTAS EN UNA SECUENCIA POSIBLE
1
Persona usuaria
Mi trámite de Derechos Reales tiene observaciones.
2
Funcionario
¿Le entregaron observaciones por escrito?
3
Persona usuaria
Sí, tengo las observaciones escritas.
4
Funcionario
¿Tiene una constancia de recepción de documentos?
5
Persona usuaria
Sí, tengo constancia de recepción.
6
Funcionario
¿Trajo algún documento relacionado con su solicitud?
7
Persona usuaria
Sí, traje documentos.
8
Funcionario
¿Prefiere recibir la explicación por escrito?
9
Persona usuaria
Sí, prefiero la explicación por escrito.
10
Funcionario
Pida que le confirmen por escrito el siguiente paso.
VARIANTES Y RESPUESTAS POSIBLES
P1. ¿Le entregaron observaciones por escrito?
Variantes: ¿Tiene una lista escrita de observaciones? / ¿Recibió una observación escrita del trámite?
Respuestas: Sí, tengo las observaciones escritas. / No, no tengo observaciones escritas. / No sé cuáles
son las observaciones.
P2. ¿Tiene una constancia de recepción de documentos?
Variantes: ¿Le dieron un cargo de recepción? / ¿Conserva prueba de entrega de sus documentos?
Respuestas: Sí, tengo constancia de recepción. / No, no tengo constancia. / No sé si este papel es la
constancia.
P3. ¿Trajo algún documento relacionado con su solicitud?
Variantes: ¿Tiene documentos de su solicitud? / ¿Trae algún papel sobre este trámite?
Respuestas: Sí, traje documentos. / No, no traje documentos. / No sé qué documento corresponde.
P4. ¿Prefiere recibir la explicación por escrito?
Variantes: ¿Quiere una explicación escrita? / ¿Le ayuda que escriba la explicación?
Respuestas: Sí, prefiero la explicación por escrito. / No, no prefiero la explicación escrita. / No sé si la
explicación escrita me ayuda.
ESCENARIOS POSIBLES
Con observaciones: solicitar explicación y subsanación. Sin observaciones escritas: pedir detalle. No
modificar datos del título desde la app.
Condiciones del MD: Turno 4: si Turno 2 es negado o desconocido.
Referencia temática: F-DDRR-101 · Tipo: mixto
OpenSoul | Documento de escenarios | 2026-10-04
46

## Página 47

ESC-SLIM-101 / SLIM
Orientación por violencia contra la mujer
Situación: Propuesta de conversación para orientación por violencia contra la mujer. Las respuestas son
alternativas que el usuario debe elegir; no describen hechos ya confirmados.
PREGUNTAS EN UNA SECUENCIA POSIBLE
1
Persona usuaria
Necesito orientación por violencia.
2
Funcionario
¿Está en peligro ahora?
3
Persona usuaria
Sí, estoy en peligro ahora.
4
Funcionario
¿Necesita atención médica ahora?
5
Persona usuaria
Sí, necesito atención médica.
6
Funcionario
¿Desea apoyo psicológico?
7
Persona usuaria
Sí, quiero apoyo psicológico.
8
Funcionario
¿Necesita un intérprete de Lengua de Señas Boliviana?
9
Persona usuaria
Sí, necesito un intérprete de LSB.
10
Funcionario
Pida que le confirmen por escrito el siguiente paso.
VARIANTES Y RESPUESTAS POSIBLES
P1. ¿Está en peligro ahora?
Variantes: ¿Corre peligro en este momento? / ¿Existe peligro inmediato para usted?
Respuestas: Sí, estoy en peligro ahora. / No, no estoy en peligro ahora. / No sé si estoy en peligro.
P2. ¿Necesita atención médica ahora?
Variantes: ¿Necesita ayuda médica inmediata? / ¿Requiere atención de salud en este momento?
Respuestas: Sí, necesito atención médica. / No, no necesito atención médica. / No sé si necesito atención
médica.
P3. ¿Desea apoyo psicológico?
Variantes: ¿Quiere hablar con un profesional de psicología? / ¿Necesita orientación psicológica?
Respuestas: Sí, quiero apoyo psicológico. / No, no quiero apoyo psicológico. / No sé si necesito ese
apoyo.
P4. ¿Necesita un intérprete de Lengua de Señas Boliviana?
Variantes: ¿Requiere interpretación en LSB? / ¿Necesita apoyo de un intérprete de LSB?
Respuestas: Sí, necesito un intérprete de LSB. / No, no necesito un intérprete. / No sé cómo solicitar un
intérprete.
ESCENARIOS POSIBLES
Riesgo: atención urgente y coordinación competente. Sin riesgo inmediato: consultar apoyo y recepción.
Confirmar oficina municipal; no prometer atención permanente.
Referencia temática: F-SLIM-101 · Tipo: mixto
OpenSoul | Documento de escenarios | 2026-10-04
47

## Página 48

ESC-SLIM-102 / SLIM
Apoyo para promover denuncia
Situación: Propuesta de conversación para apoyo para promover denuncia. Las respuestas son
alternativas que el usuario debe elegir; no describen hechos ya confirmados.
PREGUNTAS EN UNA SECUENCIA POSIBLE
1
Persona usuaria
Quiero ayuda para denunciar violencia.
2
Funcionario
¿Ya presentó una denuncia por este hecho?
3
Persona usuaria
Sí, ya presenté una denuncia.
4
Funcionario
¿Tiene el código de su caso en Fiscalía?
5
Persona usuaria
Sí, tengo el código fiscal.
6
Funcionario
¿Trajo algún documento relacionado con su solicitud?
7
Persona usuaria
Sí, traje documentos.
8
Funcionario
¿Necesita un intérprete de Lengua de Señas Boliviana?
9
Persona usuaria
Sí, necesito un intérprete de LSB.
10
Funcionario
Pida que le confirmen por escrito el siguiente paso.
VARIANTES Y RESPUESTAS POSIBLES
P1. ¿Ya presentó una denuncia por este hecho?
Variantes: ¿Ya denunció lo ocurrido? / ¿Este hecho ya fue denunciado?
Respuestas: Sí, ya presenté una denuncia. / No, todavía no presenté una denuncia. / No sé si existe una
denuncia.
P2. ¿Tiene el código de su caso en Fiscalía?
Variantes: ¿Conoce el código fiscal de su caso? / ¿Trajo el código del caso fiscal?
Respuestas: Sí, tengo el código fiscal. / No, no tengo el código fiscal. / No sé cuál es el código fiscal.
P3. ¿Trajo algún documento relacionado con su solicitud?
Variantes: ¿Tiene documentos de su solicitud? / ¿Trae algún papel sobre este trámite?
Respuestas: Sí, traje documentos. / No, no traje documentos. / No sé qué documento corresponde.
P4. ¿Necesita un intérprete de Lengua de Señas Boliviana?
Variantes: ¿Requiere interpretación en LSB? / ¿Necesita apoyo de un intérprete de LSB?
Respuestas: Sí, necesito un intérprete de LSB. / No, no necesito un intérprete. / No sé cómo solicitar un
intérprete.
ESCENARIOS POSIBLES
Si ya denunció: pedir apoyo de seguimiento. Si no denunció: solicitar orientación para recepción. No
obligar a reconciliación ni pedir desistimiento.
Condiciones del MD: Turno 4: si Turno 2 es afirmado.
Referencia temática: F-SLIM-101 · Tipo: mixto
OpenSoul | Documento de escenarios | 2026-10-04
48

## Página 49

ESC-SLIM-103 / SLIM
Apoyo psicológico solicitado por la usuaria
Situación: Propuesta de conversación para apoyo psicológico solicitado por la usuaria. Las respuestas
son alternativas que el usuario debe elegir; no describen hechos ya confirmados.
PREGUNTAS EN UNA SECUENCIA POSIBLE
1
Persona usuaria
Quiero apoyo psicológico por violencia.
2
Funcionario
¿Está en peligro ahora?
3
Persona usuaria
Sí, estoy en peligro ahora.
4
Funcionario
¿Necesita atención médica ahora?
5
Persona usuaria
Sí, necesito atención médica.
6
Funcionario
¿Desea apoyo psicológico?
7
Persona usuaria
Sí, quiero apoyo psicológico.
8
Funcionario
¿Prefiere recibir la explicación por escrito?
9
Persona usuaria
Sí, prefiero la explicación por escrito.
10
Funcionario
Pida que le confirmen por escrito el siguiente paso.
VARIANTES Y RESPUESTAS POSIBLES
P1. ¿Está en peligro ahora?
Variantes: ¿Corre peligro en este momento? / ¿Existe peligro inmediato para usted?
Respuestas: Sí, estoy en peligro ahora. / No, no estoy en peligro ahora. / No sé si estoy en peligro.
P2. ¿Necesita atención médica ahora?
Variantes: ¿Necesita ayuda médica inmediata? / ¿Requiere atención de salud en este momento?
Respuestas: Sí, necesito atención médica. / No, no necesito atención médica. / No sé si necesito atención
médica.
P3. ¿Desea apoyo psicológico?
Variantes: ¿Quiere hablar con un profesional de psicología? / ¿Necesita orientación psicológica?
Respuestas: Sí, quiero apoyo psicológico. / No, no quiero apoyo psicológico. / No sé si necesito ese
apoyo.
P4. ¿Prefiere recibir la explicación por escrito?
Variantes: ¿Quiere una explicación escrita? / ¿Le ayuda que escriba la explicación?
Respuestas: Sí, prefiero la explicación por escrito. / No, no prefiero la explicación escrita. / No sé si la
explicación escrita me ayuda.
ESCENARIOS POSIBLES
Priorizar protección si hay peligro. Confirmar disponibilidad y forma de atención; no diagnosticar ni
convertir un no sé en rechazo de ayuda.
Referencia temática: F-SLIM-101 · Tipo: mixto
OpenSoul | Documento de escenarios | 2026-10-04
49

## Página 50

ESC-SLIM-104 / SLIM
Dificultad para entender medidas de protección
Situación: Propuesta de conversación para dificultad para entender medidas de protección. Las
respuestas son alternativas que el usuario debe elegir; no describen hechos ya confirmados.
PREGUNTAS EN UNA SECUENCIA POSIBLE
1
Persona usuaria
No entiendo el papel sobre mi protección.
2
Funcionario
¿Le comunicaron medidas de protección?
3
Persona usuaria
Sí, me comunicaron medidas de protección.
4
Funcionario
¿Recibió una notificación?
5
Persona usuaria
Sí, recibí una notificación.
6
Funcionario
¿Trajo algún documento relacionado con su solicitud?
7
Persona usuaria
Sí, traje documentos.
8
Funcionario
¿Necesita un intérprete de Lengua de Señas Boliviana?
9
Persona usuaria
Sí, necesito un intérprete de LSB.
10
Funcionario
Pida que le confirmen por escrito el siguiente paso.
VARIANTES Y RESPUESTAS POSIBLES
P1. ¿Le comunicaron medidas de protección?
Variantes: ¿Recibió información sobre medidas de protección? / ¿Tiene un documento sobre medidas de
protección?
Respuestas: Sí, me comunicaron medidas de protección. / No, no me comunicaron medidas de
protección. / No sé si tengo medidas de protección.
P2. ¿Recibió una notificación?
Variantes: ¿Le entregaron una notificación? / ¿Tiene una notificación de este caso?
Respuestas: Sí, recibí una notificación. / No, no recibí una notificación. / No sé si es una notificación.
P3. ¿Trajo algún documento relacionado con su solicitud?
Variantes: ¿Tiene documentos de su solicitud? / ¿Trae algún papel sobre este trámite?
Respuestas: Sí, traje documentos. / No, no traje documentos. / No sé qué documento corresponde.
P4. ¿Necesita un intérprete de Lengua de Señas Boliviana?
Variantes: ¿Requiere interpretación en LSB? / ¿Necesita apoyo de un intérprete de LSB?
Respuestas: Sí, necesito un intérprete de LSB. / No, no necesito un intérprete. / No sé cómo solicitar un
intérprete.
ESCENARIOS POSIBLES
Con documento: pedir explicación accesible. Sin documento: consultar cómo obtener información. La
interpretación no cambia el contenido de la medida.
Referencia temática: F-SLIM-101 · Tipo: mixto
OpenSoul | Documento de escenarios | 2026-10-04
50

## Página 51

ESC-DNA-101 / DNA
Protección de niño o adolescente en riesgo
Situación: Propuesta de conversación para protección de niño o adolescente en riesgo. Las respuestas
son alternativas que el usuario debe elegir; no describen hechos ya confirmados.
PREGUNTAS EN UNA SECUENCIA POSIBLE
1
Persona usuaria
Hay un niño que necesita protección.
2
Funcionario
¿Está en peligro ahora?
3
Persona usuaria
Sí, estoy en peligro ahora.
4
Funcionario
¿Necesita atención médica ahora?
5
Persona usuaria
Sí, necesito atención médica.
6
Funcionario
¿Hay un niño o adolescente afectado?
7
Persona usuaria
Sí, hay un niño afectado.
8
Funcionario
¿Necesita un intérprete de Lengua de Señas Boliviana?
9
Persona usuaria
Sí, necesito un intérprete de LSB.
10
Funcionario
Pida que le confirmen por escrito el siguiente paso.
VARIANTES Y RESPUESTAS POSIBLES
P1. ¿Está en peligro ahora?
Variantes: ¿Corre peligro en este momento? / ¿Existe peligro inmediato para usted?
Respuestas: Sí, estoy en peligro ahora. / No, no estoy en peligro ahora. / No sé si estoy en peligro.
P2. ¿Necesita atención médica ahora?
Variantes: ¿Necesita ayuda médica inmediata? / ¿Requiere atención de salud en este momento?
Respuestas: Sí, necesito atención médica. / No, no necesito atención médica. / No sé si necesito atención
médica.
P3. ¿Hay un niño o adolescente afectado?
Variantes: ¿Lo ocurrido afecta a una persona menor de edad? / ¿Hay una niña, niño o adolescente
involucrado?
Respuestas: Sí, hay un niño afectado. / No, no hay un niño afectado. / No sé si hay un niño afectado.
P4. ¿Necesita un intérprete de Lengua de Señas Boliviana?
Variantes: ¿Requiere interpretación en LSB? / ¿Necesita apoyo de un intérprete de LSB?
Respuestas: Sí, necesito un intérprete de LSB. / No, no necesito un intérprete. / No sé cómo solicitar un
intérprete.
ESCENARIOS POSIBLES
Peligro: solicitar protección y atención urgente. No exigir que sea el padre quien pida ayuda ni recopilar
detalles sensibles de forma innecesaria.
Referencia temática: F-DNA-101 · Tipo: mixto
OpenSoul | Documento de escenarios | 2026-10-04
51

## Página 52

ESC-DNA-102 / DNA
Violencia o abandono de persona menor de edad
Situación: Propuesta de conversación para violencia o abandono de persona menor de edad. Las
respuestas son alternativas que el usuario debe elegir; no describen hechos ya confirmados.
PREGUNTAS EN UNA SECUENCIA POSIBLE
1
Persona usuaria
Quiero informar un problema que afecta a un niño.
2
Funcionario
¿Hay un niño o adolescente afectado?
3
Persona usuaria
Sí, hay un niño afectado.
4
Funcionario
¿Está en peligro ahora?
5
Persona usuaria
Sí, estoy en peligro ahora.
6
Funcionario
¿Usted es familiar de la persona afectada?
7
Persona usuaria
Sí, soy familiar.
8
Funcionario
¿Necesita un intérprete de Lengua de Señas Boliviana?
9
Persona usuaria
Sí, necesito un intérprete de LSB.
10
Funcionario
Pida que le confirmen por escrito el siguiente paso.
VARIANTES Y RESPUESTAS POSIBLES
P1. ¿Hay un niño o adolescente afectado?
Variantes: ¿Lo ocurrido afecta a una persona menor de edad? / ¿Hay una niña, niño o adolescente
involucrado?
Respuestas: Sí, hay un niño afectado. / No, no hay un niño afectado. / No sé si hay un niño afectado.
P2. ¿Está en peligro ahora?
Variantes: ¿Corre peligro en este momento? / ¿Existe peligro inmediato para usted?
Respuestas: Sí, estoy en peligro ahora. / No, no estoy en peligro ahora. / No sé si estoy en peligro.
P3. ¿Usted es familiar de la persona afectada?
Variantes: ¿La persona afectada es de su familia? / ¿Tiene parentesco con la persona afectada?
Respuestas: Sí, soy familiar. / No, no soy familiar. / No sé cómo explicar el parentesco.
P4. ¿Necesita un intérprete de Lengua de Señas Boliviana?
Variantes: ¿Requiere interpretación en LSB? / ¿Necesita apoyo de un intérprete de LSB?
Respuestas: Sí, necesito un intérprete de LSB. / No, no necesito un intérprete. / No sé cómo solicitar un
intérprete.
ESCENARIOS POSIBLES
Aclarar si se trata de niña, niño o adolescente. Riesgo actual requiere atención prioritaria; autoridad
determina medidas y coordinación.
Referencia temática: F-DNA-101 · Tipo: mixto
OpenSoul | Documento de escenarios | 2026-10-04
52

## Página 53

ESC-DNA-103 / DNA
Orientación sobre viaje de menor
Situación: Propuesta de conversación para orientación sobre viaje de menor. Las respuestas son
alternativas que el usuario debe elegir; no describen hechos ya confirmados.
PREGUNTAS EN UNA SECUENCIA POSIBLE
1
Persona usuaria
Quiero consultar un viaje con mi hijo.
2
Funcionario
¿Hay un niño o adolescente afectado?
3
Persona usuaria
Sí, hay un niño afectado.
4
Funcionario
¿Trajo algún documento relacionado con su solicitud?
5
Persona usuaria
Sí, traje documentos.
6
Funcionario
¿Usted es familiar de la persona afectada?
7
Persona usuaria
Sí, soy familiar.
8
Funcionario
¿Prefiere recibir la explicación por escrito?
9
Persona usuaria
Sí, prefiero la explicación por escrito.
10
Funcionario
Pida que le confirmen por escrito el siguiente paso.
VARIANTES Y RESPUESTAS POSIBLES
P1. ¿Hay un niño o adolescente afectado?
Variantes: ¿Lo ocurrido afecta a una persona menor de edad? / ¿Hay una niña, niño o adolescente
involucrado?
Respuestas: Sí, hay un niño afectado. / No, no hay un niño afectado. / No sé si hay un niño afectado.
P2. ¿Trajo algún documento relacionado con su solicitud?
Variantes: ¿Tiene documentos de su solicitud? / ¿Trae algún papel sobre este trámite?
Respuestas: Sí, traje documentos. / No, no traje documentos. / No sé qué documento corresponde.
P3. ¿Usted es familiar de la persona afectada?
Variantes: ¿La persona afectada es de su familia? / ¿Tiene parentesco con la persona afectada?
Respuestas: Sí, soy familiar. / No, no soy familiar. / No sé cómo explicar el parentesco.
P4. ¿Prefiere recibir la explicación por escrito?
Variantes: ¿Quiere una explicación escrita? / ¿Le ayuda que escriba la explicación?
Respuestas: Sí, prefiero la explicación por escrito. / No, no prefiero la explicación escrita. / No sé si la
explicación escrita me ayuda.
ESCENARIOS POSIBLES
Confirmar destino, acompañantes y autoridad que autoriza según caso. No asegurar autorización con
permiso simple ni inventar requisitos.
Referencia temática: F-DNA-101 · Tipo: mixto
OpenSoul | Documento de escenarios | 2026-10-04
53

## Página 54

ESC-DNA-104 / DNA
Seguimiento de solicitud de protección
Situación: Propuesta de conversación para seguimiento de solicitud de protección. Las respuestas son
alternativas que el usuario debe elegir; no describen hechos ya confirmados.
PREGUNTAS EN UNA SECUENCIA POSIBLE
1
Persona usuaria
Quiero consultar la atención de mi hijo.
2
Funcionario
¿Tiene el número de su trámite?
3
Persona usuaria
Sí, tengo el número.
4
Funcionario
¿Recibió una notificación?
5
Persona usuaria
Sí, recibí una notificación.
6
Funcionario
¿Trajo algún documento relacionado con su solicitud?
7
Persona usuaria
Sí, traje documentos.
8
Funcionario
¿Necesita un intérprete de Lengua de Señas Boliviana?
9
Persona usuaria
Sí, necesito un intérprete de LSB.
10
Funcionario
Pida que le confirmen por escrito el siguiente paso.
VARIANTES Y RESPUESTAS POSIBLES
P1. ¿Tiene el número de su trámite?
Variantes: ¿Conoce el código del trámite? / ¿Trajo el número de la solicitud?
Respuestas: Sí, tengo el número. / No, no tengo el número. / No sé cuál es el número.
P2. ¿Recibió una notificación?
Variantes: ¿Le entregaron una notificación? / ¿Tiene una notificación de este caso?
Respuestas: Sí, recibí una notificación. / No, no recibí una notificación. / No sé si es una notificación.
P3. ¿Trajo algún documento relacionado con su solicitud?
Variantes: ¿Tiene documentos de su solicitud? / ¿Trae algún papel sobre este trámite?
Respuestas: Sí, traje documentos. / No, no traje documentos. / No sé qué documento corresponde.
P4. ¿Necesita un intérprete de Lengua de Señas Boliviana?
Variantes: ¿Requiere interpretación en LSB? / ¿Necesita apoyo de un intérprete de LSB?
Respuestas: Sí, necesito un intérprete de LSB. / No, no necesito un intérprete. / No sé cómo solicitar un
intérprete.
ESCENARIOS POSIBLES
Con número: consultar recepción y equipo. Sin número: buscar constancia. No divulgar información del
menor a personas no autorizadas.
Condiciones del MD: Turno 4: si Turno 2 es afirmado.
Referencia temática: F-DNA-101 · Tipo: mixto
OpenSoul | Documento de escenarios | 2026-10-04
54

## Página 55

ESC-NOT-101 / NOT
Reconocimiento de firmas y comprensión
Situación: Propuesta de conversación para reconocimiento de firmas y comprensión. Las respuestas son
alternativas que el usuario debe elegir; no describen hechos ya confirmados.
PREGUNTAS EN UNA SECUENCIA POSIBLE
1
Persona usuaria
Quiero consultar el reconocimiento de firmas.
2
Funcionario
¿Trajo el contrato que quiere revisar?
3
Persona usuaria
Sí, traje el contrato.
4
Funcionario
¿Comprendió el documento antes de firmar?
5
Persona usuaria
Sí, comprendí el documento.
6
Funcionario
¿Trajo algún documento relacionado con su solicitud?
7
Persona usuaria
Sí, traje documentos.
8
Funcionario
¿Necesita un intérprete de Lengua de Señas Boliviana?
9
Persona usuaria
Sí, necesito un intérprete de LSB.
10
Funcionario
Pida que le confirmen por escrito el siguiente paso.
VARIANTES Y RESPUESTAS POSIBLES
P1. ¿Trajo el contrato que quiere revisar?
Variantes: ¿Tiene el contrato con usted? / ¿Cuenta con el documento del contrato?
Respuestas: Sí, traje el contrato. / No, no traje el contrato. / No sé cuál documento es el contrato.
P2. ¿Comprendió el documento antes de firmar?
Variantes: ¿Entiende el contenido del documento? / ¿Está claro qué dice el documento?
Respuestas: Sí, comprendí el documento. / No, no comprendí el documento. / No sé qué dice el
documento.
P3. ¿Trajo algún documento relacionado con su solicitud?
Variantes: ¿Tiene documentos de su solicitud? / ¿Trae algún papel sobre este trámite?
Respuestas: Sí, traje documentos. / No, no traje documentos. / No sé qué documento corresponde.
P4. ¿Necesita un intérprete de Lengua de Señas Boliviana?
Variantes: ¿Requiere interpretación en LSB? / ¿Necesita apoyo de un intérprete de LSB?
Respuestas: Sí, necesito un intérprete de LSB. / No, no necesito un intérprete. / No sé cómo solicitar un
intérprete.
ESCENARIOS POSIBLES
Revisar contenido antes de cualquier firma. Si no comprende: pedir explicación e interpretación.
Requisitos y arancel se confirman para el acto concreto.
Condiciones del MD: Turno 4: si Turno 2 es afirmado; Turno 6: si Turno 2 es negado o desconocido.
Referencia temática: F-NOT-101 · Tipo: mixto
OpenSoul | Documento de escenarios | 2026-10-04
55

## Página 56

ESC-NOT-102 / NOT
Poder para realizar una gestión
Situación: Propuesta de conversación para poder para realizar una gestión. Las respuestas son
alternativas que el usuario debe elegir; no describen hechos ya confirmados.
PREGUNTAS EN UNA SECUENCIA POSIBLE
1
Persona usuaria
Quiero consultar un poder para un trámite.
2
Funcionario
¿Está realizando el trámite por otra persona?
3
Persona usuaria
Sí, represento a otra persona.
4
Funcionario
¿Trajo un poder para este trámite?
5
Persona usuaria
Sí, traje un poder.
6
Funcionario
¿Trajo algún documento relacionado con su solicitud?
7
Persona usuaria
Sí, traje documentos.
8
Funcionario
¿Prefiere recibir la explicación por escrito?
9
Persona usuaria
Sí, prefiero la explicación por escrito.
10
Funcionario
Pida que le confirmen por escrito el siguiente paso.
VARIANTES Y RESPUESTAS POSIBLES
P1. ¿Está realizando el trámite por otra persona?
Variantes: ¿Viene en representación de alguien? / ¿El trámite es para otra persona?
Respuestas: Sí, represento a otra persona. / No, el trámite es para mí. / No sé cómo acreditar la
representación.
P2. ¿Trajo un poder para este trámite?
Variantes: ¿Tiene un documento de poder? / ¿Cuenta con un poder relacionado con esta gestión?
Respuestas: Sí, traje un poder. / No, no traje un poder. / No sé si este poder sirve.
P3. ¿Trajo algún documento relacionado con su solicitud?
Variantes: ¿Tiene documentos de su solicitud? / ¿Trae algún papel sobre este trámite?
Respuestas: Sí, traje documentos. / No, no traje documentos. / No sé qué documento corresponde.
P4. ¿Prefiere recibir la explicación por escrito?
Variantes: ¿Quiere una explicación escrita? / ¿Le ayuda que escriba la explicación?
Respuestas: Sí, prefiero la explicación por escrito. / No, no prefiero la explicación escrita. / No sé si la
explicación escrita me ayuda.
ESCENARIOS POSIBLES
Precisar quién otorga el poder, a quién y para qué gestión. No crear facultades legales por inferencia ni
asegurar que cualquier poder sirve.
Referencia temática: F-NOT-101 · Tipo: mixto
OpenSoul | Documento de escenarios | 2026-10-04
56

## Página 57

ESC-NOT-103 / NOT
Contrato de alquiler o anticrético
Situación: Propuesta de conversación para contrato de alquiler o anticrético. Las respuestas son
alternativas que el usuario debe elegir; no describen hechos ya confirmados.
PREGUNTAS EN UNA SECUENCIA POSIBLE
1
Persona usuaria
Quiero consultar el contrato de mi vivienda.
2
Funcionario
¿Trajo el contrato que quiere revisar?
3
Persona usuaria
Sí, traje el contrato.
4
Funcionario
¿Comprendió el documento antes de firmar?
5
Persona usuaria
Sí, comprendí el documento.
6
Funcionario
¿Trajo algún documento relacionado con su solicitud?
7
Persona usuaria
Sí, traje documentos.
8
Funcionario
¿Necesita un intérprete de Lengua de Señas Boliviana?
9
Persona usuaria
Sí, necesito un intérprete de LSB.
10
Funcionario
Pida que le confirmen por escrito el siguiente paso.
VARIANTES Y RESPUESTAS POSIBLES
P1. ¿Trajo el contrato que quiere revisar?
Variantes: ¿Tiene el contrato con usted? / ¿Cuenta con el documento del contrato?
Respuestas: Sí, traje el contrato. / No, no traje el contrato. / No sé cuál documento es el contrato.
P2. ¿Comprendió el documento antes de firmar?
Variantes: ¿Entiende el contenido del documento? / ¿Está claro qué dice el documento?
Respuestas: Sí, comprendí el documento. / No, no comprendí el documento. / No sé qué dice el
documento.
P3. ¿Trajo algún documento relacionado con su solicitud?
Variantes: ¿Tiene documentos de su solicitud? / ¿Trae algún papel sobre este trámite?
Respuestas: Sí, traje documentos. / No, no traje documentos. / No sé qué documento corresponde.
P4. ¿Necesita un intérprete de Lengua de Señas Boliviana?
Variantes: ¿Requiere interpretación en LSB? / ¿Necesita apoyo de un intérprete de LSB?
Respuestas: Sí, necesito un intérprete de LSB. / No, no necesito un intérprete. / No sé cómo solicitar un
intérprete.
ESCENARIOS POSIBLES
Distinguir alquiler de anticrético y acto solicitado. No inventar montos ni afirmar que reconocimiento de
firmas equivale a registro de propiedad.
Condiciones del MD: Turno 4: si Turno 2 es afirmado; Turno 6: si Turno 2 es negado o desconocido.
Referencia temática: F-NOT-101 · Tipo: mixto
OpenSoul | Documento de escenarios | 2026-10-04
57

## Página 58

ESC-NOT-104 / NOT
Copia de instrumento notarial anterior
Situación: Propuesta de conversación para copia de instrumento notarial anterior. Las respuestas son
alternativas que el usuario debe elegir; no describen hechos ya confirmados.
PREGUNTAS EN UNA SECUENCIA POSIBLE
1
Persona usuaria
Necesito orientación para obtener un documento notarial anterior.
2
Funcionario
¿Trajo algún documento relacionado con su solicitud?
3
Persona usuaria
Sí, traje documentos.
4
Funcionario
¿Trajo un poder para este trámite?
5
Persona usuaria
Sí, traje un poder.
6
Funcionario
¿Tiene una constancia de recepción de documentos?
7
Persona usuaria
Sí, tengo constancia de recepción.
8
Funcionario
¿Prefiere recibir la explicación por escrito?
9
Persona usuaria
Sí, prefiero la explicación por escrito.
10
Funcionario
Pida que le confirmen por escrito el siguiente paso.
VARIANTES Y RESPUESTAS POSIBLES
P1. ¿Trajo algún documento relacionado con su solicitud?
Variantes: ¿Tiene documentos de su solicitud? / ¿Trae algún papel sobre este trámite?
Respuestas: Sí, traje documentos. / No, no traje documentos. / No sé qué documento corresponde.
P2. ¿Trajo un poder para este trámite?
Variantes: ¿Tiene un documento de poder? / ¿Cuenta con un poder relacionado con esta gestión?
Respuestas: Sí, traje un poder. / No, no traje un poder. / No sé si este poder sirve.
P3. ¿Tiene una constancia de recepción de documentos?
Variantes: ¿Le dieron un cargo de recepción? / ¿Conserva prueba de entrega de sus documentos?
Respuestas: Sí, tengo constancia de recepción. / No, no tengo constancia. / No sé si este papel es la
constancia.
P4. ¿Prefiere recibir la explicación por escrito?
Variantes: ¿Quiere una explicación escrita? / ¿Le ayuda que escriba la explicación?
Respuestas: Sí, prefiero la explicación por escrito. / No, no prefiero la explicación escrita. / No sé si la
explicación escrita me ayuda.
ESCENARIOS POSIBLES
Con referencia disponible: pedir búsqueda en la notaría o instancia competente. Sin referencia: solicitar
orientación. Confirmar legitimación y tipo de copia.
Condiciones del MD: Turno 4: si Turno 2 es negado o desconocido.
Referencia temática: F-NOT-101 · Tipo: mixto
OpenSoul | Documento de escenarios | 2026-10-04
58

## Página 59

ESC-SEGIP-101 / SEGIP
Primera cédula de identidad
Situación: Propuesta de conversación para primera cédula de identidad. Las respuestas son alternativas
que el usuario debe elegir; no describen hechos ya confirmados.
PREGUNTAS EN UNA SECUENCIA POSIBLE
1
Persona usuaria
Quiero consultar mi primera cédula.
2
Funcionario
¿Es la primera vez que solicita su cédula?
3
Persona usuaria
Sí, es mi primera cédula.
4
Funcionario
¿Tiene un certificado de nacimiento anterior?
5
Persona usuaria
Sí, tengo mi certificado.
6
Funcionario
¿Trajo algún documento relacionado con su solicitud?
7
Persona usuaria
Sí, traje documentos.
8
Funcionario
¿Necesita un intérprete de Lengua de Señas Boliviana?
9
Persona usuaria
Sí, necesito un intérprete de LSB.
10
Funcionario
Pida que le confirmen por escrito el siguiente paso.
VARIANTES Y RESPUESTAS POSIBLES
P1. ¿Es la primera vez que solicita su cédula?
Variantes: ¿Nunca tuvo cédula de identidad? / ¿Solicita su primera cédula?
Respuestas: Sí, es mi primera cédula. / No, ya tuve cédula. / No sé si existe un registro anterior.
P2. ¿Tiene un certificado de nacimiento anterior?
Variantes: ¿Conserva su certificado de nacimiento? / ¿Trajo un certificado anterior de nacimiento?
Respuestas: Sí, tengo mi certificado. / No, no tengo mi certificado. / No sé dónde está mi certificado.
P3. ¿Trajo algún documento relacionado con su solicitud?
Variantes: ¿Tiene documentos de su solicitud? / ¿Trae algún papel sobre este trámite?
Respuestas: Sí, traje documentos. / No, no traje documentos. / No sé qué documento corresponde.
P4. ¿Necesita un intérprete de Lengua de Señas Boliviana?
Variantes: ¿Requiere interpretación en LSB? / ¿Necesita apoyo de un intérprete de LSB?
Respuestas: Sí, necesito un intérprete de LSB. / No, no necesito un intérprete. / No sé cómo solicitar un
intérprete.
ESCENARIOS POSIBLES
Primera emisión: pedir requisitos de esa modalidad. Registro previo: consultar duplicado o renovación.
No inventar pagos, vigencia ni documentos obligatorios.
Condiciones del MD: Turno 4: si Turno 2 es afirmado.
Referencia temática: F-SEGIP-101 · Tipo: mixto
OpenSoul | Documento de escenarios | 2026-10-04
59

## Página 60

ESC-SEGIP-102 / SEGIP
Renovación de cédula
Situación: Propuesta de conversación para renovación de cédula. Las respuestas son alternativas que el
usuario debe elegir; no describen hechos ya confirmados.
PREGUNTAS EN UNA SECUENCIA POSIBLE
1
Persona usuaria
Quiero renovar mi carnet.
2
Funcionario
¿Trajo su cédula de identidad?
3
Persona usuaria
Sí, traje mi cédula.
4
Funcionario
¿Encontró un error en sus datos?
5
Persona usuaria
Sí, encontré un error.
6
Funcionario
¿Trajo algún documento relacionado con su solicitud?
7
Persona usuaria
Sí, traje documentos.
8
Funcionario
¿Prefiere recibir la explicación por escrito?
9
Persona usuaria
Sí, prefiero la explicación por escrito.
10
Funcionario
Pida que le confirmen por escrito el siguiente paso.
VARIANTES Y RESPUESTAS POSIBLES
P1. ¿Trajo su cédula de identidad?
Variantes: ¿Tiene su carnet con usted? / ¿Trae su documento de identidad?
Respuestas: Sí, traje mi cédula. / No, no traje mi cédula. / No sé si la traje.
P2. ¿Encontró un error en sus datos?
Variantes: ¿Algún dato del documento está equivocado? / ¿Necesita corregir información personal?
Respuestas: Sí, encontré un error. / No, no encontré un error. / No sé si el dato está equivocado.
P3. ¿Trajo algún documento relacionado con su solicitud?
Variantes: ¿Tiene documentos de su solicitud? / ¿Trae algún papel sobre este trámite?
Respuestas: Sí, traje documentos. / No, no traje documentos. / No sé qué documento corresponde.
P4. ¿Prefiere recibir la explicación por escrito?
Variantes: ¿Quiere una explicación escrita? / ¿Le ayuda que escriba la explicación?
Respuestas: Sí, prefiero la explicación por escrito. / No, no prefiero la explicación escrita. / No sé si la
explicación escrita me ayuda.
ESCENARIOS POSIBLES
Con cédula anterior: consultar renovación y datos. Sin documento: aclarar extravío. No asegurar
renovación sin verificar la modalidad.
Condiciones del MD: Turno 4: si Turno 2 es afirmado.
Referencia temática: F-SEGIP-101 · Tipo: mixto
OpenSoul | Documento de escenarios | 2026-10-04
60

## Página 61

ESC-SEGIP-103 / SEGIP
Reposición por pérdida o robo
Situación: Propuesta de conversación para reposición por pérdida o robo. Las respuestas son alternativas
que el usuario debe elegir; no describen hechos ya confirmados.
PREGUNTAS EN UNA SECUENCIA POSIBLE
1
Persona usuaria
Perdí mi carnet y necesito orientación.
2
Funcionario
¿Cree que perdió el objeto?
3
Persona usuaria
Sí, creo que lo perdí.
4
Funcionario
¿Trajo algún documento relacionado con su solicitud?
5
Persona usuaria
Sí, traje documentos.
6
Funcionario
¿Ya presentó una denuncia por este hecho?
7
Persona usuaria
Sí, ya presenté una denuncia.
8
Funcionario
¿Necesita un intérprete de Lengua de Señas Boliviana?
9
Persona usuaria
Sí, necesito un intérprete de LSB.
10
Funcionario
Pida que le confirmen por escrito el siguiente paso.
VARIANTES Y RESPUESTAS POSIBLES
P1. ¿Cree que perdió el objeto?
Variantes: ¿Piensa que el objeto se extravió? / ¿Puede haber perdido el objeto?
Respuestas: Sí, creo que lo perdí. / No, no creo haberlo perdido. / No sé si lo perdí o lo robaron.
P2. ¿Trajo algún documento relacionado con su solicitud?
Variantes: ¿Tiene documentos de su solicitud? / ¿Trae algún papel sobre este trámite?
Respuestas: Sí, traje documentos. / No, no traje documentos. / No sé qué documento corresponde.
P3. ¿Ya presentó una denuncia por este hecho?
Variantes: ¿Ya denunció lo ocurrido? / ¿Este hecho ya fue denunciado?
Respuestas: Sí, ya presenté una denuncia. / No, todavía no presenté una denuncia. / No sé si existe una
denuncia.
P4. ¿Necesita un intérprete de Lengua de Señas Boliviana?
Variantes: ¿Requiere interpretación en LSB? / ¿Necesita apoyo de un intérprete de LSB?
Respuestas: Sí, necesito un intérprete de LSB. / No, no necesito un intérprete. / No sé cómo solicitar un
intérprete.
ESCENARIOS POSIBLES
Aclarar pérdida o posible robo. Consultar reposición; no afirmar que una denuncia policial es siempre
requisito para emitir cédula.
Referencia temática: F-SEGIP-101 · Tipo: mixto
OpenSoul | Documento de escenarios | 2026-10-04
61

## Página 62

ESC-SEGIP-104 / SEGIP
Corrección de datos de identidad
Situación: Propuesta de conversación para corrección de datos de identidad. Las respuestas son
alternativas que el usuario debe elegir; no describen hechos ya confirmados.
PREGUNTAS EN UNA SECUENCIA POSIBLE
1
Persona usuaria
Mi carnet tiene un dato equivocado.
2
Funcionario
¿Encontró un error en sus datos?
3
Persona usuaria
Sí, encontré un error.
4
Funcionario
¿Tiene un certificado de nacimiento anterior?
5
Persona usuaria
Sí, tengo mi certificado.
6
Funcionario
¿Trajo algún documento relacionado con su solicitud?
7
Persona usuaria
Sí, traje documentos.
8
Funcionario
¿Prefiere recibir la explicación por escrito?
9
Persona usuaria
Sí, prefiero la explicación por escrito.
10
Funcionario
Pida que le confirmen por escrito el siguiente paso.
VARIANTES Y RESPUESTAS POSIBLES
P1. ¿Encontró un error en sus datos?
Variantes: ¿Algún dato del documento está equivocado? / ¿Necesita corregir información personal?
Respuestas: Sí, encontré un error. / No, no encontré un error. / No sé si el dato está equivocado.
P2. ¿Tiene un certificado de nacimiento anterior?
Variantes: ¿Conserva su certificado de nacimiento? / ¿Trajo un certificado anterior de nacimiento?
Respuestas: Sí, tengo mi certificado. / No, no tengo mi certificado. / No sé dónde está mi certificado.
P3. ¿Trajo algún documento relacionado con su solicitud?
Variantes: ¿Tiene documentos de su solicitud? / ¿Trae algún papel sobre este trámite?
Respuestas: Sí, traje documentos. / No, no traje documentos. / No sé qué documento corresponde.
P4. ¿Prefiere recibir la explicación por escrito?
Variantes: ¿Quiere una explicación escrita? / ¿Le ayuda que escriba la explicación?
Respuestas: Sí, prefiero la explicación por escrito. / No, no prefiero la explicación escrita. / No sé si la
explicación escrita me ayuda.
ESCENARIOS POSIBLES
Identificar dato incorrecto y respaldo. Si el error proviene del registro civil: consultar coordinación con
SERECI. No alterar datos oficiales desde la app.
Condiciones del MD: Turno 4: si Turno 2 es afirmado.
Referencia temática: F-SEGIP-101 · Tipo: mixto
OpenSoul | Documento de escenarios | 2026-10-04
62

## Página 63

ESC-SERECI-101 / SERECI
Duplicado de certificado de nacimiento
Situación: Propuesta de conversación para duplicado de certificado de nacimiento. Las respuestas son
alternativas que el usuario debe elegir; no describen hechos ya confirmados.
PREGUNTAS EN UNA SECUENCIA POSIBLE
1
Persona usuaria
Quiero consultar mi certificado de nacimiento.
2
Funcionario
¿Tiene un certificado de nacimiento anterior?
3
Persona usuaria
Sí, tengo mi certificado.
4
Funcionario
¿Encontró un error en sus datos?
5
Persona usuaria
Sí, encontré un error.
6
Funcionario
¿Trajo algún documento relacionado con su solicitud?
7
Persona usuaria
Sí, traje documentos.
8
Funcionario
¿Necesita un intérprete de Lengua de Señas Boliviana?
9
Persona usuaria
Sí, necesito un intérprete de LSB.
10
Funcionario
Pida que le confirmen por escrito el siguiente paso.
VARIANTES Y RESPUESTAS POSIBLES
P1. ¿Tiene un certificado de nacimiento anterior?
Variantes: ¿Conserva su certificado de nacimiento? / ¿Trajo un certificado anterior de nacimiento?
Respuestas: Sí, tengo mi certificado. / No, no tengo mi certificado. / No sé dónde está mi certificado.
P2. ¿Encontró un error en sus datos?
Variantes: ¿Algún dato del documento está equivocado? / ¿Necesita corregir información personal?
Respuestas: Sí, encontré un error. / No, no encontré un error. / No sé si el dato está equivocado.
P3. ¿Trajo algún documento relacionado con su solicitud?
Variantes: ¿Tiene documentos de su solicitud? / ¿Trae algún papel sobre este trámite?
Respuestas: Sí, traje documentos. / No, no traje documentos. / No sé qué documento corresponde.
P4. ¿Necesita un intérprete de Lengua de Señas Boliviana?
Variantes: ¿Requiere interpretación en LSB? / ¿Necesita apoyo de un intérprete de LSB?
Respuestas: Sí, necesito un intérprete de LSB. / No, no necesito un intérprete. / No sé cómo solicitar un
intérprete.
ESCENARIOS POSIBLES
Con certificado anterior: consultar duplicado o corrección. Sin certificado: pedir búsqueda. No confundir
certificado de nacimiento con cédula SEGIP.
Condiciones del MD: Turno 4: si Turno 2 es afirmado.
Referencia temática: F-SERECI-101 · Tipo: mixto
OpenSoul | Documento de escenarios | 2026-10-04
63

## Página 64

ESC-SERECI-102 / SERECI
Certificado de matrimonio o estado civil
Situación: Propuesta de conversación para certificado de matrimonio o estado civil. Las respuestas son
alternativas que el usuario debe elegir; no describen hechos ya confirmados.
PREGUNTAS EN UNA SECUENCIA POSIBLE
1
Persona usuaria
Quiero consultar un certificado de mi estado civil.
2
Funcionario
¿Trajo algún documento relacionado con su solicitud?
3
Persona usuaria
Sí, traje documentos.
4
Funcionario
¿Encontró un error en sus datos?
5
Persona usuaria
Sí, encontré un error.
6
Funcionario
¿Está realizando el trámite por otra persona?
7
Persona usuaria
Sí, represento a otra persona.
8
Funcionario
¿Prefiere recibir la explicación por escrito?
9
Persona usuaria
Sí, prefiero la explicación por escrito.
10
Funcionario
Pida que le confirmen por escrito el siguiente paso.
VARIANTES Y RESPUESTAS POSIBLES
P1. ¿Trajo algún documento relacionado con su solicitud?
Variantes: ¿Tiene documentos de su solicitud? / ¿Trae algún papel sobre este trámite?
Respuestas: Sí, traje documentos. / No, no traje documentos. / No sé qué documento corresponde.
P2. ¿Encontró un error en sus datos?
Variantes: ¿Algún dato del documento está equivocado? / ¿Necesita corregir información personal?
Respuestas: Sí, encontré un error. / No, no encontré un error. / No sé si el dato está equivocado.
P3. ¿Está realizando el trámite por otra persona?
Variantes: ¿Viene en representación de alguien? / ¿El trámite es para otra persona?
Respuestas: Sí, represento a otra persona. / No, el trámite es para mí. / No sé cómo acreditar la
representación.
P4. ¿Prefiere recibir la explicación por escrito?
Variantes: ¿Quiere una explicación escrita? / ¿Le ayuda que escriba la explicación?
Respuestas: Sí, prefiero la explicación por escrito. / No, no prefiero la explicación escrita. / No sé si la
explicación escrita me ayuda.
ESCENARIOS POSIBLES
Precisar certificado de matrimonio, unión libre o estado civil. No tratar estas certificaciones como
equivalentes ni inventar el estado civil personal.
Referencia temática: F-SERECI-101 · Tipo: mixto
OpenSoul | Documento de escenarios | 2026-10-04
64

## Página 65

ESC-SERECI-103 / SERECI
Certificado de defunción
Situación: Propuesta de conversación para certificado de defunción. Las respuestas son alternativas que
el usuario debe elegir; no describen hechos ya confirmados.
PREGUNTAS EN UNA SECUENCIA POSIBLE
1
Persona usuaria
Quiero orientación para un certificado de defunción.
2
Funcionario
¿Trajo algún documento relacionado con su solicitud?
3
Persona usuaria
Sí, traje documentos.
4
Funcionario
¿Usted es familiar de la persona afectada?
5
Persona usuaria
Sí, soy familiar.
6
Funcionario
¿Está realizando el trámite por otra persona?
7
Persona usuaria
Sí, represento a otra persona.
8
Funcionario
¿Necesita un intérprete de Lengua de Señas Boliviana?
9
Persona usuaria
Sí, necesito un intérprete de LSB.
10
Funcionario
Pida que le confirmen por escrito el siguiente paso.
VARIANTES Y RESPUESTAS POSIBLES
P1. ¿Trajo algún documento relacionado con su solicitud?
Variantes: ¿Tiene documentos de su solicitud? / ¿Trae algún papel sobre este trámite?
Respuestas: Sí, traje documentos. / No, no traje documentos. / No sé qué documento corresponde.
P2. ¿Usted es familiar de la persona afectada?
Variantes: ¿La persona afectada es de su familia? / ¿Tiene parentesco con la persona afectada?
Respuestas: Sí, soy familiar. / No, no soy familiar. / No sé cómo explicar el parentesco.
P3. ¿Está realizando el trámite por otra persona?
Variantes: ¿Viene en representación de alguien? / ¿El trámite es para otra persona?
Respuestas: Sí, represento a otra persona. / No, el trámite es para mí. / No sé cómo acreditar la
representación.
P4. ¿Necesita un intérprete de Lengua de Señas Boliviana?
Variantes: ¿Requiere interpretación en LSB? / ¿Necesita apoyo de un intérprete de LSB?
Respuestas: Sí, necesito un intérprete de LSB. / No, no necesito un intérprete. / No sé cómo solicitar un
intérprete.
ESCENARIOS POSIBLES
Distinguir registro inicial de duplicado. Confirmar documentación y legitimación de quien solicita. No
inventar causa, fecha o datos del fallecimiento.
Referencia temática: F-SERECI-101 · Tipo: mixto
OpenSoul | Documento de escenarios | 2026-10-04
65

## Página 66

ESC-SERECI-104 / SERECI
Saneamiento de partida con error
Situación: Propuesta de conversación para saneamiento de partida con error. Las respuestas son
alternativas que el usuario debe elegir; no describen hechos ya confirmados.
PREGUNTAS EN UNA SECUENCIA POSIBLE
1
Persona usuaria
Mi certificado tiene un dato equivocado.
2
Funcionario
¿Encontró un error en sus datos?
3
Persona usuaria
Sí, encontré un error.
4
Funcionario
¿Trajo algún documento relacionado con su solicitud?
5
Persona usuaria
Sí, traje documentos.
6
Funcionario
¿Tiene un certificado de nacimiento anterior?
7
Persona usuaria
Sí, tengo mi certificado.
8
Funcionario
¿Prefiere recibir la explicación por escrito?
9
Persona usuaria
Sí, prefiero la explicación por escrito.
10
Funcionario
Pida que le confirmen por escrito el siguiente paso.
VARIANTES Y RESPUESTAS POSIBLES
P1. ¿Encontró un error en sus datos?
Variantes: ¿Algún dato del documento está equivocado? / ¿Necesita corregir información personal?
Respuestas: Sí, encontré un error. / No, no encontré un error. / No sé si el dato está equivocado.
P2. ¿Trajo algún documento relacionado con su solicitud?
Variantes: ¿Tiene documentos de su solicitud? / ¿Trae algún papel sobre este trámite?
Respuestas: Sí, traje documentos. / No, no traje documentos. / No sé qué documento corresponde.
P3. ¿Tiene un certificado de nacimiento anterior?
Variantes: ¿Conserva su certificado de nacimiento? / ¿Trajo un certificado anterior de nacimiento?
Respuestas: Sí, tengo mi certificado. / No, no tengo mi certificado. / No sé dónde está mi certificado.
P4. ¿Prefiere recibir la explicación por escrito?
Variantes: ¿Quiere una explicación escrita? / ¿Le ayuda que escriba la explicación?
Respuestas: Sí, prefiero la explicación por escrito. / No, no prefiero la explicación escrita. / No sé si la
explicación escrita me ayuda.
ESCENARIOS POSIBLES
Identificar partida y dato cuestionado. Confirmar vía administrativa o judicial. No prometer corrección
automática ni sustitución de documentos.
Condiciones del MD: Turno 4: si Turno 2 es afirmado.
Referencia temática: F-SERECI-101 · Tipo: mixto
OpenSoul | Documento de escenarios | 2026-10-04
66

## Página 67

ESC-DISC-101 / DISC
Primera calificación de discapacidad
Situación: Propuesta de conversación para primera calificación de discapacidad. Las respuestas son
alternativas que el usuario debe elegir; no describen hechos ya confirmados.
PREGUNTAS EN UNA SECUENCIA POSIBLE
1
Persona usuaria
Quiero orientación para la calificación de discapacidad.
2
Funcionario
¿Ya fue evaluado para la calificación de discapacidad?
3
Persona usuaria
Sí, ya fui evaluado.
4
Funcionario
¿Conserva informes médicos relacionados con su solicitud?
5
Persona usuaria
Sí, tengo informes médicos.
6
Funcionario
¿Ya tiene carnet de discapacidad?
7
Persona usuaria
Sí, tengo carnet de discapacidad.
8
Funcionario
¿Necesita un intérprete de Lengua de Señas Boliviana?
9
Persona usuaria
Sí, necesito un intérprete de LSB.
10
Funcionario
Pida que le confirmen por escrito el siguiente paso.
VARIANTES Y RESPUESTAS POSIBLES
P1. ¿Ya fue evaluado para la calificación de discapacidad?
Variantes: ¿Le realizaron evaluación de discapacidad? / ¿Pasó por el equipo de calificación?
Respuestas: Sí, ya fui evaluado. / No, todavía no fui evaluado. / No sé si esa evaluación fue de
calificación.
P2. ¿Conserva informes médicos relacionados con su solicitud?
Variantes: ¿Tiene sus informes médicos? / ¿Trajo informes de salud sobre su solicitud?
Respuestas: Sí, tengo informes médicos. / No, no tengo informes médicos. / No sé qué informe
corresponde.
P3. ¿Ya tiene carnet de discapacidad?
Variantes: ¿Cuenta con un carnet de discapacidad? / ¿Le emitieron carnet de discapacidad?
Respuestas: Sí, tengo carnet de discapacidad. / No, no tengo carnet de discapacidad. / No sé si este
carnet está vigente.
P4. ¿Necesita un intérprete de Lengua de Señas Boliviana?
Variantes: ¿Requiere interpretación en LSB? / ¿Necesita apoyo de un intérprete de LSB?
Respuestas: Sí, necesito un intérprete de LSB. / No, no necesito un intérprete. / No sé cómo solicitar un
intérprete.
ESCENARIOS POSIBLES
Evaluación previa: consultar continuidad. Sin evaluación: pedir orientación para equipo competente. La
app no asigna grado de discapacidad ni diagnóstico.
Condiciones del MD: Turno 4: si Turno 2 es negado o desconocido.
Referencia temática: F-DISC-101 · Tipo: mixto
OpenSoul | Documento de escenarios | 2026-10-04
67

## Página 68

ESC-DISC-102 / DISC
Carnetización o renovación de carnet
Situación: Propuesta de conversación para carnetización o renovación de carnet. Las respuestas son
alternativas que el usuario debe elegir; no describen hechos ya confirmados.
PREGUNTAS EN UNA SECUENCIA POSIBLE
1
Persona usuaria
Quiero consultar mi carnet de discapacidad.
2
Funcionario
¿Ya tiene carnet de discapacidad?
3
Persona usuaria
Sí, tengo carnet de discapacidad.
4
Funcionario
¿Ya fue evaluado para la calificación de discapacidad?
5
Persona usuaria
Sí, ya fui evaluado.
6
Funcionario
¿Trajo algún documento relacionado con su solicitud?
7
Persona usuaria
Sí, traje documentos.
8
Funcionario
¿Prefiere recibir la explicación por escrito?
9
Persona usuaria
Sí, prefiero la explicación por escrito.
10
Funcionario
Pida que le confirmen por escrito el siguiente paso.
VARIANTES Y RESPUESTAS POSIBLES
P1. ¿Ya tiene carnet de discapacidad?
Variantes: ¿Cuenta con un carnet de discapacidad? / ¿Le emitieron carnet de discapacidad?
Respuestas: Sí, tengo carnet de discapacidad. / No, no tengo carnet de discapacidad. / No sé si este
carnet está vigente.
P2. ¿Ya fue evaluado para la calificación de discapacidad?
Variantes: ¿Le realizaron evaluación de discapacidad? / ¿Pasó por el equipo de calificación?
Respuestas: Sí, ya fui evaluado. / No, todavía no fui evaluado. / No sé si esa evaluación fue de
calificación.
P3. ¿Trajo algún documento relacionado con su solicitud?
Variantes: ¿Tiene documentos de su solicitud? / ¿Trae algún papel sobre este trámite?
Respuestas: Sí, traje documentos. / No, no traje documentos. / No sé qué documento corresponde.
P4. ¿Prefiere recibir la explicación por escrito?
Variantes: ¿Quiere una explicación escrita? / ¿Le ayuda que escriba la explicación?
Respuestas: Sí, prefiero la explicación por escrito. / No, no prefiero la explicación escrita. / No sé si la
explicación escrita me ayuda.
ESCENARIOS POSIBLES
Con carnet: consultar vigencia o renovación. Sin carnet: aclarar etapa del registro. Requisitos y cita
deben confirmarse con SEDES y equipo competente.
Referencia temática: F-DISC-101 · Tipo: mixto
OpenSoul | Documento de escenarios | 2026-10-04
68

## Página 69

ESC-DISC-103 / DISC
Consulta de registro o documento extraviado
Situación: Propuesta de conversación para consulta de registro o documento extraviado. Las respuestas
son alternativas que el usuario debe elegir; no describen hechos ya confirmados.
PREGUNTAS EN UNA SECUENCIA POSIBLE
1
Persona usuaria
No encuentro mi carnet de discapacidad.
2
Funcionario
¿Ya tiene carnet de discapacidad?
3
Persona usuaria
Sí, tengo carnet de discapacidad.
4
Funcionario
¿Trajo algún documento relacionado con su solicitud?
5
Persona usuaria
Sí, traje documentos.
6
Funcionario
¿Ya fue evaluado para la calificación de discapacidad?
7
Persona usuaria
Sí, ya fui evaluado.
8
Funcionario
¿Necesita un intérprete de Lengua de Señas Boliviana?
9
Persona usuaria
Sí, necesito un intérprete de LSB.
10
Funcionario
Pida que le confirmen por escrito el siguiente paso.
VARIANTES Y RESPUESTAS POSIBLES
P1. ¿Ya tiene carnet de discapacidad?
Variantes: ¿Cuenta con un carnet de discapacidad? / ¿Le emitieron carnet de discapacidad?
Respuestas: Sí, tengo carnet de discapacidad. / No, no tengo carnet de discapacidad. / No sé si este
carnet está vigente.
P2. ¿Trajo algún documento relacionado con su solicitud?
Variantes: ¿Tiene documentos de su solicitud? / ¿Trae algún papel sobre este trámite?
Respuestas: Sí, traje documentos. / No, no traje documentos. / No sé qué documento corresponde.
P3. ¿Ya fue evaluado para la calificación de discapacidad?
Variantes: ¿Le realizaron evaluación de discapacidad? / ¿Pasó por el equipo de calificación?
Respuestas: Sí, ya fui evaluado. / No, todavía no fui evaluado. / No sé si esa evaluación fue de
calificación.
P4. ¿Necesita un intérprete de Lengua de Señas Boliviana?
Variantes: ¿Requiere interpretación en LSB? / ¿Necesita apoyo de un intérprete de LSB?
Respuestas: Sí, necesito un intérprete de LSB. / No, no necesito un intérprete. / No sé cómo solicitar un
intérprete.
ESCENARIOS POSIBLES
Aclarar emisión previa y pérdida. Pedir consulta del registro y modalidad de reposición. No ordenar una
nueva evaluación sin indicación institucional.
Referencia temática: F-DISC-101 · Tipo: mixto
OpenSoul | Documento de escenarios | 2026-10-04
69

## Página 70

ESC-DISC-104 / DISC
Orientación para beneficio municipal
Situación: Propuesta de conversación para orientación para beneficio municipal. Las respuestas son
alternativas que el usuario debe elegir; no describen hechos ya confirmados.
PREGUNTAS EN UNA SECUENCIA POSIBLE
1
Persona usuaria
Quiero consultar apoyo municipal por discapacidad.
2
Funcionario
¿Ya tiene carnet de discapacidad?
3
Persona usuaria
Sí, tengo carnet de discapacidad.
4
Funcionario
¿Trajo algún documento relacionado con su solicitud?
5
Persona usuaria
Sí, traje documentos.
6
Funcionario
¿Ya fue evaluado para la calificación de discapacidad?
7
Persona usuaria
Sí, ya fui evaluado.
8
Funcionario
¿Prefiere recibir la explicación por escrito?
9
Persona usuaria
Sí, prefiero la explicación por escrito.
10
Funcionario
Pida que le confirmen por escrito el siguiente paso.
VARIANTES Y RESPUESTAS POSIBLES
P1. ¿Ya tiene carnet de discapacidad?
Variantes: ¿Cuenta con un carnet de discapacidad? / ¿Le emitieron carnet de discapacidad?
Respuestas: Sí, tengo carnet de discapacidad. / No, no tengo carnet de discapacidad. / No sé si este
carnet está vigente.
P2. ¿Trajo algún documento relacionado con su solicitud?
Variantes: ¿Tiene documentos de su solicitud? / ¿Trae algún papel sobre este trámite?
Respuestas: Sí, traje documentos. / No, no traje documentos. / No sé qué documento corresponde.
P3. ¿Ya fue evaluado para la calificación de discapacidad?
Variantes: ¿Le realizaron evaluación de discapacidad? / ¿Pasó por el equipo de calificación?
Respuestas: Sí, ya fui evaluado. / No, todavía no fui evaluado. / No sé si esa evaluación fue de
calificación.
P4. ¿Prefiere recibir la explicación por escrito?
Variantes: ¿Quiere una explicación escrita? / ¿Le ayuda que escriba la explicación?
Respuestas: Sí, prefiero la explicación por escrito. / No, no prefiero la explicación escrita. / No sé si la
explicación escrita me ayuda.
ESCENARIOS POSIBLES
Consultar el programa concreto y condiciones actuales. Carnetización y pago de beneficios son gestiones
diferentes; no prometer bono ni monto.
Referencia temática: F-DISC-101 · Tipo: mixto
OpenSoul | Documento de escenarios | 2026-10-04
70

## Página 71

ESC-LSB-101 / LSB
Solicitar interpretación en una ventanilla
Situación: Propuesta de conversación para solicitar interpretación en una ventanilla. Las respuestas son
alternativas que el usuario debe elegir; no describen hechos ya confirmados.
PREGUNTAS EN UNA SECUENCIA POSIBLE
1
Persona usuaria
Soy una persona sorda y necesito interpretación en LSB.
2
Funcionario
¿Necesita un intérprete de Lengua de Señas Boliviana?
3
Persona usuaria
Sí, necesito un intérprete de LSB.
4
Funcionario
¿Prefiere recibir la explicación por escrito?
5
Persona usuaria
Sí, prefiero la explicación por escrito.
6
Funcionario
¿Entendió el siguiente paso?
7
Persona usuaria
Sí, entendí el siguiente paso.
8
Funcionario
¿Tiene un contacto seguro para recibir información?
9
Persona usuaria
Sí, tengo un contacto seguro.
10
Funcionario
Pida que le confirmen por escrito el siguiente paso.
VARIANTES Y RESPUESTAS POSIBLES
P1. ¿Necesita un intérprete de Lengua de Señas Boliviana?
Variantes: ¿Requiere interpretación en LSB? / ¿Necesita apoyo de un intérprete de LSB?
Respuestas: Sí, necesito un intérprete de LSB. / No, no necesito un intérprete. / No sé cómo solicitar un
intérprete.
P2. ¿Prefiere recibir la explicación por escrito?
Variantes: ¿Quiere una explicación escrita? / ¿Le ayuda que escriba la explicación?
Respuestas: Sí, prefiero la explicación por escrito. / No, no prefiero la explicación escrita. / No sé si la
explicación escrita me ayuda.
P3. ¿Entendió el siguiente paso?
Variantes: ¿Comprendió qué debe hacer después? / ¿Está claro el paso siguiente?
Respuestas: Sí, entendí el siguiente paso. / No, no entendí el siguiente paso. / No sé cuál es el siguiente
paso.
P4. ¿Tiene un contacto seguro para recibir información?
Variantes: ¿Puede indicar un medio seguro de contacto? / ¿Cuenta con un contacto que sea seguro?
Respuestas: Sí, tengo un contacto seguro. / No, no tengo un contacto seguro. / No sé qué contacto es
seguro.
ESCENARIOS POSIBLES
Con necesidad de interpretación: pedir coordinación. La escritura es alternativa aceptada solo si resulta
comprensible; no reemplaza automáticamente la interpretación.
Referencia temática: F-LSB-101 · Tipo: mixto
OpenSoul | Documento de escenarios | 2026-10-04
71

## Página 72

ESC-LSB-102 / LSB
Negación de atención o barrera comunicativa
Situación: Propuesta de conversación para negación de atención o barrera comunicativa. Las respuestas
son alternativas que el usuario debe elegir; no describen hechos ya confirmados.
PREGUNTAS EN UNA SECUENCIA POSIBLE
1
Persona usuaria
No me atendieron por mi forma de comunicarme.
2
Funcionario
¿Le negaron atención por su forma de comunicarse?
3
Persona usuaria
Sí, me negaron atención.
4
Funcionario
¿Trajo algún documento relacionado con su solicitud?
5
Persona usuaria
Sí, traje documentos.
6
Funcionario
¿Necesita un intérprete de Lengua de Señas Boliviana?
7
Persona usuaria
Sí, necesito un intérprete de LSB.
8
Funcionario
¿Prefiere recibir la explicación por escrito?
9
Persona usuaria
Sí, prefiero la explicación por escrito.
10
Funcionario
Pida que le confirmen por escrito el siguiente paso.
VARIANTES Y RESPUESTAS POSIBLES
P1. ¿Le negaron atención por su forma de comunicarse?
Variantes: ¿Le impidieron recibir atención por usar LSB? / ¿Le negaron atención por ser una persona
sorda?
Respuestas: Sí, me negaron atención. / No, no me negaron atención. / No sé por qué me negaron
atención.
P2. ¿Trajo algún documento relacionado con su solicitud?
Variantes: ¿Tiene documentos de su solicitud? / ¿Trae algún papel sobre este trámite?
Respuestas: Sí, traje documentos. / No, no traje documentos. / No sé qué documento corresponde.
P3. ¿Necesita un intérprete de Lengua de Señas Boliviana?
Variantes: ¿Requiere interpretación en LSB? / ¿Necesita apoyo de un intérprete de LSB?
Respuestas: Sí, necesito un intérprete de LSB. / No, no necesito un intérprete. / No sé cómo solicitar un
intérprete.
P4. ¿Prefiere recibir la explicación por escrito?
Variantes: ¿Quiere una explicación escrita? / ¿Le ayuda que escriba la explicación?
Respuestas: Sí, prefiero la explicación por escrito. / No, no prefiero la explicación escrita. / No sé si la
explicación escrita me ayuda.
ESCENARIOS POSIBLES
Registrar institución, fecha y lo ocurrido sin inferir motivos. Solicitar orientación en Defensoría del
Pueblo; no garantizar sanción ni resolución.
Condiciones del MD: Turno 4: si Turno 2 es afirmado.
Referencia temática: F-LSB-101 · Tipo: mixto
OpenSoul | Documento de escenarios | 2026-10-04
72

## Página 73

ESC-LSB-103 / LSB
Documento que no se entiende antes de firmar
Situación: Propuesta de conversación para documento que no se entiende antes de firmar. Las
respuestas son alternativas que el usuario debe elegir; no describen hechos ya confirmados.
PREGUNTAS EN UNA SECUENCIA POSIBLE
1
Persona usuaria
No entiendo este documento y necesito ayuda.
2
Funcionario
¿Comprendió el documento antes de firmar?
3
Persona usuaria
Sí, comprendí el documento.
4
Funcionario
¿Necesita un intérprete de Lengua de Señas Boliviana?
5
Persona usuaria
Sí, necesito un intérprete de LSB.
6
Funcionario
¿Ya firmó el documento?
7
Persona usuaria
Sí, ya firmé.
8
Funcionario
¿Prefiere recibir la explicación por escrito?
9
Persona usuaria
Sí, prefiero la explicación por escrito.
10
Funcionario
Pida que le confirmen por escrito el siguiente paso.
VARIANTES Y RESPUESTAS POSIBLES
P1. ¿Comprendió el documento antes de firmar?
Variantes: ¿Entiende el contenido del documento? / ¿Está claro qué dice el documento?
Respuestas: Sí, comprendí el documento. / No, no comprendí el documento. / No sé qué dice el
documento.
P2. ¿Necesita un intérprete de Lengua de Señas Boliviana?
Variantes: ¿Requiere interpretación en LSB? / ¿Necesita apoyo de un intérprete de LSB?
Respuestas: Sí, necesito un intérprete de LSB. / No, no necesito un intérprete. / No sé cómo solicitar un
intérprete.
P3. ¿Ya firmó el documento?
Variantes: ¿Su firma ya está en el documento? / ¿Firmó antes de venir?
Respuestas: Sí, ya firmé. / No, todavía no firmé. / No sé si esa firma corresponde.
P4. ¿Prefiere recibir la explicación por escrito?
Variantes: ¿Quiere una explicación escrita? / ¿Le ayuda que escriba la explicación?
Respuestas: Sí, prefiero la explicación por escrito. / No, no prefiero la explicación escrita. / No sé si la
explicación escrita me ayuda.
ESCENARIOS POSIBLES
No convertir incomprensión en consentimiento. Si ya firmó: pedir orientación profesional sobre el acto.
No afirmar nulidad ni validez jurídica desde el RAG.
Condiciones del MD: Turno 4: si Turno 2 es negado o desconocido.
Referencia temática: F-LSB-101 · Tipo: mixto
OpenSoul | Documento de escenarios | 2026-10-04
73

## Página 74

ESC-LSB-104 / LSB
Oficina equivocada o atención no disponible
Situación: Propuesta de conversación para oficina equivocada o atención no disponible. Las respuestas
son alternativas que el usuario debe elegir; no describen hechos ya confirmados.
PREGUNTAS EN UNA SECUENCIA POSIBLE
1
Persona usuaria
No sé qué oficina atiende mi solicitud.
2
Funcionario
¿Trajo algún documento relacionado con su solicitud?
3
Persona usuaria
Sí, traje documentos.
4
Funcionario
¿Tiene el número de su trámite?
5
Persona usuaria
Sí, tengo el número.
6
Funcionario
¿Necesita un intérprete de Lengua de Señas Boliviana?
7
Persona usuaria
Sí, necesito un intérprete de LSB.
8
Funcionario
¿Prefiere recibir la explicación por escrito?
9
Persona usuaria
Sí, prefiero la explicación por escrito.
10
Funcionario
Pida que le confirmen por escrito el siguiente paso.
VARIANTES Y RESPUESTAS POSIBLES
P1. ¿Trajo algún documento relacionado con su solicitud?
Variantes: ¿Tiene documentos de su solicitud? / ¿Trae algún papel sobre este trámite?
Respuestas: Sí, traje documentos. / No, no traje documentos. / No sé qué documento corresponde.
P2. ¿Tiene el número de su trámite?
Variantes: ¿Conoce el código del trámite? / ¿Trajo el número de la solicitud?
Respuestas: Sí, tengo el número. / No, no tengo el número. / No sé cuál es el número.
P3. ¿Necesita un intérprete de Lengua de Señas Boliviana?
Variantes: ¿Requiere interpretación en LSB? / ¿Necesita apoyo de un intérprete de LSB?
Respuestas: Sí, necesito un intérprete de LSB. / No, no necesito un intérprete. / No sé cómo solicitar un
intérprete.
P4. ¿Prefiere recibir la explicación por escrito?
Variantes: ¿Quiere una explicación escrita? / ¿Le ayuda que escriba la explicación?
Respuestas: Sí, prefiero la explicación por escrito. / No, no prefiero la explicación escrita. / No sé si la
explicación escrita me ayuda.
ESCENARIOS POSIBLES
Aclarar trámite y confirmar competencia. Si oficina cerrada o personal ausente: pedir fecha y canal
oficiales; no inventar horario ni enviarlo a una oficina sin confirmar.
Referencia temática: F-LSB-101 · Tipo: mixto
OpenSoul | Documento de escenarios | 2026-10-04
74

## Página 75

Fuentes oficiales consultadas
Consultadas el 2026-10-04
F-GAM-101 · INNOVA seguimiento municipal
https://innova.cochabamba.bo/menu-consultaAtlas
F-GAM-102 · GAM consulta de deudas
https://www.gob.bo/tramites/consulta-de-deudas
F-IMP-101 · RUAT consulta de vehículos
https://www.ruat.gob.bo/vehiculos/consultageneral/InicioBusquedaVehiculo.jsf
F-FIS-101 · Directorio del Ministerio Público
https://www.gob.bo/entidades/ministerio-publico
F-OJ-101 · SIREJ forma de uso
https://magistratura.organojudicial.gob.bo/sirej/index.php?r=formauso/index
F-SEPDEP-101 · SEPDEP defensa penal gratuita
https://www.gob.bo/tramites/defensa-penal-gratuita
F-SEPDAVI-101 · SEPDAVI asistencia a víctimas
https://www.gob.bo/entidades/servicio-plurinacional-de-asistencia-a-la-victima
F-FELCC-101 · FELCC investigación de robo de celulares
https://www.policia.bo/%F0%9D%97%94%F0%9D%97%A3%F0%9D%97%A5%F0%9D%97%A2%F0%9D%97%9B%F0
%9D%97%98%F0%9D%97%A1%F0%9D%97%97%F0%9D%97%98%F0%9D%97%A0%F0%9D%97%A2%F0%9D%97%
A6-%F0%9D%97%94-%F0%9D%97%A8%F0%9D%97%A1-%F0%9D%97%97/
F-FELCV-101 · FELCV ruta general de atención
https://www.defensoria.gob.bo/oficinas/prensa/defensoria-del-pueblo-y-sedes-pando-socializan-ley-348-para-garantiza
r-a-las-mujeres-una-vida-libre-de-violencia-y-los-derechos-sexuales-y-derechos-reproductivos
F-SLIM-101 · SLIM ruta general de atención
https://www.defensoria.gob.bo/oficinas/prensa/defensoria-del-pueblo-y-sedes-pando-socializan-ley-348-para-garantiza
r-a-las-mujeres-una-vida-libre-de-violencia-y-los-derechos-sexuales-y-derechos-reproductivos
F-DNA-101 · DNA protección de la niñez en Cochabamba
https://www.defensoria.gob.bo/oficinas/prensa/defensoria-del-pueblo-insta-a-las-autoridades-investigar-presunta-agre
sion-fisica-a-un-ninyo-en-kinder-de-cochabamba
F-DDRR-101 · DDRR catálogo de trámites
https://tramitesddrr.organojudicial.gob.bo/
F-NOT-101 · DIRNOPLU servicio notarial
https://www.gob.bo/entidades/direccion-del-notariado-plurinacional
F-SEGIP-101 · SEGIP identificación institucional
https://www.gob.bo/entidades/servicio-general-de-identificacion-personal
F-SERECI-101 · SERECI servicios de registro civil
https://web.oep.org.bo/registro-civico/servicios-registro-civil/
F-DISC-101 · Calificación y carnetización de discapacidad
https://www.gob.bo/tramites/calificacion-registro-y-carnetizacion-de-discapacidad
F-LSB-101 · LSB derechos lingüísticos y Ley 1658
https://www.defensoria.gob.bo/oficinas/prensa/defensoria-del-pueblo-concluye-con-exito-el-5%C2%BA-festival-cultural
-de-artes-en-lengua-de-senyas-boliviana-y-exhorta-al-estado-reglamentar-la-ley-n%C2%BA-1658
OpenSoul | Documento de escenarios | 2026-10-04
75

