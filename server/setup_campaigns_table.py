#!/usr/bin/env python3
"""Create the campaigns table in Supabase."""
import os, sys
from pathlib import Path
from dotenv import load_dotenv
load_dotenv(Path(__file__).parent / '.env')

from supabase import create_client

url = os.environ.get('SUPABASE_URL', '')
key = os.environ.get('SUPABASE_SERVICE_ROLE_KEY', '')
if not url or not key:
    print("ERROR: SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY not set")
    sys.exit(1)

sb = create_client(url, key)

# Check if table already exists
try:
    res = sb.table('campaigns').select('id').limit(1).execute()
    print(f"campaigns table already exists ({len(res.data)} rows)")
    sys.exit(0)
except Exception as e:
    print(f"Table not found, will create: {e}")

# Create via PostgREST is not possible — print SQL for Supabase Dashboard
SQL = """
create table if not exists public.campaigns (
  id          text primary key,
  name        text not null default '',
  market      text not null default 'egypt',
  budget      double precision default 0,
  start_date  text default null,
  created_at  text not null default '',
  updated_at  text not null default ''
);

create index if not exists idx_campaigns_market on public.campaigns(market);

alter table public.campaigns enable row level security;

create policy "Campaigns full access for authenticated"
  on public.campaigns for all to authenticated
  using (true) with check (true);

create policy "Service role full access on campaigns"
  on public.campaigns for all to service_role
  using (true) with check (true);
"""

# Try management API
import httpx
project_ref = url.replace("https://", "").split(".")[0]
mgmt_url = f"https://api.supabase.com/v1/projects/{project_ref}/database/query"
resp = httpx.post(
    mgmt_url,
    headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"},
    json={"query": SQL},
    timeout=30,
)
if resp.status_code in (200, 201):
    print("campaigns table created successfully via API")
else:
    print(f"API returned {resp.status_code}")
    print("\nPlease run this SQL in Supabase Dashboard > SQL Editor:")
    print("=" * 60)
    print(SQL)
    print("=" * 60)
