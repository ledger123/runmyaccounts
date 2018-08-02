######################################
package SL::Model::GoBD::Table::Firma;
######################################
use base qw(SL::Model::GoBD::Table::AbstractTable);
use strict;
use warnings;
use feature ':5.10';
use DBIx::Simple;


sub init {
    my $self = shift;

    $self->{name}        = 'Firma';
    $self->{filename}    = 'firma.csv';
    $self->{description} = 'Firmenstammblatt';

    $self->{columns} = [
        { name => "Name",    type => "alpha" },
        { name => "Strasse", type => "alpha" },
        { name => "PLZ",     type => "alpha" },
        { name => "Ort",     type => "alpha" },
    ];

    $self->{sql} = qq|
SELECT * FROM
(
  SELECT fldvalue FROM defaults WHERE fldname = 'company'
  UNION ALL
  SELECT NULL
  LIMIT 1
) AS company,
(
  SELECT fldvalue FROM defaults WHERE fldname = 'address1'
  UNION ALL
  SELECT NULL
  LIMIT 1
) AS address,
(
  SELECT fldvalue FROM defaults WHERE fldname = 'zip'
  UNION ALL
  SELECT NULL
  LIMIT 1
) AS zip,
(
  SELECT fldvalue FROM defaults WHERE fldname = 'city'
  UNION ALL
  SELECT NULL
  LIMIT 1
) AS city
|;
}



1;
