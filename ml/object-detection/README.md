# Object Detection Service

A production-ready YOLO-based object detection service built with FastAPI. Detects objects in Base64-encoded images and returns spatial position information.

## Features

- **Fast Object Detection**: YOLOv8s model for real-time inference (20-50ms on CPU)
- **Spatial Reasoning**: 3×3 grid-based position description (left/center/right + top/middle/bottom)
- **Base64 Image Input**: Direct Base64 support, no file upload required
- **JSON Response**: Clean, structured JSON output with object labels and positions
- **Auto Model Download**: Automatically downloads YOLOv8s from Ultralytics on first run
- **Production Ready**: Comprehensive error handling, logging, and validation
- **Health Monitoring**: Built-in health check endpoint

## System Requirements

- **Python**: 3.9+
- **RAM**: 2GB+ (for model loading)
- **Storage**: 500MB+ (for model and dependencies)
- **OS**: Windows, macOS, Linux

## Installation

### 1. Clone the Repository

```bash
cd ml/object-detection
```

### 2. Create Virtual Environment

```bash
# Windows
python -m venv venv
venv\Scripts\activate

# macOS/Linux
python -m venv venv
source venv/bin/activate
```

### 3. Install Dependencies

```bash
pip install -r requirements.txt
```

The first run will automatically download the YOLOv8s model (~22.5 MB) from Ultralytics.

## Quick Start

### Start the Server

```bash
# Using Python directly
python -m src.main

# Or using uvicorn
uvicorn src.main:app --host 127.0.0.1 --port 8001
```

Server will be available at: `http://127.0.0.1:8001`

### Health Check

```bash
curl http://127.0.0.1:8001/api/v1/objects/health
```

Response:
```json
{
  "status": "healthy",
  "model_loaded": true,
  "model_name": "yolov8s"
}
```

### Run Object Detection

**Using cURL:**

```bash
# Create a test image first (as Base64)
# Or use an existing image and encode it

curl -X POST http://127.0.0.1:8001/api/v1/objects/detect \
  -H "Content-Type: application/json" \
  -d '{
    "image_base64": "<YOUR_BASE64_ENCODED_IMAGE>",
    "confidence_threshold": 0.5
  }'
```

**Using Python:**

```python
import requests
import base64

# Load and encode image
with open("image.jpg", "rb") as f:
    image_base64 = base64.b64encode(f.read()).decode()

# Send request
response = requests.post(
    "http://127.0.0.1:8001/api/v1/objects/detect",
    json={
        "image_base64": image_base64,
        "confidence_threshold": 0.5
    }
)

# Print results
print(response.json())
```

## API Documentation

### POST `/api/v1/objects/detect`

Detect objects in a Base64-encoded image.

**Request Body:**

```json
{
  "image_base64": "string (Base64-encoded image)",
  "confidence_threshold": 0.5 (optional, default: 0.5, range: 0-1)
}
```

**Response (200 OK):**

```json
{
  "status": "success",
  "inference_time_ms": 45.23,
  "detected_objects": [
    {
      "label": "person",
      "confidence": 0.95,
      "position_description": "person on the left side",
      "bounding_box": {
        "x": 10.5,
        "y": 50.2,
        "width": 80.3,
        "height": 200.1
      },
      "relative_position": {
        "horizontal": "left",
        "vertical": "middle"
      }
    },
    {
      "label": "chair",
      "confidence": 0.87,
      "position_description": "chair in the bottom-right",
      "bounding_box": {
        "x": 200.1,
        "y": 300.5,
        "width": 120.2,
        "height": 150.3
      },
      "relative_position": {
        "horizontal": "right",
        "vertical": "bottom"
      }
    }
  ],
  "total_detections": 2
}
```

**Error Response (400 Bad Request):**

```json
{
  "status": "error",
  "error_type": "InvalidBase64Exception",
  "message": "Invalid Base64 format",
  "details": null
}
```

### GET `/api/v1/objects/health`

Health check endpoint.

**Response:**

```json
{
  "status": "healthy",
  "model_loaded": true,
  "model_name": "yolov8s"
}
```

### GET `/`

Root endpoint with API information.

**Response:**

```json
{
  "name": "Object Detection Service",
  "version": "1.0.0",
  "description": "YOLO-based object detection service with spatial reasoning",
  "endpoints": {
    "detect": "POST /api/v1/objects/detect",
    "health": "GET /api/v1/objects/health",
    "docs": "/docs",
    "openapi": "/openapi.json"
  }
}
```

## Interactive API Documentation

Once the server is running, visit:

- **Swagger UI**: http://127.0.0.1:8001/docs
- **ReDoc**: http://127.0.0.1:8001/redoc
- **OpenAPI Schema**: http://127.0.0.1:8001/openapi.json

## Testing

### Run Unit Tests

```bash
pytest tests/ -v
```

### Run Specific Test File

```bash
pytest tests/test_spatial_service.py -v
```

### Run with Coverage

```bash
pytest tests/ --cov=src --cov-report=html
```

## Configuration

Edit [config.py](config.py) to customize:

```python
# Model
YOLO_MODEL_NAME = "yolov8s"

# Detection
DEFAULT_CONFIDENCE_THRESHOLD = 0.5

# Server
HOST = "127.0.0.1"
PORT = 8001

# Image limits
MAX_IMAGE_SIZE_MB = 10

# Logging
LOG_LEVEL = "INFO"
```

Or use environment variables:

```bash
export OD_HOST=0.0.0.0
export OD_PORT=8001
export DEBUG=True
export LOG_LEVEL=DEBUG
```

## Project Structure

```
ml/object-detection/
├── src/
│   ├── main.py                    # FastAPI app entry point
│   ├── models.py                  # Pydantic request/response models
│   ├── exceptions.py              # Custom exceptions
│   │
│   ├── api/
│   │   └── v1/
│   │       └── objects.py         # Detection endpoints
│   │
│   ├── services/
│   │   ├── yolo_service.py        # YOLO model wrapper
│   │   ├── detection_service.py   # Detection orchestrator
│   │   ├── image_service.py       # Image processing
│   │   └── spatial_service.py     # Spatial position logic
│   │
│   └── utils/
│       ├── logger.py              # Logging setup
│       └── validators.py          # Input validation
│
├── models/                         # YOLO model storage (auto-downloaded)
├── tests/                          # Test suite
│   ├── conftest.py
│   ├── test_api_endpoints.py
│   ├── test_spatial_service.py
│   └── test_image_service.py
│
├── scripts/                        # Utility scripts
├── config.py                       # Configuration
├── requirements.txt                # Python dependencies
└── README.md                       # This file
```

## Performance Characteristics

### Inference Time (YOLOv8s)

- **CPU (typical laptop)**: 30-50ms per image
- **GPU (NVIDIA)**: 5-10ms per image
- **End-to-end (with overhead)**: ~50-100ms

### Memory Usage

- **Model in memory**: ~50-80 MB
- **Framework overhead**: ~100-150 MB
- **Per-request overhead**: Minimal

### Supported Image Formats

- JPEG/JPG
- PNG
- BMP
- WebP

## Spatial Position Grid

Objects are positioned using a 3×3 grid:

```
[top-left]     [top-center]     [top-right]
[middle-left]  [middle-center]  [middle-right]
[bottom-left]  [bottom-center]  [bottom-right]
```

**Zones:**
- **Horizontal**: left (0-33%), center (33-66%), right (66-100%)
- **Vertical**: top (0-33%), middle (33-66%), bottom (66-100%)

## Error Handling

The service provides detailed error responses:

| Error Type | Status | Description |
|-----------|--------|-------------|
| `InvalidBase64Exception` | 400 | Invalid Base64 format |
| `ImageDecodingException` | 400 | Image decode failure |
| `UnsupportedImageFormatException` | 400 | Unsupported image type |
| `ImageSizeException` | 400 | Image exceeds max size |
| `ValidationException` | 400 | Invalid input parameters |
| `InferenceException` | 500 | Inference failure |
| `ModelLoadException` | 500 | Model loading failure |

## Logging

Logs are output to console. Adjust logging level in [config.py](config.py):

```python
LOG_LEVEL = "DEBUG"  # DEBUG, INFO, WARNING, ERROR, CRITICAL
```

## Known Limitations

1. **Sequential Processing**: Requests are processed sequentially (not concurrent)
2. **Single Image**: Processes one image per request (no batch processing)
3. **Image Size**: Maximum 10 MB per image
4. **Timeout**: No request timeout configured (can be added via Uvicorn config)

## Troubleshooting

### Model Download Fails

```
Error: Failed to load YOLO model
```

**Solution**: Ensure internet connection, or manually download from:
```
https://github.com/ultralytics/assets/releases/download/v0.0.0/yolov8s.pt
```
Place in `ml/object-detection/models/` folder.

### Out of Memory

```
RuntimeError: CUDA out of memory
```

**Solution**: Reduce image size or use YOLOv8n (nano) instead of yolov8s.

### Slow Inference

**Solution**: 
- Reduce image resolution
- Use GPU (install torch with CUDA support)
- Use lighter model (yolov8n instead of yolov8s)

## Integration with S.A.G.E Backend

To integrate with the main S.A.G.E application:

```python
import requests

# Send image to object detection service
response = requests.post(
    "http://127.0.0.1:8001/api/v1/objects/detect",
    json={
        "image_base64": image_base64,
        "confidence_threshold": 0.5
    }
)

detections = response.json()
# Process detections...
```

## Contributing

1. Add new tests in `tests/`
2. Follow existing code structure
3. Update documentation

## License

Part of S.A.G.E Project

## References

- [Ultralytics YOLOv8](https://docs.ultralytics.com/)
- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [Pydantic](https://docs.pydantic.dev/)
