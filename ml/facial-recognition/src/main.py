def recognize_face(detected_embedding):
    conn = sqlite3.connect('../src/models/face_data.db')
    cursor = conn.cursor()
    cursor.execute("SELECT name, description, embedding FROM people")
    rows = cursor.fetchall()
    
    best_match = {"name": "Unknown", "description": "No data found", "confidence": 0.0}
    max_sim = 0.0
    
    for name, description, emb_blob in rows:
        known_emb = convert_array(emb_blob)
        # Calculate cosine similarity
        similarity = np.dot(detected_embedding, known_emb) / (np.linalg.norm(detected_embedding) * np.linalg.norm(known_emb))
        
        if similarity > 0.5 and similarity > max_sim: # Threshold of 0.5 is standard for buffalo_l
            max_sim = similarity
            best_match = {
                "name": name,
                "description": description,
                "confidence": float(max_sim)
            }
            
    conn.close()
    return best_match