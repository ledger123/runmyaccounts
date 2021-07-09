drop index if exists acc_trans_chart_id_transdate_approved_trans_id;
create index acc_trans_chart_id_transdate_approved_trans_id on acc_trans (chart_id, transdate, approved, trans_id, amount);

UPDATE defaults SET fldvalue = '2.8.20' where fldname = 'version';

