
import requests
import os

# --- Konfigurasi ---
# Ganti dengan path ke gambar yang ingin Anda tes
IMAGE_PATH = 'test.jpg' 
# URL dari server FastAPI Anda
API_URL = 'http://127.0.0.1:8000/translate_image'
# Bahasa sumber (opsional, default 'ja')
LANGUAGE = 'ja'
# Path untuk menyimpan hasil
OUTPUT_PATH = 'translated_result.jpg'

# Cek apakah file gambar ada
if not os.path.exists(IMAGE_PATH):
    print(f"Error: File gambar tidak ditemukan di '{IMAGE_PATH}'")
    print("Silakan ganti nilai IMAGE_PATH di dalam script ini.")
else:
    print(f"Mengirim gambar '{os.path.basename(IMAGE_PATH)}' ke server...")
    
    # Siapkan file untuk dikirim
    with open(IMAGE_PATH, 'rb') as f:
        files = {'file': (os.path.basename(IMAGE_PATH), f, 'image/jpeg')}
        params = {'lang': LANGUAGE}
        
        try:
            # Kirim request POST
            response = requests.post(API_URL, files=files, params=params, timeout=300) # Timeout 5 menit

            # Cek status respons
            if response.status_code == 200:
                # Simpan gambar hasil translasi
                with open(OUTPUT_PATH, 'wb') as out_file:
                    out_file.write(response.content)
                print(f"Sukses! Gambar hasil translasi disimpan di: {OUTPUT_PATH}")
            else:
                # Tampilkan error jika gagal
                print(f"Gagal! Server merespons dengan status code: {response.status_code}")
                print("Detail error:", response.text)

        except requests.exceptions.RequestException as e:
            print(f"Terjadi error saat menghubungi server: {e}")
