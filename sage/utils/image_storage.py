"""
Image and Video Storage Manager
Handles local storage, cleanup, and management of captured images and videos
"""

import logging
import os
import json
from pathlib import Path
from datetime import datetime
from typing import List, Dict, Optional

logger = logging.getLogger(__name__)


class ImageStorage:
    """Manages local storage of captured images"""
    
    def __init__(self, storage_path: str, max_images: int = 10):
        """
        Initialize image storage manager
        
        Args:
            storage_path: Directory path to store images
            max_images: Maximum number of images to keep
        """
        self.storage_path = Path(storage_path)
        self.max_images = max_images
        
        # Create storage directory if it doesn't exist
        self.storage_path.mkdir(parents=True, exist_ok=True)
        logger.info(f"Image storage initialized at {self.storage_path}")
    
    def save_image(self, image_data: bytes, filename: Optional[str] = None) -> str:
        """
        Save image to local storage
        
        Args:
            image_data: Image bytes (JPEG)
            filename: Optional filename (default: img_<timestamp>.jpg)
            
        Returns:
            Full path to saved image
        """
        if filename is None:
            timestamp = datetime.utcnow().strftime("%Y%m%d_%H%M%S_%f")[:-3]
            filename = f"img_{timestamp}.jpg"
        
        filepath = self.storage_path / filename
        
        with open(filepath, 'wb') as f:
            f.write(image_data)
        
        logger.debug(f"Saved image: {filepath} ({len(image_data)} bytes)")
        
        # Cleanup old images
        self._cleanup_old_images()
        
        return str(filepath)
    
    def get_images(self) -> List[Dict[str, any]]:
        """
        Get list of stored images with metadata
        
        Returns:
            List of image info dictionaries
        """
        images = []
        
        for filepath in sorted(self.storage_path.glob("img_*.jpg"), reverse=True):
            stat = filepath.stat()
            images.append({
                "filename": filepath.name,
                "path": str(filepath),
                "size_bytes": stat.st_size,
                "size_mb": round(stat.st_size / (1024 * 1024), 2),
                "timestamp": datetime.fromtimestamp(stat.st_mtime).isoformat()
            })
        
        return images
    
    def delete_image(self, filename: str) -> bool:
        """
        Delete a specific image
        
        Args:
            filename: Name of the image file
            
        Returns:
            True if deleted successfully
        """
        filepath = self.storage_path / filename
        
        if filepath.exists():
            filepath.unlink()
            logger.info(f"Deleted image: {filename}")
            return True
        else:
            logger.warning(f"Image not found: {filename}")
            return False
    
    def _cleanup_old_images(self):
        """Remove oldest images if exceeding max_images limit"""
        images = sorted(self.storage_path.glob("img_*.jpg"), key=os.path.getmtime, reverse=True)
        
        if len(images) > self.max_images:
            for old_image in images[self.max_images:]:
                old_image.unlink()
                logger.debug(f"Cleaned up old image: {old_image.name}")
    
    def get_storage_info(self) -> Dict[str, any]:
        """Get storage statistics"""
        images = self.get_images()
        total_size = sum(img["size_bytes"] for img in images)
        
        return {
            "total_images": len(images),
            "total_size_mb": round(total_size / (1024 * 1024), 2),
            "max_images": self.max_images,
            "storage_path": str(self.storage_path)
        }


class VideoStorage:
    """Manages local storage of recorded videos"""
    
    def __init__(self, storage_path: str, max_videos: int = 5, max_storage_mb: int = 1000):
        """
        Initialize video storage manager
        
        Args:
            storage_path: Directory path to store videos
            max_videos: Maximum number of videos to keep
            max_storage_mb: Maximum total storage in MB
        """
        self.storage_path = Path(storage_path)
        self.max_videos = max_videos
        self.max_storage_mb = max_storage_mb
        
        # Create storage directory if it doesn't exist
        self.storage_path.mkdir(parents=True, exist_ok=True)
        logger.info(f"Video storage initialized at {self.storage_path}")
    
    def get_video_path(self, video_id: str) -> Path:
        """
        Get full path for a video file
        
        Args:
            video_id: Video identifier
            
        Returns:
            Path object for the video file
        """
        return self.storage_path / f"{video_id}.mp4"
    
    def video_exists(self, video_id: str) -> bool:
        """Check if video file exists"""
        return self.get_video_path(video_id).exists()
    
    def get_videos(self) -> List[Dict[str, any]]:
        """
        Get list of stored videos with metadata
        
        Returns:
            List of video info dictionaries
        """
        videos = []
        
        for filepath in sorted(self.storage_path.glob("vid_*.mp4"), reverse=True):
            stat = filepath.stat()
            videos.append({
                "video_id": filepath.stem,
                "filename": filepath.name,
                "path": str(filepath),
                "size_bytes": stat.st_size,
                "size_mb": round(stat.st_size / (1024 * 1024), 2),
                "timestamp": datetime.fromtimestamp(stat.st_mtime).isoformat()
            })
        
        return videos
    
    def delete_video(self, video_id: str) -> bool:
        """
        Delete a specific video
        
        Args:
            video_id: Video identifier
            
        Returns:
            True if deleted successfully
        """
        filepath = self.get_video_path(video_id)
        
        if filepath.exists():
            filepath.unlink()
            logger.info(f"Deleted video: {video_id}")
            return True
        else:
            logger.warning(f"Video not found: {video_id}")
            return False
    
    def cleanup_old_videos(self, keep_last_n: int = None):
        """
        Remove oldest videos to maintain storage limits
        
        Args:
            keep_last_n: Number of videos to keep (default: self.max_videos)
        """
        if keep_last_n is None:
            keep_last_n = self.max_videos
        
        videos = sorted(self.storage_path.glob("vid_*.mp4"), key=os.path.getmtime, reverse=True)
        
        # Remove by count
        if len(videos) > keep_last_n:
            for old_video in videos[keep_last_n:]:
                old_video.unlink()
                logger.info(f"Cleaned up old video: {old_video.name}")
        
        # Remove by size
        self._cleanup_by_size()
    
    def _cleanup_by_size(self):
        """Remove oldest videos if exceeding max storage size"""
        videos = sorted(self.storage_path.glob("vid_*.mp4"), key=os.path.getmtime, reverse=True)
        
        total_size_mb = sum(v.stat().st_size for v in videos) / (1024 * 1024)
        
        while total_size_mb > self.max_storage_mb and len(videos) > 1:
            oldest = videos.pop()
            oldest.unlink()
            logger.info(f"Cleaned up video (size limit): {oldest.name}")
            total_size_mb = sum(v.stat().st_size for v in videos) / (1024 * 1024)
    
    def get_storage_info(self) -> Dict[str, any]:
        """Get storage statistics"""
        videos = self.get_videos()
        total_size = sum(v["size_bytes"] for v in videos)
        
        return {
            "total_videos": len(videos),
            "total_size_mb": round(total_size / (1024 * 1024), 2),
            "max_videos": self.max_videos,
            "max_storage_mb": self.max_storage_mb,
            "storage_path": str(self.storage_path)
        }
