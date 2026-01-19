import os
import json
from mistralai import Mistral
from parse_response import parse_raw_response

# Global variable to store the last raw response
LAST_RAW_RESPONSE = ""

def process_image(image_base64, system_prompt):
    """Process an image with Mistral OCR and return structured JSON data."""
    global LAST_RAW_RESPONSE
    
    try:
        api_key = os.environ.get("MISTRAL_API_KEY")
        
        if not api_key:
            raise ValueError("MISTRAL_API_KEY environment variable not set")
        
        client = Mistral(api_key=api_key)
        
        # Ensure the image_base64 is properly formatted
        if image_base64.startswith("data:image"):
            # Extract the base64 part if it's already in data URL format
            image_b64 = image_base64.split(",")[1]
        else:
            image_b64 = image_base64
            
        print(f"Sending request to Mistral OCR API with image of length: {len(image_b64)}")
        
        # Process with Mistral OCR - use "image_url" type for images
        ocr_response = client.ocr.process(
            model="mistral-ocr-latest",
            document={
                "type": "image_url",
                "image_url": f"data:image/jpeg;base64,{image_b64}"
            }
        )
        
        # Extract text from all pages
        text = "\n\n".join([page.markdown for page in ocr_response.pages])
        
        print(f"Mistral OCR extracted text (first 200 chars): {text[:200]}")
        
        # Now use Mistral chat to structure the data
        chat_response = client.chat.complete(
            model="mistral-large-latest",
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": f"Here is the OCR text from a receipt:\n\n{text}\n\nPlease extract and structure this data as JSON."}
            ],
            temperature=0.0
        )
        
        content = chat_response.choices[0].message.content
        
        # Store the raw response for debugging
        LAST_RAW_RESPONSE = content
        
        print(f"Mistral chat response (first 100 chars): {content[:100]}")
        
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
