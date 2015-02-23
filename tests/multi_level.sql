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
SELECT plan(2);

SELECT is(
    array_agg(d::text ORDER BY distance),
    ARRAY[
        'public.stats_ex',
        'public.stats_ex2'
    ]
) FROM dep_recurse.dependents(dep_recurse.table_ref('public', 'stats')) d;


SELECT is(
    array_agg(d::text ORDER BY distance),
    ARRAY[
        'public.stats_ex',
        'public.stats'
    ]
) FROM dep_recurse.dependencies(dep_recurse.view_ref('public', 'stats_ex2')) d;

SELECT * FROM finish();

ROLLBACK;
