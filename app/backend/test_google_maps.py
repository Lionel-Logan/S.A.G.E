"""
Quick test for Google Maps integration (Places API + Directions API)
Run from: D:\S8 Project\S.A.G.E\app\backend
Usage: python test_google_maps.py
"""

import asyncio
import sys
import os

# Add backend to path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app.services.navigation_service import NavigationService

# ── Test coordinates (Kochi, India) ───────────────────────────────────────────
TEST_ORIGIN_LAT = 10.0261
TEST_ORIGIN_LON = 76.3125
TEST_DESTINATION = "Lulu Mall Kochi"


async def test_places_api():
    """Test Google Places API (geocoding)"""
    print("\n" + "=" * 60)
    print("TEST 1: Google Places API — Find Place")
    print("=" * 60)

    nav = NavigationService()
    print(f"  Searching for: '{TEST_DESTINATION}'")
    print(f"  Near: ({TEST_ORIGIN_LAT}, {TEST_ORIGIN_LON})")

    coords = await nav.get_coordinates(TEST_DESTINATION, TEST_ORIGIN_LAT, TEST_ORIGIN_LON)

    if coords:
        lon, lat = coords
        print(f"\n  ✅ PASS — Found at: lat={lat:.6f}, lon={lon:.6f}")
    else:
        print("\n  ❌ FAIL — No coordinates returned")
        print("  Check: Is GOOGLE_MAPS_API_KEY set? Is Places API enabled?")

    return coords


async def test_directions_api():
    """Test Google Directions API (walking route)"""
    print("\n" + "=" * 60)
    print("TEST 2: Google Directions API — Walking Route")
    print("=" * 60)

    nav = NavigationService()
    print(f"  From: ({TEST_ORIGIN_LAT}, {TEST_ORIGIN_LON})")
    print(f"  To:   '{TEST_DESTINATION}'")

    result = await nav.get_directions(
        start_lon=TEST_ORIGIN_LON,
        start_lat=TEST_ORIGIN_LAT,
        destination_query=TEST_DESTINATION
    )

    if "error" in result:
        print(f"\n  ❌ FAIL — {result['error']}")
        return

    print(f"\n  ✅ PASS")
    print(f"  Distance : {result['distance_text']}")
    print(f"  Duration : {result['total_time_text']}")
    print(f"  ETA      : {result['eta']}")
    print(f"  Steps    : {result['step_count']}")

    print(f"\n  --- Turn-by-Turn Instructions ---")
    for i, step in enumerate(result["steps"], 1):
        coord_str = f"({step['lat']:.6f}, {step['lon']:.6f})" if step.get("lat") else "no coords"
        print(f"  {i:2d}. [{step['distance_text']:>10}]  {step['instruction']}")
        print(f"       coords: {coord_str}")

    return result


async def main():
    print("\n🗺️  Google Maps Navigation Service Test")
    print(f"   Destination : {TEST_DESTINATION}")
    print(f"   Origin      : ({TEST_ORIGIN_LAT}, {TEST_ORIGIN_LON})")

    # Test 1: Places API
    coords = await test_places_api()
    if not coords:
        print("\n⛔ Stopping — Places API failed. Fix API key/permissions first.")
        return

    # Test 2: Directions API
    await test_directions_api()

    print("\n" + "=" * 60)
    print("✅ All tests complete")
    print("=" * 60)


if __name__ == "__main__":
    asyncio.run(main())
