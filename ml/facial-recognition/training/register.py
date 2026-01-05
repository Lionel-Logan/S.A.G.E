import os
import cv2
import sqlite3
from insightface.app import FaceAnalysis
import sys
# Add parent dir to path so we can import utils
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from src.utils.db_helper import adapt_array, init_db

# 1. Setup paths
script_dir = os.path.dirname(os.path.abspath(__file__))
db_path = os.path.join(script_dir, "..", "src", "models", "face_data.db")
img_folder = os.path.join(script_dir, "..", "data", "faces_db")

# 2. Initialize Model
app = FaceAnalysis(name='buffalo_l', providers=['CPUExecutionProvider'])
app.prepare(ctx_id=0, det_size=(640, 640))
init_db(db_path)

def register_person(name, description, filename):
    img_path = os.path.join(img_folder, filename)
    img = cv2.imread(img_path)
    
    if img is None:
        print(f"❌ Error: Could not find or read {img_path}")
        return

    faces = app.get(img)
    if faces:
        emb = faces[0].normed_embedding
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        cursor.execute(
            "INSERT INTO people (name, description, embedding) VALUES (?, ?, ?)",
            (name, description, adapt_array(emb))
        )
        conn.commit()
        conn.close()
        print(f"✅ Successfully registered {name}!")
    else:
        print(f"⚠️ No face detected in {filename}")

if __name__ == "__main__":
    # Example usage
    register_person("Navaneet", "Team Member for SAGE Project", "Navaneet.jpg")
    register_person("Ananya", "Team Member for SAGE Project", "Ananya.jpg")
    register_person("Gayathri", "Team Member for SAGE Project", "Gayathri.jpg")