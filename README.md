# Receipt Scanner App

A full-stack receipt scanning application built with Flutter (frontend) and FastAPI (backend).

## Features

- 📷 Receipt image capture and processing
- 🤖 AI-powered data extraction using GPT-4o
- ✏️ Editable receipt data with add/remove line items
- 💾 Receipt storage and management
- 📊 Results dashboard with view/edit/delete functionality
- 📱 Responsive web interface

## Architecture

### Frontend (Flutter Web)
- Built with Flutter for web
- Responsive design with tabs interface
- Real-time calculations and form validation
- Hosted on AWS Amplify

### Backend (FastAPI + Python)
- RESTful API with FastAPI
- OpenAI GPT-4o integration for receipt processing
- CSV export functionality
- Deployed on AWS Lambda + API Gateway

## Local Development

### Prerequisites
- Flutter SDK
- Python 3.8+
- OpenAI API key

### Setup

1. **Backend Setup:**
   ```bash
   cd backend
   pip install -r requirements.txt
   cp .env.example .env  # Add your OpenAI API key
   uvicorn main:app --reload
   ```

2. **Frontend Setup:**
   ```bash
   cd frontend
   flutter pub get
   flutter run -d web-server
   ```

## Deployment

- **Frontend**: AWS Amplify
- **Backend**: AWS Lambda + API Gateway
- **Version Control**: AWS CodeCommit

## Environment Variables

- `OPENAI_API_KEY`: Your OpenAI API key for GPT-4o

## License

MIT License