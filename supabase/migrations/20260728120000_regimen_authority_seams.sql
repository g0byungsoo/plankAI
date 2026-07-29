-- App v8 founder refinement (2026-07-28, second brief) — the
-- clinician is medication's future source of truth. The authority
-- enum (FHIR reported[x] + US Core requester collapsed) + the
-- reconciliation seams the future clinic bridge populates. The iOS
-- client only ever writes authority = 'self'; 'care_team' rows are
-- written exclusively by the future clinician seam (service role).
-- Additive; safe whether or not the base 20260728 migration ran
-- (add column if not exists).

alter table public.regimen_plans
  add column if not exists authority text not null default 'self',
  add column if not exists rxnorm_code text,
  add column if not exists strength_value double precision,
  add column if not exists strength_unit text;
