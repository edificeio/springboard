CREATE USER "apps" WITH PASSWORD 'We_1234';
GRANT TEMPORARY ON DATABASE ong TO "apps";
GRANT USAGE ON SCHEMA information_schema TO "apps";
GRANT SELECT ON information_schema.tables TO "apps";
