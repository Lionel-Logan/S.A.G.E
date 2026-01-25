# Testing Guide - Object Detection Service

## Quick Start: Running the Service

### Option 1: Using the Startup Script (Easiest)

**Windows:**
```bash
cd d:\S8 Project\S.A.G.E\ml\object-detection
run.bat
```

**macOS/Linux:**
```bash
cd ml/object-detection
chmod +x run.sh
./run.sh
```

### Option 2: Manual Setup

**Step 1: Navigate to the project directory**
```bash
cd d:\S8 Project\S.A.G.E\ml\object-detection
```

**Step 2: Create and activate virtual environment**
```bash
# Windows
python -m venv venv
venv\Scripts\activate

# macOS/Linux
python3 -m venv venv
source venv/bin/activate
```

**Step 3: Install dependencies**
```bash
pip install -r requirements.txt
```

**Step 4: Start the server**
```bash
python -m uvicorn src.main:app --host 127.0.0.1 --port 8001 --reload
```

You should see:
```
INFO:     Started server process [XXXX]
INFO:     Waiting for application startup.
...YOLO model loading messages...
INFO:     Application startup complete
INFO:     Uvicorn running on http://127.0.0.1:8001 (Press CTRL+C to quit)
```

---

## Testing with Swagger UI (Interactive Testing)

### Step 1: Open API Documentation

Once the server is running, open your browser and go to:

**Main Swagger UI:**
```
http://127.0.0.1:8001/docs
```

You'll see the interactive API documentation with all endpoints.

### Step 2: Test Health Check First

1. **Expand the `GET /api/v1/objects/health` endpoint**
2. Click the **"Try it out"** button
3. Click **"Execute"**
4. You should see a 200 response with:
   ```json
   {
     "status": "healthy",
     "model_loaded": true,
     "model_name": "yolov8s"
   }
   ```

---

## Step 3: Test Object Detection with Sample Images

### Method A: Using Test Image from Web (Easiest)

1. **Expand the `POST /api/v1/objects/detect` endpoint**
2. Click **"Try it out"**
3. In the request body, paste this sample request with a pre-encoded image:

**Sample 1: Person Image**
```json
{
  "image_base64": "/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAAIBAQIBAQICAgICAgICAwUDAwwDAwsGFAwMDQ4SEw8TExNTGBEUFRYTGBESExkTGBESExkTGBESExkTGB//wAALCAA4AyABAREA/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwD9/KKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigD/9k",
  "confidence_threshold": 0.5
}
```

**Sample 2: Multiple Objects**
```json
{
  "image_base64": "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==",
  "confidence_threshold": 0.5
}
```

---

### Method B: Encode Your Own Test Image

If you want to test with your own image:

1. **Create a test image** (e.g., `test_image.jpg`) in your project directory
2. **Run this Python script** to encode it to Base64:

```python
import base64

# Read your image
with open("test_image.jpg", "rb") as f:
    image_base64 = base64.b64encode(f.read()).decode()

# Print it (copy this output)
print(image_base64)
```

3. **Copy the output Base64 string** and paste it into the Swagger UI request body

---

## Testing with Example Request

Here's a complete example you can copy directly into Swagger UI:

**Request Body:**
```json
{
  "image_base64": "iVBORw0KGgoAAAANSUhEUgAAAQAAAAEACAIAAAB7OR7PAAAAIElEQVRoge3BMQEAAADCoPVPbQlfoAAAAAAAAAAAAAAAAAAAAEQDxcIAAcARBKwH",
  "confidence_threshold": 0.5
}
```

**Expected Response (if objects detected):**
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
    }
  ],
  "total_detections": 1
}
```

---

## Alternative Testing Methods

### Using cURL (Command Line)

```bash
curl -X POST http://127.0.0.1:8001/api/v1/objects/detect \
  -H "Content-Type: application/json" \
  -d '{
    "image_base64": "YOUR_BASE64_ENCODED_IMAGE_HERE",
    "confidence_threshold": 0.5
  }'
```

### Using Python Requests

Create a file `test_detection.py`:

```python
import requests
import base64

# Method 1: Using your own image file
def test_with_file():
    with open("test_image.jpg", "rb") as f:
        image_base64 = base64.b64encode(f.read()).decode()
    
    response = requests.post(
        "http://127.0.0.1:8001/api/v1/objects/detect",
        json={
            "image_base64": image_base64,
            "confidence_threshold": 0.5
        }
    )
    
    print("Status:", response.status_code)
    print("Response:", response.json())

# Run test
test_with_file()
```

Run it:
```bash
python test_detection.py
```

---

## Available Endpoints

### 1. Health Check
- **Endpoint:** `GET /api/v1/objects/health`
- **No authentication required**
- **Response:** Model status

### 2. Detect Objects
- **Endpoint:** `POST /api/v1/objects/detect`
- **Required:** Base64 image in JSON body
- **Optional:** Confidence threshold (0-1)
- **Response:** JSON with detections, positions, and inference time

### 3. API Info
- **Endpoint:** `GET /`
- **Response:** API version and available endpoints

---

## Troubleshooting

### Issue: Model Takes Long Time to Load

**What's happening:** YOLO model is being downloaded on first run (~22.5 MB)
- **Wait 2-3 minutes** for first startup
- On subsequent runs, it will be instant

**Check logs:**
```
...YOLO model loading...
YOLO model loaded successfully: yolov8s
✓ All services initialized successfully
```

### Issue: "Connection Refused" Error

**Solution:** Make sure server is running
```bash
# You should see this in terminal:
INFO:     Application startup complete
INFO:     Uvicorn running on http://127.0.0.1:8001
```

### Issue: Invalid Base64 Error

**Cause:** Image data is corrupted or invalid format
**Solution:** 
1. Use the provided sample Base64 first
2. Ensure your image is JPEG, PNG, BMP, or WebP
3. Verify Base64 encoding is correct

### Issue: No Objects Detected

**Causes:**
- Image quality too low
- Objects are too small
- Confidence threshold too high
- Image doesn't contain common objects (person, car, etc.)

**Solution:**
- Lower confidence_threshold to 0.3 or 0.4
- Use clearer images
- Test with images containing common objects

---

## Real-World Test Scenarios

### Test 1: Basic Detection
1. Open `http://127.0.0.1:8001/docs`
2. Click Try it out on `/api/v1/objects/detect`
3. Use the sample Base64 from Method A
4. Verify response format

### Test 2: Confidence Threshold
1. Test with threshold 0.5
2. Test with threshold 0.3 (detects more, lower confidence)
3. Test with threshold 0.9 (detects only high-confidence objects)

### Test 3: Error Handling
1. Send empty Base64: `"image_base64": ""`
2. Send invalid Base64: `"image_base64": "not_base64!!!"`
3. Send invalid threshold: `"confidence_threshold": 1.5`
4. Verify error responses with proper HTTP status codes

---

## Next Steps

Once testing is complete:

1. **Integrate with your mobile app** by sending Base64 images from the frontend
2. **Adjust confidence thresholds** based on your use case
3. **Monitor performance** using the inference_time_ms metric
4. **Deploy** using Docker if needed (see docker-compose.yml)

---

## Quick Reference Commands

| Action | Command |
|--------|---------|
| Start server | `python -m uvicorn src.main:app --host 127.0.0.1 --port 8001` |
| Swagger UI | `http://127.0.0.1:8001/docs` |
| API Docs | `http://127.0.0.1:8001/docs` |
| Health check | `http://127.0.0.1:8001/api/v1/objects/health` |
| Run tests | `pytest tests/ -v` |
| Download model | `python scripts/download_model.py` |

