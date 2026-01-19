import json

def lambda_handler(event, context):
    """Handle WebSocket disconnection"""
    connection_id = event['requestContext']['connectionId']
    
    print(f"Client disconnected: {connection_id}")
    
    return {
        'statusCode': 200,
        'body': json.dumps({'message': 'Disconnected'})
    }
