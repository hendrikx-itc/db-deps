BEGIN;

--------
-- Setup
--------
CREATE TABLE stats (
    id integer,
    x integer
);

CREATE VIEW stats_ex AS
SELECT id, x + 1 AS "x'" FROM stats;

--------
-- Tests
--------
SELECT plan(3);

SELECT is(
    dep_recurse.table_ref('public', 'stats'),
    (pg_class.oid, 'table')::dep_recurse.obj_ref
)
FROM pg_class WHERE relname = 'stats';

SELECT is(
    array_agg(d::text),
    ARRAY['public.stats_ex']
) FROM dep_recurse.direct_dependents(dep_recurse.table_ref('public', 'stats')) d;

SELECT is(
    array_agg(d::text),
    ARRAY['public.stats']
) FROM dep_recurse.direct_dependencies(dep_recurse.view_ref('public', 'stats_ex')) d;

SELECT * FROM finish();

ROLLBACK;
