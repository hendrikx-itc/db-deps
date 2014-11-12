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

-- PostgreSQL does some funky formatting with the view query, so there is some
-- unexpected spacing here as well.
SELECT is(
    (dep_recurse.table_ref('public', 'dummy'))::text,
    'public.dummy'
);

SELECT * FROM finish();

ROLLBACK;
