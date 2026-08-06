-- app v9 P6 — the between-visit longitudinal substrate (W10).
-- FOUNDER APPLIES (dev project now; pilot project when provisioned).
-- Additive + idempotent, the house convention.
--
-- care_weekly_summaries: INSERT-ONLY history (one row per patient ×
-- org × ISO week; the current week may upsert, prior weeks are never
-- rewritten — visit_packets stays the latest-snapshot surface, this
-- is the series). Patient-computed, deterministic, offline-valid —
-- NO AI in the clinic loop (v8 law). Clinician access is RPC-only
-- (the disclosure-audit chokepoint); no direct clinician policies.
--
-- Consent: rides the EXISTING visit_packet_view scope — the summary
-- is packet-class data at packet cadence (it publishes only when
-- her app runs, exactly like the packet). The D6 counsel review
-- covers the between-visit framing; the true dropout-risk flag
-- stays out until that lands.

create table if not exists public.care_weekly_summaries (
  id text primary key,                       -- "{user_id}-{org_id}-{week_key}"
  user_id uuid not null,
  org_id uuid not null,
  week_key text not null,                    -- ISO-monday "2026-07-28"
  payload jsonb not null,
  generated_at timestamptz not null default now(),
  app_version text,
  created_at timestamptz not null default now()
);

create index if not exists care_weekly_summaries_patient_org
  on public.care_weekly_summaries (user_id, org_id, week_key desc);

alter table public.care_weekly_summaries enable row level security;

do $$
begin
  execute 'drop policy if exists "cws_insert_own_consented" on public.care_weekly_summaries';
  execute 'drop policy if exists "cws_update_own_consented" on public.care_weekly_summaries';
  execute 'drop policy if exists "cws_select_own" on public.care_weekly_summaries';
  -- Patient writes her own rows, only while packet consent is active
  -- (the visit_packets stance verbatim). No delete policy — history
  -- is append-only for everyone at the policy layer.
  execute 'create policy "cws_insert_own_consented" on public.care_weekly_summaries for insert to authenticated with check (
      user_id = (select auth.uid())
      and exists (
        select 1 from public.consent_grants g
        where g.user_id = (select auth.uid())
          and g.org_id = care_weekly_summaries.org_id
          and g.scope = ''visit_packet_view''
          and g.revoked_at is null
      ))';
  -- The CURRENT week may re-publish (upsert); the id embeds the
  -- week, so an update can only ever touch that same week''s row.
  execute 'create policy "cws_update_own_consented" on public.care_weekly_summaries for update to authenticated using (
      user_id = (select auth.uid())
    ) with check (
      user_id = (select auth.uid())
      and exists (
        select 1 from public.consent_grants g
        where g.user_id = (select auth.uid())
          and g.org_id = care_weekly_summaries.org_id
          and g.scope = ''visit_packet_view''
          and g.revoked_at is null
      ))';
  execute 'create policy "cws_select_own" on public.care_weekly_summaries for select to authenticated using (user_id = (select auth.uid()))';
end $$;

-- The clinician read: member + consent + lookback clamp + audit —
-- the care_get_visit_packet shape, returning the series (newest
-- first, capped at 26 weeks).
create or replace function public.care_get_weekly_summaries(p_org uuid, p_patient uuid)
returns jsonb
language plpgsql volatile security definer set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_window_start timestamptz;
  v_rows jsonb;
begin
  if not private.is_active_member(p_org) then
    raise exception 'not a member of this organization.';
  end if;
  if not private.has_consent(p_patient, p_org, 'visit_packet_view') then
    raise exception 'no packet access for this patient.';
  end if;
  v_window_start := private.consent_window_start(p_patient, p_org);

  select coalesce(jsonb_agg(jsonb_build_object(
           'week_key', s.week_key,
           'payload', s.payload,
           'generated_at', s.generated_at
         ) order by s.week_key desc), '[]'::jsonb)
    into v_rows
    from (
      select * from public.care_weekly_summaries w
      where w.user_id = p_patient and w.org_id = p_org
        and w.generated_at >= coalesce(v_window_start, w.generated_at)
      order by w.week_key desc
      limit 26
    ) s;

  perform private.log_care_event(p_org, v_uid, private.actor_role_in(p_org),
    'summary.viewed', p_patient, 'summary', null,
    (select count(*)::text from public.care_weekly_summaries w
      where w.user_id = p_patient and w.org_id = p_org));
  return v_rows;
end;
$$;

revoke all on function public.care_get_weekly_summaries(uuid, uuid) from public;
grant execute on function public.care_get_weekly_summaries(uuid, uuid) to authenticated;

-- VERIFICATION
--   1. RLS on:  select relrowsecurity from pg_class where relname='care_weekly_summaries';  -> t
--   2. Policies: select policyname, cmd from pg_policies where tablename='care_weekly_summaries';
--        -> cws_insert_own_consented / cws_update_own_consented / cws_select_own (no delete)
--   3. As a non-member clinician: select care_get_weekly_summaries(...) -> raises
