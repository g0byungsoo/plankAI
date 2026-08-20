-- PACKAGE A · 3 of 3 — TURN THREE OMISSIONS INTO THREE DECISIONS
--
-- ==========================================================================
-- ==  NOT WRITTEN TO supabase/migrations. NOT APPLIED.                    ==
-- ==  CHANGES NO BEHAVIOUR AND NO ROW. COMMENTS ONLY.                     ==
-- ==========================================================================
--
-- Three tables outlive an account deletion because they have no foreign key
-- to `auth.users`. Each is DEFENSIBLE. None is DECIDED — the schema records
-- an absence, and an absence cannot be audited, explained to a customer, or
-- relied on. One `comment on table` each fixes that at zero cost.
--
-- Measured 2026-08-14:
--     public.care_audit_events.patient_id      135 rows,   0 orphans
--     public.care_audit_events.actor_id        206 rows,   0 orphans
--     private.invitation_attempts.user_id       29 rows,   0 orphans
--     public.ops_events.actor_id                 0 rows,   0 orphans
--
-- `public.care_weekly_summaries` is NOT here: it is a live policy question
-- with two drafted migrations, and it is PACKAGE D.

-- ------------------------------- FORWARD ---------------------------------

comment on table public.care_audit_events is
  'CLINICAL AUDIT TRAIL. patient_id and actor_id are intentionally NOT
   foreign keys and survive account deletion: an audit record that can be
   erased by the party it audits is not an audit record. Rows carry WHO did
   WHAT and WHEN against an organisation, not health content. Reviewed
   2026-08-14 (v25 §40 §11); 135 patient rows, 206 actor rows, zero orphans.';

comment on table private.invitation_attempts is
  'RATE LIMITING. user_id is intentionally NOT a foreign key and survives
   account deletion: the row exists to bound invitation-code guessing, holds
   no health content, and a rate limit an attacker can clear by deleting an
   account is not a rate limit. Reviewed 2026-08-14 (v25 §40 §11); 29 rows,
   zero orphans.';

comment on table public.ops_events is
  'OPERATIONAL EVENTS. actor_id is intentionally NOT a foreign key and
   survives account deletion. No health content. Reviewed 2026-08-14
   (v25 §40 §11); currently zero rows.';

-- ------------------------------- ROLLBACK --------------------------------
-- comment on table public.care_audit_events is null;
-- comment on table private.invitation_attempts is null;
-- comment on table public.ops_events is null;
--
-- ------------------------------ SAFETY MATRIX -----------------------------
-- OLD CLIENT:      SAFE — comments are metadata.
-- NEW CLIENT:      SAFE.
-- DEPLOY ORDER:    any.
-- SECRET REQUIRED: none.
-- FOUNDER ACTION:  read the three sentences and confirm each is TRUE of the
--                  policy you intend. If any is not, the sentence changes
--                  and so does the schema — that is the whole point of
--                  writing it down.
