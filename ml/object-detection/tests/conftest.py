"""Pytest configuration and fixtures."""
import sys
from pathlib import Path
import pytest
from fastapi.testclient import TestClient

# Add project root to path
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))

from src.main import create_app
from src.services.yolo_service import YOLOService
from src.services.detection_service import DetectionService


@pytest.fixture(scope="session")
def app():
    """Create FastAPI test application."""
    return create_app()


@pytest.fixture(scope="session")
def client(app):
    """Create test client."""
    return TestClient(app)


@pytest.fixture(scope="session")
def yolo_service():
    """Create YOLO service instance for testing."""
    return YOLOService()


@pytest.fixture(scope="session")
def detection_service(yolo_service):
    """Create Detection service instance for testing."""
    return DetectionService(yolo_service)
