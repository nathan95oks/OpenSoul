# QA del módulo Conversación — 2026-10-09

Nueve casos reportados con frases reales del funcionario: testigos, fiscal,
investigador, cámaras, «¿a dónde tiene que ir?», acoso sexual, fotos
publicadas y bullying. Cada uno se reprodujo primero contra las Lambdas
desplegadas (traducción real, ruta y respuesta de la persona sorda) y quedó
como guion del QA (C30–C35).

## 1. Resultado

| Medición | Resultado |
|---|---|
| QA estricto, respuestas grabadas | **35 de 35 conversaciones, 0 de 112 turnos con falla** |
| Flutter | 1144 ✓ · `flutter analyze` sin observaciones |
| aws/tests | 453 ✓ |
| tool/tests | 137 ✓ |
| `build_rag_corpus.py --check` · `build_question_matrix.py --check` | ✓ · ✓ |

Los flujos completos, turno por turno, están en
[FLUJOS_CONVERSACION_2026-10-09.md](FLUJOS_CONVERSACION_2026-10-09.md).

## 2. Los casos reportados

| Funcionario | Antes | Ahora |
|---|---|---|
| «¿Quiénes son los testigos?» (robo) | ¿Conoce a la persona involucrada? (el autor) | **¿Conoce a los testigos?** Sí → nombre y celular del testigo («El testigo se llama…», «El número de celular del testigo es…») |
| «¿Quiere saber quién investigará su caso?» | ¿A quién vio? (hombre / mujer / ladrón) o ¿Con quién quiere hablar? | **Sí / No** («Sí, quiero saber quién investigará mi caso.») |
| «¿Sabe quién es su fiscal?» | ¿Con quién quiere hablar? o ¿Conoce a la persona que le escribe? (ciberacoso) | **Sí / No.** Sí pide el nombre: «Sí, mi fiscal es {nombre}.» · No: «No sé quién es mi fiscal.» |
| «¿Hay cámaras en esa calle?» (robo) | No abría nada | ¿Hay cámaras o video del lugar? (sin conversación previa, la pregunta del trámite de robo de la FELCC) |
| «¿Entiende a dónde tiene que ir?» | ¿Dónde ocurrió? (calle, avenida, plaza…) | Contexto **Derivación**: FELCC, FELCV, Fiscalía, Policía, SEPDAVI, SEPDEP, juzgado o «No sé, dígame usted» |
| «¿La acosaron sexualmente?» | No abría nada | El trámite **Denunciar acoso sexual (FELCV)** |
| «¿Conoce a la persona que lo acosa?» | Solo sí / no | Sí → **¿Quién es esa persona?** (jefe, compañero, pareja, amigo, pariente, no sé) |
| «¿Publicaron fotos suyas sin su permiso?» (amenazas) | ¿Tiene fotos de la pantalla? («No tengo fotos de la pantalla.») | ¿Publicaron sus fotos sin su permiso? · No → «No, no publicaron nada.» |
| «¿Usted o su hijo sufre bullying?» | ¿Su hijo tiene heridas o dolor? (HIJO HERIDA DOLOR TENER **NO**) | **¿Su hijo sufre bullying?** (y la de heridas, sin el NO) |
| «¿Habló con alguien más sobre este acoso?» | Saltaba al robo: ¿Hay testigos? | Sí / No / No sé; Sí → **¿Con quién habló?** |

## 3. Causas y correcciones

### 3.1 Datos (banco y escenarios)

- **Banco** (`docs/negocio/config/banco_preguntas.json`): siete preguntas
  nuevas. Son Q.TES.CONOCE, Q.TES.NOMBRE y Q.TES.TELEFONO (en el robo, tras
  «Sí, hay testigos»), Q.SEG.CONOCE_FISCAL, Q.SEG.SABER_INVESTIGADOR,
  Q.ORI.DESTINO y Q.DIG.PUBLICACION. Q.EVI.CAMARAS entra al recorrido del robo
  con variantes («¿Hay cámaras en esa calle?»). El fiscal y el investigador se
  preguntan **solo en conversación** (`soloConversacion`): no aparecen al
  armar una denuncia a solas.
- **Contexto «Derivación»** (familia Consultas), declarado con datos en el
  banco: es el primero que usa ese mecanismo. «¿Sabe a dónde tiene que ir?»
  vale para cualquier caso. Repetida en seis recorridos, el router no podía
  elegir uno sin adivinar y abría el selector. El nombre se eligió para no
  chocar con otras frases: «orientación» ya nombra a «¿Desea orientación…
  SEPDAVI?» e «institución» a «¿Ante qué institución…?».
- **Escenarios** (`violencia_acoso_y_trata_escenarios.md`):
  - ESC-FELCV-201 (acoso sexual) gana «¿La acosaron sexualmente?», «¿Quién es
    esa persona?», «¿Habló con alguien más sobre este acoso?» y «¿Con quién
    habló?».
  - ESC-FELCC-202 (acoso físico) gana «¿Quién es esa persona?».
  - ESC-DNA-201 (bullying) gana «¿Su hijo sufre bullying?», con la variante
    «¿Usted o su hijo sufre bullying?».
  - Los turnos de esos tres escenarios cambiaron de número. Las pruebas se
    renumeraron.
- **Glosas corregidas** (`glosas_correcciones.json`):
  - Se quitó el NO que la Lambda agregó sin negación en el español: «¿Su hijo
    tiene heridas o dolor?», «¿Tiene la matrícula de la casa que consulta?»,
    «¿Usaron violencia para quitarle el objeto?», «¿La acosaron
    sexualmente?» y «Sí, me acosaron sexualmente.».
  - PARENTE → PARIENTE.
  - SUFRE → SUFRIR.
  - SEXUALMENTE / SEXO → ACOSO_SEXUAL, que ya tiene su descripción.

### 3.2 Reglas generales

1. **Una rama que precisa un «sí» se pregunta junto con él**
   (`build_rag_corpus.py`). En «### Ramificaciones»,
   `- **Turno 8:** si Turno 6 es afirmado (se pregunta junto)` vuelve
   obligatoria la rama. En la conversación, la ruta de un trámite trae sus
   hijas obligatorias con el mismo camino mínimo que el banco
   (`ragTramiteRoute`). Así, tras «Sí, conozco a esa persona» se pregunta
   quién es.
2. **El tema no es la ruta provisional de una pregunta respondida en un
   trámite** (`Conversation.topicContextWhere`). Antes, «¿Conoce a la persona
   que lo acosa?» quedaba con la ruta provisional del grafo (el robo), aunque
   se respondió en el trámite de acoso. La pregunta siguiente se leía como
   robo y «¿Habló con alguien más…?» terminaba en «¿Hay testigos?».
3. **Casi literal no es literal si falta la palabra que identifica la
   pregunta** (`GraphMatcher._bestEntry`). «¿No sabe quién fue?» contra «¿Sabe
   quién es su fiscal?» daba 2·2/(2+3) = 0,80, justo el umbral de frase
   literal, sin decir «fiscal». Ahora una forma documentada a la que le falta
   una palabra propia (de tres preguntas o menos) queda por debajo del
   umbral.
4. **Empate por ranura: gana la que el recorrido activo pregunta antes**
   (`GraphMatcher._bySlot`). En la violencia, «¿No sabe quién fue?» es el
   agresor, no los testigos.
5. **Lambda Texto→LSB: una negación que nadie dijo se retira**
   (`enforce_spoken_form_fidelity`). «¿La acosaron sexualmente?» salía
   ACOSAR SEXUALMENTE ELLA **NO**, y el avatar preguntaba lo contrario. Un NO
   se conserva si el español niega: no, sin, ni, nadie, nada, nunca, jamás,
   tampoco, ningún, negar, prohibido, imposible, faltar, evitar.
   **Sin desplegar** (§4).

### 3.3 Lo que se descartó

- **Testigos en el recorrido de violencia.** Con la misma pregunta en dos
  recorridos, «¿Cuántos testigos hay?» sin conversación previa abre el
  selector, porque el router no elige un contexto a ciegas. Queda solo en el
  robo; el trámite de acoso ya tiene «¿Tiene testigos?».
- **Una regla deducida para las ramas abiertas.** Marcaba también «¿Qué
  documentos trajo?» tras «Sí, traje mi cédula», que no precisa esa
  respuesta. Se reemplazó por la marca explícita «(se pregunta junto)».
- **La variante «¿Sabe quiénes son los testigos?».** Hacía que cualquier
  «¿sabe quién…?» fuera la pregunta de los testigos.
- **Señas equivalentes recalculadas.** `rag_actualizar.py` volvió a calcular
  todas las equivalencias con Bedrock y cambió trámites que nadie revisó
  (NEGAR → NEGATIVO, PSICOLÓGICO → PSICOLOGÍA). Se restauró
  `senas_equivalentes.json`.

## 4. Pendiente

- **Desplegar las dos Lambdas.**
  - Texto→LSB (`aws/lambda_text_to_lsb.py`): la regla 3.2.5.
  - LSB→Texto/Audio: `aws/question_bank.json` tiene las preguntas nuevas.
    Hoy la Lambda no las conoce, y la app usa su redacción local, que es la
    correcta.

  Después hay que volver a grabar `test/qa/lambda_respuestas.json`: las
  frases del funcionario grabadas todavía traen el NO.
- **LSB→Texto/Audio redacta mal «¿Vino a consultar el estado de su caso?» →
  Sí.** Contra la Lambda desplegada salió «El estado del caso es confirmado
  como SÍ, según la consulta realizada en el marco del seguimiento.». No es de
  esta ronda; hay que revisar su redacción guiada.
- **«PERMISO NO» es «sin permiso».** El diccionario no tiene la seña SIN y en
  LSB la negación va después. Para cambiarlo hace falta una seña nueva.
- **«¿Quiénes son los testigos?» dentro del trámite de acoso abre «¿Tiene
  testigos?».** Los trámites no admiten respuestas escritas (nombre,
  celular): eso existe solo en el banco.
- **«Compañera.» para COMPAÑERO.** Es la primera forma del catálogo de
  señas.

## 5. Cómo se prueba

- `test/qa_conversacion_test.dart`, guiones C30–C35: testigos, fiscal e
  investigador, acoso sexual, fotos, bullying y derivación sin conversación
  previa.
- `test/qa_conversacion_2026_10_09_test.dart`: los casos de §2 con las glosas
  reales, «¿No sabe quién fue?» en la violencia, la ruta del trámite con
  «¿Quién es esa persona?» y el tema tras responder en un trámite.
- `aws/tests/test_fidelidad_forma_hablada.py` (`NegacionNoDicha`) y
  `tool/tests/test_rag_ingesta_y_ramas.py` (`SePreguntaJunto`).
