#=====================================================================
# SQL-Ledger ERP
# Copyright (c) 2006
#
#  Author: DWS Systems Inc.
#     Web: http://www.sql-ledger.com
#
#======================================================================
#
# Genereal Ledger
#
#======================================================================

use SL::GL;
use SL::PE;
use SL::VR;

use IO::File;
use File::Temp qw(tempfile);

require "$form->{path}/arap.pl";
require "$form->{path}/mylib.pl";

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

sub add {

    if ( $form->{batch} ) {
        $form->{title} = $locale->text('Add General Ledger Voucher');
        if ( $form->{batchdescription} ) {
            $form->{title} .= " / $form->{batchdescription}";
        }
    }
    else {
        if ( $form->{fxadj} ) {
            $form->{title} = $locale->text('Add FX Adjustment');
        }
        else {
            $form->{title} = $locale->text('Add General Ledger Transaction');
        }
    }

    $form->{callback} = "$form->{script}?action=add&fxadj=$form->{fxadj}&path=$form->{path}&login=$form->{login}" unless $form->{callback};

    $transdate = $form->{transdate};

    &create_links;

    $form->{transdate} = $transdate if $transdate;

    $form->{rowcount}     = ( $form->{fxadj} ) ? 2 : 9;
    $form->{oldtransdate} = $form->{transdate};
    $form->{focus}        = "reference";

    $form->{currency} = $form->{defaultcurrency};

    #  delete $form->{defaultcurrency} if $form->{fxadj};

    &display_form(1);

}

sub edit {

    &create_links;

    $form->{locked} = ( $form->{revtrans} ) ? '1' : ( $form->datetonum( \%myconfig, $form->{transdate} ) <= $form->{closedto} );

    #  delete $form->{defaultcurrency} if $form->{fxadj};

    if ( $form->{batch} ) {
        $form->{title} = $locale->text('Edit General Ledger Voucher');
        if ( $form->{batchdescription} ) {
            $form->{title} .= " / $form->{batchdescription}";
        }
    }
    else {
        if ( $form->{fxadj} ) {
            $form->{title} = $locale->text('Edit FX Adjustment');
        }
        else {
            $form->{title} = $locale->text('Edit General Ledger Transaction');
        }
    }

    $form->check_exchangerate( \%myconfig, $form->{currency}, $form->{transdate} );

    $i = 1;

    my $dbh = $form->dbconnect( \%myconfig );
    foreach $ref ( @{ $form->{GL} } ) {
        $form->{"accno_$i"} = "$ref->{accno}--$ref->{description}";

        $form->{"projectnumber_$i"} = "$ref->{projectnumber}--$ref->{project_id}" if $ref->{project_id};
        for (qw(fx_transaction source memo cleared tax taxamount)) { $form->{"${_}_$i"} = $ref->{$_} }

        if ( $ref->{amount} < 0 ) {
            $form->{totaldebit} -= $ref->{amount};
            $form->{"debit_$i"} = $ref->{amount} * -1;
        }
        else {
            $form->{totalcredit} += $ref->{amount};
            $form->{"credit_$i"} = $ref->{amount};
        }

        $i++;
    }
    $dbh->disconnect;

    $form->{rowcount} = $i;
    $form->{focus}    = "debit_$i";

    # readonly
    if ( !$form->{readonly} ) {
        if ( $form->{batch} ) {
            $form->{readonly} = 1 if $myconfig{acs} =~ /VR--General Ledger/ || $form->{approved};
        }
        else {
            $form->{readonly} = 1 if $myconfig{acs} =~ /General Ledger--Add Transaction/;
        }
    }

    &form_header;
    &display_rows;
    &form_footer;

}

sub create_links {

    GL->transaction( \%myconfig, \%$form );

    for ( @{ $form->{all_accno} } ) { $form->{selectaccno} .= "$_->{accno}--$_->{description}\n" }

    $form->{oldcurrency} = $form->{currency};

    # currencies
    @curr = split /:/, $form->{currencies};
    $form->{defaultcurrency} = $curr[0];
    chomp $form->{defaultcurrency};

    for (@curr) { $form->{selectcurrency} .= "$_\n" }

    # projects
    if ( @{ $form->{all_project} } ) {
        $form->{selectprojectnumber} = "\n";
        for ( @{ $form->{all_project} } ) { $form->{selectprojectnumber} .= qq|$_->{projectnumber}--$_->{id}\n| }
    }

    # tax accounts
    my $dbh = $form->dbconnect( \%myconfig );
    my ($linetax) = $dbh->selectrow_array("SELECT fldvalue FROM defaults WHERE fldname='linetax'");
    $linetax = 0 if $form->{fxadj};

    if ($linetax) {
        my $sth = $dbh->prepare(
            qq|
             SELECT accno, description FROM chart WHERE id IN 
               (SELECT chart_id FROM tax WHERE validto >= '$form->{transdate}' OR validto IS NULL)
             ORDER BY accno
             |
        );
        $sth->execute;
        $form->{selecttax} = "\n";
        while ( my $row = $sth->fetchrow_hashref(NAME_lc) ) {
            $form->{selecttax} .= "$row->{accno}--$row->{description}\n";
        }
        $sth->finish;
    }
    $dbh->disconnect;

    # departments
    if ( @{ $form->{all_department} } ) {
        if ( $myconfig{department_id} and $myconfig{role} eq 'user' ) {
            $form->{selectdepartment} = qq|$myconfig{department}--$myconfig{department_id}\n|;
        }
        else {
            $form->{department}       = "$form->{department}--$form->{department_id}";
            $form->{selectdepartment} = "\n";
            for ( @{ $form->{all_department} } ) { $form->{selectdepartment} .= qq|$_->{description}--$_->{id}\n| }
        }
    }

    for (qw(department projectnumber accno currency tax)) { $form->{"select$_"} = $form->escape( $form->{"select$_"}, 1 ) }

}

sub search {

    $form->{title} = $locale->text('General Ledger') . " " . $locale->text('Reports');

    $default_checked = "transdate,reference,description,debit,credit,accno";
    $form->get_lastused(\%myconfig, "gl-transactions", $default_checked);

    $form->{reportcode} = 'gl';
    $form->{dateformat} = $myconfig{dateformat};

    $form->all_departments( \%myconfig );

    # departments
    # armaghan 12-apr-2012 restrict user to his department
    if ( @{ $form->{all_department} } ) {
        if ( $myconfig{department_id} and $myconfig{role} eq 'user' ) {
            $form->{selectdepartment} = qq|$myconfig{department}--$myconfig{department_id}\n|;
        }
        else {
            $form->{selectdepartment} = "\n";
            $form->{department} = "$form->{department}--$form->{department_id}" if $form->{department_id};

            for ( @{ $form->{all_department} } ) { $form->{selectdepartment} .= qq|$_->{description}--$_->{id}\n| }
        }
        $l_department = 1;

        $department = qq|
  	<tr>
	  <th align=right>| . $locale->text('Department') . qq|</th>
	  <td><select name=department>|
          . $form->select_option( $form->{selectdepartment}, $form->{department}, 1 ) . qq|
	  </select></td>
	</tr>
|;
    }

    $form->all_projects( \%myconfig );
    if ( @{ $form->{all_project} } ) {
        $form->{selectproject} = "<option>\n";
        for ( @{ $form->{all_project} } ) { $form->{selectproject} .= qq|<option value="| . $form->quote( $_->{projectnumber} ) . qq|--$_->{id}">$_->{projectnumber}\n| }

        $project = qq|
	<tr>
	  <th align=right nowrap>| . $locale->text('Project') . qq|</th>
	  <td colspan=3><select name=projectnumber>$form->{selectproject}</select></td>
	</tr>|;

    }

    if ( @{ $form->{all_years} } ) {

        # accounting years
        $selectaccountingyear = "\n";
        for ( @{ $form->{all_years} } ) { $selectaccountingyear .= qq|$_\n| }
        $selectaccountingmonth = "\n";
        for ( sort keys %{ $form->{all_month} } ) { $selectaccountingmonth .= qq|$_--| . $locale->text( $form->{all_month}{$_} ) . qq|\n| }

        $selectfrom = qq|
        <tr>
	<th align=right>| . $locale->text('Period') . qq|</th>
	<td>
	<select name=month>| . $form->select_option( $selectaccountingmonth, $form->{month}, 1, 1 ) . qq|</select>
	<select name=year>| . $form->select_option( $selectaccountingyear, $form->{year} ) . qq|</select>
	<input name=interval class=radio type=radio value=0 checked>&nbsp;| . $locale->text('Current') . qq|
	<input name=interval class=radio type=radio value=1>&nbsp;| . $locale->text('Month') . qq|
	<input name=interval class=radio type=radio value=3>&nbsp;| . $locale->text('Quarter') . qq|
	<input name=interval class=radio type=radio value=12>&nbsp;| . $locale->text('Year') . qq|
	</td>
      </tr>
|;
    }

    if ( @{ $form->{all_report} } ) {
        $form->{selectreportform} = "\n";
        for ( @{ $form->{all_report} } ) { $form->{selectreportform} .= qq|$_->{reportdescription}--$_->{reportid}\n| }

        $reportform = qq|
      <tr>
        <th align=right>| . $locale->text('Report') . qq|</th>
	<td>
	  <select name=report onChange="ChangeReport();">| . $form->select_option( $form->{selectreportform}, undef, 1 ) . qq|</select>
	</td>
      </tr>
|;
    }

    for (qw(transdate reference description debit credit accno)) { $form->{"l_$_"} = "checked" }

    @checked = qw(l_subtotal);
    @input   = qw(reference description name vcnumber lineitem notes source memo datefrom dateto month year accnofrom accnoto amountfrom amountto sort direction reportlogin projectnumber intnotes);
    for (qw(department)) {
        push @input, $_ if exists $form->{$_};
    }
    %radio = (
        interval => { 0 => 0, 1 => 1, 3 => 2, 12 => 3 },
        category => { X => 0, A => 1, L => 2, Q  => 3, I => 4, E => 5 }
    );

    $i = 1;
    $includeinreport{id} = { ndx => $i++, sort => id, checkbox => 1, html => qq|<input name="l_id" class=checkbox type=checkbox value=Y $form->{l_id}>|, label => $locale->text('ID') };
    $includeinreport{transdate} =
      { ndx => $i++, sort => transdate, checkbox => 1, html => qq|<input name="l_transdate" class=checkbox type=checkbox value=Y $form->{l_transdate}>|, label => $locale->text('Date') };
    $includeinreport{reference} =
      { ndx => $i++, sort => reference, checkbox => 1, html => qq|<input name="l_reference" class=checkbox type=checkbox value=Y $form->{l_reference}>|, label => $locale->text('Reference') };
    $includeinreport{description} =
      { ndx => $i++, sort => description, checkbox => 1, html => qq|<input name="l_description" class=checkbox type=checkbox value=Y $form->{l_description}>|, label => $locale->text('Description') };
    $includeinreport{name} =
      { ndx => $i++, sort => name, checkbox => 1, html => qq|<input name="l_name" class=checkbox type=checkbox value=Y $form->{l_name}>|, label => $locale->text('Company Name') };
    $includeinreport{vcnumber} =
      { ndx => $i++, sort => vcnumber, checkbox => 1, html => qq|<input name="l_vcnumber" class=checkbox type=checkbox value=Y $form->{l_vcnumber}>|, label => $locale->text('Company Number') };
    $includeinreport{address} = { ndx => $i++, checkbox => 1, html => qq|<input name="l_address" class=checkbox type=checkbox value=Y $form->{l_address}>|, label => $locale->text('Address') };
    $includeinreport{department} =
      { ndx => $i++, sort => department, checkbox => 1, html => qq|<input name="l_department" class=checkbox type=checkbox value=Y $form->{l_department}>|, label => $locale->text('Department') }
      if $l_department;
    $includeinreport{projectnumber} = {
        ndx      => $i++,
        sort     => projectnumber,
        checkbox => 1,
        html     => qq|<input name="l_projectnumber" class=checkbox type=checkbox value=Y $form->{l_projectnumber}>|,
        label    => $locale->text('Project Number')
    };
    $includeinreport{notes}  = { ndx => $i++, checkbox => 1, html => qq|<input name="l_notes" class=checkbox type=checkbox value=Y $form->{l_notes}>|,   label => $locale->text('Notes') };
    $includeinreport{debit}  = { ndx => $i++, checkbox => 1, html => qq|<input name="l_debit" class=checkbox type=checkbox value=Y $form->{l_debit}>|,   label => $locale->text('Debit') };
    $includeinreport{credit} = { ndx => $i++, checkbox => 1, html => qq|<input name="l_credit" class=checkbox type=checkbox value=Y $form->{l_credit}>|, label => $locale->text('Credit') };
    $includeinreport{source} =
      { ndx => $i++, sort => source, checkbox => 1, html => qq|<input name="l_source" class=checkbox type=checkbox value=Y $form->{l_source}>|, label => $locale->text('Source') };
    $includeinreport{memo} = { ndx => $i++, sort => memo, checkbox => 1, html => qq|<input name="l_memo" class=checkbox type=checkbox value=Y $form->{l_memo}>|, label => $locale->text('Memo') };
    $includeinreport{lineitem} =
      { ndx => $i++, sort => lineitem, checkbox => 1, html => qq|<input name="l_lineitem" class=checkbox type=checkbox value=Y $form->{l_lineitem}>|, label => $locale->text('Line Item') };
    $includeinreport{accno} =
      { ndx => $i++, sort => accno, checkbox => 1, html => qq|<input name="l_accno" class=checkbox type=checkbox value=Y $form->{l_accno}>|, label => $locale->text('Account') };
    $includeinreport{accdescription} = {
        ndx      => $i++,
        sort     => accdescription,
        checkbox => 1,
        html     => qq|<input name="l_accdescription" class=checkbox type=checkbox value=Y $form->{l_accdescription}>|,
        label    => $locale->text('Account Description')
    };
    $includeinreport{gifi_accno} =
      { ndx => $i++, sort => gifi_accno, checkbox => 1, html => qq|<input name="l_gifi_accno" class=checkbox type=checkbox value=Y $form->{l_gifi_accno}>|, label => $locale->text('GIFI') };
    $includeinreport{contra} = { ndx => $i++, checkbox => 1, html => qq|<input name="l_contra" class=checkbox type=checkbox value=Y $form->{l_contra}>|, label => $locale->text('Contra') };
    $includeinreport{intnotes} =
      { ndx => $i++, checkbox => 1, html => qq|<input name="l_intnotes" class=checkbox type=checkbox value=Y $form->{l_intnotes}>|, label => $locale->text('Internal Notes') };
    $includeinreport{include_log} =
      { ndx => $i++, checkbox => 1, html => qq|<input name="include_log" class=checkbox type=checkbox value=Y $form->{include_log}>|, label => $locale->text('Include Log') };
    $includeinreport{ts} =
      { ndx => $i++, checkbox => 1, html => qq|<input name="l_ts" class=checkbox type=checkbox value=Y $form->{l_ts}>|, label => $locale->text('TS') };
    $includeinreport{curr} =
      { ndx => $i++, checkbox => 1, html => qq|<input name="l_curr" class=checkbox type=checkbox value=Y $form->{l_curr}>|, label => $locale->text('Currency') };
    $includeinreport{exchangerate} =
      { ndx => $i++, checkbox => 1, html => qq|<input name="l_exchangerate" class=checkbox type=checkbox value=Y $form->{l_exchangerate}>|, label => $locale->text('Exchange rate') };
    $includeinreport{tax} =
      { ndx => $i++, sort => tax, checkbox => 1, html => qq|<input name="l_tax" class=checkbox type=checkbox value=Y $form->{l_tax}>|, label => $locale->text('Tax') };
    $includeinreport{taxamount} =
      { ndx => $i++, checkbox => 1, html => qq|<input name="l_taxamount" class=checkbox type=checkbox value=Y $form->{l_taxamount}>|, label => $locale->text('Tax Amount') };

    @f = ();
    $form->{flds} = "";

    for ( sort { $includeinreport{$a}->{ndx} <=> $includeinreport{$b}->{ndx} } keys %includeinreport ) {
        $form->{flds} .= "$_=$includeinreport{$_}->{label}=$includeinreport{$_}->{sort},";
        push @checked, "l_$_";
        if ( $includeinreport{$_}->{checkbox} ) {
            push @f, "$includeinreport{$_}->{html} $includeinreport{$_}->{label}";
        }
    }
    chop $form->{flds};

    $form->helpref( "search_gl_transactions", $myconfig{countrycode} );

    $form->header;

	my $title = $locale->text('General Ledger');

    #JS->change_report(\%$form, \@input, \@checked, \%radio);

    print qq|
<body>
|;

    print qq|
<form method=get action=$form->{script}>
<input type="hidden" name="auth_token" value="<%auth_token%>" />
<input type="hidden" name="title" value="$title" /> 

<table width=100%>
  <tr>
    <th class=listtop>$form->{helpref}$form->{title}</a></th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <td>
      <table width=100%>
        $reportform
	<tr>
	  <th align=right>| . $locale->text('Account') . qq|</th>
	  <td><input name=accno size=10 value="$form->{accno}"></td>
	</tr>
	<tr>
	  <th align=right>| . $locale->text('Reference') . qq| / | . $locale->text('Invoice Number') . qq|</th>
	  <td><input name=reference size=20></td>
	</tr>
	<tr>
	  <th align=right>| . $locale->text('Description') . qq|</th>
	  <td><input name=description size=40></td>
	</tr>
	<tr>
	  <th align=right>| . $locale->text('Company Name') . qq|</th>
	  <td><input id="vc" name=name size=35></td>
	</tr>
	<tr>
	  <th align=right>| . $locale->text('Company Number') . qq|</th>
	  <td><input id="vcnumber" name=vcnumber size=35></td>
	</tr>

      	$department
	$project
	
	<tr>
	  <th align=right>| . $locale->text('Line Item') . qq|</th>
	  <td><input name=lineitem size=30></td>
	</tr>

	<tr>
	  <th align=right>| . $locale->text('Notes') . qq|</th>
	  <td><input name=notes size=40></td>
	</tr>

	<tr>
	  <th align=right>| . $locale->text('Internal Notes') . qq|</th>
	  <td><input name=intnotes size=40></td>
	</tr>

	<tr>
	  <th align=right>| . $locale->text('Source') . qq|</th>
	  <td><input name=source size=20></td>
	</tr>
	
	<tr>
	  <th align=right>| . $locale->text('Memo') . qq|</th>
	  <td><input name=memo size=30></td>
	</tr>

	<tr>
	  <th align=right>| . $locale->text('From') . qq|</th>
	  <td><input name=datefrom size=11 class=date title="$myconfig{dateformat}"> <b>| . $locale->text('To') . qq|</b> <input name=dateto size=11 class=date title="$myconfig{dateformat}"></td>
	</tr>
	
	$selectfrom
	
	<tr>
	  <th align=right>| . $locale->text('Account') . qq| >=</th>
	  <td><input name=accnofrom> <b>| . $locale->text('Account') . qq| <=</b> <input name=accnoto></td>
	</tr>
	
	<tr>
	  <th align=right>| . $locale->text('Amount') . qq| >=</th>
	  <td><input name=amountfrom size=11> <b>| . $locale->text('Amount') . qq| <=</b> <input name=amountto size=11></td>
	</tr>
	
	<tr>
	  <th align=right>| . $locale->text('Include in Report') . qq|</th>
	  <td>
	    <table>
	      <tr>
		<td>
		  <input name="category" class=radio type=radio value=X checked>&nbsp;| . $locale->text('All') . qq|
		  <input name="category" class=radio type=radio value=A>&nbsp;| . $locale->text('Asset') . qq|
		  <input name="category" class=radio type=radio value=L>&nbsp;| . $locale->text('Liability') . qq|
		  <input name="category" class=radio type=radio value=Q>&nbsp;| . $locale->text('Equity') . qq|
		  <input name="category" class=radio type=radio value=I>&nbsp;| . $locale->text('Income') . qq|
		  <input name="category" class=radio type=radio value=E>&nbsp;| . $locale->text('Expense') . qq|
		</td>
	      </tr>
	      
	      <tr>
	        <td>
		  <table>
|;

    while (@f) {
        print qq|<tr>\n|;
        for ( 1 .. 5 ) {
            print qq|<td nowrap>| . shift @f;
            print qq|</td>\n|;
        }
        print qq|</tr>\n|;
    }

    print qq|
		    <tr>
		      <td nowrap><input name="l_subtotal" class=checkbox type=checkbox value=Y>&nbsp;| . $locale->text('Subtotal') . qq|</td>
              <td><input type=checkbox class=checkbox name=fx_transaction value=1 checked> |.$locale->text('Exchange Rate Difference').qq|</td>
              <td><input type=checkbox class=checkbox name=filter_amounts value=1> |.$locale->text('Filter Amounts').qq|</td>
		      <td><input name="l_csv" class=checkbox type=checkbox value=Y>&nbsp;| . $locale->text('CSV') . qq|</td>
		      <td nowrap><input name=onhold class=checkbox type=checkbox value=1>| . $locale->text('On Hold') . qq|</td>
		    </tr>
		  </table>
		</td>
	      </tr>
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
<br>
|;

    %button = ( 'Continue' => { ndx => 1, key => 'C', value => $locale->text('Continue') } );

    for ( sort { $button{$a}->{ndx} <=> $button{$b}->{ndx} } keys %button ) {
        $form->print_button( \%button, $_ );
    }

    $form->{sort}      ||= "transdate";
    $form->{direction} ||= "ASC";

    $form->{nextsub}    = "transactions";
    $form->{initreport} = 1;

    $form->hide_form(qw(sort direction reportlogin nextsub initreport path login flds));

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

sub transactions {

    use DBIx::Simple;
    $form->{dbh} = $form->dbconnect(\%myconfig);
    $form->{dbs} = DBIx::Simple->connect($form->{dbh});

    $form->isvaldate(\%myconfig, $form->{datefrom}, $locale->text('Invalid from date ...'));
    $form->isvaldate(\%myconfig, $form->{dateto}, $locale->text('Invalid to date ...'));

    for (qw(amountfrom amountto)){ $form->{"save_$_"} = $form->{$_} }
    for (qw(amountfrom amountto)){ $form->{$_} = $form->parse_amount( \%myconfig, $form->{$_} ) }

    # currencies
    $form->{currencies} = $form->get_currencies(0, \%myconfig);
    @curr = split /:/, $form->{currencies};
    $form->{defaultcurrency} = $curr[0];
    chomp $form->{defaultcurrency};

    $form->{amountfrom} *= 1;
    $form->{amountto} *= 1;

    ( $form->{reportdescription}, $form->{reportid} ) = split /--/, $form->{report};
    $form->{sort} ||= "transdate";
    $form->{reportcode} = 'gl';

    if ( $form->{flds} eq "" ) {
        $form->{flds} = "id="
          . $locale->text('ID')
          . "=id,transdate="
          . $locale->text('Date')
          . "=transdate,reference="
          . $locale->text('Reference')
          . "=reference,description="
          . $locale->text('Description')
          . "=description,name="
          . $locale->text('Company Name')
          . "=name,vcnumber="
          . $locale->text('Company Number')
          . "=vcnumber,address="
          . $locale->text('Address')
          . "=,projectnumber="
          . $locale->text('Project Number')
          . "=projectnumber,notes="
          . $locale->text('Notes')
          . "=,debit="
          . $locale->text('Debit')
          . "=,credit="
          . $locale->text('Credit')
          . "=,source="
          . $locale->text('Source')
          . "=source,memo="
          . $locale->text('Memo')
          . "=memo,lineitem="
          . $locale->text('Line Item')
          . "=lineitem,accno="
          . $locale->text('Account')
          . "=accno,accdescription="
          . $locale->text('Account Description')
          . "=accdescription,gifi_accno="
          . $locale->text('GIFI')
          . "=gifi_accno,contra="
          . $locale->text('Contra') . "=";
    }

    if ( $form->{l_csv} eq 'Y' ) {
        &transactions_to_csv;
        exit;
    }

    GL->transactions( \%myconfig, \%$form );

    $href = "$form->{script}?action=transactions";
    for (qw(direction oldsort path login month year interval reportlogin fx_transaction include_log l_ts)) { $href .= "&$_=$form->{$_}" }
    for (qw(report flds))                                                  { $href .= "&$_=" . $form->escape( $form->{$_} ) }

    $form->sort_order();

    $callback = "$form->{script}?action=transactions";
    for (qw(direction oldsort path login month year interval reportlogin fx_transaction include_log l_ts filter_amounts)) { $callback .= "&$_=$form->{$_}" }
    for (qw(report flds))                                                  { $callback .= "&$_=" . $form->escape( $form->{$_} ) }

    %acctype = (
        'A' => $locale->text('Asset'),
        'L' => $locale->text('Liability'),
        'Q' => $locale->text('Equity'),
        'I' => $locale->text('Income'),
        'E' => $locale->text('Expense'),
    );

    $href .= "&title=" . $form->escape( $locale->text('General Ledger') );
    
    $form->{title} = $locale->text('General Ledger') . " / $form->{company}";

    $ml = ( $form->{category} =~ /(A|E)/ ) ? -1 : 1;

    unless ( $form->{category} eq 'X' ) {
        $form->{title} .= " : " . $locale->text( $acctype{ $form->{category} } );
    }
    if ( $form->{accno} ) {
        $href .= "&accno=" . $form->escape( $form->{accno} );
        $callback .= "&accno=" . $form->escape( $form->{accno}, 1 );
        $option = $locale->text('Account') . " : $form->{accno} $form->{account_description}";
    }
    if ( $form->{gifi_accno} ) {
        $href     .= "&gifi_accno=" . $form->escape( $form->{gifi_accno} );
        $callback .= "&gifi_accno=" . $form->escape( $form->{gifi_accno}, 1 );
        $option   .= "\n<br>" if $option;
        $option   .= $locale->text('GIFI') . " : $form->{gifi_accno} $form->{gifi_account_description}";
    }
    if ( $form->{reference} ) {
        $href     .= "&reference=" . $form->escape( $form->{reference} );
        $callback .= "&reference=" . $form->escape( $form->{reference}, 1 );
        $option   .= "\n<br>" if $option;
        $option   .= $locale->text('Reference') . " / " . $locale->text('Invoice Number') . " : $form->{reference}";
    }
    if ( $form->{description} ) {
        $href     .= "&description=" . $form->escape( $form->{description} );
        $callback .= "&description=" . $form->escape( $form->{description}, 1 );
        $option   .= "\n<br>" if $option;
        $option   .= $locale->text('Description') . " : $form->{description}";
    }
    if ( $form->{name} ) {
        $href     .= "&name=" . $form->escape( $form->{name} );
        $callback .= "&name=" . $form->escape( $form->{name}, 1 );
        $option   .= "\n<br>" if $option;
        $option   .= $locale->text('Company Name') . " : $form->{name}";
    }
    if ( $form->{vcnumber} ) {
        $href     .= "&vcnumber=" . $form->escape( $form->{vcnumber} );
        $callback .= "&vcnumber=" . $form->escape( $form->{vcnumber}, 1 );
        $option   .= "\n<br>" if $option;
        $option   .= $locale->text('Company Number') . " : $form->{vcnumber}";
    }
    if ( $form->{department} ) {
        $href .= "&department=" . $form->escape( $form->{department} );
        $callback .= "&department=" . $form->escape( $form->{department}, 1 );
        ($department) = split /--/, $form->{department};
        $option .= "\n<br>" if $option;
        $option .= $locale->text('Department') . " : $department";
    }
    if ( $form->{projectnumber} ) {
        $href .= "&projectnumber=" . $form->escape( $form->{projectnumber} );
        $callback .= "&projectnumber=" . $form->escape( $form->{projectnumber}, 1 );
        ($projectnumber) = split /--/, $form->{projectnumber};
        $option .= "\n<br>" if $option;
        $option .= $locale->text('Project') . " : $projectnumber";
    }
    if ( $form->{notes} ) {
        $href     .= "&notes=" . $form->escape( $form->{notes} );
        $callback .= "&notes=" . $form->escape( $form->{notes}, 1 );
        $option   .= "\n<br>" if $option;
        $option   .= $locale->text('Notes') . " : $form->{notes}";
    }
    if ( $form->{intnotes} ) {
        $href     .= "&intnotes=" . $form->escape( $form->{intnotes} );
        $callback .= "&intnotes=" . $form->escape( $form->{intnotes}, 1 );
        $option   .= "\n<br>" if $option;
        $option   .= $locale->text('Internal Notes') . " : $form->{intnotes}";
    }
    if ( $form->{lineitem} ) {
        $href     .= "&lineitem=" . $form->escape( $form->{lineitem} );
        $callback .= "&lineitem=" . $form->escape( $form->{lineitem}, 1 );
        $option   .= "\n<br>" if $option;
        $option   .= $locale->text('Line Item') . " : $form->{lineitem}";
    }
    if ( $form->{source} ) {
        $href     .= "&source=" . $form->escape( $form->{source} );
        $callback .= "&source=" . $form->escape( $form->{source}, 1 );
        $option   .= "\n<br>" if $option;
        $option   .= $locale->text('Source') . " : $form->{source}";
    }
    if ( $form->{memo} ) {
        $href     .= "&memo=" . $form->escape( $form->{memo} );
        $callback .= "&memo=" . $form->escape( $form->{memo}, 1 );
        $option   .= "\n<br>" if $option;
        $option   .= $locale->text('Memo') . " : $form->{memo}";
    }
    if ( $form->{datefrom} ) {
        $href     .= "&datefrom=$form->{datefrom}";
        $callback .= "&datefrom=$form->{datefrom}";
        $option   .= "\n<br>" if $option;
        $option   .= $locale->text('From') . " " . $locale->date( \%myconfig, $form->{datefrom}, 1 );
    }
    if ( $form->{dateto} ) {
        $href     .= "&dateto=$form->{dateto}";
        $callback .= "&dateto=$form->{dateto}";
        if ( $form->{datefrom} ) {
            $option .= " ";
        }
        else {
            $option .= "\n<br>" if $option;
        }
        $option .= $locale->text('To') . " " . $locale->date( \%myconfig, $form->{dateto}, 1 );
    }
    if ( $form->{accnofrom} ) {
        $href     .= "&accnofrom=$form->{accnofrom}";
        $callback .= "&accnofrom=$form->{accnofrom}";
        $option   .= "\n<br>" if $option;
        $option   .= $locale->text('Account') . " >= $form->{accnofrom} $form->{accnofrom_description}";
    }
    if ( $form->{accnoto} ) {
        $href     .= "&accnoto=$form->{accnoto}";
        $callback .= "&accnoto=$form->{accnoto}";
        if ( $form->{accnofrom} ) {
            $option .= " <= ";
        }
        else {
            $option .= "\n<br>" if $option;
            $option .= $locale->text('Account') . " <= ";
        }
        $option .= "$form->{accnoto} $form->{accnoto_description}";
    }

    if ( $form->{amountfrom} ) {
        $href     .= "&amountfrom=$form->{save_amountfrom}";
        $callback .= "&amountfrom=$form->{save_amountfrom}";
        $option   .= "\n<br>" if $option;
        $option   .= $locale->text('Amount') . " >= " . $form->format_amount( \%myconfig, $form->{amountfrom}, $form->{precision} );
    }
    if ( $form->{amountto} ) {
        $href     .= "&amountto=$form->{save_amountto}";
        $callback .= "&amountto=$form->{save_amountto}";
        if ( $form->{amountfrom} ) {
            $option .= " <= ";
        }
        else {
            $option .= "\n<br>" if $option;
            $option .= $locale->text('Amount') . " <= ";
        }
        $option .= $form->format_amount( \%myconfig, $form->{amountto}, $form->{precision} );
    }
    if ( $form->{onhold} ) {
        $callback .= "&onhold=$form->{onhold}";
        $href     .= "&onhold=$form->{onhold}";
        $option   .= "\n<br>" if ($option);
        $option   .= $locale->text('On Hold');
    }

    @columns = ();
    for ( split /,/, $form->{flds} ) {
        ( $column, $label, $sort ) = split /=/, $_;
        push @columns, $column;
        $column_data{$column} = $label;
        $column_sort{$column} = $sort;
        $column_align{$column} = 'left';
    }
    $column_align{debit} = 'right';
    $column_align{credit} = 'right';
    $column_align{exchangerate} = 'right';
    
    if ($form->{include_log}){
        $form->{l_log} = 'Y';
        push @columns, 'log';
        $column_data{log} = qq|&nbsp;|;
    }

    push @columns, "gifi_contra";
    $column_data{gifi_contra} = $column_data{contra};

    $columns{debit}  = 1;
    $columns{credit} = 1;

    if ( $form->{link} =~ /_paid/ ) {
        push @columns, "cleared";
        $column_data{cleared} = $locale->text('R');
        $form->{l_cleared} = "Y";
    }
    @columns = grep !/department/, @columns if $form->{department};

    $i = 0;
    if ( $form->{column_index} ) {
        for ( split /,/, $form->{column_index} ) {
            s/=.*//;
            push @column_index, $_;
            $column_index{$_} = ++$i;
            $form->{"l_$_"} = "Y";
        }
    }
    else {
        for (@columns) {
            if ( $form->{"l_$_"} eq "Y" ) {
                push @column_index, $_;
                $column_index{$_} = ++$i;
                $form->{column_index} .= "$_=$columns{$_},";
            }
        }
        chop $form->{column_index};
    }

    $form->save_lastused(\%myconfig, "gl-transactions", \@column_index);

    if ( $form->{accno} || $form->{gifi_accno} ) {
        @column_index = grep !/(accno|gifi_accno|contra|gifi_contra)/, @column_index;
        push @column_index, "balance";
        $column_data{balance} = $locale->text('Balance');
    }

    if ( $form->{l_contra} ) {
        $form->{l_gifi_contra} = "Y" if $form->{l_gifi_accno};
        $form->{l_contra}      = ""  if !$form->{l_accno};
    }

    if ( $form->{initreport} ) {
        if ( $form->{movecolumn} ) {
            @column_index = $form->sort_column_index;
        }
        else {
            @column_index         = ();
            $form->{column_index} = "";
            $i                    = 0;
            $j                    = 0;
            for ( split /,/, $form->{report_column_index} ) {
                s/=.*//;
                $j++;

                if ( $form->{"l_$_"} ) {
                    push @column_index, $_;
                    $form->{column_index} .= "$_=$columns{$_},";
                    delete $column_index{$_};
                    $i++;
                }
            }

            for ( sort { $column_index{$a} <=> $column_index{$b} } keys %column_index ) {
                push @column_index, $_;
            }

            $form->{column_index} = "";
            for (@column_index) { $form->{column_index} .= "$_=$columns{$_}," }
            chop $form->{column_index};

        }
    }
    else {
        if ( $form->{movecolumn} ) {
            @column_index = $form->sort_column_index;
        }
    }

    for (@columns) {
        if ( $form->{"l_$_"} eq "Y" ) {

            # add column to href and callback
            $callback .= "&l_$_=Y";
            $href     .= "&l_$_=Y";
        }
    }

    if ( $form->{l_subtotal} eq 'Y' ) {
        $callback .= "&l_subtotal=Y";
        $href     .= "&l_subtotal=Y";
    }
    $href     .= "&column_index=" . $form->escape( $form->{column_index} );
    $callback .= "&column_index=" . $form->escape( $form->{column_index} );

    $href     .= "&category=$form->{category}";
    
    $callback .= "&category=$form->{category}";

    $form->helpref( "list_gl_transactions", $myconfig{countrycode} );

    $form->header;

    my $today = $form->today(\%myconfig);

    print qq|
<body>

<button onclick="window.parent.postMessage({name: 'ledgerEvent', params: {event: 'urlToPdf', url: window.location.href}}, '*')" class="noprint nkp" style="background-color: white; cursor: pointer; position: fixed; top: 5px; right: 5px; height: 30px; width: 30px; margin: 0; padding: 0; outline: none; border: none; -webkit-appearance: none;">
  <img style="max-width: 100%" src="https://my.runmyaccounts.com/assets/img/file-icons/icons8-pdf-96.png">
</button>

<div align="center" class="redirectmsg noprint">$form->{redirectmsg}</div>
<div class="printonly"><span class="creation-date">$today</span></div>

<div class="printonly">
<span class="page-topleft">$form->{company}</span>
<span class="page-topright">$option</span>
</div>

<table width=100%>
  <tr>
    <th class=listtop>$form->{helpref}$form->{title}</a></th>
  </tr>
  <tr class="noprint" height="5"></tr>
  <tr class="noprint">
    <td>$option</td>
  </tr>
  <tr>
    <td>
      <table class="report-table" width=100%>
|;

    $l = $#column_index;

    print qq|<thead><tr class="table-sorting noprint">
|;

    if ( !( $form->{accno} || $form->{gifi_accno} ) ) {
        if ( $l > 0 ) {
            $revhref = $href;
            $direction = ( $form->{direction} eq 'DESC' ) ? "ASC" : "DESC";
            $revhref =~ s/direction=$direction/direction=$form->{direction}/;

            print "\n<td align=$column_align{$column_index[0]}><a href=$revhref&movecolumn=$column_index[0],right><img src=$images/right.png border=0></a></td>";
            for ( 1 .. $l - 1 ) {
                print
"\n<td align=$column_align{$column_index[$_]}><a href=$revhref&movecolumn=$column_index[$_],left><img src=$images/left.png border=0></a><a href=$href&movecolumn=$column_index[$_],right><img src=$images/right.png border=0></a></td>";
            }
            print "\n<td align=$column_align{$column_index[$_]}><a href=$revhref&movecolumn=$column_index[$l],left><img src=$images/left.png border=0></a></td>";
        }
    }

    print qq|
        </tr>
	    <tr class=listheading>
|;

    for ( 0 .. $l ) {
        if ( $column_sort{ $column_index[$_] } ) {
            $sort = "";
            if ( $form->{sort} eq $column_sort{ $column_index[$_] } ) {
                if ( $form->{direction} eq 'ASC' ) {
                    $sort = qq|<span class="noprint"><img src=$images/up.png>&nbsp;&nbsp;&nbsp;</span>|;
                }
                else {
                    $sort = qq|<span class="noprint"><img src=$images/down.png class="noprint" >&nbsp;&nbsp;&nbsp;</span>|;
                }
            }
            print qq|\n<th align=$column_align{$column_index[$_]} nowrap>$sort<a class=listheading href=$href&sort=$column_sort{$column_index[$_]}>$column_data{$column_index[$_]}</a></th>|;
        }
        else {
            print qq|\n<th align=$column_align{$column_index[$_]} nowrap class=listheading>$column_data{$column_index[$_]}</th>|;
        }
    }

    print qq|
        </tr></thead>
|;

    # add sort to callback
    $form->{callback} = "$callback&sort=$form->{sort}";
    $callback = $form->escape( $form->{callback} );

    $cml = 1;

    # initial item for subtotals
    if ( @{ $form->{GL} } ) {
        $sameitem = $form->{GL}->[0]->{ $form->{sort} };
        $cml = -1 if $form->{contra};
    }

    if ( ( $form->{accno} || $form->{gifi_accno} ) && $form->{balance} ) {

        for (@column_index) { $column_data{$_} = "<td>&nbsp;</td>" }
        $column_data{balance} = "<td align=right>" . $form->format_amount( \%myconfig, $form->{balance} * $ml * $cml, $form->{precision}, 0 ) . "</td>";

        if ( $ref->{id} != $sameid ) {
            $i++;
            $i %= 2;
        }

        print qq|
        <tr class=listrow$i>
|;
        for (@column_index) { print "$column_data{$_}\n" }

        print qq|
        </tr>
|;
    }

    # reverse href
    $direction = ( $form->{direction} eq 'ASC' ) ? "ASC" : "DESC";
    $form->sort_order();
    $href =~ s/direction=$form->{direction}/direction=$direction/;

    $i = 0;
    foreach $ref ( @{ $form->{GL} } ) {

        # if item ne sort print subtotal
        if ( $form->{l_subtotal} eq 'Y' ) {
            if ( $sameitem ne $ref->{ $form->{sort} } ) {
                &gl_subtotal;
            }
        }

        $form->{balance} += $ref->{amount};

        $subtotaldebit  += $ref->{debit};
        $subtotalcredit += $ref->{credit};
        $subtotaltaxamount += $ref->{taxamount};

        $totaldebit  += $ref->{debit};
        $totalcredit += $ref->{credit};
        $totaltaxamount += $ref->{taxamount};

        $ref->{debit}  = $form->format_amount( \%myconfig, $ref->{debit},  $form->{precision}, "&nbsp;" );
        $ref->{credit} = $form->format_amount( \%myconfig, $ref->{credit}, $form->{precision}, "&nbsp;" );
        $ref->{taxamount} = $form->format_amount( \%myconfig, $ref->{taxamount}, $form->{precision}, "&nbsp;" );
        if ($form->{l_exchangerate}){
           if ($ref->{payment_id}){
              my $exchangerate = $form->{dbs}->query("
                  SELECT exchangerate
                  FROM payment
                  WHERE trans_id = ?
                  AND id = ?",
                  $ref->{id}, $ref->{payment_id}
              )->list;
              $ref->{exchangerate} = $exchangerate if $exchangerate;
           }
        }
        $ref->{exchangerate} = $form->format_amount( \%myconfig, $ref->{exchangerate}, 8, "&nbsp;" );

        $column_data{id}        = "<td align=left>$ref->{id}</td>";
        $column_data{transdate} = "<td align=left>$ref->{transdate}</td>";

        $ref->{reference} ||= "&nbsp;";
        $column_data{reference} = "<td align=left><a href=$ref->{module}.pl?action=edit&id=$ref->{id}&path=$form->{path}&login=$form->{login}&callback=$callback>$ref->{reference}</a></td>";
        if ($ref->{log} eq '*'){
            $column_data{reference} = "<td align=left><a href=$ref->{module}.pl?action=view&id=$ref->{id}&ts=".$form->escape($ref->{ts})."&path=$form->{path}&login=$form->{login}&callback=$callback>$ref->{reference}</td>";
        }

        for (qw(tax department projectnumber name vcnumber address)) { $column_data{$_} = "<td align=left>$ref->{$_}</td>" }

        for (qw(lineitem description source memo notes intnotes)) {
            $ref->{$_} =~ s/\r?\n/<br>/g;
            $column_data{$_} = "<td align=left>$ref->{$_}</td>";
        }

        if ( $ref->{vc_id} ) {
            $column_data{name} = "<td align=left><a href=ct.pl?action=edit&id=$ref->{vc_id}&db=$ref->{db}&path=$form->{path}&login=$form->{login}&callback=$callback>$ref->{name}</a></td>";
        }

        $column_data{debit}  = "<td align=right>$ref->{debit}</td>";
        $column_data{credit} = "<td align=right>$ref->{credit}</td>";
        $column_data{taxamount} = "<td align=right>$ref->{taxamount}</td>";
        $column_data{exchangerate} = "<td align=right>$ref->{exchangerate}</td>";

        $column_data{accno}          = "<td align=left><a href=$href&accno=$ref->{accno}&callback=$callback>$ref->{accno}</a></td>";
        $column_data{accdescription} = "<td align=left>$ref->{accdescription}</td>";
        if ($ref->{fx_transaction}){
           $column_data{curr} = "<td>$form->{defaultcurrency}</td>";
        } else {
           $column_data{curr} = "<td>$ref->{curr}</td>";
        }
        $column_data{contra}         = "<td align=left>";
        for ( split / /, $ref->{contra} ) {
            $column_data{contra} .= qq|<a href=$href&accno=$_&callback=$callback>$_</a>&nbsp;|;
        }
        $column_data{contra} .= "</td>";
        $column_data{gifi_accno}  = "<td align=left><a href=$href&gifi_accno=$ref->{gifi_accno}&callback=$callback>$ref->{gifi_accno}</a>&nbsp;</td>";
        $column_data{gifi_contra} = "<td align=left>";
        for ( split / /, $ref->{gifi_contra} ) {
            $column_data{gifi_contra} .= qq|<a href=$href&gifi_accno=$_&callback=$callback>$_</a>&nbsp;|;
        }
        $column_data{gifi_contra} .= "</td>";

        $column_data{balance} = "<td align=right>" . $form->format_amount( \%myconfig, $form->{balance} * $ml * $cml, $form->{precision}, 0 ) . "</td>";
        $column_data{cleared} = ( $ref->{cleared} ) ? "<td>*</td>" : "<td>&nbsp;</td>";
        $column_data{log} = "<td align=left>$ref->{log}</td>";
        $column_data{ts} = "<td align=left>$ref->{ts}</td>";

        if ( $ref->{id} != $sameid ) {
            $i++;
            $i %= 2;
        }
        print "
        <tr class=listrow$i>";
        for (@column_index) { print "$column_data{$_}\n" }
        print qq|
        <td align=left nowrap class="noprint nkp">
          <a href='javascript:void(0);' onclick="window.parent.postMessage(
          {name: 'ledgerEvent', params:{event: 'uploadLinkAndSignFile', id:$ref->{id}, origin: window.location.pathname}}, '*')">
           <img style="width: 1.5em; padding-left:0.3em; padding-right:0.3em; align:top; filter: invert(100%); background-color: #bb490f"
           src="https://my.runmyaccounts.com/assets/img/file-icons/cloud-upload-solid.svg">
          <a/>
        </td>|;
        print "</tr>";

        $sameid = $ref->{id};
    }

    &gl_subtotal if ( $form->{l_subtotal} eq 'Y' );

    for (@column_index) { $column_data{$_} = "<td>&nbsp;</td>" }

    $column_data{debit}   = "<th align=right class=listtotal>" . $form->format_amount( \%myconfig, $totaldebit,                   $form->{precision}, "&nbsp;" ) . "</th>";
    $column_data{credit}  = "<th align=right class=listtotal>" . $form->format_amount( \%myconfig, $totalcredit,                  $form->{precision}, "&nbsp;" ) . "</th>";
    $column_data{taxamount}  = "<th align=right class=listtotal>" . $form->format_amount( \%myconfig, $totaltaxamount,                  $form->{precision}, "&nbsp;" ) . "</th>";
    $column_data{balance} = "<th align=right class=listtotal>" . $form->format_amount( \%myconfig, $form->{balance} * $ml * $cml, $form->{precision}, 0 ) . "</th>";

    print qq|
	<tr class=listtotal>
|;

    for (@column_index) { print "$column_data{$_}\n" }

    %button = (
        'General Ledger--Add Transaction' => { ndx => 1, key => 'G', value => $locale->text('GL Transaction') },
        'AR--Add Transaction'             => { ndx => 2, key => 'R', value => $locale->text('AR Transaction') },
        'AR--Sales Invoice'               => { ndx => 3, key => 'I', value => $locale->text('Sales Invoice ') },
        'AR--Credit Invoice'              => { ndx => 4, key => 'C', value => $locale->text('Credit Invoice ') },
        'AP--Add Transaction'             => { ndx => 5, key => 'P', value => $locale->text('AP Transaction') },
        'AP--Vendor Invoice'              => { ndx => 6, key => 'V', value => $locale->text('Vendor Invoice ') },
        'AP--Vendor Invoice'              => { ndx => 7, key => 'D', value => $locale->text('Debit Invoice ') },
        'Save Report'                     => { ndx => 8, key => 'S', value => $locale->text('Save Report') }
    );

    if ( !$form->{admin} ) {
        delete $button{'Save Report'} unless $form->{savereport};
    }

    if ( $myconfig{acs} =~ /General Ledger--General Ledger/ ) {
        delete $button{'General Ledger--Add Transaction'};
    }
    if ( $myconfig{acs} =~ /AR--AR/ ) {
        delete $button{'AR--Add Transaction'};
        delete $button{'AR--Sales Invoice'};
        delete $button{'AR--Credit Invoice'};
    }
    if ( $myconfig{acs} =~ /AP--AP/ ) {
        delete $button{'AP--AP Transaction'};
        delete $button{'AP--Vendor Invoice'};
        delete $button{'AP--Debit Invoice'};
    }

    foreach $item ( split /;/, $myconfig{acs} ) {
        delete $button{$item};
    }

    if ( $form->{accno} || $form->{gifi_accno} ) {
        delete $button{'Save Report'};
    }

    print qq|
        </tr>
      </table>
    </td>
  </tr>
  <tr>
    <td><hr size=3 noshade></td>
  </tr>
</table>

<br>

<form method=post action=$form->{script}>
|;

    if ( $form->{year} && $form->{month} ) {
        for (qw(datefrom dateto)) { delete $form->{$_} }
    }
    $form->hide_form(
        qw(department reference description name vcnumber lineitem notes source memo datefrom dateto month year accnofrom accnoto amountfrom amountto interval category l_subtotal intnotes));

    $form->hide_form(qw(callback path login report reportcode reportlogin column_index flds sort direction));

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

sub gl_subtotal {

    $subtotaldebit  = $form->format_amount( \%myconfig, $subtotaldebit,  $form->{precision}, "&nbsp;" );
    $subtotalcredit = $form->format_amount( \%myconfig, $subtotalcredit, $form->{precision}, "&nbsp;" );
    $subtotaltaxamount = $form->format_amount( \%myconfig, $subtotaltaxamount, $form->{precision}, "&nbsp;" );

    for (@column_index) { $column_data{$_} = "<td>&nbsp;</td>" }

    $column_data{debit}  = "<th align=right class=listsubtotal>$subtotaldebit</td>";
    $column_data{credit} = "<th align=right class=listsubtotal>$subtotalcredit</td>";
    $column_data{taxamount} = "<th align=right class=listsubtotal>$subtotaltaxamount</td>";

    print "<tr class=listsubtotal>";
    for (@column_index) { print "$column_data{$_}\n" }
    print "</tr>";

    $subtotaldebit  = 0;
    $subtotalcredit = 0;
    $subtotaltaxamount = 0;

    $sameitem = $ref->{ $form->{sort} };

}

sub transactions_to_csv {

    $filename = 'gl';

    my ($fh, $name) = tempfile();

    ( $form->{reportdescription}, $form->{reportid} ) = split /--/, $form->{report};
    $form->{sort} ||= "transdate";
    $form->{reportcode} = 'gl';

    GL->transactions( \%myconfig, \%$form );

    $href = "$form->{script}?action=transactions";
    for (qw(direction oldsort path login month year interval reportlogin)) { $href .= "&$_=$form->{$_}" }
    for (qw(report flds))                                                  { $href .= "&$_=" . $form->escape( $form->{$_} ) }

    $form->sort_order();

    $callback = "$form->{script}?action=transactions";
    for (qw(direction oldsort path login month year interval reportlogin)) { $callback .= "&$_=$form->{$_}" }
    for (qw(report flds))                                                  { $callback .= "&$_=" . $form->escape( $form->{$_} ) }

    %acctype = (
        'A' => $locale->text('Asset'),
        'L' => $locale->text('Liability'),
        'Q' => $locale->text('Equity'),
        'I' => $locale->text('Income'),
        'E' => $locale->text('Expense'),
    );

    $form->{title} = $locale->text('General Ledger') . " / $form->{company}";

    $ml = ( $form->{category} =~ /(A|E)/ ) ? -1 : 1;

    unless ( $form->{category} eq 'X' ) {
        $form->{title} .= " : " . $locale->text( $acctype{ $form->{category} } );
    }
    if ( $form->{accno} ) {
        $href .= "&accno=" . $form->escape( $form->{accno} );
        $callback .= "&accno=" . $form->escape( $form->{accno}, 1 );
        $option = $locale->text('Account') . " : $form->{accno} $form->{account_description}";
    }
    if ( $form->{gifi_accno} ) {
        $href     .= "&gifi_accno=" . $form->escape( $form->{gifi_accno} );
        $callback .= "&gifi_accno=" . $form->escape( $form->{gifi_accno}, 1 );
        $option   .= "\n<br>" if $option;
        $option   .= $locale->text('GIFI') . " : $form->{gifi_accno} $form->{gifi_account_description}";
    }
    if ( $form->{reference} ) {
        $href     .= "&reference=" . $form->escape( $form->{reference} );
        $callback .= "&reference=" . $form->escape( $form->{reference}, 1 );
        $option   .= "\n<br>" if $option;
        $option   .= $locale->text('Reference') . " / " . $locale->text('Invoice Number') . " : $form->{reference}";
    }
    if ( $form->{description} ) {
        $href     .= "&description=" . $form->escape( $form->{description} );
        $callback .= "&description=" . $form->escape( $form->{description}, 1 );
        $option   .= "\n<br>" if $option;
        $option   .= $locale->text('Description') . " : $form->{description}";
    }
    if ( $form->{name} ) {
        $href     .= "&name=" . $form->escape( $form->{name} );
        $callback .= "&name=" . $form->escape( $form->{name}, 1 );
        $option   .= "\n<br>" if $option;
        $option   .= $locale->text('Company Name') . " : $form->{name}";
    }
    if ( $form->{vcnumber} ) {
        $href     .= "&vcnumber=" . $form->escape( $form->{vcnumber} );
        $callback .= "&vcnumber=" . $form->escape( $form->{vcnumber}, 1 );
        $option   .= "\n<br>" if $option;
        $option   .= $locale->text('Company Number') . " : $form->{vcnumber}";
    }
    if ( $form->{department} ) {
        $href .= "&department=" . $form->escape( $form->{department} );
        $callback .= "&department=" . $form->escape( $form->{department}, 1 );
        ($department) = split /--/, $form->{department};
        $option .= "\n<br>" if $option;
        $option .= $locale->text('Department') . " : $department";
    }
    if ( $form->{projectnumber} ) {
        $href .= "&projectnumber=" . $form->escape( $form->{projectnumber} );
        $callback .= "&projectnumber=" . $form->escape( $form->{projectnumber}, 1 );
        ($projectnumber) = split /--/, $form->{projectnumber};
        $option .= "\n<br>" if $option;
        $option .= $locale->text('Project') . " : $projectnumber";
    }
    if ( $form->{notes} ) {
        $href     .= "&notes=" . $form->escape( $form->{notes} );
        $callback .= "&notes=" . $form->escape( $form->{notes}, 1 );
        $option   .= "\n<br>" if $option;
        $option   .= $locale->text('Notes') . " : $form->{notes}";
    }
    if ( $form->{intnotes} ) {
        $href     .= "&intnotes=" . $form->escape( $form->{intnotes} );
        $callback .= "&intnotes=" . $form->escape( $form->{intnotes}, 1 );
        $option   .= "\n<br>" if $option;
        $option   .= $locale->text('Internal Notes') . " : $form->{intnotes}";
    }
    if ( $form->{lineitem} ) {
        $href     .= "&lineitem=" . $form->escape( $form->{lineitem} );
        $callback .= "&lineitem=" . $form->escape( $form->{lineitem}, 1 );
        $option   .= "\n<br>" if $option;
        $option   .= $locale->text('Line Item') . " : $form->{lineitem}";
    }
    if ( $form->{source} ) {
        $href     .= "&source=" . $form->escape( $form->{source} );
        $callback .= "&source=" . $form->escape( $form->{source}, 1 );
        $option   .= "\n<br>" if $option;
        $option   .= $locale->text('Source') . " : $form->{source}";
    }
    if ( $form->{memo} ) {
        $href     .= "&memo=" . $form->escape( $form->{memo} );
        $callback .= "&memo=" . $form->escape( $form->{memo}, 1 );
        $option   .= "\n<br>" if $option;
        $option   .= $locale->text('Memo') . " : $form->{memo}";
    }
    if ( $form->{datefrom} ) {
        $href     .= "&datefrom=$form->{datefrom}";
        $callback .= "&datefrom=$form->{datefrom}";
        $option   .= "\n<br>" if $option;
        $option   .= $locale->text('From') . " " . $locale->date( \%myconfig, $form->{datefrom}, 1 );
    }
    if ( $form->{dateto} ) {
        $href     .= "&dateto=$form->{dateto}";
        $callback .= "&dateto=$form->{dateto}";
        if ( $form->{datefrom} ) {
            $option .= " ";
        }
        else {
            $option .= "\n<br>" if $option;
        }
        $option .= $locale->text('To') . " " . $locale->date( \%myconfig, $form->{dateto}, 1 );
    }
    if ( $form->{accnofrom} ) {
        $href     .= "&accnofrom=$form->{accnofrom}";
        $callback .= "&accnofrom=$form->{accnofrom}";
        $option   .= "\n<br>" if $option;
        $option   .= $locale->text('Account') . " >= $form->{accnofrom} $form->{accnofrom_description}";
    }
    if ( $form->{accnoto} ) {
        $href     .= "&accnoto=$form->{accnoto}";
        $callback .= "&accnoto=$form->{accnoto}";
        if ( $form->{accnofrom} ) {
            $option .= " <= ";
        }
        else {
            $option .= "\n<br>" if $option;
            $option .= $locale->text('Account') . " <= ";
        }
        $option .= "$form->{accnoto} $form->{accnoto_description}";
    }
    if ( $form->{amountfrom} ) {
        $href     .= "&amountfrom=$form->{amountfrom}";
        $callback .= "&amountfrom=$form->{amountfrom}";
        $option   .= "\n<br>" if $option;
        $option   .= $locale->text('Amount') . " >= " . $form->format_amount( \%myconfig, $form->{amountfrom}, $form->{precision} );
    }
    if ( $form->{amountto} ) {
        $href     .= "&amountto=$form->{amountto}";
        $callback .= "&amountto=$form->{amountto}";
        if ( $form->{amountfrom} ) {
            $option .= " <= ";
        }
        else {
            $option .= "\n<br>" if $option;
            $option .= $locale->text('Amount') . " <= ";
        }
        $option .= $form->format_amount( \%myconfig, $form->{amountto}, $form->{precision} );
    }

    @columns = ();
    for ( split /,/, $form->{flds} ) {
        ( $column, $label, $sort ) = split /=/, $_;
        push @columns, $column;
        $column_data{$column} = $label;
        $column_sort{$column} = $sort;
    }

    push @columns, "gifi_contra";
    $column_data{gifi_contra} = $column_data{contra};

    $columns{debit}  = 1;
    $columns{credit} = 1;

    if ( $form->{link} =~ /_paid/ ) {
        push @columns, "cleared";
        $column_data{cleared} = $locale->text('R');
        $form->{l_cleared} = "Y";
    }
    @columns = grep !/department/, @columns if $form->{department};

    $i = 0;
    if ( $form->{column_index} ) {
        for ( split /,/, $form->{column_index} ) {
            s/=.*//;
            push @column_index, $_;
            $column_index{$_} = ++$i;
            $form->{"l_$_"} = "Y";
        }
    }
    else {
        for (@columns) {
            if ( $form->{"l_$_"} eq "Y" ) {
                push @column_index, $_;
                $column_index{$_} = ++$i;
                $form->{column_index} .= "$_=$columns{$_},";
            }
        }
        chop $form->{column_index};
    }

    if ( $form->{accno} || $form->{gifi_accno} ) {
        @column_index = grep !/(accno|gifi_accno|contra|gifi_contra)/, @column_index;
        push @column_index, "balance";
        $column_data{balance} = $locale->text('Balance');
    }

    if ( $form->{l_contra} ) {
        $form->{l_gifi_contra} = "Y" if $form->{l_gifi_accno};
        $form->{l_contra}      = ""  if !$form->{l_accno};
    }

    if ( $form->{initreport} ) {
        if ( $form->{movecolumn} ) {
            @column_index = $form->sort_column_index;
        }
        else {
            @column_index         = ();
            $form->{column_index} = "";
            $i                    = 0;
            $j                    = 0;
            for ( split /,/, $form->{report_column_index} ) {
                s/=.*//;
                $j++;

                if ( $form->{"l_$_"} ) {
                    push @column_index, $_;
                    $form->{column_index} .= "$_=$columns{$_},";
                    delete $column_index{$_};
                    $i++;
                }
            }

            for ( sort { $column_index{$a} <=> $column_index{$b} } keys %column_index ) {
                push @column_index, $_;
            }

            $form->{column_index} = "";
            for (@column_index) { $form->{column_index} .= "$_=$columns{$_}," }
            chop $form->{column_index};

        }
    }
    else {
        if ( $form->{movecolumn} ) {
            @column_index = $form->sort_column_index;
        }
    }

    for (@columns) {
        if ( $form->{"l_$_"} eq "Y" ) {

            # add column to href and callback
            $callback .= "&l_$_=Y";
            $href     .= "&l_$_=Y";
        }
    }

    if ( $form->{l_subtotal} eq 'Y' ) {
        $callback .= "&l_subtotal=Y";
        $href     .= "&l_subtotal=Y";
    }
    $href     .= "&column_index=" . $form->escape( $form->{column_index} );
    $callback .= "&column_index=" . $form->escape( $form->{column_index} );

    $href     .= "&category=$form->{category}";
    $callback .= "&category=$form->{category}";

    $form->helpref( "list_gl_transactions", $myconfig{countrycode} );

    $l = $#column_index;

    for ( 0 .. $l ) {
        print $fh qq|"$column_data{$column_index[$_]}",|;
    }
    print $fh qq|\n|;

    # add sort to callback
    $form->{callback} = "$callback&sort=$form->{sort}";
    $callback = $form->escape( $form->{callback} );

    $cml = 1;

    # initial item for subtotals
    if ( @{ $form->{GL} } ) {
        $sameitem = $form->{GL}->[0]->{ $form->{sort} };
        $cml = -1 if $form->{contra};
    }

    if ( ( $form->{accno} || $form->{gifi_accno} ) && $form->{balance} ) {

        for (@column_index) { $column_data{$_} = "" }
        $column_data{balance} = '"' . $form->format_amount( \%myconfig, $form->{balance} * $ml * $cml, $form->{precision}, 0 ) . '"';

        if ( $ref->{id} != $sameid ) {
            $i++;
            $i %= 2;
        }

        for (@column_index) { print $fh qq|"$column_data{$_}",| }

    }

    # reverse href
    $direction = ( $form->{direction} eq 'ASC' ) ? "ASC" : "DESC";
    $form->sort_order();
    $href =~ s/direction=$form->{direction}/direction=$direction/;

    $i = 0;
    foreach $ref ( @{ $form->{GL} } ) {

        # if item ne sort print subtotal
        if ( $form->{l_subtotal} eq 'Y' ) {
            if ( $sameitem ne $ref->{ $form->{sort} } ) {
                &gl_subtotal_to_csv($fh);
            }
        }

        $form->{balance} += $ref->{amount};

        $subtotaldebit  += $ref->{debit};
        $subtotalcredit += $ref->{credit};
        $subtotaltaxamount += $ref->{taxamount};

        $totaldebit  += $ref->{debit};
        $totalcredit += $ref->{credit};
        $totaltaxamount += $ref->{taxmount};

        $ref->{debit}  = $ref->{debit};
        $ref->{credit} = $ref->{credit};
        $ref->{taxamount} = $ref->{taxamount};

        $column_data{id}        = "$ref->{id}";
        $column_data{transdate} = "$ref->{transdate}";

        $ref->{reference} ||= "";
        $column_data{reference} = "$ref->{reference}";

        for (qw(department projectnumber name vcnumber address exchangerate curr ts)) { $column_data{$_} = "$ref->{$_}" }

        for (qw(lineitem description source memo notes intnotes)) {
            $column_data{$_} = &escape_csv( $ref->{$_} );
        }

        if ( $ref->{vc_id} ) {
            $column_data{name} = "$ref->{name}";
        }

        $column_data{debit}  = $ref->{debit};
        $column_data{credit} = $ref->{credit};

        $column_data{accno}          = "$ref->{accno}";
        $column_data{accdescription} = "$ref->{accdescription}";
        $column_data{contra}         = "";
        for ( split / /, $ref->{contra} ) {
            $column_data{contra} .= qq|$_ |;
        }
        $column_data{contra} .= "";
        $column_data{gifi_accno}  = "$ref->{gifi_accno}";
        $column_data{gifi_contra} = "";
        for ( split / /, $ref->{gifi_contra} ) {
            $column_data{gifi_contra} .= qq|$_ |;
        }
        $column_data{gifi_contra} .= "";

        $column_data{balance} = $form->format_amount( \%myconfig, $form->{balance} * $ml * $cml, $form->{precision}, 0 );
        $column_data{cleared} = ( $ref->{cleared} ) ? "*" : "";

        if ( $ref->{id} != $sameid ) {
            $i++;
            $i %= 2;
        }
        for (@column_index) { print $fh qq|"$column_data{$_}",| }
        print $fh "\n";

        $sameid = $ref->{id};
    }

    &gl_subtotal_to_csv($fh) if ( $form->{l_subtotal} eq 'Y' );

    for (@column_index) { $column_data{$_} = "" }

    $column_data{debit}   = $totaldebit;
    $column_data{credit}  = $totalcredit;
    $column_data{balance} = $form->{balance} * $ml * $cml;

    for (@column_index) { print $fh qq|"$column_data{$_}",| }
    print $fh qq|\n|;

    %button = (
        'General Ledger--Add Transaction' => { ndx => 1, key => 'G', value => $locale->text('GL Transaction') },
        'AR--Add Transaction'             => { ndx => 2, key => 'R', value => $locale->text('AR Transaction') },
        'AR--Sales Invoice'               => { ndx => 3, key => 'I', value => $locale->text('Sales Invoice ') },
        'AR--Credit Invoice'              => { ndx => 4, key => 'C', value => $locale->text('Credit Invoice ') },
        'AP--Add Transaction'             => { ndx => 5, key => 'P', value => $locale->text('AP Transaction') },
        'AP--Vendor Invoice'              => { ndx => 6, key => 'V', value => $locale->text('Vendor Invoice ') },
        'AP--Vendor Invoice'              => { ndx => 7, key => 'D', value => $locale->text('Debit Invoice ') },
        'Save Report'                     => { ndx => 8, key => 'S', value => $locale->text('Save Report') }
    );

    if ( !$form->{admin} ) {
        delete $button{'Save Report'} unless $form->{savereport};
    }

    if ( $myconfig{acs} =~ /General Ledger--General Ledger/ ) {
        delete $button{'General Ledger--Add Transaction'};
    }
    if ( $myconfig{acs} =~ /AR--AR/ ) {
        delete $button{'AR--Add Transaction'};
        delete $button{'AR--Sales Invoice'};
        delete $button{'AR--Credit Invoice'};
    }
    if ( $myconfig{acs} =~ /AP--AP/ ) {
        delete $button{'AP--AP Transaction'};
        delete $button{'AP--Vendor Invoice'};
        delete $button{'AP--Debit Invoice'};
    }

    foreach $item ( split /;/, $myconfig{acs} ) {
        delete $button{$item};
    }

    if ( $form->{accno} || $form->{gifi_accno} ) {
        delete $button{'Save Report'};
    }

    close($fh) || $form->error('Cannot close csv file');

    my @fileholder;
    open( DLFILE, qq|<$name| ) || $form->error('Cannot open file for download');
    @fileholder = <DLFILE>;
    close(DLFILE) || $form->error('Cannot close file opened for download');
    my $dlfile = $filename . ".csv";
    print "Content-Type: application/csv\n";
    print "Content-Disposition:attachment; filename=$dlfile\n\n";
    print @fileholder;
    unlink($name) or die "Couldn't unlink $name : $!";
}

sub gl_subtotal_to_csv {
    $fh = shift;

    for (@column_index) { $column_data{$_} = "" }

    $column_data{debit}  = $subtotaldebit;
    $column_data{credit} = $subtotalcredit;
    $column_data{taxamount} = $subtotaltaxamount;

    for (@column_index) { print $fh qq|"$column_data{$_}",| }
    print $fh qq|\n|;

    $subtotaldebit  = 0;
    $subtotalcredit = 0;
    $subtotaltaxamount = 0;

    $sameitem = $ref->{ $form->{sort} };

}

sub update {

    $form->isvaldate(\%myconfig, $form->{transdate}, $locale->text('Invalid date ...'));

    if ( $form->{currency} ne $form->{defaultcurrency} ) {
        $form->{exchangerate} = $form->parse_amount( \%myconfig, $form->{exchangerate} );
    }

    if ( $form->{transdate} ne $form->{oldtransdate} ) {
        if ( $form->{selectprojectnumber} ) {
            $form->all_projects( \%myconfig, undef, $form->{transdate} );
            if ( @{ $form->{all_project} } ) {
                $form->{selectprojectnumber} = "\n";
                for ( @{ $form->{all_project} } ) { $form->{selectprojectnumber} .= qq|$_->{projectnumber}--$_->{id}\n| }
                $form->{selectprojectnumber} = $form->escape( $form->{selectprojectnumber}, 1 );
            }
        }
        $form->{oldtransdate} = $form->{transdate};

        $form->{exchangerate} = $form->check_exchangerate( \%myconfig, $form->{currency}, $form->{transdate} );
        $form->{oldcurrency} = $form->{currency};
    }

    $form->{exchangerate} = $form->check_exchangerate( \%myconfig, $form->{currency}, $form->{transdate} ) if $form->{currency} ne $form->{oldcurrency};

    $form->{oldcurrency} = $form->{currency};

    @a     = ();
    $count = 0;
    @flds  = qw(accno debit credit taxamount projectnumber tax source memo cleared);

    # per line tax
    for $i ( 1 .. $form->{rowcount} ) {
        unless ( ( $form->{"debit_$i"} eq "" ) && ( $form->{"credit_$i"} eq "" ) ) {
            for (qw(debit credit)) { $form->{"${_}_$i"} = $form->parse_amount( \%myconfig, $form->{"${_}_$i"} ) }

            push @a, {};
            $j = $#a;

            for (@flds) { $a[$j]->{$_} = $form->{"${_}_$i"} }
            $count++;
        }
    }

    for $i ( 1 .. $count ) {
        $j = $i - 1;
        for (@flds) { $form->{"${_}_$i"} = $a[$j]->{$_} }
    }

    for $i ( $count + 1 .. $form->{rowcount} ) {
        for (@flds) { delete $form->{"${_}_$i"} }
    }

    my $dbh = $form->dbconnect( \%myconfig );
    for $i ( 1 .. $count ) {
        if ( $form->{"tax_$i"} and !$form->{"taxamount_$i"} ) {
            my ( $tax_accno, $null ) = split( /--/, $form->{"tax_$i"} );
            ($tax_rate) = $dbh->selectrow_array(
                qq|
                SELECT rate 
                FROM tax 
                WHERE chart_id = (SELECT id FROM chart WHERE accno = '$tax_accno')
                AND (validto IS NULL OR validto >= '$form->{transdate}')|
            );
            $taxamount = $form->round_amount( ( $form->{"debit_$i"} + $form->{"credit_$i"} ) - ( $form->{"debit_$i"} + $form->{"credit_$i"} ) / ( 1 + $tax_rate ), $form->{precision} );
            $form->{"taxamount_$i"} = $taxamount;
        }
    }
    $dbh->disconnect;

    $form->{rowcount} = $count + 1;

    &display_form;

}

sub display_form {
    my ($init) = @_;

    &form_header;
    &display_rows($init);
    &form_footer;

    if ($form->{id}){
        if ($debits_credits_footer){

          use DBIx::Simple;
          $form->{dbh} = $form->dbconnect(\%myconfig);
          $form->{dbs} = DBIx::Simple->connect($form->{dbh});

          $form->{dbh}->do("create table debits (id serial, reference text, description text, transdate date, accno text, amount numeric(12,2))");
          $form->{dbh}->do("create table credits (id serial, reference text, description text, transdate date, accno text, amount numeric(12,2))");
          $form->{dbh}->do("create table debitscredits (id serial, reference text, description text, transdate date, debit_accno text, credit_accno text, amount numeric(12,2))");

          $form->{dbs}->query('delete from debits');
          $form->{dbs}->query('delete from credits');
          $form->{dbs}->query('delete from debitscredits');

          my %debits; my %credits;
          for my $i (1 .. $form->{rowcount}){
             $form->{"debit_$i"} = $form->parse_amount(\%myconfig, $form->{"debit_$i"});
             $form->{"credit_$i"} = $form->parse_amount(\%myconfig, $form->{"credit_$i"});
             $form->{dbs}->query(qq|insert into debits (accno, amount) values ('$form->{"accno_$i"}', $form->{"debit_$i"})|) if $form->{"debit_$i"} > 0;
             $form->{dbs}->query(qq|insert into credits (accno, amount) values ('$form->{"accno_$i"}', $form->{"credit_$i"})|) if $form->{"credit_$i"} > 0;
          }

          for $row (@rows = ($form->{dbs}->query(qq|select * from debits order by amount|)->hashes)){
             for $row2 (@rows2 = ($form->{dbs}->query(qq|select * from credits where amount = $row->{amount} limit 1|)->hashes)){
                $form->{dbs}->query('insert into debitscredits (debit_accno, credit_accno, amount) values (?, ?, ?)',
                    $row->{accno}, $row2->{accno}, $row->{amount});
                $form->{dbs}->query('delete from debits where id = ?', $row->{id});
                $form->{dbs}->query('delete from credits where id = ?', $row2->{id});
             }
          }

          while (1){
              $debitrow = $form->{dbs}->query(qq|select * from debits order by amount DESC limit 1|)->hash;
              $creditrow = $form->{dbs}->query(qq|select * from credits order by amount DESC limit 1|)->hash;
              if ($debitrow->{amount} and $creditrow->{amount}){
                  if ($debitrow->{amount} > $creditrow->{amount}){
                      $form->{dbs}->query('insert into debitscredits (debit_accno, credit_accno, amount) values (?, ?, ?)',
                            $debitrow->{accno}, $creditrow->{accno}, $creditrow->{amount});
                      $form->{dbs}->query(qq|delete from credits where id = $creditrow->{id}|);
                      $form->{dbs}->query(qq|update debits set amount = amount - $creditrow->{amount} where id = $debitrow->{id}|);
                  } else {
                      $form->{dbs}->query('insert into debitscredits (debit_accno, credit_accno, amount) values (?, ?, ?)',
                            $debitrow->{accno}, $creditrow->{accno}, $debitrow->{amount});
                      $form->{dbs}->query(qq|delete from debits where id = $debitrow->{id}|);
                      $form->{dbs}->query(qq|update credits set amount = amount - $debitrow->{amount} where id = $creditrow->{id}|);
                  }
              } else {
                last;
              }
          }

        $table1 = $form->{dbs}->query(qq|SELECT * FROM debitscredits ORDER BY reference, amount DESC|)->xto(
                tr => { class => [ 'listrow0', 'listrow1' ] },
                th => { class => ['listheading'] },
        );
        $table1->modify( td => { align => 'right' }, 'amount' );
        $table1->calc_totals( 'amount' );
        print $table1->output;
    }
  }

}

sub display_rows {
    my ($init) = @_;

    $form->{totaldebit}     = 0;
    $form->{totalcredit}    = 0;
    $form->{totaltaxamount} = 0;

    for $i ( 1 .. $form->{rowcount} ) {

        $source = qq|<input name="source_$i" size=10 value="| . $form->quote( $form->{"source_$i"} ) . qq|">|;
        $memo = qq|<input name="memo_$i" value="| . $form->quote( $form->{"memo_$i"} ) . qq|">|;

        if ($init) {
            $accno = qq|<select name="accno_$i">| . $form->select_option( $form->{selectaccno} ) . qq|</select>|;

            if ( $form->{selectprojectnumber} ) {
                $project = qq|<select name="projectnumber_$i">| . $form->select_option( $form->{selectprojectnumber}, undef, 1 ) . qq|</select>|;
            }

            if ( $form->{selecttax} ) {
                $tax = qq|<select name="tax_$i">| . $form->select_option( $form->{selecttax} ) . qq|</select>|;
                $taxamount = qq|<input name="taxamount_$i" class="inputright" type=text size=12 value="| . $form->format_amount( \%myconfig, $form->{"taxamount_$i"}, $form->{precision} ) . qq|">|;
            }

            if ( $form->{fxadj} ) {
                $fx_transaction = qq|<td><input name="fx_transaction_$i" class=checkbox type=checkbox value=1></td>|;
                $fx_transaction2 = qq|<td>&nbsp;</td>|;
            }

        } else {

            $form->{totaldebit}     += $form->{"debit_$i"};
            $form->{totalcredit}    += $form->{"credit_$i"};
            $form->{totaltaxamount} += $form->{"taxamount_$i"};

            for (qw(debit credit)) { $form->{"${_}_$i"} = ( $form->{"${_}_$i"} ) ? $form->format_amount( \%myconfig, $form->{"${_}_$i"}, $form->{precision} ) : "" }

            if ( $i < $form->{rowcount} ) {

                $accno = qq|$form->{"accno_$i"}|;

                if ( $form->{selectprojectnumber} ) {
                    $project = $form->{"projectnumber_$i"};
                    $project =~ s/--.*//;
                    $project = qq|$project|;
                }

                if ( $form->{selecttax} ) {
                    $tax = $form->{"tax_$i"};
                    $tax = qq|$tax|;
                    $taxamount = qq|<input name="taxamount_$i" class="inputright" type=text size=12 value="| . $form->format_amount( \%myconfig, $form->{"taxamount_$i"}, $form->{precision} ) . qq|">|;
                }

                if ( $form->{fxadj} ) {
                    $checked = ( $form->{"fx_transaction_$i"} ) ? "1" : "";
                    $x = ($checked) ? "x" : "";
                    $fx_transaction = qq|<td><input type=hidden name="fx_transaction_$i" value="$checked">$x</td>|;
                    $fx_transaction2 = qq|<td>&nbsp;</td>|;
                }

                $form->hide_form( map { "${_}_$i" } qw(accno projectnumber tax) );

            }
            else {

                $accno = qq|<select name="accno_$i">| . $form->select_option( $form->{selectaccno} ) . qq|</select>|;

                if ( $form->{selectprojectnumber} ) {
                    $project = qq|<select name="projectnumber_$i">| . $form->select_option( $form->{selectprojectnumber}, undef, 1 ) . qq|</select>|;
                }

                if ( $form->{selecttax} ) {
                    $tax = qq|<select name="tax_$i">| . $form->select_option( $form->{selecttax} ) . qq|</select>|;
                    $taxamount = qq|<input name="taxamount_$i" class="inputright" type=text size=12 value="| . $form->format_amount( \%myconfig, $form->{"taxamount_$i"}, $form->{precision} ) . qq|">|;
                }

                if ( $form->{fxadj} ) {
                    $fx_transaction = qq|<td><input name="fx_transaction_$i" class=checkbox type=checkbox value=1></td>|;
                    $fx_transaction2 = qq|<td>&nbsp;</td>|;
                }
            }
        }

        if ($form->{selecttax}){
            print qq|
            <tr valign=top>
                <td>$accno</td>
                $fx_transaction
                <td align="right"><input name="debit_$i" size=12 value="$form->{"debit_$i"}" accesskey=$i></td>
                <td align="right"><input name="credit_$i" size=12 value=$form->{"credit_$i"}></td>
                <td>$tax<br/>
                <td>$taxamount</td>
            </tr>
            <tr>
                <td>$memo $source</td>
                $fx_transaction2
                <td>&nbsp;</td>
                <td>&nbsp;</td>
                <td>$project</td>
                <td>&nbsp;</td>
            </tr>|;
        } else {
            print qq|
            <tr valign=top>
                <td>$accno</td>
                $fx_transaction
                <td align="right"><input name="debit_$i" size=12 value="$form->{"debit_$i"}" accesskey=$i></td>
                <td align="right"><input name="credit_$i" size=12 value=$form->{"credit_$i"}></td>
                <td>$source</td>
                <td>$memo</td>
                <td>$project</td>
            </tr>|;
        }

        $form->hide_form("cleared_$i");
    }

    $form->hide_form(qw(rowcount));
    $form->hide_form( map { "select$_" } qw(accno projectnumber) );

}

sub form_header {

    for (qw(reference description notes)) { $form->{$_} = $form->quote( $form->{$_} ) }

    if ( ( $rows = $form->numtextrows( $form->{description}, 50 ) ) > 1 ) {
        $description = qq|<textarea name=description rows=$rows cols=50 wrap=soft>$form->{description}</textarea>|;
    }
    else {
        $description = qq|<input name=description size=50 value="| . $form->quote( $form->{description} ) . qq|">|;
    }

    if ( ( $rows = $form->numtextrows( $form->{notes}, 50 ) ) > 1 ) {
        $notes = qq|<textarea name=notes rows=$rows cols=50 wrap=soft>$form->{notes}</textarea>|;
    }
    else {
        $notes = qq|<input name=notes size=50 value="| . $form->quote( $form->{notes} ) . qq|">|;
    }

    if ( !$form->{fxadj} ) {
        $exchangerate = qq|<input type=hidden name=action value="Update">
                <th align=right nowrap>| . $locale->text('Currency') . qq|</th>
		<td>
		  <table>
		    <tr>
                      <td><select name=currency onChange="javascript:document.forms[0].submit()">|
          . $form->select_option( $form->{selectcurrency}, $form->{currency} ) . qq|</select></td>|;

        if ( $form->{currency} ne $form->{defaultcurrency} ) {

            $form->{exchangerate} = $form->format_amount( \%myconfig, $form->{exchangerate} );

            $exchangerate .= qq|
              <th align=right nowrap>| . $locale->text('Exchange Rate') . qq| <font color=red>*</font></th>
              <td><input name=exchangerate size=10 value=$form->{exchangerate}></td>
              <th align=right nowrap>|
              . $locale->text('Buy') . qq|</th><td>| . $form->format_amount( \%myconfig, $form->{fxbuy} ) . qq|</td>
              <th align=right nowrap>|
              . $locale->text('Sell') . qq|</th><td>| . $form->format_amount( \%myconfig, $form->{fxsell} ) . qq|</td>|;
        }
        $exchangerate .= qq|</tr></table></td></tr>|;
    }

    $department = qq|
	  <th align=right nowrap>| . $locale->text('Department') . qq|</th>
	  <td><select name=department>| . $form->select_option( $form->unescape( $form->{selectdepartment} ), $form->{department}, 1 ) . qq|</select></td>
| if $form->{selectdepartment};

    $project = qq| 
	  <th class=listheading>| . $locale->text('Project') . qq|</th>
| if $form->{selectprojectnumber} and !$form->{selecttax};

    if ( $form->{selecttax} ) {
        $tax = qq|<th class=listheading>| . $locale->text('Tax Included');
        $tax .= qq| / | . $locale->text('Project') if $form->{selectprojectnumber};
        $tax .= qq|</th>|;
        $taxamount = qq|<th class=listheading>| . $locale->text('Tax Amount') . qq|</th>|;
    }

    if ( $form->{fxadj} ) {
        $fx_transaction = qq|
          <th class=listheading>| . $locale->text('FX') . qq|</th>
|;
    }

    $focus = ( $form->{focus} ) ? $form->{focus} : "accno_$form->{rowcount}";

    if ( $form->{batch} && !$form->{approved} ) {
        $transdate = qq|
	  <td>$form->{transdate}</td>
	  <input type=hidden name=transdate value=$form->{transdate}>
|;
    }
    else {
        $transdate = qq|
	  <td><input name=transdate size=11 class=date title="$myconfig{dateformat}" onChange="validateDate(this)" value=$form->{transdate}></td>
|;
    }

    $form->{onhold} = ( $form->{onhold} ) ? "checked" : "";

    $form->header;

    print qq|
<body onload="document.forms[0].${focus}.focus()" />

<form method=post action=$form->{script}>
|;

    $form->hide_form(qw(id fxadj closedto locked oldtransdate oldcurrency recurring batch batchid batchnumber batchdescription defaultcurrency fxbuy fxsell precision));
    $form->hide_form( map { "select$_" } qw(accno department currency tax) );

    print qq|
<input type=hidden name=title value="| . $form->quote( $form->{title} ) . qq|">

<table width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <td>
      <table>
	<tr>
	  <th align=right>| . $locale->text('Reference') . qq|</th>
	  <td><input name=reference size=20 value="| . $form->quote( $form->{reference} ) . qq|"></td>
	  <th align=right>| . $locale->text('Date') . qq| <font color=red>*</font></th>
	  $transdate
      <td>
          <table>
	      <tr>
		<td align=right><input name=onhold type=checkbox class=checkbox value=1 $form->{onhold}></td>
		<th align=left nowrap>| . $locale->text('On Hold') . qq|</font></th>
	      </tr>
          </table>
      </td>
	</tr>
	<tr>
	  $department
	  $exchangerate
	</tr>
	<tr>
	  <th align=right>| . $locale->text('Description') . qq|</th>
	  <td colspan=3>$description</td>
	</tr>
	<tr>
	  <th align=right>| . $locale->text('Notes') . qq|</th>
	  <td colspan=3>$notes</td>
	</tr>
      </table>
    </td>
  </tr>
  <tr>
    <td>
      <table width=100%>
	<tr class=listheading>
|;

    if ( $form->{selecttax} ) {
        print qq|
	  <th class=listheading>| . $locale->text('Account') . qq| / | . $locale->text('Memo') . qq| / | . $locale->text('Source') . qq|</th>
	  $fx_transaction
	  <th class=listheading>| . $locale->text('Debit') . qq|</th>
	  <th class=listheading>| . $locale->text('Credit') . qq|</th>
      $tax
      $taxamount
	  $project
|;
    }
    else {
        print qq|
	  <th class=listheading>| . $locale->text('Account') . qq|</th>
	  $fx_transaction
	  <th class=listheading>| . $locale->text('Debit') . qq|</th>
	  <th class=listheading>| . $locale->text('Credit') . qq|</th>
	  <th class=listheading>| . $locale->text('Source') . qq|</th>
	  <th class=listheading>| . $locale->text('Memo') . qq|</th>
      $tax
	  $project
|;
    }
    print qq|
	</tr>
|;

}

sub form_footer {

    for (qw(totaldebit totalcredit)) { $form->{$_} = $form->format_amount( \%myconfig, $form->{$_}, $form->{precision}, "&nbsp;" ) }

    $project = qq|
	  <th>&nbsp;</th>
| if $form->{selectprojectnumber};

    $tax = '';
    $taxamount = qq|
	  <th class=listtotal align="right">| . $form->format_amount( \%myconfig, $form->{totaltaxamount}, 2 ) . qq|</th>
| if $form->{selecttax};

    if ( $form->{fxadj} ) {
        $fx_transaction = qq|
          <th>&nbsp;</th>
|;
    }

    print qq|
        <tr class=listtotal>
	  <th>&nbsp;</th>
	  $fx_transaction
	  <th class=listtotal align=right>$form->{totaldebit}</th>
	  <th class=listtotal align=right>$form->{totalcredit}</th>
	  <th>&nbsp;</th>
      $tax
      $taxamount
	  $project
        </tr>
      </table>
    </td>
  </tr>
  <tr>
    <td><hr size=3 noshade></td>
  </tr>
</table>
|;

    $form->hide_form(qw(path login callback));

    $transdate = $form->datetonum( \%myconfig, $form->{transdate} );

    if ( $form->{readonly} ) {

        &islocked;

    }
    else {

        %button = (
            'Update'      => { ndx => 1,  key => 'U', value => $locale->text('Update') },
            'Post'        => { ndx => 3,  key => 'O', value => $locale->text('Post') },
            'Post as new' => { ndx => 6,  key => 'N', value => $locale->text('Post as new') },
            'Schedule'    => { ndx => 7,  key => 'H', value => $locale->text('Schedule') },
            'New Number'  => { ndx => 10, key => 'M', value => $locale->text('New Number') },
            'Delete'      => { ndx => 11, key => 'D', value => $locale->text('Delete') },
        );

        %a = ();

        if ( $form->{id} ) {
            for ( 'Update', 'Post as new', 'Schedule', 'New Number' ) { $a{$_} = 1 }

            if ( !$form->{locked} ) {
                if ( $transdate > $form->{closedto} ) {
                    for ( 'Post', 'Delete' ) { $a{$_} = 1 }
                }
            }

        }
        else {
            if ( $transdate > $form->{closedto} ) {
                for ( "Update", "Post", "Schedule", "New Number" ) { $a{$_} = 1 }
            }
        }

        $a{'Schedule'} = 0 if $form->{batch};

        for ( keys %button ) { delete $button{$_} if !$a{$_} }
        for ( sort { $button{$a}->{ndx} <=> $button{$b}->{ndx} } keys %button ) {
            $form->print_button( \%button, $_ );
        }

    }

    if ( $form->{recurring} ) {
        print qq|<div align=right>| . $locale->text('Scheduled') . qq|</div>|;
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

sub delete {

    $form->header;

    print qq|
<body>

<form method=post action=$form->{script}>
|;

    delete $form->{action};

    $form->hide_form;

    print qq|
<h2 class=confirm>| . $locale->text('Confirm!') . qq|</h2>

<h4>| . $locale->text('Are you sure you want to delete Transaction') . qq| $form->{reference}</h4>

<input name=action class=submit type=submit value="| . $locale->text('Yes') . qq|">
</form>
|;

}

sub yes {

    if ( GL->delete_transaction( \%myconfig, \%$form ) ) {
        $form->redirect( $locale->text('Transaction deleted!') );
    }
    else {
        $form->error( $locale->text('Cannot delete transaction!') );
    }

}

sub post {

    $form->isblank( "transdate", $locale->text('Transaction Date missing!') );

    my $dbh = $form->dbconnect( \%myconfig );
    my ($gldepartment) = $dbh->selectrow_array("SELECT fldvalue FROM defaults WHERE fldname='gldepartment'"); 
    if ($gldepartment){
       $form->isblank( "department", $locale->text('Department missing!') );
    }

    $form->isvaldate(\%myconfig, $form->{transdate}, $locale->text('Invalid date ...'));

    $transdate = $form->datetonum( \%myconfig, $form->{transdate} );

    $form->error( $locale->text('Cannot post transaction for a closed period!') ) if ( $transdate <= $form->{closedto} );

    # add up debits and credits
    for $i ( 1 .. $form->{rowcount} ) {
        $dr = $form->parse_amount( \%myconfig, $form->{"debit_$i"} );
        $cr = $form->parse_amount( \%myconfig, $form->{"credit_$i"} );

        if ( $dr && $cr ) {
            $form->error( $locale->text('Cannot post transaction with a debit and credit entry for the same account!') );
        }
        $debit  += $dr;
        $credit += $cr;
    }

    my $precision = $form->{precision};
    $precision = 8 if $precision < 8;

    if ( $form->round_amount( $debit, $precision ) != $form->round_amount( $credit, $precision ) ) {
        $form->error( $locale->text('Out of balance transaction!') );
    }

    if ( !$form->{repost} ) {
        if ( $form->{id} && !$form->{batch} ) {
            &repost;
            exit;
        }
    }

    # Process per line tax information
    $count = $form->{rowcount};
    for my $i ( 1 .. $form->{rowcount} ) {
        if ( $form->{"taxamount_$i"} ) {
            $j                  = $count++;
            $form->{"accno_$j"} = $form->{"tax_$i"};
            $form->{"tax_$j"}   = 'auto';

            $form->{"source_$j"}        = $form->{"source_$i"};
            $form->{"memo_$j"}          = $form->{"memo_$i"};
            $form->{"projectnumber_$j"} = $form->{"projectnumber_$i"};

            for (qw(debit credit taxamount)) { $form->{"${_}_$i"} = $form->parse_amount( \%myconfig, $form->{"${_}_$i"} ) }

            if ( $form->{"debit_$i"} ) {
                $form->{"debit_$i"} -= $form->{"taxamount_$i"};
                $form->{"debit_$j"} = $form->{"taxamount_$i"};
            }
            else {
                $form->{"credit_$i"} -= $form->{"taxamount_$i"};
                $form->{"credit_$j"} = $form->{"taxamount_$i"};
            }
        }
    }
    $form->{rowcount} = $count;

    if ( $form->{batch} ) {
        $rc = VR->post_transaction( \%myconfig, \%$form );
    }
    else {
        $rc = GL->post_transaction( \%myconfig, \%$form );
    }

    if ( $form->{callback} ) {
        $form->{callback} =~ s/(batch|batchid|batchdescription)=.*?&//g;
        $form->{callback} .= "&batch=$form->{batch}&batchid=$form->{batchid}&transdate=$form->{transdate}&batchdescription=" . $form->escape( $form->{batchdescription}, 1 );
    }

    if ($rc) {
        $form->redirect( $locale->text('Transaction posted!') );
    }
    else {
        $form->error( $locale->text('Cannot post transaction!') );
    }

}


sub view {
    $form->header;

    use DBIx::Simple;
    my $dbh = $form->dbconnect(\%myconfig);
    my $dbs = DBIx::Simple->connect($dbh);

    $query = qq|
            SELECT * 
            FROM gl_log a
            WHERE a.ts = ?
            ORDER BY a.ts
    |;

    my $table = $dbs->query($query, $form->{ts})->xto(
        tr => { class => [ 'listrow0', 'listrow1' ] },
        th => { class => ['listheading'] },
    );
    $table->modify(td => {align => 'right'}, 'amount');
    $table->map_cell(sub {return $form->format_amount(\%myconfig, shift, 4) }, 'amount');

    print $table->output;

    $query = qq|
            SELECT * 
            FROM acc_trans_log ac
            WHERE ac.ts = ?
            ORDER BY ac.ts
    |;
    $table = $dbs->query($query, $form->{ts})->xto(
        tr => { class => [ 'listrow0', 'listrow1' ] },
        th => { class => ['listheading'] },
    );
    $table->modify(td => {align => 'right'}, 'amount');
    $table->map_cell(sub {return $form->format_amount(\%myconfig, shift, 4) }, 'amount');
    $table->set_group( 'transdate', 1 );
    $table->calc_totals( [qw(amount)] );

    print $table->output;
}

