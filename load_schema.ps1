$env:PGPASSWORD='djouko'
psql -h 127.0.0.1 -U postgres -d prod_fiatope_development -f db/structure.sql
