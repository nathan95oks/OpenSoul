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
python3 -m unittest discover -s aws/tests -v   # regresiones de seguridad
```

Las regresiones corren solas en CI (`.github/workflows/ci.yml`, job
*Lambdas (Python)*) sobre Python 3.12 y 3.13, sin instalar dependencias:
`test_security.py` sustituye `boto3` por un doble antes de importar las
Lambdas. `flutter test` **no** las ve, que es justo por lo que necesitan job
propio.

## Seguridad

### Cotas de entrada (ya en el código)

| Lambda | Cota | Por qué |
|---|---|---|
| `lambda_function.py` | `MAX_CARDS=64`, `MAX_CARD_LENGTH=64` | Cada invocación consume Bedrock por token y Polly por carácter. Sin techo, una sola petición podía inflar el prompt sin límite. |
| `lambda_text_to_lsb.py` | `text` ≤ 1000 car., glosas devueltas validadas contra `_VALID_GLOSS` | La frase es entrada de usuario que acaba en el prompt (OWASP LLM01), y lo que devuelve el modelo es igual de poco confiable. |
| `lambda_dictionary.py` | `MAX_BODY_BYTES=16 KB`, tipo y longitud por campo | `POST /proposals` es público: sin validar valores, cualquiera podía llenar DynamoDB hasta 400 KB por item. |

Cubiertas por `aws/tests/test_security.py`.

### Pendiente: los endpoints no tienen autenticación ni límite de tasa

**Esto no se arregla en el código de las Lambdas — es configuración de API
Gateway.** Hoy las cuatro funciones aceptan cualquier petición: `CORS` está en
`*` y las cabeceras `Authorization` / `X-Api-Key` se **declaran permitidas pero
nunca se verifican**. Las URLs, además, están como valores por defecto en el
binario de la app (`String.fromEnvironment`), así que se extraen de un APK sin
esfuerzo.

Consecuencia concreta: cualquiera que lea esas URLs puede invocar Bedrock y
Polly a cargo de la cuenta. No es robo de datos, es la factura.

Mitigación mínima recomendada, en orden de coste:

1. **Usage plan + API key** en API Gateway, con *throttling* (p. ej. 10 req/s,
   ráfaga 20) y **cuota diaria**. La cuota es lo que convierte un incidente de
   facturación en un incidente de disponibilidad, que es mucho más barato.
2. **AWS Budgets con alarma** sobre el gasto de Bedrock/Polly. Detección, no
   prevención, pero es lo que avisa de que algo va mal.
3. **CORS por origen concreto** en vez de `*` (una app móvil no necesita `*`).
4. Para el diccionario, exigir la API key también en `POST /proposals`, o
   moverlo detrás de un autorizador cuando exista el portal de validación.
5. A medio plazo: WAF con *rate-based rule* por IP.

> Mientras 1 y 2 no estén, conviene no publicar las URLs de producción en un
> repositorio público.
