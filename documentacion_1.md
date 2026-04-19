# OpenSoul — Guía Técnica Completa (V3 Trámites Ciudadanos & 3D)

> **Proyecto:** OpenSoul (LSB Ciudadano App)
> **Stack:** Flutter (Dart) + Riverpod + AWS (Lambda, API Gateway, Bedrock, Polly, S3 con Presigned URLs) + model_viewer_plus (3D/GLB)
> **Arquitectura:** Clean Architecture con Inyección de Dependencias vía Riverpod
> **Contexto Principal:** Herramienta enfocada en trámites y consultas ciudadanas en entidades públicas bolivianas.

---

## 1. Vista General del Proyecto

### ¿Qué problema resuelve?

Las personas sordas en Bolivia enfrentan enormes barreras de comunicación en contextos de trámites y consultas ciudadanas en entidades públicas. OpenSoul actúa como un puente bidireccional, orientado a la precisión y formalidad administrativa:

- **LSB → Texto/Audio/Avatar 3D:** Una persona sorda selecciona tarjetas ciudadanas (como "TRAMITAR", "CARNET", "SEGIP"). La app envía estas glosas a AWS. Para evitar alucinaciones, un **Motor Híbrido Propio** procesa directamente las reglas y crea una frase inmutable. Luego, una IA generativa (Bedrock) configurada con **Few-shot Prompting** pule la gramática. Finalmente, Polly genera un audio MP3 y el Frontend dispara un **Avatar 3D secuencial** reproduciendo la frase en señas visualmente.
- **Audio → LSB:** Una persona oyente graba un mensaje de voz, el backend devuelve las glosas LSB correspondientes y el avatar las interpreta.

### ¿Cuál es el flujo principal?

```text
┌──────────────────────────────────────────────────────────────────┐
│             FLUJO MULTIMODAL LSB → TEXTO/AUDIO/3D               │
│                                                                  │
│  Usuario selecciona secuencia LSB ("YO", "TRAMITAR", "CARNET")  │
│  → Presiona "TRADUCIR Y GENERAR"                                │
│  → DataSource hace POST HTTP a AWS API Gateway                  │
│  → Lambda extrae Roles Temáticos (Sujeto, Verbo, Documento)     │
│  → Lambda construye 'baseSentence' estricta                     │
│  → Bedrock pule la gramática a 'generatedText' (Few-shot)       │
│  → S3 genera un MP3 seguro tras llave (Presigned URL)           │
│  → Flutter recibe JSON con todos los datos y la 'glossSequence' │
│  → UI muestra Textos (Crudo vs IA) + Copia Portapapeles         │
│  → AvatarSignViewer (3D) ejecuta animaciones secuenciales       │
└──────────────────────────────────────────────────────────────────┘
```

---

## 2. Estructura de Directorios Anotada

```text
OpenSoul/
├── aws/                              # Código backend serverless (AWS Lambda)
│   └── lambda_function.py            # Lambda híbrida REAL (Motor Python + Bedrock + S3 URLS)
│
├── lib/                              # Código fuente Flutter
│   ├── main.dart                     # Punto de entrada
│   ├── app/                          # Configuración global
│   │   ├── app.dart                  # Raíz MaterialApp
│   │   ├── router.dart               # Rutas GoRouter
│   │   └── theme.dart                # Tema "Dark Institucional Ciudadano"
│   │
│   └── features/
│       ├── lsb_to_text_audio/        # MÓDULO PRINCIPAL (Clean Architecture)
│       │   ├── domain/               
│       │   │   ├── entities/lsb_card.dart                  # Entidad con semanticIcon y animationKey
│       │   │   ├── repositories/translation_repository.dart# Contrato con TranslationResult ampliado
│       │   │   └── usecases/translate_cards_usecase.dart   
│       │   │
│       │   ├── data/                 
│       │   │   ├── datasources/local_cards_datasource.dart # Base de datos local: ~67 Tarjetas ciudadanas
│       │   │   └── datasources/remote_translation_datasource.dart # HTTP Client a AWS API Gateway
│       │   │
│       │   └── presentation/         
│       │       ├── controllers/translation_controller.dart #AsyncNotifier
│       │       ├── screens/home_screen.dart                # Pantalla principal
│       │       └── widgets/
│       │           ├── card_grid.dart                      # Grilla responsiva 3 columnas
│       │           ├── category_filter.dart                # Chips de 8 categorías ciudadanas
│       │           ├── sentence_builder.dart               # Barra de secuencias numeradas
│       │           └── avatar_sign_viewer.dart             # El motor visual 3D usando GLB
│       │
│       └── audio_to_lsb/            # Módulo de Audio a Señas (proyecto complementario)
│
└── pubspec.yaml                      # Dependencias (model_viewer_plus, audioplayers, etc)
```

---

## 3. Recorrido Archivo por Archivo

### 3.1 Punto de Entrada y App

#### `main.dart` y `app.dart`
- **Propósito:** Inicia la app envolviéndola en el `ProviderScope` global de Riverpod y usa `MaterialApp.router`.
- **Decisión:** Imprescindible para el ruteo de GoRouter y para que todos los estados globales sobrevivan cambios de pantalla.

#### `theme.dart`
- **Propósito:** Configuración central visual de tipo "Dark Institucional". Colores basados en tonalidades azules de fondo (`#0D1117`) y dorados (`#FFD700`) como acentos para dar sensación de institucionalidad pública a una app de uso ciudadano.

### 3.2 Módulo Principal: `lsb_to_text_audio`

#### CAPA DOMAIN (Reglas Puras)

##### `entities/lsb_card.dart`
- **Qué hace:** Define la tarjeta. Sumado al texto, se añadieron variables para el 3D y la UI: `semanticIcon` (Material Icon name) y `animationKey` (Nombre de la animación guardada en Blender).

##### `repositories/translation_repository.dart`
- **Qué hace:** Tiene el Contrato de inyección. Su clase estrella es `TranslationResult`, que ahora obliga a recibir:
  - `baseSentence` (El crudo, sin mentiras de IA).
  - `generatedText` (El procesado por Bedrock).
  - `glossSequence` (El orden de glosas validadas por el Backend para el reproductor 3D).

#### CAPA DATA (El Mundo Real)

##### `local_cards_datasource.dart`
- **Qué hace:** Actúa como la memoria RAM de tarjetas en 8 Categorías Ciudadanas (Identificación, Acciones, Trámites, Documentos, Tiempo, Instituciones, Servicios, Estado/Urgencia). Contiene **~67 tarjetas especializadas** en trámites y consultas en entidades públicas.

##### `remote_translation_datasource.dart`
- **Qué hace:** Solo un objetivo: Hacer `HTTP POST`. Envía `{'context': 'ciudadano', 'cards': [...]}` hacia el API Gateway. Extrae la compleja respuesta anidada del JSON. Este archivo es el límite del aislamiento de la red.

#### CAPA PRESENTATION (Vistas y Estados)

##### `screens/home_screen.dart`
- **Qué hace:** Pantalla orquestadora principal.
- **La gran mejora (Fix de Layout):** Para evitar desbordamientos de RenderFlex en móviles pequeños, todo el cuerpo está envuelto en un `SingleChildScrollView`.
- **El Panel Multimodal (`_ResultPanel`):** Container que solo aparece al haber resultados. Contrapone visualmente al usuario la `baseSentence` vs `generatedText` demostrando transparencia IA, e integra el Visor 3D y el botón Copiar Portapapeles (Clipboard).

##### `widgets/avatar_sign_viewer.dart` (La Magia 3D)
- **Qué hace:** Usando el framework WebGL/SceneViewer nativo invocado por `model_viewer_plus`, renderiza modelos paramétricos `.glb`.
- **Su lógica:** Mantiene un diccionario local `_animationMap` en donde, por ejemplo, asocia la palabra `'TRAMITAR'` con el bloque de animación `'Pointing'`. El widget avanza a la siguiente animación cada poco tiempo guiado por una barra de progreso que lee del Array `glossSequence`.

---

### 3.3 Backend AWS en Python (`aws/lambda_function.py`)

Todo el cerebro vive agrupado aquí por practicidad serverless:

#### A. Lexicón de Glosas y Motor Propio
- `GLOSS_LEXICON` mapea glosas LSB a roles semánticos: SUJETO, VERBO, DOCUMENTO, TRAMITE, INSTITUCION, SERVICIO, TIEMPO, DESCRIPTOR, URGENCIA, ESTADO.
- `generate_base_sentence()` coge estos tokens. Nunca "adivina", rellena plantillas duras de Python. Esto asegura que nadie reciba un mensaje incorrecto a causa de una alucinación de la IA.

#### B. Bedrock con Few-shot Prompting
El refinamiento usa **Few-shot Prompting** con 3 ejemplos de pares base→refinada para guiar la IA. Si falla, el bloque Try-Catch en Lambda garantiza un retorno de 200 usando la frase base.

#### C. URLs Prefirmadas en Amazon S3
Para evitar dar al mundo acceso libre a los buckets, la Lambda emite una **Presigned URL**.
```python
presigned_url = s3_client.generate_presigned_url(
    'get_object', Params={'Bucket': S3_BUCKET, 'Key': s3_key}, ExpiresIn=3600
)
```
Ese MP3 se encripta y tiene muerte programada en 1 hora.

---

## 4. Flujo Exacto del 3D y la Interfaz

```text
1. Usuario elige: ["YO", "TRAMITAR", "CARNET"]
2. Backend devuelve: glossSequence = [{"gloss": "YO"}, {"gloss": "TRAMITAR"}, {"gloss": "CARNET"}]
3. En avatar_sign_viewer.dart:
    - Index arranca en 0 (glosa "YO"). Buscamos en _animationMap -> "Wave".
    - <model-viewer> activa animation-name="Wave".
4. Tras 2,000 milisegundos:
    - Index avanza a 1 (glosa "TRAMITAR"). Buscamos -> "Pointing".
    - El widget hace crossfade mágico y comienza "Pointing".
5. Fin del array, el Avatar vuelve al estado 'Idle'.
```

---

## 5. Patrones y Convenciones Respetadas

### Principio de Responsabilidad Única
* Si falla el renderizado 3D, se revisa `avatar_sign_viewer.dart`.
* Si falla la conexión, se revisa `remote_translation_datasource.dart`.
* Si el texto se narra mal, se edita la gramática pura en el AWS Lambda en la función `generate_base_sentence()`.

### Gestión de Estados con Riverpod 3.x
* Ya no hay setState() esparcidos; La dependencia fluye: `CardGrid` reacciona a `cardsByCategoryProvider` observando a `categoryFilter`.

---

## 6. Procedimientos Futuros para Modeladores 3D

Para una integración completa en la Tesis utilizando un personaje creado en **Blender** u otro software CGI:
1. Diseñar el personaje y añadir en el Action Editor (Blender NLA) las animaciones separadas nombrando cada clip claramente por la LSB correspondiente, y exportar al disco un único documento `.GLB`.
2. Subirlo al AWS S3 (Bucket).
3. Entrar a `lib/features/lsb_to_text_audio/presentation/widgets/avatar_sign_viewer.dart`.
4. Editar la variable global `modelSrc` con el link del bucket de tu `.glb`.
5. Editar la variable `_animationMap` uniendo en código duro tu glosa con el clip de Blender (`'TRAMITAR' : 'NombreDeAnimacionEnBlender'`).

Todo el código de base e interpolación lo hará de forma automática en todas las plataformas gracias al motor implementado.
