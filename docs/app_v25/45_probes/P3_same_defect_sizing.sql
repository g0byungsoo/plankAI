-- =====================================================================
-- 45 · P3 — SIZING THE OTHER GRANTLESS TABLES
-- =====================================================================
--
-- READ ONLY. Counts and bounds only. No identifiers, no free text, no
-- health values.
--
-- P2 found four public tables carrying RLS policies and ZERO data-API
-- privileges for `authenticated`:
--
--   program_facts          (the E1 spine — G1's subject)
--   weekly_reads           (the E1 spine — G1's subject)
--   care_weekly_summaries  (a SHIPPING iOS write path: publishWeeklySummary)
--   patient_invitations    (no client path found in the repo — prove it)
--
-- This asks how many customers can currently REACH each one.
--
-- Run: supabase db query --linked -f docs/app_v25/45_probes/P3_same_defect_sizing.sql -o json

select 'care_relationships total'          as q, count(*)::text as n from public.care_relationships
union all
select 'care_relationships active',        count(*)::text from public.care_relationships where status = 'active'
union all
select 'consent visit_packet_view live',   count(*)::text from public.consent_grants
  where scope = 'visit_packet_view' and revoked_at is null
union all
select 'consent care_assignment live',     count(*)::text from public.consent_grants
  where scope = 'care_assignment' and revoked_at is null
union all
select 'consent_grants rows',              count(*)::text from public.consent_grants
union all
select 'visit_packets rows',               count(*)::text from public.visit_packets
union all
select 'care_weekly_summaries rows',       count(*)::text from public.care_weekly_summaries
union all
select 'patient_invitations rows',         count(*)::text from public.patient_invitations
union all
select 'program_facts rows',               count(*)::text from public.program_facts
union all
select 'weekly_reads rows',                count(*)::text from public.weekly_reads
union all
select 'organizations rows',               count(*)::text from public.organizations
union all
select 'org_members rows',                 count(*)::text from public.org_members
union all
select 'auth.users total',                 count(*)::text from auth.users
union all
select 'auth.users anonymous',             count(*)::text from auth.users where is_anonymous
union all
select 'auth.users permanent',             count(*)::text from auth.users where not is_anonymous
union all
select 'identities apple',                 count(*)::text from auth.identities where provider = 'apple'
union all
select 'identities email',                 count(*)::text from auth.identities where provider = 'email'
union all
select 'program_plans live',               count(*)::text from public.program_plans where archived_at is null
union all
-- every SECURITY DEFINER function in public that names either spine
-- table, so "the clinic reaches it another way" is measured not assumed
select 'secdef fns naming program_facts',  count(*)::text from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.prosecdef and p.prosrc like '%program_facts%'
union all
select 'secdef fns naming weekly_reads',   count(*)::text from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.prosecdef and p.prosrc like '%weekly_reads%'
union all
select 'secdef fns naming care_weekly_summaries', count(*)::text from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.prosecdef and p.prosrc like '%care_weekly_summaries%'
union all
select 'secdef fns naming patient_invitations',   count(*)::text from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.prosecdef and p.prosrc like '%patient_invitations%';
