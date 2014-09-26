CREATE TYPE obj_ref AS (
    obj_id oid,
    obj_type varchar
);


CREATE TYPE dep AS (
    obj obj_ref,
    distance integer
);
