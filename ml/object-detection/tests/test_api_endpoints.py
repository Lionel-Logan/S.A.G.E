"""Tests for the detection API endpoints."""
import base64
from pathlib import Path
import pytest


@pytest.mark.asyncio
async def test_health_check(client):
    """Test health check endpoint."""
    response = client.get("/api/v1/objects/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] in ["healthy", "unhealthy"]
    assert "model_loaded" in data


@pytest.mark.asyncio
async def test_root_endpoint(client):
    """Test root endpoint."""
    response = client.get("/")
    assert response.status_code == 200
    data = response.json()
    assert "name" in data
    assert "version" in data
    assert "endpoints" in data


@pytest.mark.asyncio
async def test_detect_with_invalid_base64(client):
    """Test detection with invalid Base64."""
    payload = {
        "image_base64": "not_valid_base64!!!"
    }
    response = client.post("/api/v1/objects/detect", json=payload)
    assert response.status_code == 400
    data = response.json()
    assert data["detail"]["status"] == "error"


@pytest.mark.asyncio
async def test_detect_with_empty_base64(client):
    """Test detection with empty Base64."""
    payload = {
        "image_base64": ""
    }
    response = client.post("/api/v1/objects/detect", json=payload)
    assert response.status_code == 400


@pytest.mark.asyncio
async def test_detect_with_invalid_confidence_threshold(client):
    """Test detection with invalid confidence threshold."""
    # This would require a valid image, so we'll just test the validation logic
    payload = {
        "image_base64": base64.b64encode(b"test").decode(),
        "confidence_threshold": 1.5  # Invalid: > 1.0
    }
    response = client.post("/api/v1/objects/detect", json=payload)
    # Should fail validation before attempting detection
    assert response.status_code in [400, 422]
