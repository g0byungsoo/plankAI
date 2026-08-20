-- PASS 43 · P3 — three confirmations. READ ONLY.
with b as (select '280CAA8E-B635-49B7-8BF1-CA725F71798A'::uuid as id)
select 'B_apple_identity_last_sign_in' as k, (select i.last_sign_in_at::text from auth.identities i, b where i.user_id=b.id and i.provider='apple') as v
union all select 'B_apple_identity_updated_at', (select i.updated_at::text from auth.identities i, b where i.user_id=b.id and i.provider='apple')
union all select 'B_auth_last_sign_in',        (select u.last_sign_in_at::text from auth.users u, b where u.id=b.id)
union all select 'B_email_confirmed',          (select (u.email_confirmed_at is not null)::text from auth.users u, b where u.id=b.id)
union all select 'B_app_meta_providers',       (select (u.raw_app_meta_data->>'providers') from auth.users u, b where u.id=b.id)
-- how many accounts hold this same apple subject (must be exactly one: B)
union all select 'accounts_sharing_B_subject', (select count(distinct i2.user_id)::text
                                                  from auth.identities i2
                                                 where i2.provider='apple'
                                                   and i2.identity_data->>'sub' = (
                                                       select i.identity_data->>'sub' from auth.identities i, b
                                                        where i.user_id=b.id and i.provider='apple'))
-- open receipts anywhere, and any receipt not belonging to B
union all select 'receipts_open_anywhere',     (select count(*)::text from public.account_handoffs where state='open')
union all select 'receipts_not_B',             (select count(*)::text from public.account_handoffs h, b where h.destination_user_id is distinct from b.id)
-- the two tables the client's hydrate was refused on, at 05:48
union all select 'grant_program_facts_select',  pg_catalog.has_table_privilege('authenticated','public.program_facts','SELECT')::text
union all select 'grant_weekly_reads_select',   pg_catalog.has_table_privilege('authenticated','public.weekly_reads','SELECT')::text
union all select 'grant_weight_logs_select',    pg_catalog.has_table_privilege('authenticated','public.weight_logs','SELECT')::text
union all select 'program_facts_rows',          (select count(*)::text from public.program_facts)
union all select 'weekly_reads_rows',           (select count(*)::text from public.weekly_reads)
-- nothing else was retired: anonymous accounts created before T0 still stand
union all select 'anon_users_created_before_T0',(select count(*)::text from auth.users where is_anonymous and created_at < '2026-08-15 05:26:45+00')
;
