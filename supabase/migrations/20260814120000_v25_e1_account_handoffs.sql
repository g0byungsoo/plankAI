-- v25 §42 — THE ACCOUNT HANDOFF (PACKAGE E1, CORRECTED AND APPLIED)
--
-- ==========================================================================
-- ==  THIS IS THE FILE THAT WAS APPLIED. It is NOT byte-identical to      ==
-- ==  docs/app_v25/41_packages/E1_account_handoffs.sql, which is left     ==
-- ==  unmodified as `41`'s record. Eight corrections were found by        ==
-- ==  auditing that file as hostile code against the LIVE catalog before  ==
-- ==  applying it; each is marked [CORR-n] below and every one is         ==
-- ==  restated in docs/app_v25/42_THE_HANDOFF_ACTUALLY_RUNS.md.           ==
-- ==                                                                      ==
-- ==  [CORR-1] BLOCKER. storage.objects carries `protect_objects_delete`, ==
-- ==           a BEFORE DELETE **FOR EACH STATEMENT** trigger that raises ==
-- ==           42501 on ANY direct delete — including one that matches    ==
-- ==           ZERO ROWS. Proven against production. `41`'s COMPLETE      ==
-- ==           would have thrown on every call, for every customer,       ==
-- ==           forever. (Package A1 has the identical defect and would    ==
-- ==           have broken "delete my account" for 100% of customers.)    ==
-- ==  [CORR-2] Deterministic ids lowercased their TAIL, so the server     ==
-- ==           and the client would mint DIFFERENT ids for the same slot. ==
-- ==           Production `observations.id` values contain uppercase      ==
-- ==           (ObservationKind.rawValue is camelCase). Tail case is now  ==
-- ==           preserved and collisions compared case-insensitively.      ==
-- ==  [CORR-3] provider 'email' removed. An Apple `sub` comes from a      ==
-- ==           credential Apple signed for this device; a typed email is  ==
-- ==           proof of nothing, and a typo matching another customer's   ==
-- ==           address would hand him her record. Exfiltration, not the   ==
-- ==           injection residual `41` named.                             ==
-- ==  [CORR-4] program_day_checks DOES have a per-user unique key         ==
-- ==           (user_id, program_plan_id, program_day, item_key) — `41`   ==
-- ==           said it had none. Guarded like every other composite key.  ==
-- ==  [CORR-5] public.coach_messages was in no list at all. Named, and    ==
-- ==           transferred rather than silently deleted with the source.  ==
-- ==  [CORR-6] A per-SOURCE cap on open receipts. `41` capped per-subject ==
-- ==           only, so one anonymous session could write unbounded rows. ==
-- ==  [CORR-7] The profile. `41` §25's rule is "the source's row fills a  ==
-- ==           total absence"; the server implemented only "destination   ==
-- ==           wins", so a destination with no profile lost her body      ==
-- ==           facts. 87 of 867 permanent accounts have no profile row.   ==
-- ==  [CORR-8] A same-uid upgrade's pre-link receipt is now closed        ==
-- ==           deterministically instead of sitting open for 30 days.     ==
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
--   ▎ THE REMAINING PROBLEM CANNOT HONESTLY BE SOLVED BY ANOTHER CLIENT
--   ▎ RETRY. THE OWNERSHIP TRANSITION NEEDS A DURABLE SERVER-SIDE HANDOFF.
--
-- ==========================================================================
-- THE AUTHORIZATION, WHICH IS THE HARD PART
-- ==========================================================================
--
-- An endpoint that accepts `source_uid` and `destination_uid` and trusts
-- the caller is an account-takeover primitive. This design accepts NEITHER
-- as an authorization input.
--
--   1. **BEGIN, while the source is still authenticated.** The anonymous
--      session — and only an anonymous session — writes a receipt naming
--      ITSELF (`auth.uid()`, never a parameter) and PRE-COMMITTING to the
--      destination it is about to reach, as a SHA-256 of "apple:<sub>".
--
--   2. **COMPLETE, as the destination.** The caller passes no identity at
--      all. The server computes the set of subject hashes THIS caller
--      demonstrably owns, from its own `auth.identities` rows, and acts
--      only on open receipts whose pre-commitment is in that set.
--
--   ▎ SO THE PROOF IS NOT A BEARER CREDENTIAL. It cannot be stolen and
--   ▎ replayed, because redeeming it requires BEING the account that owns
--   ▎ the pre-committed subject. Nothing secret is persisted on the device.
--
-- A client that lies about the subject at BEGIN produces a receipt nobody,
-- including itself, can ever complete. **A lie only locks the liar out.**
--
-- ### The residual, stated rather than glossed
--
-- An attacker who ALREADY KNOWS a victim's Apple `sub` for this app could
-- pre-commit their own anonymous account to it, and the victim's next
-- sign-in would absorb the attacker's rows. That is data INJECTION, not
-- exfiltration — nothing of the victim's leaves — and it requires a value
-- that is per-developer-team, is not derivable from an email address, and
-- exists server-side only in `auth.identities.identity_data`, which no
-- client can read. Bounded by the `is_anonymous` gate on the source and by
-- the two caps below. A security argument that names no residual is not a
-- security argument.
--
-- ==========================================================================
-- WHY THE SERVER MOVES THE ROWS RATHER THAN ONLY DELETING THEM
-- ==========================================================================
--
--     every UPDATE policy is  USING (auth.uid() = user_id)
--                       AND   WITH CHECK (auth.uid() = user_id)
--
--   ▎ NO SINGLE BEARER TOKEN CAN SATISFY BOTH HALVES OF AN OWNERSHIP
--   ▎ CHANGE. THAT IS NOT A GAP IN THE POLICIES. IT IS THE POLICIES
--   ▎ WORKING.
--
-- And it buys the property the client cannot: **RECORD IDS SURVIVE**, and
-- the transfer is based on SERVER truth rather than on whatever this
-- device happens to hold — which is what makes a handoff from a
-- half-hydrated reinstall correct instead of lossy.
--
-- ==========================================================================
-- WHY THERE IS NO STATE MACHINE
-- ==========================================================================
--
-- Rows, storage objects and `auth.users` are all ordinary DML in the same
-- Postgres transaction, so a handoff either happens or does not. **Two
-- states, and the second is terminal.** A transient failure rolls back to
-- `open`, which is already the retry state.

-- ==========================================================================
-- ============================== FORWARD ===================================
-- ==========================================================================

create schema if not exists private;

-- ------------------------------- THE RECEIPT ------------------------------

create table if not exists public.account_handoffs (
    -- Fully qualified deliberately: a DEFAULT is resolved with the
    -- SESSION search_path at CREATE TABLE time, not with the `search_path
    -- = ''` the functions below pin. [CORR-8] now() is qualified too.
    id                  uuid primary key default pg_catalog.gen_random_uuid(),

    -- The abandoned account. NULLED when it is retired (see the FK).
    source_user_id      uuid references auth.users(id) on delete set null,

    -- The account that received it. Written at COMPLETE, never passed in.
    destination_user_id uuid references auth.users(id) on delete cascade,

    -- [CORR-3] 'apple' ONLY. See the header. Widening this is a deliberate
    -- migration, which is the right amount of friction for a decision that
    -- has an exfiltration mode.
    provider            text not null check (provider in ('apple')),

    -- sha256("apple:<sub>") as 64 lowercase hex characters. NULLED at
    -- completion: an identifier digest kept past its purpose is an
    -- identifier kept past its purpose.
    subject_hash        text check (subject_hash is null or subject_hash ~ '^[0-9a-f]{64}$'),

    state               text not null default 'open'
                          check (state in ('open', 'completed')),

    created_at          timestamptz not null default pg_catalog.now(),

    -- Garbage collection, NOT a credential lifetime. The pre-commitment is
    -- redeemable only by an account that already owns the named subject,
    -- so a long window costs nothing in security and buys the one thing
    -- that matters: a handoff interrupted by an offline stretch, a crash
    -- or a reinstall still completes when she next signs in.
    expires_at          timestamptz not null default pg_catalog.now() + interval '30 days',

    completed_at        timestamptz,
    source_retired_at   timestamptz
);

comment on table public.account_handoffs is
  'v25 42 - the durable record of an ownership transition from an anonymous
   account to a permanent one. Holds no health data, no token and no
   identifier of a retired account: source_user_id is SET NULL by its own
   foreign key at retirement and subject_hash is nulled in the same
   statement. Invisible to every client role. Only the SECURITY DEFINER
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
--
-- NOTE, verified rather than assumed: `authenticated` DOES hold USAGE on
-- schema `private` in this project (it was created by the v8 care
-- platform). So the schema is not a wall — the REVOKE below is the wall,
-- and it is load-bearing.

create or replace function private.transfer_account_rows(p_src uuid, p_dst uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_src_prefix text := lower(p_src::text);
    v_dst_prefix text := lower(p_dst::text);
    v_plen       integer := length(p_src::text);
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
    update public.weight_logs      set user_id = p_dst where user_id = p_src;
    update public.food_logs        set user_id = p_dst where user_id = p_src;
    update public.food_log_items   set user_id = p_dst where user_id = p_src;
    update public.food_corrections set user_id = p_dst where user_id = p_src;
    update public.session_logs     set user_id = p_dst where user_id = p_src;
    update public.session_ratings  set user_id = p_dst where user_id = p_src;

    -- [CORR-5] `public.coach_messages` appeared in NO list in `41` —
    -- neither transferred nor refused — so a handoff would have deleted
    -- her transcript with the source account without anyone deciding
    -- that. It has PRIMARY KEY (id) and no per-user unique key, so it is
    -- a simple move. Zero rows in production today (`37` deprecated its
    -- only writer), which is exactly when a rule is cheapest to make.
    update public.coach_messages   set user_id = p_dst where user_id = p_src;

    -- [CORR-4] `program_day_checks` HAS a per-user unique key —
    --     UNIQUE (user_id, program_plan_id, program_day, item_key)
    -- read from the live catalog. `41` §24 called it uncollidable
    -- "because the plan id is rewritten to a fresh uuid", which is the
    -- CLIENT's re-key; the server PRESERVES plan ids, so that reasoning
    -- does not transfer. The collision needs the destination to already
    -- hold a row pointing at one of the SOURCE's plan ids, which is not a
    -- reachable state — but "not reachable" is not "guarded", and an
    -- unguarded unique key inside a one-transaction merge is precisely
    -- the defect `41` found for day_progress.
    delete from public.program_day_checks s
     where s.user_id = p_src
       and exists (select 1 from public.program_day_checks d
                    where d.user_id = p_dst
                      and d.program_plan_id is not distinct from s.program_plan_id
                      and d.program_day = s.program_day
                      and d.item_key = s.item_key);
    update public.program_day_checks set user_id = p_dst where user_id = p_src;

    -- ── 2 · DETERMINISTIC IDS ─────────────────────────────────────────
    -- `dose_events.id`  is "<uid>-dose-<dayKey>"
    -- `observations.id` is "<uid>-<kind>-<dayKey>"
    -- `weekly_reads.id` is "<uid>-read-<windowStartDay>"
    --
    -- The prefix is swapped so the id becomes exactly the one the
    -- destination account WOULD MINT for that slot — her next mark of
    -- that dose day upserts onto this row instead of creating a second.
    --
    -- [CORR-2] THE TAIL'S CASE IS PRESERVED. `41` wrote
    -- `substring(lower(id) …)`, which lowercases the whole tail. The
    -- client mints `userId.lowercased()` as the prefix and leaves the
    -- tail alone (`IdentityMerge.rekeyedDeterministicId` is
    -- `new + id.dropFirst(old.count)`), and `ObservationKind.rawValue`
    -- is camelCase — production `observations.id` values verifiably
    -- contain uppercase. Lowercasing the tail would have produced an id
    -- the client never mints, so her next log of that symptom on that
    -- day would have created a SECOND row: the exact duplication a
    -- deterministic id exists to prevent, introduced by the function
    -- whose job is to preserve it.
    --
    -- THE ACCOUNT'S OWN ROW WINS A COLLISION. One id means one slot on
    -- one day for one account; two rows cannot both be it, and CONTENT
    -- IS NEVER COMPARED.
    delete from public.dose_events s
     where s.user_id = p_src
       and lower(s.id) like v_src_prefix || '%'
       and exists (
           select 1 from public.dose_events d
            where d.user_id = p_dst
              and lower(d.id) = v_dst_prefix || lower(substring(s.id from v_plen + 1)));
    update public.dose_events
       set user_id = p_dst,
           id = case when lower(id) like v_src_prefix || '%'
                     then v_dst_prefix || substring(id from v_plen + 1)
                     else id end
     where user_id = p_src;

    delete from public.observations s
     where s.user_id = p_src
       and lower(s.id) like v_src_prefix || '%'
       and exists (
           select 1 from public.observations d
            where d.user_id = p_dst
              and lower(d.id) = v_dst_prefix || lower(substring(s.id from v_plen + 1)));
    update public.observations
       set user_id = p_dst,
           id = case when lower(id) like v_src_prefix || '%'
                     then v_dst_prefix || substring(id from v_plen + 1)
                     else id end
     where user_id = p_src;

    delete from public.weekly_reads s
     where s.user_id = p_src
       and lower(s.id) like v_src_prefix || '%'
       and exists (
           select 1 from public.weekly_reads d
            where d.user_id = p_dst
              and lower(d.id) = v_dst_prefix || lower(substring(s.id from v_plen + 1)));
    update public.weekly_reads
       set user_id = p_dst,
           id = case when lower(id) like v_src_prefix || '%'
                     then v_dst_prefix || substring(id from v_plen + 1)
                     else id end
     where user_id = p_src;

    -- ── 3 · COMPOSITE KEYS ────────────────────────────────────────────
    -- These three CANNOT be moved without a collision rule, because the
    -- user id is IN the key. Read from the live catalog:
    --
    --     public.day_progress           PRIMARY KEY (user_id, program_day)
    --     public.exercise_calibrations  PRIMARY KEY (user_id, exercise_type)
    --     public.day_reflections        UNIQUE      (user_id, day_key)
    --
    -- Destination wins, whole row, content never compared. A day of the
    -- anonymous period is not evidence about a day the destination
    -- account already lived.
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

    -- `public.day_reflections` is the one SERVER-backed family that was
    -- in no merge at all, in either direction (`41` §2.2). Her evening
    -- words. It transfers here, keyed by (user_id, day_key), destination
    -- wins a shared day.
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
    -- is a fabricated provenance.
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
    -- own head keeps the present tense, A's arrives ended so her dose
    -- eras stay in the record.
    if exists (select 1 from public.regimen_plans d
                where d.user_id = p_dst and d.kind = 'medication' and d.ended_at is null) then
        update public.regimen_plans
           set ended_at = now(), end_reason = 'ended', updated_at = now()
         where user_id = p_src and kind = 'medication' and ended_at is null;
    end if;
    update public.regimen_plans set user_id = p_dst where user_id = p_src;

    -- ── 6 · THE PROFILE ───────────────────────────────────────────────
    -- [CORR-7] `public.users.id` IS the uid, so the row cannot move, and
    -- the account she reached owns its own height, weight, goal, sex and
    -- cohort — `41` §25, and the shape `29` spent a whole pass removing.
    -- That is DESTINATION WINS, and `41` implemented only that half.
    --
    -- The other half of its own stated rule is "the source's row is used
    -- ONLY when the destination has none". Without it, a destination
    -- account with no profile row loses her body facts to the cascade —
    -- 87 of 867 permanent accounts are in exactly that state — and the
    -- client cannot be relied on to repair it, because a half-hydrated
    -- reinstall may hold no local profile either (§22).
    --
    -- Monotone by construction: it can only ever ADD a row that does not
    -- exist. It never overwrites one, so no safety fact, cohort fact or
    -- goal of the destination's is touched, and nothing is inferred.
    if not exists (select 1 from public.users d where d.id = p_dst) then
        insert into public.users
        select (pg_catalog.jsonb_populate_record(
                    null::public.users,
                    pg_catalog.to_jsonb(s) || pg_catalog.jsonb_build_object('id', p_dst)
                )).*
          from public.users s
         where s.id = p_src;
    end if;

    -- ── 7 · REFUSED, AND THEREFORE DELETED WITH THE SOURCE ────────────
    -- Nothing is written for these. They all cascade from `auth.users`,
    -- so the retirement removes them, which is the correct outcome:
    --
    --   public.users            the source's own row, once the fill
    --                           above has (or has not) run.
    --   consent_grants          a grant made as one identity is not
    --                           another's answer. UNKNOWN CONSENT IS
    --                           NEVER PERMISSION.
    --   care_relationships      a clinic relationship is between a clinic
    --   visit_packets           and an IDENTITY. None of it widens
    --   org_members             because two accounts met on one phone.
    --   correction_requests     **NAMED CONSEQUENCE: all 10 care
    --   protocol_assignments    relationships in production have an
    --                           ANONYMOUS patient, so the first handoff
    --                           for such a patient ENDS her clinic
    --                           relationship. That is already true of the
    --                           shipping client-side retirement; this
    --                           migration makes it durable, not new. The
    --                           clinic's own audit trail survives
    --                           (`care_audit_events` has no FK).**
    --
    -- ── 8 · NOT TRANSFERRED, BY EXISTING DECISION ─────────────────────
    --   food_vision_telemetry · jeni_chat_telemetry   `set null` (`38` §1.2)
    --   care_weekly_summaries                         no FK; `40` §12 is
    --                                                 still unanswered and
    --                                                 this does not answer it
    --   care_audit_events · patient_invitations.accepted_by ·
    --   private.invitation_attempts · ops_events      `40` §11's retention
    --                                                 decisions
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
    v_open_for_source integer;
    v_id uuid;
begin
    if v_source is null then
        raise exception 'Not authenticated' using errcode = '28000';
    end if;

    -- [CORR-3] APPLE ONLY, AND THE REASON IS NOT TASTE.
    --
    -- The Apple `sub` reaches the client inside an identity token Apple
    -- SIGNED for this device after the customer authenticated with her
    -- own Apple ID. It is evidence.
    --
    -- A typed email address is not. BEGIN necessarily runs BEFORE the
    -- sign-in — that is the whole design — so for the email door the
    -- subject would be a string the customer typed and nobody has
    -- verified. A single typo landing on another real Jeni account's
    -- address would create an open receipt that the stranger's next
    -- sign-in redeems: her entire record moves into his account and hers
    -- is retired. That is EXFILTRATION, and it is a different and worse
    -- animal than the injection residual in the header.
    --
    -- So the email door keeps `40`'s client-side best-effort retirement
    -- and is NOT covered by the durable handoff. Stated as a limitation
    -- rather than closed with a guess.
    if p_provider is null or p_provider not in ('apple') then
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

    -- [CORR-6] AND A CAP PER SOURCE. `41` capped only per SUBJECT, so a
    -- single anonymous session could insert unbounded receipts by
    -- varying the hash. A source legitimately needs more than one open
    -- receipt only if the customer abandons one sign-in sheet and opens
    -- another with a different Apple ID, which is rare and small.
    select count(*) into v_open_for_source
      from public.account_handoffs h
     where h.source_user_id = v_source
       and h.state = 'open'
       and h.expires_at > now();
    if v_open_for_source >= 5 then
        raise exception 'Too many open handoffs for this account'
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
    v_this integer := 0;
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

    -- [CORR-8] THE SAME-UID UPGRADE'S RECEIPT, CLOSED DETERMINISTICALLY.
    --
    -- The client opens a receipt BEFORE the Apple call, because that is
    -- the last instant the source is still authenticated. When the link
    -- SUCCEEDS the uid does not change, so the receipt names the caller
    -- as its own source: it is unredeemable by anyone (the loop below
    -- excludes `source = destination`) and it would otherwise sit `open`
    -- for thirty days as a dangling authorization artifact.
    --
    -- Deleting it can only ever remove the CALLER'S OWN receipt naming
    -- the CALLER'S OWN uid, so it is not a third state and not a
    -- privilege: it is the upgrade path cleaning up after itself.
    delete from public.account_handoffs
     where state = 'open' and source_user_id = v_dest;

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

        -- [CORR-1] THE BLOCKER, AND IT WOULD HAVE FIRED ON EVERY CALL.
        --
        -- `storage.objects` carries `protect_objects_delete`, a
        --     BEFORE DELETE ... FOR EACH STATEMENT
        -- trigger raising 42501 unless `storage.allow_delete_query` is
        -- 'true'. A STATEMENT-level trigger fires once per DELETE
        -- STATEMENT — including one that matches ZERO ROWS — so `41`'s
        -- version aborted the whole handoff transaction every single
        -- time, for every customer, forever. Proven against production
        -- before this migration was applied.
        --
        -- `set_config(..., is_local => true)` scopes the permission to
        -- THIS transaction, which is the mechanism the Storage service
        -- itself uses.
        --
        -- Storage FIRST, because `storage.objects` has NO foreign key to
        -- `auth.users` (verified from the live catalog), so once the auth
        -- row is gone nothing can ever name these objects again. This is
        -- deliberately duplicated from Package A1 rather than depending
        -- on it: the handoff must be correct whether or not A1 has been
        -- applied — and A1 as written has this identical defect, which
        -- would have broken "delete my account" for 100% of customers.
        perform pg_catalog.set_config('storage.allow_delete_query', 'true', true);
        delete from storage.objects o
         where o.bucket_id in ('food-photos', 'body-scans')
           and (o.name like r.source_user_id::text || '/%'
                or o.owner = r.source_user_id);

        -- THE TERMINAL STATE OF THE SOURCE. `is_anonymous` is asserted on
        -- the DELETE itself, as belt and braces, so a permanent account
        -- can never be matched however this function is reached.
        delete from auth.users u
         where u.id = r.source_user_id and u.is_anonymous is true;
        get diagnostics v_this = row_count;
        v_retired := v_retired + v_this;

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
-- behaviour it has today. `private` is NOT dropped — it predates this
-- migration and holds the v8 care platform's helpers.

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
-- A CLIENT CARRYING THE PROTOCOL, BEFORE THIS MIGRATION IS APPLIED
--   `begin_account_handoff` returns 404 (PGRST202); the client catches it
--   and behaves exactly as today. **Degrades, never breaks.**
--
-- SECRET REQUIRED   none.
