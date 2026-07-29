-- App v8 S4 (2026-07-29) — the first real clinic loop.
-- docs/app_v8/10_S4_CLINIC_LOOP.md is the law this file implements.
--
-- Shape (research-resolved, 04_DECISIONS S4-1..S4-10):
--   * Patients keep direct RLS CRUD on their OWN rows.
--   * EVERY clinician read/write of patient data goes through a
--     SECURITY DEFINER RPC that checks role + relationship + scope,
--     writes an audit event, and returns an explicit projection.
--     There are NO direct clinician policies on patient charts —
--     Postgres has no SELECT triggers, so the RPC chokepoint is the
--     only honest way to account for disclosures.
--   * Helpers live in the unexposed `private` schema, definer,
--     pinned search_path, EXECUTE revoked in the same transaction.
--   * Audit is append-only: API roles hold no write grants; a
--     raising trigger is the belt.
--   * Additive only for consumer behavior: the org-null tenant's
--     paths are untouched except where policies TIGHTEN (patient
--     writes constrained to authority='self' / org-null consent).
-- Idempotent throughout (create if not exists / drop policy if
-- exists / create or replace) — safe to re-run.

-- ============================================================
-- 0. private schema + config (the invitation-code pepper)
-- ============================================================

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create table if not exists private.config (
  key text primary key,
  value text not null
);

-- Pepper generated IN the database, never present in the repo:
-- a leaked table of code hashes is useless without it.
insert into private.config (key, value)
select 'invitation_code_pepper', encode(extensions.gen_random_bytes(32), 'hex')
where not exists (select 1 from private.config where key = 'invitation_code_pepper');

create table if not exists private.invitation_attempts (
  user_id uuid not null,
  attempted_at timestamptz not null default now()
);
create index if not exists invitation_attempts_user_time_idx
  on private.invitation_attempts (user_id, attempted_at desc);

-- ============================================================
-- 1. Tables
-- ============================================================

create table if not exists public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text unique,
  created_at timestamptz not null default now()
);

create table if not exists public.org_members (
  org_id uuid not null references public.organizations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('owner','clinician','staff')),
  status text not null default 'active' check (status in ('active','disabled')),
  display_name text not null default '',
  credential_label text,
  created_at timestamptz not null default now(),
  primary key (org_id, user_id)
);
create index if not exists org_members_user_idx on public.org_members (user_id);

create table if not exists public.patient_invitations (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  created_by uuid not null,
  code_hash text not null unique,
  patient_label text not null,
  status text not null default 'pending'
    check (status in ('pending','accepted','cancelled')),
  expires_at timestamptz not null,
  accepted_by uuid,
  accepted_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists patient_invitations_org_idx
  on public.patient_invitations (org_id, status);

create table if not exists public.care_relationships (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  patient_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'active'
    check (status in ('active','revoked','ended')),
  patient_label text not null default '',
  invitation_id uuid references public.patient_invitations(id) on delete set null,
  established_at timestamptz not null default now(),
  ended_at timestamptz,
  follow_up_on date,
  reviewed_at timestamptz
);
create unique index if not exists care_relationships_one_active
  on public.care_relationships (org_id, patient_id) where status = 'active';
create index if not exists care_relationships_patient_idx
  on public.care_relationships (patient_id, status);
create index if not exists care_relationships_org_idx
  on public.care_relationships (org_id, status);

create table if not exists public.protocol_assignments (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  patient_id uuid not null references auth.users(id) on delete cascade,
  protocol_id text not null references public.protocols(id) on delete cascade,
  status text not null default 'active' check (status in ('active','replaced')),
  assigned_by uuid not null,
  assigned_at timestamptz not null default now(),
  replaced_at timestamptz
);
create unique index if not exists protocol_assignments_one_active
  on public.protocol_assignments (patient_id) where status = 'active';
create index if not exists protocol_assignments_org_idx
  on public.protocol_assignments (org_id, status);

create table if not exists public.correction_requests (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  patient_id uuid not null references auth.users(id) on delete cascade,
  regimen_plan_id text not null,
  category text not null check (category in
    ('name','strength','schedule','not_taking','other')),
  -- Sensitive clinical content: never in analytics, never in audit
  -- meta, never in generic logs. Bounded at the API (≤200).
  note text,
  status text not null default 'open'
    check (status in ('open','accepted','dismissed')),
  resolution_note text,
  resolved_by uuid,
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);
create index if not exists correction_requests_org_idx
  on public.correction_requests (org_id, status);
create index if not exists correction_requests_patient_idx
  on public.correction_requests (patient_id);

-- Deliberately NO foreign keys: audit rows outlive accounts
-- (a bare uuid after account deletion is pseudonymous).
create table if not exists public.care_audit_events (
  id bigint generated always as identity primary key,
  occurred_at timestamptz not null default now(),
  org_id uuid,
  actor_id uuid not null,
  actor_role text not null,
  action text not null,
  patient_id uuid,
  target_kind text,
  target_id text,
  outcome text not null default 'success',
  -- ids / scopes / categories / counts ONLY. Never names, values,
  -- symptoms, weights, notes.
  meta jsonb not null default '{}'::jsonb
);
create index if not exists care_audit_org_idx
  on public.care_audit_events (org_id, occurred_at desc);
create index if not exists care_audit_patient_idx
  on public.care_audit_events (patient_id, occurred_at desc);

create table if not exists public.visit_packets (
  id text primary key,                     -- "<user_id>-<org_id>"
  user_id uuid not null references auth.users(id) on delete cascade,
  org_id uuid not null references public.organizations(id) on delete cascade,
  payload jsonb not null,                  -- canonical S3 VisitPacket
  window_start date,
  window_end date,
  generated_at timestamptz not null default now(),
  app_version text
);
create index if not exists visit_packets_org_idx on public.visit_packets (org_id);
create index if not exists visit_packets_user_idx on public.visit_packets (user_id);

-- Clinic-authored patient-facing instruction joins the regimen
-- record (additive; her own dose_stage_label stays hers).
alter table public.regimen_plans
  add column if not exists instruction text;

-- The lookback the patient chose at connect (28 | 0). Null = a
-- legacy org-null preference row.
alter table public.consent_grants
  add column if not exists lookback_days int;

-- ============================================================
-- 2. Default-deny grants on every new table
-- ============================================================

revoke all on public.organizations        from anon, authenticated;
revoke all on public.org_members          from anon, authenticated;
revoke all on public.patient_invitations  from anon, authenticated;
revoke all on public.care_relationships   from anon, authenticated;
revoke all on public.protocol_assignments from anon, authenticated;
revoke all on public.correction_requests  from anon, authenticated;
revoke all on public.care_audit_events    from anon, authenticated;
revoke all on public.visit_packets        from anon, authenticated;

grant select on public.organizations to authenticated;
grant select on public.org_members to authenticated;
-- code_hash is deliberately absent from the column list.
grant select (id, org_id, created_by, patient_label, status,
              expires_at, accepted_by, accepted_at, created_at)
  on public.patient_invitations to authenticated;
grant select on public.care_relationships to authenticated;
grant select on public.protocol_assignments to authenticated;
grant select on public.correction_requests to authenticated;
grant select on public.care_audit_events to authenticated;
grant select, insert, update, delete on public.visit_packets to authenticated;

alter table public.organizations        enable row level security;
alter table public.org_members          enable row level security;
alter table public.patient_invitations  enable row level security;
alter table public.care_relationships   enable row level security;
alter table public.protocol_assignments enable row level security;
alter table public.correction_requests  enable row level security;
alter table public.care_audit_events    enable row level security;
alter table public.visit_packets        enable row level security;

-- ============================================================
-- 3. private helpers (SECURITY DEFINER; the policy vocabulary)
-- ============================================================

create or replace function private.is_active_member(p_org uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.org_members m
    where m.org_id = p_org
      and m.user_id = (select auth.uid())
      and m.status = 'active'
  );
$$;

create or replace function private.has_org_role(p_org uuid, p_roles text[])
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.org_members m
    where m.org_id = p_org
      and m.user_id = (select auth.uid())
      and m.status = 'active'
      and m.role = any (p_roles)
  );
$$;

create or replace function private.is_related_patient(p_org uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.care_relationships r
    where r.org_id = p_org and r.patient_id = (select auth.uid())
  );
$$;

create or replace function private.active_relationship(p_patient uuid, p_org uuid)
returns uuid
language sql stable security definer set search_path = ''
as $$
  select r.id from public.care_relationships r
  where r.org_id = p_org and r.patient_id = p_patient and r.status = 'active'
  limit 1;
$$;

create or replace function private.has_consent(p_patient uuid, p_org uuid, p_scope text)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select private.active_relationship(p_patient, p_org) is not null
     and exists (
       select 1 from public.consent_grants g
       where g.user_id = p_patient
         and g.org_id = p_org
         and g.scope = p_scope
         and g.revoked_at is null
     );
$$;

-- The clinic may see records no older than this (her lookback
-- choice, anchored at the relationship's establishment).
create or replace function private.consent_window_start(p_patient uuid, p_org uuid)
returns date
language sql stable security definer set search_path = ''
as $$
  select (r.established_at::date - coalesce(
           (select max(g.lookback_days) from public.consent_grants g
            where g.user_id = p_patient and g.org_id = p_org
              and g.revoked_at is null), 0))
  from public.care_relationships r
  where r.org_id = p_org and r.patient_id = p_patient and r.status = 'active'
  limit 1;
$$;

create or replace function private.can_publish_packet(p_user uuid, p_org uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select private.has_consent(p_user, p_org, 'visit_packet_view');
$$;

create or replace function private.has_active_assignment(p_user uuid, p_protocol text)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.protocol_assignments a
    where a.patient_id = p_user and a.protocol_id = p_protocol
      and a.status = 'active'
  );
$$;

-- The ONE door into the audit table.
create or replace function private.log_care_event(
  p_org uuid, p_actor uuid, p_actor_role text, p_action text,
  p_patient uuid, p_target_kind text, p_target_id text,
  p_outcome text default 'success', p_meta jsonb default '{}'::jsonb
) returns void
language sql volatile security definer set search_path = ''
as $$
  insert into public.care_audit_events
    (org_id, actor_id, actor_role, action, patient_id,
     target_kind, target_id, outcome, meta)
  values
    (p_org, p_actor, p_actor_role, p_action, p_patient,
     p_target_kind, p_target_id, p_outcome, coalesce(p_meta, '{}'::jsonb));
$$;

create or replace function private.raise_append_only()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  raise exception 'care_audit_events is append-only';
end;
$$;

drop trigger if exists care_audit_append_only on public.care_audit_events;
create trigger care_audit_append_only
  before update or delete on public.care_audit_events
  for each row execute function private.raise_append_only();

-- The caller's role inside an org ('patient' when none).
create or replace function private.actor_role_in(p_org uuid)
returns text
language sql stable security definer set search_path = ''
as $$
  select coalesce(
    (select m.role from public.org_members m
     where m.org_id = p_org and m.user_id = (select auth.uid())
       and m.status = 'active'),
    'patient');
$$;

-- Invitation-code plumbing: normalize (Crockford confusables),
-- pepper, hash. Raw codes are NEVER stored.
create or replace function private.normalize_code(p_code text)
returns text
language sql immutable security definer set search_path = ''
as $$
  select translate(upper(regexp_replace(coalesce(p_code, ''), '[^0-9A-Za-z]', '', 'g')),
                   'OIL', '011');
$$;

create or replace function private.hash_code(p_code text)
returns text
language sql stable security definer set search_path = ''
as $$
  select encode(extensions.digest(
    (select value from private.config where key = 'invitation_code_pepper')
      || ':' || private.normalize_code(p_code), 'sha256'), 'hex');
$$;

-- 8 chars of Crockford Base32 (no I/L/O/U) = 40 bits, CSPRNG.
create or replace function private.generate_code()
returns text
language sql volatile security definer set search_path = ''
as $$
  select string_agg(
    substr('0123456789ABCDEFGHJKMNPQRSTVWXYZ',
           (get_byte(extensions.gen_random_bytes(1), 0) % 32) + 1, 1), '')
  from generate_series(1, 8);
$$;

-- Attempt throttle: 5 failures / 15 min, 20 / day, per caller.
create or replace function private.check_invitation_rate(p_user uuid)
returns void
language plpgsql volatile security definer set search_path = ''
as $$
begin
  if (select count(*) from private.invitation_attempts
      where user_id = p_user and attempted_at > now() - interval '15 minutes') >= 5
     or (select count(*) from private.invitation_attempts
      where user_id = p_user and attempted_at > now() - interval '24 hours') >= 20
  then
    raise exception 'too many attempts. try again in a little while.';
  end if;
end;
$$;

create or replace function private.record_invitation_failure(p_user uuid)
returns void
language sql volatile security definer set search_path = ''
as $$
  insert into private.invitation_attempts (user_id) values (p_user);
$$;

-- ============================================================
-- 4. Policies (patient-direct surfaces only; clinicians use RPCs)
-- ============================================================

drop policy if exists "organizations_select" on public.organizations;
create policy "organizations_select" on public.organizations
  for select to authenticated
  using (private.is_active_member(id) or private.is_related_patient(id));

drop policy if exists "org_members_select" on public.org_members;
create policy "org_members_select" on public.org_members
  for select to authenticated
  using (user_id = (select auth.uid()) or private.is_active_member(org_id));

drop policy if exists "patient_invitations_select" on public.patient_invitations;
create policy "patient_invitations_select" on public.patient_invitations
  for select to authenticated
  using (private.is_active_member(org_id));

drop policy if exists "care_relationships_select" on public.care_relationships;
create policy "care_relationships_select" on public.care_relationships
  for select to authenticated
  using (patient_id = (select auth.uid()) or private.is_active_member(org_id));

drop policy if exists "protocol_assignments_select" on public.protocol_assignments;
create policy "protocol_assignments_select" on public.protocol_assignments
  for select to authenticated
  using (patient_id = (select auth.uid()) or private.is_active_member(org_id));

drop policy if exists "correction_requests_select" on public.correction_requests;
create policy "correction_requests_select" on public.correction_requests
  for select to authenticated
  using (patient_id = (select auth.uid()) or private.is_active_member(org_id));

-- Audit transparency: the patient sees events about her; active
-- members see their org's. Nobody writes through the API.
drop policy if exists "care_audit_select" on public.care_audit_events;
create policy "care_audit_select" on public.care_audit_events
  for select to authenticated
  using (patient_id = (select auth.uid()) or private.is_active_member(org_id));

-- The patient owns her published packet; publishing requires an
-- active relationship + the packet scope. Clinic reads are
-- RPC-only (no member policy here, deliberately).
drop policy if exists "visit_packets_select_own" on public.visit_packets;
create policy "visit_packets_select_own" on public.visit_packets
  for select to authenticated using (user_id = (select auth.uid()));
drop policy if exists "visit_packets_insert_own" on public.visit_packets;
create policy "visit_packets_insert_own" on public.visit_packets
  for insert to authenticated
  with check (user_id = (select auth.uid())
              and private.can_publish_packet(user_id, org_id));
drop policy if exists "visit_packets_update_own" on public.visit_packets;
create policy "visit_packets_update_own" on public.visit_packets
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid())
              and private.can_publish_packet(user_id, org_id));
drop policy if exists "visit_packets_delete_own" on public.visit_packets;
create policy "visit_packets_delete_own" on public.visit_packets
  for delete to authenticated using (user_id = (select auth.uid()));

-- ---- TIGHTENED existing policies ----

-- regimen_plans: the FR1 client guards become server law. The
-- patient's direct writes exist only for authority='self' rows;
-- care_team rows are clinician-RPC territory.
drop policy if exists "regimen_plans_insert_own" on public.regimen_plans;
create policy "regimen_plans_insert_own" on public.regimen_plans
  for insert to authenticated
  with check ((select auth.uid()) = user_id
              and authority = 'self'
              and org_id is null
              and source_protocol_id is null);
drop policy if exists "regimen_plans_update_own" on public.regimen_plans;
create policy "regimen_plans_update_own" on public.regimen_plans
  for update to authenticated
  using ((select auth.uid()) = user_id and authority = 'self')
  with check ((select auth.uid()) = user_id and authority = 'self'
              and org_id is null and source_protocol_id is null);
drop policy if exists "regimen_plans_delete_own" on public.regimen_plans;
create policy "regimen_plans_delete_own" on public.regimen_plans
  for delete to authenticated
  using ((select auth.uid()) = user_id and authority = 'self');

-- consent_grants: the S3 org-null preference keeps its direct
-- path; org-scoped grants move ONLY through audited RPCs.
drop policy if exists "consent_grants_insert_own" on public.consent_grants;
create policy "consent_grants_insert_own" on public.consent_grants
  for insert to authenticated
  with check ((select auth.uid()) = user_id and org_id is null);
drop policy if exists "consent_grants_update_own" on public.consent_grants;
create policy "consent_grants_update_own" on public.consent_grants
  for update to authenticated
  using ((select auth.uid()) = user_id and org_id is null)
  with check ((select auth.uid()) = user_id and org_id is null);

-- protocols: tenant configs stop being world-readable. The
-- consumer default (org_id null) stays public to authenticated;
-- an org's rows are visible to its members and to patients
-- actively assigned to them.
drop policy if exists "protocols_read_all" on public.protocols;
drop policy if exists "protocols_read" on public.protocols;
create policy "protocols_read" on public.protocols
  for select to authenticated
  using (org_id is null
         or private.is_active_member(org_id)
         or private.has_active_assignment((select auth.uid()), id));

-- ============================================================
-- 5. RPCs — patient side
-- ============================================================

-- WHO is asking, before any grant. Contract: this ALWAYS returns
-- jsonb {ok, ...} and only RAISES on the hard throttle stop or a
-- structural error. A bad/expired/used code is an EXPECTED outcome
-- ({ok:false, reason:'invalid'}) — not an exception. That matters
-- for more than tidiness: a RAISE aborts the function's own
-- transaction, which would roll back the very attempt-log insert
-- the throttle counts. Soft-returning commits the log so brute
-- force actually accumulates toward the cap.
create or replace function public.care_preview_invitation(p_code text)
returns jsonb
language plpgsql volatile security definer set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_inv record;
begin
  if v_uid is null then raise exception 'not signed in'; end if;
  perform private.check_invitation_rate(v_uid);
  select i.id, i.org_id, i.patient_label, i.expires_at, o.name as org_name
    into v_inv
    from public.patient_invitations i
    join public.organizations o on o.id = i.org_id
   where i.code_hash = private.hash_code(p_code)
     and i.status = 'pending'
     and i.expires_at > now();
  if not found then
    perform private.record_invitation_failure(v_uid);
    return jsonb_build_object('ok', false, 'reason', 'invalid');
  end if;
  return jsonb_build_object(
    'ok', true,
    'org_id', v_inv.org_id,
    'org_name', v_inv.org_name,
    'patient_label', v_inv.patient_label,
    'expires_at', v_inv.expires_at
  );
end;
$$;

create or replace function public.care_accept_invitation(
  p_code text, p_lookback_days int, p_scopes text[]
) returns jsonb
language plpgsql volatile security definer set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_inv record;
  v_rel_id uuid;
  v_scope text;
  v_allowed text[] := array['visit_packet_view','observation_view','care_assignment'];
begin
  if v_uid is null then raise exception 'not signed in'; end if;
  perform private.check_invitation_rate(v_uid);

  if p_scopes is null or array_length(p_scopes, 1) is null then
    raise exception 'pick at least one thing to share.';
  end if;
  if not (p_scopes <@ v_allowed) then
    raise exception 'unknown scope.';
  end if;
  if p_lookback_days is null or p_lookback_days not in (0, 28) then
    raise exception 'invalid history choice.';
  end if;
  p_scopes := (select array_agg(distinct s) from unnest(p_scopes) s);

  select i.*, o.name as org_name into v_inv
    from public.patient_invitations i
    join public.organizations o on o.id = i.org_id
   where i.code_hash = private.hash_code(p_code)
   for update of i;

  -- Soft-return (not RAISE) so the attempt log survives to feed the
  -- throttle — see care_preview_invitation's note.
  if not found or v_inv.status <> 'pending' or v_inv.expires_at <= now() then
    perform private.record_invitation_failure(v_uid);
    return jsonb_build_object('ok', false, 'reason', 'invalid');
  end if;

  if private.active_relationship(v_uid, v_inv.org_id) is not null then
    return jsonb_build_object('ok', false, 'reason', 'already_connected');
  end if;

  update public.patient_invitations
     set status = 'accepted', accepted_by = v_uid, accepted_at = now()
   where id = v_inv.id;

  insert into public.care_relationships
    (org_id, patient_id, status, patient_label, invitation_id)
  values (v_inv.org_id, v_uid, 'active', v_inv.patient_label, v_inv.id)
  returning id into v_rel_id;

  foreach v_scope in array p_scopes loop
    insert into public.consent_grants
      (id, user_id, scope, purpose, org_id, lookback_days)
    values
      (v_uid::text || '-' || v_inv.org_id::text || '-' || v_scope || '-'
         || extract(epoch from now())::bigint::text,
       v_uid, v_scope,
       'care connection with ' || v_inv.org_name,
       v_inv.org_id, p_lookback_days);
  end loop;

  perform private.log_care_event(v_inv.org_id, v_uid, 'patient',
    'invitation.accepted', v_uid, 'invitation', v_inv.id::text);
  perform private.log_care_event(v_inv.org_id, v_uid, 'patient',
    'relationship.activated', v_uid, 'relationship', v_rel_id::text);
  perform private.log_care_event(v_inv.org_id, v_uid, 'patient',
    'consent.granted', v_uid, 'consent', null, 'success',
    jsonb_build_object('scopes', p_scopes, 'lookback_days', p_lookback_days));

  return jsonb_build_object(
    'ok', true,
    'org_id', v_inv.org_id,
    'org_name', v_inv.org_name,
    'relationship_id', v_rel_id,
    'scopes', p_scopes,
    'lookback_days', p_lookback_days
  );
end;
$$;

-- Revoke one scope, all scopes, or disconnect entirely.
-- Prospective-only; history and provenance stay.
create or replace function public.care_revoke_consent(
  p_org uuid, p_scope text default null, p_disconnect boolean default false
) returns void
language plpgsql volatile security definer set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_revoked text[];
begin
  if v_uid is null then raise exception 'not signed in'; end if;

  with revoked as (
    update public.consent_grants
       set revoked_at = now()
     where user_id = v_uid and org_id = p_org and revoked_at is null
       and (p_scope is null or scope = p_scope)
    returning scope
  )
  select coalesce(array_agg(scope), array[]::text[])
    into v_revoked from revoked;

  -- Apple-precedent: stop-sharing removes the shared copy.
  if p_scope is null or p_scope = 'visit_packet_view' then
    delete from public.visit_packets
     where user_id = v_uid and org_id = p_org;
  end if;

  if p_disconnect then
    update public.care_relationships
       set status = 'revoked', ended_at = now()
     where org_id = p_org and patient_id = v_uid and status = 'active';
  end if;

  perform private.log_care_event(p_org, v_uid, 'patient',
    'consent.revoked', v_uid, 'consent', null, 'success',
    jsonb_build_object('scopes', coalesce(v_revoked, array[]::text[]),
                       'disconnect', p_disconnect));
end;
$$;

-- 164.526-shaped: a request never mutates the regimen.
create or replace function public.care_submit_correction(
  p_org uuid, p_regimen_plan_id text, p_category text, p_note text default null
) returns uuid
language plpgsql volatile security definer set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_id uuid;
begin
  if v_uid is null then raise exception 'not signed in'; end if;
  if private.active_relationship(v_uid, p_org) is null then
    raise exception 'no active connection to this clinic.';
  end if;
  if p_category not in ('name','strength','schedule','not_taking','other') then
    raise exception 'unknown category.';
  end if;
  if length(coalesce(p_note, '')) > 200 then
    raise exception 'note is too long.';
  end if;
  if not exists (
    select 1 from public.regimen_plans r
    where r.id = p_regimen_plan_id and r.user_id = v_uid
      and r.authority = 'care_team' and r.org_id = p_org
  ) then
    raise exception 'that plan isn''t from this care team.';
  end if;

  insert into public.correction_requests
    (org_id, patient_id, regimen_plan_id, category, note)
  values (p_org, v_uid, p_regimen_plan_id, p_category, nullif(p_note, ''))
  returning id into v_id;

  perform private.log_care_event(p_org, v_uid, 'patient',
    'correction.requested', v_uid, 'correction', v_id::text, 'success',
    jsonb_build_object('category', p_category));
  return v_id;
end;
$$;

-- The FR2 moment's server half: confirm retires the self plan
-- (history intact); flag records the dispute state.
create or replace function public.care_confirm_reconciliation(
  p_plan_id text, p_action text, p_prior_self_plan_id text default null
) returns void
language plpgsql volatile security definer set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_org uuid;
begin
  if v_uid is null then raise exception 'not signed in'; end if;
  if p_action not in ('confirmed','flagged') then
    raise exception 'unknown action.';
  end if;
  select r.org_id into v_org from public.regimen_plans r
   where r.id = p_plan_id and r.user_id = v_uid
     and r.authority = 'care_team' and r.ended_at is null;
  if not found then
    raise exception 'no active care-team plan to confirm.';
  end if;

  if p_action = 'confirmed' and p_prior_self_plan_id is not null then
    update public.regimen_plans
       set ended_at = now(), updated_at = now()
     where id = p_prior_self_plan_id and user_id = v_uid
       and authority = 'self' and ended_at is null;
  end if;

  perform private.log_care_event(v_org, v_uid, 'patient',
    'reconciliation.confirmed', v_uid, 'regimen', p_plan_id, 'success',
    jsonb_build_object('action', p_action));
end;
$$;

-- ============================================================
-- 6. RPCs — clinic side
-- ============================================================

-- Clinic actors are real accounts, never anonymous ones.
create or replace function public.care_create_org(p_name text)
returns jsonb
language plpgsql volatile security definer set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_org uuid;
begin
  if v_uid is null then raise exception 'not signed in'; end if;
  if coalesce((select auth.jwt() ->> 'is_anonymous')::boolean, false) then
    raise exception 'a clinic account needs a signed-in email account.';
  end if;
  if length(trim(coalesce(p_name, ''))) < 2 or length(p_name) > 120 then
    raise exception 'give the organization a real name.';
  end if;

  insert into public.organizations (name) values (trim(p_name))
  returning id into v_org;
  insert into public.org_members (org_id, user_id, role, display_name)
  values (v_org, v_uid, 'owner', '');

  perform private.log_care_event(v_org, v_uid, 'owner',
    'org.created', null, 'organization', v_org::text);
  return jsonb_build_object('org_id', v_org, 'name', trim(p_name));
end;
$$;

create or replace function public.care_add_member(
  p_org uuid, p_email text, p_role text,
  p_display_name text default '', p_credential text default null
) returns void
language plpgsql volatile security definer set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_target uuid;
begin
  if not private.has_org_role(p_org, array['owner']) then
    raise exception 'only the organization owner can add members.';
  end if;
  if p_role not in ('owner','clinician','staff') then
    raise exception 'unknown role.';
  end if;
  select u.id into v_target from auth.users u
   where lower(u.email) = lower(trim(p_email)) limit 1;
  if not found then
    raise exception 'no account with that email yet. have them sign up first.';
  end if;
  insert into public.org_members (org_id, user_id, role, display_name, credential_label)
  values (p_org, v_target, p_role, coalesce(p_display_name, ''), p_credential)
  on conflict (org_id, user_id)
  do update set role = excluded.role, status = 'active',
                display_name = excluded.display_name,
                credential_label = excluded.credential_label;
  perform private.log_care_event(p_org, v_uid, 'owner',
    'member.added', null, 'member', v_target::text,
    'success', jsonb_build_object('role', p_role));
end;
$$;

create or replace function public.care_set_member_status(
  p_org uuid, p_user uuid, p_status text
) returns void
language plpgsql volatile security definer set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
begin
  if not private.has_org_role(p_org, array['owner']) then
    raise exception 'only the organization owner can change member status.';
  end if;
  if p_status not in ('active','disabled') then
    raise exception 'unknown status.';
  end if;
  if p_user = v_uid and p_status = 'disabled' then
    raise exception 'you can''t disable yourself.';
  end if;
  update public.org_members set status = p_status
   where org_id = p_org and user_id = p_user;
  perform private.log_care_event(p_org, v_uid, 'owner',
    'member.status_set', null, 'member', p_user::text,
    'success', jsonb_build_object('status', p_status));
end;
$$;

-- Any active member may hand a patient a code (clerical act).
-- p_expires_minutes: the front desk may shorten the window
-- (clamped 5 min – 7 days; default 72h).
-- Drop the earlier two-arg shape so PostgREST never sees an
-- ambiguous overload (safe: the RPC never shipped to a client).
drop function if exists public.care_create_invitation(uuid, text);
create or replace function public.care_create_invitation(
  p_org uuid, p_label text, p_expires_minutes int default 4320
) returns jsonb
language plpgsql volatile security definer set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_code text;
  v_id uuid;
  v_expires timestamptz :=
    now() + make_interval(mins => greatest(5, least(10080, coalesce(p_expires_minutes, 4320))));
begin
  if not private.is_active_member(p_org) then
    raise exception 'not a member of this organization.';
  end if;
  if length(trim(coalesce(p_label, ''))) < 1 or length(p_label) > 80 then
    raise exception 'give the invitation a patient label.';
  end if;
  if (select count(*) from public.patient_invitations
      where org_id = p_org and status = 'pending' and expires_at > now()) >= 50 then
    raise exception 'too many open invitations.';
  end if;

  v_code := private.generate_code();
  insert into public.patient_invitations
    (org_id, created_by, code_hash, patient_label, expires_at)
  values (p_org, v_uid, private.hash_code(v_code), trim(p_label), v_expires)
  returning id into v_id;

  perform private.log_care_event(p_org, v_uid, private.actor_role_in(p_org),
    'invitation.created', null, 'invitation', v_id::text);

  -- The raw code exists exactly once: in this response.
  return jsonb_build_object(
    'id', v_id,
    'code', substr(v_code, 1, 4) || '-' || substr(v_code, 5, 4),
    'expires_at', v_expires
  );
end;
$$;

create or replace function public.care_cancel_invitation(p_id uuid)
returns void
language plpgsql volatile security definer set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_org uuid;
begin
  select org_id into v_org from public.patient_invitations where id = p_id;
  if not found or not private.is_active_member(v_org) then
    raise exception 'invitation not found.';
  end if;
  update public.patient_invitations set status = 'cancelled'
   where id = p_id and status = 'pending';
  perform private.log_care_event(v_org, v_uid, private.actor_role_in(v_org),
    'invitation.cancelled', null, 'invitation', p_id::text);
end;
$$;

-- The roster: labels + states + packet freshness + open work.
-- No health values. needs_attention derives from the packet's own
-- generated flags (deterministic; no new scoring).
create or replace function public.care_list_patients(p_org uuid)
returns jsonb
language plpgsql stable security definer set search_path = ''
as $$
declare
  v_out jsonb;
begin
  if not private.is_active_member(p_org) then
    raise exception 'not a member of this organization.';
  end if;
  select coalesce(jsonb_agg(pt.j order by (pt.j->>'established_at') desc), '[]'::jsonb)
    into v_out
  from (
    select jsonb_build_object(
      'patient_id', r.patient_id,
      'label', r.patient_label,
      'status', r.status,
      'established_at', r.established_at,
      'ended_at', r.ended_at,
      'follow_up_on', r.follow_up_on,
      'reviewed_at', r.reviewed_at,
      'packet_generated_at', vp.generated_at,
      'open_corrections', (
        select count(*) from public.correction_requests c
        where c.org_id = p_org and c.patient_id = r.patient_id
          and c.status = 'open'),
      'scopes', (
        select coalesce(array_agg(g.scope), array[]::text[])
        from public.consent_grants g
        where g.user_id = r.patient_id and g.org_id = p_org
          and g.revoked_at is null),
      'needs_attention', coalesce((
        select exists (
          select 1 from jsonb_array_elements(coalesce(vp.payload->'questions', '[]'::jsonb)) q
          where q->>'origin' = 'generated')), false)
    ) as j
    from public.care_relationships r
    left join public.visit_packets vp
      on vp.user_id = r.patient_id and vp.org_id = p_org
    where r.org_id = p_org
  ) pt;
  return v_out;
end;
$$;

-- One audited open per patient chart. Self-plan presence is
-- F1-masked: schedule facts only, never her words.
create or replace function public.care_open_patient_chart(p_org uuid, p_patient uuid)
returns jsonb
language plpgsql volatile security definer set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_rel record;
  v_scopes text[];
  v_out jsonb;
begin
  if not private.is_active_member(p_org) then
    raise exception 'not a member of this organization.';
  end if;
  select * into v_rel from public.care_relationships r
   where r.org_id = p_org and r.patient_id = p_patient
   order by (r.status = 'active') desc, r.established_at desc
   limit 1;
  if not found then
    raise exception 'no relationship with this patient.';
  end if;

  select coalesce(array_agg(g.scope), array[]::text[]) into v_scopes
    from public.consent_grants g
   where g.user_id = p_patient and g.org_id = p_org and g.revoked_at is null;

  v_out := jsonb_build_object(
    'relationship', jsonb_build_object(
      'id', v_rel.id, 'status', v_rel.status, 'label', v_rel.patient_label,
      'established_at', v_rel.established_at, 'ended_at', v_rel.ended_at,
      'follow_up_on', v_rel.follow_up_on, 'reviewed_at', v_rel.reviewed_at),
    'scopes', to_jsonb(v_scopes),
    'lookback_start', private.consent_window_start(p_patient, p_org),
    'assignment', (
      select jsonb_build_object(
        'id', a.id, 'protocol_id', a.protocol_id, 'status', a.status,
        'assigned_at', a.assigned_at, 'assigned_by', a.assigned_by,
        'protocol_title', p.title, 'protocol_version', p.version)
      from public.protocol_assignments a
      join public.protocols p on p.id = a.protocol_id
      where a.patient_id = p_patient and a.org_id = p_org and a.status = 'active'
      limit 1),
    'care_team_regimens', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', r.id, 'display_name', r.display_name,
        'strength_value', r.strength_value, 'strength_unit', r.strength_unit,
        'anchor_weekday', r.anchor_weekday, 'schedule_rule', r.schedule_rule,
        'instruction', r.instruction,
        'started_at', r.started_at, 'ended_at', r.ended_at,
        'updated_at', r.updated_at)
        order by r.created_at desc), '[]'::jsonb)
      from public.regimen_plans r
      where r.user_id = p_patient and r.org_id = p_org
        and r.authority = 'care_team' and r.kind = 'medication'),
    'self_regimen', case
      when v_rel.status = 'active'
           and ('observation_view' = any(v_scopes) or 'care_assignment' = any(v_scopes))
      then (
        select jsonb_build_object(
          'exists', true,
          'anchor_weekday', r.anchor_weekday,
          'started_at', r.started_at)
        from public.regimen_plans r
        where r.user_id = p_patient and r.authority = 'self'
          and r.kind = 'medication' and r.ended_at is null
        order by r.created_at desc limit 1)
      else null end,
    'corrections', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', c.id, 'regimen_plan_id', c.regimen_plan_id,
        'category', c.category, 'note', c.note, 'status', c.status,
        'resolution_note', c.resolution_note,
        'created_at', c.created_at, 'resolved_at', c.resolved_at)
        order by c.created_at desc), '[]'::jsonb)
      from public.correction_requests c
      where c.org_id = p_org and c.patient_id = p_patient),
    'packet_meta', (
      select jsonb_build_object(
        'generated_at', vp.generated_at,
        'window_start', vp.window_start, 'window_end', vp.window_end)
      from public.visit_packets vp
      where vp.user_id = p_patient and vp.org_id = p_org)
  );

  perform private.log_care_event(p_org, v_uid, private.actor_role_in(p_org),
    'chart.opened', p_patient, 'relationship', v_rel.id::text);
  return v_out;
end;
$$;

create or replace function public.care_get_visit_packet(p_org uuid, p_patient uuid)
returns jsonb
language plpgsql volatile security definer set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_row record;
begin
  if not private.is_active_member(p_org) then
    raise exception 'not a member of this organization.';
  end if;
  if not private.has_consent(p_patient, p_org, 'visit_packet_view') then
    raise exception 'no packet access for this patient.';
  end if;
  select * into v_row from public.visit_packets
   where user_id = p_patient and org_id = p_org;
  if not found then
    perform private.log_care_event(p_org, v_uid, private.actor_role_in(p_org),
      'packet.viewed', p_patient, 'packet', null, 'empty');
    return null;
  end if;
  perform private.log_care_event(p_org, v_uid, private.actor_role_in(p_org),
    'packet.viewed', p_patient, 'packet', v_row.id);
  return jsonb_build_object(
    'payload', v_row.payload,
    'generated_at', v_row.generated_at,
    'window_start', v_row.window_start,
    'window_end', v_row.window_end,
    'app_version', v_row.app_version);
end;
$$;

-- Underlying series: whitelisted observation kinds + weigh-ins,
-- clamped to her lookback. journalNote / feeling / tonightPlan /
-- daySealed are structurally excluded.
create or replace function public.care_get_patient_series(p_org uuid, p_patient uuid)
returns jsonb
language plpgsql volatile security definer set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_start date;
  v_obs jsonb;
  v_weights jsonb;
begin
  if not private.is_active_member(p_org) then
    raise exception 'not a member of this organization.';
  end if;
  if not private.has_consent(p_patient, p_org, 'observation_view') then
    raise exception 'no observation access for this patient.';
  end if;
  v_start := coalesce(private.consent_window_start(p_patient, p_org), now()::date);

  select coalesce(jsonb_agg(jsonb_build_object(
    'kind', o.kind, 'day_key', o.day_key, 'value_text', o.value_text,
    'value_num', o.value_num, 'source', o.source)
    order by o.day_key desc), '[]'::jsonb)
    into v_obs
  from public.observations o
  where o.user_id = p_patient
    and o.kind in ('doseTaken','sitCheck','hydration')
    and o.day_key >= to_char(v_start, 'YYYY-MM-DD');

  select coalesce(jsonb_agg(jsonb_build_object(
    'logged_at', w.logged_at, 'weight_kg', w.weight_kg, 'source', w.source)
    order by w.logged_at desc), '[]'::jsonb)
    into v_weights
  from public.weight_logs w
  where w.user_id = p_patient and w.logged_at >= v_start;

  perform private.log_care_event(p_org, v_uid, private.actor_role_in(p_org),
    'series.viewed', p_patient, 'series', null, 'success',
    jsonb_build_object(
      'observation_count', jsonb_array_length(v_obs),
      'weight_count', jsonb_array_length(v_weights)));

  return jsonb_build_object(
    'window_start', v_start,
    'observations', v_obs,
    'weights', v_weights);
end;
$$;

-- Assign an approved protocol row (the org's own, or the public
-- default). Replacement is explicit and audited.
create or replace function public.care_assign_protocol(
  p_org uuid, p_patient uuid, p_protocol_id text
) returns void
language plpgsql volatile security definer set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_proto record;
begin
  if not private.has_org_role(p_org, array['owner','clinician']) then
    raise exception 'only a clinician can assign care.';
  end if;
  if not private.has_consent(p_patient, p_org, 'care_assignment') then
    raise exception 'no assignment consent for this patient.';
  end if;
  select * into v_proto from public.protocols
   where id = p_protocol_id and (org_id = p_org or org_id is null);
  if not found then
    raise exception 'protocol not available to this organization.';
  end if;

  update public.protocol_assignments
     set status = 'replaced', replaced_at = now()
   where patient_id = p_patient and status = 'active';

  insert into public.protocol_assignments
    (org_id, patient_id, protocol_id, assigned_by)
  values (p_org, p_patient, p_protocol_id, v_uid);

  perform private.log_care_event(p_org, v_uid, private.actor_role_in(p_org),
    'protocol.assigned', p_patient, 'protocol', p_protocol_id);
end;
$$;

-- Approved-template-plus-bounded-tuning: the org's protocol is the
-- consumer default with ONLY supports + title authored. No
-- clinical numbers pass through this door.
create or replace function public.care_create_org_protocol(
  p_org uuid, p_title text, p_supports jsonb default '[]'::jsonb
) returns text
language plpgsql volatile security definer set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_default jsonb;
  v_id text;
  v_item jsonb;
begin
  if not private.has_org_role(p_org, array['owner','clinician']) then
    raise exception 'only a clinician can author the protocol.';
  end if;
  if length(trim(coalesce(p_title, ''))) < 2 or length(p_title) > 120 then
    raise exception 'give the protocol a title.';
  end if;
  if jsonb_typeof(p_supports) <> 'array' or jsonb_array_length(p_supports) > 12 then
    raise exception 'supports must be a short list.';
  end if;
  for v_item in select * from jsonb_array_elements(p_supports) loop
    if length(coalesce(v_item->>'kind', '')) not between 1 and 40
       or length(coalesce(v_item->>'note', '')) > 200 then
      raise exception 'each support needs a short kind and an optional short note.';
    end if;
  end loop;

  select payload into v_default from public.protocols where id = 'jenifit.default';
  if not found then raise exception 'default protocol missing.'; end if;

  v_id := 'org-' || replace(p_org::text, '-', '') || '-v1';
  insert into public.protocols (id, org_id, title, version, payload, published_at)
  values (
    v_id, p_org, trim(p_title), 1,
    jsonb_set(jsonb_set(v_default, '{id}', to_jsonb(v_id)),
              '{supports}', p_supports),
    now())
  on conflict (id) do update
    set title = excluded.title,
        payload = excluded.payload,
        version = public.protocols.version + 1,
        updated_at = now();

  perform private.log_care_event(p_org, v_uid, private.actor_role_in(p_org),
    'protocol.authored', null, 'protocol', v_id);
  return v_id;
end;
$$;

-- The care-team regimen: name · mg per administration · weekly
-- anchor · start date · optional instruction. mg ONLY (FDA 2024
-- mg/mL/units confusion). One active care-team plan per org.
create or replace function public.care_assign_regimen(
  p_org uuid, p_patient uuid, p_name text, p_strength_mg numeric,
  p_anchor_weekday int, p_started_on date, p_instruction text default null
) returns text
language plpgsql volatile security definer set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_id text;
begin
  if not private.has_org_role(p_org, array['owner','clinician']) then
    raise exception 'only a clinician can assign a regimen.';
  end if;
  if not private.has_consent(p_patient, p_org, 'care_assignment') then
    raise exception 'no assignment consent for this patient.';
  end if;
  if length(trim(coalesce(p_name, ''))) < 1 or length(p_name) > 80 then
    raise exception 'the medication needs a patient-facing name.';
  end if;
  if p_strength_mg is null or p_strength_mg <= 0 or p_strength_mg > 50 then
    raise exception 'dose must be in mg per administration (0–50).';
  end if;
  if p_anchor_weekday not between 1 and 7 then
    raise exception 'pick the weekly day.';
  end if;
  if p_started_on is null
     or p_started_on < now()::date - 365 or p_started_on > now()::date + 60 then
    raise exception 'start date out of range.';
  end if;
  if length(coalesce(p_instruction, '')) > 140 then
    raise exception 'instruction is too long.';
  end if;
  if exists (
    select 1 from public.regimen_plans r
    where r.user_id = p_patient and r.org_id = p_org
      and r.authority = 'care_team' and r.kind = 'medication'
      and r.ended_at is null
  ) then
    raise exception 'an active plan already exists — update it instead.';
  end if;

  v_id := gen_random_uuid()::text;
  insert into public.regimen_plans
    (id, user_id, kind, display_name, schedule_rule, anchor_weekday,
     strength_value, strength_unit, instruction, started_at,
     authority, org_id, reminder_enabled)
  values
    (v_id, p_patient, 'medication', trim(p_name), 'weeklyAnchor',
     p_anchor_weekday, p_strength_mg, 'mg', nullif(trim(coalesce(p_instruction,'')), ''),
     p_started_on::timestamptz, 'care_team', p_org, false);

  perform private.log_care_event(p_org, v_uid, private.actor_role_in(p_org),
    'regimen.assigned', p_patient, 'regimen', v_id);
  return v_id;
end;
$$;

-- Update = a new confirmed state of the same record (fields
-- optional; audit carries which ones moved, never their values).
-- Optionally closes a correction as accepted.
create or replace function public.care_update_regimen(
  p_org uuid, p_regimen_id text, p_name text default null,
  p_strength_mg numeric default null, p_anchor_weekday int default null,
  p_instruction text default null, p_correction_id uuid default null
) returns void
language plpgsql volatile security definer set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_row record;
  v_changed text[] := array[]::text[];
begin
  if not private.has_org_role(p_org, array['owner','clinician']) then
    raise exception 'only a clinician can update a regimen.';
  end if;
  select * into v_row from public.regimen_plans r
   where r.id = p_regimen_id and r.org_id = p_org
     and r.authority = 'care_team' and r.ended_at is null
   for update;
  if not found then
    raise exception 'no active care-team plan with that id.';
  end if;
  if not private.has_consent(v_row.user_id, p_org, 'care_assignment') then
    raise exception 'no assignment consent for this patient.';
  end if;

  if p_name is not null then
    if length(trim(p_name)) < 1 or length(p_name) > 80 then
      raise exception 'bad name.';
    end if;
    v_changed := array_append(v_changed, 'name');
  end if;
  if p_strength_mg is not null then
    if p_strength_mg <= 0 or p_strength_mg > 50 then
      raise exception 'dose must be in mg per administration (0–50).';
    end if;
    v_changed := array_append(v_changed, 'strength');
  end if;
  if p_anchor_weekday is not null then
    if p_anchor_weekday not between 1 and 7 then
      raise exception 'bad weekday.';
    end if;
    v_changed := array_append(v_changed, 'schedule');
  end if;
  if p_instruction is not null then
    if length(p_instruction) > 140 then
      raise exception 'instruction is too long.';
    end if;
    v_changed := array_append(v_changed, 'instruction');
  end if;

  update public.regimen_plans
     set display_name = coalesce(trim(p_name), display_name),
         strength_value = coalesce(p_strength_mg, strength_value),
         strength_unit = 'mg',
         anchor_weekday = coalesce(p_anchor_weekday, anchor_weekday),
         instruction = case when p_instruction is not null
                            then nullif(trim(p_instruction), '')
                            else instruction end,
         updated_at = now()
   where id = p_regimen_id;

  if p_correction_id is not null then
    update public.correction_requests
       set status = 'accepted', resolved_by = v_uid, resolved_at = now()
     where id = p_correction_id and org_id = p_org and status = 'open';
    perform private.log_care_event(p_org, v_uid, private.actor_role_in(p_org),
      'correction.resolved', v_row.user_id, 'correction', p_correction_id::text,
      'success', jsonb_build_object('resolution', 'accepted'));
  end if;

  perform private.log_care_event(p_org, v_uid, private.actor_role_in(p_org),
    'regimen.updated', v_row.user_id, 'regimen', p_regimen_id,
    'success', jsonb_build_object('fields', v_changed));
end;
$$;

create or replace function public.care_end_regimen(
  p_org uuid, p_regimen_id text, p_correction_id uuid default null
) returns void
language plpgsql volatile security definer set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_row record;
begin
  if not private.has_org_role(p_org, array['owner','clinician']) then
    raise exception 'only a clinician can end a regimen.';
  end if;
  select * into v_row from public.regimen_plans r
   where r.id = p_regimen_id and r.org_id = p_org
     and r.authority = 'care_team' and r.ended_at is null
   for update;
  if not found then
    raise exception 'no active care-team plan with that id.';
  end if;

  update public.regimen_plans
     set ended_at = now(), updated_at = now()
   where id = p_regimen_id;

  if p_correction_id is not null then
    update public.correction_requests
       set status = 'accepted', resolved_by = v_uid, resolved_at = now()
     where id = p_correction_id and org_id = p_org and status = 'open';
    perform private.log_care_event(p_org, v_uid, private.actor_role_in(p_org),
      'correction.resolved', v_row.user_id, 'correction', p_correction_id::text,
      'success', jsonb_build_object('resolution', 'accepted'));
  end if;

  perform private.log_care_event(p_org, v_uid, private.actor_role_in(p_org),
    'regimen.ended', v_row.user_id, 'regimen', p_regimen_id);
end;
$$;

-- Dismissal needs a brief plain-language reason (164.526 shape).
-- Acceptance happens through care_update_regimen / care_end_regimen.
create or replace function public.care_resolve_correction(
  p_org uuid, p_correction_id uuid, p_note text
) returns void
language plpgsql volatile security definer set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_row record;
begin
  if not private.has_org_role(p_org, array['owner','clinician']) then
    raise exception 'only a clinician can resolve a correction.';
  end if;
  if length(trim(coalesce(p_note, ''))) < 2 or length(p_note) > 200 then
    raise exception 'give a brief reason.';
  end if;
  select * into v_row from public.correction_requests
   where id = p_correction_id and org_id = p_org and status = 'open'
   for update;
  if not found then
    raise exception 'no open request with that id.';
  end if;
  update public.correction_requests
     set status = 'dismissed', resolution_note = trim(p_note),
         resolved_by = v_uid, resolved_at = now()
   where id = p_correction_id;
  perform private.log_care_event(p_org, v_uid, private.actor_role_in(p_org),
    'correction.resolved', v_row.patient_id, 'correction', p_correction_id::text,
    'success', jsonb_build_object('resolution', 'dismissed'));
end;
$$;

create or replace function public.care_set_patient_review(
  p_org uuid, p_patient uuid, p_follow_up_on date default null,
  p_mark_reviewed boolean default false
) returns void
language plpgsql volatile security definer set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_rel uuid;
begin
  if not private.has_org_role(p_org, array['owner','clinician']) then
    raise exception 'only a clinician can set review status.';
  end if;
  select id into v_rel from public.care_relationships
   where org_id = p_org and patient_id = p_patient and status = 'active';
  if not found then
    raise exception 'no active relationship with this patient.';
  end if;
  update public.care_relationships
     set follow_up_on = coalesce(p_follow_up_on, follow_up_on),
         reviewed_at = case when p_mark_reviewed then now() else reviewed_at end
   where id = v_rel;
  perform private.log_care_event(p_org, v_uid, private.actor_role_in(p_org),
    'relationship.review_set', p_patient, 'relationship', v_rel::text,
    'success', jsonb_build_object('marked_reviewed', p_mark_reviewed));
end;
$$;

-- ============================================================
-- 7. Function grants (revoke PUBLIC default, grant precisely)
-- ============================================================

revoke execute on function public.care_preview_invitation(text) from public, anon;
revoke execute on function public.care_accept_invitation(text, int, text[]) from public, anon;
revoke execute on function public.care_revoke_consent(uuid, text, boolean) from public, anon;
revoke execute on function public.care_submit_correction(uuid, text, text, text) from public, anon;
revoke execute on function public.care_confirm_reconciliation(text, text, text) from public, anon;
revoke execute on function public.care_create_org(text) from public, anon;
revoke execute on function public.care_add_member(uuid, text, text, text, text) from public, anon;
revoke execute on function public.care_set_member_status(uuid, uuid, text) from public, anon;
revoke execute on function public.care_create_invitation(uuid, text, int) from public, anon;
revoke execute on function public.care_cancel_invitation(uuid) from public, anon;
revoke execute on function public.care_list_patients(uuid) from public, anon;
revoke execute on function public.care_open_patient_chart(uuid, uuid) from public, anon;
revoke execute on function public.care_get_visit_packet(uuid, uuid) from public, anon;
revoke execute on function public.care_get_patient_series(uuid, uuid) from public, anon;
revoke execute on function public.care_assign_protocol(uuid, uuid, text) from public, anon;
revoke execute on function public.care_create_org_protocol(uuid, text, jsonb) from public, anon;
revoke execute on function public.care_assign_regimen(uuid, uuid, text, numeric, int, date, text) from public, anon;
revoke execute on function public.care_update_regimen(uuid, text, text, numeric, int, text, uuid) from public, anon;
revoke execute on function public.care_end_regimen(uuid, text, uuid) from public, anon;
revoke execute on function public.care_resolve_correction(uuid, uuid, text) from public, anon;
revoke execute on function public.care_set_patient_review(uuid, uuid, date, boolean) from public, anon;

grant execute on function public.care_preview_invitation(text) to authenticated;
grant execute on function public.care_accept_invitation(text, int, text[]) to authenticated;
grant execute on function public.care_revoke_consent(uuid, text, boolean) to authenticated;
grant execute on function public.care_submit_correction(uuid, text, text, text) to authenticated;
grant execute on function public.care_confirm_reconciliation(text, text, text) to authenticated;
grant execute on function public.care_create_org(text) to authenticated;
grant execute on function public.care_add_member(uuid, text, text, text, text) to authenticated;
grant execute on function public.care_set_member_status(uuid, uuid, text) to authenticated;
grant execute on function public.care_create_invitation(uuid, text, int) to authenticated;
grant execute on function public.care_cancel_invitation(uuid) to authenticated;
grant execute on function public.care_list_patients(uuid) to authenticated;
grant execute on function public.care_open_patient_chart(uuid, uuid) to authenticated;
grant execute on function public.care_get_visit_packet(uuid, uuid) to authenticated;
grant execute on function public.care_get_patient_series(uuid, uuid) to authenticated;
grant execute on function public.care_assign_protocol(uuid, uuid, text) to authenticated;
grant execute on function public.care_create_org_protocol(uuid, text, jsonb) to authenticated;
grant execute on function public.care_assign_regimen(uuid, uuid, text, numeric, int, date, text) to authenticated;
grant execute on function public.care_update_regimen(uuid, text, text, numeric, int, text, uuid) to authenticated;
grant execute on function public.care_end_regimen(uuid, text, uuid) to authenticated;
grant execute on function public.care_resolve_correction(uuid, uuid, text) to authenticated;
grant execute on function public.care_set_patient_review(uuid, uuid, date, boolean) to authenticated;

-- Private helpers are never callable through the API (the schema is
-- not in PostgREST's exposed list), but RLS POLICY EXPRESSIONS run
-- as the querying role — so `authenticated` needs USAGE on the
-- schema plus EXECUTE on exactly the predicates that policies
-- reference. Everything else in `private` stays definer-only.
revoke execute on all functions in schema private from public, anon, authenticated;
grant usage on schema private to authenticated;
grant execute on function private.is_active_member(uuid) to authenticated;
grant execute on function private.is_related_patient(uuid) to authenticated;
grant execute on function private.can_publish_packet(uuid, uuid) to authenticated;
grant execute on function private.has_active_assignment(uuid, text) to authenticated;

-- PostgREST picks up the new surface without a redeploy.
notify pgrst, 'reload schema';
