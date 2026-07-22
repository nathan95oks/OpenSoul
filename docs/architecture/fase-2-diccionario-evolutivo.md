# Fase 2 — Diccionario evolutivo y backend unificado

**Fecha:** 2026-07-22 · **Rama:** Update1 · **Fase previa:** [fase-1-nucleo-conversacional.md](fase-1-nucleo-conversacional.md)

## Objetivo

Sacar el lexicón del código y convertirlo en un diccionario de datos con una
única fuente canónica, compartida por la app (ambas direcciones), el backend
y el futuro portal de validación. Es el prerequisito de las propuestas de la
comunidad (Fase 3) y del portal (Fase 4).

## Problema que corrige (P3 del diagnóstico)

El lexicón vivía **triplicado y hardcodeado**:

1. `local_cards_datasource.dart` — 153 tarjetas en Dart (563 líneas).
2. `GLOSS_LEXICON` en `aws/lambda_function.py` — morfología española.
3. `AVAILABLE_GLOSSES` en `aws/lambda_text_to_lsb.py` — señas del avatar.

Agregar una palabra exigía tocar tres archivos y redesplegar app + lambdas.

## Diseño implementado

### Fuente canónica única

`assets/dictionary/official_dictionary.json` — documento versionado
(`version`, `dialect`, `categoryOrder`, `entries[153]`) generado desde el
catálogo Dart original (migración única, fidelidad verificada por los tests
de cobertura). El mismo contrato viaja por el asset, la caché, la API y la
tabla DynamoDB.

### Entidad

`LsbCard` evolucionó a entrada del lexicón: gana `status`
(`official | community | pending` — enum `DictionaryStatus`), `animationFile`
(enlace al .glb del avatar; hoy `YO`, `POLICIA`, `ABOGADO`) y serialización
JSON. Las propuestas `pending` jamás son visibles en la app
(`DictionaryDocument.visibleEntries`).

### App — `lib/core/dictionary/`

```
domain/  dictionary_document.dart   contrato del documento
         lexicon_repository.dart    puerto (getDocument/getEntries/getCategories/refresh)
data/    asset_lexicon_datasource   JSON empaquetado (siempre disponible)
         lexicon_cache               caché en disco de la última sincronización (best-effort)
         remote_lexicon_datasource   GET al endpoint (LSB_DICTIONARY_API_URL por --dart-define)
         lexicon_repository_impl     offline-first: memoria ← caché(si version >) ← asset,
                                     con refresh remoto en segundo plano al primer uso
```

Reglas: la app **solo** aplica un documento remoto con `version` mayor;
sin endpoint configurado funciona 100 % local; sin red, la caché o el asset
respaldan siempre. `CardsRepositoryImpl` quedó como fachada por categorías
sobre `lexiconRepositoryProvider` (core/di); `LocalCardsDataSource` se eliminó.

### Backend — tabla `OpenSoul-Dictionary` (DynamoDB, on-demand)

| pk | sk | contenido |
|---|---|---|
| `META` | `DICTIONARY` | `version`, `dialect`, `categoryOrder` |
| `ENTRY` | `<status>#<gloss>` | campos de la entrada |
| `PROPOSAL` | `<isoDate>#<uuid>` | propuesta pendiente de la comunidad |

- **`lambda_dictionary.py` (nuevo):** `GET /dictionary` (documento completo,
  nunca `pending`) y `POST /dictionary/proposals` (almacena `pending`; jamás
  toca el diccionario ni la versión — aprobar es exclusivo del portal, Fase 4).
- **`seed_dictionary.py` (nuevo):** crea/puebla la tabla desde el JSON
  canónico del repo. Idempotente; no toca propuestas.
- **`lambda_text_to_lsb.py` (modificado):** el mapa glosa→animación ahora se
  lee de la tabla (`DICTIONARY_TABLE`, caché por proceso) y alimenta también
  el prompt de Bedrock; el set estático queda como base garantizada
  (dactilología, números) y fallback total. Una seña aprobada en el portal
  queda disponible para el avatar **sin redesplegar**.

### Flujo de una palabra nueva (visión completa)

```
Usuario propone (app, Fase 3) → POST /proposals → PROPOSAL pending
Validador aprueba (portal, Fase 4) → escribe ENTRY + sube META.version
App: refresh() detecta version mayor → caché → visible en tarjetas
Avatar: lambda_text_to_lsb lee la tabla → la seña se reproduce
```

## Decisiones y deuda declarada

1. **Versionado monótono simple** en vez de sync por deltas: el diccionario
   completo pesa ~60 KB; simplicidad > optimización prematura.
2. **`GLOSS_LEXICON` (morfología española de `lambda_function.py`) aún no
   migra** a la tabla: su estructura (roles, conjugaciones 1p/3p/formal) exige
   diseño lingüístico propio. Los tests de cobertura (`find_missing_lexicon`,
   `tool/find_missing_lambda_lexicon.dart`) siguen auditando que ninguna glosa
   del diccionario canónico quede fuera de él ni del motor local.
3. El refresco remoto ocurre al primer uso del diccionario por sesión; una
   sincronización periódica/push queda para cuando exista el portal.
4. Tests: `FakeLexiconRepository` (respaldado por el mismo JSON) para pruebas
   de widgets — `rootBundle` no resuelve bajo el reloj falso de `testWidgets`.

## Verificación

- `flutter analyze`: 0 errores/warnings · `flutter test`: 61/61.
- `dart run tool/find_missing_lambda_lexicon.dart`: cobertura completa
  (153 glosas del JSON ↔ motor local ↔ GLOSS_LEXICON).
- `python3 -m py_compile` sobre los tres lambdas: OK.
- Despliegue pendiente (requiere credenciales): pasos en `aws/README.md`.
