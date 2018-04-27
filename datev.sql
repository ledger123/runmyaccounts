create table debits (id serial, reference text, description text, transdate date, accno text, amount numeric(12,2));
create table credits (id serial, reference text, description text, transdate date, accno text, amount numeric(12,2));
create table debitscredits (id serial, reference text, description text, transdate date, debit_accno text, credit_accno text, amount numeric(12,2));

-- ALTER TABLE acc_trans ADD tax_chart_id integer DEFAULT 0;
ALTER TABLE tax ADD datev_flag CHAR(1);

ALTER TABLE acc_trans ADD amount2 float default 0;

CREATE TABLE acc_trans2 AS SELECT * FROM acc_trans WHERE 1 = 2;

ALTER TABLE debits ADD tax_chart_id INTEGER;
ALTER TABLE credits ADD tax_chart_id INTEGER;
ALTER TABLE debitscredits ADD tax_chart_id INTEGER;

ALTER TABLE debits ADD taxamount float;
ALTER TABLE credits ADD taxamount float;
ALTER TABLE debitscredits ADD taxamount float;

