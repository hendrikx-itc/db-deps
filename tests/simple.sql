BEGIN;

SELECT plan(1);

SELECT has_table('public'::name, 'deps_saved_ddl'::name);

SELECT * FROM finish();

ROLLBACK;
