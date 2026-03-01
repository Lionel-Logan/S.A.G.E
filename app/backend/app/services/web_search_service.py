"""
Web Search Service - Integrates Google Custom Search API for real-time information.
Uses API Key authentication (not service account - Custom Search API doesn't support it).
"""

from typing import List, Dict, Optional
from datetime import datetime, timedelta
from googleapiclient.discovery import build
from app.config import settings
import logging

logger = logging.getLogger(__name__)

class WebSearchService:
    """
    Service for real-time web search using Google Custom Search API.
    Uses API Key authentication (Custom Search API requirement).
    """
    
    def __init__(self):
        """Initialize Google Custom Search service with API Key."""
        print("\n" + "="*60)
        print("🔍 WebSearchService Initialization")
        print("="*60)
        
        self.api_key = settings.GOOGLE_SEARCH_API_KEY
        self.search_engine_id = settings.GOOGLE_SEARCH_ENGINE_ID
        
        print(f"API Key: {self.api_key[:10]}***" if self.api_key else "API Key: NOT SET")
        print(f"Search Engine ID: {self.search_engine_id}")
        
        # Build the search service using API Key
        try:
            print(f"Building Custom Search client with API Key...")
            self.service = build(
                'customsearch', 'v1',
                developerKey=self.api_key,
                static_discovery=False
            )
            print(f"✅ Google Custom Search Service initialized with API Key")
            print(f"   Search Engine ID: {self.search_engine_id}")
            logger.info(f"✅ Google Custom Search Service initialized with API Key")
        except Exception as e:
            print(f"❌ Failed to initialize Google Custom Search: {type(e).__name__}: {e}")
            import traceback
            traceback.print_exc()
            logger.error(f"Failed to initialize Google Custom Search: {e}")
            self.service = None
        
        # Simple in-memory cache for search results
        self.cache: Dict[str, Dict] = {}
        self.cache_ttl = settings.WEB_SEARCH_CACHE_TTL
        print("="*60 + "\n")
    
    def _is_cache_valid(self, cached_item: Dict) -> bool:
        """Check if cached item is still valid."""
        if "timestamp" not in cached_item:
            return False
        elapsed = (datetime.utcnow() - cached_item["timestamp"]).total_seconds()
        return elapsed < self.cache_ttl
    
    async def search(self, query: str, num_results: int = 5) -> List[Dict]:
        """
        Search for query and return formatted results.
        
        Args:
            query: Search query string
            num_results: Number of results to return (default 5)
        
        Returns:
            List of dicts with keys: title, snippet, url, published_date
        """
        try:
            print(f"\n🔍 [WebSearch] Searching for: {query}")
            logger.info(f"🔍 Searching for: {query}")
            
            # Check cache first
            if query in self.cache and self._is_cache_valid(self.cache[query]):
                print(f"📦 [WebSearch] Cache hit for query: {query}")
                logger.info(f"Cache hit for query: {query}")
                return self.cache[query]["results"]
            
            if not self.service:
                print(f"❌ [WebSearch] Search service not initialized!")
                logger.warning("Search service not initialized, returning empty results")
                return []
            
            # Execute search
            print(f"🔄 [WebSearch] Calling Google Custom Search API")
            logger.info(f"Calling Google Custom Search API for: {query}")
            result = self.service.cse().list(
                q=query,
                cx=self.search_engine_id,
                num=num_results,
                safe='active'  # Filter adult content
            ).execute()
            
            print(f"✅ [WebSearch] API call successful, processing results")
            
            # Parse and format results
            formatted_results = []
            if 'items' in result:
                print(f"📄 [WebSearch] Found {len(result['items'])} items in search results")
                for i, item in enumerate(result['items'], 1):
                    formatted_item = {
                        'title': item.get('title', 'No title'),
                        'snippet': item.get('snippet', 'No snippet'),
                        'url': item.get('link', ''),
                        'published_date': item.get('pagemap', {}).get('metatags', [{}])[0].get('article:published_time', 'N/A')
                    }
                    formatted_results.append(formatted_item)
                    print(f"  {i}. {formatted_item['title'][:60]}...")
            else:
                print(f"⚠️ [WebSearch] No 'items' key in search results. Raw response keys: {result.keys()}")
            
            # Cache the results
            self.cache[query] = {
                "results": formatted_results,
                "timestamp": datetime.utcnow()
            }
            
            print(f"✅ [WebSearch] Found {len(formatted_results)} results for: {query}\n")
            logger.info(f"Found {len(formatted_results)} results for: {query}")
            return formatted_results
        
        except Exception as e:
            print(f"❌ [WebSearch] ERROR: {type(e).__name__}: {str(e)}")
            logger.error(f"Search error: {type(e).__name__}: {str(e)}", exc_info=True)
            import traceback
            print(traceback.format_exc())
            return []
    
    def format_results_for_prompt(self, results: List[Dict]) -> str:
        """
        Format search results into a string suitable for Gemini prompt.
        
        Args:
            results: List of search result dicts
        
        Returns:
            Formatted string with sources
        """
        if not results:
            return "No search results found."
        
        formatted = "Recent sources:\n"
        for i, result in enumerate(results, 1):
            date_str = f" ({result['published_date']})" if result['published_date'] != 'N/A' else ""
            formatted += f"{i}. {result['title']}{date_str}\n"
            formatted += f"   URL: {result['url']}\n"
            formatted += f"   Snippet: {result['snippet']}\n\n"
        
        return formatted
    
    def clear_cache(self):
        """Clear all cached search results."""
        self.cache.clear()
        logger.info("Search cache cleared")


# Singleton instance
_web_search_service = None

def get_web_search_service() -> WebSearchService:
    """Get or create singleton instance of WebSearchService."""
    global _web_search_service
    if _web_search_service is None:
        _web_search_service = WebSearchService()
    return _web_search_service
