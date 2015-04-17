CREATE FUNCTION dep_recurse.relkind_to_obj_type("char")
    RETURNS dep_recurse.obj_type
AS $$
SELECT
    CASE $1
        WHEN 'r' THEN 'table'::dep_recurse.obj_type
        WHEN 'v' THEN 'view'::dep_recurse.obj_type
        WHEN 'm' THEN 'materialized view'::dep_recurse.obj_type
    END;
$$ LANGUAGE sql IMMUTABLE;


CREATE FUNCTION dep_recurse.execute(anyelement, statements text[])
    RETURNS anyelement
AS $$
DECLARE
    statement text;
BEGIN
    FOREACH statement IN ARRAY statements LOOP
        EXECUTE statement;
    END LOOP;

    RETURN $1;
END;
$$ LANGUAGE plpgsql VOLATILE STRICT;

COMMENT ON FUNCTION dep_recurse.execute(anyelement, text[]) IS
'execute a set of schema altering queries';


CREATE FUNCTION dep_recurse.to_oid(dep_recurse.obj_ref)
    RETURNS oid
AS $$
    SELECT $1.obj_id;
$$ LANGUAGE sql IMMUTABLE;

CREATE CAST (dep_recurse.obj_ref AS oid)
WITH FUNCTION dep_recurse.to_oid(dep_recurse.obj_ref);


CREATE FUNCTION dep_recurse.table_ref(oid)
    RETURNS dep_recurse.obj_ref
AS $$
    SELECT $1, 'table'::dep_recurse.obj_type
$$ LANGUAGE sql IMMUTABLE;


CREATE FUNCTION dep_recurse.table_ref(obj_schema name, obj_name name)
    RETURNS dep_recurse.obj_ref
AS $$
    SELECT
        dep_recurse.table_ref(pg_class.oid)
    FROM pg_class
    JOIN pg_namespace ON pg_class.relnamespace = pg_namespace.oid
    WHERE pg_namespace.nspname = $1 AND pg_class.relname = $2
$$ LANGUAGE sql STABLE;


CREATE FUNCTION dep_recurse.view_ref(oid)
    RETURNS dep_recurse.obj_ref
AS $$
    SELECT $1, 'view'::dep_recurse.obj_type
$$ LANGUAGE sql IMMUTABLE;


CREATE FUNCTION dep_recurse.view_ref(obj_schema name, obj_name name)
    RETURNS dep_recurse.obj_ref
AS $$
    SELECT
        dep_recurse.view_ref(pg_class.oid)
    FROM pg_class
    JOIN pg_namespace ON pg_class.relnamespace = pg_namespace.oid
    WHERE pg_namespace.nspname = $1 AND pg_class.relname = $2
$$ LANGUAGE sql STABLE;


CREATE FUNCTION dep_recurse.table_to_char(oid)
    RETURNS text
AS $$
SELECT format('%I.%I', nspname, relname)
FROM pg_class
JOIN pg_namespace ON relnamespace = pg_namespace.oid
WHERE pg_class.oid = $1;
$$ LANGUAGE sql STABLE;


CREATE FUNCTION dep_recurse.view_to_char(oid)
    RETURNS text
AS $$
SELECT format('%I.%I', nspname, relname)
FROM pg_class
JOIN pg_namespace ON relnamespace = pg_namespace.oid
WHERE pg_class.oid = $1;
$$ LANGUAGE sql STABLE;


CREATE FUNCTION dep_recurse.type_to_char(oid)
    RETURNS text
AS $$
SELECT format('%I.%I', nspname, typname)
FROM pg_type
JOIN pg_namespace ON pg_namespace.oid = pg_type.typnamespace
WHERE pg_type.oid = $1;
$$ LANGUAGE sql STABLE;


CREATE FUNCTION dep_recurse.function_ref(oid)
    RETURNS dep_recurse.obj_ref
AS $$
SELECT ($1, 'function')::dep_recurse.obj_ref
$$ LANGUAGE sql IMMUTABLE;


CREATE FUNCTION dep_recurse.function_ref(
        obj_schema name, obj_name name, signature text[])
    RETURNS dep_recurse.obj_ref
AS $$
SELECT
    dep_recurse.function_ref(bar.oid)
FROM (
	SELECT foo.oid, array_agg(dep_recurse.type_to_char(foo.t)) sig
	FROM (
		SELECT pg_proc.oid, unnest(pg_proc.proargtypes) t
		FROM pg_proc
		JOIN pg_namespace ON pg_namespace.oid = pg_proc.pronamespace
		WHERE nspname = $1 AND proname = $2
	) foo
	JOIN pg_type ON foo.t = pg_type.oid
	GROUP BY foo.oid
) bar
WHERE bar.sig = $3;
$$ LANGUAGE sql STABLE;


CREATE FUNCTION dep_recurse.function_signature(oid)
    RETURNS text[]
AS $$
SELECT array_agg(dep_recurse.type_to_char(type_oid))
FROM (
    SELECT unnest(proargtypes) type_oid
    FROM pg_proc WHERE oid = $1
) t
$$ LANGUAGE sql STABLE;


CREATE FUNCTION dep_recurse.function_signature_str(oid)
    RETURNS text
AS $$
SELECT array_to_string(array_agg(dep_recurse.type_to_char(type_oid)), ', ')
FROM (
    SELECT unnest(proargtypes) type_oid
    FROM pg_proc WHERE oid = $1
) t;
$$ LANGUAGE sql STABLE;


CREATE FUNCTION dep_recurse.function_to_char(oid)
    RETURNS text
AS $$
SELECT
    format(
        '%I.%I(%s)',
        nspname,
        proname,
        dep_recurse.function_signature_str($1)
    )
FROM pg_proc
JOIN pg_namespace ON pronamespace = pg_namespace.oid
WHERE pg_proc.oid = $1;
$$ LANGUAGE sql STABLE;


CREATE FUNCTION dep_recurse.to_char(dep_recurse.obj_ref)
    RETURNS text
AS $$
SELECT CASE $1.obj_type
WHEN 'table' THEN dep_recurse.table_to_char($1.obj_id)
WHEN 'view' THEN dep_recurse.view_to_char($1.obj_id)
WHEN 'materialized view' THEN dep_recurse.view_to_char($1.obj_id)
WHEN 'function' THEN dep_recurse.function_to_char($1.obj_id)
END;
$$ LANGUAGE sql STABLE;

CREATE CAST (dep_recurse.obj_ref AS text)
WITH FUNCTION dep_recurse.to_char(dep_recurse.obj_ref);


CREATE FUNCTION dep_recurse.to_char(dep_recurse.dependent)
    RETURNS text
AS $$
SELECT $1.obj::text;
$$ LANGUAGE sql STABLE;

CREATE CAST (dep_recurse.dependent AS text)
WITH FUNCTION dep_recurse.to_char(dep_recurse.dependent);


CREATE FUNCTION dep_recurse.to_char(dep_recurse.dependency)
    RETURNS text
AS $$
SELECT $1.obj::text;
$$ LANGUAGE sql STABLE;

CREATE CAST (dep_recurse.dependency AS text)
WITH FUNCTION dep_recurse.to_char(dep_recurse.dependency);
