import os
import io
from fastapi import FastAPI, Request, HTTPException
from fastapi.responses import JSONResponse, HTMLResponse, FileResponse
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
from starlette.requests import Request
from starlette.status import HTTP_413_REQUEST_ENTITY_TOO_LARGE
import json
import asyncio
import base64
import subprocess
import sys
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

# Import our Mistral client module
from mistral_client import process_image, get_last_raw_response
from csv_exporter import write_receipt_to_csv

# Load OpenAI API key from environment variable
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
if not OPENAI_API_KEY:
    print("WARNING: OPENAI_API_KEY environment variable not set. Some features will be limited.")
    OPENAI_API_KEY = "dummy_key_for_testing"  # Use a dummy key for testing

GPT4O_PROMPT_PATH = os.path.join(os.path.dirname(__file__), '../gpt4o_prompt.txt')
with open(GPT4O_PROMPT_PATH, 'r') as f:
    GPT4O_PROMPT = f.read()

MAX_IMAGE_SIZE = 4 * 1024 * 1024  # 4MB

app = FastAPI()

# Mount static files directory
static_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "static")
os.makedirs(static_dir, exist_ok=True)
app.mount("/static", StaticFiles(directory=static_dir), name="static")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["*"]
)

async def call_gpt4o(image_bytes: str, max_retries=3, delay=2):
    for attempt in range(max_retries):
        try:
            # Print for debugging
            print(f"Attempt {attempt+1}/{max_retries} to call GPT-4o")
            
            # Use our separate module to process the image
            data = process_image(image_bytes, GPT4O_PROMPT)
            return data
            
        except json.JSONDecodeError as e:
            print(f"JSON decode error: {str(e)}")
            if attempt == max_retries - 1:
                raise HTTPException(status_code=502, detail=f"Failed to parse JSON from GPT-4o: {str(e)}")
            await asyncio.sleep(delay)
        except Exception as e:
            print(f"Error in attempt {attempt+1}: {str(e)}")
            if attempt == max_retries - 1:
                raise HTTPException(status_code=500, detail=str(e))
            await asyncio.sleep(delay)

@app.get("/raw_response")
async def get_raw_response():
    """Endpoint to get the last raw response from OpenAI."""
    # Return the last raw response from the openai_client module
    return JSONResponse(content={"raw_response": get_last_raw_response()})

@app.get("/view_raw", response_class=HTMLResponse)
async def view_raw_response_html():
    """Endpoint to view the last raw response in a browser."""
    html_content = f"""
    <html>
        <head>
            <title>Raw GPT-4o Response</title>
            <style>
                body {{ font-family: Arial, sans-serif; margin: 20px; }}
                pre {{ background-color: #f5f5f5; padding: 15px; border-radius: 5px; white-space: pre-wrap; }}
                h1 {{ color: #333; }}
            </style>
        </head>
        <body>
            <h1>Raw GPT-4o Response</h1>
            <pre>{get_last_raw_response()}</pre>
        </body>
    </html>
    """
    return HTMLResponse(content=html_content)

@app.post("/upload")
async def upload_image(request: Request):
    try:
        data = await request.json()
        image_b64 = data["image_base64"]
        
        # Validate image size
        image_size = len(image_b64) * 3 / 4  # Approximate size of decoded base64
        if image_size > MAX_IMAGE_SIZE:
            raise HTTPException(
                status_code=HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                detail=f"Image too large. Maximum size is {MAX_IMAGE_SIZE / (1024 * 1024):.1f} MB"
            )
        
        # Process the image with GPT-4o
        try:
            result = await call_gpt4o(image_b64)
            
            # Only return the result, do NOT write to CSV here
            return JSONResponse(
                content={
                    "success": True,
                    "data": result
                }
            )
        except Exception as e:
            print(f"Error processing image: {str(e)}")
            raise HTTPException(status_code=500, detail=str(e))
    except Exception as e:
        error_msg = str(e)
        print(f"Error in upload_image: {error_msg}")
        
        if "FULL RAW RESPONSE" in error_msg:
            # Extract the raw response from the error message
            raw_response = error_msg.split("FULL RAW RESPONSE:")[1].strip()
            
            # Create a minimal valid response
            return JSONResponse(
                content={
                    "success": False,
                    "error": "Failed to parse response from GPT-4o",
                    "data": {
                        "merchant": "",
                        "address": "",
                        "date": "",
                        "total": "",
                        "items": []
                    }
                }
            )
        
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/receipts/{filename}")
async def get_receipt_csv(filename: str):
    """Endpoint to download a receipt CSV file."""
    file_path = os.path.join("receipts", filename)
    if os.path.exists(file_path):
        return FileResponse(
            path=file_path,
            filename=filename,
            media_type="text/csv"
        )
    else:
        raise HTTPException(status_code=404, detail="Receipt file not found")

@app.get("/receipts")
async def get_all_receipts():
    """Endpoint to get all receipts data."""
    receipts_dir = "receipts"
    if not os.path.exists(receipts_dir):
        return JSONResponse(content={"receipts": []})
    
    header_path = os.path.join(receipts_dir, "header.csv")
    line_path = os.path.join(receipts_dir, "line.csv")
    
    if not os.path.exists(header_path) or not os.path.exists(line_path):
        return JSONResponse(content={"receipts": []})
    
    return JSONResponse(
        content={
            "success": True,
            "header_csv": "header.csv",
            "line_csv": "line.csv"
        }
    )

@app.post("/submit")
async def submit_receipt(request: Request):
    """Endpoint to submit a receipt for CSV export."""
    try:
        data = await request.json()
        
        # Validate the required fields
        required_fields = ["merchant", "address", "date", "total", "items"]
        for field in required_fields:
            if field not in data:
                raise HTTPException(status_code=400, detail=f"Missing required field: {field}")
        
        # Write the receipt data to CSV files
        result = write_receipt_to_csv(data)
        
        return JSONResponse(
            content={
                "success": True,
                "message": "Receipt data saved successfully",
                "header_csv": "header.csv",
                "line_csv": "line.csv"
            }
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
