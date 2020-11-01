#############################################
package SL::Model::GoBD::Table::SummenSalden;
#############################################
use base qw(SL::Model::GoBD::Table::AbstractTable);
use strict;
use warnings;
use feature ':5.10';


sub init {
    my $self = shift;

    $self->{name}        = 'SummenSalden';
    $self->{filename}    = 'summen_salden.csv';
    $self->{description} = 'Summen- und Saldenliste';

    $self->{columns} = [
        { name => "Kontonummer",       type => "numeric(0)" },
        { name => "Kontobeschreibung", type => "alpha" },
        { name => "EB_Soll",           type => "numeric(2)" },
        { name => "EB_Haben",          type => "numeric(2)" },
        { name => "Periode_Soll",      type => "numeric(2)" },
        { name => "Periode_Haben",     type => "numeric(2)" },
        { name => "SB_Soll",           type => "numeric(2)" },
        { name => "SB_Haben",          type => "numeric(2)" },
    ];

    $self->{sql} = sprintf(qq|
WITH result(no, descr, eb, soll, haben) AS
(
SELECT
c.accno,
c.description,
COALESCE (
(
    SELECT SUM(ac.amount)
    FROM acc_trans ac
    JOIN chart c2 ON (ac.chart_id = c2.id)
    WHERE transdate < ?
    AND c2.accno = c.accno
), 0),
COALESCE (
(
    SELECT SUM(ac.amount)
    FROM acc_trans ac
    JOIN chart c2 ON (ac.chart_id = c2.id)
    WHERE transdate BETWEEN ? AND ?
    AND c2.accno = c.accno
    AND ac.amount < 0
), 0),
COALESCE (
(
    SELECT SUM(ac.amount)
    FROM acc_trans ac
    JOIN chart c2 ON (ac.chart_id = c2.id)
    WHERE transdate BETWEEN ? AND ?
    AND c2.accno = c.accno
    AND ac.amount > 0
), 0)

FROM acc_trans ac
RIGHT OUTER JOIN chart c ON (ac.chart_id = c.id)

WHERE transdate BETWEEN ? AND ?
)
SELECT DISTINCT
no,
descr,
%s,
%s,
%s,
%s,
%s,
%s
FROM result
ORDER BY no
|,
                           $self->_sql_debit_column('eb'),
                           $self->_sql_credit_column('eb'),
                           $self->_sql_debit_column('soll'),
                           $self->_sql_credit_column('haben'),
                           $self->_sql_debit_column('eb + soll + haben'),
                           $self->_sql_credit_column('eb + soll + haben'),
  
                           );

   $self->{placeholders} = [
       $self->{from},
       $self->{from},
       $self->{to},
       $self->{from},
       $self->{to},
       $self->{from},
       $self->{to},
   ];
}



1;
