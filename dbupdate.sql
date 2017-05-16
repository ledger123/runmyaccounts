DROP TABLE audittrail_detail;

CREATE TABLE audittrail_detail (
    id serial,
    trans_id    integer,
    action      text,
    cname       text,
    cval        text,
    cname2      text,
    cval2       text,
    employee_id integer,
    created     timestamp default now()
);


