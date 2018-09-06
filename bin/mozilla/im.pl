#=====================================================================
# SQL-Ledger ERP
# Copyright (c) 2007
#
#  Author: DWS Systems Inc.
#     Web: http://www.sql-ledger.com
#
#======================================================================
#
# import/export
#
#======================================================================

use SL::IM;
use SL::CP;

use SL::CT;
use SL::IC;
use SL::AM;
use SL::AA;
use SL::GL;
use SL::PE;
 
1;
# end of main


sub import {

  %title = ( sales_invoice => 'Sales Invoices',
	     sales_order => 'Sales Orders',
	     purchase_order => 'Purchase Orders',
	     payment => 'Payments',
	     gl => 'General Ledger',
	     vc => "$form->{db}s",
	     account => 'Accounts',
	     transactions => "$form->{ARAP} Transactions",
	     parts => 'Parts',
	     service => 'Services',
	     partscustomer => 'Parts Customers',
	     partsvendor => 'Parts Vendors',
	   );

# $locale->text('Import Sales Invoices')
# $locale->text('Import Payments')
# $locale->text('Import General Ledger')
# $locale->text('Import AR Transactions')
# $locale->text('Import AP Transactions')
# $locale->text('Import Parts')
# $locale->text('Import Services')

  $msg = "Import $title{$form->{type}}";
  $form->{title} = $locale->text($msg);
  
  $form->header;

  $form->{nextsub} = "im_$form->{type}";
  $form->{action} = "continue";

  if ($form->{type} eq 'sales_invoice' or $form->{type} eq 'payment' or $form->{type} eq 'transactions') {
    IM->paymentaccounts(\%myconfig, \%$form);
    if (@{ $form->{all_paymentaccount} }) {
      @curr = split /:/, $form->{currencies};
      $form->{defaultcurrency} = $curr[0];
      chomp $form->{defaultcurrency};

      for (@curr) { $form->{selectcurrency} .= "$_\n" }
      
      $selectpaymentaccount = "";
      for (@{ $form->{all_paymentaccount} }) { $selectpaymentaccount .= qq|$_->{accno}--$_->{description}\n| }
      if (($form->{type} eq 'sales_invoice') or ($form->{type} eq 'transactions' and $form->{ARAP} eq 'AR')){
	 $paymentaccount = qq|
	  <tr>
	   <th align=right>|.$locale->text('Receipts').qq|</th>
	   <td><input type=checkbox name=markpaid value='Y'></td>
	  </tr>
	|;
      }
      $paymentaccount .= qq|
         <tr>
	  <th align=right>|.$locale->text('Account').qq|</th>
	  <td>
	    <select name=paymentaccount>|.$form->select_option($selectpaymentaccount)
	    .qq|</select>
	  </td>
	</tr>
	<tr>
	  <th align=right nowrap>|.$locale->text('Currency').qq|</th>
	  <td><select name=currency>|
	  .$form->select_option($form->{selectcurrency}, $form->{currency})
	  .qq|</select></td>
	</tr>|;
      $selectarapaccounts = "";
      for (@{ $form->{arap_accounts} }) { $selectarapaccounts .= qq|$_->{accno}--$_->{description}\n| }
      $arapaccounts = qq|
         <tr>
	  <th align=right>|.$locale->text("$form->{ARAP} Account").qq|</th>
	  <td>
	    <select name=arapaccount>|.$form->select_option($selectarapaccounts)
	    .qq|</select>
	  </td>
	</tr>| if $form->{ARAP};

      if ($form->{type} ne 'transactions'){
         $selectincomeaccounts = "";
         for (@{ $form->{income_accounts} }) { $selectincomeaccounts .= qq|$_->{accno}--$_->{description}\n| }
         $incomeaccounts = qq|
         <tr>
	  <th align=right>|.$locale->text("Income Account").qq|</th>
	  <td>
	    <select name=incomeaccount>|.$form->select_option($selectincomeaccounts)
	    .qq|</select>
	  </td>
	</tr>| if $form->{ARAP} eq 'AR';

        $selectexpenseaccounts = "";
        for (@{ $form->{expense_accounts} }) { $selectexpenseaccounts .= qq|$_->{accno}--$_->{description}\n| }
        $expenseaccounts = qq|
         <tr>
	  <th align=right>|.$locale->text("Expense Account").qq|</th>
	  <td>
	    <select name=expenseaccount>|.$form->select_option($selectexpenseaccounts)
	    .qq|</select>
	  </td>
	 </tr>| if $form->{ARAP} eq 'AP';
      }
    }
  } elsif ($form->{type} =~ /(parts|service)/) {
	IC->create_links("IC", \%myconfig, \%$form);
  	$form->{taxaccounts} = "";

  	# parts, assemblies , labor and overhead have the same links
	$taxpart = ($form->{item} eq 'service') ? "service" : "part";

        foreach $key (keys %{ $form->{IC_links} }) {
          $form->{"select$key"} = "";
          foreach $ref (@{ $form->{IC_links}{$key} }) {
            # if this is a tax field
            if ($key =~ /IC_tax/) {
	      if ($key =~ /$taxpart/) {
	  
	        $form->{taxaccounts} .= "$ref->{accno} ";
	        $form->{"IC_tax_$ref->{accno}_description"} = "$ref->{accno}--$ref->{description}";

	        if ($form->{id}) {
	          if ($form->{amount}{$ref->{accno}}) {
	            $form->{"IC_tax_$ref->{accno}"} = "checked";
	          }
	        } else {
	          $form->{"IC_tax_$ref->{accno}"} = "checked";
	        }
	  
	      }
            } else {
	      $form->{"select$key"} .= "$ref->{accno}--$ref->{description}\n";
            }
          }
        }
        chop $form->{taxaccounts};

	my $tax;
	$tax = qq|<input type=hidden name=taxaccounts value='$form->{taxaccounts}'>|;

        for (split / /, $form->{taxaccounts}) { $form->{"IC_tax_$_"} = ($form->{"IC_tax_$_"}) ? "checked" : "" }
	# tax fields
	foreach $item (split / /, $form->{taxaccounts}) {
	    $tax .= qq|
      		<input class=checkbox type=checkbox name="IC_tax_$item" value=1 $form->{"IC_tax_$item"}>&nbsp;<b>$form->{"IC_tax_${item}_description"}</b>
      		<br>|.$form->hide_form("IC_tax_${item}_description");
  	}

        if ($form->{type} eq 'parts'){
        $itemaccounts = qq|
         <tr>
	  <th align=right>|.$locale->text('Inventory').qq|</th>
	  <td>
	    <select name=IC_inventory>|.$form->select_option($form->{"selectIC"})
	    .qq|</select>
	  </td>
	</tr>
         <tr>
	  <th align=right>|.$locale->text('Income').qq|</th>
	  <td>
	    <select name=IC_income>|.$form->select_option($form->{"selectIC_income"})
	    .qq|</select>
	  </td>
	</tr>
         <tr>
	  <th align=right>|.$locale->text('COGS').qq|</th>
	  <td>
	    <select name=IC_expense>|.$form->select_option($form->{"selectIC_expense"})
	    .qq|</select>
	  </td>
	</tr>|;
       } elsif ($form->{type} eq 'service') {
        $itemaccounts = qq|
	</tr>
         <tr>
	  <th align=right>|.$locale->text('Income').qq|</th>
	  <td>
	    <select name=IC_income>|.$form->select_option($form->{"selectIC_income"})
	    .qq|</select>
	  </td>
	</tr>
         <tr>
	  <th align=right>|.$locale->text('Expense').qq|</th>
	  <td>
	    <select name=IC_expense>|.$form->select_option($form->{"selectIC_expense"})
	    .qq|</select>
	  </td>
	</tr>
       |;
       }
        $itemaccounts .= qq|
	<tr>
	   <th></th>
	   <td>$tax</td>
	</tr>|;
  } elsif ($form->{type} eq 'vc') {
	$form->{ARAP} = ($form->{db} eq 'customer') ? 'AR' : 'AP';
	CT->create_links(\%myconfig, \%$form);
	for (keys %$form) { $form->{$_} = $form->quote($form->{$_}) }
	if ($form->{currencies}) {
	  # currencies
	  for (split /:/, $form->{currencies}) { $form->{selectcurrency} .= "$_\n" }
	}
	# accounts
	foreach $item (qw(arap discount payment)) {
	   if (@ { $form->{"${item}_accounts"} }) {
	      $form->{"select$item"} = "\n";
              for (@{ $form->{"${item}_accounts"} }) { $form->{"select$item"} .= qq|$_->{accno}--$_->{description}\n| }
              $form->{"select$item"} = $form->escape($form->{"select$item"},1);
           }
        }
	if ($form->{selectcurrency}) {
	   $currency = qq|
          <th align=right>|.$locale->text('Currency').qq|</th>
          <td><select name=curr>|
          .$form->select_option($form->{selectcurrency}, $form->{curr})
          .qq|</select></td>\n|;
  	}

	$vclinks .= $currency;

	$taxable = qq|<input type=hidden name=taxaccounts value='$form->{taxaccounts}'>\n|;
  	for (split / /, $form->{taxaccounts}) {
	    $form->{"tax_${_}_description"} =~ s/ /&nbsp;/g;
	    if ($form->{"tax_$_"}) {
	      $taxable .= qq| <input name="tax_$_" value=1 class=checkbox type=checkbox checked>&nbsp;<b>$form->{"tax_${_}_description"}</b>\n|;
	    } else {
	      $taxable .= qq| <input name="tax_$_" value=1 class=checkbox type=checkbox>&nbsp;<b>$form->{"tax_${_}_description"}</b>\n|;
	    }
	}

	$form->{taxincluded} = ($form->{taxincluded}) ? "checked" : "";

	if ($taxable) {
	    $tax = qq|
	          <tr>
		    <td>&nbsp;</td>
	            <td>
			$taxable
	                <input name=taxincluded class=checkbox type=checkbox value=1 $form->{taxincluded}> <b>|.$locale->text('Tax Included').qq|</b>
	            </td>
	          </tr>
		|;
	}
	$vclinks .= $tax;

 	if ($form->{selectarap}) {
	    $arapaccount = qq|
	        <tr>
	          <th align=right>|.$locale->text($form->{ARAP}).qq|</th>
	          <td><select name="arap_accno">|
	          .$form->select_option($form->{selectarap}, $form->{arap_accno})
	          .qq|</select>
	          </td>
	        </tr>
		|;

  	}
  	$vclinks .= $arapaccount;

	if ($form->{selectpayment}) {

	    $paymentaccount = qq|
		<tr>
 	  	<th align=right>|.$locale->text('Payment').qq|</th>
	  	<td><select name="payment_accno">|
	  	.$form->select_option($form->{selectpayment}, $form->{payment_accno})
	  	.qq|</select>
	  	</td>
		</tr>
	    |;
  	}
    }

  
print qq|
<body>

<form enctype="multipart/form-data" method=post action=$form->{script}>

<table width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <td>
      <table>
	$arapaccounts
	$incomeaccounts
	$expenseaccounts
	$vclinks
        $paymentaccount
	$itemaccounts
        <tr>
	  <th align=right>|.$locale->text('File to Import').qq|</th>
	  <td>
	    <input name=data size=60 type=file>
	  </td>
	</tr>
	<tr valign=top>
	  <th align=right>|.$locale->text('Type of File').qq|</th>
	  <td>
	    <table>
	      <tr>
	        <td><input name=filetype type=radio class=radio value=CSV checked>&nbsp;|.$locale->text('CSV').qq|</td>
		<td width=20></td>
		<th align=right>|.$locale->text('Delimiter').qq|</th>
		<td><input name=delimiter size=2 value=","></td>
	      </tr>
	      <tr>
		<th align=right colspan=2>|.$locale->text('Tab delimited file').qq|</th>
		<td align=left><input name=tabdelimited type=checkbox class=checkbox></td>
	      </tr>
	    </table>
	  </td>
	</tr>
	<tr>
	  <th align=right>|.$locale->text('Mapfile').qq|</th>
	  <td><input name=mapfile type=radio class=radio value=1>&nbsp;|.$locale->text('Yes').qq|&nbsp;
	      <input name=mapfile type=radio class=radio value=0 checked>&nbsp;|.$locale->text('No').qq|
	  </td>
	</tr>
      </table>
    </td>
  </tr>
  <tr>
    <td><hr size=3 noshade></td>
  </tr>

</table>
|;

  $form->hide_form(qw(ARAP vc db defaultcurrency title type action nextsub login path));

  print qq|
<input name=action class=submit type=submit value="|.$locale->text('Continue').qq|">
</form>

</body>
</html>
|;

}


sub export {

  %title = ( payment => 'Payments'
	   );

# $locale->text('Export Payments')

  $form->{file} ||= time;

  $msg = "Export $title{$form->{type}}";
  $form->{title} = $locale->text($msg);
  
  $form->header;

  $form->{nextsub} = "ex_$form->{type}";
  $form->{action} = "continue";

  if ($form->{type} eq 'payment') {
    IM->paymentaccounts(\%myconfig, \%$form);
    if (@{ $form->{all_paymentaccount} }) {
      @curr = split /:/, $form->{currencies};
      $form->{defaultcurrency} = $curr[0];
      chomp $form->{defaultcurrency};

      for (@curr) { $form->{selectcurrency} .= "$_\n" }
      
      $form->{selectpaymentaccount} = "";
      for (@{ $form->{all_paymentaccount} }) { $form->{selectpaymentaccount} .= qq|$_->{accno}--$_->{description}\n| }
	
      if (@{ $form->{all_paymentmethod} }) {
	$form->{selectpaymentmethod} = "\n";
	for (@{ $form->{all_paymentmethod} }) { $form->{selectpaymentmethod} .= qq|$_->{description}--$_->{id}\n| }
      }

      $paymentaccount = qq|
         <tr>
	  <th align=right>|.$locale->text('Account').qq|</th>
	  <td>
	    <select name=paymentaccount>|.$form->select_option($form->{selectpaymentaccount})
	    .qq|</select>
	  </td>
	</tr>
	<tr>
	  <th align=right nowrap>|.$locale->text('Currency').qq|</th>
	  <td><select name=currency>|
	  .$form->select_option($form->{selectcurrency}, $form->{currency})
	  .qq|</select></td>
	</tr>
|;

      if ($form->{selectpaymentmethod}) {
	$paymentaccount .= qq|
	<tr>
	  <th align=right nowrap>|.$locale->text('Payment Method').qq|</th>
	  <td><select name=paymentmethod>|
	  .$form->select_option($form->{selectpaymentmethod}, $form->{paymentmethod}, 1)
	  .qq|</select></td>
	</tr>
|;
      }
    }
  }

  @a = ();
  push @a, qq|<input name="l_invnumber" class=checkbox type=checkbox value=Y checked> |.$locale->text('Invoice Number');
  push @a, qq|<input name="l_description" class=checkbox type=checkbox value=Y> |.$locale->text('Description');
  push @a, qq|<input name="l_dcn" class=checkbox type=checkbox value=Y checked> |.$locale->text('DCN');
  push @a, qq|<input name="l_name" class=checkbox type=checkbox value=Y checked> |.$locale->text('Company Name');
  push @a, qq|<input name="l_companynumber" class=checkbox type=checkbox value=Y> |.$locale->text('Company Number');
  push @a, qq|<input name="l_datepaid" class=checkbox type=checkbox value=Y checked> |.$locale->text('Date Paid');
  push @a, qq|<input name="l_amount" class=checkbox type=checkbox value=Y checked> |.$locale->text('Amount');
  push @a, qq|<input name="l_curr" class=checkbox type=checkbox value=Y> |.$locale->text('Currency');
  push @a, qq|<input name="l_paymentmethod" class=checkbox type=checkbox value=Y> |.$locale->text('Payment Method');
  push @a, qq|<input name="l_source" class=checkbox type=checkbox value=Y checked> |.$locale->text('Source');
  push @a, qq|<input name="l_memo" class=checkbox type=checkbox value=Y> |.$locale->text('Memo');
  
  
print qq|
<body>

<form method=post action=$form->{script}>

<table width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <td>
      <table>
        $paymentaccount
        <tr>
	  <th align=right>|.$locale->text('Filename').qq|</th>
	  <td>
	    <input name=file size=20 value="$form->{file}">
	  </td>
	</tr>
	<tr valign=top>
	  <th align=right>|.$locale->text('Type of File').qq|</th>
	  <td>
	    <table>
	      <tr>
	        <td><input name=filetype type=radio class=radio value=CSV checked>&nbsp;|.$locale->text('CSV').qq|</td>
		<td width=20></td>
		<th align=right>|.$locale->text('Delimiter').qq|</th>
		<td><input name=delimiter size=2 value=","></td>
	      </tr>
	      <tr>
		<th align=right colspan=2>|.$locale->text('Tab delimited file').qq|</th>
		<td align=left><input name=tabdelimited type=checkbox class=checkbox></td>
		<th align=right>|.$locale->text('Include Header').qq|</th>
		<td align=left><input name=includeheader type=checkbox class=checkbox checked></td>
	      </tr>

	    </table>
	  </td>
	</tr>
	<tr>
	  <th align=right>|.$locale->text('Include in Report').qq|</th>
	  <td>
	    <table>
|;
  while (@a) {
    print qq|<tr>\n|;
    for (1 .. 5) {
      print qq|<td nowrap>|. shift @a;
      print qq|</td>\n|;
    }
    print qq|</tr>\n|;
  }

  print qq|
            </table>
	  </td>
	</tr>
      </table>
    </td>
  </tr>
  <tr>
    <td><hr size=3 noshade></td>
  </tr>

</table>
|;

  $form->hide_form(qw(defaultcurrency title type action nextsub login path));

  print qq|
<input name=action class=submit type=submit value="|.$locale->text('Continue').qq|">
</form>

</body>
</html>
|;

}


sub im_sales_invoice {

  $form->error($locale->text('Import File missing!')) if ! $form->{data};

  @column_index = qw(ndx transdate invnumber customer customernumber city dcn invoicedescription total curr exchangerate totalqty unit duedate employee department warehouse);
  @flds = @column_index;
  shift @flds;
  push @flds, qw(ordnumber quonumber customer_id datepaid dcn shippingpoint shipvia waybill terms notes intnotes language_code ponumber cashdiscount discountterms employee_id parts_id description sellprice discount qty unit serialnumber projectnumber deliverydate AR taxincluded department_id warehouse_id);
  unshift @column_index, "runningnumber";
    
  $form->{callback} = "$form->{script}?action=import";
  for (qw(type login path)) { $form->{callback} .= "&$_=$form->{$_}" }

  &xrefhdr;
  
  $form->{vc} = 'customer';
  IM->sales_invoice(\%myconfig, \%$form);

  $column_data{runningnumber} = "&nbsp;";
  $column_data{transdate} = $locale->text('Invoice Date');
  $column_data{invnumber} = $locale->text('Invoice Number');
  $column_data{invoicedescription} = $locale->text('Description');
  $column_data{dcn} = $locale->text('DCN');
  $column_data{customer} = $locale->text('Customer');
  $column_data{customernumber} = $locale->text('Customer Number');
  $column_data{city} = $locale->text('City');
  $column_data{total} = $locale->text('Total');
  $column_data{totalqty} = $locale->text('Qty');
  $column_data{curr} = $locale->text('Curr');
  $column_data{exchangerate} = $locale->text('Exchange Rate');
  $column_data{unit} = $locale->text('Unit');
  $column_data{duedate} = $locale->text('Due Date');
  $column_data{employee} = $locale->text('Salesperson');
  $column_data{department} = $locale->text('Department');
  $column_data{warehouse} = $locale->text('Warehouse');

  $form->header;
 
  print qq|
<body>

<form method=post action=$form->{script}>

<table width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <td>
      <table width=100%>
        <tr class=listheading>
|;

  for (@column_index) { print "\n<th>$column_data{$_}</th>" }

  print qq|
        </tr>
|;

  # $form->{ndx} contains sequence number of each unqiue invoice number.
  # For example we have 5 lines items CSV file and first invoice has 
  # two items, 2nd,3rd,4th invoices one item, then $form->{ndx} will
  # be 1,3,4,5 (as in our sample csv file on wiki) and $form->{rowcount} = 5
  @ndx = split / /, $form->{ndx};
  $ndx = shift @ndx;
  $k = 0;

  if ($form->{batch_import}){
     for $i (1 .. $form->{rowcount}){
        if ($form->{"customer_id_$i"}) {
           $form->{"ndx_$i"} = "on";
	}
     }
     &import_sales_invoices;
     exit;
  }

  for $i (1 .. $form->{rowcount}) {
    
    # Show only first line for multi-line invoices
    if ($i == $ndx) {
      $k++;
      $j++; $j %= 2;
      $ndx = shift @ndx;
   
      print qq|
        <tr class=listrow$j>
|;

      $total += $form->{"total_$i"};
      
      for (@column_index) { $column_data{$_} = qq|<td>$form->{"${_}_$i"}</td>| }
      $column_data{total} = qq|<td align=right>|.$form->format_amount(\%myconfig, $form->{"total_$i"}, $form->{precision}).qq|</td>|;
      $column_data{totalqty} = qq|<td align=right>|.$form->format_amount(\%myconfig, $form->{"totalqty_$i"}).qq|</td>|;

      $column_data{runningnumber} = qq|<td align=right>$k</td>|;
      
      if ($form->{"customer_id_$i"}) {
	$column_data{ndx} = qq|<td><input name="ndx_$i" type=checkbox class=checkbox checked></td>|;
      } else {
	$column_data{ndx} = qq|<td>&nbsp;</td>|;
      }

      for (@column_index) { print $column_data{$_} }

      print qq|
	</tr>
|;
    
    }

    $form->hide_form(map { "${_}_$i" } @flds);
    
  }

  # print total
  for (@column_index) { $column_data{$_} = qq|<td>&nbsp;</td>| }
  $column_data{total} = qq|<th class=listtotal align=right>|.$form->format_amount(\%myconfig, $total, $form->{precision}, "&nbsp;")."</th>";

  print qq|
        <tr class=listtotal>
|;

  for (@column_index) { print "\n$column_data{$_}" }
  
  print qq|
        </tr>
      </table>
    </td>
  </tr>
|;

  if ($form->{missingparts}) {
    print qq|
    <tr>
      <td>|;
      $form->info($locale->text('The following parts could not be found:')."\n\n");
      for (split /\n/, $form->{missingparts}) {
	$form->info("$_\n");
      }
    print qq|
      </td>
    </tr>
|;
  }

  print qq|
  <tr>
    <td><hr size=3 noshade></td>
  </tr>

</table>
|;
   
  $form->hide_form(qw(vc rowcount ndx type login path callback markpaid paymentaccount));

  print qq|
<input name=action class=submit type=submit value="|.$locale->text('Import Sales Invoices').qq|">
</form>

</body>
</html>
|;

}

sub im_sales_order {

  $form->error($locale->text('Import File missing!')) if ! $form->{data};

  @column_index = qw(ndx transdate ordnumber customer customernumber city orderdescription total curr totalqty unit duedate employee);
  @flds = @column_index;
  shift @flds;
  push @flds, qw(ordnumber quonumber customer_id datepaid shippingpoint shipvia waybill terms notes intnotes language_code ponumber discountterms employee_id parts_id description sellprice discount qty unit serialnumber projectnumber deliverydate);
  unshift @column_index, "runningnumber";
    
  $form->{callback} = "$form->{script}?action=import";
  for (qw(type login path)) { $form->{callback} .= "&$_=$form->{$_}" }

  &xrefhdr;
  
  $form->{vc} = 'customer';
  IM->sales_order(\%myconfig, \%$form);

  $column_data{runningnumber} = "&nbsp;";
  $column_data{transdate} = $locale->text('Order Date');
  $column_data{ordnumber} = $locale->text('Order Number');
  $column_data{orderdescription} = $locale->text('Description');
  $column_data{customer} = $locale->text('Customer');
  $column_data{customernumber} = $locale->text('Customer Number');
  $column_data{city} = $locale->text('City');
  $column_data{total} = $locale->text('Total');
  $column_data{totalqty} = $locale->text('Qty');
  $column_data{curr} = $locale->text('Curr');
  $column_data{unit} = $locale->text('Unit');
  $column_data{duedate} = $locale->text('Due Date');
  $column_data{employee} = $locale->text('Salesperson');

  $form->header;
 
  print qq|
<body>

<form method=post action=$form->{script}>

<table width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <td>
      <table width=100%>
        <tr class=listheading>
|;

  for (@column_index) { print "\n<th>$column_data{$_}</th>" }

  print qq|
        </tr>
|;

  @ndx = split / /, $form->{ndx};
  $ndx = shift @ndx;
  $k = 0;

  for $i (1 .. $form->{rowcount}) {
    
    if ($i == $ndx) {
      $k++;
      $j++; $j %= 2;
      $ndx = shift @ndx;
   
      print qq|
        <tr class=listrow$j>
|;

      $total += $form->{"total_$i"};
      
      for (@column_index) { $column_data{$_} = qq|<td>$form->{"${_}_$i"}</td>| }
      $column_data{total} = qq|<td align=right>|.$form->format_amount(\%myconfig, $form->{"total_$i"}, $form->{precision}).qq|</td>|;
      $column_data{totalqty} = qq|<td align=right>|.$form->format_amount(\%myconfig, $form->{"totalqty_$i"}).qq|</td>|;

      $column_data{runningnumber} = qq|<td align=right>$k</td>|;
      
      if ($form->{"customer_id_$i"}) {
	$column_data{ndx} = qq|<td><input name="ndx_$i" type=checkbox class=checkbox $form->{"checked_$i"}></td>|;
      } else {
	$column_data{ndx} = qq|<td>&nbsp;</td>|;
      }

      for (@column_index) { print $column_data{$_} }

      print qq|
	</tr>
|;
    
    }

    $form->hide_form(map { "${_}_$i" } @flds);
    
  }

  # print total
  for (@column_index) { $column_data{$_} = qq|<td>&nbsp;</td>| }
  $column_data{total} = qq|<th class=listtotal align=right>|.$form->format_amount(\%myconfig, $total, $form->{precision}, "&nbsp;")."</th>";

  print qq|
        <tr class=listtotal>
|;

  for (@column_index) { print "\n$column_data{$_}" }
  
  print qq|
        </tr>
      </table>
    </td>
  </tr>
|;

  if ($form->{missingparts}) {
    print qq|
    <tr>
      <td>|;
      $form->info($locale->text('The following parts could not be found:')."\n\n");
      for (split /\n/, $form->{missingparts}) {
	$form->info("$_\n");
      }
    print qq|
      </td>
    </tr>
|;
  }

  print qq|
  <tr>
    <td><hr size=3 noshade></td>
  </tr>

</table>
|;
   
  $form->hide_form(qw(vc rowcount ndx type login path callback));

  print qq|
<input name=action class=submit type=submit value="|.$locale->text('Import Sales Orders').qq|">
</form>

</body>
</html>
|;

}

sub im_purchase_order {

  $form->error($locale->text('Import File missing!')) if ! $form->{data};

  @column_index = qw(ndx transdate ordnumber vendor vendornumber city orderdescription total curr totalqty unit duedate employee);
  @flds = @column_index;
  shift @flds;
  push @flds, qw(ordnumber quonumber vendor_id datepaid shippingpoint shipvia waybill terms notes intnotes language_code ponumber discountterms employee_id parts_id description sellprice discount qty unit serialnumber projectnumber deliverydate);
  unshift @column_index, "runningnumber";
    
  $form->{callback} = "$form->{script}?action=import";
  for (qw(type login path)) { $form->{callback} .= "&$_=$form->{$_}" }

  &xrefhdr;
  
  $form->{vc} = 'vendor';
  IM->purchase_order(\%myconfig, \%$form);

  $column_data{runningnumber} = "&nbsp;";
  $column_data{transdate} = $locale->text('Order Date');
  $column_data{ordnumber} = $locale->text('Order Number');
  $column_data{orderdescription} = $locale->text('Description');
  $column_data{vendor} = $locale->text('Vendor');
  $column_data{vendornumber} = $locale->text('Vendor Number');
  $column_data{city} = $locale->text('City');
  $column_data{total} = $locale->text('Total');
  $column_data{totalqty} = $locale->text('Qty');
  $column_data{curr} = $locale->text('Curr');
  $column_data{unit} = $locale->text('Unit');
  $column_data{duedate} = $locale->text('Due Date');
  $column_data{employee} = $locale->text('Employee');

  $form->header;
 
  print qq|
<body>

<form method=post action=$form->{script}>

<table width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <td>
      <table width=100%>
        <tr class=listheading>
|;

  for (@column_index) { print "\n<th>$column_data{$_}</th>" }

  print qq|
        </tr>
|;

  @ndx = split / /, $form->{ndx};
  $ndx = shift @ndx;
  $k = 0;

  for $i (1 .. $form->{rowcount}) {
    
    if ($i == $ndx) {
      $k++;
      $j++; $j %= 2;
      $ndx = shift @ndx;
   
      print qq|
        <tr class=listrow$j>
|;

      $total += $form->{"total_$i"};
      
      for (@column_index) { $column_data{$_} = qq|<td>$form->{"${_}_$i"}</td>| }
      $column_data{total} = qq|<td align=right>|.$form->format_amount(\%myconfig, $form->{"total_$i"}, $form->{precision}).qq|</td>|;
      $column_data{totalqty} = qq|<td align=right>|.$form->format_amount(\%myconfig, $form->{"totalqty_$i"}).qq|</td>|;

      $column_data{runningnumber} = qq|<td align=right>$k</td>|;
      
      if ($form->{"vendor_id_$i"}) {
	$column_data{ndx} = qq|<td><input name="ndx_$i" type=checkbox class=checkbox $form->{"checked_$i"}></td>|;
      } else {
	$column_data{ndx} = qq|<td>&nbsp;</td>|;
      }

      for (@column_index) { print $column_data{$_} }

      print qq|
	</tr>
|;
    
    }

    $form->hide_form(map { "${_}_$i" } @flds);
    
  }

  # print total
  for (@column_index) { $column_data{$_} = qq|<td>&nbsp;</td>| }
  $column_data{total} = qq|<th class=listtotal align=right>|.$form->format_amount(\%myconfig, $total, $form->{precision}, "&nbsp;")."</th>";

  print qq|
        <tr class=listtotal>
|;

  for (@column_index) { print "\n$column_data{$_}" }
  
  print qq|
        </tr>
      </table>
    </td>
  </tr>
|;

  if ($form->{missingparts}) {
    print qq|
    <tr>
      <td>|;
      $form->info($locale->text('The following parts could not be found:')."\n\n");
      for (split /\n/, $form->{missingparts}) {
	$form->info("$_\n");
      }
    print qq|
      </td>
    </tr>
|;
  }

  print qq|
  <tr>
    <td><hr size=3 noshade></td>
  </tr>

</table>
|;
   
  $form->hide_form(qw(vc rowcount ndx type login path callback));

  print qq|
<input name=action class=submit type=submit value="|.$locale->text('Import Purchase Orders').qq|">
</form>

</body>
</html>
|;

}


sub xrefhdr {
  
  $form->{delimiter} ||= ',';
 
  $i = 0;

  if ($form->{mapfile}) {
    open(FH, "$myconfig{templates}/import.map") or $form->error($!);

    while (<FH>) {
      next if /^(#|;|\s)/;
      chomp;

      s/\s*(#|;).*//g;
      s/^\s*(.*?)\s*$/$1/;

      last if $xrefhdr && $_ =~ /^\[/;

      if (/^\[$form->{type}\]/) {
	$xrefhdr = 1;
	next;
      }

      if ($xrefhdr) {
	($key, $value) = split /=/, $_;
	@a = split /,/, $value;
	$form->{$form->{type}}{$a[0]} = { field => $key, length => $a[1], ndx => $i++ };
      }
    }
    close FH;
    
  } else {
    # get first line
    @a = split /\n/, $form->{data};

    if ($form->{tabdelimited}) {
      $form->{delimiter} = '\t';
    } else {
      $a[0] =~ s/(^"|"$)//g;
      $a[0] =~ s/"$form->{delimiter}"/$form->{delimiter}/g;
    }
      
    for (split /$form->{delimiter}/, $a[0]) {
      $form->{$form->{type}}{$_} = { field => $_, length => "", ndx => $i++ };
    }
  }

}


sub import_sales_invoices {

  my $numberformat = $myconfig{numberformat};
  $myconfig{numberformat} = "1000.00";

  my %ndx = ();
  my @ndx = split / /, $form->{ndx};
  
  my $i;
  my $j = shift @ndx;
  my $k = shift @ndx;
  $k ||= $j;

  for $i (1 .. $form->{rowcount}) {
    if ($i == $k) {
      $j = $k;
      $k = shift @ndx;
    }
    push @{$ndx{$j}}, $i;
  }

  my $total = 0;
  
  $newform = new Form;

  my $m = 0;
  
  for $k (keys %ndx) {
    
    if ($form->{"ndx_$k"}) {

      $m++;

      for (keys %$newform) { delete $newform->{$_} };

      $newform->{importing} = 1;
      $newform->{precision} = $form->{precision};

      for (qw(invnumber ordnumber quonumber transdate customer customer_id datepaid duedate dcn shippingpoint shipvia waybill terms notes intnotes curr exchangerate language_code ponumber cashdiscount discountterms AR taxincluded)) { $newform->{$_} = $form->{"${_}_$k"} }
      $newform->{description} = $form->{"invoicedescription_$k"};

      $newform->{employee} = qq|--$form->{"employee_id_$k"}|;
      $newform->{department} = qq|--$form->{"department_id_$k"}|;
      $newform->{warehouse} = qq|--$form->{"warehouse_id_$k"}|;

      $newform->{type} = "invoice";

      $j = 1; 

      for $i (@{ $ndx{$k} }) {

        $total += $form->{"sellprice_$i"} * $form->{"qty_$i"};
	
	$newform->{"id_$j"} = $form->{"parts_id_$i"};
	for (qw(qty discount)) { $newform->{"${_}_$j"} = $form->format_amount($myconfig, $form->{"${_}_$i"}) }
	for (qw(description unit deliverydate serialnumber itemnotes projectnumber)) { $newform->{"${_}_$j"} = $form->{"${_}_$i"} }
	$newform->{"sellprice_$j"} = $form->format_amount($myconfig, $form->{"sellprice_$i"});

        $test = sprintf('%s', $newform->{"description_$j"});
	$form->info($test);

	$j++; 
      }

      $newform->{rowcount} = $j;
      if ($form->{markpaid}){
	$newform->{markpaid} = 'Y';
	$newform->{datepaid_1} = $newform->{transdate};
	$newform->{AR_paid_1} = $form->{paymentaccount};
	$newform->{paidaccounts} = 2;
      }

      # post invoice
      $form->info("${m}. ".$locale->text('Posting Invoice ...'));
      if (IM->import_sales_invoice(\%myconfig, \%$newform)) {
	$form->info(qq| $newform->{invnumber}, $newform->{description}, $newform->{customernumber}, $newform->{name}, $newform->{city}, |);
	$myconfig{numberformat} = $numberformat;
	$form->info($form->format_amount(\%myconfig, $form->{"total_$k"}, $form->{precision}));
	$myconfig{numberformat} = "1000.00";
	$form->info(" ... ".$locale->text('ok')."\n");
      } else {
	$form->error($locale->text('Posting failed!'));
      }
    }
  }

  $myconfig{numberformat} = $numberformat;
  $form->info("\n".$locale->text('Total:')." ".$form->format_amount(\%myconfig, $total, $form->{precision}));
  
}

sub import_sales_orders {

  my $numberformat = $myconfig{numberformat};
  $myconfig{numberformat} = "1000.00";

  my %ndx = ();
  my @ndx = split / /, $form->{ndx};
  
  my $i;
  my $j = shift @ndx;
  my $k = shift @ndx;
  $k ||= $j;

  for $i (1 .. $form->{rowcount}) {
    if ($i == $k) {
      $j = $k;
      $k = shift @ndx;
    }
    push @{$ndx{$j}}, $i;
  }

  my $total = 0;
  
  $newform = new Form;

  my $m = 0;
  
  for $k (keys %ndx) {
    
    if ($form->{"ndx_$k"}) {

      $m++;

      for (keys %$newform) { delete $newform->{$_} };

      $newform->{precision} = $form->{precision};

      for (qw(ordnumber quonumber transdate customer customer_id reqdate shippingpoint shipvia waybill terms notes intnotes curr language_code ponumber cashdiscount discountterms AR taxincluded)) { $newform->{$_} = $form->{"${_}_$k"} }
      $newform->{description} = $form->{"orderdescription_$k"};

      $newform->{employee} = qq|--$form->{"employee_id_$k"}|;
      $newform->{department} = qq|--$form->{"department_id_$k"}|;
      $newform->{warehouse} = qq|--$form->{"warehouse_id_$k"}|;

      $newform->{type} = "sales_order";

      $j = 1; 

      for $i (@{ $ndx{$k} }) {

        $total += $form->{"sellprice_$i"} * $form->{"qty_$i"};
	
	$newform->{"id_$j"} = $form->{"parts_id_$i"};
	for (qw(qty discount)) { $newform->{"${_}_$j"} = $form->format_amount($myconfig, $form->{"${_}_$i"}) }
	for (qw(description unit deliverydate serialnumber itemnotes projectnumber)) { $newform->{"${_}_$j"} = $form->{"${_}_$i"} }
	$newform->{"sellprice_$j"} = $form->format_amount($myconfig, $form->{"sellprice_$i"});

	$j++; 
      }
      
      $newform->{rowcount} = $j;
      
      # post order
      $form->info("${m}. ".$locale->text('Posting Order ...'));
      if (IM->import_sales_order(\%myconfig, \%$newform)) {
	$form->info(qq| $newform->{ordnumber}, $newform->{description}, $newform->{customernumber}, $newform->{name}, $newform->{city}, |);
	$myconfig{numberformat} = $numberformat;
	$form->info($form->format_amount(\%myconfig, $form->{"total_$k"}, $form->{precision}));
	$myconfig{numberformat} = "1000.00";
	$form->info(" ... ".$locale->text('ok')."\n");
      } else {
	$form->error($locale->text('Posting failed!'));
      }
    }
  }

  $myconfig{numberformat} = $numberformat;
  $form->info("\n".$locale->text('Total:')." ".$form->format_amount(\%myconfig, $total, $form->{precision}));
  
}

sub import_purchase_orders {

  my $numberformat = $myconfig{numberformat};
  $myconfig{numberformat} = "1000.00";

  my %ndx = ();
  my @ndx = split / /, $form->{ndx};
  
  my $i;
  my $j = shift @ndx;
  my $k = shift @ndx;
  $k ||= $j;

  for $i (1 .. $form->{rowcount}) {
    if ($i == $k) {
      $j = $k;
      $k = shift @ndx;
    }
    push @{$ndx{$j}}, $i;
  }

  my $total = 0;
  
  $newform = new Form;

  my $m = 0;
  
  for $k (keys %ndx) {
    
    if ($form->{"ndx_$k"}) {

      $m++;

      for (keys %$newform) { delete $newform->{$_} };

      $newform->{precision} = $form->{precision};

      for (qw(ordnumber quonumber transdate vendor vendor_id reqdate shippingpoint shipvia waybill terms notes intnotes curr language_code ponumber cashdiscount discountterms AP taxincluded)) { $newform->{$_} = $form->{"${_}_$k"} }
      $newform->{description} = $form->{"orderdescription_$k"};

      $newform->{employee} = qq|--$form->{"employee_id_$k"}|;
      $newform->{department} = qq|--$form->{"department_id_$k"}|;
      $newform->{warehouse} = qq|--$form->{"warehouse_id_$k"}|;

      $newform->{type} = "purchase_order";

      $j = 1; 

      for $i (@{ $ndx{$k} }) {

        $total += $form->{"sellprice_$i"} * $form->{"qty_$i"};
	
	$newform->{"id_$j"} = $form->{"parts_id_$i"};
	for (qw(qty discount)) { $newform->{"${_}_$j"} = $form->format_amount($myconfig, $form->{"${_}_$i"}) }
	for (qw(description unit deliverydate serialnumber itemnotes projectnumber)) { $newform->{"${_}_$j"} = $form->{"${_}_$i"} }
	$newform->{"sellprice_$j"} = $form->format_amount($myconfig, $form->{"sellprice_$i"});

	$j++; 
      }
      
      $newform->{rowcount} = $j;
      
      # post order
      $form->info("${m}. ".$locale->text('Posting Order ...'));
      if (IM->import_purchase_order(\%myconfig, \%$newform)) {
	$form->info(qq| $newform->{ordnumber}, $newform->{description}, $newform->{vendornumber}, $newform->{name}, $newform->{city}, |);
	$myconfig{numberformat} = $numberformat;
	$form->info($form->format_amount(\%myconfig, $form->{"total_$k"}, $form->{precision}));
	$myconfig{numberformat} = "1000.00";
	$form->info(" ... ".$locale->text('ok')."\n");
      } else {
	$form->error($locale->text('Posting failed!'));
      }
    }
  }

  $myconfig{numberformat} = $numberformat;
  $form->info("\n".$locale->text('Total:')." ".$form->format_amount(\%myconfig, $total, $form->{precision}));
  
}



sub im_payment {

  $form->error($locale->text('Import File missing!')) if ! $form->{data};

  @column_index = qw(runningnumber ndx invnumber description dcn name companynumber city datepaid amount);
  push @column_index, "exchangerate" if $form->{currency} ne $form->{defaultcurrency};
  @flds = @column_index;
  shift @flds;
  shift @flds;
  push @flds, qw(id source memo paymentmethod arap vc);
  
  $form->{callback} = "$form->{script}?action=import";
  for (qw(type login path)) { $form->{callback} .= "&$_=$form->{$_}" }
  
  &xrefhdr;
  
  IM->payments(\%myconfig, \%$form);

  $column_data{runningnumber} = "&nbsp;";
  $column_data{datepaid} = $locale->text('Date Paid');
  $column_data{invnumber} = $locale->text('Invoice');
  $column_data{description} = $locale->text('Description');
  $column_data{name} = $locale->text('Company');
  $column_data{company} = $locale->text('Company Number');
  $column_data{city} = $locale->text('City');
  $column_data{dcn} = $locale->text('DCN');
  $column_data{amount} = $locale->text('Paid');
  $column_data{exchangerate} = $locale->text('Exch');

  $form->header;
 
  print qq|
<body>

<form method=post action=$form->{script}>

<table width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <td>
      <table width=100%>
        <tr class=listheading>
|;

  for (@column_index) { print "\n<th>$column_data{$_}</th>" }

  print qq|
        </tr>
|;

  for $i (1 .. $form->{rowcount}) {
    
    $j++; $j %= 2;
 
    print qq|
      <tr class=listrow$j>
|;

    $total += $form->parse_amount(\%myconfig, $form->{"amount_$i"});

    for (@column_index) { $column_data{$_} = qq|<td>$form->{"${_}_$i"}</td>| }
    $column_data{amount} = qq|<td align=right>$form->{"amount_$i"}</td>|;

    $column_data{runningnumber} = qq|<td align=right>$i</td>|;
    $column_data{exchangerate} = qq|<td><input name="exchangerate_$i" size=10 value=|.$form->format_amount(\%myconfig, $form->{"exchangerate_$i"}).qq|></td>|;
    
    $column_data{ndx} = qq|<td><input name="ndx_$i" type=checkbox class=checkbox checked></td>|;

    for (@column_index) { print $column_data{$_} }

    print qq|
	</tr>
|;
    
    $form->{"paymentmethod_$i"} = qq|--$form->{"paymentmethod_id_$i"}|;
    $form->hide_form(map { "${_}_$i" } @flds);
    
  }

  # print total
  for (@column_index) { $column_data{$_} = qq|<td>&nbsp;</td>| }
  $column_data{amount} = qq|<th class=listtotal align=right>|.$form->format_amount(\%myconfig, $total, $form->{precision}, "&nbsp;")."</th>";

  print qq|
        <tr class=listtotal>
|;

  for (@column_index) { print "\n$column_data{$_}" }
  
  print qq|
        </tr>
      </table>
    </td>
  </tr>
  <tr>
    <td><hr size=3 noshade></td>
  </tr>

</table>
|;
  
  $form->{paymentaccount} =~ s/--.*//;

  $form->hide_form(qw(precision rowcount type paymentaccount currency defaultcurrency login path callback));

  print qq|
<input name=action class=submit type=submit value="|.$locale->text('Import Payments').qq|">
</form>

</body>
</html>
|;

}


sub import_payments {

  my $m = 0;

  $newform = new Form;
  
  for my $i (1 .. $form->{rowcount}) {
    
    if ($form->{"ndx_$i"}) {

      $m++;
      
      for (keys %$newform) { delete $newform->{$_} };

      for (qw(precision currency defaultcurrency)) { $newform->{$_} = $form->{$_} }
      for (qw(vc arap exchangerate datepaid amount source memo paymentmethod)) { $newform->{$_} = $form->{"${_}_$i"} }
      $newform->{ARAP} = uc $newform->{arap};

      $newform->{rowcount} = 1;
      $newform->{"$newform->{ARAP}_paid"} = $form->{paymentaccount};
      $newform->{"paid_1"} = $form->{"amount_$i"};
      $newform->{"checked_1"} = 1;
      $newform->{"id_1"} = $form->{"id_$i"};
      
      $form->info("${m}. ".$locale->text('Posting Payment ...'));

      if (CP->post_payment(\%myconfig, \%$newform)) {
	$form->info(qq| $form->{"invnumber_$i"}, $form->{"description_$i"}, $form->{"companynumber_$i"}, $form->{"name_$i"}, $form->{"city_$i"}, |);
	$form->info($form->{"amount_$i"});
	$form->info(" ... ".$locale->text('ok')."\n");
      } else {
	$form->error($locale->text('Posting failed!'));
      }
    }
  }

}


sub ex_payment {

  %columns = ( invnumber => { ndx => 1 },
               description => { ndx => 2 },
	       dcn => { ndx => 3 },
	       name => { ndx => 4 },
	       companynumber => { ndx => 5 },
	       datepaid => { ndx => 6 },
	       amount => { ndx => 7, numeric => 1 },
	       curr => { ndx => 8 },
	       paymentmethod => { ndx => 9 },
	       source => { ndx => 10 },
	       memo => { ndx => 11 }
	     );
  
  @column_index = qw(runningnumber ndx);
  $form->{column_index} = "";
 
  for (sort { $columns{$a}->{ndx} <=> $columns{$b}->{ndx} } keys %columns) {
    push @flds, $_;
    if ($form->{"l_$_"} eq "Y") {
      push @column_index, $_;
      $form->{column_index} .= "$_=$columns{$_}->{numeric},";
    }
  }
  chop $form->{column_index};
  
  push @flds, "id";

 
  $form->{callback} = "$form->{script}?action=export";
  for (qw(type login path)) { $form->{callback} .= "&$_=$form->{$_}" }
  
  &xrefhdr;
  
  IM->unreconciled_payments(\%myconfig, \%$form);

  $column_data{runningnumber} = "&nbsp;";
  $column_data{ndx} = qq|<input name="allbox" type=checkbox class=checkbox value="1" checked onChange="CheckAll();">|;
  
  $column_data{datepaid} = $locale->text('Date Paid');
  $column_data{invnumber} = $locale->text('Invoice');
  $column_data{description} = $locale->text('Description');
  $column_data{name} = $locale->text('Company');
  $column_data{companynumber} = $locale->text('Company Number');
  $column_data{city} = $locale->text('City');
  $column_data{dcn} = $locale->text('DCN');
  $column_data{amount} = $locale->text('Paid');
  $column_data{paymentmethod} = $locale->text('Payment Method');
  $column_data{source} = $locale->text('Source');
  $column_data{memo} = $locale->text('Memo');
  $column_data{curr} = $locale->text('Curr');

  $form->header;
 
  print qq|
<script language="JavaScript">
<!--

function CheckAll() {

  var frm = document.forms[0]
  var el = frm.elements
  var re = /ndx_/;

  for (i = 0; i < el.length; i++) {
    if (el[i].type == 'checkbox' && re.test(el[i].name)) {
      el[i].checked = frm.allbox.checked
    }
  }
}

// -->
</script>

<body>

<form method=post action=$form->{script}>

<table width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <td>
      <table width=100%>
        <tr class=listheading>
|;

  for (@column_index) { print "\n<th>$column_data{$_}</th>" }

  print qq|
        </tr>
|;

  $i = 0;
  foreach $ref (@{ $form->{TR} }) {
    
    $j++; $j %= 2;
 
    print qq|
      <tr class=listrow$j>
|;

    $i++;
    
    $total += $ref->{amount};
    
    for (@column_index) { $column_data{$_} = qq|<td>$ref->{$_}</td>| }
    $column_data{amount} = qq|<td align=right>|.$form->format_amount(\%myconfig, $ref->{amount}, $form->{precision}).qq|</td>|;

    $column_data{runningnumber} = qq|<td align=right>$i</td>|;
    
    $column_data{ndx} = qq|<td><input name="ndx_$i" type=checkbox class=checkbox checked></td>|;

    for (@column_index) { print $column_data{$_} }

    print qq|
	</tr>
|;

    for (@flds) { $form->{"${_}_$i"} = $ref->{$_} };
    $form->hide_form(map { "${_}_$i" } @flds);
    
  }

  $form->{rowcount} = $i;

  # print total
  for (@column_index) { $column_data{$_} = qq|<td>&nbsp;</td>| }
  $column_data{amount} = qq|<th class=listtotal align=right>|.$form->format_amount(\%myconfig, $total, $form->{precision}, "&nbsp;")."</th>";

  print qq|
        <tr class=listtotal>
|;

  for (@column_index) { print "\n$column_data{$_}" }
  
  print qq|
        </tr>
      </table>
    </td>
  </tr>
  <tr>
    <td><hr size=3 noshade></td>
  </tr>

</table>
|;
  
  $form->hide_form(qw(column_index rowcount file filetype delimiter tabdelimited includeheader type paymentaccount paymentmethod currency defaultcurrency login path callback));

  print qq|
<input name=action class=submit type=submit value="|.$locale->text('Export Payments').qq|">
</form>

</body>
</html>
|;

}


sub export_payments {

  open(OUT, ">-") or $form->error("STDOUT : $!");
  
  binmode(OUT);
  
  print qq|Content-Type: application/file;
Content-Disposition: attachment; filename="$form->{file}.$form->{filetype}"\n\n|;

  @column_index = split /,/, $form->{column_index};
  for (@column_index) {
    ($f, $n) = split /=/, $_;
    $column_index{$f} = $n;
  }
  @column_index = grep { s/=.*// } @column_index;

  if ($form->{tabdelimited}) {
    $form->{delimiter} = "\t";
    for (@column_index) { $column_index{$_} = 1 }
  }

  # print header
  $line = "";
  if ($form->{includeheader}) {
    for (@column_index) {
      if ($form->{tabdelimited}) {
	$line .= qq|$_$form->{delimiter}|;
      } else {
	$line .= qq|"$_"$form->{delimiter}|;
      }
    }
    chop $line;
    print OUT "$line\n";
  }
  
  for $i (1 .. $form->{rowcount}) {
    $line = "";
    if ($form->{"ndx_$i"}) {
      for (@column_index) {
	if ($column_index{$_}) {
	  $line .= qq|$form->{"${_}_$i"}$form->{delimiter}|;
	} else {
	  $line .= qq|"$form->{"${_}_$i"}"$form->{delimiter}|;
	}
      }
      chop $line;
      print OUT "$line\n";
    }
  }
  
  close(OUT);
  
}

sub continue { &{ $form->{nextsub} } };

#=========================================
#
# New Import Procedures 
#
#=========================================

#=========================================
sub im_service {
   &im_parts;
}

sub im_parts {

  $form->error($locale->text('Import File missing!')) if ! $form->{data};

  @column_index = qw(partnumber description unit partsgroup newpartsgroup listprice sellprice lastcost rop bin image drawing notes);
  @flds = @column_index;
  push @flds, qw(parts_id partsgroup_id microfiche barcode tarrif_hscode countryorigin toolnumber);
  unshift @column_index, qw(runningnumber ndx);

  $form->{callback} = "$form->{script}?action=import";
  for (qw(type login path)) { $form->{callback} .= "&$_=$form->{$_}" }
  
  &xrefhdr;
  
  IM->parts(\%myconfig, \%$form);

  $column_data{runningnumber} = "&nbsp;";
  $column_data{partnumber} = $locale->text('Number');
  $column_data{description} = $locale->text('Description');
  $column_data{unit} = $locale->text('Unit');
  $column_data{partsgroup} = $locale->text('Group');
  $column_data{listprice} = $locale->text('List Price');
  $column_data{sellprice} = $locale->text('Sell Price');
  $column_data{lastcost} = $locale->text('Last Cost');
  $column_data{rop} = $locale->text('ROP');
  $column_data{bin} = $locale->text('Bin');
  $column_data{image} = $locale->text('Image');
  $column_data{drawing} = $locale->text('Drawing');
  $column_data{notes} = $locale->text('Notes');

  $form->header;
 
  print qq|
<body>

<form method=post action=$form->{script}>

<table width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <td>
      <table width=100%>
        <tr class=listheading>
|;

  for (@column_index) { print "\n<th>$column_data{$_}</th>" }

  print qq|
        </tr>
|;

  for $i (1 .. $form->{rowcount}) {
    
    $j++; $j %= 2;
 
    print qq|
      <tr class=listrow$j>
|;

    $form->{"newpartsgroup_$i"} .= '+' if !($form->{"partsgroup_id_$i"});
    for (@column_index) { $column_data{$_} = qq|<td>$form->{"${_}_$i"}</td>| }

    $column_data{runningnumber} = qq|<td align=right>$i</td>|;
    $column_data{ndx} = qq|<td><input name="ndx_$i" type=checkbox class=checkbox value='1' checked></td>|;

    for (@column_index) { print $column_data{$_} }

    print qq|
	</tr>
|;
    $form->hide_form(map { "${_}_$i" } @flds);
  
  }

  # print total
  for (@column_index) { $column_data{$_} = qq|<td>&nbsp;</td>| }

  print qq|
        <tr class=listtotal>
|;

  for (@column_index) { print "\n$column_data{$_}" }
  
  print qq|
        </tr>
      </table>
    </td>
  </tr>
  <tr>
    <td><hr size=3 noshade></td>
  </tr>

</table>
|;
  for (split / /, $form->{taxaccounts}) { $form->hide_form("IC_tax_$_") };
  $form->hide_form(qw(taxaccounts IC_inventory IC_income IC_expense precision rowcount type login path callback));

  print qq|
<input name=action class=submit type=submit value="|.$locale->text('Import Parts').qq|">
</form>

</body>
</html>
|;

}

#=========================================
sub import_parts {

  my $m = 0;
  my $query;

  $newform = new Form;
  
  my $dbh = $form->dbconnect(\%myconfig);
  for my $i (1 .. $form->{rowcount}) {
    
    if ($form->{"ndx_$i"}) {

      $m++;
      
      if ($form->{"partsgroup_$i"} and !$form->{"partsgroup_id_$i"}){
      	  for (keys %$newform) { delete $newform->{$_} };
	  #Lookup partsgroup id if it is already added by this procedure.
	  $query = qq|SELECT id FROM partsgroup WHERE partsgroup='$form->{"partsgroup_$i"}'|;
	  ($form->{"partsgroup_id_$i"}) = $dbh->selectrow_array($query);
	  if (!$form->{"partsgroup_id_$i"}){
	     $newform->{partsgroup} = $form->{"partsgroup_$i"};
	     PE->save_partsgroup(\%myconfig, \%$newform);
	     ($form->{"partsgroup_id_$i"}) = $dbh->selectrow_array($query);
	  }
      }

      for (keys %$newform) { delete $newform->{$_} };

      if ($form->{"parts_id_$i"}){
         # Load existing part / service information
	 $query = qq|
		SELECT parts.*, 
		c1.accno AS inventory_accno, 
		c2.accno AS income_accno,
		c3.accno AS expense_accno
		FROM parts 
		LEFT JOIN chart c1 ON (c1.id = parts.inventory_accno_id)
		LEFT JOIN chart c2 ON (c2.id = parts.income_accno_id)
		LEFT JOIN chart c3 ON (c3.id = parts.expense_accno_id)
		WHERE parts.id = $form->{"parts_id_$i"}|;
         $sth = $dbh->prepare($query) or $form->dberror($query);
         $sth->execute;
         my $row = $sth->fetchrow_hashref(NAME_lc);
         for (keys %$row) { $newform->{$_} = $row->{$_} }
	 $newform->{IC_inventory} = "$newform->{inventory_accno}--null";
	 $newform->{IC_income} = "$newform->{income_accno}--null";
	 $newform->{IC_expense} = "$newform->{expense_accno}--null";
      }

      $newform->{item} = 'part';
      $newform->{"id"} = $form->{"parts_id_$i"};
      $newform->{"partnumber"} = $form->{"partnumber_$i"};
      $newform->{"description"} = $form->{"description_$i"};
      $newform->{"unit"} = $form->{"unit_$i"};
      $newform->{"partsgroup"} = qq|$form->{"partsgroup_$i"}--$form->{"partsgroup_id_$i"}| if $form->{"partsgroup_id_$i"};
      $newform->{"listprice"} = $form->{"listprice_$i"};
      $newform->{"sellprice"} = $form->{"sellprice_$i"};
      $newform->{"lastcost"} = $form->{"lastcost_$i"};
      $newform->{"rop"} = $form->{"rop_$i"};
      $newform->{"bin"} = $form->{"bin_$i"};
      $newform->{"image"} = $form->{"image_$i"};
      $newform->{"drawing"} = $form->{"drawing_$i"};
      $newform->{"notes"} = $form->{"notes_$i"};
      $newform->{"barcode"} = $form->{"barcode_$i"};
      $newform->{"tarrif_hscode"} = $form->{"tarrif_hscode_$i"};
      $newform->{"countryorigin"} = $form->{"countryorigin_$i"};
      $newform->{"toolnumber"} = $form->{"toolnumber_$i"};
      if (!$form->{"parts_id_$i"}){
	 # Update for new parts / services only
         $newform->{"IC_inventory"} = $form->{"IC_inventory"};
         $newform->{"IC_income"} = $form->{"IC_income"};
         $newform->{"IC_expense"} = $form->{"IC_expense"};
     }
     $newform->{"taxaccounts"} = $form->{"taxaccounts"};
     for (split / /, $form->{taxaccounts}) { $newform->{"IC_tax_$_"} = $form->{"IC_tax_$_"} }
 
      if ($form->{type} eq 'parts'){
         $form->info("${m}. ".$locale->text('Add part ...'));
      } elsif ($form->{type} eq 'service') {
         $form->info("${m}. ".$locale->text('Add service ...'));
      }

      if (IC->save(\%myconfig, \%$newform)) {
	$form->info(qq| $form->{"partnumber_$i"}, $form->{"description_$i"}|);
	$form->info(" ... ".$locale->text('ok')."\n");
      } else {
	$form->error($locale->text('Saving failed!'));
      }
    }
  }
  if ($form->{type} eq 'parts'){
     $form->info('Parts imported');
  } elsif ($form->{type} eq 'service') {
     $form->info('Services imported');
  }
}

#=========================================
sub im_partscustomer {

  $form->error($locale->text('Import File missing!')) if ! $form->{data};
  @column_index = qw(partnumber description customernumber name pricegroup pricebreak sellprice validfrom validto curr);
  @flds = @column_index;
  push @flds, qw(parts_id customer_id pricegroup_id);
  unshift @column_index, qw(runningnumber ndx);

  $form->{callback} = "$form->{script}?action=import";
  for (qw(type login path)) { $form->{callback} .= "&$_=$form->{$_}" }
  
  &xrefhdr;
  
  IM->partscustomer(\%myconfig, \%$form);

  $column_data{runningnumber} = "&nbsp;";
  $column_data{partnumber} = $locale->text('Part Number');
  $column_data{description} = $locale->text('Description');
  $column_data{customernumber} = $locale->text('Customer Number');
  $column_data{name} = $locale->text('Customer Name');
  $column_data{pricegroup} = $locale->text('Price Group');
  $column_data{pricebreak} = $locale->text('Price Break');
  $column_data{sellprice} = $locale->text('Price');
  $column_data{validfrom} = $locale->text('From');
  $column_data{validto} = $locale->text('To');
  $column_data{curr} = $locale->text('Curr');

  $form->header;
 
  print qq|<body><form method=post action=$form->{script}>|;
  print qq|<table width=100%>|;
  print qq|<tr><th class=listtop>$form->{title}</th></tr>|;
  print qq|<tr height="5"></tr><tr><td><table width=100%><tr class=listheading>|;
  for (@column_index) { print "\n<th>$column_data{$_}</th>" }
  print qq|</tr>|;

  for $i (1 .. $form->{rowcount}) {
    
    $j++; $j %= 2;
 
    print qq|<tr class=listrow$j>|;
    for (@column_index) { $column_data{$_} = qq|<td>$form->{"${_}_$i"}</td>| }

    $column_data{runningnumber} = qq|<td align=right>$i</td>|;
    if ($form->{"parts_id_$i"}){ # and ($form->{"customer_id_$i"} or $form->{"pricegroup_id_$i"})){
       $column_data{ndx} = qq|<td><input name="ndx_$i" type=checkbox class=checkbox value='1' checked></td>|;
    } else {
       $column_data{ndx} = qq|<td>&nbsp;</td>|;
    }

    for (@column_index) { print $column_data{$_} }

    print qq|</tr>|;
    $form->hide_form(map { "${_}_$i" } @flds);
  }

  # print total
  for (@column_index) { $column_data{$_} = qq|<td>&nbsp;</td>| }
  print qq|<tr class=listtotal>|;
  for (@column_index) { print "\n$column_data{$_}" }
  print qq|</tr></table></td></tr><tr><td><hr size=3 noshade></td></tr></table>|;
  $form->hide_form(qw(precision rowcount type login path callback));

  print qq|<input name=action class=submit type=submit value="|.
	$locale->text('Import Parts Customers').qq|">
	</form></body></html>
  |;

}

#=========================================
sub import_parts_customers {
  my $m = 0;
  my $dbh = $form->dbconnect(\%myconfig);
  for my $i (1 .. $form->{rowcount}) {
    if ($form->{"ndx_$i"}) {
      $m++;

      if ($form->{"validfrom_$i"}){
	$form->{"validfrom_$i"} = qq|'$form->{"validfrom_$i"}'|;
      } else {
        $form->{"validfrom_$i"} = 'NULL'; 
      }
      if ($form->{"validto_$i"}){
	$form->{"validto_$i"} = qq|'$form->{"validto_$i"}'|;
      } else {
        $form->{"validto_$i"} = 'NULL'; 
      }

      $form->{"customer_id_$i"} *= 1;
      $form->{"pricegroup_id_$i"} *= 1;
      $form->{"pricebreak_$i"} *= 1;
      $form->{"sellprice_$i"} *= 1;
 
      $query = qq|INSERT INTO partscustomer(
			parts_id, customer_id, 
			pricegroup_id, pricebreak, 
			sellprice, validfrom, 
			validto, curr) 
		VALUES ($form->{"parts_id_$i"}, $form->{"customer_id_$i"},
			$form->{"pricegroup_id_$i"}, $form->{"pricebreak_$i"},
			$form->{"sellprice_$i"}, $form->{"validfrom_$i"},
			$form->{"validto_$i"}, '$form->{"curr_$i"}'
		)|;
      $dbh->do($query) || $form->dberror($query);
      $form->info("${m}. ".$locale->text('Add part ...'));
      $form->info(qq| $form->{"partnumber_$i"}, $form->{"description_$i"}|);
      $form->info(" ... ".$locale->text('ok')."\n");
    }
  }
  $form->info('Parts customers imported');
}

#=========================================
sub im_partsvendor {

  $form->error($locale->text('Import File missing!')) if ! $form->{data};
  @column_index = qw(partnumber description vendornumber name vendorpartnumber lastcost curr leadtime);
  @flds = @column_index;
  push @flds, qw(parts_id vendor_id);
  unshift @column_index, qw(runningnumber ndx);

  $form->{callback} = "$form->{script}?action=import";
  for (qw(type login path)) { $form->{callback} .= "&$_=$form->{$_}" }
  
  &xrefhdr;
  
  IM->partsvendor(\%myconfig, \%$form);

  $column_data{runningnumber} = "&nbsp;";
  $column_data{partnumber} = $locale->text('Part Number');
  $column_data{description} = $locale->text('Description');
  $column_data{vendornumber} = $locale->text('Vendor Number');
  $column_data{name} = $locale->text('Vendor Name');
  $column_data{vendorpartnumber} = $locale->text('Vendor Part Number');
  $column_data{lastcost} = $locale->text('Cost');
  $column_data{curr} = $locale->text('Curr');
  $column_data{leadtime} = $locale->text('Leadtime');

  $form->header;
 
  print qq|<body><form method=post action=$form->{script}>|;
  print qq|<table width=100%>|;
  print qq|<tr><th class=listtop>$form->{title}</th></tr>|;
  print qq|<tr height="5"></tr><tr><td><table width=100%><tr class=listheading>|;
  for (@column_index) { print "\n<th>$column_data{$_}</th>" }
  print qq|</tr>|;

  for $i (1 .. $form->{rowcount}) {
    
    $j++; $j %= 2;
 
    print qq|<tr class=listrow$j>|;
    for (@column_index) { $column_data{$_} = qq|<td>$form->{"${_}_$i"}</td>| }

    $column_data{runningnumber} = qq|<td align=right>$i</td>|;
    if ($form->{"parts_id_$i"} and $form->{"vendor_id_$i"}){
       $column_data{ndx} = qq|<td><input name="ndx_$i" type=checkbox class=checkbox value='1' checked></td>|;
    } else {
       $column_data{ndx} = qq|<td>&nbsp;</td>|;
    }

    for (@column_index) { print $column_data{$_} }

    print qq|</tr>|;
    $form->hide_form(map { "${_}_$i" } @flds);
  }

  # print total
  for (@column_index) { $column_data{$_} = qq|<td>&nbsp;</td>| }
  print qq|<tr class=listtotal>|;
  for (@column_index) { print "\n$column_data{$_}" }
  print qq|</tr></table></td></tr><tr><td><hr size=3 noshade></td></tr></table>|;
  $form->hide_form(qw(precision rowcount type login path callback));

  print qq|<input name=action class=submit type=submit value="|.
	$locale->text('Import Parts Vendors').qq|">
	</form></body></html>
  |;

}

#=========================================
sub import_parts_vendors {
  my $m = 0;
  my $dbh = $form->dbconnect(\%myconfig);
  for my $i (1 .. $form->{rowcount}) {
    if ($form->{"ndx_$i"}) {
      $m++;

      $form->{"vendor_id_$i"} *= 1;
      $form->{"leadtime_$i"} *= 1;
      $form->{"lastcost_$i"} *= 1;

      $query = qq|INSERT INTO partsvendor(
			vendor_id, parts_id, 
			partnumber, leadtime, 
			lastcost, curr)
		VALUES ($form->{"vendor_id_$i"}, $form->{"parts_id_$i"}, 
			'$form->{"vendorpartnumber_$i"}', $form->{"leadtime_$i"},
			$form->{"lastcost_$i"}, '$form->{"curr_$i"}'
		)|;
      $dbh->do($query) || $form->dberror($query);
      $form->info("${m}. ".$locale->text('Add part ...'));
      $form->info(qq| $form->{"partnumber_$i"}, $form->{"description_$i"}|);
      $form->info(" ... ".$locale->text('ok')."\n");
    }
  }
  $form->info('Parts vendors imported');
}


#=========================================
sub im_vc {

  $form->error($locale->text('Import File missing!')) if ! $form->{data};

  @column_index = qw(ndx);
  push @column_index, "$form->{db}number";
  push @column_index, qw(id name salutation firstname lastname contacttitle phone fax email notes address1 address2 city state zipcode country);
  @flds = @column_index;
  push @flds, qw(cc bcc business_id taxnumber sic_code discount creditlimit employee_id language_code pricegroup_id curr cashdiscount threshold paymentmethod_id remittancevoucher contactid typeofcontact saluation occupation terms startdate mobile gender addressid shiptoname shiptoaddress1 shiptoaddress2 shiptocity shiptostate shiptozipcode shiptocountry shiptophone shiptofax shiptoemail bankname iban bic bankaddress1 bankaddress2 bankcity bankstate bankzipcode bankcountry dcn rvc membernumber);
  unshift @column_index, "runningnumber";

  $form->{callback} = "$form->{script}?action=import";
  for (qw(type login path)) { $form->{callback} .= "&$_=$form->{$_}" }
  
  &xrefhdr;
  
  IM->vc(\%myconfig, \%$form);

  $column_data{runningnumber} = "&nbsp;";
  $column_data{id} = $locale->text('ID');
  $column_data{"$form->{db}number"} = $locale->text('Number');
  $column_data{name} = $locale->text('Name');
  $column_data{firstname} = $locale->text('First Name');
  $column_data{lastname} = $locale->text('Last Name');
  $column_data{contacttitle} = $locale->text('Contact Title');
  $column_data{phone} = $locale->text('Phone');
  $column_data{fax} = $locale->text('Fax');
  $column_data{email} = $locale->text('Email');
  $column_data{notes} = $locale->text('notes');
  $column_data{address1} = $locale->text('Address1');
  $column_data{address2} = $locale->text('Address2');
  $column_data{city} = $locale->text('City');
  $column_data{state} = $locale->text('State');
  $column_data{zipcode} = $locale->text('Zip');
  $column_data{country} = $locale->text('Country');

  $form->header;
 
  print qq|
<body>

<form method=post action=$form->{script}>

<table width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <td>
      <table width=100%>
        <tr class=listheading>
|;

  for (@column_index) { print "\n<th>$column_data{$_}</th>" }

  print qq|
        </tr>
|;

  for $i (1 .. $form->{rowcount}) {
    
    $j++; $j %= 2;
 
    print qq|
      <tr class=listrow$j>
|;

    for (@column_index) { $column_data{$_} = qq|<td>$form->{"${_}_$i"}</td>| }

    $form->{"ndx_$i"} = '1';
    $column_data{runningnumber} = qq|<td align=right>$i</td>|;
    $column_data{ndx} = qq|<td><input name="ndx_$i" type=checkbox class=checkbox value='1' checked></td>|;

    for (@column_index) { print $column_data{$_} }

    print qq|
	</tr>
|;
    $form->hide_form(map { "${_}_$i" } @flds);
  
  }

  # print total
  for (@column_index) { $column_data{$_} = qq|<td>&nbsp;</td>| }

  print qq|
        <tr class=listtotal>
|;

  for (@column_index) { print "\n$column_data{$_}" }
  
  print qq|
        </tr>
      </table>
    </td>
  </tr>
  <tr>
    <td><hr size=3 noshade></td>
  </tr>

</table>
|;

  for (split / /, $form->{taxaccounts}) { $form->hide_form("tax_$_") }
  $form->{nextsub} = 'import_vc';
  $form->hide_form(qw(arap_accno payment_accno taxaccounts taxincluded precision rowcount nextsub db type login path callback));

  print qq|
<input name=action class=submit type=submit value="|.$locale->text('Continue').qq|">
</form>

</body>
</html>
|;

}

sub import_vc {

  my $m = 0;

  $newform = new Form;
  
  for my $i (1 .. $form->{rowcount}) {
    
    if ($form->{"ndx_$i"}) {

      $m++;
      
      push @flds, "$form->{db}number";
      push @flds, qw(id name salutation firstname lastname contacttitle phone fax email notes address1 address2 city state zipcode country);
      push @flds, qw(cc bcc business_id taxnumber sic_code discount creditlimit employee_id language_code pricegroup_id curr cashdiscount threshold paymentmethod_id remittancevoucher contactid typeofcontact saluation occupation terms startdate mobile gender addressid shiptoname shiptoaddress1 shiptoaddress2 shiptocity shiptostate shiptozipcode shiptocountry shiptophone shiptofax shiptoemail bankname iban bic bankaddress1 bankaddress2 bankcity bankstate bankzipcode bankcountry dcn rvc membernumber);

      for (keys %$newform) { delete $newform->{$_} };

      for (@flds){ $newform->{$_} = $form->{"${_}_$i"}; }

      for (split / /, $form->{taxaccounts}){ $newform->{"tax_$_"} = $form->{"tax_$_"}; }

      $newform->{db} = $form->{db};
      $newform->{typeofcontact} = 'company' if $newform->{typeofcontact} ne 'person';
      $newform->{taxaccounts} = $form->{taxaccounts};
      $newform->{taxincluded} = $form->{taxincluded};
      $newform->{arap_accno} = $form->{arap_accno};
      $newform->{payment_accno} = $form->{payment_accno};

      $newform->{id} = $form->{"id_$i"};

      if ($newform->{id}){
         $form->info("${m}. ".$locale->text("Update $form->{db} ..."));
      } else {
         $form->info("${m}. ".$locale->text("Add $form->{db} ..."));
      }

      if (CT->save(\%myconfig, \%$newform)) {
	$form->info(qq| $form->{"$form->{db}number_$i"}, $form->{"name_$i"}|);
	$form->info(" ... ".$locale->text('ok')."\n");
      } else {
	$form->error($locale->text('Save failed!'));
      }
    }
  }

}


sub im_account {

  $form->error($locale->text('Import File missing!')) if ! $form->{data};

  @column_index = qw(accno description charttype category link);
  @flds = @column_index;
  unshift @column_index, qw(runningnumber ndx);

  $form->{callback} = "$form->{script}?action=import";
  for (qw(type login path)) { $form->{callback} .= "&$_=$form->{$_}" }
  
  &xrefhdr;
  
  IM->accounts(\%myconfig, \%$form);

  $column_data{runningnumber} = "&nbsp;";
  $column_data{accno} = $locale->text('Account Number');
  $column_data{description} = $locale->text('Description');
  $column_data{charttype} = $locale->text('Account Type');
  $column_data{category} = $locale->text('Category');
  $column_data{"link"} = $locale->text('Link');

  $form->header;
 
  print qq|
<body>

<form method=post action=$form->{script}>

<table width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <td>
      <table width=100%>
        <tr class=listheading>
|;

  for (@column_index) { print "\n<th>$column_data{$_}</th>" }

  print qq|
        </tr>
|;

  for $i (1 .. $form->{rowcount}) {
    
    $j++; $j %= 2;
 
    print qq|
      <tr class=listrow$j>
|;

    for (@column_index) { $column_data{$_} = qq|<td>$form->{"${_}_$i"}</td>| }

    $column_data{runningnumber} = qq|<td align=right>$i</td>|;
    if ($form->{"ndx_$i"}){
       $column_data{ndx} = qq|<td>&nbsp;</td>|;
    } else {
       $column_data{ndx} = qq|<td><input name="ndx_$i" type=checkbox class=checkbox value='Y' checked></td>|;
    }

    for (@column_index) { print $column_data{$_} }

    print qq|
	</tr>
|;
    $form->hide_form(map { "${_}_$i" } @flds);
  
  }

  # print total
  for (@column_index) { $column_data{$_} = qq|<td>&nbsp;</td>| }

  print qq|
        <tr class=listtotal>
|;

  for (@column_index) { print "\n$column_data{$_}" }
  
  print qq|
        </tr>
      </table>
    </td>
  </tr>
  <tr>
    <td><hr size=3 noshade></td>
  </tr>

</table>
|;
  
  $form->hide_form(qw(precision rowcount type login path callback));

  print qq|
<input name=action class=submit type=submit value="|.$locale->text('Import Accounts').qq|">
</form>

</body>
</html>
|;

}

sub import_accounts {

  my $m = 0;

  $newform = new Form;
 
  for my $i (1 .. $form->{rowcount}) {
    
    if ($form->{"ndx_$i"}) {

      $m++;
      
      for (keys %$newform) { delete $newform->{$_} };

      $newform->{item} = 'part';
      $newform->{"accno"} = $form->{"accno_$i"};
      $newform->{"description"} = $form->{"description_$i"};
      $newform->{"charttype"} = $form->{"charttype_$i"};
      $newform->{"category"} = $form->{"category_$i"};
      $newform->{"link"} = $form->{"link_$i"};
      
      $form->info("${m}. ".$locale->text('Add part ...'));

      if (AM->save_account(\%myconfig, \%$newform)) {
	$form->info(qq| $form->{"account_$i"}, $form->{"description_$i"}|);
	$form->info(" ... ".$locale->text('ok')."\n");
      } else {
	$form->error($locale->text('Saving failed!'));
      }
    }
  }
}

sub im_gl {

  $form->error($locale->text('Import File missing!')) if ! $form->{data};

  @column_index = qw(reference department department_id description transdate notes currency exchangerate accno accdescription debit credit source memo);
  @flds = @column_index;
  unshift @column_index, qw(runningnumber ndx);

  $form->{callback} = "$form->{script}?action=import";
  for (qw(type login path)) { $form->{callback} .= "&$_=$form->{$_}" }
  
  &xrefhdr;
  
  IM->gl(\%myconfig, \%$form);

  $column_data{runningnumber} = "&nbsp;";
  $column_data{reference} = $locale->text('Reference');
  $column_data{department} = $locale->text('Department');
  $column_data{description} = $locale->text('Description');
  $column_data{transdate} = $locale->text('Date');
  $column_data{notes} = $locale->text('Notes');
  $column_data{currency} = $locale->text('Currency');
  $column_data{exchangerate} = $locale->text('Exchange Rate');
  $column_data{accno} = $locale->text('Account');
  $column_data{accdescription} = $locale->text('Account Description');
  $column_data{debit} = $locale->text('Debit');
  $column_data{credit} = $locale->text('Credit');
  $column_data{source} = $locale->text('Source');
  $column_data{memo} = $locale->text('Memo');

  $form->header;
 
  print qq|
<body>

<form method=post action=$form->{script}>

<table width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <td>
      <table width=100%>
        <tr class=listheading>
|;

  for (@column_index) { print "\n<th>$column_data{$_}</th>" }

  print qq|
        </tr>
|;
  my $debit_total, $credit_total;
  for $i (1 .. $form->{rowcount}) {
    
    $j++; $j %= 2;
 
    print qq|
      <tr class=listrow$j>
|;

    for (@column_index) { $column_data{$_} = qq|<td>$form->{"${_}_$i"}</td>| }
    $column_data{debit} = qq|<td>|. $form->format_amount(\%myconfig, $form->{"debit_$i"}, $form->{precision}) . qq|</td>|;
    $column_data{credit} = qq|<td>| . $form->format_amount(\%myconfig, $form->{"credit_$i"}, $form->{precision}) . qq|</td>|;

    $column_data{runningnumber} = qq|<td align=right>$i</td>|;
    if ($form->{"accdescription_$i"} eq '*****'){
       $column_data{ndx} = qq|<td>&nbsp;</td>|;
    } else {
       $column_data{ndx} = qq|<td><input name="ndx_$i" type=checkbox class=checkbox value='Y' checked></td>|;
       $debit_total += $form->{"debit_$i"};
       $credit_total += $form->{"credit_$i"};
    }
    for (@column_index) { print $column_data{$_} }

    print qq|
	</tr>
|;
    $form->hide_form(map { "${_}_$i" } @flds);
  }
  # print total
  for (@column_index) { $column_data{$_} = qq|<td>&nbsp;</td>| }
  $column_data{debit} = qq|<td>|. $form->format_amount(\%myconfig, $debit_total, $form->{precision}) . qq|</td>|;
  $column_data{credit} = qq|<td>| . $form->format_amount(\%myconfig, $credit_total, $form->{precision}) . qq|</td>|;

  print qq|
        <tr class=listtotal>
|;

  for (@column_index) { print "\n$column_data{$_}" }
  
  print qq|
        </tr>
      </table>
    </td>
  </tr>
  <tr>
    <td><hr size=3 noshade></td>
  </tr>

</table>
|;
  
  $form->hide_form(qw(precision rowcount type login path callback));

  # Fixes rounding problems nsamuelsson 4.5.2012
  $debit_total = $form->round_amount($debit_total, 2);
  $credit_total = $form->round_amount($credit_total, 2);
  # End, Fixes rounding problems nsamuelsson 4.5.2012
  
  if ($debit_total eq $credit_total) {
    print qq|
<input name=action class=submit type=submit value="| . $locale->text('Import GL') . qq|">|;
  } else {
   $form->error($locale->text('Debits and credits are not equal. Cannot import') );
  }

print qq|
</form>

</body>
</html>
|;

}

sub import_gl {

  my $m = 0;

  $newform = new Form;
  my $reference = 'null';
  my $linenum = 1;

  for my $i (1 .. $form->{rowcount}) {
    if ($form->{"ndx_$i"}) {

      $m++;
      if ($form->{"reference_$i"} ne $reference){
	# Post if it is a new transaction or last transaction.
	if ($reference ne 'null'){
	   $newform->{rowcount} = $linenum;
      	   $form->info("${m}. ".$locale->text('Posting gl transaction ...'));
      	   if (GL->post_transaction(\%myconfig, \%$newform)) {
		$form->info(qq| $reference|);
		$form->info(" ... ".$locale->text('ok')."\n");
      		for (keys %$newform) { delete $newform->{$_} };
      	   } else {
		$form->error($locale->text('Posting failed!'));
      	   }
	   # start new transaction
	   $linenum = 1;
	}
	$reference = $form->{"reference_$i"};
      }
      @curr = split /:/, $form->{currencies};
      $form->{defaultcurrency} = $curr[0];
      chomp $form->{defaultcurrency};
      
      $newform->{reference} = $form->{"reference_$i"};
      $newform->{transdate} = $form->{"transdate_$i"};
      $newform->{department} = qq|$form->{"department_$i"}--$form->{"department_id_$i"}|;
      $newform->{description} = $form->{"description_$i"};
      $newform->{currency} = $form->{"currency_$i"};
      $newform->{oldcurrency} = $form->{"currency_$i"};
      $newform->{exchangerate} = $form->{"exchangerate_$i"};
      $newform->{notes} = $form->{"notes_$i"};
      $newform->{"accno_$linenum"} = qq|$form->{"accno_$i"}--$form->{"accdescription_$i"}|;
      $newform->{"debit_$linenum"} = $form->{"debit_$i"};
      $newform->{"credit_$linenum"} = $form->{"credit_$i"};
      $newform->{"source_$linenum"} = $form->{"source_$i"};
      $newform->{"memo_$linenum"} = $form->{"memo_$i"};
      $linenum++;
    }
  }

  # Now post last transaction. (Code duplicated from above loop)
  $newform->{rowcount} = $linenum;
  $form->info("${m}. ".$locale->text('Posting last gl transaction ...'));
  if (GL->post_transaction(\%myconfig, \%$newform)) {
     $form->info(qq| $reference|);
     $form->info(" ... ".$locale->text('ok')."\n");
     for (keys %$newform) { delete $newform->{$_} };
  } else {
     $form->error($locale->text('Posting failed!'));
  }
}

sub im_transactions {

  $form->error($locale->text('Import File missing!')) if ! $form->{data};

  if ($form->{vc} eq 'customer'){
    @column_index = qw(ndx invnumber customernumber name transdate account account_description amount description notes source memo);
  } else {
    @column_index = qw(ndx invnumber vendornumber name transdate account account_description amount description notes source memo);
  }
  @flds = @column_index;
  push @flds, qw(vendor_id customer_id employee employee_id);
  unshift @column_index, "runningnumber";

  $form->{callback} = "$form->{script}?action=import";
  for (qw(type login path)) { $form->{callback} .= "&$_=$form->{$_}" }

  &xrefhdr;

  ($form->{arapaccount}) = split /--/, $form->{arapaccount};
  ($form->{incomeaccount}) = split /--/, $form->{incomeaccount};
  ($form->{expenseaccount}) = split /--/, $form->{expenseaccount};
  ($form->{paymentaccount}) = split /--/, $form->{paymentaccount};

  IM->transactions(\%myconfig, \%$form);

  $column_data{runningnumber} = "&nbsp;";
  $column_data{invnumber} = $locale->text('Invoice Number');
  $column_data{"$form->{vc}number"} = $locale->text('Number');
  $column_data{name} = $locale->text('Name');
  $column_data{transdate} = $locale->text('Invoice Date');
  $column_data{account} = $locale->text('Account');
  $column_data{amount} = $locale->text('Amount');

  $form->header;
 
  print qq|
<body>

<form method=post action=$form->{script}>

<table width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <td>
      <table width=100%>
        <tr class=listheading>
|;

  for (@column_index) { print "\n<th>$column_data{$_}</th>" }

  print qq|
        </tr>
|;

  my $total_amount = 0;
  for $i (1 .. $form->{rowcount}) {
    
    $j++; $j %= 2;
 
    print qq|
      <tr class=listrow$j>
|;

    for (@column_index) { $column_data{$_} = qq|<td>$form->{"${_}_$i"}</td>| }
    $column_data{amount} = qq|<td align=right>|.$form->format_amount(\%myconfig, $form->{"amount_$i"}, $form->{precision}).qq|</td>|;
    $total_amount += $form->{"amount_$i"};

    $form->{"ndx_$i"} = '1';
    $column_data{runningnumber} = qq|<td align=right>$i</td>|;
    $column_data{ndx} = qq|<td><input name="ndx_$i" type=checkbox class=checkbox value='1' checked></td>|;

    for (@column_index) { print $column_data{$_} }

    print qq|
	</tr>
|;
    $form->hide_form(map { "${_}_$i" } @flds);
  }

  # print total
  for (@column_index) { $column_data{$_} = qq|<td>&nbsp;</td>| }
  $column_data{amount} = qq|<td align=right>|.$form->format_amount(\%myconfig, $total_amount, $form->{precision}).qq|</td>|;

  print qq|
        <tr class=listtotal>
|;

  for (@column_index) { print "\n$column_data{$_}" }
  
  print qq|
        </tr>
      </table>
    </td>
  </tr>
  <tr>
    <td><hr size=3 noshade></td>
  </tr>

</table>
|;
  
  $form->hide_form(qw(markpaid ARAP vc currency arapaccount incomeaccount paymentaccount expenseaccount precision rowcount type login path callback));

  print qq|
<input name=action class=submit type=submit value="|.$locale->text('Import Transactions').qq|">
</form>

</body>
</html>
|;

}

sub import_transactions {

  my $m = 0;
  $newform = new Form;
 
  $newform->{invnumber} = 'null';
  my $linenum = 1;
  for my $i (1 .. $form->{rowcount}) {
    if ($form->{"ndx_$i"}) {
      $m++;
      if ($newform->{invnumber} ne $form->{"invnumber_$i"}){
         if ($newform->{invnumber} ne 'null'){ 
            $form->info("${m}. ".$locale->text('Add transaction ...'));
            if (AA->post_transaction(\%myconfig, \%$newform)) {
 	      $form->info(qq| $newform->{invnumber}, $form->{"$form->{vc}number_$i"}|);
	      $form->info(" ... ".$locale->text('ok')."\n");
            } else {
	      $form->error($locale->text('Posting failed!'));
            }
         }
         for (keys %$newform) { delete $newform->{$_} }
	 $newform->{vc} = $form->{vc};
	 $newform->{type} = 'transaction';
         $newform->{invnumber} = $form->{"invnumber_$i"};
         $newform->{$form->{vc}} = qq|$form->{"name_$i"}--$form->{"$form->{vc}_id_$i"}|;
         $newform->{"old$form->{vc}"} = $newform->{$form->{vc}};
         $newform->{"$form->{vc}_id"} = $form->{"$form->{vc}_id_$i"};
         $newform->{$form->{ARAP}}= $form->{arapaccount};
         $newform->{currency} = $form->{currency};
         $newform->{defaultcurrency} = $form->{currency};
         $newform->{employee}= qq|$form->{"employee_$i"}--$form->{"employee_id_$i"}|;
	 $linenum = 0;
      }
      $linenum += 1;
      $newform->{transdate} = $form->{"transdate_$i"};
      $newform->{duedate} = $form->{"transdate_$i"};
      $newform->{notes} = $form->{"notes_$i"};

      $newform->{"amount_$linenum"} = $form->{"amount_$i"};
      $newform->{"description_$linenum"} = $form->{"description_$i"};
      $newform->{"$form->{ARAP}_amount_$linenum"} = $form->{"account_$i"};
      $newform->{oldinvtotal} = $form->{"amount_$i"};
      $newform->{rowcount} = $linenum + 1;
    }
  }
  # Post last transaction
  $form->info("${m}. ".$locale->text('Add transaction ...'));
  if (AA->post_transaction(\%myconfig, \%$newform)) {
     $form->info(qq| $newform->{invnumber}, $form->{"$form->{vc}number_$i"}|);
     $form->info(" ... ".$locale->text('ok')."\n");
  } else {
     $form->error($locale->text('Posting failed!'));
  }
}


# EOF

