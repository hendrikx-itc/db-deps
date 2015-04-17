BEGIN;

--------
-- Setup
--------
CREATE VIEW public.num_x AS
SELECT 1 x;

CREATE VIEW public.num_y AS
SELECT x + 1 AS y
FROM public.num_x;

--------
-- Tests
--------
SELECT plan(2);

SELECT is(
    array_agg(d::text),
    NULL
) FROM dep_recurse.direct_dependents(dep_recurse.view_ref('public', 'num_y')) d;


SELECT is(
    array_agg(d::text),
    ARRAY['public.num_y']
) FROM dep_recurse.direct_dependents(dep_recurse.view_ref('public', 'num_x')) d;

SELECT * FROM finish();

ROLLBACK;
