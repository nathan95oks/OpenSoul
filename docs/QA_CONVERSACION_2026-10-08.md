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
| Hoy, con las Lambdas desplegadas | 28 de 95 |
| Tras redesplegar las dos Lambdas (simulado, §6) | **23 de 95** |

Son 29 conversaciones (C01–C29); C26–C29 son nuevas y reproducen los cuatro
problemas reportados. Los cuatro quedan corregidos. Los 23 turnos que siguen
fallando no se tapan con reglas por frase: son preguntas que el banco no tiene
(§5), con su causa.

Pruebas: Flutter 1143 ✓ · `flutter analyze` sin observaciones · aws/tests 450 ✓
· tool/tests 132 ✓ · `build_rag_corpus.py --check` ✓.

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
podía leer. Corregido en `aws/lambda_function.py` (falta desplegar).

## 3. Los cuatro problemas reportados

### 3.1 «Buenas tardes» y «buenas noches» salían BUENOS_DÍAS

**Causa:** el catálogo del avatar solo trae BUENOS_DÍAS y el modelo convertía
cualquier saludo en él. **Corrección** (Lambda Texto→LSB,
`enforce_spoken_form_fidelity`): el saludo dicho manda; BUENAS_TARDES y
BUENAS_NOCHES son señas del Módulo 1 y no se deletrean. **Requiere redesplegar.**

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
   ranuras de interrogativos que nadie dijo. *Requiere redesplegar.*
2. **PREGUNTA deletreada al final de cada pregunta** (P-R-E-G-U-N-T-A en el
   avatar). En LSB la pregunta se marca con la cara. Se retira si el oyente
   no dijo «pregunta». *Requiere redesplegar.*
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
   *Requiere redesplegar.*
9. **Desempate con el modelo.** El cliente ya no manda candidatas que la
   Lambda no conoce (antes ese 400 rechazaba el pedido entero).

Se probó y se descartó una pista `acos` → violencia para «acoso». Abría el
recorrido general de violencia («Me pegaron.») en lugar del trámite de acoso,
así que no se dejó.

## 5. Lo que todavía falla (23 turnos) y por qué

Ninguno se arregla bien con una regla por frase. Se indica qué haría falta.

| Turnos | Causa | Qué haría falta |
|---|---|---|
| C02 «¿Está en peligro ahora mismo?», «¿Está herida? ¿Le duele algo?», «¿Esto ya le pasó antes?», «¿Necesita que la llevemos al médico?»; C15 «¿Necesita atención médica?» | El recorrido de violencia no tiene esas preguntas con esas palabras; PELIGRO, MÉDICO y ANTES salen deletreadas y no aportan significado | Agregar al banco de violencia frases del corpus para riesgo y salud, o señas para PELIGRO/MÉDICO |
| C03 «¿A qué número la podemos llamar?», C04 «¿Puede leer lo que le escribo?» | Coincidencia débil: NÚMERO deletreado; LEER coincide con dos preguntas | Variantes en el banco de identificación y accesibilidad |
| C05 cédula perdida, C06 certificado de nacimiento | El grafo tiene «¿Le falta su carnet?» y «¿Tiene un certificado?» (robo, testimonio) y ganan a los trámites SEGIP/SERECI | Que una pregunta de trámite de otra área gane cuando nombra un documento propio de ese trámite (NACIMIENTO) |
| C09 «¿Habló con el maestro?», C10 «¿Tiene una foto de ella?» | El trámite (DNA, trata) no tiene esa pregunta | Agregar el turno al escenario, con palabras existentes o azules con descripción |
| C11 «¿Tiene el comprobante?» | Abre «¿Qué comprobante tiene?» en vez de «¿Tiene comprobante?» (COMPROBANTE deletreado) | Seña o equivalencia para COMPROBANTE |
| C14 «No le pregunto por el robo, le pregunto por su cédula. ¿La trae?» | Negación de un tema y anáfora («la») | Leer la negación de contexto en la Lambda |
| C17 «¿Cómo se llama y cuántos años tiene?» | Sin interrogativo de «cómo se llama»; abre la edad del agresor | Ranura «nombre propio» y pregunta de edad propia |
| C18 «¿Viene a ver cómo va su denuncia?» | «Denuncia» nombra la familia, no Seguimiento | Pista «ver cómo va» → seguimiento en `SITUATION_CUES` (con revisión lingüística) |
| C19 «Aquí atendemos robos. Para violencia tiene que ir a la FELCV.» | Derivación: no hay paso «ir a otra oficina» fuera de los trámites | Indicación de derivación en el grafo |
| C21 «¿Qué vio exactamente?», «¿Podría declarar como testigo?» | Coinciden con «¿Vio al ladrón?» y «¿Hay testigos?» | Preguntas propias en el recorrido «otro» |
| C22 «¿Un funcionario la discriminó por ser sorda?», «¿Se burlan de usted…?» | Solo SORDO coincide, y la persona termina diciendo «Sí, soy una persona sorda.» | Penalizar una coincidencia que deja sin cubrir una seña de contenido (BURLAR); que el trámite LSB-201 gane |

**Recomendación aparte:** abrir un trámite por su título cuando el
funcionario lo nombra («¿Quiere denunciar acoso sexual?» → «Denunciar acoso
sexual»). Hoy se abre la familia Denuncias y la persona elige (también con el
buscador). Es fluido, pero tiene un paso más.

No se agregaron escenarios nuevos: los que faltan arriba necesitan palabras
que todavía no tienen seña y conviene revisarlos con la comunidad antes de
escribirlos.

## 6. Despliegue pendiente

Hay que desplegar las **dos** Lambdas (mismo procedimiento que la vez
anterior, con zip):

1. `aws/lambda_text_to_lsb.py` (Texto→LSB): saludo dicho, marca PREGUNTA,
   QUIÉN por «quiere», ranuras de interrogativos dichos, pistas `fraud` y
   `violaci`, y `repair_cached_translation`. Lo ya guardado en caché se
   repara al servirlo.
2. `aws/lambda_function.py` (LSB→Texto/Audio): lectura completa del JSON de
   Nova en el desempate `route`.

Después, para medir con la Lambda real:

```
# borrar de test/qa/lambda_respuestas.json las entradas "texto/…" y las
# "api/translate|{\"action\":\"route\"…" (o el archivo completo), y luego:
flutter test test/qa_conversacion_test.dart --dart-define=LSB_API_URL=https://api.qa.invalid/translate --dart-define=LSB_TEXT_API_URL=https://texto.qa.invalid/translate
python tool/qa_capturar_lambdas.py      # repetir prueba + captura hasta que no quede nada
REPORTE_QA=test/qa/reporte.json QA_ESTRICTO=1 flutter test test/qa_conversacion_test.dart --dart-define=...
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
