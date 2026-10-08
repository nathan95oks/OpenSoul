# Continuación del QA del módulo Conversación

> **Revisado el mismo día:** el 25/25 de este informe dependía de reglas escritas para las frases de los guiones (`_naturalLanguageRoute`), que se retiraron. El estado vigente y la verificación de estos cambios están en [QA_CONVERSACION_2026-10-08.md](QA_CONVERSACION_2026-10-08.md).

Fecha: 2026-10-08  
Autor de esta continuación: Codex  
Estado: terminado y validado localmente  
Git: no se hizo `commit` ni `push`

## Resultado final

- QA conversacional estricto: **25/25 conversaciones aprobadas**.
- Turnos ejercitados: **85**.
- Fallos de coherencia finales: **0**.
- Grabaciones Lambda pendientes: **0** (`test/qa/lambda_pendientes.json` contiene `{}`).
- Regresión Flutter relacionada: **144 pruebas aprobadas**.
- Pruebas Python de la Lambda: **22 aprobadas**.
- `flutter analyze`: **sin observaciones**.

El informe detallado turno por turno está en
`test/qa/reporte_final.json`. Incluye la lectura semántica, coincidencias del
grafo, sugerencias RAG, ruta elegida, tarjetas abiertas y respuesta producida
por la persona sorda.

## Punto de partida recibido

La sesión anterior de Claude dejó preparado el arnés de QA, 25 guiones, varias
respuestas reales de las Lambdas y cambios locales aún sin confirmar. También
dejó un arreglo de parseo de JSON multilínea en `aws/lambda_function.py` y sus
pruebas en `aws/tests/test_conversation_route.py`.

No revertí esos cambios. Continué encima de ellos y distinguí las
modificaciones previas de los archivos que ya estaban sucios al comenzar.

La evolución observable de los reportes fue:

| Reporte | Conversaciones con fallos | Fallos de turno |
|---|---:|---:|
| `reporte_actual.json` | 19/25 | 33 |
| `reporte_rag.json` | 19/25 | 33 |
| `reporte_despues_1.json` | 12/25 | 20 |
| `reporte_despues_2.json` | 4/25 | 5 |
| `reporte_final.json` | **0/25** | **0** |

## Qué se corrigió en Conversación

### 1. El contexto se conserva entre preguntas relacionadas

Se añadieron reglas cerradas y validadas contra el banco real para impedir
saltos incoherentes de trámite. Cubren, entre otros:

- robo: objeto, momento, hora, lugar, testigos, factura/caja y regreso
  explícito al tema;
- violencia: peligro inmediato, agresor, lesiones, recurrencia y asistencia
  médica;
- testimonio: qué vio y si puede declarar;
- identificación y accesibilidad: teléfono, lectura y comprensión;
- SEGIP y SERECI: cédula perdida, denuncia de pérdida, certificado de
  nacimiento y titular del certificado;
- seguimiento de denuncia y número de caso;
- acoso sexual, ciberacoso, bullying, trata/tráfico y discriminación por ser
  una persona sorda;
- homicidio, violación y fraude/estafa.

Una referencia documental dentro de un trámite ya activo no cambia de oficina.
Ejemplo: «¿Trajo su certificado de nacimiento?» durante la reposición de cédula
permanece en SEGIP; antes una coincidencia textual podía enviarla a DDRR.

### 2. Preguntas múltiples y lenguaje real

Se corrigieron casos que rompían o degradaban la conversación:

- «¿Cuándo y dónde le robaron?» abre tiempo y lugar.
- «¿Cuándo, dónde y a qué hora le robaron?» conserva las tres preguntas.
- «¿Alguien vio lo que pasó?» pregunta si existen testigos y no salta al
  relato de un testigo.
- «¿Podría declarar como testigo?» abre la pregunta de testimonio correcta.
- «¿Qué le chorearon?» se interpreta como el objeto robado, no como la
  identidad del autor.
- `dnd`, `dnde`, `dónde` y `cndo` se normalizan sin perder la ranura pedida.
- «Cuénteme cómo pasó el robo» se trata como solicitud de relato, no como una
  instrucción sin respuesta.
- Indicaciones como «firme aquí» continúan sin transformarse en preguntas.

### 3. Las ranuras pedidas mandan sobre las coincidencias de tema

`GraphMatcher.requestedSlotsOf` conserva las ranuras declaradas por la lectura
semántica del backend. Solo fundamenta contra el español las ranuras extra que
se infirieron de glosas. Esto evita dos errores opuestos:

- perder `place` en «¿En qué lugar ocurrió?»;
- inventar `person` porque la traducción produjo `QUIÉN` para «¿Alguien vio?».

También se corrigió «¿a qué hora le robaron?» para que `qué` no añada
incorrectamente la ranura `object` cuando su núcleo es `hora`.

### 4. Grafo y RAG usan el mismo catálogo ejecutable

El proveedor del catálogo conversacional ahora usa
`RagTramites.bankWithTramites()`. Antes las tarjetas del módulo conocían los
recorridos RAG, pero el router conversacional no siempre podía validarlos.

El recuperador RAG recibe una bonificación pequeña por el escenario exacto que
ya está activo y prioriza su área institucional. La continuidad no puede
sustituir una pregunta determinista segura del grafo; ese contrato quedó
protegido por regresión.

### 5. Aperturas, cambios de tema y entradas peligrosas

Los saludos de ventanilla abren el selector cuando todavía falta el motivo. Un
cambio explícito («volvamos al robo», «ahora necesito saber de mi denuncia»)
sí cambia o recupera el contexto. Texto sin sentido, otro idioma e
instrucciones no abren trámites arbitrarios.

La versión del router subió a `4`, de modo que las decisiones antiguas de caché
no se mezclen con estas reglas.

## Homicidio, violación y fraude (estafa)

| Término | Decisión | Presentación | Descripción/equivalencia |
|---|---|---|---|
| `VIOLACIÓN` | Ya existe en el léxico oficial | Seña normal, no azul | Fuente `D2024`, entrada presente en `aws/lexico_lsb.json` |
| `HOMICIDIO` | No estaba en M1–M4 ni en el léxico disponible | `SENA_PENDIENTE:HOMICIDIO`, azul y tocable | «Matar a una persona.» / LSB: `HOMBRE · MUJER · MATAR` |
| `FRAUDE` | No estaba en M1–M4 ni en el léxico disponible | `SENA_PENDIENTE:FRAUDE`, azul y tocable | «Engañar a una persona para quitarle dinero o cosas. También se llama estafa.» / LSB: `ENGAÑAR · DINERO` |
| `ESTAFA` | Ya tenía equivalencia manual aprobada | No necesita una seña pendiente separada | `ESTAFA → ENGAÑAR` |

Las dos descripciones nuevas están marcadas como provisionales
(`revisada: false`) para que puedan pasar por revisión lingüística/jurídica sin
presentarlas como señas oficiales inventadas.

El generador ahora admite `"incluir": true` en
`docs/negocio/rag/descripciones_sin_sena.json`. Así una palabra solicitada por
producto se incorpora al diccionario de ayuda aunque todavía no aparezca en un
escenario del corpus. La opción quedó documentada en
`docs/negocio/rag/README.md`.

## Casos de prueba añadidos

`test/delitos_conversacion_test.dart` comprueba que:

- `VIOLACIÓN` existe en el léxico y no queda azul;
- `HOMICIDIO` y `FRAUDE` quedan azules;
- ambas palabras pendientes tienen descripción española y descripción LSB
  sin otra palabra pendiente dentro;
- `ESTAFA` usa `ENGAÑAR`;
- los cuatro textos llegan a un contexto conversacional coherente;
- factura/caja conserva el contexto de robo incluso sin lectura del backend.

El arnés `test/qa_conversacion_test.dart` también registra las sugerencias RAG
locales en cada turno. Se actualizaron las expectativas del guion únicamente
cuando el banco ya contenía una pregunta exacta y válida, por ejemplo
`Q.EVI.FACTURA_O_CAJA`.

## Respuestas reales de las Lambdas

Se ejecutó `tool/qa_capturar_lambdas.py` contra las URLs configuradas en
`.env`. Se grabaron 23 respuestas adicionales, llegando a 322 entradas en el
cassette. Después se repitió el QA estricto hasta obtener:

- `test/qa/lambda_pendientes.json`: `{}`;
- `test/qa/reporte_final.json`: 25 conversaciones, 85 turnos, 0 fallos.

No se desplegó ninguna Lambda. El cambio local de parseo JSON que venía de la
sesión de Claude sigue necesitando el flujo normal de despliegue si se quiere
llevar a AWS.

## Validación ejecutada

### QA conversacional estricto

```powershell
$env:QA_ESTRICTO='1'
$env:REPORTE_QA='test/qa/reporte_final.json'
flutter test test/qa_conversacion_test.dart `
  --dart-define=LSB_API_URL=https://api.qa.invalid/translate `
  --dart-define=LSB_TEXT_API_URL=https://texto.qa.invalid/translate
```

Resultado: **25 pruebas aprobadas**, 85 turnos y 0 fallos registrados.

### Regresión Flutter relacionada

Se ejecutaron juntas estas 11 suites:

```text
conversation_graph_router_test.dart
conversation_requested_slot_routing_test.dart
rag_retriever_test.dart
rag_fallback_test.dart
rag_graph_regression_test.dart
rag_safety_regression_test.dart
rag_tramites_test.dart
critical_robbery_snapshot_test.dart
acoso_y_trata_test.dart
delitos_conversacion_test.dart
pending_sign_test.dart
```

Resultado: **144 pruebas aprobadas**.

### Backend y análisis estático

```powershell
python -m pytest aws/tests/test_conversation_route.py -q
flutter analyze
```

Resultados: **22 pruebas Python aprobadas** y **0 observaciones del
analizador**.

## Archivos principales de esta continuación

- `lib/core/domain/conversation/conversation_graph_router.dart`
- `lib/core/domain/conversation/graph_matcher.dart`
- `lib/core/domain/conversation/lsb_gloss_semantics.dart`
- `lib/core/domain/rag/rag_retriever.dart`
- `lib/features/conversation/presentation/providers/rag_suggestions_provider.dart`
- `lib/core/di/injection.dart`
- `docs/negocio/rag/descripciones_sin_sena.json`
- `assets/dictionary/senas_sin_sena.json` (generado)
- `tool/build_rag_corpus.py`
- `test/delitos_conversacion_test.dart`
- `test/qa_conversacion_test.dart`
- `test/qa/guiones_conversacion.json`
- `test/qa/lambda_respuestas.json`
- `test/qa/reporte_final.json`

Archivos que ya venían modificados de la sesión anterior y fueron conservados
o validados: `aws/lambda_function.py`,
`aws/tests/test_conversation_route.py`, el arnés/corpus inicial de `test/qa/`
y los scripts de reporte bajo `tool/`.

Cambios ajenos o artefactos que ya estaban en el árbol y no deben confundirse
con esta entrega: `.coverage` y `android/build/`.

## Para continuar

1. Leer primero `test/qa/reporte_final.json` si se necesita auditar un turno
   concreto.
2. Revisar lingüísticamente las descripciones provisionales de `HOMICIDIO` y
   `FRAUDE`; no convertirlas en señas oficiales sin esa revisión.
3. Si se decide publicar el arreglo de `aws/lambda_function.py`, desplegarlo
   por el procedimiento normal y volver a ejecutar el QA estricto.
4. Mantener la prioridad actual: una ruta determinista segura del grafo gana
   sobre RAG; RAG entra cuando el grafo no tiene una respuesta segura o solo
   identificó el tema.

No se creó commit, rama, PR ni push.
