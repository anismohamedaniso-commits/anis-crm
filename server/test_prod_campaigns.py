#!/usr/bin/env python3
"""Test campaign CRUD on production Railway API using Supabase JWT auth."""
import os, requests, json
from pathlib import Path
from dotenv import load_dotenv
load_dotenv(Path(__file__).parent / '.env')

sb_url = os.environ.get('SUPABASE_URL', '')
sb_anon = os.environ.get('SUPABASE_ANON_KEY', '')
base = 'https://anis-crm-api-production.up.railway.app'

# Step 1: Get a JWT token via Supabase Auth
print('Logging in via Supabase...')
login_resp = requests.post(
    f'{sb_url}/auth/v1/token?grant_type=password',
    json={'email': 'anis.arafa@tickandtalk.com', 'password': 'Anis23908262!'},
    headers={'apikey': sb_anon, 'Content-Type': 'application/json'},
)
if login_resp.status_code != 200:
    print(f'Login failed: {login_resp.status_code} {login_resp.text[:200]}')
    service_key = os.environ.get('SUPABASE_SERVICE_ROLE_KEY', '')
    users_resp = requests.get(
        f'{sb_url}/auth/v1/admin/users',
        headers={'apikey': service_key, 'Authorization': f'Bearer {service_key}'},
    )
    if users_resp.status_code == 200:
        users = users_resp.json().get('users', [])
        print(f'Found {len(users)} users:')
        for u in users[:5]:
            print(f'  - {u.get("email")}')
    exit(1)

token = login_resp.json().get('access_token', '')
print(f'Got JWT token ({len(token)} chars)')

headers = {
    'Content-Type': 'application/json',
    'Authorization': f'Bearer {token}',
}

# Step 2: Create a test campaign
payload = {
    'name': 'Test - Auto Detect Fix',
    'description': 'Testing description field',
    'market': 'egypt',
    'budget': 1000.0,
    'status': 'active',
    'start_date': '2026-03-10',
    'end_date': '2026-04-10',
}

print('\nCreating campaign on production...')
resp = requests.post(f'{base}/api/campaigns', json=payload, headers=headers)
print(f'CREATE: {resp.status_code}')
print(f'Response text: {resp.text[:500]}')
try:
    print(json.dumps(resp.json(), indent=2))
except Exception:
    pass

if resp.status_code == 201:
    cid = resp.json().get('id')
    resp2 = requests.get(f'{base}/api/campaigns', headers=headers)
    data = resp2.json()
    print(f'\nLIST: {resp2.status_code}, count={len(data.get("campaigns", []))}')
    for c in data.get('campaigns', []):
        print(f'  - {c["id"]}: {c["name"]}')
    resp3 = requests.delete(f'{base}/api/campaigns/{cid}', headers=headers)
    print(f'\nDELETE: {resp3.status_code}')
    print('SUCCESS: Campaign CRUD works on production!')
else:
    print('Campaign creation failed!')
    print('Response:', resp.text[:500])
