#!/usr/bin/env bash
# Regenerate demo/supabase/migrations from the canonical SQL sources.
#
# The demo stack is a SEPARATE supabase workdir (demo/) so that
# `supabase db push` against the linked production project can never
# see these files. The ordering below is scripts/care_env_provision.md
# §2, extended with the three migrations that shipped after that
# runbook was written (p6 weekly summaries, v24 medication platform,
# v25 e1 program spine).
#
# Nothing here is hand-edited: run this whenever a canonical migration
# changes, then `scripts/demo/stack.sh reset`.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="$ROOT/demo/supabase/migrations"

rm -rf "$OUT"
mkdir -p "$OUT"

copy() { # <dest-stamp> <dest-name> <source-path>
  cp "$ROOT/$3" "$OUT/$1_$2.sql"
  echo "  $1_$2.sql  ←  $3"
}

echo "regenerating $OUT"

# The base schema + policies the migration chain assumes already exist.
copy 20260101000000 base_schema      scripts/schema.sql
copy 20260101000001 base_rls_policies scripts/rls_policies.sql

# The app's own chain, in the order care_env_provision.md §2 fixes.
copy 20260623000000 users_cohort_intake_columns            supabase/migrations/20260623_users_cohort_intake_columns.sql
copy 20260628000000 users_clinical_baseline_promises_kept  supabase/migrations/20260628_users_clinical_baseline_promises_kept.sql
copy 20260703000000 app_v2_chat_and_cohort_columns         supabase/migrations/20260703_app_v2_chat_and_cohort_columns.sql
copy 20260708000000 food_logs_sugar_g                      supabase/migrations/20260708_food_logs_sugar_g.sql
copy 20260728000000 app_v8_care_platform_foundation        supabase/migrations/20260728000000_app_v8_care_platform_foundation.sql
copy 20260728120000 regimen_authority_seams                supabase/migrations/20260728120000_regimen_authority_seams.sql
copy 20260729120000 s3_consent_grants                      supabase/migrations/20260729120000_s3_consent_grants.sql
copy 20260729180000 s4_clinic_loop                         supabase/migrations/20260729180000_s4_clinic_loop.sql
copy 20260730090000 s5_pilot_ready                         supabase/migrations/20260730090000_s5_pilot_ready.sql
copy 20260804090000 p6_weekly_summaries                    supabase/migrations/20260804090000_p6_weekly_summaries.sql
copy 20260809090000 v24_medication_platform                supabase/migrations/20260809090000_v24_medication_platform.sql
copy 20260810090000 v25_e1_program_spine                   supabase/migrations/20260810090000_v25_e1_program_spine.sql
copy 20260811090000 care_program_facts                     supabase/migrations/20260811090000_care_program_facts.sql

echo "done — $(ls "$OUT" | wc -l | tr -d ' ') files"
