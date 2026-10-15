# OpenSoul — LSB Ciudadano

Aplicación de apoyo a la comunicación que permite a una persona sorda y a una
persona oyente **mantener una conversación** durante denuncias, consultas y
trámites ante entidades públicas bolivianas. Su corpus institucional está
centrado en Cochabamba e incluye, entre otras áreas, Policía, Fiscalía, Órgano
Judicial, SEGIP, SERECI, Derechos Reales, GAM, notarías y servicios de defensa.

Stack: Flutter + Riverpod + Clean Architecture + AWS (Lambda, API Gateway,
Bedrock, Polly, S3). El paquete Dart se llama `lsb_legal_app`.

---

## Qué problema resuelve

En Bolivia, una persona sorda que necesita presentar una denuncia o hacer un
trámite puede encontrar barreras cuando no hay interpretación en Lengua de
Señas Boliviana disponible. Escribir en español tampoco siempre ofrece una
comunicación equivalente: para muchas personas sordas es una segunda lengua,
con una gramática distinta de la LSB.

OpenSoul reduce esa barrera en ambos sentidos de la conversación sin exigirle a
la persona sorda redactar todo en español. Es una ayuda comunicativa: **no
sustituye automáticamente a un intérprete, no certifica una denuncia y no
representa consentimiento ni aceptación formal de una institución**.

## Cómo lo resuelve

Un solo dispositivo que las dos personas se pasan, con una conversación de
turnos alternados:

- **La persona oyente** habla o escribe. Su frase se convierte en glosas LSB
  —con desambiguación semántica de términos polisémicos en contexto jurídico— y
  un avatar 3D las ejecuta.
- **La persona sorda** responde construyendo su mensaje con tarjetas de glosas,
  opciones y editores de datos, guiada por preguntas según el contexto. El
  sistema compone un mensaje revisable en español y lo reproduce en voz.

La frase de la persona oyente determina el contexto desde el que se le propone
responder, y el contexto que ella confirma vuelve al motor de traducción para
acotar el vocabulario del turno siguiente. Cada turno condiciona al próximo.

### Se responde lo que se preguntó

El enunciado del oyente no solo fija el contexto: también determina **qué
preguntas del flujo guiado se recorren y en qué orden**.

```
Oyente: «¿A qué hora y dónde te robaron?»
   │
   ├─ Respondiendo 1 de 2 · ¿Cuándo pasó?    → NOCHE
   ├─ Respondiendo 2 de 2 · ¿Dónde ocurrió?  → CALLE
   │
   └─ «Quiero denunciar un robo. Ocurrió en la calle por la noche.»
        un audio · un turno · de vuelta a la conversación
```

Dos preguntas en lugar de recorrer el contexto completo. Las zonas y ranuras
detectadas guían el recorrido, mientras que las respuestas condicionales abren
o descartan sus preguntas dependientes.

El mensaje se genera **una sola vez, al final**. Partirlo en uno por
sub-pregunta produciría frases sueltas —«Fue de noche.», «Fue en la calle.»— en
lugar de una respuesta coherente, y obligaría a pasarse el teléfono una vez por
cada dato.

### Trámites documentados

La familia **Trámites** combina un banco guiado con un corpus RAG local. En el
estado actual del repositorio contiene:

- **183 escenarios fuente** documentados;
- **167 recorridos ejecutables** agrupados en 16 áreas institucionales;
- **616 preguntas** de trámite;
- recorridos profundizados con ramificaciones y limpieza automática de
  respuestas que dejan de ser válidas;
- respuestas completas de Sí/No/No sé, detalles de documentos y editores
  opcionales para datos como NUREJ, WebID o número de caso.

El grafo conversacional tiene prioridad cuando reconoce una pregunta segura. El
RAG local entra cuando el grafo no alcanza, conserva la institución o el trámite
del que se venía hablando y puede usar una consulta semántica remota como
respaldo. Ante ambigüedad, abre el selector en vez de inventar una ruta.

Los datos en vivo —por ejemplo, una deuda, el fiscal asignado o la fecha de una
audiencia— no se inventan: la app ayuda a preguntarlos o comunicarlos, pero no
consulta sistemas internos de las instituciones.

## Por qué está construido así

**El motor de generación es determinista.** Las intervenciones guiadas se
redactan desde el mismo banco en Dart y Python. Las rutas históricas pueden usar
Bedrock para refinar una base local, pero el resultado remoto se rechaza si
omite o altera contenido. En una comunicación institucional, cambiar un actor,
una negación o un dato no es una mejora de estilo: es otro mensaje.

**El diccionario vive fuera del código.** Las señas son una lengua viva y
regional; el vocabulario se carga desde una fuente canónica versionada, con un
asset local de respaldo. Las palabras todavía no incorporadas se muestran como
“seña a incorporar” y nunca se presentan como animaciones disponibles.

**Toda entrada se normaliza a una misma representación semántica** antes de
generar cualquier salida. No hay caminos directos de texto a avatar ni de
tarjetas a audio: ambos sentidos comparten núcleo.

**La red no decide si la conversación puede continuar.** El turno de la persona
oyente entra en el hilo y el contexto se deduce localmente. Si la Lambda de
Texto→LSB no responde, un traductor local limitado usa el léxico y las
animaciones empaquetadas; el grafo y el corpus RAG local siguen disponibles.

---

## Los tres módulos

### `conversation` — la conversación

Centro de la aplicación y punto de entrada. Mantiene el agregado `Conversation`:
los turnos alternados de ambas personas, el contexto vigente y el enlace entre
cada respuesta y la pregunta que contesta. Es quien decide, al abrir el flujo de
tarjetas, desde qué contexto se responde.

Presenta cada turno como una burbuja: las de la persona oyente con acceso al
avatar y las ambigüedades que se resolvieron; las de la persona sorda con el
texto generado y su audio.

### `lsb_to_text_audio` — de LSB a texto y voz

Dirección de la persona sorda. Flujo guiado por preguntas: el contexto
situacional se elige entre las familias **Denuncias, Consultas, Trámites y
Preguntas**. Cada recorrido ofrece únicamente las opciones pertinentes y puede
abrir editores de nombre, teléfono, monto, documento u otros datos literales.
Los trámites se agrupan primero por institución para no presentar una lista
plana de más de cien casos.

Con las glosas seleccionadas, el motor semántico local clasifica roles
gramaticales y compone el mensaje. El backend valida el contrato, conserva la
redacción guiada y sintetiza el audio. El resultado se puede escuchar, copiar y
enviar a la conversación.

Es el módulo con mayor carga de procesamiento de lenguaje: la entrada es un
conjunto de glosas sin orden ni morfología y la salida debe ser español bien
formado sin agregar hechos que la persona no confirmó.

### `audio_to_lsb` — de voz y texto a LSB

Dirección de la persona oyente. Captura voz mediante reconocimiento en el
dispositivo, o texto escrito. El backend produce la secuencia de glosas
resolviendo términos polisémicos según el contexto jurídico, y devuelve las
animaciones que el avatar 3D reproduce en orden.

Las glosas sin seña propia se deletrean con dactilología, y las señas
compuestas encadenan varias animaciones bajo una sola glosa. Si la Lambda no
está disponible, entra un traductor local de cobertura más limitada.

---

## Arquitectura

```
Conversation Engine → Semantic Engine / Context Engine → Generadores → UI
```

### Fronteras entre módulos

Los dos módulos de traducción son independientes: **no se conocen entre sí ni
conocen al de conversación**. La única dirección de dependencia permitida es la
del integrador hacia sus partes.

```
conversation ──→ lsb_to_text_audio
     │      ╲──→ audio_to_lsb
     ▼
   core/  ←── los tres dependen solo del núcleo
```

Donde el flujo de tarjetas necesita saber de una conversación en curso —qué
pregunta se está respondiendo, dónde entregar la declaración terminada— la
dependencia está invertida: el núcleo declara los puertos
(`core/domain/services/conversation_bridge.dart`) desactivados por defecto, y el
módulo de conversación los implementa al componer la aplicación en `main.dart`.

Con los puertos desactivados, el flujo de tarjetas funciona como una aplicación
autónoma. La propiedad está verificada en `test/module_boundaries_test.dart`.

### Una sesión por superficie

Los tres módulos comparten el `ProviderScope` raíz, pero no la sesión. Cada
módulo de traducción tiene dos dueños posibles —la conversación, donde responde
a un turno, y su pestaña autónoma, donde es una herramienta suelta— y la regla
que los separa es una sola:

> Los módulos de traducción no guardan nada entre superficies; solo la
> conversación tiene memoria.

El estado se descarta en **cada cruce**, no solo al entrar en una pestaña: de lo
contrario la fuga queda invertida y lo construido como herramienta suelta
reaparece como respuesta de un turno. Quien abre "Tarjetas LSB" o "Voz a LSB"
los encuentra como si nunca los hubiera tocado, y la pregunta del oyente no
enruta un recorrido que allí nadie pidió.

Reabrir el mismo encargo conversacional conserva el borrador; cambiar a otro
encargo solicita confirmación antes de descartarlo. Las superficies autónomas
siguen aisladas para que un mensaje preparado fuera del chat no reaparezca como
respuesta a una pregunta distinta. El historial de la conversación no se toca.

Verificado en `test/module_isolation_test.dart`.

```
lib/
├── main.dart                     punto de entrada y ProviderScope raíz
├── app/                          shell de la aplicación (tema, rutas, sesión)
│   └── screens/                  splash y navegación principal
├── core/                         núcleo compartido, ordenado por capas
│   ├── domain/                   capa de dominio (sin Flutter ni IO)
│   │   ├── conversation/         grafo, rutas y semántica de turnos
│   │   ├── guided/               banco y compositor guiado
│   │   ├── rag/                  corpus y recuperación de trámites
│   │   ├── entities/             Conversation, SemanticMessage, LsbCard…
│   │   ├── repositories/         contratos (translation, audio, lexicon)
│   │   ├── services/             motores, inferencia y puertos invertidos
│   │   ├── session/              propósito y política de la sesión
│   │   └── text/                 normalización de español
│   ├── data/                     capa de datos
│   │   ├── datasources/          HTTP, asset y caché en disco
│   │   ├── models/               DTOs con (de)serialización
│   │   ├── repositories/         implementaciones de los contratos
│   │   └── services/             salida de audio real (Polly/TTS)
│   ├── network/                  validación de endpoints inyectados
│   ├── presentation/             visor 3D y estado de superficie compartidos
│   └── di/                       composition root (injection.dart)
└── features/                     cada feature con domain/data/presentation
    ├── conversation/
    ├── lsb_to_text_audio/
    └── audio_to_lsb/
aws/                              funciones Lambda
docs/architecture/                decisiones de diseño por fase
```

`SemanticMessage` es la representación única: toda entrada se normaliza a ella y
toda salida se genera desde ella.

## Backend

| Lambda | Función |
|---|---|
| `lambda_function.py` | Tarjetas/datos → español y audio; contrato guiado v4, compatibilidad histórica y consulta RAG semántica |
| `lambda_text_to_lsb.py` | Texto en español → glosas LSB con desambiguación semántica |


Detalles de despliegue en [`aws/README.md`](aws/README.md).

## Ejecutar

Los endpoints de AWS no viven en el código: se leen de un archivo `.env`
local (git-ignored) y se inyectan como `--dart-define` en tiempo de
compilación.

```bash
flutter pub get
cp .env.example .env        # y rellena con tus endpoints reales
```

Luego, según tu sistema:

```powershell
# Windows
.\run.ps1                              # dispositivo por defecto
.\run.ps1 -Device emulator-5554        # dispositivo concreto
```

```bash
# Linux / macOS
./run.sh                               # dispositivo por defecto
./run.sh -d emulator-5554              # dispositivo concreto
```

Los scripts leen `.env`, montan un `--dart-define` por línea y llaman a
`flutter run`. Sin endpoints válidos no están disponibles Bedrock, Polly, la
sincronización remota ni el RAG semántico. La app conserva el diccionario, el
grafo, el corpus RAG, el GLB y una traducción Texto→LSB local de respaldo; su
cobertura es menor que la del backend.

Variables disponibles y su comportamiento por defecto se documentan en
[`.env.example`](.env.example).

## Pruebas

```bash
flutter analyze                                          # análisis estático
flutter test                                             # suite completa
flutter test test/qa_conversacion_test.dart              # 35 conversaciones reales
flutter test test/conversation_bidirectional_test.dart   # ciclo conversacional
flutter test test/conversation_routing_exhaustive_test.dart # rutas del grafo
flutter test test/rag_tramites_test.dart                 # RAG → tarjetas → chat
flutter test test/tramites_profundizados_test.dart       # ramas y datos editables
flutter test test/tramites_respuestas_completas_test.dart # respuestas de trámites
flutter test test/conversacion_sin_internet_test.dart    # respaldo local
flutter test test/module_isolation_test.dart             # sesión por superficie
```

Regresiones de seguridad del backend. No las ve `flutter test` —son Python—,
así que tienen job propio en CI:

```bash
python3 -m unittest discover -s aws/tests -v
python3 -m pytest tool/tests -q
python3 tool/build_rag_corpus.py --check
python3 tool/build_question_matrix.py --check
```

El CI ([`.github/workflows/ci.yml`](.github/workflows/ci.yml)) ejecuta el
analizador, la suite Flutter, la cobertura del diccionario y las pruebas de las
Lambdas sobre Python 3.12 y 3.13. Los `--check` de los generadores deben
ejecutarse al modificar sus fuentes canónicas.

Evaluación cuantitativa del motor de generación:

```bash
flutter test test/benchmark/engine_benchmark_test.dart   # motor local
flutter test test/benchmark/engine_benchmark_test.dart \
    --dart-define=BENCHMARK_REMOTE=true                  # compara con Bedrock
```

Resultados y metodología en
[`docs/architecture/evaluacion-motor-semantico.md`](docs/architecture/evaluacion-motor-semantico.md).

## Documentación

| Documento | Contenido |
|---|---|
| [Fase 1](docs/architecture/fase-1-nucleo-conversacional.md) | Núcleo semántico compartido y conversación unificada |
| [Fase 2](docs/architecture/fase-2-diccionario-evolutivo.md) | Diccionario fuera del código, fuente canónica única |
| [Fase 3](docs/architecture/fase-3-propuestas-comunidad.md) | Diseño histórico del ciclo de propuestas; esa UI no está en la superficie actual |
| [Fase 4](docs/architecture/fase-4-contexto-conversacional.md) | Contexto conversacional entre módulos |
| [Aislamiento y fluidez](docs/architecture/aislamiento-superficies-y-fluidez.md) | Sesión por superficie y camino crítico del turno |
| [Evaluación](docs/architecture/evaluacion-motor-semantico.md) | Medición del motor semántico |
| [Contexto maestro](docs/CONTEXTO_MAESTRO_PARA_IA.md) | Contratos, límites y fuentes canónicas del proyecto |
| [Flujos de conversación](docs/FLUJOS_CONVERSACION_2026-10-12.md) | 35 conversaciones reproducibles, turno por turno |
| [RAG institucional](docs/architecture/rag-conocimiento-institucional.md) | Recuperación local/remota y reglas de seguridad |
| [Corpus de trámites](docs/negocio/rag/README.md) | Cómo ampliar, validar y regenerar escenarios |

## Fuentes generadas

No se editan manualmente `lib/core/domain/rag/tramites_data.g.dart`,
`assets/rag/escenarios_cbba.json` ni `aws/question_bank.json`. Los escenarios y
correcciones se modifican en `docs/negocio/rag/` y se regeneran con las
herramientas de `tool/`; los comandos `--check` comprueban que los artefactos
empaquetados estén al día.
