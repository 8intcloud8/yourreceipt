#!/usr/bin/env python3
import json
import requests
import sys
import re

def parse_raw_response(text: str) -> dict:
    """
    Parse the raw response JSON from GPT-4o, handling common formatting issues.
    
    Args:
        text (str): The raw response string from GPT-4o.
        
    Returns:
        dict: Parsed dictionary with receipt data.
    """
    if not text or text.strip() == "":
        return {"merchant": "", "address": "", "date": "", "total": "", "items": []}
    
    # Step 1: Clean up the text
    # Remove markdown code blocks
    if "```json" in text:
        text = text.split("```json")[1].split("```")[0].strip()
    elif "```" in text:
        text = text.split("```")[1].split("```")[0].strip()
    
    # Decode escaped characters
    try:
        cleaned = text.encode('utf-8').decode('unicode_escape').strip()
    except Exception:
        cleaned = text.strip()
    
    # Step 2: Try to parse as valid JSON
    try:
        parsed = json.loads(cleaned)
        return parsed
    except json.JSONDecodeError:
        # If parsing fails, extract fields using regex
        return extract_fields_with_regex(cleaned)

def extract_fields_with_regex(text: str) -> dict:
    """Extract receipt fields using regex patterns."""
    result = {
        "merchant": extract_field(text, "merchant"),
        "address": extract_field(text, "address"),
        "date": extract_field(text, "date"),
        "total": extract_field(text, "total"),
        "items": extract_items(text)
    }
    return result

def extract_field(text: str, field_name: str) -> str:
    """Extract a field value from JSON-like text using regex."""
    pattern = f'"{field_name}"\\s*:\\s*"([^"]*)"'
    match = re.search(pattern, text)
    if match:
        return match.group(1)
    return ""

def extract_items(text: str) -> list:
    """Extract line items from the items array using regex."""
    items = []
    
    # Find the items array
    if '"items"' not in text or '[' not in text:
        return items
    
    # Extract all complete item objects (text between { and })
    item_pattern = r'\{([^{}]*(?:\{[^{}]*\}[^{}]*)*)\}'
    matches = re.finditer(item_pattern, text)
    
    for match in matches:
        item_text = '{' + match.group(1) + '}'
        try:
            # Try to parse as JSON
            item = json.loads(item_text)
            items.append(item)
        except json.JSONDecodeError:
            # If parsing fails, extract fields manually
            item = {
                "name": extract_field(item_text, "name"),
                "qty": extract_numeric_field(item_text, "qty"),
                "unit_price": extract_field(item_text, "unit_price"),
                "total_price": extract_field(item_text, "total_price")
            }
            if any(item.values()):  # Only add if at least one field has a value
                items.append(item)
    
    return items

def extract_numeric_field(text: str, field_name: str) -> int:
    """Extract a numeric field value from JSON-like text."""
    pattern = f'"{field_name}"\\s*:\\s*([0-9]+)'
    match = re.search(pattern, text)
    if match:
        try:
            return int(match.group(1))
        except ValueError:
            pass
    return 1  # Default to 1 if not found or not a number

def fetch_and_parse_raw_response(url="http://localhost:8080/raw_response"):
    """Fetch the raw response from the server and parse it."""
    try:
        response = requests.get(url)
        if response.status_code == 200:
            data = response.json()
            if 'raw_response' in data and data['raw_response']:
                result = parse_raw_response(data['raw_response'])
                print(json.dumps(result, indent=2))
                return result
            else:
                print("raw_response not found in the API response")
        else:
            print(f"API request failed with status code: {response.status_code}")
    except Exception as e:
        print(f"Error fetching or parsing response: {e}")
    
    return None

if __name__ == "__main__":
    # If a file path is provided, read and parse that file
    if len(sys.argv) > 1:
        file_path = sys.argv[1]
        try:
            with open(file_path, 'r') as f:
                raw_json = f.read()
            result = parse_raw_response(raw_json)
            print(json.dumps(result, indent=2))
        except Exception as e:
            print(f"Error reading or parsing file: {e}")
    else:
        # Otherwise fetch from the API
        fetch_and_parse_raw_response()
