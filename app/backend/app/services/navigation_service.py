import httpx
import math
from datetime import datetime, timedelta

class NavigationService:
    def __init__(self):
        # 1. The Search Engine (Finds coordinates)
        self.geocoder_url = "https://nominatim.openstreetmap.org/search"
        
        # 2. The Router (Finds the path)
        self.router_url = "http://router.project-osrm.org/route/v1/foot"
        
        # 3. API timeout settings
        self.timeout = 30.0  # 30 seconds for API calls

    def _validate_coordinates(self, lat: float, lon: float) -> bool:
        """Validate GPS coordinates are within valid ranges."""
        return -90 <= lat <= 90 and -180 <= lon <= 180

    def _format_distance(self, meters: float) -> dict:
        """
        Format distance for display and voice output.
        
        Returns:
            dict with 'value', 'unit', and 'text' fields
        """
        if meters >= 1000:
            km = round(meters / 1000, 1)
            return {
                "value": km,
                "unit": "km",
                "text": f"{km} kilometers" if km != 1 else "1 kilometer"
            }
        else:
            m = round(meters)
            return {
                "value": m,
                "unit": "m",
                "text": f"{m} meters" if m != 1 else "1 meter"
            }
    
    def _format_time(self, seconds: float) -> dict:
        """
        Format duration for display and voice output.
        
        Returns:
            dict with 'minutes', 'text', and 'eta' fields
        """
        minutes = round(seconds / 60)
        
        # Calculate ETA
        eta_time = datetime.now() + timedelta(seconds=seconds)
        eta_formatted = eta_time.strftime("%I:%M %p")  # e.g., "02:30 PM"
        
        # Voice-friendly time text
        if minutes < 1:
            time_text = "less than a minute"
        elif minutes == 1:
            time_text = "1 minute"
        elif minutes < 60:
            time_text = f"{minutes} minutes"
        else:
            hours = minutes // 60
            remaining_mins = minutes % 60
            if remaining_mins == 0:
                time_text = f"{hours} hour" if hours == 1 else f"{hours} hours"
            else:
                time_text = f"{hours} hour {remaining_mins} minutes" if hours == 1 else f"{hours} hours {remaining_mins} minutes"
        
        return {
            "minutes": minutes,
            "text": time_text,
            "eta": eta_formatted
        }
    
    async def get_coordinates(self, place_name: str, user_lat: float = None, user_lon: float = None):
        """
        Geocode a place name to coordinates using Nominatim.
        Prioritizes results near user's current location.
        
        Args:
            place_name: Location name to search for
            user_lat: User's current latitude (for proximity bias)
            user_lon: User's current longitude (for proximity bias)
            
        Returns:
            Tuple of (lon, lat) or None if not found
        """
        params = {
            "q": place_name,
            "format": "json",
            "limit": 1,
            "addressdetails": 1
        }
        
        # Add proximity bias if user location is available
        if user_lat is not None and user_lon is not None:
            # Nominatim prioritizes results near these coordinates
            params["lat"] = user_lat
            params["lon"] = user_lon
            
            # Optional: Add viewbox to restrict search area (50km radius)
            # This ensures we find the NEAREST location
            params["viewbox"] = f"{user_lon-0.5},{user_lat-0.5},{user_lon+0.5},{user_lat+0.5}"
            params["bounded"] = 1  # Restrict results to viewbox
        
        try:
            async with httpx.AsyncClient(timeout=self.timeout) as client:
                resp = await client.get(self.geocoder_url, params=params)
                resp.raise_for_status()
                data = resp.json()
            
            if data and len(data) > 0:
                result = data[0]
                lon = float(result["lon"])
                lat = float(result["lat"])
                return (lon, lat)
            else:
                return None
                
        except httpx.TimeoutException:
            print(f"⚠️ Geocoding timeout for: {place_name}")
            return None
        except Exception as e:
            print(f"⚠️ Geocoding error: {e}")
            return None
    
    async def get_directions(self, start_lon: float, start_lat: float, destination_query: str):
        """
        Returns a dictionary with route metadata and a FULL LIST of steps.
        Enhanced with validation, error handling, and voice-friendly formatting.
        """
        # Validate GPS coordinates
        if not self._validate_coordinates(start_lat, start_lon):
            return {"error": "Invalid GPS coordinates. Please check your location settings."}
        
        # Validate destination
        if not destination_query or not destination_query.strip():
            return {"error": "Please provide a destination."}
        
        # Get destination coordinates with proximity bias (finds NEAREST location)
        dest_coords = await self.get_coordinates(destination_query, start_lat, start_lon)
        if not dest_coords:
            return {"error": f"I couldn't find '{destination_query}'. Please try a different location name."}

        dest_lon, dest_lat = dest_coords
        print(f"🎯 Destination found: {destination_query} at ({dest_lat:.6f}, {dest_lon:.6f})")
        
        route_url = f"{self.router_url}/{start_lon},{start_lat};{dest_lon},{dest_lat}"
        print(f"🔗 OSRM Request: {route_url}")
        
        params = {"steps": "true", "geometries": "geojson", "overview": "false"}

        try:
            async with httpx.AsyncClient(timeout=self.timeout) as client:
                resp = await client.get(route_url, params=params)
                resp.raise_for_status()
                data = resp.json()

            if data.get("code") != "Ok" or not data.get("routes"):
                return {"error": f"I couldn't find a walking route to {destination_query}. It might be too far or unreachable on foot."}

            # Extract Route Data (best route is the first one)
            route = data["routes"][0]
            legs = route["legs"][0]
            steps = legs["steps"]

            # Parse ALL steps into a readable list with voice-friendly formatting
            parsed_steps = []
            for idx, step in enumerate(steps):
                # 1. Instruction (e.g., "turn right")
                maneuver = step["maneuver"]
                action = maneuver.get("type", "move").replace("-", " ")
                modifier = maneuver.get("modifier", "").replace("_", " ")
                
                # 2. Extract GPS coordinates for this instruction point
                # OSRM provides maneuver location as [longitude, latitude]
                maneuver_location = maneuver.get("location", [None, None])
                maneuver_lon = maneuver_location[0]
                maneuver_lat = maneuver_location[1]
                
                # 3. Road Name (expand abbreviations for TTS)
                road = step.get("name", "the path")
                if road == "": 
                    road = "the path"
                else:
                    # Expand common abbreviations
                    road = road.replace(" Rd", " Road")
                    road = road.replace(" St", " Street")
                    road = road.replace(" Ave", " Avenue")
                    road = road.replace(" Blvd", " Boulevard")
                
                # 4. Distance for this step
                dist = step.get("distance", 0)
                dist_formatted = self._format_distance(dist)
                
                # Construct natural language sentence with distance context
                if action == "arrive":
                    instruction = "You have arrived at your destination."
                elif action == "depart":
                    instruction = f"Head {modifier} on {road}."
                else:
                    # Add distance context for better navigation
                    if modifier:
                        instruction = f"In {dist_formatted['text']}, {action} {modifier} onto {road}."
                    else:
                        instruction = f"Continue on {road} for {dist_formatted['text']}."
                
                parsed_steps.append({
                    "instruction": instruction,
                    "distance_meters": round(dist),
                    "distance_text": dist_formatted["text"],
                    "lat": maneuver_lat,  # GPS coordinate for proximity checking
                    "lon": maneuver_lon
                })

            # Format total distance and time
            total_distance = route["distance"]
            total_duration = route["duration"]
            
            distance_formatted = self._format_distance(total_distance)
            time_formatted = self._format_time(total_duration)
            
            print(f"\n📊 OSRM Route Summary:")
            print(f"   Total Distance: {distance_formatted['text']} ({total_distance:.0f} meters)")
            print(f"   Estimated Time: {time_formatted['text']} (ETA: {time_formatted['eta']})")
            print(f"   Number of Steps: {len(parsed_steps)}")

            # Return the RICH DATA object with formatted values
            return {
                "destination": destination_query,
                "total_distance_meters": round(total_distance),
                "total_distance": distance_formatted["value"],
                "distance_unit": distance_formatted["unit"],
                "distance_text": distance_formatted["text"],
                "total_time_min": time_formatted["minutes"],
                "total_time_text": time_formatted["text"],
                "eta": time_formatted["eta"],
                "steps": parsed_steps,
                "step_count": len(parsed_steps)
            }
            
        except httpx.TimeoutException:
            return {"error": "Navigation request timed out. Please try again."}
        except httpx.HTTPError as e:
            print(f"⚠️ Routing HTTP error: {e}")
            return {"error": "Navigation service is temporarily unavailable. Please try again later."}
        except Exception as e:
            print(f"⚠️ Routing error: {e}")
            return {"error": "An error occurred while finding the route. Please try again."}