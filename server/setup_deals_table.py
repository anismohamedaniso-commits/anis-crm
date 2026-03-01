#!/usr/bin/env python3
"""Create the deals table in Supabase if it doesn't exist."""

import os
import requests
from dotenv import load_dotenv

load_dotenv()

SUPABASE_URL = os.environ.get('SUPABASE_URL', '')
SERVICE_ROLE_KEY = os.environ.get('SUPABASE_SERVICE_ROLE_KEY', '')

DEALS_SQL = """
create table if not exists public.deals (
  id text primary key,
  title text not null default '',
  lead_id text not null default '',
  lead_name text not null default '',
  stage text not null default 'unfinished',
  value double precision not null default 0,
  currency text not null default 'EGP',
  expected_close_date text default '',
  owner_id text not null default '',
  owner_name text not null default '',
  notes text default '',
  created_at text not null default '',
  updated_at text not null default ''
);

create index if not exists idx_deals_lead_id on public.deals(lead_id);
create index if not exists idx_deals_stage on public.deals(stage);

alter table public.deals enable row level security;

drop policy if exists "Deals full access for authenticated" on public.deals;
create policy "Deals full access for authenticated"
  on public.deals for all
  to authenticated
  using (true)
  with check (true);

drop policy if exists "Service role full access on deals" on public.deals;
create policy "Service role full access on deals"
  on public.deals for all
  to service_role
  using (true)
  with check (true);
"""


def main():
    if not SUPABASE_URL or not SERVICE_ROLE_KEY:
        print("ERROR: SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY not set in .env")
        return

    # First check if table already exists via postgrest
    try:
        from supabase import create_client
        sb = create_client(SUPABASE_URL, SERVICE_ROLE_KEY)
        sb.table("deals").select("id").limit(1).execute()
        print("deals table already exists!")
        return
    except Exception:
        print("deals table does not exist yet - creating...")

    headers = {
        "apikey": SERVICE_ROLE_KEY,
        "Authorization": "Bearer " + SERVICE_ROLE_KEY,
        "Content-Type": "application/json",
    }

    # Try creating via SQL endpoint
    for endpoint in ["/sql", "/pg/query"]:
        try:
            resp = requests.post(
                SUPABASE_URL + endpoint,
                headers=headers,
                json={"query": DEALS_SQL},
                timeout=15,
            )
            if resp.status_code in (200, 201, 204):
                print("SUCCESS: deals table created via " + endpoint)
                return
            else:
                print("  " + endpoint + ": status=" + str(resp.status_code))
        except Exception as e:
            print("  " + endpoint + ": error - " + str(e))

    # Try direct Postgres connection
    print("REST API endpoints not available. Trying direct Postgres...")
    try:
        import psycopg2
    except ImportError:
        print("psycopg2 not installed. Cannot connect directly.")
        print("Please run the SQL in Supabase Dashboard > SQL Editor.")
        return

    ref = SUPABASE_URL.replace("https://", "").split(".")[0]
    db_password = os.environ.get("SUPABASE_DB_PASSWORD", "")

    if not db_password:
        print("Set SUPABASE_DB_PASSWORD env var for direct DB connection.")
        candidates = []
    else:
        candidates = [db_password]

    # Try multiple region patterns for pooler
    regions = [
        "eu-central-1", "us-east-1", "us-west-1", "ap-southeast-1",
        "eu-west-1", "eu-west-2", "ap-northeast-1",
    ]
    hosts = [("db." + ref + ".supabase.co", 5432, "postgres")]
    for region in regions:
        hosts.append(("aws-0-" + region + ".pooler.supabase.com", 6543, "postgres." + ref))
        hosts.append(("aws-0-" + region + ".pooler.supabase.com", 5432, "postgres." + ref))

    for host, port, user in hosts:
        for pwd in candidates:
            try:
                conn = psycopg2.connect(
                    host=host, port=port, user=user,
                    password=pwd, dbname="postgres",
                    connect_timeout=5
                )
                conn.autocommit = True
                cur = conn.cursor()
                cur.execute(DEALS_SQL)
                cur.close()
                conn.close()
                print("SUCCESS: deals table created via direct Postgres!")
                print("  host=" + host + " port=" + str(port) + " user=" + user)
                return
            except Exception as e:
                msg = str(e).strip().split("\n")[0]
                print("  " + host + ":" + str(port) + " user=" + user + " -> " + msg)

    print("")
    print("Could not create table automatically.")
    print("Please run the SQL in Supabase Dashboard > SQL Editor.")
    print("The SQL is in: lib/supabase/supabase_tables.sql (deals section)")


if __name__ == "__main__":
    main()


if __name__ == "__main__":
    main()
