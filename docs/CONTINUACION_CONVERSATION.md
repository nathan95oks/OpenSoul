# Continuación — Conversation ↔ LSB (handoff)

Estado a 2026-09-26. Documento de trabajo **no commiteado**. Úsalo para continuar sobre el mismo working tree.

## A. Base
- Repo: `C:\Users\LENOVO\OpenSoul\OpenSoul`, rama `main`, HEAD `3f25152` ("Actualizando a Gramatica LSB").
- Hay **muchos cambios sin commitear** (27 archivos modificados + archivos nuevos). No hacer reset/rebase/revert/checkout de archivos. Inspeccionar primero con `git status`, `git diff --stat`.
- `semantic_node.dart` tiene además 2 líneas en *staged* (ajenas/previas).
- Cambios **ajenos** que no deben tocarse: `lib/core/domain/guided/question_bank.dart` (`NÚM`→`NÚMERO` en el segmento numérico) y el `PopScope` de `lsb_flow_screen.dart`.

## B. Objetivo
Conversation es un **orquestador**, no un tercer traductor: el oyente habla/escribe → Audio/Texto→LSB traduce UNA vez y entrega su lectura semántica (`semanticTurn`) → LSB→Texto/Audio (router) elige una ruta REAL de su grafo/QuestionBank (determinista; Bedrock solo si es ambiguo) → la persona sorda responde con tarjetas → español natural (Bedrock sobre SemanticFrame, validado) + Polly → vuelve al mismo hilo/turno.

## C–D. Arquitectura y archivos
Nuevos:
- `lib/core/domain/conversation/semantic_turn.dart` — `SemanticIntent`, `SemanticTurnSource{backend,clientFallback}`, `ContextMention`, `BackendSemanticTurn` (bloque del backend), `SemanticTurn` (+`fromBackend`).
- `lib/core/domain/conversation/lsb_gloss_semantics.dart` — tabla cerrada gloss→ranura (interrogativos, núcleos HORA/FECHA/DIA/MOMENTO/DIRECCION, glosas de función, negadores); espejo de la tabla de la Lambda.
- `lib/core/domain/conversation/graph_matcher.dart` — `GraphMatcher`, `RequestedQuestion`. `bySemantics` (backend: glosas+ranuras vs formulación LSB del banco), `byText` (solo respaldo), `nearby`.
- `lib/core/domain/conversation/conversation_graph_catalog.dart` — catálogo derivado de `QuestionBank` + `DialogueGraph` (nodos modo C con `bankQuestion`) + familias/contextos; `ReplyEntry`.
- `lib/core/domain/conversation/conversation_graph_router.dart` — `ConversationGraphRouter` (`routeDeterministic`, `route`, `acceptModelRoute`), `GraphRouteModel`.
- `lib/core/domain/conversation/conversation_route.dart` — `ConversationRouteType` (CONTEXT_SELECTOR, DIRECT_CONTEXT, DIRECT_QUESTION, MINIMAL_GRAPH_PATH, NO_SAFE_ROUTE), `RouteSource{deterministic,bedrock,cache}`, `ConversationRoute` (+`sourceLabel`, `fromModelJson` que rechaza claves de respuesta).
- `lib/core/domain/conversation/conversation_route_validator.dart` — `ConversationRouteValidator`, `RouteValidation`.
- `lib/core/domain/conversation/semantic_turn_builder.dart` — `SemanticTurnBuilder` = **respaldo del cliente** (backend sin `semanticTurn`).
- `lib/core/domain/conversation/conversation_reply.dart` — `ConversationReplyResult` + extensión `submitReply` sobre `ConversationBridge`.
- `lib/core/data/datasources/remote_graph_route_datasource.dart` — `RemoteGraphRouteDataSource` (implementa `GraphRouteModel`, `action: route`).
- `lib/features/lsb_to_text_audio/presentation/providers/conversation_return.dart` — `ConversationReturn.deliver` (vuelta al hilo).
- `lib/features/lsb_to_text_audio/presentation/providers/guided_emission.dart` — `GuidedEmission.emit` (emisión guiada extraída del widget).
- Tests nuevos: `test/conversation_graph_router_test.dart`, `test/conversation_reply_roundtrip_test.dart`, `test/audio_a_lsb_semantic_turn_test.dart`, `test/guided_layout_test.dart`, `aws/tests/test_conversation_route.py`, `aws/tests/test_semantic_turn_audio_a_lsb.py`, fixture `aws/tests/casos_semantic_turn.json` + `aws/tests/regenerar_casos_semantic_turn.py`.

Modificados (esta línea de trabajo): `aws/lambda_text_to_lsb.py` (`build_semantic_turn`, `SITUATION_CUES`, campo `semanticTurn` en HIT y MISS), `aws/lambda_function.py` (`route_conversation_turn`, `validate_route_candidate`, `build_route_prompt`, `route_cache_key`, `serve_cached_route`, `read_cache_json`/`write_cache_json`), `lib/core/di/injection.dart` (providers `conversationGraphCatalogProvider`, `semanticTurnBuilderProvider`, `graphRouteModelProvider`, `conversationGraphRouterProvider`), `lib/core/domain/entities/{conversation,dialogue_node,lsb_translation}.dart`, `lib/core/data/models/{conversation_json,lsb_translation_model}.dart`, `lib/core/data/datasources/remote_audio_datasource.dart` (1 línea), `lib/core/domain/services/{conversation_engine,context_inference_engine,dialogue_graph}.dart`, `lib/core/domain/guided/guided_session.dart` (`startJourney(onlySteps)`, `minimalPath`, `dependenciesOf`), `lib/core/presentation/session/cards_flow_launch.dart` (`route`, `focusedFamilyId`, `returnToConversation`), `lib/features/conversation/presentation/providers/{conversation_provider,conversation_handoff}.dart` (`routeForTurn`), `lib/features/lsb_to_text_audio/presentation/providers/guided_flow_provider.dart`, `.../widgets/{context_selection_widget,live_declaration_preview_panel,adaptive_node_layout,node_flow_canvas,semantic_node}.dart`, `.../screens/{declaration_result_screen,home_screen}.dart`, `test/home_to_result_flow_test.dart`. (Los widgets/pantallas también contienen cambios de UI de tareas previas.)

## E. Contratos
- `semanticTurn` (Lambda Audio/Texto→LSB): `{version, intent, requestedSlots[time|place|person|amount], mentionedContexts[{id(situación), evidence}], negations, confidence}`. No repite `glosses`/`disambiguation`.
- `SemanticTurn` (Dart): lectura completa que consume Conversation (entities = glosas, resolvedSenses desde `disambiguation`, `source`).
- `ConversationRoute`: solo IDs reales (familia, contexto, preguntas, ranuras); nunca opciones/respuestas. `pathQuestionIds` = recorrido validado; `presupposedQuestionIds` = preguntas que el oyente hizo tal cual.
- Ida: `CardsFlowLaunch.reply(conversationId, hearingTurnId, hearingText, route)` (hace de ConversationReplyRequest). Vuelta: `ConversationReplyResult` → `ConversationBridge.submitReply` → `ConversationNotifier.addDeafDeclaration` (valida conversationId/turno).
- Lambda LSB→Texto `action: "route"`: entrada `{semanticTurn, candidates[{id, routeType, targetContextId?, targetFamilyId?, targetQuestionIds, requestedSlots, label}], activeContextId?, routerVersion}`; salida `{generated, routeSource(bedrock|cache|noSafeRoute), candidateId, routeType, target*, requestedSlots, confidence, reason, cacheHit}`.

## F. semanticTurn backend + clientFallback
`lambda_text_to_lsb.lambda_handler` → Bedrock 1 vez → `post_process_glosses` → `build_semantic_turn(text, result)` (determinista, sin prompt nuevo, no persistido en caché de traducción). Cliente: `RemoteAudioDataSourceImpl` → `LsbTranslationModel.fromJson` (`BackendSemanticTurn.fromJson`) → `ConversationEngine.translateHearingTurn` crea `SemanticTurn.fromBackend`. Si falta: `routeForTurn` usa `SemanticTurnBuilder` (`clientFallback`). Trazas `developer.log`: `semanticTurnSource=…`, `routeSource=…`.

## G. Routing determinista (`ConversationGraphRouter.routeDeterministic`)
1) coincidencias fuertes del `GraphMatcher` (≥0.6) → DIRECT_QUESTION / MINIMAL_GRAPH_PATH con contexto por `_contextFor`; 2) menciones (agrupadas por familia; varias situaciones de una familia = familia; pista propia dentro de la familia = ese contexto) → DIRECT_CONTEXT; 3) `askPurpose` → CONTEXT_SELECTOR; 4) coincidencias débiles → NO_SAFE_ROUTE + candidatas para modelo; 5) pregunta libre → NO_SAFE_ROUTE + `nearby` para modelo; si no, NO_SAFE_ROUTE.

## H–I. Bedrock `route` y validación
Solo si `needsModel`. `acceptModelRoute`: `ConversationRouteValidator.validate` (existencia de familia/contexto/pregunta/ranura, pertenencia al recorrido salvo presupuesta, confianza ≥0.6, recálculo de dependencias con `GuidedFlow.minimalPath`) + `_withinCandidates`. Rechazo → ruta determinista segura (nunca navega a lo inventado). Lambda: valida candidatas contra el banco, el modelo elige por id y la respuesta copia la candidata (no los campos del modelo).

## J. Caché S3 de route (`aws/lambda_function.py`)
Reutiliza `_cache_s3_key` + `read_cache_json`/`write_cache_json`. Clave `route-v{ROUTER_PROMPT_VERSION}-sha256({router, bank=_bank_fingerprint, model=BEDROCK_MODEL_ID, turn=_turn_signature, active, candidates})`. HIT se revalida (`serve_cached_route`). "Sin ruta" TTL `ROUTE_NO_ROUTE_TTL_SECONDS`=900. Errores del modelo no se cachean.

## K. Contexto entre turnos
`Conversation.activeContextId` = contexto de la última respuesta sorda. `_contextFor`: contexto nombrado > familia nombrada > activo (si la pregunta es suya) > otro de la familia del activo > ámbito del nodo donde es paso > recorrido común.

## L. Ida/vuelta
`ConversationHandoff.nextDeafLaunch` (ruta del turno o `routeForTurn`) → `openCards` (contexto propuesto por la ruta; familia desplegada vía `focusedFamilyId` en `ContextSelectionWidget`) → `GuidedFlowNotifier._start` (con ruta de preguntas: `startJourney(requestedQuestionIds: presupposed, onlySteps: path)`; con ruta, no reinterpreta el texto) → `GuidedEmission.emit` → `ConversationReturn.deliver` (solo si `returnToConversation`) → pestaña Conversation. Sin autoplay.

## M. Español desde SemanticFrame
`TranslationController.translateGuided` → `ConversationEngine.generateGuided` → Lambda `lambda_function` (guided: `GuidedComposer`, `generate_spanish_from_semantic_frame`, `semantic_frame_is_preserved`, Polly `synthesize_audio`, caché S3). Solo se acepta texto con `coverageValidated`; si no, redacción local del banco.

## N–O. Tests (finales)
`flutter analyze`: 0 issues. `flutter test`: 734 passed (1 skip previo). Python `unittest discover -s aws/tests`: 342 OK. `compileall aws`: OK. `find_missing_lambda_lexicon`: OK. `validate_business_config.py`: exit 0.

## P. Pendientes (prioridad)
1. Paridad Python↔Dart de la tabla de ranuras (`_SLOT_POR_INTERROGATIVO`, `_SLOT_POR_NUCLEO`, `_NEGADORES` en `lambda_text_to_lsb.py` vs `LsbGlossSemantics`): hoy solo el fixture valida la salida de la Lambda; falta test de paridad o fuente común.
2. `SITUATION_CUES` (en `lambda_text_to_lsb.py`, junto a `build_semantic_turn`) es configuración manual; evaluar si se deriva de metadata existente sin tocar Corpus v4. Puede ser válido conservarlo.
3. `dart run tool/sync_vocabulary.dart --check` falla; los bloques `AVAILABLE_GLOSSES` y `GLOSS_LEXICON` son idénticos a HEAD → preexistente. Diagnosticar antes de tocar.
4. Pruebas opt-in con Bedrock real (glosas reales de frases libres); CI sigue con mocks.
5. Despliegue: `aws/deploy/build_package.py` empaqueta solo `lambda_function.py`, pero esta importa `guided_composer` y carga `question_bank.json` (preexistente); revisar antes de desplegar ambas Lambdas. Hasta desplegar, la app usa `clientFallback`.
6. Modo Libre: solo punto de extensión en `NO_SAFE_ROUTE`.
7. Cambio ajeno `question_bank.dart` (`NÚM`→`NÚMERO`): no tocar.

## Q. No tocar
Corpus Maestro v4, 143 preguntas/banco, grafos, Audio/Texto→LSB fuera de contratos, `question_bank.dart` ajeno; no chat LLM; Bedrock no responde por la persona sorda ni crea IDs/glosas/facts; no reset/rebase/revert; no refactor masivo; no `dart format` masivo (HEAD no está formateado uniformemente).

## R. Aceptación siguiente fase
Auditoría independiente coincide con este documento; deuda pequeña resuelta sin cambiar comportamiento; todas las suites en verde con cantidades ≥ las actuales; ningún cambio en corpus/banco/grafos (`git diff --stat -- assets/dictionary assets/dialogue aws/question_bank.json docs/negocio` vacío).
