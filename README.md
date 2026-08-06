# OpenSoul — LSB Ciudadano

Aplicación de accesibilidad que permite a una persona sorda y a una persona
oyente **mantener una conversación** en trámites y situaciones reales ante
entidades públicas bolivianas: denuncias policiales, defensoría, SEGIP,
hospitales, alcaldía y fiscalía.

Stack: Flutter + Riverpod + Clean Architecture + AWS (Lambda, API Gateway,
Bedrock, Polly, DynamoDB, S3). El paquete Dart se llama `lsb_legal_app`.

---

## Qué problema resuelve

En Bolivia, una persona sorda que necesita presentar una denuncia o hacer un
trámite depende de que haya un intérprete de Lengua de Señas Boliviana
disponible. Casi nunca lo hay. El resultado es que la persona escribe en un
papel, se hace entender a medias, o desiste del trámite.

Escribir en español tampoco es una solución equivalente: para muchas personas
sordas el español es una segunda lengua, con una gramática distinta de la LSB, y
un texto escrito con dificultad puede restarle credibilidad a una denuncia
legítima ante un funcionario.

OpenSoul sustituye al intérprete ausente en ambos sentidos de la conversación,
sin exigirle a la persona sorda que escriba en español.

## Cómo lo resuelve

Un solo dispositivo que las dos personas se pasan, con una conversación de
turnos alternados:

- **La persona oyente** habla o escribe. Su frase se convierte en glosas LSB
  —con desambiguación semántica de términos polisémicos en contexto jurídico— y
  un avatar 3D las ejecuta.
- **La persona sorda** responde construyendo su mensaje con tarjetas de glosas,
  guiada por preguntas según el contexto. El sistema redacta una declaración en
  español formal y la reproduce en voz.

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

Dos preguntas en lugar de las nueve del contexto. Las zonas detectadas guían el
recorrido pero no lo encierran: agotadas, el resto del árbol sigue disponible
por si la persona quiere añadir algo que no le preguntaron.

La declaración se genera **una sola vez, al final**. Partirla en una por
sub-pregunta produciría frases sueltas —«Fue de noche.», «Fue en la calle.»— en
lugar de una oración con valor documental, y obligaría a pasarse el teléfono una
vez por cada dato.

## Por qué está construido así

**El motor de generación es propio, y la IA solo refina.** Un modelo de lenguaje
redacta mejor, pero omite contenido: en la evaluación del corpus, generando por
su cuenta representa el 58,3 % de las glosas declaradas frente al 100 % del
motor de reglas. En una declaración destinada a una institución pública, omitir
que se pidió ayuda o que intervino la policía no es una redacción más elegante:
es otra declaración. Por eso el motor local produce siempre la oración base, el
refinamiento remoto se descarta cuando pierde contenido, y la app funciona
aunque el backend no responda.

**El diccionario vive fuera del código.** Las señas son una lengua viva y
regional; el vocabulario se sirve desde una fuente canónica versionada con
sincronización remota, y la comunidad puede proponer señas nuevas desde la app.

**Toda entrada se normaliza a una misma representación semántica** antes de
generar cualquier salida. No hay caminos directos de texto a avatar ni de
tarjetas a audio: ambos sentidos comparten núcleo.

**Un enunciado vale desde que se dice, no desde que el backend contesta.** El
turno de la persona oyente entra en la conversación de inmediato y el contexto
se deduce en local, así que la persona sorda puede abrir las tarjetas y empezar
a responder mientras la traducción todavía viaja; las señas se incorporan al
mismo turno cuando llegan. Antes ese ida y vuelta era tiempo muerto en el centro
de la conversación. Si el backend no responde, el turno se queda y se contesta
igual.

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
situacional (denuncia de robo, violencia, accidente, testigo, orientación)
define un árbol de zonas semánticas, y cada zona ofrece las tarjetas
pertinentes.

Con las glosas seleccionadas, el motor semántico local clasifica roles
gramaticales y compone la declaración; el backend la refina y sintetiza el
audio. El resultado se puede escuchar, copiar y enviar a la conversación.

Es el módulo con mayor carga de procesamiento de lenguaje: la entrada es un
conjunto de glosas sin orden ni morfología y la salida debe ser español bien
formado con valor documental.

### `audio_to_lsb` — de voz y texto a LSB

Dirección de la persona oyente. Captura voz mediante reconocimiento en el
dispositivo, o texto escrito. El backend produce la secuencia de glosas
resolviendo términos polisémicos según el contexto jurídico, y devuelve las
animaciones que el avatar 3D reproduce en orden.

Las glosas sin seña propia se deletrean con dactilología, y las señas
compuestas encadenan varias animaciones bajo una sola glosa.

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
(`core/domain/ports/conversation_bridge.dart`) desactivados por defecto, y el
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

El precio, asumido: salir de la conversación a una pestaña autónoma descarta una
respuesta a medio construir. Es preferible a que reaparezca donde no
corresponde — una declaración que se cuela en otro contexto no es un
inconveniente, es falsa. El historial de la conversación nunca se toca.

Verificado en `test/module_isolation_test.dart`.

```
lib/
├── core/
│   ├── domain/entities/     SemanticMessage, Conversation, LsbCard…
│   ├── engines/
│   │   ├── conversation_engine/   orquesta ambos sentidos
│   │   ├── semantic_engine/       LocalSentenceAssembler (glosas → español)
│   │   └── context_engine/        catálogo, navegación, inferencia de
│   │                              contexto y de preguntas
│   ├── generators/          audio (Polly/TTS) y avatar 3D
│   ├── dictionary/          diccionario evolutivo offline-first
│   ├── data/                datasources y repositorios remotos
│   └── di/                  composition root compartido
├── features/
│   ├── conversation/
│   ├── lsb_to_text_audio/
│   ├── audio_to_lsb/
│   └── dictionary_proposals/
aws/                         funciones Lambda
docs/architecture/           decisiones de diseño por fase
```

`SemanticMessage` es la representación única: toda entrada se normaliza a ella y
toda salida se genera desde ella.

## Backend

| Lambda | Función |
|---|---|
| `lambda_function.py` | Glosas LSB → declaración en español (motor de reglas + Bedrock) + audio con Polly |
| `lambda_text_to_lsb.py` | Texto en español → glosas LSB con desambiguación semántica |
| `lambda_dictionary.py` | Diccionario evolutivo sobre DynamoDB: consulta y propuestas |
| `seed_dictionary.py` | Siembra la tabla desde el JSON canónico del repositorio |

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
`flutter run`. Sin `.env` la app compila pero las traducciones remotas
fallan, el diccionario cae al asset empaquetado (modo offline) y las
animaciones 3D caen al placeholder de texto.

Variables disponibles y su comportamiento por defecto se documentan en
[`.env.example`](.env.example).

## Pruebas

```bash
flutter test                                             # suite completa
flutter test test/local_sentence_assembler_test.dart     # motor semántico
flutter test test/conversation_bidirectional_test.dart   # ciclo conversacional
flutter test test/context_inference_engine_test.dart     # inferencia de contexto
flutter test test/zone_inference_engine_test.dart        # inferencia de preguntas
flutter test test/composite_sign_test.dart               # señas compuestas
flutter test test/module_boundaries_test.dart            # fronteras entre módulos
flutter test test/module_isolation_test.dart             # sesión por superficie
flutter test test/conversation_fluidity_test.dart        # camino crítico del turno
```

Regresiones de seguridad del backend. No las ve `flutter test` —son Python—,
así que tienen job propio en CI:

```bash
python3 -m unittest discover -s aws/tests -v
```

Todo lo anterior se ejecuta en cada push y pull request
([`.github/workflows/ci.yml`](.github/workflows/ci.yml)): analizador, suite de
Dart, cobertura del diccionario y las Lambdas sobre Python 3.12 y 3.13.

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
| [Fase 3](docs/architecture/fase-3-propuestas-comunidad.md) | Propuestas de señas desde la aplicación |
| [Fase 4](docs/architecture/fase-4-contexto-conversacional.md) | Contexto conversacional entre módulos |
| [Aislamiento y fluidez](docs/architecture/aislamiento-superficies-y-fluidez.md) | Sesión por superficie y camino crítico del turno |
| [Evaluación](docs/architecture/evaluacion-motor-semantico.md) | Medición del motor semántico |
