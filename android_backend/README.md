# LinguaPanel Backend

FastAPI-based translation pipeline for manga, manhwa, and manhua. Automatically detects text bubbles, reads text via OCR, translates using LLM, and renders the translated overlay back onto the original image.

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Web Framework | FastAPI + Uvicorn |
| Bubble Detection | YOLOv11 (custom fine-tuned) |
| Character Detection | ONNX Runtime |
| OCR Engine | EasyOCR |
| Translation | DeepSeek API |
| Image Processing | OpenCV, Pillow |
| Font Rendering | Noto Sans (bundled) |

## Pipeline Architecture

```
Input Image ──▶ Bubble Detection ──▶ OCR ──▶ Translation ──▶ Text Overlay ──▶ Output Image
                  (YOLOv11)        (EasyOCR)  (DeepSeek)      (Pillow)
```

### Vertical Mode (Manga / Manhua) — Default

For Japanese and Chinese comics where text runs top-to-bottom inside speech bubbles:

1. Detect text bubbles (YOLOv11)
2. Crop and rotate each bubble 90° counter-clockwise
3. Detect individual characters within the rotated crop (ONNX)
4. Rotate each character 90° clockwise onto a white canvas
5. Run OCR on the horizontally-arranged canvas
6. Translate → render overlay

### Horizontal Mode (Manhwa)

For Korean comics where text is already horizontal:

1. Detect text bubbles (YOLOv11)
2. Crop each bubble directly (no rotation)
3. Run OCR on the raw crop
4. Translate → render overlay

### Key Features

- **Auto-invert** — Dark bubbles (white text on black) are automatically inverted for reliable OCR
- **Dynamic font scaling** — Font size scales proportionally with bubble dimensions (8–60px range), preventing tiny text on high-resolution images
- **Pixel-accurate text wrapping** — Line breaks are calculated using actual rendered pixel widths, not character-count estimates
- **Two-pass rendering** — White backgrounds are composited first across all bubbles, then text is drawn on top. This prevents adjacent bubbles from overlapping each other's content
- **Retry with exponential backoff** — Translation API calls retry up to 3 times (5s → 10s → 20s) with per-page fallback on final failure
- **Batched translation** — Entire chapters are translated in a single API call, chunked into groups of 10 pages

## Project Structure

```
android_backend/
├── api.py                  # FastAPI routes and background job workers
├── core_new.py             # Core pipeline (detection, OCR, translation, overlay)
├── model_inference.py      # YOLODetector and ONNXDetector wrappers
├── job_manager.py          # In-memory job store with auto-cleanup (30 min TTL)
├── config.py               # Environment variable loader
├── requirements.txt        # Python dependencies
├── Dockerfile              # Production container image
├── .env.example            # Environment variable template
├── assets/
│   └── fonts/
│       ├── NotoSans-Regular.ttf
│       └── NotoSans-Bold.ttf
├── models/                 # Git-ignored — see Setup section
│   ├── best.pt             # YOLOv11 bubble detector (text_bubble, text_free)
│   └── character_detection.onnx
├── temp_images/            # Temporary upload storage (auto-cleaned)
└── temp_jobs/              # Per-job output directory (auto-cleaned after 30 min)
```

## API Reference

### Health Check

```http
GET /
```

Returns API version and link to interactive docs.

### Create Single Image Job

```http
POST /jobs/image?lang=ja&orientation=vertical
Content-Type: multipart/form-data

file: <image file>
```

Returns `{ "job_id": "...", "status": "queued" }`.

### Create Chapter Job

```http
POST /jobs/chapter?lang=ja&orientation=vertical
Content-Type: multipart/form-data

files[]: <image files or single .zip>
```

Accepts either multiple image files or a single `.zip` archive containing images. Files are sorted by filename to preserve page order.

Returns `{ "job_id": "...", "status": "queued", "total_pages": 29 }`.

### Job Status

```http
GET /jobs/{job_id}/status
```

Returns progress, status, and URLs for completed pages. Supports progressive display — pages become available as they finish rendering.

### Download Results

```http
GET /jobs/{job_id}/pages/{page}    # Single page
GET /jobs/{job_id}/download        # All pages as ZIP
```

### Delete Job

```http
DELETE /jobs/{job_id}
```

### Query Parameters

| Parameter | Values | Default | Description |
|-----------|--------|---------|-------------|
| `lang` | `ja`, `ko`, `ch_sim`, `en`, etc. | `ja` | OCR source language ([EasyOCR language codes](https://www.jaided.ai/easyocr/)) |
| `orientation` | `vertical`, `horizontal` | `vertical` | Text orientation in the source material |

### Supported Formats

`jpg`, `jpeg`, `png`, `webp`

## Setup

### 1. Environment Variables

```bash
cp .env.example .env
```

Edit `.env` and set your DeepSeek API key:

```
DEEPSEEK_API_KEY=sk-...
```

### 2. Model Files

Place the following files in `android_backend/models/`:

| File | Size | Purpose |
|------|------|---------|
| `best.pt` | ~19 MB | YOLOv11 bubble detection (classes: `text_bubble`, `text_free`) |
| `character_detection.onnx` | ~130 MB | Character-level detection for vertical text rotation |

> **Note:** Model files are git-ignored due to size. They must be manually placed or downloaded before running.

### 3. Install Dependencies

```bash
pip install -r requirements.txt
```

### 4. Run

```bash
# Development
python api.py
# → http://localhost:8080
# → Swagger UI at /docs

# Production (Docker)
docker build -t linguapanel-backend .
docker run -p 8080:8080 --env-file .env linguapanel-backend
```

## Configuration

| Setting | Location | Default | Description |
|---------|----------|---------|-------------|
| `DEEPSEEK_API_KEY` | `.env` | — | Required. Translation API key |
| `OCR_CONFIDENCE_THRESHOLD` | `core_new.py` | `0.35` | Minimum OCR confidence score |
| `JOB_TTL_SECONDS` | `job_manager.py` | `1800` | Auto-cleanup delay for completed jobs (seconds) |
| Bubble detection confidence | `core_new.py` | `0.5` | Minimum YOLO confidence for bubble detection |
| Character detection confidence | `core_new.py` | `0.35` | Minimum confidence for character-level detection |
