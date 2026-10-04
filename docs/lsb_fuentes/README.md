# Fuentes LSB: módulos y diccionarios

De aquí sale el **léxico LSB válido** (`aws/lexico_lsb.json`): las únicas
señas que pueden entrar al corpus RAG desde un documento. Lo genera:

```bash
pip install -r tool/requirements.txt
python tool/build_lexico_lsb.py           # valida y escribe
python tool/build_lexico_lsb.py --check   # ¿está al día? (lo usa rag_actualizar)
```

## Carpetas

| Carpeta | Qué va | Cómo se lee |
|---|---|---|
| `modulos/` | `M1.pdf` … `M4.pdf`: «Curso de enseñanza de la LSB», Ministerio de Educación (minedu.gob.bo). Con estos nombres exactos. | Su «Índice de palabras y señas»: cada tema con su página y sus palabras numeradas. |
| `diccionarios/` | Un diccionario por archivo, en **CSV** o **JSON**. El nombre del archivo (sin extensión) es el nombre de la fuente: `D2024.csv`. | Columnas abajo. |
| `diccionarios/D2024.pdf` | **II Diccionario Bilingüe LSB–Castellano** (Ministerio de Educación y FEBOS, 2024). | `tool/extraer_diccionario_lsb.py` lo pasa a `D2024.csv` + `D2024.huella`. |

Además entra siempre el catálogo de la app (`aws/catalogo_senas.json`, 346
señas ya auditadas contra M1–M4 y el II Diccionario 2024).

### Formato de un diccionario

```csv
palabra,pagina,glosa,nota
Robar,499,,
Testigo,557,TESTIGO,
Esconder / Ocultar,120,,
```

- `palabra` y `pagina`: obligatorias. Varias formas con «/» («Bonito/a»
  da bonito y bonita).
- `glosa`: opcional; si falta, sale de la palabra (`Buenos días` →
  `BUENOS_DÍAS`) o de la seña del catálogo que se escribe igual.
- Un diccionario en **PDF** se extrae una vez (tarda minutos) y vale por su
  CSV:

  ```bash
  python tool/extraer_diccionario_lsb.py   # escribe D2024.csv y D2024.huella
  python tool/build_lexico_lsb.py
  ```

  Hoy reconoce la maquetación del II Diccionario 2024
  («499.Robar: v. …»). Se detiene si falta o se repite un número de
  entrada, si el texto está dañado o si una seña que el catálogo cita del
  diccionario («D2024-499» → ROBAR) no es la palabra de esa entrada. Si el
  PDF cambia, `build_lexico_lsb.py` lo detecta por la huella y pide volver
  a extraerlo. Otro diccionario con otra maquetación (o escaneado, que pide
  OCR) necesita su propio extractor.

## Qué valida antes de escribir

Se detiene, sin tocar el léxico activo, si:

- falta un módulo o no es un PDF legible;
- no encuentra el índice o da menos de 10 temas / 150 palabras (no se leyó
  entero);
- el texto del índice trae caracteres dañados (los mismos controles que la
  ingesta de documentos);
- un tema salta números (se perdió una palabra al extraer);
- un diccionario no tiene `palabra` y `pagina` o trae una glosa mal escrita.

## Cómo se usa el léxico

1. **Filtro.** Una glosa que no está en el léxico no se ofrece.
2. **Forma 1: la palabra existe.** Si una palabra se escribe igual que una
   seña del léxico, es una *candidata*. No entra solo por cómo se escribe:
   Bedrock confirma que el sentido de la frase es el del tema de la seña
   («mi fiscal» ≠ FISCAL de M3 · *Escuela*, «escuela fiscal»).
3. **Forma 2: la palabra no existe.** Bedrock propone un sinónimo o una
   combinación de hasta 3 señas del léxico que la explican
   (FISCALÍA → OFICINA + FISCAL), y la vuelta al español confirma que la
   frase dice lo mismo.

Las tarjetas de respuesta de la persona sorda son siempre una sola seña de
este léxico: una palabra sin seña confirmada nunca llega a una tarjeta.

## Lo que el léxico no garantiza

- **Animación.** Que una seña esté en M1–M4 no significa que el avatar la
  tenga: el `.glb` trae ~157 clips. `animacion: false` en el léxico; en la
  app se ve como marcador.
- **Variante regional.** M1–M4 son nacionales; la app es de Cochabamba.
