# Receipt Scanner Backend (FastAPI)

## Setup

1. Install dependencies:
   ```sh
   pip install -r requirements.txt
   ```
2. Copy `.env.example` to `.env` and add your OpenAI API key:
   ```sh
   cp .env.example .env
   # Edit .env and set OPENAI_API_KEY
   ```

## Run (development)

```sh
uvicorn main:app --host 0.0.0.0 --port 8000 --reload --ssl-keyfile=./key.pem --ssl-certfile=./cert.pem
```

- The server runs on HTTPS (required for secure image transfer).
- Images are not stored on server.
- Maximum file size: 4MB.

## Endpoint

POST `/upload` (multipart/form-data)
- Field: `file` (image/jpeg or image/png)
- Returns: Extracted JSON from GPT-4o

---

# Security Notes
- Use HTTPS in production (see above for local self-signed SSL).
- Never store uploaded images.
- Validate content-type and size.
