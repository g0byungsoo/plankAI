-- PACKAGE E · 1 of 1 — THE ACCOUNT HANDOFF
--
-- ==========================================================================
-- ==  NOT WRITTEN TO supabase/migrations. NOT APPLIED. NOT DEPLOYED.      ==
-- ==  A file in supabase/migrations is applied by the next `db push`;     ==
-- ==  this one is staged here so a person applies it deliberately, and    ==
-- ==  so the client that adopts it can be written against a contract      ==
-- ==  that has been VERIFIED in production first (§31, step 2).           ==
-- ==========================================================================
--
-- ==========================================================================
-- WHY THIS EXISTS AT ALL
-- ==========================================================================
--
-- `40` closed every transition Jeni can produce except one, and named the
-- residue itself:
--
--   anonymous A → permanent B → the session switches → A is retired
--   client-side with its own access token → THE REQUEST FAILS → A survives
--   with customer data, and the client has no credential that can ever
--   name A again.
--
-- `40` §3.5 stated the reason plainly: a retry needs a bearer token this
-- build refuses to persist, and persisting one would be a worse defect than
-- the one it fixes. That is correct, and it means:
--
--   ▎ THE REMAINING PROBLEM CANNOT HONESTLY BE SOLVED BY ANOTHER CLIENT
--   ▎ RETRY. THE OWNERSHIP TRANSITION NEEDS A DURABLE SERVER-SIDE HANDOFF.
--
-- ==========================================================================
-- THE AUTHORIZATION, WHICH IS THE HARD PART
-- ==========================================================================
--
-- The brief's warning is exact: an endpoint that accepts `source_uid` and
-- `destination_uid` and trusts the caller is an account-takeover primitive.
-- So this design accepts NEITHER as an authorization input.
--
--   1. **BEGIN, while the source is still authenticated.** The anonymous
--      session — and only an anonymous session — writes a receipt naming
--      ITSELF (`auth.uid()`, never a parameter) and PRE-COMMITTING to the
--      destination it is about to reach, as a SHA-256 of
--      `"<provider>:<subject>"`. The subject is the Apple `sub` claim or
--      the lowercased email address.
--
--   2. **COMPLETE, as the destination.** The caller passes no identity at
--      all. The server computes the set of subject hashes THIS caller
--      demonstrably owns, from its own `auth.identities` / `auth.users`
--      rows, and acts only on open receipts whose pre-commitment is in
--      that set.
--
--   ▎ SO THE PROOF IS NOT A BEARER CREDENTIAL. It cannot be stolen and
--   ▎ replayed, because redeeming it requires BEING the account that owns
--   ▎ the pre-committed subject. Nothing secret is persisted on the
--   ▎ device — the client keeps only the two uids it already keeps.
--
-- A client that lies about the subject at BEGIN produces a receipt nobody,
-- including itself, can ever complete. **A lie only locks the liar out.**
-- That property is what makes it safe for the client to extract the `sub`
-- claim locally rather than making the server verify an Apple id token.
--
-- ### The residual, stated rather than glossed
--
-- An attacker who ALREADY KNOWS a victim's Apple `sub` for this app could
-- pre-commit their own anonymous account to it, and the victim's next
-- sign-in would absorb the attacker's rows. That is data INJECTION, not
-- exfiltration — nothing of the victim's leaves — and it requires a value
-- that is per-developer-team, is not derivable from an email address, and
-- exists server-side only in `auth.identities.identity_data`, which no
-- client can read. It is bounded further by the `is_anonymous` gate on the
-- source (an injected account can only ever be one anonymous account's
-- rows) and by the cap on open receipts per subject. It is recorded here
-- because a security argument that names no residual is not a security
-- argument.
--
-- ==========================================================================
-- WHY THE SERVER MOVES THE ROWS RATHER THAN ONLY DELETING THEM
-- ==========================================================================
--
-- Read from the deployed RLS this session, and it is the mechanical answer
-- to "does the transfer belong server-side":
--
--     every UPDATE policy is  USING (auth.uid() = user_id)
--                       AND   WITH CHECK (auth.uid() = user_id)
--
-- For an ownership change Postgres evaluates USING against the OLD row and
-- WITH CHECK against the NEW one, so with the SOURCE's token USING passes
-- and WITH CHECK fails, and with the DESTINATION's token USING fails.
--
--   ▎ NO SINGLE BEARER TOKEN CAN SATISFY BOTH HALVES OF AN OWNERSHIP
--   ▎ CHANGE. THAT IS NOT A GAP IN THE POLICIES. IT IS THE POLICIES
--   ▎ WORKING.
--
-- And it buys the property the client cannot: **RECORD IDS SURVIVE.** The
-- client re-key mints fresh uuids for weight, sessions, plans, checks and
-- food precisely because the cloud row still belongs to the old uid; here
-- the row simply changes owner and keeps its id.
--
-- ==========================================================================
-- WHY THERE IS NO STATE MACHINE
-- ==========================================================================
--
-- Rows, storage objects and `auth.users` are all ordinary DML in the same
-- Postgres transaction, so a handoff either happens or does not. There is
-- no phase that can be half-applied, therefore there is no PREPARED /
-- ROWS_TRANSFERRED / SOURCE_RETIRED ladder to invent. **Two states, and the
-- second is terminal.** A transient failure rolls back to `open`, which is
-- already the retry state, which is also why there is no `last_error_class`
-- column: a value written by a transaction that rolls back is a value that
-- does not exist.

-- ==========================================================================
-- ============================== FORWARD ===================================
-- ==========================================================================

create schema if not exists private;

-- ------------------------------- THE RECEIPT ------------------------------
--
-- MINIMUM FIELDS ONLY. No health payload. No Apple token. No email address
-- and no `sub` — only a one-way digest, and that digest is NULLED the
-- moment the handoff terminates. `source_user_id` is a foreign key with
-- ON DELETE SET NULL, so retiring the source ANONYMISES the receipt in the
-- same statement that retires it: the row keeps the fact that an ownership
-- transition happened and keeps no identifier of the account that is gone.
-- That is the `set null` precedent this schema already uses for telemetry
-- and that Package A2 chose for `patient_invitations.accepted_by`.

create table if not exists public.account_handoffs (
    -- Fully qualified deliberately: a DEFAULT is resolved with the
    -- SESSION search_path at CREATE TABLE time, not with the `search_path
    -- = ''` the functions below pin.
    id                  uuid primary key default pg_catalog.gen_random_uuid(),

    -- The abandoned account. NULLED when it is retired (see the FK).
    source_user_id      uuid references auth.users(id) on delete set null,

    -- The account that received it. Written at COMPLETE, never passed in.
    destination_user_id uuid references auth.users(id) on delete cascade,

    provider            text not null check (provider in ('apple', 'email')),

    -- sha256("<provider>:<subject>") as 64 lowercase hex characters.
    -- NULLED at completion: it has no further use, and an identifier
    -- digest kept past its purpose is an identifier kept past its purpose.
    subject_hash        text check (subject_hash is null or subject_hash ~ '^[0-9a-f]{64}$'),

    state               text not null default 'open'
                          check (state in ('open', 'completed')),

    created_at          timestamptz not null default now(),

    -- Garbage collection, NOT a credential lifetime. The pre-commitment is
    -- redeemable only by an account that already owns the named subject,
    -- so a long window costs nothing in security and buys the one thing
    -- that matters: a handoff interrupted by an offline stretch, a crash or
    -- a reinstall still completes when she next signs in.
    expires_at          timestamptz not null default now() + interval '30 days',

    completed_at        timestamptz,
    source_retired_at   timestamptz
);

comment on table public.account_handoffs is
  'v25 §41 — the durable record of an ownership transition from an
   anonymous account to a permanent one. Holds no health data, no token and
   no identifier of a retired account: source_user_id is SET NULL by its own
   foreign key at retirement and subject_hash is nulled in the same
   statement. Invisible to every client role; only the SECURITY DEFINER
   functions below read or write it.';

-- BEGIN is idempotent because of this index: a double-tapped button, a
-- retried call or a relaunch produces one row, not two.
create unique index if not exists account_handoffs_open_uniq
    on public.account_handoffs (source_user_id, subject_hash)
    where state = 'open';

create index if not exists account_handoffs_subject_open_idx
    on public.account_handoffs (subject_hash)
    where state = 'open';

-- RLS ON WITH NO POLICIES = deny-all for every role that is not BYPASSRLS.
-- Stated explicitly rather than relied on, and the grants are revoked as
-- well so the table is not merely unreadable but unreachable.
alter table public.account_handoffs enable row level security;
revoke all on public.account_handoffs from anon, authenticated;

-- ------------------------- THE TRANSFER, PER FAMILY -----------------------
--
-- In `private`, with EXECUTE revoked from every client role, because a
-- function that takes (source, destination) and rewrites ownership IS the
-- admin merge endpoint the brief forbids. It is reachable only from
-- `public.complete_account_handoff`, which decides both arguments itself.

create or replace function private.transfer_account_rows(p_src uuid, p_dst uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_src_prefix text := lower(p_src::text);
    v_dst_prefix text := lower(p_dst::text);
begin
    if p_src is null or p_dst is null or p_src = p_dst then
        return;
    end if;

    -- ── 1 · SIMPLE MOVES ──────────────────────────────────────────────
    -- Primary key is a client-minted id and there is no per-user unique
    -- constraint, so ownership rewrites in place and EVERY RECORD ID IS
    -- PRESERVED. Nothing is deduplicated by content: two weigh-ins on one
    -- day are not duplicates, and two plates that look alike are not
    -- evidence about each other.
    update public.weight_logs        set user_id = p_dst where user_id = p_src;
    update public.food_logs          set user_id = p_dst where user_id = p_src;
    update public.food_log_items     set user_id = p_dst where user_id = p_src;
    update public.food_corrections   set user_id = p_dst where user_id = p_src;
    update public.session_logs       set user_id = p_dst where user_id = p_src;
    update public.session_ratings    set user_id = p_dst where user_id = p_src;
    update public.program_day_checks set user_id = p_dst where user_id = p_src;

    -- ── 2 · DETERMINISTIC IDS ─────────────────────────────────────────
    -- `dose_events.id` is "<uid>-dose-<dayKey>", `observations.id` is
    -- "<uid>-symptom-<symptom>-<dayKey>", `weekly_reads.id` is
    -- "<uid>-read-<windowStartDay>", all lowercased. The prefix is
    -- swapped so the id becomes exactly the one the destination account
    -- WOULD MINT for that slot — her next mark of that dose day upserts
    -- onto this row instead of creating a second. A row whose id does not
    -- carry the source uid keeps its id and only changes owner; an id is
    -- never guessed at.
    --
    -- THE ACCOUNT'S OWN ROW WINS A COLLISION. One id means one slot on one
    -- day for one account; two rows cannot both be it, and CONTENT IS
    -- NEVER COMPARED.
    delete from public.dose_events s
     where s.user_id = p_src
       and lower(s.id) like v_src_prefix || '%'
       and exists (
           select 1 from public.dose_events d
            where d.user_id = p_dst
              and d.id = v_dst_prefix || substring(lower(s.id) from length(v_src_prefix) + 1));
    update public.dose_events
       set user_id = p_dst,
           id = case when lower(id) like v_src_prefix || '%'
                     then v_dst_prefix || substring(lower(id) from length(v_src_prefix) + 1)
                     else id end
     where user_id = p_src;

    delete from public.observations s
     where s.user_id = p_src
       and lower(s.id) like v_src_prefix || '%'
       and exists (
           select 1 from public.observations d
            where d.user_id = p_dst
              and d.id = v_dst_prefix || substring(lower(s.id) from length(v_src_prefix) + 1));
    update public.observations
       set user_id = p_dst,
           id = case when lower(id) like v_src_prefix || '%'
                     then v_dst_prefix || substring(lower(id) from length(v_src_prefix) + 1)
                     else id end
     where user_id = p_src;

    delete from public.weekly_reads s
     where s.user_id = p_src
       and lower(s.id) like v_src_prefix || '%'
       and exists (
           select 1 from public.weekly_reads d
            where d.user_id = p_dst
              and d.id = v_dst_prefix || substring(lower(s.id) from length(v_src_prefix) + 1));
    update public.weekly_reads
       set user_id = p_dst,
           id = case when lower(id) like v_src_prefix || '%'
                     then v_dst_prefix || substring(lower(id) from length(v_src_prefix) + 1)
                     else id end
     where user_id = p_src;

    -- ── 3 · COMPOSITE KEYS ────────────────────────────────────────────
    -- These three CANNOT be moved without a collision rule, because the
    -- user id is IN the key. Read from the live catalog, not the
    -- repository:
    --
    --     public.day_progress           PRIMARY KEY (user_id, program_day)
    --     public.exercise_calibrations  PRIMARY KEY (user_id, exercise_type)
    --     public.day_reflections        UNIQUE      (user_id, day_key)
    --
    -- Destination wins, whole row, content never compared. A day of the
    -- anonymous period is not evidence about a day the destination account
    -- already lived.
    delete from public.day_progress s
     where s.user_id = p_src
       and exists (select 1 from public.day_progress d
                    where d.user_id = p_dst and d.program_day = s.program_day);
    update public.day_progress set user_id = p_dst where user_id = p_src;

    delete from public.exercise_calibrations s
     where s.user_id = p_src
       and exists (select 1 from public.exercise_calibrations d
                    where d.user_id = p_dst and d.exercise_type = s.exercise_type);
    update public.exercise_calibrations set user_id = p_dst where user_id = p_src;

    delete from public.day_reflections s
     where s.user_id = p_src
       and exists (select 1 from public.day_reflections d
                    where d.user_id = p_dst and d.day_key = s.day_key);
    update public.day_reflections set user_id = p_dst where user_id = p_src;

    -- ── 4 · ONE LIVE PLAN, AND THE DESTINATION'S IS THE ACCOUNT'S ─────
    -- A plan is not an append-only ledger; its head is a current-state
    -- claim about which day she is on. The account she is keeping owns
    -- that claim. A's plan is not discarded — it arrives ARCHIVED, which
    -- is how this model already carries a superseded enrollment.
    if exists (select 1 from public.program_plans d
                where d.user_id = p_dst
                  and d.archived_at is null
                  and d.phase in ('active', 'maintenance', 'recomp', 'pause')) then
        update public.program_plans
           set phase = 'abandoned', archived_at = now(), updated_at = now()
         where user_id = p_src
           and archived_at is null
           and phase in ('active', 'maintenance', 'recomp', 'pause');
    end if;
    update public.program_plans set user_id = p_dst where user_id = p_src;

    -- ── 5 · AUTHORITY IS NOT PORTABLE ─────────────────────────────────
    -- The RLS on these two tables refuses a client insert of a prescribed
    -- fact or a care-team regimen, which is the schema saying out loud
    -- that they are not the app's to author. They are equally not the
    -- app's to MOVE: a prescription assigned to one identity by a clinic
    -- that has never met the other is not a record with a new owner, it
    -- is a fabricated provenance. They are refused, and they go with the
    -- account they were assigned to.
    --
    -- **NO AUTHORITY IS EVER DOWNGRADED TO MAKE A ROW CARRYABLE.**
    delete from public.program_facts
     where user_id = p_src and authority = 'prescribed';
    update public.program_facts set user_id = p_dst where user_id = p_src;

    delete from public.regimen_plans
     where user_id = p_src
       and (authority is distinct from 'self'
            or org_id is not null
            or source_protocol_id is not null);
    -- One live MEDICATION regimen, same rule as the plan: the account's
    -- own head keeps the present tense, A's arrives ended so her dose eras
    -- stay in the record.
    if exists (select 1 from public.regimen_plans d
                where d.user_id = p_dst and d.kind = 'medication' and d.ended_at is null) then
        update public.regimen_plans
           set ended_at = now(), end_reason = 'ended', updated_at = now()
         where user_id = p_src and kind = 'medication' and ended_at is null;
    end if;
    update public.regimen_plans set user_id = p_dst where user_id = p_src;

    -- ── 6 · REFUSED, AND THEREFORE DELETED WITH THE SOURCE ────────────
    -- Nothing is written for these. They all cascade from `auth.users`,
    -- so the retirement removes them, which is the correct outcome:
    --
    --   public.users            the profile. Its PRIMARY KEY IS the uid,
    --                           so it cannot move; and the account she
    --                           reached owns its own height, weight, goal
    --                           and cohort. Carrying a device's profile
    --                           over an account's is the exact shape `29`
    --                           spent a pass removing.
    --   consent_grants          a grant made as one identity is not
    --                           another's answer. UNKNOWN CONSENT IS
    --                           NEVER PERMISSION.
    --   care_relationships      a clinic relationship is between a clinic
    --   visit_packets           and an IDENTITY. None of it widens because
    --   org_members             two accounts met on one phone.
    --   correction_requests
    --   protocol_assignments
    --
    -- ── 7 · NOT TRANSFERRED, BY EXISTING DECISION ─────────────────────
    --   food_vision_telemetry · jeni_chat_telemetry   `set null`, a stated
    --                                                 choice (`38` §1.2)
    --   care_weekly_summaries                         no FK; §12 is still
    --                                                 unanswered and this
    --                                                 migration does not
    --                                                 answer it
    --   care_audit_events · patient_invitations.accepted_by ·
    --   invitation_attempts · ops_events              §40 §11's four
    --                                                 retention decisions
end;
$$;

revoke all on function private.transfer_account_rows(uuid, uuid) from public, anon, authenticated;

-- ------------------------------- BEGIN ------------------------------------

create or replace function public.begin_account_handoff(
    p_provider text,
    p_subject_hash text
) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_source uuid := auth.uid();
    v_is_anonymous boolean;
    v_open_for_subject integer;
    v_id uuid;
begin
    if v_source is null then
        raise exception 'Not authenticated' using errcode = '28000';
    end if;
    if p_provider is null or p_provider not in ('apple', 'email') then
        raise exception 'Unsupported provider' using errcode = '22023';
    end if;
    if p_subject_hash is null or p_subject_hash !~ '^[0-9a-f]{64}$' then
        raise exception 'Malformed subject' using errcode = '22023';
    end if;

    -- ▎ THE NAMED → NAMED FIREWALL, SERVER-SIDE, AND FIRST.
    --
    -- The gate is POSITIVE PROOF that the source is anonymous, read from
    -- `auth.users` rather than inferred from a uid difference, a missing
    -- profile, a fresh account or the absence of an Apple identity. A
    -- permanent account cannot open a handoff at all, so no later step
    -- can be tricked into moving one customer's record into another's.
    select u.is_anonymous into v_is_anonymous
      from auth.users u where u.id = v_source;
    if v_is_anonymous is not true then
        raise exception 'Only an anonymous account may begin a handoff'
            using errcode = '42501';
    end if;

    -- Bounds the injection residual described in the header: an attacker
    -- who somehow knew a victim's subject digest could pre-commit at most
    -- this many anonymous accounts to it.
    select count(*) into v_open_for_subject
      from public.account_handoffs h
     where h.subject_hash = p_subject_hash
       and h.state = 'open'
       and h.expires_at > now();
    if v_open_for_subject >= 10 then
        raise exception 'Too many open handoffs for this destination'
            using errcode = '54000';
    end if;

    insert into public.account_handoffs (source_user_id, provider, subject_hash)
    values (v_source, p_provider, p_subject_hash)
        on conflict (source_user_id, subject_hash) where state = 'open'
        do update set expires_at = now() + interval '30 days'
    returning id into v_id;

    return v_id;
end;
$$;

revoke all on function public.begin_account_handoff(text, text) from public, anon;
grant execute on function public.begin_account_handoff(text, text) to authenticated;

-- ------------------------------ COMPLETE ----------------------------------

create or replace function public.complete_account_handoff(
    p_source_user_id uuid default null,
    p_mode text default 'move'
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_dest uuid := auth.uid();
    v_dest_anonymous boolean;
    v_subjects text[];
    r record;
    v_moved integer := 0;
    v_retired integer := 0;
begin
    if v_dest is null then
        raise exception 'Not authenticated' using errcode = '28000';
    end if;
    if p_mode is null or p_mode not in ('move', 'retire') then
        raise exception 'Unknown mode' using errcode = '22023';
    end if;

    -- A destination must be a PERMANENT account. An anonymous caller can
    -- never absorb anything, which removes a whole class of attack before
    -- any lookup happens.
    select u.is_anonymous into v_dest_anonymous
      from auth.users u where u.id = v_dest;
    if v_dest_anonymous is not false then
        raise exception 'An anonymous account may not receive a handoff'
            using errcode = '42501';
    end if;

    -- ▎ THE WHOLE AUTHORIZATION. The subjects THIS caller demonstrably
    -- ▎ owns, computed server-side from its OWN identity rows. Nothing the
    -- ▎ client sends can widen this set, because the client sends no
    -- ▎ identity at all.
    select coalesce(array_agg(s), '{}'::text[]) into v_subjects
      from (
        select encode(pg_catalog.sha256(
                   pg_catalog.convert_to('apple:' || (i.identity_data ->> 'sub'), 'UTF8')
               ), 'hex') as s
          from auth.identities i
         where i.user_id = v_dest
           and i.provider = 'apple'
           and (i.identity_data ->> 'sub') is not null
        union
        select encode(pg_catalog.sha256(
                   pg_catalog.convert_to('email:' || lower(u.email), 'UTF8')
               ), 'hex')
          from auth.users u
         where u.id = v_dest
           and u.email is not null
      ) t;

    if array_length(v_subjects, 1) is null then
        return jsonb_build_object('moved', 0, 'retired', 0);
    end if;

    for r in
        select h.id, h.source_user_id
          from public.account_handoffs h
         where h.state = 'open'
           and h.expires_at > now()
           and h.subject_hash = any(v_subjects)
           and h.source_user_id is not null
           and h.source_user_id <> v_dest
           and (p_source_user_id is null or h.source_user_id = p_source_user_id)
         for update
    loop
        -- Re-checked AT USE, not only at BEGIN. An account that became
        -- permanent by another path between the two calls is no longer a
        -- handoff source, and must never be deleted by one.
        if not exists (
            select 1 from auth.users u
             where u.id = r.source_user_id and u.is_anonymous is true
        ) then
            continue;
        end if;

        -- 'move'   the server carries the record, ids preserved.
        -- 'retire' the CLIENT has already carried it under fresh ids
        --          (the legacy path, used when this function was
        --          unreachable at the moment of the switch); moving again
        --          would duplicate her record, so only the retirement is
        --          owed. The client records which one it did at the
        --          instant it did it, so a crash cannot change the answer.
        if p_mode = 'move' then
            perform private.transfer_account_rows(r.source_user_id, v_dest);
            v_moved := v_moved + 1;
        end if;

        -- Storage FIRST: `storage.objects` has NO foreign key to
        -- `auth.users` (verified from the live catalog), so once the auth
        -- row is gone nothing can ever name these objects again. This is
        -- deliberately duplicated from Package A1 rather than depending on
        -- it: the handoff must be correct whether or not A1 has been
        -- applied.
        delete from storage.objects o
         where o.bucket_id in ('food-photos', 'body-scans')
           and (o.name like r.source_user_id::text || '/%'
                or o.owner = r.source_user_id);

        -- THE TERMINAL STATE OF THE SOURCE. `is_anonymous` is asserted on
        -- the DELETE itself, as belt and braces, so a permanent account
        -- can never be matched however this function is reached.
        delete from auth.users u
         where u.id = r.source_user_id and u.is_anonymous is true;
        v_retired := v_retired + 1;

        -- The FK's ON DELETE SET NULL has already anonymised
        -- `source_user_id`; this records what happened and drops the
        -- subject digest, which has no further use.
        update public.account_handoffs
           set state = 'completed',
               destination_user_id = v_dest,
               completed_at = now(),
               source_retired_at = now(),
               subject_hash = null
         where id = r.id;
    end loop;

    return jsonb_build_object('moved', v_moved, 'retired', v_retired);
end;
$$;

revoke all on function public.complete_account_handoff(uuid, text) from public, anon;
grant execute on function public.complete_account_handoff(uuid, text) to authenticated;

-- ==========================================================================
-- ============================== ROLLBACK ==================================
-- ==========================================================================
--
-- drop function if exists public.complete_account_handoff(uuid, text);
-- drop function if exists public.begin_account_handoff(text, text);
-- drop function if exists private.transfer_account_rows(uuid, uuid);
-- drop table if exists public.account_handoffs;
--
-- Rolling back is safe at any time: no other object depends on these, no
-- column was added to a customer table, and no existing function changed.
-- A client that calls a dropped function gets a 404 and falls back to the
-- behaviour it has today.

-- ==========================================================================
-- ============================ SAFETY MATRIX ===============================
-- ==========================================================================
--
-- BUILD 30 (live) AFTER THIS MIGRATION
--   trigger a handoff?     NO — it calls no function by these names.
--   read a receipt?        NO — no grant, no policy, RLS on.
--   write a receipt?       NO.
--   move another user's    NO — the only mover is `private`, execute
--     data?                  revoked from every client role.
--   break login?           NO — nothing in the auth path changed.
--   lose local data?       NO — no client behaviour changes at all.
--   VERDICT                **INVISIBLE. Additive in the strictest sense.**
--
-- BUILD 31 (this session's build) AFTER THIS MIGRATION
--   Identical to build 30 on this contract: it does not call these
--   functions either. The client that adopts the protocol is step 3 of the
--   deploy order and is deliberately NOT in this build — a client written
--   against a contract nobody has verified in production is the same class
--   of error as `38` §11's "PROVEN BY CODE" storage purge that had never
--   been applied.
--
-- A CLIENT CARRYING THE PROTOCOL, BEFORE THIS MIGRATION IS APPLIED
--   `begin_account_handoff` returns 404 (PGRST202); the client catches it
--   and behaves exactly as today — one best-effort retirement at the
--   switch, and the legacy fresh-id carry. **Degrades, never breaks.**
--
-- DEPLOY ORDER
--   1. apply this migration
--   2. verify in production, read-only: the table exists, both functions
--      exist, `has_function_privilege('authenticated', …)` is true for the
--      two public ones and FALSE for `private.transfer_account_rows`
--   3. ship the client that calls BEGIN before the identity call and
--      COMPLETE after the switch
--   4. adoption window
--   5. only then consider removing the client-side best-effort retirement
--
-- SECRET REQUIRED   none.
-- FOUNDER ACTION    read the authorization argument in this header, then
--                   apply. It is the only thing that closes "the source
--                   uid survives forever because one delete request
--                   failed".
