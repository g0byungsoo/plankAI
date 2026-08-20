-- PASS 43 · W1 — THE ONLY WRITE THIS PASS MAKES TO PRODUCTION.
--
-- A duplicate LIVE program plan was minted on the founder's own account at
-- 2026-08-15 06:25:18 by the onramp race (43 §5): the sign-in restore
-- arrives at the END of a 17-call hydrate chain, so for ~35 seconds a
-- returning payer is shown "start my program", and tapping it enrolls her
-- again with started_at = today.
--
-- It is ARCHIVED, not deleted: `phase='abandoned' + archived_at` is how this
-- model already carries a superseded enrollment (42 §8.3), it keeps the
-- history honest, and `ProgramPlanMerge` (31) adopts it on the device with
-- no founder action. Deleting would risk the device pushing it back.
--
-- One statement, one row, five independent guards, and it ROLLS BACK unless
-- exactly one row moved and exactly one live plan remains.
begin;

update public.program_plans
   set phase = 'abandoned',
       archived_at = now(),
       updated_at = now()
 where id          = '5d7158d6-aa19-48e9-b483-a1efccb8ff53'
   and user_id     = '280CAA8E-B635-49B7-8BF1-CA725F71798A'
   and phase       = 'active'
   and archived_at is null
   and started_at  = '2026-08-15 06:25:18+00';

do $$
declare
    v_live integer;
    v_target text;
begin
    select count(*) into v_live
      from public.program_plans
     where user_id = '280CAA8E-B635-49B7-8BF1-CA725F71798A'
       and archived_at is null and phase <> 'abandoned';
    if v_live <> 1 then
        raise exception 'ABORT: expected exactly 1 live plan, found %', v_live;
    end if;

    select id::text into v_target
      from public.program_plans
     where user_id = '280CAA8E-B635-49B7-8BF1-CA725F71798A'
       and archived_at is null and phase <> 'abandoned';
    if v_target <> '15ec87d9-c73d-44a9-b068-88b46269d99b' then
        raise exception 'ABORT: the surviving live plan is not the 2026-08-04 one (%)', v_target;
    end if;
end $$;

commit;
