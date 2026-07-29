-- App v8 — THE CARE PLATFORM foundation (2026-07-28)
-- docs/app_v8/03_ARCHITECTURE.md §3g. Additive only; zero changes to
-- existing tables. Four tables:
--   observations    — the chart: typed, userId-scoped subjective +
--                     derived records (feeling / sit-check / dose /
--                     note / tonight-plan / hydration / care events).
--   regimen_plans   — medication + supplement plans (display_name is
--                     HER OWN words; never rendered on app-authored
--                     surfaces; org seam nullable).
--   protocols       — served CareProtocol configs (S2 target; the
--                     jenimethod_lessons read-all pattern). Seeded
--                     with the shipped default.
--   protocol_items  — protocol item rows (S2; empty at seed).

-- ============================================================
-- observations
-- ============================================================
create table if not exists public.observations (
  id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  kind text not null,
  day_key text not null,
  effective_at timestamptz,
  value_text text,
  value_num double precision,
  unit text,
  source text not null default 'manual',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists observations_user_kind_day_idx
  on public.observations (user_id, kind, day_key desc);

alter table public.observations enable row level security;

drop policy if exists "observations_select_own" on public.observations;
create policy "observations_select_own" on public.observations
  for select to authenticated using (auth.uid() = user_id);

drop policy if exists "observations_insert_own" on public.observations;
create policy "observations_insert_own" on public.observations
  for insert to authenticated with check (auth.uid() = user_id);

drop policy if exists "observations_update_own" on public.observations;
create policy "observations_update_own" on public.observations
  for update to authenticated using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "observations_delete_own" on public.observations;
create policy "observations_delete_own" on public.observations
  for delete to authenticated using (auth.uid() = user_id);

grant select, insert, update, delete on public.observations to authenticated;

-- ============================================================
-- regimen_plans
-- ============================================================
create table if not exists public.regimen_plans (
  id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  kind text not null,                       -- 'medication' | 'supplement'
  display_name text not null,               -- her words (sensitive)
  schedule_rule text not null,              -- 'weeklyAnchor' | 'daily' | 'asNeeded'
  anchor_weekday int,                       -- ISO 1=Mon … 7=Sun
  time_of_day_minutes int,
  dose_stage_label text,                    -- her label; app never authors dosing
  started_at timestamptz,
  ended_at timestamptz,
  reminder_enabled boolean not null default false,
  source_protocol_id text,                  -- tenancy seam (null = self-created)
  org_id uuid,                              -- tenancy seam (null = consumer)
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists regimen_plans_user_idx
  on public.regimen_plans (user_id);

alter table public.regimen_plans enable row level security;

drop policy if exists "regimen_plans_select_own" on public.regimen_plans;
create policy "regimen_plans_select_own" on public.regimen_plans
  for select to authenticated using (auth.uid() = user_id);

drop policy if exists "regimen_plans_insert_own" on public.regimen_plans;
create policy "regimen_plans_insert_own" on public.regimen_plans
  for insert to authenticated with check (auth.uid() = user_id);

drop policy if exists "regimen_plans_update_own" on public.regimen_plans;
create policy "regimen_plans_update_own" on public.regimen_plans
  for update to authenticated using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "regimen_plans_delete_own" on public.regimen_plans;
create policy "regimen_plans_delete_own" on public.regimen_plans
  for delete to authenticated using (auth.uid() = user_id);

grant select, insert, update, delete on public.regimen_plans to authenticated;

-- ============================================================
-- protocols (served CareProtocol — read-all, service-role authored)
-- ============================================================
create table if not exists public.protocols (
  id text primary key,
  org_id uuid,                              -- null = the consumer default
  title text not null,
  version int not null default 1,
  payload jsonb not null,                   -- serialized CareProtocol
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.protocols enable row level security;

drop policy if exists "protocols_read_all" on public.protocols;
create policy "protocols_read_all" on public.protocols
  for select to authenticated using (true);

grant select on public.protocols to authenticated;

-- ============================================================
-- protocol_items (S2 — the item catalog as data; empty at seed)
-- ============================================================
create table if not exists public.protocol_items (
  id text primary key,
  protocol_id text not null references public.protocols(id) on delete cascade,
  item_order int not null default 0,
  payload jsonb not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists protocol_items_protocol_idx
  on public.protocol_items (protocol_id, item_order);

alter table public.protocol_items enable row level security;

drop policy if exists "protocol_items_read_all" on public.protocol_items;
create policy "protocol_items_read_all" on public.protocol_items
  for select to authenticated using (true);

grant select on public.protocol_items to authenticated;

-- ============================================================
-- Seed: the shipped default protocol (CareProtocol.default,
-- serialized). The org-null tenant's config — S2's hydration target.
-- ============================================================
insert into public.protocols (id, org_id, title, version, payload, published_at)
values (
  'jenifit.default',
  null,
  'jenifit consumer default',
  1,
  '{
    "id": "jenifit.default",
    "version": 1,
    "protein": {
      "perKgGLP1Current": 1.6, "perKgDefault": 1.2,
      "floorGLP1G": 90, "floorDefaultG": 70,
      "capGLP1G": 140, "capDefaultG": 130, "roundToG": 5
    },
    "maxPlanRatePctPerWeek": 0.01,
    "composition": {
      "maxSupportingMoves": 2, "maxOfferedMoves": 2,
      "shortNightHours": 6, "gentleReturnDays": 4,
      "rapidLossRatePctPerWeek": 0.01, "proteinDeficitPromoteG": 25
    },
    "cadence": {
      "weighSlotsDefault": [0, 3], "weighSlotsGLP1Current": [0],
      "weighSlotsRestrictiveRisk": [0], "weighSlotsSoftened": [0],
      "weighSlotsMaintenance": [6], "weighStaleFallbackDays": 7
    },
    "band": {
      "driftingAtKg": 1.4, "resetAtKg": 2.3,
      "keptMinWeighDays": 1, "keptMinPresenceDays": 3
    },
    "regimen": {
      "titrationSupportWeeks": 8, "hydrationDuringTitration": true,
      "hydrationMlDuringTitration": 1800, "doseDayLeads": true
    }
  }'::jsonb,
  now()
)
on conflict (id) do nothing;
