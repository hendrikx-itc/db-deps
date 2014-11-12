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
SELECT plan(2);

SELECT is(
    dep_recurse.table_ref('public', 'stats'),
    (pg_class.oid, 'table')::dep_recurse.obj_ref
)
FROM pg_class WHERE relname = 'stats';

SELECT is(
    array_agg(d::text),
    ARRAY['public.stats_ex']
) FROM dep_recurse.direct_deps(dep_recurse.table_ref('public', 'stats')) d;

SELECT * FROM finish();

ROLLBACK;
