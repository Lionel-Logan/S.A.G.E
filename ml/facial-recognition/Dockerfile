FROM python:3.11-slim as base

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libsm6 \
    libxext6 \
    libxrender-dev \
    libgl1 \
    libglib2.0-0 \
    wget \
    && rm -rf /var/lib/apt/lists/*

COPY src/requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

COPY src/ ./src
# Install insightface. We might be able to install it via pip or via the whl if linux compatible. 
# But the whl is 'win_amd64'. Since we are on docker linux, pip install insightface should work.

EXPOSE 8002

WORKDIR /app/src
CMD ["uvicorn", "face_recognition_service:app", "--host", "0.0.0.0", "--port", "8002"]