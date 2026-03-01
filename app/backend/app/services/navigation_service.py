import re
import httpx
import math
from datetime import datetime, timedelta
from app.config import settings

class NavigationService:
    def __init__(self):
        # Google Maps Platform REST endpoints
        # Places API (New) - Text Search (POST)
        self.places_url = "https://places.googleapis.com/v1/places:searchText"
        # Legacy Directions API (GET) - still active for this project
        self.directions_url = "https://maps.googleapis.com/maps/api/directions/json"

        # API timeout settings
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
        Geocode a place name to coordinates using Places API (New) — Text Search.
        Uses POST with X-Goog-Api-Key header and X-Goog-FieldMask.
        Prioritizes results near user's current location via locationBias circle.

        Returns:
            Tuple of (lon, lat) or None if not found
        """
        headers = {
            "Content-Type": "application/json",
            "X-Goog-Api-Key": settings.GOOGLE_MAPS_API_KEY,
            "X-Goog-FieldMask": "places.location"
        }

        body = {"textQuery": place_name}

        # Bias results within 50km of user's current location
        if user_lat is not None and user_lon is not None:
            body["locationBias"] = {
                "circle": {
                    "center": {"latitude": user_lat, "longitude": user_lon},
                    "radius": 50000.0
                }
            }

        try:
            async with httpx.AsyncClient(timeout=self.timeout) as client:
                resp = await client.post(self.places_url, json=body, headers=headers)
                resp.raise_for_status()
                data = resp.json()

            places = data.get("places", [])
            if not places:
                print(f"⚠️ Places API (New): No results for '{place_name}'")
                return None

            location = places[0]["location"]
            lat = location["latitude"]
            lon = location["longitude"]
            print(f"📍 Places API found: {place_name} → ({lat:.6f}, {lon:.6f})")
            return (lon, lat)

        except httpx.TimeoutException:
            print(f"⚠️ Places API timeout for: {place_name}")
            return None
        except Exception as e:
            print(f"⚠️ Places API error: {e}")
            return None
    
    async def get_directions(self, start_lon: float, start_lat: float, destination_query: str):
        """
        Returns a dictionary with route metadata and a FULL LIST of steps.
        Uses Google Directions API for walking routes with natural language instructions.
        Output shape is identical to before — navigation_session.py is unchanged.
        """
        # Validate GPS coordinates
        if not self._validate_coordinates(start_lat, start_lon):
            return {"error": "Invalid GPS coordinates. Please check your location settings."}

        # Validate destination
        if not destination_query or not destination_query.strip():
            return {"error": "Please provide a destination."}

        # Step 1: Geocode destination using Places API (nearest match to user)
        dest_coords = await self.get_coordinates(destination_query, start_lat, start_lon)
        if not dest_coords:
            return {"error": f"I couldn't find '{destination_query}'. Please try a different location name."}

        dest_lon, dest_lat = dest_coords
        print(f"🎯 Destination found: {destination_query} at ({dest_lat:.6f}, {dest_lon:.6f})")

        # Step 2: Fetch walking route from Google Directions API
        params = {
            "origin": f"{start_lat},{start_lon}",
            "destination": f"{dest_lat},{dest_lon}",
            "mode": "walking",
            "key": settings.GOOGLE_MAPS_API_KEY
        }
        print(f"🔗 Directions API Request: {start_lat},{start_lon} → {dest_lat},{dest_lon}")

        try:
            async with httpx.AsyncClient(timeout=self.timeout) as client:
                resp = await client.get(self.directions_url, params=params)
                resp.raise_for_status()
                data = resp.json()

            status = data.get("status")
            if status != "OK" or not data.get("routes"):
                print(f"⚠️ Directions API status: {status}")
                return {"error": f"I couldn't find a walking route to {destination_query}. It might be too far or unreachable on foot."}

            # Extract route data (best route is first)
            legs = data["routes"][0]["legs"][0]
            steps = legs["steps"]

            # Parse ALL steps — Google provides pre-built natural language instructions
            parsed_steps = []
            for step in steps:
                # Strip HTML tags from Google's instruction
                # e.g. "Turn <b>right</b> onto <b>MG Road</b>" → "Turn right onto MG Road"
                raw_instruction = step.get("html_instructions", "Continue")
                instruction = re.sub(r'<[^>]+>', '', raw_instruction)
                instruction = instruction.replace("&nbsp;", " ").strip()

                # GPS coordinates — start_location is always present in Directions API
                lat = step["start_location"]["lat"]
                lon = step["start_location"]["lng"]

                # Distance in meters
                dist = step["distance"]["value"]
                dist_formatted = self._format_distance(dist)

                parsed_steps.append({
                    "instruction": instruction,
                    "distance_meters": dist,
                    "distance_text": dist_formatted["text"],
                    "lat": lat,
                    "lon": lon
                })

            # Total route stats
            total_distance = legs["distance"]["value"]   # meters
            total_duration = legs["duration"]["value"]   # seconds

            distance_formatted = self._format_distance(total_distance)
            time_formatted = self._format_time(total_duration)

            print(f"\n📊 Google Directions Route Summary:")
            print(f"   Total Distance: {distance_formatted['text']} ({total_distance:.0f} meters)")
            print(f"   Estimated Time: {time_formatted['text']} (ETA: {time_formatted['eta']})")
            print(f"   Number of Steps: {len(parsed_steps)}")

            return {
                "destination": destination_query,
                "total_distance_meters": total_distance,
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
            print(f"⚠️ Directions API HTTP error: {e}")
            return {"error": "Navigation service is temporarily unavailable. Please try again later."}
        except Exception as e:
            print(f"⚠️ Directions API error: {e}")
            return {"error": "An error occurred while finding the route. Please try again."}