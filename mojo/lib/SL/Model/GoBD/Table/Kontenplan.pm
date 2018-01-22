###########################################
package SL::Model::GoBD::Table::Kontenplan;
###########################################
use base qw(SL::Model::GoBD::Table::AbstractTable);
use strict;
use warnings;
use feature ':5.10';


sub init {
    my $self = shift;

    $self->{name}        = 'Kontenplan';
    $self->{filename}    = 'kontenplan.csv';
    $self->{description} = 'Kontenplan';

    $self->{columns} = [
        { name => "Kontonummer",       type => "numeric(0)" },
        { name => "Kontenbezeichnung", type => "alpha" },
        { name => "Kontenkategorie",   type => "alpha" },
    ];

    $self->{sql} = qq|
SELECT accno, description,
CASE category
WHEN 'A' THEN 'Aktiva'
WHEN 'L' THEN 'Passiva/Mittelherkunft'
WHEN 'Q' THEN 'Passiva/Eigenkapital'
WHEN 'I' THEN 'Ertrag'
WHEN 'E' THEN 'Aufwand'
ELSE 'Weissnich'
END
FROM chart
WHERE charttype = 'A'
ORDER BY accno
|;
}



1;
