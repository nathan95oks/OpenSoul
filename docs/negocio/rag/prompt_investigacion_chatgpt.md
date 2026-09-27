# Prompt para ChatGPT: escenarios reales de trámites en Cochabamba

Úsalo en ChatGPT con **búsqueda web activada** (o en modo «Investigación
profunda» / *Deep research*). Copia todo lo que está debajo de la línea.

---

## Rol

Eres un investigador de trámites públicos de Bolivia. Documentas cómo se
atiende a una persona sorda en ventanillas reales de **Cochabamba (Cercado y
municipios del área metropolitana)**. Tu trabajo alimenta un sistema de
recuperación (RAG) de una app que traduce entre Lengua de Señas Boliviana (LSB)
y español. **La precisión es más importante que la cantidad:** un precio o
requisito inventado puede hacer que una persona sorda pierda un día de trámite.

## Objetivo

Producir un documento Markdown con **escenarios de diálogo realistas** entre un
**Usuario Sordo** (que se comunica por la app) y un **Funcionario** de
ventanilla. Cada escenario debe apoyarse en **información oficial verificada**
(costos, requisitos, pasos, horarios, lugares), citando la fuente.

## Instituciones y trámites a cubrir

Busca el **sitio oficial** de cada institución (preferentemente dominios
`.gob.bo`), sus redes sociales oficiales y la normativa publicada. Cubre al
menos:

1. **Derechos Reales – Cochabamba** (Consejo de la Magistratura): Folio Real,
   certificado de gravámenes e hipotecas, certificado alodial, inscripción de
   transferencia.
2. **Impuestos municipales – Gobierno Autónomo Municipal de Cochabamba y
   sistema RUAT**: consulta de deuda de vehículos e inmuebles, descuentos por
   pronto pago, planes de pago, transferencia de vehículo.
3. **Ministerio Público – Fiscalía Departamental de Cochabamba**: presentar
   una denuncia, seguimiento de un caso (NUREJ o número de caso), cómo
   ubicar al fiscal asignado.
4. **Órgano Judicial – Tribunal Departamental de Justicia de Cochabamba**:
   juzgados de familia (asistencia familiar, audiencias), consulta de causas,
   audiencias presenciales o virtuales.
5. **SEPDEP – Servicio Plurinacional de Defensa Pública**: defensor gratuito
   para la persona **denunciada o imputada**, requisitos.
6. **SEPDAVI – Servicio Plurinacional de Asistencia a la Víctima**.
7. **Policía Boliviana – FELCC** (robos, estafas) y **FELCV** (violencia
   familiar o contra la mujer).
8. **SLIM – Servicios Legales Integrales Municipales** y **DNA – Defensoría de
   la Niñez y Adolescencia** del municipio de Cochabamba.
9. **Notarías de Fe Pública** (Dirección del Notariado Plurinacional):
   reconocimiento de firmas, contrato de alquiler o anticrético, poder
   notarial, aranceles oficiales.
10. **SEGIP**: cédula de identidad (primera vez, renovación, pérdida),
    turnos, costos.
11. **SERECÍ**: certificados de nacimiento, matrimonio, defunción.
12. **Registro y carnet de discapacidad** (calificación, carnet, SIPRUNPCD u
    organismo vigente) y la **renta o bono** para personas con discapacidad.
13. **Derechos lingüísticos de la persona sorda**: intérprete de LSB en
    trámites y en procesos judiciales o policiales (Ley N.° 223 y la que
    corresponda), organizaciones de personas sordas en Cochabamba, y cómo
    reclamar ante la **Defensoría del Pueblo** si se niega el intérprete.

Si una institución cambió de nombre o ya no existe, dilo y usa la vigente.

## Reglas de veracidad (obligatorias)

1. **No inventes datos.** Todo costo, requisito, plazo, horario, dirección o
   nombre de oficina debe venir de una fuente que **hayas abierto de
   verdad**.
2. **Cita cada fuente** con título, URL exacta y fecha de consulta
   (AAAA-MM-DD). No construyas URLs de memoria: si no la abriste, no la
   cites.
3. **Jerarquía de fuentes:**
   1. sitio oficial `.gob.bo`;
   2. normativa oficial (Gaceta Oficial, leyes, decretos, reglamentos);
   3. redes sociales oficiales de la institución;
   4. prensa boliviana reconocida (Los Tiempos, Opinión, etc.).

   Los blogs, foros o videos sirven solo para describir **cómo ocurre una
   situación**, nunca para cifras.
4. Si no encuentras un dato en una fuente fiable, escribe **`[VERIFICAR]`**
   en lugar del dato. No lo estimes.
5. Si dos fuentes se contradicen (p. ej. dos precios), anota ambas con sus
   fechas y marca `[CONTRADICCIÓN]`.
6. Distingue siempre:
   - **conocimiento fijo** (igual para todos: precio, requisito, horario);
   - **dato en vivo** (propio de una persona: su deuda, el estado de su
     caso, la fecha de su audiencia).

   Los datos en vivo del diálogo deben ser **ficticios** y marcados como
   ficticios.
7. **Datos personales ficticios:** nombres, números de carnet, NUREJ, placas
   y teléfonos inventados y claramente de ejemplo. Nunca uses datos de
   personas reales.

## Estilo de los diálogos

- **Usuario Sordo:** frases **cortas y concretas**, de 12 palabras o menos,
  una idea por frase, sin modismos ni ironía. Se traducirán a glosas LSB.
  Ejemplo: «Quiero saber cuánto debo de mi moto.»
- **Funcionario:** registro real de ventanilla en Cochabamba (trato de
  «usted»), de 25 palabras o menos por turno. Si necesita decir más, divídelo
  en varios turnos.
- Cada diálogo tiene **entre 6 y 14 turnos** y termina con un cierre claro
  (qué hacer, a dónde ir, cuándo volver).
- Incluye situaciones difíciles reales:
  - le falta un requisito;
  - el pago es en otro lugar (banco o caja) y hay que volver;
  - la oficina está cerrada o el funcionario no está;
  - la persona no entiende y pide que se lo expliquen despacio o por
    escrito;
  - la persona pide un intérprete de LSB;
  - el trámite no corresponde a esa oficina y la derivan;
  - hay que hacer fila, sacar ficha o pedir cita en línea.
- Alterna quién inicia: a veces el **Usuario Sordo**, a veces el
  **Funcionario**.

## Cantidad

- **Al menos 4 escenarios por institución** (13 instituciones: 52 o más
  escenarios).
- En cada escenario, **variantes**:
  - 2 o 3 formas distintas de decir cada pregunta del funcionario;
  - 3 respuestas posibles del usuario sordo para cada pregunta
    (afirmativa, negativa y «no sé» o «no tengo»).
- Como la respuesta será larga, **entrégala por partes** («Parte 1 de N»),
  una o dos instituciones por parte, **sin repetir IDs**. Al final de cada
  parte escribe «CONTINÚA EN LA PARTE X» hasta terminar.

## Formato de salida (respétalo exactamente; se procesa con un programa)

Todo el documento en **Markdown**, en español, con esta estructura:

```markdown
# Escenarios de trámites en Cochabamba — Parte X de N

## Fuentes
| ID | Institución | Título | URL | Consultado |
|---|---|---|---|---|
| F-DDRR-01 | Derechos Reales Cochabamba | … | https://… | 2026-09-27 |

## Hechos verificados
| ID | Institución | Hecho | Tipo | Fuente | Vigencia |
|---|---|---|---|---|---|
| H-DDRR-01 | Derechos Reales | El Folio Real cuesta X Bs. | costo | F-DDRR-01 | según fuente, 2026 |
| H-DDRR-02 | Derechos Reales | [VERIFICAR] horario de atención | horario | — | — |

## ESC-DDRR-01 — Folio Real para saber si una casa tiene hipoteca
- **Institución:** Derechos Reales – Cochabamba
- **Trámite:** Folio Real / certificado de gravámenes
- **Tipo:** conocimiento_fijo | dato_en_vivo | mixto
- **Inicia:** Usuario Sordo | Funcionario
- **Situación:** una o dos frases con el contexto real.

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Usuario Sordo | Hola. Necesito el Folio Real de mi casa. | Iniciar el trámite | — |
| 2 | Funcionario | ¿Trae el número de matrícula o el Folio Real antiguo? | Filtro de búsqueda | H-DDRR-03 |
| 3 | Usuario Sordo | Sí, aquí tengo el Folio antiguo. | Entrega del dato | — |

### Variantes
- **Turno 2 (Funcionario):** «¿Tiene la matrícula del inmueble?» · «¿Trae algún documento de la casa?»
- **Respuestas al turno 2:** «Sí, tengo el Folio antiguo.» · «No tengo ningún papel.» · «No sé qué es la matrícula.»

### Datos ficticios
- Matrícula: 3.01.1.99.0012345 (ficticia)
```

Reglas del formato:

- IDs estables:
  - fuentes: `F-<INST>-NN`;
  - hechos: `H-<INST>-NN`;
  - escenarios: `ESC-<INST>-NN`.
- `<INST>` usa estos códigos: DDRR, IMP, FIS, OJ, SEPDEP, SEPDAVI, FELCC,
  FELCV, SLIM, DNA, NOT, SEGIP, SERECI, DISC, LSB.
- La columna **Hechos** del diálogo cita los `H-…` que usa ese turno. Si un
  turno menciona un costo, requisito u horario, **debe** citar un hecho.
- Nada fuera de esta estructura: sin introducciones largas ni conclusiones.

## Semillas

Estos siete diálogos son **ejemplos de situación, no datos verificados**.
Verifica o corrige sus cifras con fuentes y úsalos como punto de partida:

1. Folio Real en Derechos Reales (costo, pago en banco, volver con el recibo
   sin hacer fila).
2. Deuda de impuestos de moto o auto por placa (años adeudados, descuento por
   pronto pago).
3. Violencia de pareja en la FELCV o el SLIM (riesgo inmediato, psicóloga,
   trabajadora social, intérprete).
4. Seguimiento de una denuncia por robo en la Fiscalía (NUREJ, fiscal
   asignado, días de atención).
5. Fecha de audiencia de asistencia familiar en un juzgado de familia
   (número de juzgado, apellido del demandado, audiencia presencial o
   virtual).
6. Defensor público en el SEPDEP (solo para la persona denunciada;
   requisitos: carnet y notificación).
7. Contrato de alquiler y reconocimiento de firmas en una notaría (arancel
   por firma, presencia de ambas partes, tiempo de entrega).

## Antes de terminar cada parte, comprueba

- [ ] Cada cifra del documento tiene un `H-…` con fuente y fecha, o dice
      `[VERIFICAR]`.
- [ ] Ninguna URL fue inventada.
- [ ] Todos los datos personales son ficticios y están marcados.
- [ ] Los mensajes del Usuario Sordo tienen 12 palabras o menos.
- [ ] Cada escenario tiene sus variantes.
