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
                format('update %I set %I = %L::regnamespace where oid = %L;', 
                    c.relname, 
                    a.attname,
                    new_schema,
                    d.objid
                ) query,
                CASE c.relname WHEN 'pg_class' THEN 
                    format('update pg_type u set typnamespace = %L::regnamespace from pg_type t where t.typrelid = %L and u.oid in (t.oid, t.typarray);', 
                        new_schema,
                        d.objid
                    )
                END type_query
            FROM pg_depend d
            JOIN pg_extension e ON e.oid = d.refobjid AND e.extrelocatable AND e.extnamespace = 'pg_catalog'::regnamespace
            JOIN pg_class c ON c.oid = d.classid
            JOIN pg_attribute a ON a.attrelid = c.oid AND a.attname like '%namespace'
            WHERE d.deptype = 'e'
            UNION ALL
            SELECT
                extname, null,
                format('update %I set extnamespace = %L::regnamespace where oid = %L;', 
                    tableoid::regclass, 
                    new_schema,
                    oid
                ), null
            FROM pg_extension WHERE extrelocatable AND extnamespace = 'pg_catalog'::regnamespace
            ORDER BY extname, relname LOOP
            
        EXECUTE r.query;
        RETURN NEXT r.query;
        if r.type_query notnull then
            EXECUTE r.type_query;
            RETURN NEXT r.type_query;
        end if;
    END LOOP;
    RETURN;
END;
$body$
LANGUAGE plpgsql
VOLATILE;
