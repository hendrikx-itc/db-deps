CREATE TYPE obj_type AS ENUM (
    'table',
    'view',
    'materialized view',
    'function'
);


CREATE TYPE obj_ref AS (
    obj_id oid,
    obj_type obj_type
);


CREATE TYPE dep AS (
    obj obj_ref,
    distance integer
);
