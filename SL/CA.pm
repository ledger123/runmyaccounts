#=====================================================================
# SQL-Ledger ERP
# Copyright (C) 2006
#
#  Author: DWS Systems Inc.
#     Web: http://www.sql-ledger.com
#
#======================================================================
#
# chart of accounts
#
#======================================================================


package CA;


sub all_accounts {
  my ($self, $myconfig, $form) = @_;

  my $amount = ();
  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $ref;
  
  my %defaults = $form->get_defaults($dbh, \@{['precision', 'company']});
  for (keys %defaults) { $form->{$_} = $defaults{$_} }
 
  my $query = qq|SELECT c.accno,
                 SUM(ac.amount) AS amount
                 FROM chart c
		 JOIN acc_trans ac ON (ac.chart_id = c.id)
		 WHERE ac.approved = '1'
		 GROUP BY c.accno|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    $amount{$ref->{accno}} = $ref->{amount}
  }
  $sth->finish;
 
  $query = qq|SELECT accno, description
              FROM gifi|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  my $gifi = ();
  while (my ($accno, $description) = $sth->fetchrow_array) {
    $gifi{$accno} = $description;
  }
  $sth->finish;

  $query = qq|SELECT c.id, c.accno, c.description, c.charttype, c.gifi_accno,
              c.category, c.link, allow_gl,
	      l.description AS translation
              FROM chart c
	      LEFT JOIN translation l ON (l.trans_id = c.id AND l.language_code = '$myconfig->{countrycode}')
	      ORDER BY c.accno|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);
 
  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    $ref->{amount} = $amount{$ref->{accno}};
    $ref->{gifi_description} = $gifi{$ref->{gifi_accno}};
    if ($ref->{amount} < 0) {
      $ref->{debit} = $ref->{amount} * -1;
    } else {
      $ref->{credit} = $ref->{amount};
    }
    $ref->{description} = $ref->{translation} if $ref->{translation};
    push @{ $form->{CA} }, $ref;
  }

  $sth->finish;
  $dbh->disconnect;

}


sub all_transactions {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);


  my %defaults = $form->get_defaults($dbh, \@{['precision', 'company']});
  for (keys %defaults) { $form->{$_} = $defaults{$_} }
    
  # SQLI protection: accno, gifi_accno need to be validated/escaped

  # get chart_id
  my $query = qq|SELECT id FROM chart
                 WHERE accno = |.$dbh->quote($form->{accno}).qq||;
  if ($form->{accounttype} eq 'gifi') {
    $query = qq|SELECT id FROM chart
                WHERE gifi_accno = |.$dbh->quote($form->{gifi_accno}).qq||;
  }
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  my @id = ();
  while (my ($id) = $sth->fetchrow_array) {
    push @id, $id;
  }
  $sth->finish;

  my $fromdate_where;
  my $todate_where;
  my $fx_transaction;

  ($form->{fromdate}, $form->{todate}) = $form->from_to($form->{year}, $form->{month}, $form->{interval}) if $form->{year} && $form->{month};

  my $subwhere;

  if ($form->{fromdate}) {
    $fromdate_where = qq|
                 AND ac.transdate >= '$form->{fromdate}'
		| if $form->{method} ne 'cash';
    $subwhere = qq| AND ac.transdate >= '$form->{fromdate}'|;
  }
  if ($form->{todate}) {
    $todate_where = qq|
                 AND ac.transdate <= '$form->{todate}'
		|;
    $subwhere .= qq| AND ac.transdate <= '$form->{todate}'|;
  }

  my $subquery = qq|
	AND ac.trans_id IN (
		SELECT ac.trans_id
		FROM acc_trans ac
		JOIN chart c ON (ac.chart_id = c.id)
		WHERE (c.link LIKE '%AP_paid%' OR c.link LIKE '%AR_paid')
		AND ac.approved = '1'
		$subwhere
  )| if $form->{method} eq 'cash';

  if (!$form->{fx_transaction}){
    $fx_transaction = qq|
                AND ac.fx_transaction = '0' 
|; 
  }

  my $false = ($myconfig->{dbdriver} =~ /Pg/) ? FALSE : q|'0'|;
  
  # Oracle workaround, use ordinal positions
  my %ordinal = ( transdate => 5,
		  reference => 2,
		  description => 3 );

  my @a = qw(transdate reference description);
  my $sortorder = $form->sort_order(\@a, \%ordinal);

  my $null;
  my $department_id;
  my $dpt_where;
  my $dpt_join;
  my $union;
  
  ($null, $department_id) = split /--/, $form->{department};
  
  if ($department_id) {
    $dpt_join = qq|
                   JOIN department t ON (t.id = a.department_id)
		  |;
    $dpt_where = qq|
		   AND t.id = $department_id
		  |;
  }

  my $project;
  my $project_id;
  if ($form->{projectnumber}) {
    ($null, $project_id) = split /--/, $form->{projectnumber};
    $project = qq|
                 AND ac.project_id = $project_id
		 |;
  }

  if ($form->{accno} || $form->{gifi_accno}) {
    # get category for account
    $query = qq|SELECT c.description, c.category, c.link, c.contra,
                l.description AS translation
                FROM chart c
		LEFT JOIN translation l ON (l.trans_id = c.id AND l.language_code = '$myconfig->{countrycode}')
		WHERE c.accno = |.$dbh->quote($form->{accno}).qq||;
    if ($form->{accounttype} eq 'gifi') {
      $query = qq|SELECT description, category, link, contra
                FROM chart
		WHERE gifi_accno = |.$dbh->quote($form->{gifi_accno}).qq|
		AND charttype = 'A'|;
    }

    ($form->{description}, $form->{category}, $form->{link}, $form->{contra}, $form->{translation}) = $dbh->selectrow_array($query);

    $form->{description} = $form->{translation} if $form->{translation};
    
    if ($form->{fromdate}) {

      if ($department_id) {
	
	$query = ""; 
	$union = "";

	for (qw(ar ap gl)) {
	  
	  if ($form->{accounttype} eq 'gifi') {
	    $query = qq|
	                $union
			SELECT SUM(ac.amount)
			FROM acc_trans ac
			JOIN $_ a ON (a.id = ac.trans_id)
			JOIN chart c ON (ac.chart_id = c.id)
			WHERE c.gifi_accno = |.$dbh->quote($form->{gifi_accno}).qq|
			AND ac.approved = '1'
			AND ac.transdate < '$form->{fromdate}'
			AND a.department_id = |.$form->dbclean($department_id).qq|
			$project
            $fx_transaction
			$subquery
			|;
		      
	  } else {

	    $query = qq|
			$union
			SELECT SUM(ac.amount)
			FROM acc_trans ac
			JOIN $_ a ON (a.id = ac.trans_id)
			JOIN chart c ON (ac.chart_id = c.id)
			WHERE c.accno = |.$dbh->quote($form->{accno}).qq|
			AND ac.approved = '1'
			AND ac.transdate < '$form->{fromdate}'
			AND a.department_id = |.$form->dbclean($department_id).qq|
			$project
            $fx_transaction
			$subquery
			|;
	  }

	}
	
      } else {
	
	if ($form->{accounttype} eq 'gifi') {
	  $query = qq|SELECT SUM(ac.amount)
		    FROM acc_trans ac
		    JOIN chart c ON (ac.chart_id = c.id)
		    WHERE c.gifi_accno = |.$dbh->quote($form->{gifi_accno}).qq|
		    AND ac.approved = '1'
		    AND ac.transdate < '$form->{fromdate}'
		    $project
            $fx_transaction
		    $subquery
		    |;
	} else {
	  $query = qq|SELECT SUM(ac.amount)
		      FROM acc_trans ac
		      JOIN chart c ON (ac.chart_id = c.id)
		      WHERE c.accno = |.$dbh->quote($form->{accno}).qq|
		      AND ac.approved = '1'
		      AND ac.transdate < '$form->{fromdate}'
		      $project
              $fx_transaction
		      $subquery
		      |;
	}
      }
	
      ($form->{balance}) = $dbh->selectrow_array($query);
      
    }
  }
  $form->{balance} = 0 if $form->{method} eq 'cash'; # We don't need it when drilling down from income statement

  $query = "";
  my $union = "";

  foreach my $id (@id) {

    # get all transactions
    $query .= qq|$union
                 SELECT a.id, a.reference, a.description, '' AS name, ac.transdate,
	         $false AS invoice, a.curr, ac.amount, 'gl' as module, ac.cleared,
		 ac.source,
		 '' AS till, ac.chart_id, '0' AS vc_id
		 FROM gl a
		 JOIN acc_trans ac ON (ac.trans_id = a.id)
		 $dpt_join
		 WHERE ac.chart_id = $id
		 AND ac.approved = '1'
		 $fromdate_where
		 $todate_where
		 $dpt_where
		 $project
         $fx_transaction
		 $subquery
      
             UNION ALL
      
                 SELECT a.id, a.invnumber, a.description, c.name, ac.transdate,
	         a.invoice, a.curr, ac.amount, 'ar' as module, ac.cleared,
		 ac.source,
		 a.till, ac.chart_id, c.id AS vc_id
		 FROM ar a
		 JOIN acc_trans ac ON (ac.trans_id = a.id)
		 JOIN customer c ON (a.customer_id = c.id)
		 $dpt_join
		 WHERE ac.chart_id = $id
		 AND ac.approved = '1'
		 $fromdate_where
		 $todate_where
		 $dpt_where
		 $project
         $fx_transaction
		 $subquery
      
             UNION ALL
      
                 SELECT a.id, a.invnumber, a.description, v.name, ac.transdate,
	         a.invoice, a.curr, ac.amount, 'ap' as module, ac.cleared,
		 ac.source,
		 a.till, ac.chart_id, v.id AS vc_id
		 FROM ap a
		 JOIN acc_trans ac ON (ac.trans_id = a.id)
		 JOIN vendor v ON (a.vendor_id = v.id)
		 $dpt_join
		 WHERE ac.chart_id = $id
		 AND ac.approved = '1'
		 $fromdate_where
		 $todate_where
		 $dpt_where
		 $project
         $fx_transaction
		 $subquery
		 |;

    $union = qq|
             UNION ALL
                 |;
  }

  $query .= qq|
      ORDER BY $sortorder|;

  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  $query = qq|SELECT c.id, c.accno FROM chart c
              JOIN acc_trans ac ON (ac.chart_id = c.id)
              WHERE ac.amount >= 0
	      AND (c.link = 'AR' OR c.link = 'AP')
	      AND ac.approved = '1'
	      AND ac.trans_id = ?|;
  my $dr = $dbh->prepare($query) || $form->dberror($query);

  $query = qq|SELECT c.id, c.accno FROM chart c
              JOIN acc_trans ac ON (ac.chart_id = c.id)
              WHERE ac.amount < 0
	      AND (c.link = 'AR' OR c.link = 'AP')
	      AND ac.approved = '1'
	      AND ac.trans_id = ?|;
  my $cr = $dbh->prepare($query) || $form->dberror($query);
  
  my $accno;
  my $chart_id;
  my %accno;
  
  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    
    # gl
    if ($ref->{module} eq "gl") {
      $ref->{module} = "gl";
      $ref->{vc_id} = 0;
      $ref->{db} = "";
    }

    # ap
    if ($ref->{module} eq "ap") {
      $ref->{module} = ($ref->{invoice}) ? 'ir' : 'ap';
      $ref->{module} = 'ps' if $ref->{till};
      $ref->{db} = "vendor";
    }

    # ar
    if ($ref->{module} eq "ar") {
      $ref->{module} = ($ref->{invoice}) ? 'is' : 'ar';
      $ref->{module} = 'ps' if $ref->{till};
      $ref->{db} = "customer";
    }

    if ($ref->{amount}) {
      %accno = ();

      if ($ref->{amount} < 0) {
	$ref->{debit} = $ref->{amount} * -1;
	$ref->{credit} = 0;
	$dr->execute($ref->{id});
	$ref->{accno} = ();
	while (($chart_id, $accno) = $dr->fetchrow_array) {
	  $accno{$accno} = 1 if $chart_id ne $ref->{chart_id};
	}
	$dr->finish;
	
	for (sort keys %accno) { push @{ $ref->{accno} }, "$_ " }

      } else {
	$ref->{credit} = $ref->{amount};
	$ref->{debit} = 0;
	
	$cr->execute($ref->{id});
	$ref->{accno} = ();
	while (($chart_id, $accno) = $cr->fetchrow_array) {
	  $accno{$accno} = 1 if $chart_id ne $ref->{chart_id};
	}
	$cr->finish;

	for (keys %accno) { push @{ $ref->{accno} }, "$_ " }

      }

      push @{ $form->{CA} }, $ref;
    }
    
  }
 
  $sth->finish;
  $dbh->disconnect;

}

1;

