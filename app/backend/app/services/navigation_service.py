import httpx
import math

class NavigationService:
    def __init__(self):
        # 1. The Search Engine (Finds coordinates)
        self.geocoder_url = "https://nominatim.openstreetmap.org/search"
        
        # 2. The Router (Finds the path)
        self.router_url = "http://router.project-osrm.org/route/v1/foot"

    async def get_coordinates(self, place_name: str):
        """
        Converts "Kochi Metro Station" -> (76.2, 9.9)
        Uses Nominatim API.
        """
        params = {
            "q": place_name,
            "format": "json",
            "limit": 1,
            "addressdetails": 1
        }
        # Nominatim REQUIRES a User-Agent header (Rule of usage)
        headers = {"User-Agent": "SageSmartGlass/1.0"}

        async with httpx.AsyncClient() as client:
            resp = await client.get(self.geocoder_url, params=params, headers=headers)
            data = resp.json()
            
            if not data:
                return None
            
            # Extract Lat/Lon
            lat = data[0]["lat"]
            lon = data[0]["lon"]
            return float(lon), float(lat) # Return as (Lon, Lat) for OSRM
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