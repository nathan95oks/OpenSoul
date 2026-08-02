# Evaluación del motor semántico LSB → español

**Fecha:** 2026-08-02 · **Módulo:** `lsb_to_text_audio` · **Autor:** Nathanael Alba

## Por qué existe este banco de pruebas

El módulo sostiene una decisión de arquitectura concreta: **un motor de reglas
propio genera la declaración, y la IA solo la refina**. Hasta ahora esa
afirmación descansaba en pruebas de cobertura que respondían *sí o no*, no en
cifras. Un tribunal puede rebatir una opinión; no puede rebatir una medición
reproducible.

El banco mide las tres vías posibles sobre el mismo corpus:

1. **Motor local solo** — `LocalSentenceAssembler`, sin red.
2. **Bedrock solo** — el refinador remoto, sin motor local.
3. **Híbrido** — lo que el usuario recibe de verdad (`ConversationEngine`).

## Cómo se ejecuta

```bash
# Solo motor local — determinista, sin red, corre en cada `flutter test`
flutter test test/benchmark/engine_benchmark_test.dart

# Comparación completa — consume cuota de Bedrock y Polly
flutter test test/benchmark/engine_benchmark_test.dart \
    --dart-define=BENCHMARK_REMOTE=true
```

La comparación remota está apagada por defecto a propósito: depende de la red y
de la cuota de AWS, así que no debe correr en cada ejecución de la suite.

## Métricas

Se separan en dos familias por su coste de obtención.

**Sin referencia humana** — se calculan hoy, sobre cualquier salida:

| Métrica | Qué mide |
|---|---|
| Cobertura total de glosas | % de casos en los que **ninguna** glosa se perdió |
| Glosas representadas | % de glosas representadas sobre el total del corpus (más fina: distingue perder una de perder cinco) |
| Declaraciones bien formadas | % sin defectos duros: vacía, sin mayúscula inicial, sin cierre, espaciado roto, o con glosas volcadas en crudo |
| Sin defecto alguno | añade los defectos de estilo (palabra repetida) |
| Respuestas degeneradas | veces que el backend devolvió algo que `isBackendDegenerate` rechaza |

**Con referencia humana** — se activan al rellenar `reference` en
`test/benchmark/corpus.dart`: coincidencia exacta y F1 por palabra.

## Resultados — 25 casos, 5 contextos

| Vía | Cobertura total | Glosas representadas | Bien formadas |
|---|---|---|---|
| **Motor local** | **100 %** | **100 %** | **100 %** |
| Bedrock solo | 28 % | 58,3 % | 100 % |
| **Híbrido (entregado)** | **100 %** | **100 %** | **100 %** |

Respuestas degeneradas del backend: **20 / 25 (80 %)**. Fallos de red: 0/25.

### Lectura

**Bedrock redacta mejor y declara peor.** Sus 25 salidas son impecables de forma
—100 % bien formadas, 100 % sin defecto de estilo, frente al 96 % del motor
local— pero **omite contenido declarado**. Ejemplo real del corpus:

> Glosas: `AMENAZAR + AYUDA + PELO_CORTO + POLICIA + ASUSTADO`
> Bedrock: *"Una persona de cabello corto me amenazó, provocándome un estado de temor."*

Desaparecen la petición de ayuda y la policía. En una declaración destinada a una
institución pública, eso no es una redacción más elegante: es una declaración
distinta de la que la persona sorda construyó.

El híbrido iguala al motor local en fidelidad (100 %) porque la detección de
degeneración descarta el refinamiento cuando pierde contenido — y lo descarta en
el 80 % de los casos. **Ese 80 % es la justificación cuantitativa de que el motor
propio no es un respaldo, es la vía principal.**

### Sesgo de medición corregido

La primera ejecución dio 47,9 % para Bedrock. Parte de esa pérdida era un
artefacto: la métrica buscaba la raíz de la glosa y Bedrock usa registro
jurídico formal (*sustrajo* por ROBAR, *individuo* por HOMBRE, *temor* por
MIEDO). Se añadió una tabla de equivalencias formales (`_formalRegister` en
`metrics.dart`) y la cifra subió a 58,3 %.

Se admitieron solo equivalencias que **no alteran el hecho declarado**.
*"Madrugada"* por `NOCHE` quedó fuera a propósito: cambia el momento del
suceso, y en una denuncia eso importa.

El 41,7 % restante es omisión real, no paráfrasis.

## Limitaciones declaradas

- **El estándar de oro está vacío (0/25 validados).** Las métricas actuales no
  necesitan referencia humana, pero la coincidencia exacta y el F1 solo se
  activan cuando alguien —idealmente una persona sorda usuaria de LSB o un
  intérprete— escriba la oración correcta de cada caso en `corpus.dart`.
- **25 casos son pocos** para una conclusión estadística fuerte; bastan para una
  comparación de arquitecturas, no para afirmar un porcentaje poblacional.
- **La cobertura por raíz léxica es aproximada.** Comparte criterio con
  `semantic_coverage_test.dart`, así que un fallo del criterio afecta a ambas.
- La medición de Bedrock depende del modelo configurado en la Lambda; cambiarlo
  invalida la comparación y obliga a repetirla.

## Defecto encontrado por el propio banco

`otro · testigo mínimo` repite la palabra *presencié* al cruzar el preámbulo con
la primera oración:

> *"Quiero declarar como testigo lo que presencié. Presencié cómo una persona
> robó a otra persona."*

Clasificado como defecto de **estilo**, no de forma: la declaración sigue siendo
válida. Es el único defecto del motor local en los 25 casos (96 % sin defecto
alguno).
