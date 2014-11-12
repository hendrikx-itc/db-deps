BEGIN;

--------
-- Setup
--------
CREATE VIEW dummy AS
SELECT 10 x, 12 y;

CREATE VIEW "42-dummy" AS
SELECT 10 x, 12 y;

--------
-- Tests
--------
SELECT plan(2);

SELECT is(
    (dep_recurse.view_ref('public', 'dummy'))::text,
    'public.dummy'
);

SELECT is(
    (dep_recurse.view_ref('public', '42-dummy'))::text,
    'public."42-dummy"'
);

SELECT * FROM finish();

ROLLBACK;
