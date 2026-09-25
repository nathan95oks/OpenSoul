# OpenSoul: contexto maestro para Claude, ChatGPT y otros asistentes

> Documento de traspaso técnico y funcional. Leerlo completo antes de modificar
> el proyecto. Describe el árbol de trabajo vigente al 25 de septiembre de 2026,
> incluyendo cambios todavía no confirmados en Git sobre `HEAD 031b821`.

## 1. Propósito de este documento

Este archivo permite iniciar una conversación nueva con un asistente sin perder
el contexto esencial del proyecto. Explica:

- qué problema intenta resolver OpenSoul;
- cómo funciona cada dirección de la conversación;
- qué significan los modos personal y ventanilla;
- dónde viven las fuentes canónicas y qué archivos son generados;
- cómo se conserva el significado entre UI, dominio, Lambda, texto, audio y avatar;
- qué está implementado y qué sigue pendiente;
- cómo verificar una modificación sin confundir pruebas técnicas con validación
  lingüística;
- cuál es el problema prioritario actual: **coherencia completa y máxima precisión
  semántica en todas las preguntas y contextos**.

Este documento no sustituye a las matrices procesables. Es el mapa para saber
qué leer, qué ejecutar y qué no asumir.

## 2. Resumen ejecutivo

OpenSoul es una aplicación Flutter de comunicación bidireccional para una persona
sorda y personal oyente de una entidad pública boliviana. Está orientada sobre
todo a situaciones de denuncia, consulta y trámite. El dispositivo se comparte
entre ambas personas.

Hay dos direcciones:

1. **Persona sorda → texto y audio en español.** La persona responde preguntas
   cortas mediante opciones, editores literales y datos tipados. El sistema arma
   una frase revisable, la envía como texto y puede sintetizar audio.
2. **Persona oyente → LSB/avatar.** El funcionario habla o escribe. El sistema
   obtiene glosas, resuelve ambigüedades y reproduce las animaciones disponibles;
   cuando no existe una animación verificable, recurre a dactilología o declara la
   limitación.

La aplicación también mantiene una conversación con varios turnos. Una respuesta
debe conservar la pregunta exacta que contesta, su `hearingTurnId` y el
`conversationId`. Cambiar de modo, superficie, intención o atención no puede
reutilizar datos o turnos anteriores.

### Objetivo actual

El objetivo no es añadir más botones ni más vocabulario por sí mismo. Es lograr
que, para **cada pregunta accesible**:

```text
pregunta visible
  → clase de dato solicitada
  → opciones realmente pertinentes
  → editor correcto
  → respuesta tipada guardada
  → borrador revisable
  → request del cliente
  → Lambda
  → texto final
  → audio
  → turno correcto de la conversación
```

conserven exactamente el mismo significado, sin omisiones, inferencias externas,
actores inventados ni trámites presentados que todavía no sucedieron.

La suite automática está verde, pero eso **no demuestra precisión absoluta**.
Muchas pruebas históricas comprueban infraestructura, navegación o ejemplos
concretos. La matriz completa de preguntas y los 36 defectos auditados siguen
siendo el contrato para ampliar la cobertura semántica real.

## 3. Límites éticos y lingüísticos

OpenSoul es una ayuda comunicativa; no sustituye automáticamente a un intérprete,
no certifica una denuncia y no representa consentimiento legal.

Nunca afirmar sin evidencia:

- que una composición es LSB lingüísticamente validada;
- que una institución acepta formalmente el resultado;
- que el avatar traduce una frase completa si faltan animaciones;
- que una frase en español equivale por sí sola a una seña disponible;
- que la aplicación elimina la necesidad de intérpretes;
- que las composiciones fueron validadas por personas sordas de Cochabamba.

Cinco conceptos deben mantenerse separados:

1. glosa documentada en el corpus o diccionario;
2. acepción válida en un contexto concreto;
3. texto literal escrito por la persona;
4. representación solicitada al avatar;
5. animación efectivamente presente en el archivo GLB desplegado.

## 4. Stack y estructura general

- Flutter/Dart 3.11.
- Riverpod para estado e inyección.
- GoRouter para navegación.
- AWS Lambda, API Gateway, Bedrock, Polly y S3.
- `model_viewer_plus` para el avatar 3D.
- `speech_to_text` para voz del oyente.
- paquete Dart: `lsb_legal_app`.

Estructura principal:

```text
lib/
  app/                         shell, rutas, modos y restauración de sesión
  core/
    domain/entities/           conversación, borrador, grafo, tarjetas
    domain/guided/             banco y compositor guiado v4
    domain/services/           motores semánticos y de conversación
    domain/repositories/       puertos del dominio
    data/datasources/          HTTP, caché y capacidades del backend
    data/repositories/         adaptadores concretos
    presentation/              sesión compartida y avatar
    di/                        composition root
  features/
    conversation/              conversación por turnos
    lsb_to_text_audio/         persona sorda → texto/audio
    audio_to_lsb/              persona oyente → glosas/avatar

assets/
  dictionary/official_dictionary.json
  dictionary/corpus_lsb_judicial.json
  dialogue/dialogue_graph.json
  business/institution_profiles.json

aws/
  lambda_function.py           tarjetas/datos → español + audio
  lambda_text_to_lsb.py        español/voz → glosas y animaciones
  guided_composer.py           compositor guiado Python
  question_bank.json           banco generado para Lambda
  tests/

docs/negocio/                  especificación, auditoría y matrices
tool/                          generadores y validadores
test/                          dominio, widgets y contratos Flutter
```

## 5. Modos, superficies y propósitos

### 5.1. Modos de uso

#### Personal

- La persona puede preparar e iniciar un mensaje sin que exista un turno del
  funcionario.
- No necesita conocer previamente la institución.
- Puede entrar después en conversación y responder un turno real.
- No se debe fingir que una institución recibió o formalizó el mensaje.

#### Ventanilla

- Puede existir un perfil institucional configurado.
- Puede iniciar cualquiera de los participantes.
- Cada nueva atención debe limpiar datos ciudadanos y contenido del caso previo.
- Finalizar atención no debe borrar la configuración permanente de la ventanilla,
  pero sí nombre, teléfono, monto, personas, hechos y enlaces a turnos del caso.

Los dos modos comparten semántica. Una factura, un robo o una captura significan
lo mismo. Cambian los datos previos, quién inicia y cómo se entrega el turno.

### 5.2. Propósitos A/B/C del flujo de tarjetas

- `standaloneIntervention`: intervención independiente.
- `conversationInitiative`: la persona sorda inicia un turno dentro de una
  conversación.
- `conversationReply`: responde al turno exacto de la persona oyente.

Los nombres aparecen también como `standalone`, `initiative` y `reply` en el
contrato guiado.

### 5.3. Aislamiento

Las pestañas autónomas no deben heredar el borrador de la conversación, y la
conversación no debe heredar un borrador construido en una herramienta suelta.
Solo el historial conversacional tiene memoria entre turnos. Revisar:

- `lib/app/surface_session.dart`
- `lib/core/presentation/session/`
- `test/module_isolation_test.dart`
- `test/navegacion_y_persistencia_test.dart`

## 6. Flujo persona sorda → texto y audio

### 6.1. Entrada

El contexto, la necesidad, la intención, el modo y, si corresponde, el turno del
oyente determinan el recorrido. La persona ve una pregunta corta y opciones
compatibles con el dato solicitado.

Archivos principales:

- `semantic_zones_provider.dart`: navegación histórica por zonas.
- `cards_provider.dart`: obtiene y ordena tarjetas visibles.
- `candidate_engine.dart`: filtro duro y orden de candidatos.
- `node_flow_canvas.dart`: pregunta y opciones visibles.
- `qualifier_sheets.dart`: despacho de modales/editores.
- `entity_editor_sheets.dart`: persona, nombre, teléfono y otros datos.
- `amount_input_sheet.dart`: monto y moneda.
- `denuncia_robo_draft_provider.dart`: combina respuestas y entidades.
- `live_declaration_preview_panel.dart`: frase revisable y emisión.
- `declaration_result_screen.dart`: resultado final.

### 6.2. Datos estructurados

`DeclarationDraft` conserva, entre otros:

- hasta dos hechos en `facts`, cada uno con su propio actor;
- personas y descripciones;
- objetos con rol explícito;
- lugar y referencia;
- tiempo;
- testigos;
- evidencia;
- violencia, fraude, amenaza digital, trámite o consulta;
- intención de presentar denuncia, que no equivale a una denuncia presentada;
- `speechAct` y `replyToId`.

Tipos importantes en `declaration_draft.dart`:

- `ConfirmationState`: confirmado, incierto, negado o pendiente;
- `ActorRole`: víctima, sospechoso, tercera persona o desconocido;
- `Certainty`: certeza propia del hecho;
- `Fact`: acción, actor, negación, certeza y detalle;
- `PersonEntity`, `ObjectInvolved`, `EvidenceItem`, `FraudDetails`, etc.

No deducir un actor por descarte. `ROBAR + ESCAPAR` puede significar:

- “me robaron y yo escapé”; o
- “me robaron y la otra persona escapó”.

El orden de toque tampoco expresa orden temporal.

### 6.3. Composición histórica y guiada

Actualmente coexisten dos representaciones:

1. `DeclarationDraft` + `LocalSentenceAssembler`, usada por los flujos
   históricos y el contrato estructurado v3/v4.
2. `GuidedIntervention` + `GuidedComposer`, introducida para que la matriz de
   preguntas sea ejecutable sin reinterpretar respuestas.

La migración aún debe comprobar que todas las rutas reales de UI producen el
contrato guiado. La existencia del compositor no demuestra que cada pantalla lo
use.

### 6.4. Salida

La frase determinista se muestra antes de emitir. En el backend puede existir
refinamiento con Bedrock para rutas antiguas, pero el texto solo se acepta si
conserva las relaciones. Las respuestas guiadas v4 se redactan directamente con
el banco y **no pasan por Bedrock**, porque un refinamiento podría cambiar actor,
negación o texto literal.

Polly debe sintetizar el texto finalmente aceptado, no una versión anterior.

## 7. Flujo persona oyente → LSB/avatar

Entrada:

- texto escrito; o
- dictado convertido a texto en el dispositivo.

La Lambda `aws/lambda_text_to_lsb.py`:

1. valida longitud y formato;
2. analiza el texto;
3. resuelve términos polisémicos cuando el contexto lo permite;
4. genera glosas;
5. contrasta cada glosa con las animaciones conocidas del GLB;
6. devuelve una secuencia de animación o dactilología.

Archivos cliente relevantes:

- `audio_to_lsb_screen.dart`
- `audio_translation_controller.dart`
- `animation_repository_impl.dart`
- `animation_url_resolver.dart`
- `avatar_3d_viewer.dart`

La lista estática `AVAILABLE_3D_GLOSSES` es un respaldo, no una prueba del
contenido del modelo real. Cuando la Lambda tiene permisos, debe inspeccionar la
lista de clips del GLB en S3. La comprobación definitiva requiere servicio y
dispositivo reales.

## 8. Conversación y turnos

La entidad `Conversation` guarda turnos alternados. Para una respuesta son
autoritativos:

- `conversationId`;
- `hearingTurnId`/`replyToId`;
- texto exacto del turno oyente;
- contexto confirmado para ese turno.

Reglas:

- una respuesta vuelve el control a la persona oyente;
- tres o más turnos deben mantener sus enlaces individuales;
- un nuevo caso no reutiliza el turno anterior;
- cambiar de modo no reutiliza un `hearingTurnId` obsoleto;
- si el turno original ya no existe, se informa y no se envía como si todavía
  fuera válido;
- “¿Le robaron el celular?” + “No” no crea un hecho de robo;
- “Sí” confirma el objeto ya mencionado y no debe preguntarlo otra vez.

Pruebas útiles:

- `conversation_bidirectional_test.dart`
- `conversation_fluidity_test.dart`
- `preguntas_funcionario_test.dart`
- `conversacion_iniciada_por_sorda_test.dart`
- `conversacion_ventanilla_test.dart`
- `recorridos_completos_test.dart`

## 9. Banco de preguntas: fuente canónica

Fuente editable:

```text
docs/negocio/config/banco_preguntas.json
docs/negocio/config/acepciones.json
```

El banco actual contiene:

- 143 preguntas;
- 8 recorridos;
- 528 opciones;
- asignación para los 98 enunciados de funcionario del corpus.

Generador:

```bash
python tool/build_question_matrix.py
python tool/build_question_matrix.py --check
```

Salidas generadas; no editar directamente:

- `docs/negocio/11_Matriz_Preguntas.md`
- `docs/negocio/12_Brechas_Lexicas_Animacion.md`
- `docs/negocio/matriz_preguntas.json`
- `docs/negocio/matriz_preguntas.csv`
- `docs/negocio/matriz_nodos_grafo.csv`
- `docs/negocio/matriz_zonas_actuales.csv`
- `docs/negocio/matriz_modos.csv`
- `lib/core/domain/guided/question_bank_data.g.dart`
- `aws/question_bank.json`

### 9.1. Contrato de una pregunta

Cada pregunta debe declarar como mínimo:

- identificador estable;
- formulación visible;
- acto comunicativo;
- entidad y campo solicitado;
- control de interfaz;
- opciones válidas;
- estado producido por cada opción;
- frase o fragmento resultante;
- glosas de respuesta, si existen;
- editor y valores requeridos, si son literales;
- condiciones de visibilidad;
- opciones que explícitamente no deben ofrecerse.

### 9.2. Tipos de dato solicitados

El sistema debe distinguir:

- polaridad;
- persona/actor;
- objeto;
- hecho/acción;
- lugar;
- fecha/hora;
- documento;
- medio;
- cantidad y moneda;
- nombre literal;
- teléfono literal;
- edad numérica o rango explícito;
- detalle abierto necesario.

Ausencia de respuesta, “No”, “No sé” y omisión voluntaria son cuatro estados
diferentes.

### 9.3. Separación obligatoria

En `DialogueNode` y en el JSON generado no mezclar:

- `formulationGlosses`: vocabulario usado para formular la pregunta;
- `options`: respuestas seleccionables;
- `controls`: continuar, volver, omitir, corregir;
- `literals`: valores escritos o deletreados;
- `pendingOptions`: conceptos sin cobertura.

Ejemplo: en “¿Le robaron el celular?”, `CELULAR` pertenece al enunciado. Las
respuestas directas son Sí/No/No sé. El motor puede usar la entidad mencionada
para redactar la confirmación, pero no debe presentar cualquier objeto o persona
como respuesta polar.

## 10. Candidatos y tarjetas

`CandidateEngine` aplica restricciones duras antes de ordenar.

Principios:

- Bedrock no vuelve válida una opción incompatible;
- el perfil institucional y la necesidad ordenan, no autorizan;
- una allowlist de zona tampoco puede anular la clase semántica del campo;
- `CELULAR` puede ser objeto o medio, nunca la persona que envió mensajes;
- `DÓNDE` formula una pregunta; no es una respuesta de lugar;
- una glosa desconocida no se debe aceptar para llenar la cuadrícula;
- el diccionario general permanece disponible cuando la persona explora;
- explorar vocabulario y responder un paso guiado son actividades distintas;
- “No sé” debe estar disponible, pero al final de las alternativas concretas.

La clase semántica debe salir de la misma tabla que usa el ensamblador:
`LocalSentenceAssembler.functionOf`. Evitar mantener dos clasificaciones
incompatibles.

## 11. Contrato cliente/Lambda vigente

Versión anunciada por cliente y backend: **4**.

Cliente:

- `RemoteTranslationDataSourceImpl.contractVersion = 4`.
- `BackendCompatibility.clientContractVersion = 4`.

Backend:

- `BACKEND_CONTRACT_VERSION = 4`.
- `GENERATOR_VERSION = 3`; forma parte de la clave de caché.

Cuerpo simplificado:

```json
{
  "context": "amenaza_digital",
  "cards": [],
  "language": "es-BO",
  "institutionType": "entidad_publica",
  "contractVersion": 4,
  "replyToId": "hearing-3",
  "conversationId": "conversation-7",
  "guided": {
    "recorrido": "amenaza_digital",
    "proposito": "reply",
    "conversationId": "conversation-7",
    "hearingTurnId": "hearing-3",
    "hearingTurnText": "¿Quién envió los mensajes?",
    "respuestas": [
      {
        "pregunta": "Q.DIG.REMITENTE",
        "estado": "afirmado",
        "opciones": ["solo_numero"],
        "valores": {
          "solo_numero": {"telefono": "70012345"}
        }
      }
    ]
  }
}
```

`GuidedAnswerState` distingue `afirmado`, `negado`, `desconocido` y `omitido`.
Los compositores gemelos son:

- Dart: `lib/core/domain/guided/guided_composer.dart`.
- Python: `aws/guided_composer.py`.

El mismo banco generado alimenta ambos.

## 12. Fuentes canónicas y generación

| Información | Fuente editable | Salida generada |
|---|---|---|
| Diccionario de tarjetas | `assets/dictionary/official_dictionary.json` | lexicones Dart/Python mediante `sync_vocabulary.dart` |
| Corpus conversacional | documentos de corpus usados por `corpus_dialogue.py` | `assets/dialogue/dialogue_graph.json` |
| Preguntas y recorridos | `config/banco_preguntas.json` | matrices, Dart y AWS question bank |
| Acepciones | `config/acepciones.json` | validación y matrices |
| Perfiles | `config/perfiles_institucionales.json` | `assets/business/institution_profiles.json` y docs |
| Aceptación | `config/matriz_aceptacion.json` | `06_Matriz_Aceptacion.md` |

Regla absoluta: **no editar un archivo generado sin modificar primero su fuente**.

Comandos principales:

```bash
dart run tool/sync_vocabulary.dart
python tool/build_dialogue_graph.py
python tool/build_question_matrix.py
python tool/build_business_assets.py
python tool/build_business_docs.py
```

## 13. Contextos y recorridos principales

El banco guiado tiene recorridos para:

- `denuncia_robo`: robo, pérdida o daño;
- `violencia`: violencia o agresión;
- `amenaza_digital`: amenazas o mensajes;
- `engano_dinero`: engaño con dinero;
- `identificacion`: datos propios;
- `otro`: declaración de testigo;
- `preguntas`: consulta iniciada por la persona;
- `seguimiento`: consulta de trámite o investigación.

La semántica institucional no debe duplicar estos recorridos. Personal y
ventanilla comparten las preguntas cuando intención y datos coinciden.

### Ejemplos de precisión requerida

#### Remitente de mensajes

“¿Quién envió los mensajes?” permite:

- persona conocida;
- solo número conocido, con editor telefónico;
- descripción opcional;
- desconocido.

No permite `CELULAR` como actor. Si solo se conoce el número, la frase indica
que el nombre es desconocido y muestra únicamente el número confirmado.

#### Factura y comprobantes

“¿Tiene factura?” y “¿Conserva comprobante bancario?” son preguntas polares.
Solo si la respuesta es Sí se solicita un detalle pertinente. `PAPEL` representa
un documento todavía no identificado; no debe duplicar `FACTURA`.

Mensajes guardados y capturas son campos independientes.

#### Engaño con dinero

El sistema pregunta por separado:

- procedimiento del engaño;
- medio de entrega;
- monto;
- moneda;
- destinatario, si se conoce;
- comprobante;
- mensajes/capturas, si corresponde.

Elegir `BILLETES` no significa “me estafaron” ni “transferí dinero”.

#### Denuncia formal

“¿Desea presentar una denuncia?” produce intención: Sí/No/No sé. No afirma
“denuncia presentada”. La institución solo se pregunta después, cuando proceda.

#### Edad

Una edad numérica se conserva como número. “24” no se transforma en “joven”.
“Aproximadamente 24 años” solo se redacta si se marcó incertidumbre.

#### Salud

No introducir un itinerario médico rutinario en denuncias o trámites. Preguntar
por auxilio o asistencia cuando la persona lo pide o una respuesta previa lo
justifica.

## 14. Problema actual: coherencia y precisión

La auditoría de `08_Auditoria_Precision_Semantica.md` encontró 36 defectos. La
lista procesable vive en `10_Defectos_Priorizados.md`. Aunque varios mecanismos
ya fueron corregidos, no debe suponerse que todos los nodos y recorridos están
cerrados.

Familias de riesgo:

1. Actor descartado o atribuido por inferencia.
2. Pérdida convertida en robo, o desconocimiento convertido en hecho.
3. Cancelar un modal modifica el borrador.
4. Límites de selección ignorados.
5. Frases fijas que no leen respuestas.
6. Canal, institución, formalidad o documento inventados.
7. Monto, moneda, receptor o comprobante perdidos.
8. Pregunta del funcionario mapeada a otra pregunta.
9. Nombre, edad o contacto no llegan a la frase.
10. Glosas del enunciado ofrecidas como respuestas.
11. Filtro por campo eludido desde categorías, búsqueda o allowlists.
12. Preguntas compuestas que guardan un dato ambiguo.
13. Borrador o turno viejo reutilizado.
14. Preguntas encadenadas inalcanzables.
15. Falta de revisión antes de emitir.
16. Diferencia insuficiente entre personal y ventanilla.

### Definición de coherencia completa

Para cada fila de `matriz_preguntas.json` deben comprobarse:

- pregunta correcta para contexto, propósito y turno;
- opciones visibles válidas y opciones inválidas ausentes;
- control/editor adecuado;
- cancelar = cero cambios;
- confirmar = una modificación validada;
- editar conserva datos no relacionados;
- cambio de respuesta limpia únicamente subordinados, con aviso;
- dato tipado correcto en memoria y JSON;
- frase previa fiel;
- frase Lambda idéntica en significado;
- audio solicitado para esa misma frase;
- retorno al turno correcto;
- limpieza al iniciar caso o cerrar ventanilla.

## 15. Pruebas y puerta de salida

Última ejecución local conocida sobre este árbol:

```text
flutter analyze
  → No issues found

flutter test
  → 626 aprobadas, 1 omitida, 0 fallidas

python -m unittest discover -s aws/tests
  → 240 aprobadas, 0 fallidas

python tool/validate_business_config.py
  → 15 casos, 11 perfiles, 41 intenciones verificadas

python tool/build_dialogue_graph.py --check
  → grafo al día

python tool/build_question_matrix.py --check
  → banco al día y coherente
```

No reutilizar estas cifras en un informe futuro: ejecutar de nuevo los comandos.

Puerta obligatoria:

```bash
flutter analyze
flutter test
python -m unittest discover -s aws/tests
python tool/validate_business_config.py
python tool/build_dialogue_graph.py --check
python tool/build_question_matrix.py --check
```

Pruebas especialmente importantes:

- `guided_composer_test.dart`
- `aws/tests/test_guiado_v4.py`
- `candidate_engine_test.dart`
- `filtro_por_campo_test.dart`
- `dialogue_graph_test.dart`
- `preguntas_funcionario_test.dart`
- `exhaustive_flows_coherence_test.dart`
- `declaration_draft_assembler_test.dart`
- `dos_hechos_test.dart`
- `person_full_traits_ui_test.dart`
- `contract_fixtures_test.dart`
- `aws/tests/test_contrato_cliente_real.py`

Una prueba nueva debe ejercer la ruta real. Probar solo una función ideal no
demuestra que el widget, provider, request y handler usen esa función.

## 16. Estado Git al redactar este documento

`HEAD` es `031b821`, pero existe un árbol de trabajo amplio sin commit. Incluye:

- auditoría y matrices nuevas;
- regeneración del grafo;
- banco guiado Dart/Python;
- contrato v4;
- correcciones del motor de candidatos;
- sincronización de vocabulario;
- cambios de animación y caché;
- pruebas y fixtures actualizados.

Antes de trabajar:

```bash
git status --short
git diff --stat
```

No ejecutar `git reset --hard`, `git checkout --` ni regeneraciones masivas sin
revisar este árbol. Los cambios sin confirmar forman parte del trabajo actual.

## 17. Qué no está verificado

- Bedrock real: las pruebas usan dobles.
- Polly real y pronunciación de frases complejas.
- caché S3 real.
- API Gateway desplegado con contrato v4.
- contenido real del GLB en producción.
- reproducción del avatar en dispositivo.
- teclado, orientación, aumento de texto y rendimiento en teléfonos/tablets
  físicos.
- exactitud lingüística con personas sordas e intérpretes de Cochabamba.
- aceptación formal por instituciones.

El backend v4 requiere desplegar primero la Lambda y su `question_bank.json`.
Publicar primero un cliente v4 contra una Lambda anterior puede aceptar HTTP 200
y aun perder datos.

## 18. Seguridad operativa

Las Lambdas limitan tamaño y formato de entrada, pero API Gateway todavía debe
tener autenticación, cuota y rate limiting. CORS amplio y URLs extraíbles de un
APK pueden permitir consumo de Bedrock/Polly a cargo de la cuenta.

Antes de producción:

- usage plan y API key;
- throttling y cuota diaria;
- AWS Budgets y alarmas;
- CORS restringido cuando aplique;
- permisos mínimos para S3/Bedrock/Polly;
- despliegue backend antes del cliente.

## 19. Protocolo recomendado para continuar

1. Leer este archivo y `10_Defectos_Priorizados.md`.
2. Ejecutar `git status --short`; preservar cambios existentes.
3. Elegir una familia de preguntas o un defecto P0/P1.
4. Encontrar la fuente canónica antes de editar una salida generada.
5. Trazar la ruta real completa: widget → provider → borrador → request →
   Lambda → texto/audio → conversación.
6. Escribir primero una prueba negativa y una positiva.
7. Corregir el origen, no una frase aislada en el JSON generado.
8. Regenerar solo los artefactos afectados.
9. Ejecutar pruebas focales y luego toda la puerta de salida.
10. Documentar brechas reales, sin convertir texto fácil de generar en falsa
    cobertura lingüística.

### Orden sugerido de trabajo

1. P0: pérdida/robo, actor de escape, cancelación, formalidad, fraude y respuesta
   al turno exacto.
2. P1: todas las preguntas del funcionario, editores tipados, preguntas
   compuestas y limpieza de subordinados.
3. Integración completa del banco guiado en las pantallas reales.
4. Widgets en teléfono pequeño/tablet y accesibilidad.
5. Prueba contra Lambda desplegada y dispositivo real.
6. Validación lingüística y de uso con la comunidad sorda.

## 20. Prompt inicial para otra conversación

Copiar este texto junto con el repositorio:

```text
Trabaja en el repositorio OpenSoul. Lee primero
docs/CONTEXTO_MAESTRO_PARA_IA.md completo y luego
docs/negocio/10_Defectos_Priorizados.md. El objetivo prioritario es lograr
coherencia semántica completa y máxima precisión en todas las preguntas y
contextos: pregunta visible, opciones, editor, dato tipado, borrador, request,
Lambda, texto, audio y turno deben conservar exactamente el mismo significado.

Preserva el árbol de trabajo sin commit. No edites archivos generados sin
modificar su fuente. No inventes glosas, animaciones, actores, instituciones,
formalidades o cobertura lingüística. Usa las matrices procesables como contrato,
implementa por la ruta real y añade pruebas positivas y negativas. Antes de
afirmar que terminaste, ejecuta toda la puerta de salida indicada en el documento
y declara con precisión qué no se probó en AWS, dispositivo o con personas sordas.
```

## 21. Documentos que deben consultarse después

1. `docs/negocio/10_Defectos_Priorizados.md`: defectos y aceptación.
2. `docs/negocio/11_Matriz_Preguntas.md`: banco completo legible.
3. `docs/negocio/matriz_preguntas.json`: banco procesable.
4. `docs/negocio/09_Recorridos_A_I.md`: recorridos de referencia.
5. `docs/negocio/08_Auditoria_Precision_Semantica.md`: causas raíz.
6. `docs/negocio/12_Brechas_Lexicas_Animacion.md`: límites de vocabulario/avatar.
7. `docs/negocio/04_Contratos_Datos.md`: reglas de datos.
8. `README.md`: visión general y ejecución.
9. `aws/README.md`: backend, caché y seguridad.

La regla de cierre es sencilla: una opción es correcta solo si una persona que
lee la pregunta visible puede entenderla como respuesta razonable, y la frase
final expresa exactamente esa elección —ni más ni menos— en el turno correcto.
