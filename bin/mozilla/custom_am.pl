1;

require "$form->{path}/mylib.pl";

sub continue { &{$form->{nextsub} } };

sub ask_dbcheck {
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
<form method=post action='$form->{script}'>
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
  $form->{title} = $locale->text('Ledger Doctor');
  $form->header;
  print qq|<body><table width=100%><tr><th class=listtop>$form->{title}</th></tr></table><br />|;
  my $dbh = $form->dbconnect(\%myconfig);
  my $query, $sth, $i;
  my $callback = "$form->{script}?action=do_dbcheck&firstdate=$form->{firstdate}&lastdate=$form->{lastdate}&path=$form->{path}&login=$form->{login}";
  $callback = $form->escape($callback);

  #------------------
  # 1. Invalid Dates
  #------------------
  print qq|<h2>Invalid Dates</h2>|;
  $query = qq|
		SELECT 'AR' AS module, id, invnumber, transdate 
		FROM ar
		WHERE transdate < '$form->{firstdate}'
		OR transdate > '$form->{lastdate}'

		UNION ALL

		SELECT 'AP' AS module, id, invnumber, transdate 
		FROM ap
		WHERE transdate < '$form->{firstdate}'
		OR transdate > '$form->{lastdate}'

		UNION ALL

		SELECT 'GL' AS module, id, reference, transdate 
		FROM gl
		WHERE transdate < '$form->{firstdate}'
		OR transdate > '$form->{lastdate}'
  |;
  $sth = $dbh->prepare($query) || $form->dberror($query);
  $sth->execute;
  print qq|<table>|;
  print qq|<tr class=listheading>|;
  print qq|<th class=listheading>|.$locale->text('Module').qq|</td>|;
  print qq|<th class=listheading>|.$locale->text('Invoice Number / Reference').qq|</td>|;
  print qq|<th class=listheading>|.$locale->text('Date').qq|</td>|;
  print qq|</tr>|;
  $i = 0;

  while ($ref = $sth->fetchrow_hashref(NAME_lc)){
     $module = lc $ref->{module};
     $module = 'ir' if $ref->{invoice} and $ref->{module} eq 'AP';
     $module = 'is' if $ref->{invoice} and $ref->{module} eq 'AR';

     print qq|<tr class=listrow$i>|;
     print qq|<td>$ref->{module}</td>|;
     print qq|<td><a href=$module.pl?action=edit&id=$ref->{id}&path=$form->{path}&login=$form->{login}&callback=$callback>$ref->{invnumber}</a></td>|;
     print qq|<td>$ref->{transdate}</td>|;
     print qq|</tr>|;
  }
  print qq|</table>|;

  #------------------------
  # 2. Unbalanced Journals
  #------------------------
  print qq|<h3>Unbalanced Journals</h3>|;
  $query = qq|
	SELECT 'GL' AS module, gl.reference AS invnumber, gl.id,
		gl.transdate, false AS invoice, SUM(ac.amount) AS amount
	FROM acc_trans ac
	JOIN gl ON (gl.id = ac.trans_id)
    WHERE ac.transdate BETWEEN '2015-01-01 00:00' and '2016-01-01'
	GROUP BY 1, 2, 3, 4, 5
	HAVING SUM(ac.amount) > 0.005 OR SUM(ac.amount) < -0.005

	UNION ALL

	SELECT 'AR' AS module, ar.invnumber, ar.id,
		ar.transdate, ar.invoice, SUM(ac.amount) AS amount
	FROM acc_trans ac
	JOIN ar ON (ar.id = ac.trans_id)
    WHERE ac.transdate BETWEEN '2015-01-01 00:00' and '2016-01-01'
	GROUP BY 1, 2, 3, 4, 5
	HAVING SUM(ac.amount) > 0.005 OR SUM(ac.amount) < -0.005

	UNION ALL

	SELECT 'AP' AS module, ap.invnumber, ap.id,
		ap.transdate, ap.invoice, SUM(ac.amount) AS amount
	FROM acc_trans ac
	JOIN ap ON (ap.id = ac.trans_id)
    WHERE ac.transdate BETWEEN '2015-01-01 00:00' and '2016-01-01'
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



  $dbh->disconnect;
}

######
# EOF 
######

