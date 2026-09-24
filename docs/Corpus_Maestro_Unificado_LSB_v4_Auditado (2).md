**CORPUS MAESTRO UNIFICADO ESPAÑOL ↔ LSB  
VERSIÓN 4.0 AUDITADA**

Etapa preliminar judicial penal — Cochabamba, Bolivia

**Base léxica compartida para los módulos Audio/Texto → LSB y LSB → Texto/Audio**

Auditoría de los corpus conversacionales v2 y v3, integración con fuentes oficiales M1–M4 y II Diccionario Bilingüe LSB–Castellano 2024.

Documento de trabajo para Proyecto de Grado  
Septiembre de 2026

# 1. Decisión de arquitectura: sí se puede unificar el diccionario

La unificación no significa que ambos módulos deban aceptar exactamente el mismo tipo de entrada. Debe unificarse la representación léxica interna: una sola fuente de verdad para las señas LSB, sus identificadores, archivos de animación, fuentes y metadatos.

El módulo Audio/Texto → LSB puede aceptar español libre. Ese texto no se convierte palabra por palabra en señas; primero se normaliza semánticamente y luego se restringe a conceptos que el sistema sabe expresar con el léxico LSB validado, composiciones validadas o dactilología.

El módulo LSB → Texto/Audio, en cambio, parte de glosas/tarjetas del mismo léxico canónico. Por tanto, los dos módulos comparten el diccionario de salida/representación, aunque sus entradas sean asimétricas.

## 1.1. Estructura recomendada

| **Capa**                  | **Función**                                                                     | **Ejemplo**                                                                               |
|---------------------------|---------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------|
| lsb_lexicon.json          | Única fuente de verdad de señas directas LSB.                                   | ROBAR → D2024-499 → asset robar.glb                                                       |
| spanish_aliases.json      | Sinónimos y formas libres del español se asocian a un concepto.                 | “me sustrajeron”, “me robaron”, “se llevó mi celular” → concepto ROBO                     |
| concept_compositions.json | Conceptos sin seña directa se representan con secuencias previamente validadas. | DENUNCIA → QUEJAR + AUTORIDAD (solo si se valida)                                         |
| dactylology               | Nombres propios, siglas y términos técnicos no estandarizados.                  | d(FELCC), d(FISCALÍA), d(SEPDAVI)                                                         |
| conversation_templates    | Preguntas/escenarios para pruebas; no crean nuevas señas.                       | “¿Qué ocurrió?” y “Cuénteme qué pasó” pueden terminar en la misma intención RELATO_HECHO. |

**Regla de ingeniería:** entrada libre en español ≠ diccionario infinito de señas. El NLP puede recibir vocabulario abierto, pero la salida visual debe pasar por una compuerta de cobertura léxica antes de reproducirse en el avatar.

# 2. Delimitación institucional y correcciones

| **Institución/actor**                           | **Uso dentro del alcance**                                                                                                                                    |
|-------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Ministerio Público / Fiscalías Departamentales  | Recepción y conducción de actuaciones iniciales vinculadas a denuncias e investigación penal.                                                                 |
| FELCC                                           | Recepción de denuncias e investigación policial en hechos de competencia criminal.                                                                            |
| FELCV                                           | Atención policial especializada en violencia, según corresponda al caso.                                                                                      |
| Juzgados de Instrucción Penal / Órgano Judicial | Control jurisdiccional en la etapa preparatoria; se incluye solo la interacción básica limítrofe al alcance.                                                  |
| SEPDAVI                                         | Servicio Plurinacional de Asistencia a la Víctima. Apoyo jurídico, psicológico y social según su marco institucional.                                         |
| SEPDEP                                          | Servicio Plurinacional de Defensa Pública. Defensa penal gratuita para personas denunciadas, imputadas o procesadas que cumplan las condiciones del servicio. |
| Usuario institucional del sistema               | Receptor de denuncias, policía, fiscal u operador que necesita comunicarse con la persona sorda; no un funcionario municipal genérico.                        |

**Corrección importante:** el nombre oficial es SEPDAVI, no “SEPAV”. Para Defensa Pública, la sigla oficial utilizada por la institución es SEPDEP.

# 3. Auditoría de los dos corpus recibidos

| **Hallazgo**              | **Resultado**                                                                                                                                         |
|---------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------|
| Corpus conversacional v2  | 267 glosas candidatas.                                                                                                                                |
| Corpus ciudadano sordo v3 | 255 glosas candidatas.                                                                                                                                |
| Intersección              | 237 glosas aparecen en ambos con el mismo ID y la misma referencia de módulo.                                                                         |
| Unión                     | 285 glosas candidatas antes de incorporar el Diccionario 2024.                                                                                        |
| Diferencias               | 30 glosas solo en v2 y 18 solo en v3; la diferencia responde principalmente al alcance funcionario/judicial frente al corpus solo ciudadano-policial. |
| Problema detectado        | Los corpus trataban M1–M4 como si fueran exhaustivos de toda la LSB. No lo son: el Diccionario 2024 incorpora vocabulario útil adicional.             |

## 3.1. Jerarquía de fuentes adoptada para esta versión

- Nivel A — II Diccionario Bilingüe LSB–Castellano (Ministerio de Educación, 2024; revisión FEBOS): fuente léxica más reciente revisada en esta auditoría.

- Nivel B — Curso de Enseñanza de la LSB, Módulos 1–4 (Ministerio de Educación / FEBOS, 2010): fuente oficial con fotografías y señalización de movimiento.

- Nivel C — Corpus v2/v3 aportados por el usuario: sirven como banco de escenarios y trazabilidad, no como autoridad lingüística independiente.

- Nivel D — Validación con personas sordas señantes de Cochabamba e intérpretes: obligatoria para sintaxis, variantes regionales y composiciones jurídicas no documentadas.

## 3.2. Correcciones relevantes encontradas

| **Término** | **Resultado de auditoría**                                                            | **Decisión**                                                                                          |
|-------------|---------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------|
| ROBAR       | No estaba en M1–M4 del corpus, pero sí aparece como entrada 499 del Diccionario 2024. | Añadir como seña directa al diccionario maestro.                                                      |
| LADRÓN/A    | Aparece como entrada 326 del Diccionario 2024.                                        | Añadir como seña directa.                                                                             |
| TESTIGO     | Aparece como entrada 557 del Diccionario 2024.                                        | Añadir como seña directa; ya no hace falta reemplazar siempre por “persona que vio”.                  |
| TESTIMONIO  | Aparece como entrada 558 del Diccionario 2024.                                        | Añadir como seña directa.                                                                             |
| TRÁMITE     | Aparece en el índice del Diccionario 2024, p.216.                                     | Puede existir como seña directa en el maestro; usar solo cuando el contexto realmente sea un trámite. |
| VIOLENCIA   | Aparece en el Diccionario 2024, p.228.                                                | Añadir como seña directa.                                                                             |
| PRESENTAR   | Aparece como entrada 471 del Diccionario 2024.                                        | Útil para “presentar fotos/papel”, evitando perífrasis innecesarias.                                  |
| RESOLUCIÓN  | Aparece en el Diccionario 2024, p.188, con sentido administrativo/judicial.           | Añadir como seña directa; es especialmente útil para desambiguar “auto/resolución”.                   |
| FISCAL      | La seña FISCAL de M3 corresponde al sentido escolar “fiscal/público”.                 | Prohibido reutilizarla para el fiscal del Ministerio Público.                                         |
| DENUNCIA    | No se localizó como entrada directa en M1–M4 ni en el índice revisado de 2024.        | Mantener como concepto semántico; composición o dactilología requieren validación.                    |

# 4. Conceptos jurídicos sin correspondencia directa segura

| **Concepto**          | **Estado**                                                                                                                    | **Tratamiento seguro para el software**                                                                                                                 |
|-----------------------|-------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------|
| DENUNCIA / DENUNCIAR  | No localizada como entrada directa en M1-4 ni en el índice revisado del Diccionario 2024.                                     | Concepto semántico. Propuesta provisional: QUEJAR + AUTORIDAD; validar con señantes de Cochabamba. Dactilología solo si se necesita el término literal. |
| FISCAL (funcionario)  | No localizada como entrada jurídica directa. La palabra FISCAL de M3 corresponde a “fiscal” en el sentido de escuela pública. | No reutilizar esa seña. Usar d(FISCAL) hasta validar una seña institucional aceptada.                                                                   |
| FISCALÍA              | No localizada como entrada directa en las fuentes revisadas.                                                                  | Usar d(FISCALÍA) para la institución exacta; opcionalmente asociar el concepto a MINISTERIO-PÚBLICO como alias de software, no como seña inventada.     |
| FELCC / FELCV         | Siglas institucionales.                                                                                                       | Usar d(FELCC) / d(FELCV), o una seña institucional solo si es validada por la comunidad.                                                                |
| SEPDAVI               | Nombre institucional oficial: Servicio Plurinacional de Asistencia a la Víctima.                                              | Usar d(SEPDAVI) cuando se requiera el nombre exacto.                                                                                                    |
| SEPDEP                | Nombre institucional oficial: Servicio Plurinacional de Defensa Pública.                                                      | Usar d(SEPDEP) cuando se requiera el nombre exacto.                                                                                                     |
| JUZGADO               | No localizada como entrada directa en el índice revisado del Diccionario 2024.                                                | Para el concepto general puede usarse ÓRGANO-JUDICIAL + OFICINA como composición provisional; para el nombre exacto, d(JUZGADO).                        |
| VÍCTIMA               | No localizada como entrada directa en el índice revisado.                                                                     | Evitar inventar una seña. Referenciar a la persona en el espacio o usar d(VÍCTIMA) si el término técnico es indispensable.                              |
| IMPUTADO / DENUNCIADO | No localizado como entrada directa en las fuentes revisadas.                                                                  | Usar referencia espacial al participante o d(IMPUTADO)/d(DENUNCIADO) cuando el término procesal sea imprescindible.                                     |
| DECLARACIÓN           | No localizada como entrada léxica jurídica directa.                                                                           | Mapear por intención: NARRAR para relatar; TESTIMONIO cuando corresponda a contenido testimonial. No crear una seña “DECLARACIÓN” sin validación.       |
| DOCUMENTO             | No localizada como entrada genérica directa en las fuentes revisadas.                                                         | Preferir el objeto concreto: PAPEL, CERTIFICADO, FOTOCOPIA, FACTURA, RESOLUCIÓN, TEXTO.                                                                 |
| FIRMA / FIRMAR        | No localizada como entrada directa.                                                                                           | Composición provisional NOMBRE + ESCRIBIR; debe validarse antes de animarla como unidad semántica.                                                      |
| ACTA                  | No localizada como entrada directa.                                                                                           | Usar el tipo de papel concreto o d(ACTA) si es necesario el término técnico.                                                                            |
| PRUEBA / EVIDENCIA    | No conviene forzar una seña genérica.                                                                                         | Nombrar la evidencia concreta: FOTOS, VIDEO, TESTIMONIO, CERTIFICADO, PAPEL, FACTURA.                                                                   |
| AUDIENCIA             | No localizada como entrada directa en el índice revisado.                                                                     | Si aparece en el límite del proyecto, usar d(AUDIENCIA) o composición JUEZ + REUNIÓN solo después de validación.                                        |

**Importante:** “no localizada en estas fuentes” no significa “no existe en toda la LSB”. Significa únicamente que el proyecto no debe inventar una seña ni atribuirle una fuente oficial que no ha sido encontrada.

# 5. Cómo resolver el español libre sin romper el diccionario unificado

| **Entrada libre del funcionario** | **Intención normalizada** | **Salida léxica objetivo**                               |
|-----------------------------------|---------------------------|----------------------------------------------------------|
| ¿Qué ocurrió?                     | RELATO_HECHO              | NARRAR + ¿QUÉ?                                           |
| Cuénteme qué pasó.                | RELATO_HECHO              | NARRAR + ¿QUÉ?                                           |
| Explíqueme lo sucedido.           | RELATO_HECHO              | EXPLICAR / NARRAR                                        |
| ¿Le sustrajeron el teléfono?      | ROBO_CELULAR              | ROBAR + CELULAR                                          |
| ¿Le robaron su celular?           | ROBO_CELULAR              | ROBAR + CELULAR                                          |
| ¿Había alguien que vio el hecho?  | TESTIGO_EXISTE            | TESTIGO + TENER                                          |
| ¿Existían testigos?               | TESTIGO_EXISTE            | TESTIGO + TENER                                          |
| ¿Quiere interponer una denuncia?  | INTENCION_DENUNCIA        | \[DENUNCIA\] → composición validada o dactilología       |
| ¿Desea formular una denuncia?     | INTENCION_DENUNCIA        | \[DENUNCIA\] → misma representación que la fila anterior |

# 6. Banco ampliado de preguntas del funcionario/receptor

Las siguientes frases son entradas de prueba en español. La columna “conceptos objetivo” representa la salida léxica esperada del normalizador; no pretende fijar por sí sola la sintaxis natural definitiva de la LSB.

## Acceso comunicativo e identificación

| **\#** | **Pregunta en español**                          | **Intención**            | **Conceptos LSB objetivo**         | **Estado/nota**             |
|--------|--------------------------------------------------|--------------------------|------------------------------------|-----------------------------|
| 1      | ¿Usted es una persona sorda?                     | CONFIRMAR_ACCESO         | TÚ · SORDO                         | Directo                     |
| 2      | ¿Necesita un intérprete de LSB?                  | NECESIDAD_INTERPRETE     | INTÉRPRETE · NECESITAR             | Directo                     |
| 3      | ¿Prefiere que le escriba en papel?               | CANAL_ESCRITO            | ESCRIBIR · PAPEL · MEJOR           | Directo                     |
| 4      | ¿Puede leer este texto?                          | LECTURA                  | TÚ · LEER · PUEDO · TEXTO          | Directo                     |
| 5      | ¿Comprende lo que le estoy explicando?           | COMPRENSION              | TÚ · COMPRENDER · EXPLICAR         | Directo                     |
| 6      | ¿Quiere que lo explique otra vez y más despacio? | REPARACION               | VOLVER · EXPLICAR · LENTO · QUERER | Directo                     |
| 7      | ¿Cuál es su nombre completo?                     | IDENTIFICACION_NOMBRE    | TUYO · NOMBRE · ¿CUÁL?             | Directo                     |
| 8      | ¿Puede deletrear su apellido?                    | IDENTIFICACION_DELETREO  | DELETREAR · NOMBRE · PUEDO         | Directo                     |
| 9      | ¿Tiene su carnet de identidad?                   | IDENTIFICACION_DOCUMENTO | PAPEL · IDENTIDAD · TENER          | Composición PAPEL+IDENTIDAD |
| 10     | ¿Este número de celular es suyo?                 | VALIDAR_CONTACTO         | CELULAR · NÚM(...) · TUYO · VERDAD | Directo                     |
| 11     | ¿Prefiere recibir avisos por mensaje escrito?    | PREFERENCIA_AVISO        | AVISAR · ESCRIBIR · ENVIAR · MEJOR | Directo                     |
| 12     | ¿Vino solo o acompañado?                         | ACOMPAÑANTE              | TÚ · NÚM(1) · VENIR / ACOMPAÑAR    | Directo                     |

## Inicio de denuncia y relato básico

| **\#** | **Pregunta en español**                      | **Intención**        | **Conceptos LSB objetivo**         | **Estado/nota**                                       |
|--------|----------------------------------------------|----------------------|------------------------------------|-------------------------------------------------------|
| 1      | ¿Desea presentar una denuncia?               | INTENCION_DENUNCIA   | PRESENTAR · \[DENUNCIA\]           | DENUNCIA es concepto pendiente; no crear seña directa |
| 2      | ¿Qué ocurrió?                                | RELATO_ABIERTO       | TÚ · NARRAR · ¿QUÉ?                | Directo; sintaxis final a validar                     |
| 3      | ¿Puede contarme lo sucedido desde el inicio? | RELATO_ORDENADO      | NARRAR · EMPEZAR · PRIMERA-VEZ     | Directo                                               |
| 4      | ¿Cuándo ocurrió?                             | TIEMPO_HECHO         | ¿CUÁNDO? · FECHA · HORA            | Directo                                               |
| 5      | ¿Fue hoy, ayer o antes?                      | TIEMPO_APROX         | HOY · AYER · PASADO                | Directo                                               |
| 6      | ¿A qué hora aproximadamente?                 | HORA_HECHO           | HORA · ¿CUÁNTOS? · MÁS-O-MENOS     | Directo                                               |
| 7      | ¿Dónde ocurrió?                              | LUGAR_HECHO          | ¿DÓNDE?                            | Directo                                               |
| 8      | ¿Ocurrió dentro o fuera del lugar?           | POSICION_LUGAR       | DENTRO · FUERA · ¿CUÁL?            | Directo                                               |
| 9      | ¿Conoce a la persona involucrada?            | CONOCIMIENTO_PERSONA | TÚ · ÉL/ELLA · CONOCER             | Directo                                               |
| 10     | ¿Puede identificarla si la vuelve a ver?     | RECONOCIMIENTO       | IDENTIFICAR · VOLVER · VER · PUEDO | Directo D2024 + M1-4                                  |
| 11     | ¿Había otras personas presentes?             | PRESENCIA_OTROS      | HOMBRE · MUJER · ALLÍ · TENER      | Directo                                               |
| 12     | ¿Quiere agregar algo que no le pregunté?     | AMPLIACION_RELATO    | AUMENTAR · NARRAR · QUERER         | Directo                                               |

## Descripción de personas

| **\#** | **Pregunta en español**                     | **Intención**    | **Conceptos LSB objetivo**            | **Estado/nota**                               |
|--------|---------------------------------------------|------------------|---------------------------------------|-----------------------------------------------|
| 1      | ¿Era un hombre o una mujer?                 | SEXO_DESCRIPCION | HOMBRE · MUJER · ¿CUÁL?               | Directo                                       |
| 2      | ¿Era joven o adulto?                        | EDAD_APROX       | JOVEN · ADULTO · ¿CUÁL?               | Directo                                       |
| 3      | ¿Era alto o bajo?                           | ALTURA           | ALTO · BAJO · ¿CUÁL?                  | Directo                                       |
| 4      | ¿Era delgado o de contextura gruesa?        | CONTEXTURA       | FLACO · GORDO · ¿CUÁL?                | Directo                                       |
| 5      | ¿Qué color de cabello recuerda?             | CABELLO          | CABELLO · COLOR · ¿CUÁL?              | COLOR como categoría; usar colores concretos  |
| 6      | ¿Qué ropa llevaba?                          | VESTIMENTA       | POLERA · PANTALÓN · CHAMARRA · ¿CUÁL? | Directo                                       |
| 7      | ¿Llevaba gorra?                             | GORRA            | GORRA · TENER                         | Directo                                       |
| 8      | ¿Llevaba mochila o bolsa?                   | OBJETO_PERSONA   | MOCHILA · BOLSA · ¿CUÁL?              | Directo                                       |
| 9      | ¿Usaba lentes?                              | LENTES           | LENTES · TENER                        | Directo                                       |
| 10     | ¿Recuerda alguna característica particular? | RASGO_DISTINTIVO | RECORDAR · ¿QUÉ?                      | No forzar “tatuaje”; describir rasgo concreto |

## Robo, hurto y objetos

| **\#** | **Pregunta en español**                  | **Intención**     | **Conceptos LSB objetivo**       | **Estado/nota**                               |
|--------|------------------------------------------|-------------------|----------------------------------|-----------------------------------------------|
| 1      | ¿Le robaron algún objeto?                | ROBO_OBJETO       | ROBAR · OBJETO                   | ROBAR directo D2024; objeto debe ser concreto |
| 2      | ¿Qué le robaron?                         | OBJETO_ROBADO     | ROBAR · ¿QUÉ?                    | Directo                                       |
| 3      | ¿Le robaron el celular?                  | ROBO_CELULAR      | ROBAR · CELULAR                  | Directo                                       |
| 4      | ¿Le falta su carnet de identidad?        | FALTA_IDENTIDAD   | PAPEL · IDENTIDAD · PERDER       | Composición                                   |
| 5      | ¿Le falta dinero?                        | FALTA_DINERO      | DINERO/BILLETES · PERDER         | Directo                                       |
| 6      | ¿Vio al ladrón?                          | VER_LADRON        | LADRÓN · VER                     | LADRÓN directo D2024                          |
| 7      | ¿El ladrón escapó?                       | ESCAPE            | LADRÓN · ESCAPAR                 | Directo                                       |
| 8      | ¿Tiene la factura o la caja del celular? | PROPIEDAD_CELULAR | FACTURA · CAJA · CELULAR · TENER | Directo                                       |
| 9      | ¿Hay cámaras o video del lugar?          | VIDEO_LUGAR       | VIDEO · FILMAR · TENER           | Directo                                       |
| 10     | ¿Hay testigos del robo?                  | TESTIGOS_ROBO     | TESTIGO · TENER                  | TESTIGO directo D2024                         |

## Agresión, violencia y riesgo

| **\#** | **Pregunta en español**                                | **Intención**      | **Conceptos LSB objetivo**       | **Estado/nota**              |
|--------|--------------------------------------------------------|--------------------|----------------------------------|------------------------------|
| 1      | ¿Alguien le pegó o maltrató?                           | AGRESION           | PEGAR · MALTRATAR                | Directo M1-4/D2024           |
| 2      | ¿Está herido?                                          | HERIDA             | HERIDA · TENER                   | Directo                      |
| 3      | ¿Necesita asistencia médica?                           | ASISTENCIA_MEDICA  | ASISTENCIA · DOCTOR · NECESITAR  | ASISTENCIA directo D2024     |
| 4      | ¿Fue al hospital?                                      | ATENCION_HOSPITAL  | HOSPITAL · IR                    | Directo                      |
| 5      | ¿Tiene certificado del doctor?                         | CERTIFICADO_MEDICO | CERTIFICADO · DOCTOR · TENER     | Directo                      |
| 6      | ¿Recibió amenazas?                                     | AMENAZA            | AMENAZAR · RECIBIR               | Directo                      |
| 7      | ¿Tiene miedo de volver a su casa?                      | RIESGO_RETORNO     | MIEDO · CASA · VOLVER            | Directo                      |
| 8      | ¿Necesita auxilio ahora?                               | AUXILIO_INMEDIATO  | AUXILIO · AHORA · NECESITAR      | AUXILIO directo D2024        |
| 9      | ¿Hay niños u otras personas que necesiten protección?  | PROTECCION_OTROS   | HIJO/HIJA · PROTEGER · NECESITAR | Directo                      |
| 10     | ¿Desea orientación para recibir asistencia de SEPDAVI? | DERIVACION_SEPDAVI | ASISTENCIA · d(SEPDAVI) · QUERER | Institución por dactilología |

## Amenazas, mensajes y entorno digital

| **\#** | **Pregunta en español**                        | **Intención**        | **Conceptos LSB objetivo**        | **Estado/nota** |
|--------|------------------------------------------------|----------------------|-----------------------------------|-----------------|
| 1      | ¿Las amenazas llegaron por celular?            | AMENAZA_CELULAR      | AMENAZAR · CELULAR · ENVIAR       | Directo         |
| 2      | ¿Le escribieron por internet?                  | MENSAJE_INTERNET     | INTERNET · ESCRIBIR · ENVIAR      | Directo         |
| 3      | ¿Conoce el número desde el que le escribieron? | NUMERO_ORIGEN        | CELULAR · NÚM(...) · CONOCER      | Directo         |
| 4      | ¿Guardó los mensajes?                          | GUARDAR_MENSAJES     | ESCRIBIR · GUARDAR                | Directo         |
| 5      | ¿Tiene fotos de la pantalla?                   | CAPTURAS             | FOTOS · CELULAR · TENER           | Directo         |
| 6      | ¿Sigue recibiendo mensajes?                    | CONTINUIDAD_MENSAJES | AÚN · RECIBIR · ESCRIBIR          | Directo         |
| 7      | ¿Son uno o varios números?                     | CANTIDAD_NUMEROS     | CELULAR · NÚM(...) · ¿CUÁNTOS?    | Directo         |
| 8      | ¿Puede mostrar el celular ahora?               | MOSTRAR_CELULAR      | CELULAR · AHORA · MOSTRAR · PUEDO | Directo         |

## Engaño, dinero y transacciones

| **\#** | **Pregunta en español**           | **Intención**     | **Conceptos LSB objetivo**           | **Estado/nota**      |
|--------|-----------------------------------|-------------------|--------------------------------------|----------------------|
| 1      | ¿Entregó o envió dinero?          | DINERO_ENTREGADO  | DINERO/BILLETES · DAR/ENVIAR         | Directo              |
| 2      | ¿Cuánto dinero entregó?           | MONTO             | BILLETES · ¿CUÁNTOS?                 | Directo              |
| 3      | ¿Lo hizo mediante un banco?       | BANCO             | BANCO · BILLETES · ENVIAR            | Directo              |
| 4      | ¿Tiene factura o papel del banco? | COMPROBANTE       | FACTURA / PAPEL · BANCO · TENER      | Usar objeto concreto |
| 5      | ¿Conoce el nombre de la persona?  | NOMBRE_PERSONA    | ÉL/ELLA · NOMBRE · CONOCER           | Directo              |
| 6      | ¿Tiene su número de celular?      | CONTACTO_PERSONA  | ÉL/ELLA · CELULAR · NÚM(...) · TENER | Directo              |
| 7      | ¿Se comunicaron por internet?     | CONTACTO_INTERNET | INTERNET · ESCRIBIR                  | Directo              |
| 8      | ¿Conserva toda la conversación?   | CONSERVAR_CHAT    | ESCRIBIR · TOTAL · GUARDAR           | Directo              |

## Testigos, fotos, video y otros elementos

| **\#** | **Pregunta en español**               | **Intención**       | **Conceptos LSB objetivo**             | **Estado/nota**          |
|--------|---------------------------------------|---------------------|----------------------------------------|--------------------------|
| 1      | ¿Hay algún testigo?                   | TESTIGO_EXISTE      | TESTIGO · TENER                        | Directo D2024            |
| 2      | ¿Cuántos testigos hay?                | TESTIGO_CANTIDAD    | TESTIGO · ¿CUÁNTOS?                    | Directo D2024            |
| 3      | ¿El testigo vio todo?                 | TESTIGO_VIO         | TESTIGO · TOTAL · VER                  | Directo                  |
| 4      | ¿Puede traer al testigo?              | TESTIGO_TRAER       | TESTIGO · TRAER · PUEDO                | Directo                  |
| 5      | ¿Tiene fotografías?                   | FOTOS               | FOTOS · TENER                          | Directo                  |
| 6      | ¿Tiene video?                         | VIDEO               | VIDEO · TENER                          | Directo                  |
| 7      | ¿Puede mostrarlo ahora?               | MOSTRAR             | AHORA · MOSTRAR · PUEDO                | Directo                  |
| 8      | ¿Tiene un certificado?                | CERTIFICADO         | CERTIFICADO · TENER                    | Directo                  |
| 9      | ¿Tiene una resolución o papel previo? | RESOLUCION          | RESOLUCIÓN / PAPEL · TENER             | RESOLUCIÓN directo D2024 |
| 10     | ¿Desea presentar estos elementos?     | PRESENTAR_ELEMENTOS | PRESENTAR · FOTOS/VIDEO/PAPEL · QUERER | PRESENTAR directo D2024  |

## Seguimiento preliminar y orientación

| **\#** | **Pregunta en español**                  | **Intención**     | **Conceptos LSB objetivo**               | **Estado/nota**                                        |
|--------|------------------------------------------|-------------------|------------------------------------------|--------------------------------------------------------|
| 1      | ¿Vino a consultar el estado de su caso?  | CONSULTA_ESTADO   | INVESTIGACIÓN · BUSCAR · VENIR           | No usar “caso” como seña si no está validada           |
| 2      | ¿Tiene el número de referencia?          | NUMERO_REFERENCIA | NÚM(...) · TENER                         | Directo                                                |
| 3      | ¿Cuándo presentó la denuncia?            | FECHA_DENUNCIA    | \[DENUNCIA\] · ¿CUÁNDO?                  | Concepto DENUNCIA pendiente                            |
| 4      | ¿Quiere hablar con el policía encargado? | HABLAR_POLICIA    | POLICÍA · HABLAR · QUERER                | Directo                                                |
| 5      | ¿Necesita hablar con un abogado?         | HABLAR_ABOGADO    | ABOGADO · HABLAR · NECESITAR             | Directo                                                |
| 6      | ¿Necesita defensa pública gratuita?      | SEPDEP            | ABOGADO · GRATIS · d(SEPDEP) · NECESITAR | Institución por dactilología                           |
| 7      | ¿Necesita saber dónde está la Fiscalía?  | FISCALIA          | d(FISCALÍA) · ¿DÓNDE?                    | Dactilología; no usar falso amigo FISCAL               |
| 8      | ¿Recibió un papel de convocatoria?       | CITACION          | PAPEL · CONVOCAR · RECIBIR               | Composición establecida en corpus; validar naturalidad |
| 9      | ¿Tiene que volver otro día?              | RETORNO           | VOLVER · DÍA · NECESITAR                 | Directo                                                |
| 10     | ¿Prefiere que le avisemos por escrito?   | AVISO_ESCRITO     | AVISAR · ESCRIBIR · ENVIAR · MEJOR       | Directo                                                |

## Interacción con fiscal/juez en el límite del alcance

| **\#** | **Pregunta en español**                            | **Intención**       | **Conceptos LSB objetivo**                | **Estado/nota**                                          |
|--------|----------------------------------------------------|---------------------|-------------------------------------------|----------------------------------------------------------|
| 1      | ¿Necesita hablar con el fiscal?                    | HABLAR_FISCAL       | d(FISCAL) · HABLAR · NECESITAR            | Dactilología; NO usar FISCAL escolar                     |
| 2      | ¿Le indicaron ir a la Fiscalía?                    | DERIVACION_FISCALIA | d(FISCALÍA) · IR                          | Dactilología                                             |
| 3      | ¿Recibió una resolución?                           | RECIBIR_RESOLUCION  | RESOLUCIÓN · RECIBIR                      | Directo D2024                                            |
| 4      | ¿Debe presentarse ante un juez?                    | JUEZ                | JUEZ · PRESENTAR                          | JUEZ M3 + PRESENTAR D2024                                |
| 5      | ¿Sabe dónde está el Órgano Judicial?               | ORGANO_JUDICIAL     | ÓRGANO-JUDICIAL · ¿DÓNDE?                 | Directo D2024                                            |
| 6      | ¿Necesita intérprete para esa reunión?             | INTERPRETE_REUNION  | INTÉRPRETE · REUNIÓN · NECESITAR          | Directo; reunión no equivale automáticamente a audiencia |
| 7      | ¿Quiere leer el papel antes de escribir su nombre? | LECTURA_ANTES_FIRMA | PAPEL · LEER · NOMBRE · ESCRIBIR · QUERER | Firma como composición provisional                       |
| 8      | ¿Está de acuerdo con lo escrito?                   | CONFORMIDAD         | ESTAR-DE-ACUERDO · ESCRIBIR               | Directo                                                  |

# 7. Banco ampliado de preguntas del ciudadano sordo

## Acceso y comunicación

| **\#** | **Pregunta del ciudadano**            | **Conceptos/glosas objetivo**                |
|--------|---------------------------------------|----------------------------------------------|
| 1      | ¿Aquí hay intérprete de LSB?          | INTÉRPRETE · AQUÍ · TENER                    |
| 2      | ¿Puede escribir lo que me pregunta?   | TÚ · ESCRIBIR · PUEDO                        |
| 3      | ¿Puede hablar más despacio?           | TÚ · LENTO · HABLAR · PUEDO                  |
| 4      | ¿Puede mostrarme otra vez?            | VOLVER · MOSTRAR · PUEDO                     |
| 5      | ¿Puedo leer primero?                  | YO · LEER · PRIMERA-VEZ · PUEDO              |
| 6      | ¿Me entiende?                         | TÚ · YO · COMPRENDER                         |
| 7      | ¿Puedo venir con mi intérprete?       | INTÉRPRETE · ACOMPAÑAR · VENIR · PUEDO       |
| 8      | ¿Pueden avisarme por mensaje escrito? | AVISAR · CELULAR · ESCRIBIR · ENVIAR · PUEDO |

## Denuncia y relato

| **\#** | **Pregunta del ciudadano**                       | **Conceptos/glosas objetivo**            |
|--------|--------------------------------------------------|------------------------------------------|
| 1      | ¿Puedo presentar mi denuncia aquí?               | PRESENTAR · \[DENUNCIA\] · AQUÍ · PUEDO  |
| 2      | ¿Quién va a recibir mi denuncia?                 | ¿QUIÉN? · RECIBIR · \[DENUNCIA\]         |
| 3      | ¿Tengo que contar todo ahora?                    | YO · TOTAL · NARRAR · AHORA · NECESITAR  |
| 4      | ¿Puedo explicar despacio?                        | YO · LENTO · EXPLICAR · PUEDO            |
| 5      | ¿Puedo agregar información después?              | AUMENTAR · NARRAR · DESPUÉS · PUEDO      |
| 6      | ¿Puedo corregir algo si está mal escrito?        | MAL · ESCRIBIR · ARREGLAR · PUEDO        |
| 7      | ¿Puedo leer lo escrito antes de poner mi nombre? | PAPEL · LEER · NOMBRE · ESCRIBIR · PUEDO |
| 8      | ¿Me dan una copia?                               | FOTOCOPIA · YO · RECIBIR                 |

## Robo y objetos

| **\#** | **Pregunta del ciudadano**           | **Conceptos/glosas objetivo**             |
|--------|--------------------------------------|-------------------------------------------|
| 1      | ¿Pueden buscar mi celular?           | MÍO · CELULAR · BUSCAR · PUEDO            |
| 2      | ¿Traigo la factura del celular?      | CELULAR · FACTURA · TRAER · NECESITAR     |
| 3      | ¿Traigo la caja del celular?         | CELULAR · CAJA · TRAER · NECESITAR        |
| 4      | ¿Dónde entrego las fotos?            | FOTOS · YO · ¿DÓNDE? · DAR                |
| 5      | ¿Puedo traer el video mañana?        | VIDEO · MAÑANA · TRAER · PUEDO            |
| 6      | ¿Puedo agregar otro objeto robado?   | ROBAR · OBJETO · AUMENTAR · PUEDO         |
| 7      | ¿Me avisan si encuentran mi celular? | CELULAR · BUSCAR · TERMINAR · YO · AVISAR |
| 8      | ¿La investigación continúa?          | INVESTIGACIÓN · CONTINUAR                 |

## Violencia, amenazas y asistencia

| **\#** | **Pregunta del ciudadano**               | **Conceptos/glosas objetivo**                      |
|--------|------------------------------------------|----------------------------------------------------|
| 1      | ¿Puedo pedir ayuda ahora?                | AYUDAR · AHORA · PEDIR · PUEDO                     |
| 2      | ¿Pueden ayudarme a estar protegido?      | YO · PROTEGER · AYUDAR · PUEDO                     |
| 3      | ¿Necesito ir al hospital?                | HOSPITAL · IR · NECESITAR                          |
| 4      | ¿Necesito certificado del doctor?        | DOCTOR · CERTIFICADO · NECESITAR                   |
| 5      | ¿Dónde entrego el certificado?           | CERTIFICADO · ¿DÓNDE? · DAR                        |
| 6      | ¿Qué hago si vuelve a amenazarme?        | ÉL · VOLVER · AMENAZAR /cond/ · YO · ¿QUÉ? · HACER |
| 7      | ¿Puedo mostrar los mensajes del celular? | CELULAR · ESCRIBIR · MOSTRAR · PUEDO               |
| 8      | ¿SEPDAVI puede ayudarme?                 | d(SEPDAVI) · YO · AYUDAR · PUEDO                   |

## Testigos y evidencia concreta

| **\#** | **Pregunta del ciudadano**                | **Conceptos/glosas objetivo**             |
|--------|-------------------------------------------|-------------------------------------------|
| 1      | ¿Puedo traer al testigo mañana?           | TESTIGO · MAÑANA · TRAER · PUEDO          |
| 2      | ¿El testigo necesita su carnet?           | TESTIGO · PAPEL · IDENTIDAD · NECESITAR   |
| 3      | ¿Puedo enviar las fotos?                  | FOTOS · ENVIAR · PUEDO                    |
| 4      | ¿Puedo mostrar el video desde mi celular? | VIDEO · CELULAR · MOSTRAR · PUEDO         |
| 5      | ¿Necesito fotocopias?                     | FOTOCOPIA · NECESITAR                     |
| 6      | ¿Me dan un papel con sello?               | PAPEL · SELLO · YO · RECIBIR              |
| 7      | ¿Puedo presentar un certificado después?  | PRESENTAR · CERTIFICADO · DESPUÉS · PUEDO |
| 8      | ¿Qué más tengo que traer?                 | TRAER · ¿QUÉ? · AÚN · NECESITAR           |

## Consulta y seguimiento

| **\#** | **Pregunta del ciudadano**              | **Conceptos/glosas objetivo**              |
|--------|-----------------------------------------|--------------------------------------------|
| 1      | ¿Quién investiga mi denuncia?           | ¿QUIÉN? · INVESTIGACIÓN · \[DENUNCIA\]     |
| 2      | ¿Puedo hablar con el policía encargado? | POLICÍA · HABLAR · PUEDO                   |
| 3      | ¿Cuándo vuelvo?                         | YO · ¿CUÁNDO? · VOLVER                     |
| 4      | ¿Cuánto tiempo debo esperar?            | YO · ESPERAR · HORA/DÍA · ¿CUÁNTOS?        |
| 5      | ¿Me van a avisar?                       | ELLOS · YO · AVISAR                        |
| 6      | ¿Pueden escribirme al celular?          | CELULAR · ESCRIBIR · ENVIAR · PUEDO        |
| 7      | ¿La investigación ya terminó?           | INVESTIGACIÓN · TERMINAR                   |
| 8      | ¿Encontraron a la persona?              | ÉL/ELLA · BUSCAR · TERMINAR                |
| 9      | ¿Puedo cambiar mi dirección?            | MÍO · DIRECCIÓN · CAMBIAR · PUEDO          |
| 10     | ¿Puedo cambiar mi número de celular?    | MÍO · CELULAR · NÚM(...) · CAMBIAR · PUEDO |

## Fiscalía, asistencia y defensa

| **\#** | **Pregunta del ciudadano**                    | **Conceptos/glosas objetivo**    |
|--------|-----------------------------------------------|----------------------------------|
| 1      | ¿Dónde está la Fiscalía?                      | d(FISCALÍA) · ¿DÓNDE?            |
| 2      | ¿Tengo que ir a la Fiscalía?                  | d(FISCALÍA) · IR · NECESITAR     |
| 3      | ¿Puedo hablar con el fiscal?                  | d(FISCAL) · HABLAR · PUEDO       |
| 4      | ¿Necesito abogado?                            | ABOGADO · NECESITAR              |
| 5      | ¿Hay abogado gratis?                          | ABOGADO · GRATIS · TENER         |
| 6      | ¿SEPDEP puede darme defensa gratuita?         | d(SEPDEP) · ABOGADO · GRATIS     |
| 7      | ¿SEPDAVI puede orientarme?                    | d(SEPDAVI) · ASISTENCIA · AYUDAR |
| 8      | ¿Dónde está el Órgano Judicial?               | ÓRGANO-JUDICIAL · ¿DÓNDE?        |
| 9      | ¿Tengo que presentarme ante un juez?          | JUEZ · PRESENTAR · NECESITAR     |
| 10     | ¿Necesito intérprete para hablar con el juez? | JUEZ · INTÉRPRETE · NECESITAR    |

# 8. Declaraciones y respuestas frecuentes del ciudadano sordo

| **\#** | **Declaración/respuesta**                       | **Conceptos/glosas objetivo**              |
|--------|-------------------------------------------------|--------------------------------------------|
| 1      | Soy sordo y necesito intérprete.                | YO · SORDO · INTÉRPRETE · NECESITAR        |
| 2      | Leo poco; prefiero LSB.                         | YO · LEER · POCO · LSB/INTÉRPRETE · MEJOR  |
| 3      | Quiero presentar una denuncia.                  | PRESENTAR · \[DENUNCIA\] · QUERER          |
| 4      | Quiero explicar lo que pasó desde el principio. | NARRAR · EMPEZAR · QUERER                  |
| 5      | Ayer por la tarde ocurrió.                      | AYER · TARDE                               |
| 6      | No recuerdo la hora exacta.                     | HORA · RECORDAR /neg/                      |
| 7      | Ocurrió en la calle cerca del mercado.          | CALLE · MERCADO · CERCA                    |
| 8      | No conozco a la persona.                        | ÉL/ELLA · CONOCER /neg/                    |
| 9      | Si la vuelvo a ver, puedo identificarla.        | VOLVER · VER /cond/ · IDENTIFICAR · PUEDO  |
| 10     | Vi a un hombre joven con mochila.               | HOMBRE · JOVEN · MOCHILA · VER             |
| 11     | Me robaron el celular.                          | ROBAR · MÍO · CELULAR                      |
| 12     | También perdí mi carnet.                        | PAPEL · IDENTIDAD · PERDER                 |
| 13     | Tengo la factura del celular.                   | CELULAR · FACTURA · TENER                  |
| 14     | Hay un testigo.                                 | TESTIGO · TENER                            |
| 15     | El testigo vio todo.                            | TESTIGO · TOTAL · VER                      |
| 16     | Tengo fotos en mi celular.                      | FOTOS · CELULAR · TENER                    |
| 17     | Tengo un video.                                 | VIDEO · TENER                              |
| 18     | Un hombre me pegó.                              | HOMBRE · YO · PEGAR                        |
| 19     | Tengo una herida en el brazo.                   | BRAZO · HERIDA · TENER                     |
| 20     | Fui al hospital.                                | HOSPITAL · IR                              |
| 21     | Tengo certificado del doctor.                   | DOCTOR · CERTIFICADO · TENER               |
| 22     | Mi expareja me amenaza.                         | PAREJA · PASADO · ÉL/ELLA · YO · AMENAZAR  |
| 23     | Tengo miedo de volver a mi casa.                | MIEDO · CASA · VOLVER                      |
| 24     | Necesito auxilio ahora.                         | AUXILIO · AHORA · NECESITAR                |
| 25     | Guardé todos los mensajes.                      | ESCRIBIR · TOTAL · GUARDAR                 |
| 26     | Tengo fotos de la pantalla.                     | FOTOS · CELULAR · TENER                    |
| 27     | Me engañaron con dinero.                        | ENGAÑAR · DINERO/BILLETES                  |
| 28     | Envié dinero por el banco.                      | BANCO · BILLETES · ENVIAR                  |
| 29     | Tengo el papel del banco.                       | PAPEL · BANCO · TENER                      |
| 30     | Dañaron la puerta de mi tienda.                 | TIENDA · PUERTA · DAÑAR                    |
| 31     | Tengo el video de la cámara.                    | VIDEO · FILMAR · TENER                     |
| 32     | Vi lo ocurrido y puedo dar testimonio.          | OBSERVAR · TESTIMONIO · PUEDO              |
| 33     | Quiero agregar información.                     | AUMENTAR · NARRAR · QUERER                 |
| 34     | Aquí hay un error en mi nombre.                 | AQUÍ · NOMBRE · MAL                        |
| 35     | Quiero leer antes de escribir mi nombre.        | LEER · NOMBRE · ESCRIBIR · QUERER          |
| 36     | Prefiero recibir mensajes escritos.             | ESCRIBIR · ENVIAR · MEJOR                  |
| 37     | Cambié de dirección.                            | DIRECCIÓN · CAMBIAR                        |
| 38     | Cambié de número de celular.                    | CELULAR · NÚM(...) · CAMBIAR               |
| 39     | Quiero saber si la investigación continúa.      | INVESTIGACIÓN · CONTINUAR · SABER · QUERER |
| 40     | Necesito un abogado.                            | ABOGADO · NECESITAR                        |
| 41     | No tengo dinero para un abogado.                | ABOGADO · BILLETES · TENER /neg/           |
| 42     | Quiero asistencia de SEPDAVI.                   | ASISTENCIA · d(SEPDAVI) · QUERER           |
| 43     | Necesito defensa pública.                       | d(SEPDEP) · ABOGADO · NECESITAR            |
| 44     | Me dijeron que debo ir a la Fiscalía.           | d(FISCALÍA) · IR · NECESITAR               |
| 45     | Recibí una resolución.                          | RESOLUCIÓN · RECIBIR                       |
| 46     | Tengo que presentarme ante un juez.             | JUEZ · PRESENTAR · NECESITAR               |
| 47     | Necesito intérprete para hablar con el juez.    | JUEZ · INTÉRPRETE · NECESITAR              |
| 48     | No entiendo este papel.                         | PAPEL · COMPRENDER /neg/                   |
| 49     | Explíqueme despacio, por favor.                 | LENTO · EXPLICAR · POR-FAVOR               |
| 50     | Ahora sí entiendo.                              | AHORA · COMPRENDER                         |
| 51     | Gracias por su ayuda.                           | AYUDAR · GRACIAS                           |

# 9. Escenarios funcionales cubiertos

| **Escenario**                        | **Actor que inicia**    | **Objetivo de prueba**                                                                                  |
|--------------------------------------|-------------------------|---------------------------------------------------------------------------------------------------------|
| Acceso comunicativo                  | Ciudadano o funcionario | Detectar sordera, intérprete, canal escrito, reparación comunicativa.                                   |
| Recepción de denuncia                | Ambos                   | Capturar intención de denunciar y abrir relato sin depender de la palabra “denuncia” como seña directa. |
| Robo/hurto                           | Ciudadano               | Objeto, tiempo, lugar, autor, testigo, fotos/video, propiedad.                                          |
| Agresión/violencia                   | Ciudadano               | Relato no gráfico, necesidad médica, riesgo, protección y asistencia.                                   |
| Amenazas por celular/internet        | Ciudadano               | Emisor, mensajes, fechas, conservación de contenido y continuidad.                                      |
| Engaño con dinero                    | Ciudadano               | Monto, banco, conversación, identidad y documentos concretos.                                           |
| Daño a propiedad                     | Ciudadano               | Objeto dañado, momento, video/fotos y costo/constancia.                                                 |
| Testigo                              | Ciudadano               | Lo observado, identificación, tiempo/lugar y testimonio.                                                |
| Entrega de elementos                 | Ambos                   | Fotos, video, certificados, facturas, fotocopias, resolución.                                           |
| Seguimiento de investigación         | Ciudadano               | Estado, responsable, retorno, avisos y actualización de contacto.                                       |
| Derivación a Fiscalía/SEPDAVI/SEPDEP | Funcionario             | Nombre institucional mediante dactilología y vocabulario de asistencia/defensa.                         |
| Interacción limítrofe con juez       | Ambos                   | Resolución, juez, intérprete y comprensión del papel sin entrar al juicio oral.                         |

**Cobertura conversacional nueva:** 98 preguntas de funcionario + 60 preguntas del ciudadano + 51 declaraciones/respuestas del ciudadano, además de los bancos aportados en v2/v3.

# 10. Protocolo de validación lingüística antes de animar

- Validar primero los conceptos críticos: DENUNCIA, FISCAL, FISCALÍA, JUZGADO, VÍCTIMA, IMPUTADO, FIRMA, ACTA y AUDIENCIA.

- Mostrar la seña o composición sin el texto en español y pedir al participante que diga qué entendió. Si no recupera el concepto, la representación no se aprueba.

- Validar naturalidad de las secuencias completas; no asumir que un orden OSV fijo sirve para todas las frases.

- Registrar variante Cochabamba cuando difiera del material nacional.

- Para el avatar, guardar parámetros manuales y no manuales: configuración, orientación, ubicación, movimiento, dirección, expresión facial y postura.

- Versionar el léxico. Ejemplo: gloss_id estable + source + validation_status + validator_role + date + asset_version.

- Una composición provisional nunca debe convertirse automáticamente en una “seña nueva” del diccionario sin validación explícita.

# 11. Esquema de datos recomendado para el diccionario maestro

{  
"concept_id": "ROBAR",  
"canonical_gloss": "ROBAR",  
"representation_type": "direct_sign",  
"source": {"type": "D2024", "entry": 499, "page": 190},  
"aliases_es": \["robar", "sustraer", "quitar", "me robaron"\],  
"citizen_input_enabled": true,  
"avatar_asset": "robar.glb",  
"validation_status": "documented_needs_regional_validation"  
}

# 12. Diccionario maestro: unión auditada de los dos corpus + incorporaciones 2024

Este apéndice conserva la unión de las entradas v2/v3 para no perder trabajo previo. “A+” indica que la entrada fue además contrastada explícitamente durante esta auditoría con fuentes oficiales en línea; “A” indica trazabilidad M1–M4 declarada de forma consistente en los corpus; “B” corresponde a incorporaciones directas del Diccionario 2024.

| **Glosa**           | **Español/Fuente léxica** | **ID**     | **Referencia**                                       | **Usos máx.** | **Prior.** | **Auditoría**     |
|---------------------|---------------------------|------------|------------------------------------------------------|---------------|------------|-------------------|
| YO                  | Yo                        | M1-T14-01  | M1 · Pronombres · p.113                              | 193           | P1         | A — M1–M4 trazado |
| ÉL                  | Él                        | M1-T14-04  | M1 · Pronombres · p.113                              | 62            | P1         | A — M1–M4 trazado |
| TÚ                  | Tú                        | M1-T14-02  | M1 · Pronombres · p.113                              | 57            | P1         | A — M1–M4 trazado |
| SÍ                  | Sí                        | M1-T01-16  | M1 · Saludos · p.55                                  | 49            | P1         | A — M1–M4 trazado |
| ESCRIBIR            | Escribir                  | M1-T12-15  | M1 · Verbos · p.101                                  | 47            | P1         | A — M1–M4 trazado |
| PAPEL               | Papel                     | M1-T13-17  | M1 · Sustantivos · p.107                             | 34            | P1         | A — M1–M4 trazado |
| CELULAR             | Celular                   | M2-T07-11  | M2 · Sustantivo II · p.61                            | 31            | P1         | A — M1–M4 trazado |
| NECESITAR           | Necesitar                 | M2-T02-06  | M2 · Verbos II · p.41                                | 30            | P1         | A — M1–M4 trazado |
| QUERER              | Querer                    | M1-T12-11  | M1 · Verbos · p.101                                  | 25            | P1         | A — M1–M4 trazado |
| PUEDO               | Puedo                     | M1-T01-11  | M1 · Saludos · p.55                                  | 24            | P1         | A — M1–M4 trazado |
| VOLVER              | Volver                    | M2-T02-13  | M2 · Verbos II · p.41                                | 24            | P1         | A — M1–M4 trazado |
| FOTOS               | Fotos                     | M3-T15-13  | M3 · Cumpleaños · p.117                              | 19            | P1         | A — M1–M4 trazado |
| INTÉRPRETE          | Intérprete                | M4-T11-06  | M4 · General II · p.99                               | 19            | P1         | A+ — contrastado  |
| DAR                 | Dar                       | M2-T02-27  | M2 · Verbos II · p.41                                | 18            | P1         | A — M1–M4 trazado |
| NOMBRE              | Nombre                    | M1-T01-15  | M1 · Saludos · p.55                                  | 18            | P1         | A — M1–M4 trazado |
| CASA                | Casa                      | M1-T05-01  | M1 · Lugares · p.71                                  | 17            | P1         | A — M1–M4 trazado |
| VER                 | Ver                       | M1-T12-16  | M1 · Verbos · p.101                                  | 17            | P1         | A — M1–M4 trazado |
| CUÁNDO              | ¿Cuándo?                  | M1-T11-09  | M1 · Preguntas · p.97                                | 16            | P1         | A — M1–M4 trazado |
| QUÉ                 | ¿Qué?                     | M1-T11-05  | M1 · Preguntas · p.97                                | 16            | P1         | A — M1–M4 trazado |
| TRAER               | Traer                     | M3-T12-03  | M3 · Opuestos II · p.101                             | 15            | P1         | A — M1–M4 trazado |
| HORA                | Hora                      | M3-T17-03  | M3 · Tiempo III · p.129                              | 14            | P1         | A — M1–M4 trazado |
| QUEJAR              | Quejar                    | M4-T10-04  | M4 · Política II · p.89                              | 14            | P1         | A+ — contrastado  |
| BILLETES            | Billetes                  | M4-T17-13  | M4 · Escuela II · p.129                              | 13            | P1         | A — M1–M4 trazado |
| CUÁL                | ¿Cuál?                    | M1-T11-06  | M1 · Preguntas · p.97                                | 13            | P1         | A — M1–M4 trazado |
| CUÁNTOS             | ¿Cuántos?                 | M1-T11-08  | M1 · Preguntas · p.97                                | 12            | P1         | A — M1–M4 trazado |
| ENVIAR              | Enviar                    | M4-T04-24  | M4 · Opuestos II · p.51                              | 11            | P1         | A — M1–M4 trazado |
| MAÑANA              | Mañana                    | M1-T15-09  | M1 · Tiempo · p.117                                  | 11            | P1         | A — M1–M4 trazado |
| QUIÉN               | ¿Quién?                   | M1-T11-01  | M1 · Preguntas · p.97                                | 11            | P1         | A — M1–M4 trazado |
| ESPERAR             | Esperar                   | M2-T02-19  | M2 · Verbos II · p.41                                | 10            | P1         | A — M1–M4 trazado |
| GUARDAR             | Guardar                   | M4-T02-14  | M4 · Verbos IV · p.39                                | 10            | P1         | A — M1–M4 trazado |
| HOMBRE              | Hombre                    | M1-T02-01  | M1 · Familia · p.59                                  | 10            | P1         | A — M1–M4 trazado |
| NO                  | No                        | M1-T01-17  | M1 · Saludos · p.55                                  | 10            | P1         | A — M1–M4 trazado |
| DÓNDE               | ¿Dónde?                   | M1-T11-02  | M1 · Preguntas · p.97                                | 9             | P1         | A — M1–M4 trazado |
| EXPLICAR            | Explicar                  | M4-T02-12  | M4 · Verbos IV · p.39                                | 9             | P1         | A — M1–M4 trazado |
| IDENTIDAD           | Identidad                 | M4-T09-17  | M4 · Diálogo II · p.83                               | 9             | P1         | A — M1–M4 trazado |
| MOSTRAR             | Mostrar                   | M3-T15-10  | M3 · Cumpleaños · p.117                              | 9             | P1         | A — M1–M4 trazado |
| SABER               | Saber                     | M3-T04-05  | M3 · Verbos III · p.55                               | 9             | P1         | A — M1–M4 trazado |
| ABOGADO             | Abogado                   | M2-T10-10  | M2 · Trabajo · p.79                                  | 8             | P1         | A+ — contrastado  |
| AYER                | Ayer                      | M1-T15-05  | M1 · Tiempo · p.117                                  | 8             | P1         | A — M1–M4 trazado |
| FECHA               | Fecha                     | M1-T15-11  | M1 · Tiempo · p.117                                  | 8             | P1         | A — M1–M4 trazado |
| NO-PUEDO            | No puedo                  | M1-T01-12  | M1 · Saludos · p.55                                  | 8             | P1         | A — M1–M4 trazado |
| COMPRENDER          | Comprender                | M1-T12-24  | M1 · Verbos · p.101                                  | 7             | P1         | A — M1–M4 trazado |
| ELLA                | Ella                      | M1-T14-06  | M1 · Pronombres · p.113                              | 7             | P1         | A — M1–M4 trazado |
| GRACIAS             | Gracias                   | M1-T01-06  | M1 · Saludos · p.55                                  | 7             | P1         | A — M1–M4 trazado |
| JUEZ                | Juez                      | M3-T02-21  | M3 · Política I · p.43                               | 7             | P1         | A+ — contrastado  |
| LEER                | Leer                      | M2-T02-29  | M2 · Verbos II · p.41                                | 7             | P1         | A — M1–M4 trazado |
| MUJER               | Mujer                     | M1-T02-02  | M1 · Familia · p.59                                  | 7             | P1         | A — M1–M4 trazado |
| OFICINA             | Oficina                   | M3-T16-23  | M3 · Lugares II · p.123                              | 7             | P1         | A — M1–M4 trazado |
| RECIBIR             | Recibir                   | M4-T04-23  | M4 · Opuestos II · p.51                              | 7             | P1         | A — M1–M4 trazado |
| RECORDAR            | Recordar                  | M2-T02-04  | M2 · Verbos II · p.41                                | 7             | P1         | A — M1–M4 trazado |
| VIDEO               | Video                     | M3-T15-09  | M3 · Cumpleaños · p.117                              | 7             | P1         | A — M1–M4 trazado |
| AYUDAR              | Ayudar                    | M1-T12-23  | M1 · Verbos · p.101                                  | 6             | P1         | A — M1–M4 trazado |
| DAÑAR               | Dañar                     | M4-T11-09  | M4 · General II · p.99                               | 6             | P1         | A+ — contrastado  |
| HOY                 | Hoy                       | M1-T15-07  | M1 · Tiempo · p.117                                  | 6             | P1         | A — M1–M4 trazado |
| LENTO               | Lento                     | M2-T01-06  | M2 · Opuestos · p.33                                 | 6             | P1         | A — M1–M4 trazado |
| NO-SABER            | No saber                  | M3-T04-06  | M3 · Verbos III · p.55                               | 6             | P1         | A — M1–M4 trazado |
| CERTIFICADO         | Certificado               | M4-T17-10  | M4 · Escuela II · p.129                              | 5             | P1         | A — M1–M4 trazado |
| FACTURA             | Factura                   | M3-T14-09  | M3 · General I · p.111                               | 5             | P1         | A — M1–M4 trazado |
| MIEDO               | Miedo                     | M3-T12-05  | M3 · Opuestos II · p.101                             | 5             | P1         | A — M1–M4 trazado |
| PEGAR               | Pegar                     | M3-T14-08  | M3 · General I · p.111                               | 5             | P1         | A — M1–M4 trazado |
| POR-FAVOR           | Por favor                 | M1-T01-08  | M1 · Saludos · p.55                                  | 5             | P1         | A — M1–M4 trazado |
| AMENAZAR            | Amenazar                  | M3-T04-04  | M3 · Verbos III · p.55                               | 4             | P1         | A — M1–M4 trazado |
| AVENIDA             | Avenida                   | M3-T16-04  | M3 · Lugares II · p.123                              | 4             | P1         | A — M1–M4 trazado |
| CALLE               | Calle                     | M3-T16-02  | M3 · Lugares II · p.123                              | 4             | P1         | A — M1–M4 trazado |
| AUTORIDAD           | Autoridad                 | M4-T10-46  | M4 · Política II · p.89                              | 3             | P1         | A+ — contrastado  |
| CÓMO                | ¿Cómo?                    | M1-T11-03  | M1 · Preguntas · p.97                                | 3             | P1         | A — M1–M4 trazado |
| ENGAÑAR             | Engañar                   | M4-T09-22  | M4 · Diálogo II · p.83                               | 3             | P1         | A — M1–M4 trazado |
| HERIDA              | Herida                    | M3-T03-22  | M3 · Salud · p.49                                    | 3             | P1         | A — M1–M4 trazado |
| INVESTIGACIÓN       | Investigación             | M3-T02-22  | M3 · Política I · p.43                               | 3             | P1         | A+ — contrastado  |
| PROTEGER            | Proteger                  | M3-T04-13  | M3 · Verbos III · p.55                               | 3             | P1         | A — M1–M4 trazado |
| JUSTICIA            | Justicia                  | M3-T02-20  | M3 · Política I · p.43                               | 2             | P1         | A+ — contrastado  |
| POLICÍA             | Policía                   | M2-T10-11  | M2 · Trabajo · p.79                                  | 2             | P1         | A+ — contrastado  |
| HOSPITAL            | Hospital                  | M1-T05-07  | M1 · Lugares · p.71                                  | 1             | P1         | A — M1–M4 trazado |
| ASISTENCIA          | Asistencia                | D2024-p23  | II Diccionario Bilingüe LSB-Castellano (2024), p.23  | 0             | P1         | B — directo D2024 |
| AUXILIO             | Auxilio                   | D2024-p26  | II Diccionario Bilingüe LSB-Castellano (2024), p.26  | 0             | P1         | B — directo D2024 |
| LADRÓN              | Ladrón/a                  | D2024-326  | II Diccionario Bilingüe LSB-Castellano (2024), p.125 | 0             | P1         | B — directo D2024 |
| NARRAR              | Narrar                    | D2024-p150 | II Diccionario Bilingüe LSB-Castellano (2024), p.150 | 0             | P1         | B — directo D2024 |
| OBSERVAR            | Observar                  | D2024-p155 | II Diccionario Bilingüe LSB-Castellano (2024), p.155 | 0             | P1         | B — directo D2024 |
| PRESENTAR           | Presentar                 | D2024-471  | II Diccionario Bilingüe LSB-Castellano (2024), p.178 | 0             | P1         | B — directo D2024 |
| RESOLUCIÓN          | Resolución                | D2024-p188 | II Diccionario Bilingüe LSB-Castellano (2024), p.188 | 0             | P1         | B — directo D2024 |
| ROBAR               | Robar                     | D2024-499  | II Diccionario Bilingüe LSB-Castellano (2024), p.190 | 0             | P1         | B — directo D2024 |
| TESTIGO             | Testigo                   | D2024-557  | II Diccionario Bilingüe LSB-Castellano (2024), p.212 | 0             | P1         | B — directo D2024 |
| TESTIMONIO          | Testimonio                | D2024-558  | II Diccionario Bilingüe LSB-Castellano (2024), p.212 | 0             | P1         | B — directo D2024 |
| TRÁMITE             | Trámite                   | D2024-p216 | II Diccionario Bilingüe LSB-Castellano (2024), p.216 | 0             | P1         | B — directo D2024 |
| VIOLENCIA           | Violencia                 | D2024-p228 | II Diccionario Bilingüe LSB-Castellano (2024), p.228 | 0             | P1         | B — directo D2024 |
| MÍO                 | Mío                       | M1-T14-12  | M1 · Pronombres · p.113                              | 79            | P2         | A — M1–M4 trazado |
| TENER               | Tener                     | M2-T02-01  | M2 · Verbos II · p.41                                | 34            | P2         | A — M1–M4 trazado |
| ELLOS               | Ellos                     | M1-T14-08  | M1 · Pronombres · p.113                              | 25            | P2         | A — M1–M4 trazado |
| TUYO                | Tuyo                      | M1-T14-11  | M1 · Pronombres · p.113                              | 22            | P2         | A — M1–M4 trazado |
| PASADO              | Pasado                    | M2-T05-06  | M2 · Tiempo II · p.53                                | 18            | P2         | A — M1–M4 trazado |
| DENTRO              | Dentro                    | M2-T20-03  | M2 · Adverbios de lugar · p.119                      | 17            | P2         | A — M1–M4 trazado |
| VENIR               | Venir                     | M1-T12-18  | M1 · Verbos · p.101                                  | 17            | P2         | A — M1–M4 trazado |
| AQUÍ                | Aquí                      | M2-T20-09  | M2 · Adverbios de lugar · p.119                      | 16            | P2         | A — M1–M4 trazado |
| CARPETA             | Carpeta                   | M3-T07-08  | M3 · Sustantivos III · p.73                          | 16            | P2         | A — M1–M4 trazado |
| AHORA               | Ahora                     | M1-T15-08  | M1 · Tiempo · p.117                                  | 14            | P2         | A — M1–M4 trazado |
| FOTOCOPIA           | Fotocopia                 | M3-T07-06  | M3 · Sustantivos III · p.73                          | 14            | P2         | A — M1–M4 trazado |
| AMBOS               | Ambos                     | M4-T17-07  | M4 · Escuela II · p.129                              | 12            | P2         | A — M1–M4 trazado |
| SEMANA              | Semana                    | M1-T15-03  | M1 · Tiempo · p.117                                  | 12            | P2         | A — M1–M4 trazado |
| TERMINAR            | Terminar                  | M2-T02-09  | M2 · Verbos II · p.41                                | 12            | P2         | A — M1–M4 trazado |
| TOTAL               | Total                     | M3-T08-23  | M3 · Escuela · p.77                                  | 12            | P2         | A — M1–M4 trazado |
| BUSCAR              | Buscar                    | M2-T02-15  | M2 · Verbos II · p.41                                | 11            | P2         | A — M1–M4 trazado |
| AÚN                 | Aún                       | M3-T01-16  | M3 · Diálogo · p.37                                  | 10            | P2         | A — M1–M4 trazado |
| SORDO               | Sordo                     | M3-T01-04  | M3 · Diálogo · p.37                                  | 10            | P2         | A — M1–M4 trazado |
| CERCA               | Cerca                     | M2-T01-14  | M2 · Opuestos · p.33                                 | 9             | P2         | A — M1–M4 trazado |
| HABLAR              | Hablar                    | M1-T12-08  | M1 · Verbos · p.101                                  | 9             | P2         | A — M1–M4 trazado |
| HACER               | Hacer                     | M3-T14-04  | M3 · General I · p.111                               | 9             | P2         | A — M1–M4 trazado |
| IR                  | Ir                        | M1-T12-19  | M1 · Verbos · p.101                                  | 9             | P2         | A — M1–M4 trazado |
| NOSOTROS            | Nosotros                  | M1-T14-03  | M1 · Pronombres · p.113                              | 9             | P2         | A — M1–M4 trazado |
| TARDE               | Tarde                     | M2-T05-02  | M2 · Tiempo II · p.53                                | 9             | P2         | A — M1–M4 trazado |
| DÍA                 | Día                       | M1-T15-02  | M1 · Tiempo · p.117                                  | 8             | P2         | A — M1–M4 trazado |
| TIENDA              | Tienda                    | M3-T16-17  | M3 · Lugares II · p.123                              | 8             | P2         | A — M1–M4 trazado |
| ACOMPAÑAR           | Acompañar                 | M3-T04-02  | M3 · Verbos III · p.55                               | 7             | P2         | A — M1–M4 trazado |
| ALLÍ                | Allí                      | M2-T20-10  | M2 · Adverbios de lugar · p.119                      | 7             | P2         | A — M1–M4 trazado |
| TEMPRANO            | Temprano                  | M2-T05-01  | M2 · Tiempo II · p.53                                | 7             | P2         | A — M1–M4 trazado |
| CONOCER             | Conocido                  | M3-T01-01  | M3 · Diálogo · p.37                                  | 6             | P2         | A — M1–M4 trazado |
| DESPUÉS             | Después                   | M2-T05-03  | M2 · Tiempo II · p.53                                | 6             | P2         | A — M1–M4 trazado |
| INTERNET            | Internet                  | M2-T07-12  | M2 · Sustantivo II · p.61                            | 6             | P2         | A — M1–M4 trazado |
| PEDIR               | Pedir                     | M1-T12-14  | M1 · Verbos · p.101                                  | 6             | P2         | A — M1–M4 trazado |
| VERDAD              | Verdad                    | M2-T01-25  | M2 · Opuestos · p.33                                 | 6             | P2         | A — M1–M4 trazado |
| AL-LADO             | El                        | M2-T20-06  | M2 · Adverbios de lugar · p.119                      | 5             | P2         | A — M1–M4 trazado |
| BANCO               | Banco                     | M3-T16-05  | M3 · Lugares II · p.123                              | 5             | P2         | A — M1–M4 trazado |
| BRAZO               | Brazo                     | M1-T03-05  | M1 · Cuerpo humano · p.63                            | 5             | P2         | A — M1–M4 trazado |
| HIJA                | Hija                      | M1-T02-11  | M1 · Familia · p.59                                  | 5             | P2         | A — M1–M4 trazado |
| JUEVES              | Jueves                    | M1-T17-04  | M1 · Días de la semana · p.127                       | 5             | P2         | A — M1–M4 trazado |
| LLEVAR              | Llevar                    | M3-T12-04  | M3 · Opuestos II · p.101                             | 5             | P2         | A — M1–M4 trazado |
| MUCHO               | Mucho                     | M2-T01-11  | M2 · Opuestos · p.33                                 | 5             | P2         | A — M1–M4 trazado |
| NEGRO               | Negro                     | M1-T07-08  | M1 · Colores · p.81                                  | 5             | P2         | A — M1–M4 trazado |
| NUEVO               | Nuevo                     | M4-T04-18  | M4 · Opuestos II · p.51                              | 5             | P2         | A — M1–M4 trazado |
| PERDER              | Perder                    | M4-T04-14  | M4 · Opuestos II · p.51                              | 5             | P2         | A — M1–M4 trazado |
| PRIMERA-VEZ         | Primera vez               | M3-T01-22  | M3 · Diálogo · p.37                                  | 5             | P2         | A — M1–M4 trazado |
| PÁGINA              | Página                    | M3-T08-04  | M3 · Escuela · p.77                                  | 5             | P2         | A — M1–M4 trazado |
| SELLO               | Sello                     | M3-T07-09  | M3 · Sustantivos III · p.73                          | 5             | P2         | A — M1–M4 trazado |
| ARREGLAR            | Arreglar                  | M4-T02-18  | M4 · Verbos IV · p.39                                | 4             | P3         | A — M1–M4 trazado |
| AUMENTAR            | Aumentar                  | M3-T12-15  | M3 · Opuestos II · p.101                             | 4             | P3         | A — M1–M4 trazado |
| AVISAR              | Avisar                    | M3-T04-03  | M3 · Verbos III · p.55                               | 4             | P3         | A — M1–M4 trazado |
| AZUL                | Azul                      | M1-T07-04  | M1 · Colores · p.81                                  | 4             | P3         | A — M1–M4 trazado |
| CAMBIAR             | Cambiar                   | M1-T12-01  | M1 · Verbos · p.101                                  | 4             | P3         | A — M1–M4 trazado |
| COMPUTADORA         | Computadora               | M2-T07-14  | M2 · Sustantivo II · p.61                            | 4             | P3         | A — M1–M4 trazado |
| CONTESTAR-DOS-VECES | Contestar dos veces       | M3-T01-11  | M3 · Diálogo · p.37                                  | 4             | P3         | A — M1–M4 trazado |
| DIRECCIÓN           | Dirección                 | M3-T16-03  | M3 · Lugares II · p.123                              | 4             | P3         | A — M1–M4 trazado |
| DOCTOR              | Doctor                    | M2-T10-13  | M2 · Trabajo · p.79                                  | 4             | P3         | A+ — contrastado  |
| ESTAR-DE-ACUERDO    | Estar de acuerdo          | M3-T02-25  | M3 · Política I · p.43                               | 4             | P3         | A — M1–M4 trazado |
| GRATIS              | Gratis                    | M4-T09-12  | M4 · Diálogo II · p.83                               | 4             | P3         | A — M1–M4 trazado |
| HERMANA             | Hermana                   | M1-T02-13  | M1 · Familia · p.59                                  | 4             | P3         | A — M1–M4 trazado |
| HERMANO             | Hermano                   | M1-T02-12  | M1 · Familia · p.59                                  | 4             | P3         | A — M1–M4 trazado |
| JAMÁS               | Jamás                     | M3-T17-14  | M3 · Tiempo III · p.129                              | 4             | P3         | A — M1–M4 trazado |
| MAL                 | Mal                       | M1-T01-13  | M1 · Saludos · p.55                                  | 4             | P3         | A — M1–M4 trazado |
| MEJOR               | Mejor                     | M4-T04-21  | M4 · Opuestos II · p.51                              | 4             | P3         | A — M1–M4 trazado |
| MERCADO             | Mercado                   | M1-T05-10  | M1 · Lugares · p.71                                  | 4             | P3         | A — M1–M4 trazado |
| MES                 | Mes                       | M1-T15-01  | M1 · Tiempo · p.117                                  | 4             | P3         | A — M1–M4 trazado |
| MOCHILA             | Mochila                   | M3-T07-02  | M3 · Sustantivos III · p.73                          | 4             | P3         | A — M1–M4 trazado |
| MÁS-O-MENOS         | Más o menos               | M1-T01-14  | M1 · Saludos · p.55                                  | 4             | P3         | A — M1–M4 trazado |
| OÍR                 | Oír                       | M2-T02-16  | M2 · Verbos II · p.41                                | 4             | P3         | A — M1–M4 trazado |
| POCO                | Poco                      | M2-T01-12  | M2 · Opuestos · p.33                                 | 4             | P3         | A — M1–M4 trazado |
| PUERTA              | Puerta                    | M1-T13-03  | M1 · Sustantivos · p.107                             | 4             | P3         | A — M1–M4 trazado |
| VIVIR               | Vivir                     | M3-T01-09  | M3 · Diálogo · p.37                                  | 4             | P3         | A — M1–M4 trazado |
| ALTO                | Alto                      | M2-T01-01  | M2 · Opuestos · p.33                                 | 3             | P3         | A — M1–M4 trazado |
| AMIGO               | Amigo                     | M2-T08-12  | M2 · Familia II · p.67                               | 3             | P3         | A — M1–M4 trazado |
| ANTEAYER            | Anteayer                  | M1-T15-06  | M1 · Tiempo · p.117                                  | 3             | P3         | A — M1–M4 trazado |
| ATENDER             | Atender                   | M1-T12-25  | M1 · Verbos · p.101                                  | 3             | P3         | A — M1–M4 trazado |
| CAJA                | Caja                      | M4-T17-22  | M4 · Escuela II · p.129                              | 3             | P3         | A — M1–M4 trazado |
| COMPAÑERO           | Compañera                 | M4-T17-09  | M4 · Escuela II · p.129                              | 3             | P3         | A — M1–M4 trazado |
| CONVOCAR            | Convocar                  | M4-T10-43  | M4 · Política II · p.89                              | 3             | P3         | A+ — contrastado  |
| CREER               | Creer                     | M4-T02-16  | M4 · Verbos IV · p.39                                | 3             | P3         | A — M1–M4 trazado |
| CÁMARA-FOTOGRÁFICA  | Cámara fotográfica        | M4-T07-16  | M4 · Hogar II · p.69                                 | 3             | P3         | A — M1–M4 trazado |
| DECIDIR             | Decidir                   | M4-T11-26  | M4 · General II · p.99                               | 3             | P3         | A — M1–M4 trazado |
| DIBUJAR             | Dibujar                   | M1-T12-12  | M1 · Verbos · p.101                                  | 3             | P3         | A — M1–M4 trazado |
| ENCONTRARSE         | Encontrarse               | M3-T01-07  | M3 · Diálogo · p.37                                  | 3             | P3         | A — M1–M4 trazado |
| ESCONDER            | Esconder                  | M4-T02-25  | M4 · Verbos IV · p.39                                | 3             | P3         | A — M1–M4 trazado |
| FILMAR              | Filmar                    | M3-T15-08  | M3 · Cumpleaños · p.117                              | 3             | P3         | A — M1–M4 trazado |
| FLACO               | Flaco                     | M2-T01-08  | M2 · Opuestos · p.33                                 | 3             | P3         | A — M1–M4 trazado |
| FUNCIONAR           | Funcionar                 | M4-T02-01  | M4 · Verbos IV · p.39                                | 3             | P3         | A — M1–M4 trazado |
| JOVEN               | Joven                     | M2-T08-20  | M2 · Familia II · p.67                               | 3             | P3         | A — M1–M4 trazado |
| LEJOS               | Lejos                     | M2-T01-13  | M2 · Opuestos · p.33                                 | 3             | P3         | A — M1–M4 trazado |
| LEY                 | Ley                       | M3-T02-18  | M3 · Política I · p.43                               | 3             | P3         | A — M1–M4 trazado |
| MAMÁ                | Mamá                      | M1-T02-05  | M1 · Familia · p.59                                  | 3             | P3         | A — M1–M4 trazado |
| MICRO               | Micro                     | M1-T10-05  | M1 · Medios de transporte · p.93                     | 3             | P3         | A — M1–M4 trazado |
| MINUTO              | Minuto                    | M3-T17-02  | M3 · Tiempo III · p.129                              | 3             | P3         | A — M1–M4 trazado |
| OSCURO              | Oscuro                    | M3-T12-02  | M3 · Opuestos II · p.101                             | 3             | P3         | A — M1–M4 trazado |
| PLAZA               | Plaza                     | M1-T05-05  | M1 · Lugares · p.71                                  | 3             | P3         | A — M1–M4 trazado |
| PLAZO               | Plazo                     | M3-T14-21  | M3 · General I · p.111                               | 3             | P3         | A — M1–M4 trazado |
| POSTERGAR           | Postergar                 | M3-T17-20  | M3 · Tiempo III · p.129                              | 3             | P3         | A — M1–M4 trazado |
| PRÓXIMO             | Próximo                   | M2-T05-08  | M2 · Tiempo II · p.53                                | 3             | P3         | A — M1–M4 trazado |
| SÁBADO              | Sábado                    | M1-T17-06  | M1 · Días de la semana · p.127                       | 3             | P3         | A — M1–M4 trazado |
| TRABAJADOR          | Trabajador                | M2-T10-02  | M2 · Trabajo · p.79                                  | 3             | P3         | A — M1–M4 trazado |
| VIERNES             | Viernes                   | M1-T17-05  | M1 · Días de la semana · p.127                       | 3             | P3         | A — M1–M4 trazado |
| ACEPTAR             | Aceptar                   | M3-T04-12  | M3 · Verbos III · p.55                               | 2             | P3         | A — M1–M4 trazado |
| ALLÁ                | Allá                      | M2-T20-08  | M2 · Adverbios de lugar · p.119                      | 2             | P3         | A — M1–M4 trazado |
| ANDAR               | Andar                     | M4-T02-07  | M4 · Verbos IV · p.39                                | 2             | P3         | A — M1–M4 trazado |
| ASISTENTE           | Asistente                 | M4-T10-12  | M4 · Política II · p.89                              | 2             | P3         | A — M1–M4 trazado |
| ASOCIACIÓN-SORDOS   | Asociación (Sordos)       | M3-T01-12  | M3 · Diálogo · p.37                                  | 2             | P3         | A — M1–M4 trazado |
| ATRÁS               | Atrás                     | M2-T20-01  | M2 · Adverbios de lugar · p.119                      | 2             | P3         | A — M1–M4 trazado |
| BARRIO              | Barrio                    | M3-T16-14  | M3 · Lugares II · p.123                              | 2             | P3         | A — M1–M4 trazado |
| BOCA                | Boca                      | M1-T03-12  | M1 · Cuerpo humano · p.63                            | 2             | P3         | A — M1–M4 trazado |
| BOLSA               | Bolsa                     | M3-T09-09  | M3 · Cocinar · p.83                                  | 2             | P3         | A — M1–M4 trazado |
| BUENO               | Bueno                     | M2-T01-19  | M2 · Opuestos · p.33                                 | 2             | P3         | A — M1–M4 trazado |
| CABELLO             | Cabello                   | M1-T03-14  | M1 · Cuerpo humano · p.63                            | 2             | P3         | A — M1–M4 trazado |
| CADA-DÍA            | Cada día                  | M3-T17-18  | M3 · Tiempo III · p.129                              | 2             | P3         | A — M1–M4 trazado |
| CHAMARRA            | Chamarra                  | M4-T12-03  | M4 · Ropas II · p.105                                | 2             | P3         | A — M1–M4 trazado |
| COCHABAMBA          | Cochabamba                | M1-T09-03  | M1 · Deptos. de Bolivia · p.89                       | 2             | P3         | A — M1–M4 trazado |
| COMPRAR             | Comprar                   | M1-T12-04  | M1 · Verbos · p.101                                  | 2             | P3         | A — M1–M4 trazado |
| COMUNIDAD-SORDA     | Comunidad Sorda           | M4-T10-20  | M4 · Política II · p.89                              | 2             | P3         | A — M1–M4 trazado |
| DEVOLVER            | Devolver                  | M4-T02-26  | M4 · Verbos IV · p.39                                | 2             | P3         | A — M1–M4 trazado |
| DOLOR               | Dolor                     | M2-T13-17  | M2 · Salud sexual y reproductiva · p.91              | 2             | P3         | A — M1–M4 trazado |
| DURANTE             | Durante                   | M3-T17-16  | M3 · Tiempo III · p.129                              | 2             | P3         | A — M1–M4 trazado |
| EDAD                | Edad                      | M4-T06-20  | M4 · Personas · p.61                                 | 2             | P3         | A — M1–M4 trazado |
| EMPEZAR             | Empezar                   | M2-T02-08  | M2 · Verbos II · p.41                                | 2             | P3         | A — M1–M4 trazado |
| ESCAPAR             | Escapar                   | M4-T02-23  | M4 · Verbos IV · p.39                                | 2             | P3         | A — M1–M4 trazado |
| ESCUELA             | Escuela                   | M1-T05-06  | M1 · Lugares · p.71                                  | 2             | P3         | A — M1–M4 trazado |
| FRACTURA            | Fractura                  | M4-T03-11  | M4 · Salud II · p.45                                 | 2             | P3         | A — M1–M4 trazado |
| FUTURO              | Futuro                    | M2-T05-07  | M2 · Tiempo II · p.53                                | 2             | P3         | A — M1–M4 trazado |
| GORRA               | Gorra                     | M4-T12-08  | M4 · Ropas II · p.105                                | 2             | P3         | A — M1–M4 trazado |
| HASTA-LUEGO         | Hasta luego               | M2-T05-10  | M2 · Tiempo II · p.53                                | 2             | P3         | A — M1–M4 trazado |
| HASTA-MAÑANA        | Hasta mañana              | M2-T05-11  | M2 · Tiempo II · p.53                                | 2             | P3         | A — M1–M4 trazado |
| HIJO                | Hijo                      | M1-T02-10  | M1 · Familia · p.59                                  | 2             | P3         | A — M1–M4 trazado |
| JEFE                | Jefe                      | M2-T10-07  | M2 · Trabajo · p.79                                  | 2             | P3         | A — M1–M4 trazado |
| LLAMAR              | Llamar                    | M3-T01-10  | M3 · Diálogo · p.37                                  | 2             | P3         | A — M1–M4 trazado |
| MIRAR               | Ver                       | M2-T02-18  | M2 · Verbos II · p.41                                | 2             | P3         | A — M1–M4 trazado |
| PELEAR              | Pelear                    | M4-T02-10  | M4 · Verbos IV · p.39                                | 2             | P3         | A — M1–M4 trazado |
| POLERA              | Polera                    | M2-T06-14  | M2 · Prendas de vestir · p.57                        | 2             | P3         | A — M1–M4 trazado |
| PREOCUPAR           | Preocupar                 | M4-T02-11  | M4 · Verbos IV · p.39                                | 2             | P3         | A — M1–M4 trazado |
| REUNIÓN             | Reunión                   | M4-T10-13  | M4 · Política II · p.89                              | 2             | P3         | A — M1–M4 trazado |
| ROJO                | Rojo                      | M1-T07-01  | M1 · Colores · p.81                                  | 2             | P3         | A — M1–M4 trazado |
| SEPARADOS           | Separados                 | M3-T11-12  | M3 · Estado Civil · p.95                             | 2             | P3         | A — M1–M4 trazado |
| SIEMPRE             | Siempre                   | M3-T17-07  | M3 · Tiempo III · p.129                              | 2             | P3         | A — M1–M4 trazado |
| URGENTE             | Urgente                   | M3-T17-13  | M3 · Tiempo III · p.129                              | 2             | P3         | A — M1–M4 trazado |
| VARIOS              | Algunos                   | M4-T17-06  | M4 · Escuela II · p.129                              | 2             | P3         | A — M1–M4 trazado |
| VENDER              | Vender                    | M1-T12-05  | M1 · Verbos · p.101                                  | 2             | P3         | A — M1–M4 trazado |
| ÚLTIMO              | Último                    | M3-T17-09  | M3 · Tiempo III · p.129                              | 2             | P3         | A — M1–M4 trazado |
| ABRIR               | Abrir                     | M1-T12-07  | M1 · Verbos · p.101                                  | 1             | P3         | A — M1–M4 trazado |
| ADULTO              | Adulto                    | M2-T08-19  | M2 · Familia II · p.67                               | 1             | P3         | A — M1–M4 trazado |
| ALCALDÍA            | Alcaldía                  | M3-T02-07  | M3 · Política I · p.43                               | 1             | P3         | A — M1–M4 trazado |
| AÑO                 | Año                       | M1-T15-04  | M1 · Tiempo · p.117                                  | 1             | P3         | A — M1–M4 trazado |
| AÑO-PASADO          | Año pasado                | M2-T05-09  | M2 · Tiempo II · p.53                                | 1             | P3         | A — M1–M4 trazado |
| BAJO                | Bajo                      | M2-T01-02  | M2 · Opuestos · p.33                                 | 1             | P3         | A — M1–M4 trazado |
| BUENOS-DÍAS         | Buenos días               | M1-T01-04  | M1 · Saludos · p.55                                  | 1             | P3         | A — M1–M4 trazado |
| BURLAR              | Burlar                    | M4-T09-06  | M4 · Diálogo II · p.83                               | 1             | P3         | A — M1–M4 trazado |
| CARO                | Caro                      | M2-T01-28  | M2 · Opuestos · p.33                                 | 1             | P3         | A — M1–M4 trazado |
| CONFIANZA           | Confianza                 | M4-T11-11  | M4 · General II · p.99                               | 1             | P3         | A — M1–M4 trazado |
| CONTINUAR           | Continuar                 | M3-T14-15  | M3 · General I · p.111                               | 1             | P3         | A — M1–M4 trazado |
| CORTO               | Corto                     | M4-T04-28  | M4 · Opuestos II · p.51                              | 1             | P3         | A — M1–M4 trazado |
| CURAR               | Curar                     | M3-T03-21  | M3 · Salud · p.49                                    | 1             | P3         | A — M1–M4 trazado |
| DE-NADA             | De nada                   | M4-T11-27  | M4 · General II · p.99                               | 1             | P3         | A — M1–M4 trazado |
| DEJAR               | Dejar                     | M4-T11-23  | M4 · General II · p.99                               | 1             | P3         | A — M1–M4 trazado |
| DESCANSO            | Descanso                  | M3-T17-05  | M3 · Tiempo III · p.129                              | 1             | P3         | A — M1–M4 trazado |
| DIFERENTE           | Diferente                 | M3-T14-02  | M3 · General I · p.111                               | 1             | P3         | A — M1–M4 trazado |
| DIFÍCIL             | Difícil                   | M3-T12-08  | M3 · Opuestos II · p.101                             | 1             | P3         | A — M1–M4 trazado |
| DISCRIMINACIÓN      | Discriminación            | M4-T10-42  | M4 · Política II · p.89                              | 1             | P3         | A+ — contrastado  |
| DORMIR              | Dormir                    | M1-T12-21  | M1 · Verbos · p.101                                  | 1             | P3         | A — M1–M4 trazado |
| ENFRENTE            | Enfrente                  | M2-T20-07  | M2 · Adverbios de lugar · p.119                      | 1             | P3         | A — M1–M4 trazado |
| ESCUELA-NOCTURNA    | Escuela nocturna          | M2-T15-03  | M2 · Educación · p.99                                | 1             | P3         | A — M1–M4 trazado |
| ESPOSA              | Esposa                    | M1-T02-06  | M1 · Familia · p.59                                  | 1             | P3         | A — M1–M4 trazado |
| EVALUAR             | Evaluar                   | M4-T02-06  | M4 · Verbos IV · p.39                                | 1             | P3         | A — M1–M4 trazado |
| FUERA               | Fuera                     | M2-T20-04  | M2 · Adverbios de lugar · p.119                      | 1             | P3         | A — M1–M4 trazado |
| GANAR-DINERO        | Ganar dinero              | M3-T01-14  | M3 · Diálogo · p.37                                  | 1             | P3         | A — M1–M4 trazado |
| GOBIERNO            | Gobierno                  | M3-T02-08  | M3 · Política I · p.43                               | 1             | P3         | A — M1–M4 trazado |
| GORDO               | Gordo                     | M2-T01-07  | M2 · Opuestos · p.33                                 | 1             | P3         | A — M1–M4 trazado |
| GRITAR              | Gritar                    | M4-T02-24  | M4 · Verbos IV · p.39                                | 1             | P3         | A — M1–M4 trazado |
| HOLA                | Hola                      | M1-T01-01  | M1 · Saludos · p.55                                  | 1             | P3         | A — M1–M4 trazado |
| HUESOS              | Huesos                    | M4-T03-09  | M4 · Salud II · p.45                                 | 1             | P3         | A — M1–M4 trazado |
| IGNORAR             | Ignorar                   | M4-T09-05  | M4 · Diálogo II · p.83                               | 1             | P3         | A — M1–M4 trazado |
| JULIO               | Julio                     | M1-T16-07  | M1 · Calendario · p.121                              | 1             | P3         | A — M1–M4 trazado |
| LENTES              | Lentes                    | M4-T14-02  | M4 · Sustantivos IV · p.113                          | 1             | P3         | A — M1–M4 trazado |
| LIBRE               | Libre                     | M3-T17-11  | M3 · Tiempo III · p.129                              | 1             | P3         | A — M1–M4 trazado |
| LISTA               | Lista                     | M3-T08-07  | M3 · Escuela · p.77                                  | 1             | P3         | A — M1–M4 trazado |
| LLEGAR              | Llegar                    | M2-T02-23  | M2 · Verbos II · p.41                                | 1             | P3         | A — M1–M4 trazado |
| LO-SIENTO           | Lo siento                 | M1-T01-18  | M1 · Saludos · p.55                                  | 1             | P3         | A — M1–M4 trazado |
| LUEGO               | Luego                     | M2-T05-04  | M2 · Tiempo II · p.53                                | 1             | P3         | A — M1–M4 trazado |
| LUNES               | Lunes                     | M1-T17-01  | M1 · Días de la semana · p.127                       | 1             | P3         | A — M1–M4 trazado |
| MARTES              | Martes                    | M1-T17-02  | M1 · Días de la semana · p.127                       | 1             | P3         | A — M1–M4 trazado |
| MARZO               | Marzo                     | M1-T16-03  | M1 · Calendario · p.121                              | 1             | P3         | A — M1–M4 trazado |
| MEDICINA            | Medicina                  | M2-T13-02  | M2 · Salud sexual y reproductiva · p.91              | 1             | P3         | A — M1–M4 trazado |
| MENTIRA             | Mentira                   | M2-T01-26  | M2 · Opuestos · p.33                                 | 1             | P3         | A — M1–M4 trazado |
| MOMENTO             | Momento                   | M3-T17-17  | M3 · Tiempo III · p.129                              | 1             | P3         | A — M1–M4 trazado |
| NO-ESTAR-DE-ACUERDO | No estar de acuerdo       | M3-T02-24  | M3 · Política I · p.43                               | 1             | P3         | A — M1–M4 trazado |
| OCUPADO             | Ocupado                   | M3-T17-04  | M3 · Tiempo III · p.129                              | 1             | P3         | A — M1–M4 trazado |
| OFICIAL             | Oficial                   | M4-T10-38  | M4 · Política II · p.89                              | 1             | P3         | A — M1–M4 trazado |
| ORGANIZAR           | Organizar                 | M4-T11-25  | M4 · General II · p.99                               | 1             | P3         | A — M1–M4 trazado |
| OYENTE              | Oyente                    | M3-T01-03  | M3 · Diálogo · p.37                                  | 1             | P3         | A — M1–M4 trazado |
| PALABRA             | Palabra                   | M3-T08-15  | M3 · Escuela · p.77                                  | 1             | P3         | A — M1–M4 trazado |
| PANTALÓN            | Pantalón                  | M2-T06-12  | M2 · Prendas de vestir · p.57                        | 1             | P3         | A — M1–M4 trazado |
| PAREJA              | Pareja                    | M4-T06-15  | M4 · Personas · p.61                                 | 1             | P3         | A — M1–M4 trazado |
| PARIENTE            | Pariente                  | M3-T11-14  | M3 · Estado Civil · p.95                             | 1             | P3         | A — M1–M4 trazado |
| PASADO-MAÑANA       | Pasado mañana             | M1-T15-10  | M1 · Tiempo · p.117                                  | 1             | P3         | A — M1–M4 trazado |
| PERMISO             | Permiso                   | M1-T01-03  | M1 · Saludos · p.55                                  | 1             | P3         | A — M1–M4 trazado |
| PROHIBIDO           | Prohibido                 | M3-T14-01  | M3 · General I · p.111                               | 1             | P3         | A — M1–M4 trazado |
| PROVINCIA           | Provincia                 | M3-T16-08  | M3 · Lugares II · p.123                              | 1             | P3         | A — M1–M4 trazado |
| RAYOS-X             | Rayos X                   | M4-T03-22  | M4 · Salud II · p.45                                 | 1             | P3         | A — M1–M4 trazado |
| RECHAZAR            | Rechazar                  | M3-T04-08  | M3 · Verbos III · p.55                               | 1             | P3         | A — M1–M4 trazado |
| RESULTADO           | Resultado                 | M4-T03-17  | M4 · Salud II · p.45                                 | 1             | P3         | A — M1–M4 trazado |
| SEGUNDO             | Segundo                   | M3-T17-01  | M3 · Tiempo III · p.129                              | 1             | P3         | A — M1–M4 trazado |
| SEÑOR               | Señor                     | M4-T06-10  | M4 · Personas · p.61                                 | 1             | P3         | A — M1–M4 trazado |
| SUYO                | Suyo                      | M1-T14-10  | M1 · Pronombres · p.113                              | 1             | P3         | A — M1–M4 trazado |
| TAL-VEZ             | Tal vez                   | M3-T17-12  | M3 · Tiempo III · p.129                              | 1             | P3         | A — M1–M4 trazado |
| TODOS-LOS-DÍAS      | Todos los días            | M2-T05-13  | M2 · Tiempo II · p.53                                | 1             | P3         | A — M1–M4 trazado |
| TRISTE              | Triste                    | M4-T04-11  | M4 · Opuestos II · p.51                              | 1             | P3         | A — M1–M4 trazado |
| TRUFI               | Trufi                     | M1-T10-06  | M1 · Medios de transporte · p.93                     | 1             | P3         | A — M1–M4 trazado |
| ABUSAR              | Abusar                    | D2024-p3   | II Diccionario Bilingüe LSB-Castellano (2024), p.3   | 0             | P3         | B — directo D2024 |
| ARRESTAR            | Arrestar                  | D2024-48   | II Diccionario Bilingüe LSB-Castellano (2024), p.17  | 0             | P3         | B — directo D2024 |
| IDENTIFICAR         | Identificar               | D2024-p111 | II Diccionario Bilingüe LSB-Castellano (2024), p.111 | 0             | P3         | B — directo D2024 |
| INSTITUCIÓN         | Institución               | D2024-312  | II Diccionario Bilingüe LSB-Castellano (2024), p.116 | 0             | P3         | B — directo D2024 |
| MALTRATAR           | Maltratar                 | D2024-p135 | II Diccionario Bilingüe LSB-Castellano (2024), p.135 | 0             | P3         | B — directo D2024 |
| ÓRGANO-JUDICIAL     | Órgano Judicial           | D2024-p157 | II Diccionario Bilingüe LSB-Castellano (2024), p.157 | 0             | P3         | B — directo D2024 |

# 13. Fuentes y trazabilidad

Ministerio de Educación de Bolivia / Federación Boliviana de Sordos. Curso de Enseñanza de la Lengua de Señas Boliviana (LSB), Módulos 1, 2, 3 y 4. 2010.

Ministerio de Educación de Bolivia. II Diccionario Bilingüe Lengua de Señas Boliviana – Castellano. Revisión: Federación Boliviana de Sordos (FEBOS). 2024.

Corpus conversacional Español ↔ LSB — entorno judicial (Cochabamba), versión 2.0, archivo aportado por el usuario.

Corpus conversacional LSB — ciudadano sordo en sede policial, versión 3.0, archivo aportado por el usuario.

Policía Boliviana. Información institucional y registros de FELCC/FELCV.

SEPDAVI. Servicio Plurinacional de Asistencia a la Víctima, sitio oficial del Estado Plurinacional de Bolivia.

SEPDEP. Servicio Plurinacional de Defensa Pública, sitio oficial del Estado Plurinacional de Bolivia.

# 14. Conclusión de la auditoría

**La recomendación final es mantener un único diccionario maestro de señas y conceptos, pero no un único “vocabulario de entrada”.** El ciudadano sordo opera sobre el léxico LSB disponible; el funcionario puede hablar o escribir español libre. Ambos flujos convergen en los mismos concept_id y assets LSB. La ampliación del español no obliga a crear una seña por cada palabra: obliga al NLP a normalizar, desambiguar y comprobar cobertura antes de renderizar.
