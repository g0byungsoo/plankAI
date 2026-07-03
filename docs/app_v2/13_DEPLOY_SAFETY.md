# 13 — Production deploy safety: migration + jeni-chat EF

Date: 2026-07-03. Adversarial audit of the two pending server
artifacts against the LIVE v1.1.2 app (real users). Verdict:
**GO / GO** — with three findings already fixed in-tree before this
doc was written (see "Fixed pre-deploy"). The live binary contains
zero references to any of this (`git log main -- PlankApp/Chat/
supabase/functions/jeni-chat/ supabase/migrations/20260703_*` = 0
commits): both artifacts are additive to a contract the live app
never touches.

## Why the live app cannot break

1. **users columns (9, all nullable text).** The live app's
   `SupabaseUserUpsert` is a fixed field list — PostgREST
   merge-duplicates updates only payload columns, so old-app writes
   can never null the new columns. Hydrate uses `select()` (=`*`)
   into a plain Decodable — Swift ignores unknown keys. No type
   hazard (nullable text ↔ String?).
2. **No triggers, no NOT NULL on existing tables, indexes only on
   brand-new empty tables.** The single existing-table touch (ALTER
   users ADD COLUMN, nullable, no default) is metadata-only in
   Postgres 11+ (milliseconds). `set lock_timeout='5s'` first so it
   can never queue behind a stuck transaction.
3. **New tables are disjoint** from the live app's entire `.from()`
   surface (users, session_logs, day_progress, weight_logs,
   program_plans, program_day_checks, food_logs). RLS ships in the
   same file: coach_messages + day_reflections uid-scoped;
   jeni_chat_telemetry default-deny (service-role only).
4. **The new app writes nothing new server-side yet** — chat
   transcripts are device-local SwiftData; the 9 columns have no
   SyncService writers in v2.0. So migration and EF can deploy in
   ANY order relative to the App Store release. The only ordering
   that matters: **migration before EF** (the EF's cost caps read
   the telemetry table; without it they fail-open silently).
5. **If the EF is missing/failing**, the new app degrades to
   friendly copy (404/5xx → "she couldn't answer just now.",
   401 → session-refresh line, 429 → "we've talked a lot today ♥").
   No crash, no retry storm; the daily brief still renders (local).
6. **Payment is RevenueCat-only** — unaffected. Gating states
   (paid / unpaid / expired) derive client-side from RC and are
   covered by the AppPhase table tests; no server change touches
   them.

## Fixed pre-deploy (from the audit's risk register)

- **R7** `jeni_chat_telemetry.user_id` now `references auth.users
  on delete set null` (was FK-less NOT NULL) — delete-account leaves
  no orphaned user UUIDs, matching food_vision_telemetry.
- **R5** the global $40/day budget check now calls a SECURITY
  DEFINER `jeni_chat_spend_today()` sum RPC (client-select sums
  silently cap at PostgREST max_rows ~1000 rows/day).
- **R8** the EF's 502 path no longer forwards provider error bodies
  to clients.

Accepted (documented, not blockers): unauthenticated requests reach
function code before 401 (same posture as live food-vision); CORS `*`
(same as food-vision; JWT still required); `DAILY_BUDGET_USD` is a
code constant (change = redeploy).

## Founder deploy checklist (ordered)

```sql
-- PRE-FLIGHT (SQL editor) — expect 2 rows:
select column_name from information_schema.columns
 where table_schema='public' and table_name='users'
   and column_name in ('onboarding_glp1_status','computed_start_bmi');
```

```sql
-- APPLY (SQL editor, low-traffic moment):
set lock_timeout = '5s';
-- paste ALL of supabase/migrations/20260703_app_v2_chat_and_cohort_columns.sql
-- idempotent: safe to re-run on any error
```

```sql
-- VERIFY — expect 9 / 3-with-rls / 7 policies (telemetry: ZERO):
select column_name from information_schema.columns
 where table_schema='public' and table_name='users'
   and column_name in ('program_mode','goal_direction','medication_status',
   'dietary_csv','nsv_priority_csv','appetite_rhythm','glp1_stop_window',
   'fears_csv','snap_demo_meal');
select tablename, rowsecurity from pg_tables where schemaname='public'
 and tablename in ('coach_messages','jeni_chat_telemetry','day_reflections');
select tablename, policyname from pg_policies
 where tablename in ('coach_messages','jeni_chat_telemetry','day_reflections');
```

**Live-app canary before the EF:** on the current App Store build:
open Becoming (hydrate path) + log a weight (upsert path).

```bash
# EF — verify the shared key exists, do NOT re-set it
# (secrets set restarts ALL functions, incl. food-vision):
supabase secrets list
supabase functions deploy jeni-chat --no-verify-jwt
# unauth probe — expect 401:
curl -si -X POST "https://<PROJECT_REF>.supabase.co/functions/v1/jeni-chat" \
  -H "Content-Type: application/json" -d '{"messages":[{"role":"user","content":"hi"}]}'
```

Then one real chat turn from a dev build (no `--uitest-mock-chat`) and:

```sql
select status, model, cost_usd, created_at from jeni_chat_telemetry
 order by created_at desc limit 5;          -- an 'ok' row => caps live
select max(requested_at) from food_vision_telemetry;  -- food-vision ticking
```

Final regression: snap one meal on the live/TestFlight build.

## Rollback (no app update needed)

1. `supabase functions delete jeni-chat` → clients get the friendly
   line; redeploy to restore. Zero effect on food-vision.
2. Same-day mute: `insert into jeni_chat_telemetry (cost_usd, status)
   values (41.0, 'manual_kill');` → 429s until UTC midnight.
3. Migration: leave it. Additive and inert; nothing live reads it.

## Old-app compatibility checklist

- [x] users upsert preserves new columns (merge-duplicates, fixed payload)
- [x] users hydrate ignores new columns (lenient Decodable)
- [x] no existing table other than users touched; users touch additive-only
- [x] no triggers / NOT NULL / defaults on existing rows
- [x] live table set disjoint from new tables; uid-scoped RLS regardless
- [x] delete_user_account cascade covers coach_messages + day_reflections;
      telemetry FK now SET NULL
- [x] live binary has zero chat references (0 commits on main)
- [x] EF absent/failing → friendly degradation in the new app
- [x] paid / unpaid / expired gating fully client-side (RC), untouched
