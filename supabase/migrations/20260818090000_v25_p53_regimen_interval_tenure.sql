-- APP v25 PASS 53 — THE ANSWERING RECORD (docs/app_v25/53_THE_ANSWERING_RECORD.md)
-- Additive only. Founder applies; until then the client defers
-- gracefully (local-first; a row carrying a new fact retries under
-- pendingUpsert until the columns exist — the v24 pattern, verbatim).
--
-- WHY (G1, evidence in the pass record): real regimens are not all
-- "every seven days". Physician-directed q2wk–q6wk maintenance is
-- published (Scripps, Obesity 2026); ~15% of injectable users stretch
-- or split; split dosing is two named weekdays (labels forbid two
-- doses inside 48–72h, so same-day splits do not exist and the
-- per-day deterministic dose id is safe). Treatment tenure is the
-- fact clinician follow-ups and reauthorizations actually consume,
-- and it is NOT the first logged shot (most adopters arrive
-- mid-journey). Civil-day columns are dates, never instants — the
-- pass-51 boundary law.

-- 1 ── regimen_plans: the rhythm + tenure facts ──────────────────

alter table public.regimen_plans
  add column if not exists second_anchor_weekday int,
  add column if not exists interval_days int,
  add column if not exists anchor_date date,
  add column if not exists treatment_started_on date;

comment on column public.regimen_plans.second_anchor_weekday is
  'p53 split rhythm: second ISO weekday (1=Mon..7=Sun); weeklyAnchor rows only';
comment on column public.regimen_plans.interval_days is
  'p53: days between doses when schedule_rule = intervalDays (client enforces 2..90)';
comment on column public.regimen_plans.anchor_date is
  'p53: CIVIL day the interval chain counts from (first planned dose day); events re-anchor the chain';
comment on column public.regimen_plans.treatment_started_on is
  'p53: CIVIL day treatment actually began (her statement; month-ish precision is fine). NOT started_at, which restarts on dose changes';

comment on column public.regimen_plans.schedule_rule is
  'weeklyAnchor | daily | asNeeded | intervalDays (p53)';

-- 2 ── dose_events: her word for what THIS shot was ──────────────

alter table public.dose_events
  add column if not exists dose_label text;

comment on column public.dose_events.dose_label is
  'p53: HER words for this event''s strength when it differed from the plan''s stage ("1.25", "half"). Display-only; the app never authors dose advice';
