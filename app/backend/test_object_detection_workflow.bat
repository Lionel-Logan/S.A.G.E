@echo off
REM Test Object Detection Workflow
REM Make sure backend, Pi server, and object detection server are running

echo ====================================
echo SAGE Object Detection Workflow Test
echo ====================================
echo.
echo Prerequisites:
echo   1. Backend server running on port 8000
echo   2. Pi server running on port 8001
echo   3. Object detection server running on port 8003
echo.
echo Press Ctrl+C to exit
echo ====================================
echo.

python test_object_detection_workflow.py

pause
