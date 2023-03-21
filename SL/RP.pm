#=====================================================================
# SQL-Ledger ERP
# Copyright (C) 2006
#
#  Author: DWS Systems Inc.
#     Web: http://www.sql-ledger.com
#
#======================================================================
#
# backend code for reports
#
#======================================================================

package RP;


sub yearend_statement {
  my ($self, $myconfig, $form) = @_;

  my ($null, $department_id) = split(/--/, $form->{department});
  $department_id *= 1;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  # if todate < existing yearends, delete GL and yearends
  my $query = qq|SELECT trans_id FROM yearend
                 WHERE transdate >= |.$dbh->quote($form->{todate}).qq||;
  if ($department_id){
     $query .= " AND trans_id IN (SELECT trans_id FROM dpt_trans WHERE department_id = $department_id)";
  }
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  my @trans_id = ();
  my $id;
  while (($id) = $sth->fetchrow_array) {
    push @trans_id, $id;
  }
  $sth->finish;

  $query = qq|DELETE FROM gl
              WHERE id = ?|;
  $sth = $dbh->prepare($query) || $form->dberror($query);

  $query = qq|DELETE FROM acc_trans
              WHERE trans_id = ?|;
  my $ath = $dbh->prepare($query) || $form->dberror($query);

  $query = qq|DELETE FROM yearend
              WHERE trans_id = ?|;
  my $yth = $dbh->prepare($query) || $form->dberror($query);

  foreach $id (@trans_id) {
    $sth->execute($id);
    $ath->execute($id);
    $yth->execute($id);

    $sth->finish;
    $ath->finish;
    $yth->finish;
  }

  my $last_period = 0;
  my @categories = qw(I E);
  my $category;

  $form->{decimalplaces} *= 1;

  &get_accounts($dbh, 0, $form->{fromdate}, $form->{todate}, $form, \@categories);

  # disconnect
  $dbh->disconnect;


  # now we got $form->{I}{accno}{ }
  # and $form->{E}{accno}{  }

  my %account = ( 'I' => { 'label' => 'income',
                           'labels' => 'income',
			   'ml' => 1 },
		  'E' => { 'label' => 'expense',
		           'labels' => 'expenses',
			   'ml' => -1 }
		);

  foreach $category (@categories) {
    foreach $key (sort keys %{ $form->{$category} }) {
      if ($form->{$category}{$key}{charttype} eq 'A') {
	$form->{"total_$account{$category}{labels}_this_period"} += $form->{$category}{$key}{this} * $account{$category}{ml};
      }
    }
  }


  # totals for income and expenses
  $form->{total_income_this_period} = $form->round_amount($form->{total_income_this_period}, $form->{decimalplaces});
  $form->{total_expenses_this_period} = $form->round_amount($form->{total_expenses_this_period}, $form->{decimalplaces});

  # total for income/loss
  $form->{total_this_period} = $form->{total_income_this_period} - $form->{total_expenses_this_period};

}


sub create_links {
  my ($self, $myconfig, $form, $vc) = @_;

  $vc = 'vendor' if $vc ne 'customer'; # SQLI protection

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  $form->all_departments($myconfig, $dbh, $vc);

  $form->all_projects($myconfig, $dbh);

  $form->all_languages($myconfig, $dbh);

  $dbh->disconnect;

}


sub income_statement {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $last_period = 0;
  my @categories = qw(I E);
  my $category;

  $form->{decimalplaces} *= 1;

  if (! ($form->{fromdate} || $form->{todate})) {
    if ($form->{fromyear} && $form->{frommonth}) {
      ($form->{fromdate}, $form->{todate}) = $form->from_to($form->{fromyear}, $form->{frommonth}, $form->{interval});
    }
  }

  if ($form->{currency} ne $form->{defaultcurrency}) {
    my $transdate = $form->{todate};
    $transdate ||= $form->current_date($myconfig);

    $form->{exchangerate} = $form->get_exchangerate($myconfig, $dbh, $form->{currency}, $transdate, 'buy');
  }

  $form->{exchangerate} ||= 1;

  &get_accounts($dbh, $last_period, $form->{fromdate}, $form->{todate}, $form, \@categories, 1);

  if (! ($form->{comparefromdate} || $form->{comparetodate})) {
    if ($form->{compareyear} && $form->{comparemonth}) {
      ($form->{comparefromdate}, $form->{comparetodate}) = $form->from_to($form->{compareyear}, $form->{comparemonth}, $form->{interval});
    }
  }

  # if there are any compare dates
  if ($form->{comparefromdate} || $form->{comparetodate}) {
    $last_period = 1;

    &get_accounts($dbh, $last_period, $form->{comparefromdate}, $form->{comparetodate}, $form, \@categories, 1);
  }

  my %defaults = $form->get_defaults($dbh, \@{['company','address','businessnumber']});
  for (keys %defaults) { $form->{$_} = $defaults{$_} }

  # disconnect
  $dbh->disconnect;


  # now we got $form->{I}{accno}{ }
  # and $form->{E}{accno}{  }

  my %account = ( 'I' => { 'label' => 'income',
                           'labels' => 'income',
			   'ml' => 1 },
		  'E' => { 'label' => 'expense',
		           'labels' => 'expenses',
			   'ml' => -1 }
		);

  my $str;
  my $tmpstr;
  my $translink = qq|ca.pl?action=list_transactions&fx_transaction=1&l_name=1|;
  for (qw(path login fromdate todate method)){ $translink .= qq|&$_=$form->{$_}| }
  for (qw(projectnumber department)){
     $translink .= "&$_=" . $form->escape($form->{$_});
  }

  foreach $category (@categories) {

    foreach $key (sort keys %{ $form->{$category} }) {
      # push description onto array

      $str = ($form->{l_heading}) ? $form->{padding} : "";

      if ($form->{$category}{$key}{charttype} eq "A") {
	$form->{tmpstr} = ($form->{l_accno}) ? "$form->{$category}{$key}{accno} - $form->{$category}{$key}{description}" : "$form->{$category}{$key}{description}";
    $form->format_string(tmpstr);
	$form->{tmpstr} = qq|<a href=$translink&accno=$form->{$category}{$key}{accno} target=_blank>| . $form->{tmpstr} . qq|</a>| if $form->{accounttype} eq 'standard';
	$str .= $form->{tmpstr};
      }
      if ($form->{$category}{$key}{charttype} eq "H") {
	if ($account{$category}{subtotal} && $form->{l_subtotal}) {
	  $dash = "- ";
	  push(@{$form->{"$account{$category}{label}_account"}}, "$str$form->{bold}$account{$category}{subdescription}$form->{endbold}");
	  push(@{$form->{"$account{$category}{labels}_this_period"}}, $form->format_amount($myconfig, $account{$category}{subthis} * $account{$category}{ml}, $form->{decimalplaces}, $dash));

	  if ($last_period) {
	    push(@{$form->{"$account{$category}{labels}_last_period"}}, $form->format_amount($myconfig, $account{$category}{sublast} * $account{$category}{ml}, $form->{decimalplaces}, $dash));
	  }

	}

	$str = "$form->{br}$form->{bold}$form->{$category}{$key}{description}$form->{endbold}";

	$account{$category}{subthis} = $form->{$category}{$key}{this};
	$account{$category}{sublast} = $form->{$category}{$key}{last};
	$account{$category}{subdescription} = $form->{$category}{$key}{description};
	$account{$category}{subtotal} = 1;

	$form->{$category}{$key}{this} = 0;
	$form->{$category}{$key}{last} = 0;

	next unless $form->{l_heading};

	$dash = " ";
      }

      push(@{$form->{"$account{$category}{label}_account"}}, $str);

      if ($form->{$category}{$key}{charttype} eq 'A') {
	$form->{"total_$account{$category}{labels}_this_period"} += $form->{$category}{$key}{this} * $account{$category}{ml};
	$dash = "- ";
      }

      push(@{$form->{"$account{$category}{labels}_this_period"}}, $form->format_amount($myconfig, $form->{$category}{$key}{this} * $account{$category}{ml}, $form->{decimalplaces}, $dash));

      # add amount or - for last period
      if ($last_period) {
	$form->{"total_$account{$category}{labels}_last_period"} += $form->{$category}{$key}{last} * $account{$category}{ml};

	push(@{$form->{"$account{$category}{labels}_last_period"}}, $form->format_amount($myconfig,$form->{$category}{$key}{last} * $account{$category}{ml}, $form->{decimalplaces}, $dash));
      }
    }

    $str = ($form->{l_heading}) ? $form->{padding} : "";
    if ($account{$category}{subtotal} && $form->{l_subtotal}) {
      push(@{$form->{"$account{$category}{label}_account"}}, "$str$form->{bold}$account{$category}{subdescription}$form->{endbold}");
      push(@{$form->{"$account{$category}{labels}_this_period"}}, $form->format_amount($myconfig, $account{$category}{subthis} * $account{$category}{ml}, $form->{decimalplaces}, $dash));

      if ($last_period) {
	push(@{$form->{"$account{$category}{labels}_last_period"}}, $form->format_amount($myconfig, $account{$category}{sublast} * $account{$category}{ml}, $form->{decimalplaces}, $dash));
      }
    }

  }


  # totals for income and expenses
  $form->{total_income_this_period} = $form->round_amount($form->{total_income_this_period}, $form->{decimalplaces});
  $form->{total_expenses_this_period} = $form->round_amount($form->{total_expenses_this_period}, $form->{decimalplaces});

  # total for income/loss
  $form->{total_this_period} = $form->{total_income_this_period} - $form->{total_expenses_this_period};

  if ($last_period) {
    # total for income/loss
    $form->{total_last_period} = $form->format_amount($myconfig, $form->{total_income_last_period} - $form->{total_expenses_last_period}, $form->{decimalplaces}, "- ");

    # totals for income and expenses for last_period
    $form->{total_income_last_period} = $form->format_amount($myconfig, $form->{total_income_last_period}, $form->{decimalplaces}, "- ");
    $form->{total_expenses_last_period} = $form->format_amount($myconfig, $form->{total_expenses_last_period}, $form->{decimalplaces}, "- ");

  }


  $form->{total_income_this_period} = $form->format_amount($myconfig,$form->{total_income_this_period}, $form->{decimalplaces}, "- ");
  $form->{total_expenses_this_period} = $form->format_amount($myconfig,$form->{total_expenses_this_period}, $form->{decimalplaces}, "- ");
  $form->{total_this_period} = $form->format_amount($myconfig,$form->{total_this_period}, $form->{decimalplaces}, "- ");

}


sub balance_sheet {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $last_period = 0;
  my @categories = qw(A L Q);

  my $null;

  $form->{asofdate} = $form->dbclean($form->{asofdate});
  $form->{compareasofdate} = $form->dbclean($form->{compareasofdate});

  if ($form->{asofdate}) {
    if ($form->{asofyear} && $form->{asofmonth}) {
      if ($form->{asofdate} !~ /\W/) {
	$form->{asofdate} = "$form->{asofyear}$form->{asofmonth}$form->{asofdate}";
      }
    }
  } else {
    if ($form->{asofyear} && $form->{asofmonth}) {
      ($null, $form->{asofdate}) = $form->from_to($form->{asofyear}, $form->{asofmonth});
    }
  }

  # if there are any dates construct a where
  if ($form->{asofdate}) {

    $form->{this_period} = "$form->{asofdate}";
    $form->{period} = "$form->{asofdate}";

  }

  $form->{decimalplaces} *= 1;

  if ($form->{currency} ne $form->{defaultcurrency}) {
    my $transdate = $form->{asofdate};
    $transdate ||= $form->current_date($myconfig);

    $form->{exchangerate} = $form->get_exchangerate($myconfig, $dbh, $form->{currency}, $transdate, 'buy');
  }

  $form->{exchangerate} ||= 1;

  &get_accounts($dbh, $last_period, "", $form->{asofdate}, $form, \@categories, 1);

  if ($form->{compareasofdate}) {
    if ($form->{compareasofyear} && $form->{compareasofmonth}) {
      if ($form->{compareasofdate} !~ /\W/) {
	$form->{compareasofdate} = "$form->{compareasofyear}$form->{compareasofmonth}$form->{compareasofdate}";
      }
    }
  } else {
    if ($form->{compareasofyear} && $form->{compareasofmonth}) {
      ($null, $form->{compareasofdate}) = $form->from_to($form->{compareasofyear}, $form->{compareasofmonth});
    }
  }

  # if there are any compare dates
  if ($form->{compareasofdate}) {

    $last_period = 1;
    &get_accounts($dbh, $last_period, "", $form->{compareasofdate}, $form, \@categories, 1);

    $form->{last_period} = "$form->{compareasofdate}";

  }

  my %defaults = $form->get_defaults($dbh, \@{['company','address','businessnumber']});
  for (keys %defaults) { $form->{$_} = $defaults{$_} }

  # disconnect
  $dbh->disconnect;


  # now we got $form->{A}{accno}{ }    assets
  # and $form->{L}{accno}{ }           liabilities
  # and $form->{Q}{accno}{ }           equity
  # build asset accounts

  my $str;
  my $key;

  my %account  = ( 'A' => { 'label' => 'asset',
                            'labels' => 'assets',
			    'ml' => -1 },
		   'L' => { 'label' => 'liability',
		            'labels' => 'liabilities',
			    'ml' => 1 },
		   'Q' => { 'label' => 'equity',
		            'labels' => 'equity',
			    'ml' => 1 }
		);


   foreach $category (@categories) {

    foreach $key (sort keys %{ $form->{$category} }) {

      $str = ($form->{l_heading}) ? $form->{padding} : "";

      if ($form->{$category}{$key}{charttype} eq "A") {
	$str .= ($form->{l_accno}) ? "$form->{$category}{$key}{accno} - $form->{$category}{$key}{description}" : "$form->{$category}{$key}{description}";
      }
      if ($form->{$category}{$key}{charttype} eq "H") {
	if ($account{$category}{subtotal} && $form->{l_subtotal}) {
	  $dash = "- ";
	  push(@{$form->{"$account{$category}{label}_account"}}, "$str$form->{bold}$account{$category}{subdescription}$form->{endbold}");
	  push(@{$form->{"$account{$category}{label}_this_period"}}, $form->format_amount($myconfig, $account{$category}{subthis} * $account{$category}{ml}, $form->{decimalplaces}, $dash));

	  if ($last_period) {
	    push(@{$form->{"$account{$category}{label}_last_period"}}, $form->format_amount($myconfig, $account{$category}{sublast} * $account{$category}{ml}, $form->{decimalplaces}, $dash));
	  }
	}

	$str = "$form->{bold}$form->{$category}{$key}{description}$form->{endbold}";

	$account{$category}{subthis} = $form->{$category}{$key}{this};
	$account{$category}{sublast} = $form->{$category}{$key}{last};
	$account{$category}{subdescription} = $form->{$category}{$key}{description};
	$account{$category}{subtotal} = 1;

	$form->{$category}{$key}{this} = 0;
	$form->{$category}{$key}{last} = 0;

	next unless $form->{l_heading};

	$dash = " ";
      }

      # push description onto array
      push(@{$form->{"$account{$category}{label}_account"}}, $str);

      if ($form->{$category}{$key}{charttype} eq 'A') {
	$form->{"total_$account{$category}{labels}_this_period"} += $form->{$category}{$key}{this} * $account{$category}{ml};
	$dash = "- ";
      }

      push(@{$form->{"$account{$category}{label}_this_period"}}, $form->format_amount($myconfig, $form->{$category}{$key}{this} * $account{$category}{ml}, $form->{decimalplaces}, $dash));

      if ($last_period) {
	$form->{"total_$account{$category}{labels}_last_period"} += $form->{$category}{$key}{last} * $account{$category}{ml};

	push(@{$form->{"$account{$category}{label}_last_period"}}, $form->format_amount($myconfig, $form->{$category}{$key}{last} * $account{$category}{ml}, $form->{decimalplaces}, $dash));
      }
    }

    $str = ($form->{l_heading}) ? $form->{padding} : "";
    if ($account{$category}{subtotal} && $form->{l_subtotal}) {
      push(@{$form->{"$account{$category}{label}_account"}}, "$str$form->{bold}$account{$category}{subdescription}$form->{endbold}");
      push(@{$form->{"$account{$category}{label}_this_period"}}, $form->format_amount($myconfig, $account{$category}{subthis} * $account{$category}{ml}, $form->{decimalplaces}, $dash));

      if ($last_period) {
	push(@{$form->{"$account{$category}{label}_last_period"}}, $form->format_amount($myconfig, $account{$category}{sublast} * $account{$category}{ml}, $form->{decimalplaces}, $dash));
      }
    }

  }


  # totals for assets, liabilities
  $form->{total_assets_this_period} = $form->round_amount($form->{total_assets_this_period}, 8);
  $form->{total_liabilities_this_period} = $form->round_amount($form->{total_liabilities_this_period}, 8);
  $form->{total_equity_this_period} = $form->round_amount($form->{total_equity_this_period}, 8);

  # calculate earnings
  $form->{earnings_this_period} = $form->{total_assets_this_period} - $form->{total_liabilities_this_period} - $form->{total_equity_this_period};

  push(@{$form->{equity_this_period}}, $form->format_amount($myconfig, $form->{earnings_this_period}, $form->{decimalplaces}, "- "));

  $form->{total_equity_this_period} = $form->round_amount($form->{total_equity_this_period} + $form->{earnings_this_period}, 8);

  # add liability + equity
  $form->{total_this_period} = $form->format_amount($myconfig, $form->{total_liabilities_this_period} + $form->{total_equity_this_period}, $form->{decimalplaces}, "- ");


  if ($last_period) {
    # totals for assets, liabilities
    $form->{total_assets_last_period} = $form->round_amount($form->{total_assets_last_period}, 8);
    $form->{total_liabilities_last_period} = $form->round_amount($form->{total_liabilities_last_period}, 8);
    $form->{total_equity_last_period} = $form->round_amount($form->{total_equity_last_period}, 8);

    # calculate retained earnings
    $form->{earnings_last_period} = $form->{total_assets_last_period} - $form->{total_liabilities_last_period} - $form->{total_equity_last_period};

    push(@{$form->{equity_last_period}}, $form->format_amount($myconfig,$form->{earnings_last_period}, $form->{decimalplaces}, "- "));

    $form->{total_equity_last_period} = $form->round_amount($form->{total_equity_last_period} + $form->{earnings_last_period}, 8);

    # add liability + equity
    $form->{total_last_period} = $form->format_amount($myconfig, $form->{total_liabilities_last_period} + $form->{total_equity_last_period}, $form->{decimalplaces}, "- ");

  }


  $form->{total_liabilities_last_period} = $form->format_amount($myconfig, $form->{total_liabilities_last_period}, $form->{decimalplaces}, "- ") if ($form->{total_liabilities_last_period});

  $form->{total_equity_last_period} = $form->format_amount($myconfig, $form->{total_equity_last_period}, $form->{decimalplaces}, "- ") if ($form->{total_equity_last_period});

  $form->{total_assets_last_period} = $form->format_amount($myconfig, $form->{total_assets_last_period}, $form->{decimalplaces}, "- ") if ($form->{total_assets_last_period});

  $form->{total_assets_this_period} = $form->format_amount($myconfig, $form->{total_assets_this_period}, $form->{decimalplaces}, "- ");

  $form->{total_liabilities_this_period} = $form->format_amount($myconfig, $form->{total_liabilities_this_period}, $form->{decimalplaces}, "- ");

  $form->{total_equity_this_period} = $form->format_amount($myconfig, $form->{total_equity_this_period}, $form->{decimalplaces}, "- ");

}


sub get_accounts {
  my ($dbh, $last_period, $fromdate, $todate, $form, $categories, $excludeyearend) = @_;

  my $department_id;
  my $project_id;

  ($null, $department_id) = split /--/, $form->{department};
  ($null, $project_id) = split /--/, $form->{projectnumber};

  my $query;
  my $dpt_where;
  my $dpt_join;
  my $project;
  my $where = "1 = 1";
  my $glwhere = "";
  my $subwhere = "";
  my $subwhere2 = "";
  my $yearendwhere = "1 = 1";
  my $item;

  my $category = "AND (";
  foreach $item (@{ $categories }) {
    $category .= qq|c.category = |.$dbh->quote($item).qq| OR |;
  }
  $category =~ s/OR $/\)/;


  # get headings
  $query = qq|SELECT c.accno, c.description, c.category,
              l.description AS translation
	      FROM chart c
	      LEFT JOIN translation l ON (l.trans_id = c.id AND l.language_code = |.$dbh->quote($form->{language_code}).qq|)
	      WHERE c.charttype = 'H'
	      $category
	      ORDER by c.accno|;

  if ($form->{accounttype} eq 'gifi')
  {
    $query = qq|SELECT g.accno, g.description, 'A'
		FROM gifi g
		JOIN chart c ON (c.gifi_accno = g.accno)
		WHERE c.charttype = 'H'
		$category
		ORDER BY g.accno|;
  }

  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  my @headingaccounts = ();
  while ($ref = $sth->fetchrow_hashref(NAME_lc))
  {
    $ref->{description} = $ref->{translation} if $ref->{translation};

    $form->{$ref->{category}}{$ref->{accno}}{description} = "$ref->{description}";
    $form->{$ref->{category}}{$ref->{accno}}{charttype} = "H";
    $form->{$ref->{category}}{$ref->{accno}}{accno} = $ref->{accno};

    push @headingaccounts, $ref->{accno};
  }

  $sth->finish;

  if ($form->{method} eq 'cash' && !$todate) {
    $todate = $form->current_date($myconfig);
  }

  if ($fromdate) {
    if ($form->{method} eq 'cash') {
      $subwhere .= " AND ac.transdate >= '".$form->dbclean($fromdate)."'";
      $subwhere2 .= " AND datepaid >= '".$form->dbclean($fromdate)."'";
      $glwhere = " AND ac.transdate >= '".$form->dbclean($fromdate)."'";
    } else {
      $where .= " AND ac.transdate >= '".$form->dbclean($fromdate)."'";
    }
  }

  if ($todate) {
    $where .= " AND ac.transdate <= '".$form->dbclean($todate)."'";
    $subwhere .= " AND ac.transdate <= '".$form->dbclean($todate)."'";
    $subwhere2 .= " AND datepaid <= '".$form->dbclean($todate)."'";
    $yearendwhere = "ac.transdate < '".$form->dbclean($todate)."'";
  }

  if ($excludeyearend) {
    $ywhere = " AND ac.trans_id NOT IN
               (SELECT trans_id FROM yearend)";

   if ($todate) {
      $ywhere = " AND ac.trans_id NOT IN
		 (SELECT trans_id FROM yearend
		  WHERE transdate <= '".$form->dbclean($todate)."')";
    }

    if ($fromdate) {
      $ywhere = " AND ac.trans_id NOT IN
		 (SELECT trans_id FROM yearend
		  WHERE transdate >= '".$form->dbclean($fromdate)."')";
      if ($todate) {
	$ywhere = " AND ac.trans_id NOT IN
		   (SELECT trans_id FROM yearend
		    WHERE transdate >= '".$form->dbclean($fromdate)."'
		    AND transdate <= '".$form->dbclean($todate)."')";
      }
    }
  }

  if ($department_id) {
    $dpt_join = qq|
               JOIN department t ON (a.department_id = t.id)
		  |;
    $dpt_where = qq|
               AND t.id = |.$form->dbclean($department_id).qq|
	           |;
  }

  if ($project_id) {
    $project = qq|
                 AND ac.project_id = |.$form->dbclean($project_id).qq|
		 |;
  }


  if ($form->{accounttype} eq 'gifi') {

    if ($form->{method} eq 'cash') {

	$query = qq|

	         SELECT g.accno, sum(ac.amount) AS amount,
		 g.description, c.category
		 FROM acc_trans ac
	         JOIN chart c ON (c.id = ac.chart_id)
	         JOIN ar a ON (a.id = ac.trans_id)
	         JOIN gifi g ON (g.accno = c.gifi_accno)
	         $dpt_join
		 WHERE $where
		 AND a.approved = '1'
		 $ywhere
		 $dpt_where
		 $category
		 AND ac.trans_id IN
		   (
		     SELECT trans_id
		     FROM acc_trans ac
		     JOIN chart c ON (ac.chart_id = c.id)
		     WHERE c.link LIKE '%AR_paid%'
		     AND ac.approved = '1'
		     $subwhere
		     AND ac.trans_id IN (SELECT id FROM ar WHERE amount = paid $subwhere2)
		   )
		 $project
		 GROUP BY g.accno, g.description, c.category

       UNION ALL

		 SELECT '' AS accno, SUM(ac.amount) AS amount,
		 '' AS description, c.category
		 FROM acc_trans ac
	         JOIN chart c ON (c.id = ac.chart_id)
	         JOIN ar a ON (a.id = ac.trans_id)
	         $dpt_join
		 WHERE $where
		 AND ac.approved = '1'
		 $ywhere
		 $dpt_where
		 $category
		 AND c.gifi_accno = ''
		 AND ac.trans_id IN
		   (
		     SELECT ac.trans_id
		     FROM acc_trans ac
		     JOIN chart c ON (ac.chart_id = c.id)
		     WHERE c.link LIKE '%AR_paid%'
		     AND ac.approved = '1'
		     $subwhere
		     AND ac.trans_id IN (SELECT id FROM ar WHERE amount = paid $subwhere2)
		   )
		 $project
		 GROUP BY c.category

       UNION ALL

       	         SELECT g.accno, sum(ac.amount) AS amount,
		 g.description, c.category
		 FROM acc_trans ac
	         JOIN chart c ON (c.id = ac.chart_id)
	         JOIN ap a ON (a.id = ac.trans_id)
	         JOIN gifi g ON (g.accno = c.gifi_accno)
	         $dpt_join
		 WHERE $where
		 AND a.approved = '1'
		 $ywhere
		 $dpt_where
		 $category
		 AND ac.trans_id IN
		   (
		     SELECT ac.trans_id
		     FROM acc_trans ac
		     JOIN chart c ON (ac.chart_id = c.id)
		     WHERE c.link LIKE '%AP_paid%'
		     AND ac.approved = '1'
		     $subwhere
		     AND ac.trans_id IN (SELECT id FROM ap WHERE amount = paid $subwhere2)
		   )
		 $project
		 GROUP BY g.accno, g.description, c.category

       UNION ALL

		 SELECT '' AS accno, SUM(ac.amount) AS amount,
		 '' AS description, c.category
		 FROM acc_trans ac
	         JOIN chart c ON (c.id = ac.chart_id)
	         JOIN ap a ON (a.id = ac.trans_id)
	         $dpt_join
		 WHERE $where
		 AND a.approved = '1'
		 $ywhere
		 $dpt_where
		 $category
		 AND c.gifi_accno = ''
		 AND ac.trans_id IN
		   (
		     SELECT ac.trans_id
		     FROM acc_trans ac
		     JOIN chart c ON (ac.chart_id = c.id)
		     WHERE c.link LIKE '%AP_paid%'
		     AND ac.approved = '1'
		     $subwhere
		     AND ac.trans_id IN (SELECT id FROM ap WHERE amount = paid $subwhere2)
		   )
		 $project
		 GROUP BY c.category

       UNION ALL

-- add gl

	         SELECT g.accno, sum(ac.amount) AS amount,
		 g.description, c.category
		 FROM acc_trans ac
	         JOIN chart c ON (c.id = ac.chart_id)
	         JOIN gifi g ON (g.accno = c.gifi_accno)
	         JOIN gl a ON (a.id = ac.trans_id)
	         $dpt_join
		 WHERE $where
		 AND a.approved = '1'
		 $ywhere
		 $glwhere
		 $dpt_where
		 $category
		 AND NOT (c.link = 'AR' OR c.link = 'AP')
		 $project
		 GROUP BY g.accno, g.description, c.category

       UNION ALL

		 SELECT '' AS accno, SUM(ac.amount) AS amount,
		 '' AS description, c.category
		 FROM acc_trans ac
	         JOIN chart c ON (c.id = ac.chart_id)
	         JOIN gl a ON (a.id = ac.trans_id)
	         $dpt_join
		 WHERE $where
		 AND a.approved = '1'
		 $ywhere
		 $glwhere
		 $dpt_where
		 $category
		 AND c.gifi_accno = ''
		 AND NOT (c.link = 'AR' OR c.link = 'AP')
		 $project
		 GROUP BY c.category
		 |;

      if ($excludeyearend) {

         # this is for the yearend

	 $query .= qq|

       UNION ALL

	         SELECT g.accno, sum(ac.amount) AS amount,
		 g.description, c.category
		 FROM yearend y
		 JOIN gl a ON (a.id = y.trans_id)
		 JOIN acc_trans ac ON (ac.trans_id = y.trans_id)
		 JOIN chart c ON (c.id = ac.chart_id)
		 JOIN gifi g ON (g.accno = c.gifi_accno)
	         $dpt_join
		 WHERE $yearendwhere
		 AND c.category = 'Q'
		 $dpt_where
		 $project
		 GROUP BY g.accno, g.description, c.category
		 |;
      }

    } else {

      if ($department_id) {
	$dpt_join = qq|
	      JOIN dpt_trans t ON (t.trans_id = ac.trans_id)
	      |;
	$dpt_where = qq|
               AND t.department_id = $department_id
	      |;
      }

      $query = qq|

	      SELECT g.accno, SUM(ac.amount) AS amount,
	      g.description, c.category
	      FROM acc_trans ac
	      JOIN chart c ON (c.id = ac.chart_id)
	      JOIN gifi g ON (c.gifi_accno = g.accno)
	      $dpt_join
	      WHERE $where
	      AND ac.approved = '1'
	      $ywhere
	      $dpt_where
	      $category
	      $project
	      GROUP BY g.accno, g.description, c.category

	   UNION ALL

	      SELECT '' AS accno, SUM(ac.amount) AS amount,
	      '' AS description, c.category
	      FROM acc_trans ac
	      JOIN chart c ON (c.id = ac.chart_id)
	      $dpt_join
	      WHERE $where
	      AND ac.approved = '1'
	      $ywhere
	      $dpt_where
	      $category
	      AND c.gifi_accno = ''
	      $project
	      GROUP BY c.category
	      |;

	if ($excludeyearend) {

	  # this is for the yearend

	  $query .= qq|

       UNION ALL

	         SELECT g.accno, sum(ac.amount) AS amount,
		 g.description, c.category
		 FROM yearend y
		 JOIN gl a ON (a.id = y.trans_id)
		 JOIN acc_trans ac ON (ac.trans_id = y.trans_id)
		 JOIN chart c ON (c.id = ac.chart_id)
		 JOIN gifi g ON (g.accno = c.gifi_accno)
	         $dpt_join
		 WHERE $yearendwhere
		 AND c.category = 'Q'
		 $dpt_where
		 $project
		 GROUP BY g.accno, g.description, c.category
	      |;
	}
    }

  } else {    # standard account

    if ($form->{method} eq 'cash') {

      $query = qq|

	         SELECT c.accno, sum(ac.amount) AS amount,
		 c.description, c.category,
		 l.description AS translation
		 FROM acc_trans ac
		 JOIN chart c ON (c.id = ac.chart_id)
		 JOIN ar a ON (a.id = ac.trans_id)
		 LEFT JOIN translation l ON (l.trans_id = c.id AND l.language_code = '$form->{language_code}')
		 $dpt_join
		 WHERE $where
		 AND ac.approved = '1'
	         $ywhere
		 $dpt_where
		 $category
		 AND ac.trans_id IN
		   (
		     SELECT ac.trans_id
		     FROM acc_trans ac
		     JOIN chart c ON (ac.chart_id = c.id)
		     WHERE c.link LIKE '%AR_paid%'
		     AND ac.approved = '1'
		     $subwhere
		     AND ac.trans_id IN (SELECT id FROM ar WHERE amount = paid $subwhere2)
		   )

		 $project
		 GROUP BY c.accno, c.description, c.category, translation

	UNION ALL

	         SELECT c.accno, sum(ac.amount) AS amount,
		 c.description, c.category,
		 l.description AS translation
		 FROM acc_trans ac
		 JOIN chart c ON (c.id = ac.chart_id)
		 JOIN ap a ON (a.id = ac.trans_id)
		 LEFT JOIN translation l ON (l.trans_id = c.id AND l.language_code = '$form->{language_code}')
		 $dpt_join
		 WHERE $where
		 AND a.approved = '1'
	         $ywhere
		 $dpt_where
		 $category
		 AND ac.trans_id IN
		   (
		     SELECT ac.trans_id
		     FROM acc_trans ac
		     JOIN chart c ON (ac.chart_id = c.id)
		     WHERE c.link LIKE '%AP_paid%'
		     AND ac.approved = '1'
		     $subwhere
		     AND ac.trans_id IN (SELECT id FROM ap WHERE amount = paid $subwhere2)
		   )

		 $project
		 GROUP BY c.accno, c.description, c.category, translation

        UNION ALL

		 SELECT c.accno, sum(ac.amount) AS amount,
		 c.description, c.category,
		 l.description AS translation
		 FROM acc_trans ac
		 JOIN chart c ON (c.id = ac.chart_id)
		 JOIN gl a ON (a.id = ac.trans_id)
		 LEFT JOIN translation l ON (l.trans_id = c.id AND l.language_code = '$form->{language_code}')
		 $dpt_join
		 WHERE $where
		 AND a.approved = '1'
	         $ywhere
		 $glwhere
		 $dpt_where
		 $category
		 AND NOT (c.link = 'AR' OR c.link = 'AP')
		 $project
		 GROUP BY c.accno, c.description, c.category, translation
		 |;

      if ($excludeyearend) {

        # this is for the yearend

	$query .= qq|

       UNION ALL

	         SELECT c.accno, sum(ac.amount) AS amount,
		 c.description, c.category,
		 l.description AS translation
		 FROM yearend y
		 JOIN gl a ON (a.id = y.trans_id)
		 JOIN acc_trans ac ON (ac.trans_id = y.trans_id)
		 JOIN chart c ON (c.id = ac.chart_id)
		 LEFT JOIN translation l ON (l.trans_id = c.id AND l.language_code = '$form->{language_code}')
	         $dpt_join
		 WHERE $yearendwhere
		 AND c.category = 'Q'
		 $dpt_where
		 $project
		 GROUP BY c.accno, c.description, c.category, translation
		 |;
      }

    } else {

      if ($department_id) {
	$dpt_join = qq|
	      JOIN dpt_trans t ON (t.trans_id = ac.trans_id)
	      |;
	$dpt_where = qq|
               AND t.department_id = |.$form->dbclean($department_id).qq|
	      |;
      }


      $query = qq|

		 SELECT c.accno, sum(ac.amount) AS amount,
		 c.description, c.category,
		 l.description AS translation
		 FROM acc_trans ac
		 JOIN chart c ON (c.id = ac.chart_id)
		 LEFT JOIN translation l ON (l.trans_id = c.id AND l.language_code = |.$dbh->quote($form->{language_code}).qq|)
		 $dpt_join
		 WHERE $where
		 AND ac.approved = '1'
	         $ywhere
		 $dpt_where
		 $category
		 $project
		 GROUP BY c.accno, c.description, c.category, translation
		 |;

      if ($excludeyearend) {

        # this is for the yearend

	$query .= qq|

       UNION ALL

	         SELECT c.accno, sum(ac.amount) AS amount,
		 c.description, c.category,
		 l.description AS translation
		 FROM yearend y
		 JOIN gl a ON (a.id = y.trans_id)
		 JOIN acc_trans ac ON (ac.trans_id = y.trans_id)
		 JOIN chart c ON (c.id = ac.chart_id)
		 LEFT JOIN translation l ON (l.trans_id = c.id AND l.language_code = |.$dbh->quote($form->{language_code}).qq|)
	         $dpt_join
		 WHERE $yearendwhere
		 AND c.category = 'Q'
		 $dpt_where
		 $project
		 GROUP BY c.accno, c.description, c.category, translation
		 |;
      }
    }
  }

  my @accno;
  my $accno;
  my $ref;

  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  $form->{exchangerate} ||= 1;

  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {

    # get last heading account
    @accno = grep { $_ le "$ref->{accno}" } @headingaccounts;
    $accno = pop @accno;

    $ref->{amount} /= $form->{exchangerate};

    if ($accno && ($accno ne $ref->{accno}) ) {
      if ($last_period)
      {
	$form->{$ref->{category}}{$accno}{last} += $ref->{amount};
      } else {
	$form->{$ref->{category}}{$accno}{this} += $ref->{amount};
      }
    }

    $ref->{description} = $ref->{translation} if $ref->{translation};

    $form->{$ref->{category}}{$ref->{accno}}{accno} = $ref->{accno};
    $form->{$ref->{category}}{$ref->{accno}}{description} = $ref->{description};
    $form->{$ref->{category}}{$ref->{accno}}{charttype} = "A";

    if ($last_period) {
      $form->{$ref->{category}}{$ref->{accno}}{last} += $ref->{amount};
    } else {
      $form->{$ref->{category}}{$ref->{accno}}{this} += $ref->{amount};
    }
  }
  $sth->finish;


  # remove accounts with zero balance
  foreach $category (@{ $categories }) {
    foreach $accno (keys %{ $form->{$category} }) {
      # armaghan 17 aug 2020 forced 8 precision in rounding to avoid rounding errors in calculating income
      #$form->{$category}{$accno}{last} = $form->round_amount($form->{$category}{$accno}{last}, $form->{decimalplaces});
      #$form->{$category}{$accno}{this} = $form->round_amount($form->{$category}{$accno}{this}, $form->{decimalplaces});
      $form->{$category}{$accno}{last} = $form->round_amount($form->{$category}{$accno}{last}, 8);
      $form->{$category}{$accno}{this} = $form->round_amount($form->{$category}{$accno}{this}, 8);

      delete $form->{$category}{$accno} if ($form->round_amount($form->{$category}{$accno}{this},2) == 0 && $form->round_amount($form->{$category}{$accno}{last},2) == 0); 
    }
  }

}



sub trial_balance {
  my ($self, $myconfig, $form) = @_;

  my $dbh = $form->dbconnect($myconfig);

  my ($query, $sth, $ref);
  my %balance = ();
  my %trb = ();
  my $null;
  my $department_id;
  my $project_id;
  my @headingaccounts = ();
  my $dpt_where;
  my $dpt_join;
  my $project;

  my $fx_transaction;

  my %defaults = $form->get_defaults($dbh, \@{['precision', 'company']});
  for (keys %defaults) { $form->{$_} = $defaults{$_} }

  $form->{precision8} = 8; # armaghan 7 april 2020 use 8 as precision for calculations to avoid rounding issues.

  my $where = "ac.approved = '1'";
  my $invwhere = $where;

  ($null, $department_id) = split /--/, $form->{department};
  ($null, $project_id) = split /--/, $form->{projectnumber};

  if ($department_id) {
    $dpt_join = qq|
                JOIN dpt_trans t ON (ac.trans_id = t.trans_id)
		  |;
    $dpt_where = qq|
                AND t.department_id = |.$form->dbclean($department_id).qq|
		|;
  }


  if ($project_id) {
    $project = qq|
                AND ac.project_id = |.$form->dbclean($project_id).qq|
		|;
  }

  if (!$form->{fx_transaction}){
    $fx_transaction = qq|
                AND fx_transaction = '0'
|;
  }

  ($form->{fromdate}, $form->{todate}) = $form->from_to($form->{year}, $form->{month}, $form->{interval}) if $form->{year} && $form->{month};

  # get beginning balances
  if ($form->{fromdate}) {

    if ($form->{accounttype} eq 'gifi') {

      $query = qq|SELECT g.accno, c.category, SUM(ac.amount) AS amount,
                  g.description, c.contra
		  FROM acc_trans ac
		  JOIN chart c ON (ac.chart_id = c.id)
		  JOIN gifi g ON (c.gifi_accno = g.accno)
		  $dpt_join
		  WHERE ac.transdate < |.$dbh->quote($form->{fromdate}).qq|
		  AND ac.approved = '1'
		  $dpt_where
		  $project
          $fx_transaction
		  GROUP BY g.accno, c.category, g.description, c.contra
		  |;

    } else {

      $query = qq|SELECT c.accno, c.category, SUM(ac.amount) AS amount,
                  c.description, c.contra,
		  l.description AS translation
		  FROM acc_trans ac
		  JOIN chart c ON (ac.chart_id = c.id)
		  LEFT JOIN translation l ON (l.trans_id = c.id AND l.language_code = |.$dbh->quote($form->{language_code}).qq|)
		  $dpt_join
		  WHERE ac.transdate < |.$dbh->quote($form->{fromdate}).qq|
		  AND ac.approved = '1'
		  $dpt_where
		  $project
          $fx_transaction
		  GROUP BY c.accno, c.category, c.description, c.contra, translation
		  |;

    }

    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
      $ref->{amount} = $form->round_amount($ref->{amount}, $form->{precision8});
      $balance{$ref->{accno}} = $ref->{amount};

      $ref->{description} = $ref->{translation} if $ref->{translation};

      if ($form->{all_accounts}) {
	$trb{$ref->{accno}}{description} = $ref->{description};
	$trb{$ref->{accno}}{charttype} = 'A';
	$trb{$ref->{accno}}{category} = $ref->{category};
	$trb{$ref->{accno}}{contra} = $ref->{contra};
      }

    }
    $sth->finish;

  }


  # get headings
  $query = qq|SELECT c.accno, c.description, c.category,
              l.description AS translation
	      FROM chart c
	      LEFT JOIN translation l ON (l.trans_id = c.id AND l.language_code = |.$dbh->quote($form->{language_code}).qq|)
	      WHERE c.charttype = 'H'
	      ORDER by c.accno|;

  if ($form->{accounttype} eq 'gifi')
  {
    $query = qq|SELECT g.accno, g.description, c.category, c.contra
		FROM gifi g
		JOIN chart c ON (c.gifi_accno = g.accno)
		WHERE c.charttype = 'H'
		ORDER BY g.accno|;
  }

  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while ($ref = $sth->fetchrow_hashref(NAME_lc))
  {
    $ref->{description} = $ref->{translation} if $ref->{translation};

    $trb{$ref->{accno}}{description} = $ref->{description};
    $trb{$ref->{accno}}{charttype} = 'H';
    $trb{$ref->{accno}}{category} = $ref->{category};
    $trb{$ref->{accno}}{contra} = $ref->{contra};

    push @headingaccounts, $ref->{accno};
  }

  $sth->finish;


  if ($form->{fromdate} || $form->{todate}) {
    if ($form->{fromdate}) {
      $where .= " AND ac.transdate >= '".$form->dbclean($form->{fromdate})."'";
      $invwhere .= " AND a.transdate >= '".$form->dbclean($form->{fromdate})."'";
    }
    if ($form->{todate}) {
      $where .= " AND ac.transdate <= '".$form->dbclean($form->{todate})."'";
      $invwhere .= " AND a.transdate <= '".$form->dbclean($form->{todate})."'";
    }
  }


  if ($form->{accounttype} eq 'gifi') {

    $query = qq|SELECT g.accno, g.description, c.category,
                SUM(ac.amount) AS amount, c.contra
		FROM acc_trans ac
		JOIN chart c ON (c.id = ac.chart_id)
		JOIN gifi g ON (c.gifi_accno = g.accno)
		$dpt_join
		WHERE $where
		$dpt_where
		$project
        $fx_transaction
		GROUP BY g.accno, g.description, c.category, c.contra
		ORDER BY accno|;

  } else {

    $query = qq|SELECT c.accno, c.description, c.category,
                SUM(ac.amount) AS amount, c.contra,
		l.description AS translation
		FROM acc_trans ac
		JOIN chart c ON (c.id = ac.chart_id)
		LEFT JOIN translation l ON (l.trans_id = c.id AND l.language_code = |.$dbh->quote($form->{language_code}).qq|)
		$dpt_join
		WHERE $where
		$dpt_where
		$project
        $fx_transaction
		GROUP BY c.accno, c.description, c.category, c.contra, translation
                ORDER BY accno|;

  }

  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  # prepare query for each account
  $query = qq|SELECT (SELECT SUM(ac.amount) * -1
	      FROM acc_trans ac
	      JOIN chart c ON (c.id = ac.chart_id)
	      $dpt_join
	      WHERE $where
	      $dpt_where
	      $project
          $fx_transaction
	      AND ac.amount < 0
	      AND c.accno = ?) AS debit,

	     (SELECT SUM(ac.amount)
	      FROM acc_trans ac
	      JOIN chart c ON (c.id = ac.chart_id)
	      $dpt_join
	      WHERE $where
	      $dpt_where
	      $project
          $fx_transaction
	      AND ac.amount > 0
	      AND c.accno = ?) AS credit
	      |;

  if ($form->{accounttype} eq 'gifi') {

    $query = qq|SELECT (SELECT SUM(ac.amount) * -1
		FROM acc_trans ac
		JOIN chart c ON (c.id = ac.chart_id)
		$dpt_join
		WHERE $where
		$dpt_where
		$project
        $fx_transaction
		AND ac.amount < 0
		AND c.gifi_accno = ?) AS debit,

	       (SELECT SUM(ac.amount)
		FROM acc_trans ac
		JOIN chart c ON (c.id = ac.chart_id)
		$dpt_join
		WHERE $where
		$dpt_where
		$project
        $fx_transaction
		AND ac.amount > 0
		AND c.gifi_accno = ?) AS credit|;

  }

  $drcr = $dbh->prepare($query);

  # calculate debit and credit for the period
  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    $ref->{description} = $ref->{translation} if $ref->{translation};

    $trb{$ref->{accno}}{description} = $ref->{description};
    $trb{$ref->{accno}}{charttype} = 'A';
    $trb{$ref->{accno}}{category} = $ref->{category};
    $trb{$ref->{accno}}{contra} = $ref->{contra};
    $trb{$ref->{accno}}{amount} += $ref->{amount};
  }
  $sth->finish;

  my ($debit, $credit);

  foreach my $accno (sort keys %trb) {
    $ref = ();

    $ref->{accno} = $accno;
    for (qw(description category contra charttype amount)) { $ref->{$_} = $trb{$accno}{$_} }

    $ref->{balance} = $balance{$ref->{accno}};

    if ($trb{$accno}{charttype} eq 'A') {
      if ($project_id) {

        if ($ref->{amount} < 0) {
	  $ref->{debit} = $ref->{amount} * -1;
	} else {
	  $ref->{credit} = $ref->{amount};
	}
	next if $form->round_amount($ref->{amount}, $form->{precision8}) == 0;

      } else {

	# get DR/CR
	$drcr->execute($ref->{accno}, $ref->{accno});

	($debit, $credit) = (0,0);
	while (($debit, $credit) = $drcr->fetchrow_array) {
	  $ref->{debit} += $debit;
	  $ref->{credit} += $credit;
	}
	$drcr->finish;

      }

      $ref->{debit} = $form->round_amount($ref->{debit}, $form->{precision8});
      $ref->{credit} = $form->round_amount($ref->{credit}, $form->{precision8});

      if (!$form->{all_accounts}) {
	next if $form->round_amount($ref->{debit} + $ref->{credit}, $form->{precision8}) == 0;
      }
    }

    # add subtotal
    @accno = grep { $_ le "$ref->{accno}" } @headingaccounts;
    $accno = pop @accno;
    if ($accno) {
      $trb{$accno}{debit} += $ref->{debit};
      $trb{$accno}{credit} += $ref->{credit};
    }

    if ($form->{empty_accounts}) {
       push @{ $form->{TB} }, $ref;
    } else {
        if (($ref->{debit} != 0) or ($ref->{credit} != 0) or ($ref->{balance} != 0)){
           push @{ $form->{TB} }, $ref;
        }
    }
  }

  $dbh->disconnect;

  # debits and credits for headings
  foreach $accno (@headingaccounts) {
    foreach $ref (@{ $form->{TB} }) {
      if ($accno eq $ref->{accno}) {
        $ref->{debit} = $trb{$accno}{debit};
        $ref->{credit} = $trb{$accno}{credit};
      }
    }
  }

}


sub aging {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);
  my $invoice = ($form->{arap} eq 'ar') ? 'is' : 'ir';

  my $query;

  my $item;
  my $curr;

  my %defaults = $form->get_defaults($dbh, \@{[qw(company address businessnumber tel fax precision)]});
  for (keys %defaults) { $form->{$_} = $defaults{$_} }

  $form->{currencies} = $form->get_currencies($dbh, $myconfig);

  ($null, $form->{todate}) = $form->from_to($form->{year}, $form->{month}) if $form->{year} && $form->{month};

  if (! $form->{todate}) {
    $form->{todate} = $form->current_date($myconfig);
  }

  my $where = "a.approved = '1'";
  my $name;
  my $null;
  my $ref;
  my $transdate = ($form->{overdue}) ? "duedate" : "transdate";
  my $openAmountMultiplicator = ($form->{arap} eq 'ar') ? -1 : 1;

  $form->{vc} = 'vendor' if $form->{vc} ne 'customer'; # SQLI protection

  if ($form->{"$form->{vc}_id"}) {
    $where .= qq| AND ct.id = $form->{"$form->{vc}_id"}|;
  } else {
    if ($form->{$form->{vc}} ne "") {
      $name = $form->like(lc $form->{$form->{vc}});
      $where .= qq| AND lower(ct.name) LIKE '$name'|;
    }
    if ($form->{"$form->{vc}number"} ne "") {
      $name = $form->like(lc $form->{"$form->{vc}number"});
      $where .= qq| AND lower(ct.$form->{vc}number) LIKE '$name'|;
    }
  }

  if ($form->{department}) {
    ($null, $department_id) = split /--/, $form->{department};
    $where .= qq| AND a.department_id = |.$form->dbclean($department_id).qq||;
  }

  $form->{sort} =~ s/;//g;
  $form->{sort} = $form->dbclean($form->{sort});
  my $sortorder = ($form->{sort}) ? "ct.$form->{sort}" : "ct.name";

  # select outstanding vendors or customers, depends on $ct
  $paidAmountCheck = 'AND a.paid != a.amount';
  if($form->{payed}){
  	$paidAmountCheck = qq|AND a.amount <> 0 AND (a.paid != a.amount or (a.datepaid is null or a.datepaid > |.$dbh->quote($form->{todate}).qq|))|;
  }
  $query = qq|SELECT DISTINCT ct.id, ct.name, ct.$form->{vc}number,
              ct.language_code
              FROM $form->{vc} ct
	      JOIN $form->{arap} a ON (a.$form->{vc}_id = ct.id)
	      WHERE $where
              |.$paidAmountCheck.qq|
              AND (a.$transdate <= |.$dbh->quote($form->{todate}).qq|)
              ORDER BY $sortorder|;

  my $sth = $dbh->prepare($query);

  $sth->execute || $form->dberror;

  my @ot = ();
  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @ot, $ref;
  }
  $sth->finish;

  my $buysell = ($form->{arap} eq 'ar') ? 'buy' : 'sell';

  my %interval = ( 'Pg' => {
                        'c0' => "(date '".$form->dbclean($form->{todate})."' - interval '0 days')",
			'c15' => "(date '".$form->dbclean($form->{todate})."' - interval '15 days')",
			'c30' => "(date '".$form->dbclean($form->{todate})."' - interval '30 days')",
			'c45' => "(date '".$form->dbclean($form->{todate})."' - interval '45 days')",
			'c60' => "(date '".$form->dbclean($form->{todate})."' - interval '60 days')",
			'c75' => "(date '".$form->dbclean($form->{todate})."' - interval '75 days')",
			'c90' => "(date '".$form->dbclean($form->{todate})."' - interval '90 days')" },
		  'DB2' => {
		        'c0' => "(date ('".$form->dbclean($form->{todate})."') - 0 days)",
			'c15' => "(date ('".$form->dbclean($form->{todate})."') - 15 days)",
			'c30' => "(date ('".$form->dbclean($form->{todate})."') - 30 days)",
			'c45' => "(date ('".$form->dbclean($form->{todate})."') - 45 days)",
			'c60' => "(date ('".$form->dbclean($form->{todate})."') - 60 days)",
			'c75' => "(date ('".$form->dbclean($form->{todate})."') - 75 days)",
			'c90' => "(date ('".$form->dbclean($form->{todate})."') - 90 days)" }
		);

  $interval{Oracle} = $interval{PgPP} = $interval{Pg};

  # for each company that has some stuff outstanding
  $form->{currencies} ||= ":";

  $where = qq|
	a.paid != a.amount
	AND a.approved = '1'
	AND c.id = ?
	AND a.curr = ?|;

  if($form->{payed}){
  	$where = qq|
	a.approved = '1'
	AND ((a.amount = a.paid AND (SELECT MAX(acc.transdate) FROM acc_trans acc WHERE acc.trans_id = a.id) >= |.$dbh->quote($form->{todate}).qq|) OR a.amount <> a.paid OR a.datepaid > |.$dbh->quote($form->{todate}).qq| OR a.datepaid IS NULL)
	AND c.id = ?
	AND a.curr = ?|;
  }

  if ($department_id) {
    $where .= qq| AND a.department_id = |.$form->dbclean($department_id).qq||;
  }

  $query = "";
  my $union = "";

  my %c = (c0 => { flds => '(a.amount - a.paid) AS c0, 0.00 AS c15, 0.00 AS c30, 0.00 AS c45, 0.00 AS c60, 0.00 AS c75, 0.00 AS c90' },
           c15 => { flds => '0.00 AS c0, (a.amount - a.paid) AS c15, 0.00 AS c30, 0.00 AS c45, 0.00 AS c60, 0.00 AS c75, 0.00 AS c90' },
           c30 => { flds => '0.00 AS c0, 0.00 AS c15, (a.amount - a.paid) AS c30, 0.00 AS c45, 0.00 AS c60, 0.00 AS c75, 0.00 AS c90' },
           c45 => { flds => '0.00 AS c0, 0.00 AS c15, 0.00 AS c30, (a.amount - a.paid) AS c45, 0.00 AS c60, 0.00 AS c75, 0.00 AS c90' },
           c60 => { flds => '0.00 AS c0, 0.00 AS c15, 0.00 AS c30, 0.00 AS c45, (a.amount - a.paid) AS c60, 0.00 AS c75, 0.00 AS c90' },
           c75 => { flds => '0.00 AS c0, 0.00 AS c15, 0.00 AS c30, 0.00 AS c45, 0.00 AS c60, (a.amount - a.paid) AS c75, 0.00 AS c90' },
           c90 => { flds => '0.00 AS c0, 0.00 AS c15, 0.00 AS c30, 0.00 AS c45, 0.00 AS c60, 0.00 AS c75, (a.amount - a.paid) AS c90' }
	  );

	  $upperCaseARAP = uc $form->dbclean($form->{arap});
if($form->{payed}){
	$openAmountQuery = qq| round(a.amount::numeric, 2) - round((coalesce((SELECT SUM(ac.amount) FROM acc_trans ac JOIN chart ch ON (ch.id = ac.chart_id) WHERE ac.trans_id = a.id and ac.transdate <= |.$dbh->quote($form->{todate}).qq| AND ac.approved = '1' AND (ch.link LIKE '%|.$upperCaseARAP.qq|_paid%' or ch.id in (select fldvalue::int from defaults where fldname in ('fxgain_accno_id','fxloss_accno_id')))), 0) * |.$openAmountMultiplicator.qq|)::numeric,2)|;
  	 %c = (c0 => { flds => $openAmountQuery.qq| AS c0, 0.00 AS c15, 0.00 AS c30, 0.00 AS c45, 0.00 AS c60, 0.00 AS c75, 0.00 AS c90| },
           c15 => { flds => qq| 0.00 AS c0, |.$openAmountQuery.qq| AS c15, 0.00 AS c30, 0.00 AS c45, 0.00 AS c60, 0.00 AS c75, 0.00 AS c90| },
           c30 => { flds => qq| 0.00 AS c0, 0.00 AS c15, |.$openAmountQuery.qq| AS c30, 0.00 AS c45, 0.00 AS c60, 0.00 AS c75, 0.00 AS c90| },
           c45 => { flds => qq| 0.00 AS c0, 0.00 AS c15, 0.00 AS c30, |.$openAmountQuery.qq| AS c45, 0.00 AS c60, 0.00 AS c75, 0.00 AS c90| },
           c60 => { flds => qq| 0.00 AS c0, 0.00 AS c15, 0.00 AS c30, 0.00 AS c45, |.$openAmountQuery.qq| AS c60, 0.00 AS c75, 0.00 AS c90| },
           c75 => { flds => qq| 0.00 AS c0, 0.00 AS c15, 0.00 AS c30, 0.00 AS c45, 0.00 AS c60, |.$openAmountQuery.qq| AS c75, 0.00 AS c90| },
           c90 => { flds => qq| 0.00 AS c0, 0.00 AS c15, 0.00 AS c30, 0.00 AS c45, 0.00 AS c60, 0.00 AS c75, |.$openAmountQuery.qq| AS c90| }
	  );
  }

  my @c = ();

  for (qw(c0 c15 c30 c45 c45 c60 c75 c90)) {
    if ($form->{$_}) {
      push @c, $_;
    }
  }

  $item = $#c;
  $c{$c[$item]}{and} = qq|AND a.$transdate < $interval{$myconfig->{dbdriver}}{$c[$item]}|;

  if ($item > 0) {
    $c{$c[0]}{and} = qq|
    	  AND (
		  a.$transdate <= $interval{$myconfig->{dbdriver}}{$c[0]}
		  AND a.$transdate >= $interval{$myconfig->{dbdriver}}{$c[1]}
 	      )|;
  }

  for (1 .. $item - 1) {
    $c{$c[$_]}{and} = qq|
    	  AND (
		  a.$transdate < $interval{$myconfig->{dbdriver}}{$c[$_]}
		  AND a.$transdate >= $interval{$myconfig->{dbdriver}}{$c[$_+1]}
 	      )|;
  }

  for (@c) {

    $query .= qq|$union
    SELECT c.id AS vc_id, c.$form->{vc}number, c.name,
    ad.address1, ad.address2, ad.city, ad.state, ad.zipcode, ad.country,
    c.contact, c.email,
    c.phone as $form->{vc}phone, c.fax as $form->{vc}fax,
    c.$form->{vc}number, c.taxnumber as $form->{vc}taxnumber,
    a.description AS invdescription,
    a.invnumber, a.transdate, a.till, a.ordnumber, a.ponumber, a.notes,
    $c{$_}{flds},
    a.duedate, a.invoice, a.id, a.curr,
      (SELECT $buysell FROM exchangerate e
       WHERE a.curr = e.curr
       AND e.transdate = a.transdate) AS exchangerate,
    ct.firstname, ct.lastname, ct.salutation, ct.typeofcontact,
    s.*
    FROM |.$form->dbclean($form->{arap}).qq| a
    JOIN $form->{vc} c ON (a.$form->{vc}_id = c.id)
    JOIN address ad ON (ad.trans_id = c.id)
    LEFT JOIN contact ct ON (ct.trans_id = c.id)
    LEFT JOIN shipto s ON (a.id = s.trans_id)
    WHERE $where
    $c{$_}{and}
|;

    $union = qq|
    UNION
|;
  }

  $query .= qq|

      ORDER BY vc_id, $transdate, invnumber|;

  $sth = $dbh->prepare($query) || $form->dberror($query);

  my @var;

  foreach $curr (split /:/, $form->{currencies}) {

    foreach $item (@ot) {

      @var = ();
      for (@c) { push @var, ($item->{id}, $curr) }

      $sth->execute(@var);

      while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
	$ref->{module} = ($ref->{invoice}) ? $invoice : $form->{arap};
	$ref->{module} = 'ps' if $ref->{till};
	$ref->{exchangerate} ||= 1;
	$ref->{language_code} = $item->{language_code};
	push @{ $form->{AG} }, $ref;
      }
      $sth->finish;

    }
  }

  # get language
  my $query = qq|SELECT *
                 FROM language
		 ORDER BY 2|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{all_language} }, $ref;
  }
  $sth->finish;

  # disconnect
  $dbh->disconnect;

}


sub reminder {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query;

  my $item;
  my $curr;

  my @a = qw(company companyemail companywebsite address address1 address2 city state zip country businessnumber tel fax precision);
  my %defaults = $form->get_defaults($dbh, \@a);
  for (keys %defaults) { $form->{$_} = $defaults{$_} }

  $form->{companyaddress1} = $defaults{address1};
  $form->{companyaddress2} = $defaults{address2};
  $form->{companycity} = $defaults{city};
  $form->{companystate} = $defaults{state};
  $form->{companyzip} = $defaults{zip};
  $form->{companycountry} = $defaults{country};

  $form->{currencies} = $form->get_currencies($dbh, $myconfig);

  my $where = "a.approved = '1'";
  my $name;
  my $null;
  my $ref;

  $form->{vc} = 'vendor' if $form->{vc} ne 'customer'; # SQLI protection

  if ($form->{"$form->{vc}_id"}*=1) {
    $where .= qq| AND vc.id = $form->{"$form->{vc}_id"}|;
  } else {
    if ($form->{$form->{vc}} ne "") {
      $name = $form->like(lc $form->{$form->{vc}});
      $where .= qq| AND lower(vc.name) LIKE '$name'|;
    }
    if ($form->{"$form->{vc}number"} ne "") {
      $name = $form->like(lc $form->{"$form->{vc}number"});
      $where .= qq| AND lower(vc.$form->{vc}number) LIKE '$name'|;
    }
  }

  if ($form->{department}) {
    ($null, $department_id) = split /--/, $form->{department};
    $where .= qq| AND a.department_id = |.$form->dbclean($department_id).qq||;
  }

  $form->{sort} =~ s/;//g;
  $form->{sort} = $form->dbclean($form->{sort});
  my $sortorder = ($form->{sort}) ? "vc.$form->{sort}" : "vc.name";

  # select outstanding customers
  $query = qq|SELECT DISTINCT vc.id, vc.name, vc.$form->{vc}number,
              vc.language_code
              FROM $form->{vc} vc
	      JOIN ar a ON (a.$form->{vc}_id = vc.id)
	      WHERE $where
              AND a.paid != a.amount
              ORDER BY $sortorder|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror;

  my @ot = ();
  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @ot, $ref;
  }
  $sth->finish;

  $query = qq|SELECT s.formname
              FROM status s
	      JOIN ar a ON (a.id = s.trans_id)
	      WHERE s.formname LIKE 'reminder_'
	      AND s.trans_id = ?
	      AND a.curr = ?
	      ORDER BY s.formname DESC|;
  my $rth = $dbh->prepare($query);

  # for each company that has some stuff outstanding
  $form->{currencies} ||= ":";

  $where = qq|
	ROUND(a.paid::NUMERIC, $form->{precision}) != ROUND(a.amount::NUMERIC, $form->{precision})
	AND a.approved = '1'
	AND a.duedate < current_date
	AND c.id = ?
	AND a.curr = ?|;

  if ($department_id) {
    $where .= qq| AND a.department_id = |.$form->dbclean($department_id).qq||;
  }

  if ($form->{overpaid} ne "on") {
	  $where .= qq| AND ((a.amount > 0 AND a.paid < a.amount) OR (a.amount < 0 AND a.paid > a.amount))|;
  }

  $exclude_credits = 'AND a.amount > 0' if $form->{exclude_credits};
  $query = qq|SELECT c.id AS vc_id, c.$form->{vc}number, c.name, c.terms,
              ad.address1, ad.address2, ad.city, ad.state, ad.zipcode, ad.country,
	      c.contact, c.email,
	      c.phone as $form->{vc}phone, c.fax as $form->{vc}fax,
	      c.$form->{vc}number, c.taxnumber as $form->{vc}taxnumber,
	      a.description AS invdescription, a.shippingpoint, a.shipvia, a.waybill,
	      a.invnumber, a.transdate, a.till, a.ordnumber, a.ponumber, a.notes,
	      a.amount - a.paid AS due,
	      a.duedate, a.invoice, a.id, a.curr,
		(SELECT exchangerate FROM exchangerate e
		 WHERE a.curr = e.curr
		 AND e.transdate = a.transdate) AS exchangerate,
	      ct.firstname, ct.lastname, ct.salutation, ct.typeofcontact,
	      current_date - a.duedate duedays,
	      s.*,
          bank.name bankname, bank.iban, bank.bic bankbic,
          bank.dcn, bank.rvc, bank.membernumber,
          bank.qriban, bank.strdbkginf, bank.invdescriptionqr,
          ad2.address1 bankaddress1, ad2.address2 bankaddress2, ad2.city bankcity,
          ad2.state bankstate, ad2.zipcode bankzipcode, ad2.country bankcountry
	      FROM ar a
	      JOIN $form->{vc} c ON (a.$form->{vc}_id = c.id)
	      JOIN address ad ON (ad.trans_id = c.id)
	      LEFT JOIN contact ct ON (ct.trans_id = c.id)
	      LEFT JOIN shipto s ON (a.id = s.trans_id)
          LEFT JOIN bank ON (bank.id = a.bank_id)
          LEFT JOIN address ad2 ON (ad2.trans_id = bank.id)
	      WHERE a.duedate <= '$form->{duedateto}'
	      AND $where
	      $exclude_credits
	      ORDER BY vc_id, transdate, invnumber|;
  $sth = $dbh->prepare($query) || $form->dberror($query);

  $form->{AG} = ();

  for $curr (split /:/, $form->{currencies}) {

    for $item (@ot) {

      $sth->execute($item->{id}, $curr);

      while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
		$ref->{module} = ($ref->{invoice}) ? 'is' : 'ar';
		$ref->{module} = 'ps' if $ref->{till};
		$ref->{exchangerate} ||= 1;
		$ref->{language_code} = $item->{language_code};
	    $form->{terms} = $ref->{terms};
	

		# conversion to QR variables ("%" needs to be removed from all variables since it breaks the print, See #112443)
		# taken from IS.pm / line 689 / method invoice_details() (to good someone made small and comprehensive sub methods and its not just one huge fucking piece of code!)
	    $form->{invnumber} = $ref->{invnumber};
		$form->{invnumber} = substr($form->{invnumber}, 0, 24);
		$form->{invnumber} = $form->string_replace($form->{invnumber}, "%", "");
		$form->{invnumber} = $form->string_replace($form->{invnumber}, "/", ""); # QR Standard requires "/" to be escaped. We just remove it ("/" is rarely used) (See #112446)
		$form->{invnumber} = $form->string_replace($form->{invnumber}, "\Q\\\E", ""); # QR Standard requires "\" to be escaped. We just remove it ("/" is rarely used) ("\Q\\\E" is the escaped regex for "\") (See #112446)
		$form->{invnumberqr} = $form->{invnumber};
		
		# QR-Codes needs to be the same as in Debitoren-Modul (as it works in Debitoren-Modul). This variable is not filled in Debitoren-Modul, thats why commented out here.
		#$form->{invdescription} = $ref->{invdescription};
		#$form->{invdescriptionqr} = $form->format_line($myconfig, $form->{invdescription});
		#$form->{invdescriptionqr} = $form->string_replace($form->{invdescriptionqr}, "%", "");
		#$form->{invdescriptionqr} = $form->string_abbreviate($form->{invdescriptionqr}, 55); # abbrevate with ... because of QR Standard (See #112445)
		#$form->{invdescriptionqr2} = $form->{invdescriptionqr};
		
		$form->{qriban} = $ref->{qriban};
		$form->{qribanqr} = $form->{qriban};
		$form->{qribanqr} =~ s/\s//g;
		$form->{qribanqr} = $form->string_replace($form->{qribanqr}, "%", "");

		$form->{companyqr} = substr($form->{company},0,70);
		$form->{companyqr} = $form->string_replace($form->{companyqr}, "%", "");
		
		$form->{companyaddress1qr} = substr($form->{address1},0,70);
		$form->{companyaddress1qr} = $form->string_replace($form->{companyaddress1qr}, "%", "");
		
		$form->{companyzipqr} = substr($form->{zip},0,16);
		$form->{companyzipqr} = $form->string_replace($form->{companyzipqr}, "%", "");
		
		$form->{companycityqr} = substr($form->{city},0,35);
		$form->{companycityqr} = $form->string_replace($form->{companycityqr}, "%", "");
		
		$form->{nameqr} = substr($ref->{name},0,70);
		$form->{nameqr} = $form->string_replace($form->{nameqr}, "%", "");
		
		$form->{address1qr} = substr($ref->{address1},0,70);
		$form->{address1qr} = $form->string_replace($form->{address1qr}, "%", "");
		
		$form->{zipcodeqr}  = substr($ref->{zipcode},0,16);
		$form->{zipcodeqr} = $form->string_replace($form->{zipcodeqr}, "%", "");
		
		$form->{cityqr} = substr($ref->{city},0,35);
		$form->{cityqr} = $form->string_replace($form->{cityqr}, "%", "");
		
		my @nums = $form->{businessnumber} =~ /(\d+)/g;
		for (@nums) { $form->{businessnumberqr} .= $_ };
		
		$form->{swicotaxbaseqr}  = $form->{swicotaxbase};
		$form->{swicotaxbaseqr} = $form->string_replace($form->{swicotaxbaseqr}, "%", "");
		
		$form->{swicotaxqr}  = $form->{swicotax};
		$form->{swicotaxqr} = $form->string_replace($form->{swicotaxqr}, "%", "");
		
		@taxaccounts = split (/ /, $form->{taxaccounts}); 
		
		for (@taxaccounts) {
			if ($form->{"${_}_rate"}) {
			    #$rate = $form->parse_amount($myconfig, $form->{"${_}_rate"});
			    $rate = $form->{"${_}_rate"};
			    $taxbase = $form->parse_amount($myconfig, $form->{"${_}_taxbase"});
			    $taxbase *= 1;
			    $tax = $form->round_amount(($rate * $taxbase)/100,2);
			    $rate *= 100;
			    if ($taxbase){
			      $form->{swicotaxbaseqr} .= qq|$rate:$taxbase;|;
			    }
			}
		}
	
		chop $form->{swicotaxbaseqr};
		
		$form->{invdate} = $ref->{transdate};
		$form->{invdateqr}  = substr($form->datetonum($myconfig, $form->{invdate}),2);
		$form->{invdateqr} = $form->string_replace($form->{invdateqr}, "%", "");
		
		$form->{strdbkginf} = $form->format_line($myconfig, $ref->{strdbkginf});
		$form->{strdbkginf}  = substr($form->{strdbkginf}, 0, 85); # abbrevate to maximum length allowed by the QR Standard.
		$form->{strdbkginf} = $form->string_replace($form->{strdbkginf}, "%", "");
		$form->{strdbkginfqr} = $form->{strdbkginf};
		
		# split strdbkginfqr into 2 lines, since doing this in latex causes display issues for special characters such as "_" (See #112444)
		$form->{strdbkginfline1qr} = substr($form->{strdbkginfqr}, 0, 50);
		$form->{strdbkginfline2qr} = substr($form->{strdbkginfqr}, 50, 85);


		# Here in the Mahnmodul, I'm not sure which variables are taken from $from and which from $ref so I just make all variables available in both. Seems to work...
		$ref->{terms} = $form->{terms};
		$ref->{invnumber} = $form->{invnumber};
		$ref->{invnumberqr} = $form->{invnumberqr};
		$ref->{invdescription} = $form->{invdescription};
		$ref->{invdescriptionqr} = $form->{invdescriptionqr};
		$ref->{invdescriptionqr2} = $form->{invdescriptionqr2};
		$ref->{qriban} = $form->{qriban};
		$ref->{qribanqr} = $form->{qribanqr};
		$ref->{companyqr} = $form->{companyqr};
		$ref->{companyaddress1qr} = $form->{companyaddress1qr};
		$ref->{companyzipqr} = $form->{companyzipqr};
		$ref->{companycityqr} = $form->{companycityqr};
		$ref->{nameqr} = $form->{nameqr};
		$ref->{address1qr} = $form->{address1qr};
		$ref->{zipcodeqr} = $form->{zipcodeqr};
		$ref->{cityqr} = $form->{cityqr};
		$ref->{businessnumber} = $form->{businessnumber};
		$ref->{businessnumberqr} = $form->{businessnumberqr};
		$ref->{swicotaxbaseqr} = $form->{swicotaxbaseqr};
		$ref->{swicotaxqr} = $form->{swicotaxqr};
		$ref->{invdate} = $form->{invdate};
		$ref->{invdateqr} = $form->{invdateqr};
		$ref->{strdbkginf} = $form->{strdbkginf};
		$ref->{strdbkginfqr} = $form->{strdbkginfqr};
		$ref->{strdbkginfline1qr} = $form->{strdbkginfline1qr};
		$ref->{strdbkginfline2qr} = $form->{strdbkginfline2qr};

	
	    ($whole, $decimal) = split /\./, $ref->{due};
	    $ref->{out_decimal} = substr("${decimal}00", 0, 2);
	    $ref->{integer_out_amount} = $whole;
	
		$rth->execute($ref->{id}, $curr);
		$found = 0;
		while (($reminder) = $rth->fetchrow_array) {
		  $ref->{level} = substr($reminder, -1);
		  $ref->{level}++;
		  push @{ $form->{AG} }, $ref;
		  $found = 1;
		}
		$rth->finish;
	
	        if (! $found) {
		  $ref->{level}++;
	
		  push @{ $form->{AG} }, $ref;
		}
      }
      $sth->finish;
    }

  }

  #$form->info("<pre>"); for my $row (@{$form->{AG}}){ for (qw(invnumber bankname qriban strdbkginf invoicedescriptionqr)) { print "$_: $row->{$_}\n" } print "\n\n" }

  # get language
  $form->all_languages($myconfig, $dbh);

  # disconnect
  $dbh->disconnect;

}


sub save_level {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect_noauto($myconfig);

  my $query;

  $query = qq|DELETE FROM status
              WHERE trans_id = ?
	      AND formname LIKE 'reminder_'|;
  my $dth = $dbh->prepare($query) || $form->dberror($query);

  $query = qq|INSERT INTO status (trans_id, formname)
              VALUES (?,?)|;
  my $ath = $dbh->prepare($query) || $form->dberror($query);

  ($null, $form->{employee_id}) = $form->get_employee($dbh);

  # Record change of reminder level in audittrail table
  $query = qq|INSERT INTO audittrail
		(trans_id, tablename, reference,
		formname, action, employee_id)
	      VALUES (
		?, 'ar', ?,
		'reminder', 'level-change', |.$form->dbclean($form->{employee_id}).qq|
	      )|;
  my $tth = $dbh->prepare($query) || $form->dberror($query);

  for (split / /, $form->{ids}) {
    if ($form->{"ndx_$_"}) {

      $dth->execute($_) || $form->dberror;
      $dth->finish;

      if ($form->{"level_$_"} *= 1) {
	$ath->execute($_, qq|reminder$form->{"level_$_"}|) || $form->dberror;
	$ath->finish;
        $tth->execute($_, $form->{"level_$_"});
	$tth->finish;
      }
    }
  }

  my $rc = $dbh->commit;

  $dbh->disconnect;

  $rc;

}


sub get_customer {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  $form->{vc} = 'vendor' if $form->{vc} ne 'customer'; # SQLI protection

  my $query = qq|SELECT name, email, cc, bcc
                 FROM $form->{vc} ct
		 WHERE ct.id = |.$form->dbclean($form->{"$form->{vc}_id"}).qq||;
  ($form->{$form->{vc}}, $form->{email}, $form->{cc}, $form->{bcc}) = $dbh->selectrow_array($query);

  $dbh->disconnect;

}


sub get_taxaccounts {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);
  my $ARAP = uc $form->{db};

  # get tax accounts
  my $query = qq|SELECT DISTINCT c.accno, c.description,
                 l.description AS translation
                 FROM chart c
		 JOIN tax t ON (c.id = t.chart_id)
		 LEFT JOIN translation l ON (l.trans_id = c.id AND l.language_code = '$myconfig->{countrycode}')
		 WHERE c.link LIKE '%|.$form->dbclean(${ARAP}).qq|_tax%'
                 ORDER BY c.accno|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror;

  my $ref = ();
  while ($ref = $sth->fetchrow_hashref(NAME_lc) ) {
    push @{ $form->{taxaccounts} }, $ref;
  }
  $sth->finish;

  # get gifi tax accounts
  my $query = qq|SELECT DISTINCT g.accno, g.description
                 FROM gifi g
		 JOIN chart c ON (c.gifi_accno= g.accno)
		 JOIN tax t ON (c.id = t.chart_id)
		 WHERE c.link LIKE '%|.$form->dbclean(${ARAP}).qq|_tax%'
                 ORDER BY accno|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror;

  while ($ref = $sth->fetchrow_hashref(NAME_lc) ) {
    push @{ $form->{gifi_taxaccounts} }, $ref;
  }
  $sth->finish;

  $dbh->disconnect;

}



sub tax_report {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my ($null, $department_id) = split /--/, $form->{department};

  # build WHERE
  my $where = "a.approved = '1'";
  my $cashwhere = "";

  my %defaults = $form->get_defaults($dbh, \@{['precision', 'company']});
  for (keys %defaults) { $form->{$_} = $defaults{$_} }

  if ($department_id) {
    $where .= qq|
                 AND a.department_id = |.$form->dbclean($department_id).qq|
		|;
  }

  my $query;
  my $sth;
  my $accno;

  if ($form->{accno}) {
    if ($form->{accno} =~ /^gifi_/) {
      ($null, $accno) = split /_/, $form->{accno};
      $accno = qq| AND ch.gifi_accno = |.$dbh->quote($accno).qq||;
    } else {
      $accno = $form->{accno};
      $accno = qq| AND ch.accno = |.$dbh->quote($accno).qq||;
    }
  }

  my $vc;
  my $ARAP;

  # SQLI protection: $form->{db} needs to be validated.
  $form->{db} = $form->dbclean($form->{db});
  if ($form->{db} eq 'ar') {
    $vc = "customer";
    $ARAP = "AR";
  }
  if ($form->{db} eq 'ap') {
    $vc = "vendor";
    $ARAP = "AP";
  }

  my $transdate = "a.transdate";

  ($form->{fromdate}, $form->{todate}) = $form->from_to($form->{year}, $form->{month}, $form->{interval}) if $form->{year} && $form->{month};

  # if there are any dates construct a where
  if ($form->{fromdate} || $form->{todate}) {
    if ($form->{fromdate}) {
      $where .= " AND $transdate >= '".$form->dbclean($form->{fromdate})."'";
    }
    if ($form->{todate}) {
      $where .= " AND $transdate <= '".$form->dbclean($form->{todate})."'";
    }
  }


  if ($form->{method} eq 'cash') {
    $transdate = "a.datepaid";

    my $todate = $form->{todate};
    if (! $todate) {
      $todate = $form->current_date($myconfig);
    }

    $cashwhere = qq|
		 AND ac.trans_id IN
		   (
		     SELECT trans_id
		     FROM acc_trans
		     JOIN chart ON (chart_id = chart.id)
		     WHERE link LIKE '%${ARAP}_paid%'
		     AND a.approved = '1'
		     AND $transdate <= |.$dbh->quote($todate).qq|
		     AND a.paid = a.amount
		   )
		  |;

  }


  my $ml = ($form->{db} eq 'ar') ? 1 : -1;

  my %ordinal = ( 'transdate' => 3,
                  'invnumber' => 4,
		  'name' => 5,
		  "${vc}number" => 6,
		  'description' => 8
		);

  my @a = qw(transdate invnumber name);
  my $sortorder = $form->sort_order(\@a, \%ordinal);

  if ($form->{summary}) {

    $query = qq|SELECT a.id, a.invoice, $transdate AS transdate,
		a.invnumber, n.name, n.${vc}number, a.netamount,
		a.description,
		sum(ac.amount) * $ml AS tax,
		a.till, n.id AS vc_id
		FROM acc_trans ac
	      JOIN $form->{db} a ON (a.id = ac.trans_id)
	      JOIN chart ch ON (ch.id = ac.chart_id)
	      JOIN $vc n ON (n.id = a.${vc}_id)
		WHERE $where
		$accno
		$cashwhere
	GROUP BY a.id, a.invoice, $transdate, a.invnumber, n.name,
	a.netamount, a.till, n.id, a.description, n.${vc}number
		|;

      if ($form->{fromdate}) {
	# include open transactions from previous period
	if ($cashwhere) {
	  $query .= qq|
              UNION

                SELECT a.id, a.invoice, $transdate AS transdate,
		a.invnumber, n.name, n.${vc}number, a.netamount,
		a.description,
		sum(ac.amount) * $ml AS tax,
		a.till, n.id AS vc_id
		FROM acc_trans ac
	      JOIN $form->{db} a ON (a.id = ac.trans_id)
	      JOIN chart ch ON (ch.id = ac.chart_id)
	      JOIN $vc n ON (n.id = a.${vc}_id)
		WHERE a.datepaid >= |.$dbh->quote($form->{fromdate}).qq|
		$accno
		$cashwhere
	GROUP BY a.id, a.invoice, $transdate, a.invnumber, n.name,
	a.netamount, a.till, n.id, a.description, n.${vc}number
		|;
	}
      }


    } else {

     $query = qq|SELECT a.id, '0' AS invoice, $transdate AS transdate,
		a.invnumber, n.name, n.${vc}number, a.netamount,
		ac.memo AS description,
		ac.amount * $ml AS tax,
		a.till, n.id AS vc_id
		FROM acc_trans ac
	      JOIN $form->{db} a ON (a.id = ac.trans_id)
	      JOIN chart ch ON (ch.id = ac.chart_id)
	      JOIN $vc n ON (n.id = a.${vc}_id)
		WHERE $where
		$accno
		AND a.invoice = '0'
		AND NOT (ch.link LIKE '%_paid' OR ch.link = '$ARAP')
		$cashwhere

	      UNION ALL

		SELECT a.id, '1' AS invoice, $transdate AS transdate,
		a.invnumber, n.name, n.${vc}number,
		i.sellprice * i.qty * $ml * (1 - i.discount) AS netamount,
		i.description,
		i.sellprice * i.qty * $ml * (1 - i.discount) *
		(SELECT tx.rate FROM tax tx WHERE tx.chart_id = ch.id AND (tx.validto > $transdate OR tx.validto IS NULL) ORDER BY validto LIMIT 1) AS tax,
		a.till, n.id AS vc_id
		FROM acc_trans ac
	      JOIN $form->{db} a ON (a.id = ac.trans_id)
	      JOIN chart ch ON (ch.id = ac.chart_id)
	      JOIN $vc n ON (n.id = a.${vc}_id)
	      JOIN ${vc}tax t ON (t.${vc}_id = n.id AND t.chart_id = ch.id)
	      JOIN invoice i ON (i.trans_id = a.id)
	      JOIN partstax pt ON (pt.parts_id = i.parts_id AND pt.chart_id = ch.id)
		WHERE $where
		$accno
		AND a.invoice = '1'
		$cashwhere
		|;

      if ($form->{fromdate}) {
	if ($cashwhere) {
	 $query .= qq|
	      UNION

	        SELECT a.id, '0' AS invoice, $transdate AS transdate,
		a.invnumber, n.name, n.${vc}number, a.netamount,
		ac.memo AS description,
		ac.amount * $ml AS tax,
		a.till, n.id AS vc_id
		FROM acc_trans ac
	      JOIN $form->{db} a ON (a.id = ac.trans_id)
	      JOIN chart ch ON (ch.id = ac.chart_id)
	      JOIN $vc n ON (n.id = a.${vc}_id)
		WHERE a.datepaid >= '$form->{fromdate}'
		$accno
		AND a.invoice = '0'
		AND NOT (ch.link LIKE '%_paid' OR ch.link = '$ARAP')
		$cashwhere

	      UNION

		SELECT a.id, '1' AS invoice, $transdate AS transdate,
		a.invnumber, n.name, n.${vc}number,
		i.sellprice * i.qty * $ml * (1 - i.discount) AS netamount,
		i.description,
		i.sellprice * i.qty * $ml * (1 - i.discount) *
		(SELECT tx.rate FROM tax tx WHERE tx.chart_id = ch.id AND (tx.validto > $transdate OR tx.validto IS NULL) ORDER BY validto LIMIT 1) AS tax,
		a.till, n.id AS vc_id
		FROM acc_trans ac
	      JOIN $form->{db} a ON (a.id = ac.trans_id)
	      JOIN chart ch ON (ch.id = ac.chart_id)
	      JOIN $vc n ON (n.id = a.${vc}_id)
	      JOIN ${vc}tax t ON (t.${vc}_id = n.id AND t.chart_id = ch.id)
	      JOIN invoice i ON (i.trans_id = a.id)
	      JOIN partstax pt ON (pt.parts_id = i.parts_id AND pt.chart_id = ch.id)
		WHERE a.datepaid >= |.$dbh->quote($form->{fromdate}).qq|
		$accno
		AND a.invoice = '1'
		$cashwhere
		|;
	}
      }
    }


  if ($form->{report} =~ /nontaxable/) {

    if ($form->{summary}) {
      # only gather up non-taxable transactions
      $query = qq|SELECT DISTINCT a.id, a.invoice, $transdate AS transdate,
		  a.invnumber, n.name, n.${vc}number, a.netamount,
		  a.description,
		  a.till, n.id AS vc_id
		  FROM acc_trans ac
		JOIN $form->{db} a ON (a.id = ac.trans_id)
		JOIN $vc n ON (n.id = a.${vc}_id)
		  WHERE $where
		  AND a.netamount = a.amount
		  $cashwhere
		  |;

      if ($form->{fromdate}) {
	if ($cashwhere) {
	  $query .= qq|
                UNION

                  SELECT DISTINCT a.id, a.invoice, $transdate AS transdate,
		  a.invnumber, n.name, n.${vc}number, a.netamount,
		  a.description,
		  a.till, n.id AS vc_id
		  FROM acc_trans ac
		JOIN $form->{db} a ON (a.id = ac.trans_id)
		JOIN $vc n ON (n.id = a.${vc}_id)
		WHERE a.datepaid >= |.$dbh->quote($form->{fromdate}).qq|
		  AND a.netamount = a.amount
		  $cashwhere
		  |;
	}
      }

    } else {

      # gather up details for non-taxable transactions
      $query = qq|SELECT a.id, '0' AS invoice, $transdate AS transdate,
		  a.invnumber, n.name, n.${vc}number,
		  ac.amount * $ml AS netamount,
		  ac.memo AS description,
		  a.till, n.id AS vc_id
		  FROM acc_trans ac
		JOIN $form->{db} a ON (a.id = ac.trans_id)
		JOIN $vc n ON (n.id = a.${vc}_id)
		JOIN chart ch ON (ch.id = ac.chart_id)
		  WHERE $where
		  AND a.invoice = '0'
		  AND a.netamount = a.amount
		  AND NOT (ch.link LIKE '%_paid' OR ch.link = '$ARAP')
		  $cashwhere
		GROUP BY a.id, $transdate, a.invnumber, n.name, ac.amount,
		ac.memo, a.till, n.id, n.${vc}number

		UNION ALL

		  SELECT a.id, '1' AS invoice, $transdate AS transdate,
		  a.invnumber, n.name, n.${vc}number,
		  sum(ac.sellprice * ac.qty * (1 - ac.discount)) * $ml AS netamount,
		  ac.description,
		  a.till, n.id AS vc_id
		  FROM invoice ac
		JOIN $form->{db} a ON (a.id = ac.trans_id)
		JOIN $vc n ON (n.id = a.${vc}_id)
		  WHERE $where
		  AND a.invoice = '1'
		  AND (
		    a.${vc}_id NOT IN (
			  SELECT ${vc}_id FROM ${vc}tax t (${vc}_id)
					 ) OR
		    ac.parts_id NOT IN (
			  SELECT parts_id FROM partstax p (parts_id)
				      )
		      )
		  $cashwhere
		  GROUP BY a.id, a.invnumber, $transdate, n.name,
		  ac.description, a.till, n.id, n.${vc}number
		  |;

      if ($form->{fromdate}) {
	if ($cashwhere) {
	  $query .= qq|
                UNION

                  SELECT a.id, '0' AS invoice, $transdate AS transdate,
		  a.invnumber, n.name, n.${vc}number, a.netamount,
		  ac.memo AS description,
		  a.till, n.id AS vc_id
		  FROM acc_trans ac
		JOIN $form->{db} a ON (a.id = ac.trans_id)
		JOIN $vc n ON (n.id = a.${vc}_id)
		JOIN chart ch ON (ch.id = ac.chart_id)
		  WHERE a.datepaid >= |.$dbh->quote($form->{fromdate}).qq|
		  AND a.invoice = '0'
		  AND a.netamount = a.amount
		  AND NOT (ch.link LIKE '%_paid' OR ch.link = '$ARAP')
		  $cashwhere
		GROUP BY a.id, $transdate, a.invnumber, n.name, a.netamount,
		ac.memo, a.till, n.id, n.${vc}number

		UNION

		  SELECT a.id, '1' AS invoice, $transdate AS transdate,
		  a.invnumber, n.name, n.${vc}number,
		  sum(ac.sellprice * ac.qty * (1 - ac.discount)) * $ml AS netamount,
		  ac.description,
		  a.till, n.id AS vc_id
		  FROM invoice ac
		JOIN $form->{db} a ON (a.id = ac.trans_id)
		JOIN $vc n ON (n.id = a.${vc}_id)
		  WHERE a.datepaid >= |.$dbh->quote($form->{fromdate}).qq|
		  AND a.invoice = '1'
		  AND (
		    a.${vc}_id NOT IN (
			  SELECT ${vc}_id FROM ${vc}tax t (${vc}_id)
					 ) OR
		    ac.parts_id NOT IN (
			  SELECT parts_id FROM partstax p (parts_id)
				      )
		      )
		  $cashwhere
		  GROUP BY a.id, a.invnumber, $transdate, n.name,
		  ac.description, a.till, n.id, n.${vc}number
		  |;
	}
      }

    }
  }


  $query .= qq|
	      ORDER by $sortorder|;

  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while ( my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    $ref->{tax} = $form->round_amount($ref->{tax}, $form->{precision});
    if ($form->{report} =~ /nontaxable/) {
      push @{ $form->{TR} }, $ref if $ref->{netamount};
    } else {
      push @{ $form->{TR} }, $ref; # Removed if $ref->{tax} to show 0 taxes
    }
  }

  $sth->finish;
  $dbh->disconnect;

}


sub paymentaccounts {
  my ($self, $myconfig, $form) = @_;

  # connect to database, turn AutoCommit off
  my $dbh = $form->dbconnect_noauto($myconfig);

  my $ARAP = uc $form->{db};

  # get A(R|P)_paid accounts
  my $query = qq|SELECT c.accno, c.description,
                 l.description AS translation
                 FROM chart c
		 LEFT JOIN translation l ON (l.trans_id = c.id AND l.language_code = '$myconfig->{countrycode}')
                 WHERE c.link LIKE '%|.$form->dbclean(${ARAP}).qq|_paid%'
		 ORDER BY c.accno|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    $ref->{description} = $ref->{translation} if $ref->{translation};
    push @{ $form->{PR} }, $ref;
  }
  $sth->finish;

  $form->all_years($myconfig, $dbh);

  $dbh->disconnect;

}


sub payments {
  my ($self, $myconfig, $form) = @_;

  # connect to database, turn AutoCommit off
  my $dbh = $form->dbconnect_noauto($myconfig);

  my $ml = ($form->{db} eq 'ar') ? -1 : 1;
  my $query;
  my $sth;
  my $dpt_join;
  my $where = "1 = 1";
  my $var;
  my $arapwhere;
  my $gl = ($form->{till} eq "");

  my %defaults = $form->get_defaults($dbh, \@{['precision', 'company']});
  for (keys %defaults) { $form->{$_} = $defaults{$_} }

  if ($form->{department_id}) {
    $dpt_join = qq|
	         JOIN dpt_trans t ON (t.trans_id = ac.trans_id)
		 |;

    $where .= qq|
		 AND t.department_id = |.$form->dbclean($form->{department_id}).qq|
		|;
  }

  ($form->{fromdate}, $form->{todate}) = $form->from_to($form->{year}, $form->{month}, $form->{interval}) if $form->{year} && $form->{month};

  if ($form->{fromdate}) {
    $where .= " AND ac.transdate >= '".$form->dbclean($form->{fromdate})."'";
  }
  if ($form->{todate}) {
    $where .= " AND ac.transdate <= '".$form->dbclean($form->{todate})."'";
  }
  if (!$form->{fx_transaction}) {
    $where .= " AND ac.fx_transaction = '0'";
  }

  if ($form->{description} ne "") {
    $var = $form->like(lc $form->{description});
    $where .= " AND lower(a.description) LIKE '$var'";
  }
  if ($form->{source} ne "") {
    $var = $form->like(lc $form->{source});
    $where .= " AND lower(ac.source) LIKE '$var'";
  }
  if ($form->{memo} ne "") {
    $var = $form->like(lc $form->{memo});
    $where .= " AND lower(ac.memo) LIKE '$var'";
  }
  if ($form->{"$form->{vc}number"} ne "") {
    $var = $form->like(lc $form->{"$form->{vc}number"});
    $where .= " AND lower(c.$form->{vc}number) LIKE '$var'";
    $gl = 0;
  }
  if ($form->{$form->{vc}} ne "") {
    $var = $form->like(lc $form->{$form->{vc}});
    $where .= " AND lower(c.name) LIKE '$var'";
    $gl = 0;
  }


  my %ordinal = ( 'description' => 1,
                  'name' => 2,
		  'transdate' => 3,
		  'source' => 5,
		  'employee' => 7,
		  'till' => 8,
		  'customernumber' => 14,
		  'vendornumber' => 14,
		  'reference' => 15,
		  'variance' => 16
		);

  my @a = qw(name transdate employee);
  my $sortorder = $form->sort_order(\@a, \%ordinal);

  # cycle through each id
  foreach my $accno (split(/ /, $form->{paymentaccounts})) {

    $query = qq|SELECT c.id, c.accno, c.description,
                l.description AS translation
                FROM chart c
		LEFT JOIN translation l ON (l.trans_id = c.id AND l.language_code = '$myconfig->{countrycode}')
		WHERE c.accno = '$accno'|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    my $ref = $sth->fetchrow_hashref(NAME_lc);
    $ref->{description} = $ref->{translation} if $ref->{translation};
    push @{ $form->{PR} }, $ref;
    $sth->finish;

    $query = qq|SELECT a.description, c.name, ac.transdate,
                sum(ac.amount) * $ml AS paid,
                ac.source, ac.memo, e.name AS employee, a.till, a.curr,
		'$form->{db}' AS module, ac.trans_id, c.id AS vcid, a.invoice,
		c.$form->{vc}number, a.invnumber AS reference, (-1)*(a.duedate - ac.transdate) as variance
		FROM acc_trans ac
	        JOIN $form->{db} a ON (ac.trans_id = a.id)
	        JOIN $form->{vc} c ON (c.id = a.$form->{vc}_id)
		LEFT JOIN employee e ON (a.employee_id = e.id)
	        $dpt_join
		WHERE $where
		AND ac.chart_id = $ref->{id}
		AND ac.approved = '1'|;

    if ($form->{till} ne "") {
      $query .= " AND a.invoice = '1'
                  AND NOT a.till IS NULL";

      if ($myconfig->{role} eq 'user') {
	$query .= " AND e.login = '$form->{login}'";
      }
    }

    $query .= qq|
                GROUP BY a.description, c.name, ac.transdate, ac.source,
		ac.memo, e.name, a.till, a.curr, ac.trans_id, c.id, a.invoice,
		c.$form->{vc}number, a.invnumber, variance
		|;

    if ($gl) {
      # don't need gl for a till or if there is a name

      $query .= qq|
 	UNION ALL
		SELECT a.description, '' AS name, ac.transdate,
		sum(ac.amount) * $ml AS paid, ac.source,
		ac.memo, e.name AS employee, '' AS till, '' AS curr,
		'gl' AS module, ac.trans_id, '0' AS vcid, '0' AS invoice,
		'' AS $form->{vc}number, a.reference, 0 as variance
		FROM acc_trans ac
	        JOIN gl a ON (a.id = ac.trans_id)
		LEFT JOIN employee e ON (a.employee_id = e.id)
	        $dpt_join
		WHERE $where
		AND ac.chart_id = $ref->{id}
		AND a.approved = '1'
		AND (ac.amount * $ml) > 0
	GROUP BY a.description, ac.transdate, ac.source, ac.memo, e.name,
	        ac.trans_id, a.reference, variance
		|;

    }

    $query .= qq|
                ORDER BY $sortorder|;

    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    while (my $pr = $sth->fetchrow_hashref(NAME_lc)) {
      push @{ $form->{$ref->{id}} }, $pr;
    }
    $sth->finish;

  }

  $dbh->disconnect;

}


1;


