# Texto de actualización para los apartados 4.4 a 4.7 del documento de grado

Redactado para incorporarse al proyecto de grado. Las cifras proceden de
ejecutar las herramientas y las pruebas del repositorio el 24 de septiembre de
2026; cada una es reproducible con los comandos indicados al final.

**Corrección de cifras desactualizadas.** El apartado 4.4.4 de la versión v1.4
menciona «210 glosas» como cobertura del catálogo. Esa cifra ya no corresponde
al sistema: el catálogo que la aplicación empaqueta
(`assets/dictionary/official_dictionary.json`) contiene **346 entradas**.
Tampoco debe emplearse la cifra de 303 como número de animaciones: son las
**entradas documentadas del apéndice 12 del corpus maestro**, no recursos
ejecutables por el avatar.

---

## 4.4. Validación técnica

### 4.4.5. Cobertura del corpus conversacional

Para verificar que el sistema responde a la conversación real y no solo a un
recorrido previsto, se contrastó el banco completo de intervenciones de
ejemplo del corpus maestro —**209 enunciados**: 98 preguntas del
funcionario receptor (sección 6), 60 preguntas del ciudadano sordo (sección 7)
y 51 declaraciones y respuestas frecuentes (sección 8)— contra los recursos
léxicos que la aplicación tiene efectivamente empaquetados.

El procedimiento resuelve cada concepto objetivo del corpus frente a cuatro
planos que se mantienen deliberadamente separados: el concepto semántico, la
glosa elegible en el catálogo de la aplicación, el mecanismo de representación
(seña directa, dactilología o número) y el recurso de avatar disponible. La
herramienta `tool/build_dialogue_graph.py` automatiza esta resolución y emite
la matriz completa, intervención por intervención, en
`docs/Matriz_Cobertura_Corpus_209.md`.

**Tabla — Cobertura del corpus conversacional (209 intervenciones)**

| Estado | Intervenciones | Porcentaje |
|---|---:|---:|
| Cubierta con señas del catálogo | 184 | 88,0 % |
| Cubierta mediante dactilología | 20 | 9,6 % |
| Cubierta por composición validada | 0 | 0,0 % |
| Requiere validación lingüística | 0 | 0,0 % |
| No soportada | 5 | 2,4 % |
| **Total** | **209** | **100 %** |

*Fuente: elaboración propia, 2026.*

Las cinco intervenciones no soportadas corresponden a cuatro conceptos
genéricos —OBJETO, TEXTO, COLOR y DELETREAR— que el corpus no documenta como
entradas léxicas. La sección 4 del propio corpus prescribe el tratamiento
seguro para casos así: preferir el objeto concreto antes que crear una seña
genérica. La aplicación no las representa hoy y el sistema lo declara
explícitamente en lugar de simular una traducción.

### 4.4.6. Cobertura del avatar tridimensional

Se distingue entre disponibilidad léxica y disponibilidad de animación, porque
una entrada presente en el catálogo no implica que exista un recurso
ejecutable. La verificación se realizó sobre el resolutor efectivo
(`AnimationUrlResolver`) y no sobre el campo de datos `animationFile`. Se trata
de una lectura del código: el archivo del modelo tridimensional no forma parte
del repositorio, de modo que estas cifras describen lo que el sistema declara
que puede pedir, no una inspección de las animaciones existentes.

**Tabla — Recursos léxicos y de animación verificados**

| Recurso | Cantidad | Naturaleza |
|---|---:|---|
| Apéndice 12 del corpus maestro | 303 | Glosas documentadas con trazabilidad M1–M4 y Diccionario 2024 |
| Catálogo de la aplicación | 346 | Entradas elegibles como tarjeta, incluidos mecanismos de deletreo y numeración |
| Léxico del servicio `audio → LSB` | 346 | Paridad exacta entre cliente y backend |
| Identificadores declarados disponibles por el resolutor | 41 | 5 señas léxicas, 25 letras dactilológicas y 11 numerales. Procede de la constante `available3DGlosses`; el modelo `.glb` no forma parte del repositorio y no fue inspeccionado. |

*Fuente: elaboración propia, 2026.*

En consecuencia, la dirección español → LSB se apoya hoy mayoritariamente en
dactilología y en marcadores de posición explícitos. El sistema no simula una
seña inexistente: cuando el concepto carece de representación, lo comunica.

### 4.4.7. Validación del ciclo conversacional bidireccional

Se validó el ciclo completo de alternancia entre participantes en sus tres
modos de uso del módulo LSB → texto/audio: declaración independiente fuera de
la conversación (modo A), apertura del turno por la persona sorda dentro de la
conversación (modo B) y respuesta a un turno concreto del interlocutor oyente
(modo C). La distinción entre los tres es dato explícito del lanzamiento del
módulo, no una inferencia a partir de la pestaña activa ni del estado residual
de una conversación anterior.

La validación incluye la estabilidad del enlace entre turnos: el
identificador del turno al que se responde se congela al abrir el módulo, de
modo que la respuesta permanece vinculada al enunciado que la persona sorda
tenía a la vista aunque llegue una nueva intervención durante la edición. Si
ese turno deja de existir —por reinicio del historial o restauración de
sesión— el sistema no envía la declaración ni la vincula a otro enunciado:
notifica el conflicto y conserva el contenido.

Durante esta validación se detectó y corrigió un defecto de integridad del
historial: los identificadores de turno se derivaban únicamente de la marca
temporal en microsegundos, de manera que dos turnos generados en el mismo
microsegundo compartían identificador y el mecanismo de sustitución de turnos
reemplazaba la intervención equivocada, con pérdida silenciosa de una
declaración ya registrada. El defecto quedó cubierto por una prueba de
regresión específica.

---

## 4.5. Modelo declarativo de diálogo

La conversación deja de depender de un árbol de decisión fijo y pasa a
apoyarse en un grafo declarativo y versionado, generado desde el corpus
maestro y empaquetado con la aplicación
(`assets/dialogue/dialogue_graph.json`).

El grafo contiene **209 nodos** que agrupan **99 intenciones comunicativas
distintas**. Cada nodo declara: identificador estable y versión; procedencia
exacta en el corpus (sección, subsección, fila y enunciado original); ámbito
temático; intención; acto comunicativo; los modos A/B/C en que puede
activarse; las ranuras de respuesta que admite (polaridad, persona, objeto,
lugar, tiempo, monto, institución, evidencia o texto libre); las opciones ya
resueltas contra el catálogo; las opciones pendientes con su motivo; y las
transiciones hacia los nodos que aportan información aún no proporcionada.

Dos propiedades resultan centrales para el dominio judicial:

1. **Las ranuras no aparecen por omisión.** Una pregunta abierta no ofrece
   respuesta de sí/no, y una afirmación o instrucción del interlocutor oyente
   no se convierte en pregunta cerrada. La polaridad se ofrece únicamente
   cuando el enunciado entrante es una pregunta cerrada.
2. **La incertidumbre es una respuesta.** Todo nodo incorpora una salida
   segura (NO SABER) que preserva el desconocimiento en lugar de forzar una
   afirmación.

El emparejamiento entre el español libre del interlocutor oyente y los nodos
se realiza por similitud léxica con lematización aproximada. Cuando ninguna
correspondencia alcanza el umbral, el sistema no selecciona el nodo más
parecido: devuelve ausencia de correspondencia y ofrece intenciones
candidatas, conservando el enunciado original. Se asume explícitamente que un
corpus finito produce una cobertura finita y que existirán entradas no
cubiertas.

---

## 4.6. Control de invenciones léxicas

El sistema incorpora tres barreras acumulativas para que ninguna capa
introduzca vocabulario que el corpus no respalde.

En el **backend**, el modelo fundacional únicamente reordena y selecciona
dentro del vocabulario que el cliente le entrega; cualquier glosa ajena a esa
lista se descarta después de la generación, con independencia de lo que el
modelo produzca.

En el **grafo de diálogo**, toda opción ofrecida como tarjeta se resuelve
contra el catálogo empaquetado en el momento de generar el artefacto. Lo que
no resuelve no se emite: queda registrado aparte, con el motivo, para poder
declararlo pendiente en lugar de aproximarlo.

En la **interfaz**, la reordenación procedente del modelo no elimina ninguna
opción que el catálogo ofreciera: se antepone lo más pertinente y se conserva
el resto accesible.

Se mantiene asimismo la distinción exigida por la sección 4 del corpus entre
seña directa documentada, concepto semántico, alias de software, composición
provisional y dactilología. En particular, DENUNCIA, FISCAL en su acepción
jurídica, FISCALÍA, JUZGADO y VÍCTIMA no se representan como señas directas;
se tratan mediante dactilología o quedan señalados como pendientes de
validación. Una prueba automatizada verifica específicamente que DENUNCIA no
se ofrezca nunca como seña directa.

---

## 4.7. Estado de verificación por componente

Se distingue entre lo implementado, lo probado, lo pendiente y lo desplegado,
según la evidencia disponible y no según la intención de diseño.

**Tabla — Estado verificado por componente**

| Componente | Implementado | Probado | Desplegado | Pendiente |
|---|---|---|---|---|
| Modos A/B/C del módulo LSB → texto/audio | Sí | Sí, 12 pruebas | Sí, en la aplicación | Pruebas sobre widgets montados |
| Estabilidad del enlace entre turnos | Sí | Sí | Sí | — |
| Integridad de identificadores de turno | Sí | Sí, prueba de regresión | Sí | — |
| Grafo declarativo de diálogo (209 nodos) | Sí | Sí, 22 pruebas de integridad | Sí, como recurso empaquetado | Validación lingüística de las composiciones |
| Matriz de cobertura del corpus | Sí | Sí, generación verificable | — | Decisión de producto sobre conceptos genéricos |
| Priorización de opciones por nodo | Sí | Sí | Sí | Medición de latencia en dispositivos modestos |
| Contextos de consulta y trámite | No | — | — | Construcción completa de sus recorridos |
| Cobertura de animación del avatar | Parcial (41 recursos) | Sí | Sí | Producción de señas léxicas adicionales |

*Fuente: elaboración propia, 2026.*

### Evidencia de ejecución

```
flutter analyze                             → sin incidencias
flutter test                                → 452 pruebas, todas satisfactorias
python -m unittest discover -s aws/tests    → 162 pruebas, satisfactorias
python tool/build_dialogue_graph.py --check → artefacto al día con el corpus
```

### Limitación explícita

Ninguna de las composiciones provisionales ni de las secuencias de glosas
empleadas en este trabajo ha sido validada con señantes de Lengua de Señas
Boliviana de Cochabamba ni con intérpretes acreditados. La verificación
realizada es de cobertura léxica, integridad de datos y comportamiento del
sistema; **no** constituye validación de naturalidad lingüística. Dicha
validación es requisito previo a afirmar que una composición o una secuencia
resulta lingüísticamente adecuada, y a considerar el sistema preparado para
publicación o uso en atención real.
