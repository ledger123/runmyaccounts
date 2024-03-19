ALTER TABLE tax ADD id SERIAL;
ALTER TABLE tax ADD PRIMARY KEY (id);

UPDATE defaults SET fldvalue = '2.8.29' where fldname = 'version';
