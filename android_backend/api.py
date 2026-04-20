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

TEMP_DIR = "temp_images"
os.makedirs(TEMP_DIR, exist_ok=True)


def cleanup_files(paths: list):
    """Delete temporary files after response is sent."""
    for path in paths:
        if path and os.path.exists(path):
            try:
                os.remove(path)
            except OSError:
                pass


@app.get("/")
def read_root():
    return {"message": "Welcome to the Manga Translator API"}


@app.post("/translate_image")
async def translate_image(
    lang: str = Query("ja", description="Source language for OCR (e.g., 'ja', 'zh-cn', 'en')"),
    file: UploadFile = File(...),
):
    """
    Accepts a manga image, runs the full translation pipeline,
    and returns the processed image with translated text overlaid.
    """
    file_path = None
    try:
        file_extension = os.path.splitext(file.filename)[1].lower()
        if file_extension not in [".png", ".jpg", ".jpeg"]:
            raise HTTPException(status_code=400, detail="Invalid file type. Please upload a PNG, JPG, or JPEG image.")

        unique_filename = f"{uuid.uuid4()}{file_extension}"
        file_path = os.path.join(TEMP_DIR, unique_filename)

        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)

        processed_image_path = await run_in_threadpool(run_translation_pipeline, file_path, lang=lang)

        if not os.path.exists(processed_image_path):
            raise HTTPException(status_code=500, detail="Processing failed: output file not found.")

        out_ext = os.path.splitext(processed_image_path)[1].lower()
        media_type = "image/png" if out_ext == ".png" else "image/jpeg"

        # Collect all temp files to delete after response is sent.
        # Input and output may be the same path when no bubbles are detected.
        paths_to_clean = list({file_path, processed_image_path})
        cleanup_task = BackgroundTask(cleanup_files, paths=paths_to_clean)

        return FileResponse(
            path=processed_image_path,
            media_type=media_type,
            filename=f"translated_{os.path.basename(processed_image_path)}",
            background=cleanup_task,
        )

    except Exception as e:
        print(f"Error during image processing: {e}")
        raise HTTPException(status_code=500, detail=f"An error occurred during processing: {str(e)}")

    finally:
        if file:
            file.file.close()


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8080))
    uvicorn.run(app, host="0.0.0.0", port=port)
