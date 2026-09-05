-- Read-only audit. Run in the Supabase SQL editor for the production project.
-- No private records or keys are returned. This does not enable or change RLS.
SELECT n.nspname AS schema_name, c.relname AS table_name,
       c.relrowsecurity AS rls_enabled, c.relforcerowsecurity AS rls_forced
FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname='public' AND c.relkind='r'
ORDER BY c.relname;

SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies
WHERE schemaname='public'
ORDER BY tablename, policyname;

SELECT grantee, table_name, privilege_type
FROM information_schema.role_table_grants
WHERE table_schema='public' AND grantee IN ('anon','authenticated')
ORDER BY table_name, grantee, privilege_type;
