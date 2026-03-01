-- ═══════════════════════════════════════════════════════════════════════════
-- CRM Migration v2 — Full Supabase/Postgres Schema
-- Run this AFTER supabase_tables.sql (which creates profiles + messages).
-- ═══════════════════════════════════════════════════════════════════════════

-- ───────────────────────────────────────────────────────────────────────────
-- 1. LEADS
-- ───────────────────────────────────────────────────────────────────────────
create table if not exists public.leads (
  id          text primary key,
  name        text not null default '',
  email       text default '',
  phone       text default '',
  source      text default '',
  status      text not null default 'new'
    check (status in ('new','contacted','qualified','converted','lost')),
  notes       text default '',
  tags        text[] default '{}',
  assigned_to uuid references public.profiles(id) on delete set null,
  assigned_to_name text default '',
  company     text default '',
  value       numeric default 0,
  extra       jsonb default '{}',
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index if not exists idx_leads_status     on public.leads(status);
create index if not exists idx_leads_assigned   on public.leads(assigned_to);
create index if not exists idx_leads_created    on public.leads(created_at);
create index if not exists idx_leads_source     on public.leads(source);

alter table public.leads enable row level security;

drop policy if exists "leads_select" on public.leads;
create policy "leads_select" on public.leads
  for select to authenticated using (true);

drop policy if exists "leads_insert" on public.leads;
create policy "leads_insert" on public.leads
  for insert to authenticated with check (true);

drop policy if exists "leads_update" on public.leads;
create policy "leads_update" on public.leads
  for update to authenticated using (true);

drop policy if exists "leads_delete" on public.leads;
create policy "leads_delete" on public.leads
  for delete to authenticated
  using (
    exists (
      select 1 from public.profiles
      where profiles.id = auth.uid()
        and profiles.role = 'account_executive'
    )
  );

-- ───────────────────────────────────────────────────────────────────────────
-- 2. ACTIVITIES / NOTES
-- ───────────────────────────────────────────────────────────────────────────
create table if not exists public.activities (
  id          text primary key,
  lead_id     text references public.leads(id) on delete cascade,
  author      text not null default '',
  author_id   uuid references public.profiles(id) on delete set null,
  type        text not null default 'note',
  content     text default '',
  ts          timestamptz not null default now()
);

create index if not exists idx_activities_lead  on public.activities(lead_id);
create index if not exists idx_activities_ts    on public.activities(ts);

alter table public.activities enable row level security;

drop policy if exists "activities_select" on public.activities;
create policy "activities_select" on public.activities
  for select to authenticated using (true);

drop policy if exists "activities_insert" on public.activities;
create policy "activities_insert" on public.activities
  for insert to authenticated with check (true);

-- ───────────────────────────────────────────────────────────────────────────
-- 3. TASKS
-- ───────────────────────────────────────────────────────────────────────────
create table if not exists public.tasks (
  id               text primary key,
  title            text not null default '',
  description      text default '',
  status           text not null default 'todo'
    check (status in ('todo','in_progress','done')),
  priority         text not null default 'medium'
    check (priority in ('low','medium','high','urgent')),
  assigned_to      uuid references public.profiles(id) on delete set null,
  assigned_to_name text default '',
  created_by       uuid references public.profiles(id) on delete set null,
  created_by_name  text default '',
  lead_id          text default '',
  lead_name        text default '',
  due_date         text default '',
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

create index if not exists idx_tasks_assigned   on public.tasks(assigned_to);
create index if not exists idx_tasks_status     on public.tasks(status);
create index if not exists idx_tasks_created    on public.tasks(created_at);

alter table public.tasks enable row level security;

drop policy if exists "tasks_select" on public.tasks;
create policy "tasks_select" on public.tasks
  for select to authenticated using (true);

drop policy if exists "tasks_insert" on public.tasks;
create policy "tasks_insert" on public.tasks
  for insert to authenticated with check (true);

drop policy if exists "tasks_update" on public.tasks;
create policy "tasks_update" on public.tasks
  for update to authenticated using (true);

drop policy if exists "tasks_delete" on public.tasks;
create policy "tasks_delete" on public.tasks
  for delete to authenticated using (
    created_by = auth.uid()
    or exists (
      select 1 from public.profiles
      where profiles.id = auth.uid()
        and profiles.role = 'account_executive'
    )
  );

-- ───────────────────────────────────────────────────────────────────────────
-- 4. TEAM ACTIVITIES (collaboration feed)
-- ───────────────────────────────────────────────────────────────────────────
create table if not exists public.team_activities (
  id            text primary key,
  user_id       uuid references public.profiles(id) on delete set null,
  user_name     text default '',
  action        text not null default '',
  target_type   text default '',
  target_id     text default '',
  target_name   text default '',
  detail        text default '',
  ts            timestamptz not null default now()
);

create index if not exists idx_team_act_ts on public.team_activities(ts);

alter table public.team_activities enable row level security;

drop policy if exists "team_activities_select" on public.team_activities;
create policy "team_activities_select" on public.team_activities
  for select to authenticated using (true);

drop policy if exists "team_activities_insert" on public.team_activities;
create policy "team_activities_insert" on public.team_activities
  for insert to authenticated with check (true);

-- ───────────────────────────────────────────────────────────────────────────
-- 5. NOTIFICATIONS
-- ───────────────────────────────────────────────────────────────────────────
create table if not exists public.notifications (
  id              text primary key,
  user_id         uuid not null references public.profiles(id) on delete cascade,
  type            text default '',
  title           text not null default '',
  body            text default '',
  action_url      text default '',
  from_user_id    uuid references public.profiles(id) on delete set null,
  from_user_name  text default '',
  read            boolean not null default false,
  ts              timestamptz not null default now()
);

create index if not exists idx_notif_user   on public.notifications(user_id);
create index if not exists idx_notif_read   on public.notifications(user_id, read);
create index if not exists idx_notif_ts     on public.notifications(ts);

alter table public.notifications enable row level security;

-- Users can only see their own notifications
drop policy if exists "notifications_select" on public.notifications;
create policy "notifications_select" on public.notifications
  for select to authenticated using (user_id = auth.uid());

drop policy if exists "notifications_insert" on public.notifications;
create policy "notifications_insert" on public.notifications
  for insert to authenticated with check (true);

drop policy if exists "notifications_update" on public.notifications;
create policy "notifications_update" on public.notifications
  for update to authenticated using (user_id = auth.uid());

-- ───────────────────────────────────────────────────────────────────────────
-- 6. CHAT CHANNELS
-- ───────────────────────────────────────────────────────────────────────────
create table if not exists public.chat_channels (
  id            text primary key,
  name          text default '',
  type          text not null default 'direct'
    check (type in ('direct','group','general')),
  member_ids    uuid[] default '{}',
  member_names  text[] default '{}',
  created_by    text default '',
  created_at    timestamptz not null default now()
);

alter table public.chat_channels enable row level security;

-- Users can see channels they are a member of, or 'general' channels
drop policy if exists "chat_channels_select" on public.chat_channels;
create policy "chat_channels_select" on public.chat_channels
  for select to authenticated
  using (type = 'general' or auth.uid() = any(member_ids));

drop policy if exists "chat_channels_insert" on public.chat_channels;
create policy "chat_channels_insert" on public.chat_channels
  for insert to authenticated with check (true);

-- ───────────────────────────────────────────────────────────────────────────
-- 7. CHAT MESSAGES
-- ───────────────────────────────────────────────────────────────────────────
create table if not exists public.chat_messages (
  id          text primary key,
  channel_id  text not null references public.chat_channels(id) on delete cascade,
  sender_id   uuid references public.profiles(id) on delete set null,
  sender_name text default '',
  text        text not null default '',
  ts          timestamptz not null default now()
);

create index if not exists idx_chat_msg_channel on public.chat_messages(channel_id);
create index if not exists idx_chat_msg_ts      on public.chat_messages(ts);

alter table public.chat_messages enable row level security;

-- Users can see messages in channels they are a member of
drop policy if exists "chat_messages_select" on public.chat_messages;
create policy "chat_messages_select" on public.chat_messages
  for select to authenticated
  using (
    exists (
      select 1 from public.chat_channels ch
      where ch.id = channel_id
        and (ch.type = 'general' or auth.uid() = any(ch.member_ids))
    )
  );

drop policy if exists "chat_messages_insert" on public.chat_messages;
create policy "chat_messages_insert" on public.chat_messages
  for insert to authenticated with check (true);

-- ───────────────────────────────────────────────────────────────────────────
-- 8. Enable Supabase Realtime on chat tables
-- ───────────────────────────────────────────────────────────────────────────
alter publication supabase_realtime add table public.chat_messages;
alter publication supabase_realtime add table public.chat_channels;
alter publication supabase_realtime add table public.notifications;

-- ───────────────────────────────────────────────────────────────────────────
-- 9. Updated-at trigger function (reusable)
-- ───────────────────────────────────────────────────────────────────────────
create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_leads_updated on public.leads;
create trigger trg_leads_updated before update on public.leads
  for each row execute function public.set_updated_at();

drop trigger if exists trg_tasks_updated on public.tasks;
create trigger trg_tasks_updated before update on public.tasks
  for each row execute function public.set_updated_at();

-- ───────────────────────────────────────────────────────────────────────────
-- 10. Fix original messages table RLS (scope to team, not wide open)
-- ───────────────────────────────────────────────────────────────────────────
drop policy if exists "messages_select" on public.messages;
create policy "messages_select" on public.messages
  for select to authenticated using (true);

drop policy if exists "messages_insert" on public.messages;
create policy "messages_insert" on public.messages
  for insert to authenticated with check (true);

drop policy if exists "messages_update" on public.messages;
create policy "messages_update" on public.messages
  for update to authenticated
  using (user_id = auth.uid() or user_id is null);

drop policy if exists "messages_delete" on public.messages;
create policy "messages_delete" on public.messages
  for delete to authenticated
  using (
    user_id = auth.uid()
    or exists (
      select 1 from public.profiles
      where profiles.id = auth.uid()
        and profiles.role = 'account_executive'
    )
  );
