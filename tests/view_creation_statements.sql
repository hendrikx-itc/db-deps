BEGIN;

--------
-- Setup
--------
CREATE ROLE dummy_user;

CREATE VIEW dummy AS
SELECT 1 AS x, 2 AS y;

ALTER VIEW dummy OWNER TO dummy_user;


--------
-- Tests
--------
SELECT plan(1);

-- PostgreSQL does some funky formatting with the view query, so there is some
-- unexpected spacing here as well.
SELECT is(
    array_agg(statement),
    ARRAY[
        'CREATE VIEW public.dummy AS  SELECT 1 AS x,
    2 AS y;',
        'ALTER VIEW public.dummy OWNER TO dummy_user;'
    ]::character varying[]
)
FROM dep_recurse.view_creation_statements((dep_recurse.view_ref('public', 'dummy')).obj_id) statement;

SELECT * FROM finish();

ROLLBACK;
