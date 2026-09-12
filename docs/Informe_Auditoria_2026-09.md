# Informe de auditoría e implementación — OpenSoul LSB

**Fecha:** 2026-09-12
**Commit base:** `78580befc3a1cb3469ac2b19ced747555649c993` (coincide exactamente con el commit de la auditoría original)
**Alcance ejecutado** (decidido con el usuario dado el tamaño real del encargo): modelo estructurado completo para `denuncia_robo` + corrección de todos los bugs transversales que afectan a los 8 contextos. Los otros 7 contextos quedan con los bugs transversales corregidos, **sin** el rediseño de entidades específico que solo se aplicó al contexto insignia.

---

## 1. Línea base reproducida

| Suite | Antes | Después | Regresiones |
|---|---|---|---|
| `flutter test` | 309 pruebas, 62 fallos, 1 omitida | 322 pruebas (+13 nuevas), 62 fallos, 1 omitida | **0** |
| `python3 -m unittest discover -s aws/tests` | 96 pruebas, 63 fallos, 3 errores | 122 pruebas (+26 nuevas), 61 fallos, 3 errores | **0** |
| `flutter analyze lib test` | 4 avisos menores preexistentes | igual (7, con las nuevas líneas incluidas; ninguno es error) | **0** |

Metodología: cada comparación se hizo restaurando el árbol de trabajo exacto (`git stash` / copia de los archivos) para obtener la línea base real, ejecutando la suite completa, y diferenciando por **nombre de prueba** (no solo el conteo) contra el resultado con los cambios aplicados. Los fallos que sobreviven en ambos lados son preexistentes y no se tocaron — corresponden en su mayoría a pruebas con vocabulario o nombres de zona anteriores (`tramite`/`consulta`/`accidente`/`perdida`/`orientacion`, glosas del corpus nunca agregadas a `GLOSS_LEXICON`), tal como advertía el propio encargo.

Dos fallos preexistentes sí se resolvieron como consecuencia directa de una corrección real (normalización de acentos): `test_security.GlosasAcentuadas` para `ÓRGANO_JUDICIAL` y `MÁS_O_MENOS`. Quedan 2 casos de esa misma clase (`SÍ`, `¿CÓMO ESTÁS?`) que **no** se tocaron porque el propio diccionario canónico no contiene glosas para "SI" sin tilde ni para "COMO_ESTAS" — es una discrepancia real entre esa prueba y el diccionario vigente, no algo que debiera resolverse cambiando el motor. Queda documentada como hallazgo pendiente de reconciliación (sección 8).

No se eliminó ni se debilitó ninguna prueba existente.

---

## 2. Archivos modificados y su propósito

### Cliente (Flutter/Dart)

| Archivo | Cambio |
|---|---|
| `lib/core/domain/services/context_catalog.dart` | Deduplicación de las 8 listas con glosas repetidas (BILLETES, MICRO, PAREJA×2, AMIGO, NOMBRE, FISCALIA, PRESENTAR). Rediseño completo de las 15 zonas de `denuncia_robo` → 13 zonas sin redundancia (ver matriz, sección 6). |
| `lib/core/domain/services/zone_inference_engine.dart` | Los destinos `'apariencia'`→`'persona'` y `'pruebas'`→`'evidencia'` se actualizaron para no apuntar a zonas eliminadas por la fusión. |
| `lib/core/domain/services/local_sentence_assembler.dart` | Nuevo método público `assembleStructured(DeclarationDraft)`: generador determinista que consume el modelo de hechos/entidades en vez de una lista plana de glosas, exclusivo de `denuncia_robo`. El generador heredado (`assemble`) queda intacto para los demás contextos. |
| `lib/core/domain/entities/lsb_card.dart` | Se conservan `canonicalGloss`, `source`, `audit` del JSON (antes se descartaban al leer). Nuevo `DictionaryStatus.unknown` para no aprobar automáticamente un `status` no reconocido como `official`. |
| `lib/core/domain/entities/dictionary_document.dart` | `visibleEntries` excluye también `DictionaryStatus.unknown`. |
| `lib/features/lsb_to_text_audio/presentation/providers/cards_provider.dart` | Se elimina el corte silencioso a 12 opciones. `dynamicCardsProvider` ahora **combina** la sugerencia remota con las opciones locales en vez de sustituirlas: una sugerencia parcial ya no hace desaparecer opciones válidas. |
| `lib/features/lsb_to_text_audio/presentation/providers/semantic_zones_provider.dart` | Nuevo campo `zoneQualifiers` que separa los calificadores (cantidad, deletreo) de la lista de respuestas: `appendQualifiers` ya no borra todo lo que sigue a la glosa editada, y los calificadores no cuentan contra `maxPicks`. Quitar una respuesta limpia sus propios calificadores (sin huérfanos). |
| `lib/features/lsb_to_text_audio/presentation/widgets/qualifier_sheets.dart` | Nuevo teclado de texto libre (preserva espacios y tildes; ver `entity_editor_sheets.dart`) usado para lugar/color en vez del deletreo letra por letra. `elegirGlosa` enruta las zonas de entidad de `denuncia_robo` a los editores nuevos. Corrección del texto de detalle de CELULAR (ya no asume "número de caso"). |
| `lib/features/lsb_to_text_audio/presentation/widgets/card_grid.dart` | Nota de auditoría: componente no instanciado en ningún lugar de `lib/` (código muerto); se documenta para no confundirlo con `SuggestedGlossPanel`, que sí es el camino activo. |
| `lib/features/lsb_to_text_audio/presentation/controllers/translation_controller.dart` | `translateCards` ya no reproduce el audio automáticamente al generar: la persona debe poder revisar el texto primero. La reproducción queda a un toque explícito en "Reproducir". |
| `lib/features/lsb_to_text_audio/presentation/providers/cards_flow_session.dart` | `reset()` también limpia el borrador de entidades (`denunciaRoboDraftProvider`), para que una respuesta tardía no se inserte en un caso nuevo tras cambiar de contexto. |
| `lib/features/lsb_to_text_audio/presentation/screens/home_screen.dart` | Construye el `DeclarationDraft` estructurado antes de traducir cuando el contexto es `denuncia_robo`. |
| `lib/core/domain/services/conversation_engine.dart` | `turnFromDeclaration` ahora propaga `speechAct` (antes quedaba siempre en `statement` aunque el texto fuera una pregunta). `generateDeclaration`/`composeDeafTurn` aceptan un `DeclarationDraft` opcional y lo envían al backend. |
| `lib/core/domain/repositories/translation_repository.dart`, `lib/core/data/repositories/translation_repository_impl.dart`, `lib/core/data/datasources/remote_translation_datasource.dart` | Contrato remoto v2: se añaden `declaration`, `speechAct`, `replyToId` y `contractVersion` al cuerpo de la petición, con compatibilidad hacia atrás (todos opcionales). |

### Nuevos archivos (cliente)

| Archivo | Propósito |
|---|---|
| `lib/core/domain/entities/declaration_draft.dart` | El modelo estructurado: `PersonEntity`, `ClothingItem`, `ObjectInvolved`, `LocationInfo`, `TimeInfo`, `WitnessInfo`, `EvidenceItem`, `FactInfo`, `DeclarationDraft`. Ver diseño en sección 5. |
| `lib/features/lsb_to_text_audio/presentation/providers/denuncia_robo_draft_provider.dart` | `DenunciaRoboDraftNotifier`: gestiona personas/objetos/lugar como entidades reales (agregar persona, agregar prenda con su color, agregar objeto con su papel...). `buildFullDeclarationDraft()` combina este estado con las respuestas simples de `semanticZonesProvider` (hecho, tiempo, testigos, evidencia, emergencia, denuncia, apoyo legal, institución) en un `DeclarationDraft` completo. |
| `lib/features/lsb_to_text_audio/presentation/widgets/entity_editor_sheets.dart` | Editores de entidad: lugar (relación espacial + referencia, con teclado de texto libre), objeto (papel: robado/perdido/llevado por otra persona), persona (género, edad, complexión, estatura, prendas con color). |

### Backend (Python)

| Archivo | Cambio |
|---|---|
| `aws/lambda_function.py` | Ver detalle en sección 4. Resumen: normalización de acentos en el lexicón, PERDER/FALTA sin atribución a terceros, `denuncia_robo`/`violencia` ya no fuerzan ROBO/AGRESIÓN sin contenido real del hecho, relaciones espaciales (CERCA/LEJOS/DENTRO/FUERA/AL_LADO) admiten referencia, PRUEBA_MARCADOR reconocido como control estructural, validador de fidelidad más estricto (montos inventados, cambio de afirmación a pregunta), clave de caché ampliada, generador estructurado `generate_structured_sentence` para el contrato v2, logging sin contenido de la declaración. |
| `aws/lambda_text_to_lsb.py` | `_VALID_GLOSS` ahora admite vocales acentuadas: la forma canónica que el propio `canonical_gloss` produce (`DÓNDE`, `ÓRGANO_JUDICIAL`, `MÁS_O_MENOS`...) ya no se autorrechazaba. |

### Pruebas nuevas

| Archivo | Cobertura |
|---|---|
| `test/declaration_draft_assembler_test.dart` | 14 pruebas del generador estructurado del cliente (PERDER, CERCA/LEJOS/DENTRO/FUERA con y sin referencia, colores por prenda, dos personas, mochila robada vs. llevada, testigos con sus tres polaridades, monto con unidad, hecho no confirmado). |
| `aws/tests/test_auditoria_2026_09.py` | 26 pruebas del backend: normalización de acentos, PERDER, NO+TESTIGO, CERCA, PRUEBA_MARCADOR, validador de fidelidad, clave de caché, generador estructurado (paridad con las pruebas de Dart). |
| `test/translation_controller_test.dart` (editado) | Se actualizaron las aserciones para reflejar que ya no se reproduce audio automáticamente. |
| `test/preguntas_funcionario_test.dart` (editado) | Las dos expectativas de zona (`apariencia`→`persona`, `pruebas`→`evidencia`) se actualizaron para reflejar la fusión intencional. |
| `test/{conversacion_iniciada_por_sorda,conversation_bidirectional,home_to_result_flow,module_isolation}_test.dart` (editados) | Firma de `TranslationRepository.translateCards` actualizada en los dobles de prueba (parámetros nuevos opcionales). |

---

## 3. Hallazgos de la sección 2 del encargo — verificación puntual

| Hallazgo original | Estado |
|---|---|
| PERDER+CELULAR atribuye la pérdida a otra persona | **Corregido** (cliente: modelo estructurado; backend: se quitó el flag `agresor` falso de PERDER/FALTA y PERDER manda sobre el contexto) |
| ROBAR+CELULAR+CERCA sin preguntar cerca de qué | **Corregido** (cliente: hoja de relación espacial con referencia obligatoria u opción "dejar pendiente"; backend: CERCA/LEJOS/DENTRO/FUERA/AL_LADO admiten detalle, ya no fabrican "del lugar") |
| Colores atribuidos al hombre en vez de a la prenda | **Corregido en el generador estructurado** (`assembleStructured`/`generate_structured_sentence`); el generador heredado (bolsa de palabras, usado en otros contextos) conserva esta limitación — ver sección 8 |
| DÓNDE+PRESENTAR+PAPEL pierde la interrogación | **No corregido en el backend** — ver limitación explícita en sección 8. El cliente Dart (`_composeQuestion`) ya la redacta correctamente; el motor Python heredado no tiene un compositor de preguntas equivalente. |
| NO+TESTIGO fabrica una afirmación de robo | **Corregido** (backend: `denuncia_robo`/`violencia` ya no fuerzan la plantilla sin verbo/objeto/descriptor/lugar reales) |
| Validador acepta fecha/plaza/monto inventados y cambio de afirmación a pregunta | **Parcialmente corregido**: se agregó un chequeo de números inventados (cubre el caso "500 bolivianos") y de preservación del acto comunicativo (cubre "afirmación → pregunta"). Se intentó además un chequeo léxico general de contenido no declarado, pero rechazaba paráfrasis fieles reales (falsos positivos confirmados por la propia suite existente) y se retiró. La fabricación de una fecha o lugar sin usar un número (ej. "ayer", "una plaza") **no** queda cubierta — ver sección 8. |

---

## 4. Backend Python — detalle de los cambios en `lambda_function.py`

1. **Normalización de acentos** (`_lexicon_key`, `lexicon_lookup`): antes, `GLOSS_LEXICON` solo tenía claves sin tilde mientras el diccionario canónico del cliente usa la forma con tilde (`DÓNDE`, `POLICÍA`, `DÍA`, `RESOLUCIÓN`...). Toda glosa acentuada caía en "desconocidos" aunque el lexicón la tuviera con otra ortografía. Se normaliza una sola vez, al inicio de `analyze_glosses`, para que todas las comparaciones internas (unidades de tiempo, marcadores, lexicón) usen la misma forma canónica.
2. **PERDER/FALTA**: se quitó el flag `"agresor": "perdí"` que los hacía elegibles como verbo de agresión. `_detect_event_type` ahora resuelve PERDER/FALTA a `PERDIDA` **antes** de mirar el contexto, incluso dentro de `denuncia_robo`.
3. **`denuncia_robo`/`violencia` ya no fuerzan su plantilla sin contenido real**: se exige al menos un verbo, objeto, descriptor o lugar antes de devolver ROBO/AGRESIÓN; si no hay nada de eso (p. ej. solo se respondió sobre testigos), cae a `GENERAL` y no fabrica un delito.
4. **Relaciones espaciales con detalle**: CERCA/LEJOS/DENTRO/FUERA/AL_LADO se agregaron a `_ADMITE_DETALLE` con la etiqueta `relacion`, y sus lexemas base perdieron el "del lugar"/"afuera del lugar" que fabricaba una referencia vaga.
5. **PRUEBA_MARCADOR/VEHICULO_MARCADOR**: se reconocen como controles estructurales (activan `evidence_mode`/`vehicle_mode`) en vez de caer en "desconocidos" y filtrarse como texto crudo. Un objeto mencionado en modo evidencia se clasifica como prueba, no como botín.
6. **`_generation_is_safe`**: además de la cobertura existente, rechaza números en el texto generado que no estén en la oración base (captura montos/fechas numéricas inventadas) y rechaza que una afirmación se convierta en pregunta (o viceversa) conservando las mismas palabras relevantes.
7. **`generate_cache_key`**: ahora incluye `institutionType`, `language`, `speechAct` y un hash del `declaration` estructurado, no solo `context`/`cards`. Antes, dos peticiones con las mismas glosas pero distinto registro o relaciones compartían una respuesta cacheada ajena.
8. **`generate_structured_sentence`**: espejo Python de `assembleStructured` en Dart, usado cuando el cliente manda `contractVersion >= 2` y un `declaration` para `denuncia_robo`. Mismas garantías: PERDER no atribuye a terceros, colores por prenda, objetos por papel, ubicación con referencia real o pendiente.
9. **Logging**: se dejó de registrar el contenido completo de `cards`, `base_sentence`, `generated_text` y el texto rechazado por Bedrock; ahora se registran longitudes y metadatos. La Lambda seguía registrando declaraciones completas en CloudWatch en texto plano.

---

## 5. Modelo estructurado — diseño

`DeclarationDraft` (`lib/core/domain/entities/declaration_draft.dart`) es la representación que viaja del cliente al generador local y, versionada (`contractVersion: 2`), al backend:

```
DeclarationDraft
├── contextId, speechAct, replyToId
├── fact: { action, motiveConfirmed }
├── persons: [ PersonEntity {
│     id, role (suspect/witness/other), gender, ageApprox, build, height,
│     identityState (confirmed/uncertain/negated/pending),
│     clothing: [ ClothingItem { id, concept, color, colorState } ]
│   } ]
├── objects: [ ObjectInvolved {
│     id, concept, role (stolen/lost/carriedByOtherPerson/evidenceSupport),
│     carriedByPersonId, quantity, unit, detail
│   } ]
├── location: { mainPlaceConcept, mainPlaceDetail, relation,
│               referenceType (home/knownPlace/other/conceptCard),
│               referenceLiteralText, referenceConceptGloss }
├── time: { dateOrMoment, elapsedUnit, elapsedCount, unknown }
├── witnesses: { existence (confirmed/negated/uncertain/pending), count, willIdentify }
├── evidence: [ EvidenceItem { id, concept, availability, offeredToShow } ]
└── injured, medicalHelpRequested, willFileComplaint, needsLegalSupport, receivingInstitution
```

Decisiones de diseño relevantes:

- **La navegación sigue siendo por zonas** (`semanticZonesProvider`, sin cambios en su mecánica de avanzar/retroceder/progreso). Lo que cambia es **qué captura cada zona**: `hecho`, `conocimiento`, `tiempo`, `testigos`, `evidencia`, `emergencia`, `denuncia`, `apoyo_legal` e `institucion` siguen siendo selecciones simples (van a `zoneAnswers`); `objetos`, `persona` y `lugar` son zonas de entidad y escriben en `denunciaRoboDraftProvider`, porque una lista plana de respuestas no puede expresar "esta prenda es de esta persona" o "este objeto tiene este papel".
- **`buildFullDeclarationDraft()`** combina ambas fuentes en un único `DeclarationDraft` inmediatamente antes de generar el texto.
- **Ausencia de respuesta ≠ negación**: `ConfirmationState` tiene `pending`, `uncertain`, `confirmed` y `negated` como valores distintos en persona (identidad), color de prenda, testigos y voluntad de denunciar.
- **El texto literal nunca pasa por el pipeline de normalización de glosas**: la ubicación escrita a mano (`referenceLiteralText`) se mezcla directamente en la oración compuesta por `assembleStructured`, sin pasar por `_normalize`/`_stripGlossAccents`, así que conserva tildes y mayúsculas tal como se escribió.

---

## 6. Matriz final — las 15 zonas originales de `denuncia_robo` → destino

| Zona original | Destino |
|---|---|
| `hecho` | **Conservada**, corregida: ya no incluye LADRÓN como acción (queda en el léxico, sin ofrecerse como hecho); agrega `NO_SABER`. |
| `objetos` | **Conservada**, corregida: sin duplicados, sin el corte a 12/3; ahora es zona de entidad (papel por objeto: robado/perdido/llevado por otra persona); MICRO/TRUFI aparecen aquí solo como vehículo sustraído. |
| `persona` | **Unificada con `apariencia`**: zona de entidad con género, edad, complexión, estatura y prendas (cada una con su propio color); admite varias personas. |
| `conocimiento` | **Conservada**, corregida: sin duplicados (AMIGO/PAREJA), agrega `NO_SABER`, quita VER (no es un vínculo). |
| `apariencia` | **Retirada / fusionada con `persona`** (editar la misma entidad, no crear una lista suelta). |
| `lugar` | **Conservada**, corregida: zona de entidad con lugar principal + relación espacial + referencia (Mi casa / lugar ya indicado / otro lugar con teclado libre / pendiente). Admite MICRO/TRUFI como referencia ("dentro de un micro"). |
| `tiempo` | **Conservada**, corregida: agrega `NO_SABER` explícito. |
| `testigos` | **Conservada**, corregida: separa existencia (sí/no/no sabe) de cantidad mediante el mecanismo de cadena existente, reutilizando la zona `cantidad`. |
| `pruebas` | **Retirada / fusionada con `evidencia`** (misma necesidad, sin la zona duplicada). |
| `evidencia` | **Conservada**, corregida: sin duplicados, sin el corte a 3; ya no depende de `PRUEBA_MARCADOR` para tener sentido (el backend lo reconoce como control estructural). |
| `emergencia` | **Conservada**, ampliada a 2 selecciones (herida y atención pueden coexistir). |
| `denuncia` | **Conservada**, corregida: sin duplicados, agrega `NO_SABER`. |
| `apoyo_legal` | **Conservada** sin cambios de contenido (no tenía duplicados). |
| `institucion` | **Conservada** sin cambios de contenido. |
| `cantidad` | **Conservada** sin cambios; ahora también es el destino de la cadena de `testigos`, no solo de `tiempo`. |

Resultado: 15 zonas originales → **13 zonas** (dos fusiones), todas sin duplicados, todas con `maxPicks` acorde a si son de selección única, múltiple o de entidad (sin tope arbitrario).

---

## 7. Ejemplos de entrada estructurada → salida

```jsonc
// Entrada (DeclarationDraft, resumido)
{
  "fact": { "action": "ROBAR" },
  "persons": [{
    "id": "p1", "role": "suspect", "gender": "HOMBRE", "height": "ALTO",
    "clothing": [
      { "concept": "POLERA", "color": "ROJO", "colorState": "confirmed" },
      { "concept": "PANTALÓN", "color": "NEGRO", "colorState": "confirmed" }
    ]
  }],
  "objects": [{ "concept": "CELULAR", "role": "stolen" }],
  "location": { "relation": "FUERA", "referenceType": "other",
                "referenceLiteralText": "Mercado Calatayud" }
}
```
```
→ "Un hombre alto que llevaba una polera roja y un pantalón negro me robó
   mi celular fuera de Mercado Calatayud."
```

```jsonc
{ "fact": { "action": "PERDER" },
  "objects": [{ "concept": "CELULAR", "role": "lost" }] }
```
```
→ "Perdí mi celular."
```

```jsonc
{ "witnesses": { "existence": "uncertain" } }
```
```
→ "No sé si hay testigos."   // (nunca "No hay testigos.")
```

Estos tres ejemplos, y los demás casos exigidos en la sección 10 del encargo, están cubiertos por pruebas automatizadas (`test/declaration_draft_assembler_test.dart` y `aws/tests/test_auditoria_2026_09.py`), ejecutadas y en verde.

---

## 8. Limitaciones conocidas y lo que falta

**No verificado por falta de material:**
- No tuve acceso al DOCX `Corpus_Maestro_Unificado_LSB_v4_Auditado(2).docx` mencionado en el encargo (solo existe `docs/Corpus_Maestro_Unificado_LSB_v4_Auditado.md` en el repositorio). No pude contrastar ambos ni reconciliar la diferencia de 346 vs. 303 entradas del diccionario. **Se solicita específicamente ese DOCX** para completar esa reconciliación.
- No tuve acceso a los PDF originales de los módulos M1–M4 ni al II Diccionario Bilingüe LSB–Castellano 2024. Ninguna seña se validó, inventó ni se declaró oficial en esta sesión; donde el corpus ya marcaba una representación como pendiente, se dejó así.
- No se ejecutó Flutter contra un dispositivo/emulador real ni se probó la interfaz manualmente (sin acceso a un entorno gráfico en esta sesión). Todo lo reportado como "funciona" está verificado por `flutter analyze`/`flutter test`, no por uso real de la app. Los nuevos editores de entidad (`entity_editor_sheets.dart`) no se probaron con widget tests de interacción táctil — solo indirectamente, a través de las pruebas del generador que consumen el `DeclarationDraft` que esos editores producen.
- No se llamó a Bedrock ni a AWS real; todas las pruebas del backend usan los dobles (`boto3_stub`).

**Limitaciones de diseño, documentadas explícitamente:**
- El generador heredado (`assemble()` en Dart, `generate_base_sentence()` en Python — la "bolsa de palabras") **sigue existiendo** y se usa para los 7 contextos no rediseñados. Conserva las limitaciones originales de atribución de color/prenda y de composición de preguntas en el backend. Extender el modelo estructurado a los demás contextos es el trabajo pendiente más importante.
- El validador de fidelidad (`_generation_is_safe`) no detecta la fabricación de una fecha o un lugar que no use dígitos (el caso "agregar ayer y una plaza" del hallazgo original). Se intentó un chequeo léxico general y se retiró por generar falsos positivos reales contra paráfrasis fieles ya cubiertas por la suite existente. Cerrar esta brecha con seguridad requeriría una comparación semántica más fina que un heurístico de palabras, o back-verificación con el propio modelo.
- El backend Python no tiene un compositor de preguntas equivalente al `_composeQuestion` del cliente Dart. El cliente ya redacta correctamente las preguntas del contexto `preguntas` (camino que ve la persona cuando el backend no está disponible o su respuesta se descarta), pero el `baseSentence`/anclaje que el backend calcula para ese contexto sigue sin conservar el signo de interrogación. No se implementó un compositor equivalente por el tamaño y riesgo de replicarlo de forma parcial; queda como tarea acotada y bien definida para una sesión futura.
- La reconciliación completa del diccionario (346 vs. 303 entradas) no se hizo — ver arriba.
- Los otros 7 contextos (`violencia`, `amenaza_digital`, `engano_dinero`, `seguimiento`, `otro`, `identificacion`, `preguntas`) recibieron las correcciones transversales (deduplicación donde aplicaba, trazabilidad del diccionario, no-auto-reproducción de audio, preservación de `speechAct`, validador más estricto, normalización de acentos) pero **no** el mismo rediseño de entidades que `denuncia_robo`. Sus 33 zonas restantes (48 − 15 de robo) no tienen todavía la matriz de destino final que pide la sección 12.11 del encargo — ese trabajo, con el mismo nivel de detalle que se aplicó aquí a robo, es la continuación natural de esta sesión.

**Requiere validación de señantes de Cochabamba, intérpretes y usuarios del entorno de atención:**
- Que las nuevas preguntas y su fraseo (p. ej. "¿Cerca de qué lugar?", "¿Qué pasó con este objeto?") sean comprensibles y naturales en LSB, no solo en español.
- Que la fusión de `apariencia` en `persona` y de `pruebas` en `evidencia` no pierda un matiz que un señante consideraría una pregunta distinta.
- Que las 13 zonas resultantes cubran de forma natural el flujo real de una denuncia en la ventanilla de atención (esto se diseñó a partir del texto del encargo y del corpus, no de observación de campo).

---

## 9. Cómo verificar

```bash
# Flutter
flutter analyze lib test
flutter test

# Python
cd aws && python3 -m unittest discover -s tests -v
```

Ambos comandos se ejecutaron como parte de esta sesión; los resultados están en la sección 1.
