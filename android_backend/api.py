import io
import os
import shutil
import threading
import uuid
import zipfile
import uvicorn

from fastapi import FastAPI, File, HTTPException, Query, UploadFile
from fastapi.responses import FileResponse, JSONResponse, StreamingResponse
from typing import List

from core_new import (
    detect_and_ocr_page,
    translate_chapter,
    apply_translation_overlay,
    get_reader,
)
from job_manager import job_manager, JOBS_DIR

app = FastAPI(title="LinguaPanel API", version="2.0.0")

TEMP_DIR = "temp_images"
os.makedirs(TEMP_DIR, exist_ok=True)
os.makedirs(JOBS_DIR, exist_ok=True)

ALLOWED_EXTS = {".png", ".jpg", ".jpeg", ".webp"}


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _save_upload(file: UploadFile, dest_dir: str) -> str:
    """Save an uploaded file to dest_dir and return its full path."""
    ext = os.path.splitext(file.filename)[1].lower()
    if ext not in ALLOWED_EXTS and ext != ".zip":
        raise HTTPException(status_code=400, detail=f"Unsupported file type: {ext}")
    path = os.path.join(dest_dir, f"{uuid.uuid4()}{ext}")
    with open(path, "wb") as f:
        shutil.copyfileobj(file.file, f)
    return path


def _delete(path: str):
    if path and os.path.exists(path):
        try:
            os.remove(path)
        except OSError:
            pass



# ---------------------------------------------------------------------------
# Background workers
# ---------------------------------------------------------------------------

def _run_single_job(job_id: str, image_path: str, lang: str, orientation: str = "vertical"):
    """Background worker for single-image translation job (uses same 3-phase pipeline as chapter)."""
    try:
        reader = get_reader(lang)

        # Phase 1: Detect + OCR
        job_manager.update(job_id, progress=1, total=4, message="Scanning...", status="running")
        work_dir = os.path.join(TEMP_DIR, f"work_{job_id}_0")
        os.makedirs(work_dir, exist_ok=True)
        crops, ocr_text = detect_and_ocr_page(image_path, reader, work_dir, orientation=orientation)

        # Phase 2: Translate
        job_manager.update(job_id, progress=2, total=4, message="Translating...", status="running")
        translations = {}
        if ocr_text.strip():
            translations = translate_chapter({0: ocr_text})

        # Phase 3: Render
        job_manager.update(job_id, progress=3, total=4, message="Rendering...", status="running")
        ext = os.path.splitext(image_path)[1].lower()
        result_filename = f"page_1{ext}"
        output_path = os.path.join(job_manager.get(job_id).result_dir, result_filename)
        apply_translation_overlay(image_path, crops, translations.get(0, ""), output_path)

        job_manager.append_result(job_id, page=1, filename=result_filename)
        job_manager.update(job_id, status="done", progress=4, total=4, message="Done!")

    except Exception as e:
        print(f"[Job {job_id}] Error: {e}")
        job_manager.update(job_id, status="failed", error=str(e))
    finally:
        _delete(image_path)
        work_dir = os.path.join(TEMP_DIR, f"work_{job_id}_0")
        if os.path.exists(work_dir):
            shutil.rmtree(work_dir, ignore_errors=True)


def _run_chapter_job(job_id: str, image_paths: list[str], lang: str, orientation: str = "vertical"):
    """
    Background worker for chapter translation — 3-phase pipeline:
      Phase 1: Detect + OCR all pages  (sequential, shows scanning progress)
      Phase 2: Translate all pages     (1 batched DeepSeek call)
      Phase 3: Render overlays         (sequential, results appear progressively)
    """
    total = len(image_paths)
    # Progress buckets: each page gets 2 steps (OCR + render); translation = 1 shared step
    TOTAL_STEPS = total * 2 + 1

    def _upd(step: int, message: str):
        job_manager.update(job_id, progress=step, total=TOTAL_STEPS,
                           message=message, status="running")

    try:
        reader = get_reader(lang)

        # ------------------------------------------------------------------
        # Phase 1: Detect + OCR all pages
        # ------------------------------------------------------------------
        pages_crops: list = []
        pages_ocr: dict = {}

        for page_idx, image_path in enumerate(image_paths):
            _upd(page_idx, f"Scanning page {page_idx + 1}/{total}...")
            work_dir = os.path.join(TEMP_DIR, f"work_{job_id}_{page_idx}")
            os.makedirs(work_dir, exist_ok=True)

            crops, ocr_text = detect_and_ocr_page(image_path, reader, work_dir, orientation=orientation)
            pages_crops.append(crops)
            if ocr_text.strip():
                pages_ocr[page_idx] = ocr_text

        # ------------------------------------------------------------------
        # Phase 2: Translate all pages in one batched API call
        # ------------------------------------------------------------------
        _upd(total, f"Translating {total} pages...")
        translations: dict = {}
        if pages_ocr:
            translations = translate_chapter(pages_ocr)

        # ------------------------------------------------------------------
        # Phase 3: Render overlays — results become available page by page
        # ------------------------------------------------------------------
        for page_idx, image_path in enumerate(image_paths):
            render_step = total + 1 + page_idx
            _upd(render_step, f"Rendering page {page_idx + 1}/{total}...")

            ext = os.path.splitext(image_path)[1].lower()
            result_filename = f"page_{page_idx + 1:03d}{ext}"
            output_path = os.path.join(job_manager.get(job_id).result_dir, result_filename)

            translated_text = translations.get(page_idx, "")
            apply_translation_overlay(
                image_path, pages_crops[page_idx], translated_text, output_path
            )

            job_manager.append_result(job_id, page=page_idx + 1, filename=result_filename)
            _delete(image_path)

        job_manager.update(job_id, status="done", progress=TOTAL_STEPS, total=TOTAL_STEPS,
                           message=f"Done! {total} pages translated.")


    except Exception as e:
        print(f"[Job {job_id}] Error: {e}")
        job_manager.update(job_id, status="failed", error=str(e))
    finally:
        for p in image_paths:
            _delete(p)
        # Cleanup work dirs
        for page_idx in range(total):
            work_dir = os.path.join(TEMP_DIR, f"work_{job_id}_{page_idx}")
            if os.path.exists(work_dir):
                shutil.rmtree(work_dir, ignore_errors=True)


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------

@app.get("/")
def read_root():
    return {"message": "LinguaPanel Translation API v2", "docs": "/docs"}



# ---------------------------------------------------------------------------
# Routes — job-based endpoints
# ---------------------------------------------------------------------------

@app.post("/jobs/image", summary="Translate single image (async job)")
async def create_image_job(
    lang: str = Query("ja", description="Source language for OCR"),
    orientation: str = Query("vertical", description="Text orientation: 'vertical' (manga/manhua) or 'horizontal' (manhwa)"),
    file: UploadFile = File(...),
):
    """
    Creates a background translation job for a single image.
    Returns a job_id immediately. Poll /jobs/{id}/status for progress.
    """
    ext = os.path.splitext(file.filename)[1].lower()
    if ext not in ALLOWED_EXTS:
        raise HTTPException(status_code=400, detail="Invalid file type. Use PNG, JPG, or JPEG.")

    file_path = os.path.join(TEMP_DIR, f"{uuid.uuid4()}{ext}")
    with open(file_path, "wb") as f:
        shutil.copyfileobj(file.file, f)
    file.file.close()

    job = job_manager.create(total_steps=4)
    threading.Thread(
        target=_run_single_job,
        args=(job.id, file_path, lang, orientation),
        daemon=True,
    ).start()

    return {"job_id": job.id, "status": job.status}


@app.post("/jobs/chapter", summary="Translate multiple pages (async job)")
async def create_chapter_job(
    lang: str = Query("ja", description="Source language for OCR"),
    orientation: str = Query("vertical", description="Text orientation: 'vertical' (manga/manhua) or 'horizontal' (manhwa)"),
    files: List[UploadFile] = File(...),

):
    """
    Creates a background translation job for a chapter.

    Accepts **either**:
    - A single `.zip` file containing manga page images, OR
    - Multiple image files uploaded directly (sorted by filename).

    Progress and individual page results are available via /jobs/{id}/status.
    """
    image_paths: list[str] = []

    if len(files) == 1 and files[0].filename.lower().endswith(".zip"):
        # --- ZIP input ---
        zip_tmp = os.path.join(TEMP_DIR, f"{uuid.uuid4()}.zip")
        with open(zip_tmp, "wb") as f:
            shutil.copyfileobj(files[0].file, f)
        files[0].file.close()

        extract_dir = os.path.join(TEMP_DIR, str(uuid.uuid4()))
        os.makedirs(extract_dir, exist_ok=True)
        with zipfile.ZipFile(zip_tmp, "r") as zf:
            for member in sorted(zf.namelist()):
                ext = os.path.splitext(member)[1].lower()
                if ext in ALLOWED_EXTS:
                    dest = os.path.join(extract_dir, os.path.basename(member))
                    with zf.open(member) as src, open(dest, "wb") as dst:
                        shutil.copyfileobj(src, dst)
                    image_paths.append(dest)
        _delete(zip_tmp)

    else:
        # --- Multiple image input ---
        # Sort by original filename to preserve page order
        sorted_files = sorted(files, key=lambda f: f.filename)
        for uf in sorted_files:
            ext = os.path.splitext(uf.filename)[1].lower()
            if ext not in ALLOWED_EXTS:
                continue
            path = os.path.join(TEMP_DIR, f"{uuid.uuid4()}{ext}")
            with open(path, "wb") as f:
                shutil.copyfileobj(uf.file, f)
            uf.file.close()
            image_paths.append(path)

    if not image_paths:
        raise HTTPException(status_code=400, detail="No valid image files found in upload.")

    job = job_manager.create(total_steps=len(image_paths) * 4)
    threading.Thread(
        target=_run_chapter_job,
        args=(job.id, image_paths, lang, orientation),
        daemon=True,
    ).start()

    return {"job_id": job.id, "status": job.status, "total_pages": len(image_paths)}


@app.get("/jobs/{job_id}/status", summary="Get job progress and available results")
def get_job_status(job_id: str):
    """
    Returns current job status, progress, and URLs for pages that have
    already been translated (useful for progressive display).
    """
    job = job_manager.get(job_id)
    if not job:
        raise HTTPException(status_code=404, detail="Job not found.")

    percent = int(job.progress / job.total * 100) if job.total else 0
    results_with_urls = [
        {**r, "url": f"/jobs/{job_id}/pages/{r['page']}"}
        for r in job.results
    ]

    return {
        "job_id": job_id,
        "status": job.status,
        "message": job.message,
        "progress": job.progress,
        "total": job.total,
        "percent": percent,
        "results": results_with_urls,
        "error": job.error,
    }


@app.get("/jobs/{job_id}/pages/{page}", summary="Download a single translated page")
def get_job_page(job_id: str, page: int):
    """Serve an individual translated page once it's ready."""
    job = job_manager.get(job_id)
    if not job:
        raise HTTPException(status_code=404, detail="Job not found.")

    match = next((r for r in job.results if r["page"] == page), None)
    if not match:
        raise HTTPException(status_code=404, detail=f"Page {page} not yet available.")

    file_path = os.path.join(job.result_dir, match["filename"])
    if not os.path.exists(file_path):
        raise HTTPException(status_code=404, detail="File not found on disk.")

    ext = os.path.splitext(file_path)[1].lower()
    media_types = {".png": "image/png", ".webp": "image/webp"}
    media_type = media_types.get(ext, "image/jpeg")
    return FileResponse(path=file_path, media_type=media_type, filename=match["filename"])


@app.get("/jobs/{job_id}/download", summary="Download all translated pages as ZIP")
def download_job_zip(job_id: str):
    """
    Stream a ZIP archive of all currently translated pages.
    Can be called before job completes to get partial results.
    """
    job = job_manager.get(job_id)
    if not job:
        raise HTTPException(status_code=404, detail="Job not found.")
    if not job.results:
        raise HTTPException(status_code=404, detail="No pages translated yet.")

    def generate_zip():
        buf = io.BytesIO()
        with zipfile.ZipFile(buf, "w", zipfile.ZIP_DEFLATED) as zf:
            for result in sorted(job.results, key=lambda r: r["page"]):
                file_path = os.path.join(job.result_dir, result["filename"])
                if os.path.exists(file_path):
                    zf.write(file_path, arcname=result["filename"])
        buf.seek(0)
        yield buf.read()

    return StreamingResponse(
        generate_zip(),
        media_type="application/zip",
        headers={"Content-Disposition": f"attachment; filename=translated_chapter_{job_id[:8]}.zip"},
    )


@app.delete("/jobs/{job_id}", summary="Delete a job and its files")
def delete_job(job_id: str):
    """Manually delete a job and all associated output files."""
    job = job_manager.get(job_id)
    if not job:
        raise HTTPException(status_code=404, detail="Job not found.")
    job_manager.delete(job_id)
    return {"message": "Job deleted."}


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8080))
    uvicorn.run(app, host="0.0.0.0", port=port)
