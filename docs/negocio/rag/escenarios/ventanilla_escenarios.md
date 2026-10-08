<!-- lexico: estricto -->
<!-- Escenarios de ventanilla que empieza el funcionario. Redactados con IA (Claude) a pedido del equipo, 2026-10-08, a partir del QA del módulo Conversación (docs/QA_CONVERSACION_2026-10-08.md): son preguntas reales que el funcionario hace al recibir a la persona y que ningún escenario cubría. Las preguntas no afirman datos; las respuestas son alternativas que la persona elige. -->
# Escenarios de ventanilla

## Fuentes
| ID | Institución | Título | URL | Consultado |
|---|---|---|---|---|

## Hechos verificados
| ID | Institución | Hecho | Tipo | Fuente | Vigencia |
|---|---|---|---|---|---|

## ESC-SERECI-201 — Pedir un certificado de nacimiento

- **Institución:** SERECI – Cochabamba
- **Trámite:** Pedir un certificado de nacimiento
- **Tipo:** mixto
- **Inicia:** Funcionario
- **Situación:** El funcionario de SERECI recibe a una persona sorda, le pregunta si viene por un certificado de nacimiento y para quién es.

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Funcionario | ¿Viene por un certificado de nacimiento? | Recabar | — |
| 2 | Usuario Sordo | Sí, necesito un certificado de nacimiento. | Responder | — |
| 3 | Funcionario | ¿El certificado es suyo? | Recabar | — |
| 4 | Usuario Sordo | Sí, es mi certificado. | Responder | — |
| 5 | Funcionario | ¿Trajo su cédula de identidad? | Recabar | — |
| 6 | Usuario Sordo | Sí, traje mi cédula. | Responder | — |
| 7 | Funcionario | ¿Necesita un intérprete de Lengua de Señas Boliviana? | Accesibilidad | — |
| 8 | Usuario Sordo | Sí, necesito un intérprete de LSB. | Responder | — |

### Variantes

- **Turno 1 (Funcionario):** «¿Necesita un certificado de nacimiento?» · «¿Viene a sacar un certificado de nacimiento?»
- **Respuestas:** «Sí, necesito un certificado de nacimiento.» · «No, vengo por otro trámite.» · «No sé qué trámite necesito.»
- **Turno 3 (Funcionario):** «¿El certificado es suyo o de otra persona?» · «¿El certificado es para usted?»
- **Respuestas:** «Sí, es mi certificado.» · «No, es el certificado de mi hijo.» · «No sé.»
- **Turno 5 (Funcionario):** «¿Tiene su cédula de identidad?» · «¿Trae su carnet de identidad?»
- **Respuestas:** «Sí, traje mi cédula.» · «No, no traje mi cédula.» · «No sé si la traje.»
- **Turno 7 (Funcionario):** «¿Requiere interpretación en LSB?» · «¿Necesita apoyo de un intérprete de LSB?»
- **Respuestas:** «Sí, necesito un intérprete de LSB.» · «No, no necesito un intérprete.» · «No sé cómo pedir un intérprete.»
