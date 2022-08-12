#=====================================================================
# SQL-Ledger ERP
# Copyright (c) 2006
#
#  Author: DWS Systems Inc.
#     Web: http://www.sql-ledger.com
#
#======================================================================
#
# Job Costing module
#
#======================================================================

use SL::JC;

1;
# end of main



sub add {

  if ($form->{type} eq 'timecard') {
    $form->{title} = $locale->text('Add Time Card');
  }
  if ($form->{type} eq 'storescard') {
    $form->{title} = $locale->text('Add Stores Card');
  }

  $form->{callback} = "$form->{script}?action=add&type=$form->{type}&login=$form->{login}&path=$form->{path}&project=$form->{project}" unless $form->{callback};

  &{ "prepare_$form->{type}" };
  
  $form->{orphaned} = 1;
  &display_form;
  
}


sub edit {

  if ($form->{type} eq 'timecard') {
    $form->{title} = $locale->text('Edit Time Card');
  }
  if ($form->{type} eq 'storescard') {
    $form->{title} = $locale->text('Edit Stores Card');
  }
 
  &{ "prepare_$form->{type}" };
  
  &display_form;
 
}


sub jcitems_links {

  if (@{ $form->{all_project} }) {
    $form->{selectprojectnumber} = "\n";
    $form->{projectdescription} = "";
    foreach $ref (@{ $form->{all_project} }) {
      $form->{selectprojectnumber} .= qq|$ref->{projectnumber}--$ref->{id}\n|;
      if ($form->{projectnumber} eq "$ref->{projectnumber}--$ref->{id}") {
	$form->{projectdescription} = $ref->{description};
      }
    }
  } else {
    if ($form->{project} eq 'job') {
      $form->error($locale->text('No open Jobs!'));
    } else {
      $form->error($locale->text('No open Projects!'));
    }
  }
  
  # employees
  if (@{ $form->{all_employee} }) {
    $form->{selectemployee} = "";
    for (@{ $form->{all_employee} }) { $form->{selectemployee} .= qq|$_->{name}--$_->{id}\n| }
  } else {
    $form->error($locale->text('No Employees on file!'));
  }

  for (qw(projectnumber employee)) { $form->{"select$_"} = $form->escape($form->{"select$_"},1) }
  
}


sub search {
  
  # accounting years
  $form->all_years(\%myconfig);

  if (@{ $form->{all_years} }) {
    $selectaccountingyear = "<option>\n";
    for (@{ $form->{all_years} }) { $selectaccountingyear .= qq|<option>$_\n| }

    $selectaccountingmonth = "<option>\n";
    for (sort keys %{ $form->{all_month} }) { $selectaccountingmonth .= qq|<option value=$_>|.$locale->text($form->{all_month}{$_}).qq|\n| }

    $selectfrom = qq|
        <tr>
	  <th align=right>|.$locale->text('Period').qq|</th>
	  <td colspan=3>
	  <select name=month>$selectaccountingmonth</select>
	  <select name=year>$selectaccountingyear</select>
	  <input name=interval class=radio type=radio value=0 checked>&nbsp;|.$locale->text('Current').qq|
	  <input name=interval class=radio type=radio value=1>&nbsp;|.$locale->text('Month').qq|
	  <input name=interval class=radio type=radio value=3>&nbsp;|.$locale->text('Quarter').qq|
	  <input name=interval class=radio type=radio value=12>&nbsp;|.$locale->text('Year').qq|
	  </td>
	</tr>
|;
  }

  $fromto = qq|
	<tr>
	  <th align=right nowrap>|.$locale->text('Startdate').qq|</th>
	  <td>|.$locale->text('From').qq| <input name=startdatefrom size=11 title="$myconfig{dateformat}" onChange="validateDate(this)">
	  |.$locale->text('To').qq| <input name=startdateto size=11 title="$myconfig{dateformat}" onChange="validateDate(this)"></td>
	</tr>
	$selectfrom
|;

  $form->{title} = $locale->text('Time & Stores Cards');
  if ($form->{type} eq 'timecard') {
    $form->{title} = $locale->text('Time Cards');
  }
  if ($form->{type} eq 'storescard') {
    $form->{title} = $locale->text('Stores Cards');
  }

  JC->jcitems_links(\%myconfig, \%$form);
  
  if (@{ $form->{all_project} }) {
    $form->{selectprojectnumber} = "<option>\n";
    for (@{ $form->{all_project} }) { $form->{selectprojectnumber} .= qq|<option value="|.$form->quote($_->{projectnumber}).qq|--$_->{id}">$_->{projectnumber}\n| }
  }
  
  if ($form->{project} eq 'job') {
    
    $projectnumberlabel = $locale->text('Job Number');
    $projectdescriptionlabel = $locale->text('Job Name');
    if ($form->{type}) {
      if ($form->{type} eq 'timecard') {
	$partnumberlabel = $locale->text('Labor Code');
      } else {
	$partnumberlabel = $locale->text('Part Number');
      }
    } else {
      $partnumberlabel = $locale->text('Part Number')."/".$locale->text('Labor Code');
    }

  } elsif ($form->{project} eq 'project') {
    
    $projectnumberlabel = $locale->text('Project Number');
    $projectdescriptionlabel = $locale->text('Project Name');
    $partnumberlabel = $locale->text('Service Code');
    
  } else {
    
    $projectnumberlabel = $locale->text('Project Number')."/".$locale->text('Job Number');
    $partnumberlabel = $locale->text('Service Code')."/".$locale->text('Labor Code');
    $projectdescriptionlabel = $locale->text('Project Name')."/".$locale->text('Job Name');
    
  }
  
  if ($form->{selectprojectnumber}) {
    $projectnumber = qq|
      <tr>
	<th align=right nowrap>$projectnumberlabel</th>
	<td colspan=3><select name=projectnumber>$form->{selectprojectnumber}</select></td>
      </tr>
|;
  }
  
  $partnumber = qq|
	<tr>
	  <th align=right nowrap>$partnumberlabel</th>
	  <td colspan=3><input name=partnumber></td>
        </tr>
|;

 
  if ($form->{type} eq 'timecard') {
    # employees
    if (@{ $form->{all_employee} }) {
      $form->{selectemployee} = "<option>\n";
      for (@{ $form->{all_employee} }) { $form->{selectemployee} .= qq|<option value="|.$form->quote($_->{name}).qq|--$_->{id}">$_->{name}\n| }
    } else {
      $form->error($locale->text('No Employees on file!'));
    }
    
    $employee = qq|
	<tr>
	  <th align=right nowrap>|.$locale->text('Employee').qq|</th>
	  <td colspan=3><select name=employee>$form->{selectemployee}</select></td>
        </tr>
|;

    $l_time = qq|<input name=l_time class=checkbox type=checkbox value=Y>&nbsp;|.$locale->text('Time');
   
  }
  
  @a = ();
  push @a, qq|<input name="l_transdate" class=checkbox type=checkbox value=Y checked> |.$locale->text('Date');
  push @a, qq|<input name="l_projectnumber" class=checkbox type=checkbox value=Y checked> $projectnumberlabel|;
  push @a, qq|<input name="l_projectdescription" class=checkbox type=checkbox value=Y checked> $projectdescriptionlabel|;
  push @a, qq|<input name="l_id" class=checkbox type=checkbox value=Y checked> |.$locale->text('ID');
  push @a, qq|<input name="l_partnumber" class=checkbox type=checkbox value=Y checked> $partnumberlabel|;
  push @a, qq|<input name="l_description" class=checkbox type=checkbox value=Y checked> |.$locale->text('Description');
  push @a, qq|<input name="l_notes" class=checkbox type=checkbox value=Y checked> |.$locale->text('Notes');
  push @a, qq|<input name="l_qty" class=checkbox type=checkbox value=Y checked> |.$locale->text('Qty');
  push @a, $l_time if $l_time;
  push @a, qq|<input name=l_allocated class=checkbox type=checkbox value=Y> |.$locale->text('Allocated');

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
        $projectnumber
	$partnumber
	$employee
	$fromto

	<tr>
	  <th align=right nowrap>|.$locale->text('Include in Report').qq|</th>
	  <td>
	    <table>
	      <tr>
       		<td nowrap><input name=open class=checkbox type=checkbox value=Y checked> |.$locale->text('Open').qq|</td>
		<td nowrap><input name=closed class=checkbox type=checkbox value=Y> |.$locale->text('Closed').qq|</td>
	      </tr>
|;

  while (@a) {
    for (1 .. 5) {
      print qq|<td nowrap>|. shift @a;
      print qq|</td>\n|;
    }
    print qq|</tr>\n|;
  }

  print qq|
	      <tr>
	        <td><input name=l_subtotal class=checkbox type=checkbox value=Y>&nbsp;|.$locale->text('Subtotal').qq|</td>
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

<input type=hidden name=nextsub value="list_cards">
<input type=hidden name=sort value="transdate">
|;

  $form->hide_form(qw(db path login project type));

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


sub display_form {

  &{ "$form->{type}_header" };
  &{ "$form->{type}_footer" };

}


sub form_header {

  &{ "$form->{type}_header" };

}


sub form_footer {

  &{ "form->{type}_footer" };

}


sub prepare_timecard {

  $form->{formname} = "timecard";
  $form->{format} ||= $myconfig{outputformat};

  if ($myconfig{printer}) {
    $form->{format} ||= "postscript";
  } else {
    $form->{format} ||= "pdf";
  }
  $form->{media} ||= $myconfig{printer};
  
  JC->retrieve_card(\%myconfig, \%$form);

  $form->{selectformname} = qq|timecard--|.$locale->text('Time Card');
  
  foreach $item (qw(in out)) {
    ($form->{"${item}hour"}, $form->{"${item}min"}, $form->{"${item}sec"}) = split /:/, $form->{"checked$item"};
    for (qw(hour min sec)) {
      if (($form->{"$item$_"} *= 1) > 0) {
        $form->{"$item$_"} = substr(qq|0$form->{"$item$_"}|,-2);
      } else {
	$form->{"$item$_"} ||= "";
      }
    }
  }
  
  $form->{checkedin} = $form->{inhour} * 3600 + $form->{inmin} * 60 + $form->{insec};
  $form->{checkedout} = $form->{outhour} * 3600 + $form->{outmin} * 60 + $form->{outsec};

  if ($form->{checkedin} > $form->{checkedout}) {
    $form->{checkedout} = 86400 - ($form->{checkedin} - $form->{checkedout});
    $form->{checkedin} = 0;
  }

  $form->{clocked} = ($form->{checkedout} - $form->{checkedin}) / 3600;
  if ($form->{clocked}) {
    $form->{oldnoncharge} = $form->{clocked} - $form->{qty};
  }
  $form->{oldqty} = $form->{qty};
  
  $form->{noncharge} = $form->format_amount(\%myconfig, $form->{clocked} - $form->{qty}, 4) if $form->{checkedin} != $form->{checkedout};
  $form->{clocked} = $form->format_amount(\%myconfig, $form->{clocked}, 4);
  
  $form->{amount} = $form->{sellprice} * $form->{qty};
  for (qw(sellprice amount)) { $form->{$_} = $form->format_amount(\%myconfig, $form->{$_}, $form->{precision}) }
  $form->{qty} = $form->format_amount(\%myconfig, $form->{qty}, 4);
  $form->{allocated} = $form->format_amount(\%myconfig, $form->{allocated}, 4);

  $form->{employee} .= "--$form->{employee_id}";
  $form->{projectnumber} .= "--$form->{project_id}";
  $form->{oldpartnumber} = $form->{partnumber};
  $form->{oldproject_id} = $form->{project_id};

  if (@{ $form->{all_language} }) {
    $form->{selectlanguage} = "\n";
    for (@{ $form->{all_language} }) { $form->{selectlanguage} .= qq|$_->{code}--$_->{description}\n| }
  }

  &jcitems_links;

  $form->{locked} = ($form->{revtrans}) ? '1' : ($form->datetonum(\%myconfig, $form->{transdate}) <= $form->{closedto});
  
  $form->{readonly} = 1 if $myconfig{acs} =~ /Production--Add Time Card/;

  if ($form->{income_accno_id}) {
    $form->{locked} = 1 if $form->{production} == $form->{completed};
  }

  for (qw(formname language)) { $form->{"select$_"} = $form->escape($form->{"select$_"}, 1) }

}


sub timecard_header {

  $rows = $form->numtextrows($form->{description}, 50, 8);

  for (qw(transdate checkedin checkedout partnumber)) { $form->{"old$_"} = $form->{$_} }

  if ($rows > 1) {
    $description = qq|<textarea name=description rows=$rows cols=46 wrap=soft>$form->{description}</textarea>|;
  } else {
    $description = qq|<input name=description size=48 value="|.$form->quote($form->{description}).qq|">|;
  }
  
  $projectlabel = $locale->text('Project/Job Number');
  $laborlabel = $locale->text('Service/Labor Code');
 
  if ($form->{project} eq 'job') {
    $projectlabel = $locale->text('Job Number');
    $laborlabel = $locale->text('Labor Code');
    $chargeoutlabel = $locale->text('Cost');
  }
  
  if ($form->{project} eq 'project') {
    $projectlabel = $locale->text('Project Number');
    $laborlabel = $locale->text('Service Code');
    $chargeoutlabel = $locale->text('Chargeout Rate');
  }


  if ($myconfig{role} ne 'user') {
    if ($form->{type} eq 'timecard') {
      $rate = qq|
	      <tr>
		<th align=right nowrap>$chargeoutlabel</th>
		<td><input name=sellprice value=$form->{sellprice}></td>|;
      $rate .= qq|<th align=right nowrap>|.$locale->text('Total').qq|</th>
                <td>$form->{amount}</td>| if $form->{amount};
      $rate .= qq|
	      </tr>
	      <tr>
		<th align=right nowrap>|.$locale->text('Allocated').qq|</th>
		<td><input name=allocated value=$form->{allocated}></td>
	      </tr>
|;
    } else {
      $rate = qq|
	      <tr>
		<th align=right nowrap>$chargeoutlabel</th>
		<td><input name=sellprice value=$form->{sellprice}></td>|;
      $rate .= qq|<th align=right nowrap>|.$locale->text('Total').qq|</th>
                <td>$form->{amount}</td>| if $form->{amount};
      $rate .= qq|
	      </tr>
	      <tr>
		<th align=right nowrap>|.$locale->text('Allocated').qq|</th>
		<td>$form->{allocated}</td>
	      </tr>|
	      .$form->hide_form(qw(allocated));
    }
    
  } else {
    $rate = qq|
              <tr>
	        <th align=right nowrap>$chargeoutlabel</th>
		<td>$form->{sellprice}</td>|;
    $rate .= qq|<th align=right nowrap>|.$locale->text('Total').qq|</th>
                <td>$form->{amount}</td>| if $form->{amount};
    $rate .= qq|
              </tr>
	      <tr>
		<th align=right nowrap>|.$locale->text('Allocated').qq|</th>
		<td>$form->{allocated}</td>
	      </tr>|
	      .$form->hide_form(qw(sellprice allocated));
  }
  
  if ($myconfig{role} ne 'user') {
    $charge = qq|<input name=qty value=$form->{qty}>|;
  } else {
    $charge = $form->{qty}.$form->hide_form(qw(qty));
  }
  
  if (($rows = $form->numtextrows($form->{notes}, 40, 6)) < 2) {
    $rows = 2;
  }

  $notes = qq|<tr>
		<th align=right>|.$locale->text('Notes').qq|</th>
                  <td colspan=3><textarea name="notes" rows=$rows cols=46 wrap=soft>$form->{notes}</textarea>
		</td>
	      </tr>
|;

  $clocked = qq|
 	<tr>
	  <th align=right nowrap>|.$locale->text('Clocked').qq|</th>
	  <td>$form->{clocked}</td>
	</tr>
|;
   
  $form->header;

  print qq|
<body>

<form method=post action="$form->{script}">
|;

  $form->hide_form(map { "select$_" } qw(projectnumber employee formname language));
  $form->hide_form(qw(id type printed queued title closedto locked project pricematrix parts_id precision));
  $form->hide_form(map { "old$_" } qw(transdate checkedin checkedout partnumber qty noncharge project_id));

  print qq|
<table width=100%>
  <tr class=listtop>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <td>
      <table>
	<tr>
	  <th align=right nowrap>|.$locale->text('Employee').qq| <font color=red>*</font></th>
	  <td colspan=3><select name=employee>|
	  .$form->select_option($form->{selectemployee}, $form->{employee}, 1)
	  .qq|</select>
	  </td>
	</tr>
	<tr>
	  <th align=right nowrap>$projectlabel <font color=red>*</font></th>
	  <td><select name=projectnumber>|
	  .$form->select_option($form->{selectprojectnumber}, $form->{projectnumber}, 1)
	  .qq|</select>
	  </td>
	  <td colspan=2>$form->{projectdescription}</td>|
	  .$form->hide_form(qw(projectdescription))
	  .qq|
	</tr>
	<tr>
	  <th align=right nowrap>|.$locale->text('Date worked').qq| <font color=red>*</font></th>
	  <td><input name=transdate size=11 title="$myconfig{dateformat}" onChange="validateDate(this)" value=$form->{transdate}></td>
	</tr>
	<tr>
	  <th align=right nowrap>$laborlabel <font color=red>*</font></th>
	  <td><input name=partnumber value="|.$form->quote($form->{partnumber})
	  .qq|">
	  </td>
	</tr>
	<tr valign=top>
	  <th align=right nowrap>|.$locale->text('Description').qq|</th>
	  <td colspan=3>$description</td>
	</tr>
	<tr>
	  <th align=right nowrap>|.$locale->text('Time In').qq|</th>
	  <td>
	    <table>
	      <tr>
		<td><input name=inhour title="hh" size=3 maxlength=2 value=$form->{inhour}></td>
		<td><input name=inmin title="mm" size=3 maxlength=2 value=$form->{inmin}></td>
		<td><input name=insec title="ss" size=3 maxlength=2 value=$form->{insec}></td>
	      </tr>
	    </table>
	  </td>
	  <th align=right nowrap>|.$locale->text('Time Out').qq|</th>
	  <td>
	    <table>
	      <tr>
		<td><input name=outhour title="hh" size=3 maxlength=2 value=$form->{outhour}></td>
		<td><input name=outmin title="mm" size=3 maxlength=2 value=$form->{outmin}></td>
		<td><input name=outsec title="ss" size=3 maxlength=2 value=$form->{outsec}></td>
	      </tr>
	    </table>
	  </td>
	</tr>
	$clocked
	<tr>
	  <th align=right nowrap>|.$locale->text('Non-chargeable').qq|</th>
	  <td><input name=noncharge value=$form->{noncharge}></td>
	</tr>
	<tr>
	  <th align=right nowrap>|.$locale->text('Chargeable').qq|</th>
	  <td>$charge</td>
	</tr>
	$rate
	$notes
|;

}


sub timecard_footer {

  print qq|
      </table>
    </td>
  </tr>
  <tr>
    <td><hr size=3 noshade></td>
  </tr>
  <tr>
    <td>
|;

  &print_options;

  print qq|
    </td>
  </tr>
</table>
<br>
|;

  $transdate = $form->datetonum(\%myconfig, $form->{transdate});

  if ($form->{readonly}) {

    &islocked;

  } else {

  %button = ('Update' => { ndx => 1, key => 'U', value => $locale->text('Update') },
             'Print' => { ndx => 2, key => 'P', value => $locale->text('Print') },
	     'Save' => { ndx => 3, key => 'S', value => $locale->text('Save') },
	     'Save as new' => { ndx => 7, key => 'N', value => $locale->text('Save as new') },
	     
	     'Delete' => { ndx => 16, key => 'D', value => $locale->text('Delete') },
	    );

    %a = ();
    
    if ($form->{id}) {
    
      if (!$form->{locked}) {
	for ('Update', 'Print', 'Save', 'Save as new') { $a{$_} = 1 }
	
	if ($latex) {
	  for ('Print and Save') { $a{$_} = 1 }
	}

	if ($form->{orphaned}) {
	  $a{'Delete'} = 1;
	}
	
      }

    } else {

      if ($transdate > $form->{closedto}) {
	
	for ('Update', 'Print', 'Save') { $a{$_} = 1 }

	if ($latex) {
	  $a{'Print and Save'} = 1;
	}

      }
    }
  }

  for (keys %button) { delete $button{$_} if ! $a{$_} }
  for (sort { $button{$a}->{ndx} <=> $button{$b}->{ndx} } keys %button) { $form->print_button(\%button, $_) }
  
  if ($form->{menubar}) {
    require "$form->{path}/menu.pl";
    &menubar;
  }

  $form->hide_form(qw(callback path login orphaned));
  
  print qq|

</form>

</body>
</html>
|;

}


sub prepare_storescard {

  $form->{formname} = "storescard";
  $form->{format} = "postscript" if $myconfig{printer};
  $form->{media} = $myconfig{printer};

  JC->retrieve_card(\%myconfig, \%$form);
  
  $form->{selectformname} = qq|storescard--|.$locale->text('Stores Card');
  
  $form->{amount} = $form->{sellprice} * $form->{qty};
  for (qw(sellprice amount)) { $form->{$_} = $form->format_amount(\%myconfig, $form->{$_}, $form->{precision}) }
  $form->{qty} = $form->format_amount(\%myconfig, $form->{qty});
 
  $form->{employee} .= "--$form->{employee_id}";
  $form->{projectnumber} .= "--$form->{project_id}";
  $form->{oldpartnumber} = $form->{partnumber};
  $form->{oldproject_id} = $form->{project_id};

  if (@{ $form->{all_language} }) {
    $form->{selectlanguage} = "\n";
    for (@{ $form->{all_language} }) { $form->{selectlanguage} .= qq|$_->{code}--$_->{description}\n| }
  }

  &jcitems_links;

  $form->{locked} = ($form->{revtrans}) ? '1' : ($form->datetonum(\%myconfig, $form->{transdate}) <= $form->{closedto});
  
  $form->{readonly} = 1 if $myconfig{acs} =~ /Production--Add Time Card/;

  if ($form->{income_accno_id}) {
    $form->{locked} = 1 if $form->{production} == $form->{completed};
  }

  for (qw(formname language)) { $form->{"select$_"} = $form->escape($form->{"select$_"}, 1) }

}


sub storescard_header {

  $rows = $form->numtextrows($form->{description}, 50, 8);

  for (qw(transdate partnumber)) { $form->{"old$_"} = $form->{$_} }

  if ($rows > 1) {
    $description = qq|<textarea name=description rows=$rows cols=46 wrap=soft>$form->{description}</textarea>|;
  } else {
    $description = qq|<input name=description size=48 value="|.$form->quote($form->{description}).qq|">|;
  }

  if ($myconfig{role} ne 'user') {
    $cost = qq|<tr>
                 <th align=right nowrap>|.$locale->text('Cost').qq|</th>
                 <td><input name=sellprice value=$form->{sellprice}></td>|;
    $cost .= qq|<th align=right nowrap>|.$locale->text('Total').qq|</th>
               <td>$form->{amount}</td>| if $form->{amount};
    $cost .= qq|
	       </tr>|;
  } else {
    $cost = $form->hide_form(qw(sellprice));
  }
   

  $form->header;

  print qq|
<body>

<form method=post action="$form->{script}">
|;

  $form->hide_form(map { "select$_" } qw(projectnumber formname language));
  $form->hide_form(qw(id type printed queued title closedto locked project parts_id employee precision));
  $form->hide_form(map { "old$_" } qw(transdate partnumber));

  print qq|
<table width=100%>
  <tr class=listtop>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <td>
      <table>
        <tr>
	  <th align=right nowrap>|.$locale->text('Job Number').qq| <font color=red>*</font></th>
	  <td colspan=2><select name=projectnumber>|
	  .$form->select_option($form->{selectprojectnumber}, $form->{projectnumber}, 1)
	  .qq|</select>
	  </td>
	  <td>$form->{projectdescription}</td>|
	  .$form->hide_form(qw(projectdescription))
	  .qq|
	</tr>
	<tr>
	  <th align=right nowrap>|.$locale->text('Date').qq| <font color=red>*</font></th>
	  <td colspan=3><input name=transdate size=11 title="$myconfig{dateformat}" onChange="validateDate(this)" value=$form->{transdate}></td>
	</tr>
	<tr>
	  <th align=right nowrap>|.$locale->text('Part Number').qq| <font color=red>*</font></th>
	  <td colspan=3><input name=partnumber value="|.$form->quote($form->{partnumber})
	  .qq|">
	  </td>
	</tr>
	<tr valign=top>
	  <th align=right nowrap>|.$locale->text('Description').qq|</th>
	  <td colspan=3>$description</td>
	</tr>
	<tr>
	  <th align=right nowrap>|.$locale->text('Qty').qq|</th>
	  <td><input name=qty size=6 value=$form->{qty}></td>
	</tr>
	$cost
|;

}


sub storescard_footer {

  print qq|
      </table>
    </td>
  </tr>
  <tr>
    <td><hr size=3 noshade></td>
  </tr>
  <tr>
    <td>
|;

  &print_options;

  print qq|
    </td>
  </tr>
</table>
<br>
|;

  $transdate = $form->datetonum(\%myconfig, $form->{transdate});

  if (! $form->{readonly}) {

    %button = ('Update' => { ndx => 1, key => 'U', value => $locale->text('Update') },
               'Print' => { ndx => 2, key => 'P', value => $locale->text('Print') },
	       'Save' => { ndx => 3, key => 'S', value => $locale->text('Save') },
	       'Save as new' => { ndx => 7, key => 'N', value => $locale->text('Save as new') },
	       'Delete' => { ndx => 16, key => 'D', value => $locale->text('Delete') },
	      );
    
    %a = ();
    
    if ($form->{id}) {
      
      if (!$form->{locked}) {
	for ('Update', 'Print', 'Save', 'Save as new') { $a{$_} = 1 }
	if ($latex) {
	  for ('Print and Save', 'Print and Save as new') { $a{$_} = 1 }
	}
	if ($form->{orphaned}) {
	  $a{'Delete'} = 1;
	}
      }
      
    } else {

      if ($transdate > $form->{closedto}) {
	for ('Update', 'Print', 'Save') { $a{$_} = 1 }

	if ($latex) {
	  $a{'Print and Save'} = 1;
	}
      }
    }

    for (keys %button) { delete $button{$_} if ! $a{$_} }
    for (sort { $button{$a}->{ndx} <=> $button{$b}->{ndx} } keys %button) { $form->print_button(\%button, $_) }
    
  }

  if ($form->{menubar}) {
    require "$form->{path}/menu.pl";
    &menubar;
  }

  $form->hide_form(qw(callback path login orphaned));
  
  print qq|

</form>

</body>
</html>
|;

}



sub update {

  ($null, $form->{project_id}) = split /--/, $form->{projectnumber};

  $form->isvaldate(\%myconfig, $form->{transdate}, $locale->text('Invalid date ...'));

  for (qw(transdate project_id)) {
    if ($form->{"old$_"} ne $form->{$_}) {
      JC->jcitems_links(\%myconfig, \%$form);
      &jcitems_links;
      last;
    }
  }

  if ($form->{oldpartnumber} ne $form->{partnumber}) {
    $form->error($locale->text('Project/Job Number missing!')) if ! $form->{project};
    if ($form->{project} eq 'project') {
      $form->error($locale->text('Project Number missing!')) if ! $form->{projectnumber};
    }
    if ($form->{project} eq 'job') {
      $form->error($locale->text('Job Number missing!')) if ! $form->{projectnumber}; 
    }

    JC->retrieve_item(\%myconfig, \%$form);

    $rows = scalar @{ $form->{item_list} };

    if ($rows) {

      if ($rows > 1) {
	&select_item;
	exit;
      } else {
	for (keys %{ $form->{item_list}[0] }) { $form->{$_} = $form->{item_list}[0]{$_} }
	
	($dec) = ($form->{sellprice} =~ /\.(\d+)/);
	$dec = length $dec;
	$decimalplaces = ($dec > $form->{precision}) ? $dec : $form->{precision};
	
	$form->{sellprice} = $form->format_amount(\%myconfig, $form->{sellprice}, $decimalplaces);
      }

    } else {
      &new_item;
      exit;
    }
  }

  if ($form->{type} eq 'timecard') {

    # time clocked
    %hour = ( in => 0, out => 0 );
    for $t (qw(in out)) {
      if ($form->{"${t}sec"} > 60) {
	$form->{"${t}sec"} -= 60;
	$form->{"${t}min"}++;
      }
      if ($form->{"${t}min"} > 60) {
	$form->{"${t}min"} -= 60;
	$form->{"${t}hour"}++;
      }
      $hour{$t} = $form->{"${t}hour"};
    }

    $form->{checkedin} = $hour{in} * 3600 + $form->{inmin} * 60 + $form->{insec};
    $form->{checkedout} = $hour{out} * 3600 + $form->{outmin} * 60 + $form->{outsec};

    if ($form->{checkedin} > $form->{checkedout}) {
      $form->{checkedout} = 86400 - ($form->{checkedin} - $form->{checkedout});
      $form->{checkedin} = 0;
    }

    $form->{clocked} = ($form->{checkedout} - $form->{checkedin}) / 3600;

    for (qw(sellprice qty noncharge allocated)) { $form->{$_} = $form->parse_amount(\%myconfig, $form->{$_}) }
    
    $checkmatrix = 1 if $form->{oldqty} != $form->{qty};
    
    if (($form->{oldcheckedin} != $form->{checkedin}) || ($form->{oldcheckedout} != $form->{checkedout})) {
      $checkmatrix = 1;
      $form->{oldqty} = $form->{qty} = $form->{clocked} - $form->{noncharge};
      $form->{oldnoncharge} = $form->{noncharge};
    }

    if (($form->{qty} != $form->{oldqty}) && $form->{clocked}) {
      $form->{oldnoncharge} = $form->{noncharge} = $form->{clocked} - $form->{qty};
      $checkmatrix = 1;
    }

    if (($form->{oldnoncharge} != $form->{noncharge}) && $form->{clocked}) {
      $form->{oldqty} = $form->{qty} = $form->{clocked} - $form->{noncharge};
      $checkmatrix = 1;
    }
    
    if ($checkmatrix) {
      @a = split / /, $form->{pricematrix};
      if (scalar @a > 2) {
	for (@a) {
	  ($q, $p) = split /:/, $_;
	  if (($p * 1) && ($form->{qty} >= ($q * 1))) {
	    $form->{sellprice} = $p;
	  }
	}
      }
    }
      
    $form->{amount} = $form->{sellprice} * $form->{qty};
	
    $form->{clocked} = $form->format_amount(\%myconfig, $form->{clocked}, 4);
    for (qw(sellprice amount)) { $form->{$_} = $form->format_amount(\%myconfig, $form->{$_}, $form->{precision}) }
    for (qw(qty noncharge)) {
      $form->{"old$_"} = $form->{$_};
      $form->{$_} = $form->format_amount(\%myconfig, $form->{$_}, 4);
    }
    
  } else {
    
    for (qw(sellprice qty allocated)) { $form->{$_} = $form->parse_amount(\%myconfig, $form->{$_}) }

    if ($form->{oldqty} != $form->{qty}) {
      @a = split / /, $form->{pricematrix};
      if (scalar @a > 2) {
	for (@a) {
	  ($q, $p) = split /:/, $_;
	  if (($p * 1) && ($form->{qty} >= ($q * 1))) {
	    $form->{sellprice} = $p;
	  }
	}
      }
    }
    
    $form->{amount} = $form->{sellprice} * $form->{qty};
    for (qw(sellprice amount)) { $form->{$_} = $form->format_amount(\%myconfig, $form->{$_}, $form->{precision}) }
    $form->{oldqty} = $form->{qty};
    $form->{qty} = $form->format_amount(\%myconfig, $form->{qty});
 
  }

  $form->{allocated} = $form->format_amount(\%myconfig, $form->{allocated});
    
  &display_form;

}


sub save {

  $form->isblank("transdate", $locale->text('Date missing!'));
  $form->isvaldate(\%myconfig, $form->{transdate}, $locale->text('Invalid date ...'));

  if ($form->{project} eq 'project') {
    $form->isblank("projectnumber", $locale->text('Project Number missing!'));
    $form->isblank("partnumber", $locale->text('Service Code missing!'));
  } else {
    $form->isblank("projectnumber", $locale->text('Job Number missing!'));
    $form->isblank("partnumber", $locale->text('Labor Code missing!'));
  }

  $transdate = $form->datetonum(\%myconfig, $form->{transdate});
  
  $msg = ($form->{type} eq 'timecard') ? $locale->text('Cannot save time card for a closed period!') : $locale->text('Cannot save stores card for a closed period!');
  $form->error($msg) if ($transdate <= $form->{closedto});

  if (! $form->{resave}) {
    if ($form->{id}) {
      &resave;
      exit;
    }
  }
  
  
  $rc = JC->save(\%myconfig, \%$form);
  
  if ($form->{type} eq 'timecard') {
    $form->error($locale->text('Cannot change time card for a completed job!')) if ($rc == -1);
    $form->error($locale->text('Cannot add time card for a completed job!')) if ($rc == -2);
    
    if ($rc) {
      $form->redirect($locale->text('Time Card saved!'));
    } else {
      $form->error($locale->text('Cannot save time card!'));
    }
    
  } else {
    $form->error($locale->text('Cannot change stores card for a completed job!')) if ($rc == -1);
    $form->error($locale->text('Cannot add stores card for a completed job!')) if ($rc == -2);

    if ($rc) {
      $form->redirect($locale->text('Stores Card saved!'));
    } else {
      $form->error($locale->text('Cannot save stores card!'));
    }
  }
  
}


sub save_as_new {

  delete $form->{id};
  &save;

}


sub print_and_save_as_new {

  delete $form->{id};
  &print_and_save;

}


sub resave {

  if ($form->{print_and_save}) {
    $form->{nextsub} = "print_and_save";
    $msg = $locale->text('You are printing and saving an existing transaction!');
  } else {
    $form->{nextsub} = "save";
    $msg = $locale->text('You are saving an existing transaction!');
  }
  
  $form->{resave} = 1;
  
  $form->header;

  print qq|
<body>

<form method=post action=$form->{script}>

|;

  delete $form->{action};

  $form->hide_form;

  print qq|
<h2 class=confirm>|.$locale->text('Warning!').qq|</h2>

<h4>$msg</h4>

<input name=action class=submit type=submit value="|.$locale->text('Continue').qq|">
</form>

</body>
</html>
|;

}


sub print_and_save {

  $form->error($locale->text('Select postscript or PDF!')) if $form->{format} !~ /(postscript|pdf)/;
  $form->error($locale->text('Select a Printer!')) if $form->{media} eq 'screen';

  if (! $form->{resave}) {
    if ($form->{id}) {
      $form->{print_and_save} = 1;
      &resave;
      exit;
    }
  }

  $old_form = new Form;
  $form->{display_form} = "save";
  for (keys %$form) { $old_form->{$_} = $form->{$_} }

  &{ "print_$form->{formname}" }($old_form);

}


sub delete_timecard {

  $form->header;

  $employee = $form->{employee};
  $employee =~ s/--.*//g;
  $projectnumber = $form->{projectnumber};
  $projectnumber =~ s/--.*//g;

  print qq|
<body>

<form method=post action=$form->{script}>
|;

  delete $form->{action};

  $form->hide_form;

  print qq|
<h2 class=confirm>|.$locale->text('Confirm!').qq|</h2>

<h4>|.$locale->text('Are you sure you want to delete time card for').qq|
<p>$form->{transdate}
<br>$employee
<br>$projectnumber
</h4>

<p>
<input name=action class=submit type=submit value="|.$locale->text('Yes').qq|">
</form>
|;

}


sub delete { &{ "delete_$form->{type}" } };
sub yes { &{ "yes_delete_$form->{type}" } };


sub yes_delete_timecard {
  
  if (JC->delete_timecard(\%myconfig, \%$form)) {
    $form->redirect($locale->text('Time Card deleted!'));
  } else {
    $form->error($locale->text('Cannot delete time card!'));
  }

}


sub list_cards {

  $form->isvaldate(\%myconfig, $form->{startdatefrom}, $locale->text('Invalid from date ...'));
  $form->isvaldate(\%myconfig, $form->{startdateto}, $locale->text('Invalid to date ...'));
  
  if (! exists $form->{title}) {
    $form->{title} = $locale->text('Time and Stores Cards');
    $form->{title} = $locale->text('Stores Cards') if $form->{type} eq 'storescard';
    $form->{title} = $locale->text('Time Cards') if $form->{type} eq 'timecard';
  }
  
  JC->jcitems(\%myconfig, \%$form);

  @a = qw(type direction oldsort path login project open closed);
  $href = "$form->{script}?action=list_cards";
  for (@a) { $href .= "&$_=$form->{$_}" }

  $href .= "&title=".$form->escape($form->{title});

  $form->sort_order();

  $callback = "$form->{script}?action=list_cards";
  for (@a) { $callback .= "&$_=$form->{$_}" }

  @columns = $form->sort_columns(qw(transdate id projectnumber projectname partnumber description notes));

  @column_index = ();
  foreach $item (@columns) {
    if ($form->{"l_$item"} eq "Y") {
      push @column_index, $item;

      $callback .= "&l_$item=Y";
      $href .= "&l_$item=Y";
    }
  }

  foreach $item (qw(subtotal qty allocated sellprice)) {
    if ($form->{"l_$item"} eq "Y") {
      $callback .= "&l_$item=Y";
      $href .= "&l_$item=Y";
    }
  }

  $callback .= "&title=".$form->escape($form->{title},1);
  
  if (@{ $form->{transactions} }) {
    $sameitem = $form->{transactions}->[0]->{$form->{sort}};
    if ($form->{type} eq 'timecard') {
      $sameemployeenumber = $form->{transactions}->[0]->{employeenumber};
      $employee = $form->{transactions}->[0]->{employee};
      $sameweek = $form->{transactions}->[0]->{workweek};
    }
  }

  
  if ($form->{type} eq 'timecard') {
    push @column_index, (qw(2 3 4 5 6 7 1)) if ($form->{l_qty} || $form->{l_time});
  } else {
    push @column_index, (qw(qty sellprice)) if $form->{l_qty};
  }
  
  push @column_index, "allocated" if $form->{l_allocated};
  
  if ($form->{project} eq 'job') {
    $joblabel = $locale->text('Job Number');
    if ($form->{type} eq 'timecard') {
      $laborlabel = $locale->text('Labor Code');
    } elsif ($form->{type} eq 'storescard') {
      $laborlabel = $locale->text('Part Number');
    } else {
      $laborlabel = $locale->text('Part Number')."/".$locale->text('Labor Code');
    }
    $desclabel = $locale->text('Job Name');
  } elsif ($form->{project} eq 'project') {
    $joblabel = $locale->text('Project Number');
    $laborlabel = $locale->text('Service Code');
    $desclabel = $locale->text('Project Name');
  } else {
    $joblabel = $locale->text('Project Number')."/".$locale->text('Job Number');
    $laborlabel = $locale->text('Service Code')."/".$locale->text('Labor Code');
    $desclabel = $locale->text('Project Description')."/".$locale->text('Job Name');
  }
  
  if ($form->{projectnumber}) {
    $callback .= "&projectnumber=".$form->escape($form->{projectnumber},1);
    $href .= "&projectnumber=".$form->escape($form->{projectnumber});
    ($var) = split /--/, $form->{projectnumber};
    $option .= "\n<br>" if ($option);
    $option .= "$joblabel : $var";
    @column_index = grep !/(projectnumber|projectdescription)/, @column_index;
    $option .= "\n<br>$desclabel : ".$form->{transactions}->[0]->{projectdescription};
  }
  if ($form->{partnumber}) {
    $callback .= "&partnumber=".$form->escape($form->{partnumber},1);
    $href .= "&partnumber=".$form->escape($form->{partnumber});
    $option .= "\n<br>" if ($option);
    $option .= "$laborlabel : $form->{partnumber}";
  }
  if ($form->{employee}) {
    $callback .= "&employee=".$form->escape($form->{employee},1);
    $href .= "&employee=".$form->escape($form->{employee});
  }
  
  if ($form->{startdatefrom}) {
    $callback .= "&startdatefrom=$form->{startdatefrom}";
    $href .= "&startdatefrom=$form->{startdatefrom}";
    $option .= "\n<br>" if ($option);
    $option .= $locale->text('From')."&nbsp;".$locale->date(\%myconfig, $form->{startdatefrom}, 1);
  }
  if ($form->{startdateto}) {
    $callback .= "&startdateto=$form->{startdateto}";
    $href .= "&startdateto=$form->{startdateto}";
    $option .= "\n<br>" if ($option);
    $option .= $locale->text('To')."&nbsp;".$locale->date(\%myconfig, $form->{startdateto}, 1);
  }
  if ($form->{open}) {
    $callback .= "&open=$form->{open}";
    $href .= "&open=$form->{open}";
    $option .= "\n<br>" if ($option);
    $option .= $locale->text('Open');
  }
  if ($form->{closed}) {
    $callback .= "&closed=$form->{closed}";
    $href .= "&closed=$form->{closed}";
    $option .= "\n<br>" if ($option);
    $option .= $locale->text('Closed');
  }

  if ($form->{type} eq 'timecard') {

    %weekday = ( 1 => $locale->text('Sunday'),
		 2 => $locale->text('Monday'),
		 3 => $locale->text('Tuesday'),
		 4 => $locale->text('Wednesday'),
		 5 => $locale->text('Thursday'),
		 6 => $locale->text('Friday'),
		 7 => $locale->text('Saturday'),
	       );
    
    for (keys %weekday) { $column_header{$_} = "<th class=listheading width=25>".substr($weekday{$_},0,3)."</th>" }
  }
  
  $column_header{id} = "<th><a class=listheading href=$href&sort=id>".$locale->text('ID')."</a></th>";
  $column_header{transdate} = "<th><a class=listheading href=$href&sort=transdate>".$locale->text('Date')."</a></th>";
  $column_header{description} = "<th><a class=listheading href=$href&sort=description>".$locale->text('Description')."</a></th>";
  $column_header{projectnumber} = "<th><a class=listheading href=$href&sort=projectnumber>$joblabel</a></th>";
  $column_header{partnumber} = "<th><a class=listheading href=$href&sort=partnumber>$laborlabel</a></th>";
  $column_header{projectdescription} = "<th><a class=listheading href=$href&sort=projectdescription>$desclabel</a></th>";
  $column_header{notes} = "<th class=listheading>".$locale->text('Notes')."</th>";
  $column_header{qty} = "<th class=listheading>".$locale->text('Qty')."</th>";
  $column_header{allocated} = "<th class=listheading>".$locale->text('Allocated')."</th>";
  $column_header{sellprice} = "<th class=listheading>".$locale->text('Amount')."</th>";

  
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
	<tr>
	  <th colspan=2 align=left>
	    $employee
	  </th>
	  <th align=left>
	    $sameemployeenumber
	  </th>
        <tr class=listheading>
|;

  for (@column_index) { print "\n$column_header{$_}" }
  
  print qq|
        </tr>
|;

  # add sort and escape callback, this one we use for the add sub
  $form->{callback} = $callback .= "&sort=$form->{sort}";

  # escape callback for href
  $callback = $form->escape($callback);

  %total = ();
  
  foreach $ref (@{ $form->{transactions} }) {

    if ($form->{type} eq 'timecard') {
      if ($sameemployeenumber ne $ref->{employeenumber}) {
	$sameemployeenumber = $ref->{employeenumber};
	$sameweek = $ref->{workweek};

	if ($form->{l_subtotal}) {
	  print qq|
        <tr class=listsubtotal>
|;

	  for (@column_index) { $column_data{$_} = "<td>&nbsp;</td>" }

	  $weektotal = 0;
	  for (keys %weekday) {
	    $column_data{$_} = "<th class=listsubtotal align=right>".$form->format_amount(\%myconfig, $subtotal{$_}, undef, "&nbsp;")."</th>";
	    $weektotal += $subtotal{$_};
	    $subtotal{$_} = 0;
	  }
      
	  $column_data{$form->{sort}} = "<th class=listsubtotal align=right>".$form->format_amount(\%myconfig, $weektotal, undef, "&nbsp;")."</th>";
	
	  for (@column_index) { print "\n$column_data{$_}" }
	}

	# print total
	print qq|
        <tr class=listtotal>
|;

	for (@column_index) { $column_data{$_} = "<td>&nbsp;</td>" }

	$total = 0;
	for (keys %weekday) {
	  $column_data{$_} = "<th class=listtotal align=right>".$form->format_amount(\%myconfig, $total{$_}, undef, "&nbsp;")."</th>";
	  $total += $total{$_};
	  $total{$_} = 0;
	}
  
	$column_data{$form->{sort}} = "<th class=listtotal align=right>".$form->format_amount(\%myconfig, $total, undef, "&nbsp;")."</th>";
	
	for (@column_index) { print "\n$column_data{$_}" }

	print qq|
	<tr height=30 valign=bottom>
	  <th colspan=2 align=left>
	    $ref->{employee}
	  </th>
	  <th align=left>
	    $ref->{employeenumber}
	  </th>
        <tr class=listheading>
|;

	for (@column_index) { print "\n$column_header{$_}" }
  
	print qq|
        </tr>
|;

      }
    }

    if ($form->{l_subtotal}) {
      for (@column_index) { $column_data{$_} = "<td>&nbsp;</td>" }
      
      if ($form->{type} eq 'timecard') {
	if ($ref->{workweek} != $sameweek) {
	  $weektotal = 0;
	  for (keys %weekday) {
	    $column_data{$_} = "<th class=listsubtotal align=right>".$form->format_amount(\%myconfig, $subtotal{$_}, undef, "&nbsp;")."</th>";
	    $weektotal += $subtotal{$_};
	    $subtotal{$_} = 0
	  }
	  $column_data{$form->{sort}} = "<th class=listsubtotal align=right>".$form->format_amount(\%myconfig, $weektotal, undef, "&nbsp;")."</th>";
	  $sameweek = $ref->{workweek};
	  
	  print qq|
	  <tr class=listsubtotal>
|;
	  for (@column_index) { print "\n$column_data{$_}" }
	
	  print qq|
        </tr>
|;
	}

      } else {
	if ($sameitem ne $ref->{$form->{sort}}) {
	  $column_data{qty} = "<th class=listsubtotal align=right>".$form->format_amount(\%myconfig, $subtotal{qty}, undef, "&nbsp;")."</th>";
	  $column_data{sellprice} = "<th class=listsubtotal align=right>".$form->format_amount(\%myconfig, $subtotal{sellprice}, $form->{precision})."</th>";
	  
	  $sameitem = $ref->{$form->{sort}};
	  $subtotal{qty} = 0;
	  $subtotal{sellprice} = 0;

          print qq|
        <tr class=listsubtotal>
|;
	  for (@column_index) { print "\n$column_data{$_}" }
      
	  print qq|
        </tr>
|;
	}
      }
    }

    for (qw(description notes)) { $ref->{$_} =~ s/\n/<br>/g }
    
    for (@column_index) { $column_data{$_} = "<td>$ref->{$_}&nbsp;</td>" }
    
    for (keys %weekday) { $column_data{$_} = "<td>&nbsp;</td>" }
    
    $column_data{qty} = "<td align=right>".$form->format_amount(\%myconfig, $ref->{qty}, undef, "&nbsp;")."</td>";
    $column_data{allocated} = "<td align=right>".$form->format_amount(\%myconfig, $ref->{allocated}, undef, "&nbsp;")."</td>";
    $column_data{sellprice} = qq|<td align=right>|.$form->format_amount(\%myconfig,$ref->{qty} * $ref->{sellprice}, $form->{precision})."</td>";
    
    $column_data{$ref->{weekday}} = "<td align=right>";
    $column_data{$ref->{weekday}} .= $form->format_amount(\%myconfig, $ref->{qty}, undef, "&nbsp;") if $form->{l_qty};
    
    if ($form->{l_time}) {
      $column_data{$ref->{weekday}} .= "<br>" if $form->{l_qty};
      $column_data{$ref->{weekday}} .= "$ref->{checkedin}<br>$ref->{checkedout}";
    }
    $column_data{$ref->{weekday}} .= "</td>";
    
    $column_data{id} = "<td><a href=$form->{script}?action=edit&id=$ref->{id}&type=$ref->{type}&path=$form->{path}&login=$form->{login}&project=$ref->{project}&callback=$callback>$ref->{id}</a></td>";

    $subtotal{$ref->{weekday}} += $ref->{qty};
    $total{$ref->{weekday}} += $ref->{qty};

    $total{qty} += $ref->{qty};
    $total{sellprice} += $ref->{sellprice} * $ref->{qty};
    $subtotal{qty} += $ref->{qty};
    $subtotal{sellprice} += $ref->{sellprice} * $ref->{qty};

    $j++; $j %= 2;
    print qq|
        <tr class=listrow$j>
|;

    for (@column_index) { print "\n$column_data{$_}" }

    print qq|
        </tr>
|;
  }

  # print last subtotal
  if ($form->{l_subtotal}) {
    print qq|
        <tr class=listsubtotal>
|;

    for (@column_index) { $column_data{$_} = "<td>&nbsp;</td>" }

    if ($form->{type} eq 'timecard') {
      $weektotal = 0;
      for (keys %weekday) {
	$column_data{$_} = "<th class=listsubtotal align=right>".$form->format_amount(\%myconfig, $subtotal{$_}, undef, "&nbsp;")."</th>";
	$weektotal += $subtotal{$_};
      }
    
      $column_data{$form->{sort}} = "<th class=listsubtotal align=right>".$form->format_amount(\%myconfig, $weektotal, undef, "&nbsp;")."</th>";
	  
    } else {
      $column_data{qty} = "<th class=listsubtotal align=right>".$form->format_amount(\%myconfig, $subtotal{qty}, undef, "&nbsp;")."</th>";
      $column_data{sellprice} = "<th class=listsubtotal align=right>".$form->format_amount(\%myconfig, $subtotal{sellprice}, $form->{precision})."</th>";
    }

    for (@column_index) { print "\n$column_data{$_}" }
  }

  # print last total
  print qq|
        <tr class=listtotal>
|;

  for (@column_index) { $column_data{$_} = "<td>&nbsp;</td>" }

  if ($form->{type} eq 'timecard') {
    $total = 0;
    for (keys %weekday) {
      $column_data{$_} = "<th class=listtotal align=right>".$form->format_amount(\%myconfig, $total{$_}, undef, "&nbsp;")."</th>";
      $total += $total{$_};
      $total{$_} = 0;
    }
    
    $column_data{$form->{sort}} = "<th class=listtotal align=right>".$form->format_amount(\%myconfig, $total, undef, "&nbsp;")."</th>";
    
  } else {

    $column_data{qty} = "<th class=listtotal align=right>".$form->format_amount(\%myconfig, $total{qty}, undef, "&nbsp;")."</th>";
    $column_data{sellprice} = "<th class=listtotal align=right>".$form->format_amount(\%myconfig, $total{sellprice}, $form->{precision})."</th>";

  }

  for (@column_index) { print "\n$column_data{$_}" }
  
  if ($form->{project} eq 'job') {
    if ($form->{type} eq 'timecard') {
      if ($myconfig{acs} !~ /Production--Add Time Card/) {
	$i = 1;
	$button{'Production--Add Time Card'}{code} = qq|<input class=submit type=submit name=action value="|.$locale->text('Add Time Card').qq|"> |;
	$button{'Production--Add Time Card'}{order} = $i++;
      }
    } elsif ($form->{type} eq 'storescard') {
      if ($myconfig{acs} !~ /Production--Add Stores Card/) {
	$i = 1;
	$button{'Production--Add Stores Card'}{code} = qq|<input class=submit type=submit name=action value="|.$locale->text('Add Stores Card').qq|"> |;
	$button{'Production--Add Stores Card'}{order} = $i++;
      }
    } else {
      $i = 1;
      if ($myconfig{acs} !~ /Production--Add Time Card/) {
	$button{'Production--Add Time Card'}{code} = qq|<input class=submit type=submit name=action value="|.$locale->text('Add Time Card').qq|"> |;
	$button{'Production--Add Time Card'}{order} = $i++;
      }
      
      if ($myconfig{acs} !~ /Production--Add Stores Card/) {
	$button{'Production--Add Stores Card'}{code} = qq|<input class=submit type=submit name=action value="|.$locale->text('Add Stores Card').qq|"> |;
	$button{'Production--Add Stores Card'}{order} = $i++;
      }
    }
  } elsif ($form->{project} eq 'project') {
    if ($myconfig{acs} !~ /Projects--Projects/) {
      $i = 1;
      $button{'Projects--Add Time Card'}{code} = qq|<input class=submit type=submit name=action value="|.$locale->text('Add Time Card').qq|"> |;
      $button{'Projects--Add Time Card'}{order} = $i++;
    }
  } else {
    if ($myconfig{acs} !~ /Time Cards--Time Cards/) {
      $i = 1;
      $button{'Time Cards--Add Time Card'}{code} = qq|<input class=submit type=submit name=action value="|.$locale->text('Add Time Card').qq|"> |;
      $button{'Time Cards--Add Time Card'}{order} = $i++;
    }
  }

  for (split /;/, $myconfig{acs}) { delete $button{$_} }

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

  $form->hide_form(qw(callback path login project));

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


sub continue { &{ $form->{nextsub} } };

sub add_time_card {

  $form->{type} = "timecard";
  &add;

}


sub add_stores_card {

  $form->{type} = "storescard";
  &add;

}


sub print_options {

  if ($form->{selectlanguage}) {
    $lang = qq|<select name=language_code>|.$form->select_option($form->{selectlanguage}, $form->{language_code}, undef, 1).qq|</select>|;
  }
  
  $type = qq|<select name=formname>|.$form->select_option($form->{selectformname}, $form->{formname}, undef, 1).qq|</select>|;

  $media = qq|<select name=media>
          <option value="screen">|.$locale->text('Screen');

  $form->{selectformat} = qq|<option value="html">html\n|;
  
  if (%printer && $latex) {
    for (sort keys %printer) { $media .= qq| 
          <option value="$_">$_| }
  }

  if ($latex) {
    $media .= qq|
          <option value="queue">|.$locale->text('Queue');
	  
    $form->{selectformat} .= qq|
	    <option value="pdf">|.$locale->text('PDF');
  }

  $format = qq|<select name=format>$form->{selectformat}</select>|;
  $format =~ s/(<option value="\Q$form->{format}\E")/$1 selected/;
  $format .= qq|
  <input type=hidden name=selectformat value="|.$form->escape($form->{selectformat},1).qq|">|;
  $media .= qq|</select>|;
  $media =~ s/(<option value="\Q$form->{media}\E")/$1 selected/;

  print qq|
  <table width=100%>
    <tr>
      <td>$type</td>
      <td>$lang</td>
      <td>$format</td>
      <td>$media</td>
      <td align=right width=90%>
  |;

  if ($form->{printed} =~ /$form->{formname}/) {
    print $locale->text('Printed').qq|<br>|;
  }

  if ($form->{queued} =~ /$form->{formname}/) {
    print $locale->text('Queued');
  }

  print qq|
      </td>
    </tr>
  </table>
|;

}


sub print {

  if ($form->{media} !~ /screen/) {
    $form->error($locale->text('Select postscript or PDF!')) if $form->{format} !~ /(postscript|pdf)/;
    $old_form = new Form;
    for (keys %$form) { $old_form->{$_} = $form->{$_} }
  }

  &print_form($old_form);

}


sub print_form {
  my ($old_form) = @_;
  
  $display_form = ($form->{display_form}) ? $form->{display_form} : "update";

  $form->{description} =~ s/^\s+//g;
  $form->{projectnumber} =~ s/--.*//;

  if ($form->{type} eq 'timecard') {
    @a = qw(hour min sec);
    foreach $item (qw(in out)) {
      for (@a) { $form->{"$item$_"} = substr(qq|00$form->{"$item$_"}|, -2) }
      $form->{"checked$item"} = qq|$form->{"${item}hour"}:$form->{"${item}min"}:$form->{"${item}sec"}|;
    }
  }
  
  JC->company_defaults(\%myconfig, \%$form);
  
  @a = ();
  push @a, qw(partnumber description projectnumber projectdescription);
  push @a, qw(companyemail companywebsite company address tel fax businessnumber username useremail);
  
  $form->format_string(@a);

  $form->{total} = $form->format_amount(\%myconfig, $form->parse_amount(\%myconfig, $form->{qty}) * $form->parse_amount(\%myconfig, $form->{sellprice}), $form->{precision});

  
  ($form->{employee}, $form->{employee_id}) = split /--/, $form->{employee};

  $form->{templates} = "$myconfig{templates}";
  $form->{IN} = "$form->{formname}.html";

  if ($form->{format} =~ /(postscript|pdf)/) {
    $form->{IN} =~ s/html$/tex/;
  }

  if ($form->{media} !~ /(screen|queue)/) {
    $form->{OUT} = "| $printer{$form->{media}}";

    if ($form->{printed} !~ /$form->{formname}/) {
      $form->{printed} .= " $form->{formname}";
      $form->{printed} =~ s/^ //;

      $form->update_status(\%myconfig);
    }

    %audittrail = ( tablename   => jcitems,
                    reference   => $form->{id},
		    formname    => $form->{formname},
		    action      => 'printed',
		    id          => $form->{id} );

    %status = ();
    for (qw(printed queued audittrail)) { $status{$_} = $form->{$_} }

    $status{audittrail} .= $form->audittrail("", \%myconfig, \%audittrail);

  }

  if ($form->{media} eq 'queue') {
    %queued = split / /, $form->{queued};

    if ($filename = $queued{$form->{formname}}) {
      $form->{queued} =~ s/$form->{formname} $filename//;
      unlink "$spool/$filename";
      $filename =~ s/\..*$//g;
    } else {
      $filename = time;
      $filename .= int rand 10000;
    }

    $filename .= ($form->{format} eq 'postscript') ? '.ps' : '.pdf';
    $form->{OUT} = ">$spool/$filename";
    
    $form->{queued} = "$form->{formname} $filename";
    $form->update_status(\%myconfig);

    %audittrail = ( tablename   => jcitems,
                    reference   => $form->{id},
		    formname    => $form->{formname},
		    action      => 'queued',
		    id          => $form->{id} );

    %status = ();
    for (qw(printed queued audittrail)) { $status{$_} = $form->{$_} }

    $status{audittrail} .= $form->audittrail("", \%myconfig, \%audittrail);
  }

  $form->parse_template(\%myconfig, $userspath, $debuglatex);

  if ($old_form) {

    for (keys %$old_form) { $form->{$_} = $old_form->{$_} }
    for (qw(printed queued audittrail)) { $form->{$_} = $status{$_} }
    
    &{ "$display_form" };
    
  }
  
}


sub select_item {

  @column_index = qw(ndx partnumber description sellprice);

  $column_data{ndx} = qq|<th class=listheading width=1%>&nbsp;</th>|;
  $column_data{partnumber} = qq|<th class=listheading>|.$locale->text('Number').qq|</th>|;
  $column_data{description} = qq|<th class=listheading>|.$locale->text('Description').qq|</th>|;
  $column_data{sellprice} = qq|<th class=listheading>|;
  $column_data{sellprice} .= ($form->{project} eq 'project') ? $locale->text('Sell Price') : $locale->text('Cost');
  $column_data{sellprice} .= qq|</th>|;
  
  # list items with radio button on a form
  $form->header;

  $title = $locale->text('Select items');

  print qq|
<body>

<form method=post action="$form->{script}">

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
        <tr class=listheading>|;

  for (@column_index) { print "\n$column_data{$_}" }
  
  print qq|
        </tr>
|;

  my $i = 0;
  foreach $ref (@{ $form->{item_list} }) {
    $i++;

    for (qw(partnumber description)) { $ref->{$_} = $form->quote($ref->{$_}) }

    $column_data{ndx} = qq|<td><input name="ndx" class=radio type=radio value=$i></td>|;
    
    for (qw(partnumber description)) { $column_data{$_} = qq|<td>$ref->{$_}&nbsp;</td>| }
    
    $column_data{sellprice} = qq|<td align=right>|.$form->format_amount(\%myconfig, $ref->{sellprice}, $form->{precision}, "&nbsp;").qq|</td>|;
    
    $j++; $j %= 2;
    print qq|
        <tr class=listrow$j>|;

    for (@column_index) { print "\n$column_data{$_}" }

    print qq|
        </tr>
|;

    for (qw(partnumber description sellprice pricematrix parts_id)) {
      print qq|<input type=hidden name="new_${_}_$i" value="|.$form->quote($ref->{$_}).qq|">\n|;
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

<input name=lastndx type=hidden value=$i>

|;

  # delete variables
  for (qw(nextsub item_list)) { delete $form->{$_} }

  $form->{action} = "item_selected";
  
  $form->hide_form;
  
  print qq|
<input type=hidden name=nextsub value=item_selected>

<br>
<input class=submit type=submit name=action value="|.$locale->text('Continue').qq|">
</form>

</body>
</html>
|;

}



sub item_selected {

  for (qw(partnumber description sellprice pricematrix parts_id)) {
    $form->{$_} = $form->{"new_${_}_$form->{ndx}"};
  }

  ($dec) = ($form->{sellprice} =~ /\.(\d+)/);
  $dec = length $dec;
  $decimalplaces = ($dec > $form->{precision}) ? $dec : $form->{precision};
  
  # format amounts
  $form->{sellprice} = $form->format_amount(\%myconfig, $form->{sellprice}, $decimalplaces);
  for (qw(partnumber transdate project_id)) { $form->{"old$_"} = $form->{$_} }

  &update;

}


sub new_item {

  # change callback
  $form->{old_callback} = $form->escape($form->{callback},1);
  $form->{callback} = $form->escape("$form->{script}?action=update",1);

  # delete action
  delete $form->{action};

  # save all other form variables in a previousform variable
  foreach $key (keys %$form) {
    # escape ampersands
    $form->{$key} =~ s/&/%26/g;
    $form->{previousform} .= qq|$key=$form->{$key}&|;
  }
  chop $form->{previousform};

  $form->{callback} = qq|ic.pl?action=add|;
  
  for (qw(path login)) { $form->{callback} .= qq|&$_=$form->{$_}| }
  for (qw(partnumber description previousform)) { $form->{callback} .= qq|&$_=|.$form->escape($form->{$_},1) }
  
  if ($form->{type} eq 'timecard') {
    if ($form->{project} eq 'project') {
      $form->error($locale->text('You are not authorized to add a new item!')) if $myconfig{acs} =~ /Goods \& Services--Add Service/;
      $form->{callback} .= qq|&item=service|;
    } else {
      $form->error($locale->text('You are not authorized to add a new item!')) if $myconfig{acs} =~ /Goods \& Services--Add Labor\/Overhead/;
      $form->{callback} .= qq|&item=labor|;
    }
  } else {
    $form->error($locale->text('You are not authorized to add a new item!')) if $myconfig{acs} =~ /Goods \& Services--Add Part/;
    $form->{callback} .= qq|&item=part|;
  }

  $form->redirect;

}


sub islocked {

  print "<p><font color=red>".$locale->text('Locked by').": $form->{haslock}</font>" if $form->{haslock};

}

