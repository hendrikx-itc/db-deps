BEGIN;

--------
-- Setup
--------
CREATE TABLE data (
    x integer,
    y double precision
);

CREATE VIEW data_ex1 AS
SELECT
    x + 1 AS x,
    y * 2 AS y
FROM data;

CREATE FUNCTION operate_on_record(data_ex1)
    RETURNS data_ex1
    LANGUAGE sql IMMUTABLE
AS $$SELECT $1;$$;

COMMENT ON FUNCTION operate_on_record(data_ex1) IS 'operate_on_record(data_ex1)';

CREATE VIEW data_ex2a AS
SELECT
    x + 1 AS x,
    y * 2 AS y
FROM data_ex1;

COMMENT ON VIEW data_ex2a IS 'data_ex2a';

CREATE VIEW data_ex2b AS
SELECT
    x + 2 AS x,
    y * 3 AS y
FROM data_ex1;

COMMENT ON VIEW data_ex2b IS 'data_ex2b';

SET search_path = public, dep_recurse;

--------
-- Tests
--------
SELECT plan(1);

SELECT results_eq(
    $$SELECT d::text FROM dependent_create_statements(
            table_ref('public', 'data'),
            ARRAY[
                view_ref('public', 'data_ex1')
            ]
        ) d$$,
    ARRAY[
        'CREATE OR REPLACE FUNCTION public.operate_on_record(data_ex1)
 RETURNS data_ex1
 LANGUAGE sql
 IMMUTABLE
AS $function$SELECT $1;$function$
',
        'ALTER FUNCTION public.operate_on_record(public.data_ex1) OWNER TO vagrant',
        'CREATE VIEW public.data_ex2a AS  SELECT (data_ex1.x + 1) AS x,
    (data_ex1.y * (2)::double precision) AS y
   FROM data_ex1;',
        $$COMMENT ON VIEW public.data_ex2a IS 'data_ex2a';$$,
        'ALTER VIEW public.data_ex2a OWNER TO vagrant;',
        'CREATE VIEW public.data_ex2b AS  SELECT (data_ex1.x + 2) AS x,
    (data_ex1.y * (3)::double precision) AS y
   FROM data_ex1;',
        $$COMMENT ON VIEW public.data_ex2b IS 'data_ex2b';$$,
        'ALTER VIEW public.data_ex2b OWNER TO vagrant;'
    ]
);

SELECT * FROM finish();

ROLLBACK;
