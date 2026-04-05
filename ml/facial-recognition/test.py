import requests
import json
import base64
import sys
import time

URL = "http://localhost:8002"
IMAGE_PATH = "E:/S.A.G.E/ml/facial-recognition/data/faces_db/Ananya.jpg"

def get_base64_image(path):
    with open(path, "rb") as f:
        return base64.b64encode(f.read()).decode("utf-8")

def check_health():
    print("Checking health...")
    r = requests.get(f"{URL}/health")
    print(r.status_code, r.json())
    return r.json().get("model_loaded", False)

def enroll(name, b64):
    print("Enrolling...", name)
    payload = {
        "name": name,
        "image_base64": b64,
        "description": "Test person"
    }
    r = requests.post(f"{URL}/enroll", json=payload)
    print(r.status_code, r.json())
    return r.status_code == 201 or r.status_code == 200

def recognize(b64):
    print("Recognizing...")
    payload = {
        "image_base64": b64,
        "threshold": 0.4
    }
    r = requests.post(f"{URL}/recognize", json=payload)
    print(r.status_code, r.json())
    return r.status_code == 200

if __name__ == "__main__":
    b64_image = get_base64_image(IMAGE_PATH)
    
    # wait for model load
    for i in range(20):
        if check_health():
            break
        print("Waiting for model to load...")
        time.sleep(5)
    else:
        print("Model did not load in time!")
        sys.exit(1)
        
    enroll("AnanyaTest", b64_image)
    recognize(b64_image)
    print("DONE!")