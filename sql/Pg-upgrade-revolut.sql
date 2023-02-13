CREATE TABLE revolut_accounts (
    id text primary key, curr varchar(3),
    name text, balance numeric(12,2) default 0
);

ALTER TABLE gl ADD transjson json;

