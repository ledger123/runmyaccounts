1;

require "$form->{path}/mylib.pl";

sub continue { &{$form->{nextsub} } };

sub ask_dbcheck {

  $form->error($locale->text('Only for admin ...')) unless $myconfig{role} eq 'admin';

  $form->{title} = $locale->text('Ledger Doctor');
  $form->header;
  my $dbh = $form->dbconnect(\%myconfig);
  my ($firstdate) = $dbh->selectrow_array("SELECT MIN(transdate) FROM acc_trans");
  my ($lastdate) = $dbh->selectrow_array("SELECT MAX(transdate) FROM acc_trans");
  print qq|
<body>
  <table width=100%>
     <tr><th class=listtop>$form->{title}</th></tr>
  </table><br />

<h1>Check for database inconsistancies</h1>
<form method=post action=$form->{script}>
  <table>
    <tr>
	<th>|.$locale->text('First transaction date').qq|</th>
	<td><input name=firstdate size=11 value='$firstdate' title='$myconfig{dateformat}'></td>
    </tr>
    <tr>
	<th>|.$locale->text('Last transaction date').qq|</th>
	<td><input name=lastdate size=11 value='$lastdate' title='$myconfig{dateformat}'></td>
     </tr>
  </table>|.
$locale->text('All transactions outside this date range will be reported as having invalid dates.').qq|
<br><br><hr/>
<input type=submit class=submit name=action value="|.$locale->text('Continue').qq|">
|;

  $form->{nextsub} = 'do_dbcheck';
  $form->hide_form(qw(title path nextsub login));

print qq|
</table>
</form>
</body>
|;
}

sub do_dbcheck {

  $form->error($locale->text('Only for admin ...')) unless $myconfig{role} eq 'admin';

  $form->{title} = $locale->text('Ledger Doctor');
  $form->header;
  print qq|<body><table width=100%><tr><th class=listtop>$form->{title}</th></tr></table><br />|;
  my $dbh = $form->dbconnect(\%myconfig);
  my $query, $sth, $i;
  my $callback = "$form->{script}?action=do_dbcheck&firstdate=$form->{firstdate}&lastdate=$form->{lastdate}&path=$form->{path}&login=$form->{login}";
  $callback = $form->escape($callback);

  #------------------------
  # 1. Blank rows
  #------------------------

  print qq|<h3>Blank rows</h3>|;
  $query = qq|
    SELECT COUNT(*) 
    FROM acc_trans 
    WHERE amount = 0 
    AND chart_id NOT IN (SELECT id FROM chart WHERE link LIKE '%_tax%')
|;
  my ($count) = $dbh->selectrow_array($query);

  $query = qq|
    SELECT COUNT(*) 
    FROM acc_trans 
    WHERE amount = 0 
    AND chart_id IN (SELECT id FROM chart WHERE link LIKE '%_tax%')
|;
  my ($count2) = $dbh->selectrow_array($query);

  $query = qq|
    SELECT COUNT(*) 
    FROM acc_trans 
    WHERE amount = 0 
    AND chart_id IN (SELECT id FROM chart WHERE link NOT LIKE '%_tax%')
|;
  my ($count3) = $dbh->selectrow_array($query);

  if ($count or $count2 or $count3){
     $form->info($locale->text("There are $count blank rows ..."));
     $form->info($locale->text("There are $count2 blank TAX rows ..."));
     $form->info($locale->text("There are $count3 blank non-TAX rows ..."));
     print qq|
<form method=post action=$form->{script}>
<input type=submit class=submit name=action value="|.$locale->text('Click here to delete blank rows').qq|">
<input type=submit class=submit name=action value="|.$locale->text('Click here to delete blank TAX rows').qq|">
<input type=submit class=submit name=action value="|.$locale->text('Click here to delete blank non-TAX rows').qq|">
|;

  $form->{nextsub} = 'do_dbcheck';
  $form->hide_form(qw(title path nextsub login));

    print qq|
</form>
|;

  } else {
     $form->info($locale->text("No blank rows found ...")); 
  }

  #------------------------
  # 2. Unbalanced Journals
  #------------------------
  print qq|<h3>Unbalanced Journals</h3>|;
  $query = qq|
	SELECT 'GL' AS module, gl.reference AS invnumber, gl.id,
		ac.transdate, false AS invoice, SUM(ac.amount) AS amount
	FROM acc_trans ac
	JOIN gl ON (gl.id = ac.trans_id)
    WHERE ac.transdate BETWEEN '$form->{firstdate} 00:00' and '$form->{lastdate}'
	GROUP BY 1, 2, 3, 4, 5
	HAVING SUM(ac.amount) > 0.005 OR SUM(ac.amount) < -0.005

	UNION ALL

	SELECT 'AR' AS module, ar.invnumber, ar.id,
		ac.transdate, ar.invoice, SUM(ac.amount) AS amount
	FROM acc_trans ac
	JOIN ar ON (ar.id = ac.trans_id)
    WHERE ac.transdate BETWEEN '$form->{firstdate} 00:00' and '$form->{lastdate}'
	GROUP BY 1, 2, 3, 4, 5
	HAVING SUM(ac.amount) > 0.005 OR SUM(ac.amount) < -0.005

	UNION ALL

	SELECT 'AP' AS module, ap.invnumber, ap.id,
		ac.transdate, ap.invoice, SUM(ac.amount) AS amount
	FROM acc_trans ac
	JOIN ap ON (ap.id = ac.trans_id)
    WHERE ac.transdate BETWEEN '$form->{firstdate} 00:00' and '$form->{lastdate}'
	GROUP BY 1, 2, 3, 4, 5
	HAVING SUM(ac.amount) > 0.005 OR SUM(ac.amount) < -0.005

	ORDER BY 3
  |;
  $sth = $dbh->prepare($query) || $form->dberror($query);
  $sth->execute;
  print qq|<table>|;
  print qq|<tr class=listheading>|;
  print qq|<th class=listheading>|.$locale->text('Module').qq|</td>|;
  print qq|<th class=listheading>|.$locale->text('Invoice Number / Reference').qq|</td>|;
  print qq|<th class=listheading>|.$locale->text('Date').qq|</td>|;
  print qq|<th class=listheading>|.$locale->text('Amount').qq|</td>|;
  print qq|</tr>|;
  $i = 0;

  my $module;
  my $total_amount;
  while ($ref = $sth->fetchrow_hashref(NAME_lc)){
     $module = lc $ref->{module};
     $module = 'ir' if $ref->{invoice} and $ref->{module} eq 'AP';
     $module = 'is' if $ref->{invoice} and $ref->{module} eq 'AR';

     if ($form->round_amount($ref->{amount}, 2) != 0){
     	print qq|<tr class=listrow$i>|;
     	print qq|<td>$ref->{module}</td>|;
     	print qq|<td><a href=$module.pl?action=edit&id=$ref->{id}&path=$form->{path}&login=$form->{login}&callback=$callback>$ref->{invnumber}</a></td>|;
     	print qq|<td>$ref->{transdate}</td>|;
     	print qq|<td align=right>|.$form->format_amount(\%myconfig, $ref->{amount}, 6).qq|</td>|;
     	print qq|</tr>|;
	$total_amount += $ref->{amount};
     }
  }
  print qq|<tr class=listtotal><td>&nbsp;</td><td>&nbsp;</td><td>&nbsp;</td><td>|.
$form->format_amount(\%myconfig, $total_amount, 2).qq|</td></tr></table>|;

  #------------------------
  # 2a. Rounding diff
  #------------------------

  print qq|<h3>Paid transactions from AR where amount booked on AR account in debit is different from amount booked on AR account in credit.
</h3>|;

  $query = qq|
        SELECT ar.invnumber, ar.invoice, ac.trans_id, sum(ac.amount) amount
        FROM acc_trans ac 
        JOIN ar on (ar.id = ac.trans_id) 
        WHERE chart_id in (select id from chart where link='AR') 
        AND ar.amount = ar.paid 
        AND ar.transdate BETWEEN '$form->{firstdate}' AND '$form->{lastdate}'
        GROUP BY ar.invnumber, ar.invoice, ac.trans_id 
        HAVING round(sum(ac.amount)::numeric, 2) <> 0
|;
  $sth = $dbh->prepare($query) || $form->dberror($query);
  $sth->execute;
  print qq|<table>|;
  print qq|<tr class=listheading>|;
  print qq|<th class=listheading>|.$locale->text('Invoice Number').qq|</td>|;
  print qq|<th class=listheading>|.$locale->text('Trans ID').qq|</td>|;
  print qq|<th class=listheading>|.$locale->text('Amount').qq|</td>|;
  print qq|</tr>|;
  $i = 0;
  my $module;
  while ($ref = $sth->fetchrow_hashref(NAME_lc)){
     if ($ref->{invoice}){
        $module = 'is.pl';
     } else {
        $module = 'ar.pl';
     }
     print qq|<tr class=listrow$i>|;
     print qq|<td><a href=$module?action=edit&id=$ref->{trans_id}&path=$form->{path}&login=$form->{login}&callback=$callback>$ref->{invnumber}</a></td>|;
     print qq|<td>$ref->{trans_id}</td>|;
     print qq|<td align="right">$ref->{amount}</td>|;
     print qq|</tr>|;
  }
  print qq|</table>|;



  print qq|<h3>Paid transactions from AP where amount booked on AP account in debit is different from amount booked on AP account in credit.
</h3>|;

  $query = qq|
        SELECT ap.invnumber, ac.trans_id, sum(ac.amount) amount
        FROM acc_trans ac 
        JOIN ap on (ap.id = ac.trans_id) 
        WHERE chart_id in (select id from chart where link='AP') 
        AND ap.amount = ap.paid 
        AND ap.transdate BETWEEN '$form->{firstdate}' AND '$form->{lastdate}'
        GROUP BY ap.invnumber, ac.trans_id 
        HAVING round(sum(ac.amount)::numeric, 2) <> 0
|;
  $sth = $dbh->prepare($query) || $form->dberror($query);
  $sth->execute;
  print qq|<table>|;
  print qq|<tr class=listheading>|;
  print qq|<th class=listheading>|.$locale->text('Invoice Number').qq|</td>|;
  print qq|<th class=listheading>|.$locale->text('Trans ID').qq|</td>|;
  print qq|<th class=listheading>|.$locale->text('Amount').qq|</td>|;
  print qq|</tr>|;
  $i = 0;
  while ($ref = $sth->fetchrow_hashref(NAME_lc)){
     if ($ref->{invoice}){
        $module = 'ir.pl';
     } else {
        $module = 'ap.pl';
     }
     print qq|<tr class=listrow$i>|;
     print qq|<td><a href=$module?action=edit&id=$ref->{trans_id}&path=$form->{path}&login=$form->{login}&callback=$callback>$ref->{invnumber}</a></td>|;
     print qq|<td>$ref->{trans_id}</td>|;
     print qq|<td align="right">$ref->{amount}</td>|;
     print qq|</tr>|;
  }
  print qq|</table>|;



  #-------------------
  # 3. Orphaned Rows
  #-------------------
  print qq|<h3>Orphaned Rows</h3>|;
  $form->info('To delete these orphaned rows, run following query in psql or phpPgAdmin or pgAdmin3. 

Important: Make sure you have a tested backup before running this delete query.');
  print qq|<pre>
DELETE FROM acc_trans 
WHERE trans_id NOT IN
(SELECT id FROM ar UNION ALL SELECT id FROM ap UNION ALL SELECT id FROM gl);
</pre>|;
	
  $query = qq|
		SELECT ac.trans_id, ac.transdate, c.accno, c.description, ac.amount, ac.memo, ac.source
		FROM acc_trans ac
		JOIN chart c ON (c.id = ac.chart_id)
		WHERE trans_id NOT IN 
			(SELECT id FROM ar 
			UNION ALL  
			SELECT id FROM ap
			UNION ALL
			SELECT id FROM gl)
  |;
  $sth = $dbh->prepare($query) || $form->dberror($query);
  $sth->execute;
  print qq|<table>|;
  print qq|<tr class=listheading>|;
  print qq|<th class=listheading>|.$locale->text('Trans ID').qq|</td>|;
  print qq|<th class=listheading>|.$locale->text('Date').qq|</td>|;
  print qq|<th class=listheading>|.$locale->text('Account').qq|</td>|;
  print qq|<th class=listheading>|.$locale->text('Description').qq|</td>|;
  print qq|<th class=listheading>|.$locale->text('Amount').qq|</td>|;
  print qq|<th class=listheading>|.$locale->text('Memo').qq|</td>|;
  print qq|<th class=listheading>|.$locale->text('Source').qq|</td>|;
  print qq|</tr>|;
  $i = 0;
  while ($ref = $sth->fetchrow_hashref(NAME_lc)){
     print qq|<tr class=listrow$i>|;
     print qq|<td>$ref->{trans_id}</td>|;
     print qq|<td>$ref->{transdate}</td>|;
     print qq|<td>$ref->{accno}</td>|;
     print qq|<td>$ref->{description}</td>|;
     print qq|<td align="right">$ref->{amount}</td>|;
     print qq|<td>$ref->{memo}</td>|;
     print qq|<td>$ref->{source}</td>|;
     print qq|</tr>|;
  }
  print qq|</table>|;

  #---------------------------------------
  # 4. Transactions with Deleted Accounts
  #---------------------------------------
  print qq|<h3>Deleted Accounts</h3>|;
  $query = qq|
		SELECT trans_id, chart_id, source, transdate, amount
		FROM acc_trans
		WHERE chart_id NOT IN (SELECT id FROM chart)
  |;
  $sth = $dbh->prepare($query) || $form->dberror($query);
  $sth->execute;
  print qq|<table>|;
  print qq|<tr class=listheading>|;
  print qq|<th class=listheading>|.$locale->text('Chart ID').qq|</td>|;
  print qq|<th class=listheading>|.$locale->text('Source').qq|</td>|;
  print qq|<th class=listheading>|.$locale->text('Date').qq|</td>|;
  print qq|<th class=listheading>|.$locale->text('Amount').qq|</td>|;
  print qq|</tr>|;
  $i = 0;
  while ($ref = $sth->fetchrow_hashref(NAME_lc)){
     print qq|<tr class=listrow$i>|;
     print qq|<td>$ref->{chart_id}</td>|;
     print qq|<td>$ref->{source}</td>|;
     print qq|<td>$ref->{transdate}</td>|;
     print qq|<td align=right>$ref->{amount}</td>|;
     print qq|</tr>|;
  }
  print qq|</table>|;


  #----------------------------
  # 5. Duplicate Part Numbers
  #----------------------------
  print qq|<h3>Duplicate Parts</h3>|;
  $query = qq|
		SELECT partnumber, COUNT(*) AS cnt
		FROM parts
		GROUP BY partnumber
		HAVING COUNT(*) > 1
  |;
  $sth = $dbh->prepare($query) || $form->dberror($query);
  $sth->execute;
  print qq|<table>|;
  print qq|<tr class=listheading>|;
  print qq|<th class=listheading>|.$locale->text('Number').qq|</td>|;
  print qq|<th class=listheading>|.$locale->text('Duplicates').qq|</td>|;
  print qq|</tr>|;
  $i = 0;
  while ($ref = $sth->fetchrow_hashref(NAME_lc)){
     print qq|<tr class=listrow$i>|;
     print qq|<td>$ref->{partnumber}</td>|;
     print qq|<td align=right>$ref->{cnt}</td>|;
     print qq|</tr>|;
  }
  print qq|</table>|;

  #-----------------------------
  # 6. Invoices with Deleted Parts
  #-----------------------------
  print qq|<h3>Deleted Parts</h3>|;
  $query = qq|
		SELECT trans_id, parts_id, description, qty
		FROM invoice
		WHERE parts_id NOT IN (SELECT id FROM parts)
  |;
  $sth = $dbh->prepare($query) || $form->dberror($query);
  $sth->execute;
  print qq|<table>|;
  print qq|<tr class=listheading>|;
  print qq|<th class=listheading>|.$locale->text('Part ID').qq|</td>|;
  print qq|<th class=listheading>|.$locale->text('Description').qq|</td>|;
  print qq|<th class=listheading>|.$locale->text('Qty').qq|</td>|;
  print qq|</tr>|;
  $i = 0;
  while ($ref = $sth->fetchrow_hashref(NAME_lc)){
     print qq|<tr class=listrow$i>|;
     print qq|<td>$ref->{parts_id}</td>|;
     print qq|<td>$ref->{description}</td>|;
     print qq|<td align=right>$ref->{qty}</td>|;
     print qq|</tr>|;
  }
  print qq|
</table>
|;


  #-----------------------------
  # 6a. Invoices with Deleted Parts
  #-----------------------------
  print qq|<h3>Invoices with missing customer.</h3>|;
  $query = qq|
		SELECT 'AR', id, invnumber, transdate, amount 
		FROM ar
		WHERE customer_id NOT IN (SELECT id FROM customer)

        UNION ALL

		SELECT 'AP', id, invnumber, transdate, amount 
		FROM ap
		WHERE vendor_id NOT IN (SELECT id FROM vendor)

        ORDER BY 1, 3
  |;
  $sth = $dbh->prepare($query) || $form->dberror($query);
  $sth->execute;
  print qq|<table>|;
  print qq|<tr class=listheading>|;
  print qq|<th class=listheading>|.$locale->text('ID').qq|</td>|;
  print qq|<th class=listheading>|.$locale->text('Invoice Number').qq|</td>|;
  print qq|<th class=listheading>|.$locale->text('Date').qq|</td>|;
  print qq|<th class=listheading>|.$locale->text('Amount').qq|</td>|;
  print qq|</tr>|;
  $i = 0;
  while ($ref = $sth->fetchrow_hashref(NAME_lc)){
     print qq|<tr class=listrow$i>|;
     print qq|<td>$ref->{id}</td>|;
     print qq|<td>$ref->{invnumber}</td>|;
     print qq|<td>$ref->{transdate}</td>|;
     print qq|<td align=right>$ref->{amount}</td>|;
     print qq|</tr>|;
  }
  print qq|
</table>
|;



  #-----------------------------
  # 7. invoice table with blank dates
  #-----------------------------
  print qq|<h3>Missing dates in invoice table</h3>|;
  $query = qq|SELECT COUNT(*) FROM invoice WHERE transdate IS NULL|;
  my ($blankrows) = $dbh->selectrow_array($query);
  if ($blankrows){
     print qq|<p>There were '| . $blankrows . qq| rows with blank transdate in invoice table. Being corrected now ...'|;
     $dbh->do('UPDATE invoice SET transdate = (SELECT transdate FROM ar WHERE ar.id = invoice.trans_id) WHERE trans_id IN (SELECT id FROM ar) AND transdate IS NULL');
     $dbh->do('UPDATE invoice SET transdate = (SELECT transdate FROM ap WHERE ap.id = invoice.trans_id) WHERE trans_id IN (SELECT id FROM ap) AND transdate IS NULL');
     print qq|<p>... corrected.</p>|;
  } else {
     print qq|<p>... ok.</p>|;
  }

  #-----------------------------
  # 7. inventory table with blank dates
  #-----------------------------
  print qq|<h3>Missing dates in inventory table</h3>|;
  $query = qq|SELECT COUNT(*) FROM inventory WHERE shippingdate IS NULL|;
  my ($blankrows) = $dbh->selectrow_array($query);
  if ($blankrows){
     print qq|<p>There are | . $blankrows . qq| rows with blank shippingdate in invoice table. ...'|;
     #$dbh->do('UPDATE invoice SET transdate = (SELECT transdate FROM ar WHERE ar.id = invoice.trans_id) WHERE trans_id IN (SELECT id FROM ar) AND transdate IS NULL');
     #$dbh->do('UPDATE invoice SET transdate = (SELECT transdate FROM ap WHERE ap.id = invoice.trans_id) WHERE trans_id IN (SELECT id FROM ap) AND transdate IS NULL');
     print qq|<p>... check.</p>|;
  } else {
     print qq|<p>... ok.</p>|;
  }

  print qq|<h3>Incorrect line tax transactions ...</h3>|;

  $query = qq|
       SELECT ap.id, 'AP' as module, ap.invnumber, ap.transdate, ap.amount, ap.netamount, ap.amount - ap.netamount tax1, sum(ac.taxamount * -1) tax2
       FROM ap 
       JOIN acc_trans ac on ap.id = ac.trans_id 
       AND ap.id in (select distinct trans_id from acc_trans where tax is not null and tax <> '') 
       AND ap.transdate BETWEEN '$form->{firstdate}' AND '$form->{lastdate}'
       GROUP BY 1, 2, 3, 4, 5, 6

       UNION 

       SELECT ar.id, 'AR' as module, ar.invnumber, ar.transdate, ar.amount, ar.netamount, ar.amount - ar.netamount tax1, sum(ac.taxamount) tax2
       FROM ar
       JOIN acc_trans ac on ar.id = ac.trans_id 
       AND ar.id in (select distinct trans_id from acc_trans where tax is not null and tax <> '') 
       AND ar.transdate BETWEEN '$form->{firstdate}' AND '$form->{lastdate}'
       GROUP BY 1, 2, 3, 4, 5, 6

       ORDER BY 2,3
  |;

  $sth = $dbh->prepare($query) || $form->dberror($query);
  $sth->execute;
  print qq|<table>|;
  print qq|<tr class=listheading>|;
  print qq|<th class=listheading>|.$locale->text('Module').qq|</td>|;
  print qq|<th class=listheading>|.$locale->text('Invoice Number').qq|</td>|;
  print qq|<th class=listheading>|.$locale->text('Date').qq|</td>|;
  print qq|<th class=listheading>|.$locale->text('Amount').qq|</td>|;
  print qq|<th class=listheading>|.$locale->text('Net Amount').qq|</td>|;
  print qq|<th class=listheading>|.$locale->text('Invoice Tax').qq|</td>|;
  print qq|<th class=listheading>|.$locale->text('Line Tax').qq|</td>|;
  print qq|</tr>|;

  $i = 0;

  my $module;
  my $total_amount;
  while ($ref = $sth->fetchrow_hashref(NAME_lc)){
     $module = lc $ref->{module};
     $module = 'ir' if $ref->{invoice} and $ref->{module} eq 'AP';
     $module = 'is' if $ref->{invoice} and $ref->{module} eq 'AR';

     if ($form->round_amount($ref->{tax1}, 2) != $form->round_amount($ref->{tax2}, 2)){
     	print qq|<tr class=listrow$i>|;
     	print qq|<td>$ref->{module}</td>|;
     	print qq|<td><a href=$module.pl?action=edit&id=$ref->{id}&path=$form->{path}&login=$form->{login}&callback=$callback>$ref->{invnumber}</a></td>|;
     	print qq|<td>$ref->{transdate}</td>|;
     	print qq|<td align=right>|.$form->format_amount(\%myconfig, $ref->{amount}, 2).qq|</td>|;
     	print qq|<td align=right>|.$form->format_amount(\%myconfig, $ref->{netamount}, 2).qq|</td>|;
     	print qq|<td align=right>|.$form->format_amount(\%myconfig, $ref->{tax1}, 2).qq|</td>|;
     	print qq|<td align=right>|.$form->format_amount(\%myconfig, $ref->{tax2}, 2).qq|</td>|;
     	print qq|</tr>|;
     }
  }
  print qq|</table>|;

  print qq|<h3>Updating null linetax column to blank ('') in acc_trans for correcting sorting in GL report.</h3>|;
  $dbh->do("update acc_trans set tax='' where tax is null");
  print qq|<p>... done.</p>|;
  $dbh->disconnect;
}


sub click_here_to_delete_blank_rows {
  my $dbh = $form->dbconnect(\%myconfig);
  $query = qq|
    DELETE
    FROM acc_trans 
    WHERE amount = 0 
    AND chart_id NOT IN (SELECT id FROM chart WHERE link LIKE '%_tax%')
|;
  $dbh->do($query);
  $form->info($locale->text('Blank rows deleted if any ...'));
}


sub click_here_to_delete_blank_tax_rows {
  my $dbh = $form->dbconnect(\%myconfig);
  $query = qq|
    DELETE
    FROM acc_trans 
    WHERE amount = 0 
    AND chart_id IN (SELECT id FROM chart WHERE link LIKE '%_tax%')
|;
  $dbh->do($query);
  $form->info($locale->text('Blank TAX rows deleted if any ...'));
}

sub click_here_to_delete_blank_non_tax_rows {
  my $dbh = $form->dbconnect(\%myconfig);
  $query = qq|
    DELETE
    FROM acc_trans 
    WHERE amount = 0 
    AND chart_id IN (SELECT id FROM chart WHERE link NOT LIKE '%_tax%')
|;
  $dbh->do($query);
  $form->info($locale->text('Blank non-TAX rows deleted if any ...'));
}

sub fix_invoicetax_for_alltaxes_report {
    #use DBIx::Simple;
    my $dbh = $form->dbconnect(\%myconfig);
    #my $dbs = DBIx::Simple->connect($dbh);

    $form->info("Building invoicetax table<br>\n");
    $query = qq|DELETE FROM invoicetax|;
    $dbh->do($query) || $form->dberror($query);

    my $query = qq|
	    SELECT i.id, i.trans_id, i.parts_id, i.qty * i.sellprice amount,
		(i.qty * i.sellprice * tax.rate) AS taxamount, 
		ptax.chart_id
	    FROM invoice i
	    JOIN partstax ptax ON (ptax.parts_id = i.parts_id)
	    JOIN tax ON (tax.chart_id = ptax.chart_id)
	    WHERE i.trans_id = ?
	    AND ptax.chart_id = ?|;
    my $itsth = $dbh->prepare($query) || $form->dberror($query);

    $query = qq|INSERT INTO invoicetax (trans_id, invoice_id, chart_id, amount, taxamount)
		   VALUES (?, ?, ?, ?, ?)|;
    my $itins = $dbh->prepare($query) || $form->dberror($query);

    ## 1. First AR
    $query = qq|SELECT ar.id, ar.customer_id, ctax.chart_id 
		FROM ar
		JOIN customertax ctax ON (ar.customer_id = ctax.customer_id)|;
    $sth = $dbh->prepare($query) || $form->dberror($query);
    $sth->execute;
    while ($ref = $sth->fetchrow_hashref(NAME_lc)){
	    $itsth->execute($ref->{id}, $ref->{chart_id});
        while ($itref = $itsth->fetchrow_hashref(NAME_lc)){
            $itins->execute($itref->{trans_id}, $itref->{id}, $itref->{chart_id}, $itref->{amount}, $itref->{taxamount});
        }
    }

    ## 2. Now AP
    $query = qq|SELECT ap.id, ap.vendor_id, vtax.chart_id 
		FROM ap
		JOIN vendortax vtax ON (ap.vendor_id = vtax.vendor_id)|;
    $sth = $dbh->prepare($query) || $form->dberror($query);
    $sth->execute;
    while ($ref = $sth->fetchrow_hashref(NAME_lc)){
	$itsth->execute($ref->{id}, $ref->{chart_id});
       while ($itref = $itsth->fetchrow_hashref(NAME_lc)){
          $itins->execute($itref->{trans_id}, $itref->{id}, $itref->{chart_id}, $itref->{amount}*-1, $itref->{taxamount}*-1);
       }
    }
    $form->info($locale->text('Done ...'));
}

######
# EOF 
######

