CREATE TYPE dep_recurse.obj_type AS ENUM (
    'table',
    'view',
    'materialized view',
    'function'
);


CREATE TYPE dep_recurse.obj_ref AS (
    obj_id oid,
    obj_type dep_recurse.obj_type
);


CREATE TYPE dep_recurse.dep AS (
    obj dep_recurse.obj_ref,
    distance integer
);
