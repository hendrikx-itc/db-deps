CREATE FUNCTION dep_recurse.grant_view_statements(oid)
    RETURNS SETOF text
AS $$
SELECT
    format('GRANT %s ON %I.%I TO %s;', privilege_type, table_schema, table_name, grantee)
FROM information_schema.role_table_grants rtg
JOIN pg_class cl ON cl.relname = rtg.table_name
JOIN pg_roles r ON r.oid = cl.relowner
JOIN pg_namespace nsp ON nsp.oid = cl.relnamespace AND nsp.nspname = rtg.table_schema
WHERE cl.oid = $1 AND grantee <> r.rolname;
$$ LANGUAGE sql STABLE;


CREATE FUNCTION dep_recurse.owner_view_statement(oid)
    RETURNS text
AS $$
SELECT
    format('ALTER VIEW %I.%I OWNER TO %s;', nsp.nspname, cl.relname, r.rolname)
FROM pg_class cl
JOIN pg_namespace nsp ON nsp.oid = cl.relnamespace
JOIN pg_roles r ON r.oid = cl.relowner
WHERE cl.oid = $1;
$$ LANGUAGE sql STABLE;


CREATE FUNCTION dep_recurse.create_view_statement(oid)
    RETURNS text
AS $$
SELECT
    format(
        'CREATE VIEW %I.%I AS %s',
        pg_namespace.nspname,
        pg_class.relname,
        pg_get_viewdef($1)
    )
FROM pg_class
JOIN pg_namespace ON pg_namespace.oid = pg_class.relnamespace
WHERE pg_class.oid = $1;
$$ LANGUAGE sql STABLE;


CREATE FUNCTION dep_recurse.view_drop_statement(oid)
    RETURNS SETOF text
AS $$
SELECT
    format('DROP VIEW %I.%I', pg_namespace.nspname, pg_class.relname)
FROM pg_class
JOIN pg_namespace ON pg_namespace.oid = pg_class.relnamespace
WHERE pg_class.oid = $1;
$$ LANGUAGE sql STABLE;


CREATE FUNCTION dep_recurse.create_materialized_view_statement(
        obj_schema name, obj_name name)
    RETURNS text
AS $$
SELECT
    format('CREATE MATERIALIZED VIEW %I.%I AS %s', $1, $2, definition)
FROM pg_matviews
WHERE schemaname = $1 AND matviewname = $2;
$$ LANGUAGE sql STABLE;


CREATE FUNCTION dep_recurse.materialized_view_drop_statement(oid)
    RETURNS SETOF text
AS $$
SELECT
    format(
        'DROP MATERIALIZED VIEW %I.%I',
        pg_namespace.nspname,
        pg_class.relname
    )
FROM pg_class
JOIN pg_namespace ON pg_namespace.oid = pg_class.relnamespace
WHERE pg_class.oid = $1;
$$ LANGUAGE sql STABLE;


CREATE FUNCTION dep_recurse.comment_view_statement(oid)
    RETURNS text
AS $$
SELECT
    format('COMMENT ON VIEW %I.%I IS %L;', n.nspname, c.relname, d.description)
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
JOIN pg_description d ON d.objoid = c.oid AND d.objsubid = 0
WHERE c.oid = $1 AND d.description IS NOT null;
$$ LANGUAGE sql STABLE;


CREATE FUNCTION dep_recurse.comment_column_statements(oid)
    RETURNS SETOF text
AS $$
SELECT
    format(
        'COMMENT ON COLUMN %I.%I.%I IS %L;',
        n.nspname,
        c.relname,
        a.attname,
        d.description
    )
FROM pg_class c
JOIN pg_attribute a ON c.oid = a.attrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
JOIN pg_description d ON d.objoid = c.oid and d.objsubid = a.attnum
WHERE c.oid = $1 AND d.description is NOT null;
$$ LANGUAGE sql STABLE;


CREATE FUNCTION dep_recurse.owner_function_statement(oid)
    RETURNS text
AS $$
SELECT format(
    'ALTER FUNCTION %I.%I(%s) OWNER TO %s',
    nspname,
    proname,
    dep_recurse.function_signature_str($1),
    pg_authid.rolname
)
FROM pg_proc
JOIN pg_namespace ON pg_namespace.oid = pg_proc.pronamespace
JOIN pg_authid ON pg_authid.oid = proowner
WHERE pg_proc.oid = $1;
$$ LANGUAGE sql STABLE;


CREATE FUNCTION dep_recurse.function_drop_statement(oid)
    RETURNS text
AS $$
SELECT format(
    'DROP FUNCTION %I.%I(%s)',
    nspname,
    proname,
    dep_recurse.function_signature_str($1)
)
FROM pg_proc
JOIN pg_namespace ON pg_namespace.oid = pg_proc.pronamespace
WHERE pg_proc.oid = $1;
$$ LANGUAGE sql STABLE;


CREATE FUNCTION dep_recurse.grant_function_statements(oid)
    RETURNS SETOF text
AS $$
    SELECT format(
        'GRANT %s ON FUNCTION %I.%I(%s) TO %s',
        c.privilege_type,
        nspname,
        proname,
        dep_recurse.function_signature_str($1),
        grantee.rolname
    )
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


CREATE FUNCTION dep_recurse.direct_table_relation_dependents(oid)
    RETURNS SETOF dep_recurse.obj_ref
AS $$
    SELECT
        child_relation_oid,
        'table'::dep_recurse.obj_type
    FROM dep_recurse.table_relation_dependents
    WHERE parent_relation_oid = $1;
$$ LANGUAGE sql STABLE;


CREATE FUNCTION dep_recurse.direct_view_relation_dependencies(oid)
    RETURNS SETOF dep_recurse.obj_ref
AS $$
    SELECT
        obj_id,
        obj_type
    FROM dep_recurse.view_relation_dependencies
    WHERE ref_obj_id = $1;
$$ LANGUAGE sql STABLE;


CREATE FUNCTION dep_recurse.direct_relation_dependencies(oid)
    RETURNS SETOF dep_recurse.obj_ref
AS $$
SELECT dep_recurse.direct_view_relation_dependencies($1);
$$ LANGUAGE sql STABLE;


CREATE FUNCTION dep_recurse.direct_dependencies(dep_recurse.obj_ref)
    RETURNS SETOF dep_recurse.obj_ref
AS $$
SELECT
    obj_id,
    obj_type
FROM dep_recurse.direct_dependencies
WHERE ref_obj_id = $1.obj_id;
$$ LANGUAGE sql STABLE;


CREATE FUNCTION dep_recurse.direct_dependents(dep_recurse.obj_ref)
    RETURNS SETOF dep_recurse.obj_ref
AS $$
SELECT obj_id, obj_type
FROM dep_recurse.dependents
WHERE ref_obj_id = $1.obj_id;
$$ LANGUAGE sql STABLE;


CREATE FUNCTION dep_recurse.dependents(dep_recurse.obj_ref)
    RETURNS SETOF dep_recurse.dependent
AS $$
SELECT obj_ref, depth
FROM dep_recurse.dependents_tree
WHERE root_obj_id = $1.obj_id
ORDER BY obj_ref;
$$ LANGUAGE sql STABLE;


CREATE FUNCTION dep_recurse.dependencies(dep_recurse.obj_ref)
    RETURNS SETOF dep_recurse.dependency
AS $$
SELECT obj_ref, depth
FROM dep_recurse.dependency_tree
WHERE root_obj_id = $1.obj_id;
$$ LANGUAGE sql STABLE;


CREATE FUNCTION dep_recurse.view_creation_statements(oid)
    RETURNS SETOF text
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


CREATE FUNCTION dep_recurse.function_creation_statements(oid)
    RETURNS SETOF text
AS $$
SELECT pg_get_functiondef($1)
UNION ALL
SELECT dep_recurse.owner_function_statement($1)
UNION ALL
SELECT dep_recurse.grant_function_statements($1);
$$ LANGUAGE sql STABLE;


CREATE FUNCTION dep_recurse.creation_statements(dep_recurse.obj_ref)
    RETURNS SETOF text
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


CREATE FUNCTION dep_recurse.drop_statement(dep_recurse.obj_ref)
    RETURNS text
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


CREATE FUNCTION dep_recurse.dependent_drop_statements(dep_recurse.obj_ref)
    RETURNS SETOF text
AS $$
    SELECT *
    FROM (
        SELECT dep_recurse.drop_statement(d.obj)
        FROM (
            SELECT *
            FROM dep_recurse.dependents($1) d
            ORDER BY d.distance DESC
        ) d
    ) drop_statement
    WHERE drop_statement IS NOT NULL;
$$ LANGUAGE sql STABLE;


CREATE FUNCTION dep_recurse.dependent_create_statements(dep_recurse.obj_ref)
    RETURNS SETOF text
AS $$
    SELECT *
    FROM (
        SELECT dep_recurse.creation_statements(d.obj)
        FROM (
            SELECT *
            FROM dep_recurse.dependents($1) d
            ORDER BY d.distance ASC
        ) d
    ) create_statement
    WHERE create_statement IS NOT NULL;
$$ LANGUAGE sql STABLE;


CREATE FUNCTION dep_recurse.dependent_drop_statements_arr(dep_recurse.obj_ref)
    RETURNS text[]
AS $$
    SELECT array_agg(statement)
    FROM dep_recurse.dependent_drop_statements($1) statement;
$$ LANGUAGE sql STABLE;


CREATE FUNCTION dep_recurse.dependent_create_statements_arr(dep_recurse.obj_ref)
    RETURNS text[]
AS $$
    SELECT array_agg(statement)
    FROM dep_recurse.dependent_create_statements($1) statement;
$$ LANGUAGE sql STABLE;


CREATE FUNCTION dep_recurse.alter(obj dep_recurse.obj_ref, changes text[])
    RETURNS dep_recurse.obj_ref
AS $$
    SELECT dep_recurse.execute(
        $1,
        dep_recurse.dependent_drop_statements_arr($1) ||
        $2 ||
        dep_recurse.dependent_create_statements_arr($1)
    );
$$ LANGUAGE sql VOLATILE SECURITY DEFINER;


CREATE FUNCTION dep_recurse.dependent_drop_statements(
        dep_recurse.obj_ref, exclude dep_recurse.obj_ref[])
    RETURNS SETOF text
AS $$
    SELECT *
    FROM (
        SELECT dep_recurse.drop_statement(d.obj)
        FROM (
            SELECT *
            FROM dep_recurse.dependents($1) d
            WHERE NOT d.obj = ANY($2)
            ORDER BY d.distance DESC
        ) d
    ) drop_statement
    WHERE drop_statement IS NOT NULL;
$$ LANGUAGE sql STABLE;


CREATE FUNCTION dep_recurse.dependent_create_statements(
        dep_recurse.obj_ref, exclude dep_recurse.obj_ref[])
    RETURNS SETOF text
AS $$
    SELECT *
    FROM (
        SELECT dep_recurse.creation_statements(d.obj)
        FROM (
            SELECT *
            FROM dep_recurse.dependents($1) d
            WHERE NOT d.obj = ANY($2)
            ORDER BY d.distance ASC
        ) d
    ) create_statement
    WHERE create_statement IS NOT NULL;
$$ LANGUAGE sql STABLE;


CREATE FUNCTION dep_recurse.dependent_drop_statements_arr(
        dep_recurse.obj_ref, exclude dep_recurse.obj_ref[])
    RETURNS text[]
AS $$
    SELECT array_agg(statement)
    FROM dep_recurse.dependent_drop_statements($1, $2) statement;
$$ LANGUAGE sql STABLE;


CREATE FUNCTION dep_recurse.dependent_create_statements_arr(
        dep_recurse.obj_ref, exclude dep_recurse.obj_ref[])
    RETURNS text[]
AS $$
    SELECT array_agg(statement)
    FROM dep_recurse.dependent_create_statements($1, $2) statement;
$$ LANGUAGE sql STABLE;


CREATE OR REPLACE FUNCTION dep_recurse.alter(
        obj dep_recurse.obj_ref, changes text[], exclude dep_recurse.obj_ref[])
    RETURNS dep_recurse.obj_ref
AS $$
    SELECT dep_recurse.execute(
        $1,
        dep_recurse.dependent_drop_statements_arr($1, $3) ||
        $2 ||
        dep_recurse.dependent_create_statements_arr($1, $3)
    );
$$ LANGUAGE sql VOLATILE SECURITY DEFINER;

