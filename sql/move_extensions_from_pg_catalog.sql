CREATE FUNCTION move_extensions_from_pg_catalog (
    new_schema regnamespace = 'public',
    variadic extensions name [] = NULL
)
RETURNS SETOF text AS
$body$
DECLARE
    r record;
BEGIN
    FOR r IN WITH RECURSIVE e AS (
                SELECT
                    oid, 
                    format('update %I set extnamespace = %L::regnamespace where oid = %L;', 
                        tableoid::regclass, 
                        new_schema,
                        oid
                    ) query
                FROM pg_extension WHERE extrelocatable AND (extname = ANY(extensions) OR extensions IS NULL) AND extnamespace = 'pg_catalog'::regnamespace
                UNION ALL
                SELECT
                    d.objid,
                    format('update %I set %I = %L::regnamespace where oid = %L;', 
                        d.classid::regclass, 
                        a.attname,
                        new_schema,
                        d.objid
                    )
                FROM pg_depend d
                JOIN e ON e.oid = d.refobjid
                JOIN pg_attribute a ON a.attrelid = d.classid AND a.attname LIKE '%namespace'
                WHERE d.deptype IN ('e', 'i')
            ) 
            TABLE e ORDER BY oid DESC LOOP
            
        EXECUTE r.query;
        RETURN NEXT r.query;
    END LOOP;
    RETURN;
END;
$body$
LANGUAGE plpgsql
VOLATILE;
