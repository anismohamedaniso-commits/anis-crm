#!/usr/bin/env python3
"""
One-time setup script: creates profiles table + first admin user in Supabase.
Run from the server directory with the venv activated:
    python setup_auth.py
"""

import json
import os
import sys
from pathlib import Path
try:
    from dotenv import load_dotenv
    load_dotenv(Path(__file__).resolve().parent / '.env')
except ImportError:
    pass  # dotenv not installed — rely on env vars being set

import requests
from supabase import create_client

# ── Config (from environment) ──
SUPABASE_URL = os.environ.get('SUPABASE_URL', '')
SERVICE_ROLE_KEY = os.environ.get('SUPABASE_SERVICE_ROLE_KEY', '')

ADMIN_EMAIL = os.environ.get('ADMIN_EMAIL', 'anis@tickandtalk.com')
ADMIN_PASSWORD = os.environ.get('ADMIN_PASSWORD', '')
ADMIN_NAME = os.environ.get('ADMIN_NAME', 'Anis Arafa')

if not SUPABASE_URL or not SERVICE_ROLE_KEY or not ADMIN_PASSWORD:
    print('ERROR: Set SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, and ADMIN_PASSWORD in server/.env')
    sys.exit(1)

PROFILES_SQL = """
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null,
  email text not null,
  role text not null default 'campaign_executive'
    check (role in ('account_executive', 'campaign_executive')),
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

drop policy if exists "Profiles are viewable by authenticated users" on public.profiles;
create policy "Profiles are viewable by authenticated users"
  on public.profiles for select
  to authenticated
  using (true);

drop policy if exists "Users can update own profile" on public.profiles;
create policy "Users can update own profile"
  on public.profiles for update
  to authenticated
  using (id = auth.uid());
"""

TRIGGER_SQL = """
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, name, email, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'name', split_part(new.email, '@', 1)),
    new.email,
    coalesce(new.raw_user_meta_data->>'role', 'campaign_executive')
  );
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
"""


def run_sql_via_rpc(sql: str, label: str) -> bool:
    """Try running SQL via the Supabase REST API (service_role bypasses RLS)."""
    headers = {
        "apikey": SERVICE_ROLE_KEY,
        "Authorization": f"Bearer {SERVICE_ROLE_KEY}",
        "Content-Type": "application/json",
    }
    # Try the /sql endpoint (available on newer Supabase)
    for endpoint in ["/sql", "/pg/query"]:
        try:
            resp = requests.post(
                f"{SUPABASE_URL}{endpoint}",
                headers=headers,
                json={"query": sql},
                timeout=15,
            )
            if resp.status_code in (200, 201, 204):
                print(f"  [OK] {label} via {endpoint}")
                return True
        except Exception:
            pass
    return False


def main():
    client = create_client(SUPABASE_URL, SERVICE_ROLE_KEY)

    # ── Step 1: Create profiles table ──
    print("\n=== Step 1: Create profiles table ===")
    table_exists = False
    try:
        client.table("profiles").select("id").limit(1).execute()
        table_exists = True
        print("  [OK] profiles table already exists")
    except Exception:
        print("  Table does not exist — attempting to create...")
        created = run_sql_via_rpc(PROFILES_SQL, "profiles table")
        if created:
            table_exists = True
        else:
            print("  [WARN] Could not create table via REST API.")
            print("         Trying trigger SQL...")

    if table_exists:
        # Also try to install the trigger
        run_sql_via_rpc(TRIGGER_SQL, "auto-create trigger")

    # ── Step 2: Create admin user ──
    print("\n=== Step 2: Create admin user ===")
    user_id = None
    try:
        # Check if user already exists by listing users
        users_resp = client.auth.admin.list_users()
        existing = [u for u in users_resp if getattr(u, 'email', None) == ADMIN_EMAIL]
        if existing:
            user_id = existing[0].id
            print(f"  [OK] User {ADMIN_EMAIL} already exists (id={user_id})")
        else:
            resp = client.auth.admin.create_user({
                "email": ADMIN_EMAIL,
                "password": ADMIN_PASSWORD,
                "email_confirm": True,
                "user_metadata": {
                    "name": ADMIN_NAME,
                    "role": "account_executive",
                },
            })
            user_id = resp.user.id
            print(f"  [OK] Created user {ADMIN_EMAIL} (id={user_id})")
    except Exception as e:
        print(f"  [ERROR] Failed to create user: {e}")

    # ── Step 3: Insert profile row ──
    if user_id and table_exists:
        print("\n=== Step 3: Insert profile row ===")
        try:
            # Check if profile exists
            existing_profile = (
                client.table("profiles")
                .select("id")
                .eq("id", str(user_id))
                .maybe_single()
                .execute()
            )
            if existing_profile.data:
                # Update role to account_executive
                client.table("profiles").update({
                    "role": "account_executive",
                    "name": ADMIN_NAME,
                }).eq("id", str(user_id)).execute()
                print(f"  [OK] Profile already exists — updated role to account_executive")
            else:
                client.table("profiles").insert({
                    "id": str(user_id),
                    "name": ADMIN_NAME,
                    "email": ADMIN_EMAIL,
                    "role": "account_executive",
                }).execute()
                print(f"  [OK] Profile row created for {ADMIN_EMAIL}")
        except Exception as e:
            print(f"  [WARN] Could not insert profile row: {e}")
            if not table_exists:
                print("  (This is expected — the profiles table could not be created)")
    elif user_id and not table_exists:
        print("\n=== Step 3: ⚠️  MANUAL ACTION NEEDED ===")
        print("  The profiles table does not exist yet.")
        print("  Please go to your Supabase Dashboard → SQL Editor")
        print("  and paste the SQL from lib/supabase/supabase_tables.sql")
        print("  (the profiles section only — lines 9-51)")
        print(f"\n  After that, run this script again to set up the profile for {ADMIN_EMAIL}.")

    # ── Summary ──
    print("\n=== Summary ===")
    print(f"  Admin email:    {ADMIN_EMAIL}")
    print(f"  Admin password: (value from ADMIN_PASSWORD env var)")
    if table_exists:
        print("  Profiles table: ✅ Ready")
    else:
        print("  Profiles table: ❌ Needs manual SQL (see above)")
    print(f"  User created:   {'✅' if user_id else '❌'}")
    print()


if __name__ == "__main__":
    main()
