# Object Detection Service - Complete Project Overview

## 📁 Project Structure

```
ml/object-detection/
│
├── README.md                              # Full documentation
├── QUICK_START_TESTING.md                # Testing quick start guide
├── TESTING_GUIDE.md                       # Detailed testing guide
├── requirements.txt                       # Python dependencies
├── config.py                              # Configuration settings
│
├── src/
│   ├── __init__.py
│   ├── main.py                           # FastAPI app entry point
│   ├── models.py                         # Pydantic request/response models
│   ├── exceptions.py                     # Custom exceptions
│   │
│   ├── api/
│   │   ├── __init__.py
│   │   └── v1/
│   │       ├── __init__.py
│   │       └── objects.py               # Detection endpoints
│   │
│   ├── services/
│   │   ├── __init__.py
│   │   ├── yolo_service.py              # YOLO model wrapper
│   │   ├── detection_service.py         # Detection orchestrator
│   │   ├── image_service.py             # Image processing
│   │   └── spatial_service.py           # Spatial position logic
│   │
│   └── utils/
│       ├── __init__.py
│       ├── logger.py                    # Logging setup
│       └── validators.py                # Input validation
│
├── models/                               # YOLO model storage
│   └── .gitkeep
│
├── tests/
│   ├── __init__.py
│   ├── conftest.py                      # Pytest configuration
│   ├── test_api_endpoints.py            # API tests
│   ├── test_spatial_service.py          # Spatial reasoning tests
│   └── test_image_service.py            # Image processing tests
│
├── scripts/
│   ├── download_model.py                # Download YOLO model
│   ├── example_usage.py                 # Usage examples
│   ├── test_api.py                      # Automated test suite
│   └── generate_test_images.py          # Generate test images
│
├── run.bat                              # Windows startup script
├── run.sh                               # macOS/Linux startup script
├── Dockerfile                           # Docker containerization
├── docker-compose.yml                   # Docker compose config
└── .gitignore                          # Git ignore rules
```

---

## 🚀 Quick Commands

### Start Server
```bash
# Windows
cd d:\S8 Project\S.A.G.E\ml\object-detection
run.bat

# macOS/Linux
cd ml/object-detection
./run.sh
```

### Manual Start
```bash
cd d:\S8 Project\S.A.G.E\ml\object-detection
python -m uvicorn src.main:app --host 127.0.0.1 --port 8001
```

### Open API Documentation
```
http://127.0.0.1:8001/docs
```

### Run Tests
```bash
pytest tests/ -v
```

### Test API
```bash
python scripts/test_api.py
```

### Generate Test Images
```bash
python scripts/generate_test_images.py
```

---

## 📊 System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      Mobile Application                          │
│                   (Captures Base64 Image)                        │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             │ POST /api/v1/objects/detect
                             │ {image_base64, confidence_threshold}
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                    FastAPI Server                                │
│                (runs on localhost:8001)                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌────────────────────────────────────────────────────────┐     │
│  │           Detection Service Orchestrator               │     │
│  └────────────────────────────────────────────────────────┘     │
│                          │                                       │
│    ┌─────────────────────┼─────────────────────┐               │
│    ▼                     ▼                     ▼               │
│  ┌──────────┐      ┌──────────┐      ┌──────────────┐         │
│  │  Image   │      │  YOLO    │      │   Spatial    │         │
│  │ Service  │      │ Service  │      │   Service    │         │
│  └──────────┘      └──────────┘      └──────────────┘         │
│    │                   │                   │                   │
│    │ Decode Base64    │ Inference        │ Position Logic     │
│    │ Validate Image   │ (20-50ms)        │ (3x3 Grid)        │
│    │ Convert to Array │ Return Detections│ Create Description │
│    └─────────────────┴──────────────────┴──────────────────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
                             │
                             │ JSON Response
                             │ {detected_objects, inference_time}
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Mobile Application                          │
│              (Displays Detection Results)                        │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🔄 Complete Workflow

### 1. **Image Capture & Encoding** (Mobile App)
   - User captures image from camera
   - Image encoded to Base64 string

### 2. **HTTP Request Transmission** (Network)
   - POST to `http://127.0.0.1:8001/api/v1/objects/detect`
   - JSON body contains Base64 image + confidence threshold

### 3. **Image Decoding** (Image Service)
   - Decode Base64 to binary
   - Validate format (JPEG, PNG, BMP, WebP)
   - Check image size (<10 MB)
   - Convert to NumPy array

### 4. **Object Detection** (YOLO Service)
   - YOLO processes image through neural network
   - Detects objects + confidence scores
   - Returns bounding box coordinates

### 5. **Spatial Reasoning** (Spatial Service)
   - Calculate object center point
   - Map to 3x3 grid (left/center/right × top/middle/bottom)
   - Generate human-readable description

### 6. **Response Generation** (Detection Service)
   - Format all detections into JSON
   - Include inference time metrics
   - Return HTTP 200 with results

### 7. **Mobile App Display** (Mobile App)
   - Parse JSON response
   - Display "person on left side"
   - Show confidence scores
   - Render UI updates

---

## 📊 API Endpoints

### Health Check
```
GET /api/v1/objects/health
```
**Purpose:** Verify model is loaded  
**Response:** `{status, model_loaded, model_name}`

### Object Detection
```
POST /api/v1/objects/detect
```
**Request:** `{image_base64, confidence_threshold: 0.5}`  
**Response:** `{status, inference_time_ms, detected_objects, total_detections}`

### API Info
```
GET /
```
**Response:** API metadata and available endpoints

---

## 🎯 Configuration

Edit `config.py` to customize:

```python
# Model
YOLO_MODEL_NAME = "yolov8s"  # Can change to yolov8n (faster) or yolov8m (more accurate)

# Detection
DEFAULT_CONFIDENCE_THRESHOLD = 0.5

# Server
HOST = "127.0.0.1"
PORT = 8001

# Limits
MAX_IMAGE_SIZE_MB = 10

# Logging
LOG_LEVEL = "INFO"
```

---

## 📈 Performance Metrics

| Metric | Value |
|--------|-------|
| Model Load Time (first run) | 1-3 seconds |
| Model File Size | 22.5 MB (YOLOv8s) |
| Inference Time (CPU) | 30-50ms |
| Inference Time (GPU) | 5-10ms |
| Memory Usage (persistent) | 150-230 MB |
| Supported Image Formats | JPEG, PNG, BMP, WebP |
| Max Image Size | 10 MB |

---

## 🧪 Testing Strategy

### 1. **Unit Tests** (Individual Components)
```bash
pytest tests/test_spatial_service.py -v
pytest tests/test_image_service.py -v
```

### 2. **Integration Tests** (Full Pipeline)
```bash
pytest tests/test_api_endpoints.py -v
```

### 3. **Manual Testing** (Swagger UI)
- Open: http://127.0.0.1:8001/docs
- Try it out on `/api/v1/objects/detect`
- Use sample Base64 images

### 4. **Automated Testing** (Full Suite)
```bash
python scripts/test_api.py
```

### 5. **Performance Testing**
- Monitor `inference_time_ms` in responses
- Test with different image sizes
- Test with different confidence thresholds

---

## 🔐 Error Handling

The service returns proper HTTP status codes:

| Status | Meaning |
|--------|---------|
| 200 | Detection successful |
| 400 | Invalid input (bad Base64, invalid threshold) |
| 422 | Validation error (missing required fields) |
| 500 | Server error (model failure, inference failure) |

All errors include JSON response with error type and message.

---

## 📦 Dependencies

Key packages:
- **fastapi** - Web framework
- **uvicorn** - ASGI server
- **ultralytics** - YOLO library
- **torch** - Deep learning framework
- **numpy** - Numerical computing
- **pillow** - Image processing
- **opencv** - Computer vision
- **pydantic** - Data validation

---

## 🚢 Deployment Options

### Option 1: Local Development
```bash
python -m uvicorn src.main:app --host 127.0.0.1 --port 8001
```

### Option 2: Docker
```bash
docker-compose up
```

### Option 3: Production
```bash
uvicorn src.main:app --host 0.0.0.0 --port 8001 --workers 4
```

---

## 🔗 Integration with S.A.G.E Backend

To integrate with your main backend:

```python
import requests

# In your FastAPI backend
@app.post("/detect-objects")
async def detect_objects(image_base64: str):
    response = requests.post(
        "http://127.0.0.1:8001/api/v1/objects/detect",
        json={
            "image_base64": image_base64,
            "confidence_threshold": 0.5
        }
    )
    return response.json()
```

---

## 📝 Logs & Debugging

### Enable Debug Logging
```python
# In config.py
LOG_LEVEL = "DEBUG"
```

### View Server Logs
- Console output shows all activity
- Inference time printed for each request
- Error messages for troubleshooting

---

## 🎓 Learning Resources

- **YOLO Documentation:** https://docs.ultralytics.com/
- **FastAPI Guide:** https://fastapi.tiangolo.com/
- **OpenCV Docs:** https://docs.opencv.org/
- **Pydantic Validation:** https://docs.pydantic.dev/

---

## ✅ Checklist

- [x] YOLO model service with auto-download
- [x] Image processing pipeline
- [x] Spatial position reasoning (3x3 grid)
- [x] FastAPI endpoints with validation
- [x] Comprehensive error handling
- [x] Unit and integration tests
- [x] Complete documentation
- [x] Docker containerization
- [x] Testing scripts and examples
- [x] Startup scripts for easy launch

---

## 🎯 Next Steps

1. **Start the server** using `run.bat` or `run.sh`
2. **Test with Swagger UI** at http://127.0.0.1:8001/docs
3. **Generate test images** with `scripts/generate_test_images.py`
4. **Run test suite** with `python scripts/test_api.py`
5. **Integrate with your mobile app** using the API
6. **Deploy** to production when ready

---

## 📞 Support

For issues:
1. Check the logs in the terminal
2. Run `python scripts/test_api.py` for diagnostics
3. Review TESTING_GUIDE.md for common issues
4. Check QUICK_START_TESTING.md for quick solutions

---

## 📄 Documentation Files

- **README.md** - Full project documentation
- **QUICK_START_TESTING.md** - Fast testing guide (start here!)
- **TESTING_GUIDE.md** - Detailed testing instructions
- **This file** - Project overview

---

**Everything is ready to test! Start with QUICK_START_TESTING.md** 🚀
