# LinguaPanel — Manga Auto-Translation App

<p align="center">
  <strong>Translate manga panels instantly using AI-powered OCR and LLM translation.</strong>
</p>

LinguaPanel is a full-stack manga translation tool. Users can pick a manga panel from their gallery, and the app automatically detects text bubbles, performs OCR, translates the text, and renders the translation back onto the image — all in one tap.

## 🧩 How It Works

```
┌────────────┐    Upload Image    ┌─────────────────┐
│  Flutter    │ ───────────────► │  FastAPI Backend │
│  Mobile App │                   │                  │
│             │ ◄─────────────── │  1. Roboflow     │
│  • Auth     │  Translated Image │     (Bubble Det) │
│  • History  │                   │  2. EasyOCR      │
│  • Theming  │                   │  3. DeepSeek LLM │
└────────────┘                   └─────────────────┘
       │                                  │
       └──── Firebase (Auth + Storage) ───┘
```

## ✨ Features

### Mobile App (Flutter)
- **Authentication** — Email/Password & Google Sign-In with email verification
- **One-Tap Translation** — Pick image → translate → view result
- **Translation History** — Auto-saved with timestamps, deletable, favoritable
- **Theming** — Light, Dark, and System Default modes
- **About & Feedback** — In-app guide, rate, and email feedback

### Backend (Python)
- **Bubble Detection** — Roboflow ML model detects speech bubbles
- **OCR** — EasyOCR extracts text from manga panels (Japanese, Chinese, English)
- **AI Translation** — DeepSeek LLM translates with context awareness
- **Text Rendering** — Wraps and centers translated text back into bubbles

## 🏗️ Architecture

```
LinguaPanel/
├── linguapanel/              # Flutter mobile app (MVVM + Provider)
│   └── lib/
│       ├── core/
│       │   ├── config/       # App configuration (API URLs)
│       │   ├── services/     # Auth & History services
│       │   └── utils/        # Themes & UI helpers
│       └── features/
│           ├── auth/         # Login, Register, Forgot Password
│           ├── home/         # Image picker & translation
│           ├── history/      # Translation history & favorites
│           ├── settings/     # App settings
│           └── about/        # About page
│
├── android_backend/          # Python FastAPI backend
│   ├── api.py                # HTTP endpoint
│   ├── core_new.py           # Translation pipeline
│   ├── config.py             # Environment-based config
│   ├── Dockerfile            # Container deployment
│   └── .env.example          # Required env vars template
│
└── README.md                 # This file
```

The Flutter app follows **MVVM (Model-View-ViewModel)** with the `provider` package for state management.

## 🚀 Getting Started

### Prerequisites

- Flutter SDK 3.x+
- Python 3.11+
- A [Firebase](https://console.firebase.google.com/) project
- A [DeepSeek](https://platform.deepseek.com/) API key

---

### 1. Clone the Repository

```bash
git clone https://github.com/FrxHaikalPlg/lingua-panel-project.git
cd lingua-panel-project
```

### 2. Backend Setup

```bash
cd android_backend

# Create virtual environment
python -m venv venv
source venv/bin/activate   # Linux/Mac
# venv\Scripts\activate    # Windows

# Install dependencies
pip install -r requirements.txt

# Configure environment variables
cp .env.example .env
# Edit .env and fill in your DeepSeek API key
```

### 3. ML Model Setup

This project uses **custom fine-tuned RF-DETR** models for bubble detection and character detection, running locally via ONNX Runtime (no external API needed).

**Option A: Convert from PyTorch weights (if you have .pth files)**
```bash
# Install export dependencies (one-time)
pip install "rfdetr[onnxexport]"

# Run the conversion script
python convert_to_onnx.py
# This creates models/bubble_detection.onnx and models/character_detection.onnx
```

**Option B: Use pre-converted ONNX models**
Place the following files in `android_backend/models/`:
- `bubble_detection.onnx` — Text bubble detection model
- `character_detection.onnx` — Character/letter detection model

```bash
# Start the server
python api.py
```

The backend will start at `http://localhost:8080`.

### 4. Firebase Setup

1. Create a project on [Firebase Console](https://console.firebase.google.com/)
2. Enable **Email/Password** and **Google** sign-in methods in Authentication
3. Set up **Cloud Firestore** and **Firebase Storage**
4. Install the FlutterFire CLI and configure:

```bash
cd linguapanel
dart pub global activate flutterfire_cli
flutterfire configure
```

This generates `lib/firebase_options.dart` and `android/app/google-services.json` automatically.

> **Note:** A template file `lib/firebase_options_template.dart` is provided as reference for the expected structure.

### 5. Flutter App Setup

```bash
cd linguapanel

# Install dependencies
flutter pub get

# Run the app (with your backend URL)
flutter run --dart-define=API_BASE_URL=http://YOUR_BACKEND_URL:8080
```

For connecting to a local backend from an Android emulator:
```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

### 6. Docker Deployment (Optional)

```bash
cd android_backend
docker build -t linguapanel-api .
docker run -p 8080:8080 \
  -e ROBOFLOW_API_KEY=your_key \
  -e DEEPSEEK_API_KEY=your_key \
  linguapanel-api
```

## 📦 Tech Stack

| Layer | Technology |
|---|---|
| Mobile App | Flutter, Dart |
| State Management | Provider (MVVM) |
| Authentication | Firebase Auth |
| Database | Cloud Firestore |
| File Storage | Firebase Storage |
| Backend API | FastAPI, Python |
| Bubble Detection | Roboflow Inference SDK |
| OCR | EasyOCR |
| Translation | DeepSeek API (LLM) |
| Deployment | Docker, Google Cloud Run |

## 📝 Environment Variables

### Backend (`android_backend/.env`)

| Variable | Description |
|---|---|
| `ROBOFLOW_API_KEY` | API key from [Roboflow](https://roboflow.com/) for speech bubble detection |
| `DEEPSEEK_API_KEY` | API key from [DeepSeek](https://platform.deepseek.com/) for LLM translation |

### Flutter (build-time)

| Variable | Description |
|---|---|
| `API_BASE_URL` | Backend server URL, passed via `--dart-define` |

## 📄 License

This project is for educational and portfolio purposes.
