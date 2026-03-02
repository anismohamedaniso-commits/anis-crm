#!/usr/bin/env python3
"""
Create all required Supabase tables for Anis CRM.
Run from server/ directory:  python setup_supabase_tables.py
"""

import os
import sys
from pathlib import Path
from dotenv import load_dotenv

load_dotenv(Path(__file__).parent / '.env')

SUPABASE_URL     = os.environ.get('SUPABASE_URL', '')
SERVICE_ROLE_KEY = os.environ.get('SUPABASE_SERVICE_ROLE_KEY', '')

SQL = """
-- ── LEADS ────────────────────────────────────────────────────────────────────
create table if not exists public.leads (
  id                 text primary key,
  name               text not null default '',
  phone              text default null,
  email              text default null,
  status             text not null default 'fresh',
  source             text not null default 'imported',
  campaign           text default null,
  deal_value         double precision default 0,
  assigned_to        text default null,
  assigned_to_name   text default null,
  tags               text[] default '{}',
  created_at         text not null default '',
  updated_at         text not null default '',
  last_contacted_at  text default null,
  next_followup_at   text default null
);

create index if not exists idx_leads_status     on public.leads(status);
create index if not exists idx_leads_source     on public.leads(source);
create index if not exists idx_leads_created_at on public.leads(created_at);

alter table public.leads enable row level security;

drop policy if exists "Leads full access for authenticated" on public.leads;
create policy "Leads full access for authenticated"
  on public.leads for all to authenticated
  using (true) with check (true);

drop policy if exists "Service role full access on leads" on public.leads;
create policy "Service role full access on leads"
  on public.leads for all to service_role
  using (true) with check (true);

-- ── ACTIVITIES / NOTES ───────────────────────────────────────────────────────
create table if not exists public.activities (
  id       text primary key,
  lead_id  text not null,
  type     text not null default 'note',
  body     text default '',
  ts       text not null default '',
  author   text default null,
  notes    text default '',
  outcome  text default '',
  user_id  text default null
);

-- Add columns if table already exists (idempotent)
do $$ begin
  alter table public.activities add column if not exists notes text default '';
  alter table public.activities add column if not exists outcome text default '';
  alter table public.activities add column if not exists user_id text default null;
exception when others then null;
end $$;

create index if not exists idx_activities_lead_id on public.activities(lead_id);

alter table public.activities enable row level security;

drop policy if exists "Activities full access for authenticated" on public.activities;
create policy "Activities full access for authenticated"
  on public.activities for all to authenticated
  using (true) with check (true);

drop policy if exists "Service role full access on activities" on public.activities;
create policy "Service role full access on activities"
  on public.activities for all to service_role
  using (true) with check (true);

-- ── TASKS ────────────────────────────────────────────────────────────────────
create table if not exists public.tasks (
  id          text primary key,
  lead_id     text default null,
  title       text not null default '',
  due_date    text default null,
  assigned_to text default null,
  status      text not null default 'open',
  priority    text not null default 'medium',
  created_at  text not null default '',
  updated_at  text not null default ''
);

alter table public.tasks enable row level security;

drop policy if exists "Tasks full access for authenticated" on public.tasks;
create policy "Tasks full access for authenticated"
  on public.tasks for all to authenticated
  using (true) with check (true);

drop policy if exists "Service role full access on tasks" on public.tasks;
create policy "Service role full access on tasks"
  on public.tasks for all to service_role
  using (true) with check (true);

-- ── CUSTOM FIELDS ────────────────────────────────────────────────────────────
create table if not exists public.custom_fields (
  id          text primary key,
  name        text not null,
  field_type  text not null default 'text',
  options     jsonb default '[]'::jsonb,
  required    boolean default false,
  created_at  text not null default ''
);

alter table public.custom_fields enable row level security;

drop policy if exists "Custom fields full access for authenticated" on public.custom_fields;
create policy "Custom fields full access for authenticated"
  on public.custom_fields for all to authenticated
  using (true) with check (true);

drop policy if exists "Service role full access on custom_fields" on public.custom_fields;
create policy "Service role full access on custom_fields"
  on public.custom_fields for all to service_role
  using (true) with check (true);
"""


def run_sql(sql: str) -> bool:
    """Execute SQL via Supabase Management API."""
    import httpx

    # Extract project ref from URL: https://<ref>.supabase.co
    project_ref = SUPABASE_URL.replace("https://", "").split(".")[0]
    mgmt_url = f"https://api.supabase.com/v1/projects/{project_ref}/database/query"

    # Try management API (requires management token — may not work with service key)
    resp = httpx.post(
        mgmt_url,
        headers={"Authorization": f"Bearer {SERVICE_ROLE_KEY}", "Content-Type": "application/json"},
        json={"query": sql},
        timeout=30,
    )
    if resp.status_code in (200, 201):
        return True

    # Fallback: try via PostgREST rpc (psql)
    print(f"Management API returned {resp.status_code}: {resp.text[:200]}")
    print("\nPlease run the SQL below in Supabase Dashboard → SQL Editor:")
    print("=" * 60)
    print(sql)
    print("=" * 60)
    return False


def main():
    if not SUPABASE_URL or not SERVICE_ROLE_KEY:
        print("ERROR: SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY not set in .env")
        sys.exit(1)

    print(f"Setting up tables in: {SUPABASE_URL}")
    result = run_sql(SQL)
    if result:
        print("✅ All tables created successfully")
    else:
        print("\n⚠️  Could not auto-create via API. Copy the SQL above into Supabase SQL Editor.")


if __name__ == "__main__":
    main()
