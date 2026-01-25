# 🎯 TESTING QUICK REFERENCE

## ⚡ 60-SECOND QUICK START

### Terminal
```bash
cd d:\S8 Project\S.A.G.E\ml\object-detection
run.bat
```

### Browser
```
http://127.0.0.1:8001/docs
```

### Test
```
GET /api/v1/objects/health → Try it out → Execute ✓
```

**Done!** ✨

---

## 📊 RESPONSE EXAMPLES

### Health Check Response
```json
{
  "status": "healthy",
  "model_loaded": true,
  "model_name": "yolov8s"
}
```

### Detection Response
```json
{
  "status": "success",
  "inference_time_ms": 45.23,
  "detected_objects": [
    {
      "label": "person",
      "confidence": 0.95,
      "position_description": "person on the left side",
      "bounding_box": {"x": 10.5, "y": 50.2, "width": 80.3, "height": 200.1},
      "relative_position": {"horizontal": "left", "vertical": "middle"}
    }
  ],
  "total_detections": 1
}
```

---

## 🎬 SWAGGER UI TESTING IN 4 STEPS

### Step 1: Start Server
```
run.bat (or ./run.sh)
```

### Step 2: Open Swagger
```
http://127.0.0.1:8001/docs
```

### Step 3: Click Endpoint
```
Click any endpoint (e.g., POST /api/v1/objects/detect)
```

### Step 4: Test
```
Click "Try it out" → Paste JSON → Click "Execute"
```

---

## 📋 SAMPLE REQUEST

```json
{
  "image_base64": "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==",
  "confidence_threshold": 0.5
}
```

Paste into Swagger UI → Click "Execute"

---

## 📊 QUICK METRICS

| What | Value |
|-----|-------|
| **Startup** | 1-3 min first time |
| **Inference** | 30-50ms per image |
| **Memory** | 150-230 MB |
| **Model** | 22.5 MB |
| **Max Image** | 10 MB |

---

## 🔧 KEY COMMANDS

```bash
# Start server
run.bat

# Test with script
python scripts/test_api.py

# Generate test images
python scripts/generate_test_images.py

# Run unit tests
pytest tests/ -v
```

---

## 📍 API ENDPOINTS

| Endpoint | Purpose |
|----------|---------|
| `GET /api/v1/objects/health` | Check status |
| `POST /api/v1/objects/detect` | Detect objects |
| `GET /docs` | Swagger UI |

---

## ⚙️ CONFIGURATION

Edit `config.py`:
```python
YOLO_MODEL_NAME = "yolov8s"          # Model choice
DEFAULT_CONFIDENCE_THRESHOLD = 0.5   # Default threshold
HOST = "127.0.0.1"                  # Server host
PORT = 8001                          # Server port
```

---

## 🗂️ FILE STRUCTURE

```
ml/object-detection/
├── src/              # Application code
├── tests/            # Tests
├── scripts/          # Helper scripts
├── config.py         # Configuration
├── requirements.txt  # Dependencies
├── run.bat          # Start (Windows)
└── *.md             # Documentation
```

---

## 📚 DOCUMENTATION

| Document | Time | Purpose |
|----------|------|---------|
| START_HERE.md | 5 min | Quick overview |
| VISUAL_WALKTHROUGH.md | 10 min | Step-by-step |
| QUICK_START_TESTING.md | 10 min | Fast testing |
| SWAGGER_UI_TESTING.md | 15 min | Swagger details |
| TESTING_GUIDE.md | 30 min | Comprehensive |
| README.md | Ref | API docs |
| PROJECT_OVERVIEW.md | 30 min | Architecture |

---

## 🎯 POSITION DESCRIPTIONS

```
"person on the left side"
"car in the center"
"chair in the bottom-right"
"dog on the right-middle"
"phone in the top-left"
```

Grid:
```
[top-left]      [top-center]      [top-right]
[mid-left]      [mid-center]      [mid-right]
[bot-left]      [bot-center]      [bot-right]
```

---

## ✅ SUCCESS CHECKLIST

- [ ] Terminal running without errors
- [ ] Swagger UI opens at http://127.0.0.1:8001/docs
- [ ] Health check returns healthy
- [ ] Detection returns JSON
- [ ] Position descriptions show
- [ ] Inference time < 100ms

---

## 🐛 TROUBLESHOOTING QUICK FIXES

| Problem | Solution |
|---------|----------|
| Server won't start | Check Python: `python --version` |
| Model takes forever | Wait 2-3 min (first time download) |
| Connection refused | Is server running? Check terminal |
| No objects detected | Lower threshold to 0.3 |
| Swagger won't load | Try http://127.0.0.1:8001/docs |

---

## 💾 WHAT GETS CREATED

**On first run:**
- `models/yolov8s.pt` (~22.5 MB) - YOLO model

**Automatically:**
- Logs in terminal
- Temporary files (cleaned up)

**No user data stored**

---

## 🔗 USEFUL URLS

```
Server:      http://127.0.0.1:8001
Swagger UI:  http://127.0.0.1:8001/docs
API Docs:    http://127.0.0.1:8001/redoc
Health:      http://127.0.0.1:8001/api/v1/objects/health
```

---

## 📝 SAMPLE TEST JSON

### Test 1: Basic
```json
{
  "image_base64": "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==",
  "confidence_threshold": 0.5
}
```

### Test 2: High Sensitivity
```json
{
  "image_base64": "...",
  "confidence_threshold": 0.3
}
```

### Test 3: High Precision
```json
{
  "image_base64": "...",
  "confidence_threshold": 0.9
}
```

---

## 🎬 ONE-LINER QUICK START

```bash
cd d:\S8 Project\S.A.G.E\ml\object-detection && run.bat
# Then: http://127.0.0.1:8001/docs
```

---

## 📊 RESPONSE TIME EXPECTATIONS

```
Health check:     ~5ms (instant)
Detection (first):  ~1000ms (model setup)
Detection (next):   ~50ms (model in memory)
```

---

## 🚀 START NOW

```bash
run.bat
```

Then open:
```
http://127.0.0.1:8001/docs
```

Click "Try it out" on any endpoint!

---

## ✨ QUICK ANSWER INDEX

**How to start?** → `run.bat`  
**How to test?** → http://127.0.0.1:8001/docs  
**How to use?** → Paste JSON in Swagger  
**Need help?** → Read START_HERE.md  
**Got issues?** → Check TESTING_GUIDE.md  

---

**Ready to test? You are!** 🎊
