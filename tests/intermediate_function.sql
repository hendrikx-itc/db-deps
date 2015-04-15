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

CREATE FUNCTION stats_ex_inc(stats_ex)
RETURNS integer
AS $$
    SELECT $1."x'" + 1;
$$ LANGUAGE sql STABLE;

CREATE VIEW stats_ex2 AS
SELECT stats_ex_inc(stats_ex) AS x FROM stats_ex;

--------
-- Tests
--------
SELECT plan(1);

SELECT is(
    array_agg(d::text),
    ARRAY[
        'public.stats_ex',
        'public.stats_ex_inc(public.stats_ex)',
        'public.stats_ex2'
    ]
) FROM dep_recurse.dependents(dep_recurse.table_ref('public', 'stats')) d;

SELECT * FROM finish();

ROLLBACK;
