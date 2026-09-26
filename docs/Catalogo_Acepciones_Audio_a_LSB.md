# Catálogo de acepciones — módulo Audio/Texto → LSB

Este documento sostiene la auditoría 2026-09 del módulo Audio/Texto → LSB
(`aws/lambda_text_to_lsb.py` y `lib/features/audio_to_lsb/**`). Su objetivo es
que ampliar la desambiguación de términos polisémicos, o revisar una
equivalencia, no vuelva a repetir el error que motivó esta auditoría:
sustituir un concepto por otro parecido en español, o forzar una seña
"parecida" porque no hay una exacta, sin que nada lo declare.

No es una lista cerrada. Es la única fuente que debería consultarse antes de
tocar `GLOSS_ALIASES`, `LEGAL_DISAMBIGUATION_RULES` o `_AMBIGUOUS_TERMS` en
`aws/lambda_text_to_lsb.py`.

## Cómo se usa

Antes de agregar una equivalencia o un alias:

1. ¿La palabra en español y la glosa candidata significan lo mismo, o solo se
   escriben distinto (mayúsculas, tildes, singular/plural)? Solo lo segundo es
   un alias legítimo (`GLOSS_ALIASES`).
2. ¿La glosa candidata está en `AVAILABLE_GLOSSES`? Compruébalo contra
   `assets/dictionary/official_dictionary.json`, no de memoria — varias
   entradas de este archivo (ver el propio dict, `subcategoryId`) ya se
   declaran "dactilológicas": no tienen seña 3D propia aunque sean conceptos
   válidos.
3. ¿La palabra tiene más de una acepción con consecuencias distintas? Si el
   texto o un antecedente ya la distinguen, resuélvela sin preguntar. Si no,
   es candidata a `_AMBIGUOUS_TERMS` (pregunta pendiente), no a un alias fijo.
4. Si ninguna acepción tiene seña documentada, no fuerces ninguna: que se
   deletree (`enforce_catalog_membership` ya lo hace automáticamente para
   cualquier concepto fuera de `AVAILABLE_GLOSSES`).

## Términos ya resueltos en esta auditoría

| Término | Antes | Ahora | Por qué |
|---|---|---|---|
| BILLETERA | alias → BILLETES | sin alias; se deletrea | Una billetera no es dinero. Sin seña propia documentada. |
| CORRER | alias → ESCAPAR | sin alias; se deletrea | Correr no implica huida ni delito. Sin seña propia documentada. |
| Dígitos ("0".."9") | alias → nombre en LSB (CINCO...) | sin alias; queda el dígito | El dictionary oficial documenta el dígito, no la palabra ("gloss": "5"); `AVAILABLE_3D_GLOSSES` solo tiene los caracteres. El alias dejaba TODO número sin animación, sin que nada lo dijera. |
| FISCAL (funcionario) | regla → FISCAL | sin regla; se deletrea | Falso amigo documentado por el propio corpus: la seña "FISCAL" de M3 es el sentido escolar ("fiscal/público"), y el corpus prohíbe expresamente reutilizarla para el Ministerio Público (`docs/Corpus_Maestro_Unificado_LSB_v4_Auditado.md`, filas 71/78). |
| FISCALIA (institución) | regla → FISCALIA | igual, sin cambios | Es correcto: el propio dictionary la marca como dactilológica (`canonicalGloss: "d(FISCALIA)"`), y el pipeline ya la deletrea porque no está en `AVAILABLE_3D_GLOSSES`. No hacía falta ningún cambio, solo confirmarlo. |
| LLAMA (animal) vs LLAMAR (verbo) | una sola regla → LLAMAR siempre | dos reglas: LLAMAR solo para el verbo; el sustantivo se deletrea | "La llama está en el campo" no es una acción de llamar. Sin seña propia del animal documentada. |
| AUTO (vehículo / resolución) | sin desambiguación | `_AMBIGUOUS_TERMS["AUTO"]`: resuelve por señales de contexto o pregunta si no hay evidencia | Caso insignia del encargo: dos acepciones con consecuencias muy distintas (un objeto sin seña vs. un documento con seña "RESOLUCIÓN" real). Ver la sección siguiente. |
| "niñas" → HIJA (ejemplo del prompt) | agregaba parentesco no declarado | ejemplo cambiado a un plural sin relación familiar (TRABAJADOR) | Una edad no es una relación de parentesco. El catálogo no tiene un descriptor neutro de "niño/niña" (solo HIJO/HIJA, que sí son de parentesco, y JOVEN/ADULTO). |
| NO, SIN, O, NI | palabras función (invisibles para la cobertura) | palabras de contenido | Su pérdida ahora se puede detectar (`detect_fidelity_losses`, incidencia `negacion_perdida`). |
| Cifras en el texto | invisibles para `recognize_input` | detectables | Incidencia `cifra_perdida` cuando un dígito del texto no aparece en ninguna glosa de salida. |
| I, K (abecedario 3D) | servidor decía `available: true`; cliente no las anima | servidor y cliente coinciden: no disponibles en 3D | El modelo 3D del avatar no las trae (ver `animation_url_resolver.dart`); el servidor afirmaba disponibilidad que el cliente nunca podía cumplir. |

## `_AMBIGUOUS_TERMS`: cómo funciona y cómo ampliarlo

`resolve_ambiguous_terms(text, resolved_senses)` en `aws/lambda_text_to_lsb.py`
decide, para cada término registrado:

- Si `resolved_senses` (lo que la persona ya eligió en un turno anterior, vía
  `pendingClarifications` → `resolvedSenses` en la siguiente solicitud) trae
  una respuesta válida, se usa esa.
- Si no, y el texto tiene palabras de UN SOLO lado de `context_signals`, se
  resuelve sin preguntar.
- Si no hay evidencia, o hay señales de ambos lados, se devuelve una pregunta
  pendiente (`pendingClarifications` en la respuesta) y NINGUNA de las dos
  acepciones se afirma — ni la del término, ni ninguna glosa derivada de él.

Esto tiene efecto en:
- `aws/lambda_text_to_lsb.py`: `post_process_glosses`, campo `semanticStatus`
  (`resolved` / `needs_clarification`) y `pendingClarifications` de la
  respuesta.
- `lib/core/domain/entities/semantic_message.dart`:
  `PendingClarification`/`ClarificationOption`/`SemanticStatus`.
- `lib/features/audio_to_lsb/presentation/controllers/audio_translation_controller.dart`:
  estado `needsClarification`, `resolveClarification(term, optionId)`.
- `lib/features/audio_to_lsb/presentation/screens/audio_to_lsb_screen.dart`:
  la tarjeta de pregunta con las opciones.
- Caché (servidor: `generate_cache_key`; cliente:
  `caching_audio_translation_repository.dart`): el sentido elegido forma parte
  de la clave, para que una misma frase con dos sentidos resueltos distintos
  no comparta resultado.

Para agregar un término nuevo: una entrada en `_AMBIGUOUS_TERMS` con
`question`, `options`, `context_signals` (palabras que, si aparecen SOLAS de
un lado, deciden sin preguntar) y `resolved_gloss` (la glosa real del
catálogo por acepción, o `None` si esa acepción no tiene seña documentada).

## Pendiente — términos identificados pero NO resueltos todavía

Estos casos están en el banco de pruebas del encargo (sección 11) y NO tienen
una entrada en `_AMBIGUOUS_TERMS` todavía. Antes de agregarlos, hace falta
confirmar contra el corpus/dictionary si cada acepción tiene una seña
distinta, porque si comparten la misma glosa del catálogo, preguntar no
cambia nada en la salida (solo tendría sentido para decidir qué NO se
representa).

- **BANCO** (entidad financiera / asiento): `AVAILABLE_GLOSSES` solo tiene una
  entrada "BANCO" (Lugares); no hay una segunda seña para "asiento". Antes de
  desambiguar hay que confirmar con el corpus/comunidad si esa seña
  representa ambos sentidos o solo uno.
- **MÓVIL** (motivo del hecho / teléfono celular): "celular" ya tiene su
  propia glosa (CELULAR); "motivo" no tiene una entrada dedicada en el
  catálogo. Falta confirmar qué seña (si alguna) cubre "motivo".
- **EFECTIVO** (adjetivo "en efectivo" = modalidad de pago / posible nombre
  propio "Efectivo"): la regla actual (`"plata / dinero / efectivo": Mapear a
  "BILLETES"`) es razonable para el caso general, pero no distingue el caso
  límite de un nombre propio. No se tocó por no ser el error señalado en el
  encargo (que sí era BILLETERA/CORRER); queda listado para revisión.
- **Alias compuestos verificados contra el GLB**: `COMO_ESTAS` ya existe como
  clip horneado en `avatar_test.glb`. El traductor aplica coincidencia de frase
  más larga y fuerza `como estas` / `¿cómo estás?` a una sola glosa
  `COMO_ESTAS`, incluso si Bedrock devuelve `COMO` + `ESTAS` o una salida
  incompleta. Esta excepción solo se habilita cuando el alias está declarado y
  el clip aparece realmente en el GLB; un alias sin clip (por ejemplo
  `ESTOY_BIEN` mientras no se hornee) continúa deletreándose.

## Limitaciones que este trabajo NO puede cerrar

Documentadas aquí en vez de forzar una solución de software:

- **Gramática espacial y componentes no manuales**: el motor actual planifica
  una secuencia lineal de glosas; no hay soporte para referencias espaciales,
  marcadores no manuales (cejas, inclinación) ni para que el avatar
  diferencie visualmente una pregunta de una afirmación más allá del orden de
  las glosas. Cambiar esto es un trabajo de animación/rigging, no de
  post-procesamiento de texto.
- **Cobertura de animaciones 3D**: `AVAILABLE_3D_GLOSSES` tiene ~41 señas
  horneadas sobre un catálogo de 346 conceptos. La gran mayoría de una
  traducción real cae en dactilología por diseño actual del proyecto, no por
  un defecto de esta auditoría. `representationStatus` lo refleja como
  "partial" con honestidad; subir esa cobertura requiere producir más clips,
  no cambiar código.
- **Nombre propio al inicio de una frase, mencionado una sola vez** ("Ana
  vino", sin más contexto): sigue sin poder distinguirse de una palabra común
  capitalizada por ir primera. Se corrigió el caso de un nombre que se repite
  en el texto (ver tabla arriba), pero el caso de mención única y inicial
  necesita un diccionario de nombres o el propio corpus, no una heurística de
  posición.
- **Validación con personas sordas señantes e intérpretes**: ninguna prueba
  automatizada de este repositorio certifica que una construcción sea
  comprensible o gramaticalmente correcta en LSB — solo que el software no
  pierde información, no inventa recursos y no oculta sus límites. Las filas
  marcadas como pendientes en `docs/Corpus_Maestro_Unificado_LSB_v4_Auditado.md`
  (búsqueda "Validar primero los conceptos críticos") siguen necesitando esa
  revisión humana.
- **`RemoteAudioDataSourceImpl.translateText`** (cliente) todavía rellena
  URLs de animación faltantes con `avatar_test.glb` genérico cuando la lista
  de glosas es más larga que la de URLs resueltas (línea con el comentario
  "avatar_test.glb" en `remote_audio_datasource.dart`). No se tocó en esta
  auditoría porque cambiar esa lógica sin conocer el contenido real del
  archivo GLB (si es un contenedor con varios clips seleccionables, o un
  clip único) arriesga romper la reproducción real en vez de corregirla.
  Queda señalado para revisión por quien tenga acceso al recurso 3D.
- **Metadatos de origen (voz/teclado)**: el contrato de traducción no
  distingue si el texto vino de voz confirmada o de teclado más allá de qué
  callback del widget se usó (`onSubmit` vs `onSpeechSubmit`), y la pantalla
  actual (`audio_to_lsb_screen.dart`) solo usa `onSubmit`. Etiquetar el origen
  en la solicitud/telemetría es un cambio de contrato pendiente, no crítico
  para la fidelidad del significado.
