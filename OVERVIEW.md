
# 🥽 S.A.G.E — *Situational Awareness & Guidance Engine*
**AI-powered smartglass ecosystem with real-time object detection, face recognition, translation, and AR-assisted interaction.**  
This monorepo contains the **Flutter mobile app**, **FastAPI backend**, and **ML inference services** powering the S.A.G.E wearable.

---

## 🚀 Overview
S.A.G.E is a software-first, modular smartglass system designed for:

- Real-time **object detection**
- Real-time **face recognition**
- Hands-free **voice assistant** interactions
- **OCR + Translation** (Google Vision + LibreTranslate)
- AR-like display through a mobile-assisted HUD pipeline

The system offloads heavy AI workloads to a **mobile app + hosted backend**, keeping the hardware minimal and efficient.

---

## 🏗 System Architecture

```
      ┌──────────────────┐
      │  Smartglass (Pi) │
      │  - Camera        │
      │  - Mic/Speaker   │
      │  - HUD Display   │
      │  - Lightweight   │
      │    FastAPI       │
      └─────────┬────────┘
                │
       Wi-Fi Local Network
                │
       ┌────────▼────────┐
       │  Flutter Mobile │
       │  App (UI + I/O) │
       │  - Voice Input  │
       │  - Camera Relay │
       │  - TTS/STT      │
       │  - API Bridge   │
       └────────┬────────┘
                │
         REST API Calls
                │
      ┌─────────▼──────────┐
      │   Core Backend      │
      │     FastAPI         │
      │  - Translation      │
      │  - OCR              │
      │  - Gemini LLM       │
      │  - Orchestration    │
      └─────────┬──────────┘
                │
   ML Microservices (FastAPI)
                │
   ┌────────────┼────────────┐
   │            │            │
┌──▼───┐   ┌────▼────┐   ┌───────┐
│ Face │   │ Object  │   │ Future │
│ Rec  │   │ Detect  │   │ Models │
└──────┘   └─────────┘   └───────┘
```

---

## 👥 Team Responsibilities

### 🟦 **You — Mobile App Developer**
- Flutter UI/UX  
- Camera streaming & communication with Pi  
- STT/TTS integration  
- Device pairing workflow  
- Routing backend results to HUD preview  

### 🟩 **Gayathri — Core Backend Developer**
- FastAPI backend  
- Google Vision OCR integration  
- LibreTranslate pipeline  
- Gemini integration  
- Orchestration logic  
- Redis caching / async tasks  

### 🟥 **Nikhil — Face Recognition Engineer**
- Dataset preparation & training  
- ArcFace/FaceNet embeddings  
- Faiss/Annoy nearest-neighbor search  
- FastAPI inference server  
- ONNX/TorchScript export  

### 🟧 **Ananya — Object Detection Engineer**
- YOLO/EfficientDet training  
- Dataset annotation & augmentation  
- Fast inference server (FastAPI)  
- Model quantization / ONNX export  

---

## 📁 Repository Structure

```
SAGE/
│
├── docs/
│
├── mobile_app/
│
├── app_backend/
│
├── ml_services/
│   ├── face_recognition_service/
│   └── object_detection_service/
│
├── pi_firmware/
│
└── devops/
```

---

## 🧰 Tech Stack

### **Frontend & Device Layer**
- Flutter
- HTTP (Dio)
- TTS / STT plugins
- Local WiFi communication

### **Backend**
- FastAPI
- Redis
- Gemini API
- Google Vision OCR
- LibreTranslate

### **ML Services**
- PyTorch / ONNX Runtime  
- YOLOv8 / EfficientDet  
- ArcFace / FaceNet embeddings  
- Faiss / Annoy  

---

## 🧪 Local Development

### ▶ Run Flutter App
```
cd mobile_app
flutter pub get
flutter run
```

### ▶ Run Backend API
```
cd app_backend
pip install -r requirements.txt
uvicorn src.main:app --reload --port 8000
```

### ▶ Run ML Services
```
cd ml_services/face_recognition_service
uvicorn src.main:app --reload --port 8100

cd ml_services/object_detection_service
uvicorn src.main:app --reload --port 8200
```

### ▶ (Optional) Start all services together
```
docker-compose -f docker-compose.dev.yml up --build
```

---

## 🧿 Core Features (Software-first)

- Object Detection  
- Facial Recognition  
- Translation (OCR + LibreTranslate)  
- Gemini Voice Assistant  

---

## 🛡 Design Philosophy
- Hardware-light, software-heavy  
- ML offloaded to backend  
- Free/open-source friendly  
- Modular microservices  
- AR via reflective HUD  

---

## 📜 License
Add your license here.

---

## ❤️ Acknowledgements
Thanks to the S.A.G.E development team for building an accessible AI-powered wearable.
