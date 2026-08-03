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

```
lib/
├── core/
│   ├── domain/entities/     SemanticMessage, Conversation, LsbCard…
│   ├── engines/
│   │   ├── conversation_engine/   orquesta ambos sentidos
│   │   ├── semantic_engine/       LocalSentenceAssembler (glosas → español)
│   │   └── context_engine/        catálogo, navegación e inferencia de contexto
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

```bash
flutter pub get
flutter run
```

Endpoints y recursos configurables sin tocar código:

```bash
flutter run \
  --dart-define=LSB_API_URL=https://…/translate \
  --dart-define=LSB_TEXT_API_URL=https://…/OpenSoul-TextToLSB \
  --dart-define=LSB_DICTIONARY_API_URL=https://…/dictionary \
  --dart-define=LSB_ANIMATIONS_BASE_URL=https://…/
```

Sin `LSB_DICTIONARY_API_URL` la aplicación funciona con el diccionario
empaquetado, en modo totalmente local.

## Pruebas

```bash
flutter test                                             # suite completa
flutter test test/local_sentence_assembler_test.dart     # motor semántico
flutter test test/conversation_bidirectional_test.dart   # ciclo conversacional
flutter test test/context_inference_engine_test.dart     # inferencia de contexto
flutter test test/composite_sign_test.dart               # señas compuestas
```

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
| [Evaluación](docs/architecture/evaluacion-motor-semantico.md) | Medición del motor semántico |
