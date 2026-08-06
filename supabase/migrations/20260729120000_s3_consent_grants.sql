-- App v8 S3 (2026-07-29) — the consent seam. Explicit, scoped,
-- revocable, auditable, inactive by default. Additive only.

create table if not exists public.consent_grants (
  id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  scope text not null,
  purpose text not null,
  granted_at timestamptz not null default now(),
  revoked_at timestamptz,
  org_id uuid,
  created_at timestamptz not null default now()
);

create index if not exists consent_grants_user_scope_idx
  on public.consent_grants (user_id, scope);

alter table public.consent_grants enable row level security;

drop policy if exists "consent_grants_select_own" on public.consent_grants;
create policy "consent_grants_select_own" on public.consent_grants
  for select to authenticated using (auth.uid() = user_id);

drop policy if exists "consent_grants_insert_own" on public.consent_grants;
create policy "consent_grants_insert_own" on public.consent_grants
  for insert to authenticated with check (auth.uid() = user_id);

drop policy if exists "consent_grants_update_own" on public.consent_grants;
create policy "consent_grants_update_own" on public.consent_grants
  for update to authenticated using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

grant select, insert, update on public.consent_grants to authenticated;
