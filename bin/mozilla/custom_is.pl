# WLprinter start
#$printer{Netzwerkdrucker} = "wlprinter/fileprinter.pl $form->{login}";
# WLprinter end

require "$form->{path}/lib.pl";

1;

sub continue { &{$form->{nextsub}} };

#===================================
#
# Repost COGS
#
#===================================
#-----------------------------------
sub ask_repost {
   $form->{title} = $locale->text("Repost COGS");
   &print_title;
   &start_form;
 
   print qq|<h2 class=confirm> Continue with COGS reposting?</h1>|;
   print qq|
<table>
<tr>
  <th>|.$locale->text('To').qq|</th>
  <td><input type=text name=todate size=11 title='$myconfig{dateformat}'></td>
</tr>
<tr>
  <th></th>
  <td nowrap="nowrap"><input name="build_invoicetax" class="checkbox" value="Y" type="checkbox"> Build invoicetax table.</td>
</tr>
</table>
<br>
|;
   $form->{nextsub} = 'repost_cogs';
   &print_hidden('nextsub');
   &add_button('Continue');
   &end_form;
}

#-----------------------------------
sub repost_cogs {
   my $dbh = $form->dbconnect(\%myconfig);
   my ($warehouse, $warehouse_id) = split (/--/, $form->{warehouse});
   $warehouse_id *= 1;
   $form->info("Reposting COGS for warehouse $warehouse\n") if $form->{warehouse};

   # Build invoicetax table
   if ($form->{build_invoicetax}){
      $form->info("Building invoicetax table<br>\n");
      $query = qq|DELETE FROM invoicetax|;
      $dbh->do($query) || $form->dberror($query);

      my $query = qq|
	    SELECT i.id, i.trans_id, i.parts_id, 
		(i.qty * i.sellprice * tax.rate) AS taxamount, 
		ptax.chart_id
	    FROM invoice i
	    JOIN partstax ptax ON (ptax.parts_id = i.parts_id)
	    JOIN tax ON (tax.chart_id = ptax.chart_id)
	    WHERE i.trans_id = ?
	    AND ptax.chart_id = ?|;
      my $itsth = $dbh->prepare($query) || $form->dberror($query);

      $query = qq|INSERT INTO invoicetax (trans_id, invoice_id, chart_id, taxamount)
		   VALUES (?, ?, ?, ?)|;
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
	    $itins->execute($itref->{trans_id}, $itref->{id}, 
			$itref->{chart_id}, $itref->{taxamount});
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
	    $itins->execute($itref->{trans_id}, $itref->{id}, 
			$itref->{chart_id}, $itref->{taxamount});
	 }
      }

   }

   $form->info("Reposting COGS<br>");

   # Now Empty fifo table
   if ($form->{warehouse}){
 	$query = qq|DELETE FROM fifo WHERE warehouse_id = $warehouse_id|;
   } else {
	$query = qq|DELETE FROM fifo|;
   }
   $dbh->do($query) || $form->dberror($query);

   # Now update lastcost column in invoice table for AP
   $form->info("Updating AP lastcost<br>");
   $query = qq|UPDATE invoice SET lastcost = sellprice WHERE trans_id IN (SELECT id FROM ap)|;
   $dbh->do($query) || $form->dberror($query);

   # Now update lastcost column in invoice table for AR
   $form->info("Updating AR lastcost<br>");
   $query = qq|SELECT i.parts_id, ar.transdate, i.id, i.sellprice, 'AR' AS aa
	       FROM invoice i
	       JOIN ar ON (ar.id = i.trans_id)

	       UNION ALL

	       SELECT i.parts_id, ap.transdate, i.id, i.sellprice, 'AP' AS aa
	       FROM invoice i
	       JOIN ap ON (ap.id = i.trans_id)

	       ORDER BY 1,2,3
   |;
   $sth = $dbh->prepare($query) || $form->dberror($query);
   $sth->execute;

   $query = qq|UPDATE invoice SET lastcost = ? WHERE id = ?|;
   $updateinvoice = $dbh->prepare($query) || $form->error($query);

   my $parts_id = 0;
   my $lastcost = 0;
   while ($ref = $sth->fetchrow_hashref(NAME_lc)){
     if ($parts_id != $ref->{parts_id}){
        $form->info("-- Processing part $ref->{parts_id} ...<br>");
	$parts_id = $ref->{parts_id};
	$lastcost = 0;
     }
     if ($ref->{aa} eq 'AP'){
	$lastcost = $ref->{sellprice};
     } else {
	$updateinvoice->execute($lastcost, $ref->{id});
     }
   }

   # COGS Reposting. First re-post invoices based on FIFO
   $form->info("Reallocating inventory<br>");

   # Remove all current allocations
   $query = qq|UPDATE invoice SET allocated = 0, cogs = 0|;
   $dbh->do($query) || $form->dberror($query);
   
   $query = qq|UPDATE invoice SET cogs = qty * lastcost WHERE qty < 0|;
   $dbh->do($query) || $form->dberror($query);

   $query = qq|UPDATE inventory SET cogs = 0 WHERE trans_id NOT IN (SELECT id FROM trf)|;
   $dbh->do($query) || $form->dberror($query);

   # SELECT parts with unallocated quantities
   $query = qq|SELECT id, partnumber, description 
		FROM parts 
		WHERE id IN (SELECT DISTINCT parts_id FROM invoice WHERE qty < 0)
		AND inventory_accno_id IS NOT NULL|;
   $sth = $dbh->prepare($query) || $form->dberror($query);
   $sth->execute;

   $query = qq|UPDATE invoice SET allocated = allocated + ?, cogs = cogs + ? WHERE id = ?|;
   $invoiceupdate = $dbh->prepare($query) || $form->dberror($query);
   $query = qq|UPDATE inventory SET cogs = cogs + ?, cost = ? WHERE invoice_id = ?|;
   $inventoryupdate = $dbh->prepare($query) || $form->dberror($query);

   $query = qq|INSERT INTO fifo (
			trans_id, transdate, parts_id, 
			qty, costprice, sellprice,
			warehouse_id, invoice_id)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?)|;
   $fifoadd = $dbh->prepare($query) || $form->dberror($query);

   my $whwhere = '';
   $whwhere .= qq| AND warehouse_id = $warehouse_id| if $form->{warehouse};
   $whwhere .= qq| AND transdate <= '$form->{todate}'| if $form->{todate};

   $apquery = qq|SELECT id, qty, lastcost AS sellprice
		FROM invoice 
		WHERE parts_id = ? 
		$whwhere
		AND qty < 0 
		ORDER BY trans_id|;
   $apsth = $dbh->prepare($apquery) || $form->dberror($apquery);

   $arquery = qq|SELECT id, trans_id, transdate, qty, sellprice,
				qty+allocated AS unallocated
			FROM invoice 
			WHERE parts_id = ?
			$whwhere
			AND qty > 0 
			AND (qty + allocated) > 0
			ORDER BY trans_id|;
   $arsth = $dbh->prepare($arquery) || $form->dberror($arquery);
   while ($partsref = $sth->fetchrow_hashref(NAME_lc)){
	print "--- Processing $partsref->{partnumber}--$partsref->{description}<br>\n";
	$apsth->execute($partsref->{id});
	while ($apref = $apsth->fetchrow_hashref(NAME_lc)){
	    $qty2allocate = 0 - $apref->{qty}; # qty IN is always -ve so change sign for clarity
	    # select unallocated sale invoice transactions
	    $arsth->execute($partsref->{id});
	    $inventoryupdate->execute($apref->{sellprice} * $apref->{qty} * -1, $apref->{sellprice}, $apref->{id});
	    while ($arref = $arsth->fetchrow_hashref(NAME_lc)){
	        #print "----- Invoice ID $arref->{id}<br>\n";
		if ($qty2allocate != 0){
		   if ($qty2allocate > $arref->{unallocated}){
		      $thisallocation = $arref->{unallocated};
		      $qty2allocate -= $thisallocation;
		   } else {
		      $thisallocation = $qty2allocate;
		      $qty2allocate = 0;
		   }
		   $invoiceupdate->execute($thisallocation, 0, $apref->{id}) || $form->error('Error updating AP');
		   $invoiceupdate->execute(0.00 - $thisallocation, $apref->{sellprice} * $thisallocation, $arref->{id}) || $form->error('Error updating AR');
		   $inventoryupdate->execute($apref->{sellprice} * $thisallocation * -1, $apref->{sellprice},  $arref->{id});
		   $fifoadd->execute($arref->{trans_id}, "$arref->{transdate}", $partsref->{id},
				$thisallocation, $apref->{sellprice}, $arref->{sellprice},
				$warehouse_id, $apref->{id});
		}
	    }
	}
   }

   $form->info("Reposting COGS<br>");

   # Delete old COGS 
   $query = qq|DELETE FROM acc_trans
		WHERE chart_id IN (
		  SELECT id
		  FROM chart
		  WHERE (link LIKE '%IC_cogs%')
		  OR (link = 'IC'))
		AND trans_id IN (
		  SELECT id 
		  FROM ar 
		  WHERE invoice is true
		  $whwhere)
   |;
   $dbh->do($query) || $form->dberror($query);

   # Post new COGS
   my $cogsquery = qq|INSERT INTO acc_trans(
			trans_id, chart_id, amount, 
			transdate, source, id)
                        VALUES (?, ?, ?, ?, ?, ?)|;
   my $cogssth = $dbh->prepare($cogsquery) or $form->dberror($cogsquery);

   my $where;
   $where .= qq| AND f.warehouse_id = $warehouse_id| if $form->{warehouse};
   $query = qq|SELECT f.trans_id, f.transdate, 
		      f.qty * f.costprice AS amount,
		      p.inventory_accno_id, p.expense_accno_id,
		      f.invoice_id
		FROM fifo f
		JOIN parts p ON (p.id = f.parts_id)
   		WHERE f.trans_id IN (SELECT id FROM ar)
		$where|;
   $sth = $dbh->prepare($query) || $form->dberror($query);
   $sth->execute;
   while ($ref = $sth->fetchrow_hashref(NAME_lc)){
	$form->info("-- Processing transaction $ref->{trans_id}<br>");
	$cogssth->execute(
		$ref->{trans_id}, $ref->{inventory_accno_id}, 
		$ref->{amount}, $ref->{transdate}, 'cogs', $ref->{invoice_id});
	$cogssth->execute(
		$ref->{trans_id}, $ref->{expense_accno_id},
		0-($ref->{amount}), $ref->{transdate}, 'cogs', $ref->{invoice_id});
   }

   # Reverse COGS for sale returns / credit invoices
   my $query = qq|DELETE FROM acc_trans 
		WHERE chart_id = ?
		AND trans_id = ?|;
   my $saledelete = $dbh->prepare($query) || $form->dberror($query);

   $query = qq|SELECT i.id, i.trans_id, i.transdate,
			i.qty * i.lastcost AS cogs,
			(i.sellprice - (i.sellprice * i.discount/100))*i.qty*1 AS sale,
			p.inventory_accno_id, p.expense_accno_id,
			p.income_accno_id,
			i.parts_id, i.sellprice, i.warehouse_id,
			i.qty, i.lastcost
		FROM invoice i
		JOIN parts p ON (p.id = i.parts_id)
		WHERE trans_id IN (SELECT id FROM ar WHERE netamount < 0)
		$whwhere 
		ORDER BY i.trans_id
   |;
   $sth = $dbh->prepare($query) || $form->dberror($query);
   $sth->execute;

   # Delete income 
   while (my $ref = $sth->fetchrow_hashref(NAME_lc)){
	# Delete/repost sale account transactions
	$saledelete->execute($ref->{income_accno_id}, $ref->{trans_id});
   }

   $sth = $dbh->prepare($query) || $form->dberror($query);
   $sth->execute;
   while (my $ref = $sth->fetchrow_hashref(NAME_lc)){
	   # Post income
           $cogssth->execute(
		$ref->{trans_id}, $ref->{income_accno_id}, 
		$ref->{sale}, $ref->{transdate}, 
		"income", $ref->{id});

	   if ($ref->{inventory_accno_id}){
	     # Delete/repost cogs transactions
             $cogssth->execute(
		$ref->{trans_id}, $ref->{inventory_accno_id}, 
		$ref->{cogs}, $ref->{transdate}, "cogs:$ref->{sale}:$ref->{id}", $ref->{id});
             $cogssth->execute(
		$ref->{trans_id}, $ref->{expense_accno_id},
		0-($ref->{cogs}), $ref->{transdate}, "cogs:$ref->{sale}:$ref->{id}", $ref->{id});
	   }

	   $fifoadd->execute($ref->{trans_id}, "$ref->{transdate}", $ref->{parts_id},
		$ref->{qty}, $ref->{lastcost}, $ref->{sellprice},
		$warehouse_id, $ref->{id});

   }
   $sth->finish;
   $dbh->disconnect;
   print qq|<h2 class=confirm>Completed</h2>|;
}

##
## EOF
##

