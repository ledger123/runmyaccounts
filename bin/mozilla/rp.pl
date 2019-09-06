#=====================================================================
# SQL-Ledger ERP
# Copyright (c) 2006
#
#  Author: DWS Systems Inc.
#     Web: http://www.sql-ledger.com
#
#======================================================================
#
# module for preparing Income Statement and Balance Sheet
#
#======================================================================

require "$form->{path}/arap.pl";

use SL::PE;
use SL::RP;
use SL::CSV;
use IO::File;
use POSIX qw(tmpnam);

1;

# end of main

# this is for our long dates
# $locale->text('January')
# $locale->text('February')
# $locale->text('March')
# $locale->text('April')
# $locale->text('May ')
# $locale->text('June')
# $locale->text('July')
# $locale->text('August')
# $locale->text('September')
# $locale->text('October')
# $locale->text('November')
# $locale->text('December')

# this is for our short month
# $locale->text('Jan')
# $locale->text('Feb')
# $locale->text('Mar')
# $locale->text('Apr')
# $locale->text('May')
# $locale->text('Jun')
# $locale->text('Jul')
# $locale->text('Aug')
# $locale->text('Sep')
# $locale->text('Oct')
# $locale->text('Nov')
# $locale->text('Dec')

# $locale->text('Balance Sheet')
# $locale->text('Income Statement')
# $locale->text('Trial Balance')
# $locale->text('AR Aging')
# $locale->text('AP Aging')
# $locale->text('Tax collected')
# $locale->text('Tax paid')
# $locale->text('Receipts')
# $locale->text('Payments')
# $locale->text('Project Transactions')
# $locale->text('Non-taxable Sales')
# $locale->text('Non-taxable Purchases')

sub report {

	%report = (
		balance_sheet    => { title => 'Balance Sheet' },
		income_statement => { title => 'Income Statement' },
		trial_balance    => { title => 'Trial Balance' },
		ar_aging         => { title => 'AR Aging', vc => 'customer' },
		ap_aging         => { title => 'AP Aging', vc => 'vendor' },
		tax_collected    => { title => 'Tax collected', vc => 'customer' },
		tax_paid         => { title => 'Tax paid' },
		nontaxable_sales => { title => 'Non-taxable Sales', vc => 'customer' },
		nontaxable_purchases => { title => 'Non-taxable Purchases' },
		receipts             => { title => 'Receipts', vc => 'customer' },
		payments             => { title => 'Payments' },
		projects             => { title => 'Project Transactions' },
		reminder             => { title => 'Reminder', vc => 'customer' },
	);

	$form->{title} = $locale->text( $report{ $form->{report} }->{title} );

	$form->{nextsub} = "generate_$form->{report}";

	$gifi = qq|
<tr>
  <th align=right>| . $locale->text('Accounts') . qq|</th>
  <td><input name=accounttype class=radio type=radio value=standard checked> |
	  . $locale->text('Standard') . qq|

      <input name=accounttype class=radio type=radio value=gifi> |
	  . $locale->text('GIFI') . qq|
  </td>
</tr>
|;

	RP->create_links( \%myconfig, \%$form, $report{ $form->{report} }->{vc} );

	# departments
	if ( @{ $form->{all_department} } ) {
		if ( $myconfig{department_id} and $myconfig{role} eq 'user' ) {
			$form->{selectdepartment} =
qq|<option value="$myconfig{department}--$myconfig{department_id}">$myconfig{department}\n|;
		}
		else {
			$form->{selectdepartment} = "<option>\n";
			for ( @{ $form->{all_department} } ) {
				$form->{selectdepartment} .=
				    qq|<option value="|
				  . $form->quote( $_->{description} )
				  . qq|--$_->{id}">$_->{description}\n|;
			}
		}
	}

	$department = qq|
	<tr>
	  <th align=right nowrap>| . $locale->text('Department') . qq|</th>
	  <td colspan=3><select name=department>$form->{selectdepartment}</select></td>
	</tr>
| if $form->{selectdepartment};

	if ( @{ $form->{all_years} } ) {

		# accounting years
		$selectaccountingyear = "<option>\n";
		for ( @{ $form->{all_years} } ) {
			$selectaccountingyear .= qq|<option>$_\n|;
		}
		$selectaccountingmonth = "<option>\n";
		for ( sort keys %{ $form->{all_month} } ) {
			$selectaccountingmonth .= qq|<option value=$_>|
			  . $locale->text( $form->{all_month}{$_} ) . qq|\n|;
		}

		$selectfrom = qq|
        <tr>
	  <th align=right>| . $locale->text('Period') . qq|</th>
	  <td colspan=3>
	  <select name=month>$selectaccountingmonth</select>
	  <select name=year>$selectaccountingyear</select>
	  <input name=interval class=radio type=radio value=0 checked>&nbsp;|
		  . $locale->text('Current') . qq|
	  <input name=interval class=radio type=radio value=1>&nbsp;|
		  . $locale->text('Month') . qq|
	  <input name=interval class=radio type=radio value=3>&nbsp;|
		  . $locale->text('Quarter') . qq|
	  <input name=interval class=radio type=radio value=12>&nbsp;|
		  . $locale->text('Year') . qq|
	  </td>
	</tr>
|;

		$selectto = qq|
        <tr>
	  <th align=right></th>
	  <td>
	  <select name=month>$selectaccountingmonth</select>
	  <select name=year>$selectaccountingyear</select>
	  </td>
	</tr>
|;
	}

	$summary = qq|
	<tr>
	  <th></th>
	  <td><input name=summary type=radio class=radio value=1 checked> |
	  . $locale->text('Summary') . qq|
	  <input name=summary type=radio class=radio value=0> |
	  . $locale->text('Detail') . qq|
	  </td>
	</tr>
|;

	# projects
	if ( @{ $form->{all_project} } ) {
		$form->{selectproject} = "<option>\n";
		for ( @{ $form->{all_project} } ) {
			$form->{selectproject} .=
			    qq|<option value="|
			  . $form->quote( $_->{projectnumber} )
			  . qq|--$_->{id}">$_->{projectnumber}\n|;
		}

		$project = qq|
	<tr>
	  <th align=right nowrap>| . $locale->text('Project') . qq|</th>
	  <td colspan=3><select name=projectnumber>$form->{selectproject}</select></td>
	</tr>|;

	}

	if ( @{ $form->{all_language} } ) {
		$form->{language_code}  = $myconfig{countrycode};
		$form->{selectlanguage} = "\n";
		for ( @{ $form->{all_language} } ) {
			$form->{selectlanguage} .= qq|$_->{code}--$_->{description}\n|;
		}

		$lang = qq|
	<tr>
	  <th align=right nowrap>| . $locale->text('Language') . qq|</th>
	  <td colspan=3><select name=language_code>|
		  . $form->select_option(
			$form->{selectlanguage},
			$form->{language_code},
			undef, 1
		  )
		  . qq|</select></td>
	</tr>|;

	}

	$form->{decimalplaces} = $form->{precision};

	$method{accrual} = "checked" if $form->{method} eq 'accrual';
	$method{cash}    = "checked" if $form->{method} eq 'cash';

	if (   $form->{report} eq 'balance_sheet'
		|| $form->{report} eq 'income_statement' )
	{
		$form->{currencies} = $form->get_currencies( undef, \%myconfig );

		if ( $form->{currencies} ) {
			@curr = split /:/, $form->{currencies};
			$form->{defaultcurrency} = $curr[0];
			for (@curr) { $form->{selectcurrency} .= "$_\n" }

			$curr = qq|
            <input type=hidden name=fx_transaction value=1>
          <tr>
	    <th align=right>| . $locale->text('Currency') . qq|</th>
	    <td><select name=currency>|
			  . $form->select_option( $form->{selectcurrency},
				$form->{defaultcurrency} )
			  . qq|</select></td>
	  </tr>|
			  . $form->hide_form(defaultcurrency);
		}
	}

	$method = qq|
	<tr>
	  <th align=right>| . $locale->text('Method') . qq|</th>
	  <td colspan=3><input name=method class=radio type=radio value=accrual $method{accrual}>&nbsp;|
	  . $locale->text('Accrual') . qq|
	  &nbsp;<input name=method class=radio type=radio value=cash $method{cash}>&nbsp;|
	  . $locale->text('Cash')
	  . qq|</td>
	</tr>
|;

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
      <table>
      $department
|;

	if ( $form->{report} eq "projects" ) {

		print qq|
        $project
        <tr>
	  <th align=right>| . $locale->text('From') . qq|</th>
	  <td colspan=3><input name=fromdate size=11 class=date title="$myconfig{dateformat}" onChange="validateDate(this)" value=$form->{fromdate}> <b>|
		  . $locale->text('To')
		  . qq|</b> <input name=todate size=11 class=date title="$myconfig{dateformat}" onChange="validateDate(this)"></td>
	</tr>
	$selectfrom
      </table>
    </td>
  </tr>
  <tr>
    <td>
      <table>
        <tr>
          <th align=right nowrap>|.$locale->text('Include in Report').qq|</th>
          <td><input name=l_heading class=checkbox type=checkbox value=Y>&nbsp;|.$locale->text('Heading').qq|
             <input name=l_subtotal class=checkbox type=checkbox value=Y>&nbsp;|.$locale->text('Subtotal').qq|
             <input type=checkbox class=checkbox name=fx_transaction value=1 checked> |.$locale->text('Include Exchange Rate Difference').qq|
          </td>
        </tr>
|;
	}

	if ( $form->{report} eq "income_statement" ) {

		print qq|
	$project
	<tr>
	  <th align=right>| . $locale->text('From') . qq|</th>
	  <td colspan=3><input name=fromdate size=11 class=date title="$myconfig{dateformat}" onChange="validateDate(this)" value=$form->{fromdate}> <b>|
		  . $locale->text('To')
		  . qq|</b> <input name=todate size=11 class=date title="$myconfig{dateformat}" onChange="validateDate(this)"></td>
	</tr>
|;

		if ($selectfrom) {
			print qq|
        <tr>
	  <th align=right>| . $locale->text('Period') . qq|</th>
	  <td colspan=3>
	  <select name=frommonth>$selectaccountingmonth</select>
	  <select name=fromyear>$selectaccountingyear</select>
	  <input name=interval class=radio type=radio value=0 checked>&nbsp;|
			  . $locale->text('Current') . qq|
	  <input name=interval class=radio type=radio value=1>&nbsp;|
			  . $locale->text('Month') . qq|
	  <input name=interval class=radio type=radio value=3>&nbsp;|
			  . $locale->text('Quarter') . qq|
	  <input name=interval class=radio type=radio value=12>&nbsp;|
			  . $locale->text('Year') . qq|
	  </td>
	</tr>
|;
		}

		print qq|

	<tr>
	  <th align=right>| . $locale->text('Compare to') . qq|</th>
	</tr>
	<tr>
	  <th align=right>| . $locale->text('From') . qq|</th>
	  <td colspan=3><input name=comparefromdate size=11 class=date title="$myconfig{dateformat}" onChange="validateDate(this)"> <b>|
		  . $locale->text('To')
		  . qq|</b> <input name=comparetodate size=11 class=date title="$myconfig{dateformat}" onChange="validateDate(this)"></td>
	</tr>
|;

		if ($selectto) {
			print qq|
        <tr>
	  <th align=right>| . $locale->text('Period') . qq|</th>
	  <td>
	  <select name=comparemonth>$selectaccountingmonth</select>
	  <select name=compareyear>$selectaccountingyear</select>
	  </td>
	</tr>
|;
		}

		print qq|
	$curr
	<tr>
	  <th align=right>| . $locale->text('Decimalplaces') . qq|</th>
	  <td><input name=decimalplaces size=3 value=$form->{decimalplaces}></td>
	</tr>
	$lang
      </table>
    </td>
  </tr>
  <tr>
    <td>
      <table>
        $method

	<tr>
	  <th align=right nowrap>| . $locale->text('Include in Report') . qq|</th>
	  <td colspan=3><input name=l_heading class=checkbox type=checkbox value=Y>&nbsp;|
		  . $locale->text('Heading') . qq|
	  <input name=l_subtotal class=checkbox type=checkbox value=Y>&nbsp;|
		  . $locale->text('Subtotal') . qq|
	  <input name=l_accno class=checkbox type=checkbox value=Y checked>&nbsp;|
		  . $locale->text('Account Number')
		  . qq|</td>
	</tr>
|;
	}

	if ( $form->{report} eq "balance_sheet" ) {

		print qq|
	<tr>
	  <th align=right>| . $locale->text('as at') . qq|</th>
	  <td><input name=asofdate size=11 class=date title="$myconfig{dateformat}" onChange="validateDate(this)" value=$form->{asofdate}></td>
|;

		if ($selectfrom) {
			print qq|
	  <td>
	  <select name=asofmonth>$selectaccountingmonth</select>
	  <select name=asofyear>$selectaccountingyear</select>
	  </td>
|;
		}

		print qq|
	</tr>

	  <th align=right nowrap>| . $locale->text('Compare to') . qq|</th>
	  <td><input name=compareasofdate size=11 class=date title="$myconfig{dateformat}" onChange="validateDate(this)"></td>
	  <td>
|;

		if ($selectto) {
			print qq|
	  <select name=compareasofmonth>$selectaccountingmonth</select>
	  <select name=compareasofyear>$selectaccountingyear</select>
	  </td>
|;
		}

		print qq|
	</tr>
	<tr>
	  $curr
	  <th align=right>| . $locale->text('Decimalplaces') . qq|</th>
	  <td><input name=decimalplaces size=3 value=$form->{precision}></td>
	</tr>
	$lang
      </table>
    </td>
  </tr>
  <tr>
    <td>
      <table>
        $method

	<tr>
	  <th align=right nowrap>| . $locale->text('Include in Report') . qq|</th>
	  <td><input name=l_heading class=checkbox type=checkbox value=Y>&nbsp;|
		  . $locale->text('Heading') . qq|
	  <input name=l_subtotal class=checkbox type=checkbox value=Y>&nbsp;|
		  . $locale->text('Subtotal') . qq|
	  <input name=l_accno class=checkbox type=checkbox value=Y checked>&nbsp;|
		  . $locale->text('Account Number')
		  . qq|</td>
	</tr>
|;
	}

	if ( $form->{report} eq "trial_balance" ) {

		print qq|
        <tr>
	  <th align=right>| . $locale->text('From') . qq|</th>
	  <td colspan=3><input name=fromdate size=11 class=date title="$myconfig{dateformat}" onChange="validateDate(this)" value=$form->{fromdate}> <b>|
		  . $locale->text('To')
		  . qq|</b> <input name=todate size=11 class=date title="$myconfig{dateformat}" onChange="validateDate(this)"></td>
	</tr>
	$selectfrom
	$lang
      </table>
    </td>
  </tr>
  <tr>
    <td>
      <table>
	<tr>
	  <th align=right nowrap>| . $locale->text('Include in Report') . qq|</th>
	  <td><input name=l_heading class=checkbox type=checkbox value=Y>&nbsp;|
		  . $locale->text('Heading') . qq|
	  <input name=l_subtotal class=checkbox type=checkbox value=Y>&nbsp;|
		  . $locale->text('Subtotal') . qq|
	  <input name=all_accounts class=checkbox type=checkbox value=Y>&nbsp;|
		  . $locale->text('All Accounts') . qq|
	  <input name=l_name class=checkbox type=checkbox value=Y checked>&nbsp;|
		  . $locale->text('Company Name') . qq|
      <input type=checkbox class=checkbox name=fx_transaction value=1 checked> |
		  . $locale->text('Include Exchange Rate Difference')
		  . qq|</td>
	</tr>
|;
	}

	if ( $form->{report} =~ /^tax_/ ) {
		$gifi = "";

		$form->{db} = ( $form->{report} =~ /_collected/ ) ? "ar" : "ap";

		RP->get_taxaccounts( \%myconfig, \%$form );

		$form->{nextsub} = "$form->{reportsub}";

		print qq|
	<tr>
	  <th align=right>| . $locale->text('From') . qq|</th>
	  <td colspan=3><input name=fromdate size=11 class=date title="$myconfig{dateformat}" onChange="validateDate(this)" value=$form->{fromdate}> <b>|
		  . $locale->text('To')
		  . qq|</b> <input name=todate size=11 class=date title="$myconfig{dateformat}" onChange="validateDate(this)"></td>
	</tr>
	$selectfrom
	$summary
	<tr>|;
		print qq|
	  <th align=right>| . $locale->text('Report for') . qq|</th>
	  <td colspan=3>
| if $form->{reportsub} ne 'generate_tax_report_all';

		$checked = "checked";
		foreach $ref ( @{ $form->{taxaccounts} } ) {

			print qq|<input name=accno class=radio type=radio value="|
			  . $form->quote( $ref->{accno} )
			  . qq|" $checked>&nbsp;$ref->{description}

    <input name="$ref->{accno}_description" type=hidden value="|
			  . $form->quote( $ref->{description} ) . qq|">|
			  if $form->{reportsub} ne 'generate_tax_report_all';

			$checked = "";

		}

		print qq|
<input type=hidden name=db value=$form->{db}>
<input type=hidden name=sort value=transdate>

	  </td>
	</tr>
|;

		if ( @{ $form->{gifi_taxaccounts} } ) {
			print qq|
        <tr>
	  <th align=right>| . $locale->text('GIFI') . qq|</th>
	  <td colspan=3>
|;

			foreach $ref ( @{ $form->{gifi_taxaccounts} } ) {

				print qq|<input name=accno class=radio type=radio value="|
				  . $form->quote("gifi_$ref->{accno}")
				  . qq|">&nbsp;$ref->{description}

      <input name="gifi_$ref->{accno}_description" type=hidden value="|
				  . $form->quote( $ref->{description} ) . qq|">|;

			}

			print qq|
	  </td>
	</tr>
|;
		}

		if ( $form->{db} eq 'ar' ) {
			$vc = qq|
    <td><input name="l_name" class=checkbox type=checkbox value=Y checked></td>
    <td>| . $locale->text('Customer') . qq|</td>
    <td><input name="l_customernumber" class=checkbox type=checkbox value=Y></td>
    <td>| . $locale->text('Customer Number') . qq|</td>|;
		}

		if ( $form->{db} eq 'ap' ) {
			$vc = qq|
    <td><input name="l_name" class=checkbox type=checkbox value=Y checked></td>
    <td>| . $locale->text('Vendor') . qq|</td>
    <td><input name="l_vendornumber" class=checkbox type=checkbox value=Y></td>
    <td>| . $locale->text('Vendor Number') . qq|</td>|;
		}

		print qq|
        $method
      </table>
    </td>
  </tr>
  <tr>
    <td>
      <table>
        <tr>
	  <th align=right>| . $locale->text('Include in Report') . qq|</th>
	  <td>
	    <table>
	      <tr>
		<td><input name="l_id" class=checkbox type=checkbox value=Y></td>
		<td>| . $locale->text('ID') . qq|</td>
		<td><input name="l_invnumber" class=checkbox type=checkbox value=Y checked></td>
		<td>| . $locale->text('Invoice') . qq|</td>
		<td><input name="l_transdate" class=checkbox type=checkbox value=Y checked></td>
		<td>| . $locale->text('Date') . qq|</td>
  	        <td><input name="l_description" class=checkbox type=checkbox value=Y checked></td>
		<td>| . $locale->text('Description') . qq|</td>
	      </tr>

	      <tr>
	        $vc

		<td><input name="l_netamount" class=checkbox type=checkbox value=Y checked></td>
		<td>| . $locale->text('Amount') . qq|</td>

		<td><input name="l_tax" class=checkbox type=checkbox value=Y checked></td>
		<td>| . $locale->text('Tax') . qq|</td>

	      </tr>
	      <tr>
	        <td><input name="l_subtotal" class=checkbox type=checkbox value=Y></td>
		<td>| . $locale->text('Subtotal') . qq|</td>
	      </tr>
	    </table>
	  </td>
	</tr>
|;

	}

	if ( $form->{report} =~ /^nontaxable_/ ) {
		$gifi = "";

		$form->{db} = ( $form->{report} =~ /_sales/ ) ? "ar" : "ap";

		$form->{nextsub} = "$form->{reportsub}";

		if ( $form->{db} eq 'ar' ) {
			$vc = qq|
      <td><input name="l_name" class=checkbox type=checkbox value=Y checked></td>
      <td>| . $locale->text('Customer') . qq|</td>
      <td><input name="l_customernumber" class=checkbox type=checkbox value=Y></td>
      <td>| . $locale->text('Customer Number') . qq|</td>|;
		}

		if ( $form->{db} eq 'ap' ) {
			$vc = qq|
      <td><input name="l_name" class=checkbox type=checkbox value=Y checked></td>
      <td>| . $locale->text('Vendor') . qq|</td>
      <td><input name="l_vendornumber" class=checkbox type=checkbox value=Y></td>
      <td>| . $locale->text('Vendor Number') . qq|</td>|;
		}

		print qq|

        <input type=hidden name=db value=$form->{db}>
        <input type=hidden name=sort value=transdate>
        <input type=hidden name=report value=$form->{report}>

	<tr>
	  <th align=right>| . $locale->text('From') . qq|</th>
	  <td colspan=3><input name=fromdate size=11 class=date title="$myconfig{dateformat}" onChange="validateDate(this)" value=$form->{fromdate}> <b>|
		  . $locale->text('To')
		  . qq|</b> <input name=todate size=11 class=date title="$myconfig{dateformat}" onChange="validateDate(this)"></td>
	</tr>
	$selectfrom
	$summary
	$method
        <tr>
	  <th align=right>| . $locale->text('Include in Report') . qq|</th>
	  <td colspan=3>
	    <table>
	      <tr>
		<td><input name="l_id" class=checkbox type=checkbox value=Y></td>
		<td>| . $locale->text('ID') . qq|</td>
		<td><input name="l_invnumber" class=checkbox type=checkbox value=Y checked></td>
		<td>| . $locale->text('Invoice') . qq|</td>
		<td><input name="l_transdate" class=checkbox type=checkbox value=Y checked></td>
		<td>| . $locale->text('Date') . qq|</td>
	        <td><input name="l_description" class=checkbox type=checkbox value=Y checked></td>
		<td>| . $locale->text('Description') . qq|</td>
	      </tr>
	      <tr>

	        $vc

                <td><input name="l_netamount" class=checkbox type=checkbox value=Y checked></td>
		<td>| . $locale->text('Amount') . qq|</td>
	      </tr>
	      <tr>
	        <td><input name="l_subtotal" class=checkbox type=checkbox value=Y></td>
		<td>| . $locale->text('Subtotal') . qq|</td>
	      </tr>
	    </table>
	  </td>
	</tr>
|;

	}

	if (   ( $form->{report} eq "ar_aging" )
		|| ( $form->{report} eq "ap_aging" ) )
	{
		$gifi = "";

		if ( $form->{report} eq 'ar_aging' ) {
			$vclabel    = $locale->text('Customer');
			$vcnumber   = $locale->text('Customer Number');
			$form->{vc} = 'customer';
			$form->{sort} = "customernumber" if $form->{namesbynumber};
		}
		else {
			$vclabel    = $locale->text('Vendor');
			$vcnumber   = $locale->text('Vendor Number');
			$form->{vc} = 'vendor';
		}
		$form->{sort} =
		  ( $form->{namesbynumber} ) ? "$form->{vc}number" : "name";

		$form->{type} = "statement";
		$form->{format} ||= $myconfig{outputformat};
		$form->{media}  ||= $myconfig{printer};

		# setup vc selection
		$form->all_vc( \%myconfig, $form->{vc},
			( $form->{vc} eq 'customer' ) ? "AR" : "AP",
			undef, undef, undef, 1 );

		if ( @{ $form->{"all_$form->{vc}"} } ) {
			$vc = qq|
           <tr>
	     <th align=right nowrap>$vclabel</th>
	     <td colspan=2><select name=$form->{vc}><option>\n|;

			for ( @{ $form->{"all_$form->{vc}"} } ) {
				$vc .=
				    qq|<option value="|
				  . $form->quote( $_->{name} )
				  . qq|--$_->{id}">$_->{name}\n|;
			}

			$vc .= qq|</select>
             </td>
	   </tr>
|;
		}
		else {
			$vc = qq|
                <tr>
		  <th align=right nowrap>$vclabel</th>
		  <td colspan=2><input name=$form->{vc} size=35>
		  </td>
		</tr>
		<tr>
		  <th align=right nowrap>$vcnumber</th>
		  <td colspan=3><input name="$form->{vc}number" size=35>
		  </td>
		</tr>
|;
		}

		print qq|
        $vc
	<tr>
	  <th align=right>| . $locale->text('To') . qq|</th>
	  <td><input name=todate size=11 class=date title="$myconfig{dateformat}" onChange="validateDate(this)"></td>
	</tr>
	$selectto
	<input type=hidden name=action value="$form->{nextsub}">
	$summary
	<tr>
	  <table>
	    <tr>
	      <th>| . $locale->text('Include in Report') . qq|</th>

	      <td>
	        <table>
		  <tr>
	            <td nowrap><input name=overdue type=radio class=radio value=0 checked> |
		  . $locale->text('Aged')
		  . qq|</td>
 	            <td nowrap><input name=overdue type=radio class=radio value=1> |
		  . $locale->text('Overdue')
		  . qq|</td>
	          </tr>
		  <tr>
		    <td nowrap width=70><input name=c0 type=checkbox class=checkbox value=1 checked> |
		  . $locale->text('Current')
		  . qq|</td>
		    <td nowrap width=70><input name=c30 type=checkbox class=checkbox value=1 checked> 30</td>
		    <td nowrap width=70><input name=c60 type=checkbox class=checkbox value=1 checked> 60</td>
		    <td nowrap width=70><input name=c90 type=checkbox class=checkbox value=1 checked> 90</td>
		  </tr>
		  <tr>
		    <td nowrap width=70><input name=c15 type=checkbox class=checkbox value=1> 15</td>
		    <td nowrap width=70><input name=c45 type=checkbox class=checkbox value=1> 45</td>
		    <td nowrap width=70><input name=c75 type=checkbox class=checkbox value=1> 75</td>
		    <td nowrap><input name=payed type=checkbox class=checkbox value=1> |
		  . $locale->text('Include Payed')
		  . qq|</td>
		  </tr>
		</table>
	      </td>
	    </tr>
	  </table>
	</tr>

|;

		$form->hide_form(qw(nextsub type format media sort));

	}

	if ( $form->{report} eq 'reminder' ) {
		$gifi = "";

		$vclabel    = $locale->text('Customer');
		$vcnumber   = $locale->text('Customer Number');
		$form->{vc} = 'customer';
		$form->{sort} = "customernumber" if $form->{namesbynumber};
		$form->{sort} =
		  ( $form->{namesbynumber} ) ? "$form->{vc}number" : "name";

		$form->{type} = "reminder";
		$form->{format} ||= $myconfig{outputformat};
		$form->{media}  ||= $myconfig{printer};

		# setup vc selection
		$form->all_vc( \%myconfig, $form->{vc},
			( $form->{vc} eq 'customer' ) ? "AR" : "AP",
			undef, undef, undef, 1 );

		if ( @{ $form->{"all_$form->{vc}"} } ) {
			$vc = qq|
           <tr>
	     <th align=right nowrap>$vclabel</th>
	     <td colspan=2><select name=$form->{vc}><option>\n|;

			for ( @{ $form->{"all_$form->{vc}"} } ) {
				$vc .=
				    qq|<option value="|
				  . $form->quote( $_->{name} )
				  . qq|--$_->{id}">$_->{name}\n|;
			}

			$vc .= qq|</select>
             </td>
           </tr>
|;
		}
		else {
			$vc = qq|
                <tr>
		  <th align=right nowrap>$vclabel</th>
		  <td colspan=2><input name=$form->{vc} size=35>
		  </td>
                </tr>
		<tr>
		  <th align=right nowrap>$locale->text('Customer')</th>
		  <td colspan=3><input name="$form->{vc}number" size=35>
		  </td>
                </tr>
|;
		}

		$overpaidlabel = $locale->text('Overpaid');

		my $duedateto = $form->current_date( \%myconfig );

		print qq|
        $vc
    	<tr>
		  <th align=right nowrap>$overpaidlabel</th>
		  <td nowrap width=70><input name=overpaid type=checkbox class=checkbox value=on></td>
		</tr>
    	<tr>
		  <th align=right nowrap>| . $locale->text('Exclude Credits') . qq|</th>
		  <td nowrap width=70><input name=exclude_credits type=checkbox class=checkbox value=on></td>
		</tr>
    <tr>
      <th align=right nowrap>| . $locale->text('Due Date') . qq| <= </th>
      <td nowrap width=70><input name="duedateto" type=text size=12 class="date" value="$duedateto" title="$myconfig{dateformat}"></td>
    </tr>

	<input type=hidden name=action value="$form->{nextsub}">
|;

		$form->hide_form(qw(type format media sort));

	}

	# above action can be removed if there is more than one input field

	if ( $form->{report} =~ /(receipts|payments)$/ ) {

		$form->{nextsub} = "list_payments";

		$gifi = "";

		$form->{db} = ( $form->{report} =~ /payments/ ) ? "ap" : "ar";
		$form->{vc} = ( $form->{db} eq 'ar' ) ? 'customer' : 'vendor';

		RP->paymentaccounts( \%myconfig, \%$form );

		$selectpaymentaccount = "\n";
		foreach $ref ( @{ $form->{PR} } ) {
			$form->{paymentaccounts} .= "$ref->{accno} ";
			$selectpaymentaccount .= qq|$ref->{accno}--$ref->{description}\n|;
		}

		chop $form->{paymentaccounts};

		$form->hide_form(qw(paymentaccounts));

		if ( $form->{vc} eq 'customer' ) {
			$vclabel  = $locale->text('Customer');
			$vcnumber = $locale->text('Customer Number');
			$form->all_vc( \%myconfig, $form->{vc}, "AR" );
		}
		else {
			$form->all_vc( \%myconfig, $form->{vc}, "AP" );
			$vclabel  = $locale->text('Vendor');
			$vcnumber = $locale->text('Vendor Number');
		}

		# setup vc selection
		if ( $@{ $form->{"all_$form->{vc}"} } ) {
			$vc = qq|
           <tr>
	     <th align=right nowrap>$vclabel</th>
	     <td colspan=2><select name=$form->{vc}><option>\n|;

			for ( @{ $form->{"all_$form->{vc}"} } ) {
				$vc .=
				    qq|<option value="|
				  . $form->quote( $_->{name} )
				  . qq|--$_->{id}">$_->{name}\n|;
			}

			$vc .= qq|</select>
             </td>
	   </tr>
|;
		}
		else {
			$vc = qq|
                <tr>
		  <th align=right nowrap>$vclabel</th>
		  <td colspan=2><input name=$form->{vc} size=35>
		  </td>
		</tr>
		<tr>
		  <th align=right nowrap>$vcnumber</th>
		  <td colspan=3><input name="$form->{vc}number" size=35>
		  </td>
		</tr>
|;
		}

		print qq|
        <tr>
	  <th align=right nowrap>| . $locale->text('Account') . qq|</th>
          <td colspan=3><select name=account>|
		  . $form->select_option($selectpaymentaccount) . qq|</select>
	  </td>
	</tr>
	$vc
        <tr>
	  <th align=right nowrap>| . $locale->text('Description') . qq|</th>
          <td colspan=3><input name=description size=35></td>
	</tr>
        <tr>
	  <th align=right nowrap>| . $locale->text('Source') . qq|</th>
          <td colspan=3><input name=source></td>
	</tr>
        <tr>
	  <th align=right nowrap>| . $locale->text('Memo') . qq|</th>
          <td colspan=3><input name=memo size=30></td>
	</tr>
	<tr>
	  <th align=right>| . $locale->text('From') . qq|</th>
	  <td colspan=3><input name=fromdate size=11 class=date title="$myconfig{dateformat}" onChange="validateDate(this)" value=$form->{fromdate}> <b>|
		  . $locale->text('To')
		  . qq|</b> <input name=todate size=11 class=date title="$myconfig{dateformat}" onChange="validateDate(this)"></td>
	</tr>
	$selectfrom
	<tr>
	  <th align=right nowrap>| . $locale->text('Include in Report') . qq|</th>
	  <td>
	    <table width=100%>
	      <tr>
		<td align=right><input type=checkbox class=checkbox name=fx_transaction value=1 checked> |
		  . $locale->text('Exchange Rate Difference')
		  . qq|</td>
	      </tr>
|;

		@a = ();

		push @a,
qq|<input name="l_transdate" class=checkbox type=checkbox value=Y checked> |
		  . $locale->text('Date');
		push @a,
qq|<input name="l_reference" class=checkbox type=checkbox value=Y checked> |
		  . $locale->text('Reference');
		push @a,
qq|<input name="l_name" class=checkbox type=checkbox value=Y checked> |
		  . $locale->text($vclabel);
		push @a,
qq|<input name="l_$form->{vc}number" class=checkbox type=checkbox value=Y> |
		  . $locale->text($vcnumber);
		push @a,
qq|<input name="l_description" class=checkbox type=checkbox value=Y checked> |
		  . $locale->text('Description');
		push @a,
qq|<input name="l_paid" class=checkbox type=checkbox value=Y checked> |
		  . $locale->text('Amount');
		push @a,
qq|<input name="l_source" class=checkbox type=checkbox value=Y checked> |
		  . $locale->text('Source');
		push @a,
qq|<input name="l_memo" class=checkbox type=checkbox value=Y checked> |
		  . $locale->text('Memo');
		push @a,
qq|<input name="l_variance" class=checkbox type=checkbox value=Y> |
		  . $locale->text('Variance');

		while (@a) {
			print qq|<tr>\n|;
			for ( 1 .. 5 ) {
				print qq|<td nowrap>| . shift @a;
				print qq|</td>\n|;
			}
			print qq|</tr>\n|;
		}

		print qq|
	      <tr>
		<td><input name=l_subtotal class=checkbox type=checkbox value=Y> |
		  . $locale->text('Subtotal')
		  . qq|</td>
	      </tr>
	    </table>
	  </td>
	</tr>
|;

		$form->{sort} = 'transdate';
		$form->hide_form(qw(vc db sort));

	}

	print qq|

      $gifi

      </table>
    </td>
  </tr>
  <tr>
    <td><hr size=3 noshade></td>
  </tr>
</table>

<br>
<input type=submit class=submit name=action value="|
	  . $locale->text('Continue') . qq|">
|;

	$form->hide_form(qw(title nextsub path login));

	print qq|

</form>
|;

	if ( $form->{menubar} ) {
		require "$form->{path}/menu.pl";
		&menubar;
	}

	print qq|

</body>
</html>
|;

}

sub continue { &{ $form->{nextsub} } }

sub generate_income_statement {

	$form->isvaldate( \%myconfig, $form->{fromdate},
		$locale->text('Invalid from date ...') );
	$form->isvaldate( \%myconfig, $form->{todate},
		$locale->text('Invalid to date ...') );
	$form->isvaldate(
		\%myconfig,
		$form->{comparefromdate},
		$locale->text('Invalid from date ...')
	);
	$form->isvaldate(
		\%myconfig,
		$form->{comparetodate},
		$locale->text('Invalid to date ...')
	);

	$form->{padding} = "&nbsp;&nbsp;";
	$form->{bold}    = "<strong>";
	$form->{endbold} = "</strong>";
	$form->{br}      = "<br>\n";

	RP->income_statement( \%myconfig, \%$form );

	( $form->{department} )    = split /--/, $form->{department};
	( $form->{projectnumber} ) = split /--/, $form->{projectnumber};

	$form->{period} =
	  $locale->date( \%myconfig, $form->current_date( \%myconfig ), 1 );
	$form->{todate} = $form->current_date( \%myconfig ) unless $form->{todate};

	# if there are any dates construct a where
	if ( $form->{fromdate} || $form->{todate} ) {

		unless ( $form->{todate} ) {
			$form->{todate} = $form->current_date( \%myconfig );
		}

		$longtodate  = $locale->date( \%myconfig, $form->{todate}, 1 );
		$shorttodate = $locale->date( \%myconfig, $form->{todate}, 0 );

		$longfromdate  = $locale->date( \%myconfig, $form->{fromdate}, 1 );
		$shortfromdate = $locale->date( \%myconfig, $form->{fromdate}, 0 );

		$form->{this_period} = "$shortfromdate $form->{br} $shorttodate";
		$form->{period} =
		    $locale->text('for Period')
		  . qq| $form->{br} $longfromdate |
		  . $locale->text('To')
		  . qq| $longtodate|;
	}

	if ( $form->{comparefromdate} || $form->{comparetodate} ) {
		$longcomparefromdate =
		  $locale->date( \%myconfig, $form->{comparefromdate}, 1 );
		$shortcomparefromdate =
		  $locale->date( \%myconfig, $form->{comparefromdate}, 0 );

		$longcomparetodate =
		  $locale->date( \%myconfig, $form->{comparetodate}, 1 );
		$shortcomparetodate =
		  $locale->date( \%myconfig, $form->{comparetodate}, 0 );

		$form->{last_period} =
		  "$shortcomparefromdate $form->{br} $shortcomparetodate";
		$form->{period} .=
		    "$form->{br} $longcomparefromdate "
		  . $locale->text('To')
		  . qq| $longcomparetodate|;
	}

	# setup variables for the form
	$form->format_string(
		qw(companyemail companywebsite company address businessnumber));
	$form->{address} =~ s/\n/$form->{br}/g;

	$form->{templates} = $myconfig{templates};

	$form->{IN} = "income_statement.html";

	$form->parse_template( \%myconfig, $userspath, $debuglatex );

}

sub generate_balance_sheet {

	$form->isvaldate( \%myconfig, $form->{fromdate},
		$locale->text('Invalid from date ...') );
	$form->isvaldate( \%myconfig, $form->{todate},
		$locale->text('Invalid to date ...') );
	$form->isvaldate(
		\%myconfig,
		$form->{comparefromdate},
		$locale->text('Invalid from date ...')
	);
	$form->isvaldate(
		\%myconfig,
		$form->{comparetodate},
		$locale->text('Invalid to date ...')
	);

	$form->{padding} = "&nbsp;&nbsp;";
	$form->{bold}    = "<strong>";
	$form->{endbold} = "</strong>";
	$form->{br}      = "<br>\n";

	$form->{asofdate} = $form->current_date( \%myconfig )
	  unless $form->{asofdate};
	$form->{period} =
	  $locale->date( \%myconfig, $form->current_date( \%myconfig ), 1 );

	RP->balance_sheet( \%myconfig, \%$form );

	( $form->{department} ) = split /--/, $form->{department};

	# define Current Earnings account
	$padding = ( $form->{l_heading} ) ? $form->{padding} : "";
	push(
		@{ $form->{equity_account} },
		$padding . $locale->text('Current Earnings')
	);

	$form->{this_period} = $locale->date( \%myconfig, $form->{asofdate}, 0 );
	$form->{last_period} =
	  $locale->date( \%myconfig, $form->{compareasofdate}, 0 );

	$form->{IN} = "balance_sheet.html";

	# setup company variables for the form
	$form->format_string(
		qw(companyemail companywebsite company address businessnumber));
	$form->{address} =~ s/\n/$form->{br}/g;

	$form->{templates} = $myconfig{templates};

	$form->parse_template( \%myconfig, $userspath, $debuglatex );

}

sub generate_projects {

	$form->isvaldate( \%myconfig, $form->{fromdate},
		$locale->text('Invalid to date ...') );
	$form->isvaldate( \%myconfig, $form->{todate},
		$locale->text('Invalid to date ...') );

	$form->{nextsub} = "generate_projects";
	$form->{title}   = $locale->text('Project Transactions');

	RP->trial_balance( \%myconfig, \%$form );

	&list_accounts;

}

# Antonio Gallardo
#
# D.S. Feb 16, 2001
# included links to display transactions for period entered
# added headers and subtotals
#
sub generate_trial_balance {

	$form->isvaldate( \%myconfig, $form->{fromdate},
		$locale->text('Invalid from date ...') );
	$form->isvaldate( \%myconfig, $form->{todate},
		$locale->text('Invalid to date ...') );

	# get for each account initial balance, debits and credits
	RP->trial_balance( \%myconfig, \%$form );

	$form->{nextsub} = "generate_trial_balance";
	$form->{title}   = $locale->text('Trial Balance') . " / $form->{company}";

	$form->{callback} = "$form->{script}?action=generate_trial_balance";
	for (
		qw(login path nextsub fromdate todate month year interval l_heading l_subtotal all_accounts l_name accounttype fx_transaction)
	  )
	{
		$form->{callback} .= "&$_=$form->{$_}";
	}
	for (qw(department title)) {
		$form->{callback} .= "&$_=" . $form->escape( $form->{$_}, 1 );
	}

	$form->{callback} = $form->escape( $form->{callback} );

	&list_accounts;

}

sub list_accounts {

	$title = $form->escape( $form->{title} );

	if ( $form->{department} ) {
		($department) = split /--/, $form->{department};
		$options    = $locale->text('Department') . " : $department<br>";
		$department = $form->escape( $form->{department} );
	}
	if ( $form->{projectnumber} ) {
		($projectnumber) = split /--/, $form->{projectnumber};
		$options .= $locale->text('Project Number') . " : $projectnumber<br>";
		$projectnumber = $form->escape( $form->{projectnumber} );
	}

	# if there are any dates
	if ( $form->{fromdate} || $form->{todate} ) {

		if ( $form->{fromdate} ) {
			$fromdate = $locale->date( \%myconfig, $form->{fromdate}, 1 );
		}
		if ( $form->{todate} ) {
			$todate = $locale->date( \%myconfig, $form->{todate}, 1 );
		}

		$form->{period} = "$fromdate - $todate";
	}
	else {
		$form->{period} =
		  $locale->date( \%myconfig, $form->current_date( \%myconfig ), 1 );

	}
	$options .= $form->{period};

	@column_index = qw(accno description begbalance debit credit endbalance);

	$column_header{accno} =
	    qq|<th class=listheading width=10%>|
	  . $locale->text('Account')
	  . qq|</th>|;
	$column_header{description} =
	  qq|<th class=listheading>| . $locale->text('Description') . qq|</th>|;
	$column_header{debit} =
	  qq|<th class=listheading width=10%>| . $locale->text('Debit') . qq|</th>|;
	$column_header{credit} =
	    qq|<th class=listheading width=10%>|
	  . $locale->text('Credit')
	  . qq|</th>|;
	$column_header{begbalance} =
	    qq|<th class=listheading width=10%>|
	  . $locale->text('Beginning Balance')
	  . qq|</th>|;
	$column_header{endbalance} =
	    qq|<th class=listheading width=10%>|
	  . $locale->text('Ending Balance')
	  . qq|</th>|;

	if ( $form->{accounttype} eq 'gifi' ) {
		$column_header{accno} =
		  qq|<th class=listheading>| . $locale->text('GIFI') . qq|</th>|;
	}

	$form->header;

	print qq|
<body>

<table width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <td>$options</td>
  </tr>
  <tr>
    <td>
      <table width=100%>
	<tr>|;

	for (@column_index) { print "$column_header{$_}\n" }

	print qq|
        </tr>
|;

	# sort the whole thing by account numbers and display
	foreach $ref ( sort { $a->{accno} cmp $b->{accno} } @{ $form->{TB} } ) {

		$description = $form->escape( $ref->{description} );

		$href =
qq|ca.pl?path=$form->{path}&action=list_transactions&accounttype=$form->{accounttype}&login=$form->{login}&fromdate=$form->{fromdate}&todate=$form->{todate}&sort=transdate&l_heading=$form->{l_heading}&l_name=$form->{l_name}&l_subtotal=$form->{l_subtotal}&department=$department&projectnumber=$projectnumber&project_id=$form->{project_id}&title=$title&nextsub=$form->{nextsub}&fx_transaction=$form->{fx_transaction}&prevreport=$form->{callback}|;

		if ( $form->{accounttype} eq 'gifi' ) {
			$href .= "&gifi_accno=$ref->{accno}&gifi_description=$description";
			$na = $locale->text('N/A');
			if ( !$ref->{accno} ) {
				for (qw(accno description)) { $ref->{$_} = $na }
			}
		}
		else {
			$href .= "&accno=$ref->{accno}&description=$description";
		}

		$ml = ( $ref->{category} =~ /(A|E)/ ) ? -1 : 1;
		$ml *= -1 if $ref->{contra};

		$debit =
		  $form->format_amount( \%myconfig, $ref->{debit}, $form->{precision},
			"&nbsp;" );
		$credit =
		  $form->format_amount( \%myconfig, $ref->{credit}, $form->{precision},
			"&nbsp;" );
		$begbalance = $form->format_amount( \%myconfig, $ref->{balance} * $ml,
			$form->{precision}, "&nbsp;" );
		$endbalance =
		  $form->format_amount( \%myconfig,
			( $ref->{balance} + $ref->{amount} ) * $ml,
			$form->{precision}, "&nbsp;" );

		if ( $ref->{charttype} eq "H" && $subtotal && $form->{l_subtotal} ) {

			if ($subtotal) {

				for (qw(accno begbalance endbalance)) {
					$column_data{$_} = "<th>&nbsp;</th>";
				}

				$subtotalbegbalance =
				  $form->format_amount( \%myconfig, $subtotalbegbalance,
					$form->{precision}, "&nbsp;" );
				$subtotalendbalance =
				  $form->format_amount( \%myconfig, $subtotalendbalance,
					$form->{precision}, "&nbsp;" );
				$subtotaldebit =
				  $form->format_amount( \%myconfig, $subtotaldebit,
					$form->{precision}, "&nbsp;" );
				$subtotalcredit =
				  $form->format_amount( \%myconfig, $subtotalcredit,
					$form->{precision}, "&nbsp;" );

				$column_data{description} =
				  "<th class=listsubtotal>$subtotaldescription</th>";
				$column_data{begbalance} =
				  "<th align=right class=listsubtotal>$subtotalbegbalance</th>";
				$column_data{endbalance} =
				  "<th align=right class=listsubtotal>$subtotalendbalance</th>";
				$column_data{debit} =
				  "<th align=right class=listsubtotal>$subtotaldebit</th>";
				$column_data{credit} =
				  "<th align=right class=listsubtotal>$subtotalcredit</th>";

				print qq|
	  <tr class=listsubtotal>
|;
				for (@column_index) { print "$column_data{$_}\n" }

				print qq|
	  </tr>
|;
			}
		}

		if ( $ref->{charttype} eq "H" ) {
			$subtotal            = 1;
			$subtotaldescription = $ref->{description};
			$subtotaldebit       = $ref->{debit};
			$subtotalcredit      = $ref->{credit};
			$subtotalbegbalance  = 0;
			$subtotalendbalance  = 0;

			if ( $form->{l_heading} ) {
				if ( !$form->{all_accounts} ) {
					if ( ( $subtotaldebit + $subtotalcredit ) == 0 ) {
						$subtotal = 0;
						next;
					}
				}
			}
			else {
				$subtotal = 0;
				if (
					$form->{all_accounts}
					|| ( $form->{l_subtotal}
						&& ( ( $subtotaldebit + $subtotalcredit ) != 0 ) )
				  )
				{
					$subtotal = 1;
				}
				next;
			}

			for (qw(accno debit credit begbalance endbalance)) {
				$column_data{$_} = "<th>&nbsp;</th>";
			}
			$column_data{description} =
			  "<th class=listheading>$ref->{description}</th>";
		}

		if ( $ref->{charttype} eq "A" ) {
			$column_data{accno} = "<td><a href=$href>$ref->{accno}</a></td>";
			$column_data{description} = "<td>$ref->{description}</td>";
			$column_data{debit}       = "<td align=right>$debit</td>";
			$column_data{credit}      = "<td align=right>$credit</td>";
			$column_data{begbalance}  = "<td align=right>$begbalance</td>";
			$column_data{endbalance}  = "<td align=right>$endbalance</td>";

			$totaldebit  += $ref->{debit};
			$totalcredit += $ref->{credit};

			$cml = ( $ref->{contra} ) ? -1 : 1;

			$subtotalbegbalance += $ref->{balance} * $ml * $cml;
			$subtotalendbalance +=
			  ( $ref->{balance} + $ref->{amount} ) * $ml * $cml;

		}

		if ( $ref->{charttype} eq "H" ) {
			print qq|
      <tr class=listheading>
|;
		}
		if ( $ref->{charttype} eq "A" ) {
			$i++;
			$i %= 2;
			print qq|
      <tr class=listrow$i>
|;
		}

		for (@column_index) { print "$column_data{$_}\n" }

		print qq|
      </tr>
|;
	}

	# print last subtotal
	if ( $subtotal && $form->{l_subtotal} ) {
		for (qw(accno begbalance endbalance)) {
			$column_data{$_} = "<th>&nbsp;</th>";
		}
		$subtotalbegbalance =
		  $form->format_amount( \%myconfig, $subtotalbegbalance,
			$form->{precision}, "&nbsp;" );
		$subtotalendbalance =
		  $form->format_amount( \%myconfig, $subtotalendbalance,
			$form->{precision}, "&nbsp;" );
		$subtotaldebit =
		  $form->format_amount( \%myconfig, $subtotaldebit, $form->{precision},
			"&nbsp;" );
		$subtotalcredit =
		  $form->format_amount( \%myconfig, $subtotalcredit, $form->{precision},
			"&nbsp;" );
		$column_data{description} =
		  "<th class=listsubtotal>$subtotaldescription</th>";
		$column_data{begbalance} =
		  "<th align=right class=listsubtotal>$subtotalbegbalance</th>";
		$column_data{endbalance} =
		  "<th align=right class=listsubtotal>$subtotalendbalance</th>";
		$column_data{debit} =
		  "<th align=right class=listsubtotal>$subtotaldebit</th>";
		$column_data{credit} =
		  "<th align=right class=listsubtotal>$subtotalcredit</th>";

		print qq|
    <tr class=listsubtotal>
|;
		for (@column_index) { print "$column_data{$_}\n" }

		print qq|
    </tr>
|;
	}

	$totaldebit =
	  $form->format_amount( \%myconfig, $totaldebit, $form->{precision},
		"&nbsp;" );
	$totalcredit =
	  $form->format_amount( \%myconfig, $totalcredit, $form->{precision},
		"&nbsp;" );

	for (qw(accno description begbalance endbalance)) {
		$column_data{$_} = "<th>&nbsp;</th>";
	}

	$column_data{debit} = qq|<th align=right class=listtotal>$totaldebit</th>|;
	$column_data{credit} =
	  qq|<th align=right class=listtotal>$totalcredit</th>|;

	print qq|
        <tr class=listtotal>
|;

	for (@column_index) { print "$column_data{$_}\n" }

	print qq|
	</tr>
      </table>
    </td>
  </tr>
  <tr>
    <td><hr size=3 noshade></td>
  </tr>
</table>

</body>
</html>
|;

}

sub generate_ar_aging {

	$form->isvaldate( \%myconfig, $form->{todate},
		$locale->text('Invalid to date ...') );

	# split customer
	my @values = split( /--/, $form->{customer} );
	$form->{customer_id} = $values[1];
	( $form->{customer} ) = split( /--/, $form->{customer} );
	$customer = $form->escape( $form->{customer}, 1 );

	$title = $form->escape( $form->{title}, 1 );
	$media = $form->escape( $form->{media}, 1 );

	$form->{vc}   = "customer";
	$form->{arap} = "ar";

	$form->{initcallback} =
	  qq|$form->{script}?action=generate_ar_aging&todate=$form->{todate}|;

	RP->aging( \%myconfig, \%$form );

	&aging;

}

sub generate_ap_aging {

	$form->isvaldate( \%myconfig, $form->{todate},
		$locale->text('Invalid to date ...') );

	# split vendor
	( $form->{vendor} ) = split( /--/, $form->{vendor} );
	$vendor = $form->escape( $form->{vendor}, 1 );
	$title  = $form->escape( $form->{title},  1 );
	$media  = $form->escape( $form->{media},  1 );

	$form->{vc}   = "vendor";
	$form->{arap} = "ap";

	$form->{initcallback} =
	  qq|$form->{script}?action=generate_ap_aging&todate=$form->{todate}|;

	RP->aging( \%myconfig, \%$form );

	&aging;

}

sub aging {

	$form->isvaldate( \%myconfig, $form->{fromdate},
		$locale->text('Invalid from date ...') );
	$form->isvaldate( \%myconfig, $form->{todate},
		$locale->text('Invalid to date ...') );

	$form->{callback} = $form->{initcallback};
	for (qw(path login type format summary)) {
		$form->{callback} .= "&$_=$form->{$_}";
	}
	for (qw(title media report)) {
		$form->{callback} .= qq|&$_=| . $form->escape( $form->{$_}, 1 );
	}
	$form->{callback} .=
	  qq|&$form->{vc}=| . $form->escape( $form->{"$form->{vc}"}, 1 );
	$form->{selectprinter} = "";
	for ( @{ $form->{all_printer} } ) {
		$form->{selectprinter} .= "$_->{printer}\n";
	}
	chomp $form->{selectprinter};

	%vc_ids = ();
	$form->{curr} = "";

	$form->header;

	$vcnumber =
	  ( $form->{vc} eq 'customer' )
	  ? $locale->text('Customer Number')
	  : $locale->text('Vendor Number');

	$form->{allbox} = ( $form->{allbox} ) ? "checked" : "";
	$action = ( $form->{deselect} ) ? "deselect_all" : "select_all";
	$column_header{ndx} =
qq|<th class=listheading width=1%><input name="allbox" type=checkbox class=checkbox value="1" $form->{allbox} onChange="CheckAll(); javascript:document.forms[0].submit()"><input type=hidden name=action value="$action"></th>|;
	$column_header{vc} =
	    qq|<th class=listheading width=60%>|
	  . $locale->text( ucfirst $form->{vc} )
	  . qq|</th>|;
	$column_header{"$form->{vc}number"} =
	  qq|<th class=listheading>$vcnumber</th>|;
	$column_header{language} =
	  qq|<th class=listheading>| . $locale->text('Language') . qq|</th>|;
	$column_header{invnumber} =
	  qq|<th class=listheading>| . $locale->text('Invoice') . qq|</th>|;
	$column_header{ordnumber} =
	  qq|<th class=listheading>| . $locale->text('Order') . qq|</th>|;
	$column_header{transdate} =
	  qq|<th class=listheading nowrap>| . $locale->text('Date') . qq|</th>|;
	$column_header{duedate} =
	  qq|<th class=listheading nowrap>| . $locale->text('Due Date') . qq|</th>|;
	$column_header{c0} =
	    qq|<th class=listheading width=10% nowrap>|
	  . $locale->text('Current')
	  . qq|</th>|;
	$column_header{c15} = qq|<th class=listheading width=10% nowrap>15</th>|;
	$column_header{c30} = qq|<th class=listheading width=10% nowrap>30</th>|;
	$column_header{c45} = qq|<th class=listheading width=10% nowrap>45</th>|;
	$column_header{c60} = qq|<th class=listheading width=10% nowrap>60</th>|;
	$column_header{c75} = qq|<th class=listheading width=10% nowrap>75</th>|;
	$column_header{c90} = qq|<th class=listheading width=10% nowrap>90</th>|;
	$column_header{total} =
	    qq|<th class=listheading width=10% nowrap>|
	  . $locale->text('Total')
	  . qq|</th>|;

	@column_index = qw(ndx vc);
	push @column_index, "$form->{vc}number";

	if ( @{ $form->{all_language} } && $form->{arap} eq 'ar' ) {
		push @column_index, "language";
		$form->{selectlanguage} = qq|\n|;

		for ( @{ $form->{all_language} } ) {
			$form->{selectlanguage} .= qq|$_->{code}--$_->{description}\n|;
		}
	}

	if ( !$form->{summary} ) {
		push @column_index, qw(invnumber ordnumber transdate duedate);
	}

	@c = qw(c0 c15 c30 c45 c60 c75 c90);

	for (@c) {
		if ( $form->{$_} ) {
			push @column_index, $_;
			$form->{callback} .= "&$_=$form->{$_}";
		}
	}

	push @column_index, "total";

	$option = $locale->text('Aged');
	if ( $form->{overdue} ) {
		$option = $locale->text('Aged Overdue');
		$form->{callback} .= "&overdue=$form->{overdue}";
	}

	if ( $form->{department} ) {
		$option .= "\n<br>" if $option;
		($department) = split /--/, $form->{department};
		$option .= $locale->text('Department') . " : $department";
		$department = $form->escape( $form->{department}, 1 );
		$form->{callback} .= "&department=$department";
	}

	if ( $form->{arap} eq 'ar' ) {
		if ( $form->{customer} ) {
			$option .= "\n<br>" if $option;
			$option .= $form->{customer};
		}
	}
	if ( $form->{arap} eq 'ap' ) {
		shift @column_index;
		if ( $form->{vendor} ) {
			$option .= "\n<br>" if $option;
			$option .= $form->{vendor};
		}
	}

	$todate = $locale->date( \%myconfig, $form->{todate}, 1 );
	$option .= "\n<br>" if $option;
	$option .=
	  $locale->text('for Period') . " " . $locale->text('To') . " $todate";

	$title = "$form->{title} / $form->{company}";

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
<!-- $form->{debug_msg} -->
<form method=post action=$form->{script}>

<table width=100%>
  <tr>
    <th class=listtop>$title</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <td>$option</td>
  </tr>
  <tr>
    <td>
      <table width=100%>
|;

	$vc_id = 0;
	$i     = 0;
	$k     = 0;
	$l     = $#{ $form->{AG} };

	$callback = $form->escape( $form->{callback}, 1 );

	foreach $ref ( @{ $form->{AG} } ) {

		if ( $curr ne $ref->{curr} ) {
			$vc_id = 0;
			for (@column_index) { $column_data{$_} = qq|<th>&nbsp;</th>| }
			if ($curr) {

				for (@c) {
					$column_data{$_} = qq|<th align=right>|
					  . $form->format_amount( \%myconfig, $c{$_}{total},
						$form->{precision}, "&nbsp" )
					  . qq|</th>|;
					$c{$_}{total}    = 0;
					$c{$_}{subtotal} = 0;
				}

				$column_data{total} = qq|<th align=right>|
				  . $form->format_amount( \%myconfig, $total,
					$form->{precision}, "&nbsp" )
				  . qq|</th>|;

				for (qw(vc ndx language)) {
					$column_data{$_} = qq|<td>&nbsp;</td>|;
				}
				print qq|
	<tr class=listtotal>
|;

				for (@column_index) { print "$column_data{$_}\n" }

				print qq|
	  </tr>
|;

				$total = 0;

			}

			$form->{curr} .= "$ref->{curr} ";

			print qq|
        <tr>
	  <td></td>
	  <th>$ref->{curr}</th>
	</tr>

	<tr class=listheading>
|;

			for (@column_index) { print "$column_header{$_}\n" }

			print qq|
	</tr>
|;
		}

		$curr = $ref->{curr};
		$k++;

		if ( $vc_id != $ref->{vc_id} ) {
			$i++;

			$column_data{vc} =
qq|<td><a href=ct.pl?path=$form->{path}&login=$form->{login}&action=edit&id=$ref->{vc_id}&db=$form->{vc}&callback=$callback>$ref->{name}</a></td>|;
			$column_data{"$form->{vc}number"} =
			  qq|<td>$ref->{"$form->{vc}number"}</td>|;

			if ( $form->{selectlanguage} ) {
				if (
					exists $form->{"language_code_$ref->{curr}_$ref->{vc_id}"} )
				{
					$ref->{language_code} =
					  $form->{"language_code_$ref->{curr}_$ref->{vc_id}"};
				}

				$column_data{language} =
qq|<td><select name="language_code_$ref->{curr}_$ref->{vc_id}">|
				  . $form->select_option( $form->{selectlanguage},
					$ref->{language_code}, undef, 1 )
				  . qq|</select></td>|;
			}

			$checked = ( $ref->{checked} ) ? "checked" : "";
			$column_data{ndx} =
qq|<td><input name="ndx_$ref->{curr}_$ref->{vc_id}" type=checkbox class=checkbox value=1 $checked></td>|;

			$vc_ids{"$ref->{vc_id}"} = 1;

			$linetotal = 0;

		}

		$vc_id = $ref->{vc_id};

		for (@c) {

			$ref->{$_} = $form->round_amount( $ref->{$_} / $ref->{exchangerate},
				$form->{precision} );

			$c{$_}{total}    += $ref->{$_};
			$c{$_}{subtotal} += $ref->{$_};
			$linetotal       += $ref->{$_};
			$total           += $ref->{$_};

			$column_data{$_} = qq|<td align=right>|
			  . $form->format_amount( \%myconfig, $ref->{$_},
				$form->{precision}, "&nbsp;" )
			  . qq|</td>|;

		}

		$column_data{total} = qq|<td align=right>|
		  . $form->format_amount( \%myconfig, $linetotal, $form->{precision},
			"&nbsp;" )
		  . qq|</td>|;

		$href =
qq|$ref->{module}.pl?path=$form->{path}&action=edit&id=$ref->{id}&login=$form->{login}&callback=|
		  . $form->escape( $form->{callback} );

		$column_data{invnumber} =
		  qq|<td><a href=$href>$ref->{invnumber}</a></td>|;
		$column_data{ordnumber} = qq|<td>$ref->{ordnumber}</td>|;
		for (qw(transdate duedate)) {
			$column_data{$_} = qq|<td nowrap>$ref->{$_}</td>|;
		}

		if ( !$form->{summary} ) {

			$j++;
			$j %= 2;
			print qq|
        <tr class=listrow$j>
|;

			for (@column_index) { print "$column_data{$_}\n" }

			print qq|
        </tr>
|;

			for (qw(vc ndx language)) { $column_data{$_} = qq|<td>&nbsp;</td>| }

		}

		# print subtotal
		if ( $l > 0 ) {
			if ( $k <= $l ) {
				$nextid   = $form->{AG}->[$k]->{vc_id};
				$nextcurr = $form->{AG}->[$k]->{curr};
			}
			else {
				$nextid   = 0;
				$nextcurr = "";
			}
		}

		if ( $vc_id != $nextid || $curr ne $nextcurr ) {

			for (@c) {
				$c{$_}{subtotal} =
				  $form->format_amount( \%myconfig, $c{$_}{subtotal},
					$form->{precision}, "&nbsp" );
			}

			if ( $form->{summary} ) {
				for (@c) {
					$column_data{$_} =
					  qq|<td align=right>$c{$_}{subtotal}</th>|;
					$c{$_}{subtotal} = 0;
				}

				$j++;
				$j %= 2;
				print qq|
      <tr class=listrow$j>
|;

				for (@column_index) { print "$column_data{$_}\n" }

				print qq|
      </tr>
|;

			}
			else {

				for (@column_index) { $column_data{$_} = qq|<th>&nbsp;</th>| }

				for (@c) {
					$column_data{$_} =
qq|<th class=listsubtotal align=right>$c{$_}{subtotal}</th>|;
					$c{$_}{subtotal} = 0;
				}

				# print subtotals
				print qq|
      <tr class=listsubtotal>
|;
				for (@column_index) { print "$column_data{$_}\n" }

				print qq|
      </tr>
|;

			}
		}
	}

	print qq|
        </tr>
        <tr class=listtotal>
|;

	for (@column_index) { $column_data{$_} = qq|<th>&nbsp;</th>| }

	for (@c) {
		$column_data{$_} = qq|<th align=right class=listtotal>|
		  . $form->format_amount( \%myconfig, $c{$_}{total}, $form->{precision},
			"&nbsp;" )
		  . qq|</th>|;
	}

	$column_data{total} =
	    qq|<th align=right class=listtotal>|
	  . $form->format_amount( \%myconfig, $total, $form->{precision}, "&nbsp;" )
	  . qq|</th>|;

	for (@column_index) { print "$column_data{$_}\n" }

	print qq|
	</tr>
      </table>
    </td>
  </tr>

  <tr>
    <td>
|;

	&print_options if ( $form->{arap} eq 'ar' );

	print qq|
    </td>
  </tr>
  <tr>
    <td><hr size=3 noshade></td>
  </tr>
</table>
|;

	$form->{todate} = $temp{todate};

	$form->{vc_ids} = join ' ', ( keys %vc_ids );
	chop $form->{curr};

	$form->hide_form(
		qw(todate title summary overdue callback arap vc department path login type report vc_ids curr)
	);
	$form->hide_form(
		qw(todate title summary overdue callback initcallback arap vc department path login type report vc_ids curr)
	);
	$form->hide_form( @c, "$form->{vc}" );

	if ( $form->{arap} eq 'ar' ) {

		%button = (
			'Select all' =>
			  { ndx => 1, key => 'A', value => $locale->text('Select all') },
			'Deselect all' =>
			  { ndx => 2, key => 'A', value => $locale->text('Deselect all') },
			'Print' =>
			  { ndx => 3, key => 'P', value => $locale->text('Print') },
			'E-mail' =>
			  { ndx => 5, key => 'E', value => $locale->text('E-mail') },
		);

		if ( $form->{deselect} ) {
			delete $button{'Select all'};
		}
		else {
			delete $button{'Deselect all'};
		}

		for ( sort { $button{$a}->{ndx} <=> $button{$b}->{ndx} } keys %button )
		{
			$form->print_button( \%button, $_ );
		}

	}

	if ( $form->{menubar} ) {
		require "$form->{path}/menu.pl";
		&menubar;
	}

	print qq|
</form>

</body>
</html>
|;

}

sub select_all { &{"select_all_$form->{type}"} }

sub select_all_statement {

	RP->aging( \%myconfig, \%$form );

	for ( @{ $form->{AG} } ) { $_->{checked} = "checked" }
	$form->{allbox}   = "checked";
	$form->{deselect} = 1;

	&aging;

}

sub select_all_reminder {

	RP->reminder( \%myconfig, \%$form );

	for ( @{ $form->{AG} } ) { $form->{"ndx_$_->{id}"} = "checked" }
	$form->{allbox}   = "checked";
	$form->{deselect} = 1;

	&reminder;

}

sub deselect_all { &{"deselect_all_$form->{type}"} }

sub deselect_all_statement {

	RP->aging( \%myconfig, \%$form );

	for ( @{ $form->{AG} } ) { $_->{checked} = "" }
	$form->{allbox} = "";

	&aging;

}

sub deselect_all_reminder {

	RP->reminder( \%myconfig, \%$form );

	for ( @{ $form->{AG} } ) { $_->{checked} = "" }
	$form->{allbox} = "";

	&reminder;

}

sub generate_reminder {

	# split customer
	my @values = split( /--/, $form->{customer} );
	$form->{customer_id} = $values[1];
	( $form->{customer} ) = split( /--/, $form->{customer} );
	$form->{vc}   = "customer";
	$form->{arap} = "ar";

	$form->{initcallback} = qq|$form->{script}?action=generate_reminder|;

	RP->reminder( \%myconfig, \%$form );

	&reminder;

	if ( -f "$spool/$form->{login}_reminders.pdf" ) {
		print
qq|<a href="$spool/$form->{login}_reminders.pdf">Download reminders pdf</a>|;
	}
}

sub export_as_csv {
	if ( $form->{type} eq "reminder" ) {

		# Export reminders as csv file

		# split customer
		my @values = split( /--/, $form->{customer} );
		$form->{customer_id} = $values[1];
		( $form->{customer} ) = split( /--/, $form->{customer} );
		$form->{vc}   = "customer";
		$form->{arap} = "ar";

		$form->{initcallback} = qq|$form->{script}?action=generate_reminder|;

		RP->reminder( \%myconfig, \%$form );

		$filename = 'rp';
		my $aaname;
		do { $aaname = tmpnam() }
		  until $fh = IO::File->new( $aaname, O_RDWR | O_CREAT | O_EXCL );
		open( CSVFILE, ">$aaname" ) || $form->error('Cannot create csv file');

		$vcnumber                      = $locale->text('Customer Number');
		$column_header{vc}             = $locale->text( ucfirst $form->{vc} );
		$column_header{number}         = $vcnumber;
		$column_header{level}          = $locale->text('Level');
		$column_header{language}       = $locale->text('Language');
		$column_header{invnumber}      = $locale->text('Invoice');
		$column_header{invdescription} = $locale->text('Description');
		$column_header{ordnumber}      = $locale->text('Order');
		$column_header{transdate}      = $locale->text('Date');
		$column_header{duedate}        = $locale->text('Due Date');
		$column_header{due}            = $locale->text('Due');
		$column_header{curr}           = $locale->text('Currency');

		push @column_index,
		  qw(vc number level language invnumber invdescription ordnumber transdate duedate due curr);

		# Write header line
		for (@column_index) { print CSVFILE "\"$column_header{$_}\"," }
		print CSVFILE "\n";

		# Write data TODO
		for $ref ( @{ $form->{AG} } ) {
			if ( $form->{"ndx_$ref->{id}"} ) {

				# Data line
				$column_data{vc} = CSV->escape_csv( $ref->{name} );
				$column_data{number} =
				  CSV->escape_csv( $ref->{"$form->{vc}number"} );

				if ( exists $form->{"level_$ref->{id}"} ) {
					$ref->{level} = $form->{"level_$ref->{id}"};
				}
				$column_data{level} = $ref->{level};

				if ( $form->{selectlanguage} ) {
					if ( exists $form->{"language_code_$ref->{id}"} ) {
						$ref->{language_code} =
						  $form->{"language_code_$ref->{id}"};
					}
					$column_data{language} = $ref->{language_code};
				}

				$column_data{invnumber} = CSV->escape_csv( $ref->{invnumber} );
				$column_data{ordnumber} = CSV->escape_csv( $ref->{ordnumber} );
				$column_data{invdescription} =
				  CSV->escape_csv( $ref->{invdescription} );

				for (qw(transdate duedate)) {
					$column_data{$_} = CSV->escape_csv( $ref->{$_} );
				}

				$column_data{due} =
				  $form->format_amount( \%myconfig,
					$ref->{due} / $ref->{exchangerate},
					$form->{precision} );
				$column_data{curr} = $ref->{curr};

				for (@column_index) { print CSVFILE "\"$column_data{$_}\"," }
				print CSVFILE "\n";
			}
		}

		# write csv end
		close(CSVFILE) || $form->error('Cannot close csv file');

		my @fileholder;
		open( DLFILE, qq|<$aaname| )
		  || $form->error('Cannot open file for download');
		@fileholder = <DLFILE>;
		close(DLFILE) || $form->error('Cannot close file opened for download');
		my $dlfile = $filename . ".csv";
		print "Content-Type: application/csv\n";
		print "Content-Disposition:attachment; filename=$dlfile\n\n";
		print @fileholder;
		unlink($aaname) or die "Couldn't unlink $name : $!";
	}
}

sub reminder {

	$form->{callback} = $form->{initcallback};
	for (qw(path login type format)) { $form->{callback} .= "&$_=$form->{$_}" }
	for (qw(title media report)) {
		$form->{callback} .= qq|&$_=| . $form->escape( $form->{$_}, 1 );
	}
	$form->{callback} .=
	  qq|&$form->{vc}=| . $form->escape( $form->{"$form->{vc}"}, 1 );

	$vcnumber = $locale->text('Customer Number');

	$form->{allbox} = ( $form->{allbox} ) ? "checked" : "";
	$action = ( $form->{deselect} ) ? "deselect_all" : "select_all";
	$column_header{ndx} =
qq|<th class=listheading width=1%><input name="allbox" type=checkbox class=checkbox value="1" $form->{allbox} onChange="CheckAll(); javascript:document.forms[0].submit()"><input type=hidden name=action value="$action"></th>|;
	$column_header{vc} =
	    qq|<th class=listheading width=60%>|
	  . $locale->text( ucfirst $form->{vc} )
	  . qq|</th>|;
	$column_header{"$form->{vc}number"} =
	  qq|<th class=listheading>$vcnumber</th>|;
	$column_header{level} =
	  qq|<th class=listheading>| . $locale->text('Level') . qq|</th>|;
	$column_header{language} =
	  qq|<th class=listheading>| . $locale->text('Language') . qq|</th>|;
	$column_header{invnumber} =
	  qq|<th class=listheading>| . $locale->text('Invoice') . qq|</th>|;
	$column_header{invdescription} =
	  qq|<th class=listheading>| . $locale->text('Description') . qq|</th>|;
	$column_header{ordnumber} =
	  qq|<th class=listheading>| . $locale->text('Order') . qq|</th>|;
	$column_header{transdate} =
	  qq|<th class=listheading nowrap>| . $locale->text('Date') . qq|</th>|;
	$column_header{duedate} =
	  qq|<th class=listheading nowrap>| . $locale->text('Due Date') . qq|</th>|;
	$column_header{duedays} =
	  qq|<th class=listheading nowrap>| . $locale->text('Due Days') . qq|</th>|;
	$column_header{due} =
	  qq|<th class=listheading nowrap>| . $locale->text('Due') . qq|</th>|;

	@column_index = qw(ndx vc);
	push @column_index, "$form->{vc}number";
	push @column_index, "level";

	$form->{selectlevel} = "\n1\n2\n3";

	if ( @{ $form->{all_language} } ) {
		push @column_index, "language";
		$form->{selectlanguage} = qq|\n|;
		$form->{language_code} ||= "";

		for ( @{ $form->{all_language} } ) {
			$form->{selectlanguage} .= qq|$_->{code}--$_->{description}\n|;
		}
	}

	push @column_index,
	  qw(invnumber invdescription ordnumber transdate duedate duedays due);

	if ( $form->{department} ) {
		$option .= "\n<br>" if $option;
		($department) = split /--/, $form->{department};
		$option .= $locale->text('Department') . " : $department";
		$department = $form->escape( $form->{department}, 1 );
		$form->{callback} .= "&department=$department";
	}

	if ( $form->{customer} ) {
		$option .= "\n<br>" if $option;
		$option .= $form->{customer};
	}
	if ( $form->{duedateto} ) {
		$option .= "\n<br>" if $option;
		$option .= $locale->text("Due Date") . " : " . $form->{duedateto};
	}

	$title = "$form->{title} / $form->{company}";

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
    <th class=listtop>$title</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <td>$option</td>
  </tr>
  <tr>
    <td>
      <table width=100%>
|;

	$curr = "";
	$form->{ids} = "";

	$callback = $form->escape( $form->{callback}, 1 );

	for $ref ( @{ $form->{AG} } ) {

		if ( $curr ne $ref->{curr} ) {

			for (@column_index) { $column_data{$_} = qq|<th>&nbsp;</th>| }

			if ($curr) {

				print qq|
	<tr class=listtotal>
|;

				for (@column_index) { print "$column_data{$_}\n" }

				print qq|
	  </tr>
|;
			}

			print qq|
        <tr>
	  <td></td>
	  <th>$ref->{curr}</th>
	</tr>

	<tr class=listheading>
|;

			for (@column_index) { print "$column_header{$_}\n" }

			print qq|
	</tr>
|;
		}

		$curr = $ref->{curr};

		$column_data{vc} =
qq|<td><a href=ct.pl?path=$form->{path}&login=$form->{login}&action=edit&id=$ref->{vc_id}&db=$form->{vc}&callback=$callback>$ref->{name}</a></td>
    <input type=hidden name="vc_$ref->{id}" value="$ref->{vc_id}">|;

		$column_data{"$form->{vc}number"} =
		  qq|<td>$ref->{"$form->{vc}number"}</td>|;

		if ( exists $form->{"level_$ref->{id}"} ) {
			$ref->{level} = $form->{"level_$ref->{id}"};
		}
		$column_data{level} =
		    qq|<td><select name="level_$ref->{id}">|
		  . $form->select_option( $form->{selectlevel}, $ref->{level} )
		  . qq|</select></td>|;

		if ( $form->{selectlanguage} ) {
			if ( exists $form->{"language_code_$ref->{id}"} ) {
				$ref->{language_code} = $form->{"language_code_$ref->{id}"};
			}

			$column_data{language} =
			  qq|<td><select name="language_code_$ref->{id}">|
			  . $form->select_option( $form->{selectlanguage},
				$ref->{language_code}, undef, 1 )
			  . qq|</select></td>|;
		}

		$checked = ( $form->{"ndx_$ref->{id}"} ) ? "checked" : "";
		$column_data{ndx} =
qq|<td><input name="ndx_$ref->{id}" type=checkbox class=checkbox value=1 $checked></td>|;

		$form->{ids} .= "$ref->{id} ";

		$href =
qq|$ref->{module}.pl?path=$form->{path}&action=edit&id=$ref->{id}&login=$form->{login}&callback=|
		  . $form->escape( $form->{callback} );

		$column_data{invnumber} =
		  qq|<td nowrap><a href=$href>$ref->{invnumber}</a></td>|;
		$column_data{ordnumber} = qq|<td nowrap>$ref->{ordnumber}</td>|;
		$column_data{invdescription} =
		  qq|<td nowrap>$ref->{invdescription}</td>|;
		for (qw(transdate duedate)) {
			$column_data{$_} = qq|<td nowrap>$ref->{$_}</td>|;
		}
		for (qw(duedays)) {
			$column_data{$_} = qq|<td nowrap align="right">$ref->{$_}</td>|;
		}

		$column_data{due} = qq|<td align=right nowrap>|
		  . $form->format_amount( \%myconfig,
			$ref->{due} / $ref->{exchangerate},
			$form->{precision} )
		  . qq|</td>|;

		$j++;
		$j %= 2;
		print qq|
      <tr class=listrow$j>
|;

		for (@column_index) { print "$column_data{$_}\n" }

		print qq|
      </tr>
|;

		for (qw(vc ndx language level)) {
			$column_data{$_} = qq|<td>&nbsp;</td>|;
		}
		$column_data{"$form->{vc}number"} = qq|<td>&nbsp;</td>|;

	}

	print qq|
        </tr>
        <tr class=listtotal>
|;

	for (@column_index) { $column_data{$_} = qq|<th>&nbsp;</th>| }
	for (@column_index) { print "$column_data{$_}\n" }

	print qq|
	</tr>
      </table>
    </td>
  </tr>

  <tr>
    <td>
|;

	&print_options;

	print qq|
    </td>
  </tr>
  <tr>
    <td><hr size=3 noshade></td>
  </tr>
</table>
|;

	chop $form->{ids};

	$form->hide_form(
		qw(title initcallback callback vc department path login ids duedateto));
	$form->hide_form( $form->{vc} );
	$form->hide_form(qw(type report));

	%button = (
		'Select all' =>
		  { ndx => 1, key => 'A', value => $locale->text('Select all') },
		'Deselect all' =>
		  { ndx => 2, key => 'A', value => $locale->text('Deselect all') },
		'Preview' =>
		  { ndx => 3, key => 'V', value => $locale->text('Preview') },
		'Print'  => { ndx => 4, key => 'P', value => $locale->text('Print') },
		'E-mail' => { ndx => 5, key => 'E', value => $locale->text('E-mail') },
		'Save Level' =>
		  { ndx => 6, key => 'L', value => $locale->text('Save Level') },
		'Export as CSV' =>
		  { ndx => 7, key => 'X', value => $locale->text('Export as CSV') },
	);

	if ( $form->{deselect} ) {
		delete $button{'Select all'};
	}
	else {
		delete $button{'Deselect all'};
	}

	for ( sort { $button{$a}->{ndx} <=> $button{$b}->{ndx} } keys %button ) {
		$form->print_button( \%button, $_ );
	}

	if ( $form->{menubar} ) {
		require "$form->{path}/menu.pl";
		&menubar;
	}

	print qq|
</form>

</body>
</html>
|;

}

sub save_level {

	if ( RP->save_level( \%myconfig, \%$form ) ) {
		$form->redirect;
	}

	$form->error( $locale->text('Could not save reminder level!') );

}

sub print_options {

	$form->{copies} ||= 1;
	$form->{PD}{ $form->{type} } = "selected";

	if ( $myconfig{printer} ) {
		$form->{format} ||= "postscript";
	}
	else {
		$form->{format} ||= "pdf";
	}
	$form->{media} ||= $myconfig{printer};

	$form->{sendmode} = "attachment";
	$form->{format} = "pdf" if ( $latex && $form->{media} eq 'email' );

	if ( $form->{media} eq 'email' ) {
		$media = qq|<select name=sendmode>
	    <option value=attachment>| . $locale->text('Attachment') . qq|
	    <option value=inline>| . $locale->text('In-line') . qq|</select>|;

		if ( $form->{selectlanguage} ) {
			$lang = qq|<select name="language_code">|
			  . $form->select_option(
				$form->{selectlanguage},
				$form->{language_code},
				undef, 1
			  ) . qq|</select>|;
		}
	}
	else {
		$media = qq|<select name=media>
	    <option value=screen>| . $locale->text('Screen');
		$media .= qq|
            <option value="queue">| . $locale->text('Queue');

		if ( %printer && $latex ) {
			for ( sort keys %printer ) {
				$media .= qq|
            <option value="$_">$_|;
			}
		}
	}

	$format = qq|<select name=format>
            <option value="html">html|;

	$formname{statement} = $locale->text('Statement');
	$formname{reminder}  = $locale->text('Reminder');

	$type = qq|<select name=type>
	    <option value="$form->{type}" $form->{PD}{$form->{type}}>$formname{$form->{type}}
	    </select>|;

	$media .= qq|</select>|;
	$media =~ s/(<option value="\Q$form->{media}\E")/$1 selected/;

	if ($latex) {
		$format .= qq|
	    <option value="pdf">| . $locale->text('PDF');
	}

	$format .= qq|</select>|;
	$format =~ s/(<option value="\Q$form->{format}\E")/$1 selected/;

	print qq|
<table>
  <tr>
    <td>$type</td>
    <td>$lang</td>
    <td>$format</td>
    <td>$media</td>
|;

	if ( %printer && $latex && $form->{media} ne 'email' ) {
		print qq|
      <td nowrap>| . $locale->text('Copies') . qq|
      <input name=copies size=2 value=$form->{copies}></td>
|;
	}

	print qq|
  <th><input type=checkbox name=create_single_pdf value=1> |
	  . $locale->text("Create single PDF")
	  . qq|</th>
|;

	$form->{selectlanguage} = $form->escape( $form->{selectlanguage}, 1 );
	$form->hide_form(qw(selectlanguage));

	print qq|
  </tr>
</table>
|;

}

sub e_mail { &{"e_mail_$form->{type}"} }

sub e_mail_statement {

	# get name and email addresses
	@vc_ids = split / /, $form->{vc_ids};
	$found = 0;
	for $curr ( split / /, $form->{curr} ) {
		for (@vc_ids) {
			if ( $form->{"ndx_${curr}_$_"} ) {
				$form->{"$form->{vc}_id"} = $_;
				$found++;
			}
		}
	}

	$form->error( $locale->text('Can only send one statement at a time!') )
	  if $found > 1;

	for $curr ( split / /, $form->{curr} ) {
		for (@vc_ids) {
			if ( $form->{"ndx_${curr}_$_"} ) {
				$form->{"$form->{vc}_id"} = $_;
				$form->{language_code} = $form->{"language_code_${curr}_$_"};
				RP->get_customer( \%myconfig, \%$form );
				$selected = 1;
				last;
			}
		}
	}

	$form->error( $locale->text('Nothing selected!') ) unless $selected;

	if ( $myconfig{role} =~ /(admin|manager)/ ) {
		$bcc = qq|
          <th align=right nowrap=true>| . $locale->text('Bcc') . qq|</th>
	  <td><input name=bcc size=30 value="$form->{bcc}"></td>
|;
	}

	$title = $locale->text('E-mail Statement to') . " $form->{$form->{vc}}";

	&prepare_e_mail;

}

sub e_mail_reminder {

	$found = 0;
	for ( split / /, $form->{ids} ) {
		if ( $form->{"ndx_$_"} ) {
			$found++;
		}
	}

	$form->error( $locale->text('Can only send one reminder at a time!') )
	  if $found > 1;

	# get name and email addresses
	for ( split / /, $form->{ids} ) {
		if ( $form->{"ndx_$_"} ) {
			$form->{"$form->{vc}_id"} = $form->{"vc_$_"};
			$form->{language_code} = $form->{"language_code_$_"};
			RP->get_customer( \%myconfig, \%$form );
			$selected = 1;
			last;
		}
	}

	$form->error( $locale->text('Nothing selected!') ) unless $selected;

	if ( $myconfig{role} =~ /(admin|manager)/ ) {
		$bcc = qq|
          <th align=right nowrap=true>| . $locale->text('Bcc') . qq|</th>
	  <td><input name=bcc size=30 value="$form->{bcc}"></td>
|;
	}

	$title = $locale->text('E-mail Reminder to') . " $form->{$form->{vc}}";

	&prepare_e_mail;

}

sub prepare_e_mail {

	$form->{media} = "email";

	$form->header;

	print qq|
<body>

<form method=post action=$form->{script}>

<table width=100%>
  <tr class=listtop>
    <th>$form->{helpref}$title</a></th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <td>
      <table width=100%>
        <tr>
	  <th align=right nowrap>| . $locale->text('E-mail') . qq|</th>
	  <td><input name=email size=30 value="$form->{email}"></td>
	  <th align=right nowrap>| . $locale->text('Cc') . qq|</th>
	  <td><input name=cc size=30 value="$form->{cc}"></td>
	 </tr>
	<tr>
          <th align=right nowrap>| . $locale->text('Subject') . qq|</th>
	  <td><input name=subject size=30 value="|
	  . $form->quote( $form->{subject} )
	  . qq|"></td>
	  $bcc
	</tr>
      </table>
    </td>
  </tr>
  <tr>
    <td>
      <table width=100%>
        <tr>
	  <th align=left nowrap>| . $locale->text('Message') . qq|</th>
	</tr>
	<tr>
	  <td><textarea name=message rows=15 cols=60 wrap=soft>$form->{message}</textarea></td>
	</tr>
      </table>
    </td>
  </tr>
  <tr>
    <td>
|;

	&print_options;

	$nextsub = "send_email_$form->{type}";

	for (
		qw(language_code email cc bcc subject message type sendmode format action nextsub)
	  )
	{
		delete $form->{$_};
	}

	$form->hide_form;

	print qq|
    </td>
  </tr>
  <tr>
    <td><hr size=3 noshade></td>
  </tr>
</table>

<input type=hidden name=nextsub value="$nextsub">
<br>
<input name=action class=submit type=submit value="|
	  . $locale->text('Continue') . qq|">
</form>

</body>
</html>
|;

}

sub send_email_statement {

	$form->{OUT} = "$sendmail";

	$form->isblank( "email", $locale->text('E-mail address missing!') );

	$todate = $form->{todate} || $form->current_date( \%myconfig );
	$form->{subject} = $locale->text('Statement') . qq| - $todate|
	  unless $form->{subject};

	for $curr ( split / /, $form->{curr} ) {
		for ( split / /, $form->{vc_ids} ) {
			if ( $form->{"ndx_${curr}_$_"} ) {
				$form->{"language_code_${curr}_$_"} = $form->{language_code};
			}
		}
	}

	&print_statement;

	if ( $form->{callback} ) {
		for $curr ( split / /, $form->{curr} ) {
			for ( split / /, $form->{vc_ids} ) {
				if ( $form->{"ndx_${curr}_$_"} ) {
					$form->{callback} .=
					  qq|&ndx_${curr}_$_=1&language_code_${curr}_$_=|
					  . $form->escape( $form->{language_code}, 1 );
				}
			}
		}
	}

	$form->redirect(
		$locale->text('Statement sent to') . " $form->{$form->{vc}}" );

}

sub send_email_reminder {

	$form->{OUT} = "$sendmail";

	$form->isblank( "email", $locale->text('E-mail address missing!') );

	RP->reminder( \%myconfig, \%$form );

	$form->{subject} = $locale->text('Reminder') unless $form->{subject};

	for ( split / /, $form->{ids} ) {
		if ( $form->{"ndx_$_"} ) {
			$form->{"language_code_$_"} = $form->{language_code};
		}
	}

	&print_reminder;

	if ( $form->{callback} ) {
		for ( split / /, $form->{ids} ) {
			if ( $form->{"ndx_$_"} ) {
				$form->{callback} .=
				  qq|&ndx_$_=1&level_$_=$form->{"level_$_"}&language_code_$_=|
				  . $form->escape( $form->{language_code}, 1 );
			}
		}
	}

	$form->redirect(
		$locale->text('Reminder sent to') . " $form->{$form->{vc}}" );

}

sub print { &{"print_$form->{type}"} }

sub print_statement {

	$form->{customer} = "";

	@vc_ids = split / /, $form->{vc_ids};
	for $curr ( split / /, $form->{curr} ) {
		last if $selected;
		for (@vc_ids) {
			if ( $form->{"ndx_${curr}_$_"} ) {
				$selected = "ndx_${curr}_$_";
				last;
			}
		}
	}

	$form->error( $locale->text('Nothing selected!') ) unless $selected;

	if ( $form->{media} eq 'screen' ) {
		for $curr ( split / /, $form->{curr} ) {
			for (@vc_ids) {
				$form->{"ndx_${curr}_$_"} = "";
			}
		}
		$form->{$selected} = 1;
	}

	if ( $form->{media} !~ /(screen|email)/ ) {
		$form->{"$form->{vc}_id"} = "";
		$SIG{INT} = 'IGNORE';
	}

	RP->aging( \%myconfig, \%$form );

	if ( $form->{media} !~ /(screen|email)/ ) {
		$form->{OUT} = qq~| $printer{$form->{media}}~;
	}

	@c    = qw(c0 c15 c30 c45 c60 c75 c90);
	$item = $c[0];
	@{$ag} = ();

	for (@c) {
		if ( $form->{$_} ) {
			$item = $_;
		}
		push @{ $ag{$item} }, $_;
	}

	for ( keys %ag ) {
		shift @{ $ag{$_} };
	}

	for ( keys %ag ) {
		for $item ( @{ $ag{$_} } ) {
			$c{$_} += $c{$item};
		}
	}

	&do_print_statement;

	if ( $form->{callback} ) {
		for $curr ( split / /, $form->{curr} ) {
			for ( split / /, $form->{vc_ids} ) {
				if ( $form->{"ndx_${curr}_$_"} ) {
					$form->{callback} .=
					  qq|&ndx_${curr}_$_=1&language_code_${curr}_$_=|
					  . $form->escape( $form->{"language_code_${curr}_$_"}, 1 );
				}
			}
		}
	}

	$form->redirect( $locale->text('Statements sent to printer!') )
	  if ( $form->{media} !~ /(screen|email)/ );

}

sub print_reminder {

	$form->{customer} = "";

	@ids = split / /, $form->{ids};
	for (@ids) {
		if ( $form->{"ndx_$_"} ) {
			$selected = "ndx_$_";
			$form->{id} = $_;
			last;
		}
	}

	$form->error( $locale->text('Nothing selected!') ) unless $selected;

	if ( $form->{media} eq 'screen' ) {
		for (@ids) {
			$form->{"ndx_$_"} = "";
		}
		$form->{$selected} = 1;
	}

	if ( $form->{media} !~ /(screen|email)/ ) {
		$form->{"$form->{vc}_id"} = "";
		$SIG{INT} = 'IGNORE';
	}

	RP->reminder( \%myconfig, \%$form );
	if ( $form->{media} !~ /(screen|email)/ ) {
		$form->{OUT} = qq~| $printer{$form->{media}}~;
	}

	&do_print_reminder;

	if ( $form->{callback} ) {
		for ( split / /, $form->{ids} ) {
			if ( $form->{"ndx_$_"} ) {
				$form->{callback} .=
				  qq|&ndx_$_=1&level_$_=$form->{"level_$_"}&language_code_$_=|
				  . $form->escape( $form->{"language_code_$_"}, 1 );
			}
		}
	}

	$form->redirect( $locale->text('Reminders sent to printer!') )
	  if ( $form->{media} !~ /(screen|email)/ );

}

sub do_print_reminder {

	my $pdfs;
	my $ids;

	$out = $form->{OUT};

	$form->{todate} ||= $form->current_date( \%myconfig );
	$form->{statementdate} = $locale->date( \%myconfig, $form->{todate}, 1 );

	$form->{templates} = "$myconfig{templates}";

	for (qw(name email)) { $form->{"user$_"} = $myconfig{$_} }

	# setup variables for the form
	$form->format_string(
		qw(companyemail companywebsite company address businessnumber username useremail tel fax)
	);

	@a =
	  qw(id invnumber name address1 address2 city state zipcode country contact typeofcontact salutation firstname lastname dcn iban rvc membernumber);
	push @a, "$form->{vc}number", "$form->{vc}phone", "$form->{vc}fax",
	  "$form->{vc}taxnumber";
	push @a, 'email' if !$form->{media} eq 'email';
	push @a,
	  map { "shipto$_" }
	  qw(name address1 address2 city state zipcode country contact phone fax email);
	push @a,
	  map { "bank$_" }
	  qw(name address1 address2 city state zipcode country bic);

	my $dbh = $form->dbconnect( \%myconfig );

	while ( @{ $form->{AG} } ) {

		$ref = shift @{ $form->{AG} };
		$form->{OUT} = $out;

		if ( $form->{"ndx_$ref->{id}"} ) {

			# default shipto to main address if shipto address is empty.
			if ( !$ref->{shiptoaddress1} ) {
				for (
					qw(name address1 address2 city state zipcode country contact phone fax email)
				  )
				{
					$ref->{"shipto$_"} = $ref->{$_};
				}
			}
			for (@a) { $form->{$_} = $ref->{$_} }

			if ( $form->{id} && $form->{dcn} eq "<%external%>" ) {
				$query = qq|SELECT dcn FROM ar
              WHERE id = $form->{id}|;
				my $sth = $dbh->prepare($query);
				$sth->execute || $form->dberror($query);
				$form->{dcn} = $sth->fetchrow_array;
				$sth->finish;
			}

			$form->{rvc} = $form->format_dcn( $form->{rvc} );
			$form->{dcn} = $form->format_dcn( $form->{dcn} );

			$form->format_string(@a);

			$form->{IN} = qq|$form->{type}$form->{"level_$ref->{id}"}.html|;

			if ( $form->{format} =~ /(postscript|pdf)/ ) {
				$form->{IN} =~ s/html$/tex/;
			}

			$form->{ $form->{vc} }    = $form->{name};
			$form->{"$form->{vc}_id"} = $ref->{vc_id};
			$form->{language_code}    = $form->{"language_code_$ref->{id}"};
			$form->{currency}         = $ref->{curr};

			for (
				qw(invnumber ordnumber ponumber notes invdate duedate invdescription shippingpoint shipvia waybill)
			  )
			{
				$form->{$_} = ();
			}

			$ref->{invdate} = $ref->{transdate};
			my @a =
			  qw(invnumber ordnumber ponumber notes invdate duedate invdescription shippingpoint shipvia waybill);
			for (@a) { $form->{"${_}_1"} = $ref->{$_} }

			$form->format_string( map { "${_}_1" }
				  qw(invnumber ordnumber ponumber notes invdescription shippingpoint shipvia waybill)
			);
			for (@a) { $form->{$_} = $form->{"${_}_1"} }

			$ref->{exchangerate} ||= 1;
			$form->{due} =
			  $form->format_amount( \%myconfig,
				$ref->{due} / $ref->{exchangerate},
				$form->{precision} );
			$form->{integer_out_amount} = $ref->{integer_out_amount};
			$form->{out_decimal}        = $ref->{out_decimal};

			$form->{formname} = 'reminder';

			if ( $form->{media} eq 'queue' ) {
				($filename) = $dbh->selectrow_array(
					"SELECT spoolfile FROM status WHERE trans_id = $form->{id}"
				);

				if ($filename) {
					unlink "$spool/$filename";
					$filename =~ s/\..*$//g;
				}
				else {
					$filename = time;
					$filename .= int rand 10000;
				}

				$filename .=
				  ( $form->{format} eq 'postscript' ) ? '.ps' : '.pdf';
				$form->{OUT} = ">$spool/$filename";
				$pdfs .= "$spool/$filename ";
				$ids  .= "$form->{id} ";

				# save status
				$form->update_status( \%myconfig );

				%audittrail = (
					tablename => ($order) ? 'oe' : lc $ARAP,
					reference => $form->{"${inv}number"},
					formname  => $form->{formname},
					action    => 'queued',
					id        => $form->{id}
				);
				$dbh->do(
qq|UPDATE status SET spoolfile='$filename' WHERE trans_id = $form->{id}|
				);
			}
			$form->parse_template( \%myconfig, $userspath, $debuglatex );
		}
	}
	if ( $form->{create_single_pdf} ) {
		system(
"/usr/bin/pdftk $pdfs cat output $spool/$form->{login}_reminders.pdf"
		);
		my $dbh = $form->dbconnect( \%myconfig );
		my @ids = split( / /, $ids );
		for (@ids) {
			$dbh->do("UPDATE status SET spoolfile = NULL WHERE trans_id = $_");
		}
		$dbh->disconnect;
	}
	else {
		unlink "$spool/$form->{login}_reminders.pdf";
	}
}

sub do_print_statement {

	$out = $form->{OUT};

	$form->{todate} ||= $form->current_date( \%myconfig );
	$form->{statementdate} = $locale->date( \%myconfig, $form->{todate}, 1 );

	$form->{templates} = "$myconfig{templates}";

	for (qw(name email)) { $form->{"user$_"} = $myconfig{$_} }

	# setup variables for the form
	$form->format_string(
		qw(companyemail companywebsite company address businessnumber username useremail tel fax)
	);

	@a =
	  qw(name address1 address2 city state zipcode country contact typeofcontact salutation firstname lastname);
	push @a, "$form->{vc}number", "$form->{vc}phone", "$form->{vc}fax",
	  "$form->{vc}taxnumber";
	push @a, 'email' if !$form->{media} eq 'email';
	push @a,
	  map { "shipto$_" }
	  qw(name address1 address2 city state zipcode country contact phone fax email);

	$i = 0;
	while ( @{ $form->{AG} } ) {

		$ref = shift @{ $form->{AG} };
		$form->{OUT} = $out;

		if ( $vc_id != $ref->{vc_id} ) {

			if ( $form->{"ndx_$ref->{curr}_$ref->{vc_id}"} ) {

				$vc_id = $ref->{vc_id};

				for (@a) { $form->{$_} = $ref->{$_} }
				$form->format_string(@a);

				$form->{IN} = qq|$form->{type}.html|;

				if ( $form->{format} =~ /(postscript|pdf)/ ) {
					$form->{IN} =~ s/html$/tex/;
				}

				$form->{ $form->{vc} } = $form->{name};
				$form->{"$form->{vc}_id"} = $ref->{vc_id};
				$form->{language_code} =
				  $form->{"language_code_$ref->{curr}_$ref->{vc_id}"};
				$form->{currency} = $ref->{curr};

				for (
					qw(invnumber ordnumber ponumber notes invdate duedate invdescription)
				  )
				{
					$form->{$_} = ();
				}
				$form->{total} = 0;
				foreach $item (qw(c0 c15 c30 c45 c60 c75 c90)) {
					$form->{$item} = ();
					$form->{"${item}total"} = 0;
				}

				&statement_details($ref);

				while ($ref) {

					if ( scalar( @{ $form->{AG} } ) > 0 ) {

						# one or more left to go
						if ( $vc_id == $form->{AG}->[0]->{vc_id} ) {
							$ref = shift @{ $form->{AG} };
							&statement_details($ref)
							  if $ref->{curr} eq $form->{currency};

							# any more?
							$ref = scalar( @{ $form->{AG} } );
						}
						else {
							$ref = 0;
						}
					}
					else {

						# set initial ref to 0
						$ref = 0;
					}

				}

				for ( "c0", "c15", "c30", "c45", "c60", "c75", "c90", "" ) {
					$form->{"${_}total"} =
					  $form->format_amount( \%myconfig, $form->{"${_}total"},
						$form->{precision} );
				}

				$form->parse_template( \%myconfig, $userspath, $debuglatex );

			}
		}
	}

}

sub statement_details {
	my ($ref) = @_;

	$ref->{invdate} = $ref->{transdate};
	my @a =
	  qw(invnumber ordnumber ponumber notes invdate duedate invdescription);
	for (@a) { $form->{"${_}_1"} = $ref->{$_} }
	$form->format_string(
		qw(invnumber_1 ordnumber_1 ponumber_1 notes_1 invdescription_1));
	for (@a) { push @{ $form->{$_} }, $form->{"${_}_1"} }

	foreach $item (qw(c0 c15 c30 c45 c60 c75 c90)) {
		$ref->{exchangerate} ||= 1;
		$ref->{$item} =
		  $form->round_amount( $ref->{$item} / $ref->{exchangerate},
			$form->{precision} );
		$form->{"${item}total"} += $ref->{$item};
		$form->{total} += $ref->{$item};
		push @{ $form->{$item} },
		  $form->format_amount( \%myconfig, $ref->{$item}, $form->{precision} );
	}

}

sub generate_tax_report_all {

	$form->isvaldate( \%myconfig, $form->{fromdate},
		$locale->text('Invalid from date ...') );
	$form->isvaldate( \%myconfig, $form->{todate},
		$locale->text('Invalid to date ...') );

	my $dbh = $form->dbconnect( \%myconfig );

	my $query =
qq|SELECT accno, description FROM chart WHERE link LIKE '%AR_tax%' ORDER BY accno|;
	my $sth = $dbh->prepare($query) || $form->dberror($query);
	$sth->execute;
	my $all_taxaccounts;
	while ( my $ref = $sth->fetchrow_hashref(NAME_lc) ) {
		$all_taxaccounts .= "$ref->{accno} ";
		$form->{"$ref->{accno}_description"} = $ref->{description};
	}
	$sth->finish;
	$dbh->disconnect;

	$form->{alltaxes} = 1;     # Flag to affect layout for all taxes report.
	$search_form = new Form;
	for ( keys %$form ) { $search_form->{$_} = $form->{$_} }
	my $header = 0;

	# AR
	for ( split( / /, $all_taxaccounts ) ) {
		for ( keys %$form ) { delete $form->{$_} }
		for ( keys %$search_form ) { $form->{$_} = $search_form->{$_} }
		$form->{title}   = $locale->text('Tax collected');
		$form->{header}  = $header;
		$form->{nextsub} = 'generate_tax_report';
		$form->{db}      = "ar";
		$form->{accno}   = $_;
		&generate_tax_report;
		$header = 1;
	}
	for ( keys %$form ) { delete $form->{$_} }
	for ( keys %$search_form ) { $form->{$_} = $search_form->{$_} }
	$form->{title}  = $locale->text('Non-taxable Sales');
	$form->{header} = 1;
	delete $form->{accno};
	$form->{report} = 'nontaxable';
	&generate_tax_report;

	# AP
	my $dbh = $form->dbconnect( \%myconfig );
	my $query =
qq|SELECT accno, description FROM chart WHERE link LIKE '%AP_tax%' ORDER BY accno|;
	my $sth = $dbh->prepare($query) || $form->dberror($query);
	$sth->execute;
	my $all_taxaccounts;
	while ( my $ref = $sth->fetchrow_hashref(NAME_lc) ) {
		$all_taxaccounts .= "$ref->{accno} ";
		$search_form->{"$ref->{accno}_description"} = $ref->{description};
	}
	$sth->finish;
	$dbh->disconnect;

	for ( split( / /, $all_taxaccounts ) ) {
		for ( keys %$form ) { delete $form->{$_} }
		for ( keys %$search_form ) { $form->{$_} = $search_form->{$_} }
		$form->{title}   = $locale->text('Tax paid');
		$form->{header}  = $header;
		$form->{nextsub} = 'generate_tax_report';
		$form->{db}      = "ap";
		$form->{accno}   = $_;
		&generate_tax_report;
		$header = 1;
	}
	for ( keys %$form ) { delete $form->{$_} }
	for ( keys %$search_form ) { $form->{$_} = $search_form->{$_} }
	$form->{title}  = $locale->text('Non-taxable Purchases');
	$form->{header} = 1;
	delete $form->{accno};
	$form->{report} = 'nontaxable';
	$form->{db}     = "ap";
	&generate_tax_report;
	print qq|
</table>

</body>
</html>
|;

}

sub generate_tax_report {

	$form->isvaldate( \%myconfig, $form->{fromdate},
		$locale->text('Invalid from date ...') );
	$form->isvaldate( \%myconfig, $form->{todate},
		$locale->text('Invalid to date ...') );

	RP->tax_report( \%myconfig, \%$form );

	$descvar     = "$form->{accno}_description";
	$description = $form->escape( $form->{$descvar} );

	if ( $form->{accno} =~ /^gifi_/ ) {
		$descvar     = "gifi_$form->{accno}_description";
		$description = $form->escape( $form->{$descvar} );
	}

	$department = $form->escape( $form->{department} );

	# construct href
	$href =
"$form->{script}?path=$form->{path}&direction=$form->{direction}&oldsort=$form->{oldsort}&action=generate_tax_report&login=$form->{login}&fromdate=$form->{fromdate}&todate=$form->{todate}&db=$form->{db}&method=$form->{method}&summary=$form->{summary}&accno=$form->{accno}&$descvar=$description&department=$department&report=$form->{report}";

	# construct callback
	$description = $form->escape( $form->{$descvar},   1 );
	$department  = $form->escape( $form->{department}, 1 );

	$form->sort_order();

	$callback =
"$form->{script}?path=$form->{path}&direction=$form->{direction}&oldsort=$form->{oldsort}&action=generate_tax_report&login=$form->{login}&fromdate=$form->{fromdate}&todate=$form->{todate}&db=$form->{db}&method=$form->{method}&summary=$form->{summary}&accno=$form->{accno}&$descvar=$description&department=$department&report=$form->{report}";

	$form->{title} = $locale->text('GIFI') . " - "
	  if ( $form->{accno} =~ /^gifi_/ );

	$title = $form->escape( $form->{title} );
	$href .= "&title=$title";
	$title = $form->escape( $form->{title}, 1 );
	$callback .= "&title=$title";

	$form->{title} =
qq|$form->{title} $form->{"$form->{accno}_description"} / $form->{company}|;

	if ( $form->{db} eq 'ar' ) {
		$name       = $locale->text('Customer');
		$vcnumber   = $locale->text('Customer Number');
		$invoice    = 'is.pl';
		$arap       = 'ar.pl';
		$form->{vc} = "customer";
	}
	if ( $form->{db} eq 'ap' ) {
		$name       = $locale->text('Vendor');
		$vcnumber   = $locale->text('Vendor Number');
		$invoice    = 'ir.pl';
		$arap       = 'ap.pl';
		$form->{vc} = "vendor";
	}

	@columns = qw(id transdate invnumber description name);
	push @columns, "$form->{vc}number";
	push @columns, qw(netamount tax);
	@columns = $form->sort_columns(@columns);

	my @column_index;
	foreach $item (@columns) {
		if ( $form->{"l_$item"} eq "Y" ) {
			push @column_index, $item;

			# add column to href and callback
			$callback .= "&l_$item=Y";
			$href     .= "&l_$item=Y";
		}
	}

	if ( $form->{l_subtotal} eq 'Y' ) {
		$callback .= "&l_subtotal=Y";
		$href     .= "&l_subtotal=Y";
	}

	my $option;
	if ( $form->{department} ) {
		($department) = split /--/, $form->{department};
		$option = $locale->text('Department') . " : $department";
	}

	# if there are any dates
	if ( $form->{fromdate} || $form->{todate} ) {
		if ( $form->{fromdate} ) {
			$fromdate = $locale->date( \%myconfig, $form->{fromdate}, 1 );
		}
		if ( $form->{todate} ) {
			$todate = $locale->date( \%myconfig, $form->{todate}, 1 );
		}

		$form->{period} = "$fromdate - $todate";
	}
	else {
		$form->{period} =
		  $locale->date( \%myconfig, $form->current_date( \%myconfig ), 1 );
	}

	$option .= "<br>" if $option;
	$option .= $locale->text('Cash')    if ( $form->{method} eq 'cash' );
	$option .= $locale->text('Accrual') if ( $form->{method} eq 'accrual' );

	$option .= "<br>$form->{period}";

	$column_header{id} =
	    qq|<th><a class=listheading href=$href&sort=id>|
	  . $locale->text('ID')
	  . qq|</a></th>|;
	$column_header{invnumber} =
	    qq|<th><a class=listheading href=$href&sort=invnumber>|
	  . $locale->text('Invoice')
	  . qq|</a></th>|;
	$column_header{transdate} =
	    qq|<th nowrap><a class=listheading href=$href&sort=transdate>|
	  . $locale->text('Date')
	  . qq|</a></th>|;
	$column_header{netamount} =
	  qq|<th class=listheading>| . $locale->text('Amount') . qq|</th>|;
	$column_header{tax} =
	  qq|<th class=listheading>| . $locale->text('Tax') . qq|</th>|;

	$column_header{name} =
	  qq|<th><a class=listheading href=$href&sort=name>$name</a></th>|;
	$column_header{"$form->{vc}number"} =
qq|<th><a class=listheading href=$href&sort=$form->{vc}number>$vcnumber</a></th>|;

	$column_header{description} =
	    qq|<th><a class=listheading href=$href&sort=description>|
	  . $locale->text('Description')
	  . qq|</a></th>|;

	$option = ''
	  if $form->{header}; # Display report search options for first account only
	if ( $form->{accno} ) {
		$option .= '<br>'
		  . $locale->text('Account')
		  . qq| $form->{accno}--$form->{"$form->{accno}_description"}|;
	}
	else {
		$option .= '<br>' . $form->{title};
	}
	$option .= '<br>' . $locale->text( uc $form->{db} );

	my $header = $form->{header};
	$form->header;
	$form->{title} = $locale->text('Taxes') if $form->{alltaxes};

	print qq|
<body>

|;
	print qq|
<table width=100% class="vat_summary_title_table">
  <tr>
    <th class=listtop colspan=$colspan>$form->{title}</th>
  </tr>
</table>
| if !$header;
	if ( $form->{alltaxes} and !$header ) {

		# Print taxes summary for all taxes report.
		my ( $null, $department_id ) = split /--/, $form->{department};
		my $where = "a.approved = '1'";
		my $cashwhere;

		$where .= qq| AND a.department_id = $department_id| if $department_id;

		my $transdate = "a.transdate";
		if ( $form->{method} eq 'cash' ) {
			$transdate = "a.datepaid";
			$cashwhere = qq| AND a.amount = a.paid|;
		}

		if ( $form->{fromdate} || $form->{todate} ) {
			if ( $form->{fromdate} ) {
				$where .= " AND $transdate >= '$form->{fromdate}'";
			}
			if ( $form->{todate} ) {
				$where .= " AND $transdate <= '$form->{todate}'";
			}
		}

		my $query = qq|
	SELECT 1 as seq, ch.accno, ch.description, SUM(a.netamount) AS netamount, SUM(ac.amount) * 1 AS tax
	FROM acc_trans ac
	JOIN ar a ON (a.id = ac.trans_id)
	JOIN chart ch ON (ch.id = ac.chart_id)
	WHERE $where $cashwhere
	AND ch.accno IN (SELECT accno FROM chart WHERE link LIKE '%AR_tax%')
	GROUP BY seq, ch.accno, ch.description

        UNION ALL

	SELECT 1 AS seq, ch.accno, ch.description, 0 AS netamount, 0 AS tax
	FROM chart ch
	WHERE ch.accno IN (SELECT accno FROM chart WHERE link LIKE '%AR_tax%')
	AND ch.id NOT IN (
		SELECT DISTINCT ac.chart_id
		FROM acc_trans ac
		JOIN ar a ON (a.id = ac.trans_id)
		WHERE $where
	)

	UNION ALL

	SELECT 2 as seq, 'N', 'Non-taxable', SUM(a.netamount), SUM(0)
	FROM ar a
	WHERE $where $cashwhere
	AND a.netamount = a.amount
	GROUP BY 1, 2, 3

	UNION ALL

	SELECT 3 as seq, ch.accno, ch.description, SUM(a.netamount), SUM(ac.amount) * -1 AS tax
	FROM acc_trans ac
	JOIN ap a ON (a.id = ac.trans_id)
	JOIN chart ch ON (ch.id = ac.chart_id)
	WHERE $where $cashwhere
	AND ch.accno IN (SELECT accno FROM chart WHERE link LIKE '%AP_tax%')
	GROUP BY seq, ch.accno, ch.description

        UNION ALL

	SELECT 3 AS seq, ch.accno, ch.description, 0 AS netamount, 0 AS tax
	FROM chart ch
	WHERE ch.accno IN (SELECT accno FROM chart WHERE link LIKE '%AP_tax%')
	AND ch.id NOT IN (
		SELECT DISTINCT ac.chart_id
		FROM acc_trans ac
		JOIN ap a ON (a.id = ac.trans_id)
		WHERE $where
	)

	UNION ALL

	SELECT 4 as seq, 'N', 'Non-taxable', SUM(a.netamount), SUM(0)
	FROM ap a
	WHERE $where $cashwhere
	AND a.netamount = a.amount
	GROUP BY 1, 2, 3

	ORDER BY 1, 2, 3
   |;

		print qq|
     <table width=100% class="vat_summary_table">
	<tr class=listheading>
	  <th>&nbsp;</th>
	  <th>| . $locale->text('Account') . qq|</th>
	  <th>| . $locale->text('Description') . qq|</th>
	  <th>| . $locale->text('Amount') . qq|</th>
	  <th>| . $locale->text('Tax') . qq|</th>
	</tr>|;
		my $dbh = $form->dbconnect( \%myconfig );
		my $sth = $dbh->prepare($query);
		$sth->execute || $form->error($query);

		while ( my $ref = $sth->fetchrow_hashref(NAME_lc) ) {
			$i++;
			$i %= 2;
			print qq|<tr class="listrow$i">|;
			print qq|<td>AR</td>| if $ref->{seq} <= 2;
			print qq|<td>AP</td>| if $ref->{seq} > 2;
			print qq|<td>$ref->{accno}</td>|;
			print qq|<td>$ref->{description}</td>|;
			print qq|<td align=right>|
			  . $form->format_amount( \%myconfig, $ref->{netamount},
				$form->{precision} )
			  . qq|</td>|;
			print qq|<td align=right>|
			  . $form->format_amount( \%myconfig, $ref->{tax},
				$form->{precision} )
			  . qq|</td>|;
			print qq|</tr>|;
		}
		$sth->finish;
		$dbh->disconnect;
		print qq|
     </table>
     <table width=100% class="vat_details_table">|;
	}    # ($form->{alltaxes} and !$header)

	print qq|<table width=100%>| if !$form->{alltaxes};
	print qq|
  <tr height="5"></tr>
  <tr>
    <td colspan="6">$option</td>
  </tr>
|;

	print qq|
	<tr class=listheading>
|;

	for (@column_index) { print "$column_header{$_}\n" }

	print qq|
	</tr>
|;

	# add sort and escape callback
	$callback = $form->escape( $callback . "&sort=$form->{sort}" );

	if ( @{ $form->{TR} } ) {
		$sameitem = $form->{TR}->[0]->{ $form->{sort} };
	}

	my $totalnetamount = 0, $totaltax = 0, $subtotalnetamount = 0,
	  $subtotaltax = 0;
	foreach $ref ( @{ $form->{TR} } ) {

		$module = ( $ref->{invoice} ) ? $invoice : $arap;
		$module = 'ps.pl' if $ref->{till};

		if ( $form->{l_subtotal} eq 'Y' ) {
			if ( $sameitem ne $ref->{ $form->{sort} } ) {
				&tax_subtotal;
				$sameitem = $ref->{ $form->{sort} };
			}
		}

		$totalnetamount += $ref->{netamount};
		$totaltax       += $ref->{tax};

		$subtotalnetamount += $ref->{netamount};
		$subtotaltax       += $ref->{tax};

		for (qw(netamount tax)) {
			$ref->{$_} =
			  $form->format_amount( \%myconfig, $ref->{$_}, $form->{precision},
				"&nbsp;" );
		}

		my %column_data;
		$column_data{id} = qq|<td>$ref->{id}</td>|;
		$column_data{invnumber} =
qq|<td><a href=$module?path=$form->{path}&action=edit&id=$ref->{id}&login=$form->{login}&callback=$callback>$ref->{invnumber}</a></td>|;

		$column_data{transdate} = qq|<td nowrap>$ref->{transdate}</td>|;
		for (qw(id partnumber description)) {
			$column_data{$_} = qq|<td>$ref->{$_}</td>|;
		}

		$column_data{"$form->{vc}number"} =
		  qq|<td>$ref->{"$form->{vc}number"}</td>|;
		$column_data{name} =
qq|<td><a href=ct.pl?path=$form->{path}&login=$form->{login}&action=edit&id=$ref->{vc_id}&db=$form->{vc}&callback=$callback>$ref->{name}</a></td>|;

		for (qw(netamount tax)) {
			$column_data{$_} = qq|<td align=right>$ref->{$_}</td>|;
		}

		$i++;
		$i %= 2;
		print qq|
	<tr class=listrow$i>
|;

		for (@column_index) { print "$column_data{$_}\n" }

		print qq|
	</tr>
|;

	}

	if ( $form->{l_subtotal} eq 'Y' ) {
		&tax_subtotal;
	}

	for (@column_index) { $column_data{$_} = qq|<th>&nbsp;</th>| }

	print qq|
        </tr>
	<tr class=listtotal>
|;

	$totalnetamount =
	  $form->format_amount( \%myconfig, $totalnetamount, $form->{precision},
		"&nbsp;" );
	$totaltax =
	  $form->format_amount( \%myconfig, $totaltax, $form->{precision},
		"&nbsp;" );

	# set default values
	if ( $totalnetamount eq "&nbsp;" ) {
		$totalnetamount = 0;
	}
	if ( $totaltax eq "&nbsp;" ) {
		$totaltax = 0;
	}
	if ( $form->{accno} eq '' ) {
		$form->{accno} = "N";
	}
	if ( $form->{"$form->{accno}_description"} eq '' ) {
		$form->{"$form->{accno}_description"} = "Non-taxable";
	}

	$ar_ap                    = $locale->text( uc $form->{db} );
	$column_data{transdate}   = qq|<th></th>|;
	$column_data{invnumber}   = qq|<th></th>|;
	$column_data{description} = qq|<th align=right></th>|;
	$column_data{name}        = qq|<th align=right>$ar_ap $form->{accno}</th>|;
	$column_data{netamount} =
	  qq|<th class=listtotal align=right>$totalnetamount</th>|;
	$column_data{tax} = qq|<th class=listtotal align=right>$totaltax</th>|;

	for (@column_index) { print "$column_data{$_}\n" }

	print qq|
  </tr>|;
	print qq|
  <tr>
    <td colspan=6><hr size=3 noshade></td>
  </tr>| if !$form->{alltaxes};
	print qq|
</table>

</body>
</html>
| if !$form->{alltaxes};

}

sub tax_subtotal {

	for (@column_index) { $column_data{$_} = "<td>&nbsp;</td>" }

	$subtotalnetamount =
	  $form->format_amount( \%myconfig, $subtotalnetamount, $form->{precision},
		"&nbsp;" );
	$subtotaltax =
	  $form->format_amount( \%myconfig, $subtotaltax, $form->{precision},
		"&nbsp;" );

	$column_data{netamount} =
	  "<th class=listsubtotal align=right>$subtotalnetamount</th>";
	$column_data{tax} = "<th class=listsubtotal align=right>$subtotaltax</th>";

	$subtotalnetamount = 0;
	$subtotaltax       = 0;

	print qq|
	<tr class=listsubtotal>
|;
	for (@column_index) { print "\n$column_data{$_}" }

	print qq|
        </tr>
|;

}

sub list_payments {

	$form->isvaldate( \%myconfig, $form->{fromdate},
		$locale->text('Invalid from date ...') );
	$form->isvaldate( \%myconfig, $form->{todate},
		$locale->text('Invalid to date ...') );

	if ( $form->{account} ) {
		( $form->{paymentaccounts} ) = split /--/, $form->{account};
	}
	if ( $form->{department} ) {
		( $department, $form->{department_id} ) = split /--/,
		  $form->{department};
		$option = $locale->text('Department') . " : $department";
	}

	RP->payments( \%myconfig, \%$form );

	@columns = (qw(transdate reference description name));
	@columns = $form->sort_columns(@columns);
	push @columns, "$form->{vc}number";
	push @columns, (qw(paid source memo variance));

	if ( $form->{till} ) {
		@columns = (qw(transdate reference name));
		@columns = $form->sort_columns(@columns);
		push @columns, "$form->{vc}number";
		push @columns, (qw(description paid curr source till));

		if ( $myconfig{role} ne 'user' ) {
			push @columns, "employee";
		}
	}

	# construct href
	$form->{paymentaccounts} =~ s/ /%20/g;

	$href = "$form->{script}?action=list_payments";
	@a    = (
		qw(path direction sort oldsort till login fromdate todate fx_transaction db l_subtotal prepayment paymentaccounts vc db)
	);
	for (@a) { $href .= "&$_=$form->{$_}" }
	$href .= "&title=" . $form->escape( $form->{title} );

	$form->sort_order();

	$callback = "$form->{script}?action=list_payments";
	for (@a) { $callback .= "&$_=$form->{$_}" }
	$callback .= "&title=" . $form->escape( $form->{title}, 1 );

	if ( $form->{account} ) {
		$callback .= "&account=" . $form->escape( $form->{account}, 1 );
		$href .= "&account=" . $form->escape( $form->{account} );
		$option .= "\n<br>" if ($option);
		$option .= $locale->text('Account') . " : $form->{account}";
	}
	if ( $form->{department} ) {
		$callback .= "&department=" . $form->escape( $form->{department}, 1 );
		$href .= "&department=" . $form->escape( $form->{department} );
		$option .= "\n<br>" if ($option);
		$option .= $locale->text('Department') . " : $form->{department}";
	}

	%vc = (
		customer => { name => 'Customer', 'number' => 'Customer Number' },
		vendor   => { name => 'Vendor',   'number' => 'Vendor Number' }
	);

	if ( $form->{ $form->{vc} } ) {
		$callback .=
		  "&$form->{vc}=" . $form->escape( $form->{ $form->{vc} }, 1 );
		$href .= "&$form->{vc}=" . $form->escape( $form->{ $form->{vc} } );
		$option .= "\n<br>" if ($option);
		$option .=
		  $locale->text( $vc{ $form->{vc} }{name} ) . " : $form->{$form->{vc}}";
	}
	if ( $form->{"$form->{vc}number"} ) {
		$callback .= qq|&$form->{vc}number=|
		  . $form->escape( $form->{"$form->{vc}number"}, 1 );
		$href .= qq|&$form->{vc}number=|
		  . $form->escape( $form->{"$form->{vc}number"} );
		$option .= "\n<br>" if ($option);
		$option .=
		  $locale->text( $vc{ $form->{vc} }{number} )
		  . qq| : $form->{"$form->{vc}number"}|;
	}
	if ( $form->{reference} ) {
		$callback .= "&reference=" . $form->escape( $form->{reference}, 1 );
		$href .= "&reference=" . $form->escape( $form->{reference} );
		$option .= "\n<br>" if ($option);
		$option .= $locale->text('Reference') . " : $form->{reference}";
	}
	if ( $form->{description} ) {
		$callback .= "&description=" . $form->escape( $form->{description}, 1 );
		$href   .= "&description=" . $form->escape( $form->{description} );
		$option .= "\n<br>" if ($option);
		$option .= $locale->text('Description') . " : $form->{description}";
	}
	if ( $form->{source} ) {
		$callback .= "&source=" . $form->escape( $form->{source}, 1 );
		$href .= "&source=" . $form->escape( $form->{source} );
		$option .= "\n<br>" if ($option);
		$option .= $locale->text('Source') . " : $form->{source}";
	}
	if ( $form->{memo} ) {
		$callback .= "&memo=" . $form->escape( $form->{memo}, 1 );
		$href .= "&memo=" . $form->escape( $form->{memo} );
		$option .= "\n<br>" if ($option);
		$option .= $locale->text('Memo') . " : $form->{memo}";
	}
	if ( $form->{fromdate} ) {
		$callback .= "&fromdate=$form->{fromdate}";
		$href     .= "&fromdate=$form->{fromdate}";
		$option   .= "\n<br>" if ($option);
		$option .=
		    $locale->text('From') 
		  . "&nbsp;"
		  . $locale->date( \%myconfig, $form->{fromdate}, 1 );
	}
	if ( $form->{todate} ) {
		$callback .= "&todate=$form->{todate}";
		$href     .= "&todate=$form->{todate}";
		$option   .= "\n<br>" if ($option);
		$option .=
		    $locale->text('To') 
		  . "&nbsp;"
		  . $locale->date( \%myconfig, $form->{todate}, 1 );
	}

	@column_index = ();
	for (@columns) {
		if ( $form->{"l_$_"} eq 'Y' ) {
			push @column_index, $_;
			$callback .= "&l_$_=Y";
			$href     .= "&l_$_=Y";
		}
	}
	$colspan = $#column_index + 1;

	$form->{callback} = $callback;
	$callback = $form->escape( $form->{callback} );

	$column_header{name} =
	    "<th><a class=listheading href=$href&sort=name>"
	  . $locale->text( $vc{ $form->{vc} }{name} )
	  . "</a></th>";
	$column_header{"$form->{vc}number"} =
	    "<th><a class=listheading href=$href&sort=$form->{vc}number>"
	  . $locale->text( $vc{ $form->{vc} }{number} )
	  . "</a></th>";
	$column_header{reference} =
	    "<th><a class=listheading href=$href&sort=reference>"
	  . $locale->text('Reference')
	  . "</a></th>";
	$column_header{description} =
	    "<th><a class=listheading href=$href&sort=description>"
	  . $locale->text('Description')
	  . "</a></th>";
	$column_header{transdate} =
	    "<th nowrap><a class=listheading href=$href&sort=transdate>"
	  . $locale->text('Date')
	  . "</a></th>";
	$column_header{paid} =
	  "<th class=listheading>" . $locale->text('Amount') . "</a></th>";
	$column_header{curr} =
	  "<th class=listheading>" . $locale->text('Curr') . "</a></th>";
	$column_header{source} =
	    "<th><a class=listheading href=$href&sort=source>"
	  . $locale->text('Source')
	  . "</a></th>";
	$column_header{memo} =
	    "<th><a class=listheading href=$href&sort=memo>"
	  . $locale->text('Memo')
	  . "</a></th>";
	$column_header{variance} =
	    "<th><a class=listheading href=$href&sort=variance>"
	  . $locale->text('Variance')
	  . "</a></th>";

	$employee =
	  ( $form->{db} eq 'ar' )
	  ? $locale->text('Salesperson')
	  : $locale->text('Employee');
	$column_header{employee} =
	  "<th><a class=listheading href=$href&sort=employee>$employee</a></th>";
	$column_header{till} =
	    "<th><a class=listheading href=$href&sort=till>"
	  . $locale->text('Till')
	  . "</a></th>";

	$title = "$form->{title} / $form->{company}";

	$form->header;

	print qq|
<body>

<table width=100%>
  <tr>
    <th class=listtop>$title</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <td>$option</td>
  </tr>
  <tr>
    <td>
      <table width=100%>
	<tr class=listheading>
|;

	for (@column_index) { print "\n$column_header{$_}" }

	print qq|
        </tr>
|;

	$isir = ( $form->{db} eq 'ar' ) ? 'is' : 'ir';

	foreach $ref ( sort { $a->{accno} cmp $b->{accno} } @{ $form->{PR} } ) {

		next unless @{ $form->{ $ref->{id} } };

		print qq|
        <tr>
	  <th colspan=$colspan align=left>$ref->{accno}--$ref->{description}</th>
	</tr>
|;

		if ( @{ $form->{ $ref->{id} } } ) {
			$sameitem = $form->{ $ref->{id} }[0]->{ $form->{sort} };
		}

		foreach $payment ( @{ $form->{ $ref->{id} } } ) {

			if ( $form->{l_subtotal} ) {
				if ( $payment->{ $form->{sort} } ne $sameitem ) {

					# print subtotal
					&payment_subtotal;
				}
			}

			next if ( $form->{till} && !$payment->{till} );

			$href =
			  ( $payment->{vcid} )
			  ? "<a href=ct.pl?action=edit&id=$payment->{vcid}&db=$form->{vc}&login=$form->{login}&path=$form->{path}&callback=$callback>"
			  : "";

			$column_data{name} = "<td>$href$payment->{name}</a>&nbsp;</td>";
			$column_data{"$form->{vc}number"} =
			  qq|<td>$payment->{"$form->{vc}number"}&nbsp;</td>|;
			$column_data{description} =
			  "<td>$payment->{description}&nbsp;</td>";
			$column_data{transdate} =
			  "<td nowrap>$payment->{transdate}&nbsp;</td>";
			$column_data{paid} = "<td align=right>"
			  . $form->format_amount( \%myconfig, $payment->{paid},
				$form->{precision}, "&nbsp;" )
			  . "</td>";
			$column_data{curr} = "<td>$payment->{curr}</td>";

			if ( $payment->{module} eq 'gl' ) {
				$module = $payment->{module};
			}
			else {
				if ( $payment->{invoice} ) {
					$module = ( $payment->{till} ) ? 'ps' : $isir;
				}
				else {
					$module = $form->{db};
				}
			}

			$href =
"<a href=${module}.pl?action=edit&id=$payment->{trans_id}&login=$form->{login}&path=$form->{path}&callback=$callback>";

			$column_data{source} = "<td>$payment->{source}&nbsp;</td>";
			$column_data{reference} =
			  "<td>$href$payment->{reference}&nbsp;</a></td>";

			$column_data{memo}     = "<td>$payment->{memo}&nbsp;</td>";
			$column_data{employee} = "<td>$payment->{employee}&nbsp;</td>";
			$column_data{till}     = "<td>$payment->{till}&nbsp;</td>";
			$column_data{variance}     = "<td>$payment->{variance}&nbsp;</td>";

			$subtotalpaid     += $payment->{paid};
			$accounttotalpaid += $payment->{paid};
			$totalpaid        += $payment->{paid};

			$i++;
			$i %= 2;
			print qq|
	<tr class=listrow$i>
|;

			for (@column_index) { print "\n$column_data{$_}" }

			print qq|
        </tr>
|;

			$sameitem = $payment->{ $form->{sort} };

		}

		&payment_subtotal if $form->{l_subtotal};

		# print account totals
		for (@column_index) { $column_data{$_} = "<td>&nbsp;</td>" }

		$column_data{paid} = "<th class=listtotal align=right>"
		  . $form->format_amount( \%myconfig, $accounttotalpaid,
			$form->{precision}, "&nbsp;" )
		  . "</th>";

		print qq|
	<tr class=listtotal>
|;

		for (@column_index) { print "\n$column_data{$_}" }

		print qq|
        </tr>
|;

		$accounttotalpaid = 0;

	}

	# print total
	for (@column_index) { $column_data{$_} = "<td>&nbsp;</td>" }

	$column_data{paid} = "<th class=listtotal align=right>"
	  . $form->format_amount( \%myconfig, $totalpaid, $form->{precision},
		"&nbsp;" )
	  . "</th>";

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

################
	#  &print_report_options;

	if ( $form->{menubar} ) {
		require "$form->{path}/menu.pl";
		&menubar;
	}

	print qq|

</body>
</html>
|;

}

sub payment_subtotal {

	if ( $subtotalpaid != 0 ) {
		for (@column_index) { $column_data{$_} = "<td>&nbsp;</td>" }

		$column_data{paid} = "<th class=listsubtotal align=right>"
		  . $form->format_amount( \%myconfig, $subtotalpaid, $form->{precision},
			"&nbsp;" )
		  . "</th>";

		print qq|
  <tr class=listsubtotal>
|;

		for (@column_index) { print "\n$column_data{$_}" }

		print qq|
  </tr>
|;
	}

	$subtotalpaid = 0;

}

sub print_report_options {

	$form->{format} ||= "pdf";
	$form->{media}  ||= "screen";

	$media = qq|<select name=media>
	    <option value=screen $form->{MD}{screen}>| . $locale->text('Screen') . qq|
	    <option value=file $form->{MD}{file}>| . $locale->text('File');

	$format = qq|<select name=format>
            <option value=csv $form->{DF}{csv}>CSV|;

	$media =~ s/(<option value="\Q$form->{media}\E")/$1 selected/;
	$media .= qq|</select>|;

	if ($latex) {
		$format .= qq|
	    <option value=pdf $form->{DF}{pdf}>| . $locale->text('PDF');
	}
	$format .= qq|</select>|;

	print qq|
<form method=post action=$form->{script}>

<table>
  <tr>
    <td>$format</td>
    <td>$media</td>
|;

	print qq|
  </tr>
</table>

<p>
<input class=submit type=submit name=action value="|
	  . $locale->text('Print Report') . qq|">|;

	$form->{action}  = "print_report";
	$form->{nextsub} = "";

	$form->hide_form;

	print qq|
</form>
|;

}

sub print_report {

	$form->debug;

}

