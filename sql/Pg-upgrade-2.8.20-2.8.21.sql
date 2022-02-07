CREATE TABLE lastused (
    id      serial primary key,
    report  varchar(40),
    cols    text,
    login   varchar(40)
);
UPDATE defaults SET fldvalue = '2.8.21' where fldname = 'version';

