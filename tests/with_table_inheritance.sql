BEGIN;

--------
-- Setup
--------
CREATE TABLE stats (
    id integer,
    x integer
);

CREATE TABLE stats_1 () INHERITS (stats);

CREATE VIEW stats_ex AS
SELECT id, x + 1 AS "x'" FROM stats_1;

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
    ARRAY['public.stats_1']
) FROM dep_recurse.direct_deps(dep_recurse.table_ref('public', 'stats')) d;

SELECT is(
    array_agg(d::text),
    ARRAY['public.stats_1', 'public.stats_ex']
) FROM dep_recurse.deps(dep_recurse.table_ref('public', 'stats')) d;

SELECT * FROM finish();

ROLLBACK;
