# Contrato API — módulo `lsb_to_text_audio`

Interfaz HTTP entre la app Flutter y el backend AWS (API Gateway → Lambda
`lambda_function.py`). Es el punto de integración crítico del módulo.

- **Método:** `POST`
- **Endpoint (dev):** `https://5kc2fwqb49.execute-api.us-east-1.amazonaws.com/translate`
  - Configurable en compilación: `flutter run --dart-define=LSB_API_URL=<url>` (TD-01).
- **Timeout cliente:** 12 s. Al expirar, la app cae al motor local + TTS (RDS-01).
- **Headers:** `Content-Type: application/json`, `Accept: application/json`.

## Request

```json
{
  "context": "denuncia_robo",
  "cards": ["HOMBRE", "ROBAR", "CELULAR", "CALLE", "NOCHE"],
  "language": "es-BO",
  "institutionType": "entidad_publica"
}
```

| Campo | Tipo | Obligatorio | Descripción |
|-------|------|-------------|-------------|
| `context` | string | sí | Contexto de UI: `denuncia_robo`, `violencia`, `accidente`, `otro`, `orientacion`. Es el id de UI **sin resolver** — la resolución a sub-dominios (`perdida`/`tramite_id`) es interna del motor local y NO se envía (RVP-03). |
| `cards` | string[] | sí | Glosas LSB seleccionadas, en orden. No puede ir vacío. |
| `language` | string | no (def. `es`) | Idioma/voz solicitado. Determina la voz de Polly (RDS-02). `es-BO`→`Lupe`/es-US, `es-MX`→`Mia`/es-MX. |
| `institutionType` | string | no | `entidad_publica` activa el **registro formal** del backend (`is_formal=True`, AWS-01). |

> **Nota (AWS-01):** la formalidad se deriva de `institutionType` **o** de que `context`
> sea uno de los contextos institucionales conocidos. Antes se comparaba contra
> etiquetas que la app nunca enviaba, por lo que el backend nunca era formal.

## Response 200

```json
{
  "baseSentence": "Un hombre me robó el celular en la calle por la noche.",
  "generatedText": "Anoche, en la calle, un hombre me sustrajo el teléfono celular.",
  "intermediateRepresentation": { "tipo_evento": "ROBO", "roles": {} },
  "glossSequence": [
    { "gloss": "HOMBRE", "videoKey": "lsb-videos/HOMBRE.mp4", "recognized": true, "rol": "SUJETO" }
  ],
  "audioUrl": "https://<bucket>.s3.amazonaws.com/lsb-to-text-audio/<key>.mp3",
  "cacheHit": false,
  "bedrockUsed": true
}
```

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `baseSentence` | string | Oración del motor de reglas propio (backend). |
| `generatedText` | string | Oración final (refinada por Bedrock si `bedrockUsed`). |
| `intermediateRepresentation` | object? | Representación semántica intermedia (roles, tipo de evento). |
| `glossSequence` | object[]? | Glosas con clave de video para el avatar 3D. |
| `audioUrl` | string? | URL prefirmada del MP3 (Polly + S3), válida 1 h. |
| `cacheHit` | bool | `true` si la respuesta se sirvió desde la caché en S3 (combinación contexto+glosas ya procesada), sin invocar Nova ni Polly. La primera vez es `false`. |
| `bedrockUsed` | bool | `true` si Bedrock refinó la oración. La app lo muestra como chip de origen (RVP-01). |

## Errores

| Código | `error` | Causa |
|--------|---------|-------|
| 400 | `JSON_PARSE_ERROR` / `VALIDATION_ERROR` | Body inválido o `cards` ausente/vacío. |
| 500 | `POLLY_ERROR` / `S3_ERROR` | Fallo de síntesis o almacenamiento. |

## Comportamiento del cliente ante fallos (resiliencia)

La app **nunca** propaga el error al usuario: ante cualquier fallo (timeout, 4xx/5xx,
o respuesta *degenerada* que pierde glosas) usa el **motor semántico local**
(`LocalSentenceAssembler`) y el **TTS del dispositivo**, garantizando siempre
salida texto + audio. El detector `isBackendDegenerate` exige que el backend
cubra **todas** las glosas seleccionadas; si pierde alguna, se descarta su texto
y su `audioUrl`.
