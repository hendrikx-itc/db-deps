BEGIN;

--------
-- Setup
--------
CREATE TABLE dummy (
    x integer,
    y double precision
);

--------
-- Tests
--------
SELECT plan(1);

SELECT is(
    (dep_recurse.table_ref('public', 'dummy'))::text,
    'public.dummy'
);

SELECT * FROM finish();

ROLLBACK;
