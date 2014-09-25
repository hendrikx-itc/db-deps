CREATE TABLE leaf1 (
    id integer,
    name varchar,
    x integer
);

COMMENT ON COLUMN leaf1.x IS 'Some random number named ''x''';

CREATE VIEW intermediate1 AS
SELECT
    id,
    x + 1 AS "x'"
FROM leaf1;

COMMENT ON COLUMN intermediate1.id IS 'The identifier';
COMMENT ON COLUMN intermediate1."x'" IS 'Number derived from x';
COMMENT ON VIEW intermediate1 IS 'Some test intermediate view with ''quotes'' on leaf1';

CREATE FUNCTION on_intermediate1(intermediate1) RETURNS integer
AS $$
SELECT $1.id;
$$ LANGUAGE sql IMMUTABLE;

CREATE TABLE leaf2 (
    id integer,
    name varchar,
    y integer
);

COMMENT ON COLUMN leaf2.y IS 'Some random number named ''y''';

CREATE VIEW intermediate2 AS
SELECT
    id,
    y + 2 AS "y'"
FROM leaf2;

COMMENT ON COLUMN intermediate2.id IS 'The identifier';
COMMENT ON COLUMN intermediate2."y'" IS 'Number derived from y';
COMMENT ON VIEW intermediate2 IS 'Some test intermediate view with ''quotes'' on leaf2';

CREATE VIEW trunk AS 
SELECT
    intermediate1.id,
    "x'" + "y'" AS z
FROM intermediate1 JOIN intermediate2 ON intermediate1.id = intermediate2.id;
