"""
Quick camera test - Show webcam preview
Press 'q' to quit
"""

import cv2

print("🎥 Starting camera preview...")
print("Press 'q' to quit")

# Open camera with DirectShow backend (faster on Windows)
cap = cv2.VideoCapture(0, cv2.CAP_DSHOW)

# Set resolution
cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)

if not cap.isOpened():
    print("❌ Cannot open camera")
    exit()

print("✅ Camera opened successfully")

while True:
    ret, frame = cap.read()
    
    if not ret:
        print("❌ Can't receive frame")
        break
    
    # Add text overlay
    cv2.putText(frame, "SAGE Camera Preview - Press 'q' to quit", 
                (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)
    
    # Display
    cv2.imshow('SAGE Camera Preview', frame)
    
    # Press 'q' to quit
    if cv2.waitKey(1) & 0xFF == ord('q'):
        break

cap.release()
cv2.destroyAllWindows()
print("✅ Camera test complete")
