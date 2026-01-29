from app.core.utils import decode_image
import cv2

class VisionService:
    def __init__(self):
        # This is where you will load your models later
        # e.g., self.face_model = face_recognition.load_model(...)
        # e.g., self.object_model = YOLO("yolov8.pt")
        print("Vision Service Initialized")

    async def recognize_face(self, base64_image: str) -> str:
        """
        Receives base64 string -> Returns names of people detected with descriptions
        """
        try:
            from app.services.model_client import FaceRecognitionClient
            
            # Call Nikhil's face recognition server
            client = FaceRecognitionClient()
            result = await client.recognize_faces(base64_image, threshold=0.7)
            await client.close()
            
            # Parse results into voice-friendly format
            if not result.get("success") or result.get("faces_detected", 0) == 0:
                return "I don't see any faces in the image."
            
            faces = result.get("faces", [])
            recognized = [f for f in faces if f["name"] != "Unknown"]
            unknown_count = len(faces) - len(recognized)
            
            if len(recognized) == 0:
                # All faces unknown
                if len(faces) == 1:
                    return "I don't recognize this person. Try another image."
                else:
                    return f"I see {len(faces)} faces but don't recognize any of them. Try another image."
            
            # Build natural language response with descriptions
            descriptions = []
            for face in recognized:
                name = face["name"]
                desc = face.get("description", "")
                if desc:
                    descriptions.append(f"{name}, {desc}")
                else:
                    descriptions.append(name)
            
            # Format the response
            if len(recognized) == 1 and unknown_count == 0:
                return f"I see {descriptions[0]}."
            elif len(recognized) == 1 and unknown_count > 0:
                return f"I see {descriptions[0]}, and {unknown_count} unrecognized {'person' if unknown_count == 1 else 'people'}."
            elif len(recognized) > 1 and unknown_count == 0:
                return f"I see {', '.join(descriptions[:-1])}, and {descriptions[-1]}."
            else:
                return f"I see {', '.join(descriptions)}, and {unknown_count} unrecognized {'person' if unknown_count == 1 else 'people'}."
                
        except Exception as e:
            print(f"Face recognition error: {e}")
            return f"Face recognition unavailable: {str(e)}"
    
    async def enroll_face(self, name: str, base64_image: str, description: str = "") -> str:
        """
        Enroll a new face into the database
        
        Args:
            name: Person's name
            base64_image: Base64 encoded image
            description: Optional description (relation, role, etc.)
            
        Returns:
            Enrollment result message
        """
        try:
            from app.services.model_client import FaceRecognitionClient
            
            # Call Nikhil's face enrollment server
            client = FaceRecognitionClient()
            result = await client.enroll_face(name, base64_image, description, threshold=0.7)
            await client.close()
            
            if result.get("success"):
                return f"{name} has been enrolled successfully."
            else:
                error_msg = result.get("message", "Enrollment failed")
                return f"Could not enroll {name}. {error_msg}"
                
        except Exception as e:
            print(f"Face enrollment error: {e}")
            return f"Enrollment failed: {str(e)}"

    async def detect_objects(self, base64_image: str) -> str:
        """
        Receives base64 string -> Returns list of objects detected with spatial positions
        """
        try:
            from app.services.model_client import ObjectDetectionClient
            
            # Call Ananya's object detection server
            client = ObjectDetectionClient()
            result = await client.detect_objects(base64_image, confidence_threshold=0.5)
            await client.close()
            
            # Parse detected objects into voice-friendly format
            if "detected_objects" in result and result["detected_objects"]:
                objects = result["detected_objects"]
                
                # Create natural language description
                if len(objects) == 0:
                    return "I don't see any recognizable objects."
                elif len(objects) == 1:
                    obj = objects[0]
                    return f"I see {obj.get('position_description', obj['label'])}."
                else:
                    # List multiple objects with positions
                    descriptions = [obj.get('position_description', obj['label']) for obj in objects[:5]]  # Limit to 5
                    if len(objects) > 5:
                        return f"I see {', '.join(descriptions[:4])}, and {len(objects) - 4} more objects."
                    else:
                        return f"I see {', '.join(descriptions[:-1])}, and {descriptions[-1]}."
            else:
                return "I don't see any recognizable objects."
                
        except Exception as e:
            print(f"Object detection error: {e}")
            return f"Object detection unavailable: {str(e)}"