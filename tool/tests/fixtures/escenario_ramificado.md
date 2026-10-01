<!-- Escenario de prueba de ramificaciones y composición. Lo leen
tool/tests/test_rag_ingesta_y_ramas.py y, ya generado, test/rag_ramificaciones_test.dart
(test/fixtures/rag_tramite_ramificado.json). -->
# Prueba

## Fuentes
| ID | Institución | Título | URL | Consultado |
|---|---|---|---|---|

## Hechos verificados
| ID | Institución | Hecho | Tipo | Fuente | Vigencia |
|---|---|---|---|---|---|

## ESC-DDRR-90 — Cédula y documentos

- **Institución:** Derechos Reales – Cochabamba
- **Trámite:** Prueba de ramificaciones
- **Tipo:** conocimiento_fijo
- **Inicia:** Funcionario
- **Situación:** La persona muestra lo que trajo.

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Funcionario | ¿Trajo su cédula de identidad? | — | — |
| 2 | Usuario Sordo | Sí, traje mi cédula. | — | — |
| 3 | Funcionario | ¿Qué documentos trajo? | — | — |
| 4 | Usuario Sordo | Traje el certificado y la fotocopia. | — | — |
| 5 | Funcionario | ¿Tiene una fotocopia de la cédula? | — | — |
| 6 | Usuario Sordo | No, no tengo fotocopia. | — | — |
| 7 | Funcionario | ¿Sabe dónde está su cédula? | — | — |
| 8 | Usuario Sordo | No sé dónde está. | — | — |

### Variantes

- **Turno 1 (Funcionario):** «¿Tiene su cédula con usted?»
- **Respuestas:** «No, no traje mi cédula.» · «No sé si la traje.»
- **Turno 3 (Funcionario):** «¿Qué trae?»
- **Respuestas:** «Traje la factura.» · «No traje documentos.»
- **Turno 5 (Funcionario):** «¿Trae una copia de la cédula?»
- **Respuestas:** «Sí, tengo fotocopia.»
- **Turno 7 (Funcionario):** «¿Recuerda dónde la dejó?»
- **Respuestas:** «Sí, está en mi casa.»

### Escenarios posibles

Nota narrativa: sin cédula, pasar a otro escenario. No crea condiciones.

### Ramificaciones

- **Turno 3:** si Turno 1 es afirmado
- **Turno 5:** si Turno 1 es negado
- **Turno 7:** si Turno 1 = «No sé si la traje.»

### Composición

- **Turno 3:** «Traje {items}.»
