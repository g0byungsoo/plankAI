select 'A_table_exists' as k, (select count(*)::text from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname='account_handoffs') as v
union all select 'A_table_owner', (select pg_catalog.pg_get_userbyid(c.relowner) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname='account_handoffs')
union all select 'A_rls_enabled', (select c.relrowsecurity::text from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname='account_handoffs')
union all select 'A_policy_count', (select count(*)::text from pg_policies where schemaname='public' and tablename='account_handoffs')
union all select 'A_table_acl', (select coalesce(array_to_string(c.relacl,' | '),'(none)') from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname='account_handoffs')
union all select 'A_row_count', (select count(*)::text from public.account_handoffs)
union all select 'B_columns', (select string_agg(column_name||':'||data_type||':'||is_nullable, ', ' order by ordinal_position) from information_schema.columns where table_schema='public' and table_name='account_handoffs')
union all select 'C_constraints', (select string_agg(conname||' => '||pg_catalog.pg_get_constraintdef(oid), ' | ' order by conname) from pg_constraint where conrelid='public.account_handoffs'::regclass)
union all select 'D_indexes', (select string_agg(indexname||' => '||indexdef, ' | ' order by indexname) from pg_indexes where schemaname='public' and tablename='account_handoffs')
union all select 'E_begin_meta', (select p.proname||' owner='||pg_catalog.pg_get_userbyid(p.proowner)||' secdef='||p.prosecdef::text||' vol='||p.provolatile::text||' cfg='||coalesce(array_to_string(p.proconfig,','),'(none)')||' acl='||coalesce(array_to_string(p.proacl,','),'(default)') from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='begin_account_handoff')
union all select 'E_complete_meta', (select p.proname||' owner='||pg_catalog.pg_get_userbyid(p.proowner)||' secdef='||p.prosecdef::text||' vol='||p.provolatile::text||' cfg='||coalesce(array_to_string(p.proconfig,','),'(none)')||' acl='||coalesce(array_to_string(p.proacl,','),'(default)') from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='complete_account_handoff')
union all select 'E_transfer_meta', (select p.proname||' owner='||pg_catalog.pg_get_userbyid(p.proowner)||' secdef='||p.prosecdef::text||' vol='||p.provolatile::text||' cfg='||coalesce(array_to_string(p.proconfig,','),'(none)')||' acl='||coalesce(array_to_string(p.proacl,','),'(default)') from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='private' and p.proname='transfer_account_rows')
union all select 'F_auth_begin',    pg_catalog.has_function_privilege('authenticated','public.begin_account_handoff(text,text)','EXECUTE')::text
union all select 'F_auth_complete', pg_catalog.has_function_privilege('authenticated','public.complete_account_handoff(uuid,text)','EXECUTE')::text
union all select 'F_auth_transfer', pg_catalog.has_function_privilege('authenticated','private.transfer_account_rows(uuid,uuid)','EXECUTE')::text
union all select 'F_anon_begin',    pg_catalog.has_function_privilege('anon','public.begin_account_handoff(text,text)','EXECUTE')::text
union all select 'F_anon_complete', pg_catalog.has_function_privilege('anon','public.complete_account_handoff(uuid,text)','EXECUTE')::text
union all select 'F_anon_transfer', pg_catalog.has_function_privilege('anon','private.transfer_account_rows(uuid,uuid)','EXECUTE')::text
union all select 'F_svc_begin',     pg_catalog.has_function_privilege('service_role','public.begin_account_handoff(text,text)','EXECUTE')::text
union all select 'F_svc_transfer',  pg_catalog.has_function_privilege('service_role','private.transfer_account_rows(uuid,uuid)','EXECUTE')::text
union all select 'G_auth_select_table', pg_catalog.has_table_privilege('authenticated','public.account_handoffs','SELECT')::text
union all select 'G_auth_insert_table', pg_catalog.has_table_privilege('authenticated','public.account_handoffs','INSERT')::text
union all select 'G_auth_update_table', pg_catalog.has_table_privilege('authenticated','public.account_handoffs','UPDATE')::text
union all select 'G_anon_select_table', pg_catalog.has_table_privilege('anon','public.account_handoffs','SELECT')::text;
