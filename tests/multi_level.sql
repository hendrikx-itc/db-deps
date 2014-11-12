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

CREATE VIEW stats_ex2 AS
SELECT id, "x'" * 2  AS "x2" FROM stats_ex;

--------
-- Tests
--------
SELECT plan(1);

SELECT is(
    array_agg(d::text),
    ARRAY[
        'public.stats_ex',
        'public.stats_ex2'
    ]
) FROM dep_recurse.deps(dep_recurse.table_ref('public', 'stats')) d;

SELECT * FROM finish();

ROLLBACK;
