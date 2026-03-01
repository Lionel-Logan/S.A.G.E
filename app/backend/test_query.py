import requests
import json

# Test query with TODAY keyword (should trigger web search)
query = 'What date is today'
data = {'query': query}

print('\n' + '='*70)
print('🧪 Testing Web Search Functionality')
print('='*70)
print(f'Query: {query}')
print(f'Expected: Web search should be triggered (temporal keyword)')
print('='*70 + '\n')

try:
    response = requests.post('http://localhost:8000/api/v1/assistant/ask', json=data, timeout=60)
    result = response.json()
    
    print(f'\n✅ Response received:')
    print(f'\nAnswer: {result["response_text"]}')
    print(f'\nAction Type: {result["action_type"]}')
    print('\n' + '='*70)
    
except Exception as e:
    print(f'❌ Error: {e}')
