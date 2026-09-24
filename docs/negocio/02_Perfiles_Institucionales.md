# Perfiles institucionales propuestos

Generado por `tool/build_business_docs.py` desde `config/perfiles_institucionales.json`. No editar a mano.

**Incluir un perfil no demuestra cobertura lingüística de sus servicios.** La cobertura real por intención está en `02_Perfiles_Institucionales_cobertura.md`, calculada contra el grafo y el catálogo.

## Las tres necesidades

| Necesidad | Etiqueta | Parte de |
|---|---|---|
| `denuncias` | Denuncias | lo que ocurrió |
| `tramites` | Trámites y documentos | la gestión o el documento |
| `consultas` | Consultas y asistencia | lo que necesita saber |

Las tres **no** son grupos exclusivos de instituciones: se puede consultar en DDRR, preguntar por un documento en la Policía o pedir orientación sobre una denuncia.

## Perfiles

### `sin_institucion` — Sin institución / atención general

- **Fuente de la denominación**: interna
- **Tipo de servicio**: `general`
- **Necesidades prioritarias**: `denuncias`, `tramites`, `consultas`
- **Ámbitos iniciales**: `otro`, `identificacion`, `preguntas`
- **Regla de organización**: La necesidad la elige la persona. La falta de institución nunca bloquea la comunicación.

**Intenciones con cobertura (3)**: `RELATO_ABIERTO`, `NECESIDAD_INTERPRETE`, `IDENTIFICACION_NOMBRE`

### `policia` — Policía Boliviana

- **Fuente de la denominación**: por_verificar
- **Tipo de servicio**: `recepcion_de_hechos`
- **Necesidades prioritarias**: `denuncias`, `consultas`, `tramites`
- **Ámbitos iniciales**: `denuncia_robo`, `violencia`, `seguimiento`
- **Unidades**: `felcc` (FELCC), `felcv` (FELCV), `epi` (Punto EPI)
- **Regla de organización**: Distinguir institución, unidad y punto de atención cuando sea relevante. La prioridad de denuncias NO prohíbe consultar por un documento: una consulta sobre un papel en Policía no debe anteponer ROBAR por el nombre de la institución.

**Intenciones con cobertura (7)**: `INTENCION_DENUNCIA`, `RELATO_ABIERTO`, `ROBO_CELULAR`, `AGRESION`, `AUXILIO_INMEDIATO`, `CONSULTA_ESTADO`, `NUMERO_REFERENCIA`

### `derechos_reales` — Derechos Reales

- **Fuente de la denominación**: portal oficial de trámites, consultado el 2026-09-24 (referencia aportada en el encargo)
- **Tipo de servicio**: `registral`
- **Necesidades prioritarias**: `tramites`, `consultas`
- **Ámbitos iniciales**: `identificacion`, `seguimiento`, `otro`
- **Regla de organización**: Separar cada intención. No asumir que toda persona pide un folio. El portal distingue servicios distintos: folio actualizado y certificados de propiedad o de no propiedad; no unirlos en un trámite inventado.

**Intenciones con cobertura (3)**: `IDENTIFICACION_NOMBRE`, `IDENTIFICACION_DOCUMENTO`, `CONSULTA_ESTADO`

**Intenciones propuestas sin cobertura (3)**

| Intención | Necesidad | Brecha léxica |
|---|---|---|
| `DDRR_FOLIO_ACTUALIZADO` | tramites | `FOLIO`, `PROPIEDAD` |
| `DDRR_CERTIFICADO_PROPIEDAD` | tramites | `PROPIEDAD` |
| `DDRR_CERTIFICADO_NO_PROPIEDAD` | tramites | `PROPIEDAD` |

### `fiscalia` — Fiscalía

- **Fuente de la denominación**: por_verificar
- **Tipo de servicio**: `atencion_preliminar`
- **Necesidades prioritarias**: `consultas`, `denuncias`
- **Ámbitos iniciales**: `seguimiento`, `denuncia_robo`
- **Regla de organización**: No deducir el papel procesal de la persona ni el tipo de caso. La interfaz comunica una solicitud; no promete elegibilidad ni resultado.

**Intenciones con cobertura (5)**: `HABLAR_FISCAL`, `DERIVACION_FISCALIA`, `CONSULTA_ESTADO`, `CITACION`, `INTERPRETE_REUNION`

### `sepdep` — SEPDEP

- **Denominación**: Servicio Plurinacional de Defensa Pública
- **Fuente de la denominación**: corpus §4 + referencia oficial aportada en el encargo, consultada el 2026-09-24
- **Tipo de servicio**: `defensa_publica_penal`
- **Necesidades prioritarias**: `consultas`
- **Ámbitos iniciales**: `seguimiento`
- **Regla de organización**: Su misión es defensa penal. NO es equivalente universal de asistencia a víctimas: perfil distinto de SEPDAVI. La interfaz puede comunicar una solicitud de asistencia; no promete asignación de abogado.

**Intenciones con cobertura (3)**: `SEPDEP`, `HABLAR_ABOGADO`, `INTERPRETE_REUNION`

### `sepdavi` — SEPDAVI

- **Denominación**: Servicio Plurinacional de Asistencia a la Víctima
- **Fuente de la denominación**: corpus §4 + referencia oficial aportada en el encargo, consultada el 2026-09-24
- **Tipo de servicio**: `asistencia_victima`
- **Necesidades prioritarias**: `consultas`, `denuncias`
- **Ámbitos iniciales**: `seguimiento`, `violencia`
- **Regla de organización**: Escribir SEPDAVI, nunca SEPDAV. Perfil distinto de SEPDEP: no intercambiar destinatarios ni funciones.

**Intenciones con cobertura (3)**: `DERIVACION_SEPDAVI`, `ASISTENCIA_MEDICA`, `PROTECCION_OTROS`

### `slim` — SLIM

- **Fuente de la denominación**: por_verificar
- **Tipo de servicio**: `asistencia_municipal`
- **Necesidades prioritarias**: `consultas`, `denuncias`
- **Ámbitos iniciales**: `violencia`, `seguimiento`
- **Regla de organización**: Perfil diferenciado de DNA. No intercambiar sus destinatarios ni funciones.

**Intenciones con cobertura (3)**: `AGRESION`, `AMENAZA`, `PROTECCION_OTROS`

### `dna` — DNA

- **Fuente de la denominación**: por_verificar
- **Tipo de servicio**: `asistencia_municipal`
- **Necesidades prioritarias**: `consultas`, `denuncias`
- **Ámbitos iniciales**: `violencia`, `seguimiento`
- **Regla de organización**: Perfil diferenciado de SLIM. No intercambiar sus destinatarios ni funciones.

**Intenciones con cobertura (2)**: `PROTECCION_OTROS`, `AGRESION`

### `notaria` — Notaría

- **Fuente de la denominación**: por_verificar
- **Tipo de servicio**: `gestion_documental`
- **Necesidades prioritarias**: `tramites`, `consultas`
- **Ámbitos iniciales**: `identificacion`, `otro`
- **Regla de organización**: No inferir firma, consentimiento, titularidad ni poder otorgado a partir de una selección de tarjetas.

**Intenciones con cobertura (1)**: `IDENTIFICACION_DOCUMENTO`

**Intenciones propuestas sin cobertura (1)**

| Intención | Necesidad | Brecha léxica |
|---|---|---|
| `NOTARIA_GESTION_DOCUMENTAL` | tramites | `DOCUMENTO`, `ESCRITURA`, `REGISTRAR` |

### `gamc` — GAMC / plataforma municipal

- **Fuente de la denominación**: por_verificar
- **Tipo de servicio**: `plataforma_municipal`
- **Necesidades prioritarias**: `consultas`, `tramites`
- **Ámbitos iniciales**: `seguimiento`, `otro`
- **Regla de organización**: Cada servicio municipal tiene su intención propia. No modelar toda la Alcaldía como un solo trámite.

**Intenciones con cobertura (1)**: `CONSULTA_ESTADO`

**Intenciones propuestas sin cobertura (1)**

| Intención | Necesidad | Brecha léxica |
|---|---|---|
| `GAMC_GESTION_MUNICIPAL` | tramites | `PAGAR`, `REGISTRAR`, `RENOVAR` |

### `ventanilla_juzgados` — Ventanilla de juzgados

- **Fuente de la denominación**: por_verificar
- **Tipo de servicio**: `gestion_ante_despacho`
- **Necesidades prioritarias**: `consultas`, `tramites`
- **Ámbitos iniciales**: `seguimiento`
- **Regla de organización**: Orientación no es decisión judicial. La interfaz no anticipa resoluciones ni plazos.

**Intenciones con cobertura (5)**: `ORGANO_JUDICIAL`, `JUEZ`, `RECIBIR_RESOLUCION`, `CITACION`, `LECTURA_ANTES_FIRMA`

## Ampliación de alcance

El corpus maestro cubre la **etapa preliminar judicial**. Los perfiles registral (Derechos Reales), notarial y municipal (GAMC) amplían ese alcance sin corpus que los respalde: sus intenciones propias figuran arriba como «sin cobertura», con la brecha léxica concreta.

Efectos a registrar en el proyecto de grado: objetivos, alcances, límites, corpus y evaluación. La decisión de incluir un perfil es una decisión de producto, no una demostración de cobertura.
