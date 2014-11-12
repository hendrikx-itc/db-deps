CREATE OR REPLACE FUNCTION dep_recurse.grant_view_statements(oid)
    RETURNS SETOF varchar
AS $$
SELECT
    format('GRANT %s ON %I.%I TO %s;', privilege_type, table_schema, table_name, grantee)
FROM information_schema.role_table_grants rtg
JOIN pg_class cl ON cl.relname = rtg.table_name
JOIN pg_roles r ON r.oid = cl.relowner
JOIN pg_namespace nsp ON nsp.nspname = rtg.table_schema
WHERE cl.oid = $1 AND grantee <> r.rolname;
$$ LANGUAGE sql STABLE;


CREATE OR REPLACE FUNCTION dep_recurse.owner_view_statement(oid)
    RETURNS text
AS $$
SELECT
    format('ALTER VIEW %I.%I OWNER TO %s;', nsp.nspname, cl.relname, r.rolname)
FROM pg_class cl
JOIN pg_namespace nsp ON nsp.oid = cl.relnamespace
JOIN pg_roles r ON r.oid = cl.relowner
WHERE cl.oid = $1;
$$ LANGUAGE sql STABLE;


CREATE OR REPLACE FUNCTION dep_recurse.create_view_statement(oid)
    RETURNS varchar
AS $$
SELECT
    format('CREATE VIEW %I.%I AS %s', pg_namespace.nspname, pg_class.relname, pg_get_viewdef($1))
FROM pg_class
JOIN pg_namespace ON pg_namespace.oid = pg_class.relnamespace
WHERE pg_class.oid = $1;
$$ LANGUAGE sql STABLE;


CREATE OR REPLACE FUNCTION dep_recurse.view_drop_statement(oid)
    RETURNS SETOF varchar
AS $$
SELECT
    format('DROP VIEW %I.%I', pg_namespace.nspname, pg_class.relname)
FROM pg_class
JOIN pg_namespace ON pg_namespace.oid = pg_class.relnamespace
WHERE pg_class.oid = $1;
$$ LANGUAGE sql STABLE;


CREATE OR REPLACE FUNCTION dep_recurse.create_materialized_view_statement(obj_schema name, obj_name name)
    RETURNS varchar
AS $$
SELECT
    format('CREATE MATERIALIZED VIEW %I.%I AS %s', $1, $2, definition)
FROM pg_matviews
WHERE schemaname = $1 AND matviewname = $2; 
$$ LANGUAGE sql STABLE;


CREATE OR REPLACE FUNCTION dep_recurse.materialized_view_drop_statement(oid)
    RETURNS SETOF varchar
AS $$
SELECT
    format('DROP MATERIALIZED VIEW %I.%I', pg_namespace.nspname, pg_class.relname)
FROM pg_class
JOIN pg_namespace ON pg_namespace.oid = pg_class.relnamespace
WHERE pg_class.oid = $1;
$$ LANGUAGE sql STABLE;


CREATE OR REPLACE FUNCTION dep_recurse.comment_view_statement(oid)
    RETURNS varchar
AS $$
SELECT
    format('COMMENT ON VIEW %I.%I IS %L;', n.nspname, c.relname, d.description)
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
JOIN pg_description d ON d.objoid = c.oid AND d.objsubid = 0
WHERE c.oid = $1 AND d.description IS NOT null;
$$ LANGUAGE sql STABLE;


CREATE OR REPLACE FUNCTION dep_recurse.comment_column_statements(oid)
    RETURNS SETOF varchar
AS $$
SELECT
    format('COMMENT ON COLUMN %I.%I.%I IS %L;', n.nspname, c.relname, a.attname, d.description)
FROM pg_class c
JOIN pg_attribute a ON c.oid = a.attrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
JOIN pg_description d ON d.objoid = c.oid and d.objsubid = a.attnum
WHERE c.oid = $1 AND d.description is NOT null;
$$ LANGUAGE sql STABLE;


CREATE OR REPLACE FUNCTION dep_recurse.table_ref(obj_schema name, obj_name name)
    RETURNS dep_recurse.obj_ref
AS $$
    SELECT pg_class.oid, 'table'::dep_recurse.obj_type
    FROM pg_class
    JOIN pg_namespace ON pg_class.relnamespace = pg_namespace.oid
    WHERE pg_namespace.nspname = $1 AND pg_class.relname = $2
$$ LANGUAGE sql STABLE;


CREATE OR REPLACE FUNCTION dep_recurse.view_ref(obj_schema name, obj_name name)
    RETURNS dep_recurse.obj_ref
AS $$
    SELECT pg_class.oid, 'view'::dep_recurse.obj_type
    FROM pg_class
    JOIN pg_namespace ON pg_class.relnamespace = pg_namespace.oid
    WHERE pg_namespace.nspname = obj_schema AND pg_class.relname = obj_name
$$ LANGUAGE sql STABLE;


--CREATE OR REPLACE FUNCTION dep_recurse.function_ref(obj_schema name, obj_name name, signature name[])
--    RETURNS obj_ref
--AS $$
--SELECT array_agg(typname)
--FROM (
--   SELECT unnest(proargtypes) type_oid
--    FROM pg_proc
--) t
--JOIN pg_type ON pg_type.oid = t.type_oid
--JOIN pg_namespace ON pronamespace = pg_namespace.oid;
--$$ LANGUAGE sql STABLE;


CREATE OR REPLACE FUNCTION dep_recurse.view_to_char(oid)
    RETURNS text
AS $$
SELECT format('%I.%I', nspname, relname)
FROM pg_class
JOIN pg_namespace ON relnamespace = pg_namespace.oid
WHERE pg_class.oid = $1;
$$ LANGUAGE sql STABLE;


CREATE OR REPLACE FUNCTION dep_recurse.type_to_char(oid)
    RETURNS text
AS $$
SELECT format('%I.%I', nspname, typname)
FROM pg_type
JOIN pg_namespace ON pg_namespace.oid = pg_type.typnamespace
WHERE pg_type.oid = $1;
$$ LANGUAGE sql STABLE;


CREATE OR REPLACE FUNCTION dep_recurse.function_signature(oid)
    RETURNS text[]
AS $$
SELECT array_agg(dep_recurse.type_to_char(type_oid))
FROM (
    SELECT unnest(proargtypes) type_oid
    FROM pg_proc WHERE oid = $1
) t
$$ LANGUAGE sql STABLE;


CREATE OR REPLACE FUNCTION dep_recurse.function_signature_str(oid)
    RETURNS text
AS $$
SELECT array_to_string(array_agg(dep_recurse.type_to_char(type_oid)), ', ')
FROM (
    SELECT unnest(proargtypes) type_oid
    FROM pg_proc WHERE oid = $1
) t;
$$ LANGUAGE sql STABLE;


CREATE OR REPLACE FUNCTION dep_recurse.function_to_char(oid)
    RETURNS text
AS $$
SELECT format('%I.%I(%s)', nspname, proname, dep_recurse.function_signature_str($1))
FROM pg_proc
JOIN pg_namespace ON pronamespace = pg_namespace.oid
WHERE pg_proc.oid = $1;
$$ LANGUAGE sql STABLE;


CREATE OR REPLACE FUNCTION dep_recurse.to_char(dep_recurse.obj_ref)
    RETURNS text
AS $$
SELECT CASE $1.obj_type
WHEN 'view' THEN dep_recurse.view_to_char($1.obj_id)
WHEN 'materialized view' THEN dep_recurse.view_to_char($1.obj_id)
WHEN 'function' THEN dep_recurse.function_to_char($1.obj_id)
END;
$$ LANGUAGE sql STABLE;

CREATE CAST (dep_recurse.obj_ref AS text) WITH FUNCTION dep_recurse.to_char(dep_recurse.obj_ref);


CREATE OR REPLACE FUNCTION dep_recurse.to_char(dep_recurse.dep)
    RETURNS text
AS $$
SELECT $1.obj::text;
$$ LANGUAGE sql STABLE;

CREATE CAST (dep_recurse.dep AS text) WITH FUNCTION dep_recurse.to_char(dep_recurse.dep);


CREATE OR REPLACE FUNCTION dep_recurse.owner_function_statement(oid)
    RETURNS varchar
AS $$
SELECT
    format('ALTER FUNCTION %I.%I OWNER TO %s', nspname, proname, pg_authid.rolname)
FROM pg_proc
JOIN pg_namespace ON pg_namespace.oid = pg_proc.pronamespace
JOIN pg_authid ON pg_authid.oid = proowner
WHERE pg_proc.oid = $1;
$$ LANGUAGE sql STABLE;


CREATE OR REPLACE FUNCTION dep_recurse.function_drop_statement(oid)
    RETURNS varchar
AS $$
SELECT
    format('DROP FUNCTION %I.%I(%s)', nspname, proname, dep_recurse.function_signature_str($1))
FROM pg_proc
JOIN pg_namespace ON pg_namespace.oid = pg_proc.pronamespace
WHERE pg_proc.oid = $1;
$$ LANGUAGE sql STABLE;


CREATE OR REPLACE FUNCTION dep_recurse.grant_function_statements(oid)
    RETURNS SETOF varchar
AS $$
    SELECT
        format('GRANT %s ON FUNCTION %I.%I(%s) TO %s', c.privilege_type, nspname, proname, dep_recurse.function_signature_str($1), grantee.rolname)
    FROM (
        SELECT 
            (int.acl).grantee,
            (int.acl).privilege_type,
            (int.acl).is_grantable,
            int.pronamespace,
            int.proname
        FROM (
            SELECT
                pg_proc.oid,
                pg_proc.pronamespace,
                pg_proc.proname,
                pg_proc.proowner,
                (aclexplode(pg_proc.proacl)) acl
            FROM pg_proc
            WHERE oid = $1
        ) int
        WHERE (int.acl).grantee != int.proowner AND (int.acl).grantee != 0
    ) c
    JOIN pg_namespace ON pg_namespace.oid = c.pronamespace
    JOIN
    (
        SELECT
            pg_authid.oid,
            pg_authid.rolname
        FROM
            pg_authid
    ) grantee(oid, rolname) ON c.grantee = grantee.oid;
$$ LANGUAGE sql STABLE;


CREATE OR REPLACE FUNCTION dep_recurse.direct_view_relation_deps(oid)
    RETURNS SETOF dep_recurse.obj_ref 
AS $$
    SELECT
        rwr_cl.oid,
        CASE rwr_cl.relkind
            WHEN 'v' THEN 'view'::dep_recurse.obj_type
            WHEN 'm' THEN 'materialized view'::dep_recurse.obj_type
        END
    FROM pg_depend dep
    JOIN pg_rewrite rwr ON dep.objid = rwr.oid
    JOIN pg_class rwr_cl ON rwr_cl.oid = rwr.ev_class
    WHERE dep.deptype = 'n'
    AND dep.classid = 'pg_rewrite'::regclass
    AND rwr_cl.oid != $1
    AND dep.refobjid = $1
    GROUP BY rwr_cl.oid, rwr_cl.relkind
$$ LANGUAGE sql STABLE;


CREATE OR REPLACE FUNCTION dep_recurse.direct_view_relation_deps(obj_schema name, obj_name name)
    RETURNS SETOF dep_recurse.obj_ref
AS $$
    SELECT dep_recurse.direct_view_relation_deps(pg_class.oid)
    FROM pg_class
    JOIN pg_namespace ON pg_class.relnamespace = pg_namespace.oid
    WHERE pg_namespace.nspname = obj_schema AND pg_class.relname = obj_name
$$ LANGUAGE sql STABLE;

COMMENT ON FUNCTION dep_recurse.direct_view_relation_deps(obj_schema name, obj_name name) IS
'return set of views that are directly dependent on the relation with name obj_name in schema obj_schema';


CREATE OR REPLACE FUNCTION dep_recurse.direct_function_relation_deps(oid)
    RETURNS SETOF dep_recurse.obj_ref
AS $$
SELECT
        pg_proc.oid,
        'function'::dep_recurse.obj_type
FROM pg_class
JOIN pg_type ON pg_type.oid = pg_class.reltype
JOIN pg_depend ON pg_depend.refobjid = pg_type.oid
JOIN pg_proc ON pg_proc.oid = pg_depend.objid
WHERE pg_depend.deptype = 'n' AND pg_class.oid = $1
$$ LANGUAGE sql STABLE;


CREATE OR REPLACE FUNCTION dep_recurse.direct_function_relation_deps(obj_schema name, obj_name name)
    RETURNS SETOF dep_recurse.obj_ref
AS $$
SELECT
    dep_recurse.direct_function_relation_deps(pg_class.oid)
FROM pg_class
JOIN pg_namespace cl_nsp ON pg_class.relnamespace = cl_nsp.oid
WHERE relname = $2 AND cl_nsp.nspname = $1
$$ LANGUAGE sql STABLE;

COMMENT ON FUNCTION dep_recurse.direct_function_relation_deps(obj_schema name, obj_name name) IS
'return set of functions that are directly dependent on the relation with name obj_name in schema obj_schema';


CREATE OR REPLACE FUNCTION dep_recurse.direct_relation_deps(oid)
    RETURNS SETOF dep_recurse.obj_ref
AS $$
SELECT dep_recurse.direct_view_relation_deps($1)
UNION ALL
SELECT dep_recurse.direct_function_relation_deps($1);
$$ LANGUAGE sql STABLE;

COMMENT ON FUNCTION dep_recurse.direct_relation_deps(oid) IS
'return set of references to objects that are directly dependent on the relation oid';


CREATE OR REPLACE FUNCTION dep_recurse.direct_deps(dep_recurse.obj_ref)
    RETURNS SETOF dep_recurse.obj_ref
AS $$
SELECT CASE $1.obj_type
WHEN 'table' THEN dep_recurse.direct_relation_deps($1.obj_id)
WHEN 'view' THEN dep_recurse.direct_relation_deps($1.obj_id)
WHEN 'materialized view' THEN dep_recurse.direct_relation_deps($1.obj_id)
END;
$$ LANGUAGE sql STABLE;


CREATE OR REPLACE FUNCTION dep_recurse.deps(dep_recurse.obj_ref)
    RETURNS SETOF dep_recurse.dep
AS $$
WITH RECURSIVE dependencies(obj_ref, depth, path, cycle) AS (
    SELECT
        dirdep AS obj_ref,
        1 AS depth,
        ARRAY[dirdep.obj_id] AS path,
        false AS cycle
    FROM dep_recurse.direct_deps($1) dirdep
    UNION ALL
    SELECT
        dep_recurse.direct_deps(d.obj_ref) AS obj_ref,
        d.depth + 1 AS depth,
        path || (d.obj_ref).obj_id AS path,
        (d.obj_ref).obj_id = ANY(path) AS cycle
    FROM dependencies d
    WHERE NOT cycle
)
SELECT obj_ref, depth
FROM dependencies
GROUP BY obj_ref, depth;
$$ LANGUAGE sql STABLE;


CREATE OR REPLACE FUNCTION dep_recurse.view_creation_statements(oid)
    RETURNS SETOF varchar
AS $$
SELECT s FROM (
    SELECT dep_recurse.create_view_statement($1) s
    UNION ALL
    SELECT dep_recurse.comment_view_statement($1) s
    UNION ALL
    SELECT dep_recurse.comment_column_statements($1) s
    UNION ALL
    SELECT dep_recurse.owner_view_statement($1) s
    UNION ALL
    SELECT dep_recurse.grant_view_statements($1) s
) statement WHERE s IS NOT NULL;
$$ LANGUAGE sql STABLE;


CREATE OR REPLACE FUNCTION dep_recurse.function_creation_statements(oid)
    RETURNS SETOF varchar
AS $$
SELECT pg_get_functiondef($1)
UNION ALL
SELECT dep_recurse.owner_function_statement($1)
UNION ALL
SELECT dep_recurse.grant_function_statements($1);
$$ LANGUAGE sql STABLE;


CREATE OR REPLACE FUNCTION dep_recurse.creation_statements(dep_recurse.obj_ref)
    RETURNS SETOF varchar
AS $$
SELECT * FROM
(
    SELECT
        CASE $1.obj_type
            WHEN 'view' THEN
                dep_recurse.view_creation_statements($1.obj_id)
            WHEN 'materialized view' THEN
                dep_recurse.view_creation_statements($1.obj_id)
            WHEN 'function' THEN
                dep_recurse.function_creation_statements($1.obj_id)
        END AS statement
) s WHERE statement IS NOT NULL;
$$ LANGUAGE sql STABLE;


CREATE OR REPLACE FUNCTION dep_recurse.drop_statement(dep_recurse.obj_ref)
    RETURNS varchar
AS $$
SELECT
    CASE $1.obj_type
        WHEN 'view' THEN
            dep_recurse.view_drop_statement($1.obj_id)
        WHEN 'materialized view' THEN
            dep_recurse.materialized_view_drop_statement($1.obj_id)
        WHEN 'function' THEN
            dep_recurse.function_drop_statement($1.obj_id)
    END
$$ LANGUAGE sql STABLE;


CREATE OR REPLACE FUNCTION dep_recurse.dependent_drop_statements(dep_recurse.obj_ref)
    RETURNS SETOF varchar
AS $$
    SELECT dep_recurse.drop_statement(d.obj) FROM dep_recurse.deps($1) d ORDER BY d.distance DESC;
$$ LANGUAGE sql STABLE;


CREATE OR REPLACE FUNCTION dep_recurse.alter(obj dep_recurse.obj_ref, changes varchar[])
    RETURNS dep_recurse.obj_ref
AS $$
DECLARE
    statement varchar;
    drop_statements varchar[];
    recreation_statements varchar[];
    tmp_deps dep_recurse.dep[];
BEGIN
    SELECT dep_recurse.deps($1) INTO tmp_deps;
    SELECT array_agg(stat) INTO recreation_statements FROM dep_recurse.creation_statements($1) stat;

    FOREACH statement IN ARRAY recreation_statements LOOP
        EXECUTE statement;
    END LOOP;

    RETURN $1;
END;
$$ LANGUAGE plpgsql VOLATILE;
