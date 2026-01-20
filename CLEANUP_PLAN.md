# Codebase Cleanup Plan

## Files to Remove

### 1. Abandoned WebSocket Implementation
- `lambda-backend/websocket_connect.py`
- `lambda-backend/websocket_connect.zip`
- `lambda-backend/websocket_connect_new.zip`
- `lambda-backend/websocket_connect_fixed.zip`
- `lambda-backend/websocket_disconnect.py`
- `lambda-backend/websocket_disconnect.zip`
- `lambda-backend/websocket_disconnect_new.zip`
- `lambda-backend/websocket_disconnect_fixed.zip`
- `lambda-backend/websocket_process.py`
- `lambda-backend/websocket_process.zip`
- `lambda-backend/websocket_process_new.zip`
- `lambda-backend/websocket_process_fixed.zip`
- `websocket-test.html`
- `WEBSOCKET_INTEGRATION.md`

**Reason**: WebSocket approach was abandoned due to 128KB message size limit

### 2. Old Lambda Deployment (OpenAI)
- `lambda-backend/receipt-scanner-lambda.zip`
- `lambda-backend/openai_client.py`

**Reason**: Switched to Mistral OCR, OpenAI no longer used

### 3. Backend Development Server Files
- `backend/` directory (entire folder)
- **Keep**: `.env.example` for reference

**Reason**: Using Lambda for production, local backend not needed

### 4. SSL Certificates (Security Risk)
- `backend/cert.pem`
- `backend/key.pem`

**Reason**: Should not be in version control, regenerate locally if needed

### 5. Test/Development Files
- `gpt4o_prompt.txt`
- `frontend/https_server.py`

**Reason**: Development artifacts no longer needed

### 6. Unused Lambda Backend Folder
- `lambda-backend/lambda-backend/` (nested folder)

**Reason**: Appears to be duplicate/unused

## Files to Keep

### Lambda Backend (Production)
- `lambda-backend/lambda_function.py`
- `lambda-backend/mistral_client.py`
- `lambda-backend/parse_response.py`
- `lambda-backend/requirements.txt`
- `lambda-backend/receipt-scanner-mistral.zip` (current deployment)
- `lambda-backend/deploy.sh`
- `lambda-backend/package/` (dependencies)

### Frontend
- `frontend/` (entire folder - active)

### Documentation
- `README.md`
- `BATCH_PROCESSING_DESIGN.md`
- `amplify.yml`

### Configuration
- `.gitignore`
- `.fvmrc`

## Actions to Take

1. Remove all WebSocket-related files
2. Remove old OpenAI implementation
3. Remove backend/ directory (keep .env.example in docs)
4. Remove SSL certificates
5. Remove test files
6. Update README.md to reflect current architecture
7. Update .gitignore to prevent future certificate commits
