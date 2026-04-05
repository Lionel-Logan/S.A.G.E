"""
Quick test for principal query
"""

import asyncio
from app.services.web_search_service import get_web_search_service
from app.services.intent_router import IntentRouter
from app.api.v1.assistant import ask_assistant, AssistantRequest


async def test_principal_query():
    """Test web search for principal query"""
    
    print("\n" + "="*70)
    print("Testing: Who is the principal of model engineering college Thrikkakara?")
    print("="*70)
    
    # Test 1: Check if web search is detected
    print("\n[Step 1] Checking if query needs web search...")
    intent_router = IntentRouter()
    needs_search = await intent_router.needs_web_search("Who is the principal of model engineering college")
    print(f"Web Search Needed: {'✅ YES' if needs_search else '❌ NO'}")
    
    # Test 2: Make actual web search
    print("\n[Step 2] Making web search API call...")
    service = get_web_search_service()
    
    try:
        results = await service.search("Who is the principal of model engineering college", num_results=5)
        
        if results:
            print(f"✅ Search returned {len(results)} results\n")
            for i, result in enumerate(results, 1):
                print(f"Result {i}:")
                print(f"  Title: {result['title']}")
                print(f"  URL: {result['url']}")
                print(f"  Snippet: {result['snippet']}\n")
        else:
            print("⚠️  No results returned")
            
    except Exception as e:
        print(f"❌ Error: {type(e).__name__}: {e}")
    
    # Test 3: Test through assistant API
    print("\n" + "="*70)
    print("[Step 3] Testing through Assistant API...")
    print("="*70)
    
    try:
        request = AssistantRequest(
            query="Who is the principal of model engineering college",
            user_id="test_user"
        )
        response = await ask_assistant(request)
        
        print(f"\n✅ Assistant Response:")
        print(f"Type: {getattr(response, 'action_type', 'N/A')}")
        print(f"\nAnswer:\n{getattr(response, 'response_text', 'No response')}")
        
    except Exception as e:
        print(f"❌ Error: {type(e).__name__}: {e}")


if __name__ == "__main__":
    asyncio.run(test_principal_query())
