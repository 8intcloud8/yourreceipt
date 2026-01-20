# Receipt Scanner App

A full-stack receipt scanning application built with Flutter (frontend) and AWS Lambda (backend).

## Features

- 📷 Receipt image capture and processing
- 🤖 AI-powered data extraction using Mistral OCR
- ✏️ Editable receipt data with add/remove line items
- 💾 Receipt storage and management
- 📊 Results dashboard with view/edit/delete functionality
- 📱 Responsive web interface
- 🔍 Zoom and pan on receipt images

## Architecture

### Frontend (Flutter Web)
- Built with Flutter for web
- Responsive design with tabs interface
- Real-time calculations and form validation
- Image zoom and pan with InteractiveViewer
- User authentication with AWS Cognito
- Hosted on AWS Amplify
- **Live URL**: https://yourreceipt.online

### Backend (AWS Lambda + API Gateway)
- Serverless architecture with AWS Lambda
- Mistral OCR API integration for receipt processing
- RESTful API via API Gateway
- 180-second timeout for large image processing
- No data storage on server (privacy-focused)

## Tech Stack

- **Frontend**: Flutter Web, Dart
- **Backend**: Python 3.12, AWS Lambda
- **AI/OCR**: Mistral OCR (mistral-ocr-latest model)
- **Infrastructure**: AWS (Amplify, Lambda, API Gateway, Cognito, Route53)
- **Version Control**: GitHub

## Local Development

### Prerequisites
- Flutter SDK
- Python 3.12+
- Mistral API key

### Frontend Setup
```bash
cd frontend
flutter pub get
flutter run -d chrome
```

### Lambda Backend (Local Testing)
```bash
cd lambda-backend
pip install -r requirements.txt -t package/
# Set environment variable
export MISTRAL_API_KEY="your-api-key"
# Test locally
python lambda_function.py
```

## Deployment

### Frontend Deployment
- Automatically deployed via AWS Amplify on push to `main` branch
- Build configuration in `amplify.yml`

### Backend Deployment
```bash
cd lambda-backend
./deploy.sh  # Creates zip and updates Lambda function
```

Or manually:
```bash
cd lambda-backend
zip -r receipt-scanner-mistral.zip lambda_function.py mistral_client.py parse_response.py package/
aws lambda update-function-code --function-name receipt-scanner-api --zip-file fileb://receipt-scanner-mistral.zip --profile ammarwm --region ap-southeast-2
```

## Environment Variables

### Lambda Function
- `MISTRAL_API_KEY`: Retrieved from AWS Secrets Manager (`ReconcileAI/mistral/api-key`)

### Frontend
- No environment variables needed (API endpoint hardcoded)

## API Endpoints

### POST /upload
- **URL**: `https://keg1z88aee.execute-api.ap-southeast-2.amazonaws.com/prod/upload`
- **Method**: POST
- **Body**: `{"image_base64": "base64-encoded-image"}`
- **Response**: Structured JSON with receipt data

## Project Structure

```
yourreceipt/
├── frontend/              # Flutter web application
│   ├── lib/
│   │   ├── main.dart     # Main app with tabs and receipt processing
│   │   ├── auth_service.dart  # AWS Cognito authentication
│   │   └── login_screen.dart  # Login/signup UI
│   └── web/              # Web assets
├── lambda-backend/       # AWS Lambda function
│   ├── lambda_function.py     # Main Lambda handler
│   ├── mistral_client.py      # Mistral OCR integration
│   ├── parse_response.py      # Response parser
│   ├── requirements.txt       # Python dependencies
│   ├── package/              # Installed dependencies
│   └── deploy.sh             # Deployment script
├── amplify.yml           # AWS Amplify build configuration
├── BATCH_PROCESSING_DESIGN.md  # Future feature design
└── README.md            # This file
```

## Future Enhancements

See `BATCH_PROCESSING_DESIGN.md` for planned batch processing feature.

## License

MIT License