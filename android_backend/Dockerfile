FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# System deps for opencv / pillow / magic
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgl1 libglib2.0-0 libsm6 libxext6 libxrender1 file \
 && rm -rf /var/lib/apt/lists/*

# Install python deps
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# App code
COPY . .

# Cloud Run injects PORT
ENV PORT=8080

# Start with gunicorn+uvicorn worker, bind ke $PORT
CMD exec gunicorn -k uvicorn.workers.UvicornWorker api:app \
    --bind 0.0.0.0:${PORT} --timeout 0
