FROM python:3.11-slim

# Set the working directory in the container
WORKDIR /app

# Install system dependencies required for OpenCV and building python packages
RUN apt-get update && apt-get install -y \
    libgl1 \
    libglib2.0-0 \
    build-essential \
    g++ \
    && rm -rf /var/lib/apt/lists/*

# Copy the requirements file
COPY src/requirements.txt .

# Install dependencies and update onnxruntime to avoid WSL execstack bug
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt && \
    pip install --no-cache-dir "onnxruntime>=1.17.1"

# Copy the entire facial recognition codebase
COPY . .

# Expose the port the service runs on
EXPOSE 8002

# Set the working directory to the src folder since the scripts rely on relative paths (e.g. config.py)
WORKDIR /app/src

# Command to run the application
CMD ["python", "face_recognition_service.py"]
