# OPENSOUL — DOCUMENTACIÓN TÉCNICA Y ARQUITECTURA (V1.0)
> Documentación elaborada para el equipo de desarrollo, miembros de tribunal de tesis e ingenieros que realicen el onboarding al núcleo de código de OpenSoul.

## 1. INTRODUCCIÓN GENERAL DEL SISTEMA
**OpenSoul** es una aplicación móvil desarrollada en **Flutter** con un alto enfoque en el dominio "Jurídico y Administrativo". Su objetivo principal es cerrar la brecha de comunicación para la comunidad sorda en escenarios críticos (comisarías, denuncias, hospitales, juzgados).

El sistema se fundamenta conceptualmente y funciona de manera **bidireccional** mediante módulos:
- **`lsb_to_text_audio` (Eje principal desarrollado)**: Convierte selecciones discretas de señales de Lengua de Señas Boliviana (LSB) estructuradas en tarjetas, hacia voz natural, texto en español castizo, y retroalimentación interactiva a través de un **Avatar 3D secuencial**.
- **`audio_to_lsb`**: Captura señales de voz y ejecuta el proceso a la inversa para devolver información estructurada.

---

## 2. ARQUITECTURA DE SOFTWARE (FRONTEND)
El Frontend aplica rigurosamente **Clean Architecture** estructurada por Capas (Layers). Se utiliza **Riverpod** como inyector de dependencias y manejador reactivo del estado de los widgets.

### 2.1. Estructura de Directorios Clave
Toda la lógica base se implementa bajo `lib/features/lsb_to_text_audio/`:
* **`/domain` (Dominio)**: Centro cognitivo de la app. Es agnóstico a Internet y UI.
  * `entities/lsb_card.dart`: Modelo principal. Define atributos clave de una tarjeta como `gloss` (la glosa lingüística), `semanticIcon` para UI y `animationKey` utilizado para enlazar el modelo 3D.
  * `repositories/translation_repository.dart`: Define el contrato para el esquema de `TranslationResult`, dictando que todo retorno debe indicar las diferencias de traducción originadas por algoritmos o I.A (`baseSentence`, `generatedText`, `glossSequence`).
* **`/data` (Datos)**: Capa de operaciones tangibles.
  * `datasources/local_cards_datasource.dart`: Contiene una "hardcoded database" de **62 tarjetas especializadas** de marco jurídico en 9 categorías (Identificación, Agresores, Delitos, etc).
  * `datasources/remote_translation_datasource.dart`: Realiza la invocación real usando verbos HTTP a la API Gateway de AWS y encapsula el código de retorno.
* **`/presentation` (Presentación UI)**:
  * Controladores (`translation_controller.dart`): Manejan estados `AsyncLoading/Data`.
  * La interfaz `home_screen.dart`: Diseño visual usando la paleta oscura "Institucional OpenSoul" y un embudo de Layout lógico -> Constructor de Frases (`SentenceBuilder`) -> Grilla (`CardGrid`).

---

## 3. ARQUITECTURA EN LA NUBE (BACKEND SERVERLESS)
La pesada carga algorítmica no gasta ciclos de la batería del dispositivo móvil, vive en Amazon Web Services (AWS). Operamos una arquitectura orientada a Eventos (`API Gateway -> AWS Lambda`).

### 3.1. API Gateway y Conexiones
Un "HTTP API" enruta peticiones hacia Lambda. Está configurado para soportar estrictamente políticas **CORS** devolviendo pre-flight configurations (`OPTIONS`) que permiten ejecución transparente desde compilaciones Flutter Web o Móvil.

### 3.2. AWS Lambda (`aws/lambda_function.py`)
El motor, programado en Python 3.10+, es un **orquestador de pasos híbridos**. Cada paso pasa el control al siguiente solo si es seguro.

#### FASE A: El "Motor Inteligente Propio" Académico
Para garantizar un estándar académico determinista que no cause "alucinaciones I.A" en un escenario sensible de denuncias legales, se construyó un Análisis Léxico-Gramatical Reglado:
1. **GLOSS_LEXICON**: Analiza y rastrea estructuras jerárquicas como Verbos (`DENUNCIAR`), Sujetos, Tiempo, y Delitos. 
2. Construye una topología de oración conocida como **"Representación Intermedia (IR)"**.
3. **Mapeo a Reglas**: Un sistema de plantillas `generate_base_sentence()` toma el `IR` y redacta forzosamente una frase blindada llamada **`baseSentence`**. Ej: "*Deseo hacer una denuncia formal por reporte de Robo*".

#### FASE B: Integración Híbrida Inteligencia Artificial (I.A)
Solo sí y solo si se activa el flag lógico, y existe servicio:
Se invoca nativamente vía `boto3` a **Amazon Bedrock**, pasándole contexto pregrabado y pidiendo refinar la `baseSentence` para naturalizarla al oído humano (`generatedText`). El sistema es tolerante a caídas (`Fallback tolerance`): Si la IA se rompe, revierte a `baseSentence` sin errores al usuario.

#### FASE C: Sintetización Multimodal (Speech & Storage)
1. **Amazon Polly:** Usa Modelos Neurales de Lenguaje Biológico (`Voz Lupe`) convirtiendo la oración elaborada en pulsos bytes puros `audio_bytes`.
2. **Amazon S3:** Deposita en un Bucket (`opensoul-lsb-audio-dev`).
3. Para proteger las rutas S3 y que no estén "Públicas al Mundo", Lamba emite automáticamente y descifra hacia Flutter una **Presigned URL** que es una llave dinámica segura criptográficamente de acceso temporal.

---

## 4. SISTEMA 3D Y AVATAR (`AvatarSignViewer`)
El corazón audiovisual para retroalimentación. Reemplaza el uso de enormes bases de datos con megabytes en archivos `.mp4`, migrando a la utilización en render de WebGL en tiempo real acoplado a Flutter mediante el paquete `model_viewer_plus`.

### La Secuencia del Avatar 
* La función de lambda retorna adicionalmente la propiedad JSON `glossSequence` evaluando exactamente las palabras capturadas en tiempo de máquina.
* `lib/features/lsb_to_text_audio/presentation/widgets/avatar_sign_viewer.dart` captura esta orden y descarga dentro del runtime de UI el documento `modelSrc` formato `.glb` o `.gltf` (Malla geométrica en 3D).
* Lee el mapa `_animationMap` internamente y localiza dentro de la línea geométrica del robot la transición (`animation-name=""`). Logrando secuencialmente hilar una seña de "HOMBRE" seguida de "ROBAR" de modo visual gracias a un cronómetro lógico dictado cruzando las animaciones en Blender con las de Dart.

---
**Fin del Documento de Arquitectura.**
 *(Última actualización: Hito Fases LSB Jurídicas. Código versionado).*
