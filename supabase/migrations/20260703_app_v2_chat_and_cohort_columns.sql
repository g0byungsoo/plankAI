-- App v2 (docs/app_v2/06_DATA_SUPABASE.md)
-- 1. users: cohort columns that gate behavior must survive devices
-- 2. coach_messages: cross-device chat transcript (client sync v2.1)
-- 3. jeni_chat_telemetry: EF cost/caps ledger (service-role only)
-- 4. day_reflections: the evening close's one-tap feeling
-- RLS ships IN THIS FILE so the policy-runbook gap can't recur.

-- 1 ─ users cohort columns (additive, nullable)
alter table public.users
  add column if not exists program_mode text,
  add column if not exists goal_direction text,
  add column if not exists medication_status text,
  add column if not exists dietary_csv text,
  add column if not exists nsv_priority_csv text,
  add column if not exists appetite_rhythm text,
  add column if not exists glp1_stop_window text,
  add column if not exists fears_csv text,
  add column if not exists snap_demo_meal text;

-- 2 ─ coach_messages
create table if not exists public.coach_messages (
  id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('user','jeni','tool')),
  body text not null,
  tool_name text,
  tool_payload jsonb,
  day_key text not null,
  created_at timestamptz not null default now()
);
create index if not exists coach_messages_user_day
  on public.coach_messages (user_id, day_key);

alter table public.coach_messages enable row level security;
drop policy if exists coach_messages_select on public.coach_messages;
drop policy if exists coach_messages_insert on public.coach_messages;
drop policy if exists coach_messages_update on public.coach_messages;
drop policy if exists coach_messages_delete on public.coach_messages;
create policy coach_messages_select on public.coach_messages
  for select using (auth.uid() = user_id);
create policy coach_messages_insert on public.coach_messages
  for insert with check (auth.uid() = user_id);
create policy coach_messages_update on public.coach_messages
  for update using (auth.uid() = user_id);
create policy coach_messages_delete on public.coach_messages
  for delete using (auth.uid() = user_id);

-- 3 ─ jeni_chat_telemetry (RLS enabled, NO client policies —
--     service-role only, mirrors food_vision_telemetry)
create table if not exists public.jeni_chat_telemetry (
  id bigint generated always as identity primary key,
  user_id uuid not null,
  model text,
  input_tokens int,
  output_tokens int,
  cost_usd numeric(10,6),
  status text,
  duration_ms int,
  created_at timestamptz not null default now()
);
create index if not exists jeni_chat_telemetry_user_day
  on public.jeni_chat_telemetry (user_id, created_at);
alter table public.jeni_chat_telemetry enable row level security;

-- 4 ─ day_reflections
create table if not exists public.day_reflections (
  id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  day_key text not null,
  feeling text not null,
  created_at timestamptz not null default now(),
  unique (user_id, day_key)
);
alter table public.day_reflections enable row level security;
drop policy if exists day_reflections_select on public.day_reflections;
drop policy if exists day_reflections_insert on public.day_reflections;
drop policy if exists day_reflections_update on public.day_reflections;
create policy day_reflections_select on public.day_reflections
  for select using (auth.uid() = user_id);
create policy day_reflections_insert on public.day_reflections
  for insert with check (auth.uid() = user_id);
create policy day_reflections_update on public.day_reflections
  for update using (auth.uid() = user_id);
