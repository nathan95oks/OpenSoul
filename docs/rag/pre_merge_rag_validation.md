# Validación RAG previa a merge

> **Nota (auditoría posterior, 2026-09-27).** Las métricas de este informe no
> detectan respuestas inventadas: 60 de las «100 consultas» son turnos
> literales del corpus, 14 se cuentan sin evaluarse y las 3 «fuera de corpus»
> no comparten ninguna palabra con él. Con charla de ventanilla sin trámite,
> el RAG respondía a 8/25 (teléfono) y 10/25 (Lambda). Se corrigió con la
> penalización de palabras desconocidas y `RAG_MIN_SIMILARITY` 0.59; ver
> `docs/architecture/rag-conocimiento-institucional.md`. Además, el RAG ya no
> se muestra como barra en Conversación: abre su trámite en la familia
> «Trámites» del módulo de tarjetas LSB.


Fecha: 2026-09-27  
Rama: `feat/rag-conocimiento-institucional`  
Base comparada: `main`  
Veredicto: `READY_FOR_MOBILE_TEST`

## Cambios y bugs demostrados

- Se reprodujo que `ragOutranksGraph(...)` permitía a RAG competir con rutas deterministas seguras. Ahora RAG solo puede superar `NO_SAFE_ROUTE` o el selector de contexto; `DIRECT_QUESTION`, `DIRECT_CONTEXT` y `MINIMAL_GRAPH_PATH` no muestran respuestas competidoras.
- Se reprodujo que `¿Qué te robaron?` no pedía OBJECT. Flutter y Lambda ahora conservan OBJECT y enrutan a `Q.ROB.QUE`; `¿Quién te robó?` conserva PERSON y nunca abre `¿Narrar qué?`.
- Se reprodujo que `vigenciaSinConfirmar` no bloqueaba `mostrable`. Ahora `[VERIFICAR]`, hechos vencidos y vigencia no confirmada quedan fuera de respuestas mostrables como hechos definitivos.
- Las ocho advertencias de roles eran referencias de turno incorrectas en Markdown, no un error del parser. Se corrigieron en la fuente y se regeneró el corpus.
- Se reprodujo mezcla institucional en retrieval local. Se añadió clasificación/filtro por institución y continuidad contextual sin cambiar thresholds globales; el filtro equivalente se aplicó al retrieval Lambda.
- Se reprodujeron pérdidas de negación para noche, casa y dinero. La composición final conserva las cinco negaciones auditadas y no confirma presuposiciones formuladas como preguntas.
- Se añadieron fallbacks para índice/corpus vacío o corrupto, JSON remoto inválido y timeout. Los fallos de embeddings/Bedrock continúan degradando a grafo sin bloquearlo.
- Datos de ejemplo, placas, nombres, casos, NUREJ, WebID y montos no se ofrecen como datos reales. Las consultas de deuda, fiscal, audiencia y virtualidad solo explican cómo consultar.

## Tests añadidos o ampliados

- Regresión grafo/RAG: 7 consultas críticas de robo, slots PERSON/TIME/LOCATION/OBJECT, multislot y NARRATIVE.
- Continuidad multivuelta: robo LOCATION→TIME, PERSON→LOCATION, Fiscalía→seguimiento y cambio explícito a SEGIP.
- Separación institucional: SEPDEP/SEPDAVI, FELCC/FELCV, SEGIP/SERECI y Fiscalía/Órgano Judicial.
- Seguridad: datos en vivo, identificadores ficticios, presuposiciones, negaciones y marcadores de verificación.
- Fallbacks Flutter/Python y contrato semántico compartido Flutter↔Lambda.
- Dataset compacto de 100 consultas: institucionales, paráfrasis, multivuelta, ambiguas, dato en vivo, `[VERIFICAR]`, cambios de institución y fuera de corpus.

## Métricas

| Métrica | Resultado | Objetivo | Estado |
|---|---:|---:|---|
| `retrieval_hit@1` | 96.67% | informativa | PASS |
| `retrieval_hit@3` | 96.67% | informativa | PASS |
| `retrieval_hit@5` | 100% | ≥95% | PASS |
| `institution_accuracy` | 100% | 100% crítico | PASS |
| `slot_accuracy` | 100% | 100% crítico | PASS |
| `multi_slot_exact_match` | 100% | 100% crítico | PASS |
| `cross_institution_error_rate` | 0% | 0% | PASS |
| `live_data_hallucination_rate` | 0% | 0% | PASS |
| `verify_marker_preservation` | 100% | 100% | PASS |
| `graph_regression_pass_rate` | 100% | 100% | PASS |

## Comparación `main` vs rama

Se ejecutó la misma instantánea sobre ambas ramas para las siete consultas críticas. PERSON, TIME, LOCATION, multislot y NARRATIVE conservan exactamente `context`, ruta y preguntas de `main`. La única diferencia es una mejora: `¿Qué te robaron?` pasa de `requestedSlots: []` en `main` a `requestedSlots: [object]`, manteniendo `denuncia_robo`, `DIRECT_QUESTION` y `Q.ROB.QUE`/`Q.DOC.ACLARAR`. No hay regresión de un caso correcto de `main`.

## Validación automatizada final

| Comando | Resultado |
|---|---|
| `flutter analyze` | PASS, 0 issues |
| `flutter test` | PASS, 877; 1 omitido |
| `python -m unittest discover -s aws/tests -v` | PASS, 379; 1 omitido por requerir AWS real |
| `python -m compileall -q aws` | PASS |
| `python tool/build_rag_corpus.py --check` | PASS; corpus al día, 0 advertencias de roles |
| `dart run tool/find_missing_lambda_lexicon.dart` | PASS; 346/346 glosas cubiertas |
| `python -m unittest tool.tests.test_build_rag_corpus -v` | PASS, 7 |

## Riesgos restantes

- Persiste el aviso documental preexistente `F-LSB-05`: una fuente de Lexivox no pertenece a dominios oficiales. El hecho queda sujeto a las reglas de verificación y no altera el veredicto técnico.
- La prueba contra Bedrock real permanece omitida sin credenciales (`RUN_BEDROCK_REAL_TESTS=1`). Los fallos simulados de Bedrock/embeddings sí están cubiertos.
- Falta la validación física en celular; esta es precisamente la siguiente fase autorizada por este veredicto.

## Pruebas manuales en celular

1. Escribir `¿Quién te robó?`; debe abrir PERSON/Q.PER.CONOCE y no `¿Narrar qué?`.
2. Escribir `Hola, ¿cómo estás? ¿Quién te robó?`; mismo resultado, sin tarjeta RAG.
3. Escribir `¿Cuándo te robaron el celular?`; debe pedir TIME.
4. Escribir `¿Dónde te robaron?`; debe pedir LOCATION.
5. Escribir `¿Qué te robaron?`; debe pedir OBJECT/Q.ROB.QUE.
6. Escribir `¿A qué hora y dónde te robaron?`; debe abrir TIME+LOCATION en recorrido mínimo.
7. Escribir `Cuéntame cómo pasó el robo.`; debe abrir NARRATIVE/Q.HEC.QUE_OCURRIO.
8. Hacer LOCATION y luego `¿Y a qué hora?`; debe conservar robo y pasar a TIME.
9. Hacer PERSON y luego `¿Dónde pasó?`; debe conservar robo y pasar a LOCATION.
10. Consultar seguimiento en Fiscalía y luego `¿Y qué necesito?`; debe conservar Fiscalía.
11. Después escribir `Ahora necesito renovar mi cédula`; debe cambiar a SEGIP.
12. Probar `Me denunciaron y no puedo pagar abogado`; SEPDEP, nunca SEPDAVI.
13. Probar `Soy víctima y necesito abogado`; SEPDAVI, nunca SEPDEP.
14. Probar `Me robaron mi celular`; FELCC, nunca FELCV.
15. Probar `Mi pareja me amenaza y me golpea`; FELCV, nunca FELCC.
16. Probar pérdida de cédula y de certificado de nacimiento; SEGIP y SERECI respectivamente.
17. Consultar Fiscalía y verificar que no aparezcan NUREJ/WebID del Órgano Judicial.
18. Preguntar `¿Cuánto debo?` y `¿Quién es mi fiscal?`; debe explicar consulta, sin valor ni nombre inventado.
19. Preguntar `¿Cuándo es mi audiencia?` y `¿Será virtual?`; debe explicar consulta, sin fecha ni modalidad inventada.
20. Preguntar por ladrón en moto, pareja que golpeó ayer y dos celulares; no deben registrarse como hechos confirmados.
21. Probar `No conozco al ladrón` y `No vi su cara`; la negación debe llegar a la salida final.
22. Probar `No fue de noche`, `No ocurrió en mi casa` y `No me robaron dinero`; ninguna debe volverse afirmación.
23. Activar modo avión o simular timeout remoto; las rutas del grafo deben seguir operativas.
24. Abrir una respuesta marcada para verificar o con vigencia no confirmada; no debe mostrarse como hecho definitivo.

## Veredicto

`READY_FOR_MOBILE_TEST`
