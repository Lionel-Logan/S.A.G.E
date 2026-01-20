import sqlite3
import cv2
import numpy as np
import os
import io
from insightface.app import FaceAnalysis
from utils.db_helper import convert_array

# 1. Setup Models & Paths
script_dir = os.path.dirname(os.path.abspath(__file__))
db_path = os.path.join(script_dir, "models", "face_data.db")

app = FaceAnalysis(name='buffalo_l', providers=['CPUExecutionProvider'])
app.prepare(ctx_id=0, det_size=(640, 640))

def recognize_live():
    cap = cv2.VideoCapture(0) # Open Laptop Webcam
    print("Webcam active. Press 'q' to exit.")

    while True:
        ret, frame = cap.read()
        if not ret: break
        
        faces = app.get(frame)
        for face in faces:
            detected_emb = face.normed_embedding
            
            # 2. Query Face Bank
            conn = sqlite3.connect(db_path)
            cursor = conn.cursor()
            cursor.execute("SELECT name, description, embedding FROM people")
            
            match_name = "Unknown"
            match_desc = "Identifying..."
            max_sim = 0.0
            
            for name, desc, emb_blob in cursor.fetchall():
                known_emb = convert_array(emb_blob)
                # Compute Cosine Similarity
                sim = np.dot(detected_emb, known_emb)
                
                # SAGE Threshold: 0.45 is standard for buffalo_l
                if sim > 0.45 and sim > max_sim:
                    max_sim = sim
                    match_name = name
                    match_desc = desc
            
            # 3. Draw HUD-style overlays on screen
            x1, y1, x2, y2 = face.bbox.astype(int)
            cv2.rectangle(frame, (x1, y1), (x2, y2), (0, 255, 0), 2)
            label = f"{match_name} ({max_sim:.2f})"
            cv2.putText(frame, label, (x1, y1-10), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 0), 2)
            
            if match_name != "Unknown":
                print(f"SAGE Alert: {match_name} detected. {match_desc}")

        cv2.imshow("SAGE Prototype Recognition", frame)
        if cv2.waitKey(1) & 0xFF == ord('q'):
            break

    cap.release()
    cv2.destroyAllWindows()
    conn.close()

if __name__ == "__main__":
    recognize_live()