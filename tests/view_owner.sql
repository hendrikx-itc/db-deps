BEGIN;

--------
-- Setup
--------
CREATE VIEW dummy AS
SELECT 1 AS x, 2 AS y;

ALTER VIEW dummy OWNER TO dummy_user;


--------
-- Tests
--------
SELECT plan(1);

SELECT is(
    dep_recurse.owner_view_statement((dep_recurse.view_ref('public', 'dummy')).obj_id),
    'ALTER VIEW public.dummy OWNER TO dummy_user;'
);

SELECT * FROM finish();

ROLLBACK;
