import os
import json
import requests
import re
from parse_response import parse_raw_response

# Global variable to store the last raw response
LAST_RAW_RESPONSE = ""

def process_image(image_base64, system_prompt):
    """Process an image with GPT-4o and return structured JSON data using direct HTTP request."""
    global LAST_RAW_RESPONSE
    
    try:
        api_key = os.environ.get("OPENAI_API_KEY")
        
        # Check if we're using a dummy key for testing
        if api_key == "dummy_key_for_testing":
            print("Using mock data for testing (dummy API key)")
            # Return mock data for testing
            mock_data = {
                "merchant": "Test Store",
                "address": "123 Test Street, Test City",
                "date": "2025-04-18",
                "total": "$42.99",
                "items": [
                    {"name": "Test Item 1", "qty": 2, "unit_price": "$10.99", "total_price": "$21.98"},
                    {"name": "Test Item 2", "qty": 1, "unit_price": "$15.99", "total_price": "$15.99"},
                    {"name": "Test Item 3", "qty": 1, "unit_price": "$5.02", "total_price": "$5.02"}
                ]
            }
            LAST_RAW_RESPONSE = json.dumps(mock_data, indent=2)
            return mock_data
        
        if not api_key:
            raise ValueError("OPENAI_API_KEY environment variable not set")
            
        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {api_key}"
        }
        
        # Ensure the image_base64 is properly formatted
        if image_base64.startswith("data:image"):
            # Extract the base64 part if it's already in data URL format
            image_b64 = image_base64.split(",")[1]
        else:
            image_b64 = image_base64
            
        print(f"Sending request to OpenAI API with image of length: {len(image_b64)}")
        
        payload = {
            "model": "gpt-4o",
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": [
                    {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{image_b64}"}}
                ]}
            ],
            "max_tokens": 1024,
            "temperature": 0.0
        }
        
        response = requests.post(
            "https://api.openai.com/v1/chat/completions",
            headers=headers,
            json=payload,
            timeout=60  # Set a longer timeout
        )
        
        if response.status_code != 200:
            print(f"OpenAI API error: {response.status_code} - {response.text}")
            raise Exception(f"OpenAI API error: {response.status_code} - {response.text}")
            
        result = response.json()
        content = result["choices"][0]["message"]["content"]
        
        # Store the raw response for debugging
        LAST_RAW_RESPONSE = content
        
        print(f"OpenAI response content (first 100 chars): {content[:100]}")
        
        # Use the simplified parser from parse_response.py
        return parse_raw_response(content)
        
    except Exception as e:
        print(f"Error processing image: {str(e)}")
        LAST_RAW_RESPONSE = f"Error: {str(e)}"
        raise

def get_last_raw_response():
    """Return the last raw response from OpenAI API."""
    global LAST_RAW_RESPONSE
    return LAST_RAW_RESPONSE

if __name__ == "__main__":
    # For testing
    with open("test_image.txt", "r") as f:
        image_base64 = f.read()
    
    result = process_image(image_base64, "Extract receipt information")
    print(json.dumps(result, indent=2))
