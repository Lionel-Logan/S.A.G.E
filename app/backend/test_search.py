import asyncio
from app.services.web_search_service import get_web_search_service

async def test_search():
    service = get_web_search_service()
    query = 'What date is today'
    
    print('\n' + '='*70)
    print(f'Testing Web Search for: {query}')
    print('='*70)
    
    results = await service.search(query, num_results=3)
    
    print(f'\nResults found: {len(results)}')
    if results:
        print('\nFirst result:')
        for i, r in enumerate(results[:2], 1):
            print(f'\n{i}. Title: {r["title"]}')
            print(f'   URL: {r["url"]}')
            print(f'   Snippet: {r["snippet"][:80]}...')
    else:
        print('No results returned!')
    print('='*70)

asyncio.run(test_search())
