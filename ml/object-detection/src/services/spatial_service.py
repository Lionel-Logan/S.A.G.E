"""Spatial reasoning service for object positioning."""
from typing import Tuple, Dict
from src.utils.logger import get_logger
from config import SPATIAL_ZONES

logger = get_logger(__name__)


class SpatialService:
    """Service for computing relative spatial positions of detected objects."""
    
    @staticmethod
    def get_horizontal_zone(center_x: float, image_width: int) -> str:
        """Determine horizontal zone based on x-coordinate.
        
        Args:
            center_x: X-coordinate of object center
            image_width: Total image width
            
        Returns:
            Zone name: 'left', 'center', or 'right'
        """
        relative_x = center_x / image_width
        
        if relative_x < 0.33:
            return SPATIAL_ZONES["horizontal"][0]  # "left"
        elif relative_x < 0.66:
            return SPATIAL_ZONES["horizontal"][1]  # "center"
        else:
            return SPATIAL_ZONES["horizontal"][2]  # "right"
    
    @staticmethod
    def get_vertical_zone(center_y: float, image_height: int) -> str:
        """Determine vertical zone based on y-coordinate.
        
        Args:
            center_y: Y-coordinate of object center
            image_height: Total image height
            
        Returns:
            Zone name: 'top', 'middle', or 'bottom'
        """
        relative_y = center_y / image_height
        
        if relative_y < 0.33:
            return SPATIAL_ZONES["vertical"][0]  # "top"
        elif relative_y < 0.66:
            return SPATIAL_ZONES["vertical"][1]  # "middle"
        else:
            return SPATIAL_ZONES["vertical"][2]  # "bottom"
    
    @staticmethod
    def get_relative_position(
        x: float,
        y: float,
        width: float,
        height: float,
        image_width: int,
        image_height: int
    ) -> Tuple[str, str, str]:
        """Compute relative position and description for an object.
        
        Args:
            x: X coordinate of top-left corner of bounding box
            y: Y coordinate of top-left corner of bounding box
            width: Width of bounding box
            height: Height of bounding box
            image_width: Total image width
            image_height: Total image height
            
        Returns:
            Tuple of (horizontal_zone, vertical_zone, position_description)
        """
        # Calculate center point
        center_x = x + (width / 2)
        center_y = y + (height / 2)
        
        # Get zones
        horizontal_zone = SpatialService.get_horizontal_zone(center_x, image_width)
        vertical_zone = SpatialService.get_vertical_zone(center_y, image_height)
        
        logger.debug(
            f"Position computed: center=({center_x:.1f}, {center_y:.1f}), "
            f"horizontal={horizontal_zone}, vertical={vertical_zone}"
        )
        
        return horizontal_zone, vertical_zone
    
    @staticmethod
    def create_position_description(label: str, horizontal: str, vertical: str) -> str:
        """Create human-readable position description.
        
        Args:
            label: Object class label
            horizontal: Horizontal position (left, center, right)
            vertical: Vertical position (top, middle, bottom)
            
        Returns:
            Human-readable description (e.g., "person on the left side")
        """
        # Special handling for center horizontal position
        if horizontal == "center":
            if vertical == "middle":
                description = f"{label} in the center"
            else:
                description = f"{label} in the center-{vertical}"
        else:
            # For left/right, use "on the X side"
            if vertical == "middle":
                description = f"{label} on the {horizontal} side"
            else:
                description = f"{label} on the {horizontal}-{vertical}"
        
        return description
