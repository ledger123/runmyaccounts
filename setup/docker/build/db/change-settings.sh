sed -ri 's/host.*all.*all.*all.*/host all all all trust/' \
    /var/lib/postgresql/data/pg_hba.conf
