#!/bin/bash
# SAGE Voice Assistant Installation Script
# Run this script on the Raspberry Pi to set up the voice assistant

set -e  # Exit on error

echo "=========================================="
echo "SAGE Voice Assistant Installation"
echo "=========================================="
echo ""

# Check if running on Raspberry Pi
if [[ ! -f /proc/device-tree/model ]] || ! grep -q "Raspberry Pi" /proc/device-tree/model; then
    echo "⚠️  Warning: This doesn't appear to be a Raspberry Pi"
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Variables
SAGE_DIR="$HOME/sage"
VOSK_MODEL_DIR="$HOME/vosk-model-small-en-us-0.15"
VOSK_MODEL_URL="https://alphacephei.com/vosk/models/vosk-model-small-en-us-0.15.zip"
AUDIO_DIR="$HOME/audio"
LOG_DIR="/var/log/sage"

# Check if running as root (we don't want that)
if [[ $EUID -eq 0 ]]; then
   echo "❌ Don't run this script as root!"
   echo "Run as: ./install_voice_assistant.sh"
   exit 1
fi

echo "📦 Step 1: Installing system dependencies..."
echo ""

# Install system packages
sudo apt-get update
sudo apt-get install -y \
    python3-pip \
    python3-dev \
    python3-pyaudio \
    portaudio19-dev \
    libasound2-dev \
    libffi-dev \
    pulseaudio \
    unzip \
    wget

echo "✓ System dependencies installed"
echo ""

echo "📦 Step 2: Installing Python dependencies..."
echo ""

# Upgrade pip
pip3 install --upgrade pip

# Install Python packages (voice assistant only - no uvicorn/fastapi)
cd "$SAGE_DIR"
pip3 install -r requirements-voice.txt 2>/dev/null || pip3 install pvporcupine==3.0.0 vosk==0.3.45 pyaudio==0.2.14 numpy==1.26.3 requests==2.31.0

echo "✓ Python dependencies installed"
echo ""

echo "📥 Step 3: Downloading Vosk model..."
echo ""

# Download and extract Vosk model if not exists
if [ ! -d "$VOSK_MODEL_DIR" ]; then
    echo "Downloading Vosk model (50MB)..."
    cd "$HOME"
    wget -q --show-progress "$VOSK_MODEL_URL" -O vosk-model.zip
    
    echo "Extracting model..."
    unzip -q vosk-model.zip
    rm vosk-model.zip
    
    echo "✓ Vosk model downloaded and extracted"
else
    echo "✓ Vosk model already exists"
fi
echo ""

echo "📁 Step 4: Creating directories..."
echo ""

# Create audio directory for tone files
mkdir -p "$AUDIO_DIR"
echo "✓ Created $AUDIO_DIR"

# Create voice recordings directory (for debugging)
mkdir -p "$HOME/voice_recordings"
echo "✓ Created $HOME/voice_recordings"

# Create log directory
sudo mkdir -p "$LOG_DIR"
sudo chown $USER:$USER "$LOG_DIR"
echo "✓ Created $LOG_DIR"

echo ""

echo "🔑 Step 5: Porcupine API Key Setup"
echo ""
echo "You need a Porcupine access key (free tier available):"
echo "1. Go to https://console.picovoice.ai/"
echo "2. Sign up / Log in"
echo "3. Copy your Access Key"
echo ""
read -p "Enter your Porcupine Access Key: " PORCUPINE_KEY

if [ -z "$PORCUPINE_KEY" ]; then
    echo "⚠️  No key provided. You'll need to add it manually to:"
    echo "   $SAGE_DIR/config/voice_config.py"
    echo "   Set PORCUPINE_ACCESS_KEY = 'your_key_here'"
else
    # Update config file with API key (using | as delimiter to avoid issues with special chars)
    sed -i "s|PORCUPINE_ACCESS_KEY = \"\"|PORCUPINE_ACCESS_KEY = \"$PORCUPINE_KEY\"|" \
        "$SAGE_DIR/config/voice_config.py"
    echo "✓ API key saved"
fi

echo ""

echo "⚙️  Step 6: Backend API Configuration"
echo ""
echo "Current backend URL: http://localhost:8000/api/v1/assistant/ask"
read -p "Enter backend IP address (or press Enter to keep localhost): " BACKEND_IP

if [ ! -z "$BACKEND_IP" ]; then
    NEW_URL="http://$BACKEND_IP:8000/api/v1/assistant/ask"
    sed -i "s|BACKEND_API_URL = \"http://localhost:8000/api/v1/assistant/ask\"|BACKEND_API_URL = \"$NEW_URL\"|" \
        "$SAGE_DIR/config/voice_config.py"
    echo "✓ Backend URL updated to: $NEW_URL"
fi

echo ""

echo "🔧 Step 7: Installing systemd service..."
echo ""

# Copy service file
sudo cp "$SAGE_DIR/scripts/voice_assistant.service" /etc/systemd/system/

# Reload systemd
sudo systemctl daemon-reload

# Enable service (will start on boot)
sudo systemctl enable voice_assistant.service

echo "✓ Service installed and enabled"
echo ""

echo "=========================================="
echo "✅ Installation Complete!"
echo "=========================================="
echo ""
echo "📋 Next Steps:"
echo ""
echo "1. Add wake tone file:"
echo "   Place your audio file at: $AUDIO_DIR/wake_tone.wav"
echo ""
echo "2. Add end tone file:"
echo "   Place your audio file at: $AUDIO_DIR/end_tone.wav"
echo ""
echo "3. Test the microphone:"
echo "   arecord -d 5 test.wav && aplay test.wav"
echo ""
echo "4. Start the service:"
echo "   sudo systemctl start voice_assistant.service"
echo ""
echo "5. Check service status:"
echo "   sudo systemctl status voice_assistant.service"
echo ""
echo "6. View logs:"
echo "   sudo journalctl -u voice_assistant -f"
echo ""
echo "📝 Important Notes:"
echo "   - Currently using 'jarvis' wake word (built-in)"
echo "   - Train custom 'Hey Sage' at: https://console.picovoice.ai/"
echo "   - Update BACKEND_API_URL if needed in voice_config.py"
echo "   - Adjust SILENCE_THRESHOLD in voice_config.py based on your environment"
echo ""
echo "🎉 Ready to use SAGE Voice Assistant!"
echo ""
