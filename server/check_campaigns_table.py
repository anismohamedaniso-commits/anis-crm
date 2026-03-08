#!/usr/bin/env python3
"""Quick check: does the campaigns table exist in Supabase?"""
import os, sys
from pathlib import Path
from dotenv import load_dotenv
load_dotenv(Path(__file__).parent / '.env')

from supabase import create_client

url = os.environ.get('SUPABASE_URL', '')
key = os.environ.get('SUPABASE_SERVICE_ROLE_KEY', '')
sb = create_client(url, key)

try:
    sb.table('campaigns').insert({
        'id': '__probe__',
        'name': 'probe',
        'created_at': '',
        'updated_at': ''
    }).execute()
    sb.table('campaigns').delete().eq('id', '__probe__').execute()
    print('OK: campaigns table exists and is writable')
except Exception as e:
    msg = str(e)
    if 'PGRST205' in msg or 'could not find' in msg.lower():
        print('MISSING: campaigns table does not exist')
        print('Run this SQL in Supabase Dashboard > SQL Editor:')
        print("""
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
create policy "Campaigns full access for authenticated" on public.campaigns for all to authenticated using (true) with check (true);
create policy "Service role full access on campaigns" on public.campaigns for all to service_role using (true) with check (true);
""")
    else:
        print(f'ERROR: {e}')
