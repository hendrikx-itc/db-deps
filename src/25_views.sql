CREATE VIEW dep_recurse.table_relation_dependents AS
SELECT
    inhrelid child_relation_oid,
    inhparent parent_relation_oid
FROM pg_inherits;


CREATE VIEW dep_recurse.view_relation_dependents AS
SELECT
    rwr_cl.oid view_oid,
    dep.refobjid relation_oid
FROM pg_depend dep
JOIN pg_rewrite rwr ON dep.objid = rwr.oid
JOIN pg_class rwr_cl ON rwr_cl.oid = rwr.ev_class AND rwr_cl.relkind = 'v'
WHERE
    dep.deptype = 'n'
    AND
    dep.classid = 'pg_rewrite'::regclass
    AND
    rwr_cl.oid != dep.refobjid
GROUP BY rwr_cl.oid, dep.refobjid;


CREATE VIEW dep_recurse.materialized_view_relation_dependents AS
SELECT
    rwr_cl.oid view_oid,
    dep.refobjid relation_oid
FROM pg_depend dep
JOIN pg_rewrite rwr ON dep.objid = rwr.oid
JOIN pg_class rwr_cl ON rwr_cl.oid = rwr.ev_class AND rwr_cl.relkind = 'm'
WHERE
    dep.deptype = 'n'
    AND
    dep.classid = 'pg_rewrite'::regclass
    AND
    rwr_cl.oid != dep.refobjid
GROUP BY rwr_cl.oid, dep.refobjid;


CREATE VIEW dep_recurse.function_relation_dependents AS
SELECT
    pg_class.oid relation_oid,
    pg_proc.oid function_oid
FROM pg_class
JOIN pg_type ON pg_type.oid = pg_class.reltype
JOIN pg_depend ON pg_depend.refobjid = pg_type.oid
JOIN pg_proc ON pg_proc.oid = pg_depend.objid
WHERE pg_depend.deptype = 'n';


CREATE VIEW dep_recurse.relation_dependents AS
SELECT
    relation_oid ref_obj_id,
    'table'::dep_recurse.obj_type ref_obj_type,
    view_oid obj_id,
    'view'::dep_recurse.obj_type
FROM dep_recurse.view_relation_dependents
UNION ALL
SELECT
    relation_oid ref_obj_id,
    'table'::dep_recurse.obj_type ref_obj_type,
    view_oid obj_id,
    'materialized view'::dep_recurse.obj_type
FROM dep_recurse.materialized_view_relation_dependents
UNION ALL
SELECT
    relation_oid ref_obj_id,
    'table'::dep_recurse.obj_type ref_obj_type,
    function_oid obj_id,
    'function'::dep_recurse.obj_type
FROM dep_recurse.function_relation_dependents
UNION ALL
SELECT
    parent_relation_oid ref_obj_id,
    'table'::dep_recurse.obj_type ref_obj_type,
    child_relation_oid obj_id,
    'table'::dep_recurse.obj_type
FROM dep_recurse.table_relation_dependents;


CREATE VIEW dep_recurse.view_function_dependents AS
SELECT
    pg_rewrite.ev_class obj_id,
    'view'::dep_recurse.obj_type obj_type,
    refobjid ref_obj_id,
    'function'::dep_recurse.obj_type ref_obj_type
FROM pg_depend
JOIN pg_rewrite ON pg_depend.objid = pg_rewrite.oid
JOIN pg_proc ON pg_proc.oid = refobjid;


CREATE VIEW dep_recurse.dependents AS
SELECT * FROM (
    SELECT
        ref_obj_id,
        ref_obj_type,
        obj_id,
        obj_type
    FROM dep_recurse.relation_dependents

    UNION -- prevent potential duplicates

    SELECT
        ref_obj_id,
        ref_obj_type,
        obj_id,
        obj_type
    FROM dep_recurse.view_function_dependents
) d WHERE obj_id <> ref_obj_id;


CREATE VIEW dep_recurse.view_relation_dependencies AS
SELECT
    pg_rewrite.ev_class ref_obj_id,
    'view'::dep_recurse.obj_type ref_obj_type,
    pg_depend.refobjid obj_id,
    dep_recurse.relkind_to_obj_type(pg_class.relkind) AS obj_type
FROM pg_rewrite
JOIN pg_depend ON
    pg_depend.objid = pg_rewrite.oid
    AND
    pg_depend.deptype = 'n'
JOIN pg_class ON
    pg_class.oid = pg_depend.refobjid
WHERE
    pg_depend.refobjid <> pg_rewrite.ev_class
GROUP BY pg_rewrite.ev_class, pg_depend.refobjid, pg_class.relkind;


CREATE VIEW dep_recurse.relation_dependencies AS
SELECT ref_obj_id, ref_obj_type, obj_id, obj_type
FROM dep_recurse.view_relation_dependencies;


CREATE VIEW dep_recurse.direct_function_dependencies AS
SELECT
    pg_proc.oid ref_obj_id,
    'function'::dep_recurse.obj_type ref_obj_type,
    pg_class.oid obj_id,
    dep_recurse.relkind_to_obj_type(pg_class.relkind) obj_type
FROM pg_class
JOIN pg_type ON pg_type.oid = pg_class.reltype
JOIN pg_depend ON pg_depend.refobjid = pg_type.oid
JOIN pg_proc ON pg_proc.oid = pg_depend.objid
WHERE pg_depend.deptype = 'n';


CREATE VIEW dep_recurse.direct_dependencies AS

SELECT
    ref_obj_id,
    ref_obj_type,
    obj_id,
    obj_type
FROM dep_recurse.direct_function_dependencies

UNION ALL

SELECT
    ref_obj_id,
    ref_obj_type,
    obj_id,
    obj_type
FROM dep_recurse.relation_dependencies;


CREATE VIEW dep_recurse.dependents_tree AS
WITH RECURSIVE dependents(root_obj_id, root_obj_type, obj_id, obj_type, depth, path, cycle) AS (
    SELECT
        dirdep.ref_obj_id root_obj_id,
        dirdep.ref_obj_type root_obj_type,
        dirdep.obj_id,
        dirdep.obj_type,
        1 AS depth,
        ARRAY[dirdep.obj_id] AS path,
        false AS cycle
    FROM dep_recurse.dependents dirdep
    UNION ALL
    SELECT
        d.root_obj_id,
        d.root_obj_type,
        dependents.obj_id,
        dependents.obj_type,
        d.depth + 1 AS depth,
        d.path || d.obj_id AS path,
        d.obj_id = ANY(d.path) AS cycle
    FROM dependents d
    JOIN dep_recurse.dependents ON dependents.ref_obj_id = d.obj_id
    WHERE NOT cycle
)
SELECT
    root_obj_id,
    root_obj_type,
    (obj_id, obj_type)::dep_recurse.obj_ref obj_ref,
    max(depth) depth
FROM dependents
WHERE obj_id IS NOT NULL
GROUP BY root_obj_id, root_obj_type, obj_id, obj_type;


CREATE VIEW dep_recurse.dependency_tree AS
WITH RECURSIVE dependencies(root_obj_id, root_obj_type, obj_id, obj_type, depth, path, cycle) AS (
    SELECT
        dirdep.ref_obj_id root_obj_id,
        dirdep.ref_obj_type root_obj_type,
        dirdep.obj_id,
        dirdep.obj_type,
        1 AS depth,
        ARRAY[dirdep.obj_id] AS path,
        false AS cycle
    FROM dep_recurse.direct_dependencies dirdep
    UNION ALL
    SELECT
        d.root_obj_id,
        d.root_obj_type,
        direct_dependencies.obj_id,
        direct_dependencies.obj_type,
        d.depth + 1 AS depth,
        d.path || direct_dependencies.obj_id AS path,
        direct_dependencies.obj_id = ANY(d.path) AS cycle
    FROM dependencies d
    JOIN dep_recurse.direct_dependencies ON direct_dependencies.ref_obj_id = d.obj_id
    WHERE NOT cycle
)
SELECT root_obj_id, root_obj_type, (obj_id, obj_type)::dep_recurse.obj_ref obj_ref, max(depth) depth
FROM dependencies
WHERE obj_id IS NOT NULL
GROUP BY root_obj_id, root_obj_type, obj_id, obj_type;
