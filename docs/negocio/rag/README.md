# Corpus RAG: cómo hacerlo crecer

Situaciones reales de trámites en Cochabamba que la app ofrece como tarjetas
cuando el grafo de Conversación no reconoce lo que dijo el funcionario, y en
«Preguntar sobre un trámite». Diseño completo:
`docs/architecture/rag-conocimiento-institucional.md`.

## Carpetas

| Carpeta / archivo | Qué va aquí | ¿Se edita a mano? |
|---|---|---|
| `escenarios/*.md` | Escenarios de diálogo con el formato de `prompt_investigacion_chatgpt.md`. **Se añaden archivos; no hace falta tocar código.** | Sí (revisados) |
| `documentos/` | PDFs, `.md` o `.txt` oficiales: aranceles, reglamentos, fichas de trámites. | Sí (se dejan tal cual) |
| `documentos/extraido/` | Texto de cada documento por página. | No: lo genera la ingesta |
| `pendientes/` | Prompts listos para pegar en ChatGPT, uno por documento. | No: lo genera la ingesta |
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

## Añadir un documento oficial (PDF o `.md`)

1. Déjalo en `documentos/`.
2. Ejecuta:

   ```bash
   python tool/rag_ingestar_documentos.py
   ```

   - Extrae el texto por página (`documentos/extraido/`).
   - Escribe un prompt en `pendientes/<nombre>_prompt.md`. El prompt ya trae
     el texto del documento, los siguientes identificadores libres de cada
     área y las reglas de veracidad.
   - Un PDF escaneado (sin texto) avisa que hace falta OCR.
3. Pega el prompt en ChatGPT. Guarda la respuesta como
   `escenarios/<nombre>.md` y **revísala**.
4. Ejecuta `python tool/rag_actualizar.py`.

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
- Tarjetas sin glosas LSB.

## Pruebas

```bash
python -m pytest tool/tests -q                 # constructor e ingesta
python tool/build_rag_corpus.py --check        # corpus al día
flutter test test/rag_corpus_test.dart test/rag_retriever_test.dart test/rag_topics_test.dart
```
