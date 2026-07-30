# Provisioning a staging / pilot environment for Jeni Care

docs/app_v8/11_S5_PILOT_READY.md §7 is the law. This is the exact,
repeatable runbook to stand up a Jeni Care environment that is
**separate from the development project** (which is also the consumer
app's production database and must never hold real clinic data).

> **Founder gate.** Creating a real production environment for real
> patient data requires the BAA + legal + security gates in
> `docs/app_v8/pilot/VENDORS.md`. This runbook stands up a
> *fictional-data* pilot/staging project; it does not clear those
> gates.

## 1. Create the project

1. In the Supabase dashboard, create a NEW project (its own ref,
   its own keys). Name it `jeni-care-pilot` (or `-staging`).
   - Region: match the clinic's region for latency; US for a US pilot.
   - Save the DB password in your secrets manager, nowhere else.
2. For a real pilot with patient data, this must be a **HIPAA-
   eligible** project (Team plan + HIPAA add-on, marked "High
   Compliance") with a signed Supabase BAA first — see VENDORS.md.
   For a fictional-data staging environment, the free/pro tier is fine.

## 2. Apply the schema + migration chain (in order)

Point the Supabase CLI at the new project and push, OR run these in
the SQL editor in this exact order:

```
scripts/schema.sql
scripts/rls_policies.sql
supabase/migrations/20260623_users_cohort_intake_columns.sql
supabase/migrations/20260628_users_clinical_baseline_promises_kept.sql
supabase/migrations/20260703_app_v2_chat_and_cohort_columns.sql
supabase/migrations/20260708_food_logs_sugar_g.sql
supabase/migrations/20260728000000_app_v8_care_platform_foundation.sql
supabase/migrations/20260728120000_regimen_authority_seams.sql
supabase/migrations/20260729120000_s3_consent_grants.sql
supabase/migrations/20260729180000_s4_clinic_loop.sql
supabase/migrations/20260730090000_s5_pilot_ready.sql
```

(`supabase link --project-ref <newref>` then `supabase db push` does
the migration files; run schema.sql + rls_policies.sql first if this
is a brand-new DB.)

## 3. Label the environment + close org creation

Using the new project's **service-role key** (operator-local; never
committed, never in a client), via the SQL editor or a REST call:

```sql
select public.care_ops_set_config('environment', 'pilot');       -- or 'staging'
select public.care_ops_set_config('org_creation_mode', 'restricted');
```

From this point, `care_environment()` returns `pilot`, the dashboard
built for `pilot` will match it (and refuse to run against any other),
and org creation requires a founder-issued code.

## 4. Provision the pilot clinic

Mint a single-use org-provisioning code (service role):

```sql
select public.care_ops_mint_provisioning_code('Cedar Metabolic — pilot');
```

Hand the returned `XXXX-XXXX` code to the clinic owner. They create
their account in the dashboard, enter the code on the setup screen,
check "I'm a clinician" if they are, and the org is created. Every
later member is added by that owner.

## 5. Build + deploy the pilot dashboard

```
cd clinic
cp .env.pilot.example .env.pilot     # fill in the PILOT project's URL + publishable key + a real support mailbox
npm run build -- --mode pilot        # FAILS if it points at the dev ref or lacks a support email
```

Deploy `clinic/dist/` as static files (Vercel/Netlify/any static
host). The build stamps its own environment; at boot the dashboard
compares its built-for environment against `care_environment()` and
hard-stops on a mismatch — so a dev build can never talk to pilot,
and vice-versa.

## 6. Point the public site's form at the pilot inbox (optional)

If pilot requests should land in the pilot project rather than dev,
edit `site/config.js` (or replace it at deploy time) with the pilot
project's URL + publishable key, and redeploy the site.

## 7. Seed the demo tenant (optional, for founder demos)

```
export CARE_SUPABASE_URL=https://<pilotref>.supabase.co
export CARE_SUPABASE_ANON_KEY=<pilot publishable key>
export CARE_SERVICE_KEY=<pilot service-role key>   # operator-local only
export CARE_DEMO_PASSWORD=<a strong demo password>
python3 scripts/care_demo.py seed
```

## 8. Verify isolation

```
CARE_SUPABASE_URL=https://<pilotref>.supabase.co \
CARE_SUPABASE_ANON_KEY=<pilot publishable key> \
CARE_SERVICE_KEY=<pilot service-role key> \
python3 scripts/s4_security_probe.py
```

All checks must pass against the pilot project as they do against
development. Confirm `care_environment()` returns `pilot` and that a
`development`-built dashboard refuses to load against it.

## What NOT to do

- Never set `org_creation_mode = open` on a pilot/production project.
- Never put the service-role key in the dashboard, the site, the iOS
  app, CI, or the repo. It lives in your secrets manager and your
  shell for operator tasks only.
- Never copy development test data into the pilot project.
- Never point a `pilot` dashboard build at the development project
  (the build refuses this; don't defeat it).
