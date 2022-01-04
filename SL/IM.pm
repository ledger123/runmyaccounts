#=====================================================================
# SQL-Ledger ERP
# Copyright (c) 2007
#
#  Author: DWS Systems Inc.
#     Web: http://www.sql-ledger.com
#
#======================================================================
#
# Import/Export module
#
#======================================================================

package IM;


sub sales_invoice {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query;
  my $ref;
  
  my %defaults = $form->get_defaults($dbh, \@{['precision']});
  $form->{precision} = $defaults{precision};
  
  $form->{ARAP} = "AR";

  # get AR accounts
  $query = qq|SELECT accno FROM chart
              WHERE link = '$form->{ARAP}'|;
  my $sth = $dbh->prepare($query) || $form->dberror($query);

  my %ARAP = ();
  my $default_arap_accno;
  
  $sth->execute || $form->dberror($query);
  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    $ARAP{"$ref->{accno}"} = 1;
    $default_arap_accno ||= $ref->{accno};
  }

  if (! %ARAP) {
    $dbh->disconnect;
    return -1;
  }
  
  # customer
  $query = qq|SELECT cv.id, cv.name, cv.customernumber, cv.terms,
              e.id AS employee_id, e.name AS employee,
	      c.accno AS taxaccount, a.accno AS arap_accno,
	      ad.city
	      FROM customer cv
	      JOIN address ad ON (ad.trans_id = cv.id)
	      LEFT JOIN employee e ON (e.id = cv.employee_id)
	      LEFT JOIN customertax ct ON (cv.id = ct.customer_id)
	      LEFT JOIN chart c ON (c.id = ct.chart_id)
	      LEFT JOIN chart a ON (a.id = cv.arap_accno_id)
	      WHERE customernumber = ?|;
  my $cth = $dbh->prepare($query) || $form->dberror($query);

  $query = qq|SELECT id, name FROM employee WHERE employeenumber = ?|;
  my $eth = $dbh->prepare($query) || $form->dberror($query);

  # parts
  $query = qq|SELECT p.id, p.unit, p.description, p.notes AS itemnotes,
              c.accno
              FROM parts p
              LEFT JOIN partstax pt ON (p.id = pt.parts_id)
	      LEFT JOIN chart c ON (c.id = pt.chart_id)
              WHERE partnumber = ?|;
  my $pth = $dbh->prepare($query) || $form->dberror($query);
  
  # department
  $query = qq|SELECT id
              FROM department
              WHERE description = ?|;
  my $dth = $dbh->prepare($query) || $form->dberror($query);

  # warehouse
  $query = qq|SELECT id
              FROM warehouse
              WHERE description = ?|;
  my $wth = $dbh->prepare($query) || $form->dberror($query);
  
  # project
  $query = qq|SELECT id
              FROM project
              WHERE projectnumber = ?|;
  my $ptth = $dbh->prepare($query) || $form->dberror($query);

  my $arap_accno;
  my $terms;
  my $i = 0;
  my $j = 0;
  my %tax;
  my %customertax;
  my $customernumber;
  my $invnumber;
  my %partstax;
  my $parts_id;

  my @d = split /\n/, $form->{data};
  shift @d if ! $form->{mapfile};

  for (@d) {

    @a = &ndxline($form);

    if (@a) {
      $i++;
      for (keys %{$form->{$form->{type}}}) {
	$a[$form->{$form->{type}}->{$_}{ndx}] =~ s/(^"|"$)//g;
	$form->{"${_}_$i"} = $a[$form->{$form->{type}}->{$_}{ndx}];
      }

      if ($customernumber ne $a[$form->{$form->{type}}->{customernumber}{ndx}] || $invnumber ne $a[$form->{$form->{type}}->{invnumber}{ndx}]) {
	
	$j = $i;
	$form->{ndx} .= "$i ";

	%customertax = ();
	
	$cth->execute("$a[$form->{$form->{type}}->{customernumber}{ndx}]");

        $arap_accno = "";
	$terms = 0;
	
	while ($ref = $cth->fetchrow_hashref(NAME_lc)) {
	  $customernumber = $ref->{customernumber};
	  $arap_accno = $ref->{arap_accno};
	  $terms = $ref->{terms};
	  $form->{"customer_id_$i"} = $ref->{id};
	  $form->{"customer_$i"} = $ref->{name};
	  $form->{"city_$i"} = $ref->{city};
	  $form->{"employee_$i"} = $ref->{employee};
	  $form->{"employee_id_$i"} = $ref->{employee_id};
	  $form->{"curr_$i"} = $form->{currency} if !$form->{"curr_$i"};
	  $customertax{$ref->{accno}} = 1;
	}
	$cth->finish;

        if ($a[$form->{$form->{type}}->{employeenumber}{ndx}]){
	  $eth->execute("$a[$form->{$form->{type}}->{employeenumber}{ndx}]");
	  while ($ref = $eth->fetchrow_hashref(NAME_lc)){
	    $form->{"employee_$i"} = $ref->{name};
	    $form->{"employee_id_$i"} = $ref->{id};
          }
	}

	if (! $ARAP{"$a[$form->{$form->{type}}->{$form->{ARAP}}{ndx}]"}) {
	  $arap_accno ||= $default_arap_accno;
	  $form->{"$form->{ARAP}_$i"} ||= $arap_accno;
	}

        $form->{"transdate_$i"} ||= $form->current_date($myconfig);
	
	# terms and duedate
	if ($form->{"duedate_$i"}) {
	    $form->{"terms_$i"} = $form->datediff($myconfig, $form->{"transdate_$i"}, $form->{"duedate_$i"});
	} else {
	  $form->{"terms_$i"} = $terms if $form->{"terms_$i"} !~ /\d/;
	  $form->{"duedate_$i"} ||= $form->{"transdate_$i"};
	  if ($form->{"terms_$i"} > 0) {
	    $form->{"duedate_$i"} = $form->add_date($myconfig, $form->{"transdate_$i"}, $form->{"terms_$i"}, 'days');
	  }
	}
	  
	$dth->execute("$a[$form->{$form->{type}}->{department}{ndx}]");
	($form->{"department_id_$i"}) = $dth->fetchrow_array;
	$dth->finish;
	
	$wth->execute("$a[$form->{$form->{type}}->{warehouse}{ndx}]");
	($form->{"warehouse_id_$i"}) = $wth->fetchrow_array;
	$wth->finish;

      }
      
      $form->{transdate} = $form->{"transdate_$i"};
      %tax = &taxrates("", $myconfig, $form, $dbh);

      $pth->execute("$a[$form->{$form->{type}}->{partnumber}{ndx}]");

      $parts_id = 0;
      while ($ref = $pth->fetchrow_hashref(NAME_lc)) {
	$form->{"parts_id_$i"} = $ref->{id};
	for (qw(description unit)) { $form->{"${_}_$i"} ||= $ref->{$_} }
	
	$form->{"itemnotes_$i"} ||= $ref->{notes};
	
	$parts_id = 1;
	if ($customertax{$ref->{accno}}) {
	  $form->{"tax_$j"} += $a[$form->{$form->{type}}->{sellprice}{ndx}] * $a[$form->{$form->{type}}->{qty}{ndx}] * $tax{$ref->{accno}};
	}
      }
      $pth->finish;
      
      $ptth->execute("$a[$form->{$form->{type}}->{projectnumber}{ndx}]");
      ($form->{"projectnumber_$i"}) = $ptth->fetchrow_array;
      $ptth->finish;

      $form->{"projectnumber_$i"} = qq|--$form->{"projectnumber_$i"}| if $form->{"projectnumber_$i"};

      if (! $parts_id) {
	$form->{"customer_id_$j"} = 0;
	$form->{missingparts} .= "$a[$form->{$form->{type}}->{invnumber}{ndx}] : $a[$form->{$form->{type}}->{partnumber}{ndx}]\n";
      }
      
      $form->{"total_$j"} += $a[$form->{$form->{type}}->{sellprice}{ndx}] * $a[$form->{$form->{type}}->{qty}{ndx}];
      $form->{"totalqty_$j"} += $a[$form->{$form->{type}}->{qty}{ndx}];
	
    }

    $invnumber = $a[$form->{$form->{type}}->{invnumber}{ndx}];
    $form->{rowcount} = $i;

  }

  $dbh->disconnect;

  chop $form->{ndx};

}


sub taxrates {
  my ($self, $myconfig, $form, $dbh) = @_;
  
  # get tax rates
  my $query = qq|SELECT c.accno, t.rate
              FROM chart c
	      JOIN tax t ON (c.id = t.chart_id)
	      WHERE c.link LIKE '%$form->{ARAP}_tax%'
	      AND (t.validto >= ? OR t.validto IS NULL)
	      ORDER BY accno, validto|;
  my $sth = $dbh->prepare($query);
  $sth->execute($form->{transdate}) || $form->dberror($query);
  
  my %tax = ();
  
  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    if (not exists $tax{$ref->{accno}}) {
      $tax{$ref->{accno}} = $ref->{rate};
    }
  }
  $sth->finish;
  
  %tax;
  
}


sub import_sales_invoice {
  my ($self, $myconfig, $form) = @_;
  
  use SL::IS;

  # connect to database, turn off AutoCommit
  my $dbh = $form->dbconnect_noauto($myconfig);

  my $query;

  $query = qq|SELECT curr
              FROM curr
	      ORDER BY rn|;
  ($form->{defaultcurrency}) = $dbh->selectrow_array($query);
  
  $form->{curr} ||= $form->{defaultcurrency};
  $form->{currency} = $form->{curr};

  if ($form->{currency} ne $form->{defaultcurrency}){
      $form->{exchangerate} *= 1;
      if (!$form->{exchangerate}){
          $form->{exchangerate} = $form->get_exchangerate($myconfig, $dbh, $form->{currency}, $form->{transdate}, 'buy');
      }
  }

  my $language_code;
  $query = qq|SELECT c.customernumber, c.language_code, a.city
              FROM customer c
	      JOIN address a ON (a.trans_id = c.id)
	      WHERE c.id = $form->{customer_id}|;
  ($form->{customernumber}, $language_code, $form->{city}) = $dbh->selectrow_array($query);

  $form->{language_code} ||= $language_code;

  $query = qq|SELECT c.accno, t.rate
              FROM customertax ct
              JOIN chart c ON (c.id = ct.chart_id)
	      JOIN tax t ON (t.chart_id = c.id)
              WHERE ct.customer_id = $form->{customer_id}
	      AND (validto > '$form->{transdate}' OR validto IS NULL)
	      ORDER BY validto DESC|;
  my $sth = $dbh->prepare($query) || $form->dberror($query);
  $sth->execute;

  $form->{taxaccounts} = "";
  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    $form->{taxaccounts} .= "$ref->{accno} ";
    $form->{"$ref->{accno}_rate"} = $ref->{rate};
  }
  $sth->finish;
  chop $form->{taxaccounts};

  # post invoice
  my $rc = IS->post_invoice($myconfig, $form, $dbh);

  $dbh->disconnect;

  $rc;

}

sub sales_order {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query;
  my $ref;
  
  my %defaults = $form->get_defaults($dbh, \@{['precision']});
  $form->{precision} = $defaults{precision};
  
  $form->{ARAP} = "AR";

  # get AR accounts
  $query = qq|SELECT accno FROM chart
              WHERE link = '$form->{ARAP}'|;
  my $sth = $dbh->prepare($query) || $form->dberror($query);

  my %ARAP = ();
  my $default_arap_accno;
  
  $sth->execute || $form->dberror($query);
  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    $ARAP{"$ref->{accno}"} = 1;
    $default_arap_accno ||= $ref->{accno};
  }

  if (! %ARAP) {
    $dbh->disconnect;
    return -1;
  }
  
  # customer
  $query = qq|SELECT cv.id, cv.name, cv.customernumber, cv.terms,
              e.id AS employee_id, e.name AS employee,
	      c.accno AS taxaccount, a.accno AS arap_accno,
	      ad.city
	      FROM customer cv
	      JOIN address ad ON (ad.trans_id = cv.id)
	      LEFT JOIN employee e ON (e.id = cv.employee_id)
	      LEFT JOIN customertax ct ON (cv.id = ct.customer_id)
	      LEFT JOIN chart c ON (c.id = ct.chart_id)
	      LEFT JOIN chart a ON (a.id = cv.arap_accno_id)
	      WHERE customernumber = ?|;
  my $cth = $dbh->prepare($query) || $form->dberror($query);
  
  # parts
  $query = qq|SELECT p.id, p.unit, p.description, p.notes AS itemnotes,
              c.accno
              FROM parts p
              LEFT JOIN partstax pt ON (p.id = pt.parts_id)
	      LEFT JOIN chart c ON (c.id = pt.chart_id)
              WHERE partnumber = ?|;
  my $pth = $dbh->prepare($query) || $form->dberror($query);
  
  # department
  $query = qq|SELECT id
              FROM department
              WHERE description = ?|;
  my $dth = $dbh->prepare($query) || $form->dberror($query);

  # warehouse
  $query = qq|SELECT id
              FROM warehouse
              WHERE description = ?|;
  my $wth = $dbh->prepare($query) || $form->dberror($query);
  
  # project
  $query = qq|SELECT id
              FROM project
              WHERE projectnumber = ?|;
  my $ptth = $dbh->prepare($query) || $form->dberror($query);

  # check if order already exists
  $query = qq|SELECT COUNT(*) FROM oe WHERE ordnumber = ?|;
  my $oesth = $dbh->prepare($query) || $form->dberror($query);

  my $arap_accno;
  my $terms;
  my $i = 0;
  my $j = 0;
  my %tax;
  my %customertax;
  my $customernumber;
  my $ordnumber;
  my %partstax;
  my $parts_id;

  my @d = split /\n/, $form->{data};
  shift @d if ! $form->{mapfile};

  for (@d) {

    @a = &ndxline($form);

    if (@a) {
      $i++;
      for (keys %{$form->{$form->{type}}}) {
	$a[$form->{$form->{type}}->{$_}{ndx}] =~ s/(^"|"$)//g;
	$form->{"${_}_$i"} = $a[$form->{$form->{type}}->{$_}{ndx}];
      }

      if ($customernumber ne $a[$form->{$form->{type}}->{customernumber}{ndx}] || $ordnumber ne $a[$form->{$form->{type}}->{ordnumber}{ndx}]) {
	
	$j = $i;
	$form->{ndx} .= "$i ";

	%customertax = ();
	
	$cth->execute("$a[$form->{$form->{type}}->{customernumber}{ndx}]");

        $arap_accno = "";
	$terms = 0;
	
	while ($ref = $cth->fetchrow_hashref(NAME_lc)) {
	  $customernumber = $ref->{customernumber};
	  $arap_accno = $ref->{arap_accno};
	  $terms = $ref->{terms};
	  $form->{"customer_id_$i"} = $ref->{id};
	  $form->{"customer_$i"} = $ref->{name};
	  $form->{"city_$i"} = $ref->{city};
	  $form->{"employee_$i"} = $ref->{employee};
	  $form->{"employee_id_$i"} = $ref->{employee_id};
	  $customertax{$ref->{accno}} = 1;
	}
	$cth->finish;

        my $ordcount = $dbh->selectrow_array("
		SELECT COUNT(*) FROM oe 
		WHERE ordnumber = '$a[$form->{$form->{type}}->{ordnumber}{ndx}]'
		AND NOT quotation AND vendor_id = 0");
        $form->{"checked_$i"} = 'checked' if $ordcount == 0;
	
	if (! $ARAP{"$a[$form->{$form->{type}}->{$form->{ARAP}}{ndx}]"}) {
	  $arap_accno ||= $default_arap_accno;
	  $form->{"$form->{ARAP}_$i"} ||= $arap_accno;
	}

        $form->{"transdate_$i"} ||= $form->current_date($myconfig);
	
	# terms and duedate
	if ($form->{"duedate_$i"}) {
	    $form->{"terms_$i"} = $form->datediff($myconfig, $form->{"transdate_$i"}, $form->{"duedate_$i"});
	} else {
	  $form->{"terms_$i"} = $terms if $form->{"terms_$i"} !~ /\d/;
	  $form->{"duedate_$i"} ||= $form->{"transdate_$i"};
	  if ($form->{"terms_$i"} > 0) {
	    $form->{"duedate_$i"} = $form->add_date($myconfig, $form->{"transdate_$i"}, $form->{"terms_$i"}, 'days');
	  }
	}
	  
	$dth->execute("$a[$form->{$form->{type}}->{department}{ndx}]");
	($form->{"department_id_$i"}) = $dth->fetchrow_array;
	$dth->finish;
	
	$wth->execute("$a[$form->{$form->{type}}->{warehouse}{ndx}]");
	($form->{"warehouse_id_$i"}) = $wth->fetchrow_array;
	$wth->finish;

      }
      
      $form->{transdate} = $form->{"transdate_$i"};
      %tax = &taxrates("", $myconfig, $form, $dbh);

      $pth->execute("$a[$form->{$form->{type}}->{partnumber}{ndx}]");

      $parts_id = 0;
      while ($ref = $pth->fetchrow_hashref(NAME_lc)) {
	$form->{"parts_id_$i"} = $ref->{id};
	for (qw(description unit)) { $form->{"${_}_$i"} ||= $ref->{$_} }
	
	$form->{"itemnotes_$i"} ||= $ref->{notes};
	
	$parts_id = 1;
	if ($customertax{$ref->{accno}}) {
	  $form->{"tax_$j"} += $a[$form->{$form->{type}}->{sellprice}{ndx}] * $a[$form->{$form->{type}}->{qty}{ndx}] * $tax{$ref->{accno}};
	}
      }
      $pth->finish;
      
      $ptth->execute("$a[$form->{$form->{type}}->{projectnumber}{ndx}]");
      ($form->{"projectnumber_$i"}) = $ptth->fetchrow_array;
      $ptth->finish;

      $form->{"projectnumber_$i"} = qq|--$form->{"projectnumber_$i"}| if $form->{"projectnumber_$i"};

      if (! $parts_id) {
	$form->{"customer_id_$j"} = 0;
	$form->{missingparts} .= "$a[$form->{$form->{type}}->{ordnumber}{ndx}] : $a[$form->{$form->{type}}->{partnumber}{ndx}]\n";
      }
      
      $form->{"total_$j"} += $a[$form->{$form->{type}}->{sellprice}{ndx}] * $a[$form->{$form->{type}}->{qty}{ndx}];
      $form->{"totalqty_$j"} += $a[$form->{$form->{type}}->{qty}{ndx}];
	
    }

    $ordnumber = $a[$form->{$form->{type}}->{ordnumber}{ndx}];
    $form->{rowcount} = $i;

  }

  $dbh->disconnect;

  chop $form->{ndx};

}


sub import_sales_order {
  my ($self, $myconfig, $form) = @_;
  
  use SL::OE;

  # connect to database, turn off AutoCommit
  my $dbh = $form->dbconnect_noauto($myconfig);

  my $query;

  $query = qq|SELECT curr
              FROM curr
	      ORDER BY rn|;
  ($form->{defaultcurrency}) = $dbh->selectrow_array($query);
  
  $form->{curr} ||= $form->{defaultcurrency};
  $form->{currency} = $form->{curr};

  my $language_code;
  $query = qq|SELECT c.customernumber, c.language_code, a.city
              FROM customer c
	      JOIN address a ON (a.trans_id = c.id)
	      WHERE c.id = $form->{customer_id}|;
  ($form->{customernumber}, $language_code, $form->{city}) = $dbh->selectrow_array($query);

  $form->{language_code} ||= $language_code;

  $query = qq|SELECT c.accno, t.rate
              FROM customertax ct
              JOIN chart c ON (c.id = ct.chart_id)
	      JOIN tax t ON (t.chart_id = c.id)
              WHERE ct.customer_id = $form->{customer_id}
	      AND (validto > '$form->{transdate}' OR validto IS NULL)
	      ORDER BY validto DESC|;
  my $sth = $dbh->prepare($query) || $form->dberror($query);
  $sth->execute;

  $form->{taxaccounts} = "";
  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    $form->{taxaccounts} .= "$ref->{accno} ";
    $form->{"$ref->{accno}_rate"} = $ref->{rate};
  }
  $sth->finish;
  chop $form->{taxaccounts};

  # post invoice
  my $rc = OE->save($myconfig, $form, $dbh);

  $dbh->disconnect;

  $rc;

}


sub purchase_order {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query;
  my $ref;
  
  my %defaults = $form->get_defaults($dbh, \@{['precision']});
  $form->{precision} = $defaults{precision};
  
  $form->{ARAP} = "AP";

  # get AR accounts
  $query = qq|SELECT accno FROM chart
              WHERE link = '$form->{ARAP}'|;
  my $sth = $dbh->prepare($query) || $form->dberror($query);

  my %ARAP = ();
  my $default_arap_accno;
  
  $sth->execute || $form->dberror($query);
  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    $ARAP{"$ref->{accno}"} = 1;
    $default_arap_accno ||= $ref->{accno};
  }

  if (! %ARAP) {
    $dbh->disconnect;
    return -1;
  }
  
  # vendor
  $query = qq|SELECT cv.id, cv.name, cv.vendornumber, cv.terms,
              e.id AS employee_id, e.name AS employee,
	      c.accno AS taxaccount, a.accno AS arap_accno,
	      ad.city
	      FROM vendor cv
	      JOIN address ad ON (ad.trans_id = cv.id)
	      LEFT JOIN employee e ON (e.id = cv.employee_id)
	      LEFT JOIN vendortax ct ON (cv.id = ct.vendor_id)
	      LEFT JOIN chart c ON (c.id = ct.chart_id)
	      LEFT JOIN chart a ON (a.id = cv.arap_accno_id)
	      WHERE vendornumber = ?|;
  my $cth = $dbh->prepare($query) || $form->dberror($query);
  
  # parts
  $query = qq|SELECT p.id, p.unit, p.description, p.notes AS itemnotes,
              c.accno
              FROM parts p
              LEFT JOIN partstax pt ON (p.id = pt.parts_id)
	      LEFT JOIN chart c ON (c.id = pt.chart_id)
              WHERE partnumber = ?|;
  my $pth = $dbh->prepare($query) || $form->dberror($query);
  
  # department
  $query = qq|SELECT id
              FROM department
              WHERE description = ?|;
  my $dth = $dbh->prepare($query) || $form->dberror($query);

  # warehouse
  $query = qq|SELECT id
              FROM warehouse
              WHERE description = ?|;
  my $wth = $dbh->prepare($query) || $form->dberror($query);
  
  # project
  $query = qq|SELECT id
              FROM project
              WHERE projectnumber = ?|;
  my $ptth = $dbh->prepare($query) || $form->dberror($query);

  # check if order already exists
  $query = qq|SELECT COUNT(*) FROM oe WHERE ordnumber = ?|;
  my $oesth = $dbh->prepare($query) || $form->dberror($query);

  my $arap_accno;
  my $terms;
  my $i = 0;
  my $j = 0;
  my %tax;
  my %vendortax;
  my $vendornumber;
  my $ordnumber;
  my %partstax;
  my $parts_id;

  my @d = split /\n/, $form->{data};
  shift @d if ! $form->{mapfile};

  for (@d) {

    @a = &ndxline($form);

    if (@a) {
      $i++;
      for (keys %{$form->{$form->{type}}}) {
	$a[$form->{$form->{type}}->{$_}{ndx}] =~ s/(^"|"$)//g;
	$form->{"${_}_$i"} = $a[$form->{$form->{type}}->{$_}{ndx}];
      }

      if ($vendornumber ne $a[$form->{$form->{type}}->{vendornumber}{ndx}] || $ordnumber ne $a[$form->{$form->{type}}->{ordnumber}{ndx}]) {
	
	$j = $i;
	$form->{ndx} .= "$i ";

	%vendortax = ();
	
	$cth->execute("$a[$form->{$form->{type}}->{vendornumber}{ndx}]");

        $arap_accno = "";
	$terms = 0;
	
	while ($ref = $cth->fetchrow_hashref(NAME_lc)) {
	  $vendornumber = $ref->{vendornumber};
	  $arap_accno = $ref->{arap_accno};
	  $terms = $ref->{terms};
	  $form->{"vendor_id_$i"} = $ref->{id};
	  $form->{"vendor_$i"} = $ref->{name};
	  $form->{"city_$i"} = $ref->{city};
	  $form->{"employee_$i"} = $ref->{employee};
	  $form->{"employee_id_$i"} = $ref->{employee_id};
	  $vendortax{$ref->{accno}} = 1;
	}
	$cth->finish;

        my $ordcount = $dbh->selectrow_array("
		SELECT COUNT(*) FROM oe 
		WHERE ordnumber = '$a[$form->{$form->{type}}->{ordnumber}{ndx}]'
		AND NOT quotation AND vendor_id = 0");
        $form->{"checked_$i"} = 'checked' if $ordcount == 0;
	
	if (! $ARAP{"$a[$form->{$form->{type}}->{$form->{ARAP}}{ndx}]"}) {
	  $arap_accno ||= $default_arap_accno;
	  $form->{"$form->{ARAP}_$i"} ||= $arap_accno;
	}

        $form->{"transdate_$i"} ||= $form->current_date($myconfig);
	
	# terms and duedate
	if ($form->{"duedate_$i"}) {
	    $form->{"terms_$i"} = $form->datediff($myconfig, $form->{"transdate_$i"}, $form->{"duedate_$i"});
	} else {
	  $form->{"terms_$i"} = $terms if $form->{"terms_$i"} !~ /\d/;
	  $form->{"duedate_$i"} ||= $form->{"transdate_$i"};
	  if ($form->{"terms_$i"} > 0) {
	    $form->{"duedate_$i"} = $form->add_date($myconfig, $form->{"transdate_$i"}, $form->{"terms_$i"}, 'days');
	  }
	}
	  
	$dth->execute("$a[$form->{$form->{type}}->{department}{ndx}]");
	($form->{"department_id_$i"}) = $dth->fetchrow_array;
	$dth->finish;
	
	$wth->execute("$a[$form->{$form->{type}}->{warehouse}{ndx}]");
	($form->{"warehouse_id_$i"}) = $wth->fetchrow_array;
	$wth->finish;

      }
      
      $form->{transdate} = $form->{"transdate_$i"};
      %tax = &taxrates("", $myconfig, $form, $dbh);

      $pth->execute("$a[$form->{$form->{type}}->{partnumber}{ndx}]");

      $parts_id = 0;
      while ($ref = $pth->fetchrow_hashref(NAME_lc)) {
	$form->{"parts_id_$i"} = $ref->{id};
	for (qw(description unit)) { $form->{"${_}_$i"} ||= $ref->{$_} }
	
	$form->{"itemnotes_$i"} ||= $ref->{notes};
	
	$parts_id = 1;
	if ($vendortax{$ref->{accno}}) {
	  $form->{"tax_$j"} += $a[$form->{$form->{type}}->{sellprice}{ndx}] * $a[$form->{$form->{type}}->{qty}{ndx}] * $tax{$ref->{accno}};
	}
      }
      $pth->finish;
      
      $ptth->execute("$a[$form->{$form->{type}}->{projectnumber}{ndx}]");
      ($form->{"projectnumber_$i"}) = $ptth->fetchrow_array;
      $ptth->finish;

      $form->{"projectnumber_$i"} = qq|--$form->{"projectnumber_$i"}| if $form->{"projectnumber_$i"};

      if (! $parts_id) {
	$form->{"vendor_id_$j"} = 0;
	$form->{missingparts} .= "$a[$form->{$form->{type}}->{ordnumber}{ndx}] : $a[$form->{$form->{type}}->{partnumber}{ndx}]\n";
      }
      
      $form->{"total_$j"} += $a[$form->{$form->{type}}->{sellprice}{ndx}] * $a[$form->{$form->{type}}->{qty}{ndx}];
      $form->{"totalqty_$j"} += $a[$form->{$form->{type}}->{qty}{ndx}];
	
    }

    $ordnumber = $a[$form->{$form->{type}}->{ordnumber}{ndx}];
    $form->{rowcount} = $i;

  }

  $dbh->disconnect;

  chop $form->{ndx};

}


sub import_purchase_order {
  my ($self, $myconfig, $form) = @_;
  
  use SL::OE;

  # connect to database, turn off AutoCommit
  my $dbh = $form->dbconnect_noauto($myconfig);

  my $query;

  $query = qq|SELECT curr
              FROM curr
	      ORDER BY rn|;
  ($form->{defaultcurrency}) = $dbh->selectrow_array($query);
  
  $form->{curr} ||= $form->{defaultcurrency};
  $form->{currency} = $form->{curr};

  my $language_code;
  $query = qq|SELECT v.vendornumber, v.language_code, a.city
              FROM vendor v
	      JOIN address a ON (a.trans_id = v.id)
	      WHERE v.id = $form->{vendor_id}|;
  ($form->{vendornumber}, $language_code, $form->{city}) = $dbh->selectrow_array($query);

  $form->{language_code} ||= $language_code;

  $query = qq|SELECT c.accno, t.rate
              FROM vendortax ct
              JOIN chart c ON (c.id = ct.chart_id)
	      JOIN tax t ON (t.chart_id = c.id)
              WHERE ct.vendor_id = $form->{vendor_id}
	      AND (validto > '$form->{transdate}' OR validto IS NULL)
	      ORDER BY validto DESC|;
  my $sth = $dbh->prepare($query) || $form->dberror($query);
  $sth->execute;

  $form->{taxaccounts} = "";
  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    $form->{taxaccounts} .= "$ref->{accno} ";
    $form->{"$ref->{accno}_rate"} = $ref->{rate};
  }
  $sth->finish;
  chop $form->{taxaccounts};

  # post invoice
  my $rc = OE->save($myconfig, $form, $dbh);

  $dbh->disconnect;

  $rc;

}



sub paymentaccounts {
  my ($self, $myconfig, $form) = @_;

  $dbh = $form->dbconnect($myconfig);

  # payment accounts
  my $query = qq|SELECT c.accno, c.description, c.link,
                 l.description AS translation
		 FROM chart c
		 LEFT JOIN translation l ON (l.trans_id = c.id AND l.language_code = '$myconfig->{countrycode}')
		 WHERE c.link LIKE '%_paid'
		 ORDER BY c.accno|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  my $ref;
  
  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    $ref->{description} = $ref->{translation} if $ref->{translation};
    push @{ $form->{all_paymentaccount} }, $ref;
  }
  $sth->finish;

  # {ARAP} accounts
  my $query = qq|SELECT c.accno, c.description, c.link,
                 l.description AS translation
		 FROM chart c
		 LEFT JOIN translation l ON (l.trans_id = c.id AND l.language_code = '$myconfig->{countrycode}')
		 WHERE c.link LIKE '$form->{ARAP}'
		 ORDER BY c.accno|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  my $ref;
  
  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    $ref->{description} = $ref->{translation} if $ref->{translation};
    push @{ $form->{arap_accounts} }, $ref;
  }
  $sth->finish;

  # Income accounts
  my $query = qq|SELECT c.accno, c.description, c.link,
                 l.description AS translation
		 FROM chart c
		 LEFT JOIN translation l ON (l.trans_id = c.id AND l.language_code = '$myconfig->{countrycode}')
		 WHERE c.link LIKE '%income'
		 OR c.link LIKE '%sale'
		 ORDER BY c.accno|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  my $ref;
  
  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    $ref->{description} = $ref->{translation} if $ref->{translation};
    push @{ $form->{income_accounts} }, $ref;
  }
  $sth->finish;

  # Expense accounts
  my $query = qq|SELECT c.accno, c.description, c.link,
                 l.description AS translation
		 FROM chart c
		 LEFT JOIN translation l ON (l.trans_id = c.id AND l.language_code = '$myconfig->{countrycode}')
		 WHERE c.link LIKE '%expense'
		 ORDER BY c.accno|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  my $ref;
  
  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    $ref->{description} = $ref->{translation} if $ref->{translation};
    push @{ $form->{expense_accounts} }, $ref;
  }
  $sth->finish;


  # currencies
  $form->{currencies} = $form->get_currencies($dbh, $myconfig);

  $query = qq|SELECT *
              FROM paymentmethod
	      ORDER BY 2|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{all_paymentmethod} }, $ref;
  }
  $sth->finish;
  
  $dbh->disconnect;
  
}


sub payments {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  $myconfig{numberformat} = "1000.00";
  
  my $query;
  my $ref;
  
  my %defaults = $form->get_defaults($dbh, \@{['precision']});
  $form->{precision} = ($defaults{precision}) ? $defaults{precision} : 2;
  
  $query = qq|SELECT c.name, c.customernumber AS companynumber, ad.city,
              a.id, a.invnumber, a.description, a.exchangerate,
	      (a.amount - a.paid) / a.exchangerate AS amount,
	      a.transdate, a.paymentmethod_id, 'customer' AS vc,
	      'ar' AS arap
	      FROM ar a
	      JOIN customer c ON (a.customer_id = c.id)
	      LEFT JOIN address ad ON (ad.trans_id = c.id)
	      WHERE a.amount != a.paid
	      UNION
	      SELECT c.name, c.vendornumber AS companynumber, ad.city,
	      a.id, a.invnumber, a.description, a.exchangerate,
	      (a.amount - a.paid) / a.exchangerate AS amount,
	      a.transdate, a.paymentmethod_id, 'vendor' AS vc,
	      'ap' AS arap
	      FROM ap a
	      JOIN vendor c ON (a.vendor_id = c.id)
	      LEFT JOIN address ad ON (ad.trans_id = c.id)
	      WHERE a.amount != a.paid|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  my %amount;
  my $amount;

  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    $amount = $form->format_amount($myconfig, $ref->{amount}, $form->{precision});
    push @{ $amount{$amount} }, $ref;
  }
  $sth->finish;
	
  # retrieve invoice by dcn
  $query = qq|SELECT c.name, c.customernumber AS companynumber, ad.city,
              a.id, a.invnumber, a.description, a.dcn,
	      a.paymentmethod_id, 'customer' AS vc, 'ar' AS arap
	      FROM ar a
	      JOIN customer c ON (a.customer_id = c.id)
	      LEFT JOIN address ad ON (ad.trans_id = c.id)
	      WHERE a.amount != a.paid
	      AND a.dcn = ?
	      UNION
	      SELECT c.name, c.vendornumber AS companynumber, ad.city,
              a.id, a.invnumber, a.description, a.dcn,
	      a.paymentmethod_id, 'vendor' AS vc, 'ap' AS arap
	      FROM ap a
	      JOIN vendor c ON (a.vendor_id = c.id)
	      LEFT JOIN address ad ON (ad.trans_id = c.id)
	      WHERE a.amount != a.paid
	      AND a.dcn = ?
	      |;
  $sth = $dbh->prepare($query) || $form->dberror($query);

  $query = qq|SELECT buy, sell FROM exchangerate
	      WHERE curr = '$form->{currency}'
	      AND transdate = ?|;
  my $eth = $dbh->prepare($query) || $form->dberror($query);
  
  my $i = 0;
  my $j = 0;

  my $vc;
  my $buy;
  my $sell;

  my @d = split /\n/, $form->{data};
  shift @d if ! $form->{mapfile};

  my $am;

  for (@d) {

    @a = &ndxline($form);

    if (@a) {
#$form->info($a[$form->{$form->{type}}->{invnumber}{ndx}]);
      
      $amount = $form->format_amount($myconfig, $a[$form->{$form->{type}}->{credit}{ndx}] - $a[$form->{$form->{type}}->{debit}{ndx}], $form->{precision});
      $am = 1;
      
#$form->info($amount);
      # dcn
      if (exists $form->{$form->{type}}->{dcn}) {

	if ($a[$form->{$form->{type}}->{dcn}{ndx}]) {
	  $am = 0;
	  $sth->execute("$a[$form->{$form->{type}}->{dcn}{ndx}]", "$a[$form->{$form->{type}}->{dcn}{ndx}]");
	  $ref = $sth->fetchrow_hashref(NAME_lc);

	  if ($ref->{invnumber}) {

	    $i++;

	    for (keys %{$form->{$form->{type}}}) {
	      $a[$form->{$form->{type}}->{$_}{ndx}] =~ s/(^"|"$)//g;
	      $form->{"${_}_$i"} = $a[$form->{$form->{type}}->{$_}{ndx}];
	    }

            $vc = $ref->{vc};
	    for (qw(id invnumber description name companynumber vc arap city paymentmethod_id)) { $form->{"${_}_$i"} = $ref->{$_} }
	    $form->{"amount_$i"} = $amount;
	  }
	  $sth->finish;
	} else {
	  $am = 1;
	}
	
      }
      
      if ($am) {
	
	if ($amount * 1) {
	  if ($amount{$amount}->[0]->{vc}) {
	      
	    $i++;
    
	    for (keys %{$form->{$form->{type}}}) {
	      $a[$form->{$form->{type}}->{$_}{ndx}] =~ s/(^"|"$)//g;
	      $form->{"${_}_$i"} = $a[$form->{$form->{type}}->{$_}{ndx}];
	    }

            $vc = $amount{$amount}->[0]->{vc};
	    for (qw(id invnumber description name companynumber vc arap city paymentmethod_id)) { $form->{"${_}_$i"} = $amount{$amount}->[0]->{$_} }
	    $form->{"amount_$i"} = $amount;

	    shift @{ $amount{$amount} };
	  }
	}
      }

      # get exchangerate
      if ($form->{currency} ne $form->{defaultcurrency}) {
	$eth->execute($a[$form->{$form->{type}}->{datepaid}{ndx}]);
	($buy, $sell) = $eth->fetchrow_array;
	$eth->finish;
	($form->{"exchangerate_$i"}) = ($vc eq 'customer') ? $buy : $sell;
      }

    }

    $form->{rowcount} = $i;

  }

  $dbh->disconnect;

}


sub ndxline {
  my ($form) = @_;
 
 my @a = ();
 my $string = 0;
 my $chr = "";
 my $m = 0;

  if ($form->{tabdelimited}) {
    @a = split /\t/, $_;
  } else {
    
    foreach $chr (split //, $_) {
      if ($chr eq '"') {
	if (! $string) {
	  $string = 1;
	  next;
	}
      }
      if ($string) {
	if ($chr eq '"') {
	  $string = 0;
	  next;
	}
      }
      if ($chr eq $form->{delimiter}) {
	if (! $string) {
	  $m++;
	  next;
	}
      }
      $a[$m] .= $chr;
    }
  }

  return @a;

}


sub unreconciled_payments {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query;
  my $ref;
  my $null;

  my ($accno) = split /--/, $form->{paymentaccount};

  my %defaults = $form->get_defaults($dbh, \@{['precision']});
  $form->{precision} = $defaults{precision};

  my $where;
  
  if ($form->{currency}) {
    $where = " AND a.curr = '$form->{currency}'";
    $query = qq|SELECT precision FROM curr
                WHERE curr = '$form->{currency}'|;
    ($form->{precision}) = $dbh->selectrow_array($query);
  }

  my $paymentmethod_id;
  if ($form->{paymentmethod}) {
    ($null, $paymentmethod_id) = split /--/, $form->{paymentmethod};
    $where .= " AND a.paymentmethod_id = $paymentmethod_id";
  }
  
  $query = qq|SELECT vc.name, vc.customernumber AS companynumber,
              a.id, a.invnumber, a.description, a.curr,
	      ac.source, ac.memo, ac.amount, ac.transdate AS datepaid
	      FROM ar a
	      JOIN acc_trans ac ON (ac.trans_id = a.id)
	      JOIN chart c ON (c.id = ac.chart_id)
	      JOIN customer vc ON (a.customer_id = vc.id)
	      WHERE ac.cleared IS NULL
	      AND c.accno = '$accno'
	      AND ac.amount > 0
	      AND ac.fx_transaction = '0'
	      AND ac.approved = '1'
	      $where
	      UNION
	      SELECT vc.name, vc.vendornumber AS companynumber,
	      a.id, a.invnumber, a.description, a.curr,
	      ac.source, ac.memo, ac.amount, ac.transdate AS datepaid
	      FROM ap a
	      JOIN acc_trans ac ON (ac.trans_id = a.id)
	      JOIN chart c ON (c.id = ac.chart_id)
	      JOIN vendor vc ON (a.vendor_id = vc.id)
	      WHERE ac.cleared IS NULL
	      AND c.accno = '$accno'
	      AND ac.amount > 0
	      AND ac.fx_transaction = '0'
	      AND ac.approved = '1'
	      $where
	      ORDER BY datepaid
	      |;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{TR} }, $ref;
  }
  $sth->finish;

  $dbh->disconnect;

}


sub vc {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query;
  my $ref;
  
  my %defaults = $form->get_defaults($dbh, \@{['precision']});
  $form->{precision} = $defaults{precision};

  $query = qq|SELECT id FROM $form->{db} WHERE $form->{db}number = ?|;
  $sth = $dbh->prepare($query);

  $query = qq|
	SELECT name, contact, phone, fax, email, notes, terms, taxincluded, cc, bcc, business_id, taxnumber, sic_code, discount, creditlimit, iban, bic, employee_id, language_code, pricegroup_id, curr, startdate, enddate, arap_accno_id, payment_accno_id, discount_accno_id, cashdiscount, threshold, paymentmethod_id, remittancevoucher
        FROM $form->{db}
	WHERE id = ?
  |;
  my $vc = $dbh->prepare($query);

  $query = qq|
	SELECT id AS contactid, salutation, firstname, lastname, contacttitle, occupation, phone, fax, mobile, email, gender, typeofcontact
	FROM contact WHERE trans_id = ?
  |;
  my $contact = $dbh->prepare($query);
 
  $query = qq|
	SELECT id AS addressid, address1, address2, city, state, zipcode, country
	FROM address WHERE trans_id = ?
  |;
  my $address = $dbh->prepare($query);

  $query = qq|
	SELECT shiptoname, shiptoaddress1, shiptoaddress2, shiptocity, shiptostate, shiptozipcode, shiptocountry, shiptophone, shiptofax, shiptoemail
	FROM shipto WHERE trans_id = ?
  |;
  my $shipto = $dbh->prepare($query);

  $query = qq|
	SELECT name AS bankname, iban, bic, address_id AS bankaddress_id, dcn, rvc, membernumber
	FROM bank WHERE id = ?
  |;
  my $bank = $dbh->prepare($query);

  $query = qq|
	SELECT address1 AS bankaddress1, address2 AS bankaddress2, city AS bankcity, state AS bankstate, zipcode AS bankzipcode, country AS bankcountry
	FROM address WHERE trans_id = ?
  |;
  my $bankaddress = $dbh->prepare($query);

  my @d = split /\n/, $form->{data};
  shift @d if ! $form->{mapfile};

  for (@d) {
    @a = &ndxline($form);
    if (@a) {
      $i++;
      for (keys %{$form->{$form->{type}}}) {
	$a[$form->{$form->{type}}->{$_}{ndx}] =~ s/(^"|"$)//g;
	$form->{"${_}_$i"} = $a[$form->{$form->{type}}->{$_}{ndx}];
      }
      if (!$form->{"id_$i"}){
	   if ($form->{"$form->{db}number_$i"}){
	      $sth->execute($form->{"$form->{db}number_$i"});
	      $ref = $sth->fetchrow_hashref(NAME_lc);
	      $form->{"id_$i"} = $ref->{id};
	      $sth->finish;
 	   }
      }
      if ($form->{"id_$i"}){
	 # vc
	 $vc->execute($form->{"id_$i"});
         $ref = $vc->fetchrow_hashref(NAME_lc);
         foreach (keys %$ref){
	    $form->{"${_}_$i"} = $ref->{$_} if !$form->{"${_}_$i"};
	 }
	 $vc->finish;

	 # contact
	 $contact->execute($form->{"id_$i"});
         $ref = $contact->fetchrow_hashref(NAME_lc);
         foreach (keys %$ref){
	    $form->{"${_}_$i"} = $ref->{$_} if !$form->{"${_}_$i"};
	 }
	 $contact->finish;

	 # address
	 $address->execute($form->{"id_$i"});
         $ref = $address->fetchrow_hashref(NAME_lc);
         foreach (keys %$ref){
	    $form->{"${_}_$i"} = $ref->{$_} if !$form->{"${_}_$i"};
	 }
         $address->finish;

	 # shipto
	 $shipto->execute($form->{"id_$i"});
         $ref = $shipto->fetchrow_hashref(NAME_lc);
         foreach (keys %$ref){
	    $form->{"${_}_$i"} = $ref->{$_} if !$form->{"${_}_$i"};
	 }
	 $shipto->finish;

	 # bank
	 $bank->execute($form->{"id_$i"});
         $ref = $bank->fetchrow_hashref(NAME_lc);
         foreach (keys %$ref){
	    $form->{"${_}_$i"} = $ref->{$_} if !$form->{"${_}_$i"};
	 }
	 $bank->finish;

	 # bankaddress
	 $bankaddress->execute($form->{"bankaddress_id_$i"});
         $ref = $bankaddress->fetchrow_hashref(NAME_lc);
         foreach (keys %$ref){
	    $form->{"${_}_$i"} = $ref->{$_} if !$form->{"${_}_$i"};
	 }
	 $bankaddress->finish;
      }
    }
    $form->{rowcount} = $i;
  }

  $dbh->disconnect;
  chop $form->{ndx};

}

sub partscustomer {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $ref;
  
  my %defaults = $form->get_defaults($dbh, \@{['precision']});
  $form->{precision} = $defaults{precision};

  my $pquery = qq|SELECT id, description FROM parts WHERE LOWER(partnumber) = ?|; 
  my $psth = $dbh->prepare($pquery) || $form->dberror($pquery);

  my $cquery = qq|SELECT id, name FROM customer WHERE LOWER(customernumber) = ?|; 
  my $csth = $dbh->prepare($cquery) || $form->dberror($cquery);

  my $pgquery = qq|SELECT id FROM pricegroup WHERE LOWER(pricegroup) = ?|; 
  my $pgsth = $dbh->prepare($pgquery) || $form->dberror($pgquery);

  my @d = split /\n/, $form->{data};
  shift @d if ! $form->{mapfile};

  for (@d) {
    @a = &ndxline($form);
    if (@a) {
      $i++;
      for (keys %{$form->{$form->{type}}}) {
	$a[$form->{$form->{type}}->{$_}{ndx}] =~ s/(^"|"$)//g;
	$form->{"${_}_$i"} = $a[$form->{$form->{type}}->{$_}{ndx}];
      }
      $psth->execute(lc "$a[$form->{$form->{type}}->{partnumber}{ndx}]");
      if ($ref = $psth->fetchrow_hashref(NAME_lc)) {
	$form->{"parts_id_$i"} = $ref->{id};
	$form->{"description_$i"} = $ref->{description};
      }
      $psth->finish;
      $csth->execute(lc "$a[$form->{$form->{type}}->{customernumber}{ndx}]");
      if ($ref = $csth->fetchrow_hashref(NAME_lc)) {
	$form->{"customer_id_$i"} = $ref->{id};
	$form->{"name_$i"} = $ref->{name};
      }
      $csth->finish;
      $pgsth->execute(lc "$a[$form->{$form->{type}}->{pricegroup}{ndx}]");
      if ($ref = $pgsth->fetchrow_hashref(NAME_lc)) {
	$form->{"pricegroup_id_$i"} = $ref->{id};
      }
      $pgsth->finish;
      $form->{"pricegroup_id_$i"} *= 1;
    }
    $form->{rowcount} = $i;
  }

  $dbh->disconnect;
  chop $form->{ndx};
}

sub partsvendor {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $ref;
  
  my %defaults = $form->get_defaults($dbh, \@{['precision']});
  $form->{precision} = $defaults{precision};

  my $pquery = qq|SELECT id, description FROM parts WHERE LOWER(partnumber) = ?|; 
  my $psth = $dbh->prepare($pquery) || $form->dberror($pquery);

  my $vquery = qq|SELECT id, name FROM vendor WHERE LOWER(vendornumber) = ?|; 
  my $vsth = $dbh->prepare($vquery) || $form->dberror($vquery);

  my @d = split /\n/, $form->{data};
  shift @d if ! $form->{mapfile};

  for (@d) {
    @a = &ndxline($form);
    if (@a) {
      $i++;
      for (keys %{$form->{$form->{type}}}) {
	$a[$form->{$form->{type}}->{$_}{ndx}] =~ s/(^"|"$)//g;
	$form->{"${_}_$i"} = $a[$form->{$form->{type}}->{$_}{ndx}];
      }
      $psth->execute(lc "$a[$form->{$form->{type}}->{partnumber}{ndx}]");
      if ($ref = $psth->fetchrow_hashref(NAME_lc)) {
	$form->{"parts_id_$i"} = $ref->{id};
	$form->{"description_$i"} = $ref->{description};
      }
      $psth->finish;
      $vsth->execute(lc "$a[$form->{$form->{type}}->{vendornumber}{ndx}]");
      if ($ref = $vsth->fetchrow_hashref(NAME_lc)) {
	$form->{"vendor_id_$i"} = $ref->{id};
	$form->{"name_$i"} = $ref->{name};
      }
      $vsth->finish;
    }
    $form->{rowcount} = $i;
  }

  $dbh->disconnect;
  chop $form->{ndx};
}

sub parts {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query;
  my $ref;
  
  my %defaults = $form->get_defaults($dbh, \@{['precision']});
  $form->{precision} = $defaults{precision};

  $gquery = qq|SELECT id FROM partsgroup WHERE LOWER(partsgroup) = ?|; 
  my $gsth = $dbh->prepare($gquery) || $form->dberror($gquery);

  $pquery = qq|SELECT id FROM parts WHERE LOWER(partnumber) = ?|; 
  my $psth = $dbh->prepare($pquery) || $form->dberror($pquery);

  my @d = split /\n/, $form->{data};
  shift @d if ! $form->{mapfile};

  for (@d) {
    @a = &ndxline($form);
    if (@a) {
      $i++;
      for (keys %{$form->{$form->{type}}}) {
	$a[$form->{$form->{type}}->{$_}{ndx}] =~ s/(^"|"$)//g;
	$form->{"${_}_$i"} = $a[$form->{$form->{type}}->{$_}{ndx}];
      }
      $gsth->execute(lc "$a[$form->{$form->{type}}->{partsgroup}{ndx}]");
      if ($ref = $gsth->fetchrow_hashref(NAME_lc)) {
	$form->{"partsgroup_id_$i"} = $ref->{id};
      }
      $gsth->finish;
      $psth->execute(lc "$a[$form->{$form->{type}}->{partnumber}{ndx}]");
      if ($ref = $psth->fetchrow_hashref(NAME_lc)) {
	$form->{"parts_id_$i"} = $ref->{id};
      }
      $psth->finish;
    }
    $form->{rowcount} = $i;
  }

  $dbh->disconnect;
  chop $form->{ndx};
}

sub accounts {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query;
  my $ref;
  
  my %defaults = $form->get_defaults($dbh, \@{['precision']});
  $form->{precision} = $defaults{precision};
  
  my @d = split /\n/, $form->{data};
  shift @d if ! $form->{mapfile};

  for (@d) {
    @a = &ndxline($form);
    if (@a) {
      $i++;
      for (keys %{$form->{$form->{type}}}) {
	$a[$form->{$form->{type}}->{$_}{ndx}] =~ s/(^"|"$)//g;
	$form->{"${_}_$i"} = $a[$form->{$form->{type}}->{$_}{ndx}];
      }
    }
    $form->{rowcount} = $i;
  }

  $dbh->disconnect;
  chop $form->{ndx};

}


sub transactions {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query;
  my $ref;
  
  my %defaults = $form->get_defaults($dbh, \@{['precision']});
  $form->{precision} = $defaults{precision};

  # customer/vendor
  $query = qq|SELECT vc.id, vc.name, vc.$form->{vc}number, vc.terms,
              e.id AS employee_id, e.name AS employee,
              c.accno AS taxaccount, a.accno AS arap_accno,
              ad.city
              FROM $form->{vc} vc
              JOIN address ad ON (ad.trans_id = vc.id)
              LEFT JOIN employee e ON (e.id = vc.employee_id)
              LEFT JOIN $form->{vc}tax ct ON (vc.id = ct.$form->{vc}_id)
              LEFT JOIN chart c ON (c.id = ct.chart_id)
              LEFT JOIN chart a ON (a.id = vc.arap_accno_id)
              WHERE $form->{vc}number = ?|;
  my $cth = $dbh->prepare($query) || $form->dberror($query);

  $query = qq|SELECT description FROM chart WHERE accno = ?|;
  my $ath = $dbh->prepare($query) || $form->dberror($query);

  my @d = split /\n/, $form->{data};
  shift @d if ! $form->{mapfile};

  for (@d) {
    @a = &ndxline($form);
    if (@a) {
      $i++;
      for (keys %{$form->{$form->{type}}}) {
	$a[$form->{$form->{type}}->{$_}{ndx}] =~ s/(^"|"$)//g;
	$form->{"${_}_$i"} = $a[$form->{$form->{type}}->{$_}{ndx}];
      }

      $ath->execute("$a[$form->{$form->{type}}->{account}{ndx}]");
      my $ref = $ath->fetchrow_hashref(NAME_lc);
      $form->{"account_description_$i"} = $ref->{description};

      if ($form->{vc} eq 'customer'){
      $cth->execute("$a[$form->{$form->{type}}->{customernumber}{ndx}]");
      } else {
      $cth->execute("$a[$form->{$form->{type}}->{vendornumber}{ndx}]");
      }
      while ($ref = $cth->fetchrow_hashref(NAME_lc)) {
          $arap_accno = $ref->{arap_accno};
          $terms = $ref->{terms};
          $form->{"$form->{vc}_id_$i"} = $ref->{id};
          $form->{"name_$i"} = $ref->{name};
          $form->{"city_$i"} = $ref->{city};
          $form->{"employee_$i"} = $ref->{employee};
          $form->{"employee_id_$i"} = $ref->{employee_id};
          $customertax{$ref->{accno}} = 1;
      }
      $cth->finish;

    }
    $form->{rowcount} = $i;
  }

  $cth->finish;
  $ath->finish;

  $dbh->disconnect;
  chop $form->{ndx};
}


sub gl {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query;
  my $ref;
  
  my %defaults = $form->get_defaults($dbh, \@{['precision']});
  $form->{precision} = $defaults{precision};

  $query = qq|SELECT curr FROM curr ORDER BY rn|;
  ($form->{defaultcurrency}) = $dbh->selectrow_array($query);

  $query = qq|SELECT c.id, c.description
              FROM chart c
              WHERE accno = ?|;
  my $cth = $dbh->prepare($query) || $form->dberror($query);
 
  $query = qq|SELECT id FROM department WHERE description = ?|;
  my $dth = $dbh->prepare($query) || $form->dberror($query);

  $query = qq|SELECT id
              FROM project
              WHERE projectnumber = ?|;
  my $pth = $dbh->prepare($query) || $form->dberror($query);

  my @d = split /\n/, $form->{data};
  shift @d if ! $form->{mapfile};

  for (@d) {
    @a = &ndxline($form);
    if (@a) {
      $i++;
      for (keys %{$form->{$form->{type}}}) {
	$a[$form->{$form->{type}}->{$_}{ndx}] =~ s/(^"|"$)//g;
	$form->{"${_}_$i"} = $a[$form->{$form->{type}}->{$_}{ndx}];
      }
      $cth->execute("$a[$form->{$form->{type}}->{accno}{ndx}]");
      if ($ref = $cth->fetchrow_hashref(NAME_lc)) {
	$form->{"accdescription_$i"} = $ref->{description};
	$form->{"ndx_$i"} = 'Y';
      } else {
	$form->{"accdescription_$i"} = '*****';
      }
      $dth->execute("$a[$form->{$form->{type}}->{department}{ndx}]");
      if ($ref = $dth->fetchrow_hashref(NAME_lc)) {
	$form->{"department_id_$i"} = $ref->{id};
      } else {
        $a[$form->{$form->{type}}->{department}{ndx}] = '***';
	$form->{"department_id_$i"} = 0;
      }
      $pth->execute("$a[$form->{$form->{type}}->{projectnumber}{ndx}]");
      if ($ref = $pth->fetchrow_hashref(NAME_lc)) {
	$form->{"project_id_$i"} = $ref->{id};
      } else {
        $a[$form->{$form->{type}}->{projectnumber}{ndx}] = '***';
	$form->{"project_id_$i"} = 0;
      }
    }
    $form->{rowcount} = $i;
  }
  $cth->finish;
  $dth->finish;
  $pth->finish;
  $dbh->disconnect;
}

sub vendor_payment {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $ref;
  
  my %defaults = $form->get_defaults($dbh, \@{['precision']});
  $form->{precision} = $defaults{precision};

  # Payment account
  my $pquery = qq|SELECT id, accno FROM chart WHERE LOWER(description) = ?|; 
  my $psth = $dbh->prepare($pquery) || $form->dberror($pquery);

  # Vendor lookup
  my $vquery = qq|SELECT id, vendornumber FROM vendor WHERE LOWER(name) = ?|; 
  my $vsth = $dbh->prepare($vquery) || $form->dberror($vquery);

  # Expense account lookup
  my $equery = qq|SELECT id, accno FROM chart WHERE LOWER(description) = ?|; 
  my $esth = $dbh->prepare($equery) || $form->dberror($equery);

  my @d = split /\n/, $form->{data};
  shift @d if ! $form->{mapfile};

  for (@d) {
    @a = &ndxline($form);
    if (@a) {
      $i++;
      for (keys %{$form->{$form->{type}}}) {
	$a[$form->{$form->{type}}->{$_}{ndx}] =~ s/(^"|"$)//g;
	$form->{"${_}_$i"} = $a[$form->{$form->{type}}->{$_}{ndx}];
      }
      $psth->execute(lc "$a[$form->{$form->{type}}->{paidfrom}{ndx}]");
      if ($ref = $psth->fetchrow_hashref(NAME_lc)) {
	$form->{"payment_chart_id_$i"} = $ref->{id};
	$form->{"payment_accno_$i"} = $ref->{accno};
      }
      $psth->finish;

      $vsth->execute(lc "$a[$form->{$form->{type}}->{payee}{ndx}]");
      if ($ref = $vsth->fetchrow_hashref(NAME_lc)) {
	$form->{"vendor_id_$i"} = $ref->{id};
	$form->{"vendornumber_$i"} = $ref->{vendornumber};
      }
      $vsth->finish;

      $esth->execute(lc "$a[$form->{$form->{type}}->{category}{ndx}]");
      if ($ref = $esth->fetchrow_hashref(NAME_lc)) {
	$form->{"expense_chart_id_$i"} = $ref->{id};
	$form->{"expense_accno_$i"} = $ref->{accno};
      }
      $esth->finish;
    }
    $form->{rowcount} = $i;
  }

  $dbh->disconnect;
  chop $form->{ndx};
}

sub delete_import {
  my ($dbh, $form) = @_;

  my $query = qq|SELECT reportid FROM report
                 WHERE reportcode = '$form->{reportcode}'
	         AND login = '$form->{login}'|;
  my ($reportid) = $dbh->selectrow_array($query);

  if (!$reportid) {
    $query = qq|INSERT INTO report (reportcode, login)
                VALUES ('$form->{reportcode}', '$form->{login}')|;
    $dbh->do($query) || $form->dberror($query);

    $query = qq|SELECT reportid FROM report
                WHERE reportcode = '$form->{reportcode}'
		AND login = '$form->{login}'|;
    ($reportid) = $dbh->selectrow_array($query);
  }

  $query = qq|DELETE FROM reportvars
              WHERE reportid = $reportid|;
  $dbh->do($query) || $form->dberror($query);

  $reportid;
}

sub dataline {
  my ($form) = @_;

  my @dl     = ();
  my $string = 0;
  my $chr    = "";
  my $m      = 0;

  chomp;

  if ($form->{tabdelimited}) {
    @dl = split /\t/, $_;
  }
  else {
    if ($form->{stringsquoted}) {
      foreach $chr (split //, $_) {
        if ($chr eq '"') {
          if (!$string) {
            $string = 1;
            next;
          }
        }
        if ($string) {
          if ($chr eq '"') {
            $string = 0;
            next;
          }
        }
        if ($chr eq $form->{delimiter}) {
          if (!$string) {
            $m++;
            next;
          }
        }
        $dl[$m] .= $chr;
      }
    }
    else {
      @dl = split /$form->{delimiter}/, $_;
    }
  }

  unshift @dl, "";
  return @dl;

}



sub prepare_import_data {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query;
  my $sth;
  my $ref;

  # clean out report
  my $reportid = &delete_import($dbh, $form);

  $query = qq|DELETE FROM reportvars
              WHERE reportid = $reportid|;
  $dbh->do($query) || $form->dberror($query);

  $query = qq|INSERT INTO reportvars (reportid, reportvariable, reportvalue)
              VALUES ($reportid, ?, ?)|;
  my $rth = $dbh->prepare($query) || $form->dberror($query);

  my $i = 0;
  my $j = 0;

  my @d = split /\n/, $form->{data};
  shift @d if !$form->{mapfile};

  my @dl;

  for (@d) {

    @dl = &dataline($form);

    if ($#dl) {
      $i++;
      for (keys %{$form->{$form->{type}}}) {
        if (defined $form->{$form->{type}}->{$_}{ndx}) {

          # Remove non-printable character
          $dl[$form->{$form->{type}}->{$_}{ndx}] =~ s/[^[:print:]]+//g;
          $form->{"${_}_$i"} = $dl[$form->{$form->{type}}->{$_}{ndx}];
          if ($form->{"${_}_$i"}) {
            $rth->execute("${_}_$i", $form->{"${_}_$i"});
            $rth->finish;
          }
        }
      }
    }
    $form->{rowcount} = $i;

  }
  $dbh->disconnect;
}

sub import_generic {
  my ($self, $myconfig, $form) = @_;

  use DBIx::Simple;
  $form->{dbh} = $form->dbconnect($myconfig);
  $form->{dbs} = DBIx::Simple->connect($form->{dbh});

  my $reportid = $form->{dbs}->query('SELECT reportid FROM report WHERE reportcode = ?', $form->{reportcode})->list;

  my $newform = new Form;

  $query = qq|SELECT * FROM reportvars
              WHERE reportid = $reportid
	      AND reportvariable LIKE ?|;
  my $sth = $form->{dbh}->prepare($query) || $form->dberror($query);

  $form->{dbs}->query('delete from generic_import') or die($form->{dbs}->error);

  for my $i (1 .. $form->{rowcount}) {
    if ($form->{"ndx_$i"}) {

      for (keys %$newform) { delete $newform->{$_} }

      $sth->execute("%\\_$i");
      while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
        $ref->{reportvariable} =~ s/_(\d+)//;
        if ($1 == $i) {
          $newform->{$ref->{reportvariable}} = $ref->{reportvalue};
        }
      }
      $sth->finish;

      my $query = qq|
         INSERT INTO generic_import (c1, c2, c3, c4, c5, c6, c7, c8, c9, c10, c11, c12, c13, c14, c15, c16, c17, c18, c19, c20)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      |;
      $form->{dbs}->query($query, 
            $newform->{c1}, $newform->{c2}, $newform->{c3}, $newform->{c4}, $newform->{c5}, $newform->{c6}, $newform->{c7},
            $newform->{c8}, $newform->{c9}, $newform->{c10}, $newform->{c11}, $newform->{c12}, $newform->{c13}, $newform->{c14}, $newform->{c15}, $newform->{c16}, $newform->{c17}, $newform->{c18},
            $newform->{c19}, $newform->{c20}
      ) or error($form->dberror);
    }
    $i++;
  }
}

1;


