# Lógica de negocio: modos de uso, necesidades e instituciones

Especificación de negocio y estado de su implementación. Lo generado se
regenera con las herramientas de abajo; lo escrito a mano son las
configuraciones y las reglas.

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

## Datos procesables

| Archivo | Contenido |
|---|---|
| `config/perfiles_institucionales.json` | Fuente única de los perfiles (editable) |
| `config/matriz_aceptacion.json` | Fuente única de los casos (editable) |
| `vocabulario.json` · `vocabulario.csv` | Clasificación completa (generado) |
| `banco_intenciones.json` | Banco de intenciones (generado) |

## Regenerar y validar

```bash
python tool/build_vocabulary_matrix.py     # 01, vocabulario.json/.csv
python tool/build_intent_bank.py           # 03, banco_intenciones.json
python tool/build_business_docs.py         # 02, 06
python tool/validate_business_config.py    # valida y escribe la cobertura
python tool/build_business_assets.py       # asset que empaqueta la app
```

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
