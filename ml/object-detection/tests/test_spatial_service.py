"""Tests for the spatial reasoning service."""
import pytest
from src.services.spatial_service import SpatialService


class TestSpatialService:
    """Test cases for SpatialService."""
    
    def test_get_horizontal_zone_left(self):
        """Test left zone detection."""
        # Center at 20% of image width
        zone = SpatialService.get_horizontal_zone(center_x=100, image_width=500)
        assert zone == "left"
    
    def test_get_horizontal_zone_center(self):
        """Test center zone detection."""
        # Center at 50% of image width
        zone = SpatialService.get_horizontal_zone(center_x=250, image_width=500)
        assert zone == "center"
    
    def test_get_horizontal_zone_right(self):
        """Test right zone detection."""
        # Center at 80% of image width
        zone = SpatialService.get_horizontal_zone(center_x=400, image_width=500)
        assert zone == "right"
    
    def test_get_vertical_zone_top(self):
        """Test top zone detection."""
        # Center at 20% of image height
        zone = SpatialService.get_vertical_zone(center_y=100, image_height=500)
        assert zone == "top"
    
    def test_get_vertical_zone_middle(self):
        """Test middle zone detection."""
        # Center at 50% of image height
        zone = SpatialService.get_vertical_zone(center_y=250, image_height=500)
        assert zone == "middle"
    
    def test_get_vertical_zone_bottom(self):
        """Test bottom zone detection."""
        # Center at 80% of image height
        zone = SpatialService.get_vertical_zone(center_y=400, image_height=500)
        assert zone == "bottom"
    
    def test_get_relative_position(self):
        """Test relative position computation."""
        # Object at position (100, 50, 80, 100) in 500x500 image
        horizontal, vertical = SpatialService.get_relative_position(
            x=100, y=50, width=80, height=100,
            image_width=500, image_height=500
        )
        assert horizontal == "center"
        assert vertical == "top"
    
    def test_create_position_description_left_side(self):
        """Test position description for left-side object."""
        description = SpatialService.create_position_description(
            label="person",
            horizontal="left",
            vertical="middle"
        )
        assert description == "person on the left side"
    
    def test_create_position_description_right_bottom(self):
        """Test position description for right-bottom object."""
        description = SpatialService.create_position_description(
            label="chair",
            horizontal="right",
            vertical="bottom"
        )
        assert description == "chair on the right-bottom"
    
    def test_create_position_description_center(self):
        """Test position description for center object."""
        description = SpatialService.create_position_description(
            label="car",
            horizontal="center",
            vertical="middle"
        )
        assert description == "car in the center"
