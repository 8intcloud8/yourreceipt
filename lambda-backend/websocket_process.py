import json
import os
import boto3
from openai_client import process_image

# Initialize API Gateway Management API client
def get_apigw_client(event):
    domain = event['requestContext']['domainName']
    stage = event['requestContext']['stage']
    endpoint_url = f"https://{domain}/{stage}"
    
    return boto3.client('apigatewaymanagementapi', endpoint_url=endpoint_url)

def send_message(apigw_client, connection_id, message):
    """Send message to WebSocket client"""
    try:
        apigw_client.post_to_connection(
            ConnectionId=connection_id,
            Data=json.dumps(message).encode('utf-8')
        )
    except Exception as e:
        print(f"Error sending message: {e}")

def lambda_handler(event, context):
    """Process receipt image via WebSocket"""
    connection_id = event['requestContext']['connectionId']
    apigw_client = get_apigw_client(event)
    
    try:
        # Parse the incoming message
        body = json.loads(event.get('body', '{}'))
        action = body.get('action')
        
        if action != 'process':
            send_message(apigw_client, connection_id, {
                'type': 'error',
                'message': 'Invalid action'
            })
            return {'statusCode': 400}
        
        image_base64 = body.get('image_base64')
        if not image_base64:
            send_message(apigw_client, connection_id, {
                'type': 'error',
                'message': 'No image provided'
            })
            return {'statusCode': 400}
        
        # Send progress update
        send_message(apigw_client, connection_id, {
            'type': 'progress',
            'message': 'Processing image with AI...',
            'progress': 30
        })
        
        # Load GPT-4o prompt
        gpt4o_prompt = """You are a world-class vision AI assistant. Given an image of a receipt, identify and extract the receipt's header and line items. Return only valid JSON in the following format:

{
  "merchant": "Store Name",
  "address": "123 Main St",
  "date": "2025-04-15",
  "total": "$45.32",
  "items": [
    {"name": "Apples", "qty": 2, "unit_price": "$1.50", "total_price": "$3.00"},
    {"name": "Bread", "qty": 1, "unit_price": "$2.00", "total_price": "$2.00"}
  ]
}

Instructions:
- Extract merchant name, address, date, and total from the header.
- Extract each line item: name, quantity, unit price, and total price.
- If any field is missing, use null.
- Do not include any explanation or text outside the JSON.
- Only output valid, parseable JSON."""
        
        # Process with GPT-4o
        send_message(apigw_client, connection_id, {
            'type': 'progress',
            'message': 'Extracting receipt data...',
            'progress': 60
        })
        
        result = process_image(image_base64, gpt4o_prompt)
        
        # Send completion
        send_message(apigw_client, connection_id, {
            'type': 'progress',
            'message': 'Processing complete!',
            'progress': 100
        })
        
        # Send final result
        send_message(apigw_client, connection_id, {
            'type': 'result',
            'data': result
        })
        
        return {'statusCode': 200}
        
    except Exception as e:
        print(f"Error processing receipt: {e}")
        send_message(apigw_client, connection_id, {
            'type': 'error',
            'message': str(e)
        })
        return {'statusCode': 500}
