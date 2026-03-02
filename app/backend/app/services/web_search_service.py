"""
Web Search Service - Integrates SerpAPI (Google Search engine) for real-time information.
Uses API Key authentication via SerpAPI; no Google Custom Search client is used anymore.
"""

from typing import List, Dict
from datetime import datetime
import logging

import httpx

from app.config import settings

logger = logging.getLogger(__name__)


class WebSearchService:
    """Service for real-time web search using SerpAPI (Google Search)."""

    def __init__(self):
        """Initialize SerpAPI configuration for web search."""
        print("\n" + "=" * 60)
        print("🔍 WebSearchService Initialization (SerpAPI)")
        print("=" * 60)

        # SerpAPI configuration
        self.api_key = settings.SERPAPI_API_KEY
        # Keep legacy attribute for compatibility with existing tests/prints
        self.search_engine_id = settings.GOOGLE_SEARCH_ENGINE_ID
        self.base_url = "https://serpapi.com/search"

        if self.api_key:
            print(f"SerpAPI Key: {self.api_key[:10]}***")
        else:
            print("SerpAPI Key: NOT SET")

        print(f"Legacy Google Search Engine ID (unused): {self.search_engine_id}")

        # In the old implementation, `service` was a Google API client.
        # Here we just use it as a simple flag so existing checks continue to work.
        if self.api_key:
            self.service = True
            print("✅ SerpAPI web search client configured")
            logger.info("✅ SerpAPI web search client configured")
        else:
            self.service = None
            print("❌ SerpAPI API key not configured; web search disabled")
            logger.warning("SerpAPI API key not configured; web search disabled")

        # Simple in-memory cache for search results
        self.cache: Dict[str, Dict] = {}
        self.cache_ttl = settings.WEB_SEARCH_CACHE_TTL
        print("=" * 60 + "\n")
    
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
                print(f"❌ [WebSearch] Search service not initialized (missing SerpAPI key)!")
                logger.warning("Search service not initialized, returning empty results")
                return []

            # Execute search via SerpAPI
            print(f"🔄 [WebSearch] Calling SerpAPI (engine=google)")
            logger.info(f"Calling SerpAPI for: {query}")

            async with httpx.AsyncClient(timeout=20.0) as client:
                response = await client.get(
                    self.base_url,
                    params={
                        "engine": "google",
                        "q": query,
                        "api_key": self.api_key,
                        "num": num_results,
                        "safe": "active",
                    },
                )
                response.raise_for_status()
                result = response.json()

            print(f"✅ [WebSearch] API call successful, processing results")

            # Parse and format results
            formatted_results: List[Dict] = []

            # Prefer organic_results from SerpAPI
            organic_results = result.get("organic_results") or []
            if organic_results:
                print(f"📄 [WebSearch] Found {len(organic_results)} organic results")
                for i, item in enumerate(organic_results[:num_results], 1):
                    formatted_item = {
                        "title": item.get("title", "No title"),
                        "snippet": item.get("snippet", "No snippet"),
                        "url": item.get("link", ""),
                        # SerpAPI often provides a 'date' field; fall back to 'N/A' if missing
                        "published_date": item.get("date", "N/A"),
                    }
                    formatted_results.append(formatted_item)
                    print(f"  {i}. {formatted_item['title'][:60]}...")
            else:
                print(
                    f"⚠️ [WebSearch] No 'organic_results' key in search results. "
                    f"Raw response keys: {list(result.keys())}"
                )
            
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
