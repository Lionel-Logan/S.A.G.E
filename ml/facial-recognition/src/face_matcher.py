"""
Face Matcher Service
Core logic for face recognition and enrollment
"""
import sqlite3
import numpy as np
from typing import List, Dict, Optional, Tuple
from insightface.app import FaceAnalysis
import logging
import config
from utils.db_helper import adapt_array, convert_array, init_db

logger = logging.getLogger(__name__)


class FaceMatcherError(Exception):
    """Custom exception for face matching errors"""
    pass


class FaceMatcher:
    """
    Face matching service using InsightFace buffalo_l model
    Handles face recognition, enrollment, and duplicate detection
    """
    
    def __init__(self):
        """Initialize the face matcher with InsightFace model"""
        self.model = None
        self.db_path = str(config.DB_PATH)
        self._initialize_model()
        self._initialize_database()
    
    def _initialize_model(self):
        """Load InsightFace model"""
        try:
            logger.info(f"Loading InsightFace model: {config.INSIGHTFACE_MODEL}")
            self.model = FaceAnalysis(
                name=config.INSIGHTFACE_MODEL,
                providers=config.PROVIDERS
            )
            self.model.prepare(ctx_id=0, det_size=config.DETECTION_SIZE)
            logger.info("✓ Model loaded successfully")
        except Exception as e:
            logger.error(f"Failed to load model: {str(e)}")
            raise FaceMatcherError(f"Model initialization failed: {str(e)}")
    
    def _initialize_database(self):
        """Initialize database if it doesn't exist"""
        try:
            init_db(self.db_path)
            logger.info(f"✓ Database initialized: {self.db_path}")
        except Exception as e:
            logger.error(f"Failed to initialize database: {str(e)}")
            raise FaceMatcherError(f"Database initialization failed: {str(e)}")
    
    def detect_faces(self, image: np.ndarray) -> List[Dict]:
        """
        Detect faces in image and extract embeddings
        
        Args:
            image: OpenCV image (BGR format)
            
        Returns:
            List of detected faces with embeddings and bounding boxes
            Format: [{"embedding": np.ndarray, "bbox": [x1, y1, x2, y2], "confidence": float}, ...]
        """
        try:
            faces = self.model.get(image)
            
            results = []
            for face in faces:
                results.append({
                    "embedding": face.normed_embedding,  # Already normalized
                    "bbox": face.bbox.astype(int).tolist(),
                    "confidence": float(face.det_score) if hasattr(face, 'det_score') else 1.0
                })
            
            logger.info(f"Detected {len(results)} face(s) in image")
            return results
            
        except Exception as e:
            logger.error(f"Face detection failed: {str(e)}")
            raise FaceMatcherError(f"Face detection failed: {str(e)}")
    
    def find_matches(self, embedding: np.ndarray, threshold: float) -> List[Dict]:
        """
        Find matching faces in database for a given embedding
        
        Args:
            embedding: Face embedding vector (512D)
            threshold: Similarity threshold (0.0-1.0)
            
        Returns:
            List of matches sorted by confidence (highest first)
            Format: [{"name": str, "description": str, "confidence": float}, ...]
        """
        try:
            conn = sqlite3.connect(self.db_path)
            cursor = conn.cursor()
            cursor.execute("SELECT name, description, embedding FROM people")
            rows = cursor.fetchall()
            conn.close()
            
            matches = []
            
            for name, description, emb_blob in rows:
                known_emb = convert_array(emb_blob)
                
                # Calculate cosine similarity (embeddings are already normalized)
                similarity = float(np.dot(embedding, known_emb))
                
                if similarity >= threshold:
                    matches.append({
                        "name": name,
                        "description": description,
                        "confidence": similarity
                    })
            
            # Sort by confidence (highest first)
            matches.sort(key=lambda x: x["confidence"], reverse=True)
            
            logger.info(f"Found {len(matches)} match(es) above threshold {threshold}")
            return matches
            
        except Exception as e:
            logger.error(f"Database query failed: {str(e)}")
            raise FaceMatcherError(f"Database query failed: {str(e)}")
    
    def recognize_faces(self, image: np.ndarray, threshold: float = None) -> Dict:
        """
        Recognize all faces in an image
        
        Args:
            image: OpenCV image (BGR format)
            threshold: Similarity threshold (uses default if None)
            
        Returns:
            Dictionary with recognition results
            Format: {
                "faces_detected": int,
                "faces": [{"name": str, "description": str, "confidence": float, "bbox": [x1,y1,x2,y2]}, ...]
            }
        """
        if threshold is None:
            threshold = config.DEFAULT_THRESHOLD
        
        # Detect faces
        detected_faces = self.detect_faces(image)
        
        if len(detected_faces) == 0:
            return {
                "faces_detected": 0,
                "faces": []
            }
        
        # Match each detected face
        recognized_faces = []
        for face in detected_faces:
            matches = self.find_matches(face["embedding"], threshold)
            
            if matches:
                # Take the best match
                best_match = matches[0]
                recognized_faces.append({
                    "name": best_match["name"],
                    "description": best_match["description"],
                    "confidence": best_match["confidence"],
                    "bounding_box": face["bbox"]
                })
            else:
                # No match found
                recognized_faces.append({
                    "name": "Unknown",
                    "description": config.MSG_NO_MATCH,
                    "confidence": 0.0,
                    "bounding_box": face["bbox"]
                })
        
        return {
            "faces_detected": len(detected_faces),
            "faces": recognized_faces
        }
    
    def check_duplicate(self, embedding: np.ndarray, threshold: float) -> Tuple[bool, Optional[Dict]]:
        """
        Check if a face embedding already exists in database
        
        Args:
            embedding: Face embedding to check
            threshold: Similarity threshold for duplicate detection
            
        Returns:
            Tuple of (is_duplicate, match_info)
            - is_duplicate: True if duplicate found
            - match_info: Dict with duplicate details if found, else None
        """
        matches = self.find_matches(embedding, threshold)
        
        if matches:
            # Found a match - consider it a duplicate
            best_match = matches[0]
            logger.info(f"Duplicate detected: {best_match['name']} (confidence: {best_match['confidence']:.3f})")
            return True, best_match
        
        return False, None
    
    def enroll_face(
        self, 
        image: np.ndarray, 
        name: str, 
        description: str, 
        threshold: float = None
    ) -> Dict:
        """
        Enroll a new face into the database
        
        Args:
            image: OpenCV image (BGR format)
            name: Person's name
            description: Relation or description
            threshold: Threshold for duplicate detection (uses default if None)
            
        Returns:
            Dictionary with enrollment results
            Format: {
                "success": bool,
                "message": str,
                "person_id": int (if success),
                "confidence": float (if success)
            }
            
        Raises:
            FaceMatcherError: If enrollment fails
        """
        if threshold is None:
            threshold = config.DEFAULT_THRESHOLD
        
        # Detect faces
        detected_faces = self.detect_faces(image)
        
        # Check for no faces
        if len(detected_faces) == 0:
            return {
                "success": False,
                "message": config.MSG_NO_FACE_DETECTED
            }
        
        # Check for multiple faces (as per requirement #5)
        if len(detected_faces) > 1:
            return {
                "success": False,
                "message": config.MSG_MULTIPLE_FACES
            }
        
        # Single face detected - proceed with enrollment
        face = detected_faces[0]
        embedding = face["embedding"]
        
        # Check for duplicates
        is_duplicate, duplicate_info = self.check_duplicate(embedding, threshold)
        if is_duplicate:
            return {
                "success": False,
                "message": f"{config.MSG_DUPLICATE_FACE}: {duplicate_info['name']} (confidence: {duplicate_info['confidence']:.2f})"
            }
        
        # Save to database
        try:
            conn = sqlite3.connect(self.db_path)
            cursor = conn.cursor()
            cursor.execute(
                "INSERT INTO people (name, description, embedding) VALUES (?, ?, ?)",
                (name, description, adapt_array(embedding))
            )
            person_id = cursor.lastrowid
            conn.commit()
            conn.close()
            
            logger.info(f"✓ Enrolled {name} with ID {person_id}")
            
            return {
                "success": True,
                "message": config.MSG_ENROLLMENT_SUCCESS,
                "person_id": person_id,
                "confidence": face["confidence"]
            }
            
        except Exception as e:
            logger.error(f"Database insert failed: {str(e)}")
            raise FaceMatcherError(f"Failed to save to database: {str(e)}")
    
    def get_database_stats(self) -> Dict:
        """
        Get database statistics
        
        Returns:
            Dictionary with database stats
        """
        try:
            conn = sqlite3.connect(self.db_path)
            cursor = conn.cursor()
            cursor.execute("SELECT COUNT(*) FROM people")
            total_faces = cursor.fetchone()[0]
            cursor.execute("SELECT name FROM people")
            names = [row[0] for row in cursor.fetchall()]
            conn.close()
            
            return {
                "total_faces": total_faces,
                "names": names
            }
        except Exception as e:
            logger.error(f"Failed to get database stats: {str(e)}")
            return {"total_faces": 0, "names": []}
    
    def is_healthy(self) -> bool:
        """Check if the service is healthy (model loaded and DB accessible)"""
        try:
            # Check model
            if self.model is None:
                return False
            
            # Check database
            conn = sqlite3.connect(self.db_path)
            cursor = conn.cursor()
            cursor.execute("SELECT COUNT(*) FROM people")
            conn.close()
            
            return True
        except:
            return False
