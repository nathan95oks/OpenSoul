# Corpus RAG: cómo hacerlo crecer

Situaciones reales de trámites en Cochabamba que la app ofrece como tarjetas
cuando el grafo de Conversación no reconoce lo que dijo el funcionario, y en
«Preguntar sobre un trámite». Diseño completo:
`docs/architecture/rag-conocimiento-institucional.md`.

## Carpetas

| Carpeta / archivo | Qué va aquí | ¿Se edita a mano? |
|---|---|---|
| `escenarios/*.md` | **Solo** escenarios de diálogo con el formato de `prompt_investigacion_chatgpt.md`. Un PDF, un `.txt`, la copia como texto de un PDF o un texto extraído aquí es un error del constructor (antes se ignoraba sin avisar). | Sí (revisados) |
| `documentos/` | PDFs, `.md` o `.txt` originales: aranceles, reglamentos, fichas de trámites o documentos de escenarios. | Sí (se dejan tal cual) |
| `documentos/extraido/` | Texto extraído de cada documento por página, para leer y citar. **No** son escenarios. | No: lo genera la ingesta |
| `pendientes/` | Prompts para ChatGPT (documento oficial) o borradores de escenarios (documento de escenarios), uno por documento. | No: lo genera la ingesta; se revisa |
| `glosas_cache.json` | Glosas LSB ya traducidas por la Lambda Texto→LSB. | No |
| `prompt_investigacion_chatgpt.md` | Reglas de veracidad, estilo y formato. Es la única fuente: la ingesta las copia. | Sí |

El corpus que usa la app (`assets/rag/escenarios_cbba.json`) se genera; nunca
se edita.

## Añadir escenarios que ya tienes en `.md`

1. Guarda el archivo en `escenarios/` (cualquier nombre terminado en `.md`).
2. Ejecuta:

   ```bash
   python tool/rag_actualizar.py
   ```

   Valida todo, traduce a LSB solo las frases nuevas (Lambda Texto→LSB de
   `.env`) y regenera el corpus.
3. Si falla, dice qué corregir y dónde (archivo y línea). Por ejemplo:
   - un identificador ya usado en otro archivo;
   - un hecho o una fuente que no existe;
   - un documento o una página que no existe.

## Añadir un documento (PDF o `.md`)

Detectar formato → extraer texto → normalizar y revisar → guardar Markdown →
preparar escenarios → validar → actualizar corpus y glosas.

1. Deja el **archivo original** en `documentos/` (no en `escenarios/`). No lo
   abras ni lo guardes como texto: la copia como texto de un PDF
   (`%PDF-1.4 … /BaseFont … endobj` con «�») perdió sus datos comprimidos y
   se rechaza.
2. Ejecuta:

   ```bash
   python tool/rag_ingestar_documentos.py
   ```

   - Reconoce el formato por su firma (`%PDF-`), no por la extensión.
   - Extrae el texto por página y lo normaliza sin cambiar lo que dice
     (Unicode NFC, espacios; conserva tildes, ñ, ¿ ¡, cifras y nombres).
   - **Se detiene** sin escribir nada si encuentra caracteres de reemplazo
     (�), de control, de uso privado, mojibake (`Ã¡`) o sintaxis de PDF, y
     dice la página, la línea y la columna. Lo perdido no se reconstruye:
     hace falta el original. Un PDF escaneado (sin texto) pide OCR.
   - Guarda el texto en `documentos/extraido/<nombre>.md`.
   - Un **documento oficial** da un prompt en `pendientes/<nombre>_prompt.md`
     con el texto, los siguientes identificadores libres y las reglas de
     veracidad. Pégalo en ChatGPT y guarda la respuesta como borrador.
   - Un **documento de escenarios** (una página por escenario,
     «ESC-DDRR-05 / …») da el borrador `pendientes/<nombre>_escenarios.md`,
     ya validado junto al corpus activo. Cada escenario cita su página
     (`- **Documento:** documentos/<archivo>#p=N`).
3. **Revisa** el borrador y muévelo a `escenarios/`.
4. Ejecuta `python tool/rag_actualizar.py`: traduce a LSB las frases nuevas
   (respuestas **y** preguntas) y no termina bien mientras falte alguna.

El script devuelve 1 si algún documento no se pudo usar; el corpus activo no
cambia.

## Ramificaciones y composición (opcional, en el escenario)

Los pasos de un trámite van en el orden del diálogo y no dependen unos de
otros salvo que el escenario lo declare. Una nota narrativa («Escenarios
posibles: sin cédula, pasar a…») **no** crea condiciones.

```markdown
### Ramificaciones

- **Turno 5:** si Turno 3 es negado o desconocido
- **Turno 7:** si Turno 3 = «Sí, traje mi cédula.»; si Turno 5 es afirmado

### Composición

- **Turno 9:** «Traje {items}.»
```

- Un turno solo puede depender de turnos **anteriores** del funcionario
  (así no hay ciclos). Estados: `afirmado`, `negado`, `desconocido`; deben
  existir entre sus respuestas documentadas. Una respuesta citada entre «»
  debe estar documentada tal cual.
- Al cambiar una respuesta en la app, el flujo guiado borra las respuestas
  de las preguntas que dejaron de verse.
- Si la pregunta de la que depende un paso no se ofrece (sin glosas), el
  paso tampoco entra en el recorrido (no aparece siempre).
- Una pregunta abierta («¿Qué documentos trajo?») ofrece tarjetas sueltas
  (selección múltiple) con las señas de una misma zona que aparecen en sus
  respuestas **afirmativas**; la composición da la frase con que se juntan.
  Una pregunta de sí o no no se contesta juntando tarjetas.

Los escenarios nuevos citan el documento como fuente
(`documentos/arancel.pdf#p=2`). El constructor comprueba que el archivo
exista y que la página esté dentro del PDF.

## Búsqueda por significado (Lambda)

La Lambda LSB→Texto/Audio lleva empaquetado el mismo corpus. Después de
cambiar escenarios:

1. `python aws/deploy/build_package.py` y sube el ZIP (ver
   `aws/deploy/README.md`, sección 0).
2. `python tool/rag_indexar_embeddings.py` para reconstruir el índice.

Mientras tanto, la app sigue con la búsqueda por palabras.

## Lo que el constructor nunca deja llegar a la persona sorda

- Turnos que dependen de un dato `[VERIFICAR]` o **vencido**: un hecho con
  «hasta el AAAA-MM-DD» deja de mostrarse al pasar esa fecha, y el
  constructor avisa.
- Frases que hablan de la fuente en vez de atender («la página señala…»).
- Respuestas del usuario sordo con datos de ejemplo (placas, edades, años,
  montos).
- Tarjetas sin glosas LSB, o con elementos que no son glosas: una frase en
  español guardada como glosa («SÍ, LA TRAJE») o una seña que no está en el
  catálogo ni es un compuesto de la Lambda (COMO_ESTAS, NO_SABER…). Valen
  las señas del catálogo, letras y cifras, y `SENA_PENDIENTE:PALABRA`.

## Pruebas

```bash
python -m pytest tool/tests -q                 # constructor, ingesta, ramas (sin red)
python tool/build_rag_corpus.py --check        # corpus al día
flutter test test/rag_corpus_test.dart test/rag_retriever_test.dart test/rag_topics_test.dart   test/rag_tramites_test.dart test/rag_ramificaciones_test.dart
```

El banco de prueba `test/fixtures/rag_tramite_ramificado.json` sale de
`tool/tests/fixtures/escenario_ramificado.md`; si cambia el generador:

```bash
REGENERAR_FIXTURES=1 python -m pytest tool/tests/test_rag_ingesta_y_ramas.py -q
```
