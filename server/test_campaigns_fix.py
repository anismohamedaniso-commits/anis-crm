#!/usr/bin/env python3
"""Test that campaign CRUD works with the auto-detected columns fix."""
import os, warnings, sys
warnings.filterwarnings('ignore')
from pathlib import Path
from dotenv import load_dotenv
load_dotenv(Path(__file__).parent / '.env')
from supabase import create_client

url = os.environ['SUPABASE_URL']
key = os.environ['SUPABASE_SERVICE_ROLE_KEY']
sb = create_client(url, key)

print('Testing leads table probe...')
try:
    res = sb.table('leads').select('id').limit(1).execute()
    print(f'  leads probe OK: {len(res.data)} rows')
except Exception as e:
    print(f'  leads probe FAILED: {e}')

print('Testing campaigns table probe...')
try:
    res = sb.table('campaigns').select('*').limit(1).execute()
    if res.data:
        print(f'  campaigns probe OK: cols = {sorted(res.data[0].keys())}')
    else:
        print('  campaigns table empty, testing insert...')
except Exception as e:
    print(f'  campaigns probe FAILED: {e}')
    sys.exit(1)

# Test insert with ONLY the columns that exist in the table
print('Testing insert with basic columns...')
try:
    res = sb.table('campaigns').insert({
        'id': '__probe_test__',
        'name': 'Probe Test',
        'market': 'egypt',
        'budget': 100.0,
        'start_date': '2026-03-10',
        'created_at': '2026-03-10T00:00:00Z',
        'updated_at': '2026-03-10T00:00:00Z',
    }).execute()
    print(f'  INSERT OK: cols = {sorted(res.data[0].keys())}')
    sb.table('campaigns').delete().eq('id', '__probe_test__').execute()
    print('  CLEANUP OK')
except Exception as e:
    print(f'  INSERT FAILED: {e}')

# Now test via CrmDatabase with auto-detection
print()
print('Testing via CrmDatabase (with auto-detect fix)...')
from db import CrmDatabase
db = CrmDatabase(supabase_admin=sb)
print(f'  using_db = {db.using_db}')
print(f'  campaigns_use_db = {db._campaigns_use_db()}')

if db._campaigns_use_db():
    try:
        c = db.create_campaign({
            'name': 'Auto-detect Test',
            'description': 'Should be stripped if col missing',
            'market': 'egypt',
            'budget': 250.0,
            'status': 'active',
            'start_date': '2026-03-10',
            'end_date': '2026-04-10',
        })
        print(f'  CREATE OK: id={c["id"]}, name={c["name"]}')
        
        # Read it back
        fetched = db.get_campaign(c['id'])
        print(f'  FETCH OK: {fetched is not None}')
        
        # List all
        all_c = db.get_campaigns()
        print(f'  LIST OK: {len(all_c)} campaigns')
        
        # Delete
        db.delete_campaign(c['id'])
        print(f'  DELETE OK')
    except Exception as e:
        print(f'  FAILED: {e}')
else:
    print('  Supabase DB not active, skipping CRUD test')
