# LinguaPanel — Manga Auto-Translation App

<p align="center">
  <strong>Translate manga, manhwa, and manhua pages instantly using AI-powered OCR and LLM translation.</strong>
</p>

LinguaPanel is a full-stack comic translation tool. Users upload manga pages, and the app automatically detects speech bubbles, performs OCR, translates the text, and renders the translation back onto the image — supporting both vertical (Japanese/Chinese) and horizontal (Korean) text orientations.

## How It Works

```
┌─────────────┐                        ┌──────────────────────┐
│  Flutter     │   Upload Pages        │  FastAPI Backend     │
│  Mobile App  │ ────────────────────▶ │                      │
│              │                        │  1. YOLOv11          │
│  • Auth      │ ◀──────────────────── │     (Bubble Detect)  │
│  • History   │   Translated Images   │  2. EasyOCR          │
│  • Theming   │                        │  3. DeepSeek LLM     │
└─────────────┘                        │  4. Pillow Overlay   │
       │                                └──────────────────────┘
       └──── Firebase (Auth + Storage) ────┘
```

## Features

### Mobile App (Flutter)
- **Authentication** — Email/Password & Google Sign-In with email verification
- **One-Tap Translation** — Pick image → translate → view result
- **Chapter Translation** — Upload multiple pages or ZIP archive for batch processing
- **Translation History** — Auto-saved with timestamps, deletable, favoritable
- **Theming** — Light, Dark, and System Default modes
- **About & Feedback** — In-app guide, rate, and email feedback

### Backend (Python)
- **Bubble Detection** — Custom YOLOv11 model detects speech bubbles and free text regions
- **OCR** — EasyOCR extracts text (Japanese, Korean, Chinese, English)
- **Orientation Support** — Vertical mode (manga/manhua) with character rotation, horizontal mode (manhwa) with direct OCR
- **AI Translation** — DeepSeek LLM translates entire chapters in a single batched API call
- **Smart Rendering** — Dynamic font scaling, pixel-accurate text wrapping, two-pass overlay to prevent adjacent bubble overlap
- **Async Jobs** — Background processing with real-time progress tracking and progressive page delivery

## Architecture

```
LinguaPanel/
├── linguapanel/                # Flutter mobile app (MVVM + Provider)
│   └── lib/
│       ├── core/
│       │   ├── config/         # App configuration (API URLs)
│       │   ├── services/       # Auth & History services
│       │   └── utils/          # Themes & UI helpers
│       └── features/
│           ├── auth/           # Login, Register, Forgot Password
│           ├── home/           # Image picker & translation
│           ├── history/        # Translation history & favorites
│           ├── settings/       # App settings
│           └── about/          # About page
│
├── android_backend/            # Python FastAPI backend
│   ├── api.py                  # HTTP routes & job workers
│   ├── core_new.py             # Translation pipeline
│   ├── model_inference.py      # YOLO & ONNX model wrappers
│   ├── job_manager.py          # Async job store with auto-cleanup
│   ├── config.py               # Environment variable loader
│   ├── Dockerfile              # Production container
│   └── models/                 # ML models (git-ignored)
│       ├── best.pt             # YOLOv11 bubble detection
│       └── character_detection.onnx
│
├── _debug_tools/               # Debug scripts & test images (git-ignored)
└── README.md
```

The Flutter app follows **MVVM (Model-View-ViewModel)** with the `provider` package for state management.

## Getting Started

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
# Edit .env and set your DeepSeek API key
```

### 3. ML Model Setup

Place the following model files in `android_backend/models/`:

| File | Size | Purpose |
|------|------|---------|
| `best.pt` | ~19 MB | YOLOv11 bubble detection (classes: `text_bubble`, `text_free`) |
| `character_detection.onnx` | ~130 MB | Character-level detection for vertical text rotation |

> **Note:** Model files are git-ignored due to size. Contact the repository owner for access, or train your own using the provided architecture.

```bash
# Start the server
python api.py
```

The backend will start at `http://localhost:8080`. Interactive API docs available at `/docs`.

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
docker run -p 8080:8080 --env-file .env linguapanel-api
```

## Tech Stack

| Layer | Technology |
|---|---|
| Mobile App | Flutter, Dart |
| State Management | Provider (MVVM) |
| Authentication | Firebase Auth |
| Database | Cloud Firestore |
| File Storage | Firebase Storage |
| Backend API | FastAPI, Python |
| Bubble Detection | YOLOv11 (custom fine-tuned) |
| Character Detection | ONNX Runtime |
| OCR | EasyOCR |
| Translation | DeepSeek API (LLM) |
| Deployment | Docker, Google Cloud Run |

## Environment Variables

### Backend (`android_backend/.env`)

| Variable | Description |
|---|---|
| `DEEPSEEK_API_KEY` | API key from [DeepSeek](https://platform.deepseek.com/) for LLM translation |

### Flutter (build-time)

| Variable | Description |
|---|---|
| `API_BASE_URL` | Backend server URL, passed via `--dart-define` |

## License

This project is for educational and portfolio purposes.
