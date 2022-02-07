CREATE TABLE lastused (
    id      serial primary key,
    report  varchar(40),
    cols    text,
    login   varchar(255)
);

CREATE TABLE chat (
	id SERIAL PRIMARY KEY,
	trans_id INT NOT NULL,
	message VARCHAR(255) NOT NULL,
	employee_id INT NOT NULL,
	creation_date TIMESTAMP NOT NULL
);

UPDATE defaults SET fldvalue = '2.8.21' where fldname = 'version';

