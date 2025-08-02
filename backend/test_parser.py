#!/usr/bin/env python3
import json
import requests
from openai_client import parse_raw_response

# Example of a truncated or malformed JSON response from GPT-4o
test_response = '''```json
{
  "merchant": "WALMART",
  "address": "123 MAIN ST, ANYTOWN, USA",
  "date": "2023-04-15",
  "total": "$42.67",
  "items": [
    {
      "name": "BANANAS",
      "qty": 1,
      "unit_price": "$0.59",
      "total_price": "$0.59"
    },
    {
      "name": "MILK 1 GAL",
      "qty": 1,
      "unit_price": "$3.49",
      "total_price": "$3.49"
    },
    {
      "name": "BREAD",
      "qty": 2,
      "unit_price": "$2.29",
      "total_price": "$4.58"
    },
    {
      "name": "EGGS LARGE",
      "qty": 1,
      "unit_price": "$2.99",
      "total_price": "$2.99"
    },
    {
      "name": "CHICKEN BREAST",
      "qty": 1,
      "unit_price": "$8.99",
      "total_price": "$8.99"
    }
```'''

# Test with a truncated JSON that's missing closing braces
truncated_response = '''```json
{
  "merchant": "WALMART",
  "address": "123 MAIN ST, ANYTOWN, USA",
  "date": "2023-04-15",
  "total": "$42.67",
  "items": [
    {
      "name": "BANANAS",
      "qty": 1,
      "unit_price": "$0.59",
      "total_price": "$0.59"
    },
    {
      "name": "MILK 1 GAL",
      "qty": 1,
      "unit_price": "$3.49",
      "total_price": "$3.49"
    },
    {
      "name": "BREAD",
      "qty": 2,
      "unit_price": "$2.29",
'''

def test_parser():
    print("Testing with complete JSON but missing closing braces:")
    result1 = parse_raw_response(test_response)
    print(json.dumps(result1, indent=2))
    print(f"Successfully extracted {len(result1.get('items', []))} items\n")
    
    print("Testing with severely truncated JSON:")
    result2 = parse_raw_response(truncated_response)
    print(json.dumps(result2, indent=2))
    print(f"Successfully extracted {len(result2.get('items', []))} items\n")
    
    # Try to get the raw response from the server
    try:
        response = requests.get("http://localhost:8080/raw_response")
        if response.status_code == 200:
            data = response.json()
            if data.get('raw_response'):
                print("Testing with actual server response:")
                result3 = parse_raw_response(data['raw_response'])
                print(json.dumps(result3, indent=2))
                print(f"Successfully extracted {len(result3.get('items', []))} items")
            else:
                print("No raw response available from server yet")
        else:
            print(f"Failed to get raw response from server: {response.status_code}")
    except Exception as e:
        print(f"Error connecting to server: {e}")

if __name__ == "__main__":
    test_parser()
