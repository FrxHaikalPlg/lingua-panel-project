
import cv2
import numpy as np
import os
import easyocr
import requests
from config import DEEPSEEK_API_KEY
from model_inference import get_bubble_detector, get_character_detector

DEEPSEEK_API_URL = "https://api.deepseek.com/v1/chat/completions"


def init_reader(languages=['ja','en']):
    """Inisialisasi dan mengembalikan EasyOCR reader."""
    print(f"Initializing EasyOCR reader with languages: {languages}")
    return easyocr.Reader(languages)

def check_background_color(image, threshold=0.6):
    """Mengecek apakah gambar memiliki latar belakang dominan putih atau hitam."""
    if len(image.shape) == 3:
        gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    else:
        gray = image
    
    total_pixels = image.shape[0] * image.shape[1]
    light_pixels = cv2.countNonZero(cv2.threshold(gray, 200, 255, cv2.THRESH_BINARY)[1])
    
    if (light_pixels / total_pixels) > threshold:
        return 'white'
    else:
        return 'mixed' # Atau 'black', tapi 'mixed' lebih aman

def invert_if_needed(image):
    """Inversi gambar jika latar belakangnya bukan putih."""
    if check_background_color(image) != 'white':
        return cv2.bitwise_not(image)
    return image

def process_image_with_rotation(image_path, output_path):
    """Deteksi huruf, rotasi, dan menempatkannya di latar belakang putih."""
    image = cv2.imread(image_path)
    if image is None:
        return None

    detector = get_character_detector()
    predictions = detector.predict(image_path, confidence_threshold=0.5)

    # Latar belakang putih bersih
    result_image = np.full_like(image, 255, dtype=np.uint8)

    letters_detected = []
    for pred in predictions:
        x, y, w, h = pred['x'], pred['y'], pred['width'], pred['height']
        x1, y1 = pred['x1'], pred['y1']
        x2, y2 = pred['x2'], pred['y2']

        letter_crop = image[y1:y2, x1:x2]
        letters_detected.append(pred)

        if pred['class'] == 'letters':
            rotated = cv2.rotate(letter_crop, cv2.ROTATE_90_CLOCKWISE)
            rh, rw = rotated.shape[:2]
            if y1 + rh <= result_image.shape[0] and x1 + rw <= result_image.shape[1]:
                result_image[y1:y1+rh, x1:x1+rw] = rotated
        else:
            result_image[y1:y2, x1:x2] = letter_crop

    cv2.imwrite(output_path, result_image)
    return {'result': result_image, 'letters': letters_detected}

def process_manga_page(image_path, output_base_dir):
    """Deteksi balon teks, potong, dan proses."""
    os.makedirs(output_base_dir, exist_ok=True)
    
    image = cv2.imread(image_path)
    if image is None:
        raise FileNotFoundError(f"Could not read image: {image_path}")

    # Deteksi balon teks menggunakan local ONNX model
    detector = get_bubble_detector()
    predictions = detector.predict(image_path, confidence_threshold=0.6)

    crops = []
    for idx, pred in enumerate(predictions):
        # Filter hanya class 'text_bubble' (class_id 0)
        if pred['class'] != 'text_bubble':
            continue

        x, y, w, h = pred['x'], pred['y'], pred['width'], pred['height']
        x1, y1 = pred['x1'], pred['y1']
        x2, y2 = pred['x2'], pred['y2']

        if w < 20 or h < 20:
            continue

        # Potong, rotasi, dan inversi jika perlu
        cropped_image = image[y1:y2, x1:x2]
        rotated_image = cv2.rotate(cropped_image, cv2.ROTATE_90_COUNTERCLOCKWISE)
        final_crop = invert_if_needed(rotated_image)

        # Simpan hasil crop sementara untuk diproses lebih lanjut
        crop_filename = f"crop_{idx}.jpg"
        crop_path = os.path.join(output_base_dir, crop_filename)
        cv2.imwrite(crop_path, final_crop)

        crops.append({
            'path': crop_path,
            'bbox': [x1, y1, x2, y2],
            'image': final_crop
        })
    
    return crops

def perform_ocr(reader, image):
    """Melakukan OCR pada gambar dan mengembalikan teks."""
    if image is None:
        return []
    # Konversi ke RGB karena EasyOCR mengharapkannya
    rgb_image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
    results = reader.readtext(rgb_image)
    return results

def translate_text(text, source_lang='Japanese', target_lang='English'):
    """Menerjemahkan teks menggunakan DeepSeek API."""
    if not DEEPSEEK_API_KEY:
        raise ValueError("DEEPSEEK_API_KEY not configured")

    headers = {
        "Authorization": f"Bearer {DEEPSEEK_API_KEY}",
        "Content-Type": "application/json"
    }
    system_prompt = f"You are a professional translator. Translate the following {source_lang} text to {target_lang}. Handle OCR errors gracefully. Provide only the translated text."
    
    messages = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": text}
    ]
    
    data = {
        "model": "deepseek-chat",
        "messages": messages,
        "temperature": 1.3
    }
    
    try:
        response = requests.post(DEEPSEEK_API_URL, headers=headers, json=data)
        response.raise_for_status()
        result = response.json()
        return result['choices'][0]['message']['content']
    except requests.exceptions.RequestException as e:
        print(f"Translation API error: {e}")
        # Mengembalikan teks asli jika translasi gagal
        return f"[Translation Failed] {text}"

def create_translated_panel(image, crops, translated_text):
    """Membuat panel yang sudah ditranslasi dengan text wrapping."""
    translated_panel = image.copy()
    
    # Parse hasil translasi
    translation_by_area = {}
    current_area = None
    current_text = []
    for line in translated_text.split('\n'):
        if line.startswith('[Text Area #') and ']' in line:
            if current_area is not None and current_text:
                translation_by_area[current_area] = '\n'.join(current_text).strip()
            try:
                area_num = int(line.split('#')[1].split(']')[0]) - 1
                current_area = area_num
                current_text = []
            except (ValueError, IndexError):
                current_area = None
        elif current_area is not None:
            current_text.append(line)
    if current_area is not None and current_text:
        translation_by_area[current_area] = '\n'.join(current_text).strip()

    # Timpa teks pada gambar asli
    for idx, text_to_draw in translation_by_area.items():
        if idx >= len(crops):
            continue
        
        bbox = crops[idx]['bbox']
        x1, y1, x2, y2 = bbox
        bubble_width = x2 - x1
        bubble_height = y2 - y1

        # Buat overlay putih
        overlay = translated_panel.copy()
        cv2.rectangle(overlay, (x1, y1), (x2, y2), (255, 255, 255), -1)
        alpha = 0.9
        cv2.addWeighted(overlay, alpha, translated_panel, 1 - alpha, 0, translated_panel)

        # --- Logika Text Wrapping --- #
        font = cv2.FONT_HERSHEY_SIMPLEX
        font_scale = min(bubble_width, bubble_height) / 250 
        font_scale = max(0.5, min(1.2, font_scale))
        thickness = 1

        lines = []
        words = text_to_draw.replace('\n', ' ').split(' ')
        current_line = ''
        for word in words:
            test_line = f"{current_line} {word}".strip()
            (width, height), _ = cv2.getTextSize(test_line, font, font_scale, thickness)
            if width < bubble_width - 20: # Padding 10px kiri kanan
                current_line = test_line
            else:
                lines.append(current_line)
                current_line = word
        if current_line:
            lines.append(current_line)

        # Hitung posisi vertikal untuk menengahkan teks
        line_height = cv2.getTextSize("A", font, font_scale, thickness)[0][1] + 5
        total_text_height = line_height * len(lines)
        start_y = y1 + (bubble_height - total_text_height) // 2 + line_height

        # Gambar setiap baris teks
        for i, line in enumerate(lines):
            (line_width, _), _ = cv2.getTextSize(line, font, font_scale, thickness)
            text_x = x1 + (bubble_width - line_width) // 2
            text_y = start_y + i * line_height

            # Teks dengan outline untuk keterbacaan
            cv2.putText(translated_panel, line, (text_x, text_y), font, font_scale, (0, 0, 0), thickness + 1) # Outline
            cv2.putText(translated_panel, line, (text_x, text_y), font, font_scale, (255, 255, 255), thickness) # Teks utama

    return translated_panel

def run_translation_pipeline(image_path, lang='ja'):
    """Orkestrasi seluruh pipeline translasi manga."""
    base_dir = os.path.dirname(image_path)
    temp_crop_dir = os.path.join(base_dir, "temp_crops")
    temp_processed_dir = os.path.join(base_dir, "temp_processed")
    
    try:
        # 1. Inisialisasi
        reader = init_reader([lang])
        original_image = cv2.imread(image_path)
        if original_image is None:
            raise FileNotFoundError("Original image not found or unreadable.")

        # 2. Deteksi & Potong Balon Teks
        bubble_crops = process_manga_page(image_path, temp_crop_dir)
        if not bubble_crops:
            print("No text bubbles detected.")
            return image_path # Kembalikan gambar asli jika tidak ada teks

        # 3. OCR & Rotasi untuk setiap crop
        all_ocr_text = ""
        ocr_results_map = {}
        for idx, crop_info in enumerate(bubble_crops):
            processed_path = os.path.join(temp_processed_dir, f"processed_{idx}.jpg")
            os.makedirs(temp_processed_dir, exist_ok=True)
            
            # Proses rotasi huruf
            rotated_result = process_image_with_rotation(crop_info['path'], processed_path)
            if not rotated_result:
                continue

            # Lakukan OCR pada gambar yang sudah diproses
            ocr_results = perform_ocr(reader, rotated_result['result'])
            if ocr_results:
                text = ' '.join([res[1] for res in ocr_results])
                all_ocr_text += f"[Text Area #{idx+1}]\n{text}\n\n"
                ocr_results_map[idx] = text

        # 4. Translasi
        if not all_ocr_text.strip():
            print("No text found after OCR.")
            return image_path

        translated_text = translate_text(all_ocr_text)

        # 5. Buat Panel Hasil
        final_panel = create_translated_panel(original_image, bubble_crops, translated_text)
        
        # Simpan hasil akhir
        final_output_path = os.path.join(os.path.dirname(image_path), f"translated_{os.path.basename(image_path)}")
        cv2.imwrite(final_output_path, final_panel)
        
        return final_output_path

    finally:
        # 6. Bersihkan file sementara
        import shutil
        if os.path.exists(temp_crop_dir):
            shutil.rmtree(temp_crop_dir)
        if os.path.exists(temp_processed_dir):
            shutil.rmtree(temp_processed_dir)
