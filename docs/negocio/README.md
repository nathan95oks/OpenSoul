# Lógica de negocio: modos de uso, necesidades e instituciones

Fase de **organización**, no de implementación. Nada de lo que hay aquí está
en el código de producción. Lo generado se regenera; lo escrito a mano son las
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
```

`validate_business_config.py` devuelve 1 si alguna configuración no cuadra con
el repositorio: intención inexistente, brecha falsa, ámbito que el catálogo no
ofrece, duplicados o referencias rotas en la matriz de aceptación.

## Lo que esta fase **no** hace

- No reestructura código de producción.
- No ejecuta pruebas de interfaz: no existe el código que probarían.
- No demuestra cobertura lingüística de ningún servicio institucional.
- No valida ninguna composición con señantes ni con intérpretes.
