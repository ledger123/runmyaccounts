#=====================================================================
# Sample Graphs for SQL-Ledger ERP
# Copyright (c) 2008
#
#  Author: Armaghan Saqib
#     Web: http://www.ledger123.com
#   Email: support@ledger123.com
#
#  Version: 0.10
#
#======================================================================

use GD::Graph::bars;
use GD::Graph::lines;
use GD::Graph::pie;

1;

sub continue { &{$form->{nextsub}} };

###########################################################################
##
##  These two procedures 'sales_search' and 'sales_graph' impliment
##  a very simple graph.
##
##  Copy these procedures and rename appropriatly to create as many
##  graphs as you like within this single .pl file.
##
###########################################################################
#---------------------------------------
sub sales_search {
  $form->{title} = $locale->text('Sales Graph');
  $form->header;
  print qq|
<body>
<form method=post action=$form->{script}>
<table width=100%>
  <tr><th class=listtop>$form->{title}</th></tr>
  <tr height="5"></tr>
  <tr><td><table>
     <tr>
	<th align=right>|.$locale->text('Name').qq|</th>
	<td><input name=name size=30></td>
     </tr>
     <tr>
	<th align=right>|.$locale->text('From').qq|</th>
	<td><input name=datefrom size=11 title='$myconfig{dateformat}'></td>
     </tr>
     <tr>
	<th align=right>|.$locale->text('To').qq|</th>
	<td><input name=dateto size=11 title='$myconfig{dateformat}'></td>
     </tr>
  </table></td></tr>
  <tr><td><hr size=3 noshade></td></tr>
</table>
<br>
<input type=hidden name=action value=continue>
<input class=submit type=submit name=action value="|.$locale->text('Continue').qq|">|;

   $form->{nextsub} = 'sales_graph';
   $form->hide_form(qw(nextsub path login));

   print qq|
</form>|;

   print qq|
</body>
</html>|;

}

#---------------------------------------
sub sales_graph {

   # Build WHERE cluase
   my $name = $form->like(lc $form->{name}); 
   my $where = qq| (1 = 1)|;
   $where .= qq| AND LOWER(ct.name) LIKE '$name' | if $form->{name}; 
   $where .= qq| AND ar.transdate >= '$form->{datefrom}'| if $form->{datefrom};
   $where .= qq| AND ar.transdate <= '$form->{dateto}'| if $form->{dateto};

   my $query = qq|
SELECT 
  EXTRACT(MONTH FROM transdate) AS month,
  SUM(amount) AS amount
FROM ar
JOIN customer ct ON (ct.id = ar.customer_id)
WHERE $where
GROUP BY month
ORDER BY month
|;

   my $dbh = $form->dbconnect(\%myconfig);
   my $sth = $dbh->prepare($query); 
   $sth->execute || $form->dberror($query);
   @months = ();
   @sale = ();
   while ($ref = $sth->fetchrow_hashref(NAME_lc)){
	push @months, $ref->{month};
	push @sale, $ref->{amount};
   }
   my @data = (\@months, \@sale);
   my $graph = GD::Graph::bars->new(600, 400);
  # my $graph = GD::Graph::lines->new(600, 400);

   # adjust the parameters below to suite your graphing needs.
   $graph->set(
      x_label     => 'Monat',
      y_label     => 'Debitoren in CHF',
      title       => 'Debitoren pro Monat',
      bar_width   => 20,
      bar_spacing => 3,
      long_ticks  => 1, # grid
      show_values => 1  # values on top of bars
   ) or warn $graph->error;
   my $graphimage = $graph->plot(\@data) or die $graph->error;

   print "Content-type: image/png\n\n";
   print $graphimage->png;
}

################
# EOF: graphs.pl
################

