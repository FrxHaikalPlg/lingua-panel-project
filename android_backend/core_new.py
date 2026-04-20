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


def perform_ocr(reader, image):
    """Run EasyOCR on an image and return results above confidence threshold."""
    if image is None:
        return []
    rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
    results = reader.readtext(rgb)
    # Filter low-confidence detections (likely OCR noise)
    return [r for r in results if r[2] >= OCR_CONFIDENCE_THRESHOLD]


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
    predictions = detector.predict(image_path, confidence_threshold=0.5)

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
    predictions = detector.predict(image_path, confidence_threshold=0.4)

    # Filter to text_bubble class only, skip tiny detections
    bubbles = [
        p for p in predictions
        if p["class"] == "text_bubble" and p["width"] >= 20 and p["height"] >= 20
    ]
    print(f"Bubble detection: {len(bubbles)} text_bubble(s) found (from {len(predictions)} total predictions).")

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


def translate_text(text, source_lang="Japanese", target_lang="English"):
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
    }

    try:
        response = requests.post(DEEPSEEK_API_URL, headers=headers, json=data)
        response.raise_for_status()
        return response.json()["choices"][0]["message"]["content"]
    except requests.exceptions.RequestException as e:
        print(f"Translation API error: {e}")
        return f"[Translation Failed] {text}"


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


def draw_translated_text(pil_image: Image.Image, bbox: list, text: str) -> Image.Image:
    """
    White out a bubble region and draw translated text centered inside it.
    Uses Pillow for crisp, anti-aliased rendering.
    """
    x1, y1, x2, y2 = bbox
    bw = x2 - x1
    bh = y2 - y1
    padding = max(6, min(bw, bh) // 12)

    # White-out the bubble with a soft rounded rectangle
    overlay = Image.new("RGBA", pil_image.size, (0, 0, 0, 0))
    ov_draw = ImageDraw.Draw(overlay)
    radius = min(bw, bh) // 6
    ov_draw.rounded_rectangle([x1, y1, x2, y2], radius=radius, fill=(255, 255, 255, 230))
    pil_image = Image.alpha_composite(pil_image.convert("RGBA"), overlay).convert("RGB")

    draw = ImageDraw.Draw(pil_image)
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

    return pil_image


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
    pil_image = Image.fromarray(cv2.cvtColor(image_bgr, cv2.COLOR_BGR2RGB))

    overlaid = 0
    for idx, text_to_draw in translation_by_area.items():
        if idx >= len(crops) or not text_to_draw.strip():
            continue
        pil_image = draw_translated_text(pil_image, crops[idx]["bbox"], text_to_draw)
        overlaid += 1
    print(f"Text overlay: {overlaid}/{len(crops)} bubble(s) rendered.")

    # Convert back to BGR numpy array
    return cv2.cvtColor(np.array(pil_image), cv2.COLOR_RGB2BGR)

# ---------------------------------------------------------------------------
# Main pipeline
# ---------------------------------------------------------------------------

def run_translation_pipeline(image_path, lang="ja", progress_callback=None, output_path=None):
    """
    Orchestrate the full manga translation pipeline.

    Args:
        image_path:        Path to the input image.
        lang:              EasyOCR source language code.
        progress_callback: Optional callable(message, step, total) for progress reporting.
        output_path:       Where to save the translated image. Defaults to
                           translated_{filename} in the same directory.
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

        # Collect OCR text from all bubbles (sent together for page-level context)
        _report("Running OCR...", 2, 4)
        all_ocr_text = ""
        for idx, crop_info in enumerate(bubble_crops):
            processed_path = os.path.join(temp_processed_dir, f"processed_{idx}.jpg")
            os.makedirs(temp_processed_dir, exist_ok=True)

            rotated_result = process_image_with_rotation(crop_info["path"], processed_path)
            if not rotated_result:
                print(f"[DEBUG] Bubble #{idx + 1}: process_image_with_rotation returned None, skipping.")
                continue

            ocr_results = perform_ocr(reader, rotated_result["result"])
            if not ocr_results:
                # Fallback: OCR directly on the rotated crop (bypass character reconstruction)
                ocr_results = perform_ocr(reader, crop_info["image"])
            if ocr_results:
                text = " ".join(r[1] for r in ocr_results)
                all_ocr_text += f"[Text Area #{idx + 1}]\n{text}\n\n"

        print(f"OCR: extracted text from {all_ocr_text.count('[Text Area #')}/{len(bubble_crops)} bubble(s).")

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
