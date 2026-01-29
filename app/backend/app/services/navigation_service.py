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
        
        # Get destination coordinates
        dest_coords = await self.get_coordinates(destination_query)
        if not dest_coords:
            return {"error": f"I couldn't find '{destination_query}'. Please try a different location name."}

        dest_lon, dest_lat = dest_coords
        route_url = f"{self.router_url}/{start_lon},{start_lat};{dest_lon},{dest_lat}"
        
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
                
                # 2. Road Name (expand abbreviations for TTS)
                road = step.get("name", "the path")
                if road == "": 
                    road = "the path"
                else:
                    # Expand common abbreviations
                    road = road.replace(" Rd", " Road")
                    road = road.replace(" St", " Street")
                    road = road.replace(" Ave", " Avenue")
                    road = road.replace(" Blvd", " Boulevard")
                
                # 3. Distance for this step
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
                    "distance_text": dist_formatted["text"]
                })

            # Format total distance and time
            total_distance = route["distance"]
            total_duration = route["duration"]
            
            distance_formatted = self._format_distance(total_distance)
            time_formatted = self._format_time(total_duration)

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
            return {"error": "An error occurred while finding the route. Please try again."    return None
        except httpx.HTTPError as e:
            print(f"⚠️ Geocoding HTTP error: {e}")
            return None
        except Exception as e:
            print(f"⚠️ Geocoding error: {e}")
            return None
# 👇 UPDATED FUNCTION 👇
    async def get_directions(self, start_lon, start_lat, destination_query: str):
        """
        Returns a dictionary with route metadata and a FULL LIST of steps.
        """
        dest_coords = await self.get_coordinates(destination_query)
        if not dest_coords:
            return {"error": f"Place '{destination_query}' not found."}

        dest_lon, dest_lat = dest_coords
        route_url = f"{self.router_url}/{start_lon},{start_lat};{dest_lon},{dest_lat}"
        
        params = {"steps": "true", "geometries": "geojson", "overview": "false"}

        async with httpx.AsyncClient() as client:
            resp = await client.get(route_url, params=params)
            data = resp.json()

        if data.get("code") != "Ok" or not data.get("routes"):
            return {"error": "No walking route found."}

        # Extract Route Data
        route = data["routes"][0]
        legs = route["legs"][0]
        steps = legs["steps"]

        # Parse ALL steps into a readable list
        parsed_steps = []
        for step in steps:
            # 1. Instruction (e.g., "turn right")
            maneuver = step["maneuver"]
            action = maneuver.get("type", "move")
            modifier = maneuver.get("modifier", "").replace("_", " ")
            
            # 2. Road Name
            road = step.get("name", "the path")
            if road == "": road = "the path"
            
            # 3. Distance for this step
            dist = round(step.get("distance", 0))
            
            # Construct natural language sentence
            # Example: "Turn right onto Service Road. Go for 50 meters."
            if action == "arrive":
                instruction = f"You have arrived at your destination."
            elif action == "depart":
                instruction = f"Head {modifier} on {road}."
            else:
                instruction = f"{action} {modifier} onto {road}."
            
            parsed_steps.append({
                "instruction": instruction,
                "distance_meters": dist
            })

        # Return the RICH DATA object
        return {
            "destination": destination_query,
            "total_distance": round(route["distance"]),
            "total_time_min": round(route["duration"] / 60),
            "steps": parsed_steps
        }