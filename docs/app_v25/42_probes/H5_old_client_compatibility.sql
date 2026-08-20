select 'delete_user_account_len' as k, (select length(prosrc)::text from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='delete_user_account') as v
union all select 'delete_user_account_mentions_storage', (select (prosrc ilike '%storage.objects%')::text from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='delete_user_account')
union all select 'total_policies_public', (select count(*)::text from pg_policies where schemaname='public')
union all select 'policies_on_new_table', (select count(*)::text from pg_policies where schemaname='public' and tablename='account_handoffs')
union all select 'tables_with_rls_public', (select count(*)::text from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind='r' and c.relrowsecurity)
union all select 'public_tables', (select count(*)::text from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind='r')
union all select 'anon_can_select_weight_logs', pg_catalog.has_table_privilege('anon','public.weight_logs','SELECT')::text
union all select 'authenticated_can_select_weight_logs', pg_catalog.has_table_privilege('authenticated','public.weight_logs','SELECT')::text
union all select 'authenticated_can_insert_weight_logs', pg_catalog.has_table_privilege('authenticated','public.weight_logs','INSERT')::text
union all select 'authenticated_can_exec_delete_user_account', pg_catalog.has_function_privilege('authenticated','public.delete_user_account()','EXECUTE')::text
union all select 'objects_depending_on_receipt_table', (select count(*)::text from pg_depend d join pg_class c on c.oid=d.refobjid where c.relname='account_handoffs' and d.deptype='n');
