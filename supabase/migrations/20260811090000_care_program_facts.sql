-- app v8 S4/S5 · v25 E1 seam — THE CLINICIAN'S PROGRAM FACTS
--
-- v25 E1 built the whole authority chain (prescribed › preferred ›
-- recommended › defaulted): `program_facts` carries it, the RLS
-- policies already forbid a patient from writing or touching a
-- `prescribed` row, and iOS's hydrateProgramFacts already treats
-- prescribed rows as SERVER-AUTHORITATIVE. Every piece existed
-- except the one the model is named for: a way for the clinician to
-- actually author one.
--
-- This adds exactly that, and nothing more. Purpose-built, not a
-- form builder: three facts a metabolic clinic plausibly directs and
-- that the patient app already consumes today —
--
--   stepGoal      integer steps/day  → TargetsService, the walking
--                                      action on Today
--   weighCadence  standard|softened  → how often Jeni asks her to
--                                      weigh in
--   walkTiming    afterMeals|anytime|off
--                                    → when the walk is offered
--
-- The authority law holds in both directions: assigning supersedes
-- (append-only version chain, never mutate), and ENDING a prescribed
-- fact hands the knob back to the patient's own preference rather
-- than deleting her history. An authority you cannot release is not
-- a care model.

-- ---------------------------------------------------------------
-- assign / update
-- ---------------------------------------------------------------
create or replace function public.care_set_program_fact(
  p_org uuid, p_patient uuid, p_kind text, p_value text
) returns text
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_prev text;
  v_id text;
  v_encoded text;
  v_num int;
begin
  if not private.has_clinical_authority(p_org) then
    raise exception 'only a clinician can set a program fact.';
  end if;
  if not private.has_consent(p_patient, p_org, 'care_assignment') then
    raise exception 'no assignment consent for this patient.';
  end if;

  -- Validate + encode into the app's fact vocabulary
  -- (PlankApp/Program/ProgramFacts.swift: "i:<int>" | "w:<word>").
  if p_kind = 'stepGoal' then
    begin
      v_num := trim(coalesce(p_value, ''))::int;
    exception when others then
      raise exception 'a step goal is a whole number of steps.';
    end;
    -- The prescribed rail from ProgramFacts.clamped — a clinician
    -- gets wide bounds, but not absurd ones.
    if v_num < 500 or v_num > 50000 then
      raise exception 'a step goal must be between 500 and 50,000.';
    end if;
    v_encoded := 'i:' || v_num::text;

  elsif p_kind = 'weighCadence' then
    if p_value not in ('standard', 'softened') then
      raise exception 'weigh cadence is standard or softened.';
    end if;
    v_encoded := 'w:' || p_value;

  elsif p_kind = 'walkTiming' then
    if p_value not in ('afterMeals', 'anytime', 'off') then
      raise exception 'walk timing is afterMeals, anytime or off.';
    end if;
    v_encoded := 'w:' || p_value;

  else
    raise exception 'that is not a fact a clinic sets here.';
  end if;

  -- Supersede, never mutate: the previous prescribed row is closed
  -- and named as the new row's parent.
  select id into v_prev from public.program_facts
   where user_id = p_patient and kind = p_kind
     and authority = 'prescribed' and ended_at is null
   order by created_at desc limit 1;

  if v_prev is not null then
    update public.program_facts
       set ended_at = now(), end_reason = 'superseded', updated_at = now()
     where id = v_prev;
  end if;

  v_id := gen_random_uuid()::text;
  insert into public.program_facts
    (id, user_id, kind, value, authority, basis, source, previous_fact_id)
  values
    (v_id, p_patient, p_kind, v_encoded, 'prescribed', 'assigned',
     'care_team:' || p_org::text, v_prev);

  perform private.log_care_event(p_org, v_uid, private.actor_role_in(p_org),
    'program_fact.assigned', p_patient, 'program_fact', v_id, 'success',
    jsonb_build_object('kind', p_kind));
  return v_id;
end;
$$;

-- ---------------------------------------------------------------
-- release (the prescription ends; her own preference resumes)
-- ---------------------------------------------------------------
create or replace function public.care_end_program_fact(
  p_org uuid, p_patient uuid, p_kind text
) returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_id text;
begin
  if not private.has_clinical_authority(p_org) then
    raise exception 'only a clinician can release a program fact.';
  end if;
  if not private.has_consent(p_patient, p_org, 'care_assignment') then
    raise exception 'no assignment consent for this patient.';
  end if;

  select id into v_id from public.program_facts
   where user_id = p_patient and kind = p_kind
     and authority = 'prescribed' and ended_at is null
   order by created_at desc limit 1;
  if v_id is null then
    raise exception 'nothing prescribed to release.';
  end if;

  update public.program_facts
     set ended_at = now(), end_reason = 'revoked', updated_at = now()
   where id = v_id;

  perform private.log_care_event(p_org, v_uid, private.actor_role_in(p_org),
    'program_fact.released', p_patient, 'program_fact', v_id, 'success',
    jsonb_build_object('kind', p_kind));
end;
$$;

-- ---------------------------------------------------------------
-- read (what this clinic currently directs for this patient)
-- ---------------------------------------------------------------
create or replace function public.care_get_program_facts(
  p_org uuid, p_patient uuid
) returns jsonb
language plpgsql stable security definer set search_path = ''
as $$
declare
  v_out jsonb;
begin
  if not private.is_active_member(p_org) then
    raise exception 'not a member of this organization.';
  end if;
  if not private.has_consent(p_patient, p_org, 'care_assignment') then
    raise exception 'no assignment consent for this patient.';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
           'kind', kind, 'value', value, 'created_at', created_at)
         order by created_at desc), '[]'::jsonb)
    into v_out
  from public.program_facts
  where user_id = p_patient and authority = 'prescribed' and ended_at is null;

  return v_out;
end;
$$;

revoke all on function public.care_set_program_fact(uuid, uuid, text, text) from public, anon;
revoke all on function public.care_end_program_fact(uuid, uuid, text) from public, anon;
revoke all on function public.care_get_program_facts(uuid, uuid) from public, anon;
grant execute on function public.care_set_program_fact(uuid, uuid, text, text) to authenticated;
grant execute on function public.care_end_program_fact(uuid, uuid, text) to authenticated;
grant execute on function public.care_get_program_facts(uuid, uuid) to authenticated;

-- ---------------------------------------------------------------
-- THE ROSTER LEARNS TO SAY WHY
--
-- `care_list_patients` returned a bare `needs_attention` boolean,
-- which is enough to sort a list and not enough to write one. The
-- clinic home has to answer four questions — who needs attention,
-- why, how long it has been waiting, and what has already been
-- handled — and a boolean answers one of them.
--
-- Two fields are added, and no authorization is widened:
--   packet                     the published visit packet, returned
--                              ONLY when the patient granted
--                              visit_packet_view (the same scope
--                              care_get_visit_packet enforces). The
--                              reason lines are then composed in the
--                              product layer, where the packet's
--                              honesty vocabulary already lives —
--                              not in SQL.
--   oldest_open_correction_at  so "filed three days ago" is a fact
--                              and not a guess.
-- ---------------------------------------------------------------
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
      'packet', case
        when private.has_consent(r.patient_id, p_org, 'visit_packet_view')
          then vp.payload
        else null end,
      'open_corrections', (
        select count(*) from public.correction_requests c
        where c.org_id = p_org and c.patient_id = r.patient_id
          and c.status = 'open'),
      'oldest_open_correction_at', (
        select min(c.created_at) from public.correction_requests c
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

-- ---------------------------------------------------------------
-- THE SERIES LEARNS THE SYMPTOM VOCABULARY
--
-- `care_get_patient_series` whitelists doseTaken · sitCheck ·
-- hydration — the three kinds that existed when S4 was written. v24
-- added a real symptom vocabulary, and the visit packet has been
-- publishing it ever since, including the sentence "often within two
-- days of a marked dose".
--
-- So the clinician is already shown that claim and, until now, had no
-- way to check it: the days behind it were withheld while the
-- conclusion drawn from them was not. That is the wrong way round.
-- Adding 'symptom' discloses no new CATEGORY of information under the
-- observation_view scope — it discloses, at the resolution needed to
-- verify it, exactly what the packet already asserts.
--
-- Still excluded, deliberately and permanently: journalNote, feeling,
-- tonightPlan, daySealed. Her words about her own days are hers.
-- ---------------------------------------------------------------
create or replace function public.care_get_patient_series(p_org uuid, p_patient uuid)
returns jsonb
language plpgsql security definer set search_path = ''
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
    and o.kind in ('doseTaken','sitCheck','hydration','symptom')
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
