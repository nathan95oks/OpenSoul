# Matriz de vocabulario — clasificación completa del catálogo

Generado por `tool/build_vocabulary_matrix.py`. No editar a mano.
Formato procesable: `vocabulario.json` y `vocabulario.csv`.

Cada entrada se clasifica contra las fuentes del repositorio, sin
añadir sentidos que ninguna de ellas respalde.

## 1. Composición del catálogo

El conteo léxico y el de mecanismos van separados, como pide el
encargo: las letras, los dígitos y los nombres institucionales no
son señas del corpus.

| Clase | Entradas | Qué es |
|---|---:|---|
| Seña léxica | 303 | Documentada en el corpus §12 |
| Letra dactilológica | 27 | Alfabeto, mecanismo de deletreo |
| Dígito | 10 | Mecanismo de numeración |
| Institución por dactilología | 6 | `canonicalGloss: d(...)` |
| **Total del catálogo** | **346** | |

**Conteo léxico real: 303 señas.** Las otras 43 entradas son mecanismos de representación.

## 2. Cobertura de uso y de avatar

| Indicador | Valor | Lectura |
|---|---:|---|
| Con uso en algún recorrido del grafo | 150 | Tienen al menos un nodo que las ofrece |
| Sin uso en el grafo | 196 | Accesibles por categoría y buscador; no se les asigna necesidad sin respaldo |
| Sin rol en el ensamblador | 0 | No pueden integrarse en una oración: brecha de redacción |
| Ejecutables por el avatar | 30 | El resto se deletrea o se muestra como marcador |

## 3. Funciones semánticas presentes

| Función | Entradas |
|---|---:|
| `accion` | 120 |
| `tiempo` | 42 |
| `participante` | 35 |
| `marcador` | 25 |
| `lugar` | 24 |
| `objeto` | 23 |
| `descriptor` | 20 |
| `evidencia` | 16 |
| `interaccion` | 16 |
| `institucion` | 14 |
| `estado` | 11 |

## 4. Restricciones de sentido y combinación

Solo las que tienen respaldo en el corpus o en el código.

| Glosa | Restricción |
|---|---|
| `PAPEL` | No es un documento genérico. No sustituye FOLIO REAL, ESCRITURA ni CÉDULA (corpus §4: preferir el objeto concreto). |
| `CELULAR` | Polisémica por papel, no por seña: objeto sustraído o medio de contacto. Lo decide el campo que se responde, no la necesidad activa. |
| `QUEJAR` | No es una seña directa de DENUNCIA. La composición QUEJAR + AUTORIDAD es provisional y está sin validar (corpus §4). |
| `BILLETES` | No sustituye BILLETERA. Son cosas distintas. |
| `NO_SABER` | Expresa desconocimiento. No equivale a negar ni a omitir la respuesta: son tres estados distintos. |
| `CERTIFICADO` | Fuente léxica en sección escolar (M4 · Escuela II · p.129). Su presencia NO valida los sentidos registrales (certificado de propiedad, de no propiedad). |
| `TESTIGO` | NO + TESTIGO no fabrica testigos ni afirma que los haya. Ausencia de respuesta, negación e incertidumbre son estados distintos. |
| `TRÁMITE` | Entrada del Diccionario 2024 (p.216). Nombra la gestión, no un trámite institucional concreto ni su procedimiento. |
| `PERDER` | No equivale a ROBAR. El backend no puede derivar una afirmación de robo de una pérdida (auditoría 2026-09). |
| `ESCAPAR` | Es un hecho propio, no un calificador de robo. Seleccionarla sola no autoriza a redactar una denuncia de robo. |

## 5. Brechas declaradas

Conceptos que los recorridos propuestos necesitan y que el catálogo
no tiene. Ninguno se incorpora como seña nueva.

| Concepto | Necesidad afectada | ¿En catálogo? | ¿En corpus §12? | Tratamiento |
|---|---|:-:|:-:|---|
| `FOLIO` | consultas | no | no | Sin entrada. No incorporar como seña nueva. Comunicar la parte cubierta y declarar la brecha; usar dactilología solo si el término literal es imprescindible y el mecanismo lo admite. |
| `PAGAR` | tramites | no | no | Sin entrada. No incorporar como seña nueva. Comunicar la parte cubierta y declarar la brecha; usar dactilología solo si el término literal es imprescindible y el mecanismo lo admite. |
| `DOCUMENTO` | tramites | no | no | Sin entrada. No incorporar como seña nueva. Comunicar la parte cubierta y declarar la brecha; usar dactilología solo si el término literal es imprescindible y el mecanismo lo admite. |
| `PROPIEDAD` | tramites | no | no | Sin entrada. No incorporar como seña nueva. Comunicar la parte cubierta y declarar la brecha; usar dactilología solo si el término literal es imprescindible y el mecanismo lo admite. |
| `ESCRITURA` | tramites | no | no | Sin entrada. No incorporar como seña nueva. Comunicar la parte cubierta y declarar la brecha; usar dactilología solo si el término literal es imprescindible y el mecanismo lo admite. |
| `CEDULA` | identificacion | no | no | Sin entrada. No incorporar como seña nueva. Comunicar la parte cubierta y declarar la brecha; usar dactilología solo si el término literal es imprescindible y el mecanismo lo admite. |
| `ENTREGAR` | tramites | no | no | Sin entrada. No incorporar como seña nueva. Comunicar la parte cubierta y declarar la brecha; usar dactilología solo si el término literal es imprescindible y el mecanismo lo admite. |
| `REGISTRAR` | tramites | no | no | Sin entrada. No incorporar como seña nueva. Comunicar la parte cubierta y declarar la brecha; usar dactilología solo si el término literal es imprescindible y el mecanismo lo admite. |
| `CORREGIR` | tramites | no | no | Sin entrada. No incorporar como seña nueva. Comunicar la parte cubierta y declarar la brecha; usar dactilología solo si el término literal es imprescindible y el mecanismo lo admite. |
| `RENOVAR` | tramites | no | no | Sin entrada. No incorporar como seña nueva. Comunicar la parte cubierta y declarar la brecha; usar dactilología solo si el término literal es imprescindible y el mecanismo lo admite. |
| `JUICIO` | consultas | no | no | Sin entrada. No incorporar como seña nueva. Comunicar la parte cubierta y declarar la brecha; usar dactilología solo si el término literal es imprescindible y el mecanismo lo admite. |
| `BILLETERA` | denuncias | no | no | Sin entrada. No incorporar como seña nueva. Comunicar la parte cubierta y declarar la brecha; usar dactilología solo si el término literal es imprescindible y el mecanismo lo admite. |
| `ARMA` | denuncias | no | no | Sin entrada. No incorporar como seña nueva. Comunicar la parte cubierta y declarar la brecha; usar dactilología solo si el término literal es imprescindible y el mecanismo lo admite. |
| `NOCHE` | denuncias | no | no | Sin entrada. No incorporar como seña nueva. Comunicar la parte cubierta y declarar la brecha; usar dactilología solo si el término literal es imprescindible y el mecanismo lo admite. |

## 6. Entradas sin uso documentado en los recorridos

Se conservan en el catálogo. No se les fuerza una necesidad para que
aparezcan en pantalla.

| Glosa | Clase | Motivo |
|---|---|---|
| `QUEJAR` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `NO_PUEDO` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `ELLA` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `OFICINA` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `AVENIDA` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `AUTORIDAD` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `CÓMO` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `JUSTICIA` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `TRÁMITE` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `VIOLENCIA` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `CARPETA` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `AMBOS` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `SEMANA` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `NOSOTROS` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `TEMPRANO` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `AL_LADO` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `HIJA` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `JUEVES` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `LLEVAR` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `MUCHO` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `NEGRO` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `NUEVO` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `PÁGINA` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `AZUL` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `COMPUTADORA` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `CONTESTAR_DOS_VECES` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `HERMANA` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `HERMANO` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `JAMÁS` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `MES` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `OÍR` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `VIVIR` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `AMIGO` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `ANTEAYER` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `ATENDER` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `COMPAÑERO` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `CREER` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `CÁMARA_FOTOGRÁFICA` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `DECIDIR` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `DIBUJAR` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `ENCONTRARSE` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `ESCONDER` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `FUNCIONAR` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `LEJOS` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `LEY` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `MAMÁ` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `MICRO` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `MINUTO` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `OSCURO` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `PLAZA` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `PLAZO` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `POSTERGAR` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `PRÓXIMO` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `SÁBADO` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `TRABAJADOR` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `VIERNES` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `ACEPTAR` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `ALLÁ` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `ANDAR` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `ASISTENTE` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `ASOCIACIÓN_SORDOS` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `ATRÁS` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `BARRIO` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `BOCA` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `BUENO` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `CADA_DÍA` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `COCHABAMBA` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `COMPRAR` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `COMUNIDAD_SORDA` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `DEVOLVER` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `DOLOR` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `DURANTE` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `EDAD` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `ESCUELA` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `FRACTURA` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `FUTURO` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `HASTA_LUEGO` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `HASTA_MAÑANA` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `JEFE` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `LLAMAR` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `MIRAR` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `PELEAR` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `PREOCUPAR` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `ROJO` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `SEPARADOS` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `SIEMPRE` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `URGENTE` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `VARIOS` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `VENDER` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `ÚLTIMO` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `ABRIR` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `ALCALDÍA` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `AÑO` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `AÑO_PASADO` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `BUENOS_DÍAS` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `BURLAR` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `CARO` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `CONFIANZA` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `CORTO` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `CURAR` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `DE_NADA` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `DEJAR` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `DESCANSO` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `DIFERENTE` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `DIFÍCIL` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `DISCRIMINACIÓN` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `DORMIR` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `ENFRENTE` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `ESCUELA_NOCTURNA` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `ESPOSA` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `EVALUAR` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `GANAR_DINERO` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `GOBIERNO` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `GRITAR` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `HOLA` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `HUESOS` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `IGNORAR` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `JULIO` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `LIBRE` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `LISTA` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `LLEGAR` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `LO_SIENTO` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `LUEGO` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `LUNES` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `MARTES` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `MARZO` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `MEDICINA` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `MENTIRA` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `MOMENTO` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `NO_ESTAR_DE_ACUERDO` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `OCUPADO` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `OFICIAL` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `ORGANIZAR` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `OYENTE` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `PALABRA` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `PARIENTE` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `PASADO_MAÑANA` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `PERMISO` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `PROHIBIDO` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `PROVINCIA` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `RAYOS_X` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `RECHAZAR` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `RESULTADO` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `SEGUNDO` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `SEÑOR` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `SUYO` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `TAL_VEZ` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `TODOS_LOS_DÍAS` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `TRISTE` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `TRUFI` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `ABUSAR` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `ARRESTAR` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |
| `INSTITUCIÓN` | sena_lexica | Documentada en el corpus §12 pero ningún ejemplo de los bancos 6/7/8 la utiliza. Se conserva en el catálogo y queda disponible por categoría y buscador; no se le asigna una necesidad sin uso que lo respalde. |

Total sin uso en recorridos, entre las señas léxicas: **153**.

## 7. Clasificación completa

| ID | Glosa | Clase | Función | Necesidades | Campos | Representación | Avatar |
|---|---|---|---|---|---|---|---|
| `g001` | `YO` | sena_lexica | participante | consultas, denuncias, tramites | amount, evidence, free_text, institution, object, person, place, polarity, time | sena_documentada | placeholder |
| `g002` | `ÉL` | sena_lexica | participante | consultas, denuncias, tramites | free_text, object, person, polarity | sena_documentada | placeholder |
| `g003` | `TÚ` | sena_lexica | participante | consultas, denuncias, tramites | free_text, person, polarity | sena_documentada | placeholder |
| `g004` | `SÍ` | sena_lexica | marcador | consultas, denuncias, tramites | evidence, free_text, institution, object, person, place, polarity, time | sena_documentada | baked |
| `g005` | `ESCRIBIR` | sena_lexica | accion | consultas, denuncias, tramites | free_text, object, polarity, time | sena_documentada | placeholder |
| `g006` | `PAPEL` | sena_lexica | evidencia | consultas, denuncias, tramites | evidence, free_text, person, polarity, time | sena_documentada | placeholder |
| `g007` | `CELULAR` | sena_lexica | objeto | consultas, denuncias, tramites | evidence, object, polarity | sena_documentada | placeholder |
| `g008` | `NECESITAR` | sena_lexica | accion | consultas, denuncias, tramites | evidence, free_text, institution, object, person, polarity | sena_documentada | placeholder |
| `g009` | `QUERER` | sena_lexica | accion | consultas, denuncias, tramites | free_text, institution, polarity, time | sena_documentada | placeholder |
| `g010` | `PUEDO` | sena_lexica | marcador | consultas, denuncias, tramites | evidence, free_text, institution, object, person, place, polarity, time | sena_documentada | placeholder |
| `g011` | `VOLVER` | sena_lexica | accion | consultas, denuncias, tramites | free_text, polarity, time | sena_documentada | placeholder |
| `g012` | `FOTOS` | sena_lexica | objeto | consultas, denuncias, tramites | evidence, object, place, polarity | sena_documentada | placeholder |
| `g013` | `INTÉRPRETE` | sena_lexica | interaccion | consultas, denuncias, tramites | free_text, polarity | sena_documentada | placeholder |
| `g014` | `DAR` | sena_lexica | accion | denuncias | evidence, object, place, polarity | sena_documentada | placeholder |
| `g015` | `NOMBRE` | sena_lexica | marcador | consultas, denuncias, tramites | free_text, person, polarity, time | sena_documentada | placeholder |
| `g016` | `CASA` | sena_lexica | lugar | consultas, denuncias, tramites | free_text, polarity | sena_documentada | placeholder |
| `g017` | `VER` | sena_lexica | accion | consultas, denuncias, tramites | evidence, free_text, object, person, polarity | sena_documentada | placeholder |
| `g018` | `CUÁNDO` | sena_lexica | interaccion | consultas, denuncias, tramites | time | sena_documentada | placeholder |
| `g019` | `QUÉ` | sena_lexica | interaccion | consultas, denuncias, tramites | free_text, object, polarity | sena_documentada | placeholder |
| `g020` | `TRAER` | sena_lexica | accion | consultas, denuncias, tramites | evidence, free_text, object, person, polarity | sena_documentada | placeholder |
| `g021` | `HORA` | sena_lexica | tiempo | consultas, denuncias, tramites | amount, free_text, polarity, time | sena_documentada | placeholder |
| `g022` | `QUEJAR` | sena_lexica | accion | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g023` | `BILLETES` | sena_lexica | objeto | consultas, denuncias, tramites | amount, object, polarity | sena_documentada | placeholder |
| `g024` | `CUÁL` | sena_lexica | interaccion | consultas, denuncias, tramites | free_text, object, person, place, polarity | sena_documentada | placeholder |
| `g025` | `CUÁNTOS` | sena_lexica | interaccion | consultas, denuncias, tramites | amount, evidence, object, person, polarity, time | sena_documentada | placeholder |
| `g026` | `ENVIAR` | sena_lexica | accion | consultas, denuncias, tramites | evidence, free_text, object, polarity | sena_documentada | placeholder |
| `g027` | `MAÑANA` | sena_lexica | tiempo | consultas, denuncias, tramites | evidence, person, polarity | sena_documentada | placeholder |
| `g028` | `QUIÉN` | sena_lexica | interaccion | consultas, denuncias, tramites | person | sena_documentada | placeholder |
| `g029` | `ESPERAR` | sena_lexica | accion | consultas, tramites | amount, time | sena_documentada | placeholder |
| `g030` | `GUARDAR` | sena_lexica | accion | consultas, denuncias, tramites | free_text, polarity | sena_documentada | placeholder |
| `g031` | `HOMBRE` | sena_lexica | participante | consultas, denuncias, tramites | object, person, polarity | sena_documentada | placeholder |
| `g032` | `NO` | sena_lexica | marcador | consultas, denuncias, tramites | evidence, free_text, institution, object, person, place, polarity, time | sena_documentada | baked |
| `g033` | `DÓNDE` | sena_lexica | interaccion | consultas, denuncias, tramites | evidence, institution, place, polarity | sena_documentada | placeholder |
| `g034` | `EXPLICAR` | sena_lexica | accion | consultas, denuncias, tramites | free_text, polarity | sena_documentada | placeholder |
| `g035` | `IDENTIDAD` | sena_lexica | marcador | consultas, denuncias, tramites | evidence, free_text, person, polarity | sena_documentada | placeholder |
| `g036` | `MOSTRAR` | sena_lexica | accion | consultas, denuncias, tramites | evidence, object, polarity | sena_documentada | placeholder |
| `g037` | `SABER` | sena_lexica | marcador | consultas, denuncias, tramites | free_text | sena_documentada | placeholder |
| `g038` | `ABOGADO` | sena_lexica | interaccion | consultas, denuncias, tramites | free_text, institution, object, polarity | sena_documentada | placeholder |
| `g039` | `AYER` | sena_lexica | tiempo | consultas, denuncias, tramites | polarity, time | sena_documentada | placeholder |
| `g040` | `FECHA` | sena_lexica | tiempo | denuncias | time | sena_documentada | placeholder |
| `g041` | `NO_PUEDO` | sena_lexica | marcador | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g042` | `COMPRENDER` | sena_lexica | marcador | consultas, denuncias, tramites | free_text, polarity | sena_documentada | placeholder |
| `g043` | `ELLA` | sena_lexica | participante | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g044` | `GRACIAS` | sena_lexica | marcador | consultas, denuncias, tramites | free_text | sena_documentada | baked |
| `g045` | `JUEZ` | sena_lexica | institucion | consultas, denuncias, tramites | free_text, polarity | sena_documentada | placeholder |
| `g046` | `LEER` | sena_lexica | accion | consultas, denuncias, tramites | free_text, polarity, time | sena_documentada | placeholder |
| `g047` | `MUJER` | sena_lexica | participante | denuncias | person, polarity | sena_documentada | placeholder |
| `g048` | `OFICINA` | sena_lexica | lugar | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g049` | `RECIBIR` | sena_lexica | accion | consultas, denuncias, tramites | free_text, person, polarity | sena_documentada | placeholder |
| `g050` | `RECORDAR` | sena_lexica | accion | consultas, denuncias, tramites | free_text, polarity | sena_documentada | placeholder |
| `g051` | `VIDEO` | sena_lexica | objeto | consultas, denuncias, tramites | evidence, object, place, polarity | sena_documentada | placeholder |
| `g052` | `AYUDAR` | sena_lexica | accion | consultas, denuncias, tramites | free_text, institution, polarity | sena_documentada | placeholder |
| `g053` | `DAÑAR` | sena_lexica | accion | consultas, denuncias, tramites | free_text | sena_documentada | placeholder |
| `g054` | `HOY` | sena_lexica | tiempo | denuncias | polarity, time | sena_documentada | placeholder |
| `g055` | `LENTO` | sena_lexica | descriptor | consultas, denuncias, tramites | free_text, polarity | sena_documentada | placeholder |
| `g056` | `NO_SABER` | sena_lexica | marcador | consultas, denuncias, tramites | amount, evidence, free_text, institution, object, person, place, polarity, time | sena_documentada | placeholder |
| `g057` | `CERTIFICADO` | sena_lexica | evidencia | consultas, denuncias, tramites | evidence, place, polarity | sena_documentada | placeholder |
| `g058` | `FACTURA` | sena_lexica | evidencia | consultas, denuncias, tramites | evidence, object, polarity | sena_documentada | placeholder |
| `g059` | `MIEDO` | sena_lexica | estado | consultas, denuncias, tramites | free_text, polarity | sena_documentada | placeholder |
| `g060` | `PEGAR` | sena_lexica | accion | consultas, denuncias, tramites | person, polarity | sena_documentada | placeholder |
| `g061` | `POR_FAVOR` | sena_lexica | marcador | consultas, denuncias, tramites | free_text | sena_documentada | placeholder |
| `g062` | `AMENAZAR` | sena_lexica | accion | consultas, denuncias, tramites | free_text, object, polarity | sena_documentada | placeholder |
| `g063` | `AVENIDA` | sena_lexica | lugar | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g064` | `CALLE` | sena_lexica | lugar | consultas, denuncias, tramites | place | sena_documentada | placeholder |
| `g065` | `AUTORIDAD` | sena_lexica | institucion | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g066` | `CÓMO` | sena_lexica | interaccion | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g067` | `ENGAÑAR` | sena_lexica | accion | consultas, denuncias, tramites | object | sena_documentada | placeholder |
| `g068` | `HERIDA` | sena_lexica | estado | consultas, denuncias, tramites | free_text, polarity | sena_documentada | placeholder |
| `g069` | `INVESTIGACIÓN` | sena_lexica | interaccion | consultas, denuncias, tramites | free_text, person, polarity | sena_documentada | placeholder |
| `g070` | `PROTEGER` | sena_lexica | accion | denuncias | person, polarity | sena_documentada | placeholder |
| `g071` | `JUSTICIA` | sena_lexica | evidencia | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g072` | `POLICÍA` | sena_lexica | institucion | consultas, tramites | institution, polarity | sena_documentada | placeholder |
| `g073` | `HOSPITAL` | sena_lexica | institucion | consultas, denuncias, tramites | free_text, polarity | sena_documentada | placeholder |
| `g074` | `ASISTENCIA` | sena_lexica | evidencia | consultas, denuncias, tramites | institution, polarity | sena_documentada | placeholder |
| `g075` | `AUXILIO` | sena_lexica | estado | consultas, denuncias, tramites | free_text, polarity | sena_documentada | placeholder |
| `g076` | `LADRÓN` | sena_lexica | participante | denuncias | polarity | sena_documentada | placeholder |
| `g077` | `NARRAR` | sena_lexica | accion | consultas, denuncias, tramites | free_text, polarity | sena_documentada | placeholder |
| `g078` | `OBSERVAR` | sena_lexica | accion | consultas, denuncias, tramites | free_text | sena_documentada | placeholder |
| `g079` | `PRESENTAR` | sena_lexica | accion | consultas, denuncias, tramites | evidence, free_text, polarity | sena_documentada | placeholder |
| `g080` | `RESOLUCIÓN` | sena_lexica | evidencia | consultas, denuncias, tramites | free_text, polarity | sena_documentada | placeholder |
| `g081` | `ROBAR` | sena_lexica | accion | consultas, denuncias, tramites | free_text, object, polarity | sena_documentada | placeholder |
| `g082` | `TESTIGO` | sena_lexica | participante | consultas, denuncias, tramites | amount, evidence, person, polarity | sena_documentada | placeholder |
| `g083` | `TESTIMONIO` | sena_lexica | evidencia | consultas, denuncias, tramites | free_text | sena_documentada | placeholder |
| `g084` | `TRÁMITE` | sena_lexica | interaccion | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g085` | `VIOLENCIA` | sena_lexica | estado | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g086` | `MÍO` | sena_lexica | participante | consultas, denuncias, tramites | object, place, polarity | sena_documentada | placeholder |
| `g087` | `TENER` | sena_lexica | accion | consultas, denuncias, tramites | evidence, free_text, object, person, place, polarity | sena_documentada | placeholder |
| `g088` | `ELLOS` | sena_lexica | participante | consultas, tramites | polarity | sena_documentada | placeholder |
| `g089` | `TUYO` | sena_lexica | participante | consultas, denuncias, tramites | free_text, object, polarity | sena_documentada | placeholder |
| `g090` | `PASADO` | sena_lexica | tiempo | consultas, denuncias, tramites | free_text, polarity, time | sena_documentada | placeholder |
| `g091` | `DENTRO` | sena_lexica | lugar | denuncias | place, polarity | sena_documentada | placeholder |
| `g092` | `VENIR` | sena_lexica | accion | consultas, denuncias, tramites | person, polarity | sena_documentada | placeholder |
| `g093` | `AQUÍ` | sena_lexica | lugar | consultas, denuncias, tramites | free_text, polarity | sena_documentada | placeholder |
| `g094` | `CARPETA` | sena_lexica | evidencia | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g095` | `AHORA` | sena_lexica | tiempo | consultas, denuncias, tramites | free_text, object, polarity | sena_documentada | placeholder |
| `g096` | `FOTOCOPIA` | sena_lexica | evidencia | consultas, denuncias, tramites | polarity | sena_documentada | placeholder |
| `g097` | `AMBOS` | sena_lexica | participante | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g098` | `SEMANA` | sena_lexica | tiempo | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g099` | `TERMINAR` | sena_lexica | accion | consultas, denuncias, tramites | object, person, polarity | sena_documentada | placeholder |
| `g100` | `TOTAL` | sena_lexica | accion | consultas, denuncias, tramites | evidence, free_text, person, polarity | sena_documentada | placeholder |
| `g101` | `BUSCAR` | sena_lexica | accion | consultas, denuncias, tramites | object, person, polarity | sena_documentada | placeholder |
| `g102` | `AÚN` | sena_lexica | tiempo | consultas, denuncias, tramites | free_text, polarity | sena_documentada | placeholder |
| `g103` | `SORDO` | sena_lexica | participante | consultas, denuncias, tramites | free_text, person, polarity | sena_documentada | placeholder |
| `g104` | `CERCA` | sena_lexica | lugar | consultas, denuncias, tramites | place | sena_documentada | placeholder |
| `g105` | `HABLAR` | sena_lexica | accion | consultas, denuncias, tramites | institution, polarity | sena_documentada | placeholder |
| `g106` | `HACER` | sena_lexica | accion | denuncias | free_text | sena_documentada | placeholder |
| `g107` | `IR` | sena_lexica | accion | consultas, denuncias, tramites | free_text, institution, polarity | sena_documentada | placeholder |
| `g108` | `NOSOTROS` | sena_lexica | participante | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g109` | `TARDE` | sena_lexica | tiempo | consultas, denuncias, tramites | time | sena_documentada | placeholder |
| `g110` | `DÍA` | sena_lexica | tiempo | consultas, tramites | polarity | sena_documentada | placeholder |
| `g111` | `TIENDA` | sena_lexica | lugar | consultas, denuncias, tramites | free_text | sena_documentada | placeholder |
| `g112` | `ACOMPAÑAR` | sena_lexica | accion | consultas, denuncias, tramites | polarity | sena_documentada | placeholder |
| `g113` | `ALLÍ` | sena_lexica | lugar | denuncias | person, polarity | sena_documentada | placeholder |
| `g114` | `TEMPRANO` | sena_lexica | tiempo | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g115` | `CONOCER` | sena_lexica | accion | consultas, denuncias, tramites | person, polarity | sena_documentada | placeholder |
| `g116` | `DESPUÉS` | sena_lexica | tiempo | consultas, denuncias, tramites | evidence, free_text, polarity | sena_documentada | placeholder |
| `g117` | `INTERNET` | sena_lexica | objeto | denuncias | polarity | sena_documentada | placeholder |
| `g118` | `PEDIR` | sena_lexica | accion | denuncias | polarity | sena_documentada | placeholder |
| `g119` | `VERDAD` | sena_lexica | marcador | consultas, denuncias, tramites | object, polarity | sena_documentada | placeholder |
| `g120` | `AL_LADO` | sena_lexica | lugar | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g121` | `BANCO` | sena_lexica | lugar | consultas, denuncias, tramites | evidence, free_text, object, polarity | sena_documentada | placeholder |
| `g122` | `BRAZO` | sena_lexica | objeto | consultas, denuncias, tramites | free_text | sena_documentada | placeholder |
| `g123` | `HIJA` | sena_lexica | participante | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g124` | `JUEVES` | sena_lexica | tiempo | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g125` | `LLEVAR` | sena_lexica | accion | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g126` | `MUCHO` | sena_lexica | descriptor | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g127` | `NEGRO` | sena_lexica | descriptor | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g128` | `NUEVO` | sena_lexica | descriptor | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g129` | `PERDER` | sena_lexica | accion | consultas, denuncias, tramites | free_text, object, polarity | sena_documentada | placeholder |
| `g130` | `PRIMERA_VEZ` | sena_lexica | tiempo | consultas, denuncias, tramites | free_text, polarity | sena_documentada | placeholder |
| `g131` | `PÁGINA` | sena_lexica | evidencia | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g132` | `SELLO` | sena_lexica | evidencia | consultas, denuncias, tramites | polarity | sena_documentada | placeholder |
| `g133` | `ARREGLAR` | sena_lexica | accion | denuncias | polarity | sena_documentada | placeholder |
| `g134` | `AUMENTAR` | sena_lexica | accion | consultas, denuncias, tramites | free_text, object, polarity | sena_documentada | placeholder |
| `g135` | `AVISAR` | sena_lexica | accion | consultas, denuncias, tramites | object, polarity | sena_documentada | placeholder |
| `g136` | `AZUL` | sena_lexica | descriptor | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g137` | `CAMBIAR` | sena_lexica | accion | consultas, denuncias, tramites | object, place, polarity | sena_documentada | placeholder |
| `g138` | `COMPUTADORA` | sena_lexica | objeto | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g139` | `CONTESTAR_DOS_VECES` | sena_lexica | accion | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g140` | `DIRECCIÓN` | sena_lexica | lugar | consultas, denuncias, tramites | place, polarity | sena_documentada | placeholder |
| `g141` | `DOCTOR` | sena_lexica | interaccion | consultas, denuncias, tramites | evidence, polarity | sena_documentada | placeholder |
| `g142` | `ESTAR_DE_ACUERDO` | sena_lexica | marcador | consultas, tramites | polarity | sena_documentada | placeholder |
| `g143` | `GRATIS` | sena_lexica | descriptor | consultas, tramites | institution, polarity | sena_documentada | placeholder |
| `g144` | `HERMANA` | sena_lexica | participante | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g145` | `HERMANO` | sena_lexica | participante | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g146` | `JAMÁS` | sena_lexica | tiempo | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g147` | `MAL` | sena_lexica | descriptor | consultas, denuncias, tramites | free_text, polarity | sena_documentada | placeholder |
| `g148` | `MEJOR` | sena_lexica | descriptor | consultas, denuncias, tramites | free_text, polarity | sena_documentada | placeholder |
| `g149` | `MERCADO` | sena_lexica | lugar | consultas, denuncias, tramites | place | sena_documentada | placeholder |
| `g150` | `MES` | sena_lexica | tiempo | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g151` | `MOCHILA` | sena_lexica | objeto | consultas, denuncias, tramites | object, person, polarity | sena_documentada | placeholder |
| `g152` | `MÁS_O_MENOS` | sena_lexica | marcador | denuncias | polarity, time | sena_documentada | placeholder |
| `g153` | `OÍR` | sena_lexica | accion | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g154` | `POCO` | sena_lexica | descriptor | consultas, denuncias, tramites | free_text | sena_documentada | placeholder |
| `g155` | `PUERTA` | sena_lexica | objeto | consultas, denuncias, tramites | free_text | sena_documentada | placeholder |
| `g156` | `VIVIR` | sena_lexica | accion | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g157` | `ALTO` | sena_lexica | descriptor | denuncias | polarity | sena_documentada | placeholder |
| `g158` | `AMIGO` | sena_lexica | participante | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g159` | `ANTEAYER` | sena_lexica | tiempo | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g160` | `ATENDER` | sena_lexica | accion | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g161` | `CAJA` | sena_lexica | objeto | denuncias | evidence, object, polarity | sena_documentada | placeholder |
| `g162` | `COMPAÑERO` | sena_lexica | participante | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g163` | `CONVOCAR` | sena_lexica | interaccion | consultas, tramites | polarity | sena_documentada | placeholder |
| `g164` | `CREER` | sena_lexica | accion | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g165` | `CÁMARA_FOTOGRÁFICA` | sena_lexica | objeto | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g166` | `DECIDIR` | sena_lexica | accion | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g167` | `DIBUJAR` | sena_lexica | accion | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g168` | `ENCONTRARSE` | sena_lexica | accion | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g169` | `ESCONDER` | sena_lexica | accion | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g170` | `FILMAR` | sena_lexica | accion | consultas, denuncias, tramites | evidence, place, polarity | sena_documentada | placeholder |
| `g171` | `FLACO` | sena_lexica | descriptor | denuncias | polarity | sena_documentada | placeholder |
| `g172` | `FUNCIONAR` | sena_lexica | accion | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g173` | `JOVEN` | sena_lexica | participante | consultas, denuncias, tramites | object, person, polarity | sena_documentada | placeholder |
| `g174` | `LEJOS` | sena_lexica | lugar | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g175` | `LEY` | sena_lexica | evidencia | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g176` | `MAMÁ` | sena_lexica | participante | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g177` | `MICRO` | sena_lexica | objeto | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g178` | `MINUTO` | sena_lexica | tiempo | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g179` | `OSCURO` | sena_lexica | descriptor | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g180` | `PLAZA` | sena_lexica | lugar | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g181` | `PLAZO` | sena_lexica | interaccion | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g182` | `POSTERGAR` | sena_lexica | tiempo | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g183` | `PRÓXIMO` | sena_lexica | tiempo | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g184` | `SÁBADO` | sena_lexica | tiempo | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g185` | `TRABAJADOR` | sena_lexica | participante | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g186` | `VIERNES` | sena_lexica | tiempo | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g187` | `ACEPTAR` | sena_lexica | accion | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g188` | `ALLÁ` | sena_lexica | lugar | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g189` | `ANDAR` | sena_lexica | accion | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g190` | `ASISTENTE` | sena_lexica | interaccion | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g191` | `ASOCIACIÓN_SORDOS` | sena_lexica | participante | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g192` | `ATRÁS` | sena_lexica | lugar | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g193` | `BARRIO` | sena_lexica | lugar | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g194` | `BOCA` | sena_lexica | objeto | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g195` | `BOLSA` | sena_lexica | objeto | denuncias | object, polarity | sena_documentada | placeholder |
| `g196` | `BUENO` | sena_lexica | descriptor | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g197` | `CABELLO` | sena_lexica | objeto | denuncias | person | sena_documentada | placeholder |
| `g198` | `CADA_DÍA` | sena_lexica | tiempo | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g199` | `CHAMARRA` | sena_lexica | objeto | denuncias | person | sena_documentada | placeholder |
| `g200` | `COCHABAMBA` | sena_lexica | lugar | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g201` | `COMPRAR` | sena_lexica | accion | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g202` | `COMUNIDAD_SORDA` | sena_lexica | participante | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g203` | `DEVOLVER` | sena_lexica | accion | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g204` | `DOLOR` | sena_lexica | estado | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g205` | `DURANTE` | sena_lexica | tiempo | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g206` | `EDAD` | sena_lexica | marcador | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g207` | `EMPEZAR` | sena_lexica | accion | consultas, denuncias, tramites | free_text, polarity | sena_documentada | placeholder |
| `g208` | `ESCAPAR` | sena_lexica | accion | denuncias | polarity | sena_documentada | placeholder |
| `g209` | `ESCUELA` | sena_lexica | lugar | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g210` | `FRACTURA` | sena_lexica | estado | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g211` | `FUTURO` | sena_lexica | tiempo | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g212` | `GORRA` | sena_lexica | objeto | denuncias | polarity | sena_documentada | placeholder |
| `g213` | `HASTA_LUEGO` | sena_lexica | marcador | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g214` | `HASTA_MAÑANA` | sena_lexica | marcador | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g215` | `HIJO` | sena_lexica | participante | denuncias | person, polarity | sena_documentada | placeholder |
| `g216` | `JEFE` | sena_lexica | participante | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g217` | `LLAMAR` | sena_lexica | accion | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g218` | `MIRAR` | sena_lexica | accion | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g219` | `PELEAR` | sena_lexica | accion | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g220` | `POLERA` | sena_lexica | objeto | denuncias | person | sena_documentada | placeholder |
| `g221` | `PREOCUPAR` | sena_lexica | estado | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g222` | `REUNIÓN` | sena_lexica | accion | consultas, tramites | polarity | sena_documentada | placeholder |
| `g223` | `ROJO` | sena_lexica | descriptor | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g224` | `SEPARADOS` | sena_lexica | participante | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g225` | `SIEMPRE` | sena_lexica | tiempo | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g226` | `URGENTE` | sena_lexica | estado | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g227` | `VARIOS` | sena_lexica | participante | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g228` | `VENDER` | sena_lexica | accion | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g229` | `ÚLTIMO` | sena_lexica | tiempo | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g230` | `ABRIR` | sena_lexica | accion | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g231` | `ADULTO` | sena_lexica | participante | denuncias | polarity | sena_documentada | placeholder |
| `g232` | `ALCALDÍA` | sena_lexica | institucion | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g233` | `AÑO` | sena_lexica | tiempo | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g234` | `AÑO_PASADO` | sena_lexica | tiempo | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g235` | `BAJO` | sena_lexica | descriptor | denuncias | polarity | sena_documentada | placeholder |
| `g236` | `BUENOS_DÍAS` | sena_lexica | marcador | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g237` | `BURLAR` | sena_lexica | accion | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g238` | `CARO` | sena_lexica | descriptor | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g239` | `CONFIANZA` | sena_lexica | estado | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g240` | `CONTINUAR` | sena_lexica | accion | consultas, denuncias, tramites | free_text, polarity | sena_documentada | placeholder |
| `g241` | `CORTO` | sena_lexica | descriptor | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g242` | `CURAR` | sena_lexica | accion | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g243` | `DE_NADA` | sena_lexica | marcador | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g244` | `DEJAR` | sena_lexica | accion | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g245` | `DESCANSO` | sena_lexica | tiempo | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g246` | `DIFERENTE` | sena_lexica | descriptor | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g247` | `DIFÍCIL` | sena_lexica | descriptor | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g248` | `DISCRIMINACIÓN` | sena_lexica | evidencia | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g249` | `DORMIR` | sena_lexica | accion | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g250` | `ENFRENTE` | sena_lexica | lugar | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g251` | `ESCUELA_NOCTURNA` | sena_lexica | lugar | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g252` | `ESPOSA` | sena_lexica | participante | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g253` | `EVALUAR` | sena_lexica | accion | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g254` | `FUERA` | sena_lexica | lugar | denuncias | place, polarity | sena_documentada | placeholder |
| `g255` | `GANAR_DINERO` | sena_lexica | accion | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g256` | `GOBIERNO` | sena_lexica | institucion | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g257` | `GORDO` | sena_lexica | descriptor | denuncias | polarity | sena_documentada | placeholder |
| `g258` | `GRITAR` | sena_lexica | accion | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g259` | `HOLA` | sena_lexica | marcador | consultas, denuncias, tramites | — | sena_documentada | baked |
| `g260` | `HUESOS` | sena_lexica | estado | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g261` | `IGNORAR` | sena_lexica | accion | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g262` | `JULIO` | sena_lexica | tiempo | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g263` | `LENTES` | sena_lexica | objeto | denuncias | polarity | sena_documentada | placeholder |
| `g264` | `LIBRE` | sena_lexica | tiempo | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g265` | `LISTA` | sena_lexica | evidencia | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g266` | `LLEGAR` | sena_lexica | accion | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g267` | `LO_SIENTO` | sena_lexica | marcador | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g268` | `LUEGO` | sena_lexica | tiempo | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g269` | `LUNES` | sena_lexica | tiempo | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g270` | `MARTES` | sena_lexica | tiempo | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g271` | `MARZO` | sena_lexica | tiempo | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g272` | `MEDICINA` | sena_lexica | objeto | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g273` | `MENTIRA` | sena_lexica | marcador | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g274` | `MOMENTO` | sena_lexica | tiempo | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g275` | `NO_ESTAR_DE_ACUERDO` | sena_lexica | marcador | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g276` | `OCUPADO` | sena_lexica | tiempo | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g277` | `OFICIAL` | sena_lexica | interaccion | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g278` | `ORGANIZAR` | sena_lexica | accion | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g279` | `OYENTE` | sena_lexica | participante | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g280` | `PALABRA` | sena_lexica | accion | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g281` | `PANTALÓN` | sena_lexica | objeto | denuncias | person | sena_documentada | placeholder |
| `g282` | `PAREJA` | sena_lexica | participante | consultas, denuncias, tramites | free_text | sena_documentada | placeholder |
| `g283` | `PARIENTE` | sena_lexica | participante | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g284` | `PASADO_MAÑANA` | sena_lexica | tiempo | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g285` | `PERMISO` | sena_lexica | marcador | consultas, denuncias, tramites | — | sena_documentada | baked |
| `g286` | `PROHIBIDO` | sena_lexica | evidencia | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g287` | `PROVINCIA` | sena_lexica | lugar | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g288` | `RAYOS_X` | sena_lexica | objeto | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g289` | `RECHAZAR` | sena_lexica | accion | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g290` | `RESULTADO` | sena_lexica | evidencia | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g291` | `SEGUNDO` | sena_lexica | tiempo | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g292` | `SEÑOR` | sena_lexica | participante | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g293` | `SUYO` | sena_lexica | participante | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g294` | `TAL_VEZ` | sena_lexica | marcador | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g295` | `TODOS_LOS_DÍAS` | sena_lexica | tiempo | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g296` | `TRISTE` | sena_lexica | estado | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g297` | `TRUFI` | sena_lexica | objeto | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g298` | `ABUSAR` | sena_lexica | accion | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g299` | `ARRESTAR` | sena_lexica | accion | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g300` | `IDENTIFICAR` | sena_lexica | accion | consultas, denuncias, tramites | free_text, polarity | sena_documentada | placeholder |
| `g301` | `INSTITUCIÓN` | sena_lexica | institucion | consultas, denuncias, tramites | — | sena_documentada | placeholder |
| `g302` | `MALTRATAR` | sena_lexica | accion | denuncias | polarity | sena_documentada | placeholder |
| `g303` | `ÓRGANO_JUDICIAL` | sena_lexica | institucion | consultas, tramites | place, polarity | sena_documentada | placeholder |
| `g304` | `A` | letra_dactilologica | accion | consultas, denuncias, tramites | — | letra_dactilologica | baked |
| `g305` | `B` | letra_dactilologica | accion | consultas, denuncias, tramites | — | letra_dactilologica | baked |
| `g306` | `C` | letra_dactilologica | accion | consultas, denuncias, tramites | — | letra_dactilologica | baked |
| `g307` | `D` | letra_dactilologica | accion | consultas, denuncias, tramites | — | letra_dactilologica | baked |
| `g308` | `E` | letra_dactilologica | accion | consultas, denuncias, tramites | — | letra_dactilologica | baked |
| `g309` | `F` | letra_dactilologica | accion | consultas, denuncias, tramites | — | letra_dactilologica | baked |
| `g310` | `G` | letra_dactilologica | accion | consultas, denuncias, tramites | — | letra_dactilologica | baked |
| `g311` | `H` | letra_dactilologica | accion | consultas, denuncias, tramites | — | letra_dactilologica | baked |
| `g312` | `I` | letra_dactilologica | accion | consultas, denuncias, tramites | — | letra_dactilologica | placeholder |
| `g313` | `J` | letra_dactilologica | accion | consultas, denuncias, tramites | — | letra_dactilologica | baked |
| `g314` | `K` | letra_dactilologica | accion | consultas, denuncias, tramites | — | letra_dactilologica | placeholder |
| `g315` | `L` | letra_dactilologica | accion | consultas, denuncias, tramites | — | letra_dactilologica | baked |
| `g316` | `M` | letra_dactilologica | accion | consultas, denuncias, tramites | — | letra_dactilologica | baked |
| `g317` | `N` | letra_dactilologica | accion | consultas, denuncias, tramites | — | letra_dactilologica | baked |
| `g318` | `Ñ` | letra_dactilologica | accion | consultas, denuncias, tramites | — | letra_dactilologica | baked |
| `g319` | `O` | letra_dactilologica | accion | consultas, denuncias, tramites | — | letra_dactilologica | baked |
| `g320` | `P` | letra_dactilologica | accion | consultas, denuncias, tramites | — | letra_dactilologica | baked |
| `g321` | `Q` | letra_dactilologica | accion | consultas, denuncias, tramites | — | letra_dactilologica | baked |
| `g322` | `R` | letra_dactilologica | accion | consultas, denuncias, tramites | — | letra_dactilologica | baked |
| `g323` | `S` | letra_dactilologica | accion | consultas, denuncias, tramites | — | letra_dactilologica | baked |
| `g324` | `T` | letra_dactilologica | accion | consultas, denuncias, tramites | — | letra_dactilologica | baked |
| `g325` | `U` | letra_dactilologica | accion | consultas, denuncias, tramites | — | letra_dactilologica | baked |
| `g326` | `V` | letra_dactilologica | accion | consultas, denuncias, tramites | — | letra_dactilologica | baked |
| `g327` | `W` | letra_dactilologica | accion | consultas, denuncias, tramites | — | letra_dactilologica | baked |
| `g328` | `X` | letra_dactilologica | accion | consultas, denuncias, tramites | — | letra_dactilologica | baked |
| `g329` | `Y` | letra_dactilologica | accion | consultas, denuncias, tramites | — | letra_dactilologica | baked |
| `g330` | `Z` | letra_dactilologica | accion | consultas, denuncias, tramites | — | letra_dactilologica | baked |
| `g331` | `0` | digito | accion | consultas, denuncias, tramites | — | digito | placeholder |
| `g332` | `1` | digito | accion | consultas, denuncias, tramites | — | digito | placeholder |
| `g333` | `2` | digito | accion | consultas, denuncias, tramites | — | digito | placeholder |
| `g334` | `3` | digito | accion | consultas, denuncias, tramites | — | digito | placeholder |
| `g335` | `4` | digito | accion | consultas, denuncias, tramites | — | digito | placeholder |
| `g336` | `5` | digito | accion | consultas, denuncias, tramites | — | digito | placeholder |
| `g337` | `6` | digito | accion | consultas, denuncias, tramites | — | digito | placeholder |
| `g338` | `7` | digito | accion | consultas, denuncias, tramites | — | digito | placeholder |
| `g339` | `8` | digito | accion | consultas, denuncias, tramites | — | digito | placeholder |
| `g340` | `9` | digito | accion | consultas, denuncias, tramites | — | digito | placeholder |
| `g341` | `SEPDAVI` | institucion_dactilologica | institucion | consultas, denuncias, tramites | — | dactilologia | spelled |
| `g342` | `SEPDEP` | institucion_dactilologica | institucion | consultas, denuncias, tramites | — | dactilologia | spelled |
| `g343` | `FELCC` | institucion_dactilologica | institucion | consultas, denuncias, tramites | — | dactilologia | spelled |
| `g344` | `FELCV` | institucion_dactilologica | institucion | consultas, denuncias, tramites | — | dactilologia | spelled |
| `g345` | `FISCALIA` | institucion_dactilologica | institucion | consultas, denuncias, tramites | — | dactilologia | spelled |
| `g346` | `JUZGADO` | institucion_dactilologica | institucion | consultas, denuncias, tramites | — | dactilologia | spelled |
