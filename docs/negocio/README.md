# Lógica de negocio: modos de uso, necesidades e instituciones

Especificación de negocio y estado de su implementación. Lo generado se
regenera con las herramientas de abajo; lo escrito a mano son las
configuraciones y las reglas.

## Documento de traspaso para asistentes

Para continuar el proyecto con Claude, ChatGPT u otro asistente, comenzar por
[`../CONTEXTO_MAESTRO_PARA_IA.md`](../CONTEXTO_MAESTRO_PARA_IA.md). Resume la
arquitectura vigente, el contrato v4, las fuentes canónicas, las limitaciones y
el protocolo de continuidad sin sustituir las matrices procesables.

## Documentos

| Archivo | Qué es | Origen |
|---|---|---|
| `00_Especificacion_Negocio.md` | Dimensiones, 35 reglas numeradas, modos, diagramas, limitaciones | escrito |
| `01_Matriz_Vocabulario.md` | Clasificación de las 346 entradas del catálogo | generado |
| `02_Perfiles_Institucionales.md` | Los 11 perfiles propuestos | generado |
| `02_Perfiles_Institucionales_cobertura.md` | Cobertura real por intención | generado |
| `03_Banco_Intenciones_Recorridos.md` | Las 99 intenciones con sus recorridos | generado |
| `04_Contratos_Datos.md` | Contratos propuestos y reglas C1–C18 | escrito |
| `05_Plan_Implementacion.md` | Bloques 0–9 por archivo y dependencia | escrito |
| `06_Matriz_Aceptacion.md` | Los 15 casos de aceptación | generado |
| `07_Estado_Implementacion.md` | Qué bloque está hecho, parcial o pendiente | escrito |
| `08_Auditoria_Precision_Semantica.md` | Auditoría del 25-09: diagnóstico, contrato de interacción, modelo de datos, modos | escrito |
| `09_Recorridos_A_I.md` | Recorridos A–I, consultas cubiertas, conversación de tres turnos | escrito |
| `10_Defectos_Priorizados.md` | 36 defectos con causa raíz y prueba de aceptación | escrito |
| `11_Matriz_Preguntas.md` | Matriz maestra de preguntas | generado |
| `12_Brechas_Lexicas_Animacion.md` | Brechas de vocabulario y de animación | generado |
| `evidencia/2026-09-25/` | Sondas ejecutadas contra el código y sus resultados | escrito |

## Datos procesables

| Archivo | Contenido |
|---|---|
| `config/perfiles_institucionales.json` | Fuente única de los perfiles (editable) |
| `config/matriz_aceptacion.json` | Fuente única de los casos (editable) |
| `vocabulario.json` · `vocabulario.csv` | Clasificación completa (generado) |
| `banco_intenciones.json` | Banco de intenciones (generado) |
| `config/banco_preguntas.json` | Fuente única del banco semántico de preguntas, veredictos por glosa y comparativa de modos (editable) |
| `matriz_preguntas.json` · `.csv` | Matriz maestra procesable (generado) |
| `matriz_zonas_actuales.csv` | Las 374 combinaciones zona-glosa de hoy con su veredicto (generado) |
| `matriz_nodos_grafo.csv` | Los 209 nodos con diagnóstico y pregunta mostrada hoy (generado) |
| `matriz_modos.csv` | Comparativa personal / ventanilla (generado) |

## Regenerar y validar

```bash
python tool/build_vocabulary_matrix.py     # 01, vocabulario.json/.csv
python tool/build_intent_bank.py           # 03, banco_intenciones.json
python tool/build_business_docs.py         # 02, 06
python tool/validate_business_config.py    # valida y escribe la cobertura
python tool/build_business_assets.py       # asset que empaqueta la app
python tool/build_question_matrix.py       # 11, 12, matriz_*.json/.csv
python tool/build_question_matrix.py --check
```

`build_question_matrix.py` no escribe nada si el banco contradice al
repositorio: glosa de respuesta ausente del catálogo sin declararse literal,
zona o nodo inexistente, glosa de zona sin veredicto o pregunta del funcionario
sin pregunta del banco.

`build_business_assets.py` no escribe nada si el validador falla: publicar una
configuración que el repositorio contradice es peor que no publicarla.

`validate_business_config.py` devuelve 1 si alguna configuración no cuadra con
el repositorio: intención inexistente, brecha falsa, ámbito que el catálogo no
ofrece, duplicados o referencias rotas en la matriz de aceptación.

## Estado

La fase de organización terminó y la implementación está en marcha. El estado
real de cada bloque, con lo hecho y lo pendiente, está en
`07_Estado_Implementacion.md`.

Lo que esta documentación **no** demuestra, en ninguna de sus versiones:

- Cobertura lingüística de ningún servicio institucional.
- Validación de ninguna composición con señantes ni con intérpretes.
- Comportamiento de los servicios desplegados (Bedrock, Polly, S3) ni del
  avatar 3D, cuyo modelo no forma parte del repositorio.
