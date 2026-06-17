# OpenSoul — LSB Ciudadano

App de accesibilidad para **personas sordas en Bolivia**, orientada a trámites y
situaciones reales en entidades públicas (denuncias, defensoría, SEGIP, hospital,
alcaldía, fiscalía…). Es un puente bidireccional entre una persona sorda y un
funcionario oyente.

> Stack: **Flutter + Riverpod + Clean Architecture + AWS** (Lambda, API Gateway,
> Bedrock, Polly, S3). El paquete Dart se llama `lsb_legal_app`.

## Módulos

- **`lsb_to_text_audio`** — *(este repositorio, mi parte)*. El usuario sordo
  selecciona tarjetas con glosas LSB; el sistema arma una oración en español
  formal y genera audio.
- **`audio_to_lsb`** — *(módulo del compañero)*. Voz/texto del funcionario → glosas LSB.

## Arquitectura híbrida (módulo `lsb_to_text_audio`)

Cada traducción se resuelve con dos motores y degrada con elegancia:

1. **Motor semántico local** (`LocalSentenceAssembler`): clasifica las glosas por
   rol gramatical y compone una oración fiel. Funciona **offline** y garantiza
   siempre una salida (cobertura total de las glosas seleccionadas).
2. **Backend AWS** (`aws/lambda_function.py`): motor de reglas propio + refinamiento
   con Bedrock + audio con Polly (S3). Ver contrato en [`docs/API_CONTRACT.md`](docs/API_CONTRACT.md).

Si el backend cae, agota el timeout (12 s) o devuelve un texto *degenerado* que
pierde glosas, la app usa el motor local + el TTS del dispositivo. El usuario
**siempre** obtiene texto + audio; un chip indica el origen (IA remota vs motor local).

```
Glosas → [Motor local: baseSentence]  ┐
       → [Backend AWS: generatedText] ┘→ merge (descarta degenerado) → texto + audio
```

## Estructura

```
lib/features/lsb_to_text_audio/
├── domain/        entidades, repositorios (contratos), usecases, motor semántico
├── data/          datasources (remoto HTTP, catálogo local), repos, services (audio)
└── presentation/  providers (Riverpod), controllers, screens, widgets
aws/               funciones Lambda (ver aws/README.md)
docs/              contrato API y tablero Kanban del módulo
```

## Ejecutar

```bash
flutter pub get
flutter run
# Endpoint configurable sin recompilar la lógica:
flutter run --dart-define=LSB_API_URL=https://mi-endpoint/translate
```

## Pruebas

```bash
flutter test                                  # toda la suite
flutter test test/local_sentence_assembler_test.dart   # motor semántico
flutter test test/translation_controller_test.dart     # lógica híbrida/fallback
flutter test test/remote_translation_datasource_test.dart  # contrato HTTP
```
