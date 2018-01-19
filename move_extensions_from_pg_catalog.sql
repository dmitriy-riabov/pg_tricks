CREATE FUNCTION move_extensions_from_pg_catalog (
    new_schema text = 'public'
)
RETURNS SETOF text AS
$body$
DECLARE
    r record;
BEGIN
    FOR r IN SELECT
                e.extname, c.relname,
                format('update %I set %snamespace = %L::regnamespace::oid where oid = %L;', 
                    c.relname, 
                    CASE c.relname WHEN 'pg_class' THEN 'rel' WHEN 'pg_operator' THEN 'opr' ELSE substr(c.relname, 4, 3) END,
                    new_schema,
                    d.objid
                ) query
            FROM pg_depend d
            JOIN pg_extension e ON e.oid = d.refobjid AND e.extrelocatable AND e.extnamespace = 'pg_catalog'::regnamespace::oid
            JOIN pg_class c ON c.oid = d.classid AND c.relname <> 'pg_cast'
            WHERE d.deptype = 'e'
            UNION ALL
            SELECT
                extname, null,
                format('update %I set extnamespace = %L::regnamespace::oid where oid = %L;', 
                    tableoid::regclass, 
                    new_schema,
                    oid
                )
            FROM pg_extension WHERE extrelocatable AND extnamespace = 'pg_catalog'::regnamespace::oid
            ORDER BY extname, relname LOOP
            
        EXECUTE r.query;
        RETURN NEXT r.query;
    END LOOP;
    RETURN;
END;
$body$
LANGUAGE plpgsql
VOLATILE;
