#=====================================================================
# SQL-Ledger ERP
# Copyright (C) 2006
#
#  Author: DWS Systems Inc.
#     Web: http://www.sql-ledger.com
#
#======================================================================
#
# Order entry module
# Quotation
#
#======================================================================

package OE;


sub transactions {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);
 
  my $query;
  my $null;
  my $var;
  my $ordnumber = 'ordnumber';
  my $quotation = '0';
  my $where;
  my $orderitems_description;
  my $orderitems_join;
  
  # remove locks
  $form->remove_locks($myconfig, $dbh, 'oe');
  
  my %defaults = $form->get_defaults($dbh, \@{['precision', 'company']});
  for (keys %defaults) { $form->{$_} = $defaults{$_} }

  if ($form->{type} =~ /(ship|receive)_order/ || $form->{l_memo} eq 'Y') {
    $orderitems_description = ", oi.description AS memo";
    $orderitems_join = qq|JOIN orderitems oi ON (oi.trans_id = o.id)|;
  }

  if ($form->{detail}) {
    $orderitems_description .= ", oi.description AS memo, oi.sellprice, oi.qty, oi.id AS orderitemsid";
    $orderitems_join = qq|JOIN orderitems oi ON (oi.trans_id = o.id)| unless $orderitems_join;
  }

  $form->{vc} = 'vendor' if $form->{vc} ne 'customer'; # SQLI protection

  my $rate = ($form->{vc} eq 'customer') ? 'buy' : 'sell';

  ($form->{transdatefrom}, $form->{transdateto}) = $form->from_to($form->{year}, $form->{month}, $form->{interval}) if $form->{year} && $form->{month};

  if ($form->{type} =~ /_quotation$/) {
    $quotation = '1';
    $ordnumber = 'quonumber';
  }
  
  my $number = $form->like(lc $form->{$ordnumber});
  my $name = $form->like(lc $form->{$form->{vc}});
  
  for (qw(department warehouse employee)) {
    $form->{$_} = $form->dbclean($form->{$_});
    if ($form->{$_}) {
      ($null, $var) = split /--/, $form->{$_};
      $where .= " AND o.${_}_id = $var";
    }
  }
  
  my $query = qq|SELECT o.id, o.ordnumber, o.transdate, o.reqdate,
                 o.amount, ct.name, ct.$form->{vc}number, o.netamount,
		 o.$form->{vc}_id,
		 ex.$rate AS exchangerate,
		 o.closed, o.quonumber, o.shippingpoint, o.shipvia, o.waybill,
		 e.name AS employee, m.name AS manager, o.curr, o.ponumber,
		 o.notes, o.intnotes, w.description AS warehouse, o.description
		 $orderitems_description
	         FROM oe o
	         JOIN $form->{vc} ct ON (o.$form->{vc}_id = ct.id)
		 $orderitems_join
	         LEFT JOIN employee e ON (o.employee_id = e.id)
		 LEFT JOIN employee m ON (e.managerid = m.id)
	         LEFT JOIN warehouse w ON (o.warehouse_id = w.id)
	         LEFT JOIN exchangerate ex ON (ex.curr = o.curr
		                               AND ex.transdate = o.transdate)
	         WHERE o.quotation = '$quotation'
		 $where|;

  my %ordinal = ( id => 1,
                  ordnumber => 2,
                  transdate => 3,
		  reqdate => 4,
		  name => 6,
		  quonumber => 12,
		  shipvia => 14,
		  waybill => 15,
		  employee => 16,
		  manager => 17,
		  curr => 18,
		  ponumber => 19,
		  warehouse => 21,
		  description => 22
		);

  my @a = (transdate, $ordnumber, name);
  push @a, "employee" if $form->{l_employee};
  if ($form->{type} !~ /(ship|receive)_order/) {
    push @a, "manager" if $form->{l_manager};
  }
  my $sortorder = $form->sort_order(\@a, \%ordinal);
  
  
  # build query if type eq (ship|receive)_order
  if ($form->{type} =~ /(ship|receive)_order/) {

    #bp 2010-03-11 changed AND oi.qty > oi.ship
    $query .= qq|
	         AND o.quotation = '0'
		 AND oi.qty <> oi.ship
		 AND o.id NOT IN (SELECT id FROM semaphore)|;
		 
  }

  if ($form->{"$form->{vc}_id"}) {
    $form->{"$form->{vc}_id"} *= 1;
    $query .= qq| AND o.$form->{vc}_id = $form->{"$form->{vc}_id"}|;
  } else {
    if ($form->{$form->{vc}} ne "") {
      $query .= " AND lower(ct.name) LIKE '$name'";
    }
    if ($form->{"$form->{vc}number"} ne "") {
      $name = $form->like(lc $form->{"$form->{vc}number"});
      $query .= " AND lower(ct.$form->{vc}number) LIKE '$name'";
    }
  }

  if ($form->{$ordnumber} ne "") {
    $query .= " AND lower($ordnumber) LIKE '$number'";
    $form->{open} = 1;
    $form->{closed} = 1;
  }
  if ($form->{ponumber} ne "") {
    $ponumber = $form->like(lc $form->{ponumber});
    $query .= " AND lower(ponumber) LIKE '$ponumber'";
  }

  if (!$form->{open} && !$form->{closed}) {
    $query .= " AND o.id = 0";
  } elsif (!($form->{open} && $form->{closed})) {
    $query .= ($form->{open}) ? " AND o.closed = '0'" : " AND o.closed = '1'";
  }

  if ($form->{shipvia} ne "") {
    $var = $form->like(lc $form->{shipvia});
    $query .= " AND lower(o.shipvia) LIKE '$var'";
  }
  if ($form->{waybill} ne "") {
    $var = $form->like(lc $form->{waybill});
    $query .= " AND lower(o.waybill) LIKE '$var'";
  }
  if ($form->{notes} ne "") {
    $var = $form->like(lc $form->{notes});
    $query .= " AND lower(o.notes) LIKE '$var'";
  }
  if ($form->{description} ne "") {
    $var = $form->like(lc $form->{description});
    $query .= " AND lower(o.description) LIKE '$var'";
  }
  if ($form->{memo} ne "") {
    $var = $form->like(lc $form->{memo});
    $query .= " AND o.id IN (SELECT DISTINCT trans_id
                             FROM orderitems
			     WHERE lower(description) LIKE '$var')";
  }
  if ($form->{transdatefrom}) {
    $query .= " AND o.transdate >= '".$form->dbclean($form->{transdatefrom})."'";
  }
  if ($form->{transdateto}) {
    $query .= " AND o.transdate <= '".$form->dbclean($form->{transdateto})."'";
  }

  $query .= " ORDER by $sortorder";

  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  my %objid = ();
  my $i = -1;
  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    $ref->{exchangerate} ||= 1;
    if ($form->{detail}) {
      $i++;
      $ml = 1;
      if ($ref->{netamount}) {
	$ml = $ref->{amount} / $ref->{netamount};
      }
      $ref->{netamount} = $ref->{sellprice} * $ref->{qty};
      $ref->{amount} = $ref->{netamount} * $ml;
      push @{ $form->{OE} }, $ref;
      $objid{vc}{$ref->{curr}}{$ref->{"$form->{vc}_id"}}++;
    } else {
      if ($ref->{id} != $objid{id}{$ref->{id}}) {
	$i++;
	push @{ $form->{OE} }, $ref;
	$objid{vc}{$ref->{curr}}{$ref->{"$form->{vc}_id"}}++;
      } else {
	$form->{OE}[$i]->{memo} .= "\n$ref->{memo}" if $ref->{memo};
      }
    }
    $objid{id}{$ref->{id}} = $ref->{id};
  }
  $sth->finish;

  $dbh->disconnect;

  if ($form->{type} =~ /^consolidate_/) {
    @a = ();
    foreach $ref (@{ $form->{OE} }) { push @a, $ref if $objid{vc}{$ref->{curr}}{$ref->{"$form->{vc}_id"}} > 1 }

    @{ $form->{OE} } = @a;
  }
  
}


sub lookup_order {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query;
  my $ordnumber = $dbh->quote($form->{ordnumber});

  if ($form->{vc} eq 'customer') {
    $query = qq|SELECT id
                FROM oe
                WHERE ordnumber = $ordnumber
                AND customer_id > 0|;
  } else {
    $query = qq|SELECT id
                FROM oe
		WHERE ordnumber = $ordnumber
		AND vendor_id > 0|;
  }
  my ($id) = $dbh->selectrow_array($query);

  $dbh->disconnect;

  $id;

}
									

sub save {
  my ($self, $myconfig, $form) = @_;
    
  # connect to database, turn off autocommit
  my $dbh = $form->dbconnect_noauto($myconfig);

  my $query;
  my $sth;
  my $null;
  my $exchangerate = 0;
  my $ok;

  my %defaults = $form->get_defaults($dbh, \@{['precision']});
  $form->{precision} = $defaults{precision};
  
  ($null, $form->{employee_id}) = split /--/, $form->{employee};
  if (! $form->{employee_id}) {
    ($form->{employee}, $form->{employee_id}) = $form->get_employee($dbh);
    $form->{employee} = "$form->{employee}--$form->{employee_id}";
  }

  my $sw = ($form->{type} eq 'sales_order') ? 1 : -1;

  $query = qq|SELECT p.assembly, p.project_id
	      FROM parts p
	      WHERE p.id = ?|;
  my $pth = $dbh->prepare($query) || $form->dberror($query);

 
  if ($form->{id} *= 1) {
    $query = qq|SELECT id, aa_id FROM oe
                WHERE id = $form->{id}|;

    ($form->{id}, $form->{aa_id}) = $dbh->selectrow_array($query);
    
    if ($form->{id}) {
      &adj_onhand($dbh, $form, $sw) if $form->{type} =~ /_order$/ && ! $form->{aa_id};

      for (qw(dpt_trans orderitems shipto cargo)) {
	$query = qq|DELETE FROM $_
		    WHERE trans_id = $form->{id}|;
	$dbh->do($query) || $form->dberror($query);
      }

    } else {
      $query = qq|INSERT INTO oe (id)
                  VALUES ($form->{id})|;
      $dbh->do($query) || $form->dberror($query);
    }
  }

  #JHM imported purcahse orders will have id but not this
  for (qw(department warehouse)){
     ($null, $form->{"${_}_id"}) = split(/--/, $form->{$_});
     $form->{"${_}_id"} *= 1;
  }
 
  if (! $form->{id}) {
    
    my $uid = localtime;
    $uid .= $$;

    $query = qq|INSERT INTO oe (ordnumber, employee_id)
		VALUES (|.$dbh->quote($uid).qq|, |.$form->dbclean($form->{employee_id}).qq|)|;
    $dbh->do($query) || $form->dberror($query);
   
    $query = qq|SELECT id FROM oe
                WHERE ordnumber = |.$dbh->quote($uid).qq||;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);
    ($form->{id}) = $sth->fetchrow_array;
    $sth->finish;
    
  }

  my $amount;
  my $linetotal;
  my $discount;
  my $project_id;
  my $taxrate;
  my $fxsellprice;
  my %taxbase;
  my $taxbase;
  my @taxaccounts;
  my %taxaccounts;
  my $netamount = 0;
  my $lineitemdetail;

  my $uid = localtime;
  $uid .= $$;
 
  for $i (1 .. $form->{rowcount}) {

	$form->{"id_$i"} *= 1;

    for (qw(qty ship)) { $form->{"${_}_$i"} = $form->parse_amount($myconfig, $form->{"${_}_$i"}) }
     
    $form->{"discount_$i"} = $form->parse_amount($myconfig, $form->{"discount_$i"}) / 100;
    $form->{"sellprice_$i"} = $form->parse_amount($myconfig, $form->{"sellprice_$i"});
 
    if ($form->{"qty_$i"}) {

      $pth->execute($form->{"id_$i"});
      $ref = $pth->fetchrow_hashref(NAME_lc);
      for (keys %$ref) { $form->{"${_}_$i"} = $ref->{$_} }
      $pth->finish;

      $fxsellprice = $form->{"sellprice_$i"};

      my ($dec) = ($form->{"sellprice_$i"} =~ /\.(\d+)/);
      $dec = length $dec;
      my $decimalplaces = ($dec > $form->{precision}) ? $dec : $form->{precision};

      $discount = $form->round_amount($form->{"sellprice_$i"} * $form->{"discount_$i"}, $decimalplaces);
      $form->{"sellprice_$i"} = $form->round_amount($form->{"sellprice_$i"} - $discount, $decimalplaces);

      $linetotal = $form->round_amount($form->{"sellprice_$i"} * $form->{"qty_$i"} * (1 - $form->{"discount_$i"}/100), $form->{precision});
      
      @taxaccounts = split / /, $form->{"taxaccounts_$i"};
      $ml = 1;
      $tax = 0;
      
      for (0 .. 1) {
	$taxrate = 0;

	for (@taxaccounts) { $taxrate += $form->{"${_}_rate"} if ($form->{"${_}_rate"} * $ml) > 0 }
	
	$taxrate *= $ml;
	$taxamount = $linetotal * $taxrate / (1 + $taxrate);
	$taxbase = ($linetotal - $taxamount);
	
	foreach $item (@taxaccounts) {
	  if (($form->{"${item}_rate"} * $ml) > 0) {

	    if ($form->{taxincluded}) {
	      $taxaccounts{$item} += $linetotal * $form->{"${item}_rate"} / (1 + $taxrate);
	      $taxbase{$item} += $taxbase;
	    } else {
	      $taxbase{$item} += $linetotal;
	      $taxaccounts{$item} += $linetotal * $form->{"${item}_rate"};
	    }
	  }
	}

	if ($form->{taxincluded}) {
	  $tax += $linetotal * ($taxrate / (1 + ($taxrate * $ml)));
	} else {
	  $tax += $linetotal * $taxrate;
	}
	
	$ml *= -1;
      }

      $netamount += $form->{"sellprice_$i"} * $form->{"qty_$i"};
      
      $project_id = 'NULL';
      $form->{"projectnumber_$i"} = $form->dbclean($form->{"projectnumber_$i"});
      if ($form->{"projectnumber_$i"} ne "") {
	($null, $project_id) = split /--/, $form->{"projectnumber_$i"};
      }
      $project_id = $form->{"project_id_$i"} if $form->{"project_id_$i"};
      
      # add/save detail record in orderitems table
      $query = qq|INSERT INTO orderitems (description, trans_id, parts_id)
		  VALUES (|.$dbh->quote($uid).qq|, $form->{id}, |.$form->dbclean($form->{"id_$i"}).qq|)|;
      $dbh->do($query) || $form->dberror($query);

      $query = qq|SELECT id
		  FROM orderitems
		  WHERE description = |.$dbh->quote($uid).qq||;
      ($form->{"orderitems_id_$i"}) = $dbh->selectrow_array($query);

      $lineitemdetail = ($form->{"lineitemdetail_$i"}) ? 1 : 0;
      
      $query = qq|UPDATE orderitems SET
		  description = |.$dbh->quote($form->{"description_$i"}).qq|,
		  qty = |.$form->dbclean($form->{"qty_$i"}).qq|,
		  sellprice = $fxsellprice,
		  discount = $form->{"discount_$i"},
		  unit = |.$dbh->quote($form->{"unit_$i"}).qq|,
		  reqdate = |.$form->dbquote($form->dbclean($form->{"reqdate_$i"}), SQL_DATE).qq|,
		  project_id = |.$form->dbclean($project_id).qq|,
		  ship = |.$form->dbclean($form->{"ship_$i"}).qq|,
		  serialnumber = |.$dbh->quote($form->{"serialnumber_$i"}).qq|,
		  ordernumber = |.$dbh->quote($form->{"ordernumber_$i"}).qq|,
		  ponumber = |.$dbh->quote($form->{"customerponumber_$i"}).qq|,
		  itemnotes = |.$dbh->quote($form->{"itemnotes_$i"}).qq|,
		  lineitemdetail = '$lineitemdetail'
		  WHERE id = |.$form->dbclean($form->{"orderitems_id_$i"}).qq|
		  AND trans_id = $form->{id}|;
      $dbh->do($query) || $form->dberror($query);

      # armaghan When invoice is creatd from a not-shipped-received-order
      if ($form->{add_shipping}) {
         $query = qq|INSERT INTO inventory (parts_id, warehouse_id, department_id,
                  qty, trans_id, orderitems_id, shippingdate, employee_id)
                  VALUES (|.$form->dbclean($form->{"id_$i"}).qq|, |.$form->dbclean($form->{warehouse_id}).qq|, |.$form->dbclean($form->{department_id}).qq|,
		  $form->{"ship_$i"} * $sw * -1, $form->{id},
		  |.$form->dbclean($form->{"orderitems_id_$i"}).qq|, |.$dbh->quote($form->{transdate}).qq|,
		  |.$form->dbclean($form->{employee_id}).qq|)|;
         $dbh->do($query) || $form->dberror($query);
      }

      $form->{"sellprice_$i"} = $fxsellprice;

      # add package
      $ok = ($form->{"package_$i"} ne "") ? 1 : 0;
      for (qw(netweight grossweight volume)) {
	$form->{"${_}_$i"} = $form->parse_amount($myconfig, $form->{"${_}_$i"});
	$ok = 1 if $form->{"${_}_$i"};
      }
      if ($ok) {
	$query = qq|INSERT INTO cargo (id, trans_id, package, netweight,
	            grossweight, volume) VALUES ( |.$form->dbclean($form->{"orderitems_id_$i"}).qq|,
		    $form->{id}, |
		    .$dbh->quote($form->{"package_$i"}).qq|,
		    |.$form->dbclean($form->{"netweight_$i"}).qq|, |.$form->dbclean($form->{"grossweight_$i"}).qq|,
		    |.$form->dbclean($form->{"volume_$i"}).qq|)|;
        $dbh->do($query) || $form->dberror($query);
      }
      
      if ($form->{type} =~ /_order/) {
	if ($form->{"netweight_$i"}) {
	  $query = qq|UPDATE parts SET
	              weight = abs(|.$form->dbclean($form->{"netweight_$i"}).qq| / |.$form->dbclean($form->{"qty_$i"}).qq| * 1.0)
		      WHERE id = $form->{"id_$i"}|;
	  #$dbh->do($query) || $form->dberror($query);
	}
      }

    }
    $form->{"discount_$i"} *= 100;
  }


  # set values which could be empty
  for (qw(vendor_id customer_id taxincluded closed quotation)) { $form->{$_} *= 1 }

  # add up the tax
  my $tax = 0;
  for (keys %taxaccounts) { $tax += $form->round_amount($taxaccounts{$_}, $form->{precision}) }
  $netamount -= $tax if $form->{taxincluded};

  $amount = $form->round_amount($netamount + $tax, $form->{precision});
  $netamount = $form->round_amount($netamount, $form->{precision});

  if ($form->{currency} eq $form->{defaultcurrency}) {
    $form->{exchangerate} = 1;
  } else {
    $exchangerate = $form->check_exchangerate($myconfig, $form->{currency}, $form->{transdate}, ($form->{vc} eq 'customer') ? 'buy' : 'sell');
  }
  
  $form->{exchangerate} = ($exchangerate) ? $exchangerate : $form->parse_amount($myconfig, $form->{exchangerate});
  
  my $quotation;
  my $ordnumber;
  my $numberfld;
  if ($form->{type} =~ /_order$/) {
    $quotation = "0";
    $ordnumber = "ordnumber";
    $numberfld = ($form->{vc} eq 'customer') ? "sonumber" : "ponumber";
  } else {
    $quotation = "1";
    $ordnumber = "quonumber";
    $numberfld = ($form->{vc} eq 'customer') ? "sqnumber" : "rfqnumber";
  }

  $form->{$ordnumber} = $form->update_defaults($myconfig, $numberfld, $dbh) unless $form->{$ordnumber}; 
  
  $form->{terms} *= 1;

  # save OE record
  $query = qq|UPDATE oe set
	      ordnumber = |.$dbh->quote($form->{ordnumber}).qq|,
	      quonumber = |.$dbh->quote($form->{quonumber}).qq|,
              description = |.$dbh->quote($form->{description}).qq|,
              transdate = |.$dbh->quote($form->{transdate}).qq|,
              vendor_id = |.$form->dbclean($form->{vendor_id}).qq|,
	      customer_id = |.$form->dbclean($form->{customer_id}).qq|,
              amount = $amount,
              netamount = $netamount,
	      reqdate = |.$form->dbquote($form->dbclean($form->{reqdate}), SQL_DATE).qq|,
	      taxincluded = |.$dbh->quote($form->{taxincluded}).qq|,
	      shippingpoint = |.$dbh->quote($form->{shippingpoint}).qq|,
	      shipvia = |.$dbh->quote($form->{shipvia}).qq|,
	      waybill = |.$dbh->quote($form->{waybill}).qq|,
	      notes = |.$dbh->quote($form->{notes}).qq|,
	      intnotes = |.$dbh->quote($form->{intnotes}).qq|,
	      curr = |.$dbh->quote($form->{currency}).qq|,
	      closed = |.$dbh->quote($form->{closed}).qq|,
	      quotation = '$quotation',
	      department_id = |.$form->dbclean($form->{department_id}).qq|,
	      employee_id = |.$form->dbclean($form->{employee_id}).qq|,
	      language_code = |.$dbh->quote($form->{language_code}).qq|,
	      ponumber = |.$dbh->quote($form->{ponumber}).qq|,
	      terms = |.$form->dbclean($form->{terms}).qq|,
	      warehouse_id = |.$form->dbclean($form->{warehouse_id}).qq|,
	      exchangerate = |.$form->dbclean($form->{exchangerate}).qq|
              WHERE id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

  $form->{ordtotal} = $amount;

  # add shipto
  $form->{name} = $form->{$form->{vc}};
  $form->{name} =~ s/--$form->{"$form->{vc}_id"}//;
  $form->add_shipto($dbh, $form->{id});

  # save printed, emailed, queued
  $form->save_status($dbh); 
    
  if (($form->{currency} ne $form->{defaultcurrency}) && !$exchangerate) {
    if ($form->{vc} eq 'customer') {
      $form->update_exchangerate($dbh, $form->{currency}, $form->{transdate}, $form->{exchangerate}, 0);
    }
    if ($form->{vc} eq 'vendor') {
      $form->update_exchangerate($dbh, $form->{currency}, $form->{transdate}, 0, $form->{exchangerate});
    }
  }
  
  if ($form->{department_id} *= 1) {
    $query = qq|INSERT INTO dpt_trans (trans_id, department_id)
                VALUES ($form->{id}, |.$form->dbclean($form->{department_id}).qq|)|;
    $dbh->do($query) || $form->dberror($query);
  }
      
  if ($form->{type} =~ /_order$/) {
    # adjust onhand
    &adj_onhand($dbh, $form, $sw * -1) if ! $form->{aa_id};
    &adj_inventory($dbh, $myconfig, $form);
  }

  my %audittrail = ( tablename	=> 'oe',
                     reference	=> ($form->{type} =~ /_order$/) ? $form->{ordnumber} : $form->{quonumber},
		     formname	=> $form->{type},
		     action	=> 'saved',
		     id		=> $form->{id} );

  $form->audittrail($dbh, "", \%audittrail);

  $form->save_recurring($dbh, $myconfig);
  
  $form->remove_locks($myconfig, $dbh, 'oe');

  my $rc = $dbh->commit;
  $dbh->disconnect;

  $rc;
  
}



sub delete {
  my ($self, $myconfig, $form, $spool) = @_;

  # connect to database
  my $dbh = $form->dbconnect_noauto($myconfig);

  $form->{id} *= 1;

  # Check if there is any inventory received against this order.
  my $query = qq|SELECT COUNT(*) FROM inventory WHERE trans_id = $form->{id}|;
  my ($cnt) = $dbh->selectrow_array($query); 
  $form->error('Order processed. Cannot delete ...') if $cnt; 

  # delete spool files
  $query = qq|SELECT spoolfile FROM status
                 WHERE trans_id = $form->{id}
		 AND spoolfile IS NOT NULL|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  my $spoolfile;
  my @spoolfiles = ();

  while (($spoolfile) = $sth->fetchrow_array) {
    push @spoolfiles, $spoolfile;
  }
  $sth->finish;

  $query = qq|SELECT aa_id FROM oe
              WHERE id = $form->{id}|;
  if ($dbh->selectrow_array($query)) {

    $query = qq|SELECT o.parts_id, o.ship, p.inventory_accno_id, p.assembly
		FROM orderitems o
		JOIN parts p ON (p.id = o.parts_id)
		WHERE trans_id = $form->{id}|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    if ($form->{type} =~ /_order$/) {
      $ml = ($form->{type} eq 'purchase_order') ? -1 : 1;
      while (my ($id, $ship, $inv, $assembly) = $sth->fetchrow_array) {
	$form->update_balance($dbh,
			      "parts",
			      "onhand",
			      qq|id = $id|,
			      $ship * $ml) if ($inv || $assembly);
      }
    }
    $sth->finish;
    
  }

  for (qw(dpt_trans inventory status orderitems shipto cargo)) {
    $query = qq|DELETE FROM $_ WHERE trans_id = $form->{id}|;
    $dbh->do($query) || $form->dberror($query);
  }
  
  for (qw(recurring recurringemail recurringprint)) {
    $query = qq|DELETE FROM $_ WHERE id = $form->{id}|;
    $dbh->do($query) || $form->dberror($query);
  }

  # delete OE record
  $query = qq|DELETE FROM oe
              WHERE id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

  my %audittrail = ( tablename	=> 'oe',
                     reference	=> ($form->{type} =~ /_order$/) ? $form->{ordnumber} : $form->{quonumber},
		     formname	=> $form->{type},
		     action	=> 'deleted',
		     id		=> $form->{id} );

  $form->audittrail($dbh, "", \%audittrail);
  
  $form->remove_locks($myconfig, $dbh, 'oe');

  my $rc = $dbh->commit;
  $dbh->disconnect;

  if ($rc) {
    foreach $spoolfile (@spoolfiles) {
      unlink "$spool/$spoolfile" if $spoolfile;
    }
  }
  
  $rc;
  
}



sub retrieve {
  my ($self, $myconfig, $form) = @_;
  
  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query;
  my $sth;
  my $var;
  my $ref;

  my %defaults = $form->get_defaults($dbh, \@{[qw(weightunit closedto precision)]});
  for (keys %defaults) { $form->{$_} = $defaults{$_} }
  
  $form->{currencies} = $form->get_currencies($dbh, $myconfig);
  
  $form->remove_locks($myconfig, $dbh, 'oe') unless $form->{readonly};

  $form->{vc} = 'vendor' if $form->{vc} ne 'customer'; # SQLI protection

  if ($form->{id} *= 1) {
    
    # retrieve order
    $query = qq|SELECT o.ordnumber, o.transdate, o.reqdate, o.terms,
                o.taxincluded, o.shippingpoint, o.shipvia, o.waybill,
		o.notes, o.intnotes,
		o.curr AS currency, e.name AS employee, o.employee_id,
		o.$form->{vc}_id, vc.name AS $form->{vc}, o.amount AS invtotal,
		o.closed, o.quonumber, o.department_id,
		d.description AS department, o.language_code, o.ponumber,
		o.warehouse_id, w.description AS warehouse, o.description,
		o.aa_id
		FROM oe o
	        JOIN $form->{vc} vc ON (o.$form->{vc}_id = vc.id)
	        LEFT JOIN employee e ON (o.employee_id = e.id)
	        LEFT JOIN department d ON (o.department_id = d.id)
	        LEFT JOIN warehouse w ON (o.warehouse_id = w.id)
		WHERE o.id = $form->{id}|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    $ref = $sth->fetchrow_hashref(NAME_lc);
    for (keys %$ref) { $form->{$_} = $ref->{$_} }
    $sth->finish;

    # check if this order contains any inventory items? If not, we can delete it even after creating invoice
    $query = qq|SELECT COUNT(*) 
                FROM orderitems oi
                JOIN parts p ON (p.id = oi.parts_id)
                WHERE oi.trans_id = $form->{id}
                AND p.inventory_accno_id IS NOT NULL
                |;
    ($form->{inventory_items}) = $dbh->selectrow_array($query);

    $query = qq|SELECT * FROM shipto
                WHERE trans_id = $form->{id}|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    $ref = $sth->fetchrow_hashref(NAME_lc);
    for (keys %$ref) { $form->{$_} = $ref->{$_} }
    $sth->finish;

    # get printed, emailed and queued
    $query = qq|SELECT s.printed, s.emailed, s.spoolfile, s.formname
                FROM status s
		WHERE s.trans_id = $form->{id}|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
      $form->{printed} .= "$ref->{formname} " if $ref->{printed};
      $form->{emailed} .= "$ref->{formname} " if $ref->{emailed};
      $form->{queued} .= "$ref->{formname} $ref->{spoolfile} " if $ref->{spoolfile};
    }
    $sth->finish;
    for (qw(printed emailed queued)) { $form->{$_} =~ s/ +$//g }

    # retrieve individual items
    $query = qq|SELECT o.id AS orderitems_id,
                p.partnumber, p.assembly, o.description, o.qty,
		o.sellprice, o.parts_id AS id, o.unit, o.discount, p.bin,
                o.reqdate, o.project_id, o.ship, o.serialnumber,
		o.itemnotes, o.lineitemdetail, o.ordernumber,
		o.ponumber AS customerponumber,
		pr.projectnumber,
		pg.partsgroup, p.partsgroup_id, p.partnumber AS sku,
		p.listprice, p.lastcost, p.weight, p.onhand,
		p.inventory_accno_id, p.income_accno_id, p.expense_accno_id,
		t.description AS partsgrouptranslation,
		c.package, c.netweight, c.grossweight, c.volume
		FROM orderitems o
		JOIN parts p ON (o.parts_id = p.id)
		LEFT JOIN project pr ON (o.project_id = pr.id)
		LEFT JOIN partsgroup pg ON (p.partsgroup_id = pg.id)
		LEFT JOIN translation t ON (t.trans_id = p.partsgroup_id AND t.language_code = |.$dbh->quote($form->{language_code}).qq|)
		LEFT JOIN cargo c ON (c.id = o.id AND c.trans_id = o.trans_id)
		WHERE o.trans_id = $form->{id}
                ORDER BY o.id|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    # foreign exchange rates
    &exchangerate_defaults($dbh, $myconfig, $form);

    # query for price matrix
    my $pmh = &price_matrix_query($dbh, $form);
    
    # taxes
    $query = qq|SELECT c.accno
		FROM chart c
		JOIN partstax pt ON (pt.chart_id = c.id)
		WHERE pt.parts_id = ?|;
    my $tth = $dbh->prepare($query) || $form->dberror($query);
   
    my $taxrate;
    my $ptref;
    my $sellprice;
    my $listprice;
    
    while ($ref = $sth->fetchrow_hashref(NAME_lc)) {

      ($decimalplaces) = ($ref->{sellprice} =~ /\.(\d+)/);
      $decimalplaces = length $decimalplaces;
      $decimalplaces = ($decimalplaces > $form->{precision}) ? $decimalplaces : $form->{precision};

      $tth->execute($ref->{id});
      $ref->{taxaccounts} = "";
      $taxrate = 0;
      
      while ($ptref = $tth->fetchrow_hashref(NAME_lc)) {
        $ref->{taxaccounts} .= "$ptref->{accno} ";
        $taxrate += $form->{"$ptref->{accno}_rate"};
      }
      $tth->finish;
      chop $ref->{taxaccounts};

      # preserve prices
      $sellprice = $ref->{sellprice};
      
      # multiply by exchangerate
      $ref->{sellprice} = $form->round_amount($ref->{sellprice} * $form->{$form->{currency}}, $decimalplaces);
      for (qw(listprice lastcost)) { $ref->{$_} = $form->round_amount($ref->{$_} / $form->{$form->{currency}}, $decimalplaces) }
      
      # partnumber and price matrix
      &price_matrix($pmh, $ref, $form->{transdate}, $decimalplaces, $form, $myconfig);

      $ref->{sellprice} = $sellprice;

      $ref->{partsgroup} = $ref->{partsgrouptranslation} if $ref->{partsgrouptranslation};
      
      push @{ $form->{form_details} }, $ref;
      
    }
    $sth->finish;

    # get recurring transaction
    $form->get_recurring($dbh);

    $form->create_lock($myconfig, $dbh, $form->{id}, 'oe');

  } else {
    $form->{transdate} = $form->current_date($myconfig);

    # get last name used
    $form->lastname_used($myconfig, $dbh, $form->{vc}) unless $form->{"$form->{vc}_id"};
    
    delete $form->{notes};

  }

  $dbh->disconnect;

}


sub price_matrix_query {
  my ($dbh, $form) = @_;

  my $query;
  my $sth;

  if ($form->{customer_id}) {
    $query = qq|SELECT p.id AS parts_id, 0 AS customer_id, 0 AS pricegroup_id,
             0 AS pricebreak, p.sellprice, NULL AS validfrom, NULL AS validto,
	     |.$dbh->quote($form->{defaultcurrency}).qq| AS curr, '' AS pricegroup
	     FROM parts p
	     WHERE p.id = ?

	     UNION
    
             SELECT p.*, g.pricegroup
             FROM partscustomer p
	     LEFT JOIN pricegroup g ON (g.id = p.pricegroup_id)
	     WHERE p.parts_id = ?
	     AND p.customer_id = |.$form->dbclean($form->{customer_id}).qq|

	     UNION

	     SELECT p.*, g.pricegroup
	     FROM partscustomer p
	     LEFT JOIN pricegroup g ON (g.id = p.pricegroup_id)
	     JOIN customer c ON (c.pricegroup_id = g.id)
	     WHERE p.parts_id = ?
	     AND c.id = |.$form->dbclean($form->{customer_id}).qq|

	     UNION

	     SELECT p.*, '' AS pricegroup
	     FROM partscustomer p
	     WHERE p.customer_id = 0
	     AND p.pricegroup_id = 0
	     AND p.parts_id = ?

	     ORDER BY customer_id DESC, pricegroup_id DESC, pricebreak
	     |;
    $sth = $dbh->prepare($query) || $form->dberror($query);
  }
  
  if ($form->{vendor_id}) {
    # price matrix and vendor's partnumber
    $query = qq|SELECT partnumber
		FROM partsvendor
		WHERE parts_id = ?
		AND vendor_id = |.$form->dbclean($form->{vendor_id}).qq||;
    $sth = $dbh->prepare($query) || $form->dberror($query);
  }
  
  $sth;

}


sub price_matrix {
  my ($pmh, $ref, $transdate, $decimalplaces, $form, $myconfig) = @_;

  $ref->{pricematrix} = "";
  my $customerprice;
  my $pricegroupprice;
  my $sellprice;
  my $mref;
  my %p = ();
  
  # depends if this is a customer or vendor
  if ($form->{customer_id}) {
    $pmh->execute($ref->{id}, $ref->{id}, $ref->{id}, $ref->{id});

    while ($mref = $pmh->fetchrow_hashref(NAME_lc)) {

      # check date
      if ($mref->{validfrom}) {
	next if $transdate < $form->datetonum($myconfig, $mref->{validfrom});
      }
      if ($mref->{validto}) {
	next if $transdate > $form->datetonum($myconfig, $mref->{validto});
      }

      # convert price
      $sellprice = $form->round_amount($mref->{sellprice} * $form->{$mref->{curr}}, $decimalplaces);
      
      if ($mref->{customer_id}) {
	$ref->{sellprice} = $sellprice if !$mref->{pricebreak};
	$p{$mref->{pricebreak}} = $sellprice;
	$customerprice = 1;
      }

      if ($mref->{pricegroup_id}) {
	if (! $customerprice) {
	  $ref->{sellprice} = $sellprice if !$mref->{pricebreak};
	  $p{$mref->{pricebreak}} = $sellprice;
	}
	$pricegroupprice = 1;
      }

      if (!$customerprice && !$pricegroupprice) {
	$p{$mref->{pricebreak}} = $sellprice;
      }

    }
    $pmh->finish;

    if (%p) {
      if ($ref->{sellprice}) {
	$p{0} = $ref->{sellprice};
      }
      for (sort { $a <=> $b } keys %p) { $ref->{pricematrix} .= "${_}:$p{$_} " }
    } else {
      if ($init) {
	$ref->{sellprice} = $form->round_amount($ref->{sellprice}, $decimalplaces);
      } else {
	$ref->{sellprice} = $form->round_amount($ref->{sellprice} * (1 - $form->{tradediscount}), $decimalplaces);
      }
      $ref->{pricematrix} = "0:$ref->{sellprice} " if $ref->{sellprice};
    }
    chop $ref->{pricematrix};

  }


  if ($form->{vendor_id}) {
    $pmh->execute($ref->{id});
    
    $mref = $pmh->fetchrow_hashref(NAME_lc);

    if ($mref->{partnumber} ne "") {
      $ref->{partnumber} = $mref->{partnumber};
    }

    if ($mref->{lastcost}) {
      # do a conversion
      $ref->{sellprice} = $form->round_amount($mref->{lastcost} * $form->{$mref->{curr}}, $decimalplaces);
    }
    $pmh->finish;

    $ref->{sellprice} *= 1;

    # add 0:price to matrix
    $ref->{pricematrix} = "0:$ref->{sellprice}";

  }

}


sub exchangerate_defaults {
  my ($dbh, $myconfig, $form) = @_;

  my $var;
  my $query;

  $form->{vc} = 'vendor' if $form->{vc} ne 'customer'; # SQLI protection

  my $buysell = ($form->{vc} eq "customer") ? "buy" : "sell";
  
  # get default currencies
  $form->{currencies} = $form->get_currencies($dbh, $myconfig);
  $form->{defaultcurrency} = substr($form->{currencies},0,3);

  $query = qq|SELECT $buysell
              FROM exchangerate
	      WHERE curr = ?
	      AND transdate = ?|;
  my $eth1 = $dbh->prepare($query) || $form->dberror($query);
  $query = qq~SELECT max(transdate || ' ' || $buysell || ' ' || curr)
              FROM exchangerate
	      WHERE curr = ?~;
  my $eth2 = $dbh->prepare($query) || $form->dberror($query);

  # get exchange rates for transdate or max
  foreach $var (split /:/, substr($form->{currencies},4)) {
    $eth1->execute($var, $form->{transdate});
    ($form->{$var}) = $eth1->fetchrow_array;
    if (! $form->{$var} ) {
      $eth2->execute($var);
      
      ($form->{$var}) = $eth2->fetchrow_array;
      ($null, $form->{$var}) = split / /, $form->{$var};
      $form->{$var} = 1 unless $form->{$var};
      $eth2->finish;
    }
    $eth1->finish;
  }

  $form->{$form->{currency}} = $form->{exchangerate} if $form->{exchangerate};
  $form->{$form->{currency}} ||= 1;
  $form->{$form->{defaultcurrency}} = 1;
      
}


sub order_details {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);
  my $query;
  my $sth;
    
  my $item;
  my $i;
  my @sortlist = ();
  my $projectnumber;
  my $projectdescription;
  my $projectnumber_id;
  my $translation;
  my $partsgroup;
  my @taxaccounts;
  my %taxaccounts;
  my $tax;
  my $taxrate;
  my $taxamount;

  my %translations;

  $query = qq|SELECT p.description, t.description
              FROM project p
	       LEFT JOIN translation t ON (t.trans_id = p.id AND t.language_code = |.$dbh->quote($form->{language_code}).qq|)
	       WHERE id = ?|;
  my $prh = $dbh->prepare($query) || $form->dberror($query);

  $query = qq|SELECT inventory_accno_id, income_accno_id, expense_accno_id,
              assembly, tariff_hscode AS hscode, countryorigin,
	      drawing, toolnumber, barcode
	      FROM parts
	      WHERE id = ?|;
  my $pth = $dbh->prepare($query) || $form->dberror($query);

  my $sortby;
  
  # sort items by project and partsgroup
  for $i (1 .. $form->{rowcount} - 1) {

    if ($form->{"id_$i"}) {
      # account numbers
      $pth->execute($form->{"id_$i"});
      $ref = $pth->fetchrow_hashref(NAME_lc);
      for (keys %$ref) { $form->{"${_}_$i"} = $ref->{$_} }
      $pth->finish;

      $projectnumber_id = 0;
      $projectnumber = "";
      $partsgroup = "";
      $form->{projectnumber} = "";

      if ($form->{groupprojectnumber} || $form->{grouppartsgroup}) {

	$inventory_accno_id = ($form->{"inventory_accno_id_$i"} || $form->{"assembly_$i"}) ? "1" : "";

	if ($form->{groupprojectnumber}) {
	  ($projectnumber, $projectnumber_id) = split /--/, $form->{"projectnumber_$i"};
	}
	if ($form->{grouppartsgroup}) {
	  ($partsgroup) = split /--/, $form->{"partsgroup_$i"};
	}

	if ($projectnumber_id && $form->{groupprojectnumber}) {
	  if ($translation{$projectnumber_id}) {
	    $form->{projectnumber} = $translation{$projectnumber_id};
	  } else {
            # get project description
	    $prh->execute($projectnumber_id);
	    ($projectdescription, $translation) = $prh->fetchrow_array;
	    $prh->finish;

	    $form->{projectnumber} = ($translation) ? "$projectnumber, $translation" : "$projectnumber, $projectdescription";

	    $translation{$projectnumber_id} = $form->{projectnumber};
	  }
	}

	if ($form->{grouppartsgroup} && $form->{partsgroup}) {
	  $form->{projectnumber} .= " / " if $projectnumber_id;
	  $form->{projectnumber} .= $partsgroup;
	}

	$form->format_string(projectnumber);

      }

      $sortby = qq|$projectnumber$form->{partsgroup}|;
      if ($form->{sortby} ne 'runningnumber') {
	for (qw(partnumber description bin)) {
	  $sortby .= $form->{"${_}_$i"} if $form->{sortby} eq $_;
	}
      }

      push @sortlist, [ $i, qq|$projectnumber$form->{partsgroup}$inventory_accno_id|, $form->{projectnumber}, $projectnumber_id, $partsgroup, $sortby ];
    }

    # last package number
    $form->{packages} = $form->{"package_$i"} if $form->{"package_$i"};
    
  }

  my @p = ();
  if ($form->{packages}) {
    @p = reverse split //, $form->{packages};
  }
  my $p = "";
  while (@p) {
    my $n = shift @p;
    if ($n =~ /\d/) {
      $p .= "$n";
    } else {
      last;
    }
  }
  if ($p) {
    $form->{packages} = reverse split //, $p;
  }
  
  use SL::CP;
  my $c;
  if ($form->{language_code} ne "") {
    $c = new CP $form->{language_code};
  } else {
    $c = new CP $myconfig->{countrycode};
  }
  $c->init;

  $form->{text_packages} = $c->num2text($form->{packages} * 1);
  $form->format_string(qw(text_packages));
  $form->format_amount($myconfig, $form->{packages});

  $form->{orddescription} = $form->{quodescription} = $form->{description};
  $form->{description} = ();
  $form->{projectnumber} = ();

  # sort the whole thing by project and group
  @sortlist = sort { $a->[5] cmp $b->[5] } @sortlist;
  

  # if there is a warehouse limit picking
  if ($form->{warehouse_id} && $form->{formname} =~ /(pick|packing)_list/) {
    # run query to check for inventory
    $query = qq|SELECT sum(qty) AS qty
                FROM inventory
		WHERE parts_id = ?
		AND warehouse_id = ?|;
    $sth = $dbh->prepare($query) || $form->dberror($query);

    for $i (1 .. $form->{rowcount} - 1) {
      $sth->execute($form->{"id_$i"}, $form->{warehouse_id}) || $form->dberror;

      ($qty) = $sth->fetchrow_array;
      $sth->finish;

      $form->{"qty_$i"} = 0 if $qty == 0;
      
      #if ($form->parse_amount($myconfig, $form->{"ship_$i"}) > $qty) {
	#$form->{"ship_$i"} = $form->format_amount($myconfig, $qty);
      #}
    }
  }
    

  my $runningnumber = 1;
  my $sameitem = "";
  my $subtotal;
  my $k = scalar @sortlist;
  my $j = 0;

  @{ $form->{lineitems} } = ();
  @{ $form->{taxrates} } = ();
  
  foreach $item (@sortlist) {
    $i = $item->[0];
    $j++;

    if ($form->{groupprojectnumber} || $form->{grouppartsgroup}) {
      if ($item->[1] ne $sameitem) {
	$sameitem = $item->[1];
	
	$ok = 0;
	
	if ($form->{groupprojectnumber}) {
	  $ok = $form->{"projectnumber_$i"};
	}
	if ($form->{grouppartsgroup}) {
	  $ok = $form->{"partsgroup_$i"} unless $ok;
	}

        if ($ok) {
	  if ($form->{"inventory_accno_id_$i"} || $form->{"assembly_$i"}) {
	    push(@{ $form->{part} }, "");
	    push(@{ $form->{service} }, NULL);
	  } else {
	    push(@{ $form->{part} }, NULL);
	    push(@{ $form->{service} }, "");
	  }

	  push(@{ $form->{description} }, $item->[2]);
	  for (qw(taxrates runningnumber number sku qty ship unit bin serialnumber ordernumber customerponumber requiredate projectnumber sellprice listprice netprice discount discountrate linetotal itemnotes lineitemdetail package netweight grossweight volume countryorigin hscode drawing toolnumber barcode)) { push(@{ $form->{$_} }, "") }
	  push(@{ $form->{lineitems} }, { amount => 0, tax => 0 });
	}
      }
    }

    $form->{"qty_$i"} = $form->parse_amount($myconfig, $form->{"qty_$i"});
    $form->{"ship_$i"} = $form->parse_amount($myconfig, $form->{"ship_$i"});
    
    if ($form->{"qty_$i"}) {

      $form->{totalqty} += $form->{"qty_$i"};
      $form->{totalship} += $form->{"ship_$i"};
      $form->{totalnetweight} += $form->parse_amount($myconfig, $form->{"netweight_$i"});
      $form->{totalgrossweight} += $form->parse_amount($myconfig, $form->{"grossweight_$i"});

      # add number, description and qty to $form->{number}, ....
      push(@{ $form->{runningnumber} }, $runningnumber++);
      push(@{ $form->{number} }, $form->{"partnumber_$i"});
      push(@{ $form->{requiredate} }, $form->{"reqdate_$i"});

      for (qw(sku description unit bin serialnumber ordernumber customerponumber sellprice listprice package netweight grossweight volume countryorigin hscode drawing toolnumber barcode itemnotes lineitemdetail)) { push(@{ $form->{$_} }, $form->{"${_}_$i"}) }

      # if not grouped remove id
      ($projectnumber) = split /--/, $form->{"projectnumber_$i"};
      push(@{ $form->{projectnumber} }, $projectnumber);

      push(@{ $form->{qty} }, $form->format_amount($myconfig, $form->{"qty_$i"}));
      push(@{ $form->{ship} }, $form->format_amount($myconfig, $form->{"ship_$i"}));
      my $sellprice = $form->parse_amount($myconfig, $form->{"sellprice_$i"});
      my ($dec) = ($sellprice =~ /\.(\d+)/);
      $dec = length $dec;
      my $decimalplaces = ($dec > $form->{precision}) ? $dec : $form->{precision};
      
      my $discount = $form->round_amount($sellprice * $form->parse_amount($myconfig, $form->{"discount_$i"}) / 100, $decimalplaces);

      # keep a netprice as well, (sellprice - discount)
      $form->{"netprice_$i"} = $sellprice - $discount;

      my $linetotal = $form->round_amount($form->{"qty_$i"} * $sellprice * (1 - $form->{"discount_$i"}/100), $form->{precision});

      if ($form->{"inventory_accno_id_$i"} || $form->{"assembly_$i"}) {
	push(@{ $form->{part} }, $form->{"sku_$i"});
	push(@{ $form->{service} }, NULL);
	$form->{totalparts} += $linetotal;
      } else {
	push(@{ $form->{service} }, $form->{"sku_$i"});
	push(@{ $form->{part} }, NULL);
	$form->{totalservices} += $linetotal;
      }

      push(@{ $form->{netprice} }, ($form->{"netprice_$i"}) ? $form->format_amount($myconfig, $form->{"netprice_$i"}, $decimalplaces) : " ");
      
      $discount = ($discount) ? $form->format_amount($myconfig, $discount * -1, $decimalplaces) : " ";

      push(@{ $form->{discount} }, $discount);
      push(@{ $form->{discountrate} }, $form->format_amount($myconfig, $form->{"discount_$i"}));
      
      $form->{ordtotal} += $linetotal;

      # this is for the subtotals for grouping
      $subtotal += $linetotal;

      $form->{"linetotal_$i"} = $form->format_amount($myconfig, $linetotal, $form->{precision}, 0);
      push(@{ $form->{linetotal} }, $form->{"linetotal_$i"});
      
      @taxaccounts = split / /, $form->{"taxaccounts_$i"};

      my $ml = 1;
      my @taxrates = ();
      
      $tax = 0;
      
      for (0 .. 1) {
	$taxrate = 0;

	for (@taxaccounts) { $taxrate += $form->{"${_}_rate"} if ($form->{"${_}_rate"} * $ml) > 0 }
	
	$taxrate *= $ml;
	$taxamount = $linetotal * $taxrate / (1 + $taxrate);
	$taxbase = ($linetotal - $taxamount);
	
	foreach $item (@taxaccounts) {
	  if (($form->{"${item}_rate"} * $ml) > 0) {

	    push @taxrates, $form->{"${item}_rate"} * 100;
	    
	    if ($form->{taxincluded}) {
	      $taxaccounts{$item} += $linetotal * $form->{"${item}_rate"} / (1 + $taxrate);
	      $taxbase{$item} += $taxbase;
	    } else {
	      $taxbase{$item} += $linetotal;
	      $taxaccounts{$item} += $linetotal * $form->{"${item}_rate"};
	    }
	  }
	}

	if ($form->{taxincluded}) {
	  $tax += $linetotal * ($taxrate / (1 + ($taxrate * $ml)));
	} else {
	  $tax += $linetotal * $taxrate;
	}
	
	$ml *= -1;
      }

      $tax = $form->round_amount($tax, $form->{precision});
      push(@{ $form->{lineitems} }, { amount => $linetotal, tax => $tax });
      push(@{ $form->{taxrates} }, join ' ', sort { $a <=> $b } @taxrates);
	
      if ($form->{"assembly_$i"}) {
	$form->{stagger} = -1;
	&assembly_details($myconfig, $form, $dbh, $form->{"id_$i"}, $form->{"qty_$i"});
      }

    }

    # add subtotal
    if ($form->{groupprojectnumber} || $form->{grouppartsgroup}) {
      if ($subtotal) {
	if ($j < $k) {
	  # look at next item
	  if ($sortlist[$j]->[1] ne $sameitem) {

	    if ($form->{"inventory_accno_id_$i"} || $form->{"assembly_$i"}) {
	      push(@{ $form->{part} }, "");
	      push(@{ $form->{service} }, NULL);
	    } else {
	      push(@{ $form->{service} }, "");
	      push(@{ $form->{part} }, NULL);
	    }

	    for (qw(taxrates runningnumber number sku qty ship unit bin serialnumber ordernumber customerponumber requiredate projectnumber sellprice listprice netprice discount discountrate itemnotes package netweight grossweight volume countryorigin hscode drawing toolnumber barcode)) { push(@{ $form->{$_} }, "") }

	    push(@{ $form->{description} }, $form->{groupsubtotaldescription});

	    push(@{ $form->{lineitems} }, { amount => 0, tax => 0 });

	    if ($form->{groupsubtotaldescription} ne "") {
	      push(@{ $form->{linetotal} }, $form->format_amount($myconfig, $subtotal, $form->{precision}));
	    } else {
	      push(@{ $form->{linetotal} }, "");
	    }
	    $subtotal = 0;
	  }

	} else {

	  # got last item
          if ($form->{groupsubtotaldescription} ne "") {
	    
	    if ($form->{"inventory_accno_id_$i"} || $form->{"assembly_$i"}) {
	      push(@{ $form->{part} }, "");
	      push(@{ $form->{service} }, NULL);
	    } else { 
	      push(@{ $form->{service} }, "");
	      push(@{ $form->{part} }, NULL);
	    } 
	   
	    for (qw(taxrates runningnumber number sku qty ship unit bin serialnumber ordernumber customerponumber requiredate projectnumber sellprice listprice netprice discount discountrate itemnotes lineitemdetail package netweight grossweight volume countryorigin hscode drawing toolnumber barcode)) { push(@{ $form->{$_} }, "") }

	    push(@{ $form->{description} }, $form->{groupsubtotaldescription});
	    push(@{ $form->{linetotal} }, $form->format_amount($myconfig, $subtotal, $form->{precision}));
	    push(@{ $form->{lineitems} }, { amount => 0, tax => 0 });
	  }
	}
      }
    }
  }


  $tax = 0;
  foreach $item (sort keys %taxaccounts) {
    if ($form->round_amount($taxaccounts{$item}, $form->{precision})) {
      $tax += $taxamount = $form->round_amount($taxaccounts{$item}, $form->{precision});

      push(@{ $form->{taxbaseinclusive} }, $form->{"${item}_taxbaseinclusive"} = $form->round_amount($taxbase{$item} + $taxamount, $form->{precision}));
      push(@{ $form->{taxbase} }, $form->{"${item}_taxbase"} = $form->format_amount($myconfig, $taxbase{$item}, $form->{precision}));
      push(@{ $form->{tax} }, $form->{"${item}_tax"} = $form->format_amount($myconfig, $taxamount, $form->{precision}));
      
      push(@{ $form->{taxdescription} }, $form->{"${item}_description"});
      
      $form->{"${item}_taxrate"} = $form->format_amount($myconfig, $form->{"${item}_rate"} * 100);
      push(@{ $form->{taxrate} }, $form->{"${item}_taxrate"});
      
      push(@{ $form->{taxnumber} }, $form->{"${item}_taxnumber"});
    }
  }

  # adjust taxes for lineitems
  my $total = 0;
  for $ref (@{ $form->{lineitems} }) {
    $total += $ref->{tax};
  }
  if ($form->round_amount($total, $form->{precision}) != $form->round_amount($tax, $form->{precision})) {
    # get largest amount
    for $ref (reverse sort { $a->{tax} <=> $b->{tax} } @{ $form->{lineitems} }) {
      $ref->{tax} -= ($total - $tax);
      last;
    }
  }
  $i = 1;
  for (@{ $form->{lineitems} }) {
    push(@{ $form->{linetax} }, $form->format_amount($myconfig, $_->{tax}, $form->{precision}, ""));
  }
  
  $form->{totaltax} = $form->format_amount($myconfig, $tax, $form->{precision}, "");
  
  for (qw(totalparts totalservices)) { $form->{$_} = $form->format_amount($myconfig, $form->{$_}, $form->{precision}) }
  for (qw(totalqty totalship totalnetweight totalgrossweight)) { $form->{$_} = $form->format_amount($myconfig, $form->{$_}) }
  
  if ($form->{taxincluded}) {
    $form->{subtotal} = $form->{ordtotal} - $tax;
  } else {
    $form->{subtotal} = $form->{ordtotal};
    $form->{ordtotal} = $form->{ordtotal} + $tax;
  }
  
  $form->{subtotal} = $form->format_amount($myconfig, $form->{subtotal}, $form->{precision}, 0);

  my $whole;
  ($whole, $form->{decimal}) = split /\./, $form->{ordtotal};
  $form->{decimal} .= "00";
  $form->{decimal} = substr($form->{decimal}, 0, 2);
  $form->{text_decimal} = $c->num2text($form->{decimal} * 1);
  $form->{text_amount} = $c->num2text($whole);
  $form->{integer_amount} = $whole;
  
  # format amounts
  $form->{quototal} = $form->{ordtotal} = $form->format_amount($myconfig, $form->{ordtotal}, $form->{precision}, 0);

  $form->format_string(qw(text_amount text_decimal));

  $dbh->disconnect;

}


sub assembly_details {
  my ($myconfig, $form, $dbh, $id, $qty) = @_;

  my $sm = "";
  my $spacer;

  $form->{stagger}++;
  if ($form->{format} eq 'html') {
    $spacer = "&nbsp;" x (3 * ($form->{stagger} - 1)) if $form->{stagger} > 1;
  }
  if ($form->{format} =~ /(postscript|pdf)/) {
    if ($form->{stagger} > 1) {
      $spacer = ($form->{stagger} - 1) * 3;
      $spacer = '\rule{'.$spacer.'mm}{0mm}';
    }
  }

  # get parts and push them onto the stack
  my $sortorder = "";
  
  if ($form->{grouppartsgroup}) {
    $sortorder = qq|ORDER BY pg.partsgroup, a.id|;
  } else {
    $sortorder = qq|ORDER BY a.id|;
  }
  
  my $where = ($form->{formname} eq 'work_order') ? "1 = 1" : "a.bom = '1'";
  
  my $query = qq|SELECT p.partnumber, p.description, p.unit, a.qty,
	         pg.partsgroup, p.partnumber AS sku, p.assembly, p.id, p.bin,
		 p.drawing, p.toolnumber, p.barcode, p.notes AS itemnotes
	         FROM assembly a
	         JOIN parts p ON (a.parts_id = p.id)
	         LEFT JOIN partsgroup pg ON (p.partsgroup_id = pg.id)
	         WHERE $where
	         AND a.aid = |.$dbh->quote($id).qq|
	         $sortorder|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  my @a;
  
  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    
    @a = qw(partnumber description partsgroup itemnotes drawing toolnumber barcode unit bin);

    for (@a) { $form->{"a_$_"} = $ref->{$_} }
    $form->format_string(map { "a_$_" } @a);
   
    if ($form->{grouppartsgroup} && $ref->{partsgroup} ne $sm) {
      for (qw(taxrates number sku unit qty runningnumber ship bin serialnumber ordernumber customerponumber requiredate projectnumber sellprice listprice netprice discount discountrate linetotal itemnotes lineitemdetail package netweight grossweight volume countryorigin hscode drawing toolnumber barcode)) { push(@{ $form->{$_} }, "") }
      $sm = ($form->{"a_partsgroup"}) ? $form->{"a_partsgroup"} : "";
      push(@{ $form->{description} }, "$spacer$sm");
      
      push(@{ $form->{lineitems} }, { amount => 0, tax => 0 });
      
    }

    
    if ($form->{stagger}) {
     
      for (qw(drawing toolnumber barcode itemnotes)) { push(@{ $form->{$_} }, qq|$spacer$form->{"a_$_"}|) }
      push(@{ $form->{description} }, qq|$spacer$form->{"a_partnumber"}, $form->{"a_description"}|);
      for (qw(taxrates number sku runningnumber ship serialnumber ordernumber customerponumber requiredate projectnumber sellprice listprice netprice discount discountrate linetotal lineitemdetail package netweight grossweight volume countryorigin hscode)) { push(@{ $form->{$_} }, "") }
      
    } else {
      
      push(@{ $form->{number} }, $form->{"a_partnumber"});
      for (qw(description sku drawing toolnumber barcode itemnotes)) { push(@{ $form->{$_} }, $form->{"a_$_"}) }
      
      for (qw(taxrates runningnumber ship serialnumber ordernumber customerponumber requiredate projectnumber sellprice listprice netprice discount discountrate linetotal lineitemdetail package netweight grossweight volume countryorigin hscode)) { push(@{ $form->{$_} }, "") }
      
    }

    push(@{ $form->{lineitems} }, { amount => 0, tax => 0 });
      
    push(@{ $form->{qty} }, $form->format_amount($myconfig, $ref->{qty} * $qty));
    for (qw(unit bin)) { push(@{ $form->{$_} }, $form->{"a_$_"}) }

    if ($ref->{assembly} && $form->{formname} eq 'work_order') {
      &assembly_details($myconfig, $form, $dbh, $ref->{id}, $ref->{qty} * $qty);
    }
    
  }
  $sth->finish;

  $form->{stagger}--;
  
}


sub project_description {
  my ($self, $dbh, $id) = @_;

  $id *= 1;

  my $query = qq|SELECT description
                 FROM project
		 WHERE id = $id|;
  ($_) = $dbh->selectrow_array($query);
  
  $_;

}

sub get_warehouses {
  my ($self, $myconfig, $form) = @_;
  
  my $dbh = $form->dbconnect($myconfig);
  # setup warehouses
  my $query = qq|SELECT id, description
                 FROM warehouse
		 ORDER BY 2|;

  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{all_warehouse} }, $ref;
  }
  $sth->finish;

  $dbh->disconnect;

}

sub save_inventory {
  my ($self, $myconfig, $form) = @_;
  
  my ($null, $warehouse_id) = split /--/, $form->{warehouse};
  $warehouse_id *= 1;

  my $ml = ($form->{type} eq 'ship_order') ? -1 : 1;
  
  my $dbh = $form->dbconnect_noauto($myconfig);

  my $sth;
  my $cth;
  my $pth;
  my $serialnumber;
  my $ship;
  my $cargobjid;
  my $inv;
  my $assembly;
  my $aa_id;
  
  my ($null, $employee_id) = split /--/, $form->{employee};
  ($null, $employee_id) = $form->get_employee($dbh) if ! $employee_id;
 
  $query = qq|SELECT oi.serialnumber, oi.ship, o.aa_id
              FROM orderitems oi
	      JOIN oe o ON (o.id = oi.trans_id)
              WHERE oi.trans_id = ?
	      AND oi.id = ?
	      FOR UPDATE|;
  $sth = $dbh->prepare($query) || $form->dberror($query);
  
  $query = qq|SELECT id
              FROM cargo
              WHERE id = ?|;
  $cth = $dbh->prepare($query) || $form->dberror($query);

  $query = qq|SELECT inventory_accno_id, assembly
              FROM parts
	      WHERE id = ?|;
  $pth = $dbh->prepare($query) || $form->dberror($query);

  for $i (1 .. $form->{rowcount} -1) {

    $ship = $form->{"ship_$i"};
    
    if ($ship) {
      $form->{"id"} *= 1;
      #bp 2010-03-11 add serialnumber
      $ship *= $ml;
      $query = qq|INSERT INTO inventory (parts_id, warehouse_id,
                  qty, trans_id, orderitems_id, shippingdate,
		  employee_id, serialnumber)
                  VALUES (|.$form->dbclean($form->{"id_$i"}).qq|, $warehouse_id,
		  $ship, $form->{"id"},
		  |.$form->dbclean($form->{"orderitems_id_$i"}).qq|, |.$dbh->quote($form->{shippingdate}).qq|,
		  |.$form->dbclean($employee_id).qq|,|.$dbh->quote($form->{"serialnumber_$i"}).qq|)|;
      $dbh->do($query) || $form->dberror($query);
     
      # add serialnumber, ship to orderitems
      $sth->execute($form->{id}, $form->{"orderitems_id_$i"}) || $form->dberror;
      ($serialnumber, $ship, $cargobjid, $aa_id) = $sth->fetchrow_array;
      $sth->finish;

      $serialnumber .= " " if $serialnumber;
      $serialnumber .= qq|$form->{"serialnumber_$i"}|;
      $ship += $form->{"ship_$i"};

      # SQLI protection: $serialnumber needs to be quoted

      $query = qq|UPDATE orderitems SET
                  serialnumber = '$serialnumber',
		  ship = $ship,
		  reqdate = |.$dbh->quote($form->{shippingdate}).qq|
		  WHERE trans_id = $form->{id}
		  AND id = |.$form->dbclean($form->{"orderitems_id_$i"}).qq||;
      $dbh->do($query) || $form->dberror($query);

      for (qw(netweight grossweight volume)) {
	$form->{"${_}_$i"} = $form->parse_amount($myconfig, $form->{"${_}_$i"});
      }
      
      $cth->execute($form->{"orderitems_id_$i"}) || $form->dberror;
      ($cargobjid) = $cth->fetchrow_array;
      $cth->finish;
   
      if ($cargobjid) {
	$query = qq|UPDATE cargo SET
	            package = |.$dbh->quote($form->{"package_$i"}).qq|,
		    netweight = |.$form->dbclean($form->{"netweight_$i"}).qq|,
		    grossweight = |.$form->dbclean($form->{"grossweight_$i"}).qq|,
		    volume = |.$form->dbclean($form->{"volume_$i"}).qq|
		    WHERE id = |.$form->dbclean($form->{"orderitems_id_$i"}).qq|
		    AND trans_id = $form->{id}|;
      } else {
	$query = qq|INSERT INTO cargo (id, trans_id, package, netweight,
	            grossweight, volume) VALUES (
		    |.$form->dbclean($form->{"orderitems_id_$i"}).qq|, $form->{id}, |
		    .$dbh->quote($form->{"package_$i"}).qq|,
		    |.$form->dbclean($form->{"netweight_$i"}).qq|, |.$form->dbclean($form->{"grossweight_$i"}).qq|,
		    |.$form->dbclean($form->{"volume_$i"}).qq|)|;
      }
      $dbh->do($query) || $form->dberror($query);
      
      # update order with ship via
      $query = qq|UPDATE oe SET
                  shippingpoint = |.$dbh->quote($form->{shippingpoint}).qq|,
                  shipvia = |.$dbh->quote($form->{shipvia}).qq|,
                  waybill = |.$dbh->quote($form->{waybill}).qq|,
		  warehouse_id = $warehouse_id
		  WHERE id = $form->{id}|;
      $dbh->do($query) || $form->dberror($query);

      if (! $aa_id) {
	# update onhand for parts
	$pth->execute($form->{"id_$i"});
	($inv, $assembly) = $pth->fetchrow_array;
	$form->update_balance($dbh,
			      "parts",
			      "onhand",
			      qq|id = $form->{"id_$i"}|,
			      $form->{"ship_$i"} * $ml) if ($inv || $assembly);
	$pth->finish;
      }
    }
  }
  
  # remove locks
  $form->remove_locks($myconfig, $dbh, 'oe');
 
  my $rc = $dbh->commit;
  $dbh->disconnect;

  $rc;

}


sub adj_onhand {
  my ($dbh, $form, $ml) = @_;
  
  $form->{id} *= 1;

  my $query = qq|SELECT oi.parts_id, oi.ship, p.inventory_accno_id, p.assembly
                 FROM orderitems oi
		 JOIN parts p ON (p.id = oi.parts_id)
                 WHERE oi.trans_id = $form->{id}|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  $query = qq|SELECT sum(p.inventory_accno_id), p.assembly
	      FROM parts p
	      JOIN assembly a ON (a.parts_id = p.id)
	      WHERE a.aid = ?
	      GROUP BY p.assembly|;
  my $ath = $dbh->prepare($query) || $form->dberror($query);

  my $ref;
  
  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {

    if ($ref->{inventory_accno_id} || $ref->{assembly}) {

      # do not update if assembly consists of all services
      if ($ref->{assembly}) {
	$ath->execute($ref->{parts_id}) || $form->dberror($query);

        my ($inv, $assembly) = $ath->fetchrow_array;
	$ath->finish;

	next unless ($inv || $assembly);
	
      }

      # adjust onhand in parts table
      $form->update_balance($dbh,
			    "parts",
			    "onhand",
			    qq|id = $ref->{parts_id}|,
			    $ref->{ship} * $ml);
    }
  }
  
  $sth->finish;

}


sub adj_inventory {
  my ($dbh, $myconfig, $form) = @_;

  $form->{id} *= 1;

  # increase/reduce qty in inventory table
  my $query = qq|SELECT oi.id, oi.parts_id, oi.ship
                 FROM orderitems oi
                 WHERE oi.trans_id = $form->{id}|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  $query = qq|SELECT id, qty,
                     (SELECT SUM(qty) FROM inventory
                      WHERE trans_id = $form->{id}
		      AND orderitems_id = ?) AS total
	      FROM inventory
              WHERE trans_id = $form->{id}
	      AND orderitems_id = ?|;
  my $ith = $dbh->prepare($query) || $form->dberror($query);
  
  my $qty;
  my $ml = ($form->{type} =~ /(ship|sales)_order/) ? -1 : 1;
  
  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {

    $ith->execute($ref->{id}, $ref->{id}) || $form->dberror($query);

    my $ship = $ref->{ship};
    while (my $inv = $ith->fetchrow_hashref(NAME_lc)) {

      if (($qty = (($inv->{total} * $ml) - $ship)) >= 0) {
	$qty = $inv->{qty} * $ml if ($qty > ($inv->{qty} * $ml));

	$form->update_balance($dbh,
                              "inventory",
                              "qty",
                              qq|id = $inv->{id}|,
                              $qty * -1 * $ml);
	$ship -= $qty;
      }
    }
    $ith->finish;

  }
  $sth->finish;

  # delete inventory entries if qty = 0
  $query = qq|DELETE FROM inventory
              WHERE trans_id = $form->{id}
	      AND qty = 0|;
  $dbh->do($query) || $form->dberror($query);

}


sub get_inventory {
  my ($self, $myconfig, $form) = @_;

  my $where;
  my $query;
  my $null;
  my $fromwarehouse_id;
  my $towarehouse_id;
  my $var;
  
  my $dbh = $form->dbconnect($myconfig);
  
  if ($form->{partnumber} ne "") {
    $var = $form->like(lc $form->{partnumber});
    $where .= "
                AND lower(p.partnumber) LIKE '$var'";
  }
  if ($form->{description} ne "") {
    $var = $form->like(lc $form->{description});
    $where .= "
                AND lower(p.description) LIKE '$var'";
  }
  if ($form->{partsgroup} ne "") {
    ($null, $var) = split /--/, $form->{partsgroup};
    $where .= "
                AND pg.id = $var";
  }


  ($null, $fromwarehouse_id) = split /--/, $form->{fromwarehouse};
  $fromwarehouse_id *= 1;
  
  ($null, $towarehouse_id) = split /--/, $form->{towarehouse};
  $towarehouse_id *= 1;

  my %ordinal = ( partnumber => 2,
                  description => 3,
		  partsgroup => 5,
		  warehouse => 6,
		);

  my @a = (partnumber, warehouse);
  my $sortorder = $form->sort_order(\@a, \%ordinal);
  
  if ($fromwarehouse_id) {
    if ($towarehouse_id) {
      $where .= "
                AND NOT i.warehouse_id = $towarehouse_id";
    }
    $query = qq|SELECT p.id, p.partnumber, p.description,
                sum(i.qty) * 2 AS onhand, sum(i.qty) AS qty,
		pg.partsgroup, w.description AS warehouse, i.warehouse_id
		FROM inventory i
		JOIN parts p ON (p.id = i.parts_id)
		LEFT JOIN partsgroup pg ON (p.partsgroup_id = pg.id)
		JOIN warehouse w ON (w.id = i.warehouse_id)
		WHERE i.warehouse_id = $fromwarehouse_id
		$where
		GROUP BY p.id, p.partnumber, p.description, pg.partsgroup, w.description, i.warehouse_id 
		ORDER BY $sortorder|;
  } else {
    if ($towarehouse_id) {
      $query = qq|
 	      SELECT p.id, p.partnumber, p.description,
	      p.onhand, (SELECT SUM(qty) FROM inventory i WHERE i.parts_id = p.id) AS qty,
              pg.partsgroup, '' AS warehouse, 0 AS warehouse_id
              FROM parts p
	      LEFT JOIN partsgroup pg ON (p.partsgroup_id = pg.id)
	      WHERE p.onhand > 0
	      $where
	  UNION|;
    }

    $query .= qq|
              SELECT p.id, p.partnumber, p.description,
	      sum(i.qty) * 2 AS onhand, sum(i.qty) AS qty,
	      pg.partsgroup, w.description AS warehouse, i.warehouse_id
	      FROM inventory i
	      JOIN parts p ON (p.id = i.parts_id)
	      LEFT JOIN partsgroup pg ON (p.partsgroup_id = pg.id)
	      JOIN warehouse w ON (w.id = i.warehouse_id)
	      WHERE i.warehouse_id != $towarehouse_id
	      $where
	      GROUP BY p.id, p.partnumber, p.description, pg.partsgroup, w.description, i.warehouse_id
	      ORDER BY $sortorder|;
  }

  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);
  
  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    $ref->{qty} = $ref->{onhand} - $ref->{qty};
    push @{ $form->{all_inventory} }, $ref;
  }
  $sth->finish;

  $dbh->disconnect;

}

sub transfer {
  my ($self, $myconfig, $form) = @_;
  
  my $dbh = $form->dbconnect_noauto($myconfig);
  
  ($form->{employee}, $form->{employee_id}) = $form->get_employee($dbh);
  
  my @a = localtime;
  $a[5] += 1900;
  $a[4]++;
  $a[4] = substr("0$a[4]", -2);
  $a[3] = substr("0$a[3]", -2);
  $shippingdate = "$a[5]$a[4]$a[3]";

  my %total = ();

  my $query = qq|INSERT INTO inventory
                 (warehouse_id, parts_id, qty, shippingdate, employee_id)
		 VALUES (?, ?, ?, |.$dbh->quote($shippingdate).qq|, |.$form->dbclean($form->{employee_id}).qq|)|;
  $sth = $dbh->prepare($query) || $form->dberror($query);

  my $qty;
  
  for my $i (1 .. $form->{rowcount}) {
    $qty = $form->parse_amount($myconfig, $form->{"transfer_$i"});

    $qty = $form->{"qty_$i"} if ($qty > $form->{"qty_$i"});

    if ($qty > 0) {
      # to warehouse
      if ($form->{warehouse_id}) {
	$sth->execute($form->{warehouse_id}, $form->{"id_$i"}, $qty) || $form->dberror;
	$sth->finish;
      }
      
      # from warehouse
      if ($form->{"warehouse_id_$i"}) {
	$sth->execute($form->{"warehouse_id_$i"}, $form->{"id_$i"}, $qty * -1) || $form->dberror;
	$sth->finish;
      }
    }
  }

  my $rc = $dbh->commit;
  $dbh->disconnect;

  $rc;

}


sub get_soparts {
  my ($self, $myconfig, $form) = @_;
  
  # connect to database
  my $dbh = $form->dbconnect($myconfig);
  
  my $query;
  my $sth;
  my $ref;
  my $id;
  my $orderitemsid;
  my $i;
  
  my %defaults = $form->get_defaults($dbh, \@{['precision']});
  for (keys %defaults) { $form->{$_} = $defaults{$_} }

  # store required items from selected sales orders
  if ($form->{detail}) {
    $query = qq|SELECT p.id, oi.qty - oi.ship AS required,
                  p.assembly, oi.id AS orderitemsid
		  FROM orderitems oi
		  JOIN parts p ON (p.id = oi.parts_id)
		  WHERE oi.trans_id = ?
		  AND oi.id = ?|;
  } else {
    $query = qq|SELECT p.id, oi.qty - oi.ship AS required,
                p.assembly, oi.id AS orderitemsid
                FROM orderitems oi
	        JOIN parts p ON (p.id = oi.parts_id)
	        WHERE oi.trans_id = ?|;
  }
  $sth = $dbh->prepare($query) || $form->dberror($query);
  
  for ($i = 1; $i <= $form->{rowcount}; $i++) {

    if ($form->{"ndx_$i"}) {

      ($id, $orderitemsid) = split /--/, $form->{"ndx_$i"};

      if ($form->{detail}) {
	$sth->execute($id, $orderitemsid);
      } else {
	$sth->execute($id);
      }
      
      while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
	&add_items_required("", $dbh, $form, $id, $ref->{id}, $ref->{required}, $ref->{assembly}, $ref->{orderitemsid});
      }
      $sth->finish;
    }

  }

  $form->{transdate} = $form->current_date($myconfig);
  
  # foreign exchange rates
  &exchangerate_defaults($dbh, $myconfig, $form);

  $dbh->disconnect;

}


sub add_items_required {
  my ($self, $dbh, $form, $id, $parts_id, $required, $assembly, $orderitemsid) = @_;
  
  my $query;
  my $sth;
  my $ref;
  my $ph;

  if ($assembly) {
    $query = qq|SELECT p.id, a.qty, p.assembly
                FROM assembly a
		JOIN parts p ON (p.id = a.parts_id)
		WHERE a.aid = $parts_id|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);
    
    while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
      &add_items_required("", $dbh, $form, $id, $ref->{id}, $required * $ref->{qty}, $ref->{assembly}, $orderitemsid);
    }
    $sth->finish;
    
  } else {

    if ($form->{detail}) {
      $query = qq|SELECT p.partnumber, oi.description, p.lastcost
                  FROM orderitems oi
		  JOIN parts p ON (p.id = oi.parts_id)
		  WHERE oi.parts_id = $parts_id
		  AND oi.id = $orderitemsid
		  AND oi.trans_id = $id|;
    } else {
      $query = qq|SELECT partnumber, description, lastcost
		  FROM parts
		  WHERE id = $parts_id|;
    }
    
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);
    $ref = $sth->fetchrow_hashref(NAME_lc);

    if ($form->{detail}) {
      $ph = "$parts_id--$id--$orderitemsid";
    } else {
      $ph = $parts_id;
    }
    
    for (keys %$ref) { $form->{orderitems}{$ph}{$_} = $ref->{$_} }
    $sth->finish;

    $form->{orderitems}{$ph}{required} += $required;

    $query = qq|SELECT pv.partnumber, pv.leadtime, pv.lastcost, pv.curr,
		pv.vendor_id, v.name
		FROM partsvendor pv
		JOIN vendor v ON (v.id = pv.vendor_id)
		WHERE pv.parts_id = ?|;
    $sth = $dbh->prepare($query) || $form->dberror($query);

    # get cost and vendor
    $sth->execute($parts_id);

    while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
      for (keys %$ref) { $form->{orderitems}{$ph}{partsvendor}{$ref->{vendor_id}}{$_} = $ref->{$_} }
    }
    $sth->finish;
    
  }

}


sub generate_orders {
  my ($self, $myconfig, $form) = @_;

  my %a;
  my $query;
  my $sth;
  my $i;
  
  for ($i = 1; $i <= $form->{rowcount}; $i++) {
    for (qw(qty lastcost)) { $form->{"${_}_$i"} = $form->parse_amount($myconfig, $form->{"${_}_$i"}) }
    
    if ($form->{"qty_$i"}) {
      ($vendor, $vendor_id) = split /--/, $form->{"vendor_$i"};

      if ($vendor_id) {
	$a{$vendor_id}{$form->{"id_$i"}}{qty} += $form->{"qty_$i"};
	for (qw(curr lastcost)) { $a{$vendor_id}{$form->{"id_$i"}}{$_} = $form->{"${_}_$i"} }
      }
    }
  }

  # connect to database
  my $dbh = $form->dbconnect_noauto($myconfig);
  
  # foreign exchange rates
  &exchangerate_defaults($dbh, $myconfig, $form);

  my $amount;
  my $netamount;
  my $curr = "";
  my %tax;
  my $taxincluded = 0;
  my $vendor_id;

  my $description;
  my $itemnotes;
  my $unit;
  my $ordernumber;

  my $sellprice;
  my $uid;

  my $rc;
  
  foreach $vendor_id (keys %a) {
    
    %tax = ();
    
    $query = qq|SELECT v.curr, v.taxincluded, t.rate, c.accno
                FROM vendor v
		LEFT JOIN vendortax vt ON (v.id = vt.vendor_id)
		LEFT JOIN tax t ON (t.chart_id = vt.chart_id)
		LEFT JOIN chart c ON (c.id = t.chart_id)
                WHERE v.id = $vendor_id|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);
    while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
      $curr = $ref->{curr};
      $taxincluded = $ref->{taxincluded};
      $tax{$ref->{accno}} = $ref->{rate};
    }
    $sth->finish;  

    $curr ||= $form->{defaultcurrency};
    $taxincluded *= 1;

    # get precision
    $form->{precision} = "";
    $query = qq|SELECT precision FROM curr
                WHERE curr = '$curr'|;
    ($form->{precision}) = $dbh->selectrow_array($query);
    
    if ($form->{precision} eq "") {
      my %defaults = $form->get_defaults($dbh, \@{[qw(precision)]});
      $form->{precision} = $defaults{precision};
    }
    
    $uid = localtime;
    $uid .= $$;
 
    $query = qq|INSERT INTO oe (ordnumber)
		VALUES ('$uid')|;
    $dbh->do($query) || $form->dberror($query);
   
    $query = qq|SELECT id FROM oe
                WHERE ordnumber = '$uid'|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);
    my ($id) = $sth->fetchrow_array;
    $sth->finish;

    
    # get default shipto
    $query = qq|SELECT * FROM shipto
                WHERE trans_id = $vendor_id|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);
    $ref = $sth->fetchrow_hashref(NAME_lc);

    $query = qq|INSERT INTO shipto (trans_id, shiptoname, shiptoaddress1,
                shiptoaddress2, shiptocity, shiptostate, shiptozipcode,
		shiptocountry, shiptocontact, shiptophone, shiptofax,
		shiptoemail) VALUES ($id, '$ref->{shiptoname}',
		'$ref->{shiptoaddress1}', '$ref->{shiptoaddress2}',
		'$ref->{shiptocity}', '$ref->{shiptostate}',
		'$ref->{shiptozipcode}', '$ref->{shiptocountry}',
		'$ref->{shiptocontact}', '$ref->{shiptophone}',
		'$ref->{shiptofax}', '$ref->{shiptoemail}')|;
    $dbh->do($query) || $form->dberror($query);
    $sth->finish;  
   

    $amount = 0;
    $netamount = 0;
    
    foreach my $parts_id (keys %{ $a{$vendor_id} }) {

      if (($form->{$curr} * $form->{$a{$vendor_id}{$parts_id}{curr}}) > 0) {
	$sellprice = $a{$vendor_id}{$parts_id}{lastcost} / $form->{$curr} * $form->{$a{$vendor_id}{$parts_id}{curr}};
      } else {
	$sellprice = $a{$vendor_id}{$parts_id}{lastcost};
      }
      $sellprice = $form->round_amount($sellprice, $form->{precision});
      
      my $linetotal = $form->round_amount($sellprice * $a{$vendor_id}{$parts_id}{qty}, $form->{precision});

      my ($ph, $trans_id, $orderitemsid) = split /--/, $parts_id;

      $query = qq|SELECT c.accno FROM chart c
                  JOIN partstax pt ON (pt.chart_id = c.id)
		  WHERE pt.parts_id = $ph|;
      $sth = $dbh->prepare($query);
      $sth->execute || $form->dberror($query);

      my $rate = 0;
      while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
	$rate += $tax{$ref->{accno}};
      }
      $sth->finish;
      
      if ($form->{detail}) {
	$query = qq|SELECT oi.description, oi.itemnotes AS notes, p.unit,
	            oi.ordernumber
		    FROM parts p
		    JOIN orderitems oi ON (oi.parts_id = p.id)
		    WHERE oi.parts_id = $ph
		    AND oi.trans_id = $trans_id
		    AND oi.id = $orderitemsid|;
      } else {
	$query = qq|SELECT p.description, p.notes, p.unit
	            FROM parts p
		    WHERE p.id = $ph|;
      }

      $sth = $dbh->prepare($query);
      $sth->execute || $form->dberror($query);

      $ref = $sth->fetchrow_hashref(NAME_lc);
      
      $description = $dbh->quote($ref->{description});
      $itemnotes = $dbh->quote($ref->{notes});
      $unit = $dbh->quote($ref->{unit});
      $ordernumber = $dbh->quote($ref->{ordernumber});
      $sth->finish;

      $netamount += $linetotal;
      if ($taxincluded) {
	$amount += $linetotal;
      } else {
	$amount += $form->round_amount($linetotal * (1 + $rate), $form->{precision});
      }

      $query = qq|INSERT INTO orderitems (trans_id, parts_id, description,
                  qty, ship, sellprice, unit, itemnotes, ordernumber) VALUES
		  ($id, $ph, $description,
		  $a{$vendor_id}{$parts_id}{qty}, 0, $sellprice, $unit,
		  $itemnotes, $ordernumber)|;
      $dbh->do($query) || $form->dberror($query);

    }

    my $ordnumber = $form->update_defaults($myconfig, 'ponumber');

    my $null;
    my $employee_id;
    my $department_id;
    
    ($null, $employee_id) = $form->get_employee($dbh);
    ($null, $department_id) = split /--/, $form->{department};
    $department_id *= 1;
    
    $query = qq|UPDATE oe SET
		ordnumber = |.$dbh->quote($ordnumber).qq|,
		transdate = current_date,
		vendor_id = |.$form->dbclean($vendor_id).qq|,
		customer_id = 0,
		amount = $amount,
		netamount = $netamount,
		taxincluded = |.$dbh->quote($taxincluded).qq|,
		curr = |.$dbh->quote($curr).qq|,
		employee_id = |.$form->dbclean($employee_id).qq|,
		department_id = |.$dbh->quote($department_id).qq|,
		ponumber = |.$dbh->quote($form->{ponumber}).qq|
		WHERE id = $id|;
    $dbh->do($query) || $form->dberror($query);
  
    $rc = $dbh->commit;
    
  }

  $dbh->disconnect;

  $rc;
  
}


sub consolidate_orders {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect_noauto($myconfig);
  
  my $id;
  my $ref;
  my %oe = ();
  my $i;
  
  my $query = qq|SELECT * FROM oe
                 WHERE id = ?|;
  my $sth = $dbh->prepare($query) || $form->dberror($query);

  for ($i = 1; $i <= $form->{rowcount}; $i++) {
    # retrieve order
    if ($form->{"ndx_$i"}) {
      $sth->execute($form->{"ndx_$i"});
      
      $ref = $sth->fetchrow_hashref(NAME_lc);
      $ref->{ndx} = $i;
      $oe{oe}{$ref->{curr}}{$ref->{id}} = $ref;

      $oe{vc}{$ref->{curr}}{$ref->{"$form->{vc}_id"}}++;
      $sth->finish;
    }
  }

  $query = qq|SELECT * FROM orderitems
              WHERE trans_id = ?|;
  $sth = $dbh->prepare($query) || $form->dberror($query);

  foreach $curr (keys %{ $oe{oe} }) {
    
    foreach $id (sort { $oe{oe}{$curr}{$a}->{ndx} <=> $oe{oe}{$curr}{$b}->{ndx} } keys %{ $oe{oe}{$curr} }) {

      # retrieve order
      $vc_id = $oe{oe}{$curr}{$id}->{"$form->{vc}_id"};

      if ($oe{vc}{$oe{oe}{$curr}{$id}->{curr}}{$vc_id} > 1) {

        push @{ $oe{orders}{$curr}{$vc_id} }, $id;

	$sth->execute($id);
	while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
	  push @{ $oe{orderitems}{$curr}{$id} }, $ref;
	}
	$sth->finish;  

      }
    }
  }

  
  my $ordnumber = $form->{ordnumber};
  my $numberfld = ($form->{vc} eq 'customer') ? 'sonumber' : 'ponumber';
  
  my ($department, $department_id) = $form->{department};
  $department_id *= 1;
  
  my $uid = localtime;
  $uid .= $$;

  my @orderitems = ();
 
  foreach $curr (keys %{ $oe{orders} }) {
    
    foreach $vc_id (sort { $a <=> $b } keys %{ $oe{orders}{$curr} }) {
      # the orders
      @orderitems = ();
      $form->{customer_id} = $form->{vendor_id} = 0;
      $form->{"$form->{vc}_id"} = $vc_id;
      $amount = 0;
      $netamount = 0;
      
      foreach $id (@{ $oe{orders}{$curr}{$vc_id} }) {

        # header
	$ref = $oe{oe}{$curr}{$id};
	
	$amount += $ref->{amount};
	$netamount += $ref->{netamount};

	foreach $item (@{ $oe{orderitems}{$curr}{$id} }) {
	  $item->{ordernumber} ||= $ref->{ordnumber};
	  $item->{customerponumber} ||= $ref->{ponumber};
	  push @orderitems, $item;
	}

	# close order
	$query = qq|UPDATE oe SET
	            closed = '1'
		    WHERE id = $id|;
        $dbh->do($query) || $form->dberror($query);

        # reset shipped
	$query = qq|UPDATE orderitems SET
	            ship = 0
		    WHERE trans_id = $id|;
        $dbh->do($query) || $form->dberror($query);
	    
      }

      $ordnumber ||= $form->update_defaults($myconfig, $numberfld, $dbh);
    
      $query = qq|INSERT INTO oe (ordnumber)
		  VALUES ('$uid')|;
      $dbh->do($query) || $form->dberror($query);

      $query = qq|SELECT id
                  FROM oe
		  WHERE ordnumber = '$uid'|;
      ($id) = $dbh->selectrow_array($query);

      $ref->{employee_id} *= 1;
      
      $query = qq|UPDATE oe SET
		  ordnumber = |.$dbh->quote($ordnumber).qq|,
		  transdate = current_date,
		  vendor_id = |.$form->dbclean($form->{vendor_id}).qq|,
		  customer_id = |.$form->dbclean($form->{customer_id}).qq|,
		  amount = $amount,
		  netamount = $netamount,
		  reqdate = |.$form->dbquote($form->dbclean($ref->{reqdate}), SQL_DATE).qq|,
		  taxincluded = |.$dbh->quote($ref->{taxincluded}).qq|,
		  shippingpoint = |.$dbh->quote($ref->{shippingpoint}).qq|,
		  notes = |.$dbh->quote($ref->{notes}).qq|,
		  curr = '$curr',
		  employee_id = |.$form->dbclean($ref->{employee_id}).qq|,
		  intnotes = |.$dbh->quote($ref->{intnotes}).qq|,
		  shipvia = |.$dbh->quote($ref->{shipvia}).qq|,
		  waybill = |.$dbh->quote($ref->{waybill}).qq|,
		  language_code = |.$dbh->quote($ref->{language_code}).qq|,
		  ponumber = |.$dbh->quote($form->{ponumber}).qq|,
		  department_id = |.$form->dbclean($department_id).qq|
		  WHERE id = $id|;
      $dbh->do($query) || $form->dberror($query);
	  

      # add items
      foreach $item (@orderitems) {
	for (qw(qty sellprice discount project_id ship)) { $item->{$_} *= 1 }
	$query = qq|INSERT INTO orderitems (
		    trans_id, parts_id, description,
		    qty, sellprice, discount,
		    unit, reqdate, project_id,
		    ship, serialnumber, ordernumber, ponumber, itemnotes)
		    VALUES (
		    $id, $item->{parts_id}, |
		    .$dbh->quote($item->{description})
		    .qq|, $item->{qty}, $item->{sellprice}, $item->{discount}, |
		    .$dbh->quote($item->{unit}).qq|, |
		    .$form->dbquote($form->dbclean($item->{reqdate}), SQL_DATE)
		    .qq|, $item->{project_id}, $item->{ship}, |
		    .$dbh->quote($item->{serialnumber}) .qq|, |
		    .$dbh->quote($item->{ordernumber}).qq|, |
		    .$dbh->quote($item->{customerponumber}).qq|, |
		    .$dbh->quote($item->{itemnotes}).qq|)|;

      $dbh->do($query) || $form->dberror($query);
		    
      }
    }
  }


  $rc = $dbh->commit;
  $dbh->disconnect;

  $rc;
  
}


1;

