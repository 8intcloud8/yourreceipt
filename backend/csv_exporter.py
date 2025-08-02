#!/usr/bin/env python3
import csv
import os
import datetime
from typing import Dict, List, Any, Tuple

def write_receipt_to_csv(receipt_data: Dict[str, Any], output_dir: str = "receipts") -> Tuple[str, str]:
    """
    Write receipt data to two separate CSV files:
    1. header.csv - Contains merchant, address, date, total
    2. line.csv - Contains all line items
    
    Data is appended to existing files if they exist, otherwise new files are created.
    
    Args:
        receipt_data: Dictionary containing receipt data
        output_dir: Directory to save the CSV files
        
    Returns:
        Tuple of paths to the CSV files (header_path, lines_path)
    """
    # Create output directory if it doesn't exist
    os.makedirs(output_dir, exist_ok=True)
    
    # Use fixed filenames
    header_filename = "header.csv"
    lines_filename = "line.csv"
    
    header_path = os.path.join(output_dir, header_filename)
    lines_path = os.path.join(output_dir, lines_filename)
    
    # Determine if files exist to decide whether to write headers
    header_exists = os.path.exists(header_path)
    lines_exist = os.path.exists(lines_path)
    
    # --- Prevent duplicate receipts ---
    is_duplicate = False
    if header_exists:
        try:
            # Read all existing receipts and group by receipt ID
            with open(header_path, 'r', newline='') as csvfile:
                reader = csv.reader(csvfile)
                next(reader)  # Skip header row
                receipts = {}
                for row in reader:
                    if len(row) == 3:
                        rid, field, value = row
                        if rid not in receipts:
                            receipts[rid] = {}
                        receipts[rid][field] = value
                # Check for duplicate (same merchant, address, date, total)
                for r in receipts.values():
                    if all(r.get(f, None) == str(receipt_data.get(f, '')) for f in ["merchant", "address", "date", "total"]):
                        is_duplicate = True
                        break
        except Exception as e:
            print(f"Error checking for duplicate receipt: {e}")
    if is_duplicate:
        print("Duplicate receipt detected. Skipping save.")
        return (header_path, lines_path)
    # --- End duplicate check ---
    
    # Assign a receipt ID (check if any existing receipts in header file)
    receipt_id = 1
    if header_exists:
        try:
            with open(header_path, 'r', newline='') as csvfile:
                reader = csv.reader(csvfile)
                next(reader)  # Skip header row
                rows = list(reader)
                if rows:
                    # Get the highest ID and add 1
                    receipt_id = max(int(row[0]) for row in rows if row and row[0].isdigit()) + 1
        except Exception as e:
            print(f"Error determining receipt ID: {e}")
            receipt_id = 1
    
    # Write header CSV file
    with open(header_path, 'a', newline='') as csvfile:
        writer = csv.writer(csvfile)
        
        # Write column headers if file is new
        if not header_exists:
            writer.writerow(["Id", "Field", "Value"])
        
        # Write header fields
        header_fields = ["merchant", "address", "date", "total"]
        for field in header_fields:
            if field in receipt_data and receipt_data[field]:
                writer.writerow([receipt_id, field, receipt_data[field]])
    
    # Determine field order for line items
    all_fields = set()
    for item in receipt_data.get("items", []):
        all_fields.update(item.keys())
    
    # Sort fields with name, qty, unit_price, total_price at the beginning
    priority_fields = ["name", "qty", "unit_price", "total_price"]
    other_fields = sorted(field for field in all_fields if field not in priority_fields)
    field_order = priority_fields + other_fields
    
    # Get the next line item ID
    next_line_id = 1
    if lines_exist:
        try:
            with open(lines_path, 'r', newline='') as csvfile:
                reader = csv.reader(csvfile)
                next(reader)  # Skip header row
                rows = list(reader)
                if rows:
                    # Get the highest ID and add 1
                    next_line_id = max(int(row[0]) for row in rows if row and row[0].isdigit()) + 1
        except Exception as e:
            print(f"Error determining line item ID: {e}")
            next_line_id = 1
    
    # Write lines CSV file
    with open(lines_path, 'a', newline='') as csvfile:
        writer = csv.writer(csvfile)
        
        # Write column headers if file is new
        if not lines_exist:
            writer.writerow(["id", "receipt_id"] + field_order)
        
        # Write each item as a row
        for i, item in enumerate(receipt_data.get("items", []), next_line_id):
            row = [i, receipt_id]  # Add line item ID and receipt ID
            row.extend([item.get(field, "") for field in field_order])
            writer.writerow(row)
    
    print(f"Receipt header appended to {header_path}")
    print(f"Receipt line items appended to {lines_path}")
    
    return (header_path, lines_path)

def read_receipt_from_csv(header_path: str, lines_path: str) -> Dict[str, Any]:
    """
    Read receipt data from separate header and lines CSV files.
    
    Args:
        header_path: Path to the header CSV file
        lines_path: Path to the lines CSV file
        
    Returns:
        Dictionary containing receipt data
    """
    receipt_data = {
        "items": []
    }
    
    # Read header data
    with open(header_path, 'r', newline='') as csvfile:
        reader = csv.reader(csvfile)
        next(reader)  # Skip header row
        
        receipt_id = None
        
        for row in reader:
            if len(row) == 3:
                id_val, field, value = row
                
                # Set receipt ID from the first row
                if receipt_id is None:
                    receipt_id = id_val
                    receipt_data["id"] = id_val
                
                receipt_data[field] = value
    
    # Read line items
    with open(lines_path, 'r', newline='') as csvfile:
        reader = csv.DictReader(csvfile)
        
        for row in reader:
            # Create a copy of the row without the id and receipt_id fields
            item = {k: v for k, v in row.items() if k not in ['id', 'receipt_id']}
            
            # Add the line item to the items list
            receipt_data["items"].append(item)
    
    return receipt_data

if __name__ == "__main__":
    # Example usage
    sample_receipt = {
        "merchant": "WALMART",
        "address": "123 MAIN ST, ANYTOWN, USA",
        "date": "2023-04-15",
        "total": "$42.67",
        "items": [
            {"name": "BANANAS", "qty": 1, "unit_price": "$0.59", "total_price": "$0.59"},
            {"name": "MILK 1 GAL", "qty": 1, "unit_price": "$3.49", "total_price": "$3.49"}
        ]
    }
    
    # Write to CSV
    header_path, lines_path = write_receipt_to_csv(sample_receipt)
    
    # Read back from CSV
    read_data = read_receipt_from_csv(header_path, lines_path)
    print("Read data:", read_data)
