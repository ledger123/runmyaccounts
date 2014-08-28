#=================================================================
# SQL-Ledger ERP
# Copyright (C) 2006
#
#  Author: DWS Systems Inc.
#     Web: http://www.sql-ledger.com
#
#======================================================================

package CSV;


sub escape_csv {
  my ($self, $str) = @_;

  $str =~ s/\"/\"\"/g;
  return $str;
}

1;