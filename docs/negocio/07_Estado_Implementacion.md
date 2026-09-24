# Estado de la implementación por bloque

Fecha: 2026-09-24. Lo que sigue describe lo que **está en el repositorio y
verificado**, y lo que no. Ningún bloque se declara hecho por haberse
empezado.

Comandos ejecutados para todas las cifras de este documento:

```
flutter analyze                             → No issues found!
flutter test                                → 542 tests, 1 omitido (preexistente)
python -m unittest discover -s aws/tests    → 193 tests, OK
python tool/validate_business_config.py     → 0 errores
python tool/build_dialogue_graph.py --check → grafo al día con el corpus
```

Línea base al empezar esta fase: 452 Dart, 162 Python.

---

## Bloque 0 — Correcciones vivas · **hecho**

| # | Hallazgo | Corrección | Prueba |
|---|---|---|---|
| 0.1 | Borrador borrado al reabrir el mismo encargo | `openCards` no limpia cuando `sameErrand` | `modos_abc_conversacion_test.dart` |
| 0.2 | `ESCAPAR` redactaba un robo | El robo se afirma solo si hay acción de sustracción | `test_contrato_cliente_real.py::EscaparNoEsRobo` |
| 0.3 | `actorRole` enviado, `actor_role` leído | `normalize_facts` acepta ambos; el cliente manda camelCase | `test_contrato_cliente_real.py::NombresDelContrato` |
| 0.4 | `declaration` descartado fuera de `denuncia_robo` | Sin puerta por contexto; `uses_structured` renombrado y ya no ensombrecido | `test_contrato_cliente_real.py::EstructuradoFueraDeDenunciaRobo` |
| 0.5 | Numerales: catálogo `'0'` vs resolutor `CERO` | `canonicalFor` traduce, como el backend | `numerales_avatar_test.dart` |

**0.5 con matiz.** Lo comprobable en código está hecho y probado: el cliente
pide el nombre que el propio sistema declara, y los mapas de cliente y backend
coinciden. **Lo que no se ha comprobado** es que el modelo contenga esas
animaciones: el `.glb` no está en el repositorio. Una prueba vigila que si
algún día se añade, haya que revisar las afirmaciones de cobertura. La
reproducción real en el avatar **queda pendiente de dispositivo**.

---

## Bloque 1 — Navegación · **hecho**

Barra: Tarjetas LSB · Conversación · Voz a LSB, con Conversación al centro,
comprobado por posición real en pantalla.

`AppTabId` persiste una cadena, no un índice. El orden de declaración del enum
es **distinto** del visual a propósito: si coincidieran, un uso accidental de
`.index` funcionaría por casualidad. `fromLegacyIndex` traduce lo guardado con
el esquema anterior.

---

## Bloque 2 — Sesión y modos · **hecho**

Selector al entrar, con dos opciones grandes. `AppShell` no monta la
navegación mientras no haya modo, así que no puede verse una conversación
anterior antes de decidir la sesión.

Dos claves de almacenamiento: `device_config_v1` y `session_content_v1`.
«Finalizar atención» borra lo del ciudadano y conserva el perfil institucional.
Una sesión en ventanilla no se repone al reabrir.

---

## Bloque 3 — Necesidad, intención y acto · **hecho**

`standaloneDeclaration` → `standaloneIntervention`, con `CommunicativeAct`
aparte. Consultas produce una pregunta.

`setSpeechAct` existía y **nadie lo llamaba**: todo salía como afirmación. Ya
lo fija el lanzamiento.

---

## Bloque 4 — Datos de negocio en la app · **hecho**

`tool/build_business_assets.py` genera `assets/business/institution_profiles.json`
y no escribe si el validador falla. Fuente única en `docs/negocio/config/`.

Las intenciones sin cobertura viajan hasta la interfaz **para poder decirlo**.

---

## Bloque 5 — Candidatos · **hecho en el motor, parcial en la interfaz**

`CandidateEngine` aplica el orden lógico y garantiza las dos reglas duras: una
opción no se vuelve válida porque el modelo la sugiera, y una respuesta
correcta no se elimina por ser poco frecuente en esa institución.

**Pendiente:** el filtro por campo solo cubre hoy la polaridad. Las demás
ranuras (persona, objeto, lugar…) todavía no restringen qué tipo de tarjeta
cabe, así que cambiar de categoría o usar el buscador aún puede ofrecer algo
poco pertinente. No introduce nada incompatible con el sí/no, que era el caso
más dañino, pero el resto está a medias.

**Pendiente:** eliminar las ramas muertas `'tramite'` y `'consulta'` de
`resolveAssemblerContext`, o construir esos contextos de verdad.

---

## Bloque 6 — Colección de hechos · **hecho**

`FactInfo.action` único → `List<Fact>`, cada hecho con su id, `ActorRole`
tipado, negación y certeza. Se distingue «me robaron y yo escapé» de «me
robaron y el ladrón escapó», hasta el texto y el audio. Quitar un hecho no
toca el otro. Cancelar la aclaración conserva el estado anterior sin atribuir
la huida a nadie. Los borradores antiguos se leen como los hechos que
significaban.

No se resolvió subiendo `maxPicks`: el límite vive en
`DeclarationDraftLimits.maxFacts`, que usan a la vez el catálogo y el modelo.

---

## Bloque 7 — Contrato v3 · **hecho en código, no desplegado**

`BusinessSignals` transporta modo, perfil, necesidad, intención, conversación
y versión del mensaje. El backend valida los conjuntos cerrados y devuelve 400
ante un valor desconocido. Un cliente v2 sigue pasando.

Hay prueba de que el perfil **no es contenido**: su nombre no aparece en el
texto y cambiar de institución no altera lo declarado.

---

## Bloque 8 — Presentación · **parcial**

La cuadrícula de tarjetas pasa a ancho adaptable (`maxCrossAxisExtent`), así
que en tablet aparecen más columnas en vez de dos tarjetas enormes. El
selector de modo y la pantalla de necesidades usan texto **e** icono, no color.

**Pendiente:** medir accesibilidad y latencia en dispositivos modestos, y
probar el avatar en las dos orientaciones.

---

## Bloque 9 — Documentación · **parcial**

Este documento y los commits. **Pendiente:** actualizar los apartados 1.3, 1.4
y 1.5 de `informe_final.md` con la ampliación a trámites registrales,
notariales y municipales.

---

## Lo que hace falta desplegar

| Componente | Estado | Qué hace falta |
|---|---|---|
| `aws/lambda_function.py` | Cambiado, **sin desplegar** | Redespliegue. Sin él, el backend en producción sigue convirtiendo ESCAPAR en robo, ignorando `actorRole` y descartando el `declaration` fuera de `denuncia_robo`. |
| `aws/lambda_text_to_lsb.py` | Sin cambios | Nada. |
| Cliente Flutter | Cambiado | Compilación y distribución habituales. |

**El orden importa:** el cliente ya envía `contractVersion: 3` con los campos
nuevos. La Lambda desplegada los ignorará —no rompe, porque los campos
desconocidos no se validan en la versión antigua— pero **las correcciones del
bloque 0 no estarán activas hasta que se redespliegue**.

---

## Verificaciones que exigen servicios desplegados

No se han hecho y no se pueden hacer desde aquí:

1. **Bedrock real.** Todas las pruebas usan el doble de boto3. El
   comportamiento del modelo ante los prompts nuevos no está medido.
2. **Polly real.** El audio se prueba con un doble que devuelve bytes falsos.
   Que el texto y el audio correspondan a la misma versión está comprobado en
   el cliente; que Polly pronuncie bien la frase con dos hechos, no.
3. **S3 y caché.** La caché semántica se ejerce contra un doble.
4. **El avatar 3D.** El `.glb` no está en el repositorio. Los numerales, la
   dactilología y las cinco señas léxicas necesitan comprobación en
   dispositivo.
5. **Latencia extremo a extremo** en un teléfono modesto con red real.

---

## Límite que no cambia

Nada de este trabajo valida lingüísticamente ninguna composición. Las
entradas resueltas por dactilología y las composiciones provisionales de la
sección 4 del corpus **siguen sin validar** con señantes de Cochabamba ni con
intérpretes. La verificación hecha es de cobertura léxica, integridad de datos
y comportamiento del sistema.
