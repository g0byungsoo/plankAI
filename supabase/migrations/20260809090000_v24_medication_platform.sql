-- APP v24 — THE REGIMEN (docs/app_v24/00_REGIMEN.md)
-- Additive only. Founder applies; until then the client defers
-- gracefully (local-first, pending sweep retries).
--
-- 1. regimen_plans grows the version-chain + catalog columns.
-- 2. dose_events: the historically-correct dose record (one row per
--    slot day per user; deterministic ids minted client-side).

-- 1 ── regimen_plans additive columns ────────────────────────────

alter table public.regimen_plans
  add column if not exists product_id text,
  add column if not exists route text,
  add column if not exists previous_plan_id text,
  add column if not exists end_reason text;

comment on column public.regimen_plans.product_id is
  'v24 medication catalog id (ozempic, compounded-semaglutide, …); null = pre-v24 or freeform';
comment on column public.regimen_plans.route is
  'v24: injection | oral (null on pre-v24 rows)';
comment on column public.regimen_plans.previous_plan_id is
  'v24 version chain: the superseded plan this row replaced (append-only history)';
comment on column public.regimen_plans.end_reason is
  'v24: dose_changed | medication_changed | schedule_changed | paused | ended | care_team_assigned';

-- 2 ── dose_events ────────────────────────────────────────────────

create table if not exists public.dose_events (
  id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  regimen_plan_id text not null,
  day_key text not null,
  scheduled_at timestamptz,
  status text not null default 'pending'
    check (status in ('pending','taken','skipped','missed')),
  taken_at timestamptz,
  site text
    check (site is null or site in (
      'left_abdomen','right_abdomen','left_thigh','right_thigh',
      'left_arm','right_arm')),
  note text,
  skip_reason text,
  source text not null default 'sheet',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists dose_events_user_day_idx
  on public.dose_events (user_id, day_key desc);

alter table public.dose_events enable row level security;

create policy "dose_events_select_own" on public.dose_events
  for select to authenticated
  using ((select auth.uid()) = user_id);

create policy "dose_events_insert_own" on public.dose_events
  for insert to authenticated
  with check ((select auth.uid()) = user_id);

create policy "dose_events_update_own" on public.dose_events
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "dose_events_delete_own" on public.dose_events
  for delete to authenticated
  using ((select auth.uid()) = user_id);

grant select, insert, update, delete on public.dose_events to authenticated;

-- Clinician access (future): dose adherence reaches the portal only
-- through SECURITY DEFINER RPCs under care_assignment consent — no
-- direct clinician policies here, matching the S4 chokepoint law.
