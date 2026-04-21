import cv2
import numpy as np
import os
import shutil
import textwrap
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

def init_reader(languages=["ja", "en"]):
    """Initialize and return an EasyOCR reader."""
    print(f"Initializing EasyOCR reader with languages: {languages}")
    return easyocr.Reader(languages)


def _ocr_raw(reader, image):
    """Run EasyOCR on a single image, returning results above confidence threshold."""
    if image is None:
        return []
    rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
    return [r for r in reader.readtext(rgb) if r[2] >= OCR_CONFIDENCE_THRESHOLD]


def perform_ocr(reader, image):
    """
    Run OCR with multiple preprocessing fallbacks to maximize recall.
    Tries in order:
      1. Image as-is
      2. CLAHE contrast enhancement
      3. 2× upscale (helps with small text)
      4. Otsu binarization
    Returns results from the first strategy that yields output.
    """
    if image is None:
        return []

    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)

    candidates = [
        image,  # 1. original
    ]

    # 2. CLAHE (adaptive contrast enhancement)
    clahe = cv2.createCLAHE(clipLimit=3.0, tileGridSize=(4, 4))
    enhanced = clahe.apply(gray)
    candidates.append(cv2.cvtColor(enhanced, cv2.COLOR_GRAY2BGR))

    # 3. Upscale 2× (helps when text is small)
    h, w = image.shape[:2]
    if max(h, w) < 300:
        up = cv2.resize(image, (w * 2, h * 2), interpolation=cv2.INTER_CUBIC)
        candidates.append(up)

    # 4. Otsu binarization
    _, binary = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
    candidates.append(cv2.cvtColor(binary, cv2.COLOR_GRAY2BGR))

    for img in candidates:
        results = _ocr_raw(reader, img)
        if results:
            return results

    return []


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


def process_manga_page(image_path, output_base_dir):
    """
    Detect text bubbles, crop each one, and return in manga reading order
    (right-to-left, top-to-bottom).
    """
    os.makedirs(output_base_dir, exist_ok=True)

    image = cv2.imread(image_path)
    if image is None:
        raise FileNotFoundError(f"Could not read image: {image_path}")

    img_w = image.shape[1]
    detector = get_bubble_detector()
    predictions = detector.predict(image_path, confidence_threshold=0.25)

    # Filter to text_bubble class only, skip tiny detections
    bubbles = [
        p for p in predictions
        if p["class"] == "text_bubble" and p["width"] >= 20 and p["height"] >= 20
    ]


    # Sort in manga reading order: top-to-bottom primary, right-to-left secondary
    # Divide page into horizontal bands (roughly 1/5 of page height each)
    band_height = max(1, image.shape[0] // 5)
    bubbles.sort(key=lambda p: (p["y1"] // band_height, -(p["x1"] + p["x2"]) / 2))

    crops = []
    for idx, pred in enumerate(bubbles):
        x1, y1, x2, y2 = pred["x1"], pred["y1"], pred["x2"], pred["y2"]

        cropped = image[y1:y2, x1:x2]
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


CHAPTER_BATCH_SIZE = 20  # max pages per DeepSeek call


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
            "max_tokens": 16000,
        }

        try:
            response = requests.post(DEEPSEEK_API_URL, headers=headers, json=data)
            response.raise_for_status()
            raw = response.json()["choices"][0]["message"]["content"]
            chunk_result = _parse_chapter_response(raw, [pi for pi, _ in chunk])
            result.update(chunk_result)
        except requests.exceptions.RequestException as e:
            print(f"Chapter translation API error (chunk {chunk_start}): {e}")
            # Fallback: mark all pages in this chunk as failed
            for page_idx, _ in chunk:
                result[page_idx] = f"[Translation Failed for page {page_idx + 1}]"

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
    Returns dict: {page_idx (0-based): text_block_with_[TextArea#N]_markers}
    """
    result: dict[int, str] = {}
    current_page_idx = None
    current_lines: list[str] = []

    for line in raw.split("\n"):
        if line.startswith("[Page #") and "]" in line:
            # Save previous page
            if current_page_idx is not None:
                result[current_page_idx] = "\n".join(current_lines).strip()
            try:
                page_num = int(line.split("#")[1].split("]")[0])
                current_page_idx = page_num - 1  # convert to 0-based
                current_lines = []
            except (ValueError, IndexError):
                current_page_idx = None
        elif current_page_idx is not None:
            current_lines.append(line)

    # Save last page
    if current_page_idx is not None:
        result[current_page_idx] = "\n".join(current_lines).strip()

    # Fill missing pages with empty string (no translation)
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
        return ImageFont.load_default()


def _fit_text_in_bubble(
    draw: ImageDraw.ImageDraw,
    text: str,
    bbox: list,
    padding: int = 10,
) -> tuple:
    """
    Find the largest font size where the wrapped text fits inside the bubble.
    Returns (font, wrapped_lines).
    """
    x1, y1, x2, y2 = bbox
    max_w = (x2 - x1) - padding * 2
    max_h = (y2 - y1) - padding * 2

    for font_size in range(20, 7, -1):
        font = _load_font(font_size, bold=False)
        # Estimate chars per line from max_w and average char width
        avg_char_w = font_size * 0.55
        chars_per_line = max(1, int(max_w / avg_char_w))
        lines = textwrap.wrap(text, width=chars_per_line)
        if not lines:
            continue
        # Measure actual rendered height
        line_h = font_size + 3
        total_h = line_h * len(lines)
        # Measure widest line
        widest = max(draw.textlength(line, font=font) for line in lines)
        if total_h <= max_h and widest <= max_w:
            return font, lines, line_h

    # Fallback: minimum font size, truncate lines
    font = _load_font(8)
    lines = textwrap.wrap(text, width=max(1, int(max_w / 5)))[:int(max_h / 11)]
    return font, lines, 11


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

def detect_and_ocr_page(image_path: str, reader, work_dir: str) -> tuple:
    """
    Run bubble detection + OCR for a single page.

    Returns:
        (crops, ocr_text) where:
        - crops: list of crop dicts (bbox, path, image)
        - ocr_text: formatted string with [Text Area #N] markers, or "" if nothing found
    """
    temp_crop_dir = os.path.join(work_dir, "crops")
    temp_proc_dir = os.path.join(work_dir, "processed")
    os.makedirs(temp_crop_dir, exist_ok=True)
    os.makedirs(temp_proc_dir, exist_ok=True)

    crops = process_manga_page(image_path, temp_crop_dir)
    ocr_text = ""

    for idx, crop_info in enumerate(crops):
        processed_path = os.path.join(temp_proc_dir, f"p_{idx}.jpg")
        rotated_result = process_image_with_rotation(crop_info["path"], processed_path)
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


# ---------------------------------------------------------------------------
# Single-image pipeline (used by /jobs/image and /translate_image)
# ---------------------------------------------------------------------------

def run_translation_pipeline(image_path, lang="ja", progress_callback=None, output_path=None):
    """
    Orchestrate the full manga translation pipeline for a single image.

    Args:
        image_path:        Path to the input image.
        lang:              EasyOCR source language code.
        progress_callback: Optional callable(message, step, total).
        output_path:       Where to save result (default: translated_{filename}).
    """
    def _report(message: str, step: int, total: int):
        if progress_callback:
            progress_callback(message, step, total)

    base_dir = os.path.dirname(image_path)
    temp_crop_dir = os.path.join(base_dir, "temp_crops")
    temp_processed_dir = os.path.join(base_dir, "temp_processed")

    try:
        reader = init_reader([lang])
        original_image = cv2.imread(image_path)
        if original_image is None:
            raise FileNotFoundError("Original image not found or unreadable.")

        _report("Detecting text bubbles...", 1, 4)
        bubble_crops = process_manga_page(image_path, temp_crop_dir)
        if not bubble_crops:
            print("No text bubbles detected.")
            return image_path

        _report("Running OCR...", 2, 4)
        all_ocr_text = ""
        for idx, crop_info in enumerate(bubble_crops):
            processed_path = os.path.join(temp_processed_dir, f"processed_{idx}.jpg")
            os.makedirs(temp_processed_dir, exist_ok=True)

            rotated_result = process_image_with_rotation(crop_info["path"], processed_path)
            if not rotated_result:
                continue

            ocr_results = perform_ocr(reader, rotated_result["result"])
            if not ocr_results:
                ocr_results = perform_ocr(reader, crop_info["image"])

            if ocr_results:
                text = " ".join(r[1] for r in ocr_results)
                all_ocr_text += f"[Text Area #{idx + 1}]\n{text}\n\n"

        if not all_ocr_text.strip():
            print("No text found after OCR.")
            return image_path

        _report("Translating...", 3, 4)
        translated_text = translate_text(all_ocr_text)

        _report("Rendering result...", 4, 4)
        final_panel = create_translated_panel(original_image, bubble_crops, translated_text)

        dest = output_path or os.path.join(
            os.path.dirname(image_path), f"translated_{os.path.basename(image_path)}"
        )
        cv2.imwrite(dest, final_panel)
        return dest

    finally:
        for temp_dir in [temp_crop_dir, temp_processed_dir]:
            if os.path.exists(temp_dir):
                shutil.rmtree(temp_dir)
