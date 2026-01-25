# S.A.G.E Face Recognition Service

FastAPI-based face recognition and enrollment service for S.A.G.E smartglasses.

## 🎯 Features

- **Face Recognition**: Detect and recognize multiple faces in images
- **Face Enrollment**: Register new faces with name and relation
- **Duplicate Detection**: Prevents enrolling the same face twice
- **Configurable Threshold**: Adjust matching sensitivity per request
- **Base64 Image Support**: Accepts images as base64 strings
- **RESTful API**: Easy integration with mobile app and backend

## 🚀 Quick Start

### 1. Install Dependencies

```bash
cd ml/facial-recognition/src
pip install -r requirements.txt
```

### 2. Start the Service

```bash
python face_recognition_service.py
```

The service will start on `http://0.0.0.0:8002`

### 3. Test the Service

Open your browser and go to:
- API Documentation: http://localhost:8002/docs
- Health Check: http://localhost:8002/health

## 📡 API Endpoints

### 1. Health Check

**GET** `/health`

Check if the service is running and model is loaded.

**Response:**
```json
{
  "status": "healthy",
  "service": "S.A.G.E Face Recognition Service",
  "version": "1.0.0",
  "model_loaded": true,
  "database_connected": true,
  "timestamp": "2026-01-25T10:30:00"
}
```

### 2. Recognize Faces

**POST** `/recognize`

Recognize all faces in an image and match them against the database.

**Request:**
```json
{
  "image_base64": "iVBORw0KGgoAAAANSUhEUgAA...",
  "threshold": 0.5
}
```

**Parameters:**
- `image_base64` (required): Base64 encoded image string
- `threshold` (optional): Matching threshold (0.3-0.9, default: 0.5)

**Response:**
```json
{
  "success": true,
  "message": "Face recognition completed",
  "faces_detected": 2,
  "faces": [
    {
      "name": "John Doe",
      "description": "Friend",
      "confidence": 0.87,
      "bounding_box": [100, 150, 300, 400]
    },
    {
      "name": "Unknown",
      "description": "Face not in database",
      "confidence": 0.0,
      "bounding_box": [400, 150, 600, 400]
    }
  ],
  "timestamp": "2026-01-25T10:30:00"
}
```

**Possible Messages:**
- `"Face recognition completed"` - Successfully recognized faces
- `"No face detected in the image"` - No faces found
- `"Face not in database"` - Face detected but not recognized

### 3. Enroll Face

**POST** `/enroll`

Register a new face into the database.

**Request:**
```json
{
  "image_base64": "iVBORw0KGgoAAAANSUhEUgAA...",
  "name": "John Doe",
  "description": "Friend",
  "threshold": 0.5
}
```

**Parameters:**
- `image_base64` (required): Base64 encoded image with **single face**
- `name` (required): Person's name
- `description` (required): Relation or description (e.g., "Friend", "Colleague", "Family")
- `threshold` (optional): Duplicate detection threshold (0.3-0.9, default: 0.5)

**Response (Success):**
```json
{
  "success": true,
  "message": "Face enrolled successfully",
  "person_id": 13,
  "name": "John Doe",
  "confidence": 0.95,
  "timestamp": "2026-01-25T10:30:00"
}
```

**Response (Error):**
```json
{
  "success": false,
  "message": "Multiple faces detected. Please provide an image with a single face for enrollment",
  "timestamp": "2026-01-25T10:30:00"
}
```

**Possible Error Messages:**
- `"No face detected in the image"` - No face found
- `"Multiple faces detected. Please provide an image with a single face for enrollment"` - More than one face
- `"Face already exists in database: John Doe (confidence: 0.85)"` - Duplicate detected

### 4. Get Statistics

**GET** `/stats`

Get database statistics.

**Response:**
```json
{
  "total_faces": 12,
  "registered_names": ["John Doe", "Jane Smith", "..."],
  "timestamp": "2026-01-25T10:30:00"
}
```

## 🔧 Configuration

Edit `config.py` to customize:

```python
# Service settings
SERVICE_PORT = 8002
DEFAULT_THRESHOLD = 0.5

# Model settings
INSIGHTFACE_MODEL = "buffalo_l"
DETECTION_SIZE = (640, 640)
```

## 📝 Usage Examples

### Python Example

```python
import requests
import base64

# Read image and encode to base64
with open("photo.jpg", "rb") as f:
    image_base64 = base64.b64encode(f.read()).decode('utf-8')

# Recognize faces
response = requests.post(
    "http://localhost:8002/recognize",
    json={
        "image_base64": image_base64,
        "threshold": 0.5
    }
)

result = response.json()
print(f"Detected {result['faces_detected']} faces")
for face in result['faces']:
    print(f"- {face['name']}: {face['description']} ({face['confidence']:.2f})")

# Enroll a new face
response = requests.post(
    "http://localhost:8002/enroll",
    json={
        "image_base64": image_base64,
        "name": "John Doe",
        "description": "Friend",
        "threshold": 0.5
    }
)

result = response.json()
if result['success']:
    print(f"✓ Enrolled: {result['name']} (ID: {result['person_id']})")
else:
    print(f"✗ Enrollment failed: {result['message']}")
```

### JavaScript/Flutter Example

```javascript
// Read image as base64
const imageBase64 = "iVBORw0KGgoAAAANSUhEUgAA...";

// Recognize faces
const response = await fetch("http://localhost:8002/recognize", {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify({
    image_base64: imageBase64,
    threshold: 0.5
  })
});

const result = await response.json();
console.log(`Detected ${result.faces_detected} faces`);
result.faces.forEach(face => {
  console.log(`${face.name}: ${face.description} (${face.confidence})`);
});
```

### cURL Example

```bash
# Recognize faces
curl -X POST "http://localhost:8002/recognize" \
  -H "Content-Type: application/json" \
  -d '{
    "image_base64": "iVBORw0KGgoAAAANSUhEUgAA...",
    "threshold": 0.5
  }'

# Enroll face
curl -X POST "http://localhost:8002/enroll" \
  -H "Content-Type: application/json" \
  -d '{
    "image_base64": "iVBORw0KGgoAAAANSUhEUgAA...",
    "name": "John Doe",
    "description": "Friend",
    "threshold": 0.5
  }'
```

## 🎨 Threshold Tuning

The threshold controls how similar two faces must be to match:

- **0.3-0.4**: Very loose matching (more false positives)
- **0.5**: Balanced (recommended default)
- **0.6-0.7**: Strict matching (fewer false positives)
- **0.8-0.9**: Very strict (may miss some matches)

Adjust based on your use case:
- **High security**: Use higher threshold (0.6-0.7)
- **Convenience**: Use lower threshold (0.4-0.5)

## 📂 Project Structure

```
src/
├── face_recognition_service.py  # Main FastAPI server
├── face_matcher.py              # Core matching logic
├── api_models.py                # Pydantic request/response models
├── config.py                    # Configuration settings
├── requirements.txt             # Python dependencies
├── utils/
│   ├── db_helper.py            # Database utilities
│   └── image_utils.py          # Image processing utilities
└── models/
    └── face_data.db            # SQLite database
```

## 🔍 Database Schema

```sql
CREATE TABLE people (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    description TEXT,
    embedding BLOB NOT NULL  -- 512D numpy array
);
```

## 🐛 Troubleshooting

### Model Loading Error

If you see "Failed to load model", ensure InsightFace is installed correctly:

```bash
pip install insightface==0.7.3 onnxruntime==1.16.3
```

### Database Not Found

The database will be created automatically at `src/models/face_data.db`.
If issues persist, create it manually:

```python
python -c "from utils.db_helper import init_db; init_db('models/face_data.db')"
```

### Image Decoding Error

Ensure your base64 string:
- Is properly encoded
- Contains valid image data (JPEG, PNG, BMP)
- Doesn't exceed 10MB

### Port Already in Use

Change the port in `config.py`:

```python
SERVICE_PORT = 8003  # Or any available port
```

## 📊 Performance

- **Model**: InsightFace buffalo_l (512D embeddings)
- **Detection**: ~50-100ms per image
- **Matching**: ~1ms per face comparison
- **Database**: SQLite (fast for <10K faces)

## 🔐 Security Notes

For production deployment:

1. **Enable authentication** on endpoints
2. **Restrict CORS origins** in `face_recognition_service.py`
3. **Use HTTPS** instead of HTTP
4. **Rate limit** requests to prevent abuse
5. **Encrypt database** for sensitive data

## 📞 Integration with Backend

The backend's `FaceRecognitionClient` expects this service to run at the URL specified in `FACE_RECOGNITION_URL` (typically `http://localhost:8002`).

Update backend config:
```python
# app/backend/app/config.py
FACE_RECOGNITION_URL = "http://localhost:8002"
```

## 📄 License

Part of the S.A.G.E project - Team Nikhil's Face Recognition Module
