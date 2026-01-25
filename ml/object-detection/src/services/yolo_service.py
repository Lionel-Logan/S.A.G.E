"""YOLO model service for object detection."""
import time
import numpy as np
from typing import List, Tuple, Optional
from ultralytics import YOLO

from src.exceptions import ModelLoadException, InferenceException
from src.utils.logger import get_logger
from config import YOLO_MODEL_FILE, YOLO_MODEL_NAME, DEFAULT_IOU_THRESHOLD, DEFAULT_IMG_SIZE

logger = get_logger(__name__)


class YOLOService:
    """Service for YOLO model management and inference."""
    
    def __init__(self):
        """Initialize YOLO service with model loading."""
        self.model: Optional[YOLO] = None
        self._load_model()
    
    def _load_model(self) -> None:
        """Load YOLO model from disk or download from Ultralytics if not available.
        
        Raises:
            ModelLoadException: If model loading fails
        """
        logger.info(f"Starting YOLO model load: {YOLO_MODEL_NAME}")
        
        try:
            # YOLO will automatically download from Ultralytics if file doesn't exist
            self.model = YOLO(str(YOLO_MODEL_FILE))
            logger.info(f"YOLO model loaded successfully: {YOLO_MODEL_NAME}")
        except Exception as e:
            logger.error(f"Failed to load YOLO model: {str(e)}")
            raise ModelLoadException(f"Failed to load YOLO model: {str(e)}")
    
    def detect(
        self,
        image_array: np.ndarray,
        confidence_threshold: float = 0.5,
        iou_threshold: float = DEFAULT_IOU_THRESHOLD
    ) -> Tuple[List[dict], float]:
        """Run object detection on an image.
        
        Args:
            image_array: Image as NumPy array (BGR format)
            confidence_threshold: Minimum confidence score for detections
            iou_threshold: IoU threshold for NMS (Non-Maximum Suppression)
            
        Returns:
            Tuple of (detections_list, inference_time_ms) where detections_list
            contains dicts with: {box, confidence, class, name}
            
        Raises:
            InferenceException: If inference fails
        """
        if self.model is None:
            raise InferenceException("Model is not loaded")
        
        logger.debug(f"Running inference with conf={confidence_threshold}, iou={iou_threshold}")
        
        try:
            start_time = time.time()
            
            # Run inference
            results = self.model(
                image_array,
                conf=confidence_threshold,
                iou=iou_threshold,
                imgsz=DEFAULT_IMG_SIZE,
                verbose=False
            )
            
            inference_time_ms = (time.time() - start_time) * 1000
            logger.debug(f"Inference completed in {inference_time_ms:.2f}ms")
            
            # Extract detections from results
            detections = self._extract_detections(results[0])
            logger.info(f"Detected {len(detections)} objects in {inference_time_ms:.2f}ms")
            
            return detections, inference_time_ms
            
        except Exception as e:
            logger.error(f"Inference failed: {str(e)}")
            raise InferenceException(f"Inference failed: {str(e)}")
    
    @staticmethod
    def _extract_detections(result) -> List[dict]:
        """Extract detection information from YOLO result.
        
        Args:
            result: YOLO result object
            
        Returns:
            List of detection dictionaries
        """
        detections = []
        
        if result.boxes is None or len(result.boxes) == 0:
            return detections
        
        # Iterate through detections
        for i in range(len(result.boxes)):
            box = result.boxes[i]
            
            # Extract bounding box coordinates (xyxy format)
            xyxy = box.xyxy[0].cpu().numpy()
            x1, y1, x2, y2 = xyxy.astype(float)
            
            # Confidence score
            confidence = float(box.conf[0].cpu().numpy())
            
            # Class index and name
            class_id = int(box.cls[0].cpu().numpy())
            class_name = result.names[class_id]
            
            # Convert xyxy to xywh format for easier processing
            x = x1
            y = y1
            width = x2 - x1
            height = y2 - y1
            
            detection = {
                "box": {"x1": x1, "y1": y1, "x2": x2, "y2": y2},
                "box_xywh": {"x": x, "y": y, "width": width, "height": height},
                "confidence": confidence,
                "class": class_id,
                "name": class_name
            }
            
            detections.append(detection)
        
        return detections
    
    def is_model_loaded(self) -> bool:
        """Check if model is loaded.
        
        Returns:
            True if model is loaded, False otherwise
        """
        return self.model is not None
