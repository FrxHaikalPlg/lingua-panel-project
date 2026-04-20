import cv2
import numpy as np
import os
import shutil
import easyocr
import requests
from config import DEEPSEEK_API_KEY
from model_inference import get_bubble_detector, get_character_detector

DEEPSEEK_API_URL = "https://api.deepseek.com/v1/chat/completions"


def init_reader(languages=["ja", "en"]):
    """Initialize and return an EasyOCR reader."""
    print(f"Initializing EasyOCR reader with languages: {languages}")
    return easyocr.Reader(languages)


def check_background_color(image, threshold=0.6):
    """Return 'white' if the image background is predominantly light, else 'mixed'."""
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY) if len(image.shape) == 3 else image
    total_pixels = image.shape[0] * image.shape[1]
    light_pixels = cv2.countNonZero(cv2.threshold(gray, 200, 255, cv2.THRESH_BINARY)[1])
    return "white" if (light_pixels / total_pixels) > threshold else "mixed"


def invert_if_needed(image):
    """Invert image colors if the background is not white."""
    if check_background_color(image) != "white":
        return cv2.bitwise_not(image)
    return image


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
    """Detect text bubbles, crop, rotate, and save each bubble for OCR."""
    os.makedirs(output_base_dir, exist_ok=True)

    image = cv2.imread(image_path)
    if image is None:
        raise FileNotFoundError(f"Could not read image: {image_path}")

    detector = get_bubble_detector()
    predictions = detector.predict(image_path, confidence_threshold=0.6)

    crops = []
    for idx, pred in enumerate(predictions):
        if pred["class"] != "text_bubble":
            continue

        x1, y1, x2, y2 = pred["x1"], pred["y1"], pred["x2"], pred["y2"]
        w, h = pred["width"], pred["height"]

        if w < 20 or h < 20:
            continue

        cropped = image[y1:y2, x1:x2]
        rotated = cv2.rotate(cropped, cv2.ROTATE_90_COUNTERCLOCKWISE)
        final_crop = invert_if_needed(rotated)

        crop_path = os.path.join(output_base_dir, f"crop_{idx}.jpg")
        cv2.imwrite(crop_path, final_crop)

        crops.append({"path": crop_path, "bbox": [x1, y1, x2, y2], "image": final_crop})

    return crops


def perform_ocr(reader, image):
    """Run EasyOCR on an image and return results."""
    if image is None:
        return []
    rgb_image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
    return reader.readtext(rgb_image)


def translate_text(text, source_lang="Japanese", target_lang="English"):
    """Translate text using the DeepSeek API."""
    if not DEEPSEEK_API_KEY:
        raise ValueError("DEEPSEEK_API_KEY not configured")

    headers = {
        "Authorization": f"Bearer {DEEPSEEK_API_KEY}",
        "Content-Type": "application/json",
    }
    data = {
        "model": "deepseek-chat",
        "messages": [
            {
                "role": "system",
                "content": (
                    f"You are a professional translator. Translate the following {source_lang} "
                    f"text to {target_lang}. Handle OCR errors gracefully. "
                    "Provide only the translated text."
                ),
            },
            {"role": "user", "content": text},
        ],
        "temperature": 1.3,
    }

    try:
        response = requests.post(DEEPSEEK_API_URL, headers=headers, json=data)
        response.raise_for_status()
        return response.json()["choices"][0]["message"]["content"]
    except requests.exceptions.RequestException as e:
        print(f"Translation API error: {e}")
        return f"[Translation Failed] {text}"


def create_translated_panel(image, crops, translated_text):
    """Overlay translated text onto the original manga panel."""
    translated_panel = image.copy()

    # Parse structured translation response into a dict keyed by area index
    translation_by_area = {}
    current_area = None
    current_text = []
    for line in translated_text.split("\n"):
        if line.startswith("[Text Area #") and "]" in line:
            if current_area is not None and current_text:
                translation_by_area[current_area] = "\n".join(current_text).strip()
            try:
                current_area = int(line.split("#")[1].split("]")[0]) - 1
                current_text = []
            except (ValueError, IndexError):
                current_area = None
        elif current_area is not None:
            current_text.append(line)
    if current_area is not None and current_text:
        translation_by_area[current_area] = "\n".join(current_text).strip()

    for idx, text_to_draw in translation_by_area.items():
        if idx >= len(crops):
            continue

        x1, y1, x2, y2 = crops[idx]["bbox"]
        bubble_width = x2 - x1
        bubble_height = y2 - y1

        # White out the bubble area
        overlay = translated_panel.copy()
        cv2.rectangle(overlay, (x1, y1), (x2, y2), (255, 255, 255), -1)
        cv2.addWeighted(overlay, 0.9, translated_panel, 0.1, 0, translated_panel)

        # Text wrapping
        font = cv2.FONT_HERSHEY_SIMPLEX
        font_scale = max(0.5, min(1.2, min(bubble_width, bubble_height) / 250))
        thickness = 1

        lines = []
        current_line = ""
        for word in text_to_draw.replace("\n", " ").split(" "):
            test_line = f"{current_line} {word}".strip()
            (w, _), _ = cv2.getTextSize(test_line, font, font_scale, thickness)
            if w < bubble_width - 20:
                current_line = test_line
            else:
                lines.append(current_line)
                current_line = word
        if current_line:
            lines.append(current_line)

        line_height = cv2.getTextSize("A", font, font_scale, thickness)[0][1] + 5
        start_y = y1 + (bubble_height - line_height * len(lines)) // 2 + line_height

        for i, line in enumerate(lines):
            (lw, _), _ = cv2.getTextSize(line, font, font_scale, thickness)
            text_x = x1 + (bubble_width - lw) // 2
            text_y = start_y + i * line_height
            cv2.putText(translated_panel, line, (text_x, text_y), font, font_scale, (0, 0, 0), thickness + 1)
            cv2.putText(translated_panel, line, (text_x, text_y), font, font_scale, (255, 255, 255), thickness)

    return translated_panel


def run_translation_pipeline(image_path, lang="ja"):
    """Orchestrate the full manga translation pipeline."""
    base_dir = os.path.dirname(image_path)
    temp_crop_dir = os.path.join(base_dir, "temp_crops")
    temp_processed_dir = os.path.join(base_dir, "temp_processed")

    try:
        reader = init_reader([lang])
        original_image = cv2.imread(image_path)
        if original_image is None:
            raise FileNotFoundError("Original image not found or unreadable.")

        bubble_crops = process_manga_page(image_path, temp_crop_dir)
        if not bubble_crops:
            print("No text bubbles detected.")
            return image_path

        all_ocr_text = ""
        for idx, crop_info in enumerate(bubble_crops):
            processed_path = os.path.join(temp_processed_dir, f"processed_{idx}.jpg")
            os.makedirs(temp_processed_dir, exist_ok=True)

            rotated_result = process_image_with_rotation(crop_info["path"], processed_path)
            if not rotated_result:
                continue

            ocr_results = perform_ocr(reader, rotated_result["result"])
            if ocr_results:
                text = " ".join([res[1] for res in ocr_results])
                all_ocr_text += f"[Text Area #{idx + 1}]\n{text}\n\n"

        if not all_ocr_text.strip():
            print("No text found after OCR.")
            return image_path

        translated_text = translate_text(all_ocr_text)
        final_panel = create_translated_panel(original_image, bubble_crops, translated_text)

        output_path = os.path.join(base_dir, f"translated_{os.path.basename(image_path)}")
        cv2.imwrite(output_path, final_panel)
        return output_path

    finally:
        for temp_dir in [temp_crop_dir, temp_processed_dir]:
            if os.path.exists(temp_dir):
                shutil.rmtree(temp_dir)
