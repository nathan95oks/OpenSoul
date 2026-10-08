# QA del módulo Conversación — 2026-10-08

Pruebas con preguntas reales de funcionario (y algunas hechas para romper el
sistema) contra las **respuestas reales grabadas** de las Lambdas desplegadas.
Cada turno se juzga con lo que haría una conversación coherente entre la
persona sorda y el funcionario: qué tarjetas se abren, qué señas se traducen
y qué termina diciendo la persona sorda.

Reemplaza a `QA_CONVERSACION_CONTINUACION_CODEX_2026-10-08.md` (ver §2).

## 1. Resultado

| Medición | Turnos con falla |
|---|---|
| Línea base, antes de corregir (`reporte_rag.json`) | 33 de 85 |
| Lambdas nuevas desplegadas, primera medición | 19 de 95 |
| **Tras corregir las 19 (§5), Lambdas desplegadas, modo estricto** | **0 de 95** |

Son 29 conversaciones (C01–C29), medidas contra las respuestas reales de las
Lambdas desplegadas. El 0 de 95 se repitió en dos pasadas estrictas
seguidas. Desde ahora el QA es estricto por defecto: una falla rompe la
prueba (`QA_ESTRICTO=0` lo vuelve informativo).

No se logró con reglas por frase. Las 19 se corrigieron con reglas generales
del motor y con datos (variantes del banco y de los escenarios, un escenario
nuevo); el detalle está en §5. Se revisó turno por turno qué contesta la
persona sorda, no solo si la prueba pasa.

El desempate con Bedrock ya funciona en producción. Cuando propone una
pregunta que no responde a lo pedido, la app la rechaza con el mismo
validador de las rutas deterministas y no abre nada.

Pruebas: Flutter 1119 ✓ (más los 29 guiones del QA, que necesitan las URLs
de QA) · QA estricto 95/95 ✓ · `flutter analyze` sin observaciones ·
aws/tests 450 ✓ · tool/tests 132 ✓ · `build_rag_corpus.py --check` ✓ ·
`build_question_matrix.py --check` ✓.

## 2. Verificación de lo que hizo Codex

Codex informó 25/25 conversaciones sin fallas. Ese resultado dependía de
`_naturalLanguageRoute`: unas 45 reglas que reconocían **frases concretas de
los guiones** («¿Tiene la factura o la caja…?», «homicidio» → «otro», etc.).
Pasaban la prueba porque estaban escritas para ella, no porque el sistema
entendiera mejor. Eso contradice la regla del proyecto de no enrutar frases a
mano, y no generaliza: «¿Tiene la caja o la factura?» ya no entraba.

| Cambio de Codex | Decisión | Motivo |
|---|---|---|
| `_naturalLanguageRoute` (~45 reglas por frase) | **Retirado** | Sobreajuste a los guiones; se reemplazó por reglas generales (§4) |
| Catálogo del router con todos los trámites RAG (`injection.dart`) | **Revertido** | Los pasos de trámites competían con el grafo: «¿Dónde ocurrió?» abría un paso de Fiscalía. La continuidad dentro de un trámite se resolvió sin esto (§4.7) |
| `homicidio` → «Declaración y testimonio» | **Retirado** | Inventaba un contexto; ahora se abre Denuncias y elige la persona |
| `_expectsAnswer` (una indicación no abre preguntas) | Conservado, ajustado | Un dictado por voz sin puntuación no se toma como indicación |
| Normalización de «dnde», «cndo» | Conservado | Se agregó «q» → «qué» |
| `asksStolenObject` («¿qué hora…?» no es un objeto robado) | Conservado | Correcto |
| `scenarioBonus` / `preferScenarioId` del RAG | Conservado | Correcto |
| HOMICIDIO y FRAUDE azules con descripción; VIOLACIÓN es seña D2024; estafa → ENGAÑAR | Conservado | Verificado en `test/delitos_conversacion_test.dart` |
| Expectativas de guiones | 2 relajadas (aceptar el trámite FELCC del robo) | Razonables |

Además, el desempate con el modelo (`route`) **nunca funcionó en producción**:
todas sus respuestas grabadas son `model_error`. `invoke_bedrock_json` leía
solo la primera línea de la respuesta de Nova y el JSON en varias líneas no se
podía leer. Corregido en `aws/lambda_function.py` y desplegado.

## 3. Los cuatro problemas reportados

### 3.1 «Buenas tardes» y «buenas noches» salían BUENOS_DÍAS

**Causa:** el catálogo del avatar solo trae BUENOS_DÍAS y el modelo convertía
cualquier saludo en él. **Corrección** (Lambda Texto→LSB,
`enforce_spoken_form_fidelity`): el saludo dicho manda; BUENAS_TARDES y
BUENAS_NOCHES son señas del Módulo 1 y no se deletrean. Desplegado.

```
Funcionario: Buenas tardes, ¿en qué le puedo ayudar?
  antes   BUENOS_DIAS PUEDO AYUDAR
  ahora   BUENAS_TARDES PUEDO AYUDAR      → la persona elige el motivo
Sorda:    Me robaron algo.
Funcionario: Buenas noches. ¿Qué le robaron?
  antes   BUENOS_DIAS ROBAR QUE
  ahora   BUENAS_NOCHES ROBAR QUE         → «¿Qué le robaron?»
Sorda:    Me robaron el celular.
```

### 3.2 «¿Cuándo y a qué hora…?» abría solo «cuándo»

**Causa:** las dos piden un tiempo y el router abría una sola pregunta por
dato. **Corrección:** cada «qué/cuál + núcleo» del español («a qué HORA») es su
propia pregunta si el contexto la tiene. Si es la única forma de preguntar
ese dato («¿A qué hora fue?»), reemplaza a «¿Cuándo ocurrió?». Si «cuándo»
también se dijo, van las dos. Funciona en cualquier contexto (también en
violencia, cuyo recorrido no tiene la hora).

```
Funcionario: ¿Cuándo, dónde y a qué hora le robaron?
  antes   ¿Qué le robaron? / ¿Cuándo ocurrió? / ¿Dónde ocurrió?
  ahora   ¿Cuándo ocurrió? / ¿Dónde ocurrió? / ¿A qué hora aproximadamente?
Sorda:    Ocurrió hace un momento. Ocurrió en la calle. Fue por la tarde.
```

### 3.3 Acoso sexual y acoso físico: «jefe» y «vive cerca de su casa» en el audio

**Causa:** al elegir SÍ se decía la respuesta documentada del escenario: «Sí,
es mi jefe.» para «¿Conoce a la persona que la acosa?» (FELCV-201) y «Sí, vive
cerca de mi casa.» para «¿Conoce a esa persona?» (FELCC-202). Nadie había
mencionado un jefe ni una casa: era poner datos en boca de la persona.

**Corrección** (`tool/build_rag_corpus.py`, `sin_contenido_nuevo`): SÍ, NO y NO
SÉ dicen la respuesta documentada solo si no agrega contenido a lo preguntado.
Si no hay una así, se dice la partícula sola («Sí.»). Cambiaron 96 frases en
todo el corpus (34 SÍ, 62 NO), por ejemplo «Sí. Perdimos la copia anterior.»
→ «Sí.». Las que confirman lo preguntado se conservan («Sí, me tocó sin mi
permiso.»).

### 3.4 Acoso: «Entendido / No entiendo» sin sentido

**Causa:** las indicaciones del funcionario («La FELCV es la unidad
especializada contra la violencia.») eran pasos del trámite. Armando el
trámite en tarjetas, nadie las había dicho y la persona contestaba
«Entendido» a la nada. **Corrección:** en un trámite que tiene preguntas, las
indicaciones se marcan `soloConversacion`: aparecen solo cuando el
funcionario las dice. Son 27 pasos.

```
Funcionario: ¿Quiere denunciar acoso sexual?
  → familia Denuncias; la persona elige «Denunciar acoso sexual» (FELCV)
Funcionario: ¿Conoce a la persona que la acosa?
  antes   Sí, es mi jefe.
  ahora   Sí.
Funcionario: La FELCV es la unidad especializada contra la violencia.
Sorda:    Entendido.        (ahora sí la dijo el funcionario)
```

```
Funcionario: ¿Viene a denunciar acoso físico?
  → familia Denuncias; la persona elige «Acoso físico» (FELCC)
Funcionario: ¿Conoce a esa persona?
  antes   Sí, vive cerca de mi casa.
  ahora   Sí.
Funcionario: Para la violencia de pareja corresponde la FELCV.
Sorda:    Entendido.
```

## 4. Otras incoherencias corregidas

Todas son reglas generales, sin frases escritas a mano.

1. **«¿Quiere denunciar…?» se traducía QUIÉN DENUNCIAR**, y el sistema
   preguntaba «¿Conoce a la persona involucrada?». La Lambda cambia QUIÉN por
   QUERER cuando el español dice «quiere» y no «quién». También descarta las
   ranuras de interrogativos que nadie dijo. *Desplegado.*
2. **PREGUNTA deletreada al final de cada pregunta** (P-R-E-G-U-N-T-A en el
   avatar). En LSB la pregunta se marca con la cara. Se retira si el oyente
   no dijo «pregunta». *Desplegado.*
3. **Apertura de ventanilla.** «¿En qué le puedo ayudar?» y «Hola, ¿qué le
   pasó? Cuénteme…» abren el selector de motivo. Antes no abrían nada o
   abrían una calificación de discapacidad contestada con «Entendido.». Un
   trámite del RAG ya no reemplaza ese selector. «Lo que pasó» es una
   relativa y no cuenta como apertura: «¿Usted fue testigo de lo que pasó?»
   sigue abriendo Declaración y testimonio.
4. **Indicaciones que abrían preguntas.** «Firme aquí, por favor.»
   respondía «La tengo aquí.»; ahora no abre nada. Un dictado sin puntuación
   («vino a consultar el estado de su caso») no se toma como indicación.
5. **Preguntas compuestas.** «¿Tiene la factura o la caja del celular?» no
   abría nada. Ahora abre sus dos partes, cada una con SÍ / NO / NO SÉ: es una
   derivación del banco y se generalizó para cualquier pregunta de ese tipo.
6. **«dnde paso eso»** contestaba «Entendido.» a un trámite de discapacidad.
   Ahora abre «¿Dónde ocurrió?».
7. **Continuidad en los trámites.** El grafo no conoce los trámites RAG.
   Dentro de uno:
   - su propia pregunta sigue el hilo, en vez de abrir una parecida de otro
     contexto;
   - el grafo sigue con el último contexto que conoce: «¿Quiere presentar la
     denuncia formal?» durante el trámite de robo abre «¿Desea presentar una
     denuncia?», ya no «presentar estos elementos» de otro contexto.
8. **Fraude, estafa y violación** abren su contexto (Engaño con dinero,
   Denunciar violencia). Se usan las pistas lingüísticas de la Lambda
   (`SITUATION_CUES`: `fraud`, `violaci`). **Homicidio** no tiene contexto
   propio: abre Denuncias y elige la persona, sin inventar uno.
   *Desplegado.*
9. **Desempate con el modelo.** El cliente ya no manda candidatas que la
   Lambda no conoce (antes ese 400 rechazaba el pedido entero).

Se probó y se descartó una pista `acos` → violencia para «acoso». Abría el
recorrido general de violencia («Me pegaron.») en lugar del trámite de acoso,
así que no se dejó.

## 5. Las 19 fallas restantes: cómo se corrigieron

Los cambios de esta parte los hicimos Claude y Codex sobre el mismo árbol;
se revisaron los de Codex y son reglas generales (abajo, marcadas «Codex»).

**Reglas generales del motor**

1. *Lo que nadie entendió no se ignora.* El puntaje por texto ignoraba las
   palabras que el corpus no conoce, y SORDO solo bastaba para abrir
   «¿Usted es una persona sorda?» ante «¿Se burlan de usted por ser sorda?».
   Ahora, si una palabra de contenido no la conoce el corpus y la traducción
   la perdió (salió deletreada, o su seña no está en ninguna pregunta), una
   coincidencia por el resto no es segura. «Chorearon» no cuenta: llega
   como ROBAR.
2. *Abierta con abierta, sí/no con sí/no.* «¿Qué vio exactamente?» abría
   «¿Vio al ladrón?» («Sí, vi a la persona que me robó.»); «¿Tiene la
   denuncia de pérdida?» abría «¿Qué tiene?» («Tengo fotos.»). Se juzga por
   la formulación oficial de cada pregunta; las disyuntivas («¿Era hombre o
   mujer?», «¿Tiene fotos o videos?») no cuentan como sí/no, y una
   subordinada («¿Viene a ver cómo va su denuncia?») no la vuelve abierta
   (Codex).
3. *Afirmaciones e indicaciones.* Una afirmación del funcionario solo abre
   una indicación documentada; antes «Para violencia tiene que ir a la
   FELCV.» terminaba en «Sí, hay un testigo.». Y una pregunta no abre una
   indicación («¿Fue con violencia?» → «Entendido.» no).
4. *La pregunta documentada literal gana.* Si un trámite tiene la frase del
   funcionario casi literal y el grafo solo coincidió por una seña («¿Tiene
   la denuncia de pérdida?» → «¿Tiene el número de referencia?»), abre el
   trámite. Codex además movió las coincidencias literales del grafo antes
   que las semánticas; una disyuntiva queda fuera de esa prioridad.
5. *El contexto activo desambigua* una coincidencia única de su propio
   recorrido apenas por debajo del umbral (Codex).
6. *Una mención negada no abre el tema*: «No le pregunto por el robo, le
   pregunto por su cédula» no abre el robo (Codex; solo con verbos de
   discurso: «no sabe quién robó» sigue siendo robo).

**Datos (sin código)**

- El router ya lee las `variantes` del banco: estaban escritas y nunca se
  usaban. Se agregaron frases reales con respuestas que encajan, por
  ejemplo «¿Esto ya le pasó antes?» → «¿Es la primera vez o pasa seguido?»,
  «¿A qué número la podemos llamar?» → número de celular, «¿Viene a ver
  cómo va su denuncia?» → estado del caso, «¿Qué vio exactamente?»,
  «¿Podría declarar como testigo?», «¿Alguien vio lo que pasó?» y «¿Trae su
  carnet de identidad?» (Codex).
- Variantes en escenarios: «¿Habló con el maestro?» (DNA), «¿Tiene una foto
  de ella?» (trata), «¿Un funcionario la discriminó por ser sorda?» (LSB),
  «¿Perdió su cédula de identidad?» y «¿Tiene la denuncia de pérdida?»
  (SEGIP), «¿Trajo su certificado de nacimiento?» (SERECI), «Para violencia
  tiene que ir a la FELCV.» (FELCC).
- Escenario nuevo `ventanilla_escenarios.md` · ESC-SERECI-201 «Pedir un
  certificado de nacimiento», que empieza el funcionario («¿Viene por un
  certificado de nacimiento?», «¿El certificado es suyo?»…). Solo palabras
  con seña o ya descritas.

**Lo que queda aceptable pero no exacto** (pasa, y se dice):

- «¿Está en peligro ahora mismo?» abre «¿Necesita auxilio ahora?» («Sí,
  necesito auxilio ahora.»): el recorrido de violencia no tiene una pregunta
  de peligro.
- «¿Necesita que la llevemos al médico?» abre la asistencia médica y además
  «¿Qué le hicieron?» y «¿Está herido?», pasos previos de ese recorrido.
- «¿Trajo su certificado de nacimiento?» abre el de SEGIP (original
  computarizado): la misma frase existe en SEGIP y SERECI.
- «¿Cómo se llama y cuántos años tiene?» durante un robo se lee como datos
  de la persona sorda (presente: «se llama», «tiene»), no del agresor.

## 6. Despliegue

**Hecho el 2026-10-08.** Smoke check contra el endpoint: 8/8. Las respuestas
de `test/qa/lambda_respuestas.json` se volvieron a grabar contra lo
desplegado (Texto→LSB y `route`). Se desplegaron las **dos** Lambdas:

1. `aws/lambda_text_to_lsb.py` (Texto→LSB): saludo dicho, marca PREGUNTA,
   QUIÉN por «quiere», ranuras de interrogativos dichos, pistas `fraud` y
   `violaci`, y `repair_cached_translation`. Lo ya guardado en caché se
   repara al servirlo.
2. `aws/lambda_function.py` (LSB→Texto/Audio): lectura completa del JSON de
   Nova en el desempate `route`.

La corrección de las 19 fallas (§5) no cambió código de las Lambdas. Sí
cambió `aws/question_bank.json`, que va dentro del zip de LSB→Texto/Audio:
solo ganó `variantes`, que la Lambda no usa para redactar. No hace falta
redesplegar ya; conviene incluirlo en el próximo zip para que el banco de la
Lambda y el de la app sigan iguales (`python aws/deploy/build_package.py`).

Para volver a medir con la Lambda real:

```
# borrar de test/qa/lambda_respuestas.json las entradas "texto/…" y las
# "api/translate|{\"action\":\"route\"…" (o el archivo completo), y luego:
QA_ESTRICTO=0 flutter test test/qa_conversacion_test.dart --dart-define=LSB_API_URL=https://api.qa.invalid/translate --dart-define=LSB_TEXT_API_URL=https://texto.qa.invalid/translate
python tool/qa_capturar_lambdas.py      # repetir prueba + captura hasta que no quede nada
REPORTE_QA=test/qa/reporte.json flutter test test/qa_conversacion_test.dart --dart-define=...   # estricto por defecto
```

**Cómo se simuló el redespliegue:** las frases del QA ya están en la caché S3
de la Lambda. Desplegada la versión nueva, pedirlas otra vez es un acierto de
caché, que pasa por `repair_cached_translation` y `build_semantic_turn`.
`tool/qa_simular_redespliegue.py` aplica esas mismas funciones a lo grabado
y la prueba las usa con `RESPUESTAS_QA=test/qa/lambda_respuestas_redespliegue.json`.
No simula a Bedrock: el desempate `route` sigue como se grabó (`model_error`).

## 7. Cómo se prueba

- `test/qa_conversacion_test.dart` reproduce `test/qa/guiones_conversacion.json`
  con las respuestas grabadas, sin red. Comprueba ruta, contexto, trámite,
  glosas (`glosas_contienen` / `glosas_no_contienen`) y lo que dice la persona
  sorda (`sorda_no_dice`). Cuando se abre una familia, la persona elige su
  caso como en la app.
- `test/qa_regresiones_conversacion_test.dart`: hora, apertura, «lo que
  pasó», selector frente al RAG, dictado sin puntuación, indicaciones y SÍ
  sin datos inventados.
- `test/delitos_conversacion_test.dart`: homicidio, violación, fraude y
  estafa (azules, señas y contexto), y la pregunta compuesta factura/caja.
- `aws/tests/test_fidelidad_forma_hablada.py`,
  `aws/tests/test_semantic_turn_audio_a_lsb.py`,
  `aws/tests/test_conversation_route.py` (respuesta real de Nova en varias
  líneas) y `tool/tests/test_build_rag_corpus.py`
  (`RespuestaPolarSinDatosNuevos`).
