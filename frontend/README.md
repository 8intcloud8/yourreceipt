# Receipt Scanner Frontend (Flutter)

## Setup

1. Install dependencies:
   ```sh
   flutter pub get
   ```
2. Add iOS/Android camera permissions as required by `image_picker`.

## Run

```sh
flutter run
```

## Configuration
- Update the backend URL in `main.dart` (`https://your-backend-domain.com/upload`) to your FastAPI server address (must be HTTPS).

## Features
- Capture receipt image using camera.
- Upload to backend via HTTPS.
- Display extracted JSON or error if malformed.

---

# Security Notes
- Uses HTTPS for all network requests.
- Validates server response before display.
