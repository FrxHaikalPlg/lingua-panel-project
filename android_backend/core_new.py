import cv2
import numpy as np
import os
import shutil
import time
from concurrent.futures import ThreadPoolExecutor
import easyocr
import requests
from PIL import Image, ImageDraw, ImageFont
from config import DEEPSEEK_API_KEY
from model_inference import get_bubble_detector, get_character_detector

DEEPSEEK_API_URL = "https://api.deepseek.com/v1/chat/completions"

# Minimum EasyOCR confidence to accept a text detection
OCR_CONFIDENCE_THRESHOLD = 0.35
 
# Font paths bundled with the backend
_FONT_DIR = os.path.join(os.path.dirname(__file__), "assets", "fonts")
_FONT_REGULAR = os.path.join(_FONT_DIR, "NotoSans-Regular.ttf")
_FONT_BOLD = os.path.join(_FONT_DIR, "NotoSans-Bold.ttf")


# ---------------------------------------------------------------------------
# OCR
# ---------------------------------------------------------------------------

_reader_cache: dict = {}


def get_reader(lang: str = "ja") -> easyocr.Reader:
    """
    Return a cached EasyOCR reader for the given language.
    Initialized lazily on first call; subsequent calls return the same instance.
    """
    if lang not in _reader_cache:
        print(f"Initializing EasyOCR reader for language: {lang}")
        _reader_cache[lang] = easyocr.Reader([lang])
    return _reader_cache[lang]


def _ocr_raw(reader, image):
    """Run EasyOCR on a single image, returning results above confidence threshold.

    Filter logic:
      - Always accept if confidence >= OCR_CONFIDENCE_THRESHOLD
      - Also accept low-confidence results with more than 1 character
        (multi-char detections are almost never noise)
      - Reject only: confidence < threshold AND single character
    """
    if image is None:
        return []
    rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
    return [
        r for r in reader.readtext(rgb)
        if r[2] >= OCR_CONFIDENCE_THRESHOLD or len(r[1].strip()) > 1
    ]


def perform_ocr(reader, image, thorough: bool = False):
    """
    Run OCR on a preprocessed (rotated) bubble image.

    Args:
        thorough: If False (default), run OCR on the image as-is — fastest.
                  If True, try up to 4 preprocessing strategies for maximum recall:
                    1. Original  2. CLAHE  3. 2× upscale  4. Otsu binarization
    Returns results from the first strategy that yields output, or [] if all fail.
    """
    if image is None:
        return []

    if not thorough:
        return _ocr_raw(reader, image)

    # --- Thorough mode: try multiple preprocessing strategies ---
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)

    # 1. Original
    results = _ocr_raw(reader, image)
    if results:
        return results

    # 2. CLAHE contrast enhancement
    clahe = cv2.createCLAHE(clipLimit=3.0, tileGridSize=(4, 4))
    enhanced = cv2.cvtColor(clahe.apply(gray), cv2.COLOR_GRAY2BGR)
    results = _ocr_raw(reader, enhanced)
    if results:
        return results

    # 3. 2× upscale (helps with small text)
    h, w = image.shape[:2]
    if max(h, w) < 300:
        up = cv2.resize(image, (w * 2, h * 2), interpolation=cv2.INTER_CUBIC)
        results = _ocr_raw(reader, up)
        if results:
            return results

    # 4. Otsu binarization
    _, binary = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
    return _ocr_raw(reader, cv2.cvtColor(binary, cv2.COLOR_GRAY2BGR))



# ---------------------------------------------------------------------------
# Image helpers
# ---------------------------------------------------------------------------

def check_background_color(image, threshold=0.6):
    """Return 'white' if the image background is predominantly light."""
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY) if len(image.shape) == 3 else image
    total = image.shape[0] * image.shape[1]
    light = cv2.countNonZero(cv2.threshold(gray, 200, 255, cv2.THRESH_BINARY)[1])
    return "white" if (light / total) > threshold else "mixed"


def invert_if_needed(image):
    """Invert image colors if the background is not white."""
    return cv2.bitwise_not(image) if check_background_color(image) != "white" else image


# ---------------------------------------------------------------------------
# Detection & cropping
# ---------------------------------------------------------------------------

def process_image_with_rotation(image_path, output_path):
    """Detect characters, rotate vertical text, and place on a white background."""
    image = cv2.imread(image_path)
    if image is None:
        return None

    detector = get_character_detector()
    predictions = detector.predict(image_path, confidence_threshold=0.35)

    result_image = np.full_like(image, 255, dtype=np.uint8)
    letters_detected = []

    for pred in predictions:
        x1, y1, x2, y2 = pred["x1"], pred["y1"], pred["x2"], pred["y2"]
        letter_crop = image[y1:y2, x1:x2]
        letters_detected.append(pred)

        if pred["class"] == "letters":
            rotated = cv2.rotate(letter_crop, cv2.ROTATE_90_CLOCKWISE)
            rh, rw = rotated.shape[:2]
            if y1 + rh <= result_image.shape[0] and x1 + rw <= result_image.shape[1]:
                result_image[y1:y1 + rh, x1:x1 + rw] = rotated
        else:
            result_image[y1:y2, x1:x2] = letter_crop

    cv2.imwrite(output_path, result_image)
    return {"result": result_image, "letters": letters_detected}


def process_manga_page(image_path, output_base_dir, orientation="vertical"):
    """
    Detect text bubbles, crop each one, and return in reading order.

    Args:
        orientation: "vertical" (manga/manhua — rotate CCW) or
                     "horizontal" (manhwa — crop directly, no rotation)
    """
    os.makedirs(output_base_dir, exist_ok=True)

    image = cv2.imread(image_path)
    if image is None:
        raise FileNotFoundError(f"Could not read image: {image_path}")

    img_w = image.shape[1]
    detector = get_bubble_detector()
    predictions = detector.predict(image_path, confidence_threshold=0.5)

    # Accept both text_bubble and text_free classes, skip tiny detections
    bubbles = [
        p for p in predictions
        if p["class"] in ("text_bubble", "text_free")
        and p["width"] >= 20 and p["height"] >= 20
    ]

    # Reading order depends on orientation:
    # vertical (manga/manhua): right-to-left, top-to-bottom
    # horizontal (manhwa):     left-to-right, top-to-bottom
    band_height = max(1, image.shape[0] // 5)
    if orientation == "horizontal":
        bubbles.sort(key=lambda p: (p["y1"] // band_height, (p["x1"] + p["x2"]) / 2))
    else:
        bubbles.sort(key=lambda p: (p["y1"] // band_height, -(p["x1"] + p["x2"]) / 2))

    crops = []
    for idx, pred in enumerate(bubbles):
        x1, y1, x2, y2 = pred["x1"], pred["y1"], pred["x2"], pred["y2"]
        cropped = image[y1:y2, x1:x2]

        if orientation == "horizontal":
            # Manhwa: text is already horizontal, no rotation needed
            final_crop = invert_if_needed(cropped)
        else:
            # Manga/Manhua: vertical text → rotate CCW to make it horizontal
            rotated = cv2.rotate(cropped, cv2.ROTATE_90_COUNTERCLOCKWISE)
            final_crop = invert_if_needed(rotated)

        crop_path = os.path.join(output_base_dir, f"crop_{idx}.jpg")
        cv2.imwrite(crop_path, final_crop)
        crops.append({"path": crop_path, "bbox": [x1, y1, x2, y2], "image": final_crop})

    return crops



# ---------------------------------------------------------------------------
# Translation
# ---------------------------------------------------------------------------

SYSTEM_PROMPT = """You are a professional manga translator specializing in Japanese-to-English localization.

The source text comes from OCR and may contain recognition errors: wrong kanji, fragmented words, or missing characters. Your job is to infer the correct meaning and produce a natural English translation.

Rules:
- Use casual, natural English — manga characters speak informally, not formally
- Preserve emotional tone and intensity (shock, hesitation, excitement, etc.)
- Transliterate or translate sound effects/onomatopoeia naturally (e.g. ドキドキ → "thump thump")
- If a text area is too garbled to translate confidently, make your best inference — never skip or output "N/A"
- Preserve the [Text Area #N] markers exactly as given in your output
- Return only the translated text with [Text Area #N] markers, nothing else"""

SYSTEM_PROMPT_CHAPTER = """You are a professional manga translator specializing in Japanese-to-English localization.

The source text spans multiple pages of a manga chapter. Each page is marked with [Page #N] and each bubble with [Text Area #N]. Text comes from OCR and may contain recognition errors.

Rules:
- Use casual, natural English — manga characters speak informally, not formally
- Preserve emotional tone and intensity across the whole chapter
- Use consistent character names and speech patterns throughout all pages
- Transliterate or translate sound effects/onomatopoeia naturally
- If a text area is too garbled, make your best inference — never skip or output "N/A"
- Preserve BOTH [Page #N] and [Text Area #N] markers exactly in your output
- Return only the translated text with markers, nothing else"""


def translate_text(text, source_lang="Japanese", target_lang="English", max_tokens=8000):
    """Translate OCR text using the DeepSeek API with a manga-optimized prompt."""
    if not DEEPSEEK_API_KEY:
        raise ValueError("DEEPSEEK_API_KEY not configured")

    headers = {
        "Authorization": f"Bearer {DEEPSEEK_API_KEY}",
        "Content-Type": "application/json",
    }
    data = {
        "model": "deepseek-chat",
        "messages": [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": f"Translate the following {source_lang} manga text to {target_lang}:\n\n{text}"},
        ],
        "temperature": 0.8,
        "max_tokens": max_tokens,
    }

    try:
        response = requests.post(DEEPSEEK_API_URL, headers=headers, json=data)
        response.raise_for_status()
        return response.json()["choices"][0]["message"]["content"]
    except requests.exceptions.RequestException as e:
        print(f"Translation API error: {e}")
        return f"[Translation Failed] {text}"


CHAPTER_BATCH_SIZE = 15  # max pages per DeepSeek call


def translate_chapter(pages_ocr: dict, source_lang="Japanese", target_lang="English") -> dict:
    """
    Translate OCR text from multiple pages in a single (or chunked) API call.

    Args:
        pages_ocr: dict mapping page_index (0-based) -> ocr_text_block
                   e.g. {0: "[Text Area #1]\nhoge\n", 1: "[Text Area #1]\nfoo\n"}
    Returns:
        dict mapping page_index -> translated_text_block (same [Text Area #N] format)
    """
    if not DEEPSEEK_API_KEY:
        raise ValueError("DEEPSEEK_API_KEY not configured")

    sorted_pages = sorted(pages_ocr.items())  # [(page_idx, ocr_text), ...]
    result: dict[int, str] = {}

    # Auto-chunk if more than CHAPTER_BATCH_SIZE pages
    for chunk_start in range(0, len(sorted_pages), CHAPTER_BATCH_SIZE):
        chunk = sorted_pages[chunk_start: chunk_start + CHAPTER_BATCH_SIZE]

        # Build multi-page prompt block
        prompt_block = ""
        for page_idx, ocr_text in chunk:
            prompt_block += f"[Page #{page_idx + 1}]\n{ocr_text}\n"

        headers = {
            "Authorization": f"Bearer {DEEPSEEK_API_KEY}",
            "Content-Type": "application/json",
        }
        data = {
            "model": "deepseek-chat",
            "messages": [
                {"role": "system", "content": SYSTEM_PROMPT_CHAPTER},
                {"role": "user", "content": (
                    f"Translate the following {source_lang} manga chapter excerpt to {target_lang}.\n"
                    f"Maintain consistent character voices across all pages.\n\n{prompt_block}"
                )},
            ],
            "temperature": 0.8,
            "max_tokens": 8000,  # DeepSeek-V3 hard limit is 8192
        }

        # Retry up to 3 times with exponential backoff on 504 / timeout
        MAX_RETRIES = 3
        for attempt in range(MAX_RETRIES):
            try:
                response = requests.post(
                    DEEPSEEK_API_URL, headers=headers, json=data, timeout=90
                )
                if not response.ok:
                    print(f"[translate_chapter] API error {response.status_code}: {response.text[:200]}")
                    response.raise_for_status()
                raw = response.json()["choices"][0]["message"]["content"]
                chunk_result = _parse_chapter_response(raw, [pi for pi, _ in chunk])
                result.update(chunk_result)
                break  # success — exit retry loop

            except requests.exceptions.RequestException as e:
                is_last = (attempt == MAX_RETRIES - 1)
                wait = 5 * (2 ** attempt)  # 5s, 10s, 20s
                if is_last:
                    print(f"Chapter translation failed after {MAX_RETRIES} attempts (chunk {chunk_start}): {e}")
                    # Last resort: translate each page individually
                    for page_idx, ocr_text in chunk:
                        try:
                            translated = translate_text(ocr_text, source_lang, target_lang)
                            result[page_idx] = translated
                        except Exception:
                            result[page_idx] = ""
                else:
                    print(f"[translate_chapter] attempt {attempt+1} failed, retrying in {wait}s… ({e})")
                    time.sleep(wait)

    return result


def _parse_chapter_response(raw: str, expected_page_indices: list) -> dict:
    """
    Parse a multi-page DeepSeek response into per-page text blocks.
    Expected format:
        [Page #1]
        [Text Area #1]
        translated...
        [Page #2]
        ...
    Falls back gracefully when DeepSeek omits [Page #N] markers.
    """
    result: dict[int, str] = {}
    current_page_idx = None
    current_lines: list[str] = []

    for line in raw.split("\n"):
        # Handle both "[Page #1]" alone and "[Page #1][Text Area #1]..." on same line
        stripped = line.strip()
        if stripped.startswith("[Page #") and "]" in stripped:
            if current_page_idx is not None:
                result[current_page_idx] = "\n".join(current_lines).strip()
            try:
                page_num = int(stripped.split("#")[1].split("]")[0])
                current_page_idx = page_num - 1
                # If the rest of the line has more content (e.g. [Text Area #1]), keep it
                rest = stripped[stripped.index("]") + 1:].strip()
                current_lines = [rest] if rest else []
            except (ValueError, IndexError):
                current_page_idx = None
        elif current_page_idx is not None:
            current_lines.append(line)

    if current_page_idx is not None:
        result[current_page_idx] = "\n".join(current_lines).strip()

    # Fallback: if no [Page #N] markers found but we have exactly 1 expected page,
    # treat the entire response as that page's translation.
    if not result and len(expected_page_indices) == 1:
        print("[_parse_chapter_response] No [Page #N] markers found. Using full response as page 1.")
        result[expected_page_indices[0]] = raw.strip()

    # Fill missing pages with empty string
    for pi in expected_page_indices:
        result.setdefault(pi, "")

    return result


# ---------------------------------------------------------------------------
# Text overlay (Pillow-based)
# ---------------------------------------------------------------------------

def _load_font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    """Load NotoSans at a given size, with fallback to Pillow default."""
    font_path = _FONT_BOLD if bold else _FONT_REGULAR
    try:
        return ImageFont.truetype(font_path, size)
    except (IOError, OSError):
        print(f"[FONT ERROR] Failed to load '{font_path}' at size={size} — using default")
        return ImageFont.load_default()


def _wrap_text_pixels(draw, text: str, font, max_w: float) -> list:
    """Word-wrap text so no line exceeds max_w pixels (actual measurement)."""
    words = text.split()
    if not words:
        return []
    space_w = draw.textlength(" ", font=font)
    lines = []
    current_words = []
    current_w = 0.0
    for word in words:
        word_w = draw.textlength(word, font=font)
        needed = current_w + (space_w + word_w if current_words else word_w)
        if needed <= max_w or not current_words:
            current_words.append(word)
            current_w = needed
        else:
            lines.append(" ".join(current_words))
            current_words = [word]
            current_w = word_w
    if current_words:
        lines.append(" ".join(current_words))
    return lines


def _fit_text_in_bubble(
    draw: ImageDraw.ImageDraw,
    text: str,
    bbox: list,
    padding: int = 10,
) -> tuple:
    """
    Find the largest font size where the wrapped text fits inside the bubble.
    Font range scales with bubble size so high-res images get proportionally
    larger text instead of a fixed 8-20px cap.
    Returns (font, wrapped_lines, line_height).
    """
    x1, y1, x2, y2 = bbox
    bubble_w = x2 - x1
    bubble_h = y2 - y1
    max_w = bubble_w - padding * 2
    max_h = bubble_h - padding * 2

    if not text.strip():
        return _load_font(10), [], 13

    # Dynamic font range based on bubble dimensions
    # Target: font ≈ bubble_height / 10, so ~5-6 lines fill the bubble
    font_max = max(20, min(60, bubble_h // 8))
    font_min = max(8, font_max // 3)

    for font_size in range(font_max, font_min - 1, -1):
        font   = _load_font(font_size, bold=False)
        line_h = font_size + 4
        lines  = _wrap_text_pixels(draw, text, font, max_w)
        if not lines:
            continue
        total_h = line_h * len(lines)
        widest  = max(draw.textlength(ln, font=font) for ln in lines)
        if total_h <= max_h and widest <= max_w:
            return font, lines, line_h

    # Fallback: minimum font, truncate to available height
    print(
        f"[FONT FALLBACK] bbox={bbox} max_w={max_w:.0f} max_h={max_h:.0f} "
        f"text_len={len(text)} text={text[:60]!r}"
    )

    font   = _load_font(8)
    line_h = 11
    lines  = _wrap_text_pixels(draw, text, font, max_w)
    max_lines = max(1, int(max_h / line_h))
    return font, lines[:max_lines], line_h




def _draw_bubble_background(overlay_draw: ImageDraw.ImageDraw, bbox: list):
    """Draw a white rounded-rectangle background for a bubble onto an RGBA overlay."""
    x1, y1, x2, y2 = bbox
    bw, bh = x2 - x1, y2 - y1
    radius = min(bw, bh) // 6
    overlay_draw.rounded_rectangle([x1, y1, x2, y2], radius=radius, fill=(255, 255, 255, 230))


def _draw_bubble_text(draw: ImageDraw.ImageDraw, bbox: list, text: str):
    """Draw translated text centered inside a bubble (no background — drawn separately)."""
    x1, y1, x2, y2 = bbox
    bw, bh = x2 - x1, y2 - y1
    padding = max(6, min(bw, bh) // 12)

    font, lines, line_h = _fit_text_in_bubble(draw, text, bbox, padding)

    total_text_h = line_h * len(lines)
    start_y = y1 + padding + (bh - padding * 2 - total_text_h) // 2

    for i, line in enumerate(lines):
        line_w = draw.textlength(line, font=font)
        tx = x1 + padding + (bw - padding * 2 - line_w) // 2
        ty = start_y + i * line_h
        # Subtle shadow for readability
        draw.text((tx + 1, ty + 1), line, font=font, fill=(180, 180, 180))
        draw.text((tx, ty), line, font=font, fill=(20, 20, 20))


def create_translated_panel(image_bgr, crops, translated_text):
    """Overlay translated text bubbles onto the original manga panel."""
    # Parse [Text Area #N] blocks from DeepSeek response
    translation_by_area = {}
    current_area = None
    current_text = []
    for line in translated_text.split("\n"):
        if line.startswith("[Text Area #") and "]" in line:
            if current_area is not None and current_text:
                translation_by_area[current_area] = " ".join(
                    " ".join(current_text).split()
                )
            try:
                current_area = int(line.split("#")[1].split("]")[0]) - 1
                current_text = []
            except (ValueError, IndexError):
                current_area = None
        elif current_area is not None:
            current_text.append(line)
    if current_area is not None and current_text:
        translation_by_area[current_area] = " ".join(" ".join(current_text).split())

    # Convert BGR → PIL RGBA for compositing
    pil_image = Image.fromarray(cv2.cvtColor(image_bgr, cv2.COLOR_BGR2RGB)).convert("RGBA")

    # --- Pass 1: Draw ALL white backgrounds first ---
    # Using a single shared overlay so all backgrounds are composited together
    # before any text is drawn. This prevents adjacent bubbles from covering
    # each other's text.
    bg_overlay = Image.new("RGBA", pil_image.size, (0, 0, 0, 0))
    bg_draw = ImageDraw.Draw(bg_overlay)
    valid_entries = [
        (idx, text_to_draw)
        for idx, text_to_draw in translation_by_area.items()
        if idx < len(crops) and text_to_draw.strip()
    ]
    for idx, _ in valid_entries:
        _draw_bubble_background(bg_draw, crops[idx]["bbox"])
    pil_image = Image.alpha_composite(pil_image, bg_overlay).convert("RGB")

    # --- Pass 2: Draw ALL text on top ---
    text_draw = ImageDraw.Draw(pil_image)
    for idx, text_to_draw in valid_entries:
        _draw_bubble_text(text_draw, crops[idx]["bbox"], text_to_draw)

    # Convert back to BGR numpy array
    return cv2.cvtColor(np.array(pil_image), cv2.COLOR_RGB2BGR)

# ---------------------------------------------------------------------------
# Chapter pipeline helpers (used by api.py job worker)
# ---------------------------------------------------------------------------

def detect_and_ocr_page(image_path: str, reader, work_dir: str, orientation: str = "vertical") -> tuple:
    """
    Run bubble detection + OCR for a single page.

    Args:
        orientation: "vertical" (manga/manhua) or "horizontal" (manhwa).
          - vertical:   bubble crop → character rotation (parallel) → OCR
          - horizontal: bubble crop → OCR directly (skip rotation)

    Returns:
        (crops, ocr_text)
    """
    temp_crop_dir = os.path.join(work_dir, "crops")
    temp_proc_dir = os.path.join(work_dir, "processed")
    os.makedirs(temp_crop_dir, exist_ok=True)
    os.makedirs(temp_proc_dir, exist_ok=True)

    crops = process_manga_page(image_path, temp_crop_dir, orientation=orientation)

    if not crops:
        return crops, ""

    ocr_text = ""

    if orientation == "horizontal":
        # ── Horizontal (manhwa): OCR directly on bubble crops ──────────────
        for idx, crop_info in enumerate(crops):
            ocr_results = perform_ocr(reader, crop_info["image"])
            if ocr_results:
                text = " ".join(r[1] for r in ocr_results)
                ocr_text += f"[Text Area #{idx + 1}]\n{text}\n\n"
    else:
        # ── Vertical (manga/manhua): parallel character rotation → OCR ────
        def _rotate(args):
            idx, crop_info = args
            processed_path = os.path.join(temp_proc_dir, f"p_{idx}.jpg")
            return idx, process_image_with_rotation(crop_info["path"], processed_path)

        n_workers = min(4, len(crops))
        with ThreadPoolExecutor(max_workers=n_workers) as executor:
            rotation_results = dict(executor.map(_rotate, enumerate(crops)))

        for idx, crop_info in enumerate(crops):
            rotated_result = rotation_results.get(idx)
            if not rotated_result:
                continue

            ocr_results = perform_ocr(reader, rotated_result["result"])
            if not ocr_results:
                ocr_results = perform_ocr(reader, crop_info["image"])

            if ocr_results:
                text = " ".join(r[1] for r in ocr_results)
                ocr_text += f"[Text Area #{idx + 1}]\n{text}\n\n"

    # Cleanup intermediate crops
    shutil.rmtree(temp_crop_dir, ignore_errors=True)
    shutil.rmtree(temp_proc_dir, ignore_errors=True)

    return crops, ocr_text




def apply_translation_overlay(image_path: str, crops: list, translated_text: str, output_path: str) -> str:
    """
    Apply translated text overlay onto a manga page and save the result.

    Args:
        image_path:       Path to the original input image.
        crops:            Crop list returned by detect_and_ocr_page.
        translated_text:  Translated text block with [Text Area #N] markers.
        output_path:      Where to save the result.
    Returns:
        output_path
    """
    image = cv2.imread(image_path)
    if image is None:
        raise FileNotFoundError(f"Cannot read image: {image_path}")

    if not translated_text.strip() or not crops:
        cv2.imwrite(output_path, image)
        return output_path

    final = create_translated_panel(image, crops, translated_text)
    cv2.imwrite(output_path, final)
    return output_path

