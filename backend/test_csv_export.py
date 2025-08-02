#!/usr/bin/env python3
import json
import requests
from csv_exporter import write_receipt_to_csv, read_receipt_from_csv

def test_csv_export():
    """Test the CSV export functionality with a sample receipt."""
    # Sample receipt data
    sample_receipt = {
        "merchant": "WALMART",
        "address": "123 MAIN ST, ANYTOWN, USA",
        "date": "2023-04-15",
        "total": "$42.67",
        "items": [
            {"name": "BANANAS", "qty": 1, "unit_price": "$0.59", "total_price": "$0.59"},
            {"name": "MILK 1 GAL", "qty": 1, "unit_price": "$3.49", "total_price": "$3.49"},
            {"name": "BREAD", "qty": 2, "unit_price": "$2.29", "total_price": "$4.58"},
            {"name": "EGGS LARGE", "qty": 1, "unit_price": "$2.99", "total_price": "$2.99"},
            {"name": "CHICKEN BREAST", "qty": 1, "unit_price": "$8.99", "total_price": "$8.99"}
        ]
    }
    
    # Write to CSV files
    header_path, lines_path = write_receipt_to_csv(sample_receipt)
    print(f"Header CSV file created: {header_path}")
    print(f"Lines CSV file created: {lines_path}")
    
    # Display the contents of both files
    print("\nHeader CSV contents:")
    with open(header_path, 'r') as f:
        print(f.read())
    
    print("\nLines CSV contents:")
    with open(lines_path, 'r') as f:
        print(f.read())
    
    # Read back from CSV
    read_data = read_receipt_from_csv(header_path, lines_path)
    print("\nData read from CSV files:")
    print(json.dumps(read_data, indent=2))
    
    # Verify the data matches
    print("\nVerification:")
    for field in ["merchant", "address", "date", "total"]:
        print(f"{field}: {'✓' if sample_receipt[field] == read_data[field] else '✗'}")
    
    print(f"Number of items: {'✓' if len(sample_receipt['items']) == len(read_data['items']) else '✗'}")

def test_with_server_response():
    """Try to get the last raw response from the server and export it to CSV."""
    try:
        response = requests.get("http://localhost:8080/raw_response")
        if response.status_code == 200:
            data = response.json()
            if data.get('raw_response'):
                from parse_response import parse_raw_response
                
                print("\nTesting with actual server response:")
                result = parse_raw_response(data['raw_response'])
                
                if result:
                    header_path, lines_path = write_receipt_to_csv(result)
                    print(f"Server response exported to CSV files:")
                    print(f"Header: {header_path}")
                    print(f"Lines: {lines_path}")
                    
                    # Print the CSV contents
                    print("\nHeader CSV contents:")
                    with open(header_path, 'r') as f:
                        print(f.read())
                    
                    print("\nLines CSV contents:")
                    with open(lines_path, 'r') as f:
                        print(f.read())
                else:
                    print("Failed to parse server response")
            else:
                print("No raw response available from server yet")
        else:
            print(f"Failed to get raw response from server: {response.status_code}")
    except Exception as e:
        print(f"Error connecting to server: {e}")

if __name__ == "__main__":
    test_csv_export()
    test_with_server_response()
