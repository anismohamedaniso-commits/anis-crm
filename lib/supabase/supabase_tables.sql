-- Initial Supabase schema for WhatsApp messaging

create extension if not exists pgcrypto;

-- ═══════════════════════════════════════════════════════
-- USER PROFILES (linked to Supabase Auth)
-- ═══════════════════════════════════════════════════════
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null,
  email text not null,
  role text not null default 'campaign_executive'
    check (role in ('account_executive', 'campaign_executive')),
  created_at timestamptz not null default now()
);

-- Auto-create a profile row when a new user signs up
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

-- Drop trigger if exists then create
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- RLS: users can read all profiles, only account_executive can modify
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

-- ═══════════════════════════════════════════════════════
-- MESSAGES
-- ═══════════════════════════════════════════════════════
create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  lead_id text not null,
  user_id uuid null,
  phone text not null,
  channel text not null default 'whatsapp',
  direction text not null check (direction in ('incoming','outgoing')),
  text text not null,
  status text not null default 'sent',
  external_id text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_messages_lead_id on public.messages(lead_id);
create index if not exists idx_messages_created_at on public.messages(created_at);

-- ═══════════════════════════════════════════════════════
-- DEALS / REVENUE PIPELINE
-- ═══════════════════════════════════════════════════════
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

-- RLS: all authenticated users can CRUD deals (service_role bypasses anyway)
alter table public.deals enable row level security;

drop policy if exists "Deals full access for authenticated" on public.deals;
create policy "Deals full access for authenticated"
  on public.deals for all
  to authenticated
  using (true)
  with check (true);

-- Allow service_role full access (used by the FastAPI backend)
drop policy if exists "Service role full access on deals" on public.deals;
create policy "Service role full access on deals"
  on public.deals for all
  to service_role
  using (true)
  with check (true);
