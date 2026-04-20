"""
In-memory job store for tracking translation jobs.
Jobs are auto-cleaned 30 minutes after completion.
"""

import os
import shutil
import threading
import time
import uuid
from dataclasses import dataclass, field
from typing import Optional

JOB_TTL_SECONDS = 30 * 60  # auto-delete completed jobs after 30 min
JOBS_DIR = "temp_jobs"


@dataclass
class Job:
    id: str
    status: str          # "queued" | "running" | "done" | "failed"
    progress: int        # steps completed
    total: int           # total steps
    message: str         # human-readable current step
    results: list        # [{"page": 1, "filename": "page_001.jpg"}, ...]
    error: Optional[str]
    created_at: float
    result_dir: str      # absolute path to this job's output directory


class JobManager:
    def __init__(self):
        self._jobs: dict[str, Job] = {}
        self._lock = threading.Lock()
        os.makedirs(JOBS_DIR, exist_ok=True)
        # Background thread auto-cleans expired jobs
        threading.Thread(target=self._cleanup_loop, daemon=True).start()

    # ------------------------------------------------------------------
    # CRUD
    # ------------------------------------------------------------------

    def create(self, total_steps: int) -> Job:
        job_id = str(uuid.uuid4())
        result_dir = os.path.join(JOBS_DIR, job_id)
        os.makedirs(result_dir, exist_ok=True)
        job = Job(
            id=job_id,
            status="queued",
            progress=0,
            total=total_steps,
            message="Queued...",
            results=[],
            error=None,
            created_at=time.time(),
            result_dir=result_dir,
        )
        with self._lock:
            self._jobs[job_id] = job
        return job

    def get(self, job_id: str) -> Optional[Job]:
        with self._lock:
            return self._jobs.get(job_id)

    def update(self, job_id: str, **kwargs):
        with self._lock:
            job = self._jobs.get(job_id)
            if job:
                for k, v in kwargs.items():
                    setattr(job, k, v)

    def append_result(self, job_id: str, page: int, filename: str):
        with self._lock:
            job = self._jobs.get(job_id)
            if job:
                job.results.append({"page": page, "filename": filename})

    def delete(self, job_id: str):
        with self._lock:
            job = self._jobs.pop(job_id, None)
        if job and os.path.exists(job.result_dir):
            shutil.rmtree(job.result_dir, ignore_errors=True)

    # ------------------------------------------------------------------
    # Auto-cleanup
    # ------------------------------------------------------------------

    def _cleanup_loop(self):
        while True:
            time.sleep(60)
            now = time.time()
            with self._lock:
                expired = [
                    jid for jid, j in self._jobs.items()
                    if j.status in ("done", "failed")
                    and now - j.created_at > JOB_TTL_SECONDS
                ]
            for jid in expired:
                self.delete(jid)


# Singleton — imported by api.py and worker functions
job_manager = JobManager()
