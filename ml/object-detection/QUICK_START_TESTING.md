# Quick Start Guide - Testing Object Detection Service

## 🚀 Step 1: Start the Server (3 minutes)

### Windows Users:
```bash
cd d:\S8 Project\S.A.G.E\ml\object-detection
run.bat
```

### macOS/Linux Users:
```bash
cd ml/object-detection
./run.sh
```

### Manual Start (All Platforms):
```bash
cd d:\S8 Project\S.A.G.E\ml\object-detection
python -m venv venv
venv\Scripts\activate  # or: source venv/bin/activate (macOS/Linux)
pip install -r requirements.txt
python -m uvicorn src.main:app --host 127.0.0.1 --port 8001
```

**Wait for this output:**
```
INFO:     Application startup complete
INFO:     Uvicorn running on http://127.0.0.1:8001 (Press CTRL+C to quit)
```

---

## 📊 Step 2: Test with Swagger UI (Interactive Testing)

### Open API Documentation:
```
http://127.0.0.1:8001/docs
```

You'll see an interactive Swagger UI with all endpoints.

---

## ✅ Step 2A: Quick Health Check Test

1. Expand **`GET /api/v1/objects/health`**
2. Click **"Try it out"**
3. Click **"Execute"**

**Expected Response:**
```json
{
  "status": "healthy",
  "model_loaded": true,
  "model_name": "yolov8s"
}
```

---

## 🎯 Step 2B: Test Object Detection (Main Test)

### Using Sample Base64 (Easiest):

1. Expand **`POST /api/v1/objects/detect`**
2. Click **"Try it out"**
3. Paste this in the request body:

```json
{
  "image_base64": "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==",
  "confidence_threshold": 0.5
}
```

4. Click **"Execute"**

**Expected Response:**
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

## 🖼️ Step 3: Test with Your Own Image

### Option A: Using Python Script (Easiest)

1. **Generate test images:**
```bash
cd d:\S8 Project\S.A.G.E\ml\object-detection
python scripts/generate_test_images.py
```

2. **Encode image to Base64 (Python):**
```python
import base64

# Read your image
with open("tests/sample_images/objects.png", "rb") as f:
    image_base64 = base64.b64encode(f.read()).decode()

print(image_base64)  # Copy this output
```

3. **Paste the Base64 string into Swagger UI** in the `/api/v1/objects/detect` endpoint

---

### Option B: Using Test Runner Script

```bash
# Run full test suite
python scripts/test_api.py

# Or test with specific image
python scripts/test_api.py path/to/your/image.jpg
```

**This will:**
- ✓ Check server connection
- ✓ Run detection with test image
- ✓ Test error handling
- ✓ Test different confidence thresholds
- ✓ Print detailed results

---

## 🧪 Step 4: Manual Testing with cURL

```bash
curl -X POST http://127.0.0.1:8001/api/v1/objects/detect \
  -H "Content-Type: application/json" \
  -d '{
    "image_base64": "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==",
    "confidence_threshold": 0.5
  }'
```

---

## 🐍 Step 5: Testing with Python

Create a file `test.py`:

```python
import requests
import base64

# Method 1: Using your own image
def test_with_image(image_path):
    with open(image_path, "rb") as f:
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

# Run it
test_with_image("your_image.jpg")
```

Run:
```bash
python test.py
```

---

## 📝 Test Different Confidence Thresholds

Try these in Swagger UI:

| Threshold | What it means |
|-----------|--------------|
| 0.3 | Very sensitive - detects more objects, including low confidence ones |
| 0.5 | Balanced - good for most use cases (default) |
| 0.7 | Strict - only high confidence detections |
| 0.9 | Very strict - only very confident detections |

**Example Request:**
```json
{
  "image_base64": "YOUR_BASE64_IMAGE",
  "confidence_threshold": 0.3
}
```

---

## 🐛 Troubleshooting

### Issue: Server won't start
```
Error: Connection refused
```
**Solution:** 
- Make sure Python is installed: `python --version`
- Try again with: `python -m uvicorn src.main:app --host 127.0.0.1 --port 8001`

### Issue: "Model loading..." takes too long
**What's happening:** YOLO is downloading ~22.5 MB on first run
- **Wait 2-3 minutes** - this is one-time only
- Subsequent runs will be instant

### Issue: "Connection refused" in Swagger UI
**Check:**
1. Is the server running? (you should see the startup message)
2. Is it on port 8001? (default in our config)
3. Try: `http://127.0.0.1:8001/api/v1/objects/health`

### Issue: Invalid Base64 error
**Causes:**
- Image file is corrupted
- Bad encoding
- File path is wrong

**Solution:**
- Use the provided sample Base64 first
- Try: `python scripts/generate_test_images.py` to create test images

### Issue: No objects detected
**Possible reasons:**
- Image is too small or unclear
- Objects not in YOLO's training classes
- Confidence threshold too high

**Try:**
- Use clearer images with common objects (people, cars, etc.)
- Lower confidence_threshold to 0.3

---

## 📊 Available Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/v1/objects/detect` | POST | Detect objects in image |
| `/api/v1/objects/health` | GET | Check if model is loaded |
| `/docs` | GET | Swagger UI (interactive testing) |
| `/redoc` | GET | ReDoc documentation |
| `/` | GET | API info |

---

## 📈 Response Format Explained

```json
{
  "status": "success",                    // Request status
  "inference_time_ms": 45.23,            // How long detection took
  "detected_objects": [
    {
      "label": "person",                 // What object is it?
      "confidence": 0.95,                // How sure is the model? (0-1)
      "position_description": "person on the left side",  // Human-readable
      "bounding_box": {                  // Where in the image?
        "x": 10.5,                       // X coordinate
        "y": 50.2,                       // Y coordinate
        "width": 80.3,                   // Box width
        "height": 200.1                  // Box height
      },
      "relative_position": {
        "horizontal": "left",            // left, center, or right
        "vertical": "middle"             // top, middle, or bottom
      }
    }
  ],
  "total_detections": 1                  // How many objects found?
}
```

---

## ✨ Next Steps

1. **Test with different images** to understand how the service works
2. **Try different confidence thresholds** to find the right balance
3. **Integrate with your mobile app** by sending Base64 images
4. **Monitor performance** using the `inference_time_ms` metric
5. **Deploy** using Docker when ready

---

## 🎓 Learning Resources

- **API Documentation:** http://127.0.0.1:8001/docs
- **YOLO Docs:** https://docs.ultralytics.com/
- **FastAPI Guide:** https://fastapi.tiangolo.com/
- **Base64 Encoding:** https://en.wikipedia.org/wiki/Base64

---

## 💡 Pro Tips

1. **Keep the server running in one terminal** while testing in another
2. **Use Swagger UI** for quick interactive testing
3. **Use test_api.py** for automated testing
4. **Start with low confidence thresholds** to see more detections
5. **Use clear, well-lit images** for best results

---

## ✅ You're Ready!

Everything is set up. Start testing now:

1. Terminal 1: `run.bat` (or `./run.sh`)
2. Browser: http://127.0.0.1:8001/docs
3. Click "Try it out" and start testing!

Good luck! 🚀
