#=====================================================================
# SQL-Ledger ERP
# Copyright (c) 2006
#
#  Author: DWS Systems Inc.
#     Web: http://www.sql-ledger.com
#
#======================================================================
#
# payroll module
#
#======================================================================

use SL::HR;
use SL::User;

1;
# end of main



sub add {

  $label = "Add ".ucfirst $form->{db};
  $form->{title} = $locale->text($label);

  $form->{callback} = "$form->{script}?action=add&db=$form->{db}&path=$form->{path}&login=$form->{login}" unless $form->{callback};

  &{ "$form->{db}_links" };
  
}


sub search { &{ "search_$form->{db}" } };
  

sub search_employee {

  $form->{title} = $locale->text('Employees');

  @a = ();

  push @a, qq|<input name="l_ndx" type=checkbox class=checkbox value=Y> |.$locale->text('Pos');
  push @a, qq|<input name="l_id" type=checkbox class=checkbox value=Y> |.$locale->text('ID');
  push @a, qq|<input name="l_name" type=checkbox class=checkbox value=Y checked> |.$locale->text('Employee Name');
  push @a, qq|<input name="l_employeenumber" type=checkbox class=checkbox value=Y checked> |.$locale->text('Employee Number');
  push @a, qq|<input name="l_address" type=checkbox class=checkbox value=Y> |.$locale->text('Address');
  push @a, qq|<input name="l_city" type=checkbox class=checkbox value=Y> |.$locale->text('City');
  push @a, qq|<input name="l_state" type=checkbox class=checkbox value=Y> |.$locale->text('State/Province');
  push @a, qq|<input name="l_zipcode" type=checkbox class=checkbox value=Y> |.$locale->text('Zip/Postal Code');
  push @a, qq|<input name="l_country" type=checkbox class=checkbox value=Y> |.$locale->text('Country');
  push @a, qq|<input name="l_workphone" type=checkbox class=checkbox value=Y checked> |.$locale->text('Work Phone');
  push @a, qq|<input name="l_workfax" type=checkbox class=checkbox value=Y checked> |.$locale->text('Work Fax');
  push @a, qq|<input name="l_workmobile" type=checkbox class=checkbox value=Y> |.$locale->text('Work Mobile');
  push @a, qq|<input name="l_homephone" type=checkbox class=checkbox value=Y checked> |.$locale->text('Home Phone');
  push @a, qq|<input name="l_startdate" type=checkbox class=checkbox value=Y checked> |.$locale->text('Startdate');
  push @a, qq|<input name="l_enddate" type=checkbox class=checkbox value=Y checked> |.$locale->text('Enddate');
  push @a, qq|<input name="l_sales" type=checkbox class=checkbox value=Y> |.$locale->text('Sales');
  push @a, qq|<input name="l_manager" type=checkbox class=checkbox value=Y> |.$locale->text('Manager');
  push @a, qq|<input name="l_role" type=checkbox class=checkbox value=Y checked> |.$locale->text('Role');
  push @a, qq|<input name="l_login" type=checkbox class=checkbox value=Y checked> |.$locale->text('Login');
  push @a, qq|<input name="l_email" type=checkbox class=checkbox value=Y> |.$locale->text('E-mail');
  push @a, qq|<input name="l_ssn" type=checkbox class=checkbox value=Y> |.$locale->text('SSN');
  push @a, qq|<input name="l_dob" type=checkbox class=checkbox value=Y> |.$locale->text('DOB');
  push @a, qq|<input name="l_iban" type=checkbox class=checkbox value=Y> |.$locale->text('IBAN');
  push @a, qq|<input name="l_bic" type=checkbox class=checkbox value=Y> |.$locale->text('BIC');
  push @a, qq|<input name="l_notes" type=checkbox class=checkbox value=Y> |.$locale->text('Notes');
 

  $form->header;
  
  print qq|
<body>

<form method=post action=$form->{script}>

<table width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr valign=top>
    <td>
      <table>
	<tr>
	  <th align=right nowrap>|.$locale->text('Employee Name').qq|</th>
	  <td colspan=3><input name=name size=35></td>
	</tr>
	<tr>
	  <th align=right nowrap>|.$locale->text('Employee Number').qq|</th>
	  <td colspan=3><input name=employeenumber size=35></td>
	</tr>
	<tr>
	  <th align=right nowrap>|.$locale->text('Startdate').qq|</th>
	  <td>|.$locale->text('From').qq| <input name=startdatefrom size=11 class=date title="$myconfig{dateformat}" onChange="validateDate(this)"> |.$locale->text('To').qq| <input name=startdateto size=11 class=date title="$myconfig{dateformat}" onChange="validateDate(this)"></td>
	</tr>
	<tr valign=top>
	  <th align=right nowrap>|.$locale->text('Notes').qq|</th>
	  <td colspan=3><input name=notes size=40></td>
	</tr>
	<tr>
	  <td></td>
	  <td colspan=3><input name=status class=radio type=radio value=all checked>&nbsp;|.$locale->text('All').qq|
	  <input name=status class=radio type=radio value=active>&nbsp;|.$locale->text('Active').qq|
	  <input name=status class=radio type=radio value=inactive>&nbsp;|.$locale->text('Inactive').qq|
	  <input name=status class=radio type=radio value=orphaned>&nbsp;|.$locale->text('Orphaned').qq|
	  <input name=sales class=checkbox type=checkbox value=Y>&nbsp;|.$locale->text('Sales').qq|
	</tr>
	<tr>
	  <th align=right nowrap>|.$locale->text('Include in Report').qq|</th>
	  <td colspan=3>
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

<input type=hidden name=nextsub value=list_employees>
|;

  $form->hide_form(qw(db path login));

  print qq|
<br>
<input type=submit class=submit name=action value="|.$locale->text('Continue').qq|">
</form>
|;

  if ($form->{menubar}) {
    require "$form->{path}/menu.pl";
    &menubar;
  }

  print qq|

</body>
</html>
|;
}


sub list_employees {

  $form->isvaldate(\%myconfig, $form->{startdatefrom}, $locale->text('Invalid from date ...'));
  $form->isvaldate(\%myconfig, $form->{startdateto}, $locale->text('Invalid to date ...'));

  HR->employees(\%myconfig, \%$form);
  
  $href = "$form->{script}?action=list_employees&direction=$form->{direction}&oldsort=$form->{oldsort}&db=$form->{db}&path=$form->{path}&login=$form->{login}&status=$form->{status}";
  
  $form->sort_order();

  $callback = "$form->{script}?action=list_employees&direction=$form->{direction}&oldsort=$form->{oldsort}&db=$form->{db}&path=$form->{path}&login=$form->{login}&status=$form->{status}";
  
  @columns = $form->sort_columns(qw(id employeenumber name address city state zipcode country workphone workfax workmobile homephone email startdate enddate ssn dob iban bic sales role manager login notes));
  unshift @columns, "ndx";

  foreach $item (@columns) {
    if ($form->{"l_$item"} eq "Y") {
      push @column_index, $item;

      # add column to href and callback
      $callback .= "&l_$item=Y";
      $href .= "&l_$item=Y";
    }
  }

  %role = ( user	=> $locale->text('User'),
            supervisor	=> $locale->text('Supervisor'),
	    manager	=> $locale->text('Manager'),
            admin	=> $locale->text('Administrator')
	  );
  
  $option = $locale->text('All');

  if ($form->{status} eq 'sales') {
    $option = $locale->text('Sales');
  }
  if ($form->{status} eq 'orphaned') {
    $option = $locale->text('Orphaned');
  }
  if ($form->{status} eq 'active') {
    $option = $locale->text('Active');
  }
  if ($form->{status} eq 'inactive') {
    $option = $locale->text('Inactive');
  }
  
  if ($form->{employeenumber}) {
    $callback .= "&employeenumber=".$form->escape($form->{employeenumber},1);
    $href .= "&employeenumber=".$form->escape($form->{employeenumber});
    $option .= "\n<br>".$locale->text('Employee Number')." : $form->{employeenumber}";
  }
  if ($form->{name}) {
    $callback .= "&name=".$form->escape($form->{name},1);
    $href .= "&name=".$form->escape($form->{name});
    $option .= "\n<br>".$locale->text('Employee Name')." : $form->{name}";
  }
  if ($form->{startdatefrom}) {
    $callback .= "&startdatefrom=$form->{startdatefrom}";
    $href .= "&startdatefrom=$form->{startdatefrom}";
    $fromdate = $locale->date(\%myconfig, $form->{startdatefrom}, 1);
  }
  if ($form->{startdateto}) {
    $callback .= "&startdateto=$form->{startdateto}";
    $href .= "&startdateto=$form->{startdateto}";
    $todate = $locale->date(\%myconfig, $form->{startdateto}, 1);
  }
  if ($fromdate || $todate) {
    $option .= "\n<br>".$locale->text('Startdate')." $fromdate - $todate";
  }
  
  if ($form->{notes}) {
    $callback .= "&notes=".$form->escape($form->{notes},1);
    $href .= "&notes=".$form->escape($form->{notes});
    $option .= "\n<br>" if $option;
    $option .= $locale->text('Notes')." : $form->{notes}";
  }

  $form->{callback} = "$callback&sort=$form->{sort}";
  $callback = $form->escape($form->{callback});

  $column_header{ndx} = qq|<th class=listheading width=1%>&nbsp;</th>|;
  $column_header{id} = qq|<th class=listheading>|.$locale->text('ID').qq|</th>|;
  $column_header{employeenumber} = qq|<th><a class=listheading href=$href&sort=employeenumber>|.$locale->text('Number').qq|</a></th>|;
  $column_header{name} = qq|<th><a class=listheading href=$href&sort=name>|.$locale->text('Name').qq|</a></th>|;
  $column_header{manager} = qq|<th><a class=listheading href=$href&sort=manager>|.$locale->text('Manager').qq|</a></th>|;
  $column_header{address} = qq|<th class=listheading>|.$locale->text('Address').qq|</a></th>|;
  $column_header{city} = qq|<th><a class=listheading href=$href&sort=city>|.$locale->text('City').qq|</a></th>|;
  $column_header{state} = qq|<th><a class=listheading href=$href&sort=state>|.$locale->text('State/Province').qq|</a></th>|;
  $column_header{zipcode} = qq|<th><a class=listheading href=$href&sort=zipcode>|.$locale->text('Zip/Postal Code').qq|</a></th>|;
  $column_header{country} = qq|<th><a class=listheading href=$href&sort=country>|.$locale->text('Country').qq|</a></th>|;
  $column_header{workphone} = qq|<th><a class=listheading href=$href&sort=workphone>|.$locale->text('Work Phone').qq|</a></th>|;
  $column_header{workfax} = qq|<th><a class=listheading href=$href&sort=workfax>|.$locale->text('Work Fax').qq|</a></th>|;
  $column_header{workmobile} = qq|<th><a class=listheading href=$href&sort=workmobile>|.$locale->text('Work Mobile').qq|</a></th>|;
  $column_header{homephone} = qq|<th><a class=listheading href=$href&sort=homephone>|.$locale->text('Home Phone').qq|</a></th>|;
  
  $column_header{startdate} = qq|<th><a class=listheading href=$href&sort=startdate>|.$locale->text('Startdate').qq|</a></th>|;
  $column_header{enddate} = qq|<th><a class=listheading href=$href&sort=enddate>|.$locale->text('Enddate').qq|</a></th>|;
  $column_header{notes} = qq|<th><a class=listheading href=$href&sort=notes>|.$locale->text('Notes').qq|</a></th>|;
  $column_header{role} = qq|<th><a class=listheading href=$href&sort=role>|.$locale->text('Role').qq|</a></th>|;
  $column_header{login} = qq|<th><a class=listheading href=$href&sort=login>|.$locale->text('Login').qq|</a></th>|;
  
  $column_header{sales} = qq|<th class=listheading>|.$locale->text('S').qq|</th>|;
  $column_header{email} = qq|<th><a class=listheading href=$href&sort=email>|.$locale->text('E-mail').qq|</a></th>|;
  $column_header{ssn} = qq|<th><a class=listheading href=$href&sort=ssn>|.$locale->text('SSN').qq|</a></th>|;
  $column_header{dob} = qq|<th><a class=listheading href=$href&sort=dob>|.$locale->text('DOB').qq|</a></th>|;
  $column_header{iban} = qq|<th><a class=listheading href=$href&sort=iban>|.$locale->text('IBAN').qq|</a></th>|;
  $column_header{bic} = qq|<th><a class=listheading href=$href&sort=bic>|.$locale->text('BIC').qq|</a></th>|;
  
  $form->{title} = $locale->text('Employees') . " / $form->{company}";

  $form->header;

  print qq|
<body>

<table width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
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

  for (@column_index) { print "$column_header{$_}\n" }
  
  print qq|
        </tr>
|;

  $i = 0;
  foreach $ref (@{ $form->{all_employee} }) {

    $i++;
    
    $ref->{notes} =~ s/\r?\n/<br>/g;
    for (@column_index) { $column_data{$_} = "<td>$ref->{$_}&nbsp;</td>" }

    $column_data{ndx} = "<td align=right>$i</td>";
    
    $column_data{sales} = ($ref->{sales}) ? "<td>x</td>" : "<td>&nbsp;</td>";
    $column_data{role} = qq|<td>$role{"$ref->{role}"}&nbsp;</td>|;
    $column_date{address} = qq|$ref->{address1} $ref->{address2}|;

    $column_data{name} = "<td><a href=$form->{script}?action=edit&db=employee&id=$ref->{id}&path=$form->{path}&login=$form->{login}&status=$form->{status}&callback=$callback>$ref->{name}&nbsp;</a></td>";

    if ($ref->{email}) {
      $email = $ref->{email};
      $email =~ s/</\&lt;/;
      $email =~ s/>/\&gt;/;
      
      $column_data{email} = qq|<td><a href="mailto:$ref->{email}">$email</a></td>|;
    }

    $j++; $j %= 2;
    print "
        <tr class=listrow$j>
";

    for (@column_index) { print "$column_data{$_}\n" }

    print qq|
        </tr>
|;
    
  }

  $i = 1;
  $button{'HR--Employees--Add Employee'}{code} = qq|<input class=submit type=submit name=action value="|.$locale->text('Add Employee').qq|"> |;
  $button{'HR--Employees--Add Employee'}{order} = $i++;

  foreach $item (split /;/, $myconfig{acs}) {
    delete $button{$item};
  }
  
  print qq|
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

  $form->hide_form(qw(callback db path login));
  
  foreach $item (sort { $a->{order} <=> $b->{order} } %button) {
    print $item->{code};
  }

  if ($form->{menubar}) {
    require "$form->{path}/menu.pl";
    &menubar;
  }

  print qq|
  </form>

</body>
</html>
|;
 
}


sub edit {

# $locale->text('Edit Employee')
# $locale->text('Edit Deduction')

  $label = ucfirst $form->{db};
  $form->{title} = $locale->text("Edit $label");

  &{ "$form->{db}_links" };
  
}


sub employee_links {

#$form->{deductions} = 1;
  HR->get_employee(\%myconfig, \%$form);

  for (keys %$form) { $form->{$_} = $form->quote($form->{$_}) }

  if (@{ $form->{all_deduction} }) {
    $form->{selectdeduction} = "\n";
    for (@{ $form->{all_deduction} }) { $form->{selectdeduction} .= qq|$_->{description}--$_->{id}\n| }
  }

  $form->{manager} = "$form->{manager}--$form->{managerid}" if $form->{managerid};

  if (@{ $form->{all_manager} }) {
    $form->{selectmanager} = "\n";
    for (@{ $form->{all_manager} }) { $form->{selectmanager} .= qq|$_->{name}--$_->{id}\n| }
  }

  %role = ( user	=> $locale->text('User'),
            supervisor	=> $locale->text('Supervisor'),
	    manager	=> $locale->text('Manager'),
            admin	=> $locale->text('Administrator')
	  );
  
  $form->{selectrole} = "\n";
  for (qw(user supervisor manager admin)) { $form->{selectrole} .= "$_--$role{$_}\n" }

  $i = 1;
  foreach $ref (@{ $form->{all_employeededuction} }) {
    $form->{"deduction_$i"} = "$ref->{description}--$ref->{id}" if $ref->{id};
    for (qw(before after rate)) { $form->{"${_}_$i"} = $ref->{$_} }
    $i++;
  }
  $form->{deduction_rows} = $i - 1;

  for (qw(deduction manager role)) { $form->{"select$_"} = $form->escape($form->{"select$_"},1) }

  if (! $form->{readonly}) {
    $form->{readonly} = 1 if $myconfig{acs} =~ /Add Employee/;
  }

  &employee_header;
  &employee_footer;

}


sub new_number {

  $form->{employeenumber} = $form->update_defaults(\%myconfig, employeenumber);

  &employee_header;
  &employee_footer;

}


sub employee_header {

  if ($myconfig{role} ne 'user') {
    $sales = ($form->{sales}) ? "checked" : "";
    $sales = qq|
        <tr>
	  <th align=right>|.$locale->text('Sales').qq|</th>
	  <td><input name=sales class=checkbox type=checkbox value=1 $sales></td>
	</tr>
        <tr>
	  <th align=right>|.$locale->text('Role').qq|</th>
	  <td><select name=role>|
	  .$form->select_option($form->{selectrole}, $form->{role}, undef, 1)
	  .qq|</select></td>
	</tr>
|;

    if ($form->{selectmanager}) {
      $sales .= qq|
        <tr>
	  <th align=right>|.$locale->text('Manager').qq|</th>
	  <td><select name=manager>|
	  .$form->select_option($form->{selectmanager}, $form->{manager}, 1)
	  .qq|</select></td>
	</tr>
|;
    } else {
      $sales .= $form->hide_form(qw(manager));
    }
  } else {
      $sales = $form->hide_form(qw(role sales manager));
  }

  
  $form->{deduction_rows}++;

  $form->header;

  print qq|
<body>

<form method=post action=$form->{script}>
|;

  $form->hide_form(qw(deduction_rows status title));
  $form->hide_form(map { "select$_" } qw(deduction manager role));

  print qq|

<table width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <td>
      <table>
        <tr valign=top>
	  <td>
	    <table>
	      <tr>
		<th align=right nowrap>|.$locale->text('Employee Number').qq|</th>
		<td><input name=employeenumber size=32 maxlength=32 value="|.$form->quote($form->{employeenumber}).qq|"></td>
	      </tr>
	      <tr>
		<th align=right nowrap>|.$locale->text('Name').qq| <font color=red>*</font></th>
		<td><input name=name size=35 maxlength=64 value="|.$form->quote($form->{name}).qq|"></td>
	      </tr>
	      <tr>
		<th align=right nowrap>|.$locale->text('Address').qq|</th>
		<td><input name=address1 size=35 maxlength=32 value="|.$form->quote($form->{address1}).qq|"></td>
	      </tr>
	      <tr>
		<th></th>
		<td><input name=address2 size=35 maxlength=32 value="|.$form->quote($form->{address2}).qq|"></td>
	      </tr>
	      <tr>
		<th align=right nowrap>|.$locale->text('City').qq|</th>
		<td><input name=city size=35 maxlength=32 value="|.$form->quote($form->{city}).qq|"></td>
	      </tr>
	      <tr>
		<th align=right nowrap>|.$locale->text('State/Province').qq|</th>
		<td><input name=state size=35 maxlength=32 value="|.$form->quote($form->{state}).qq|"></td>
	      </tr>
	      <tr>
		<th align=right nowrap>|.$locale->text('Zip/Postal Code').qq|</th>
		<td><input name=zipcode size=10 maxlength=10 value="|.$form->quote($form->{zipcode}).qq|"></td>
	      </tr>
	      <tr>
		<th align=right nowrap>|.$locale->text('Country').qq|</th>
		<td><input name=country size=35 maxlength=32 value="|.$form->quote($form->{country}).qq|"></td>
	      </tr>
	      <tr>
		<th align=right nowrap>|.$locale->text('E-mail').qq|</th>
		<td><input name=email size=35 value="$form->{email}"></td>
	      </tr>
	      <tr>
	      $sales
	    </table>
	  </td>
	  <td>
	    <table>
	      <tr>
		<th align=right nowrap>|.$locale->text('Work Phone').qq|</th>
		<td><input name=workphone size=20 maxlength=20 value="$form->{workphone}"></td>
	      </tr>
	      <tr>
		<th align=right nowrap>|.$locale->text('Work Fax').qq|</th>
		<td><input name=workfax size=20 maxlength=20 value="$form->{workfax}"></td>
	      </tr>
	      <tr>
		<th align=right nowrap>|.$locale->text('Work Mobile').qq|</th>
		<td><input name=workmobile size=20 maxlength=20 value="$form->{workmobile}"></td>
	      </tr>
	      <tr>
		<th align=right nowrap>|.$locale->text('Home Phone').qq|</th>
		<td><input name=homephone size=20 maxlength=20 value="$form->{homephone}"></td>
	      </tr>
	      <tr>
		<th align=right nowrap>|.$locale->text('Startdate').qq|</th>
		<td><input name=startdate size=11 class=date title="$myconfig{dateformat}" onChange="validateDate(this)" value=$form->{startdate}></td>
	      </tr>
	      <tr>
		<th align=right nowrap>|.$locale->text('Enddate').qq|</th>
		<td><input name=enddate size=11 class=date title="$myconfig{dateformat}" onChange="validateDate(this)" value=$form->{enddate}></td>
	      </tr>
	      <tr>
		<th align=right nowrap>|.$locale->text('Closed To').qq|</th>
		<td><input name=closedto size=11 class=date title="$myconfig{dateformat}" onChange="validateDate(this)" value=$form->{closedto}></td>
	      </tr>

	      <tr>
		<th align=right nowrap>|.$locale->text('SSN').qq|</th>
		<td><input name=ssn size=20 maxlength=20 value="|.$form->quote($form->{ssn}).qq|"></td>
	      </tr>
	      <tr>
		<th align=right nowrap>|.$locale->text('DOB').qq|</th>
		<td><input name=dob size=11 class=date title="$myconfig{dateformat}" onChange="validateDate(this)" value=$form->{dob}></td>
	      </tr>
	      <tr>
		<th align=right nowrap>|.$locale->text('IBAN').qq|</th>
		<td><input name=iban size=34 maxlength=34 value="|.$form->quote($form->{iban}).qq|"></td>
	      </tr>
	      <tr>
		<th align=right nowrap>|.$locale->text('BIC').qq|</th>
		<td><input name=bic size=11 maxlength=11 value="|.$form->quote($form->{bic}).qq|"></td>
	      </tr>
	    </table>
	  </td>
	</tr>
      </table>
    </td>
  </tr>
  <tr>
    <th align=left nowrap>|.$locale->text('Notes').qq|</th>
  </tr>
  <tr>
    <td><textarea name=notes rows=3 cols=60 wrap=soft>$form->{notes}</textarea></td>
  </tr>
|;

    if ($form->{selectdeduction}) {

      print qq|
  <tr>
    <td>
      <table width=100%>
        <tr class=listheading>
	  <th class=listheading>|.$locale->text('Payroll Deduction').qq|</th>
	  <th class=listheading colspan=3>|.$locale->text('Allowances').qq|</th>
	</tr>

        <tr class=listheading>
	  <th></th>
	  <th class=listheading>|.$locale->text('Before Deduction').qq|</th>
	  <th class=listheading>|.$locale->text('After Deduction').qq|</th>
	  <th class=listheading>|.$locale->text('Rate').qq|</th>
	</tr>
|;

    for $i (1 .. $form->{deduction_rows}) {
      print qq|
        <tr>
	  <td><select name="deduction_$i">|
	  .$form->select_option($form->{selectdeduction}, $form->{"deduction_$i"}, 1)
	  .qq|</select></td>
	  <td><input name="before_$i" value=|.$form->format_amount(\%myconfig, $form->{"before_$i"}, $form->{precision}).qq|></td>
	  <td><input name="after_$i" value=|.$form->format_amount(\%myconfig, $form->{"after_$i"}, $form->{precision}).qq|></td>
	  <td><input name="rate_$i" size=8 value=|.$form->format_amount(\%myconfig, $form->{"rate_$i"}).qq|></td>
	</tr>
|;
    }
  }

  print qq|
      </table>
    </td>
  </tr>
  <tr>
    <td><hr size=3 noshade></td>
  </tr>
</table>
|;

}



sub employee_footer {

  $form->hide_form(qw(id db employeelogin path login callback));

  if (! $form->{readonly}) {
    %button = ('Update' => { ndx => 1, key => 'U', value => $locale->text('Update') },
	       'Save' => { ndx => 2, key => 'S', value => $locale->text('Save') },
	       'Save as new' => { ndx => 5, key => 'N', value => $locale->text('Save as new') },
	       'New Number' => { ndx => 15, key => 'M', value => $locale->text('New Number') },
	       'Delete' => { ndx => 16, key => 'D', value => $locale->text('Delete') },
	      );
	     
    %a = ();
    for ("Update", "Save", "New Number") { $a{$_} = 1 }
    
    if ($form->{id}) {
      if ($form->{status} eq 'orphaned') {
	$a{'Delete'} = 1;
      }
      $a{'Save as new'} = 1;
    }

    for (keys %button) { delete $button{$_} if ! $a{$_} }
    for (sort { $button{$a}->{ndx} <=> $button{$b}->{ndx} } keys %button) { $form->print_button(\%button, $_) }
   
  }

  if ($form->{menubar}) {
    require "$form->{path}/menu.pl";
    &menubar;
  }

  print qq|
 
  </form>

</body>
</html>
|;

}


sub save { &{ "save_$form->{db}" } };


sub save_employee {

  $form->isblank("name", $locale->text("Name missing!"));
  $form->isvaldate(\%myconfig, $form->{startdate}, $locale->text('Invalid start date ...'));
  $form->isvaldate(\%myconfig, $form->{enddate}, $locale->text('Invalid end date ...'));

  HR->save_employee(\%myconfig, \%$form);

  # if it is a login change memberfile and .conf
  if ($form->{employeelogin}) {
    $user = new User $memberfile, $form->{employeelogin};

    for (qw(name email role)) { $user->{$_} = $form->{$_} }

    # assign $myconfig for db
    for (qw(dbconnect dbhost dbport dbpasswd)) { $user->{$_} = $myconfig{$_} }
    
    for (qw(dbpasswd password)) { $user->{"old_$_"} = $user->{$_} }
    $user->{packpw} = 1;
    $user->{encrypted} = 1;

    $user->save_member($memberfile, $userspath) if $user->{login};
  }
  
  $form->redirect($locale->text('Employee saved!'));
  
}


sub delete { &{ "delete_$form->{db}" } };


sub delete_employee {

  HR->delete_employee(\%myconfig, \%$form);
  $form->redirect($locale->text('Employee deleted!'));
  
}


sub continue { &{ $form->{nextsub} } };

sub add_employee { &add };
sub add_deduction { &add };


sub search_deduction {

  HR->deductions(\%myconfig, \%$form);
  
  $href = "$form->{script}?action=search_deduction";
  for (qw(direction oldsort db path login)) { $href .= "&$_=$form->{$_}" }

  $form->sort_order();

  $callback = "$form->{script}?action=search_deduction";
  for (qw(direction oldsort db path login)) { $callback .= "&$_=$form->{$_}" } 
  
  @column_index = $form->sort_columns(qw(description rate amount above below employeepays employerpays ap_accno expense_accno));

 
  $form->{callback} = $callback;
  $callback = $form->escape($form->{callback});

  $column_header{description} = qq|<th class=listheading href=$href>|.$locale->text('Description').qq|</th>|;
  $column_header{rate} = qq|<th class=listheading nowrap>|.$locale->text('Rate').qq|<br>%</th>|;
  $column_header{amount} = qq|<th class=listheading>|.$locale->text('Amount').qq|</th>|;
  $column_header{above} = qq|<th class=listheading>|.$locale->text('Above').qq|</th>|;
  $column_header{below} = qq|<th class=listheading>|.$locale->text('Below').qq|</th>|;
  $column_header{employerpays} = qq|<th class=listheading>|.$locale->text('Employer').qq|</th>|;
  $column_header{employeepays} = qq|<th class=listheading>|.$locale->text('Employee').qq|</th>|;
  
  $column_header{ap_accno} = qq|<th class=listheading>|.$locale->text('AP').qq|</th>|;
  $column_header{expense_accno} = qq|<th class=listheading>|.$locale->text('Expense').qq|</th>|;
  
  $form->{title} = $locale->text('Deductions') . " / $form->{company}";

  $form->header;

  print qq|
<body>

<table width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
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

  for (@column_index) { print "$column_header{$_}\n" }
  
  print qq|
        </tr>
|;

  
  foreach $ref (@{ $form->{all_deduction} }) {

    $rate = $form->format_amount(\%myconfig, $ref->{rate} * 100, undef, "&nbsp;");
    
    $column_data{rate} = "<td align=right>$rate</td>";

    for (qw(amount below above)) { $column_data{$_} = "<td align=right>".$form->format_amount(\%myconfig, $ref->{$_}, $form->{precision}, "&nbsp;")."</td>" }
      
    for (qw(ap_accno expense_accno)) { $column_data{$_} = "<td>$ref->{$_}&nbsp;</td>" }
    
    for (qw(employerpays employeepays)) { $column_data{$_} = "<td align=right>".$form->format_amount(\%myconfig, $ref->{$_}, undef, "&nbsp;")."</td>" }
    
    if ($ref->{description} ne $sameitem) {
      $column_data{description} = "<td><a href=$form->{script}?action=edit&db=$form->{db}&id=$ref->{id}&path=$form->{path}&login=$form->{login}&callback=$callback>$ref->{description}</a></td>";
    } else {
      $column_data{description} = "<td>&nbsp;</td>";
    }

    $i++; $i %= 2;
    print "
        <tr class=listrow$i>
";

    for (@column_index) { print "$column_data{$_}\n" }

    print qq|
        </tr>
|;

    $sameitem = $ref->{description};
    
  }

  $i = 1;
  $button{'HR--Deductions--Add Deduction'}{code} = qq|<input class=submit type=submit name=action value="|.$locale->text('Add Deduction').qq|"> |;
  $button{'HR--Deductions--Add Deduction'}{order} = $i++;

  foreach $item (split /;/, $myconfig{acs}) {
    delete $button{$item};
  }
  
  print qq|
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

  $form->hide_form(qw(db callback path login));

  foreach $item (sort { $a->{order} <=> $b->{order} } %button) {
    print $item->{code};
  }

  if ($form->{menubar}) {
    require "$form->{path}/menu.pl";
    &menubar;
  }

  print qq|
  </form>

</body>
</html>
|;
 
}


sub deduction_links {
  
  HR->get_deduction(\%myconfig, \%$form);

  $i = 1;
  foreach $ref (@{ $form->{deductionrate} }) {
    for (keys %$ref) { $form->{"${_}_$i"} = $ref->{$_} }
    $i++;
  }
  $form->{rate_rows} = $i - 1;
  
  $i = 1;
  foreach $ref (@{ $form->{deductionbase} }) {
    $form->{"base_$i"} = "$ref->{description}--$ref->{id}" if $ref->{id};
    $form->{"maximum_$i"} = $ref->{maximum};
    $i++;
  }
  $form->{base_rows} = $i - 1;

  $i = 1;
  foreach $ref (@{ $form->{deductionafter} }) {
    $form->{"after_$i"} = "$ref->{description}--$ref->{id}" if $ref->{id};
    $i++;
  }
  $form->{after_rows} = $i - 1;
  
  $form->{employeepays} = 1;
  
  $form->{selectap} = "\n";
  for (@{ $form->{ap_accounts} }) { $form->{selectap} .= "$_->{accno}--$_->{description}\n" }

  $form->{ap_accno} = qq|$form->{ap_accno}--$form->{ap_description}|;

  $form->{selectexpense} = "\n";
  for (@{ $form->{expense_accounts} }) { $form->{selectexpense} .= "$_->{accno}--$_->{description}\n" }

  $form->{expense_accno} = qq|$form->{expense_accno}--$form->{expense_description}|;

  for (1 .. $form->{rate_rows}) { $form->{"rate_$_"} *= 100 }

  $form->{selectbase} = "\n";
  for (@{ $form->{all_deduction} }) { $form->{selectbase} .= qq|$_->{description}--$_->{id}\n| }
  
  if (! $form->{readonly}) {
    $form->{readonly} = 1 if $myconfig{acs} =~ /Add Deduction/;
  }

  for (qw(ap expense base)) { $form->{"select$_"} = $form->escape($form->{"select$_"},1) }
  
  &deduction_header;
  &deduction_footer;
  
}


sub deduction_header {

  $form->{rate_rows}++;
  $form->{base_rows}++;
  $form->{after_rows}++;

  $form->header;

  print qq|
<body>

<form method=post action=$form->{script}>
|;

  $form->hide_form(qw(title rate_rows base_rows after_rows precision));
  $form->hide_form(map { "select$_" } qw(base ap expense));

  print qq|
  
<table width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <td>
      <table>
	<tr>
	  <th align=right nowrap>|.$locale->text('Description').qq| <font color=red>*</font></th>
	  <td><input name=description size=35 value="|.$form->quote($form->{description}).qq|"></td>
	</tr>
	<tr>
	  <th align=right nowrap>|.$locale->text('AP').qq|</th>
	  <td><select name=ap_accno>|
	  .$form->select_option($form->{selectap}, $form->{ap_accno}).qq|</select></td>
	  <th align=right nowrap>|.$locale->text('Employee pays').qq| x</th>
	  <td><input name=employeepays size=4 value=|.$form->format_amount(\%myconfig, $form->{employeepays}).qq|></td>
	</tr>
	<tr>
	  <th align=right nowrap>|.$locale->text('Expense').qq|</th>
	  <td><select name=expense_accno>|
	  .$form->select_option($form->{selectexpense}, $form->{expense_accno}).qq|</select></td>
	  <th align=right nowrap>|.$locale->text('Employer pays').qq| x</th>
	  <td><input name=employerpays size=4 value=|.$form->format_amount(\%myconfig, $form->{employerpays}).qq|></td>
	</tr>
	<tr>
	  <td></td>
	  <td></td>
	  <th align=right nowrap>|.$locale->text('Exempt age <').qq|</th>
	  <td><input name=fromage size=4 value=|.$form->format_amount(\%myconfig, $form->{fromage}).qq|></td>
	  <th align=right nowrap>&gt;</th>
	  <td><input name=toage size=4 value=|.$form->format_amount(\%myconfig, $form->{toage}).qq|>
        </tr>
	<tr>
	  <td></td>
	  <td>
	    <table>
	      <tr class=listheading>
	        <th class=listheading>|.$locale->text('Rate').qq| %</th>
		<th class=listheading>|.$locale->text('Amount').qq|</th>
		<th class=listheading>|.$locale->text('Above').qq|</th>
		<th class=listheading>|.$locale->text('Below').qq|</th>
	      </tr>
|;

  for $i (1 .. $form->{rate_rows}) {
    print qq|
	      <tr>
		<td><input name="rate_$i" size=11 value=|.$form->format_amount(\%myconfig, $form->{"rate_$i"}).qq|></td>
		<td><input name="amount_$i" size=11 value=|.$form->format_amount(\%myconfig, $form->{"amount_$i"}, $form->{precision}).qq|></td>
		<td><input name="above_$i" size=11 value=|.$form->format_amount(\%myconfig, $form->{"above_$i"}, $form->{precision}).qq|></td>
		<td><input name="below_$i" size=11 value=|.$form->format_amount(\%myconfig, $form->{"below_$i"}, $form->{precision}).qq|></td>
	      </tr>
|;
  }

  print qq|
	    </table>
	  </td>
	</tr>
      </table>
    </td>
  </tr>
|;
  
  print qq|
  <tr>
    <td>
      <table>
|;

  $basedon = $locale->text('Based on');
  $maximum = $locale->text('Maximum');
  
  for $i (1 .. $form->{base_rows}) {
    print qq|
	<tr>
	  <th>$basedon</th>
	  <td><select name="base_$i">|
	  .$form->select_option($form->{selectbase}, $form->{"base_$i"}, 1).qq|</select></td>
	  <th>$maximum</th>
	  <td><input name="maximum_$i" value=|.$form->format_amount(\%myconfig, $form->{"maximum_$i"}, $form->{precision}).qq|></td>
	</tr>
|;
    $basedon = "";
    $maximum = "";
  }

  $deductafter = $locale->text('Deduct after');
  
  for $i (1 .. $form->{after_rows}) {
    print qq|
	<tr>
	  <th>$deductafter</th>
	  <td><select name="after_$i">|
	  .$form->select_option($form->{selectbase}, $form->{"after_$_"}, 1).qq|</select></td>
	</tr>
|;
    $deductafter = "";
  }

  print qq|
      </table>
    </td>
  </tr>
  <tr>
    <td><hr size=3 noshade></td>
  </tr>
</table>
|;

}



sub deduction_footer {

  $form->hide_form(qw(id db path login callback));
  
  print qq|<br>|;

  if (! $form->{readonly}) {
    %button = ('Update' => { ndx => 1, key => 'U', value => $locale->text('Update') },
	       'Save' => { ndx => 3, key => 'S', value => $locale->text('Save') },
	       'Save as new' => { ndx => 7, key => 'N', value => $locale->text('Save as new') },
	       'Delete' => { ndx => 16, key => 'D', value => $locale->text('Delete') },
	      );

    %a = ();
    for ('Update', 'Save') { $a{$_} = 1 }
    
    if ($form->{id}) {
      if ($form->{status} eq 'orphaned') {
	$a{'Delete'} = 1;
      }
      $a{'Save as new'} = 1;
    }

    for (keys %button) { delete $button{$_} if ! $a{$_} }
    for (sort { $button{$a}->{ndx} <=> $button{$b}->{ndx} } keys %button) { $form->print_button(\%button, $_) }
    
  }

  if ($form->{menubar}) {
    require "$form->{path}/menu.pl";
    &menubar;
  }

  print qq|
 
  </form>

</body>
</html>
|;

}


sub update { &{ "update_$form->{db}" }; }
sub save { &{ "save_$form->{db}" } };


sub update_deduction {

  # if rate or amount is blank remove row
  @flds = qw(rate amount above below);
  $count = 0;
  @a = ();
  for $i (1 .. $form->{rate_rows}) {
    for (@flds) { $form->{"${_}_$i"} = $form->parse_amount(\%myconfig, $form->{"${_}_$i"}) }
    if ($form->{"rate_$i"} || $form->{"amount_$i"}) {
      push @a, {};
      $j = $#a;

      for (@flds) { $a[$j]->{$_} = $form->{"${_}_$i"} }
      $count++;
    }
  }
  $form->redo_rows(\@flds, \@a, $count, $form->{rate_rows});
  $form->{rate_rows} = $count;


  @flds = qw(base maximum);
  $count = 0;
  @a = ();
  for $i (1 .. $form->{"base_rows"}) {
    $form->{"maximum_$i"} = $form->parse_amount(\%myconfig, $form->{"maximum_$i"});
    if ($form->{"base_$i"}) {
      push @a, {};
      $j = $#a;

      for (@flds) { $a[$j]->{$_} = $form->{"${_}_$i"} }
      $count++;
    }
  }
  $form->redo_rows(\@flds, \@a, $count, $form->{"base_rows"});
  $form->{"base_rows"} = $count;


  @flds = qw(after);
  $count = 0;
  @a = ();
  for $i (1 .. $form->{"after_rows"}) {
    if ($form->{"after_$i"}) {
      push @a, {};
      $j = $#a;

      for (@flds) { $a[$j]->{$_} = $form->{"${_}_$i"} }
      $count++;
    }
  }
  $form->redo_rows(\@flds, \@a, $count, $form->{"after_rows"});
  $form->{"after_rows"} = $count;

  &deduction_header;
  &deduction_footer;

}


sub update_employee {

  # if rate or amount is blank remove row
  @flds = qw(before after);
  $count = 0;
  @a = ();
  for $i (1 .. $form->{deduction_rows}) {
    for (@flds) { $form->{"${_}_$i"} = $form->parse_amount(\%myconfig, $form->{"${_}_$i"}) }
    if ($form->{"deduction_$i"}) {
      push @a, {};
      $j = $#a;

      for (@flds) { $a[$j]->{$_} = $form->{"${_}_$i"} }
      $count++;
    }
  }
  $form->redo_rows(\@flds, \@a, $count, $form->{deduction_rows});
  $form->{deduction_rows} = $count;

  &employee_header;
  &employee_footer;

}
 

sub save_as_new {

  $form->{id} = 0;
  delete $form->{employeelogin};

  &save;

}


sub save_deduction {

  $form->isblank("description", $locale->text("Description missing!"));

  unless ($form->{"rate_1"} || $form->{"amount_1"}) {
    $form->isblank("rate_1", $locale->text("Rate missing!")) unless $form->{"amount_1"};
    $form->isblank("amount_1", $locale->text("Amount missing!"));
  }
  
  HR->save_deduction(\%myconfig, \%$form);
  $form->redirect($locale->text('Deduction saved!'));
  
}


sub delete_deduction {

  HR->delete_deduction(\%myconfig, \%$form);
  $form->redirect($locale->text('Deduction deleted!'));
  
}


