@echo off
REM Object Detection Service Startup Script for Windows

echo ======================================
echo Object Detection Service
echo ======================================
echo.

REM Check if virtual environment exists
if not exist venv (
    echo Creating virtual environment...
    python -m venv venv
)

REM Activate virtual environment
call venv\Scripts\activate.bat

REM Check if dependencies are installed
if not exist venv\Lib\site-packages\fastapi (
    echo Installing dependencies...
    pip install -r requirements.txt
)

REM Start the server
echo.
echo Starting Object Detection Service...
echo Server will be available at: http://127.0.0.1:8001
echo API Documentation: http://127.0.0.1:8001/docs
echo.

python -m uvicorn src.main:app --host 127.0.0.1 --port 8001 --reload

pause
