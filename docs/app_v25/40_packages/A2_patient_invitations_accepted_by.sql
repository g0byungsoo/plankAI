-- PACKAGE A · 2 of 3 — patient_invitations.accepted_by
--
-- ==========================================================================
-- ==  NOT WRITTEN TO supabase/migrations. NOT APPLIED.                    ==
-- ==========================================================================
--
-- WHAT THE COLUMN IS, measured 2026-08-14 rather than assumed:
--
--     patient_invitations columns:
--       id · org_id · created_by · code_hash · patient_label · status ·
--       expires_at · accepted_by · accepted_at · created_at
--
--     rows                                                        17
--     accepted (accepted_by not null)                             10
--     orphaned (accepted_by names a deleted user)                  0
--     accepted_by ALSO present in care_relationships.patient_id   10 of 10
--     accepted_by belonging to an ANONYMOUS account               10 of 10
--
-- SO: the row is the CLINIC's — the clinician created it (`created_by`,
-- `org_id`), it records that an invitation was issued and that it was
-- accepted, and `care_relationships` (which DOES cascade) already carries
-- the relationship itself. The only customer-owned datum on the row is the
-- raw patient uid in `accepted_by`.
--
-- THE FOUR OPTIONS AND THEIR CONSEQUENCES:
--
--   SET NULL   The clinic keeps its record that the invitation was issued
--              and accepted, and when; the patient identifier goes with her
--              account. Matches the precedent already in this schema
--              (`food_vision_telemetry` / `jeni_chat_telemetry`, both
--              `on delete set null`, recorded as a stated choice in §38
--              §1.2). CHOSEN AND DRAFTED BELOW.
--   CASCADE    Deletes another party's invitation record — including the
--              fact that they ever issued one. A customer's deletion right
--              covers her data, not the clinic's ledger. REFUSED.
--   PSEUDONYMIZE  A hash column plus a backfill plus a rewrite of every
--              reader, to preserve a join nothing currently makes. Nothing
--              in the product joins invitations to a patient after
--              acceptance; `care_relationships` does that. REFUSED as
--              disproportionate.
--   RETAIN     Keep the raw uid after account deletion. This is what
--              happens TODAY, by omission rather than decision, and it is
--              the one option that cannot be defended without a stated
--              obligation. If the founder wants it, it needs the same
--              treatment as §40 §12 OPTION B: a table comment, a privacy
--              policy sentence, and the clinic consent copy.
--
-- WHY THIS IS SAFE TO APPLY NOW: zero orphans, so the constraint validates
-- in one statement with no repair step and no `not valid` phase.

-- ------------------------------- FORWARD ---------------------------------

alter table public.patient_invitations
  add constraint patient_invitations_accepted_by_fk
  foreign key (accepted_by) references auth.users(id) on delete set null;

comment on column public.patient_invitations.accepted_by is
  'The patient who accepted this invitation. SET NULL on account deletion:
   the invitation row belongs to the issuing organisation and records that
   an invitation was issued and accepted; the patient identifier is hers and
   goes with her account. The relationship itself lives in
   care_relationships, which cascades. v25 §40 §11.';

-- ------------------------------- ROLLBACK --------------------------------
-- alter table public.patient_invitations
--   drop constraint patient_invitations_accepted_by_fk;
-- comment on column public.patient_invitations.accepted_by is null;
--
-- ------------------------------ SAFETY MATRIX -----------------------------
-- OLD CLIENT (build 30):  SAFE. `accepted_by` is written by the
--                         `care_accept_invitation` RPC, which sets it to
--                         `auth.uid()` — always a live user, so the new
--                         constraint can never reject a write it accepts
--                         today. No client reads the column.
-- NEW CLIENT:             SAFE. Identical.
-- CLINICIAN SURFACES:     A deleted patient's invitation shows an accepted
--                         invitation with no patient attached, which is the
--                         truthful rendering of what happened.
-- DEPLOY ORDER:           standalone.
-- SECRET REQUIRED:        none.
-- FOUNDER ACTION:         confirm SET NULL is the policy, then apply.
