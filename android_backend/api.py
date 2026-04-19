
import uvicorn
from fastapi import FastAPI, File, UploadFile, HTTPException, Query
from fastapi.responses import FileResponse
from fastapi.concurrency import run_in_threadpool
from starlette.background import BackgroundTask
import os
import shutil
import uuid
from core_new import run_translation_pipeline

app = FastAPI()

# Direktori untuk menyimpan file sementara
TEMP_DIR = "temp_images"
os.makedirs(TEMP_DIR, exist_ok=True)

def cleanup_file(path: str):
    """Tugas latar belakang untuk menghapus file."""
    if path and os.path.exists(path):
        os.remove(path)

@app.get("/")
def read_root():
    return {"message": "Welcome to the Manga Translator API"}

@app.post("/translate_image")
async def translate_image(
    lang: str = Query('ja', description="Source language for OCR (e.g., 'ja', 'zh-cn', 'en')"),
    file: UploadFile = File(...)
):
    """
    Menerima file gambar, menjalankan pipeline translasi, 
    dan mengembalikan gambar hasil proses.
    """
    file_path = None
    try:
        # Buat nama file yang unik untuk file input
        file_extension = os.path.splitext(file.filename)[1]
        if file_extension not in ['.png', '.jpg', '.jpeg']:
            raise HTTPException(status_code=400, detail="Invalid file type. Please upload a PNG, JPG, or JPEG image.")
        
        unique_filename = f"{uuid.uuid4()}{file_extension}"
        file_path = os.path.join(TEMP_DIR, unique_filename)

        # Simpan file yang diunggah
        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)

        # Jalankan pipeline pemrosesan secara async
        processed_image_path = await run_in_threadpool(run_translation_pipeline, file_path, lang=lang)
        
        if not os.path.exists(processed_image_path):
            raise HTTPException(status_code=500, detail="Processing failed, output file not found.")

        # Siapkan tugas cleanup untuk dijalankan setelah response dikirim
        cleanup_task = BackgroundTask(cleanup_file, path=processed_image_path)

        return FileResponse(
            path=processed_image_path,
            media_type="image/jpeg",
            filename=f"translated_{os.path.basename(processed_image_path)}",
            background=cleanup_task
        )

    except Exception as e:
        # Log error di server
        print(f"Error during image processing: {e}")
        raise HTTPException(status_code=500, detail=f"An error occurred during processing: {str(e)}")

    finally:
        # Selalu tutup file upload
        if file:
            file.file.close()
        # Hapus hanya file input awal
        if file_path and os.path.exists(file_path):
            os.remove(file_path)

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8080))
    uvicorn.run(app, host="0.0.0.0", port=port)
