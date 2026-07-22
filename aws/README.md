# Backend AWS — OpenSoul

Funciones Lambda del proyecto. Solo `lambda_function.py` pertenece al módulo
`lsb_to_text_audio` (mi parte).

| Archivo | Estado | Pertenece a | Descripción |
|---------|--------|-------------|-------------|
| `lambda_function.py` | **Desplegado (real)** | `lsb_to_text_audio` | Motor híbrido: análisis semántico propio + refinamiento Bedrock + Polly + S3. Es el backend del contrato en [`../docs/API_CONTRACT.md`](../docs/API_CONTRACT.md). |
| `lambda_text_to_lsb.py` | Real | `audio_to_lsb` (compañero) | Texto/voz → glosas LSB. **No es de este módulo**, no auditar aquí. |
| `lambda_bedrock_polly.py` | Referencia/experimento | — | Prototipo previo de integración Bedrock+Polly. No se despliega. |
| `lambda_mock.py` | Mock | — | Respuesta fija para pruebas locales sin AWS. |
| `lambda_dictionary.py` | **Nuevo (Fase 2), pendiente de despliegue** | núcleo compartido | API del diccionario evolutivo: `GET /dictionary` (mismo contrato que `assets/dictionary/official_dictionary.json`) y `POST /dictionary/proposals` (propuestas `pending`). |
| `seed_dictionary.py` | Script local | núcleo compartido | Crea/puebla la tabla DynamoDB `OpenSoul-Dictionary` desde el JSON canónico del repo. |

## Despliegue del diccionario (Fase 2)

1. `python3 aws/seed_dictionary.py --create-table` (crea la tabla on-demand y la siembra).
2. Desplegar `lambda_dictionary.py` con rol de lectura/escritura sobre la tabla y exponerla en API Gateway (`GET /dictionary`, `POST /dictionary/proposals`).
3. Compilar la app con `--dart-define=LSB_DICTIONARY_API_URL=https://<api>/dictionary` — sin esa variable la app funciona 100 % local (asset + caché).
4. En `OpenSoul-TextToLSB` (lambda_text_to_lsb) definir `DICTIONARY_TABLE=OpenSoul-Dictionary` + permiso `dynamodb:Query`: las señas nuevas aprobadas quedan disponibles para el avatar sin redesplegar.

## Variables de entorno (`lambda_function.py`)

| Variable | Default | Uso |
|----------|---------|-----|
| `S3_BUCKET` | `opensoul-lsb-audio-dev` | Bucket de audios MP3. |
| `APP_PREFIX` | `lsb-to-text-audio` | Prefijo de las claves S3. |
| `VOICE_ID` | `Lupe` | Voz Polly. Si se fija, manda sobre la selección por `language` (RDS-02). |
| `BEDROCK_MODEL_ID` | `amazon.titan-text-express-v1` | Modelo de refinamiento. |
| `APP_REGION` | `us-east-1` | Región AWS. |
| `ENABLE_BEDROCK` | `true` | Desactiva el refinamiento si `false` (devuelve la oración base). |

## Caché (AWS-02)

La respuesta completa se cachea en S3 bajo `lsb-to-text-audio/cache/<cache_key>.json`
(el `cache_key` hashea contexto + glosas). Peticiones idénticas posteriores devuelven
esa respuesta con `cacheHit: true` **sin invocar Bedrock ni Polly** — solo se regenera
la URL prefirmada del MP3 ya almacenado. No requiere DynamoDB ni infraestructura extra.

> **IAM:** el rol de la Lambda debe permitir `s3:GetObject` y `s3:PutObject` sobre el
> bucket (`s3:PutObject` ya era necesario para el audio; `s3:GetObject` lo añade la caché).
> Si falta, la lectura de caché falla de forma silenciosa y el sistema simplemente
> reprocesa (degrada con elegancia, sin romper).

## Validación rápida

```bash
python3 -c "import ast; ast.parse(open('aws/lambda_function.py').read()); print('OK')"
```
