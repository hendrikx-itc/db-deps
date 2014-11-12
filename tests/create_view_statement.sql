BEGIN;

--------
-- Setup
--------
CREATE VIEW dummy AS
SELECT 1 AS x, 2 AS y;

--------
-- Tests
--------
SELECT plan(1);

-- PostgreSQL does some funky formatting with the view query, so there is some
-- unexpected spacing here as well.
SELECT is(
    dep_recurse.create_view_statement((dep_recurse.view_ref('public', 'dummy')).obj_id),
    'CREATE VIEW public.dummy AS  SELECT 1 AS x,
    2 AS y;'
);

SELECT * FROM finish();

ROLLBACK;
