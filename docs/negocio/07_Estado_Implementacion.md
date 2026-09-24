# Estado de la implementación por bloque

Fecha: 2026-09-24. Describe lo que **está en el repositorio y verificado**.
Ningún bloque se declara terminado mientras su interfaz permita eludir sus
reglas.

## Comandos ejecutados y resultados

```
flutter analyze                             → No issues found!
flutter test                                → 617 aprobadas, 1 omitida, 0 fallidas
python -m unittest discover -s aws/tests    → 220 aprobadas, 0 fallidas
python tool/validate_business_config.py     → 0 errores
python tool/build_dialogue_graph.py --check → grafo al día con el corpus
python aws/deploy/smoke_check.py            → 8/8 (contra handler local)
python aws/deploy/build_package.py          → paquete construido
```

La única prueba omitida es preexistente y ajena a este trabajo.
Línea base al empezar esta fase: 452 Dart, 162 Python.

**Ninguna de estas cifras verifica servicios desplegados.** Ver §«Lo que solo
se ha revisado en código».

---

## Corrección a un informe anterior

Dije que `perdida`, `tramite_id` y `orientacion` eran destinos que el
ensamblador no conoce y que por eso acababan en denuncia de robo. **Es falso.**
Son compositores reales y probados
(`local_sentence_assembler.dart:51-53`: `_composeLoss`, `_composeProcedure`,
`_composeGuidance`).

Lo cierto es otra cosa, y es peor de lo que parecía: **eran inalcanzables**.
Solo se llegaba a ellos comparando `currentContextId` contra `'tramite'` o
`'consulta'`, y `allSelectableContexts` no ofrece ningún contexto con esos
ids. Tres compositores escritos y mantenidos que la aplicación nunca podía
usar. Ahora los alcanza la necesidad elegida.

---

## Bloque 0 — Correcciones vivas · **hecho**

| # | Hallazgo | Prueba |
|---|---|---|
| 0.1 | Borrador borrado al reabrir el mismo encargo | `recorridos_completos_test.dart` |
| 0.2 | `ESCAPAR` redactaba un robo | `test_contrato_cliente_real.py` |
| 0.3 | `actorRole` enviado, `actor_role` leído | `test_contrato_cliente_real.py` |
| 0.4 | `declaration` descartado fuera de `denuncia_robo` | `test_contrato_cliente_real.py` |
| 0.5 | Numerales: catálogo `'0'` vs resolutor `CERO` | `numerales_avatar_test.dart` |

**0.5 sigue con matiz.** Lo comprobable en código está hecho. Lo que **no** se
ha comprobado es que el modelo contenga esas animaciones: el `.glb` no está en
el repositorio. Una constante con nombres de animación no demuestra que el
archivo las tenga. **Pendiente de dispositivo.**

---

## Bloques 1, 2, 3, 4, 6, 7 — **hechos**

Navegación con identificadores estables y migración de índices; modos personal
y ventanilla con persistencia separada; necesidad, intención y acto
comunicativo en el lanzamiento; datos de negocio empaquetados desde una fuente
única; colección de hechos con protagonista propio; contrato v3 validado.

Detalle en los mensajes de commit.

---

## Bloque 5 — Candidatos · **hecho**

Era el que quedaba a medias. El filtro cubría solo polaridad, así que el
buscador y las categorías podían insertar cualquier tarjeta en cualquier
pregunta.

`SemanticFunction` expone la tabla que el ensamblador ya usaba para redactar
(397 entradas). Una sola clasificación para ofrecer y para escribir: con dos,
antes o después discrepan y se ofrece algo que la frase no sabe colocar.

El filtro se aplica en **todas** las vías: cuadrícula inicial, categorías,
sugerencias del modelo y zona activa cuando no hay turno del oyente.

Tres salvedades, para no esconder respuestas correctas:

1. Una glosa que el ensamblador no clasifica **no se filtra**.
2. Las respuestas de desconocimiento nunca se filtran.
3. **La lista blanca curada de la zona gana al filtro.** JUEZ responde
   «¿quién?» y «escribir otro» cabe en evidencia; ambas se detectaron como
   regresión al implementar.

El diccionario completo sigue consultable: filtrar una respuesta no es quitar
la palabra del catálogo, y hay prueba de que las 346 entradas siguen ahí.

---

## Bloque 8 — Presentación · **parcial**

Cuadrícula de ancho adaptable; texto e icono, no color. **Pendiente:** medir
accesibilidad, aumento de texto, orientación, teclado y latencia en teléfono y
tablet. Ver §«Lo que solo se ha revisado en código».

---

## Enrutamiento — **hecho**

`routeToAssembler` decide de más explícito a menos: intención sin cobertura,
glosas elegidas, necesidad, contexto activo.

**Lo desconocido ya no acaba en denuncia de robo.** Devuelve `otro` marcado
como no soportado, con su motivo y el vocabulario que falta; la pantalla lo
dice y deja continuar con lo que sí se puede comunicar. Aproximar a una
denuncia era acusar por omisión.

El acto comunicativo se recalcula **por intervención**: elegir Consultas no
convierte toda intervención en pregunta.

---

## Fidelidad tras Bedrock — **hecho**

`_generation_is_safe` solo comprobaba palabras. Encontrar las mismas no
demuestra nada: «me robaron y yo escapé» y «me robaron y el ladrón escapó»
comparten todas. `relations_are_preserved` comprueba quién hizo qué, qué se
negó y qué quedó en duda, con los hechos normalizados del cliente.

Cuando falla, se conserva la oración determinista, y el audio se sintetiza con
el texto **finalmente aceptado**.

**Caché:** distinguía actor, negación y certeza (van dentro de `declaration`),
pero **no** la versión del generador. Una respuesta guardada por el generador
con el fallo de ESCAPAR se habría seguido sirviendo tras desplegar la
corrección, justo en los casos más frecuentes. `GENERATOR_VERSION` y
`contractVersion` entran ahora en la clave.

---

## Qué significan las cifras

Ninguna de estas prueba atención completa de ningún servicio.

| Cifra | Qué es | Qué **no** es |
|---|---|---|
| 11 perfiles | Propuestos por mí, con su regla de organización | No son convenios ni acuerdos con esas instituciones |
| 36 de 41 intenciones | Intenciones de perfil que tienen nodos en el grafo | No es que sus trámites estén cubiertos |
| 99 intenciones | Las distintas que producen los 209 ejemplos del corpus | No es un límite de mensajes ni cobertura de servicios |
| 303 señas | Glosas del corpus §12 en el catálogo | 43 entradas más son mecanismos, no señas |
| 150 con uso | Señas que algún recorrido ofrece | Las otras 153 siguen en el diccionario, consultables |
| 41 identificadores de avatar | Constante del resolutor | **No** es una inspección del modelo 3D |

Las 5 intenciones sin cobertura (Derechos Reales ×3, Notaría, GAMC) llegan
hasta la interfaz **para decirlo**, con su brecha léxica nombrada.

---

## Despliegue

`aws/deploy/` está **preparado y sin ejecutar**, esperando aprobación.

**Orden obligatorio: backend primero.** Un cliente v3 contra la Lambda actual
recibe 200 y pierde el segundo hecho y el protagonista de cada uno. No
devolver error no es compatibilidad.

Mientras esa combinación exista, `BackendCompatibility` la cubre: lee
`contractVersion` de la respuesta, avisa de qué se perdería y usa la redacción
local. **Nunca reduce dos hechos a uno en silencio.** Es una red, no una
solución.

Paquete: 45 KB, sin dependencias nuevas.
SHA-256 `170a93fffb7b36cf519613cabb27a970d6ee74207df8d23f4de5b5f374abf23b`

---

## Lo que solo se ha revisado en código

No se presenta como medido nada de esto:

1. **Bedrock real.** Todas las pruebas usan el doble de boto3. El
   comportamiento del modelo ante los prompts nuevos no está medido.
   *Procedimiento:* `python aws/deploy/smoke_check.py --endpoint <URL>` contra
   una versión publicada con Bedrock habilitado.
2. **Polly real.** Devuelve bytes falsos localmente. Que el audio corresponda
   al texto aceptado está probado; que Polly pronuncie bien una frase con dos
   hechos, no.
3. **Caché en S3.** Se ejerce contra un doble. La separación por versión está
   probada en la clave, no en el bucket.
4. **El avatar 3D.** El `.glb` no está en el repositorio. Numerales,
   dactilología y las cinco señas léxicas necesitan comprobación en
   dispositivo. *Procedimiento:* abrir el visor y reproducir las glosas de
   `available3DGlosses`, anotando cuáles emiten `finished`.
5. **Teléfono y tablet.** Aumento de texto, orientación, controles táctiles,
   manos y rostro visibles, teclado y latencia: **no medidos**.
6. **Latencia extremo a extremo** con red real.

---

## Límite que no cambia

Nada de este trabajo valida lingüísticamente ninguna composición. Las entradas
resueltas por dactilología y las composiciones provisionales de la sección 4
del corpus **siguen sin validar** con señantes de Cochabamba ni con
intérpretes. Lo verificado es cobertura léxica, integridad de datos y
comportamiento del sistema.
