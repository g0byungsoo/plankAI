-- App v8 S5 (2026-07-30) — pilot-ready Jeni Care.
-- docs/app_v8/11_S5_PILOT_READY.md is the law this file implements.
--
-- What this adds, additively and idempotently:
--   1. Environment identity — the server DECLARES which environment
--      it is (private.config 'environment'); clients verify and wear
--      the right badge. Safe defaults: an unprovisioned project reads
--      as 'development' (visible), and org creation defaults to
--      'restricted' unless a project explicitly opens it.
--   2. Role law (S5-2): clinical assignment authority becomes
--      explicit. role='clinician' carries it; an OWNER holds it only
--      when marked as a clinician; staff can never hold it. Existing
--      owner rows are grandfathered true (documented back-compat).
--   3. Organization suspension: organizations.status; every member
--      helper requires an ACTIVE org, so suspension freezes clinic
--      access server-side in one place. Patient rights (revoke,
--      correction) never gate on org status.
--   4. Gated org creation: in 'restricted' mode, care_create_org
--      requires a founder-issued single-use provisioning code
--      (operator-minted; hashes only, same pepper discipline).
--   5. Clinic administration: care_set_member_role (owner-only,
--      last-owner protected), last-owner guard on status changes,
--      care_end_relationship (clinic-side administrative end).
--   6. Demo tenancy: organizations.is_demo — demo clinics are
--      visibly demo and reset tooling refuses everything else.
--   7. pilot_requests + care_submit_pilot_request: the website's
--      founder-facing conversion path. Anon-callable, bounded,
--      honeypotted, throttled. No API role can read it back.
--   8. ops_events + care_log_client_event: minimum operational
--      visibility with STRUCTURAL redaction — single-token fields
--      only; prose is rejected at the server, so medication names /
--      weights / symptoms are unrepresentable.
--
-- Never changed: patient-owned rows, S4 RPC disclosure posture,
-- append-only audit, consent law, F1 masking, org-null consumers.

-- ============================================================
-- 0. Config seeds (environment + org-creation mode)
-- ============================================================

-- This migration runs on the existing development project first:
-- name it explicitly. A future staging/pilot project runs the same
-- chain and then SETS its own values per the provisioning runbook
-- (scripts/care_env_provision.md). Absent keys read as
-- 'development' + 'restricted' (visible badge, closed creation).
insert into private.config (key, value)
select 'environment', 'development'
where not exists (select 1 from private.config where key = 'environment');

insert into private.config (key, value)
select 'org_creation_mode', 'open'
where not exists (select 1 from private.config where key = 'org_creation_mode');

-- ============================================================
-- 1. Schema additions
-- ============================================================

alter table public.organizations
  add column if not exists status text not null default 'active';
do $$ begin
  alter table public.organizations
    add constraint organizations_status_check
    check (status in ('active','suspended'));
exception when duplicate_object then null; end $$;

alter table public.organizations
  add column if not exists is_demo boolean not null default false;

alter table public.org_members
  add column if not exists clinical_authority boolean not null default false;
do $$ begin
  alter table public.org_members
    add constraint org_members_staff_not_clinical
    check (not (role = 'staff' and clinical_authority));
exception when duplicate_object then null; end $$;

-- Back-compat grandfather (documented in 04_DECISIONS S5-2): every
-- membership that predates this migration and could already assign
-- care keeps that ability. The S5 rule (owners must be explicitly
-- marked clinical) applies to every membership created after it.
update public.org_members set clinical_authority = true
 where role in ('owner','clinician') and clinical_authority = false;

-- Founder-issued org provisioning codes (restricted mode). Minted
-- ONLY by the operator (service role / runbook SQL) — no API mint.
create table if not exists private.org_provisioning_codes (
  id uuid primary key default gen_random_uuid(),
  code_hash text not null unique,
  label text not null default '',
  status text not null default 'pending'
    check (status in ('pending','used','cancelled')),
  expires_at timestamptz not null,
  used_by uuid,
  used_org uuid,
  used_at timestamptz,
  created_at timestamptz not null default now()
);

-- The website's pilot-request inbox. NO API role may read it —
-- the founder reads via Studio/SQL (ops runbook). Insert happens
-- only inside the definer RPC below.
create table if not exists public.pilot_requests (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  email text not null,
  clinic text not null,
  role text,
  glp1_volume text,
  workflow text,
  pain text,
  contact_pref text,
  status text not null default 'new'
    check (status in ('new','contacted','closed')),
  created_at timestamptz not null default now()
);
revoke all on public.pilot_requests from public, anon, authenticated;
alter table public.pilot_requests enable row level security;

-- Operational events. Single-token fields only (enforced in the
-- RPC): kind/code/rpc/trace/build carry NO prose, so clinical
-- content is structurally unrepresentable here. No API role reads.
create table if not exists public.ops_events (
  id bigint generated always as identity primary key,
  occurred_at timestamptz not null default now(),
  actor_id uuid,
  surface text not null,
  kind text not null,
  code text,
  rpc text,
  status int,
  trace_id text,
  build text,
  env text
);
revoke all on public.ops_events from public, anon, authenticated;
alter table public.ops_events enable row level security;
create index if not exists ops_events_time_idx on public.ops_events (occurred_at desc);

-- ============================================================
-- 2. Helper law changes (suspension + clinical authority)
-- ============================================================

-- Membership now requires an ACTIVE organization: suspending an org
-- freezes every member read/RPC in one place (policies + guards all
-- route through these helpers).
create or replace function private.is_active_member(p_org uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.org_members m
    join public.organizations o on o.id = m.org_id
    where m.org_id = p_org
      and m.user_id = (select auth.uid())
      and m.status = 'active'
      and o.status = 'active'
  );
$$;

create or replace function private.has_org_role(p_org uuid, p_roles text[])
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.org_members m
    join public.organizations o on o.id = m.org_id
    where m.org_id = p_org
      and m.user_id = (select auth.uid())
      and m.status = 'active'
      and o.status = 'active'
      and m.role = any (p_roles)
  );
$$;

-- S5 role law: clinicians hold clinical authority by role; owners
-- hold it only when explicitly marked; staff never do.
create or replace function private.has_clinical_authority(p_org uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.org_members m
    join public.organizations o on o.id = m.org_id
    where m.org_id = p_org
      and m.user_id = (select auth.uid())
      and m.status = 'active'
      and o.status = 'active'
      and (m.role = 'clinician'
           or (m.role = 'owner' and m.clinical_authority))
  );
$$;

-- Publishing a packet to a suspended clinic is pointless and holds
-- data outside her device for nobody — require the org be active.
create or replace function private.can_publish_packet(p_user uuid, p_org uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select private.has_consent(p_user, p_org, 'visit_packet_view')
     and exists (select 1 from public.organizations o
                 where o.id = p_org and o.status = 'active');
$$;

create or replace function private.environment()
returns text
language sql stable security definer set search_path = ''
as $$
  select coalesce(
    (select value from private.config where key = 'environment'),
    'development');
$$;

-- ============================================================
-- 3. Clinical gates move to has_clinical_authority (7 RPCs)
-- ============================================================

create or replace function public.care_assign_protocol(
  p_org uuid, p_patient uuid, p_protocol_id text
) returns void
language plpgsql volatile security definer set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_proto record;
begin
  if not private.has_clinical_authority(p_org) then
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
  if not private.has_clinical_authority(p_org) then
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
  if not private.has_clinical_authority(p_org) then
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
  if not private.has_clinical_authority(p_org) then
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
  if not private.has_clinical_authority(p_org) then
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

create or replace function public.care_resolve_correction(
  p_org uuid, p_correction_id uuid, p_note text
) returns void
language plpgsql volatile security definer set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_row record;
begin
  if not private.has_clinical_authority(p_org) then
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
  if not private.has_clinical_authority(p_org) then
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
-- 4. Org creation: mode-gated + explicit owner clinical flag
-- ============================================================

-- Signature changes → drop the S4 shape so PostgREST never sees an
-- ambiguous overload (dashboard + fixtures update in the same pass).
drop function if exists public.care_create_org(text);

create or replace function public.care_create_org(
  p_name text,
  p_owner_is_clinician boolean default false,
  p_provision_code text default null
) returns jsonb
language plpgsql volatile security definer set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_org uuid;
  v_mode text := coalesce(
    (select value from private.config where key = 'org_creation_mode'),
    'restricted');
  v_code record;
begin
  if v_uid is null then raise exception 'not signed in'; end if;
  if coalesce((select auth.jwt() ->> 'is_anonymous')::boolean, false) then
    raise exception 'a clinic account needs a signed-in email account.';
  end if;
  if length(trim(coalesce(p_name, ''))) < 2 or length(p_name) > 120 then
    raise exception 'give the organization a real name.';
  end if;

  if v_mode <> 'open' then
    -- Restricted (staging/pilot default): a founder-issued
    -- single-use provisioning code is required. Same throttle and
    -- generic-failure discipline as patient invitations.
    perform private.check_invitation_rate(v_uid);
    select * into v_code from private.org_provisioning_codes
     where code_hash = private.hash_code(p_provision_code)
     for update;
    if not found or v_code.status <> 'pending' or v_code.expires_at <= now() then
      perform private.record_invitation_failure(v_uid);
      raise exception 'organization setup is invite-only right now. contact us for a pilot code.';
    end if;
    update private.org_provisioning_codes
       set status = 'used', used_by = v_uid, used_at = now()
     where id = v_code.id;
  end if;

  insert into public.organizations (name) values (trim(p_name))
  returning id into v_org;
  insert into public.org_members
    (org_id, user_id, role, display_name, clinical_authority)
  values (v_org, v_uid, 'owner', '', coalesce(p_owner_is_clinician, false));

  if v_mode <> 'open' then
    update private.org_provisioning_codes set used_org = v_org
     where code_hash = private.hash_code(p_provision_code);
  end if;

  perform private.log_care_event(v_org, v_uid, 'owner',
    'org.created', null, 'organization', v_org::text, 'success',
    jsonb_build_object('mode', v_mode,
                       'owner_clinical', coalesce(p_owner_is_clinician, false)));
  return jsonb_build_object('org_id', v_org, 'name', trim(p_name));
end;
$$;

-- ============================================================
-- 5. Membership administration
-- ============================================================

-- care_add_member gains the explicit clinical flag (derived when
-- absent: clinicians true, staff false, owners false — the S5 rule).
drop function if exists public.care_add_member(uuid, text, text, text, text);

create or replace function public.care_add_member(
  p_org uuid, p_email text, p_role text,
  p_display_name text default '', p_credential text default null,
  p_clinical boolean default null
) returns void
language plpgsql volatile security definer set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_target uuid;
  v_clinical boolean;
begin
  if not private.has_org_role(p_org, array['owner']) then
    raise exception 'only the organization owner can add members.';
  end if;
  if p_role not in ('owner','clinician','staff') then
    raise exception 'unknown role.';
  end if;
  v_clinical := case
    when p_role = 'clinician' then true
    when p_role = 'staff' then false
    else coalesce(p_clinical, false)
  end;
  select u.id into v_target from auth.users u
   where lower(u.email) = lower(trim(p_email)) limit 1;
  if not found then
    raise exception 'no account with that email yet. have them sign up first.';
  end if;
  insert into public.org_members
    (org_id, user_id, role, display_name, credential_label, clinical_authority)
  values (p_org, v_target, p_role, coalesce(p_display_name, ''), p_credential, v_clinical)
  on conflict (org_id, user_id)
  do update set role = excluded.role, status = 'active',
                display_name = excluded.display_name,
                credential_label = excluded.credential_label,
                clinical_authority = excluded.clinical_authority;
  perform private.log_care_event(p_org, v_uid, 'owner',
    'member.added', null, 'member', v_target::text,
    'success', jsonb_build_object('role', p_role, 'clinical', v_clinical));
end;
$$;

-- Role / clinical-authority change. Owner-only; the last active
-- owner can neither demote nor disable themselves out of the org.
create or replace function public.care_set_member_role(
  p_org uuid, p_user uuid, p_role text, p_clinical boolean default null
) returns void
language plpgsql volatile security definer set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_row record;
  v_clinical boolean;
begin
  if not private.has_org_role(p_org, array['owner']) then
    raise exception 'only the organization owner can change roles.';
  end if;
  if p_role not in ('owner','clinician','staff') then
    raise exception 'unknown role.';
  end if;
  select * into v_row from public.org_members
   where org_id = p_org and user_id = p_user for update;
  if not found then
    raise exception 'no such member.';
  end if;
  if v_row.role = 'owner' and p_role <> 'owner' and (
    select count(*) from public.org_members
    where org_id = p_org and role = 'owner' and status = 'active'
      and user_id <> p_user) = 0 then
    raise exception 'the organization needs at least one active owner.';
  end if;
  v_clinical := case
    when p_role = 'clinician' then true
    when p_role = 'staff' then false
    else coalesce(p_clinical, v_row.clinical_authority)
  end;
  update public.org_members
     set role = p_role, clinical_authority = v_clinical
   where org_id = p_org and user_id = p_user;
  perform private.log_care_event(p_org, v_uid, 'owner',
    'member.role_set', null, 'member', p_user::text,
    'success', jsonb_build_object('role', p_role, 'clinical', v_clinical));
end;
$$;

-- Status change keeps the self-guard and gains the last-owner guard.
create or replace function public.care_set_member_status(
  p_org uuid, p_user uuid, p_status text
) returns void
language plpgsql volatile security definer set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_row record;
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
  select * into v_row from public.org_members
   where org_id = p_org and user_id = p_user for update;
  if not found then
    raise exception 'no such member.';
  end if;
  if v_row.role = 'owner' and p_status = 'disabled' and (
    select count(*) from public.org_members
    where org_id = p_org and role = 'owner' and status = 'active'
      and user_id <> p_user) = 0 then
    raise exception 'the organization needs at least one active owner.';
  end if;
  update public.org_members set status = p_status
   where org_id = p_org and user_id = p_user;
  perform private.log_care_event(p_org, v_uid, 'owner',
    'member.status_set', null, 'member', p_user::text,
    'success', jsonb_build_object('status', p_status));
end;
$$;

-- Clinic-side administrative end of a relationship (patient left
-- the practice, pilot ended). Access-only, like revocation: her
-- records, provenance, audit, and any assigned plan's clinical
-- status survive. Re-connection later = a fresh invitation.
create or replace function public.care_end_relationship(
  p_org uuid, p_patient uuid
) returns void
language plpgsql volatile security definer set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_rel uuid;
begin
  if not private.has_org_role(p_org, array['owner','clinician']) then
    raise exception 'only a clinician or owner can end a care relationship.';
  end if;
  select id into v_rel from public.care_relationships
   where org_id = p_org and patient_id = p_patient and status = 'active';
  if not found then
    raise exception 'no active relationship with this patient.';
  end if;
  update public.care_relationships
     set status = 'ended', ended_at = now()
   where id = v_rel;
  update public.consent_grants
     set revoked_at = now()
   where user_id = p_patient and org_id = p_org and revoked_at is null;
  delete from public.visit_packets
   where user_id = p_patient and org_id = p_org;
  perform private.log_care_event(p_org, v_uid, private.actor_role_in(p_org),
    'relationship.ended', p_patient, 'relationship', v_rel::text);
end;
$$;

-- ============================================================
-- 6. Suspension checks on the invitation path
-- ============================================================

-- Preview/accept read the invitation row directly (not the member
-- helpers), so they need their own org-status check: a suspended
-- clinic's outstanding codes go quiet, generically.
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
     and i.expires_at > now()
     and o.status = 'active';
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

  select i.*, o.name as org_name, o.status as org_status into v_inv
    from public.patient_invitations i
    join public.organizations o on o.id = i.org_id
   where i.code_hash = private.hash_code(p_code)
   for update of i;

  if not found or v_inv.status <> 'pending' or v_inv.expires_at <= now()
     or v_inv.org_status <> 'active' then
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

-- ============================================================
-- 7. Environment identity + client ops events + pilot requests
-- ============================================================

-- Which environment is this server? Public metadata (no secrets):
-- clients wear the right badge and refuse silent misconfiguration.
-- min_dashboard_build (optional config) lets the operator flag
-- stale long-lived dashboard tabs.
create or replace function public.care_environment()
returns jsonb
language sql stable security definer set search_path = ''
as $$
  select jsonb_build_object(
    'environment', private.environment(),
    'min_dashboard_build',
    (select value from private.config where key = 'min_dashboard_build'));
$$;

-- Client-observed operational failures. STRUCTURAL redaction: every
-- field must be a single machine token (no whitespace, bounded
-- length, tight charset) — prose, names, doses, and symptoms are
-- unrepresentable. Unknown kinds and malformed fields are DROPPED
-- (never an error loop in the client); per-caller rate cap.
create or replace function public.care_log_client_event(
  p_surface text, p_kind text,
  p_code text default null, p_rpc text default null,
  p_status int default null, p_trace_id text default null,
  p_build text default null
) returns void
language plpgsql volatile security definer set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_token_re text := '^[A-Za-z0-9_.:-]+$';
begin
  if p_surface not in ('dashboard','ios','site') then return; end if;
  if p_kind is null or p_kind !~ v_token_re or length(p_kind) > 60 then return; end if;
  if p_kind not in (
    'auth.failed','auth.reset_failed',
    'roster.load_failed','chart.load_failed','packet.load_failed',
    'assign.protocol_failed','assign.regimen_failed',
    'correction.resolve_failed','correction.submit_failed',
    'invitation.create_failed','invitation.accept_failed',
    'member.manage_failed','org.create_failed',
    'hydration.failed','reconciliation.failed','revocation.failed',
    'packet.publish_failed','pilot_request.failed','client.error'
  ) then return; end if;
  if p_code is not null and (p_code !~ v_token_re or length(p_code) > 80) then return; end if;
  if p_rpc is not null and (p_rpc !~ v_token_re or length(p_rpc) > 60) then return; end if;
  if p_trace_id is not null and (p_trace_id !~ v_token_re or length(p_trace_id) > 40) then return; end if;
  if p_build is not null and (p_build !~ v_token_re or length(p_build) > 40) then return; end if;
  if p_status is not null and (p_status < 0 or p_status > 999) then return; end if;

  -- Cap: 30 events / 15 minutes per caller (anon callers share one
  -- null bucket capped the same way).
  if (select count(*) from public.ops_events
      where actor_id is not distinct from v_uid
        and occurred_at > now() - interval '15 minutes') >= 30 then
    return;
  end if;

  insert into public.ops_events
    (actor_id, surface, kind, code, rpc, status, trace_id, build, env)
  values
    (v_uid, p_surface, p_kind, p_code, p_rpc, p_status, p_trace_id, p_build,
     private.environment());
end;
$$;

-- The website's pilot-request path. Anon-callable; bounded fields;
-- honeypot + minimum-fill-time are silent drops (bots learn
-- nothing); global hourly cap fits the scale. No API role can read
-- the table back — the founder reads via the ops runbook.
create or replace function public.care_submit_pilot_request(
  p_name text, p_email text, p_clinic text,
  p_role text default null, p_glp1_volume text default null,
  p_workflow text default null, p_pain text default null,
  p_contact_pref text default null,
  p_website text default '',        -- honeypot: humans never fill it
  p_elapsed_ms int default 0
) returns jsonb
language plpgsql volatile security definer set search_path = ''
as $$
begin
  -- Silent accept for likely bots: nothing to learn from the reply.
  if coalesce(p_website, '') <> '' or coalesce(p_elapsed_ms, 0) < 2500 then
    return jsonb_build_object('ok', true);
  end if;

  if length(trim(coalesce(p_name, ''))) not between 2 and 80 then
    raise exception 'add your name.';
  end if;
  if p_email is null or p_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]{2,}$'
     or length(p_email) > 120 then
    raise exception 'add a work email.';
  end if;
  if length(trim(coalesce(p_clinic, ''))) not between 2 and 120 then
    raise exception 'add your clinic''s name.';
  end if;
  if p_role is not null and length(p_role) > 60 then
    raise exception 'role is too long.';
  end if;
  if p_glp1_volume is not null and p_glp1_volume not in
     ('under_25','25_100','100_500','500_plus','unsure') then
    raise exception 'unknown volume band.';
  end if;
  if length(coalesce(p_workflow, '')) > 600 or length(coalesce(p_pain, '')) > 600 then
    raise exception 'that answer is a little long — a sentence or two is plenty.';
  end if;
  if p_contact_pref is not null and p_contact_pref not in ('email','phone_note') then
    raise exception 'unknown contact preference.';
  end if;

  -- Global cap: 30/hour is far above any legitimate volume at pilot
  -- scale and keeps a scripted flood from filling the table.
  if (select count(*) from public.pilot_requests
      where created_at > now() - interval '1 hour') >= 30 then
    raise exception 'we''re receiving a lot of requests — please try again shortly.';
  end if;

  -- Idempotent per email/day: repeat submissions don't duplicate.
  if exists (select 1 from public.pilot_requests
             where lower(email) = lower(trim(p_email))
               and created_at > now() - interval '24 hours') then
    return jsonb_build_object('ok', true);
  end if;

  insert into public.pilot_requests
    (name, email, clinic, role, glp1_volume, workflow, pain, contact_pref)
  values
    (trim(p_name), trim(p_email), trim(p_clinic),
     nullif(trim(coalesce(p_role, '')), ''),
     p_glp1_volume,
     nullif(trim(coalesce(p_workflow, '')), ''),
     nullif(trim(coalesce(p_pain, '')), ''),
     p_contact_pref);
  return jsonb_build_object('ok', true);
end;
$$;

-- ============================================================
-- 8. Operator plumbing (service-role only)
-- ============================================================

-- The provisioning runbook and the deep security checks flip server
-- state (environment label, org-creation mode, provisioning codes)
-- through these two RPCs so no operator ever needs raw SQL. EXECUTE
-- is granted ONLY to service_role; anon/authenticated callers are
-- refused twice (grant + in-body check).
create or replace function public.care_ops_set_config(p_key text, p_value text)
returns void
language plpgsql volatile security definer set search_path = ''
as $$
begin
  if coalesce((select auth.jwt() ->> 'role'), '') <> 'service_role' then
    raise exception 'operator only.';
  end if;
  if p_key not in ('environment','org_creation_mode','min_dashboard_build') then
    raise exception 'unknown config key.';
  end if;
  if p_key = 'environment'
     and p_value not in ('development','staging','pilot','production') then
    raise exception 'unknown environment.';
  end if;
  if p_key = 'org_creation_mode' and p_value not in ('open','restricted') then
    raise exception 'unknown mode.';
  end if;
  insert into private.config (key, value) values (p_key, p_value)
  on conflict (key) do update set value = excluded.value;
end;
$$;

create or replace function public.care_ops_mint_provisioning_code(
  p_label text, p_expires_days int default 14
) returns jsonb
language plpgsql volatile security definer set search_path = ''
as $$
declare
  v_code text;
begin
  if coalesce((select auth.jwt() ->> 'role'), '') <> 'service_role' then
    raise exception 'operator only.';
  end if;
  if length(trim(coalesce(p_label, ''))) < 1 or length(p_label) > 120 then
    raise exception 'give the code a label.';
  end if;
  v_code := private.generate_code();
  insert into private.org_provisioning_codes (code_hash, label, expires_at)
  values (private.hash_code(v_code), trim(p_label),
          now() + make_interval(days => greatest(1, least(90, coalesce(p_expires_days, 14)))));
  -- The raw code exists exactly once: in this response.
  return jsonb_build_object(
    'code', substr(v_code, 1, 4) || '-' || substr(v_code, 5, 4),
    'label', trim(p_label));
end;
$$;

revoke execute on function public.care_ops_set_config(text, text) from public, anon, authenticated;
revoke execute on function public.care_ops_mint_provisioning_code(text, int) from public, anon, authenticated;
grant execute on function public.care_ops_set_config(text, text) to service_role;
grant execute on function public.care_ops_mint_provisioning_code(text, int) to service_role;

-- Explicit operator-surface table grants (never rely on implicit
-- default privileges): suspension flips, pilot-request triage, and
-- ops review are service-role acts, spelled out.
grant select, update on public.organizations to service_role;
grant select, update, delete on public.pilot_requests to service_role;
grant select, delete on public.ops_events to service_role;
-- Demo-tenant reset (scripts/care_demo.py) clears a demo org's
-- assignment rows; the script refuses any org without is_demo.
grant select, delete on public.protocol_assignments to service_role;

-- ============================================================
-- 9. Grants
-- ============================================================

revoke execute on function public.care_create_org(text, boolean, text) from public, anon;
revoke execute on function public.care_add_member(uuid, text, text, text, text, boolean) from public, anon;
revoke execute on function public.care_set_member_role(uuid, uuid, text, boolean) from public, anon;
revoke execute on function public.care_end_relationship(uuid, uuid) from public, anon;
revoke execute on function public.care_environment() from public;
revoke execute on function public.care_log_client_event(text, text, text, text, int, text, text) from public;
revoke execute on function public.care_submit_pilot_request(text, text, text, text, text, text, text, text, text, int) from public;

grant execute on function public.care_create_org(text, boolean, text) to authenticated;
grant execute on function public.care_add_member(uuid, text, text, text, text, boolean) to authenticated;
grant execute on function public.care_set_member_role(uuid, uuid, text, boolean) to authenticated;
grant execute on function public.care_end_relationship(uuid, uuid) to authenticated;
grant execute on function public.care_environment() to anon, authenticated;
grant execute on function public.care_log_client_event(text, text, text, text, int, text, text) to anon, authenticated;
grant execute on function public.care_submit_pilot_request(text, text, text, text, text, text, text, text, text, int) to anon, authenticated;

-- PostgREST picks up the new surface without a redeploy.
notify pgrst, 'reload schema';
