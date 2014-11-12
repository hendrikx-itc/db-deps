BEGIN;

--------
-- Setup
--------
CREATE FUNCTION add_one(integer)
	RETURNS integer
AS $$
	SELECT $1 + 1;
$$ LANGUAGE sql IMMUTABLE;

--------
-- Tests
--------
SELECT plan(1);

-- PostgreSQL does some funky formatting with the view query, so there is some
-- unexpected spacing here as well.
SELECT is(
    dep_recurse.function_signature(oid),
    ARRAY['pg_catalog.int4']
)
FROM pg_proc WHERE proname = 'add_one';

SELECT * FROM finish();

ROLLBACK;
