CREATE OR REPLACE FUNCTION grant_view_statements(oid)
    RETURNS SETOF varchar
AS $$
SELECT
    format('GRANT %s ON %I.%I TO %s;', privilege_type, table_schema, table_name, grantee)
FROM information_schema.role_table_grants rtg
JOIN pg_class cl ON cl.relname = rtg.table_name
JOIN pg_namespace nsp ON nsp.nspname = rtg.table_schema
WHERE cl.oid = $1;
$$ LANGUAGE sql STABLE;


CREATE OR REPLACE FUNCTION create_view_statement(oid)
    RETURNS varchar
AS $$
SELECT
    format('CREATE VIEW %I.%I AS %s', pg_namespace.nspname, pg_class.relname, pg_get_viewdef($1))
FROM pg_class
JOIN pg_namespace ON pg_namespace.oid = pg_class.relnamespace
WHERE pg_class.oid = $1;
$$ LANGUAGE sql STABLE;


CREATE OR REPLACE FUNCTION view_drop_statement(oid)
    RETURNS SETOF varchar
AS $$
SELECT
    format('DROP VIEW %I.%I', pg_namespace.nspname, pg_class.relname)
FROM pg_class
JOIN pg_namespace ON pg_namespace.oid = pg_class.relnamespace
WHERE pg_class.oid = $1;
$$ LANGUAGE sql STABLE;


CREATE OR REPLACE FUNCTION create_materialized_view_statement(obj_schema name, obj_name name)
    RETURNS varchar
AS $$
SELECT
    format('CREATE MATERIALIZED VIEW %I.%I AS %s', $1, $2, definition)
FROM pg_matviews
WHERE schemaname = $1 AND matviewname = $2; 
$$ LANGUAGE sql STABLE;


CREATE OR REPLACE FUNCTION materialized_view_drop_statement(oid)
    RETURNS SETOF varchar
AS $$
SELECT
    format('DROP MATERIALIZED VIEW %I.%I', pg_namespace.nspname, pg_class.relname)
FROM pg_class
JOIN pg_namespace ON pg_namespace.oid = pg_class.relnamespace
WHERE pg_class.oid = $1;
$$ LANGUAGE sql STABLE;


CREATE OR REPLACE FUNCTION comment_view_statement(oid)
    RETURNS varchar
AS $$
SELECT
    format('COMMENT ON VIEW %I.%I IS %L;', n.nspname, c.relname, d.description)
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
JOIN pg_description d ON d.objoid = c.oid AND d.objsubid = 0
WHERE c.oid = $1 AND d.description IS NOT null;
$$ LANGUAGE sql STABLE;


CREATE OR REPLACE FUNCTION comment_column_statements(oid)
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


CREATE OR REPLACE FUNCTION table_ref(obj_schema name, obj_name name)
    RETURNS obj_ref
AS $$
    SELECT pg_class.oid, 'table'::varchar
    FROM pg_class
    JOIN pg_namespace ON pg_class.relnamespace = pg_namespace.oid
    WHERE pg_namespace.nspname = obj_schema AND pg_class.relname = obj_name
$$ LANGUAGE sql STABLE;


CREATE OR REPLACE FUNCTION view_ref(obj_schema name, obj_name name)
    RETURNS obj_ref
AS $$
    SELECT pg_class.oid, 'view'::varchar
    FROM pg_class
    JOIN pg_namespace ON pg_class.relnamespace = pg_namespace.oid
    WHERE pg_namespace.nspname = obj_schema AND pg_class.relname = obj_name
$$ LANGUAGE sql STABLE;


--CREATE OR REPLACE FUNCTION function_ref(obj_schema name, obj_name name, signature name[])
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


CREATE OR REPLACE FUNCTION view_to_char(oid)
    RETURNS text
AS $$
SELECT format('%I.%I', nspname, relname)
FROM pg_class
JOIN pg_namespace ON relnamespace = pg_namespace.oid
WHERE pg_class.oid = $1;
$$ LANGUAGE sql STABLE;


CREATE OR REPLACE FUNCTION type_to_char(oid)
    RETURNS text
AS $$
SELECT format('%I.%I', nspname, typname)
FROM pg_type
JOIN pg_namespace ON pg_namespace.oid = pg_type.typnamespace
WHERE pg_type.oid = $1;
$$ LANGUAGE sql STABLE;


CREATE OR REPLACE FUNCTION function_signature(oid)
    RETURNS text[]
AS $$
SELECT array_agg(type_to_char(type_oid))
FROM (
    SELECT unnest(proargtypes) type_oid
    FROM pg_proc WHERE oid = $1
) t
$$ LANGUAGE sql STABLE;


CREATE OR REPLACE FUNCTION function_signature_str(oid)
    RETURNS text
AS $$
SELECT array_to_string(array_agg(type_to_char(type_oid)), ', ')
FROM (
    SELECT unnest(proargtypes) type_oid
    FROM pg_proc WHERE oid = $1
) t;
$$ LANGUAGE sql STABLE;


CREATE OR REPLACE FUNCTION function_to_char(oid)
    RETURNS text
AS $$
SELECT format('%I.%I(%s)', nspname, proname, function_signature_str($1))
FROM pg_proc
JOIN pg_namespace ON pronamespace = pg_namespace.oid
WHERE pg_proc.oid = $1;
$$ LANGUAGE sql STABLE;


CREATE OR REPLACE FUNCTION to_char(obj_ref)
    RETURNS text
AS $$
SELECT CASE $1.obj_type
WHEN 'view' THEN view_to_char($1.obj_id)
WHEN 'materialized view' THEN view_to_char($1.obj_id)
WHEN 'function' THEN function_to_char($1.obj_id)
END;
$$ LANGUAGE sql STABLE;

CREATE CAST (obj_ref AS text) WITH FUNCTION to_char(obj_ref);


CREATE OR REPLACE FUNCTION owner_function_statement(oid)
    RETURNS varchar
AS $$
SELECT
    format('ALTER FUNCTION %I.%I OWNER TO %s', nspname, proname, pg_authid.rolname)
FROM pg_proc
JOIN pg_namespace ON pg_namespace.oid = pg_proc.pronamespace
JOIN pg_authid ON pg_authid.oid = proowner
WHERE pg_proc.oid = $1;
$$ LANGUAGE sql STABLE;


CREATE OR REPLACE FUNCTION function_drop_statement(oid)
    RETURNS varchar
AS $$
SELECT
    format('DROP FUNCTION %I.%I(%s)', nspname, proname, function_signature_str($1))
FROM pg_proc
JOIN pg_namespace ON pg_namespace.oid = pg_proc.pronamespace
WHERE pg_proc.oid = $1;
$$ LANGUAGE sql STABLE;


CREATE OR REPLACE FUNCTION grant_function_statements(oid)
    RETURNS SETOF varchar
AS $$
    SELECT
        format('GRANT %s ON FUNCTION %I.%I(%s) TO %s', c.privilege_type, nspname, proname, function_signature_str($1), grantee.rolname)
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


CREATE OR REPLACE FUNCTION direct_view_relation_deps(oid)
    RETURNS SETOF obj_ref 
AS $$
    SELECT
        rwr_cl.oid,
        CASE rwr_cl.relkind
            WHEN 'v' THEN 'view'
            WHEN 'm' THEN 'materialized view'
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


CREATE OR REPLACE FUNCTION direct_view_relation_deps(obj_schema name, obj_name name)
    RETURNS SETOF obj_ref
AS $$
    SELECT direct_view_relation_deps(pg_class.oid)
    FROM pg_class
    JOIN pg_namespace ON pg_class.relnamespace = pg_namespace.oid
    WHERE pg_namespace.nspname = obj_schema AND pg_class.relname = obj_name
$$ LANGUAGE sql STABLE;

COMMENT ON FUNCTION direct_view_relation_deps(obj_schema name, obj_name name) IS 'return set of views that are directly dependent on the relation with name obj_name in schema obj_schema';


CREATE OR REPLACE FUNCTION direct_function_relation_deps(oid)
    RETURNS SETOF obj_ref
AS $$
SELECT
        pg_proc.oid,
        'function'::varchar
FROM pg_class
JOIN pg_type ON pg_type.oid = pg_class.reltype
JOIN pg_depend ON pg_depend.refobjid = pg_type.oid
JOIN pg_proc ON pg_proc.oid = pg_depend.objid
WHERE pg_depend.deptype = 'n' AND pg_class.oid = $1
$$ LANGUAGE sql STABLE;


CREATE OR REPLACE FUNCTION direct_function_relation_deps(obj_schema name, obj_name name)
    RETURNS SETOF obj_ref
AS $$
SELECT
    direct_function_relation_deps(pg_class.oid)
FROM pg_class
JOIN pg_namespace cl_nsp ON pg_class.relnamespace = cl_nsp.oid
WHERE relname = $2 AND cl_nsp.nspname = $1
$$ LANGUAGE sql STABLE;

COMMENT ON FUNCTION direct_function_relation_deps(obj_schema name, obj_name name) IS 'return set of functions that are directly dependent on the relation with name obj_name in schema obj_schema';


CREATE OR REPLACE FUNCTION direct_relation_deps(oid)
    RETURNS SETOF obj_ref
AS $$
SELECT direct_view_relation_deps($1)
UNION ALL
SELECT direct_function_relation_deps($1);
$$ LANGUAGE sql STABLE;

COMMENT ON FUNCTION direct_relation_deps(oid) IS 'return set of references to objects that are directly dependent on the relation oid';


CREATE OR REPLACE FUNCTION direct_deps(obj_ref)
    RETURNS SETOF obj_ref
AS $$
SELECT CASE $1.obj_type
WHEN 'table' THEN direct_relation_deps($1.obj_id)
WHEN 'view' THEN direct_relation_deps($1.obj_id)
WHEN 'materialized view' THEN direct_relation_deps($1.obj_id)
END;
$$ LANGUAGE sql STABLE;


CREATE OR REPLACE FUNCTION deps(obj_ref)
    RETURNS SETOF dep
AS $$
WITH RECURSIVE dependencies(obj_ref, depth, path, cycle) AS (
    SELECT
        dirdep AS obj_ref,
        1 AS depth,
        ARRAY[dirdep.obj_id] AS path,
        false AS cycle
    FROM direct_deps($1) dirdep
    UNION ALL
    SELECT
        direct_deps(d.obj_ref) AS obj_ref,
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


CREATE OR REPLACE FUNCTION view_creation_statements(oid)
    RETURNS SETOF varchar
AS $$
SELECT create_view_statement($1)
UNION ALL
SELECT comment_view_statement($1)
UNION ALL
SELECT comment_column_statements($1)
UNION ALL
SELECT grant_view_statements($1);
$$ LANGUAGE sql STABLE;


CREATE OR REPLACE FUNCTION function_creation_statements(oid)
    RETURNS SETOF varchar
AS $$
SELECT pg_get_functiondef($1)
UNION ALL
SELECT owner_function_statement($1)
UNION ALL
SELECT grant_function_statements($1);
$$ LANGUAGE sql STABLE;


CREATE OR REPLACE FUNCTION creation_statements(obj_ref)
    RETURNS SETOF varchar
AS $$
SELECT * FROM
(
    SELECT
        CASE $1.obj_type
            WHEN 'view' THEN
                view_creation_statements($1.obj_id)
            WHEN 'materialized view' THEN
                view_creation_statements($1.obj_id)
            WHEN 'function' THEN
                function_creation_statements($1.obj_id)
        END AS statement
) s WHERE statement IS NOT NULL;
$$ LANGUAGE sql STABLE;


CREATE OR REPLACE FUNCTION drop_statement(obj_ref)
    RETURNS varchar
AS $$
SELECT
    CASE $1.obj_type
        WHEN 'view' THEN
            view_drop_statement($1.obj_id)
        WHEN 'materialized view' THEN
            materialized_view_drop_statement($1.obj_id)
        WHEN 'function' THEN
            function_drop_statement($1.obj_id)
    END
$$ LANGUAGE sql STABLE;


CREATE OR REPLACE FUNCTION dependent_drop_statements(obj_ref)
    RETURNS SETOF varchar
AS $$
    SELECT drop_statement(d.obj) FROM deps($1) d ORDER BY d.distance DESC;
$$ LANGUAGE sql STABLE;


CREATE OR REPLACE FUNCTION alter(obj obj_ref, changes varchar[])
    RETURNS obj_ref
AS $$
DECLARE
    statement varchar;
    drop_statements varchar[];
    recreation_statements varchar[];
    tmp_deps dep[];
BEGIN
    SELECT deps($1) INTO tmp_deps;
    SELECT array_agg(stat) INTO recreation_statements FROM creation_statements($1) stat;

    FOREACH statement IN ARRAY recreation_statements LOOP
        EXECUTE statement;
    END LOOP;

    RETURN $1;
END;
$$ LANGUAGE plpgsql VOLATILE;
