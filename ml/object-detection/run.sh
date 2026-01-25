#!/bin/bash
# Object Detection Service Startup Script for macOS/Linux

echo "======================================"
echo "Object Detection Service"
echo "======================================"
echo ""

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv venv
fi

# Activate virtual environment
source venv/bin/activate

# Check if dependencies are installed
if ! python -c "import fastapi" 2>/dev/null; then
    echo "Installing dependencies..."
    pip install -r requirements.txt
fi

# Start the server
echo ""
echo "Starting Object Detection Service..."
echo "Server will be available at: http://127.0.0.1:8001"
echo "API Documentation: http://127.0.0.1:8001/docs"
echo ""

python -m uvicorn src.main:app --host 127.0.0.1 --port 8001 --reload
