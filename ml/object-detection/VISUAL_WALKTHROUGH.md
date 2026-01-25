# 🎬 VISUAL TESTING WALKTHROUGH

## Step-by-Step Visual Guide

---

## STEP 1: Start the Server

### Windows Users:

**1. Open File Explorer**
```
Navigate to: d:\S8 Project\S.A.G.E\ml\object-detection
```

**2. Double-click `run.bat`**
```
A terminal window opens
```

**3. Wait for this message:**
```
INFO:     Uvicorn running on http://127.0.0.1:8001 (Press CTRL+C to quit)
```

### macOS/Linux Users:

**1. Open Terminal**

**2. Run:**
```bash
cd ml/object-detection
./run.sh
```

**3. Wait for:**
```
INFO:     Uvicorn running on http://127.0.0.1:8001
```

---

## STEP 2: Open Swagger UI

**Copy-paste this into browser:**
```
http://127.0.0.1:8001/docs
```

**You'll see:**
```
═══════════════════════════════════════════════════════════
Object Detection Service v1.0.0
YOLO-based object detection service with spatial reasoning
═══════════════════════════════════════════════════════════

▼ GET  /                           [Try it out]
▼ GET  /api/v1/objects/health     [Try it out]
▼ POST /api/v1/objects/detect     [Try it out]
```

---

## STEP 3: Test Health Check (First Test!)

**1. Click the dropdown:**
```
▼ GET  /api/v1/objects/health
```

**2. You'll see:**
```
GET /api/v1/objects/health
```

**3. Click "Try it out" button**

**4. Click "Execute" button**

**5. See response at bottom:**
```json
{
  "status": "healthy",
  "model_loaded": true,
  "model_name": "yolov8s"
}
```

✓ **SUCCESS!** Model is ready!

---

## STEP 4: Test Object Detection (Main Test!)

**1. Click the dropdown:**
```
▼ POST /api/v1/objects/detect
```

**2. You'll see:**
```
POST /api/v1/objects/detect
```

**3. Click "Try it out" button**

**4. You'll see a text area with example JSON**

**5. Clear it and paste this:**
```json
{
  "image_base64": "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==",
  "confidence_threshold": 0.5
}
```

**6. Click "Execute" button**

**7. Wait 2-3 seconds**

**8. See response below:**
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

✓ **SUCCESS!** Objects detected!

---

## STEP 5: Try Different Scenarios (Optional)

### Scenario 1: High Sensitivity
```json
{
  "image_base64": "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==",
  "confidence_threshold": 0.3
}
```
📊 Result: More objects (lower threshold = more detections)

### Scenario 2: High Precision
```json
{
  "image_base64": "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==",
  "confidence_threshold": 0.9
}
```
📊 Result: Fewer objects (higher threshold = only confident detections)

---

## STEP 6: Test With Your Own Image (Optional)

**1. You have an image? (JPG, PNG, BMP, WebP)**

**2. Encode it to Base64:**

Open Python:
```bash
python
```

Run this:
```python
import base64

with open("your_image.jpg", "rb") as f:
    image_base64 = base64.b64encode(f.read()).decode()

print(image_base64)
```

Copy the long string output.

**3. Back in Swagger UI:**

Click Try it out on `/api/v1/objects/detect`

Replace the image_base64 value with your copied string:
```json
{
  "image_base64": "PASTE_YOUR_LONG_STRING_HERE",
  "confidence_threshold": 0.5
}
```

**4. Click Execute**

**5. See results!**

---

## 📊 Understanding the Response

### Response Fields:

```json
{
  "status": "success",                          // ✓ Success
  "inference_time_ms": 45.23,                  // ⏱️  Time taken (milliseconds)
  "detected_objects": [                        // 👁️ Array of detections
    {
      "label": "person",                      // 🏷️  What is it?
      "confidence": 0.95,                     // 📊 Confidence (0-1, where 1=100%)
      "position_description": "person on...",  // 📍 Human readable
      "bounding_box": {                       // 📦 Box coordinates
        "x": 10.5,                           // Left edge
        "y": 50.2,                           // Top edge
        "width": 80.3,                       // Width
        "height": 200.1                      // Height
      },
      "relative_position": {                 // 🎯 Position in grid
        "horizontal": "left",                // left, center, right
        "vertical": "middle"                 // top, middle, bottom
      }
    }
  ],
  "total_detections": 1                       // 🔢 Total objects found
}
```

---

## ❌ Testing Error Cases (Advanced)

### Test Invalid Base64:

```json
{
  "image_base64": "not_valid_base64!!!",
  "confidence_threshold": 0.5
}
```

**Result:** HTTP 400 error
```json
{
  "detail": {
    "status": "error",
    "error_type": "InvalidBase64Exception",
    "message": "Invalid Base64 format"
  }
}
```

### Test Empty Image:

```json
{
  "image_base64": "",
  "confidence_threshold": 0.5
}
```

**Result:** HTTP 400 error
```json
{
  "detail": {
    "status": "error",
    "error_type": "ValidationException",
    "message": "Image base64 string cannot be empty"
  }
}
```

### Test Invalid Threshold:

```json
{
  "image_base64": "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==",
  "confidence_threshold": 1.5
}
```

**Result:** HTTP 422 validation error

---

## 🎯 Quick Reference Table

| What | Where | How |
|------|-------|-----|
| **Start Server** | Terminal | `run.bat` or `run.sh` |
| **Open Swagger UI** | Browser | `http://127.0.0.1:8001/docs` |
| **Health Check** | Swagger | Click `GET /api/v1/objects/health` → Try it out → Execute |
| **Test Detection** | Swagger | Click `POST /api/v1/objects/detect` → Try it out → Paste JSON → Execute |
| **View Docs** | Browser | `http://127.0.0.1:8001/redoc` |
| **Stop Server** | Terminal | Press `CTRL+C` |

---

## 🎬 Common Test Results

### ✓ Success Response
```
Status: 200 (green)
Body: {status: "success", detected_objects: [...]}
```

### ✗ Bad Request
```
Status: 400 (red)
Body: {status: "error", error_type: "InvalidBase64Exception"}
```

### ✗ Validation Error
```
Status: 422 (red)
Body: Shows validation errors
```

### ✗ Server Error
```
Status: 500 (red)
Body: Server error message
```

---

## 🎓 Swagger UI Tips

### Tip 1: Collapsible Sections
Click the arrow (▼) to expand/collapse endpoints

### Tip 2: Auto-Fill
Swagger shows example formats - modify them for your test

### Tip 3: Response Codes
- 🟢 2xx = Success
- 🟠 4xx = Bad request (your fault)
- 🔴 5xx = Server error (our fault)

### Tip 4: Copy & Paste
Right-click to copy entire request or response

### Tip 5: Multiple Tests
Keep the page open and run multiple tests

---

## ⏱️ Expected Timing

```
1. Click "Execute"
   ↓
2. Server processes request (30-50ms)
   ↓
3. Response appears (instant display)
   ↓
Total time visible: < 1 second
```

---

## 🎉 You're Done!

If you see:
- ✅ Health check returns healthy
- ✅ Detection returns objects
- ✅ Positions are described
- ✅ Inference time is reasonable

**Your object detection service is working perfectly!** 🚀

---

## 📚 Next Steps

1. **Try with your own images** - Follow Step 6
2. **Try different thresholds** - Follow Scenario 1 & 2
3. **Read the docs** - START_HERE.md or README.md
4. **Integrate with mobile** - See PROJECT_OVERVIEW.md
5. **Deploy** - See docker-compose.yml

---

## 💡 Pro Tips

1. **Monitor inference_time_ms**
   - < 100ms = Great!
   - 100-200ms = Good
   - > 200ms = Slow (use GPU or smaller model)

2. **Confidence Threshold Explained**
   - 0.3 = Sensitive, more detections
   - 0.5 = Balanced (default)
   - 0.9 = Strict, fewer but confident detections

3. **If No Objects Detected**
   - Lower threshold to 0.3
   - Use clearer images
   - Test with common objects

4. **Position Description Examples**
   - "person on the left side"
   - "car in the center"
   - "chair in the bottom-right"

---

## ✨ You're All Set!

Everything works. You can now:
- ✅ Test the API
- ✅ Understand responses
- ✅ Try different scenarios
- ✅ Debug issues
- ✅ Integrate with your app

**Happy testing!** 🎊

---

**Need more help?** Read QUICK_START_TESTING.md or SWAGGER_UI_TESTING.md
