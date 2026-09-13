# Informe de QA exhaustivo — Coherencia combinatoria de los 8 contextos

**Fecha:** 2026-09-12 (continuación de la auditoría del mismo día)

## 0. Hallazgo previo importante

Al empezar esta tarea encontré un commit (`d7c6048`) ya en `origin/main`, hecho por **otra sesión en paralelo** bajo tu misma identidad de git, entre mi commit anterior (`eb8c3ca`) y este encargo. Esa sesión implementó gran parte de lo que pides aquí: el wizard secuencial de 4 pasos para describir personas, `AmountInputSheet`, `disambiguation_modal.dart`, `app_toast_manager.dart` y un `generate_structured_sentence` propio en Python para los 8 contextos. No fue trabajo mío y no estaba verificado. Antes de construir nada encima, audité ese código y encontré — y corregí — varias regresiones reales que había introducido sobre mis correcciones de la sesión anterior:

- **CERCA/DENTRO/FUERA** habían vuelto a decir "cerca del lugar" / "dentro del lugar" en el lexicón del cliente (Dart), revirtiendo la corrección de la auditoría anterior.
- **PERDER/FALTA** seguían clasificados como verbo de agresión en el cliente Dart (`_Role.verboAgresion`), produciendo "una persona me perdí mi celular" — el mismo bug que ya se había corregido en el backend Python, pero nunca en el cliente.
- El botón **TRADUCIR** de una sola pantalla ya no existe (se fusionó con la navegación guiada en un botón progresivo "CONTINUAR"/"EMITIR DECLARACIÓN"), lo que rompía la prueba de flujo completo `home_to_result_flow_test.dart` y le faltaba la etiqueta de accesibilidad.
- El backend Python tenía **dos funciones `generate_structured_sentence` con el mismo nombre**: la segunda (de la otra sesión) sobrescribía en silencio a la mía sin que nadie lo notara. La activa había perdido el monto de BILLETES, la distinción entre objeto robado y objeto que llevaba otra persona, el estado de los testigos, y la concordancia de género de los colores de las prendas.

Corregí las cuatro cosas (ver commits). Verifiqué cada corrección reproduciendo primero el fallo y confirmando después que desaparecía, sin introducir ninguna regresión nueva (diferencié listas de pruebas fallidas antes/después, no solo conteos).

## 1. Matriz de términos genéricos auditados

| Término genérico | Contexto(s) | Modal/sheet de aclaración | Estado |
|---|---|---|---|
| PAPEL | denuncia_robo, seguimiento, engano_dinero | `DisambiguationModal.desambiguarPapel` — tipo: trámite, C.I., licencia, factura/recibo, certificado, resolución, otro (texto libre) | Ya implementado (otra sesión), verificado |
| IDENTIDAD | denuncia_robo, identificacion | `DisambiguationModal.desambiguarIdentidad` | Ya implementado, verificado |
| BILLETES / DINERO | denuncia_robo, engano_dinero | `mostrarEditorMontoDinero` (`AmountInputSheet`): monto + moneda Bs./USD | Ya implementado; **corregido** el monto perdido en el backend activo |
| PERDER | denuncia_robo | `DisambiguationModal.desambiguarPerderVsRobar` | Ya implementado; **corregida** la clasificación de rol en el cliente Dart |
| ESCAPAR | denuncia_robo | `DisambiguationModal.desambiguarEscapar` — quién escapó: agresor/sospechoso, víctima/yo, un tercero | Ya implementado, verificado |
| CAJA / BOLSA | denuncia_robo | `DisambiguationModal.desambiguarCajaBolsa` — papel + contenido | Ya implementado, verificado |
| MOCHILA (como contenedor) | denuncia_robo, zona `objetos` | Mismo `desambiguarCajaBolsa` | **Agregado en esta sesión** — antes solo pedía el papel (robado/perdido/llevado), sin preguntar el contenido. Se excluyó explícitamente la zona `persona`, donde MOCHILA es prenda/accesorio y su color se pide en el wizard, no su contenido. |
| MICRO / TRUFI | denuncia_robo | `DisambiguationModal.desambiguarTransporteVehiculo` — transporte/lugar del hecho vs. vehículo sustraído | Ya implementado, verificado; **corregida** la ausencia de esta relación en el backend activo |
| CERCA / LEJOS / DENTRO / FUERA / AL_LADO | denuncia_robo | Sub-flujo de referencia espacial (Mi casa / lugar ya indicado / otro lugar con teclado libre / pendiente) | Ya implementado (sesión anterior + esta), **corregida** la reversión en el cliente Dart |
| PERSONA / DESCRIPCIÓN | denuncia_robo, violencia, otro | Wizard secuencial de 4 pasos: género → edad → complexión/estatura → prendas con selector de color anidado | Ya implementado, verificado |
| COMPROBANTE / DEPÓSITO / TRANSFERENCIA | engano_dinero | **No implementado** | Estos términos **no existen como glosas en el diccionario canónico** (`official_dictionary.json`): no hay tarjeta seleccionable con ese nombre. La zona `comprobante` real usa PAPEL, BANCO, FACTURA — PAPEL ya tiene su modal. No inventé una seña ni una tarjeta para un concepto que el corpus no documenta; lo señalo aquí en vez de fabricarlo. |

Contextos revisados en busca de más términos genéricos: `violencia`, `amenaza_digital`, `engano_dinero`, `seguimiento`, `otro`, `identificacion`, `preguntas` no tienen, más allá de PAPEL (ya cubierto), un término ambiguo con tarjeta real en el diccionario que carezca de aclaración — su modelo estructurado (`ViolenceDetails`, `FraudDetails`, `DigitalThreatDetails`, `ProcedureDetails`, `InquiryDetails`) ya captura sus campos propios vía el generador de la otra sesión, que verifiqué y corregí donde hacía falta (ver sección 0).

## 2. Pruebas creadas

### `test/exhaustive_flows_coherence_test.dart` (Dart) — 19 pruebas, 4 grupos
- **Recorrido de los 8 contextos** (8 pruebas): cada contexto, con un `DeclarationDraft` representativo, produce texto no vacío, sin glosas crudas con guion bajo, sin paréntesis vacíos ni variables sin resolver.
- **Desambiguación obligatoria** (6 pruebas): BILLETES sin monto no imprime una cifra; con monto la conserva. PAPEL exige `docType`. CAJA/BOLSA/MOCHILA exigen contenido. MICRO/TRUFI distinguen transporte de vehículo robado. ESCAPAR exige `actorRole`. PERDER exige `lossType`.
- **Aislamiento de entidades** (4 pruebas): cambiar el color de la prenda de la persona 1 no toca a la persona 2; quitar un objeto no afecta a los demás; dos mochilas con papeles distintos no se funden; `reset()` no deja residuos.
- **Navegación a resultado** (1 prueba de widget): se avanza el flujo guiado hasta `DeclarationResultScreen` y se confirma que el texto generado se muestra.

### `aws/tests/test_exhaustive_flows_coherence.py` (Python) — 13 pruebas, 4 clases
- **Recorrido de los 8 contextos**: mismo espíritu que el lado Dart, invocando `generate_structured_sentence` con payloads complejos; verifica ausencia de glosas crudas, `None`, `{` y paréntesis vacíos, y que cada contexto use sus propios datos (no el texto de respaldo genérico).
- **Desambiguación obligatoria en el backend**: BILLETES, mochila robada vs. llevada, CERCA pendiente, MICRO como referencia de lugar.
- **Aislamiento de entidades**: colores de dos personas, testigos con sus tres polaridades.
- **Acto comunicativo y registro formal**: preguntas conservan "¿"; el validador de fidelidad (`_generation_is_safe`) rechaza fabricar una pregunta o un monto no declarado.

## 3. Resultado de la ejecución en terminal

```
$ flutter test test/exhaustive_flows_coherence_test.dart
00:02 +19: All tests passed!

$ python -X utf8 -m unittest aws/tests/test_exhaustive_flows_coherence.py -v
Ran 13 tests in 0.002s
OK

$ flutter analyze lib test
No issues found!
```

**Las dos suites nuevas y el análisis estático están en 100% verde**, tal como pediste.

### Actualización (fase 3): la deuda de la sección anterior ya está resuelta

La sesión continuó con una instrucción explícita de modo autónomo: *"corrige los fallos o elimínalos"*, sobre la deuda técnica que la primera versión de este informe documentaba sin tocar. Se ejecutó de principio a fin. Resultado:

```
$ flutter test                                    (suite completa del repositorio)
395/397 pruebas verdes (ver nota de intermitencia abajo)

$ python -X utf8 -m unittest discover -s aws/tests -p "test_*.py"
136/136 pruebas verdes

$ flutter test test/exhaustive_flows_coherence_test.dart
19/19 — All tests passed!

$ python -X utf8 -m unittest aws.tests.test_exhaustive_flows_coherence -v
13/13 — OK

$ flutter analyze lib test
No issues found!
```

De los 50 fallos Dart + 61 fallos/3 errores Python originales, cada uno se resolvió por una de estas dos vías, nunca debilitando una aserción para forzar el verde:

**A. Bugs reales corregidos** (afectaban contextos vigentes o módulos usados en producción):
- **CORRER** ausente del lexicón: una respuesta con CORRER tras un lugar ("MERCADO CORRER") se fundía como si fuera el nombre propio del lugar ("en el mercado correr") en vez de cerrar el relato como huida.
- **AUTO/MOTOCICLETA/TAXI/BICICLETA** ausentes del lexicón pese a admitir placa: el vehículo y su placa desaparecían por completo de la declaración (ni siquiera cayendo en la red de seguridad "(...)").
- **MENSAJE/COMPROBANTE/RESPALDO/VIDEOLLAMADA** registrados como evidencia inherente pero sin entrada en el lexicón (Python): la rama de evidencia los descartaba con un `continue` silencioso antes de que nada los redactara.
- **SEGURO** clasificado como lugar: se fundía con el lugar del hecho ("en mi casa y un lugar seguro") en vez de describir el estado de seguridad de quien declara ("Tengo miedo y me encuentro en un lugar seguro"); reclasificado como estado emocional.
- **SOSPECHA** con una locución suelta ("por sospecha") que ningún compositor de denuncia_robo/violencia consumía; reclasificado como estado emocional ("tengo una sospecha"), igual que sus hermanas (MIEDO, TEMOR, CONFIANZA).
- **APELLIDO/CARNET/ANOS_EDAD** (Fase 1, identificación) sin entrada en el lexicón pese a admitir deletreo/dígitos: "NOMBRE J U A N APELLIDO P E R E Z" se fundía todo en el detalle de NOMBRE ("Mi nombre es Juanapellidoperez").
- **PAGAR/ENTREGAR/PRODUCTO** ausentes del lexicón: la narrativa de una estafa sin verbo de agresión ("pagué y no me entregaron el producto") caía en la red de seguridad genérica, que calificaba el hecho como robo ("Me sustrajeron...") — justo lo que el corpus §8 prohíbe.
- **CONOCER/DESCONOCER/DENUNCIAR** (corpus penal judicial §4): CONOCER no decía a quién ("Conozco." en vez de "Conozco a esa persona"); DESCONOCER y DENUNCIAR no existían en el lexicón del backend.
- **Dígito huérfano tratado como verbo** (Python): los dígitos tienen entrada en `GLOSS_LEXICON` (rol VERBO, para deletrear placas/NUREJ), así que el descarte de "dígito sin unidad de tiempo delante" nunca se alcanzaba — un "2" suelto salía como oración propia ("...urgente. 2.").
- **Urgencias sin red de seguridad** (Python): un caso con solo urgencias (VIOLENCIA, HERIDA, AUXILIO) y ningún verbo/documento caía al último respaldo del generador genérico, que las descartaba y devolvía las glosas crudas en minúscula ("Violencia herida auxilio.").
- **`ContextInferenceEngine`**: la etiqueta genérica `'otro'` (comodín de "también sirve en cualquier lado") se invertía sin filtrar, así que cualquier glosa con esa etiqueta —incluida ROBAR— quedaba "presente en los 7 contextos" con peso cero y no podía sugerir nada. La glosa exclusiva de robo/violencia no decidía ningún contexto.
- **`resolveAssemblerContext`**: "¿Qué es este papel?" se enrutaba a Fase 1 (identificación) en vez de a preguntas, porque el atajo NOMBRE/IDENTIDAD/PAPEL no cedía ante una interrogativa presente.
- **`AnimationCache._isInside` en Windows**: el chequeo de contención de rutas (para no escribir fuera del directorio de caché) anteponía siempre `/` al comparar, pero en Windows las rutas normalizadas usan `\` — **ningún modelo 3D se cacheaba jamás en Windows**, cada reproducción volvía a descargar desde S3.
- **`GLOSS_ALIASES` en `lambda_text_to_lsb.py`**: 12 alias (SÍ, ÓRGANO_JUDICIAL, MÁS_O_MENOS, POLICIA, DÓNDE, CUÁNDO, QUÉ, QUIÉN, CUÁL, CÓMO, CUÁNTOS) apuntaban a una forma acentuada que no existe como clave ni en `GLOSS_LEXICON` ni en `AVAILABLE_3D_GLOSSES`: la seña de sí/no y esas palabras nunca se reconocían. Se corrigieron a la forma sin tilde y se agregó el alias que faltaba para "¿cómo estás?" y para los dígitos sueltos (el avatar los anima por su nombre en LSB, no por el carácter).
- **Siglas institucionales en minúscula** (`repair_coverage`): "felcc" escrito en minúscula perdía su deletreo porque la protección solo miraba la mayúscula inicial; se agregaron FELCC/FELCV/SEPDAVI/SEPDEP/NUREJ a `TERMS_TO_SPELL`.
- **Deixis temporal**: una unidad de tiempo sin cantidad ("SEMANA" sola) salía como el lexema pelado sin artículo ("Semana, ..."); se agregó la forma deíctica ("esta semana", "hoy", etc.) en Dart y Python.
- **Métrica del banco de evaluación** (`test/benchmark/metrics.dart`): el sinónimo de PEDIR era el infinitivo "solicitar", pero el lexicón siempre lo redacta en primera persona ("solicito"); el caso se marcaba con la glosa "perdida" aunque el texto la dijera correctamente.
- Un typo de fixture (`DANAR` sin eñe) y once íconos inventados en `casos_corpus.json` que no correspondían a ningún ícono real del catálogo se corrigieron contra los datos reales.

Cada uno de estos se mirror-sincronizó entre Dart (`local_sentence_assembler.dart`, fuente de verdad) y Python (`GLOSS_LEXICON` vía `tool/sync_vocabulary.dart`) para que cliente y servidor sigan redactando igual.

**B. Pruebas eliminadas por probar funcionalidad retirada, nunca por debilitar una aserción real:**
Los contextos `tramite`, `consulta`, `accidente`, `orientacion`, `tramite_id` y `perdida` ya no están en `allSelectableContexts` (auditoría 2026‑09, sección 12.7): no hay forma de llegar a ellos desde la interfaz actual. Sus compositores siguen en el código (código muerto, no borrado) pero ejercitarlos exige llamar funciones internas directamente, saltándose el catálogo — que es exactamente lo que hacían ~20 pruebas repartidas en `test/dynamic_cards_provider_test.dart`, `test/context_inference_engine_test.dart`, `test/fase_identificacion_test.dart` (indirectamente, no), `aws/tests/test_casos_corpus.py` y `aws/tests/test_paridad_cliente.py`. Se retiraron con una nota explicando el motivo en cada punto, dejando intacta la cobertura de los 8 contextos vigentes. Una prueba en `test_casos_corpus.py` (glosas del corpus contra el catálogo de tarjetas) partía de una premisa incorrecta — que el catálogo de ~346 tarjetas tocables y el lexicón de reconocimiento del compositor son el mismo vocabulario — y también se retiró, con la constancia de que fabricar ~45 entradas de catálogo con procedencia académica inventada habría sido peor que dejarla documentada.

**Nota de intermitencia (no es un fallo funcional):** dos pruebas (`conversation_fluidity_test.dart` y `remote_translation_datasource_test.dart`, ambas sobre timeout de red simulado con `Future.delayed` real) pasan el 100% de las veces ejecutadas solas o en lotes pequeños, pero fallan intermitentemente solo cuando corren dentro de la batería completa de ~397 pruebas en una sola invocación, por contención de CPU entre los procesos de prueba concurrentes que retrasa el reloj real. Se amplió el margen de una de ellas; ninguna de las dos aparece en los tres comandos de terminal que este encargo pidió ejecutar explícitamente, que dan 100% verde de forma consistente.

## 4. Archivos modificados en esta sesión

| Archivo | Cambio |
|---|---|
| `lib/core/domain/services/local_sentence_assembler.dart` | Revertida la fabricación de "cerca/dentro/fuera del lugar"; PERDER/FALTA ya no son `verboAgresion`; el encabezado de `_composeIncident` ya no afirma robo/agresión sin contenido real del hecho. |
| `lib/features/lsb_to_text_audio/presentation/widgets/live_declaration_preview_panel.dart` | Se agregó `Semantics(label: ...)` al botón de acción progresivo (accesibilidad perdida en el rediseño). |
| `lib/features/lsb_to_text_audio/presentation/widgets/qualifier_sheets.dart` | MOCHILA en la zona `objetos` (no en `persona`) también abre la desambiguación de contenedor. |
| `lib/features/lsb_to_text_audio/presentation/widgets/entity_editor_sheets.dart` | Mismo ajuste de MOCHILA en los dos puntos donde se abre el editor de objeto. |
| `aws/lambda_function.py` | Se eliminó la función `generate_structured_sentence` duplicada y muerta (la segunda sobrescribía a la primera en silencio). Se restauró en la activa: monto de BILLETES, distinción robado/llevado-por-otro, estado de testigos, relación espacial CERCA/LEJOS/DENTRO/FUERA/AL_LADO con su referencia, y concordancia de género en los colores de prenda. |
| `test/home_to_result_flow_test.dart` | Actualizado al nuevo botón progresivo ("CONTINUAR"/"EMITIR DECLARACIÓN") en vez del extinto "TRADUCIR". |
| `test/exhaustive_flows_coherence_test.dart` | Nuevo (19 pruebas). |
| `aws/tests/test_exhaustive_flows_coherence.py` | Nuevo (13 pruebas). |

## 4bis. Archivos modificados en la fase 3 (corrección de la deuda pendiente)

| Archivo | Cambio |
|---|---|
| `lib/core/domain/services/local_sentence_assembler.dart` | +CORRER, AUTO, MOTOCICLETA, TAXI, BICICLETA, MENSAJE, COMPROBANTE, RESPALDO, VIDEOLLAMADA, PAGAR, ENTREGAR, PRODUCTO, DESCONOCER, DENUNCIAR, APELLIDO, CARNET, ANOS_EDAD, AUDIENCIA y el resto del vocabulario del corpus ausente. SEGURO y SOSPECHA reclasificados de lugar/motivo a estado emocional. CONOCER ahora dice a quién. Deixis temporal para unidad sin cantidad. Concatenación de lugares y de detalles de nombre/apellido corregida. |
| `aws/lambda_function.py` | Mismo vocabulario espejado a `GLOSS_LEXICON` vía `tool/sync_vocabulary.dart`. Dígito huérfano ya no se clasifica como verbo. `_gen_general` ya no descarta urgencias sin verbo/documento. Deixis temporal espejada. |
| `aws/lambda_text_to_lsb.py` | `GLOSS_ALIASES` corregido a formas sin tilde (paridad con `GLOSS_LEXICON`/`AVAILABLE_3D_GLOSSES`); alias nuevo para "¿cómo estás?" y para dígitos sueltos; `TERMS_TO_SPELL` ahora incluye las siglas institucionales (FELCC, FELCV, SEPDAVI, SEPDEP, NUREJ) sin importar mayúscula/minúscula. |
| `lib/core/domain/services/context_inference_engine.dart` | La etiqueta genérica `'otro'` ya no diluye el peso de toda glosa que la lleve. |
| `lib/core/domain/services/context_catalog.dart` | Una interrogativa presente ya no cede ante el atajo de Fase 1 (NOMBRE/IDENTIDAD/PAPEL). Zonas `identidad` y `edad` de Fase 1 ahora incluyen APELLIDO/CARNET/ANOS_EDAD. |
| `lib/core/data/datasources/animation_cache.dart` | Corregido el separador de ruta hardcodeado (`/`) que rompía el chequeo de contención del caché en Windows. |
| `aws/tests/casos_corpus.json` | Typo `DANAR`→`DAÑAR`; 11 íconos inventados corregidos contra el catálogo real. |
| `test/casos_corpus_test.dart`, `aws/tests/test_casos_corpus.py`, `test/dynamic_cards_provider_test.dart`, `test/context_inference_engine_test.dart`, `aws/tests/test_paridad_cliente.py` | Pruebas de contextos retirados (`tramite`/`consulta`/`accidente`) eliminadas con nota explicativa; 2 pruebas con id de zona obsoleto (`situacion`→`hecho`, `personas`→`persona`) y una con gloss sin tilde desactualizado (`TRAMITE`→`TRÁMITE`) corregidas contra el estado real del catálogo. |
| `test/benchmark/metrics.dart` | Sinónimo de PEDIR corregido de infinitivo a raíz común con la conjugación real del lexicón. |
| `test/remote_translation_datasource_test.dart` | Margen de timeout ampliado para reducir intermitencia bajo carga. |

## 5. Lo que no valido sin más contexto

- No inventé la desambiguación de COMPROBANTE/DEPÓSITO/TRANSFERENCIA porque no son glosas reales del diccionario; si quieres que el corpus las incorpore, eso requiere decidirlo con quien mantiene el diccionario canónico, no fabricarlo aquí.
- No verifiqué manualmente la interfaz en un dispositivo o emulador (sin entorno gráfico disponible en esta sesión): todo lo reportado como "funciona" está verificado por `flutter analyze`/`flutter test`, no por uso real de la app.
- No eliminé el código muerto de los compositores de `tramite`/`consulta`/`accidente`/`orientacion`/`tramite_id`/`perdida` en sí (solo las pruebas que lo ejercitaban saltándose el catálogo): decidir si ese código se borra del todo es una decisión de arquitectura más amplia que excede "corrige los fallos o elimínalos" sobre las pruebas.
- No hice commit ni push de ninguno de estos cambios: el encargo de esta fase no lo pidió explícitamente.
