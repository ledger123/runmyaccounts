#=====================================================================
# SQL-Ledger ERP
# Copyright (C) 2006
#
#  Author: DWS Systems Inc.
#     Web: http://www.sql-ledger.com
#
#======================================================================
#
# Inventory invoicing module
#
#======================================================================

# SQLI protection. This file looks clean

package IS;


sub invoice_details {
  my ($self, $myconfig, $form) = @_;

  $form->{duedate} ||= $form->{transdate};

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query;
  my $sth;

  $form->{total} = 0;

  $form->{terms} = $form->datediff($myconfig, $form->{transdate}, $form->{duedate});
 
  # this is for the template
  $form->{invdate} = $form->{transdate};

  $form->{xml_duedate} = $form->datetonum($myconfig, $form->{duedate});
  $form->{qr_duedate} = $form->format_date('yyyy-mm-dd', $form->{xml_duedate});
  $form->{xml_invdate} = $form->datetonum($myconfig, $form->{transdate});
  $form->{qr_invdate} = $form->format_date('yyyy-mm-dd', $form->{xml_invdate});

  my %defaults = $form->get_defaults($dbh, \@{[qw(address1 address2 city state zip country)]});

  my ($utf8templates) = $dbh->selectrow_array("SELECT fldvalue FROM defaults WHERE fldname='utf8templates'");

  $form->{companyaddress1} = $defaults{address1};
  $form->{companyaddress2} = $defaults{address2};
  $form->{companycity} = $defaults{city};
  $form->{companystate} = $defaults{state};
  $form->{companyzip} = $defaults{zip};
  $form->{companycountry} = $defaults{country};

  $form->{invdescription} = $form->{description};
  
  my $tax;
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
  my $taxrate;
  my $taxamount;
  my $taxbase;
  my %taxbase;
 
  my %translations;

  $query = qq|SELECT p.description, t.description
              FROM project p
	      LEFT JOIN translation t ON (t.trans_id = p.id AND t.language_code = '$form->{language_code}')
	      WHERE id = ?|;
  my $prh = $dbh->prepare($query) || $form->dberror($query);

  $query = qq|SELECT inventory_accno_id, income_accno_id, expense_accno_id,
              assembly, tariff_hscode AS hscode, countryorigin, barcode
	      FROM parts
              WHERE id = ?|;
  my $pth = $dbh->prepare($query) || $form->dberror($query);

  my $sortby;
  
  # sort items by project and partsgroup
  for $i (1 .. $form->{rowcount} - 1) {

    # account numbers
    $pth->execute($form->{"id_$i"});
    $ref = $pth->fetchrow_hashref(NAME_lc);
    for (keys %$ref) { $form->{"${_}_$i"} = $ref->{$_} }
    $pth->finish;

    $projectnumber_id = 0;
    $projectnumber = "";
    $form->{partsgroup} = "";
    $form->{projectnumber} = "";
    
    if ($form->{groupprojectnumber} || $form->{grouppartsgroup}) {
      
      $inventory_accno_id = ($form->{"inventory_accno_id_$i"} || $form->{"assembly_$i"}) ? "1" : "";
      
      if ($form->{groupprojectnumber}) {
	($projectnumber, $projectnumber_id) = split /--/, $form->{"projectnumber_$i"};
      }
      if ($form->{grouppartsgroup}) {
	($form->{partsgroup}) = split /--/, $form->{"partsgroup_$i"};
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
	$form->{projectnumber} .= $form->{partsgroup};
      }
      
      if (!$utf8templates){
      $form->format_string(projectnumber);
      }
    }

    $sortby = qq|$projectnumber$form->{partsgroup}|;
    if ($form->{sortby} ne 'runningnumber') {
      for (qw(partnumber description bin)) {
	$sortby .= $form->{"${_}_$i"} if $form->{sortby} eq $_;
      }
    }
    
    push @sortlist, [ $i, qq|$projectnumber$form->{partsgroup}$inventory_accno_id|, $form->{projectnumber}, $projectnumber_id, $form->{partsgroup}, $sortby ];

    # last package number
    $form->{packages} = $form->{"package_$i"} if $form->{"package_$i"};
    
  }

  my @p;
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
  if (!$utf8templates){
  $form->format_string(qw(text_packages));
  }
  $form->format_amount($myconfig, $form->{packages});
  
  $form->{projectnumber} = ();
  $form->{description} = ();
 
  # sort the whole thing by project and group
  @sortlist = sort { $a->[5] cmp $b->[5] } @sortlist;

  my $runningnumber = 1;
  my $sameitem = "";
  my $subtotal;
  my $k = scalar @sortlist;
  my $j = 0;
  my $ok;

  @{ $form->{lineitems} } = ();
  @{ $form->{taxrates} } = ();

  foreach $item (@sortlist) {

    $i = $item->[0];
    $j++;

    # heading
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
	  for (qw(taxrates runningnumber number sku serialnumber ordernumber customerponumber bin qty ship unit deliverydate projectnumber sellprice listprice netprice discount discountrate discountrate_percent linetotal itemnotes package netweight grossweight volume countryorigin hscode barcode xml_deliverydate xml_qty xml_sellprice xml_linetotal)) { push(@{ $form->{$_} }, "") }
	  push(@{ $form->{lineitems} }, { amount => 0, tax => 0 });
	}
      }
    }
      
    $form->{"qty_$i"} = $form->parse_amount($myconfig, $form->{"qty_$i"});
    
    if ($form->{"qty_$i"}) {

      $form->{totalqty} += $form->{"qty_$i"};
      $form->{totalship} += $form->{"qty_$i"};
      $form->{totalnetweight} += $form->parse_amount($myconfig, $form->{"netweight_$i"});
      $form->{totalgrossweight} += $form->parse_amount($myconfig, $form->{"grossweight_$i"});

      # add number, description and qty to $form->{number}, ....
      push(@{ $form->{runningnumber} }, $runningnumber++);
      push(@{ $form->{number} }, $form->{"partnumber_$i"});

      # if not grouped strip id
      ($projectnumber, $project_id) = split /--/, $form->{"projectnumber_$i"};
      $project_id *= 1;
      ($projectname) = $dbh->selectrow_array("SELECT description FROM project WHERE id = $project_id");

      push(@{ $form->{projectnumber} }, $projectnumber);
      push(@{ $form->{projectname} }, $projectname);
      
      for (qw(sku serialnumber ordernumber customerponumber bin description unit deliverydate sellprice listprice package netweight grossweight volume countryorigin hscode barcode itemnotes)) { push(@{ $form->{$_} }, $form->{"${_}_$i"}) }
	
      push(@{ $form->{xml_qty} }, $form->format_amount({ numberformat => '1000.00' }, $form->{"qty_$i"}, 4));
      push(@{ $form->{xml_sellprice} }, $form->format_amount({ numberformat => '1000.00' }, $form->{"sellprice_$i"}, 4));
      push(@{ $form->{qty} }, $form->format_amount($myconfig, $form->{"qty_$i"}));
      push(@{ $form->{ship} }, $form->format_amount($myconfig, $form->{"ship_$i"}));

      my $sellprice = $form->parse_amount($myconfig, $form->{"sellprice_$i"});
      my ($dec) = ($sellprice =~ /\.(\d+)/);
      $dec = length $dec;
      my $decimalplaces = ($dec > $form->{precision}) ? $dec : $form->{precision};
      
      my $discount = $form->round_amount($sellprice * $form->parse_amount($myconfig, $form->{"discount_$i"})/100, $decimalplaces);
      
      # keep a netprice as well, (sellprice - discount)
      $form->{"netprice_$i"} = $sellprice - $discount;
      
      my $linetotal = $form->round_amount($form->{"qty_$i"} * $sellprice * (1 - $form->{"discount_$i"}/100), $form->{precision});

      if ($form->{"inventory_accno_id_$i"} || $form->{"assembly_$i"}) {
	push(@{ $form->{part} }, $form->{"partnumber_$i"});
	push(@{ $form->{service} }, NULL);
	$form->{totalparts} += $linetotal;
      } else {
	push(@{ $form->{service} }, $form->{"partnumber_$i"});
	push(@{ $form->{part} }, NULL);
	$form->{totalservices} += $linetotal;
      }

      push(@{ $form->{netprice} }, ($form->{"netprice_$i"}) ? $form->format_amount($myconfig, $form->{"netprice_$i"}, $decimalplaces) : " ");
      
      $discount = ($discount) ? $form->format_amount($myconfig, $discount * -1, $decimalplaces) : " ";
      $linetotal = ($linetotal) ? $linetotal : " ";
      
      push(@{ $form->{discount} }, $discount);
      push(@{ $form->{discountrate} }, $form->format_amount($myconfig, $form->{"discount_$i"}));
      if ($form->{"discount_$i"}){
         push(@{ $form->{discountrate_percent} }, $form->format_amount($myconfig, $form->{"discount_$i"}) . '\%');
      } else {
         push(@{ $form->{discountrate_percent} }, $form->format_amount($myconfig, $form->{"discount_$i"}));
      }

      $form->{total} += $linetotal;

      # this is for the subtotals for grouping
      $subtotal += $linetotal;

      push(@{ $form->{xml_linetotal} }, $linetotal);
      $form->{"linetotal_$i"} = $form->format_amount($myconfig, $linetotal, $form->{precision}, "0");
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
	  # if (($form->{"${item}_rate"} * $ml) >= 0) {
	  if ($ml > 0){  
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

	    if ($form->{"inventory_accno_id_$j"} || $form->{"assembly_$i"}) {
	      push(@{ $form->{part} }, "");
	      push(@{ $form->{service} }, NULL);
	    } else {
	      push(@{ $form->{service} }, "");
	      push(@{ $form->{part} }, NULL);
	    }

	    for (qw(taxrates runningnumber number sku serialnumber ordernumber customerponumber bin qty ship unit deliverydate projectnumber sellprice listprice netprice discount discountrate itemnotes package netweight grossweight volume countryorigin hscode barcode xml_deliverydate xml_qty xml_sellprice)) { push(@{ $form->{$_} }, "") }
	    
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

	    if ($form->{"inventory_accno_id_$j"} || $form->{"assembly_$i"}) {
	      push(@{ $form->{part} }, "");
	      push(@{ $form->{service} }, NULL);
	    } else {
	      push(@{ $form->{service} }, "");
	      push(@{ $form->{part} }, NULL);
	    }

	    for (qw(taxrates runningnumber number sku serialnumber ordernumber customerponumber bin qty ship unit deliverydate projectnumber sellprice listprice netprice discount discountrate itemnotes package netweight grossweight volume countryorigin hscode barcode xml_deliverydate xml_qty xml_sellprice)) { push(@{ $form->{$_} }, "") }

	    push(@{ $form->{description} }, $form->{groupsubtotaldescription});
	    push(@{ $form->{xml_linetotal} }, $subtotal);
	    push(@{ $form->{linetotal} }, $form->format_amount($myconfig, $subtotal, $form->{precision}));
	    push(@{ $form->{lineitems} }, { amount => 0, tax => 0 });
	  }
	}
      }
    }
  }

  $tax = 0;
  $taxrate = 0;

  # Remove incorrect 0 taxes from $form and acc_trans
  # First find all taxes which are applicable to this invoice.
  # Duplicated below too
  my %taxaccs;
  for my $tax1 (split / /, $form->{taxaccounts}){
    for my $i (1 .. $form->{rowcount} - 1) {
      for my $tax2 (split / /, $form->{"taxaccounts_$i"}){
       if ($tax1 eq $tax2){
          $taxaccs{$tax2} = 1 if !$taxaccs{$tax2};
       }
      }
    }
  }

  for (sort keys %taxaccs) {
    #if ($taxaccounts{$_} = $form->round_amount($taxaccounts{$_}, $form->{precision})) {
      $tax += $taxaccounts{$_};

      $form->{"${_}_taxbaseinclusive"} = $taxbase{$_} + $taxaccounts{$_};
      
      push(@{ $form->{taxdescription} }, $form->{"${_}_description"});

      $taxrate += $form->{"${_}_rate"};
      
      push(@{ $form->{xml_taxrate} }, $form->{"${_}_rate"} * 100);
      push(@{ $form->{taxrate} }, $form->format_amount($myconfig, $form->{"${_}_rate"} * 100, $form->{precision}, '0.00'));
      push(@{ $form->{taxnumber} }, $form->{"${_}_taxnumber"});
    #}
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
    push(@{ $form->{linetax} }, $form->format_amount($myconfig, $_->{tax}, $form->{precision}, '0.00'));
  }
  
  
  if ($form->{taxincluded}) {
    $form->{invtotal} = $form->{total};
    $form->{subtotal} = $form->{total} - $tax;
  } else {
    $form->{subtotal} = $form->{total};
    $form->{invtotal} = $form->{total} + $tax;
  }

  for (qw(subtotal invtotal)) { $form->{"cd_$_"} = $form->{$_} }
  my $cdt = $form->parse_amount($myconfig, $form->{discount_paid});
  $cdt ||= $form->{cd_available};
  $form->{cd_subtotal} -= $cdt;
  $form->{cd_amount} = $cdt;
  
  my $cashdiscount = 0;
  if ($form->{subtotal}) {
    $cashdiscount = $cdt / $form->{subtotal};
  }

  my $cd_tax = 0;


  # Remove incorrect 0 taxes from $form and acc_trans
  # First find all taxes which are applicable to this invoice.
  # Duplicated below too
  my %taxaccs;
  for my $tax1 (split / /, $form->{taxaccounts}){
    for my $i (1 .. $form->{rowcount} - 1) {
      for my $tax2 (split / /, $form->{"taxaccounts_$i"}){
       if ($tax1 eq $tax2){
          $taxaccs{$tax2} = 1 if !$taxaccs{$tax2};
       }
      }
    }
  }


  for (sort keys %taxaccs) {
    
    #if ($taxaccounts{$_}) {

      $amount = 0;

      if ($form->{cdt} && !$form->{taxincluded}) {
	$amount = $taxbase{$_} * $cashdiscount;
      }
      
      if ($form->{cd_amount}) {
	$form->{"cd_${_}_taxbase"} = $taxbase{$_} - $amount;
	
	push(@{ $form->{cd_taxbase} }, $form->format_amount($myconfig, $form->{"cd_${_}_taxbase"}, $form->{precision}, '0.00'));

	$cd_tax += $form->{"cd_${_}_tax"} = $form->round_amount(($taxbase{$_} - $amount) * $form->{"${_}_rate"}, $form->{precision});

	push(@{ $form->{cd_tax} }, $form->format_amount($myconfig, $form->{"cd_${_}_tax"}, $form->{precision}, '0.00'));
	
	$form->{"cd_${_}_taxbase"} = $form->format_amount($myconfig, $form->{"cd_${_}_taxbase"}, $form->{precision}, '0.00');
	$form->{"cd_${_}_taxbaseinclusive"} = $form->format_amount($myconfig, $form->{"${_}_taxbaseinclusive"} - $amount, $form->{precision}, '0.00');
      }

      if ($form->{cdt} && $form->{discount_paid}) {
	$form->{"${_}_taxbaseinclusive"} -= $amount;
	$taxbase{$_} -= $amount;
	$taxaccounts{$_} -= ($taxaccounts{$_} - $form->{"cd_${_}_tax"});
      }
      
      # need formatting here
      push(@{ $form->{xml_taxbaseinclusive} }, $form->{"${_}_taxbaseinclusive"});
      push(@{ $form->{taxbaseinclusive} }, $form->format_amount($myconfig, $form->{"${_}_taxbaseinclusive"}, $form->{precision}, '0.00'));
      push(@{ $form->{xml_taxbase} }, $taxbase{$_});
      push(@{ $form->{taxbase} }, $form->format_amount($myconfig, $taxbase{$_}, $form->{precision}, '0.00'));
      push(@{ $form->{xml_tax} }, $taxaccounts{$_});
      push(@{ $form->{tax} }, $form->format_amount($myconfig, $taxaccounts{$_}, $form->{precision}, '0.00'));

      $form->{"${_}_taxbaseinclusive"} = $form->format_amount($myconfig, $form->{"${_}_taxbaseinclusive"}, $form->{precision}, '0.00');
      $form->{"xml_${_}_taxbase"} = $taxbase{$_};
      $form->{"${_}_taxbase"} = $form->format_amount($myconfig, $taxbase{$_}, $form->{precision}, '0.00');
      $form->{"xml_${_}_tax"} = $form->{"${_}_tax"};
      $form->{"${_}_tax"} = $form->format_amount($myconfig, $form->{"${_}_tax"}, $form->{precision}, '0.00');
      
      $form->{"xml_${_}_taxrate"} = $form->{"${_}_rate"} * 100;
      $form->{"${_}_taxrate"} = $form->format_amount($myconfig, $form->{"${_}_rate"} * 100, $form->{precision}, '0.00');
      
    #}
  }

  my ($paymentaccno) = split /--/, $form->{"AR_paid_$form->{paidaccounts}"};
  
  for $i (1 .. $form->{paidaccounts}) {
    if ($form->{"paid_$i"}) {
      push(@{ $form->{payment} }, $form->{"paid_$i"});
      my ($accno, $description) = split /--/, $form->{"AR_paid_$i"};
      push(@{ $form->{paymentaccount} }, $description); 
      push(@{ $form->{paymentdate} }, $form->{"datepaid_$i"});
      push(@{ $form->{paymentsource} }, $form->{"source_$i"});
      push(@{ $form->{paymentmemo} }, $form->{"memo_$i"});

      ($description) = split /--/, $form->{"paymentmethod_$i"};
      push(@{ $form->{paymentmethod} }, $description);

      $form->{paid} += $form->parse_amount($myconfig, $form->{"paid_$i"});
    }
  }

  if ($form->{cdt} && $form->{discount_paid}) {
    $form->{invtotal} = $form->{cd_subtotal} + $cd_tax;
    $tax = $cd_tax;
  }

  $form->{cd_invtotal} = $form->{cd_subtotal} + $cd_tax;

  $form->{total} = $form->{invtotal} - $form->{paid};
  
  if (!$form->{cd_amount}) {
    $form->{cd_available} = 0;
    $form->{cd_subtotal} = 0;
    $form->{cd_invtotal} = 0;
  }

  $form->{xml_totaltax} = $tax;
  $form->{totaltax} = $form->format_amount($myconfig, $tax, $form->{precision}, "");

  # Remove incorrect 0 taxes from $form and acc_trans
  # First find all taxes which are applicable to this invoice.
  # Duplicate of similar code above
  my %taxaccs;
  for my $tax1 (split / /, $form->{taxaccounts}){
    for my $i (1 .. $form->{rowcount} - 1) {
      for my $tax2 (split / /, $form->{"taxaccounts_$i"}){
       if ($tax1 eq $tax2){
          $taxaccs{$tax2} = 1 if !$taxaccs{$tax2};
       }
      }
    }
  }

  # Now remove all taxes which are not applicable to this invoice from db and from $form.
  $query = qq|SELECT id, accno FROM chart WHERE id IN (SELECT chart_id FROM tax)|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);
  $form->{id} *= 1;
  while (my $row = $sth->fetchrow_hashref(NAME_lc)){
     if (!$taxaccs{$row->{accno}}){
       map { delete $form->{"$row->{accno}_$_"} } (qw(tax taxbase taxbaseinclusive taxrate description rate taxnumber));
       $dbh->do("DELETE FROM acc_trans WHERE trans_id = $form->{id} AND chart_id = $row->{id} AND amount = 0");
     }
  }
  $sth->finish;

  my $whole;
  my $decimal;
  
  $form->{total} = $form->round_amount($form->{total}, 2);
  
  $qr_numberformat = { numberformat => '1,000.00' };
  $form->{qr_total} =  $form->format_amount($qr_numberformat, $form->{total}, 2);

  ($whole, $decimal) = split /\./, $form->round_amount($form->{invtotal},2);

  $form->{decimal} = substr("${decimal}00", 0, 2);
  $form->{text_decimal} = $c->num2text($form->{decimal} * 1);
  $form->{text_amount} = $c->num2text($whole);
  $form->{integer_amount} = $whole;

  ($whole, $decimal) = split /\./, $form->{total};
  $form->{out_decimal} = substr("${decimal}00", 0, 2);
  $form->{text_out_decimal} = $c->num2text($form->{out_decimal} * 1);
  $form->{text_out_amount} = $c->num2text($whole);
  $form->{integer_out_amount} = $whole;

  $form->{qr_integer_out_amount} =  $form->format_amount($qr_numberformat, $form->{integer_out_amount}, 2);
  for (qw(qr_total qr_integer_out_amount)){ $form->{$_} =~ s/,/ /g }
  if ($form->{cd_amount}) {
    ($whole, $decimal) = split /\./, $form->{cd_invtotal};
    $form->{cd_decimal} = substr("${decimal}00", 0, 2);
    $form->{text_cd_decimal} = $c->num2text($form->{cd_decimal} * 1);
    $form->{text_cd_invtotal} = $c->num2text($whole);
    $form->{integer_cd_invtotal} = $whole;
  }
 
  if (!$utf8templates){
  $form->format_string(qw(text_amount text_decimal text_cd_invtotal text_cd_decimal text_out_amount text_out_decimal));
  }

  for (qw(cd_amount paid)) { $form->{$_} = $form->format_amount($myconfig, $form->{$_}, $form->{precision}) }
  for (qw(invtotal subtotal total)) { $form->{"xml_$_"} = $form->{$_} }
  for (qw(cd_subtotal cd_invtotal invtotal subtotal total totalparts totalservices)) { $form->{$_} = $form->format_amount($myconfig, $form->{$_}, $form->{precision}, "0") }
  for (qw(totalqty totalship totalnetweight totalgrossweight)) { $form->{$_} = $form->format_amount($myconfig, $form->{$_}) }

  # <% customeremail %>
  $form->{customer_id} *= 1;
  ($form->{customeremail}) = $dbh->selectrow_array("SELECT email FROM customer WHERE id = $form->{customer_id}");

  # dcn
  $query = qq|SELECT bk.iban, bk.bic, bk.membernumber, bk.dcn, bk.rvc, bk.invdescriptionqr, bk.qriban, bk.strdbkginf
	      FROM bank bk
	      JOIN chart c ON (c.id = bk.id)
	      WHERE c.accno = |.$dbh->quote($paymentaccno).qq||;
  ($form->{iban}, $form->{bic}, $form->{membernumber}, $form->{dcn}, $form->{rvc},
    $form->{invdescriptionqr}, $form->{qriban}, $form->{strdbkginf}) = $dbh->selectrow_array($query);

  if ( $form->{id} && $form->{dcn} eq "<%external%>" ) {
    $query = qq|SELECT dcn FROM ar
              WHERE id = $form->{id}|;
    my $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);
    $form->{dcn} = $sth->fetchrow_array;
    $sth->finish;
  }

  for my $dcn (qw(dcn rvc)) { $form->{$dcn} = $form->format_dcn($form->{$dcn}) }

  # save dcn
  if ($form->{id}) {
    $query = qq|UPDATE ar SET
		dcn = |.$dbh->quote($form->{dcn}).qq|,
		bank_id = (SELECT id FROM chart WHERE accno = '$paymentaccno')
		WHERE id = $form->{id}|;
    $dbh->do($query) || $form->dberror($query);
  }

  $dbh->disconnect;

  my @oldvars = qw(company companyaddress1 companyzip companycity name address1 zipcode city businessnumber invdate invdescriptionqr qriban strdbkginf);

  # conversion to QR variables ("%" needs to be removed from all variables since it breaks the print, See #112443)
  $form->{invnumber} = substr($form->{invnumber}, 0, 24);
  $form->{invnumber} = $form->string_replace($form->{invnumber}, "%", "");
  $form->{invnumber} = $form->string_replace($form->{invnumber}, "/", ""); # QR Standard requires "/" to be escaped. We just remove it ("/" is rarely used) (See #112446)
  $form->{invnumber} = $form->string_replace($form->{invnumber}, "\Q\\\E", ""); # QR Standard requires "\" to be escaped. We just remove it ("/" is rarely used) ("\Q\\\E" is the escaped regex for "\") (See #112446)
  $form->{invnumberqr} = $form->{invnumber};

  $form->{invdescriptionqr} = $form->format_line($myconfig, $form->{invdescriptionqr});
  $form->{invdescriptionqr} = $form->string_replace($form->{invdescriptionqr}, "%", "");
  $form->{invdescriptionqr} = $form->string_abbreviate($form->{invdescriptionqr}, 55); # abbrevate with ... because of QR Standard (See #112445)
  $form->{invdescriptionqr2} = $form->{invdescriptionqr};
  
  $form->{qribanqr} = $form->{qriban};
  $form->{qribanqr} =~ s/\s//g;
  $form->{qribanqr} = $form->string_replace($form->{qribanqr}, "%", "");

  $form->{companyqr} = substr($form->{company},0,70);
  $form->{companyqr} = $form->string_replace($form->{companyqr}, "%", "");
  
  $form->{companyaddress1qr} = substr($form->{companyaddress1},0,70);
  $form->{companyaddress1qr} = $form->string_replace($form->{companyaddress1qr}, "%", "");

  $form->{companyzipqr} = substr($form->{companyzip},0,16);
  $form->{companyzipqr} = $form->string_replace($form->{companyzipqr}, "%", "");

  $form->{companycityqr} = substr($form->{companycity},0,35);
  $form->{companycityqr} = $form->string_replace($form->{companycityqr}, "%", "");

  $form->{nameqr} = substr($form->{name},0,70);
  $form->{nameqr} = $form->string_replace($form->{nameqr}, "%", "");

  $form->{address1qr} = substr($form->{address1},0,70);
  $form->{address1qr} = $form->string_replace($form->{address1qr}, "%", "");

  $form->{zipcodeqr}  = substr($form->{zipcode},0,16);
  $form->{zipcodeqr} = $form->string_replace($form->{zipcodeqr}, "%", "");

  $form->{cityqr} = substr($form->{city},0,35);
  $form->{cityqr} = $form->string_replace($form->{cityqr}, "%", "");

  my @nums = $form->{businessnumber} =~ /(\d+)/g;
  for (@nums) { $form->{businessnumberqr} .= $_ };

  $form->{swicotaxbaseqr}  = $form->{swicotaxbase};
  $form->{swicotaxbaseqr} = $form->string_replace($form->{swicotaxbaseqr}, "%", "");
  
  $form->{swicotaxqr}  = $form->{swicotax};
  $form->{swicotaxqr} = $form->string_replace($form->{swicotaxqr}, "%", "");

  @taxaccounts = split (/ /, $form->{taxaccounts});
  for (@taxaccounts){
     if ($form->{"${_}_rate"}){
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

  $form->{invdateqr}  = substr($form->datetonum($myconfig, $form->{invdate}),2);
  $form->{invdateqr} = $form->string_replace($form->{invdateqr}, "%", "");

  $form->{strdbkginf} = $form->format_line($myconfig, $form->{strdbkginf});
  $form->{strdbkginf}  = substr($form->{strdbkginf}, 0, 85); # abbrevate to maximum length allowed by the QR Standard.
  $form->{strdbkginf} = $form->string_replace($form->{strdbkginf}, "%", "");
  $form->{strdbkginfqr} = $form->{strdbkginf};
  
  # split strdbkginfqr into 2 lines, since doing this in latex causes display issues for special characters such as "_" (See #112444)
  $form->{strdbkginfline1qr} = substr($form->{strdbkginfqr}, 0, 50);
  $form->{strdbkginfline2qr} = substr($form->{strdbkginfqr}, 50, 85);
  
}


sub delete_invoice {
  my ($self, $myconfig, $form, $spool, $dbh) = @_;
  
  my $disconnect = ($dbh) ? 0 : 1;
  
  # connect to database, turn off autocommit
  if (! $dbh) {
    $dbh = $form->dbconnect_noauto($myconfig);
  }

  $form->{id} *= 1;

  my %defaults = $form->get_defaults($dbh, \@{['precision', 'extendedlog']});

  if ($form->{id} and $defaults{extendedlog}) {
     $query = qq|INSERT INTO ar_log_deleted SELECT ar.* FROM ar WHERE id = $form->{id}|;
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
        JOIN ar aa ON (aa.id = ac.trans_id)
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
        JOIN ar aa ON (aa.id = ac.trans_id)
        WHERE trans_id = $form->{id}|;
     $dbh->do($query) || $form->dberror($query);
  }

  &reverse_invoice($dbh, $form);
  
  my %audittrail = ( tablename  => 'ar',
                     reference  => $form->{invnumber},
		     formname   => $form->{type},
		     action     => 'deleted',
		     id         => $form->{id} );
 
  $form->audittrail($dbh, "", \%audittrail);
     
  # delete AR/AP record
  my $query = qq|DELETE FROM ar
                 WHERE id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

  # delete spool files
  $query = qq|SELECT spoolfile FROM status
              WHERE trans_id = $form->{id}
	      AND spoolfile IS NOT NULL|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  my $spoolfile;
  my @spoolfiles = ();
  
  while (($spoolfile) = $sth->fetchrow_array) {
    push @spoolfiles, $spoolfile;
  }
  $sth->finish;  

  # delete status entries
  $query = qq|DELETE FROM status
              WHERE trans_id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

  $query = qq|UPDATE oe SET aa_id = NULL
              WHERE aa_id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

  $form->remove_locks($myconfig, $dbh, 'ar');

  my $rc = $dbh->commit;

  if ($rc) {
    foreach $spoolfile (@spoolfiles) {
      unlink "$spool/$spoolfile" if $spoolfile;
    }
  }
  
  $dbh->disconnect if $disconnect;
  
  $rc;
  
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
  
  my $query = qq|SELECT p.partnumber, p.description, p.unit, a.qty,
	         pg.partsgroup, p.partnumber AS sku
	         FROM assembly a
	         JOIN parts p ON (a.parts_id = p.id)
	         LEFT JOIN partsgroup pg ON (p.partsgroup_id = pg.id)
	         WHERE a.bom = '1'
	         AND a.aid = |.$dbh->quote($id).qq|
	         $sortorder|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {

    for (qw(partnumber description partsgroup)) {
      $form->{"a_$_"} = $ref->{$_};
      $form->format_string("a_$_");
    }

    if ($form->{grouppartsgroup} && $ref->{partsgroup} ne $sm) {
      for (qw(taxrates runningnumber number sku serialnumber ordernumber customerponumber unit qty ship bin deliverydate projectnumber sellprice listprice netprice discount discountrate linetotal itemnotes package netweight grossweight volume countryorigin hscode barcode)) { push(@{ $form->{$_} }, "") }
      $sm = ($form->{"a_partsgroup"}) ? $form->{"a_partsgroup"} : "--";
      push(@{ $form->{description} }, "$spacer$sm");
      push(@{ $form->{lineitems} }, { amount => 0, tax => 0 });
    }
    if ($form->{stagger}) {
      
      push(@{ $form->{description} }, $form->format_amount($myconfig, $ref->{qty} * $form->{"qty_$i"}) . qq| -- $form->{"a_partnumber"}, $form->{"a_description"}|);
      for (qw(taxrates runningnumber number sku serialnumber ordernumber customerponumber unit qty ship bin deliverydate projectnumber sellprice listprice netprice discount discountrate linetotal itemnotes package netweight grossweight volume countryorigin hscode barcode)) { push(@{ $form->{$_} }, "") }
      
    } else {
      
      push(@{ $form->{description} }, qq|$form->{"a_description"}|);
      push(@{ $form->{number} }, $form->{"a_partnumber"});
      push(@{ $form->{sku} }, $form->{"a_partnumber"});

      for (qw(taxrates runningnumber ship serialnumber ordernumber customerponumber reqdate projectnumber sellprice listprice netprice discount discountrate linetotal itemnotes package netweight grossweight volume countryorigin hscode barcode)) { push(@{ $form->{$_} }, "") }
      
    }

    push(@{ $form->{lineitems} }, { amount => 0, tax => 0 });

    push(@{ $form->{qty} }, $form->format_amount($myconfig, $ref->{qty} * $qty));
    
    for (qw(unit bin)) {
      $form->{"a_$_"} = $ref->{$_};
      $form->format_string("a_$_");
      push(@{ $form->{$_} }, $form->{"a_$_"});
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


sub post_invoice {
  my ($self, $myconfig, $form, $dbh) = @_;
  
  my $disconnect = ($dbh) ? 0 : 1;
  
  # connect to database, turn off autocommit
  if (! $dbh) {
    $dbh = $form->dbconnect_noauto($myconfig);
  }

  my $query;
  my $sth;
  my $null;
  my $project_id;
  my $keepcleared;
  my $ok;
  
  %{$form->{acc_trans}} = ();

  ($null, $form->{employee_id}) = split /--/, $form->{employee};
  unless ($form->{employee_id}) {
    ($form->{employee}, $form->{employee_id}) = $form->get_employee($dbh);
  }
  
  for (qw(department warehouse)) {
    ($null, $form->{"${_}_id"}) = split(/--/, $form->{$_});
    $form->{"${_}_id"} *= 1;
  }

  my %defaults = $form->get_defaults($dbh, \@{['fx%_accno_id', 'cdt', 'precision', 'extendedlog']});
  $form->{precision} = $defaults{precision};

  $query = qq|SELECT p.assembly, p.inventory_accno_id,
              p.income_accno_id, p.expense_accno_id, p.project_id
	      FROM parts p
	      WHERE p.id = ?|;
  my $pth = $dbh->prepare($query) || $form->dberror($query);
  
  $query = qq|SELECT c.accno
              FROM partstax pt
              JOIN chart c ON (c.id = pt.chart_id)
	      WHERE pt.parts_id = ?|;
  my $ptt = $dbh->prepare($query) || $form->dberror($query);
 
  if ($form->{id} *= 1) {
    $keepcleared = 1;
    $query = qq|SELECT id FROM ar
                WHERE id = $form->{id}|;

    if ($dbh->selectrow_array($query)) {
      $query = qq|SELECT id FROM oe WHERE aa_id = $form->{id}|;
      $form->{oe_id} = $dbh->selectrow_array($query);
      if ($form->{oe_id}){
         $form->{oe_id} *= 1;
         $dbh->do("DELETE FROM inventory WHERE trans_id = $form->{oe_id}"); # Delete any 'inventory' transactions saved from order. For existing invoices.
      }
      if ($defaults{extendedlog}) {
        $query = qq|INSERT INTO ar_log SELECT ar.* FROM ar WHERE id = $form->{id}|;
        $dbh->do($query) || $form->dberror($query);
        $query = qq|
            INSERT INTO invoice_log
            SELECT invoice.*, ar.ts
            FROM invoice
            JOIN ar ON (ar.id = invoice.trans_id)
            WHERE invoice.trans_id = $form->{id}
        |;
        $dbh->do($query) || $form->dberror($query);

        $query = qq|
            INSERT INTO acc_trans_log 
            SELECT acc_trans.*, ar.ts
            FROM acc_trans
            JOIN ar ON (ar.id = acc_trans.trans_id)
            WHERE trans_id = $form->{id}
        |;
        $dbh->do($query) || $form->dberror($query);

        $query = qq|UPDATE ar SET ts = NOW() + TIME '00:00:01'  WHERE id = $form->{id}|;
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
            JOIN ar ON (ar.id = ac.trans_id)
            WHERE trans_id = $form->{id}|;
            $dbh->do($query) || $form->dberror($query);
      } # if ($defaults{extendedlog})

      &reverse_invoice($dbh, $form);
    } else {
      $query = qq|INSERT INTO ar (id)
                  VALUES ($form->{id})|;
      $dbh->do($query) || $form->dberror($query);

      if ($form->{order_id}){
         $form->{order_id} *= 1;
         $dbh->do("DELETE FROM inventory WHERE trans_id = $form->{order_id}"); # Delete any 'inventory' transactions saved from order.
      }
    }
    
  }
  
  my $uid = localtime;
  $uid .= $$;
 
  if (! $form->{id}) {
   
    $query = qq|INSERT INTO ar (invnumber, employee_id)
                VALUES (|.$dbh->quote($uid).qq|, |.$form->dbclean($form->{employee_id}).qq|)|;
    $dbh->do($query) || $form->dberror($query);

    $query = qq|SELECT id FROM ar
                WHERE invnumber = '$uid'|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    ($form->{id}) = $sth->fetchrow_array;
    $sth->finish;
  }

  if ($form->{department_id}) {
    $query = qq|INSERT INTO dpt_trans (trans_id, department_id)
                VALUES ($form->{id}, |.$form->dbclean($form->{department_id}).qq|)|;
    $dbh->do($query) || $form->dberror($query);
  }

  $form->{exchangerate} = $form->parse_amount($myconfig, $form->{exchangerate});
  $form->{exchangerate} ||= 1;

  my $i;
  my $item;
  my $allocated = 0;
  my $taxrate;
  my $tax;
  my $fxtax;
  my $fxtax_total = 0;
  my @taxaccounts;
  my $amount;
  my $fxamount;
  my $fxamount_total;
  my $fxpaid_total;
  my $roundamount;
  my $grossamount;
  my $invamount = 0;
  my $invnetamount = 0;
  my $diff = 0;
  my $fxdiff = 0;
  my $ml;
  my $id;
  my $ndx;
  my $sw = ($form->{type} eq 'invoice') ? 1 : -1;
  $sw = 1 if $form->{till};
  my $lineitemdetail;

  $form->{taxincluded} *= 1;

  foreach $i (1 .. $form->{rowcount}) {
    $form->{"qty_$i"} = $form->parse_amount($myconfig, $form->{"qty_$i"}) * $sw;
    
    if ($form->{"qty_$i"}) {
      $form->{"id_$i"} *= 1;
      $pth->execute($form->{"id_$i"});
      $ref = $pth->fetchrow_hashref(NAME_lc);
      for (keys %$ref) { $form->{"${_}_$i"} = $ref->{$_} }
      $pth->finish;
      
      if (! $form->{"taxaccounts_$i"}) {
	$ptt->execute($form->{"id_$i"});
	while ($ref = $ptt->fetchrow_hashref(NAME_lc)) {
	  $form->{"taxaccounts_$i"} .= "$ref->{accno} ";
	}
	$ptt->finish;
	chop $form->{"taxaccounts_$i"};
      }

      # project
      $project_id = 'NULL';
      if ($form->{"projectnumber_$i"}) {
	($null, $project_id) = split /--/, $form->{"projectnumber_$i"};
      }
      $project_id = $form->{"project_id_$i"} if $form->{"project_id_$i"};

      # keep entered selling price
      my $fxsellprice = $form->parse_amount($myconfig, $form->{"sellprice_$i"});

      my ($dec) = ($fxsellprice =~ /\.(\d+)/);
      $dec = length $dec;
      my $decimalplaces = ($dec > $form->{precision}) ? $dec : $form->{precision};
      
      # undo discount formatting
      $form->{"discount_$i"} = $form->parse_amount($myconfig, $form->{"discount_$i"})/100;
     
      # deduct discount
      $form->{"sellprice_$i"} = $fxsellprice;
      
      # linetotal
      my $fxlinetotal = $form->round_amount($form->{"sellprice_$i"} * $form->{"qty_$i"} * (1 - $form->{"discount_$i"}), $form->{precision});
      $fxamount_total += $fxlinetotal;

      $amount = $fxlinetotal * $form->{exchangerate};
      my $linetotal = $form->round_amount($amount, $form->{precision});
      $fxdiff += $form->round_amount($amount - $linetotal, 10);
      
      @taxaccounts = split / /, $form->{"taxaccounts_$i"};
      $ml = 1;
      $tax = 0;
      $fxtax = 0;
      
      for (0 .. 1) {
	$taxrate = 0;

	# add tax rates
	for (@taxaccounts) { $taxrate += $form->{"${_}_rate"} if ($form->{"${_}_rate"} * $ml) > 0 }

	if ($form->{taxincluded}) {
	  $tax += $amount = $linetotal * ($taxrate / (1 + ($taxrate * $ml)));
	  $form->{"sellprice_$i"} -= $amount / $form->{"qty_$i"};
	  $fxtax += $fxamount = $fxlinetotal * ($taxrate / (1 + ($taxrate * $ml)));
	} else {
	  $tax += $amount = $linetotal * $taxrate;
	  $fxtax += $fxamount = $fxlinetotal * $taxrate;
	}
    
        for (@taxaccounts) {
	  if (($form->{"${_}_rate"} * $ml) > 0) {
	    if ($taxrate != 0) {
	      $form->{acc_trans}{$form->{id}}{$_}{amount} += $amount * $form->{"${_}_rate"} / $taxrate;
	      $form->{acc_trans}{$form->{id}}{$_}{fxamount} += $fxamount * $form->{"${_}_rate"} / $taxrate;
	    }
	  }
	}
	
	$ml = -1;
      }
      $fxtax_total += $fxtax;
      $fxamount_total += $fxtax;

      $grossamount = $form->round_amount($linetotal, $form->{precision});
      
      if ($form->{taxincluded}) {
	$amount = $form->round_amount($tax, $form->{precision});
	$linetotal -= $form->round_amount($tax - $diff, $form->{precision});
	$diff = ($amount - $tax);
      }
      
      # add linetotal to income
      $amount = $form->round_amount($linetotal, $form->{precision});

      push @{ $form->{acc_trans}{lineitems} }, {
        chart_id => $form->{"income_accno_id_$i"},
	amount => $amount,
	grossamount => $grossamount,
	fxamount => $fxlinetotal,
	project_id => $project_id };
	
      $ndx = $#{$form->{acc_trans}{lineitems}};

      $form->{"sellprice_$i"} = $form->round_amount($form->{"sellprice_$i"} * $form->{exchangerate}, $decimalplaces);
  
      if ($form->{"inventory_accno_id_$i"} || $form->{"assembly_$i"}) {
	
        if ($form->{"assembly_$i"}) {
          # do not update if assembly consists of all services
	  $query = qq|SELECT sum(p.inventory_accno_id), p.assembly
	              FROM parts p
		      JOIN assembly a ON (a.parts_id = p.id)
		      WHERE a.aid = |.$form->dbclean($form->{"id_$i"}).qq|
		      GROUP BY p.assembly|;
          $sth = $dbh->prepare($query);
	  $sth->execute || $form->dberror($query);
	  my ($inv, $assembly) = $sth->fetchrow_array;
	  $sth->finish;
		      
          if ($inv || $assembly) {
	    $form->update_balance($dbh,
				  "parts",
				  "onhand",
				  qq|id = $form->{"id_$i"}|,
				  $form->{"qty_$i"} * -1) unless $form->{shipped};
	  }

	  &process_assembly($dbh, $form, $form->{"id_$i"}, $form->{"qty_$i"}, $project_id, $i);
	
	} else {

	  # regular part
	  $form->update_balance($dbh,
	                        "parts",
				"onhand",
				qq|id = $form->{"id_$i"}|,
				$form->{"qty_$i"} * -1) unless $form->{shipped};

          if ($form->{"qty_$i"} > 0) {
	    
	    $allocated = &cogs($dbh, $form, $form->{"id_$i"}, $form->{"qty_$i"}, $project_id);
	    
	  } else {
	   
	    # returns
	    $allocated = &cogs_returns($dbh, $form, $form->{"id_$i"}, $form->{"qty_$i"}, $project_id, $i);
	    
	    # change account to inventory
	    $form->{acc_trans}{lineitems}[$ndx]->{chart_id} = $form->{"inventory_accno_id_$i"};

	  }
	}
      }

      # save detail record in invoice table
      $query = qq|INSERT INTO invoice (description, trans_id, parts_id)
                  VALUES (|.$dbh->quote($uid).qq|, $form->{id}, |.$form->dbclean($form->{"id_$i"}).qq|)|;
      $dbh->do($query) || $form->dberror($query);

      $query = qq|SELECT id
                  FROM invoice
                  WHERE description = |.$dbh->quote($uid).qq||;
      ($id) = $dbh->selectrow_array($query);
      
      $lineitemdetail = ($form->{"lineitemdetail_$i"}) ? 1 : 0;
      
      $query = qq|UPDATE invoice SET
		  description = |.$dbh->quote($form->{"description_$i"}).qq|,
		  qty = |.$form->dbclean($form->{"qty_$i"}).qq|,
                  sellprice = |.$form->dbclean($form->{"sellprice_$i"}).qq|,
		  fxsellprice = $fxsellprice,
		  discount = $form->{"discount_$i"},
		  allocated = $allocated,
		  unit = |.$dbh->quote($form->{"unit_$i"}).qq|,
		  transdate = |.$form->dbquote($form->dbclean($form->{"transdate"}), SQL_DATE).qq|,
		  deliverydate = |.$form->dbquote($form->dbclean($form->{"deliverydate_$i"}), SQL_DATE).qq|,
		  project_id = |.$form->dbclean($project_id).qq|,
		  warehouse_id = $form->{warehouse_id},
		  serialnumber = |.$dbh->quote($form->{"serialnumber_$i"}).qq|,
		  ordernumber = |.$dbh->quote($form->{"ordernumber_$i"}).qq|,
		  ponumber = |.$dbh->quote($form->{"customerponumber_$i"}).qq|,
		  itemnotes = |.$dbh->quote($form->{"itemnotes_$i"}).qq|,
		  lineitemdetail = |.$dbh->quote($lineitemdetail).qq|
		  WHERE id = $id|;
      $dbh->do($query) || $form->dberror($query);

      # armaghan - per line tax amount for each tax
	  my $taxamount = 0;
      my $taxamounttotal = 0;
      for (@taxaccounts){
         $ok = $dbh->selectrow_array("SELECT 1 FROM customertax WHERE customer_id = $form->{customer_id} AND chart_id IN (SELECT id FROM chart WHERE accno = '$_')");
         if ($ok){
	$taxamount = $linetotal * $form->{"${_}_rate"} if $form->{"${_}_rate"} != 0; 
    $taxamounttotal += $taxamount;
        if ($taxamount != 0){
	  my $query = qq|INSERT INTO invoicetax (trans_id, invoice_id, chart_id, amount, taxamount)
			VALUES ($form->{id}, $id, (SELECT id FROM chart WHERE accno=|.$dbh->quote($_).qq|), $linetotal,  $taxamount)|;
	  $dbh->do($query) || $form->dberror($query);
	}
      }
     if ($taxamounttotal == 0){ # Item is not taxed
         $ok = $dbh->selectrow_array("SELECT 1 FROM customertax WHERE customer_id = $form->{customer_id} AND chart_id IN (SELECT id FROM chart WHERE accno = '$_')");
         if ($ok){
	  my $query = qq|INSERT INTO invoicetax (trans_id, invoice_id, chart_id, amount, taxamount)
			VALUES ($form->{id}, $id, (SELECT id FROM chart WHERE accno = '$_'), $linetotal, 0)|;
	  $dbh->do($query) || $form->dberror($query);
         }
	 }
  }



      # armaghan - manage warehouse inventory from sale/purchase invoices
      #if (!$form->{shipped}){ # if we are not coming from order screen.
         $query = qq|INSERT INTO inventory (
                        warehouse_id, parts_id, trans_id,
                        orderitems_id, qty,
                        shippingdate,
                        employee_id, department_id, serialnumber, 
			itemnotes, description, invoice_id)
                VALUES (|.$form->dbclean($form->{warehouse_id}).qq|, |.$form->dbclean($form->{"id_$i"}).qq|, $form->{id},
                        1, 0 - (|.$form->dbclean($form->{"qty_$i"}).qq|), | .
                        $form->dbquote($form->dbclean($form->{"transdate"}), SQL_DATE) .
                        qq|, |.$form->dbclean($form->{employee_id}).qq|, $form->{department_id}, | .
                        $dbh->quote($form->{"serialnumber_$i"}) . qq|, | .
                        $dbh->quote($form->{"itemnotes_$i"}) . qq|, | .
			$dbh->quote($form->{"description_$i"}) . qq|, $id)|;
         $dbh->do($query) || $form->dberror($query);
      #}

      # add id
      $form->{acc_trans}{lineitems}[$ndx]->{id} = $id;

      # add inventory
      $ok = ($form->{"package_$i"} ne "") ? 1 : 0;
      for (qw(netweight grossweight volume)) {
	$form->{"${_}_$i"} = $form->parse_amount($myconfig, $form->{"${_}_$i"});
	$ok = 1 if $form->{"${_}_$i"};
      }
      if ($ok) {
	$query = qq|INSERT INTO cargo (id, trans_id, package, netweight,
	            grossweight, volume) VALUES ( $id, $form->{id}, |
		    .$dbh->quote($form->{"package_$i"}).qq|,
		    $form->{"netweight_$i"} * 1, $form->{"grossweight_$i"} * 1,
		    $form->{"volume_$i"} * 1)|;
	$dbh->do($query) || $form->dberror($query);
      }

      $query = qq|UPDATE parts SET
		  bin = |.$dbh->quote($form->{"bin_$i"});
      if ($form->{"netweight_$i"} * 1) {
	my $weight = abs($form->{"netweight_$i"} / $form->{"qty_$i"});
	#$query .= qq|, weight = $weight|;
      }
      $query .= qq|
		  WHERE id = $form->{"id_$i"}|;
      $dbh->do($query) || $form->dberror($query);

    }
  }

  # add lineitems + tax
  $amount = 0;
  $grossamount = 0;
  $fxamount = 0;
  for (@{ $form->{acc_trans}{lineitems} }) {
    $amount += $_->{amount};
    $grossamount += $_->{grossamount};
    $fxamount += $_->{fxamount};
  }
  $invnetamount = $amount;

  $amount = 0;
  for (split / /, $form->{taxaccounts}) { $amount += $form->{acc_trans}{$form->{id}}{$_}{amount} = $form->round_amount($form->{acc_trans}{$form->{id}}{$_}{amount}, $form->{precision}) }
  $invamount = $invnetamount + $amount;

  $diff = 0;
  if ($form->{taxincluded}) {
    $diff = $form->round_amount($grossamount - $invamount, $form->{precision});
    $invamount += $diff;
  }
  $fxdiff = 0 if $form->{rowcount} == 2;
  $fxdiff = $form->round_amount($fxdiff, $form->{precision});
  $invnetamount += $fxdiff;
  $invamount += $fxdiff;

  # armaghan - markpaid is set in im.pl import module
  $form->{paid_1} = $invamount if $form->{markpaid};
  $form->{paid} = 0;
  for $i (1 .. $form->{paidaccounts}) {
    if ($form->{"paid_$i"}) {
      $form->{"paid_$i"} = $form->parse_amount($myconfig, $form->{"paid_$i"}) * $sw;
      $form->{paid} += $form->{"paid_$i"};
      $form->{datepaid} = $form->{"datepaid_$i"};
    }
  }
  $fxpaid_total = $form->{paid};

  if ($form->round_amount($form->{paid} - ($fxamount + $fxtax_total), $form->{precision}) == 0) {
    $form->{paid} = $invamount;
  } else {
    $form->{paid} = $form->round_amount($form->{paid} * $form->{exchangerate}, $form->{precision});
  }

  foreach $ref (sort { $b->{amount} <=> $a->{amount} } @ { $form->{acc_trans}{lineitems} }) {
    $amount = $ref->{amount} + $diff + $fxdiff;
    $query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount,
		transdate, project_id, id)
		VALUES ($form->{id}, $ref->{chart_id}, $amount,
	      |.$dbh->quote($form->{transdate}).qq|, $ref->{project_id}, $ref->{id})|;
    $dbh->do($query) || $form->dberror($query);
    $diff = 0;
    $fxdiff = 0;
  }
  
  $form->{receivables} = $invamount * -1;

  delete $form->{acc_trans}{lineitems};
  
  # update exchangerate
  $form->update_exchangerate($dbh, $form->{currency}, $form->{transdate}, $form->{exchangerate}, 0);

  my $accno;
  my ($araccno) = split /--/, $form->{AR};

  # record receivable
  if ($form->{receivables}) {

    $query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount,
                transdate)
                VALUES ($form->{id},
		       (SELECT id FROM chart
		        WHERE accno = |.$dbh->quote($araccno).qq|),
                $form->{receivables}, |.$dbh->quote($form->{transdate}).qq|)|;
    $dbh->do($query) || $form->dberror($query);
  }
 

  $i = $form->{discount_index};

  if ($form->{"paid_$i"} && $defaults{cdt}) {
    
    my $roundamount;
    $tax = 0;
    $fxtax = 0;
    
    $form->{"exchangerate_$i"} = $form->parse_amount($myconfig, $form->{"exchangerate_$i"});
    $form->{"exchangerate_$i"} ||= 1;

    # calculate tax difference
    my $discount = 0;
    if ($fxamount) {
      $discount = $form->{"paid_$i"} / $fxamount;
    }

    $diff = 0;
    $fxdiff = 0;

    for (split / /, $form->{taxaccounts}) {
      $fxtax = $form->round_amount($form->{acc_trans}{$form->{id}}{$_}{fxamount} * $discount, $form->{precision});

      $amount = $fxtax * $form->{"exchangerate_$i"};

      $tax += $roundamount = $form->round_amount($amount, $form->{precision});
      $diff += $amount - $roundamount;

      push @{ $form->{acc_trans}{taxes} }, {
	accno => $_,
	amount => $roundamount,
	transdate => $form->{"datepaid_$i"},
	id => $form->{id} };

    }

    $diff = $form->round_amount($diff, $form->{precision});
    if ($diff != 0) {
      my $n = $#{$form->{acc_trans}{taxes}};
      $form->{acc_trans}{taxes}[$n]{amount} -= $diff;
    }

    push @{ $form->{acc_trans}{taxes} }, {
      accno => $araccno,
      amount => $tax * -1,
      transdate => $form->{"datepaid_$i"},
      id => 'NULL' };

    $cd_tax = $tax;
    
    foreach $ref (@{ $form->{acc_trans}{taxes} }) {
      $ref->{amount} = $form->round_amount($ref->{amount}, $form->{precision});
      if ($ref->{amount}) {
	$query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount,
	            transdate, id)
	            VALUES ($form->{id},
		           (SELECT id FROM chart
			    WHERE accno = '$ref->{accno}'),
		    $ref->{amount} * -1, '$ref->{transdate}',
		    $ref->{id})|;
	$dbh->do($query) || $form->dberror($query);
      }
    }
    
    delete $form->{acc_trans}{taxes};
    
  }


  foreach my $trans_id (keys %{$form->{acc_trans}}) {
    foreach $accno (keys %{$form->{acc_trans}{$trans_id}}) {
      $amount = $form->round_amount($form->{acc_trans}{$trans_id}{$accno}{amount}, $form->{precision});
      # armaghan removed if block to allow for 0 tax to be inserted.
	$query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount,
		    transdate)
		    VALUES ($trans_id, (SELECT id FROM chart
					WHERE accno = |.$dbh->quote($accno).qq|),
		    $amount, |.$dbh->quote($form->{transdate}).qq|)|;
	$dbh->do($query) || $form->dberror($query);
    }
  }

  
  # if there is no amount but a payment record receivable
  if ($invamount == 0) {
    $form->{receivables} = 1;
  }
  
  my $cleared = 'NULL';
  my $voucherid;
  my $approved;
  my $paymentid = 1;
  my $paymentaccno;
  my $paymentmethod_id;
  my $fxtotalamount_paid = 0;

  # record payments and offsetting AR
  for $i (1 .. $form->{paidaccounts}) {
    
    if ($form->{"paid_$i"}) {
      ($accno) = split /--/, $form->{"AR_paid_$i"};
      
      ($null, $paymentmethod_id) = split /--/, $form->{"paymentmethod_$i"};
      $paymentmethod_id *= 1;

      $paymentaccno = $accno;
      $form->{"datepaid_$i"} = $form->{transdate} unless ($form->{"datepaid_$i"});
      $form->{datepaid} = $form->{"datepaid_$i"};
      
      $form->{"exchangerate_$i"} = $form->parse_amount($myconfig, $form->{"exchangerate_$i"});
      $form->{"exchangerate_$i"} ||= 1;
 
      # record AR
      $amount = $form->round_amount($form->{"paid_$i"} * $form->{exchangerate}, $form->{precision});

      $voucherid = 'NULL';
      $approved = 1;
      
      # add voucher for payment
      if ($form->{voucher}{payment}{$voucherid}{br_id}) {
	if ($form->{"vr_id_$i"}) {

	  $voucherid = $form->{"vr_id_$i"};
	  $approved = $form->{voucher}{payment}{$voucherid}{approved} * 1;

	  if ($i != $form->{discount_index}) {
	    $query = qq|INSERT INTO vr (br_id, trans_id, id, vouchernumber)
			VALUES ($form->{voucher}{payment}{$voucherid}{br_id},
			$form->{id}, $voucherid, |.
			$dbh->quote($form->{voucher}{payment}{$voucherid}{vouchernumber}).qq|)|;
	    $dbh->do($query) || $form->dberror($query);

	    $form->update_balance($dbh,
				  'br',
				  'amount',
				  qq|id = $form->{voucher}{payment}{$voucherid}{br_id}|,
				  $amount);
	  }
	}
      }

      
      if ($form->{receivables}) {
	$query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount,
	            transdate, approved, vr_id)
		    VALUES ($form->{id}, (SELECT id FROM chart
					WHERE accno = '$araccno'),
		    $amount, |.$dbh->quote($form->{"datepaid_$i"}).qq|,
		    '$approved', $voucherid)|;
	$dbh->do($query) || $form->dberror($query);
      }

      my $paymentadjust1 = $amount;

      # record payment
      $amount = $form->{"paid_$i"} * -1;
      $fxtotalamount_paid += $amount * -1;

      my $paymentadjust2 = $amount;

      if ($keepcleared) {
	$cleared = $form->dbquote($form->dbclean($form->{"cleared_$i"}), SQL_DATE);
      }
      
      $query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount, transdate,
                  source, memo, cleared, approved, vr_id, id)
                  VALUES ($form->{id}, (SELECT id FROM chart
		                      WHERE accno = '$accno'),
		  $amount, |.$dbh->quote($form->{"datepaid_$i"}).qq|, |
		  .$dbh->quote($form->{"source_$i"}).qq|, |
		  .$dbh->quote($form->{"memo_$i"}).qq|, $cleared,
		  '$approved', $voucherid, $paymentid)|;
      $dbh->do($query) || $form->dberror($query);

      $query = qq|INSERT INTO payment (id, trans_id, exchangerate,
                  paymentmethod_id)
                  VALUES ($paymentid, $form->{id}, $form->{"exchangerate_$i"},
		  $paymentmethod_id)|;
      $dbh->do($query) || $form->dberror($query);
		  
      $paymentid++;

      # gain/loss
      $amount = $form->round_amount(($form->round_amount($form->{"paid_$i"} * $form->{exchangerate}, $form->{precision}) - $form->round_amount($form->{"paid_$i"} * $form->{"exchangerate_$i"}, $form->{precision})) * -1, $form->{precision});

      my $paymentadjust3 = $amount;

      if ($amount) {
	my $accno_id;
	if ($form->round_amount($amount,1)){
 	   # real gain / loss
	   $accno_id = ($amount > 0) ? $defaults{fxgain_accno_id} : $defaults{fxloss_accno_id};
	} else {
	   # rounding difference
	   ($accno_id) = $dbh->selectrow_array("SELECT id FROM chart WHERE accno = '$araccno'");
	}
	$query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount,
	            transdate, fx_transaction, cleared, approved, vr_id)
	            VALUES ($form->{id}, $accno_id,
		    $amount, '$form->{"datepaid_$i"}', '1', $cleared,
		    '$approved', $voucherid)|;
	$dbh->do($query) || $form->dberror($query);
      }

      # exchangerate difference
      $amount = $form->round_amount(($form->round_amount($form->{"paid_$i"} * $form->{"exchangerate_$i"} - $form->{"paid_$i"}, $form->{precision})) * -1, $form->{precision});

      $amount = ($paymentadjust1 + $paymentadjust2 + $paymentadjust3) * -1; # Override calculated value above to fix outstanding report difference

      if ($amount) { 
	$query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount,
	            transdate, source, fx_transaction, cleared, approved, vr_id)
		    VALUES ($form->{id}, (SELECT id FROM chart
					WHERE accno = |.$dbh->quote($accno).qq|),
		    $amount, |.$dbh->quote($form->{"datepaid_$i"}).qq|, |
		    .$dbh->quote($form->{"source_$i"}).qq|, '1', $cleared,
		    '$approved', $voucherid)|;
	$dbh->do($query) || $form->dberror($query);
      }
     
    }
  }

  ($paymentaccno) = split /--/, $form->{"AR_paid_$form->{paidaccounts}"};

  ($null, $paymentmethod_id) = split /--/, $form->{"paymentmethod_$form->{paidaccounts}"};
  $paymentmethod_id *= 1;

  # if this is from a till
  my $till = ($form->{till}) ? qq|'$form->{till}'| : "NULL";

  $form->{invnumber} = $form->update_defaults($myconfig, "sinumber", $dbh) unless $form->{invnumber};

  for (qw(terms discountterms onhold)) { $form->{$_} *= 1 }
  $form->{cashdiscount} = $form->parse_amount($myconfig, $form->{cashdiscount}) / 100;

  if ($form->{cdt} && $form->{"paid_$form->{discount_index}"}) {
    $invamount -= $cd_tax if !$form->{taxincluded};
  }

  
  # for dcn
  ($form->{integer_amount}, $form->{decimal}) = split /\./, $form->{oldinvtotal};
  $form->{decimal} = substr("$form->{decimal}00", 0, 2);

  $query = qq|SELECT bk.membernumber, bk.dcn
	      FROM bank bk
	      JOIN chart c ON (c.id = bk.id)
	      WHERE c.accno = |.$dbh->quote($paymentaccno).qq||;

  if (!$form->{importing}){ # We are not coming from data import script im.pl
  ($form->{membernumber}, $form->{dcn}) = $dbh->selectrow_array($query);

  $form->{dcn} = ($form->{dcn} == '<%external%>') ? '' : $form->format_dcn($form->{dcn});
  }

  # Fix rounding error
  $invamount = $form->round_amount($invamount, 6);
  $invnetamount = $form->round_amount($invnetamount, 6);

  my $fxtotalamount = 0;
  $fxtotalamount = $form->round_amount($fxtax_total, $form->{precision}) + $fxamount;

  if (($fxtotalamount eq $fxtotalamount_paid) and ($invamount ne $form->{paid})){
     $correction = $form->round_amount($invamount - $form->{paid}, $form->{precision});
     $form->{paid} = $invamount;
     $query = qq|
         update acc_trans 
         set amount = amount + $correction 
         where trans_id = $form->{id} 
         and chart_id = (select id from chart where accno = '$araccno')
         and amount > 0 
         and entry_id = (
               select entry_id from acc_trans where trans_id = $form->{id}
               and chart_id in (select id from chart where accno = |.$dbh->quote($araccno).qq|) and amount > 0 limit 1
               )
     |;
     $dbh->do($query) or $form->error($query);
     
     my ($has_gain_or_loss) = $dbh->selectrow_array(qq|select count(*) from acc_trans where trans_id = $form->{id} and chart_id in ($defaults{fxgain_accno_id}, $defaults{fxloss_accno_id}) limit 1|);
     if ( $has_gain_or_loss ) {
       $query = qq|
           update acc_trans 
           set amount = amount - $correction 
           where trans_id = $form->{id} 
           and chart_id in ($defaults{fxgain_accno_id}, $defaults{fxloss_accno_id})
           and entry_id = (
                 select entry_id from acc_trans where trans_id = $form->{id}
                 and chart_id in ($defaults{fxgain_accno_id}, $defaults{fxloss_accno_id}) limit 1
           )
       |;
       $dbh->do($query) or $form->dberror($query);
     } else {
	    $correction = (-1)*$correction;
	    if ( $correction != 0 ) {
          $query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount,
		            transdate, fx_transaction, cleared, approved, vr_id)
		            VALUES ($form->{id}, $defaults{fxloss_accno_id},
			    $correction, |.$dbh->quote($form->{"datepaid_1"}).qq|, '1', $cleared,
			    '$approved', $voucherid)|;
		  $dbh->do($query) || $form->dberror($query);
		}
     }
  }

  for (qw(oldinvtotal oldtotalpaid)) { $form->{$_} *= 1 }

  $fxamount_total = $invamount if $form->{currency} eq $form->{defaultcurrency};
  $fxamount_total *= 1;
  $fxpaid_total *= 1;

  # save AR record
  $query = qq|UPDATE ar set
              invnumber = |.$dbh->quote($form->{invnumber}).qq|,
              description = |.$dbh->quote($form->{description}).qq|,
	      ordnumber = |.$dbh->quote($form->{ordnumber}).qq|,
	      quonumber = |.$dbh->quote($form->{quonumber}).qq|,
              transdate = |.$dbh->quote($form->{transdate}).qq|,
              customer_id = |.$form->dbclean($form->{customer_id}).qq|,
              amount = $invamount,
              netamount = $invnetamount,
              paid = $form->{paid},
              fxamount = $fxamount_total,
              fxpaid = $fxpaid_total,
	      datepaid = |.$form->dbquote($form->dbclean($form->{datepaid}), SQL_DATE).qq|,
	      duedate = |.$form->dbquote($form->dbclean($form->{duedate}), SQL_DATE).qq|,
	      invoice = '1',
	      shippingpoint = |.$dbh->quote($form->{shippingpoint}).qq|,
	      shipvia = |.$dbh->quote($form->{shipvia}).qq|,
	      waybill = |.$dbh->quote($form->{waybill}).qq|,
	      terms = |.$form->dbclean($form->{terms}).qq|,
	      notes = |.$dbh->quote($form->{notes}).qq|,
	      intnotes = |.$dbh->quote($form->{intnotes}).qq|,
	      taxincluded = '$form->{taxincluded}',
	      curr = |.$dbh->quote($form->{currency}).qq|,
	      department_id = |.$form->dbclean($form->{department_id}).qq|,
	      employee_id = |.$form->dbclean($form->{employee_id}).qq|,
	      till = $till,
	      language_code = |.$dbh->quote($form->{language_code}).qq|,
	      ponumber = |.$dbh->quote($form->{ponumber}).qq|,
	      cashdiscount = $form->{cashdiscount},
	      discountterms = $form->{discountterms},
	      onhold = |.$dbh->quote($form->{onhold}).qq|,
	      warehouse_id = |.$form->dbclean($form->{warehouse_id}).qq|,
	      exchangerate = $form->{exchangerate}
	      | . (($form->{dcn}=='') ? '' : qq|,dcn = |.$dbh->quote($form->{dcn}).qq|| ) . qq|,
	      bank_id = (SELECT id FROM chart WHERE accno = |.$dbh->quote($paymentaccno).qq|),
          paymentmethod_id = |.$form->dbclean($paymentmethod_id).qq|
              WHERE id = $form->{id}
             |;
  $dbh->do($query) || $form->dberror($query);
  # Remove incorrect 0 taxes from $form and acc_trans
  # First find all taxes which are applicable to this invoice.
  my %taxaccs;
  for my $tax1 (split / /, $form->{taxaccounts}){
    for my $i (1 .. $form->{rowcount} - 1) {
      for my $tax2 (split / /, $form->{"taxaccounts_$i"}){
       if ($tax1 eq $tax2){
          $taxaccs{$tax2} = 1 if !$taxaccs{$tax2};
       }
      }
    }
  }

  # Now remove all taxes which are not applicable to this invoice from db and from $form.
  $query = qq|SELECT id, accno FROM chart WHERE id IN (SELECT chart_id FROM tax)|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);
  $form->{id} *= 1;
  while (my $row = $sth->fetchrow_hashref(NAME_lc)){
     if (!$taxaccs{$row->{accno}}){
       map { delete $form->{"$row->{accno}_$_"} } (qw(tax taxbase taxbaseinclusive taxrate description rate taxnumber));
       $dbh->do("DELETE FROM acc_trans WHERE trans_id = $form->{id} AND chart_id = $row->{id} AND amount = 0");
     }
  }
  $sth->finish;

  # add shipto
  $form->{name} = $form->{customer};
  $form->{name} =~ s/--$form->{customer_id}//;
  $form->add_shipto($dbh, $form->{id});

  # save printed, emailed and queued
  $form->save_status($dbh);

  # add link for order
  if ($form->{order_id}) {
	$form->{order_id} *= 1;
    $query = qq|UPDATE oe SET aa_id = $form->{id}
                WHERE id = $form->{order_id}|;
    $dbh->do($query) || $form->dberror($query);
  }
  
  my %audittrail = ( tablename  => 'ar',
                     reference  => $form->{invnumber},
		     formname   => $form->{type},
		     action     => 'posted',
		     id         => $form->{id} );
 
  $form->audittrail($dbh, "", \%audittrail);

  $form->save_recurring($dbh, $myconfig);

  $form->remove_locks($myconfig, $dbh, 'ar');
  
  my $rc = $dbh->commit;

  # armaghan tkt #86 rounding difference between ar and acc_trans
  ($transdate, $diff) = $dbh->selectrow_array("SELECT transdate, amount-paid FROM ar WHERE id = $form->{id}");
  if ($diff == 0){ # Invoice is fully paid
     $ar_amount = $dbh->selectrow_array("SELECT amount FROM ar WHERE id = $form->{id}");
     $ac_amount = $dbh->selectrow_array("
         SELECT SUM(amount)
         FROM acc_trans ac
         JOIN chart c ON (c.id = ac.chart_id)
         WHERE trans_id = $form->{id}
         AND link NOT LIKE '%_paid%'
         AND NOT fx_transaction
     ");
     $ac_netamount = $dbh->selectrow_array("
         SELECT SUM(amount)
         FROM acc_trans ac 
         JOIN chart c ON (c.id = ac.chart_id) 
         WHERE trans_id = $form->{id}
         AND link not like '%_paid%'
         AND link not like '%_tax%' 
         AND not fx_transaction
     ");

     if ($ar_amount != $ac_amount){
        $dbh->do("UPDATE ar SET amount = $ac_amount, netamount = $ac_netamount, paid = $ac_amount WHERE id = $form->{id}") or $form->dberror('Error running query ...');
        $dbh->commit;
     }

     # Now check if there is minor difference in the AR posting
     $query = qq|SELECT ROUND(sum(amount)::numeric,2) FROM acc_trans WHERE trans_id=$form->{id} AND chart_id IN (SELECT id FROM chart WHERE link = 'AR')|;
     ($ar_amount) = $dbh->selectrow_array($query);
     if ($ar_amount != 0){
        ($ar_accno_id) = $dbh->selectrow_array(qq|
            SELECT chart_id FROM acc_trans WHERE trans_id=$form->{id} AND chart_id IN (SELECT id FROM chart WHERE link = 'AR') LIMIT 1|
        );
        ($income_accno_id) = $dbh->selectrow_array(qq|
            SELECT chart_id FROM acc_trans WHERE trans_id=$form->{id} AND chart_id IN (SELECT id FROM chart WHERE link LIKE '%IC_income%') LIMIT 1|
        );
        $query = qq|INSERT INTO acc_trans (trans_id, chart_id, transdate, amount, memo) VALUES ($form->{id}, $income_accno_id, '$transdate', $ar_amount, 'rounding adjustment')|;
        $dbh->do($query) or $form->error($query);
        $ar_amount *= -1;
        $query = qq|INSERT INTO acc_trans (trans_id, chart_id, transdate, amount, memo) VALUES ($form->{id}, $ar_accno_id, '$transdate', $ar_amount, 'rounding adjustment')|;
        $dbh->do($query) or $form->error($query);
        $dbh->commit;
     }
  }

  $dbh->disconnect if $disconnect;

  $rc;
  
}


sub process_assembly {
  my ($dbh, $form, $id, $totalqty, $project_id, $i) = @_;

  my $query = qq|SELECT a.parts_id, a.qty, p.assembly,
                 p.partnumber, p.description, p.unit,
                 p.inventory_accno_id, p.income_accno_id,
		 p.expense_accno_id
                 FROM assembly a
		 JOIN parts p ON (a.parts_id = p.id)
		 WHERE a.aid = $id|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  my $allocated;
  
  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {

    $allocated = 0;
    
    $ref->{inventory_accno_id} *= 1;
    $ref->{expense_accno_id} *= 1;

    # multiply by number of assemblies
    $ref->{qty} *= $totalqty;
    
    if ($ref->{assembly}) {
      &process_assembly($dbh, $form, $ref->{parts_id}, $ref->{qty}, $project_id, $i);
      next;
    } else {
      if ($ref->{inventory_accno_id}) {
	if ($ref->{qty} > 0) {
	  $allocated = &cogs($dbh, $form, $ref->{parts_id}, $ref->{qty}, $project_id);
	} else {
	  $allocated = &cogs_returns($dbh, $form, $ref->{parts_id}, $ref->{qty}, $project_id, $i);
	}
      }
    }

    # save detail record for individual assembly item in invoice table
    $query = qq|INSERT INTO invoice (trans_id, description, parts_id, qty,
                sellprice, fxsellprice, allocated, assemblyitem, unit)
		VALUES
		($form->{id}, |
		.$dbh->quote($ref->{description}).qq|,
		$ref->{parts_id}, $ref->{qty}, 0, 0, $allocated, 't', |
		.$dbh->quote($ref->{unit}).qq|)|;
    $dbh->do($query) || $form->dberror($query);
 
  }

  $sth->finish;

}


sub cogs {
  my ($dbh, $form, $id, $totalqty, $project_id) = @_;

  my $query;
  my $sth;

  $query = qq|SELECT i.id, i.trans_id, i.qty, i.allocated, i.sellprice,
	      p.inventory_accno_id, p.expense_accno_id
	      FROM invoice i
	      JOIN parts p ON (p.id = i.parts_id)
	      WHERE i.parts_id = $id
	      AND (i.qty + i.allocated) < 0
	      ORDER BY i.trans_id|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  my $linetotal;
  my $allocated = 0;
  my $qty;
  
  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    if (($qty = (($ref->{qty} * -1) - $ref->{allocated})) > $totalqty) {
      $qty = $totalqty;
    }
    
    $form->update_balance($dbh,
			  "invoice",
			  "allocated",
			  qq|id = $ref->{id}|,
			  $qty);

    # total expenses and inventory
    # sellprice is the cost of the item
    $linetotal = $form->round_amount($ref->{sellprice} * $qty, $form->{precision});

    # add expense
    push @{ $form->{acc_trans}{lineitems} }, {
      chart_id => $ref->{expense_accno_id},
      amount => $linetotal * -1,
      project_id => $project_id,
      id => $ref->{id} };

    # deduct inventory
    push @{ $form->{acc_trans}{lineitems} }, {
      chart_id => $ref->{inventory_accno_id},
      amount => $linetotal,
      project_id => $project_id,
      id => $ref->{id} };

    # add allocated
    $allocated += -$qty;
    
    last if (($totalqty -= $qty) <= 0);
  }

  $sth->finish;

  $allocated;
  
}


sub cogs_returns {
  my ($dbh, $form, $id, $totalqty, $project_id, $i) = @_;

  my $query;
  my $sth;

  my $linetotal;
  my $qty;
  my $ref;
  
  $totalqty *= -1;
  my $allocated = 0;

  # check if we can apply cogs against sold items
  $query = qq|SELECT i.id, i.trans_id, i.qty, i.allocated,
	      p.inventory_accno_id, p.expense_accno_id
	      FROM invoice i
	      JOIN parts p ON (p.id = i.parts_id)
	      WHERE i.parts_id = $id
	      AND (i.qty + i.allocated) > 0
	      ORDER BY i.trans_id|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  
  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {

    $qty = $ref->{qty} + $ref->{allocated};
    if ($qty > $totalqty) {
      $qty = $totalqty;
    }
    
    $linetotal = $form->round_amount($form->{"sellprice_$i"} * $qty, $form->{precision});
    
    $form->update_balance($dbh,
			  "invoice",
			  "allocated",
			  qq|id = $ref->{id}|,
			  $qty * -1);

    # debit COGS
    $query = qq|INSERT INTO acc_trans (trans_id, chart_id,
                amount, transdate, project_id)
                VALUES ($ref->{trans_id}, $ref->{expense_accno_id},
		$linetotal * -1, |.$dbh->quote($form->{transdate}).qq|, $project_id)|;
    $dbh->do($query) || $form->dberror($query);

    # credit inventory
    $query = qq|INSERT INTO acc_trans (trans_id, chart_id,
                amount, transdate, project_id)
                VALUES ($ref->{trans_id}, $ref->{inventory_accno_id},
		$linetotal, |.$dbh->quote($form->{transdate}).qq|, $project_id)|;
    $dbh->do($query) || $form->dberror($query);

    $allocated += $qty;
    
    last if (($totalqty -= $qty) <= 0);

  }
  $sth->finish;

  $allocated;
  
}


sub reverse_invoice {
  my ($dbh, $form) = @_;
  
  my $query = qq|SELECT id
                 FROM ar
		 WHERE id = $form->{id}|;
  my ($id) = $dbh->selectrow_array($query);
  
  return unless $id;

  my $qty;
  my $amount;
  
  # reverse inventory items
  $query = qq|SELECT i.id, i.parts_id, i.qty, i.allocated, i.assemblyitem,
              i.sellprice, i.project_id,
              p.assembly, p.inventory_accno_id, p.expense_accno_id, p.obsolete
              FROM invoice i
	      JOIN parts p ON (i.parts_id = p.id)
	      WHERE i.trans_id = $form->{id}|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  my $pth;
  my $pref;
  my $totalqty;
  
  $form->{id} *= 1;
  
  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    
    if ($ref->{obsolete}) {
      $query = qq|UPDATE parts SET obsolete = '0'
                  WHERE id = $ref->{parts_id}|;
      $dbh->do($query) || $form->dberror($query);
    }

    if ($ref->{inventory_accno_id} || $ref->{assembly}) {

      # if the invoice item is not an assemblyitem adjust parts onhand
      if (!$ref->{assemblyitem}) {
        # adjust onhand in parts table
	$form->update_balance($dbh,
	                      "parts",
			      "onhand",
			      qq|id = $ref->{parts_id}|,
			      $ref->{qty});
      }

      # loop if it is an assembly
      next if $ref->{assembly} || $ref->{allocated} == 0;

      if ($ref->{allocated} < 0) {
	
	# de-allocate purchases
	$query = qq|SELECT i.id, i.trans_id, i.allocated
		    FROM invoice i
		    WHERE i.parts_id = $ref->{parts_id}
		    AND i.allocated > 0
		    ORDER BY i.trans_id DESC|;

	$pth = $dbh->prepare($query);
	$pth->execute || $form->dberror($query);

	$totalqty = $ref->{allocated} * -1;

	while ($pref = $pth->fetchrow_hashref(NAME_lc)) {

	  $qty = $totalqty;
	  
	  if ($qty > $pref->{allocated}) {
	    $qty = $pref->{allocated};
	  }
	  
	  # update invoice
	  $form->update_balance($dbh,
				"invoice",
				"allocated",
				qq|id = $pref->{id}|,
				$qty * -1);

	  last if (($totalqty -= $qty) <= 0);
	}
	$pth->finish;

      } else {
	
	# de-allocate sales
	$query = qq|SELECT i.id, i.trans_id, i.qty, i.allocated
		    FROM invoice i
		    WHERE i.parts_id = $ref->{parts_id}
		    AND i.allocated < 0
		    ORDER BY i.trans_id DESC|;

	$pth = $dbh->prepare($query);
	$pth->execute || $form->dberror($query);

        $totalqty = $ref->{qty} * -1;
	
	while ($pref = $pth->fetchrow_hashref(NAME_lc)) {

          $qty = $totalqty;

	  if ($qty > ($pref->{allocated} * -1)) {
	    $qty = $pref->{allocated} * -1;
	  }

          $amount = $form->round_amount($ref->{sellprice} * $qty, $form->{precision});
	  #adjust allocated
	  $form->update_balance($dbh,
				"invoice",
				"allocated",
				qq|id = $pref->{id}|,
				$qty);

          $ref->{project_id} ||= 'NULL';
	  # credit cogs
	  $query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount,
	              transdate, project_id)
	              VALUES ($pref->{trans_id}, $ref->{expense_accno_id},
		      $amount, |.$dbh->quote($form->{transdate}).qq|, $ref->{project_id})|;
          $dbh->do($query) || $form->dberror($query);

          # debit inventory
	  $query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount,
	              transdate, project_id)
	              VALUES ($pref->{trans_id}, $ref->{inventory_accno_id},
		      $amount * -1, |.$dbh->quote($form->{transdate}).qq|, $ref->{project_id})|;
          $dbh->do($query) || $form->dberror($query);

	  last if (($totalqty -= $qty) <= 0);
	}
	$pth->finish;
      }
    }
    
    # delete cargo entry
    $query = qq|DELETE FROM cargo
                WHERE trans_id = $form->{id}
		AND id = $ref->{id}|;
    $dbh->do($query) || $form->dberror($query);

  }
  
  $sth->finish;
  
  # get voucher id for payments
  $query = qq|SELECT DISTINCT * FROM vr
              WHERE trans_id = $form->{id}|;
  $sth = $dbh->prepare($query) || $form->dberror($query);

  my %defaults = $form->get_defaults($dbh, \@{['fx%_accno_id']});
  
  $query = qq|SELECT SUM(ac.amount), ac.approved
              FROM acc_trans ac
	      JOIN chart c ON (c.id = ac.chart_id)
	      WHERE ac.trans_id = $form->{id}
	      AND ac.vr_id = ?
	      AND c.link LIKE '%AR_paid%'
	      AND NOT (ac.chart_id = $defaults{fxgain_accno_id}
	            OR ac.chart_id = $defaults{fxloss_accno_id})
	      GROUP BY ac.approved|;
  my $ath = $dbh->prepare($query) || $form->dberror($query);
  
  $sth->execute || $form->dberror($query);
  
  my $approved;
  
  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    
    $form->{voucher}{payment}{$ref->{id}} = $ref;
    
    $ath->execute($ref->{id});
    ($amount, $approved) = $ath->fetchrow_array;
    $ath->finish; 
    
    $form->{voucher}{payment}{$ref->{id}}{approved} = $approved;
    
    $amount = $form->round_amount($amount, $form->{precision});
    
    $form->update_balance($dbh,
                          'br',
			  'amount',
			  qq|id = $ref->{br_id}|,
			  $amount);
  }
  $sth->finish;
  
  
  for (qw(acc_trans dpt_trans invoice invoicetax inventory shipto vr payment)) {
    $query = qq|DELETE FROM $_ WHERE trans_id = $form->{id}|;
    $dbh->do($query) || $form->dberror($query);
  }

  for (qw(recurring recurringemail recurringprint)) {
    $query = qq|DELETE FROM $_ WHERE id = $form->{id}|;
    $dbh->do($query) || $form->dberror($query);
  }

}



sub retrieve_invoice {
  my ($self, $myconfig, $form) = @_;
  
  # connect to database
  my $dbh = $form->dbconnect_noauto($myconfig);

  my $query;
  
  $form->{currencies} = $form->get_currencies($dbh, $myconfig);
 
  if ($form->{id} *= 1) {
    
    # retrieve invoice
    $query = qq|SELECT a.invnumber, a.ordnumber, a.quonumber,
                a.transdate, a.amount, a.netamount, a.paid,
                a.shippingpoint, a.shipvia, a.waybill,
		a.cashdiscount, a.discountterms, a.terms,
		a.notes, a.intnotes,
		a.duedate, a.taxincluded, a.curr AS currency,
		a.employee_id, e.name AS employee, a.till, a.customer_id,
		a.language_code, a.ponumber,
		a.warehouse_id, w.description AS warehouse,
		a.exchangerate,
		c.accno AS bank_accno, c.description AS bank_accno_description,
		t.description AS bank_accno_translation,
		pm.description AS paymentmethod, a.paymentmethod_id
		FROM ar a
	        LEFT JOIN employee e ON (e.id = a.employee_id)
		LEFT JOIN warehouse w ON (a.warehouse_id = w.id)
		LEFT JOIN chart c ON (c.id = a.bank_id)
		LEFT JOIN translation t ON (t.trans_id = c.id AND t.language_code = '$myconfig->{countrycode}')
		LEFT JOIN paymentmethod pm ON (pm.id = a.paymentmethod_id)
		WHERE a.id = $form->{id}|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    $ref = $sth->fetchrow_hashref(NAME_lc);
    for (keys %$ref) { $form->{$_} = $ref->{$_} }
    $sth->finish;

    $query = qq|SELECT id FROM oe WHERE aa_id = $form->{id}|;
    $form->{oe_id} = $dbh->selectrow_array($query);

    if ($form->{bank_accno}) {
      $form->{payment_accno} = ($form->{bank_accno_translation}) ? "$form->{bank_accno}--$form->{bank_accno_translation}" : "$form->{bank_accno}--$form->{bank_accno_description}";
    }

    if ($form->{paymentmethod_id}) {
      $form->{payment_method} = "$form->{paymentmethod}--$form->{paymentmethod_id}";
    }
        
    if ( !$form->{precision} ) {
    	$form->{precision} = 2;
    }    
        
    $form->{type} = ($form->round_amount($form->{amount}, $form->{precision}) < 0) ? 'credit_invoice' : 'invoice';
    $form->{type} = 'pos_invoice' if $form->{till};
    $form->{formname} = $form->{type};

    # get shipto
    $query = qq|SELECT * FROM shipto
                WHERE trans_id = $form->{id}|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    $ref = $sth->fetchrow_hashref(NAME_lc);
    for (keys %$ref) { $form->{$_} = $ref->{$_} }
    $sth->finish;

    # retrieve individual items
    $query = qq|SELECT i.description, i.qty, i.fxsellprice, i.sellprice,
		i.discount, i.parts_id AS id, i.parts_id AS old_id, i.unit, i.deliverydate,
		i.project_id, pr.projectnumber, i.serialnumber, i.ordernumber,
		i.ponumber AS customerponumber, i.itemnotes, i.lineitemdetail,
		p.partnumber, p.assembly, p.bin,
		pg.partsgroup, p.partsgroup_id, p.partnumber AS sku,
		p.listprice, p.lastcost, p.weight, p.onhand,
		p.inventory_accno_id, p.income_accno_id, p.expense_accno_id,
		t.description AS partsgrouptranslation,
		c.package, c.netweight, c.grossweight, c.volume
		FROM invoice i
	        JOIN parts p ON (i.parts_id = p.id)
	        LEFT JOIN project pr ON (i.project_id = pr.id)
	        LEFT JOIN partsgroup pg ON (p.partsgroup_id = pg.id)
		LEFT JOIN translation t ON (t.trans_id = p.partsgroup_id AND t.language_code = |.$dbh->quote($form->{language_code}).qq|)
		LEFT JOIN cargo c ON (c.id = i.id AND c.trans_id = i.trans_id)
		WHERE i.trans_id = $form->{id}
		AND NOT i.assemblyitem = '1'
		ORDER BY i.id|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    # foreign currency
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
    
    while ($ref = $sth->fetchrow_hashref(NAME_lc)) {

      my ($dec) = ($ref->{fxsellprice} =~ /\.(\d+)/);
      $dec = length $dec;
      my $decimalplaces = ($dec > $form->{precision}) ? $dec : $form->{precision};

      $tth->execute($ref->{id});

      $ref->{taxaccounts} = "";
      $taxrate = 0;
      
      while ($ptref = $tth->fetchrow_hashref(NAME_lc)) {
	$ref->{taxaccounts} .= "$ptref->{accno} ";
	$taxrate += $form->{"$ptref->{accno}_rate"};
      }
      $tth->finish;
      chop $ref->{taxaccounts};

      # price matrix
      $ref->{sellprice} = ($ref->{fxsellprice} * $form->{$form->{currency}});
      &price_matrix($pmh, $ref, $form->{transdate}, $decimalplaces, $form, $myconfig);
      $ref->{sellprice} = $ref->{fxsellprice};

      $ref->{partsgroup} = $ref->{partsgrouptranslation} if $ref->{partsgrouptranslation};
      
      push @{ $form->{invoice_details} }, $ref;
    }
    $sth->finish;

  } else {
    $form->{transdate} = $form->current_date($myconfig);
  }

  my $rc = $dbh->commit;
  $dbh->disconnect;
  
  $rc;

}


sub retrieve_item {
  my ($self, $myconfig, $form) = @_;
  
  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $i = $form->{rowcount};
  my $null;
  my $var;

  my $where = "WHERE p.obsolete = '0' AND NOT p.income_accno_id IS NULL";

  if ($form->{"partnumber_$i"} ne "") {
    $var = $form->like(lc $form->{"partnumber_$i"});
    $where .= " AND lower(p.partnumber) LIKE '$var'";
  }
  if ($form->{"description_$i"} ne "") {
    $var = $form->like(lc $form->{"description_$i"});
    if ($form->{language_code} ne "") {
      $where .= " AND lower(t1.description) LIKE '$var'";
    } else {
      $where .= " AND lower(p.description) LIKE '$var'";
    }
  }

  if ($form->{"partsgroup_$i"} ne "") {
    ($null, $var) = split /--/, $form->{"partsgroup_$i"};
    $var *= 1;
    if ($var == 0) {
      # search by partsgroup, this is for the POS
      $where .= qq| AND pg.partsgroup = '$form->{"partsgroup_$i"}'|;
    } else {
      $where .= qq| AND p.partsgroup_id = $var|;
    }
  }

  if ($form->{shipped} or $form->{oe_id}){
     $where .= qq| AND p.inventory_accno_id IS NULL AND p.assembly = '0'|;
  }

  if ($form->{"description_$i"} ne "") {
    $where .= " ORDER BY 3";
  } else {
    $where .= " ORDER BY 2";
  }

  my $onhandvar = 'p.onhand';
  if ($form->{warehouse}){
     my ($null, $warehouse_id) = split /--/, $form->{warehouse};
     $warehouse_id *= 1;
     $onhandvar = "(SELECT SUM(qty) FROM inventory i
	WHERE i.parts_id = p.id AND i.warehouse_id = $warehouse_id) AS onhand"
  }

  my $query = qq|SELECT p.id, p.partnumber, p.description, p.sellprice,
                 p.listprice, p.lastcost,
		 p.unit, p.assembly, p.bin, $onhandvar, p.notes AS itemnotes,
		 p.inventory_accno_id, p.income_accno_id, p.expense_accno_id,
		 pg.partsgroup, p.partsgroup_id, p.partnumber AS sku,
		 p.weight,
		 t1.description AS translation,
		 t2.description AS grouptranslation
                 FROM parts p
		 LEFT JOIN partsgroup pg ON (pg.id = p.partsgroup_id)
		 LEFT JOIN translation t1 ON (t1.trans_id = p.id AND t1.language_code = |.$dbh->quote($form->{language_code}).qq|)
		 LEFT JOIN translation t2 ON (t2.trans_id = p.partsgroup_id AND t2.language_code = |.$dbh->quote($form->{language_code}).qq|)
	         $where|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  my $ref;
  my $ptref;

  # setup exchange rates
  &exchangerate_defaults($dbh, $myconfig, $form);
  
  # taxes
  $query = qq|SELECT c.accno
	      FROM chart c
	      JOIN partstax pt ON (c.id = pt.chart_id)
	      WHERE pt.parts_id = ?|;
  my $tth = $dbh->prepare($query) || $form->dberror($query);


  # price matrix
  my $pmh = &price_matrix_query($dbh, $form);

  my $transdate = $form->datetonum($myconfig, $form->{transdate});
  
  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {

    my ($dec) = ($ref->{sellprice} =~ /\.(\d+)/);
    $dec = length $dec;
    my $decimalplaces = ($dec > $form->{precision}) ? $dec : $form->{precision};

    # get taxes for part
    $tth->execute($ref->{id});

    $ref->{taxaccounts} = "";
    while ($ptref = $tth->fetchrow_hashref(NAME_lc)) {
      $ref->{taxaccounts} .= "$ptref->{accno} ";
    }
    $tth->finish;
    chop $ref->{taxaccounts};

    # get matrix
    &price_matrix($pmh, $ref, $transdate, $decimalplaces, $form, $myconfig);

    $ref->{description} = $ref->{translation} if $ref->{translation};
    $ref->{partsgroup} = $ref->{grouptranslation} if $ref->{grouptranslation};
    
    push @{ $form->{item_list} }, $ref;

  }
  
  $sth->finish;
  $dbh->disconnect;
  
}


sub price_matrix_query {
  my ($dbh, $form) = @_;
  
  $form->{customer_id} *= 1;
  
  my $query = qq|SELECT p.id AS parts_id, 0 AS customer_id, 0 AS pricegroup_id,
              0 AS pricebreak, p.sellprice, NULL AS validfrom, NULL AS validto,
	      '$form->{defaultcurrency}' AS curr, '' AS pricegroup
              FROM parts p
	      WHERE p.id = ?
	      UNION
  
              SELECT p.*, g.pricegroup
              FROM partscustomer p
	      LEFT JOIN pricegroup g ON (g.id = p.pricegroup_id)
	      WHERE p.parts_id = ?
	      AND p.customer_id = $form->{customer_id}
	      
	      UNION
	      SELECT p.*, g.pricegroup 
	      FROM partscustomer p 
	      LEFT JOIN pricegroup g ON (g.id = p.pricegroup_id)
	      JOIN customer c ON (c.pricegroup_id = g.id)
	      WHERE p.parts_id = ?
	      AND c.id = $form->{customer_id}
	      
	      UNION
	      SELECT p.*, '' AS pricegroup
	      FROM partscustomer p
	      WHERE p.customer_id = 0
	      AND p.pricegroup_id = 0
	      AND p.parts_id = ?
	      ORDER BY customer_id DESC, pricegroup_id DESC, pricebreak
	      
	      |;
  $dbh->prepare($query) || $form->dberror($query);

}


sub price_matrix {
  my ($pmh, $ref, $transdate, $decimalplaces, $form, $myconfig) = @_;

  $pmh->execute($ref->{id}, $ref->{id}, $ref->{id}, $ref->{id});
 
  $ref->{pricematrix} = "";
  
  my $customerprice;
  my $pricegroupprice;
  my $sellprice;
  my $baseprice;
  my $mref;
  my %p = ();
  my $i = 0;
  
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

    $mref->{pricebreak} *= 1;

    if ($mref->{customer_id}) {
      $p{$mref->{pricebreak}} = $sellprice;
      $customerprice = 1;
    }

    if ($mref->{pricegroup_id}) {
      if (!$customerprice) {
	$p{$mref->{pricebreak}} = $sellprice;
	$pricegroupprice = 1;
      }
    }

    if (!$customerprice && !$pricegroupprice) {
      $p{$mref->{pricebreak}} = $sellprice;
    }
    
    if (($mref->{pricebreak} + $mref->{customer_id} + $mref->{pricegroup_id}) == 0) {
      $baseprice = $sellprice;
    }

    $i++;
 
  }
  $pmh->finish;

  if (! exists $p{0}) {
    $p{0} = $baseprice;
  }
  
  if ($i > 1) {
    $ref->{sellprice} = $p{0};
    for (sort { $a <=> $b } keys %p) { $ref->{pricematrix} .= "${_}:$p{$_} " }
  } else {
    $ref->{sellprice} = $form->round_amount($p{0} * (1 - $form->{tradediscount}), $decimalplaces);
    $ref->{pricematrix} = "0:$ref->{sellprice} " if $ref->{sellprice};
  }
  chop $ref->{pricematrix};

}


sub exchangerate_defaults {
  my ($dbh, $myconfig, $form) = @_;

  my $var;
  
  my $query;
  
  # get default currencies
  $form->{currencies} = $form->get_currencies($dbh, $myconfig);
  $form->{defaultcurrency} = substr($form->{currencies},0,3);
  
  $query = qq|SELECT buy
              FROM exchangerate
	      WHERE curr = ?
	      AND transdate = ?|;
  my $eth1 = $dbh->prepare($query) || $form->dberror($query);

  $query = qq~SELECT max(transdate || ' ' || buy || ' ' || curr)
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


1;
