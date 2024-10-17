ALTER TABLE acc_trans ADD determinant SERIAL;
ALTER TABLE acc_trans ADD PRIMARY KEY (determinant);

UPDATE defaults SET fldvalue = '2.8.41' where fldname = 'version';
