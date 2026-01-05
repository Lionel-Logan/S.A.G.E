import insightface
from insightface.app import FaceAnalysis
import cv2
import numpy as np

# 1. Initialize the FaceAnalysis app
# We use CPUExecutionProvider since we installed the standard onnxruntime
app = FaceAnalysis(name='buffalo_l', providers=['CPUExecutionProvider'])

# 2. Prepare the model (this will download the models on the first run)
# ctx_id=0 means use the first CPU/GPU; det_size is the detection input resolution
print("Initializing models... (This may take a moment on the first run)")
app.prepare(ctx_id=0, det_size=(640, 640))

print("Successfully initialized InsightFace!")

# 3. Quick Test: Create a blank image and see if the app can process it
blank_img = np.zeros((640, 640, 3), dtype=np.uint8)
faces = app.get(blank_img)

print(f"Test complete. Detected {len(faces)} faces in a blank image.")