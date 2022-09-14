#=====================================================================
# SQL-Ledger ERP
# Copyright (C) 2006
#
#  Author: DWS Systems Inc.
#     Web: http://www.sql-ledger.com
#
#======================================================================
#
# General ledger backend code
#
#======================================================================

package GL;


sub delete_transaction {
  my ($self, $myconfig, $form) = @_;
  
  # connect to database
  my $dbh = $form->dbconnect_noauto($myconfig);
  
  $form->{id} *= 1;

  my %defaults = $form->get_defaults($dbh, \@{['precision', 'extendedlog']});

  if ($form->{id} and $defaults{extendedlog}) {
     $query = qq|INSERT INTO gl_log_deleted SELECT * FROM gl WHERE id = $form->{id}|;
     $dbh->do($query) || $form->dberror($query);

     $query = qq|
        INSERT INTO acc_trans_log_deleted (
            trans_id, chart_id, 
            amount, transdate, source,
            approved, fx_transaction, project_id,
            memo, id, cleared,
            vr_id, entry_id,
            tax, taxamount, tax_chart_id,
            ts
            )
        SELECT 
            ac.trans_id, ac.chart_id, 
            ac.amount, ac.transdate, ac.source,
            ac.approved, ac.fx_transaction, ac.project_id,
            ac.memo, ac.id, ac.cleared,
            vr_id, ac.entry_id,
            ac.tax, ac.taxamount, ac.tax_chart_id,
            ts 
        FROM acc_trans ac
        JOIN gl ON (gl.id = ac.trans_id)
        WHERE trans_id = $form->{id}|;
     $dbh->do($query) || $form->dberror($query);


     $query = qq|
        INSERT INTO acc_trans_log_deleted (
            trans_id, chart_id, 
            amount, transdate, source,
            approved, fx_transaction, project_id,
            memo, id, cleared,
            vr_id, entry_id,
            tax, taxamount, tax_chart_id,
            ts
            )
        SELECT 
            ac.trans_id, ac.chart_id, 
            0 - ac.amount, ac.transdate, ac.source,
            ac.approved, ac.fx_transaction, ac.project_id,
            ac.memo, ac.id, ac.cleared,
            vr_id, ac.entry_id,
            ac.tax, ac.taxamount, ac.tax_chart_id,
            NOW() 
        FROM acc_trans ac
        JOIN gl ON (gl.id = ac.trans_id)
        WHERE trans_id = $form->{id}|;
     $dbh->do($query) || $form->dberror($query);
  }

  my %audittrail = ( tablename  => 'gl',
                     reference  => $form->{reference},
		     formname   => 'transaction',
		     action     => 'deleted',
		     id         => $form->{id} );
 
  $form->audittrail($dbh, "", \%audittrail);

  if ($form->{batchid} *= 1) {
    $query = qq|SELECT sum(amount)
		FROM acc_trans
		WHERE trans_id = $form->{id}
		AND amount < 0|;
    my ($mount) = $dbh->selectrow_array($query);
    
    $amount = $form->round_amount($amount, $form->{precision});
    $form->update_balance($dbh,
			  'br',
			  'amount',
			  qq|id = $form->{batchid}|,
			  $amount);
    
    $query = qq|DELETE FROM vr WHERE trans_id = $form->{id}|;
    $dbh->do($query) || $form->dberror($query);
  }
  
  for (qw(acc_trans dpt_trans yearend)) {
    $query = qq|DELETE FROM $_ WHERE trans_id = $form->{id}|;
    $dbh->do($query) || $form->dberror($query);
  }
  
  for (qw(recurring recurringemail recurringprint)) {
    $query = qq|DELETE FROM $_ WHERE id = $form->{id}|;
    $dbh->do($query) || $form->dberror($query);
  }
  
  $form->remove_locks($myconfig, $dbh, 'gl');

  # commit and redirect
  my $rc = $dbh->commit;
  $dbh->disconnect;
  
  $rc;
  
}


sub post_transaction {
  my ($self, $myconfig, $form, $dbh) = @_;

  my $null;
  my $project_id;
  my $department_id;
  my $i;
  my $keepcleared;
  
  my $disconnect = ($dbh) ? 0 : 1;

  # connect to database, turn off AutoCommit
  if (! $dbh) {
    $dbh = $form->dbconnect_noauto($myconfig);
  }

  my $query;
  my $sth;
  
  my $approved = ($form->{pending}) ? '0' : '1';
  my $action = ($approved) ? 'posted' : 'saved';

  my %defaults = $form->get_defaults($dbh, \@{['precision', 'extendedlog']});
  $form->{precision} = $defaults{precision};
  $form->{precision} = 8; # Override to fix fx calculations rounding error.

  if ($form->{id} *= 1 and $defaults{extendedlog}) {
        $query = qq|INSERT INTO gl_log SELECT * FROM gl WHERE id = $form->{id}|;
        $dbh->do($query) || $form->dberror($query);
        $query = qq|
            INSERT INTO acc_trans_log 
            SELECT acc_trans.*, gl.ts
            FROM acc_trans
            JOIN gl ON (gl.id = acc_trans.trans_id)
            WHERE trans_id = $form->{id}
        |;
        $dbh->do($query) || $form->dberror($query);

        $query = qq|
        INSERT INTO acc_trans_log (
            trans_id, chart_id, 
            amount, transdate, source,
            approved, fx_transaction, project_id,
            memo, id, cleared,
            vr_id, entry_id,
            tax, taxamount, tax_chart_id,
            ts
            )
        SELECT 
            ac.trans_id, ac.chart_id, 
            0 - ac.amount, ac.transdate, ac.source,
            ac.approved, ac.fx_transaction, ac.project_id,
            ac.memo, ac.id, ac.cleared,
            vr_id, ac.entry_id,
            ac.tax, ac.taxamount, ac.tax_chart_id,
            NOW() 
        FROM acc_trans ac
        JOIN gl ON (gl.id = ac.trans_id)
        WHERE trans_id = $form->{id}|;
        $dbh->do($query) || $form->dberror($query);

        $query = qq|UPDATE gl SET ts = NOW() + TIME '00:00:01' WHERE id = $form->{id}|;
        $dbh->do($query) || $form->dberror($query);
  }

  if ($form->{id} *= 1) {
    $keepcleared = 1;
    
    if ($form->{batchid} *= 1) {
      $query = qq|SELECT * FROM vr
		  WHERE trans_id = $form->{id}|;
      $sth = $dbh->prepare($query) || $form->dberror($query);
      $sth->execute || $form->dberror($query);
      $ref = $sth->fetchrow_hashref(NAME_lc);
      $form->{voucher}{transaction} = $ref;
      $sth->finish;
     
      $query = qq|SELECT SUM(amount)
		  FROM acc_trans
		  WHERE amount < 0
		  AND trans_id = $form->{id}|;
      ($amount) = $dbh->selectrow_array($query);
      
      $form->update_balance($dbh,
			    'br',
			    'amount',
			    qq|id = $form->{batchid}|,
			    $amount);
      
      # delete voucher
      $query = qq|DELETE FROM vr
                  WHERE trans_id = $form->{id}|;
      $dbh->do($query) || $form->dberror($query);

    }

    $query = qq|SELECT id FROM gl
                WHERE id = $form->{id}|;
    ($form->{id}) = $dbh->selectrow_array($query);

    if ($form->{id}) {
      # delete individual transactions
      for (qw(acc_trans dpt_trans)) {
	$query = qq|DELETE FROM $_ WHERE trans_id = $form->{id}|;
	$dbh->do($query) || $form->dberror($query);
      }
    }
  }
  
  if (!$form->{id}) {
   
    my $uid = localtime;
    $uid .= $$;

    $query = qq|INSERT INTO gl (reference, employee_id, approved)
                VALUES (|.$dbh->quote($uid).qq|, (SELECT id FROM employee
		                 WHERE login = '$form->{login}'),
		'$approved')|;
    $dbh->do($query) || $form->dberror($query);
    
    $query = qq|SELECT id FROM gl
                WHERE reference = |.$dbh->quote($uid).qq||;
    ($form->{id}) = $dbh->selectrow_array($query);
  }
  
  ($null, $department_id) = split /--/, $form->{department};
  $department_id *= 1;

  $form->{reference} = $form->update_defaults($myconfig, 'glnumber', $dbh) unless $form->{reference};
  $form->{reference} ||= $form->{id};

  $form->{currency} ||= $form->{defaultcurrency};

  my $exchangerate = $form->parse_amount($myconfig, $form->{exchangerate});
  $exchangerate ||= 1;

  $form->{onhold} *= 1;

  $query = qq|UPDATE gl SET 
	      reference = |.$dbh->quote($form->{reference}).qq|,
	      description = |.$dbh->quote($form->{description}).qq|,
	      notes = |.$dbh->quote($form->{notes}).qq|,
	      transdate = '$form->{transdate}',
	      department_id = $department_id,
	      curr = |.$dbh->quote($form->{currency}).qq|,
	      onhold = |.$dbh->quote($form->{onhold}).qq|,
	      exchangerate = $exchangerate
	      WHERE id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

  if ($department_id) {
    $query = qq|INSERT INTO dpt_trans (trans_id, department_id)
                VALUES ($form->{id}, $department_id)|;
    $dbh->do($query) || $form->dberror($query);
  }

  my $amount;
  my $debit;
  my $credit;
  my $cleared = 'NULL';
  my $bramount = 0;
 
  # insert acc_trans transactions
  for $i (1 .. $form->{rowcount}) {

    $amount = 0;
    
    $debit = $form->parse_amount($myconfig, $form->{"debit_$i"});
    $credit = $form->parse_amount($myconfig, $form->{"credit_$i"});
    $taxamount = $form->parse_amount($myconfig, $form->{"taxamount_$i"});
    $taxamount *= 1;

    # extract accno
    ($accno) = split(/--/, $form->{"accno_$i"});
    
    if ($credit) {
      $amount = $credit;
      $bramount += $form->round_amount($amount * $exchangerate, $form->{precision});
    }
    if ($debit) {
      $amount = $debit * -1;
      $taxamount = $taxamount * -1;
    }

    # add the record
    ($null, $project_id) = split /--/, $form->{"projectnumber_$i"};
    $project_id ||= 'NULL';
    
    if ($keepcleared) {
      $cleared = $form->dbquote($form->dbclean($form->{"cleared_$i"}), SQL_DATE);
    }

    if ($form->{"fx_transaction_$i"} *= 1) {
      $cleared = $form->dbquote($form->dbclean($form->{transdate}), SQL_DATE);
    }
    
    if ($amount || $form->{"source_$i"} || $form->{"memo_$i"} || ($project_id ne 'NULL')) {
      ($tax_accno, $null) = split /--/, $form->{"tax_$i"};
      ($tax_chart_id) = $dbh->selectrow_array("SELECT id FROM chart WHERE accno = '$tax_accno'");
      $tax_chart_id *= 1;

      $query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount, transdate,
		  source, fx_transaction, project_id, memo, cleared, approved, tax, tax_chart_id, taxamount)
		  VALUES
		  ($form->{id}, (SELECT id
				 FROM chart
				 WHERE accno = |.$dbh->quote($accno).qq|),
		   $amount, '$form->{transdate}', |.
		   $dbh->quote($form->{"source_$i"}) .qq|,
		  '$form->{"fx_transaction_$i"}',
		  $project_id, |.$dbh->quote($form->{"memo_$i"}).qq|,
		  $cleared, '$approved', '$form->{"tax_$i"}', $tax_chart_id, $taxamount)|;
      $dbh->do($query) || $form->dberror($query);

      if ($form->{currency} ne $form->{defaultcurrency}) {

	$amount = $form->round_amount($amount * ($exchangerate - 1), $form->{precision});
	
	if ($amount) {
	  $query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount, transdate,
		      source, project_id, fx_transaction, memo, cleared, approved, tax, tax_chart_id, taxamount)
		      VALUES
		      ($form->{id}, (SELECT id
				     FROM chart
				     WHERE accno = |.$dbh->quote($accno).qq|),
		       $amount, '$form->{transdate}', |.
		       $dbh->quote($form->{"source_$i"}) .qq|,
		      $project_id, '1', |.$dbh->quote($form->{"memo_$i"}).qq|,
		      $cleared, '$approved', '$form->{"tax_$i"}', $tax_chart_id, $taxamount)|;
	  $dbh->do($query) || $form->dberror($query);
	}
      }
    }
  }

  # Fix for rounding diff: https://github.com/ledger123/runmyaccounts/issues/67
  if ($form->{currency} ne $form->{defaultcurrency}) {
      $query = "SELECT SUM(amount) FROM acc_trans WHERE trans_id = $form->{id} AND fx_transaction";
      my ($diff) = $dbh->selectrow_array($query);
      $diff = abs($diff);
      if ($diff){
         my ($entry_id) = $dbh->selectrow_array("SELECT entry_id FROM acc_trans WHERE trans_id = $form->{id} AND fx_transaction AND amount > 0 LIMIT 1");
         $dbh->do("UPDATE acc_trans SET amount = amount + $diff WHERE entry_id = $entry_id");
      }
  }

  if ($form->{batchid}) {
    # add voucher
    $form->{voucher}{transaction}{vouchernumber} = $form->update_defaults($myconfig, 'vouchernumber', $dbh) unless $form->{voucher}{transaction}{vouchernumber};

    $query = qq|INSERT INTO vr (br_id, trans_id, id, vouchernumber)
                VALUES ($form->{batchid}, $form->{id}, $form->{id}, |
		.$dbh->quote($form->{voucher}{transaction}{vouchernumber}).qq|)|;
    $dbh->do($query) || $form->dberror($query);

    # update batch
    $form->update_balance($dbh,
			  'br',
			  'amount',
			  qq|id = $form->{batchid}|,
			  $bramount);
   
  }
  
  my %audittrail = ( tablename  => 'gl',
                     reference  => $form->{reference},
		     formname   => 'transaction',
		     action     => $action,
		     id         => $form->{id} );
 
  $form->audittrail($dbh, "", \%audittrail);

  $form->save_recurring($dbh, $myconfig);

  $form->remove_locks($myconfig, $dbh, 'gl');

  # commit and redirect
  my $rc;
  
  if ($disconnect) {
    $rc = $dbh->commit;
    $dbh->disconnect;
  }

  $rc;

}


sub transactions {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);
  my $query;
  my $sth;
  my $var;
  my $null;
  
  my %defaults = $form->get_defaults($dbh, \@{['precision', 'company']});
  for (keys %defaults) { $form->{$_} = $defaults{$_} }

  my ($glwhere, $arwhere, $apwhere) = ("g.approved = '1'", "a.approved = '1'", "a.approved = '1'");
  
  $form->{reference} = $form->dbclean($form->{reference});
  $form->{description} = $form->dbclean($form->{description});
  $form->{projectnumber} = $form->dbclean($form->{projectnumber});
  $form->{name} = $form->dbclean($form->{name});
  $form->{vcnumber} = $form->dbclean($form->{vcnumber});
  $form->{department} = $form->dbclean($form->{department});
  $form->{fx_transaction} = $form->dbclean($form->{fx_transaction});
  
  if ($form->{reference}) {
    $var = $form->like(lc $form->{reference});
    $glwhere .= " AND lower(g.reference) LIKE '$var'";
    $arwhere .= " AND lower(a.invnumber) LIKE '$var'";
    $apwhere .= " AND lower(a.invnumber) LIKE '$var'";
  }
  if ($form->{description}) {
    $var = $form->like(lc $form->{description});
    $glwhere .= " AND lower(g.description) LIKE '$var'";
    $arwhere .= " AND lower(a.description) LIKE '$var'";
    $apwhere .= " AND lower(a.description) LIKE '$var'";
  }
  if ($form->{name}) {
    $var = $form->like(lc $form->{name});
    $glwhere .= " AND lower(g.description) LIKE '$var'";
    $arwhere .= " AND lower(ct.name) LIKE '$var'";
    $apwhere .= " AND lower(ct.name) LIKE '$var'";
  }
  if ($form->{vcnumber}) {
    $var = $form->like(lc $form->{vcnumber});
    $glwhere .= " AND g.id = 0";
    $arwhere .= " AND lower(ct.customernumber) LIKE '$var'";
    $apwhere .= " AND lower(ct.vendornumber) LIKE '$var'";
  }
  if ($form->{department}) {
    ($null, $var) = split /--/, $form->{department};
    $glwhere .= " AND g.department_id = $var";
    $arwhere .= " AND a.department_id = $var";
    $apwhere .= " AND a.department_id = $var";
  }
  if ($form->{onhold}) {
    $glwhere .= " AND g.onhold = '1'";
    $arwhere .= " AND a.onhold = '1'";
    $apwhere .= " AND a.onhold = '1'";
  }
  if ($form->{projectnumber}) {
    ($null, $var) = split /--/, $form->{projectnumber};
    $glwhere .= " AND ac.project_id = $var";
    $arwhere .= " AND ac.project_id = $var";
    $apwhere .= " AND ac.project_id = $var";
  }
  if (!$form->{fx_transaction}) {
    $glwhere .= " AND ac.fx_transaction = '0'";
    $arwhere .= " AND ac.fx_transaction = '0'";
    $apwhere .= " AND ac.fx_transaction = '0'";
  }
 
  my $gdescription = "''";
  my $invoicejoin;
  my $lineitem = "''";
 
  if ($form->{lineitem}) {
    $var = $form->like(lc $form->{lineitem});
    $glwhere .= " AND lower(ac.memo) LIKE '$var'";
    $arwhere .= " AND lower(i.description) LIKE '$var'";
    $apwhere .= " AND lower(i.description) LIKE '$var'";

    $gdescription = "ac.memo";
    $lineitem = "i.description";
    $invoicejoin = qq|
		 LEFT JOIN invoice i ON (i.id = ac.id)|;
  }
 
  if ($form->{l_lineitem}) {
    $gdescription = "ac.memo";
    $lineitem = "i.description";
    $invoicejoin = qq|
                 LEFT JOIN invoice i ON (i.id = ac.id)|;
  }

  if ($form->{source}) {
    $var = $form->like(lc $form->{source});
    $glwhere .= " AND lower(ac.source) LIKE '$var'";
    $arwhere .= " AND lower(ac.source) LIKE '$var'";
    $apwhere .= " AND lower(ac.source) LIKE '$var'";
  }
  
  my $where;
  
  my $accountwhere; # to build contra account information;

  if ($form->{accnofrom}) {
    $query = qq|SELECT c.description,
                l.description AS translation
		FROM chart c
		LEFT JOIN translation l ON (l.trans_id = c.id AND l.language_code = '$myconfig->{countrycode}')
		WHERE c.accno = |.$dbh->quote($form->{accnofrom});
    ($form->{accnofrom_description}, $form->{accnofrom_translation}) = $dbh->selectrow_array($query);
      $form->{accnofrom_description} = $form->{accnofrom_translation} if $form->{accnofrom_translation};
 
    $where = " AND c.accno >= ".$dbh->quote($form->{accnofrom});
    $glwhere .= $where;
    $arwhere .= $where;
    $apwhere .= $where;
    $accountwhere .= $where;
  }

  if ($form->{accnoto}) {
    $query = qq|SELECT c.description,
                l.description AS translation
		FROM chart c
		LEFT JOIN translation l ON (l.trans_id = c.id AND l.language_code = '$myconfig->{countrycode}')
		WHERE c.accno = |.$dbh->quote($form->{accnoto});
    ($form->{accnoto_description}, $form->{accnoto_translation}) = $dbh->selectrow_array($query);
      $form->{accnoto_description} = $form->{accnoto_translation} if $form->{accnoto_translation};
 
    $where = " AND c.accno <= ".$dbh->quote($form->{accnoto});
    $glwhere .= $where;
    $arwhere .= $where;
    $apwhere .= $where;
    $accountwhere .= $where;
  }

  if ($form->{memo}) {
    $var = $form->like(lc $form->{memo});
    $glwhere .= " AND lower(ac.memo) LIKE '$var'";
    $arwhere .= " AND lower(ac.memo) LIKE '$var'";
    $apwhere .= " AND lower(ac.memo) LIKE '$var'";
  }
  
  ($form->{datefrom}, $form->{dateto}) = $form->from_to($form->{year}, $form->{month}, $form->{interval}) if $form->{year} && $form->{month};
  
  if ($form->{datefrom}) {
    $glwhere .= " AND ac.transdate >= '$form->{datefrom}'";
    $arwhere .= " AND ac.transdate >= '$form->{datefrom}'";
    $apwhere .= " AND ac.transdate >= '$form->{datefrom}'";
  }
  if ($form->{dateto}) {
    $glwhere .= " AND ac.transdate <= '$form->{dateto}'";
    $arwhere .= " AND ac.transdate <= '$form->{dateto}'";
    $apwhere .= " AND ac.transdate <= '$form->{dateto}'";
  }
  if ($form->{amountfrom}) {
    $glwhere .= " AND abs(ac.amount) >= $form->{amountfrom}";
    $arwhere .= " AND abs(ac.amount) >= $form->{amountfrom}";
    $apwhere .= " AND abs(ac.amount) >= $form->{amountfrom}";
  }
  if ($form->{amountto}) {
    $glwhere .= " AND abs(ac.amount) <= $form->{amountto}";
    $arwhere .= " AND abs(ac.amount) <= $form->{amountto}";
    $apwhere .= " AND abs(ac.amount) <= $form->{amountto}";
  }
  if ($form->{notes}) {
    $var = $form->like(lc $form->{notes});
    $glwhere .= " AND lower(g.notes) LIKE '$var'";
    $arwhere .= " AND lower(a.notes) LIKE '$var'";
    $apwhere .= " AND lower(a.notes) LIKE '$var'";
  }
  if ($form->{intnotes}) {
    $var = $form->like(lc $form->{intnotes});
    $glwhere .= " AND '' LIKE '$var'";
    $arwhere .= " AND lower(a.intnotes) LIKE '$var'";
    $apwhere .= " AND lower(a.intnotes) LIKE '$var'";
  }
  if ($form->{accno}) {
    $glwhere .= " AND c.accno = ".$dbh->quote($form->{accno});
    $arwhere .= " AND c.accno = ".$dbh->quote($form->{accno});
    $apwhere .= " AND c.accno = ".$dbh->quote($form->{accno});
  }
  if ($form->{gifi_accno}) {
    $glwhere .= " AND c.gifi_accno = ".$dbh->quote($form->{gifi_accno});
    $arwhere .= " AND c.gifi_accno = ".$dbh->quote($form->{gifi_accno});
    $apwhere .= " AND c.gifi_accno = ".$dbh->quote($form->{gifi_accno});
  }
  if ($form->{category} ne 'X') {
    $glwhere .= " AND c.category = ".$dbh->quote($form->{category});
    $arwhere .= " AND c.category = ".$dbh->quote($form->{category});
    $apwhere .= " AND c.category = ".$dbh->quote($form->{category});
  }

  if ($form->{accno} || $form->{gifi_accno}) {
    
    # get category for account
    if ($form->{accno}) {
      $query = qq|SELECT c.category, c.link, c.contra, c.description,
                  l.description AS translation
		  FROM chart c
		  LEFT JOIN translation l ON (l.trans_id = c.id AND l.language_code = '$myconfig->{countrycode}')
		  WHERE c.accno = |.$dbh->quote($form->{accno});
      ($form->{category}, $form->{link}, $form->{contra}, $form->{account_description}, $form->{account_translation}) = $dbh->selectrow_array($query);
      $form->{account_description} = $form->{account_translation} if $form->{account_translation};
    }
    
    if ($form->{gifi_accno}) {
      $query = qq|SELECT c.category, c.link, c.contra, g.description
		  FROM chart c
		  LEFT JOIN gifi g ON (g.accno = c.gifi_accno)
		  WHERE c.gifi_accno = |.$dbh->quote($form->{gifi_accno});
      ($form->{category}, $form->{link}, $form->{contra}, $form->{gifi_account_description}) = $dbh->selectrow_array($query);
    }
 
    if ($form->{datefrom}) {
      $where = $glwhere;
      $where =~ s/(AND)??ac.transdate.*?(AND|$)//g;
      
      $query = qq|SELECT SUM(ac.amount)
		  FROM acc_trans ac
		  JOIN chart c ON (ac.chart_id = c.id)
		  JOIN gl g ON (g.id = ac.trans_id)
		  WHERE $where
		  AND ac.transdate < date '$form->{datefrom}'
		  |;
      my ($balance) = $dbh->selectrow_array($query);
      $form->{balance} += $balance;


      $where = $arwhere;
      $where =~ s/(AND)??ac.transdate.*?(AND|$)//g;
      
      $query = qq|SELECT SUM(ac.amount)
		  FROM acc_trans ac
		  JOIN chart c ON (ac.chart_id = c.id)
		  JOIN ar a ON (a.id = ac.trans_id)
		  JOIN customer ct ON (ct.id = a.customer_id)
		  $invoicejoin
		  WHERE $where
		  AND ac.transdate < date '$form->{datefrom}'
		  |;
      ($balance) = $dbh->selectrow_array($query);
      $form->{balance} += $balance;

 
      $where = $apwhere;
      $where =~ s/(AND)??ac.transdate.*?(AND|$)//g;
      
      $query = qq|SELECT SUM(ac.amount)
		  FROM acc_trans ac
		  JOIN chart c ON (ac.chart_id = c.id)
		  JOIN ap a ON (a.id = ac.trans_id)
		  JOIN vendor ct ON (ct.id = a.vendor_id)
		  $invoicejoin
		  WHERE $where
		  AND ac.transdate < date '$form->{datefrom}'
		  |;
      
      ($balance) = $dbh->selectrow_array($query);
      $form->{balance} += $balance;

    }
  }

  $dbh->do('DELETE FROM filtered');
  if ($form->{accno} and $form->{filter_amounts}){
     # CREATE TABLE filtered (trans_id int, entry_id int default 0, entry_id2 int default 0, debit float default 0, credit float default 0);
     my $query = qq|
        INSERT INTO filtered (trans_id, entry_id, debit, credit)
        SELECT trans_id, entry_id,
        (case when ac.amount < 0 then 0 - ac.amount else 0 end) debit,
        (case when ac.amount > 0 then ac.amount else 0 end) credit
        FROM acc_trans ac
        WHERE ac.chart_id IN (SELECT id FROM chart WHERE accno = '$form->{accno}')
     |;
     $query .= " AND ac.transdate >= '$form->{datefrom}'" if $form->{datefrom};
     $query .= " AND ac.transdate <= '$form->{dateto}'" if $form->{dateto};

     $dbh->do($query);
     $query = "SELECT * FROM filtered WHERE credit > 0";
     my $sth = $dbh->prepare($query);
     $sth->execute;
     while ($row = $sth->fetchrow_hashref(NAME_lc)){
        $dbh->do("
          UPDATE filtered SET entry_id2 = $row->{entry_id}
          WHERE debit = $row->{credit} 
            AND entry_id2 = 0
            AND entry_id = (SELECT entry_id FROM filtered WHERE debit = $row->{credit} AND entry_id2 = 0 LIMIT 1 )"
        );
     }
  }
  my $debit_credit_filtered_where = " AND ac.entry_id NOT IN (
       SELECT entry_id FROM filtered WHERE entry_id2 > 0
       UNION
       SELECT entry_id2 FROM filtered WHERE entry_id2 > 0
  )";

  my $false = ($myconfig->{dbdriver} =~ /Pg/) ? FALSE : q|'0'|;

  my %ordinal = ( id => 1,
                  reference => 4,
		  description => 5,
                  transdate => 6,
                  source => 7,
                  accno => 9,
		  department => 15,
		  projectnumber => 16,
		  memo => 17,
		  lineitem => 19,
		  name => 20,
		  name => 21,
		  vcnumber => 22);
  
  my @sf = qw(id transdate reference accno);
  my $sortorder = $form->sort_order(\@sf, \%ordinal);
  
  my $query = qq|SELECT g.id, 'gl' AS type, $false AS invoice, g.reference,
                 g.description, ac.transdate, ac.source,
		 ac.amount, c.accno, c.gifi_accno, g.notes, c.link,
		 '' AS till, ac.cleared, d.description AS department, p.projectnumber,
		 ac.memo, '0' AS name_id, '' AS db,
		 $gdescription AS lineitem, '' AS name, '' AS vcnumber,
		 '' AS address1, '' AS address2, '' AS city,
		 '' AS zipcode, '' AS country, c.description AS accdescription,
		 '' AS intnotes, g.curr, g.exchangerate, '' log, g.ts, ac.entry_id, ac.fx_transaction,
         ac.tax, ac.taxamount, ac.id payment_id
                 FROM gl g
		 JOIN acc_trans ac ON (g.id = ac.trans_id)
		 JOIN chart c ON (ac.chart_id = c.id)
		 LEFT JOIN department d ON (d.id = g.department_id)
		 LEFT JOIN project p ON (p.id = ac.project_id)
                 WHERE $glwhere $debit_credit_filtered_where
	UNION ALL
	         SELECT a.id, 'ar' AS type, a.invoice, a.invnumber,
		 a.description, ac.transdate, ac.source,
		 ac.amount, c.accno, c.gifi_accno, a.notes, c.link,
		 a.till, ac.cleared, d.description AS department, p.projectnumber,
		 ac.memo, ct.id AS name_id, 'customer' AS db,
		 $lineitem AS lineitem, ct.name, ct.customernumber,
		 ad.address1, ad.address2, ad.city,
		 ad.zipcode, ad.country, c.description AS accdescription,
		 a.intnotes, a.curr, a.exchangerate, '' log, a.ts, ac.entry_id, ac.fx_transaction,
         ac.tax, ac.taxamount, ac.id payment_id
		 FROM ar a
		 JOIN acc_trans ac ON (a.id = ac.trans_id)
		 $invoicejoin
		 JOIN chart c ON (ac.chart_id = c.id)
		 JOIN customer ct ON (a.customer_id = ct.id)
		 JOIN address ad ON (ad.trans_id = ct.id)
		 LEFT JOIN department d ON (d.id = a.department_id)
		 LEFT JOIN project p ON (p.id = ac.project_id)
		 WHERE $arwhere $debit_credit_filtered_where
	UNION ALL
	         SELECT a.id, 'ap' AS type, a.invoice, a.invnumber,
		 a.description, ac.transdate, ac.source,
		 ac.amount, c.accno, c.gifi_accno, a.notes, c.link,
		 a.till, ac.cleared, d.description AS department, p.projectnumber,
		 ac.memo, ct.id AS name_id, 'vendor' AS db,
		 $lineitem AS lineitem, ct.name, ct.vendornumber,
		 ad.address1, ad.address2, ad.city,
		 ad.zipcode, ad.country, c.description AS accdescription,
		 a.intnotes, a.curr, a.exchangerate, '' log, a.ts, ac.entry_id, ac.fx_transaction,
         ac.tax, ac.taxamount, ac.id payment_id
		 FROM ap a
		 JOIN acc_trans ac ON (a.id = ac.trans_id)
		 $invoicejoin
		 JOIN chart c ON (ac.chart_id = c.id)
		 JOIN vendor ct ON (a.vendor_id = ct.id)
		 JOIN address ad ON (ad.trans_id = ct.id)
		 LEFT JOIN department d ON (d.id = a.department_id)
		 LEFT JOIN project p ON (p.id = ac.project_id)
		 WHERE $apwhere $debit_credit_filtered_where
	     |;

  if ($form->{include_log}){
    # first edited log
    $query .= qq|
        
        UNION ALL

        SELECT g.id, 'gl' AS type, $false AS invoice, g.reference,
                 g.description, ac.transdate, ac.source,
		 ac.amount, c.accno, c.gifi_accno, g.notes, c.link,
		 '' AS till, ac.cleared, d.description AS department, p.projectnumber,
		 ac.memo, '0' AS name_id, '' AS db,
		 $gdescription AS lineitem, '' AS name, '' AS vcnumber,
		 '' AS address1, '' AS address2, '' AS city,
		 '' AS zipcode, '' AS country, c.description AS accdescription,
		 '' AS intnotes, g.curr, g.exchangerate, '*' log, ac.ts, ac.entry_id, ac.fx_transaction,
         ac.tax, ac.taxamount, ac.id payment_id
                 FROM gl g
		 JOIN acc_trans_log ac ON (g.id = ac.trans_id)
		 JOIN chart c ON (ac.chart_id = c.id)
		 LEFT JOIN department d ON (d.id = g.department_id)
		 LEFT JOIN project p ON (p.id = ac.project_id)
                 WHERE $glwhere
	UNION ALL
	         SELECT a.id, 'ar' AS type, a.invoice, a.invnumber,
		 a.description, ac.transdate, ac.source,
		 ac.amount, c.accno, c.gifi_accno, a.notes, c.link,
		 a.till, ac.cleared, d.description AS department, p.projectnumber,
		 ac.memo, ct.id AS name_id, 'customer' AS db,
		 $lineitem AS lineitem, ct.name, ct.customernumber,
		 ad.address1, ad.address2, ad.city,
		 ad.zipcode, ad.country, c.description AS accdescription,
		 a.intnotes, a.curr, a.exchangerate, '*' log, ac.ts, ac.entry_id, ac.fx_transaction,
         ac.tax, ac.taxamount, ac.id payment_id
		 FROM ar a
		 JOIN acc_trans_log ac ON (a.id = ac.trans_id)
		 $invoicejoin
		 JOIN chart c ON (ac.chart_id = c.id)
		 JOIN customer ct ON (a.customer_id = ct.id)
		 JOIN address ad ON (ad.trans_id = ct.id)
		 LEFT JOIN department d ON (d.id = a.department_id)
		 LEFT JOIN project p ON (p.id = ac.project_id)
		 WHERE $arwhere
	UNION ALL
	         SELECT a.id, 'ap' AS type, a.invoice, a.invnumber,
		 a.description, ac.transdate, ac.source,
		 ac.amount, c.accno, c.gifi_accno, a.notes, c.link,
		 a.till, ac.cleared, d.description AS department, p.projectnumber,
		 ac.memo, ct.id AS name_id, 'vendor' AS db,
		 $lineitem AS lineitem, ct.name, ct.vendornumber,
		 ad.address1, ad.address2, ad.city,
		 ad.zipcode, ad.country, c.description AS accdescription,
		 a.intnotes, a.curr, a.exchangerate, '*' log, ac.ts, ac.entry_id, ac.fx_transaction,
         ac.tax, ac.taxamount, ac.id payment_id
		 FROM ap a
		 JOIN acc_trans_log ac ON (a.id = ac.trans_id)
		 $invoicejoin
		 JOIN chart c ON (ac.chart_id = c.id)
		 JOIN vendor ct ON (a.vendor_id = ct.id)
		 JOIN address ad ON (ad.trans_id = ct.id)
		 LEFT JOIN department d ON (d.id = a.department_id)
		 LEFT JOIN project p ON (p.id = ac.project_id)
		 WHERE $apwhere
	     |;

    # then deleted log
    $query .= qq|
        
        UNION ALL

        SELECT g.id, 'gl' AS type, $false AS invoice, g.reference,
                 g.description, ac.transdate, ac.source,
		 ac.amount, c.accno, c.gifi_accno, g.notes, c.link,
		 '' AS till, ac.cleared, d.description AS department, p.projectnumber,
		 ac.memo, '0' AS name_id, '' AS db,
		 $gdescription AS lineitem, '' AS name, '' AS vcnumber,
		 '' AS address1, '' AS address2, '' AS city,
		 '' AS zipcode, '' AS country, c.description AS accdescription,
		 '' AS intnotes, g.curr, g.exchangerate, '*' log, ac.ts, ac.entry_id, ac.fx_transaction,
         ac.tax, ac.taxamount, ac.id payment_id
                 FROM gl_log_deleted g
		 JOIN acc_trans_log_deleted ac ON (g.id = ac.trans_id)
		 JOIN chart c ON (ac.chart_id = c.id)
		 LEFT JOIN department d ON (d.id = g.department_id)
		 LEFT JOIN project p ON (p.id = ac.project_id)
                 WHERE $glwhere
	UNION ALL
	         SELECT a.id, 'ar' AS type, a.invoice, a.invnumber,
		 a.description, ac.transdate, ac.source,
		 ac.amount, c.accno, c.gifi_accno, a.notes, c.link,
		 a.till, ac.cleared, d.description AS department, p.projectnumber,
		 ac.memo, ct.id AS name_id, 'customer' AS db,
		 $lineitem AS lineitem, ct.name, ct.customernumber,
		 ad.address1, ad.address2, ad.city,
		 ad.zipcode, ad.country, c.description AS accdescription,
		 a.intnotes, a.curr, a.exchangerate, '*' log, ac.ts, ac.entry_id, ac.fx_transaction,
         ac.tax, ac.taxamount, ac.id payment_id
		 FROM ar_log_deleted a
		 JOIN acc_trans_log_deleted ac ON (a.id = ac.trans_id)
		 $invoicejoin
		 JOIN chart c ON (ac.chart_id = c.id)
		 JOIN customer ct ON (a.customer_id = ct.id)
		 JOIN address ad ON (ad.trans_id = ct.id)
		 LEFT JOIN department d ON (d.id = a.department_id)
		 LEFT JOIN project p ON (p.id = ac.project_id)
		 WHERE $arwhere
	UNION ALL
	         SELECT a.id, 'ap' AS type, a.invoice, a.invnumber,
		 a.description, ac.transdate, ac.source,
		 ac.amount, c.accno, c.gifi_accno, a.notes, c.link,
		 a.till, ac.cleared, d.description AS department, p.projectnumber,
		 ac.memo, ct.id AS name_id, 'vendor' AS db,
		 $lineitem AS lineitem, ct.name, ct.vendornumber,
		 ad.address1, ad.address2, ad.city,
		 ad.zipcode, ad.country, c.description AS accdescription,
		 a.intnotes, a.curr, a.exchangerate, '*' log, ac.ts, ac.entry_id, ac.fx_transaction,
         ac.tax, ac.taxamount, ac.id payment_id
		 FROM ap_log_deleted a
		 JOIN acc_trans_log_deleted ac ON (a.id = ac.trans_id)
		 $invoicejoin
		 JOIN chart c ON (ac.chart_id = c.id)
		 JOIN vendor ct ON (a.vendor_id = ct.id)
		 JOIN address ad ON (ad.trans_id = ct.id)
		 LEFT JOIN department d ON (d.id = a.department_id)
		 LEFT JOIN project p ON (p.id = ac.project_id)
		 WHERE $apwhere
	     |;

    $query .= qq| ORDER BY 33, $sortorder|;
  } else {
    $query .= qq| ORDER BY $sortorder|;
  } # if $form->{include_log}

  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {

    # gl
    if ($ref->{type} eq "gl") {
      $ref->{module} = "gl";
    }

    # ap
    if ($ref->{type} eq "ap") {
      $ref->{memo} ||= $ref->{lineitem};
      if ($ref->{invoice}) {
        $ref->{module} = "ir";
      } else {
        $ref->{module} = "ap";
      }
    }

    # ar
    if ($ref->{type} eq "ar") {
      $ref->{memo} ||= $ref->{lineitem};
      if ($ref->{invoice}) {
        $ref->{module} = ($ref->{till}) ? "ps" : "is";
      } else {
        $ref->{module} = "ar";
      }
    }

    if ($ref->{amount} < 0) {
      $ref->{debit} = $ref->{amount} * -1;
      $ref->{credit} = 0;
    } else {
      $ref->{credit} = $ref->{amount};
      $ref->{debit} = 0;
    }

    for (qw(address1 address2 city zipcode country)) { $ref->{address} .= "$ref->{$_} " }

    push @{ $form->{GL} }, $ref;
    
  }
  $sth->finish;

  $query =~ s/$accountwhere//g;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  my %trans;
  my $i = 0;
  
  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {

    # gl
    if ($ref->{type} eq "gl") {
      $ref->{module} = "gl";
    }

    # ap
    if ($ref->{type} eq "ap") {
      $ref->{memo} ||= $ref->{lineitem};
      if ($ref->{invoice}) {
        $ref->{module} = "ir";
      } else {
        $ref->{module} = "ap";
      }
    }

    # ar
    if ($ref->{type} eq "ar") {
      $ref->{memo} ||= $ref->{lineitem};
      if ($ref->{invoice}) {
        $ref->{module} = ($ref->{till}) ? "ps" : "is";
      } else {
        $ref->{module} = "ar";
      }
    }

    if ($ref->{amount} < 0) {
      $ref->{debit} = $ref->{amount} * -1;
      $ref->{credit} = 0;
    } else {
      $ref->{credit} = $ref->{amount};
      $ref->{debit} = 0;
    }

    $trans{$ref->{id}}{$i} = {
                      link => $ref->{link},
                      type => $ref->{type},
                     accno => $ref->{accno},
                gifi_accno => $ref->{gifi_accno},
                     debit => $ref->{debit},
                    credit => $ref->{credit},
                    amount => $ref->{debit} + $ref->{credit}
		             };
    $i++;
    
  }
  $sth->finish;

  $dbh->disconnect;

    for my $id (keys %trans) {

      my $arap = "";
      my $ARAP;
      my $gifi_arap = "";
      my $paid = "";
      my $gifi_paid = "";
      my $accno = "";
      my $gifi_accno = "";
      my @arap = ();
      my @paid = ();
      my @accno = ();
      my %accno = ();
      my $aa = 0;
      my $j;
      my %seen = ();

      for $i (reverse sort { $trans{$id}{$a}{amount} <=> $trans{$id}{$b}{amount} } keys %{$trans{$id}}) {

	if ($trans{$id}{$i}{type} =~ /(ar|ap)/) {
	  $ARAP = uc $trans{$id}{$i}{type};
	  $aa = 1;
	  if ($trans{$id}{$i}{link} eq $ARAP) {
	    $arap = $trans{$id}{$i}{accno};
	    $gifi_arap = $trans{$id}{$i}{gifi_accno};
	    push @arap, $i;
	  } elsif ($trans{$id}{$i}{link} =~ /${ARAP}_paid/) {
	    $paid = $trans{$id}{$i}{accno};
	    $gifi_paid = $trans{$id}{$i}{gifi_accno};
	    push @paid, $i;
	  } else {
	    push @accno, { accno => $trans{$id}{$i}{accno},
		      gifi_accno => $trans{$id}{$i}{gifi_accno},
			       i => $i };
	  }
	}
      }

      if ($aa) {
	for (@paid) {
	  $form->{GL}[$_]{contra} = $arap;
	  $form->{GL}[$_]{gifi_contra} = $gifi_arap;
	}
	if (@paid) {
	  $i = pop @arap;
	  $form->{GL}[$i]{contra} = $paid;
	  $form->{GL}[$i]{gifi_contra} = $gifi_paid;
	}
	for (@arap) {
	  $i = 0;
	  for $ref (@accno) {
	    $form->{GL}[$_]{contra} .= "$ref->{accno} " unless $seen{$ref->{accno}};
	    $seen{$ref->{accno}} = 1;
	    $form->{GL}[$_]{gifi_contra} .= "$ref->{gifi_accno} " unless $seen{$ref->{gifi_accno}};
	    $seen{$ref->{gifi_accno}} = 1;
	  }
	  $i++;
	}
	for $ref (@accno) {
	  $form->{GL}[$ref->{i}]{contra} = $arap;
	  $form->{GL}[$ref->{i}]{gifi_contra} = $gifi_arap;
	}
      } else {
	
	%accno = %{$trans{$id}};
	$j = 0;
	
	for $i (reverse sort { $trans{$id}{$a}{amount} <=> $trans{$id}{$b}{amount} } keys %{$trans{$id}}) {
	  $found = 0;
	  $amount = $trans{$id}{$i}{amount};
	  $accno = $trans{$id}{$i}{accno};
	  $gifi_accno = $trans{$id}{$i}{gifi_accno};
	  $j = $i;
	  
	  if ($trans{$id}{$i}{debit}) {
	    $amt = "debit";
	    $rev = "credit";
	  } else {
	    $amt = "credit";
	    $rev = "debit";
	  }
	  
	  if ($trans{$id}{$i}{$amt}) {
	    for (keys %accno) {
	      if ($accno{$_}{$rev} == $trans{$id}{$i}{$amt}) {
		$form->{GL}[$_]{contra} = $trans{$id}{$i}{accno};
		$form->{GL}[$_]{gifi_contra} = $trans{$id}{$i}{gifi_accno};
		$found = 1;
		last;
	      }
	    }
	  }

	  if (!$found) {
	    delete $accno{$j};
	    delete $trans{$id}{$j};
	    
	    if ($amount) {
	      for $i (reverse sort { $a{amount} <=> $b{amount} } keys %accno) {
		if ($accno{$i}{amount} <= $amount) {
		  $form->{GL}[$i]{contra} = $accno;
		  $form->{GL}[$i]{gifi_contra} = $gifi_accno;
		  $amount = $form->round_amount($amount - $accno{$i}{amount}, 10);
		  last if $amount < 0;

		  $form->{GL}[$j]{contra} .= "$accno{$i}{accno} " unless $seen{$accno{$i}{accno}};
		  $seen{$accno{$i}{accno}};
		  $form->{GL}[$j]{gifi_contra} .= "$accno{$i}{gifi_accno} " unless $seen{$accno{$i}{gifi_accno}};
		  $seen{$accno{$i}{gifi_accno}};
		  delete $accno{$i};
		  delete $trans{$id}{$i};
		}
	      }
	    }
	  }
	}
      }
    }

  # get rid of rows which were used to generated contra info
  my @gl;
  foreach $ref (@{ $form->{GL} }) {
     push @gl, $ref if $ref->{id};
  }
  @{ $form->{GL} } = @gl;

}


sub transaction {
  my ($self, $myconfig, $form) = @_;
  
  my $query;
  my $sth;
  my $ref;
  my @a;
  
  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  $form->remove_locks($myconfig, $dbh, 'gl');
  
  my %defaults = $form->get_defaults($dbh, \@{[qw(closedto revtrans precision)]});
  for (keys %defaults) { $form->{$_} = $defaults{$_} }
  $form->closedto_user($myconfig, $dbh);

  $form->{currencies} = $form->get_currencies($dbh, $myconfig);
  
  if ($form->{id} *= 1) {
    $query = qq|SELECT g.*, 
                d.description AS department,
		br.id AS batchid, br.description AS batchdescription
                FROM gl g
	        LEFT JOIN department d ON (d.id = g.department_id)
		LEFT JOIN vr ON (vr.trans_id = g.id)
		LEFT JOIN br ON (br.id = vr.br_id)
	        WHERE g.id = $form->{id}|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    $ref = $sth->fetchrow_hashref(NAME_lc);
    for (keys %$ref) { $form->{$_} = $ref->{$_} }
    $form->{currency} = $form->{curr};
    $sth->finish;
  
    # retrieve individual rows
    $query = qq|SELECT ac.*, c.accno, c.description, p.projectnumber,
                l.description AS translation
	        FROM acc_trans ac
	        JOIN chart c ON (ac.chart_id = c.id)
	        LEFT JOIN project p ON (p.id = ac.project_id)
		LEFT JOIN translation l ON (l.trans_id = c.id AND l.language_code = '$myconfig->{countrycode}')
	        WHERE ac.trans_id = $form->{id}
            AND (tax <> 'auto' OR tax IS NULL)
	        ORDER BY accno|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);
    
    while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
      $ref->{amount} += $ref->{taxamount};
      $ref->{taxamount} = abs($ref->{taxamount});
      $ref->{description} = $ref->{translation} if $ref->{translation};
      push @a, $ref;
      if ($ref->{fx_transaction}) {
	$fxdr += $ref->{amount} if $ref->{amount} < 0;
	$fxcr += $ref->{amount} if $ref->{amount} > 0;
      }
    }
    $sth->finish;
    
    if ($fxdr < 0 || $fxcr > 0) {
      $form->{fxadj} = 1 if $form->round_amount($fxdr * -1, $form->{precision}) != $form->round_amount($fxcr, $form->{precision});
    }

    if ($form->{fxadj}) {
      @{ $form->{GL} } = @a;
    } else {
      foreach $ref (@a) {
	if (! $ref->{fx_transaction}) {
	  push @{ $form->{GL} }, $ref;
	}
      }
    }
    
    # get recurring transaction
    $form->get_recurring($dbh);

    $form->create_lock($myconfig, $dbh, $form->{id}, 'gl');

  } else {
    $form->{transdate} = $form->current_date($myconfig);
  }

  # get chart of accounts
  $query = qq|SELECT c.accno, c.description,
              l.description AS translation
              FROM chart c
	      LEFT JOIN translation l ON (l.trans_id = c.id AND l.language_code = '$myconfig->{countrycode}')
	      WHERE c.charttype = 'A'
	      AND c.allow_gl = '1'
              ORDER by c.accno|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);
  
  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    $ref->{description} = $ref->{translation} if $ref->{translation};
    push @{ $form->{all_accno} }, $ref;
  }
  $sth->finish;

  # get departments
  $form->all_departments($myconfig, $dbh);
  
  # get projects
  $form->all_projects($myconfig, $dbh, $form->{transdate});
  
  $dbh->disconnect;

}


1;

