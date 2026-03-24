import json
import boto3
import hashlib
import os

# Clientes AWS
bedrock = boto3.client('bedrock-runtime')
polly = boto3.client('polly')
s3 = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')

S3_BUCKET = os.environ.get('POLLY_S3_BUCKET', 'mi-bucket-app-lsb-audios')
DYNAMO_TABLE = os.environ.get('CACHE_TABLE', 'PhraseCache')

def generate_cache_key(context, cards):
    plain = f"{context}-{' '.join(cards).upper()}"
    return hashlib.md5(plain.encode()).hexdigest()

def lambda_handler(event, context):
    body = json.loads(event.get('body', '{}'))
    ctx = body.get('context', 'legal')
    cards = body.get('cards', [])
    
    cache_key = generate_cache_key(ctx, cards)
    table = dynamodb.Table(DYNAMO_TABLE)
    
    # 1. DynamoDB Caché Check (Si esta secuencia ya fue traducida y grabada)
    cached = table.get_item(Key={'cacheId': cache_key}).get('Item')
    if cached:
        return {
            'statusCode': 200,
            'body': json.dumps({
                'generatedText': cached['generatedText'],
                'audioUrl': cached['audioUrl'],
                'cacheHit': True
            })
        }

    # 2. Bedrock (Claude 3 Haiku o Llama 3)
    # Reconstrucción LSB -> Español
    prompt = f"""Human: Eres un traductor experto en Lengua de Señas Boliviana trabajando en entorno jurídico. Toma estas palabras clave de glosas LSB y fórjalas como una sola oración formal en primera persona, hablada gramaticalmente perfecta en español. NO agregues introducciones, opiniones ni aclaraciones. Devuelve únicamente la oración resultante.
    Ejemplo LSB: ["YO", "NECESITAR", "ABOGADO", "AHORA"] -> "Necesito un abogado de forma urgente."
    Entrada LSB: {json.dumps(cards)}
    Assistant:"""

    try:
        bedrock_res = bedrock.invoke_model(
            modelId='anthropic.claude-3-haiku-20240307-v1:0', # Modelo económico y ultra rápido
            contentType='application/json',
            accept='application/json',
            body=json.dumps({
                "anthropic_version": "bedrock-2023-05-31",
                "max_tokens": 100,
                "messages": [{"role": "user", "content": prompt}]
            })
        )
        response_body = json.loads(bedrock_res['body'].read())
        formal_text = response_body['content'][0]['text'].strip()
        
        # 3. Amazon Polly (Síntesis de voz)
        polly_res = polly.synthesize_speech(
            Text=formal_text,
            OutputFormat='mp3',
            VoiceId='Mia', # Voz neutral (Mexicana/Latina en Polly)
            Engine='neural' # Alta calidad
        )
        
        # 4. Amazon S3 (Guardar MP3)
        file_name = f"audios/{cache_key}.mp3"
        s3.put_object(
            Bucket=S3_BUCKET,
            Key=file_name,
            Body=polly_res['AudioStream'].read(),
            ContentType='audio/mpeg'
        )
        audio_url = f"https://{S3_BUCKET}.s3.amazonaws.com/{file_name}"
        
        # 5. Guardar en DynamoDB Cache
        table.put_item(Item={
            'cacheId': cache_key,
            'generatedText': formal_text,
            'audioUrl': audio_url
        })
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'generatedText': formal_text,
                'audioUrl': audio_url,
                'cacheHit': False
            })
        }
        
    except Exception as e:
        return {'statusCode': 500, 'body': json.dumps({'error': str(e)})}
