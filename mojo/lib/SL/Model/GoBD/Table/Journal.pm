########################################
package SL::Model::GoBD::Table::Journal;
########################################
use base qw(SL::Model::GoBD::Table::AbstractTable);
use strict;
use warnings;
use feature ':5.10';


sub init {
    my $self = shift;

    $self->{name}        = 'Journal';
    $self->{filename}    = 'journal.csv';
    $self->{description} = 'Journal';

    $self->{columns} = [
        
        { name => "Buchungsnummer",    type => "numeric(0)" },
        { name => "Buchungstyp",       type => "alpha" },

        { name => "Buchungreferenz",   type => "alpha" },
        { name => "Buchungstext",      type => "alpha" },

        { name => "Buchungsdatum",     type => "date" },
        
        { name => "Betrag_Soll",       type => "numeric(2)" },
        { name => "Betrag_Haben",      type => "numeric(2)" },

        { name => "Kontonummer",       type => "numeric(0)" },

        { name => "Debitor-/Kreditornummer",    type => "numeric(0)" },
        { name => "Debitor-/Kreditorname",      type => "alpha" },

    ];


    $self->{sql} = sprintf(qq|
SELECT * FROM (
SELECT
ac.trans_id,            -- Buchungsnummer
'Debitor',              -- Buchungstyp
ar.invnumber reference, -- Buchungreferenz
c.description,          -- Buchungstext
ac.transdate,           -- Buchungsdatum
%s,
%s,
c.accno,                -- Kontonummer
ar.customer_id,         -- Debitor-/Kreditornummer
vc.name                 -- Debitor-/Kreditorname
FROM acc_trans ac
JOIN chart c ON c.id = ac.chart_id
JOIN ar ON ac.trans_id = ar.id
JOIN customer vc ON vc.id = ar.customer_id

UNION ALL

SELECT
ac.trans_id,
'Kreditor',
ap.invnumber reference,
c.description,
ac.transdate,
%s,
%s,
c.accno,
ap.vendor_id,
vc.name
FROM acc_trans ac
JOIN chart c ON c.id = ac.chart_id
JOIN ap ON ac.trans_id = ap.id
JOIN vendor vc ON vc.id = ap.vendor_id

UNION ALL

SELECT
ac.trans_id,
'Hauptbuch',
gl.reference,
c.description,
ac.transdate,
%s,
%s,
c.accno,
-1,
'n.a.'
FROM acc_trans ac
JOIN chart c ON c.id = ac.chart_id
JOIN gl ON ac.trans_id = gl.id

) dummy_alias
WHERE transdate BETWEEN ? AND ?
ORDER BY transdate
|,
                           $self->_sql_debit_column('ac.amount'),
                           $self->_sql_credit_column('ac.amount'),
                           $self->_sql_debit_column('ac.amount'),
                           $self->_sql_credit_column('ac.amount'),
                           $self->_sql_debit_column('ac.amount'),
                           $self->_sql_credit_column('ac.amount'),
                       );


    $self->{placeholders} = [ $self->{from}, $self->{to} ];
}



1;
