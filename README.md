<div align="center">
  <img src="https://capsule-render.vercel.app/api?type=waving&color=gradient&height=200&section=header&text=S.A.G.E&fontSize=90&animation=fadeIn" width="100%" />

  <h3>Situational Awareness & Guidance Engine</h3>

  <p align="center">
    <a href="https://git.io/typing-svg">
      <img src="https://readme-typing-svg.demolab.com?font=Fira+Code&weight=600&size=20&pause=1000&color=00FF99&center=true&vCenter=true&width=600&lines=AI-powered+Smartglass+Ecosystem;Real-time+Object+%26+Face+Detection;Turn-by-Turn+AR+Navigation;Gemini+Voice+Assistant+%2B+Web+Search" alt="Typing SVG" />
    </a>
  </p>

  <p align="center">
    <img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" />
    <img src="https://img.shields.io/badge/FastAPI-009688?style=for-the-badge&logo=FastAPI&logoColor=white" />
    <img src="https://img.shields.io/badge/Python-3776AB?style=for-the-badge&logo=python&logoColor=white" />
    <img src="https://img.shields.io/badge/PyTorch-EE4C2C?style=for-the-badge&logo=pytorch&logoColor=white" />
    <img src="https://img.shields.io/badge/Raspberry%20Pi-A22846?style=for-the-badge&logo=Raspberry%20Pi&logoColor=white" />
  </p>
</div>

<br/>

<div align="center">
  <img src="https://raw.githubusercontent.com/andreasbm/readme/master/assets/lines/rainbow.png" width="100%" />
</div>

## ✨ Overview

**S.A.G.E** is a software-first, modular smartglass system pushing the limits of wearable AI. By offloading heavy ML workloads and orchestration to a mobile app and hosted backend, S.A.G.E keeps the hardware footprint minimal while delivering a powerful AR experience through a lightweight HUD.

### 🌟 Core Capabilities
- 👁️ **Continuous Object Detection**: Environmental awareness and spatial obstacle identification using YOLOv8s.
- 🧑‍🤝‍🧑 **Facial Recognition**: Seamless real-time individual identification and enrollment via InsightFace.
- 🗺️ **Turn-by-Turn Navigation**: Real-time routing via OSRM and Google Directions APIs, streamed over WebSockets.
- 🗣️ **Gemini Voice Assistant**: Hands-free intelligence seamlessly integrated with Porcupine wake-word and Google Cloud STT/TTS.
- 🔍 **Live Web Search**: Fast, live internet querying powered by SerpAPI.
- 🌍 **OCR & Translation**: Text recognition (Google Vision) combined with on-the-fly translation (LibreTranslate).

<div align="center">
  <img src="https://raw.githubusercontent.com/andreasbm/readme/master/assets/lines/rainbow.png" width="100%" />
</div>

## 🏗 System Architecture

The ecosystem relies on an asynchronous distributed microservice architecture spanning hardware, mobile, and cloud environments.

```mermaid
graph TD;
    subgraph HW["Hardware Layer - Raspberry Pi"]
        Camera((Camera)) --> PiServer[FastAPI Server]
        WakeWord[Porcupine PPN] --> Mic((Mic))
        Mic --> PiServer
        PiServer --> Bluetooth((BT Speaker/HUD))
    end

    subgraph Mobile["Mobile Layer - Flutter Companion"]
        PiServer <-->|BLE Provisioning| MobileApp[Flutter App]
        MobileApp --> Geo[Geolocation GPS]
        Geo --> WSBridge[WebSocket Location Stream]
        MobileApp --> APIBridge[API Relay]
    end

    subgraph Cloud["Cloud Backend - Orchestrator (FastAPI)"]
        WSBridge <-->|ws://| CoreBackend[FastAPI Gateway]
        APIBridge <-->|REST API| CoreBackend
        CoreBackend <--> Gemini[Gemini LLM]
        CoreBackend <--> OSRM[OSRM / Maps Routing]
        CoreBackend <--> Serp[SerpAPI Web Search]
        CoreBackend <--> OCR[Google Vision OCR & Translation]
    end

    subgraph ML["ML Microservices (Local / Edge)"]
        CoreBackend <--> FaceRec[Face Recognition: 8002 - InsightFace]
        CoreBackend <--> ObjDet[Object Detection: 8001 - YOLOv8]
    end
```

<div align="center">
  <img src="https://raw.githubusercontent.com/andreasbm/readme/master/assets/lines/rainbow.png" width="100%" />
</div>

## 📂 Codebase Structure

The repository is logically separated into focused sub-domains:

| Folder | Components | Stack | Description |
|---|---|---|---|
| 📱 `app/frontend/` | Mobile App | Dart / Flutter | Companion UI. Handles BLE pairing, GPS tracking (`geolocator`), and WebSockets. |
| ⚙️ `app/backend/` | Backend Orchestrator | Python / FastAPI | Core gateway. Routes traffic to ML, handles active Navigation sessions, and Web Search. |
| 🧠 `ml/` | ML Inference | PyTorch / YOLOv8 | Dedicated microservices for Face Recognition and Object Detection inferences. |
| 🍓 `sage/` | Pi Hardware Runtime | Python / BlueZ | On-device scripts for wake-word listeners, audio routing, and Pi FastAPI hardware control. |

<div align="center">
  <img src="https://raw.githubusercontent.com/andreasbm/readme/master/assets/lines/rainbow.png" width="100%" />
</div>
## 👩‍💻 The Team

Meet the brains behind S.A.G.E:

| Member | Role | Key Contributions (from Git History) |
| :--- | :--- | :--- |
| **Navneet** | Mobile / Systems Engineer 🟦 | Flutter UI & Dashboard, BLE/WiFi network provisioning, Pi Server initialization, Hardware I/O (STT/TTS/Camera), and full-stack Dockerization. |
| **Gayathri** | Core Backend Architect 🟩 | FastAPI Orchestrator, intelligent multi-intent routing (Gemini v2.5-flash), WebSocket turn-by-turn navigation integrations, and cross-module TTS logic. |
| **Nikhil** | ML / Cloud Engineer 🟥 | Face Recognition inference & endpoints, OCR setup, built the LibreTranslate & Google Cloud integrations for seamless translation logic. |
| **Ananya** | ML / API Engineer 🟧| YOLO Object detection pipeline & spatial grid mapping, SerpAPI live web search integrations, and Google Maps routing implementations. |

<div align="center">
  <img src="https://raw.githubusercontent.com/andreasbm/readme/master/assets/lines/rainbow.png" width="100%" />
</div>
##  Getting Started

To spin up the updated S.A.G.E ecosystem locally:

### 1. Backend & ML Services (Docker Recommended)
Ensure you configure your `app/backend/.env` with `SERPAPI_API_KEY`, `GOOGLE_MAPS_API_KEY`, and Gemini keys respectively.

```bash
# Core Backend
cd app/backend
docker-compose up -d

# ML Services (Face Rec & Object Detection on 8002 & 8001)
cd ../../ml/facial-recognition && docker-compose up -d
cd ../object-detection && docker-compose up -d
```

### 2. Raspberry Pi Hardware Scripts
Follow the setup guides inside `sage/scripts/` to register systemd services. Ensure your picovoice `hey-sage-wake-up-train.ppn` is linked.
```bash
cd sage/scripts
chmod +x *.sh
./install_pi_server.sh
```

### 3. Flutter Companion App
Ensure Flutter 3.10+ is installed.
```bash
cd app/frontend
flutter pub get
flutter run
```

<div align="center">
  <img src="https://raw.githubusercontent.com/andreasbm/readme/master/assets/lines/rainbow.png" width="100%" />
</div>

<p align="center">
  <i>S.A.G.E is built with ❤️ for smarter interactions and accessible AI.</i>
</p>
