-- v25 E1 THE SPINE — program facts + weekly reads
-- (docs/app_v25/05_E1_SPINE.md §1-2). Additive only. Founder applies;
-- until then the client defers gracefully (pendingUpsert outbox).
-- Stacks behind 20260809090000_v24_medication_platform.sql.

-- v25 E8 (2026-08-11): `create policy` has no IF NOT EXISTS in
-- Postgres, so a partially-applied run of this migration could never be
-- retried — `supabase db push` died at the first policy with SQLSTATE
-- 42710 and the whole chain stopped. Each policy is now dropped first,
-- which is safe on a fresh database and makes the migration replayable.
-- Everything else here was already idempotent (if not exists).

-- ---------------------------------------------------------------
-- program_facts — one row = one VERSION of one program fact.
-- Append-only chains per (kind, authority); supersede-never-mutate.
-- ---------------------------------------------------------------

create table if not exists public.program_facts (
  id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  kind text not null check (kind in (
    'stepGoal', 'proteinAdjust', 'movesAdjust', 'weighCadence',
    'loggingMode', 'notificationPosture', 'walkTiming', 'readAnchor'
  )),
  -- canonical encoded value ("i:5150" / "w:softened")
  value text not null,
  authority text not null check (authority in (
    'prescribed', 'preferred', 'recommended', 'defaulted'
  )),
  basis text not null check (basis in (
    'assigned', 'stated', 'inferred', 'defaulted'
  )),
  source text not null,
  previous_fact_id text,
  accepted_at timestamptz,
  ended_at timestamptz,
  end_reason text check (end_reason is null or end_reason in (
    'superseded', 'revoked', 'reset'
  )),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.program_facts is
  'v25 program memory: authority-carrying version chains. iOS writes '
  'prescribed NEVER (policy-enforced); prescribed rows arrive only via '
  'future SECURITY DEFINER care RPCs (service role bypasses RLS).';
comment on column public.program_facts.value is
  'canonical encoding: i:<int> or w:<word> (ProgramFactValue)';

create index if not exists program_facts_user_kind_idx
  on public.program_facts (user_id, kind, created_at desc);

alter table public.program_facts enable row level security;

-- Own-row RLS; the client role can never author or become a
-- prescription (S4 authority law, structural in the schema).
drop policy if exists "program_facts_select_own" on public.program_facts;
create policy "program_facts_select_own" on public.program_facts
  for select to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "program_facts_insert_own" on public.program_facts;
create policy "program_facts_insert_own" on public.program_facts
  for insert to authenticated
  with check ((select auth.uid()) = user_id and authority <> 'prescribed');

drop policy if exists "program_facts_update_own" on public.program_facts;
create policy "program_facts_update_own" on public.program_facts
  for update to authenticated
  using ((select auth.uid()) = user_id and authority <> 'prescribed')
  with check ((select auth.uid()) = user_id and authority <> 'prescribed');

drop policy if exists "program_facts_delete_own" on public.program_facts;
create policy "program_facts_delete_own" on public.program_facts
  for delete to authenticated
  using ((select auth.uid()) = user_id and authority <> 'prescribed');

-- ---------------------------------------------------------------
-- weekly_reads — one row per ritual: what was shown, what was
-- offered, what she decided. The program's court record.
-- ---------------------------------------------------------------

create table if not exists public.weekly_reads (
  id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  -- local-calendar day key of the week window's start ("2026-08-04")
  window_start_day text not null,
  -- "doseDay" | "enrollment" | "preference" — the anchor that placed it
  anchor text not null,
  -- compact categorical summary of what the read showed (no free
  -- text, no health values — the analytics hygiene law applies here)
  shown text,
  offer_key text,
  -- "accepted" | "declined" | "dismissed"
  decision text check (decision is null or decision in (
    'accepted', 'declined', 'dismissed'
  )),
  -- the program_facts row a consented offer wrote
  fact_id text,
  decided_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists weekly_reads_user_window_idx
  on public.weekly_reads (user_id, window_start_day desc);

alter table public.weekly_reads enable row level security;

drop policy if exists "weekly_reads_select_own" on public.weekly_reads;
create policy "weekly_reads_select_own" on public.weekly_reads
  for select to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "weekly_reads_insert_own" on public.weekly_reads;
create policy "weekly_reads_insert_own" on public.weekly_reads
  for insert to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "weekly_reads_update_own" on public.weekly_reads;
create policy "weekly_reads_update_own" on public.weekly_reads
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "weekly_reads_delete_own" on public.weekly_reads;
create policy "weekly_reads_delete_own" on public.weekly_reads
  for delete to authenticated
  using ((select auth.uid()) = user_id);
