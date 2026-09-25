# Cobertura real por intención de los perfiles propuestos

Generado por `tool/validate_business_config.py`. No editar a mano.

«Cubierta» significa que la intención tiene nodos en el grafo y que esos nodos ofrecen glosas del catálogo actual. **No** significa que la composición esté validada lingüísticamente ni que el servicio institucional esté cubierto por completo.

| Perfil | Intención | Necesidad | Nodos | Glosas ofrecibles | Estado |
|---|---|---|---:|---:|---|
| `derechos_reales` | `CONSULTA_ESTADO` | consultas | 1 | 3 | cubierta |
| `derechos_reales` | `DDRR_CERTIFICADO_NO_PROPIEDAD` | tramites | 0 | 0 | sin cobertura — brecha: PROPIEDAD |
| `derechos_reales` | `DDRR_CERTIFICADO_PROPIEDAD` | tramites | 0 | 0 | sin cobertura — brecha: PROPIEDAD |
| `derechos_reales` | `DDRR_FOLIO_ACTUALIZADO` | tramites | 0 | 0 | sin cobertura — brecha: FOLIO, PROPIEDAD |
| `derechos_reales` | `IDENTIFICACION_DOCUMENTO` | tramites | 1 | 3 | cubierta |
| `derechos_reales` | `IDENTIFICACION_NOMBRE` | tramites | 1 | 0 | sin opciones |
| `dna` | `AGRESION` | denuncias | 1 | 3 | cubierta |
| `dna` | `PROTECCION_OTROS` | consultas | 1 | 3 | cubierta |
| `fiscalia` | `CITACION` | tramites | 1 | 3 | cubierta |
| `fiscalia` | `CONSULTA_ESTADO` | consultas | 1 | 3 | cubierta |
| `fiscalia` | `DERIVACION_FISCALIA` | consultas | 1 | 3 | cubierta |
| `fiscalia` | `HABLAR_FISCAL` | consultas | 1 | 3 | cubierta |
| `fiscalia` | `INTERPRETE_REUNION` | consultas | 1 | 3 | cubierta |
| `gamc` | `CONSULTA_ESTADO` | consultas | 1 | 3 | cubierta |
| `gamc` | `GAMC_GESTION_MUNICIPAL` | tramites | 0 | 0 | sin cobertura — brecha: PAGAR, REGISTRAR, RENOVAR |
| `notaria` | `IDENTIFICACION_DOCUMENTO` | tramites | 1 | 3 | cubierta |
| `notaria` | `NOTARIA_GESTION_DOCUMENTAL` | tramites | 0 | 0 | sin cobertura — brecha: DOCUMENTO, ESCRITURA, REGISTRAR |
| `policia` | `AGRESION` | denuncias | 1 | 3 | cubierta |
| `policia` | `AUXILIO_INMEDIATO` | consultas | 1 | 3 | cubierta |
| `policia` | `CONSULTA_ESTADO` | consultas | 1 | 3 | cubierta |
| `policia` | `INTENCION_DENUNCIA` | denuncias | 1 | 3 | cubierta |
| `policia` | `NUMERO_REFERENCIA` | tramites | 1 | 3 | cubierta |
| `policia` | `RELATO_ABIERTO` | denuncias | 1 | 4 | cubierta |
| `policia` | `ROBO_CELULAR` | denuncias | 1 | 3 | cubierta |
| `sepdavi` | `ASISTENCIA_MEDICA` | consultas | 1 | 3 | cubierta |
| `sepdavi` | `DERIVACION_SEPDAVI` | consultas | 1 | 3 | cubierta |
| `sepdavi` | `PROTECCION_OTROS` | denuncias | 1 | 3 | cubierta |
| `sepdep` | `HABLAR_ABOGADO` | consultas | 1 | 3 | cubierta |
| `sepdep` | `INTERPRETE_REUNION` | consultas | 1 | 3 | cubierta |
| `sepdep` | `SEPDEP` | consultas | 1 | 3 | cubierta |
| `sin_institucion` | `IDENTIFICACION_NOMBRE` | tramites | 1 | 0 | sin opciones |
| `sin_institucion` | `NECESIDAD_INTERPRETE` | consultas | 1 | 3 | cubierta |
| `sin_institucion` | `RELATO_ABIERTO` | denuncias | 1 | 4 | cubierta |
| `slim` | `AGRESION` | denuncias | 1 | 3 | cubierta |
| `slim` | `AMENAZA` | denuncias | 1 | 3 | cubierta |
| `slim` | `PROTECCION_OTROS` | consultas | 1 | 3 | cubierta |
| `ventanilla_juzgados` | `CITACION` | tramites | 1 | 3 | cubierta |
| `ventanilla_juzgados` | `JUEZ` | consultas | 1 | 3 | cubierta |
| `ventanilla_juzgados` | `LECTURA_ANTES_FIRMA` | tramites | 1 | 3 | cubierta |
| `ventanilla_juzgados` | `ORGANO_JUDICIAL` | consultas | 1 | 2 | cubierta |
| `ventanilla_juzgados` | `RECIBIR_RESOLUCION` | tramites | 1 | 3 | cubierta |
