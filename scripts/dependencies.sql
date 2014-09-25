create table deps_saved_ddl
(
  deps_id serial primary key,
  deps_view_schema varchar(255),
  deps_view_name varchar(255),
  deps_ddl_to_run text
);


CREATE OR REPLACE FUNCTION grant_statements(obj_schema name, obj_name name)
    RETURNS SETOF varchar
AS $$
SELECT
    format('GRANT %s ON %I.%I TO %s;', privilege_type, table_schema, table_name, grantee)
FROM information_schema.role_table_grants
WHERE table_schema = $1 and table_name = $2;
$$ LANGUAGE sql STABLE;


CREATE OR REPLACE FUNCTION create_view_statement(obj_schema name, obj_name name)
    RETURNS varchar
AS $$
SELECT
    format('CREATE VIEW %I.%I AS %s', $1, $2, view_definition)
FROM information_schema.views
WHERE table_schema = $1 AND table_name = $2;
$$ LANGUAGE sql STABLE;


CREATE OR REPLACE FUNCTION create_materialized_view_statement(obj_schema name, obj_name name)
    RETURNS varchar
AS $$
SELECT
    format('CREATE MATERIALIZED VIEW %I.%I AS %s', $1, $2, definition)
FROM pg_matviews
WHERE schemaname = $1 AND matviewname = $2; 
$$ LANGUAGE sql STABLE;


CREATE OR REPLACE FUNCTION comment_view_statement(obj_schema name, obj_name name)
    RETURNS varchar
AS $$
SELECT
    format('COMMENT ON VIEW %I.%I IS %L;', n.nspname, c.relname, d.description)
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
JOIN pg_description d ON d.objoid = c.oid AND d.objsubid = 0
WHERE n.nspname = $1 AND c.relname = $2 AND d.description IS NOT null;
$$ LANGUAGE sql STABLE;


CREATE OR REPLACE FUNCTION comment_column_statements(obj_schema name, obj_name name)
    RETURNS SETOF varchar
AS $$
SELECT
    format('COMMENT ON COLUMN %I.%I.%I IS %L;', n.nspname, c.relname, a.attname, d.description)
FROM pg_class c
JOIN pg_attribute a ON c.oid = a.attrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
JOIN pg_description d ON d.objoid = c.oid and d.objsubid = a.attnum
WHERE n.nspname = $1 AND c.relname = $2 AND d.description is NOT null;
$$ LANGUAGE sql STABLE;


CREATE TYPE dep AS (
    schema_name name,
    obj_name name,
    obj_type varchar,
    distance integer
);


CREATE OR REPLACE FUNCTION deps(obj_schema name, obj_name name)
    RETURNS SETOF dep
AS $$
    SELECT obj_schema, obj_name, obj_type, max(distance) FROM
    (
        WITH recursive recursive_deps(obj_schema, obj_name, obj_type, distance) AS
        (
            SELECT
                $1,
                $2,
                null::varchar,
                0
            UNION
            SELECT
                dep_schema,
                dep_name,
                dep_type::varchar,
                recursive_deps.distance + 1
            FROM
            (
                SELECT
                    ref_nsp.nspname ref_schema,
                    ref_cl.relname ref_name,
                    rwr_cl.relkind dep_type,
                    rwr_nsp.nspname dep_schema,
                    rwr_cl.relname dep_name
                FROM pg_depend dep
                JOIN pg_class ref_cl ON dep.refobjid = ref_cl.oid
                JOIN pg_namespace ref_nsp ON ref_cl.relnamespace = ref_nsp.oid
                JOIN pg_rewrite rwr ON dep.objid = rwr.oid
                JOIN pg_class rwr_cl ON rwr.ev_class = rwr_cl.oid
                JOIN pg_namespace rwr_nsp ON rwr_cl.relnamespace = rwr_nsp.oid
                WHERE dep.deptype = 'n'
                AND dep.classid = 'pg_rewrite'::regclass
            ) deps
            JOIN recursive_deps ON deps.ref_schema = recursive_deps.obj_schema AND deps.ref_name = recursive_deps.obj_name
            WHERE (deps.ref_schema != deps.dep_schema OR deps.ref_name != deps.dep_name)
        )
        SELECT obj_schema, obj_name, obj_type, distance
        FROM recursive_deps
        WHERE distance > 0
    ) t
    GROUP BY obj_schema, obj_name, obj_type
    ORDER BY max(distance) ASC
$$ LANGUAGE sql STABLE;


CREATE OR REPLACE FUNCTION view_creation_statements(obj_schema name, obj_name name)
    RETURNS SETOF varchar
AS $$
SELECT create_view_statement($1, $2)
UNION ALL
SELECT comment_view_statement($1, $2)
UNION ALL
SELECT comment_column_statements($1, $2)
UNION ALL
SELECT grant_statements($1, $2);
$$ LANGUAGE sql STABLE;


CREATE OR REPLACE FUNCTION depender_creation_statements(obj_schema name, obj_name name)
    RETURNS SETOF varchar
AS $$
SELECT view_creation_statements(schema_name, obj_name) FROM deps($1, $2);
$$ LANGUAGE sql STABLE;

create or replace function deps_save_and_drop_dependencies(p_view_schema varchar, p_view_name varchar) returns void as
$$
declare
  v_curr record;
begin
for v_curr in
(
  select obj_schema, obj_name, obj_type from
  (
  with recursive recursive_deps(obj_schema, obj_name, obj_type, depth) as
  (
    select p_view_schema, p_view_name, null::varchar, 0
    union
    select dep_schema::varchar, dep_name::varchar, dep_type::varchar, recursive_deps.depth + 1 from
    (
      select ref_nsp.nspname ref_schema, ref_cl.relname ref_name,
      rwr_cl.relkind dep_type,
      rwr_nsp.nspname dep_schema,
      rwr_cl.relname dep_name
      from pg_depend dep
      join pg_class ref_cl on dep.refobjid = ref_cl.oid
      join pg_namespace ref_nsp on ref_cl.relnamespace = ref_nsp.oid
      join pg_rewrite rwr on dep.objid = rwr.oid
      join pg_class rwr_cl on rwr.ev_class = rwr_cl.oid
      join pg_namespace rwr_nsp on rwr_cl.relnamespace = rwr_nsp.oid
      where dep.deptype = 'n'
      and dep.classid = 'pg_rewrite'::regclass
    ) deps
    join recursive_deps on deps.ref_schema = recursive_deps.obj_schema and deps.ref_name = recursive_deps.obj_name
    where (deps.ref_schema != deps.dep_schema or deps.ref_name != deps.dep_name)
  )
  select obj_schema, obj_name, obj_type, depth
  from recursive_deps
  where depth > 0
  ) t
  group by obj_schema, obj_name, obj_type
  order by max(depth) desc
) loop

  insert into deps_saved_ddl(deps_view_schema, deps_view_name, deps_ddl_to_run)
  select p_view_schema, p_view_name, 'COMMENT ON ' ||
  case
  when c.relkind = 'v' then 'VIEW'
  when c.relkind = 'm' then 'MATERIALIZED VIEW'
  else ''
  end
  || ' ' || n.nspname || '.' || c.relname || ' IS ''' || replace(d.description, '''', '''''') || ''';'
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  join pg_description d on d.objoid = c.oid and d.objsubid = 0
  where n.nspname = v_curr.obj_schema and c.relname = v_curr.obj_name and d.description is not null;

  insert into deps_saved_ddl(deps_view_schema, deps_view_name, deps_ddl_to_run)
  select p_view_schema, p_view_name, 'COMMENT ON COLUMN ' || n.nspname || '.' || c.relname || '.' || a.attname || ' IS ''' || replace(d.description, '''', '''''') || ''';'
  from pg_class c
  join pg_attribute a on c.oid = a.attrelid
  join pg_namespace n on n.oid = c.relnamespace
  join pg_description d on d.objoid = c.oid and d.objsubid = a.attnum
  where n.nspname = v_curr.obj_schema and c.relname = v_curr.obj_name and d.description is not null;

  insert into deps_saved_ddl(deps_view_schema, deps_view_name, deps_ddl_to_run)
  select p_view_schema, p_view_name, 'GRANT ' || privilege_type || ' ON ' || table_schema || '.' || table_name || ' TO ' || grantee
  from information_schema.role_table_grants
  where table_schema = v_curr.obj_schema and table_name = v_curr.obj_name;

  if v_curr.obj_type = 'v' then
    insert into deps_saved_ddl(deps_view_schema, deps_view_name, deps_ddl_to_run)
    select p_view_schema, p_view_name, 'CREATE VIEW ' || v_curr.obj_schema || '.' || v_curr.obj_name || ' AS ' || view_definition
    from information_schema.views
    where table_schema = v_curr.obj_schema and table_name = v_curr.obj_name;
  elsif v_curr.obj_type = 'm' then
    insert into deps_saved_ddl(deps_view_schema, deps_view_name, deps_ddl_to_run)
    select p_view_schema, p_view_name, 'CREATE MATERIALIZED VIEW ' || v_curr.obj_schema || '.' || v_curr.obj_name || ' AS ' || definition
    from pg_matviews
    where schemaname = v_curr.obj_schema and matviewname = v_curr.obj_name;
  end if;

  execute 'DROP ' ||
  case
    when v_curr.obj_type = 'v' then 'VIEW'
    when v_curr.obj_type = 'm' then 'MATERIALIZED VIEW'
  end
  || ' ' || v_curr.obj_schema || '.' || v_curr.obj_name;

end loop;
end;
$$
LANGUAGE plpgsql;

create or replace function deps_restore_dependencies(p_view_schema varchar, p_view_name varchar) returns void as
$$
declare
  v_curr record;
begin
for v_curr in
(
  select deps_ddl_to_run
  from deps_saved_ddl
  where deps_view_schema = p_view_schema and deps_view_name = p_view_name
  order by deps_id desc
) loop
  execute v_curr.deps_ddl_to_run;
end loop;
delete from deps_saved_ddl
where deps_view_schema = p_view_schema and deps_view_name = p_view_name;
end;
$$
LANGUAGE plpgsql;
