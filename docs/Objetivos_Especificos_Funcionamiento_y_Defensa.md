# OpenSoul — Cómo cumple cada objetivo específico

**Aplicación móvil para la comunicación bidireccional entre el idioma español y
la Lengua de Señas Boliviana (LSB) basada en un modelo de Inteligencia
Artificial, aplicada a denuncias, consultas y trámites en la etapa preliminar
judicial.**

Documento de apoyo para la defensa. Cada objetivo específico tiene: qué pide,
cómo lo resuelve el sistema (flujo paso a paso), qué tecnologías usa, dónde
está en el código, con qué se prueba, qué preguntará probablemente el tribunal
y qué límites hay que declarar.

Las cifras salen del código y de las pruebas ejecutadas el 2026-10-03, no del
diseño previsto.

---

## 0. Panorama en una página

```
┌──────────────────────── Aplicación móvil (Flutter) ────────────────────────┐
│                                                                            │
│  Persona OYENTE                               Persona SORDA                │
│  voz / texto ──► [audio_to_lsb] ──► avatar 3D   tarjetas ──► [lsb_to_text_audio]
│                        │                                       │           │
│                        └──────► [conversation] ◄───────────────┘           │
│                          turnos alternados, contexto compartido            │
└───────────────┬────────────────────────────────────────────┬───────────────┘
                │ HTTPS (API Gateway)                        │
      ┌─────────▼──────────┐                      ┌──────────▼───────────┐
      │ Lambda Texto→LSB   │                      │ Lambda LSB→Texto/Audio│
      │ desambiguación,    │                      │ composición híbrida,  │
      │ gramática LSB,     │                      │ refinamiento, voz,    │
      │ plan de animación  │                      │ RAG de trámites       │
      └───┬──────────┬─────┘                      └──┬───────┬──────┬─────┘
          │          │                               │       │      │
     Amazon Bedrock  S3 (caché,               Bedrock    Polly   S3 (audio)
     (Nova 2 Lite)   avatar .glb)            (Nova 2 Lite, (voz    + Titan
                                              refinador)   neural) Embeddings
```

| Capa | Tecnología |
|---|---|
| App móvil | Flutter (Dart), Riverpod (estado), go_router (navegación), Clean Architecture por módulos |
| Voz → texto | `speech_to_text` (reconocimiento del propio dispositivo, configuración regional `es_BO` si existe) |
| Avatar 3D | `model_viewer_plus` (WebView + `<model-viewer>`), un solo modelo `.glb` con los clips de las señas |
| Backend | AWS Lambda (Python 3) detrás de API Gateway |
| Modelo fundacional | Amazon Bedrock, **Amazon Nova 2 Lite** (`global.amazon.nova-2-lite-v1:0`) |
| Embeddings (RAG) | Amazon Titan Text Embeddings v2 |
| Texto → voz | Amazon Polly, motor neural, voz **Lupe** (español de EE. UU.; Polly no tiene voz boliviana) |
| Almacenamiento | Amazon S3 (caché de traducciones, audio generado, modelo del avatar) |
| Pruebas | `flutter test`, `unittest`/`pytest` del backend, verificadores de corpus |

**Tamaño real:** 156 archivos Dart en `lib/` (~34 000 líneas), dos Lambdas
principales (`lambda_function.py` 4 478 líneas, `lambda_text_to_lsb.py`
2 167), 93 archivos de prueba en Flutter y 29 en el backend.

---

## 1. Veredicto honesto: ¿es un buen proyecto de grado?

**Sí. Cumple los siete objetivos y tiene evidencia para cada uno.** El riesgo
no es que falte algo, sino que **sobra superficie**: hay mucho código de
soporte (herramientas de corpus, auditorías, verificadores) que no es
necesario defender línea por línea.

Una defensa no evalúa si recuerdas cada función. Evalúa si puedes explicar:

1. **qué problema** resuelve el sistema y para quién;
2. **las decisiones de diseño** y por qué las tomaste (con evidencia);
3. **cómo verificaste** que funciona;
4. **qué no hace** todavía (límites declarados).

Este documento está organizado para eso. Lo que no aparece aquí es
infraestructura: se menciona como «herramientas de construcción y control de
calidad» y no hace falta abrirlo.

### Lo que hay que corregir antes de defender

Hay incoherencias entre el código y los documentos que un tribunal atento
puede encontrar:

| # | Dónde | Qué dice | Qué es verdad hoy |
|---|---|---|---|
| 1 | Encabezado de `aws/lambda_text_to_lsb.py` | «Amazon Bedrock (Claude 3 Haiku)» y «Objetivo Específico 3» | El modelo por defecto es **Amazon Nova 2 Lite**, y en tu lista es el **objetivo 2** |
| 2 | Documento de grado, 4.4.6 | 41 recursos de animación | `available3DGlosses` declara **158**: 26 letras, 11 numerales y ~121 señas |
| 3 | Documento de grado, 4.7 | «Contextos de consulta y trámite: **No**» | El corpus RAG ya los cubre: **94 escenarios, 15 instituciones, 79 recorridos** de trámite (ver §RAG) |
| 4 | Documento de grado, 4.7 | 452 pruebas Flutter / 162 backend | Hoy son más (ver objetivo 7); actualiza con la ejecución final |
| 5 | Encabezados de autoría | `lambda_text_to_lsb.py`: «Módulo Isaac Rivero»; `lambda_function.py`: «Nathanael Alba» | Si es un trabajo de dos personas, acordad quién defiende cada objetivo |

---

## 2. ¿Qué tan importante es el RAG?

### Respuesta corta

**No aparece en ningún objetivo específico, pero sostiene una palabra del
título.** El título dice «denuncias, **consultas y trámites**». El flujo
guiado original (grafo de diálogo) cubre bien las denuncias, pero tu propio
documento de grado (4.7) declara los contextos de consulta y trámite como **no
implementados**. El RAG es lo que los cubre.

### Qué es y qué hace

RAG (*Retrieval-Augmented Generation*, generación aumentada por recuperación)
es aquí una **base de conocimiento de trámites reales de Cochabamba**:

- **94 escenarios de diálogo** funcionario ↔ persona sorda en 15 instituciones
  (SEGIP, SERECI, FELCC, FELCV, Fiscalía, Órgano Judicial, Derechos Reales,
  Defensoría, SLIM, DNA, Notaría, impuestos municipales…), cada uno con su
  fuente oficial y fecha de consulta.
- Cuando el funcionario dice algo que el grafo de denuncias no reconoce
  («¿Trajo su folio real?»), la app **recupera** el escenario más parecido y
  ofrece a la persona sorda **tarjetas de respuesta ya traducidas a LSB**.
- La recuperación funciona en el dispositivo por palabras y, si hay red, por
  **significado** con embeddings de Titan.

### Cómo presentarlo

No como un objetivo aparte, sino como la **base de conocimiento del dominio**
que alimenta dos objetivos:

- **Objetivo 4** (tarjetas): las respuestas de trámites son tarjetas del mismo
  catálogo LSB, con las mismas reglas de validación.
- **Objetivo 7** (pruebas): los escenarios de «consulta y trámite» que pide el
  objetivo salen de este corpus.

### Lo que NO hace falta defender en detalle

Las herramientas que construyen y controlan el corpus son ingeniería de
calidad de datos, no el aporte central:

- ingesta de PDF y validación de texto dañado;
- léxico LSB (M1–M4 y el II Diccionario 2024) como filtro;
- equivalencias de señas con confirmación de sentido;
- retrotraducción de glosas para detectar omisiones.

Basta una frase: *«el corpus se construye con un pipeline que solo admite señas
de las fuentes oficiales del Ministerio de Educación y verifica cada traducción
antes de ofrecerla»*. Si preguntan, se explica con un ejemplo: «mi fiscal» no
se traduce con la seña FISCAL del Módulo 3, porque esa seña significa
«escuela fiscal».

**Si quieres reducir alcance:** puedes declarar el RAG como componente
complementario y mover las herramientas a un anexo. Lo que no conviene es
quitarlo del todo, porque entonces «consultas y trámites» del título quedaría
sin respaldo.

---

## 3. Objetivo 1 — Arquitectura del sistema de traducción bidireccional

> Diseñar la arquitectura del sistema de traducción bidireccional entre el
> español y la Lengua de Señas Boliviana.

### Cómo se cumple

**Tres módulos con fronteras verificadas:**

| Módulo | Responsabilidad |
|---|---|
| `conversation` | Integrador: turnos alternados, contexto vigente, enlace de cada respuesta con la pregunta que contesta |
| `audio_to_lsb` | Dirección oyente → sorda: voz/texto a glosas y avatar |
| `lsb_to_text_audio` | Dirección sorda → oyente: tarjetas a texto formal y voz |
| `core` | Entidades, servicios de dominio, acceso a datos; compartido |

**Reglas de dependencia:** los dos módulos de traducción **no se conocen entre
sí** ni conocen al de conversación. Donde el flujo de tarjetas necesita saber
de la conversación, el núcleo declara **puertos** (inversión de dependencias,
`core/domain/services/conversation_bridge.dart`) que la conversación
implementa al arrancar. Con los puertos desactivados, cada módulo funciona
como aplicación autónoma.

**Capas por módulo (Clean Architecture):** `presentation` (pantallas,
providers de Riverpod) → `domain` (entidades, casos de uso, motores) → `data`
(fuentes remotas y locales, repositorios).

**Backend sin servidores:** dos Lambdas especializadas detrás de API Gateway.
La app no depende de que respondan: el motor local compone la declaración base
y la traducción de respaldo, y el backend la mejora.

**Principio rector:** *toda entrada se normaliza a una misma representación
semántica* (glosas y marcos semánticos) antes de generar cualquier salida.
No hay caminos directos de texto a avatar ni de tarjetas a audio.

### Tecnologías
Flutter, Dart, Riverpod, go_router, Clean Architecture, AWS Lambda, API
Gateway, S3.

### Evidencia
- `test/module_boundaries_test.dart` y `test/module_isolation_test.dart`
  comprueban que ningún módulo importa a otro que no debe.
- `test/conversation_bidirectional_test.dart`: el ciclo completo en ambas
  direcciones.

### Preguntas probables
- *¿Por qué Lambdas y no un servidor?* Carga intermitente, pago por uso,
  escalado automático, sin servidor que mantener.
- *¿Qué pasa sin internet?* La app sigue funcionando con el motor local
  (composición por reglas, catálogo empaquetado); pierde el refinamiento con
  IA, la voz de Polly y la búsqueda por significado.

---

## 4. Objetivo 2 — Entrada de audio/texto, desambiguación jurídica y gramática LSB

> Desarrollar el módulo de captura y procesamiento de entrada de audio y texto
> en español, integrando un modelo de PLN que realice la desambiguación
> semántica de términos polisémicos en contexto jurídico y la reestructuración
> sintáctica hacia la gramática viso-espacial de la LSB.

### Flujo paso a paso

1. **Captura.** El oyente habla (reconocimiento de voz del propio teléfono,
   plugin `speech_to_text`, configuración regional `es_BO` si el dispositivo
   la tiene; si no, otra variante de español) o escribe.
2. **Envío.** La app manda la frase y el **contexto de la conversación**
   (denuncia de robo, violencia, trámite…) a la Lambda Texto→LSB.
3. **Caché.** Si esa frase ya se tradujo con las mismas reglas, se devuelve
   desde S3, sin invocar al modelo.
4. **Desambiguación en dos niveles:**
   - **Determinista** (`resolve_ambiguous_terms`): para términos con sentidos
     de consecuencias distintas (`_AMBIGUOUS_TERMS`), busca señales en la
     frase. Si las señales apuntan a un solo sentido, lo fija. Si no, **le
     pregunta al oyente** en vez de adivinar.
   - **Modelo fundacional** (Amazon Nova 2 Lite en Bedrock) con un prompt de
     reglas jurídicas (`LEGAL_DISAMBIGUATION_RULES`): «llamar» (verbo) vs.
     «llama» (animal), «correr» no es «escapar», «billetera» no es «dinero»,
     «fiscal» (persona) no es la seña FISCAL del Módulo 3 (sentido escolar).
5. **Reestructuración sintáctica a LSB**, en el mismo prompt:
   - orden canónico **TIEMPO → LUGAR → SUJETO/OBJETO → ADJETIVO → VERBO →
     NEGACIÓN/PREGUNTA** («Ayer llegué a la fiscalía» → `AYER FISCALIA
     LLEGAR`);
   - supresión de artículos y preposiciones sin carga semántica;
   - verbos en forma base, morfología neutra;
   - interrogativos al final («¿Dónde ocurrió el robo?» → `ROBAR DÓNDE`);
   - señas compuestas como una sola glosa (`COMO_ESTAS`).
6. **Postproceso determinista** (lo que el modelo devuelve no se acepta sin
   revisar):
   - solo glosas del catálogo oficial (`enforce_catalog_membership`); lo demás
     se **deletrea** con dactilología;
   - cobertura: si el modelo omitió una palabra con contenido, se repone
     (`repair_coverage`);
   - **pérdida de negación y de cifras** detectada (`detect_fidelity_losses`):
     «no me robaron» nunca puede salir como «me robaron»;
   - preguntas habladas sin signos de interrogación se conservan como
     preguntas.
7. **Plan de animación:** cada glosa se resuelve a su clip del avatar, a su
   deletreo o a un marcador explícito si no hay seña.

### Tecnologías
`speech_to_text` (dispositivo), API Gateway, AWS Lambda (Python), Amazon
Bedrock (Nova 2 Lite), ingeniería de prompts, reglas deterministas, S3 como
caché.

### Dónde está
`lib/features/audio_to_lsb/`, `aws/lambda_text_to_lsb.py`,
`docs/Catalogo_Acepciones_Audio_a_LSB.md` (registro de cada decisión de
acepción).

### Evidencia
`test/audio_a_lsb_integracion_test.dart`, `test/audio_a_lsb_semantic_turn_test.dart`,
`aws/tests/test_auditoria_2026_09_audio_a_lsb.py`,
`aws/tests/test_fidelidad_relaciones.py`, `aws/tests/test_gramatica_lsb.py`.

### Preguntas probables
- *¿Entrenaste un modelo de PLN?* No: se usa un **modelo fundacional**
  (Nova 2 Lite) con ingeniería de prompts, acotado por reglas deterministas
  antes y después. Entrenar un modelo propio exige un corpus paralelo
  español–LSB que no existe a esa escala para Bolivia. Es una decisión
  justificada, no una carencia.
- *¿Cómo sabes que la desambiguación es correcta?* Las reglas son explícitas y
  trazables al corpus, y donde no hay evidencia suficiente el sistema
  **pregunta** en vez de elegir.
- *¿Y la inyección de instrucciones en el prompt?* La frase va delimitada, se
  neutralizan los delimitadores y la salida se valida contra el catálogo.

### Límites a declarar
El orden de glosas sigue las reglas del corpus; **no está validado con
señantes de Cochabamba** (ver §Límites).

---

## 5. Objetivo 3 — Avatar tridimensional que ejecuta la secuencia de glosas

> Desarrollar el módulo de generación de representaciones en LSB mediante
> avatar tridimensional, que ejecute la secuencia de glosas producida por el
> módulo anterior.

### Flujo paso a paso

1. Llega la secuencia de glosas con su plan de animación.
2. `AnimationUrlResolver` decide qué es cada glosa: **clip** del modelo,
   **deletreo** letra por letra, **numeral** o **marcador** («seña en espera»).
3. Un **único modelo `.glb`** contiene todas las señas como clips. Se carga
   una sola vez (evita descargar y analizar el modelo en cada frase).
4. El visor (`<model-viewer>` dentro de un WebView, vía `model_viewer_plus`)
   recibe por JavaScript el nombre del clip, lo reproduce **una vez** y
   avisa al terminar con un **identificador de paso**. Los avisos de un paso
   anterior se descartan.
5. **Relojes de seguridad:** si un clip no avisa (no existe o el visor no
   cargó), el paso vence solo y la secuencia sigue: nunca queda bloqueada.
6. Entre frases, el avatar hace **movimientos de reposo** (NEUTRO1–3) para no
   quedar congelado; el reposo se cancela antes de empezar una seña.
7. El usuario puede **repetir** la frase.

### Tecnologías
`model_viewer_plus` (Google `<model-viewer>`, WebView), glTF/GLB,
animaciones esqueléticas, comunicación Dart ↔ JavaScript, S3 para el modelo.

### Dónde está
`lib/core/presentation/widgets/avatar_3d_viewer.dart`,
`lib/core/domain/services/animation_url_resolver.dart`,
`assets/models/avatar_test.glb`.

### Evidencia
`test/avatar_animation_resolution_test.dart`, `test/avatar_interaction_test.dart`,
`test/numerales_avatar_test.dart`, `aws/tests/test_animaciones_glb.py`
(comprueba que la lista declarada coincide con los clips del archivo).

### Preguntas probables
- *¿Cuántas señas tiene el avatar?* 158 recursos: 26 letras, 11 numerales y
  ~121 señas. El catálogo tiene 346 glosas: lo que no tiene clip se deletrea
  o se marca, **nunca se simula una seña inexistente**.
- *¿Por qué no generar las señas automáticamente?* Una seña tiene
  configuración de mano, movimiento, ubicación y expresión facial; generarla
  sin validación produciría señas incorrectas. Se prefirió animación
  producida y un catálogo honesto de lo que falta.

### Límites a declarar
Cobertura parcial de animación. Los marcadores permiten que el sistema
funcione mientras se producen más señas.

---

## 6. Objetivo 4 — Entrada visual táctil con catálogo de tarjetas

> Implementar el mecanismo de entrada visual táctil mediante un catálogo de
> tarjetas digitales que represente las glosas LSB depuradas para el dominio
> de la etapa preliminar judicial.

### Cómo se cumple

**Catálogo depurado:** 346 glosas en 16 categorías (Cortesía, Respuesta,
Preguntas, Identificación, Instituciones, Conceptos jurídicos, Acciones,
Hechos y urgencia, Descripción, Estado y emoción, Tiempo, Lugares,
Documentos, Objetos, Abecedario, Números). Cada una con **trazabilidad a su
fuente oficial**: módulos M1–M4 del curso de LSB del Ministerio de Educación
(322) y el II Diccionario Bilingüe LSB–Castellano 2024.

**Flujo guiado** (no una cuadrícula de 346 tarjetas):

1. El contexto (denuncia de robo, violencia, accidente, trámite…) define un
   árbol de **zonas semánticas** (¿quién?, ¿qué pasó?, ¿cuándo?, ¿dónde?).
2. Cada zona ofrece solo las tarjetas pertinentes, con su icono.
3. **Se responde lo que se preguntó:** si el funcionario preguntó «¿A qué hora
   y dónde le robaron?», el flujo recorre solo esas dos preguntas. Las demás
   siguen disponibles si la persona quiere añadir algo.
4. Datos concretos (montos, fechas, nombres) se ingresan con editores
   específicos, no con tarjetas.
5. Para trámites, el **RAG** aporta las respuestas documentadas como tarjetas
   (ver §RAG).

**Banco de preguntas:** 148 preguntas, 197 acepciones, 8 recorridos guiados
(`aws/question_bank.json`), y 79 recorridos de trámite del corpus RAG (180
preguntas). En los trámites cada tarjeta es **una sola seña** que contesta
su pregunta: SÍ/NO/NO SÉ; la seña de la zona que pide «¿cuándo?», «¿dónde?»
o «¿qué documentos?»; o ENTENDIDO/NO ENTIENDO ante una indicación. Al
elegirla se dice una frase completa coherente («Sí, traje mi cédula.»).

### Tecnologías
Flutter (widgets, Riverpod), JSON versionado como fuente canónica del
catálogo, motor de zonas e inferencia de contexto en el dispositivo.

### Dónde está
`assets/dictionary/official_dictionary.json`,
`lib/features/lsb_to_text_audio/presentation/` (tarjetas, flujo guiado),
`lib/core/domain/guided/`, `lib/core/domain/services/zone_inference_engine.dart`.

### Evidencia
`test/guided_exhaustivo_test.dart`, `test/hierarchical_wizard_test.dart`,
`test/gloss_icon_coverage_test.dart`, `test/recorridos_completos_test.dart`,
`test/rag_tramites_test.dart`.

### Preguntas probables
- *¿Por qué tarjetas y no reconocimiento de señas por cámara?* El
  reconocimiento de LSB por visión exige un conjunto de datos de video
  etiquetado de LSB que no existe a la escala necesaria, y un error de
  reconocimiento en una denuncia cambia la declaración. Las tarjetas dan
  control total a la persona sorda sobre lo que declara.
- *¿Qué significa «depuradas»?* Solo entran glosas con fuente oficial; las
  palabras sin seña se marcan como «seña a incorporar», no se inventan.

---

## 7. Objetivo 5 — Salida multimodal: análisis semántico híbrido y voz

> Implementar el pipeline de generación de salida multimodal, compuesto por un
> análisis semántico híbrido con lexicón LSB y modelo fundacional que produzca
> texto formal en español, y por la síntesis de dicho texto en audio continuo
> mediante un sistema de conversión texto a voz.

### Flujo paso a paso

1. **Entrada:** las glosas que eligió la persona sorda (sin orden ni
   morfología del español) y el contexto.
2. **Análisis con lexicón LSB** (en el dispositivo,
   `LocalSentenceAssembler`): cada glosa tiene en el lexicón un **rol
   semántico** (sujeto, verbo de agresión, objeto, lugar, tiempo, testigo,
   emoción…; ~400 entradas) y su forma en español. El motor clasifica, resuelve
   género y tiempo verbal y **compone la oración base** según el tipo de
   hecho (robo, violencia, trámite…).
3. **Refinamiento con el modelo fundacional** (Lambda + Bedrock Nova 2 Lite):
   mejora la redacción a español formal.
4. **Validador:** la versión refinada **se descarta si pierde contenido**
   (una glosa declarada que no aparece, una negación perdida). Entonces queda
   la oración base.
5. **Síntesis de voz:** Amazon Polly, motor neural, voz Lupe, MP3 guardado en
   S3. Sin red, la app usa el TTS del dispositivo (`flutter_tts`).
6. La declaración se genera **una sola vez al final**, como una oración con
   valor documental, no como frases sueltas por cada pregunta.

### Por qué «híbrido» (el argumento más fuerte de la defensa)

En la evaluación del corpus, **el modelo generando solo representó el 58,3 %
de las glosas declaradas; el motor de reglas, el 100 %.** En una declaración
para una institución pública, omitir que se pidió ayuda o que intervino la
policía no es «redactar mejor»: es otra declaración. Por eso:

- el **lexicón** garantiza el contenido;
- el **modelo** mejora la forma;
- el **validador** decide y nunca deja pasar una pérdida.

### Tecnologías
Dart (motor de reglas en el dispositivo), AWS Lambda, Amazon Bedrock
(Nova 2 Lite), Amazon Polly (neural), S3, `audioplayers`, `flutter_tts`.

### Dónde está
`lib/core/domain/services/local_sentence_assembler.dart`,
`aws/guided_composer.py`, `aws/lambda_function.py` (refinamiento, validador,
`synthesize_audio`).

### Evidencia
`test/local_sentence_assembler_test.dart`, `test/declaration_draft_assembler_test.dart`,
`test/backend_generativo_test.dart`, `test/critical_robbery_snapshot_test.dart`,
`aws/tests/test_guiado_precision.py`, `aws/tests/test_exhaustive_flows_coherence.py`.

### Preguntas probables
- *¿Por qué no solo el modelo?* Por la cifra 58,3 % vs. 100 %.
- *¿Y si Bedrock no responde?* Queda la oración del motor local: la
  declaración nunca depende de la nube.
- *¿La voz es boliviana?* No: Polly no ofrece español de Bolivia; se usa
  español latinoamericano (Lupe). Es una limitación del proveedor.

---

## 8. Objetivo 6 — Integración de ambas direcciones con opción de cambio

> Integrar ambas direcciones de traducción dentro de la aplicación móvil, con
> la opción de cambiar entre ellas.

### Cómo se cumple

**Dos formas de usar las dos direcciones:**

1. **Barra de navegación inferior** (`MainNavigationScreen`) con tres
   pestañas: **Tarjetas LSB**, **Conversación** y **Voz a LSB**. Cada
   dirección se puede usar como herramienta suelta; se cambia con un toque.
2. **Conversación** (el centro de la app): un solo dispositivo que las dos
   personas se pasan. Turnos alternados:
   - el oyente habla → su turno aparece al instante con el avatar;
   - la persona sorda responde con tarjetas **desde el contexto que fijó la
     pregunta** → su respuesta queda **enlazada a esa pregunta**;
   - el contexto que la persona sorda confirma vuelve al traductor para
     acotar el turno siguiente.

**Tres modos del módulo de tarjetas:** declaración independiente (A), turno
iniciado por la persona sorda (B) y respuesta a un turno concreto (C). El
enlace con la pregunta se congela al abrir el flujo: si llega otra frase
mientras se edita, la respuesta sigue vinculada a la que se estaba viendo.

**Sesiones separadas:** lo hecho en una pestaña suelta no se filtra a la
conversación ni al revés. Solo la conversación tiene memoria.

### Tecnologías
Flutter, Riverpod, go_router, puertos de inversión de dependencias,
`shared_preferences` para restaurar la sesión
(`core/data/repositories/session_repository_impl.dart`).

### Dónde está
`lib/app/` (`screens/main_navigation_screen.dart`, `app_router`,
`surface_session`),
`lib/features/conversation/`.

### Evidencia
`test/conversation_bidirectional_test.dart`, `test/modos_abc_conversacion_test.dart`,
`test/conversacion_ventanilla_test.dart`, `test/conversation_restoration_test.dart`,
`test/conversacion_iniciada_por_sorda_test.dart`.

---

## 9. Objetivo 7 — Pruebas funcionales y de coherencia semántica

> Ejecutar pruebas funcionales y de coherencia semántica mediante escenarios
> simulados de denuncia, consulta y trámite.

### Qué se prueba

| Tipo | Qué verifica | Ejemplos |
|---|---|---|
| **Funcionales** | Cada flujo de punta a punta | `home_to_result_flow_test`, `recorridos_completos_test`, `conversation_bidirectional_test` |
| **Coherencia semántica** | Que la salida diga lo mismo que la entrada: sin perder negaciones, cifras ni hechos | `exhaustive_flows_coherence_test`, `lsb_gloss_semantics_contract_test`, `aws/tests/test_fidelidad_relaciones.py` |
| **Escenarios de denuncia** | Robo, violencia, amenaza digital, estafa | `critical_robbery_snapshot_test`, `escenarios_por_datos_test` |
| **Escenarios de consulta y trámite** | 94 escenarios de 15 instituciones | `rag_tramites_test`, `rag_evaluation_test`, `rag_ramificaciones_test` |
| **Corpus** | 209 intervenciones del corpus conversacional; 25 casos del corpus contra el backend | `corpus_v4_test`, `casos_corpus_test`, `aws/tests/test_casos_corpus.py` |
| **Seguridad** | Inyección en prompts, entradas inválidas | `test/security/`, `aws/tests/test_security.py` |
| **Arquitectura** | Fronteras entre módulos | `module_boundaries_test` |

### Resultados (ejecución 2026-10-03)

| Suite | Resultado |
|---|---|
| Backend (`aws/tests`) | 433 pruebas, todas satisfactorias (1 omitida) |
| Herramientas del corpus (`tool/tests`) | 106 pruebas, todas satisfactorias |
| App (`flutter test`) | 978 satisfactorias, 1 omitida |


**Cobertura del corpus conversacional (209 intervenciones):** 88,0 % con señas
del catálogo, 9,6 % con dactilología, 2,4 % no soportadas (cuatro conceptos
genéricos: OBJETO, TEXTO, COLOR, DELETREAR).

### Pregunta probable
- *¿Probaste con personas sordas?* Ver §Límites: es la validación pendiente,
  y se declara.

---

## 10. Límites que hay que declarar (y cómo decirlo)

Declararlos **fortalece** la defensa: demuestra que sabes qué verificaste y
qué no.

1. **Sin validación con señantes.** Las secuencias de glosas y las
   composiciones no fueron validadas con personas sordas de Cochabamba ni con
   intérpretes acreditados. Lo verificado es cobertura léxica, integridad de
   datos y comportamiento del sistema; **no** naturalidad lingüística. Es
   requisito antes de un uso real.
2. **Animación parcial.** 158 recursos frente a 346 glosas; lo demás se
   deletrea o se marca.
3. **Variante regional.** M1–M4 y el diccionario son nacionales; la app se
   orienta a Cochabamba.
4. **Voz no boliviana** (limitación de Polly).
5. **Dependencia de la nube** para el refinamiento, la voz neural y la
   búsqueda por significado (el núcleo funciona sin ella).

---

## 11. Cómo preparar la defensa sin memorizar el código

1. **Un diagrama** (§0) y saber recorrerlo con una frase de ejemplo en cada
   dirección:
   - oyente: «¿Dónde le robaron el celular?» → `CELULAR ROBAR DÓNDE` → avatar
     (ejemplo según las reglas de orden; ejecútalo antes para citar la salida
     real);
   - sorda: tarjetas `NOCHE · CALLE · CELULAR · ROBAR` → «Me robaron el
     celular en la calle por la noche.» → voz.
2. **Tres decisiones con evidencia:**
   - motor propio + IA que solo refina (**58,3 % vs. 100 %**);
   - preguntar en vez de adivinar ante una ambigüedad;
   - no inventar señas (deletreo y marcadores, léxico de fuentes oficiales).
3. **Una demostración en vivo** de una conversación completa (un turno en cada
   dirección), con el plan B de un video grabado.
4. **La tabla de límites** (§10), dicha antes de que la pregunten.
5. Para cada objetivo, saber **un archivo** y **una prueba** que lo respaldan
   (están en cada sección).
