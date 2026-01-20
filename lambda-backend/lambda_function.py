import json
import base64
import os
from typing import Dict, Any
import boto3
from mistral_client import process_image

# Initialize Secrets Manager client
secrets_client = boto3.client('secretsmanager', region_name='ap-southeast-2')

def get_mistral_api_key():
    """Get Mistral API key from AWS Secrets Manager"""
    try:
        response = secrets_client.get_secret_value(SecretId='ReconcileAI/mistral/api-key')
        secret_string = response['SecretString']
        # Parse the JSON to get the api_key value
        secret_dict = json.loads(secret_string)
        return secret_dict['api_key']
    except Exception as e:
        print(f"Error getting Mistral API key from Secrets Manager: {e}")
        raise

# Load the GPT-4o prompt
GPT4O_PROMPT = """
Extract the following information from this receipt image and return it as a JSON object:

{
  "merchant": "Store name",
  "address": "Store address", 
  "date": "Date in YYYY-MM-DD format",
  "receipt_id": "Receipt number, invoice number, or receipt ID",
  "tax": "Tax amount (GST, VAT, or sales tax) with currency symbol",
  "total": "Total amount with currency symbol",
  "items": [
    {
      "name": "Item name",
      "qty": "Quantity",
      "unit_price": "Price per unit with currency",
      "total_price": "Total price for this item with currency"
    }
  ]
}

Be precise and extract exactly what's shown on the receipt. Look for:
- Receipt ID: May be labeled as "Receipt #", "Invoice #", "Receipt No", "Invoice No", or similar
- Tax: Look for GST, VAT, Sales Tax, or Tax line items
If information is unclear or missing, use empty strings.
"""

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    AWS Lambda handler for receipt processing
    """
    try:
        # Handle CORS preflight requests
        if event.get('httpMethod') == 'OPTIONS':
            return {
                'statusCode': 200,
                'headers': {
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
                    'Access-Control-Allow-Methods': 'POST,OPTIONS',
                    'Access-Control-Max-Age': '86400'
                },
                'body': ''
            }
        
        # Parse the request body
        if event.get('body'):
            if event.get('isBase64Encoded'):
                body = base64.b64decode(event['body']).decode('utf-8')
            else:
                body = event['body']
            
            try:
                request_data = json.loads(body)
            except json.JSONDecodeError:
                return {
                    'statusCode': 400,
                    'headers': {
                        'Access-Control-Allow-Origin': '*',
                        'Content-Type': 'application/json'
                    },
                    'body': json.dumps({'error': 'Invalid JSON in request body'})
                }
        else:
            return {
                'statusCode': 400,
                'headers': {
                    'Access-Control-Allow-Origin': '*',
                    'Content-Type': 'application/json'
                },
                'body': json.dumps({'error': 'Missing request body'})
            }
        
        # Extract image data
        image_base64 = request_data.get('image_base64')
        if not image_base64:
            return {
                'statusCode': 400,
                'headers': {
                    'Access-Control-Allow-Origin': '*',
                    'Content-Type': 'application/json'
                },
                'body': json.dumps({'error': 'Missing image_base64 field'})
            }
        
        # Validate image size (4MB limit)
        image_size = len(image_base64) * 3 / 4  # Approximate size of decoded base64
        max_size = 4 * 1024 * 1024  # 4MB
        if image_size > max_size:
            return {
                'statusCode': 413,
                'headers': {
                    'Access-Control-Allow-Origin': '*',
                    'Content-Type': 'application/json'
                },
                'body': json.dumps({'error': f'Image too large. Maximum size is {max_size / (1024 * 1024):.1f} MB'})
            }
        
        # Process the image with Mistral
        try:
            # Set the API key from Secrets Manager
            os.environ['MISTRAL_API_KEY'] = get_mistral_api_key()
            
            result = process_image(image_base64, GPT4O_PROMPT)
            
            return {
                'statusCode': 200,
                'headers': {
                    'Access-Control-Allow-Origin': '*',
                    'Content-Type': 'application/json'
                },
                'body': json.dumps({
                    'success': True,
                    'data': result
                })
            }
            
        except Exception as e:
            print(f"Error processing image: {str(e)}")
            return {
                'statusCode': 500,
                'headers': {
                    'Access-Control-Allow-Origin': '*',
                    'Content-Type': 'application/json'
                },
                'body': json.dumps({
                    'success': False,
                    'error': 'Failed to process receipt image',
                    'data': {
                        'merchant': '',
                        'address': '',
                        'date': '',
                        'receipt_id': '',
                        'tax': '',
                        'total': '',
                        'items': []
                    }
                })
            }
            
    except Exception as e:
        print(f"Lambda handler error: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Content-Type': 'application/json'
            },
            'body': json.dumps({'error': 'Internal server error'})
        }