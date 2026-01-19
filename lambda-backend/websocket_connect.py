import json

def lambda_handler(event, context):
    """Handle WebSocket connection"""
    connection_id = event['requestContext']['connectionId']
    
    print(f"Client connected: {connection_id}")
    
    return {
        'statusCode': 200,
        'body': json.dumps({'message': 'Connected'})
    }
