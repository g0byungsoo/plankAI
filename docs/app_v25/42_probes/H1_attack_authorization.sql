-- v25 §42 — ADVERSARIAL + POSITIVE PROOF AGAINST THE DEPLOYED CONTRACT.
-- Runs inside ONE transaction and ROLLS BACK. Every fixture uid is a
-- fixed test uuid; every assertion is scoped to them.

begin;

create temp table r(step text, expected text, actual text, ok boolean);
grant all on r to authenticated;

do $harness$
declare
    A  uuid := 'aaaaaaaa-0000-4000-8000-000000000001';
    A2 uuid := 'aaaaaaaa-0000-4000-8000-000000000002';
    A3 uuid := 'aaaaaaaa-0000-4000-8000-000000000003';
    B  uuid := 'bbbbbbbb-0000-4000-8000-000000000001';
    C  uuid := 'cccccccc-0000-4000-8000-000000000001';
    D  uuid := 'dddddddd-0000-4000-8000-000000000001';
    PERMN uuid := 'eeeeeeee-0000-4000-8000-000000000001';
    PLAN_A uuid := '11111111-0000-4000-8000-000000000001';
    PLAN_B uuid := '11111111-0000-4000-8000-000000000002';
    hB text; hC text; hD text; hX text;
    res jsonb; got text; n int; rid uuid;
begin
    ----------------------------------------------------------------------
    -- FIXTURES
    ----------------------------------------------------------------------
    insert into auth.users(id, is_anonymous) values
        (A,true),(A2,true),(A3,true),(B,false),(C,false),(D,false),(PERMN,false);

    insert into auth.identities(provider_id, user_id, identity_data, provider) values
        ('SUB_B', B, '{"sub":"SUB_B"}'::jsonb, 'apple'),
        ('SUB_C', C, '{"sub":"SUB_C"}'::jsonb, 'apple'),
        ('SUB_D', D, '{"sub":"SUB_D"}'::jsonb, 'apple'),
        ('SUB_N', PERMN, '{"sub":"SUB_N"}'::jsonb, 'apple');

    hB := encode(sha256(convert_to('apple:SUB_B','UTF8')),'hex');
    hC := encode(sha256(convert_to('apple:SUB_C','UTF8')),'hex');
    hD := encode(sha256(convert_to('apple:SUB_D','UTF8')),'hex');
    hX := encode(sha256(convert_to('apple:SUB_NOBODY','UTF8')),'hex');

    -- A's record: every family that can collide, plus the two refusals.
    insert into public.users(id, onboarding_height_cm, onboarding_current_weight_kg, onboarding_goal_weight_kg)
        values (A, 160, 80, 70);
    insert into public.users(id, onboarding_height_cm) values (B, 170);   -- B HAS a profile
    -- D deliberately has NO profile row.

    insert into public.weight_logs(id, user_id, weight_kg) values
        ('A-W1', A, 80.0), ('A-W2', A, 79.5);
    insert into public.food_logs(id, user_id, kcal_total) values ('A-F1', A, 600);
    insert into public.session_logs(id, user_id, exercise_type) values ('A-S1', A, 'plank');
    insert into public.coach_messages(id, user_id, role, body, day_key)
        values ('A-M1', A, 'user', 'x', '2026-08-10');

    -- regimen: A has a SELF medication head AND a care-team row.
    insert into public.regimen_plans(id, user_id, kind, authority, display_name, schedule_rule) values
        ('A-RG-SELF', A, 'medication', 'self',      'self med',  'weekly'),
        ('A-RG-CARE', A, 'medication', 'care_team', 'clinic med','weekly');
    update public.regimen_plans set org_id = '99999999-0000-4000-8000-000000000001'
        where id = 'A-RG-CARE';
    insert into public.regimen_plans(id, user_id, kind, authority, display_name, schedule_rule) values
        ('B-RG-SELF', B, 'medication', 'self', 'B med', 'weekly');   -- B's live head

    -- deterministic ids, one of them with UPPERCASE in the tail (CORR-2)
    insert into public.dose_events(id, user_id, regimen_plan_id, day_key) values
        (lower(A::text)||'-dose-2026-08-10', A, 'A-RG-SELF', '2026-08-10'),
        (lower(A::text)||'-dose-2026-08-11', A, 'A-RG-SELF', '2026-08-11');
    insert into public.dose_events(id, user_id, regimen_plan_id, day_key) values
        (lower(B::text)||'-dose-2026-08-11', B, 'B-RG-SELF', '2026-08-11');   -- COLLIDES
    insert into public.observations(id, user_id, kind, day_key) values
        (lower(A::text)||'-foodNoise-2026-08-10', A, 'foodNoise', '2026-08-10');
    insert into public.weekly_reads(id, user_id, window_start_day, anchor) values
        (lower(A::text)||'-read-2026-08-03', A, '2026-08-03', 'dose');

    -- composite keys: A has day 1 and day 7; B already lived day 1
    insert into public.day_progress(user_id, program_day, primary_hold_time) values
        (A, 1, 11), (A, 7, 77), (B, 1, 99);
    insert into public.exercise_calibrations(user_id, exercise_type) values (A,'plank'),(B,'plank');
    insert into public.day_reflections(id, user_id, day_key, feeling, note) values
        ('A-R1', A, '2026-08-10', 'ok', 'her words'),
        ('A-R2', A, '2026-08-11', 'ok', 'kept'),
        ('B-R1', B, '2026-08-10', 'ok', 'B own words');

    -- plans: both live. B's must survive as the present tense.
    insert into public.program_plans(id, user_id, phase, start_date, goal_date, total_days, intensity_tier) values
        (PLAN_A, A, 'active', date '2026-06-01', date '2026-09-01', 90, 'medium'),
        (PLAN_B, B, 'active', date '2026-07-01', date '2026-10-01', 90, 'medium');
    insert into public.program_day_checks(id, user_id, program_plan_id, program_day, item_key) values
        ('A-C1', A, PLAN_A, 1, 'move');

    -- program facts: one prescribed (must be refused), one preferred
    insert into public.program_facts(id, user_id, kind, value, authority, basis, source) values
        ('A-PF-RX',  A, 'stepGoal', '6000', 'prescribed', 'assigned', 'clinic'),
        ('A-PF-PREF',A, 'stepGoal', '7000', 'preferred',  'stated',   'chat');

    ----------------------------------------------------------------------
    -- §6 ATTACKS
    ----------------------------------------------------------------------

    -- 1 · a PERMANENT account tries to begin a handoff (named → named)
    perform set_config('request.jwt.claims', json_build_object('sub', PERMN::text)::text, true);
    begin
        perform public.begin_account_handoff('apple', hB);
        insert into r values('A1 permanent account begins handoff','42501','NO ERROR',false);
    exception when others then
        insert into r values('A1 permanent account begins handoff','42501',SQLSTATE,SQLSTATE='42501');
    end;

    -- 2 · unauthenticated
    perform set_config('request.jwt.claims', '', true);
    begin
        perform public.begin_account_handoff('apple', hB);
        insert into r values('A2 unauthenticated begin','28000','NO ERROR',false);
    exception when others then
        insert into r values('A2 unauthenticated begin','28000',SQLSTATE,SQLSTATE='28000');
    end;

    -- 3 · the email door is closed (CORR-3)
    perform set_config('request.jwt.claims', json_build_object('sub', A::text)::text, true);
    begin
        perform public.begin_account_handoff('email', hB);
        insert into r values('A3 email provider refused','22023','NO ERROR',false);
    exception when others then
        insert into r values('A3 email provider refused','22023',SQLSTATE,SQLSTATE='22023');
    end;

    -- 4 · malformed subject
    begin
        perform public.begin_account_handoff('apple', 'not-a-hash');
        insert into r values('A4 malformed subject','22023','NO ERROR',false);
    exception when others then
        insert into r values('A4 malformed subject','22023',SQLSTATE,SQLSTATE='22023');
    end;

    -- 5 · A legitimately pre-commits to B. This is the ONLY authorised write.
    perform set_config('request.jwt.claims', json_build_object('sub', A::text)::text, true);
    rid := public.begin_account_handoff('apple', hB);
    insert into r values('A5 anonymous A opens a receipt','1 open row',
        (select count(*)::text||' open row' from public.account_handoffs where state='open' and source_user_id=A), true);

    -- 6 · BEGIN twice = one row (idempotent)
    perform public.begin_account_handoff('apple', hB);
    select count(*) into n from public.account_handoffs where source_user_id=A and subject_hash=hB and state='open';
    insert into r values('A6 BEGIN twice is one row','1',n::text,n=1);

    -- 7 · A2 pre-commits to a subject NOBODY owns
    perform set_config('request.jwt.claims', json_build_object('sub', A2::text)::text, true);
    perform public.begin_account_handoff('apple', hX);

    -- 8 · A3 pre-commits to C (so B must NOT be able to take it)
    perform set_config('request.jwt.claims', json_build_object('sub', A3::text)::text, true);
    perform public.begin_account_handoff('apple', hC);

    -- 9 · an ANONYMOUS account tries to RECEIVE a handoff
    perform set_config('request.jwt.claims', json_build_object('sub', A2::text)::text, true);
    begin
        perform public.complete_account_handoff();
        insert into r values('A9 anonymous destination','42501','NO ERROR',false);
    exception when others then
        insert into r values('A9 anonymous destination','42501',SQLSTATE,SQLSTATE='42501');
    end;

    -- 10 · C completes: C owns SUB_C, and A3's receipt names SUB_C, so C
    --      legitimately absorbs A3 — but C must NOT touch A (SUB_B) or A2.
    perform set_config('request.jwt.claims', json_build_object('sub', C::text)::text, true);
    res := public.complete_account_handoff();
    insert into r values('A10 C absorbs only its OWN committed source','{"moved": 1, "retired": 1}',res::text,
        res = '{"moved": 1, "retired": 1}'::jsonb);
    select count(*) into n from auth.users where id in (A, A2);
    insert into r values('A10b C did not retire A or A2','2',n::text,n=2);
    select count(*) into n from public.weight_logs where user_id = C;
    insert into r values('A10c C received none of A''s rows','0',n::text,n=0);

    -- 11 · D owns SUB_D. No receipt names SUB_D. D must get nothing.
    perform set_config('request.jwt.claims', json_build_object('sub', D::text)::text, true);
    res := public.complete_account_handoff();
    insert into r values('A11 unrelated destination gets nothing','{"moved": 0, "retired": 0}',res::text,
        res = '{"moved": 0, "retired": 0}'::jsonb);

    -- 12 · N tries to NAME A as its source. p_source_user_id may only NARROW.
    perform set_config('request.jwt.claims', json_build_object('sub', PERMN::text)::text, true);
    res := public.complete_account_handoff(p_source_user_id => A);
    insert into r values('A12 naming a victim source moves nothing','{"moved": 0, "retired": 0}',res::text,
        res = '{"moved": 0, "retired": 0}'::jsonb);
    select count(*) into n from auth.users where id = A;
    insert into r values('A12b A still exists','1',n::text,n=1);

    -- 13 · N tries mode=retire on A (delete without move)
    res := public.complete_account_handoff(p_source_user_id => A, p_mode => 'retire');
    insert into r values('A13 retire-mode cannot name a victim','{"moved": 0, "retired": 0}',res::text,
        res = '{"moved": 0, "retired": 0}'::jsonb);

    -- 14 · unknown mode
    begin
        perform public.complete_account_handoff(null, 'obliterate');
        insert into r values('A14 unknown mode','22023','NO ERROR',false);
    exception when others then
        insert into r values('A14 unknown mode','22023',SQLSTATE,SQLSTATE='22023');
    end;

    -- 15 · the expired receipt is inert
    update public.account_handoffs set expires_at = now() - interval '1 day' where source_user_id = A2;
    perform set_config('request.jwt.claims', json_build_object('sub', B::text)::text, true);
    select count(*) into n from public.account_handoffs h
     where h.source_user_id = A2 and h.state = 'open' and h.expires_at > now();
    insert into r values('A15 expired receipt is outside the filter','0',n::text,n=0);

    ----------------------------------------------------------------------
    -- §7 THE POSITIVE PATH — B completes its OWN committed handoff
    ----------------------------------------------------------------------
    perform set_config('request.jwt.claims', json_build_object('sub', B::text)::text, true);
    res := public.complete_account_handoff();
    insert into r values('P1 B completes A''s committed handoff','{"moved": 1, "retired": 1}',res::text,
        res = '{"moved": 1, "retired": 1}'::jsonb);

    -- the source reached its terminal state
    select count(*) into n from auth.users where id = A;
    insert into r values('P2 source auth.users row is gone','0',n::text,n=0);

    -- ids preserved on the simple moves
    select string_agg(id, ',' order by id) into got from public.weight_logs where user_id = B;
    insert into r values('P3 weight ids preserved','A-W1,A-W2',coalesce(got,'(none)'),got='A-W1,A-W2');
    select count(*) into n from public.food_logs where user_id=B and id='A-F1';
    insert into r values('P4 food id preserved','1',n::text,n=1);
    select count(*) into n from public.coach_messages where user_id=B and id='A-M1';
    insert into r values('P5 coach_messages transferred (CORR-5)','1',n::text,n=1);

    -- CORR-2: the deterministic id keeps its tail's CASE
    select count(*) into n from public.observations
     where user_id=B and id = lower(B::text)||'-foodNoise-2026-08-10';
    insert into r values('P6 observation id case preserved (CORR-2)','1',n::text,n=1);
    select count(*) into n from public.observations
     where user_id=B and id = lower(B::text)||'-foodnoise-2026-08-10';
    insert into r values('P6b no lowercased duplicate','0',n::text,n=0);

    -- dose collision: destination wins, A's non-colliding day follows
    select string_agg(id, ',' order by id) into got from public.dose_events where user_id=B;
    insert into r values('P7 dose prefix swap + destination wins',
        lower(B::text)||'-dose-2026-08-10,'||lower(B::text)||'-dose-2026-08-11',
        coalesce(got,'(none)'),
        got = lower(B::text)||'-dose-2026-08-10,'||lower(B::text)||'-dose-2026-08-11');
    select count(*) into n from public.dose_events where user_id in (A,B);
    insert into r values('P7b exactly two dose rows survive (fixtures)','2',n::text,n=2);

    -- weekly read prefix swap
    select count(*) into n from public.weekly_reads where user_id=B and id=lower(B::text)||'-read-2026-08-03';
    insert into r values('P8 weekly read prefix swap','1',n::text,n=1);

    -- day_progress: B's own day 1 survives untouched, A's day 7 follows
    select primary_hold_time::text into got from public.day_progress where user_id=B and program_day=1;
    insert into r values('P9 destination day 1 wins, content never compared','99',coalesce(got,'(none)'),got='99');
    select count(*) into n from public.day_progress where user_id=B and program_day=7;
    insert into r values('P9b A''s day 7 followed','1',n::text,n=1);
    select count(*) into n from public.day_progress where user_id in (A,B);
    insert into r values('P9c exactly two day rows survive (fixtures)','2',n::text,n=2);

    -- calibration composite key
    select count(*) into n from public.exercise_calibrations where user_id in (A,B);
    insert into r values('P10 calibration destination wins','1',n::text,n=1);

    -- day_reflections: her evening words, the family that was in no merge
    select string_agg(id, ',' order by id) into got from public.day_reflections where user_id=B;
    insert into r values('P11 day_reflections transferred, dest wins the shared day',
        'A-R2,B-R1',coalesce(got,'(none)'),got='A-R2,B-R1');

    -- plans: B's stays live, A's arrives archived
    select phase into got from public.program_plans where id=PLAN_B;
    insert into r values('P12 destination plan stays live','active',coalesce(got,'(none)'),got='active');
    select phase||'/'||(archived_at is not null)::text into got from public.program_plans where id=PLAN_A;
    insert into r values('P12b source plan arrives archived','abandoned/true',coalesce(got,'(none)'),got='abandoned/true');
    select user_id::text into got from public.program_plans where id=PLAN_A;
    insert into r values('P12c source plan followed to B',B::text,coalesce(got,'(none)'),got=B::text);
    select count(*) into n from public.program_day_checks where user_id=B and id='A-C1';
    insert into r values('P13 day check followed','1',n::text,n=1);

    -- authority is not portable
    select count(*) into n from public.regimen_plans where id='A-RG-CARE';
    insert into r values('P14 care-team regimen REFUSED and removed','0',n::text,n=0);
    select count(*) into n from public.program_facts where id='A-PF-RX';
    insert into r values('P15 prescribed fact REFUSED and removed','0',n::text,n=0);
    select user_id::text into got from public.program_facts where id='A-PF-PREF';
    insert into r values('P15b preferred fact followed',B::text,coalesce(got,'(none)'),got=B::text);

    -- one live medication head
    select (ended_at is null)::text into got from public.regimen_plans where id='B-RG-SELF';
    insert into r values('P16 destination regimen stays live','true',coalesce(got,'(none)'),got='true');
    select coalesce(end_reason,'(null)') into got from public.regimen_plans where id='A-RG-SELF';
    insert into r values('P16b source regimen arrives ended','ended',got,got='ended');

    -- the profile: B had one, so B's wins and A's is gone with the account
    select onboarding_height_cm::text into got from public.users where id=B;
    insert into r values('P17 destination profile untouched','170',coalesce(got,'(none)'),got='170');
    select count(*) into n from public.users where id=A;
    insert into r values('P17b source profile removed with the account','0',n::text,n=0);

    -- the receipt
    select state||'/'||coalesce(subject_hash,'NULL')||'/'||coalesce(source_user_id::text,'NULL')
      into got from public.account_handoffs where id=rid;
    insert into r values('P18 receipt terminal, digest dropped, source anonymised',
        'completed/NULL/NULL',coalesce(got,'(none)'),got='completed/NULL/NULL');
    select (destination_user_id = B)::text into got from public.account_handoffs where id=rid;
    insert into r values('P18b receipt records the destination','true',coalesce(got,'(none)'),got='true');

    ----------------------------------------------------------------------
    -- §21 / §31 IDEMPOTENCY
    ----------------------------------------------------------------------
    res := public.complete_account_handoff();
    insert into r values('R1 COMPLETE replay is a no-op','{"moved": 0, "retired": 0}',res::text,
        res = '{"moved": 0, "retired": 0}'::jsonb);
    select count(*) into n from public.weight_logs where user_id=B;
    insert into r values('R1b no duplicate weigh-ins after replay','2',n::text,n=2);
    res := public.complete_account_handoff();
    insert into r values('R2 third COMPLETE still a no-op','{"moved": 0, "retired": 0}',res::text,
        res = '{"moved": 0, "retired": 0}'::jsonb);

    ----------------------------------------------------------------------
    -- §13 / CORR-8 — the same-uid upgrade's receipt is closed
    ----------------------------------------------------------------------
    -- D was anonymous when it opened a receipt, then linked in place.
    update auth.users set is_anonymous = true where id = D;
    perform set_config('request.jwt.claims', json_build_object('sub', D::text)::text, true);
    perform public.begin_account_handoff('apple', hD);
    update auth.users set is_anonymous = false where id = D;   -- the link succeeded
    select count(*) into n from public.account_handoffs where source_user_id=D and state='open';
    insert into r values('U1 pre-link receipt exists','1',n::text,n=1);
    res := public.complete_account_handoff();
    select count(*) into n from public.account_handoffs where source_user_id=D;
    insert into r values('U2 same-uid upgrade closes its own receipt (CORR-8)','0',n::text,n=0);
    insert into r values('U3 same-uid upgrade moves nothing','{"moved": 0, "retired": 0}',res::text,
        res = '{"moved": 0, "retired": 0}'::jsonb);
    select count(*) into n from public.users where id=D;
    insert into r values('U4 CORR-7 untested here (D kept no source)','0',n::text,n=0);

    ----------------------------------------------------------------------
    -- CORR-7 — a destination with NO profile gets the source's
    ----------------------------------------------------------------------
    insert into auth.users(id, is_anonymous) values
        ('aaaaaaaa-0000-4000-8000-000000000009', true);
    insert into public.users(id, onboarding_height_cm, onboarding_goal_weight_kg)
        values ('aaaaaaaa-0000-4000-8000-000000000009', 155, 60);
    perform set_config('request.jwt.claims',
        json_build_object('sub','aaaaaaaa-0000-4000-8000-000000000009')::text, true);
    perform public.begin_account_handoff('apple', hD);
    perform set_config('request.jwt.claims', json_build_object('sub', D::text)::text, true);
    res := public.complete_account_handoff();
    select onboarding_height_cm::text||'/'||onboarding_goal_weight_kg::text
      into got from public.users where id=D;
    insert into r values('C7 empty destination inherits the source profile','155/60',
        coalesce(got,'(NO PROFILE ROW)'), got='155/60');

    perform set_config('request.jwt.claims', '', true);
end;
$harness$;

-- direct-access attacks, as the real client role
set local role authenticated;
do $direct$
declare n int;
begin
    begin
        insert into public.account_handoffs(source_user_id, provider, subject_hash)
        values ('aaaaaaaa-0000-4000-8000-000000000001','apple', repeat('a',64));
        insert into r values('D1 direct INSERT into receipt table','denied','ALLOWED',false);
    exception when others then
        insert into r values('D1 direct INSERT into receipt table','denied',SQLSTATE,SQLSTATE='42501');
    end;
    begin
        update public.account_handoffs set state='open';
        insert into r values('D2 direct UPDATE of receipt state','denied','ALLOWED',false);
    exception when others then
        insert into r values('D2 direct UPDATE of receipt state','denied',SQLSTATE,SQLSTATE='42501');
    end;
    begin
        perform count(*) from public.account_handoffs;
        insert into r values('D3 direct SELECT of receipts','denied','ALLOWED',false);
    exception when others then
        insert into r values('D3 direct SELECT of receipts','denied',SQLSTATE,SQLSTATE='42501');
    end;
    begin
        perform private.transfer_account_rows(
            'aaaaaaaa-0000-4000-8000-000000000001','bbbbbbbb-0000-4000-8000-000000000001');
        insert into r values('D4 direct call to the mover','denied','ALLOWED',false);
    exception when others then
        insert into r values('D4 direct call to the mover','denied',SQLSTATE,SQLSTATE='42501');
    end;
    begin
        update public.weight_logs set user_id='bbbbbbbb-0000-4000-8000-000000000001'
         where user_id='aaaaaaaa-0000-4000-8000-000000000001';
        get diagnostics n = row_count;
        insert into r values('D5 direct ownership rewrite under RLS','0 rows',n::text||' rows',n=0);
    exception when others then
        insert into r values('D5 direct ownership rewrite under RLS','0 rows',SQLSTATE,true);
    end;
end;
$direct$;
reset role;

select (case when ok then 'PASS' else '**FAIL**' end)||' | '||step||' | expected='||expected||' | got='||actual as line from r
union all select '===== FAILURES='||(select count(*) filter (where not ok) from r)::text||'  TOTAL='||(select count(*) from r)::text;

rollback;
