#!/usr/bin/env python3
"""Add missing columns (description, status, end_date) to campaigns table in Supabase."""
import os, sys
from pathlib import Path
from dotenv import load_dotenv
load_dotenv(Path(__file__).parent / '.env')

url = os.environ.get('SUPABASE_URL', '')
key = os.environ.get('SUPABASE_SERVICE_ROLE_KEY', '')
if not url or not key:
    print("ERROR: SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY not set")
    sys.exit(1)

import requests

headers = {
    'apikey': key,
    'Authorization': f'Bearer {key}',
    'Content-Type': 'application/json',
    'Prefer': 'return=representation',
}

# Use Supabase SQL API (Management API) — try the pg_net approach
# We'll use direct REST call to PostgREST rpc

statements = [
    "ALTER TABLE public.campaigns ADD COLUMN IF NOT EXISTS description text NOT NULL DEFAULT ''",
    "ALTER TABLE public.campaigns ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'active'",
    "ALTER TABLE public.campaigns ADD COLUMN IF NOT EXISTS end_date text DEFAULT NULL",
]

for sql in statements:
    resp = requests.post(
        f'{url}/rest/v1/rpc/',
        json={'query': sql},
        headers=headers,
    )
    # Try using the Supabase Management API instead
    if resp.status_code != 200:
        # PostgREST doesn't support raw SQL - need to use psycopg2 or the management API
        break
    print(f'OK: {sql[:60]}...')
else:
    print('All columns added successfully')
    sys.exit(0)

# Fallback: try via psycopg2 if available
print('PostgREST RPC not available, trying direct Postgres connection...')

db_url = os.environ.get('DATABASE_URL', '')
if not db_url:
    # Construct from Supabase URL
    # Format: postgresql://postgres.[ref]:[password]@aws-0-[region].pooler.supabase.com:6543/postgres
    print()
    print('Cannot auto-migrate. Please run this SQL in Supabase Dashboard > SQL Editor:')
    print()
    print("ALTER TABLE public.campaigns ADD COLUMN IF NOT EXISTS description text NOT NULL DEFAULT '';")
    print("ALTER TABLE public.campaigns ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'active';")
    print("ALTER TABLE public.campaigns ADD COLUMN IF NOT EXISTS end_date text DEFAULT NULL;")
    print()
    sys.exit(1)

try:
    import psycopg2
    conn = psycopg2.connect(db_url)
    conn.autocommit = True
    cur = conn.cursor()
    for sql in statements:
        cur.execute(sql)
        print(f'OK: {sql[:60]}...')
    cur.close()
    conn.close()
    print('All columns added successfully')
except ImportError:
    print('psycopg2 not available. Please run the SQL manually in Supabase Dashboard.')
except Exception as e:
    print(f'ERROR: {e}')
    sys.exit(1)
