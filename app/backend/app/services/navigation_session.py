"""
Navigation Session Manager for Real-Time Turn-by-Turn Navigation
Manages single-user navigation sessions with proximity-based instruction triggering
"""

import math
from typing import Optional, Dict, List
from datetime import datetime, timedelta
from app.services.navigation_service import NavigationService


class NavigationSession:
    """Stores navigation state for a single active session"""
    
    def __init__(self, destination: str):
        self.destination = destination
        self.status = "waiting_for_location"  # waiting_for_location, active, arrived, stopped
        self.route_data: Optional[Dict] = None
        self.steps_with_coords: List[Dict] = []  # [{instruction, lat, lon, distance_meters}]
        self.current_step_index = 0
        self.created_at = datetime.utcnow()
        self.last_update = datetime.utcnow()
        self.origin_coords: Optional[tuple] = None
        
    def is_expired(self, timeout_minutes=30) -> bool:
        """Check if session has timed out"""
        elapsed = (datetime.utcnow() - self.last_update).total_seconds()
        return elapsed > (timeout_minutes * 60)


class NavigationSessionManager:
    """
    Manages navigation session for single-user system
    Handles route calculation, proximity checking, and instruction triggering
    """
    
    def __init__(self):
        self.active_session: Optional[NavigationSession] = None
        self.navigation_service = NavigationService()
    
    def has_active_session(self) -> bool:
        """Check if there's an active navigation session"""
        return self.active_session is not None and self.active_session.status != "stopped"
    
    def start_navigation(self, destination: str) -> NavigationSession:
        """
        Start a new navigation session
        Creates session in 'waiting_for_location' state
        Route will be calculated when first location update arrives
        """
        # Stop any existing session
        if self.active_session:
            self.stop_navigation()
        
        self.active_session = NavigationSession(destination)
        print(f"✅ Navigation session created for destination: {destination}")
        print(f"   Status: {self.active_session.status}")
        
        return self.active_session
    
    async def set_route(self, origin_lat: float, origin_lon: float):
        """
        Calculate route using first location update
        Extracts coordinates from OSRM and sets session to 'active'
        """
        if not self.active_session:
            print("⚠️ No active navigation session")
            return None
        
        if self.active_session.status != "waiting_for_location":
            print("⚠️ Session already has route calculated")
            return None
        
        print(f"📍 Calculating route from ({origin_lat}, {origin_lon}) to {self.active_session.destination}")
        
        # Fetch route from OSRM
        route_data = await self.navigation_service.get_directions(
            start_lon=origin_lon,
            start_lat=origin_lat,
            destination_query=self.active_session.destination
        )
        
        if "error" in route_data:
            print(f"❌ Route calculation failed: {route_data['error']}")
            self.stop_navigation()
            return {"error": route_data["error"]}
        
        # Store route data
        self.active_session.route_data = route_data
        self.active_session.origin_coords = (origin_lat, origin_lon)
        
        # Extract coordinates from steps
        self._extract_step_coordinates(route_data)
        
        # Update session status
        self.active_session.status = "active"
        self.active_session.last_update = datetime.utcnow()
        
        print(f"✅ Route calculated: {len(self.active_session.steps_with_coords)} steps")
        print(f"   Distance: {route_data.get('distance_text', 'N/A')}")
        print(f"   Duration: {route_data.get('total_time_text', 'N/A')}")
        print(f"   ETA: {route_data.get('eta', 'N/A')}")
        
        # Print all navigation instructions
        print(f"\n🗺️  COMPLETE ROUTE INSTRUCTIONS:")
        print(f"{'=' * 70}")
        for i, step in enumerate(self.active_session.steps_with_coords, 1):
            distance_km = step['distance_meters'] / 1000 if step['distance_meters'] >= 1000 else None
            if distance_km:
                dist_text = f"{distance_km:.1f} km"
            else:
                dist_text = f"{step['distance_meters']:.0f} m"
            
            coord_text = ""
            if step.get('lat') and step.get('lon'):
                coord_text = f" @ ({step['lat']:.6f}, {step['lon']:.6f})"
            
            print(f"   Step {i:2d}: {step['instruction']}")
            print(f"           Distance: {dist_text}{coord_text}")
        print(f"{'=' * 70}\n")
        
        # Return first instruction
        if self.active_session.steps_with_coords:
            first_step = self.active_session.steps_with_coords[0]
            return {
                "instruction": first_step["instruction"],
                "should_speak": True,
                "distance_to_destination": route_data.get("total_distance_meters", 0),
                "eta": route_data.get("eta", "")
            }
        
        return None
    
    def _extract_step_coordinates(self, route_data: Dict):
        """
        Extract GPS coordinates for each navigation step
        Coordinates come from OSRM maneuver locations (already extracted by navigation_service)
        """
        steps = route_data.get("steps", [])
        steps_with_coords = []
        
        for step in steps:
            steps_with_coords.append({
                "instruction": step["instruction"],
                "distance_meters": step["distance_meters"],
                "lat": step.get("lat"),  # Extracted from OSRM maneuver.location
                "lon": step.get("lon")
            })
        
        self.active_session.steps_with_coords = steps_with_coords
        
        # Log for debugging
        coords_available = sum(1 for s in steps_with_coords if s["lat"] is not None)
        print(f"   Coordinates available for {coords_available}/{len(steps_with_coords)} steps")
    
    async def update_location(self, lat: float, lon: float) -> Optional[Dict]:
        """
        Process location update during navigation
        Returns instruction to speak if needed
        
        Returns:
            {
                "instruction": str,
                "should_speak": bool,
                "distance_to_next": float,
                "status": "active" | "arrived"
            }
        """
        if not self.active_session:
            return None
        
        # Update last activity timestamp
        self.active_session.last_update = datetime.utcnow()
        
        # If waiting for initial location, calculate route
        if self.active_session.status == "waiting_for_location":
            result = await self.set_route(lat, lon)
            return result
        
        # If not active, ignore
        if self.active_session.status != "active":
            return None
        
        # Check if arrived at destination (within 20 meters)
        if self.active_session.origin_coords and self.active_session.route_data:
            # Calculate distance to destination
            # For now, we'll use the last step coordinates when available
            # Simplified check: if we've passed all steps, consider arrived
            if self.active_session.current_step_index >= len(self.active_session.steps_with_coords):
                self.active_session.status = "arrived"
                print(f"🎯 Destination reached: {self.active_session.destination}")
                
                return {
                    "instruction": f"You have arrived at {self.active_session.destination}",
                    "should_speak": True,
                    "distance_to_next": 0,
                    "status": "arrived"
                }
        
        # Check proximity to next instruction point
        current_step_idx = self.active_session.current_step_index
        steps = self.active_session.steps_with_coords
        
        if current_step_idx < len(steps):
            current_step = steps[current_step_idx]
            
            # If coordinates are available, check distance
            if current_step["lat"] is not None and current_step["lon"] is not None:
                distance = self._haversine_distance(
                    lat, lon,
                    current_step["lat"], current_step["lon"]
                )
                
                # Within 50 meters of next instruction point
                if distance < 50:
                    self.active_session.current_step_index += 1
                    print(f"📢 Instruction triggered: Step {current_step_idx + 1}/{len(steps)}")
                    
                    return {
                        "instruction": current_step["instruction"],
                        "should_speak": True,
                        "distance_to_next": distance,
                        "status": "active"
                    }
                else:
                    # Still approaching
                    return {
                        "instruction": current_step["instruction"],
                        "should_speak": False,
                        "distance_to_next": distance,
                        "status": "active"
                    }
            else:
                # Fallback: Use distance-based progression
                # Move to next step after estimated distance covered
                # This is a simplified approach when coordinates aren't available
                return {
                    "instruction": current_step["instruction"],
                    "should_speak": False,
                    "distance_to_next": current_step["distance_meters"],
                    "status": "active"
                }
        
        return None
    
    def _haversine_distance(self, lat1: float, lon1: float, lat2: float, lon2: float) -> float:
        """
        Calculate distance in meters between two GPS coordinates
        Uses Haversine formula
        """
        R = 6371000  # Earth radius in meters
        
        lat1_rad = math.radians(lat1)
        lat2_rad = math.radians(lat2)
        delta_lat = math.radians(lat2 - lat1)
        delta_lon = math.radians(lon2 - lon1)
        
        a = (math.sin(delta_lat / 2) ** 2 +
             math.cos(lat1_rad) * math.cos(lat2_rad) *
             math.sin(delta_lon / 2) ** 2)
        c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
        
        distance = R * c
        return distance
    
    def stop_navigation(self):
        """End the active navigation session"""
        if self.active_session:
            destination = self.active_session.destination
            self.active_session.status = "stopped"
            self.active_session = None
            print(f"🛑 Navigation session stopped for: {destination}")
        else:
            print("⚠️ No active navigation session to stop")
    
    def get_session_status(self) -> Optional[Dict]:
        """Get current session status for debugging"""
        if not self.active_session:
            return {"status": "no_session"}
        
        return {
            "status": self.active_session.status,
            "destination": self.active_session.destination,
            "current_step": self.active_session.current_step_index,
            "total_steps": len(self.active_session.steps_with_coords),
            "elapsed_time": (datetime.utcnow() - self.active_session.created_at).total_seconds()
        }
    
    def cleanup_expired_sessions(self, timeout_minutes=30):
        """Remove expired sessions (called periodically)"""
        if self.active_session and self.active_session.is_expired(timeout_minutes):
            print(f"🧹 Cleaning up expired navigation session: {self.active_session.destination}")
            self.stop_navigation()


# Global singleton instance
_navigation_session_manager = NavigationSessionManager()

def get_navigation_session_manager() -> NavigationSessionManager:
    """Get the global navigation session manager instance"""
    return _navigation_session_manager
