# RAG de conocimiento institucional — diseño

Estado: **fases 0 y 1 hechas**, con los casos 1 y 2 (corpus validado,
recuperación local en el chat); fase 2 lista para desplegar; fase 3
propuesta. Rama
`feat/rag-conocimiento-institucional`.

## 1. Qué problema resuelve

El módulo Conversación funciona con un grafo cerrado: el banco de preguntas
(`docs/negocio/config/banco_preguntas.json`) y el corpus de preguntas del
funcionario (`assets/dialogue/dialogue_graph.json`). Cuando el funcionario dice
algo que el grafo no reconoce, el enrutador devuelve `noSafeRoute` y la persona
sorda termina en el selector de contextos. Pasa también cuando el trámite no
existe en el banco: Derechos Reales, impuestos municipales, notaría, juzgado de
familia, defensa pública.

El RAG es la **tercera capa**, la alternativa cuando el grafo deja de
funcionar:

1. Reglas del grafo (hoy).
2. Modelo de desempate entre rutas reales (hoy, `action: "route"`).
3. **Nuevo:** situaciones reales documentadas de instituciones de Cochabamba.
   Se recuperan las más parecidas y se ofrecen a la persona sorda como
   respuestas o preguntas listas para enviar.

### Alcance: solo conocimiento fijo

| Tipo | Ejemplo | ¿Lo resuelve el RAG? |
|---|---|---|
| **A. Conocimiento fijo** | «El Folio Real cuesta X Bs», «hay que pagar en el banco y volver», «el intérprete es un derecho», requisitos, horarios | **Sí** |
| **B. Dato en vivo de una persona** | estado del caso por NUREJ, deuda de la placa 1234-XYZ, fecha de *su* audiencia | **No.** Necesita una API de la institución. El RAG solo ofrece a la persona sorda cómo pedir o entregar ese dato («Aquí tengo mi número de NUREJ»). Nunca inventa el dato. |

## 2. Qué se recupera y qué se devuelve

**Unidad de recuperación:** un turno de diálogo dentro de un escenario. Cada
turno lleva su escenario, su institución, el hecho que usa (si usa uno) y la
fuente de ese hecho.

**Caso 1: el funcionario pregunta y el grafo no lo reconoce.**
Se buscan los turnos de funcionario más parecidos a lo que dijo. Se toman los
turnos siguientes del usuario sordo en esos escenarios y se ofrecen como
respuestas:

> Funcionario: «¿Trae el número de matrícula o el Folio Real antiguo?»
> Tarjetas sugeridas: «Sí, tengo el Folio antiguo» · «Tengo la matrícula» ·
> «No tengo ninguno» · «No sé cuál es»

**Caso 2: la persona sorda abre el turno** (necesidad «Preguntar»).
Detectado el trámite, se le ofrecen las preguntas que hacen las personas en
ese escenario: «¿Tengo que hacer fila otra vez?», «¿Cuánto cuesta?», «¿Puedo
pedir un intérprete?».

**Recuperación extractiva.** Las frases salen tal cual del corpus revisado.
El modelo no escribe texto nuevo. Así se mantiene el criterio del proyecto:
nada que no esté documentado entra en boca de la persona sorda.

## 3. Reglas de precisión (no negociables)

1. **Todo dato lleva fuente y fecha.** Un precio, requisito u horario sin
   fuente oficial y fecha de consulta no entra al corpus como hecho.
2. **Números y fechas se verifican sin IA.** Si un día se generan respuestas
   (fase 3), cada cifra del texto debe aparecer literal en el fragmento
   recuperado. Es la misma idea que la verificación de cobertura de
   `guided_composer.py`: si falla, se descarta.
3. **Los datos personales del corpus son ficticios** (NUREJ, placas,
   nombres). Nunca se muestran como datos del usuario.
4. **Los datos en vivo (tipo B) no se responden.** Se ofrece pedírselos al
   funcionario.
5. **Sin coincidencia suficiente no hay sugerencia.** Igual que
   `noSafeRoute`: mejor no ofrecer nada que ofrecer algo equivocado.
6. **Los datos vencen.** Cada hecho guarda su fecha de consulta; pasado un
   plazo (propuesta: 6 meses), la interfaz lo muestra como «a confirmar».

## 4. Glosas

Las frases del usuario sordo del corpus se traducen **una vez, al construir el
corpus**, con la misma Lambda Texto→LSB (`lambda_text_to_lsb.py`), que ya
valida contra el diccionario oficial y deletrea lo que no tiene seña. Se
guardan texto y glosas. En la app no hay traducción en vivo ni costo por
sugerencia, y cada tarjeta muestra su secuencia LSB como hoy.

## 5. Arquitectura por fases

### Fase 0: corpus (hecha)

- ChatGPT investigó los sitios oficiales con el prompt de
  `docs/negocio/rag/prompt_investigacion_chatgpt.md`. La entrega es la fuente
  editable: `docs/negocio/rag/escenarios/tramites_cochabamba_2026-09-27.md`
  (62 escenarios, 53 fuentes, 89 hechos).
- `tool/build_rag_corpus.py`, gemelo de `build_question_matrix.py`:
  - falla si el documento contradice su formato (identificador repetido,
    hecho o fuente inexistente, turno sin rol válido);
  - marca como no mostrable lo que depende de un dato `[VERIFICAR]`, lo que
    habla de la fuente en vez de atender («la página señala…») y las
    respuestas del usuario sordo con datos de ejemplo (placas, edades, años);
  - marca los hechos con dato confirmado pero vigencia sin probar
    (`vigenciaSinConfirmar`), que se muestran como «a confirmar»;
  - genera `assets/rag/escenarios_cbba.json` y con `--check` falla si está
    desactualizado.
- `test/rag_corpus_test.dart` protege esas reglas sobre el JSON generado.
- **Pendiente: las glosas.** Precalcularlas exige llamar a la Lambda
  Texto→LSB desplegada (Bedrock), una vez por frase del usuario sordo.

### Fase 1: recuperación local en la app, sin red (hecha)

- `lib/core/domain/rag/rag_corpus.dart`: modelo del corpus (solo lectura).
- `lib/core/domain/rag/rag_retriever.dart`: indexa cada pregunta del
  funcionario (turnos y variantes) con las respuestas del usuario sordo que
  la siguieron. Puntúa por parecido de texto pesado por idf (las palabras de
  pocos escenarios identifican más) y exige un mínimo (`minScore = 0.45`).
  Solo junta escenarios casi tan parecidos como el mejor (`margin = 0.1`).
  Es extractivo: ofrece respuestas tal cual del corpus aprobado.
- `lib/core/data/datasources/rag_corpus_datasource.dart` y
  `ragCorpusProvider` / `ragRetrieverProvider` en `injection.dart`: asset
  local, sin red. Un corpus ilegible no rompe nada.
- `rag_suggestions_provider.dart`: `ragSuggestionsFor` consulta el RAG para
  la pregunta pendiente del oyente, ya traducida, y `ragOutranksGraph` decide
  si el RAG pesa más que el grafo:
  - `noSafeRoute` (el grafo no sabe): parecido ≥ 0.45;
  - contexto o selector (el grafo solo reconoció un tema, p. ej.
    «denunciado» abre Denuncias): parecido ≥ 0.6;
  - preguntas del grafo: parecido ≥ 0.8 y, además, la pregunta documentada
    literal (≥ 0.99) o 0.15 más de seguridad que el grafo.

  Las tarjetas del RAG se ofrecen junto a las guiadas; la persona elige. Si
  el modelo de desempate cambia la ruta después, el RAG se vuelve a medir.
  Con 24 frases leídas por la Lambda real, esto corrigió 6 casos en que el
  grafo se adelantaba con una palabra suelta.
- `RagSuggestionsBar` en el chat, «Situaciones parecidas · institución»:
  cada tarjeta muestra la frase y su secuencia LSB. Al elegirla se envía
  enlazada a la pregunta y se lee en voz alta.
- `test/rag_retriever_test.dart`:
  - cada pregunta del corpus y sus variantes encuentran respuestas;
  - las preguntas de ventanilla de las capturas encuentran su trámite;
  - las frases sin relación no sugieren nada;
  - solo se ofrecen tarjetas aprobadas con glosas;
  - el RAG no entra cuando el grafo reconoce la pregunta.
- **Caso 2 (hecho):** «Preguntar sobre un trámite», debajo de
  «Iniciar/Responder con tarjetas LSB». Abre `RagTopicsSheet`: primero la
  institución y después, por trámite, las frases de apertura y las preguntas
  del usuario sordo (`RagCorpus.deafTopics`), con su LSB. Quedan fuera las
  frases que solo se entienden a mitad del diálogo («¿Entonces…?»,
  «¿Eso…?»). La frase elegida se envía y se lee en voz alta
  (`test/rag_topics_test.dart`).

### Crecimiento del corpus (hecho)

Guía de uso: `docs/negocio/rag/README.md`.

- **Varios archivos.** `tool/build_rag_corpus.py` lee todos los
  `docs/negocio/rag/escenarios/*.md`. Un identificador (escenario, hecho o
  fuente con otra URL) repetido entre archivos es error, con los dos
  archivos nombrados.
- **Documentos locales como fuentes.** Una fuente puede citar
  `documentos/<archivo>#p=N`. Se comprueba que exista y que la página esté
  dentro del PDF.
- **Ingesta de PDFs y `.md`** (`tool/rag_ingestar_documentos.py`):
  - extrae el texto por página;
  - genera un prompt con los siguientes identificadores libres por área y
    las reglas del prompt de investigación (sin duplicarlas);
  - avisa de los PDFs escaneados.
- **Datos que vencen.** Un hecho «hasta el AAAA-MM-DD» vencido marca sus
  turnos como no mostrables (`dato_vencido`) y el constructor avisa.
- **Un solo comando** (`tool/rag_actualizar.py`): valida, traduce a LSB solo
  lo nuevo y regenera el corpus.
- Pruebas: `tool/tests/test_build_rag_corpus.py`.

### Correcciones del recuperador (hechas)

- Cada oración se compara por separado: un saludo antes de la pregunta no la
  diluye, y dos preguntas en un mensaje aportan respuestas cada una.
- Tema de la conversación: el área de las preguntas anteriores del
  funcionario gana los empates en preguntas genéricas («¿Trajo su cédula?»)
  con una ventaja pequeña (`topicBonus = 0.05`), sin imponerse a una
  coincidencia claramente mejor.

### Fase 2: recuperación semántica en AWS (hecha, pendiente de desplegar)

- `aws/rag_consulta.py` indexa las mismas preguntas documentadas que la app
  (turnos del funcionario y variantes, con sus respuestas ofrecibles) y las
  compara por significado con Titan Text Embeddings V2 (256 dimensiones,
  normalizados).
  - Umbral `RAG_MIN_SIMILARITY` = 0.46, calibrado con la Lambda real
    (`tool/rag_calibrar.py`): paráfrasis bien encaminadas 0.48–0.79, frases
    sin relación hasta 0.444; acepta 11 de 15 paráfrasis y rechaza las 7
    frases sin relación.
  - Margen 0.05 y ventaja de tema 0.02. Solo junta respuestas de la
    institución de la mejor coincidencia.
  - Las frases del funcionario no mostrables no son claves: atraían ruido.
  - Es extractiva, igual que la fase 1.
- `lambda_function.py`:
  - `action: "consulta"`: una llamada a Titan por pregunta. Sin índice,
    sin Bedrock o ante un error responde `generated: false`, nunca un 500.
  - `action: "rag_indexar"`: 25 vectores por llamada, solo de textos del
    corpus empaquetado, así que no sirve para gastar Bedrock con textos
    arbitrarios.
  - El índice vive en S3 bajo una huella del corpus: un corpus nuevo no
    compara contra vectores viejos.
- `aws/deploy/build_package.py` empaqueta el módulo y el corpus;
  `tool/rag_indexar_embeddings.py` construye el índice tras desplegar.
- App: `RemoteRagDataSource` y `remoteRagSuggestionsProvider`. Solo se
  consulta si la búsqueda por palabras no encontró nada **y** el grafo no
  tiene una pregunta segura (`noSafeRoute` o contexto por palabra suelta).
  Una vez por turno; cualquier fallo es «sin sugerencias».
- Pruebas: `aws/tests/test_rag_consulta.py` (embedding falso con
  sinónimos) y `test/rag_remote_test.dart` (servidor simulado).

### Fase 3 (opcional): respuestas redactadas

Solo si la fase 1–2 no alcanza. Bedrock redacta una respuesta corta con los
fragmentos recuperados, citando la fuente. Pasa la verificación de cifras
(regla 2) y, si no, se muestra el fragmento original.

## 6. Pruebas

Mismo enfoque que `test/conversation_routing_exhaustive_test.dart`:

- cada turno de funcionario del corpus recupera su propio escenario en el
  primer lugar;
- paráfrasis escritas a mano recuperan el escenario correcto entre los 3
  primeros;
- ninguna sugerencia contiene un hecho sin fuente;
- una pregunta de dato en vivo (tipo B) nunca devuelve un dato como
  respuesta;
- las frases que el grafo ya resuelve no se desvían al RAG, porque el RAG solo
  entra cuando el grafo falla.

## 7. Decisiones abiertas

1. **Plazo de vencimiento de los datos** (propuesta: 6 meses).
2. **Revisión humana del corpus**: quién confirma los precios y requisitos.
   Idealmente, una llamada o visita a cada institución.
3. **Nuevos contextos del banco**: si un trámite del RAG se usa mucho
   (p. ej. Folio Real), conviene que después pase a ser un recorrido guiado
   del banco, más preciso que el RAG.
