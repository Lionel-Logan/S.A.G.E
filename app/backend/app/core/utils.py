#  The Helper: Handling Images

import base64
import numpy as np
import cv2 # You will need 'opencv-python' in your requirements.txt

def decode_image(base64_string: str):
    """
    Converts a Base64 string into an OpenCV image (numpy array).
    """
    try:
        # 1. Split the header if present (e.g., "data:image/jpeg;base64,...")
        if "," in base64_string:
            base64_string = base64_string.split(",")[1]
            
        # 2. Decode the string to bytes
        img_data = base64.b64decode(base64_string)
        
        # 3. Convert bytes to numpy array
        np_arr = np.frombuffer(img_data, np.uint8)
        
        # 4. Decode numpy array to image
        image = cv2.imdecode(np_arr, cv2.IMREAD_COLOR)
        return image
    except Exception as e:
        print(f"Image Decode Error: {e}")
        return None