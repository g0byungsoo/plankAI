-- v25 §42 — FAILURE BOUNDARIES §8 §9 §10 §11 §24 §25 + THE CAPS.
-- One transaction, rolled back.

begin;
create temp table r(step text, expected text, actual text, ok boolean);

do $h$
declare
    A uuid := 'aaaaaaaa-1111-4000-8000-000000000001';
    B uuid := 'bbbbbbbb-1111-4000-8000-000000000001';
    S uuid := 'aaaaaaaa-1111-4000-8000-000000000002';  -- for the caps
    P uuid := 'aaaaaaaa-1111-4000-8000-000000000003';  -- becomes permanent mid-flight
    PLAN_A uuid := '22222222-1111-4000-8000-000000000001';
    hB text; res jsonb; got text; n int; rid uuid; exp timestamptz;
begin
    insert into auth.users(id, is_anonymous) values (A,true),(B,false),(S,true),(P,true);
    insert into auth.identities(provider_id,user_id,identity_data,provider)
        values ('SUB_B2', B, '{"sub":"SUB_B2"}'::jsonb, 'apple');
    hB := encode(sha256(convert_to('apple:SUB_B2','UTF8')),'hex');

    insert into public.users(id, onboarding_height_cm) values (A, 163);
    insert into public.weight_logs(id,user_id,weight_kg) values ('X-W1',A,81),('X-W2',A,80.5);
    insert into public.food_logs(id,user_id,kcal_total) values ('X-F1',A,700);
    insert into public.day_progress(user_id,program_day,primary_hold_time) values (A,1,5),(A,99999,9);
    insert into public.program_plans(id,user_id,phase,start_date,goal_date,total_days,intensity_tier)
        values (PLAN_A,A,'active',date '2026-06-01',date '2026-09-01',90,'medium');

    ---------------------------------------------------------------- §8
    -- BEGIN, then the client dies and nothing else happens.
    perform set_config('request.jwt.claims', json_build_object('sub',A::text)::text, true);
    rid := public.begin_account_handoff('apple', hB);

    select state into got from public.account_handoffs where id=rid;
    insert into r values('S8a receipt is open','open',got,got='open');
    select count(*) into n from auth.users where id=A;
    insert into r values('S8b source still exists','1',n::text,n=1);
    select count(*) into n from public.weight_logs where user_id=A;
    insert into r values('S8c source still owns her rows','2',n::text,n=2);
    select count(*) into n from public.weight_logs where user_id=B;
    insert into r values('S8d destination received nothing yet','0',n::text,n=0);
    select expires_at into exp from public.account_handoffs where id=rid;
    insert into r values('S8e receipt expires ~30d out','true',
        (exp > now() + interval '29 days' and exp < now() + interval '31 days')::text,
        exp > now() + interval '29 days' and exp < now() + interval '31 days');
    select coalesce(completed_at::text,'NULL')||'/'||coalesce(source_retired_at::text,'NULL')
      into got from public.account_handoffs where id=rid;
    insert into r values('S8f nothing recorded as done','NULL/NULL',got,got='NULL/NULL');

    -- a STALE begin cannot be weaponised: only the account owning the
    -- subject can redeem it, and it is inert once expired.
    update public.account_handoffs set expires_at = now() - interval '1 second' where id=rid;
    perform set_config('request.jwt.claims', json_build_object('sub',B::text)::text, true);
    res := public.complete_account_handoff();
    insert into r values('S8g an EXPIRED receipt is inert','{"moved": 0, "retired": 0}',res::text,
        res='{"moved": 0, "retired": 0}'::jsonb);
    update public.account_handoffs set expires_at = now() + interval '30 days' where id=rid;

    ---------------------------------------------------------------- §24
    -- She SIGNS OUT mid-handoff. The device gets a fresh anonymous uid;
    -- the server obligation is untouched and still redeemable.
    perform set_config('request.jwt.claims', json_build_object('sub',S::text)::text, true);
    select count(*) into n from public.account_handoffs where id=rid and state='open';
    insert into r values('S24a sign-out does not erase the obligation','1',n::text,n=1);

    ---------------------------------------------------------------- §10
    -- ATOMICITY. Break the transfer part-way through (day_progress is
    -- moved AFTER weight/food/plans; day 99999 is a value production does not hold) and assert the WHOLE thing rolls
    -- back: no row changed owner, the source still exists, and the
    -- receipt is still `open` — i.e. still the retry state.
    alter table public.day_progress add constraint tmp_break check (program_day <> 99999) not valid;
    perform set_config('request.jwt.claims', json_build_object('sub',B::text)::text, true);
    begin
        res := public.complete_account_handoff();
        insert into r values('S10a a mid-transfer failure raises','error','NO ERROR',false);
    exception when others then
        insert into r values('S10a a mid-transfer failure raises','error',SQLSTATE,true);
    end;
    alter table public.day_progress drop constraint tmp_break;

    select count(*) into n from public.weight_logs where user_id=B;
    insert into r values('S10b nothing moved (weight)','0',n::text,n=0);
    select count(*) into n from public.food_logs where user_id=B;
    insert into r values('S10c nothing moved (food)','0',n::text,n=0);
    select count(*) into n from public.program_plans where user_id=B;
    insert into r values('S10d nothing moved (plan)','0',n::text,n=0);
    select count(*) into n from auth.users where id=A;
    insert into r values('S10e source NOT retired','1',n::text,n=1);
    select state into got from public.account_handoffs where id=rid;
    insert into r values('S10f receipt rolled back to the retry state','open',got,got='open');
    select count(*) into n from public.weight_logs where user_id=A;
    insert into r values('S10g source still owns everything','2',n::text,n=2);

    ---------------------------------------------------------------- §9
    -- The client died after the destination authenticated and kept NO
    -- local state. B discovers the owed handoff from the server alone:
    -- COMPLETE takes no arguments at all.
    perform set_config('request.jwt.claims', json_build_object('sub',B::text)::text, true);
    res := public.complete_account_handoff();
    insert into r values('S9a B recovers with ZERO client state','{"moved": 1, "retired": 1}',res::text,
        res='{"moved": 1, "retired": 1}'::jsonb);
    select count(*) into n from public.weight_logs where user_id=B;
    insert into r values('S9b her record arrived','2',n::text,n=2);

    ---------------------------------------------------------------- §11
    -- Source retirement shares the transaction, so it cannot fail on its
    -- own. The obligation lives in `state='open'`, which is what S10f
    -- proved. Here: after success the source is gone and the receipt is
    -- terminal, and a third call is harmless.
    select count(*) into n from auth.users where id=A;
    insert into r values('S11a source reached its terminal state','0',n::text,n=0);
    res := public.complete_account_handoff();
    insert into r values('S11b retry after success is harmless','{"moved": 0, "retired": 0}',res::text,
        res='{"moved": 0, "retired": 0}'::jsonb);
    select count(*) into n from public.weight_logs where user_id=B;
    insert into r values('S11c no duplication from the retry','2',n::text,n=2);

    ---------------------------------------------------------------- §25
    -- DELETE BEATS TRANSFER. The source deletes her account after BEGIN.
    insert into auth.users(id,is_anonymous) values ('aaaaaaaa-1111-4000-8000-000000000004', true);
    insert into public.weight_logs(id,user_id,weight_kg)
        values ('Y-W1','aaaaaaaa-1111-4000-8000-000000000004',70);
    perform set_config('request.jwt.claims',
        json_build_object('sub','aaaaaaaa-1111-4000-8000-000000000004')::text, true);
    perform public.begin_account_handoff('apple', hB);
    delete from auth.users where id='aaaaaaaa-1111-4000-8000-000000000004';   -- "delete my account"
    select coalesce(source_user_id::text,'NULL') into got
      from public.account_handoffs where state='open' and subject_hash=hB;
    insert into r values('S25a a deleted source anonymises its receipt','NULL',coalesce(got,'(no row)'),got='NULL');
    perform set_config('request.jwt.claims', json_build_object('sub',B::text)::text, true);
    res := public.complete_account_handoff();
    insert into r values('S25b a deleted account transfers nothing','{"moved": 0, "retired": 0}',res::text,
        res='{"moved": 0, "retired": 0}'::jsonb);
    select count(*) into n from public.weight_logs where id='Y-W1';
    insert into r values('S25c deleted rows never reappear','0',n::text,n=0);

    ---------------------------------------------------------------- source became permanent
    perform set_config('request.jwt.claims', json_build_object('sub',P::text)::text, true);
    perform public.begin_account_handoff('apple', hB);
    insert into public.weight_logs(id,user_id,weight_kg) values ('Z-W1',P,60);
    update auth.users set is_anonymous = false where id = P;      -- upgraded elsewhere
    perform set_config('request.jwt.claims', json_build_object('sub',B::text)::text, true);
    res := public.complete_account_handoff();
    insert into r values('S12a a source that became permanent is SKIPPED','{"moved": 0, "retired": 0}',res::text,
        res='{"moved": 0, "retired": 0}'::jsonb);
    select count(*) into n from auth.users where id=P;
    insert into r values('S12b and is never deleted','1',n::text,n=1);
    select count(*) into n from public.weight_logs where id='Z-W1' and user_id=P;
    insert into r values('S12c and keeps its rows','1',n::text,n=1);

    ---------------------------------------------------------------- the caps
    perform set_config('request.jwt.claims', json_build_object('sub',S::text)::text, true);
    for n in 1..5 loop
        perform public.begin_account_handoff('apple',
            encode(sha256(convert_to('apple:CAP'||n::text,'UTF8')),'hex'));
    end loop;
    begin
        perform public.begin_account_handoff('apple',
            encode(sha256(convert_to('apple:CAP6','UTF8')),'hex'));
        insert into r values('S13 per-SOURCE cap (CORR-6)','54000','NO ERROR',false);
    exception when others then
        insert into r values('S13 per-SOURCE cap (CORR-6)','54000',SQLSTATE,SQLSTATE='54000');
    end;

    perform set_config('request.jwt.claims','',true);
end;
$h$;

select (case when ok then 'PASS' else '**FAIL**' end)||' | '||step||' | expected='||expected||' | got='||actual as line from r
union all select '===== FAILURES='||(select count(*) filter (where not ok) from r)::text||'  TOTAL='||(select count(*) from r)::text;

rollback;
