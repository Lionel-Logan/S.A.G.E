"""Object detection orchestration service."""
from typing import List

from src.models import DetectedObject, BoundingBox, RelativePosition
from src.services.image_service import ImageService
from src.services.yolo_service import YOLOService
from src.services.spatial_service import SpatialService
from src.utils.validators import validate_confidence_threshold
from src.utils.logger import get_logger

logger = get_logger(__name__)


class DetectionService:
    """Main service orchestrating the detection pipeline."""
    
    def __init__(self, yolo_service: YOLOService):
        """Initialize detection service.
        
        Args:
            yolo_service: Instance of YOLOService
        """
        self.yolo_service = yolo_service
        self.image_service = ImageService()
        self.spatial_service = SpatialService()
    
    def detect_objects(
        self,
        image_base64: str,
        confidence_threshold: float = 0.5
    ) -> List[DetectedObject]:
        """End-to-end object detection pipeline.
        
        Args:
            image_base64: Base64-encoded image
            confidence_threshold: Confidence threshold for detections
            
        Returns:
            List of DetectedObject instances
            
        Raises:
            Various exceptions from image_service, yolo_service
        """
        logger.info("Starting object detection pipeline")
        
        # Validate confidence threshold
        validate_confidence_threshold(confidence_threshold)
        
        # Step 1: Decode image from Base64
        logger.debug("Step 1: Decoding Base64 image")
        image_array, image_width, image_height = self.image_service.decode_base64_image(
            image_base64
        )
        
        # Step 2: Run YOLO inference
        logger.debug("Step 2: Running YOLO inference")
        raw_detections, inference_time_ms = self.yolo_service.detect(
            image_array,
            confidence_threshold=confidence_threshold
        )
        
        # Step 3: Process detections and compute spatial positions
        logger.debug("Step 3: Processing detections and computing spatial positions")
        detected_objects = []
        
        for detection in raw_detections:
            # Extract data
            label = detection["name"]
            confidence = detection["confidence"]
            box = detection["box_xywh"]
            
            # Compute spatial position
            horizontal, vertical = self.spatial_service.get_relative_position(
                x=box["x"],
                y=box["y"],
                width=box["width"],
                height=box["height"],
                image_width=image_width,
                image_height=image_height
            )
            
            # Create position description
            position_description = self.spatial_service.create_position_description(
                label=label,
                horizontal=horizontal,
                vertical=vertical
            )
            
            # Create DetectedObject
            detected_object = DetectedObject(
                label=label,
                confidence=round(confidence, 4),
                position_description=position_description,
                bounding_box=BoundingBox(
                    x=round(box["x"], 2),
                    y=round(box["y"], 2),
                    width=round(box["width"], 2),
                    height=round(box["height"], 2)
                ),
                relative_position=RelativePosition(
                    horizontal=horizontal,
                    vertical=vertical
                )
            )
            
            detected_objects.append(detected_object)
        
        logger.info(f"Detection pipeline completed: {len(detected_objects)} objects detected")
        
        return detected_objects
