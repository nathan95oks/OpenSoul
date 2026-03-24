import json

def lambda_handler(event, context):
    try:
        body = json.loads(event.get('body', '{}'))
        cards = body.get('cards', [])
        
        # Validar entrada
        if not cards:
            return {
                'statusCode': 400,
                'body': json.dumps({'message': 'cards is required'})
            }
        
        # Respuesta estática mockeada
        return {
            'statusCode': 200,
            'body': json.dumps({
                'generatedText': "Yo presencié un robo el día de ayer. (Mock AWS)",
                'audioUrl': "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3", 
                'cacheHit': False
            })
        }
    except Exception as e:
        return {'statusCode': 500, 'body': json.dumps({'error': str(e)})}
