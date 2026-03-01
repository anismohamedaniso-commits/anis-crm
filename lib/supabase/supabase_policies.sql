-- Enable RLS and basic authenticated access policies

alter table public.messages enable row level security;

-- Allow authenticated users to read/write their rows; if user_id is null, allow access (to avoid lockouts during initial writes), but prefer setting user_id in app/edge functions.
create policy messages_select on public.messages
  for select
  using (auth.role() = 'authenticated');

create policy messages_insert on public.messages
  for insert
  with check (auth.role() = 'authenticated');

create policy messages_update on public.messages
  for update
  using (auth.role() = 'authenticated');

create policy messages_delete on public.messages
  for delete
  using (auth.role() = 'authenticated');
