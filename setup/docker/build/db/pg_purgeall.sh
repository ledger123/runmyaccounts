#!/bin/bash

for DB in $( cat <<EOF | psql -At -U postgres
SELECT datname
FROM pg_database
WHERE NOT datistemplate AND datname <> 'postgres'
EOF
	   ); do
    dropdb -e -U postgres $DB
done


for R in $( cat <<EOF | psql -At -U postgres
SELECT rolname
FROM pg_roles
WHERE rolcanlogin AND rolname <> 'postgres'
EOF
	   ); do
    dropuser -e -U postgres $R
done
