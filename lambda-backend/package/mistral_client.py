import os
import json
from mistralai import Mistral
from parse_response import parse_raw_response

# Global variable to store the last raw response
LAST_RAW_RESPONSE = ""

def process_image(image_base64, system_prompt):
    """Process an image with Mistral vision model and return structured JSON data."""
    global LAST_RAW_RESPONSE
    
    try:
        api_key = os.environ.get("MISTRAL_API_KEY")
        
        if not api_key:
            raise ValueError("MISTRAL_API_KEY environment variable not set")
        
        client = Mistral(api_key=api_key)
        
        # Ensure the image_base64 is properly formatted
        if image_base64.startswith("data:image"):
            # Use it as is
            image_url = image_base64
        else:
            # Add the data URL prefix
            image_url = f"data:image/jpeg;base64,{image_base64}"
            
        print(f"Sending request to Mistral Vision API with image of length: {len(image_base64)}")
        
        # Use Mistral Pixtral vision model to process the image directly
        chat_response = client.chat.complete(
            model="pixtral-12b-2409",
            messages=[
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "text",
                            "text": system_prompt + "\n\nPlease analyze this receipt image and extract the data as JSON."
                        },
                        {
                            "type": "image_url",
                            "image_url": image_url
                        }
                    ]
                }
            ],
            temperature=0.0
        )
        
        content = chat_response.choices[0].message.content
        
        # Store the raw response for debugging
        LAST_RAW_RESPONSE = content
        
        print(f"Mistral vision response (first 200 chars): {content[:200]}")
        
        # Use the parser from parse_response.py
        return parse_raw_response(content)
        
    except Exception as e:
        print(f"Error processing image with Mistral: {str(e)}")
        LAST_RAW_RESPONSE = f"Error: {str(e)}"
        raise

def get_last_raw_response():
    """Return the last raw response from Mistral API."""
    global LAST_RAW_RESPONSE
    return LAST_RAW_RESPONSE
