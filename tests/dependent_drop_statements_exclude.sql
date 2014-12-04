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

CREATE VIEW data_ex2 AS
SELECT
    x + 1 AS x,
    y * 2 AS y
FROM data_ex1;

SET search_path = public, dep_recurse;

--------
-- Tests
--------
SELECT plan(2);

SELECT is(
    ARRAY[
       'DROP VIEW public.data_ex2',
       'DROP VIEW public.data_ex1'
    ],
    array_agg(d::text)
)
FROM dependent_drop_statements(
        table_ref('public', 'data')
    ) d;


SELECT is(
    ARRAY[
        'DROP VIEW public.data_ex2'
    ],
    array_agg(d::text)
)
FROM dependent_drop_statements(
        table_ref('public', 'data'),
        ARRAY[
            view_ref('public', 'data_ex1')
        ]
    ) d
;

SELECT * FROM finish();

ROLLBACK;
