# Fase 1 — Núcleo semántico y conversación unificada

**Fecha:** 2026-07-22 · **Rama:** Update1

## Objetivo

Eliminar la separación entre los módulos "LSB → Texto/Audio" y "Texto/Audio → Avatar" y convertir OpenSoul en un único sistema de comunicación bidireccional centrado en la entidad `Conversation`, según la arquitectura objetivo:

```
Conversation Engine → Semantic Engine / Context Engine → Generators (texto, audio, avatar) → Conversation UI
```

## Problemas que corrige esta fase

| # | Problema | Corrección |
|---|---|---|
| P1 | No existía representación semántica compartida: cada módulo tenía su propio modelo (`TranslationResult` vs `LsbTranslation`) | Nueva entidad central `SemanticMessage`: toda entrada se normaliza a ella y toda salida se genera desde ella |
| P4 | La lógica híbrida (fusión motor local/Bedrock, detección de degeneración, fallback) vivía en la capa de presentación (`TranslationController`) | Extraída al `ConversationEngine` en `core/engines/conversation_engine/`; el controller quedó como orquestador de UI y reproducción |
| P5 | No existía `Conversation`: dos pantallas hermanas sin estado compartido | Agregado raíz `Conversation` (turnos inmutables, contexto activo) + pantalla de conversación como centro de la app |
| P2 (parcial) | La resolución de URLs de animación (S3 + limpieza de tildes) estaba hardcodeada en el datasource | Extraída a `AnimationUrlResolver` en `core/generators/avatar_generator/`, con base URL configurable por `--dart-define` |
| P6 | Endpoint del módulo B hardcodeado; dos `http.Client` duplicados; bug de interpolación (`\${...}` literal) en mensajes de error del datasource | Endpoint configurable (`LSB_TEXT_API_URL`), un solo `httpClientProvider` en `core/di`, interpolación corregida |

## Nueva estructura

```
lib/core/
├── domain/
│   ├── entities/        semantic_message, conversation, lsb_card,
│   │                    semantic_context, semantic_zone, lsb_translation
│   └── repositories/    translation_repository, audio_translation_repository
├── engines/
│   ├── conversation_engine/   ConversationEngine (nuevo)
│   ├── semantic_engine/       LocalSentenceAssembler (promovido)
│   └── context_engine/        SemanticNavigationEngine (promovido)
├── generators/
│   ├── audio_generator/       AudioOutput (promovido)
│   └── avatar_generator/      Avatar3DViewer (promovido), AnimationUrlResolver (nuevo)
├── data/                datasources y repositorios remotos de ambas direcciones
└── di/                  core_providers.dart — composition root compartido

lib/features/
├── conversation/        NUEVO: pantalla central, provider, burbujas, hoja de avatar
├── lsb_to_text_audio/   flujo guiado de tarjetas (ahora adaptador de entrada sorda)
└── audio_to_lsb/        entrada de voz/texto (ahora adaptador de entrada oyente)
```

Los archivos se movieron con `git mv` (historial preservado). Los providers antiguos se re-exportan desde sus ubicaciones históricas para no romper consumidores ni tests (`translationRepositoryProvider`, `audioOutputProvider`, etc. siguen siendo los mismos objetos).

## Decisiones de diseño

1. **`Conversation` como agregado raíz DDD, no pipeline lineal.** El Context Engine es colaborador del Semantic Engine (el contexto alimenta la interpretación), no una etapa posterior.
2. **Modo "un dispositivo compartido"** para la v1: el teléfono se pasa entre ambas personas. El dominio (`SpeakerRole`, `Participant` implícito en turnos) queda preparado para multi-dispositivo.
3. **Refactor, no reescritura.** `LocalSentenceAssembler` (1.179 líneas) y `SemanticNavigationEngine` se promovieron intactos; los flujos existentes de tarjetas y voz siguen funcionando y ahora alimentan la conversación.
4. **El `ConversationEngine` nunca lanza en el sentido sordo→oyente** (degrada al motor local + TTS, como antes); sí lanza en oyente→sordo porque aún no existe generación local de señas (llegará con el diccionario offline de la Fase 2).
5. **Los turnos sordos entran a la conversación explícitamente** ("Enviar a la conversación" en la pantalla de resultado), evitando duplicaciones por rebuilds y conservando la pantalla clásica de declaración para uso institucional.

## Flujo bidireccional resultante

1. Persona oyente (pestaña Conversación): habla o escribe → `ConversationEngine.composeHearingTurn` → turno con glosas + animaciones → burbuja con "Ver en avatar".
2. Persona sorda: "Responder con tarjetas LSB" → flujo guiado existente → declaración híbrida → "Enviar a la conversación" → turno con texto + audio → burbuja con "Escuchar".

## Deuda y siguientes fases

- **Fase 2 — Backend unificado y diccionario:** un solo contrato API semántico; lexicón fuera del código (DynamoDB); `local_cards_datasource` (563 líneas Dart) y los léxicos duplicados de los lambdas se convierten en `LexiconRepository` (`core/dictionary`). Las entidades `LsbCard`/`SemanticContext` evolucionan a `LexiconEntry` con `status: official|community|pending`.
- **Fase 3 — Diccionario evolutivo:** propuestas Pending desde la app, repositorio Community.
- **Fase 4 — Portal web de validación + IA asistente** (duplicados, sugerencias, prioridad; nunca aprueba automáticamente).
- Pendiente menor: las pestañas "Tarjetas LSB" y "Voz a LSB" se retirarán cuando la conversación absorba ambos flujos por completo; `TextInputWidget` aún actualiza el controller legado durante el dictado (inofensivo, se limpiará al retirar la pantalla clásica).

## Verificación

- `flutter analyze`: 0 errores, 0 warnings.
- `flutter test`: 61/61 en verde. El smoke test se actualizó: tras el splash se aterriza en la Conversación (pestaña por defecto); `IndexedStack` es lazy, por lo que las demás pestañas se construyen al visitarlas.
