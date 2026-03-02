"""
Comprehensive test for Web Search Workflow in ASSISTANT module.
Tests:
1. Web Search Service API calls
2. Intent Router's 3-layer detection
3. Full Assistant endpoint with web search
"""

import asyncio
import json
from unittest.mock import patch, AsyncMock, MagicMock
from app.services.web_search_service import get_web_search_service
from app.services.intent_router import IntentRouter
from app.api.v1.assistant import ask_assistant, AssistantRequest


# ====================== TEST 1: Web Search Service ======================
async def test_web_search_service_api_call():
    """Test if Web Search Service makes actual API calls"""
    print("\n" + "="*70)
    print("TEST 1: Web Search Service API Call")
    print("="*70)
    
    service = get_web_search_service()
    query = "What is today's date"
    
    print(f"\n🔍 Testing query: '{query}'")
    print(f"   SerpAPI Key configured: {bool(service.api_key)}")
    print(f"   Legacy Search Engine ID configured: {bool(service.search_engine_id)}")
    print(f"   Service initialized: {service.service is not None}")
    
    if not service.service:
        print("\n❌ ERROR: Web Search Service not properly initialized!")
        print("   → Check SERPAPI_API_KEY in .env")
        return False
    
    try:
        results = await service.search(query, num_results=5)
        
        if results:
            print(f"\n✅ API CALL SUCCESSFUL - {len(results)} results returned")
            print(f"\n   Top Result:")
            print(f"   Title: {results[0]['title']}")
            print(f"   URL: {results[0]['url']}")
            print(f"   Snippet: {results[0]['snippet'][:100]}...")
            return True
        else:
            print(f"\n⚠️  API called but no results returned")
            return False
            
    except Exception as e:
        print(f"\n❌ API CALL FAILED: {type(e).__name__}: {e}")
        return False


# ====================== TEST 2: Intent Router Detection ======================
async def test_web_search_detection():
    """Test 3-layer detection for web search necessity"""
    print("\n" + "="*70)
    print("TEST 2: Web Search Detection (3-Layer)")
    print("="*70)
    
    intent_router = IntentRouter()
    
    test_queries = [
        # Should trigger via Layer 1 (Temporal)
        ("What is today's weather", True, "Layer 1: Temporal keyword 'today'"),
        ("What are the latest news", True, "Layer 1: Temporal keyword 'latest'"),
        ("Today's cryptocurrency prices", True, "Layer 1: Temporal keyword 'Today's'"),
        
        # Should trigger via Layer 2 (Position)
        ("Who is the current CEO of Apple", True, "Layer 2: Position keyword 'CEO'"),
        ("Who is the president right now", True, "Layer 2: Position keyword 'president'"),
        
        # Should require Layer 3 (Gemini decision)
        ("How do I make pasta", False, "Layer 3: General knowledge - no search needed"),
        ("What is Python programming", False, "Layer 3: General knowledge - Gemini handles it"),
        ("Tell me a joke", False, "Layer 3: Creative - no search needed"),
    ]
    
    results = []
    for query, expected_search, reason in test_queries:
        print(f"\n📝 Query: '{query}'")
        print(f"   Expected: {'Web Search' if expected_search else 'Direct Gemini'}")
        
        needs_search = await intent_router.needs_web_search(query)
        
        status = "✅" if needs_search == expected_search else "⚠️ "
        print(f"   Result: {status} {'Web Search' if needs_search else 'Direct Gemini'}")
        print(f"   Reason: {reason}")
        
        results.append({
            "query": query,
            "expected": expected_search,
            "actual": needs_search,
            "passed": needs_search == expected_search
        })
    
    passed = sum(1 for r in results if r["passed"])
    print(f"\n\n📊 Detection Results: {passed}/{len(results)} passed")
    
    return all(r["passed"] for r in results)


# ====================== TEST 3: Mocked Assistant Endpoint ======================
async def test_assistant_with_mocked_search():
    """Test full assistant endpoint with mocked web search"""
    print("\n" + "="*70)
    print("TEST 3: Assistant Endpoint with Mocked Web Search")
    print("="*70)
    
    # Mock web search results
    mock_search_results = [
        {
            "title": "Today's Date - Current Date",
            "url": "https://example.com/today",
            "snippet": "Today's date is March 1, 2026. Check current date and time."
        },
        {
            "title": "What is Today's Date?",
            "url": "https://example.com/date",
            "snippet": "The current date and time information for March 1, 2026."
        }
    ]
    
    request = AssistantRequest(
        query="What is today's date",
        user_id="test_user",
        lat=None,
        lon=None
    )
    
    print(f"\n📝 Request Query: '{request.query}'")
    print(f"   User ID: {request.user_id}")
    
    try:
        with patch('app.api.v1.assistant.web_search_service.search', 
                   new_callable=AsyncMock) as mock_search, \
             patch('app.api.v1.assistant.gemini_service.ask_with_search',
                   new_callable=AsyncMock) as mock_ask_search, \
             patch('app.api.v1.assistant._send_to_tts',
                   new_callable=AsyncMock):
            
            # Setup mocks
            mock_search.return_value = mock_search_results
            mock_ask_search.return_value = f"Based on search results, today is March 1, 2026."
            
            # Call assistant
            response = await ask_assistant(request)
            
            # Verify mocks were called
            if mock_search.called:
                print(f"\n✅ Web Search API was CALLED")
                print(f"   Called with query: '{mock_search.call_args[0][0]}'")
                print(f"   Num results requested: {mock_search.call_args[1].get('num_results', 5)}")
            else:
                print(f"\n❌ Web Search API was NOT called")
                return False
            
            if mock_ask_search.called:
                print(f"\n✅ Gemini with_search was CALLED")
                print(f"   Response: {response.response_text[:100]}...")
            else:
                print(f"\n⚠️  Gemini with_search was not called")
            
            print(f"\n📤 Response Type: {response.action_type}")
            print(f"   Status Code: 200")
            
            return True
            
    except Exception as e:
        print(f"\n❌ ERROR: {type(e).__name__}: {e}")
        import traceback
        traceback.print_exc()
        return False


# ====================== TEST 4: API Configuration Check ======================
def test_api_configuration():
    """Verify API credentials are configured"""
    print("\n" + "="*70)
    print("TEST 4: API Configuration Check")
    print("="*70)
    
    from app.config import settings
    
    print(f"\n🔐 SerpAPI Configuration for Web Search:")
    print(f"   SERPAPI_API_KEY set: {bool(settings.SERPAPI_API_KEY)}")
    if settings.SERPAPI_API_KEY:
        key_preview = settings.SERPAPI_API_KEY[:20] + "..." if len(settings.SERPAPI_API_KEY) > 20 else settings.SERPAPI_API_KEY
        print(f"   SERPAPI_API_KEY preview: {key_preview}")
    
    # Legacy values are printed only for information
    print(f"   Legacy GOOGLE_SEARCH_API_KEY set: {bool(settings.GOOGLE_SEARCH_API_KEY)}")
    print(f"   Legacy GOOGLE_SEARCH_ENGINE_ID set: {bool(settings.GOOGLE_SEARCH_ENGINE_ID)}")
    
    if not settings.SERPAPI_API_KEY:
        print(f"\n⚠️  MISSING CONFIGURATION!")
        print(f"   Add to your .env file:")
        print(f"   SERPAPI_API_KEY=your_serpapi_key")
        return False
    
    print(f"\n✅ Configuration is complete")
    return True


# ====================== MAIN TEST RUNNER ======================
async def run_all_tests():
    """Run all tests in sequence"""
    print("\n\n")
    print("╔" + "="*68 + "╗")
    print("║" + " "*15 + "WEB SEARCH WORKFLOW TEST SUITE" + " "*23 + "║")
    print("╚" + "="*68 + "╝")
    
    results = {}
    
    # Test 4: Configuration (doesn't need async)
    results["API Configuration"] = test_api_configuration()
    
    if not results["API Configuration"]:
        print("\n❌ Cannot proceed - API not configured. Set credentials and try again.")
        return results
    
    # Test 1: Service API Call
    results["Web Search Service"] = await test_web_search_service_api_call()
    
    # Test 2: Detection Logic
    results["Web Search Detection"] = await test_web_search_detection()
    
    # Test 3: Assistant Endpoint
    results["Assistant Endpoint"] = await test_assistant_with_mocked_search()
    
    # Summary
    print("\n\n" + "╔" + "="*68 + "╗")
    print("║" + " "*20 + "TEST SUMMARY" + " "*36 + "║")
    print("╠" + "="*68 + "╣")
    
    for test_name, passed in results.items():
        status = "✅ PASSED" if passed else "❌ FAILED"
        print(f"║ {test_name:<35} {status:<30} ║")
    
    print("╚" + "="*68 + "╝")
    
    all_passed = all(results.values())
    print(f"\n{'🎉 ALL TESTS PASSED!' if all_passed else '⚠️  SOME TESTS FAILED'}\n")
    
    return results


if __name__ == "__main__":
    asyncio.run(run_all_tests())
