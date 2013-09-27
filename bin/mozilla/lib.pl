
1;

###############################
sub print_period {
  $form->all_years(\%myconfig);
  if (@{ $form->{all_years} }) {
    # accounting years
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
  print $selectfrom;
}

###############################
sub bld_department {
    my ($selectname, $override) = @_;
    $selectname = 'selectdepartment' if !$selectname;

    $query = qq|SELECT id, description FROM department ORDER BY description|;
    $dbh = $form->dbconnect(\%myconfig);
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror;

    $form->{"$selectname"} = "";
    if ($myconfig{department_id} and !$override){
	$form->{"$selectname"} .= qq|<option value="$myconfig{department}--$myconfig{department_id}">$myconfig{department}\n|;
    } else {
    	$form->{"$selectname"} = "<option>\n";
    	while (my $ref = $sth->fetchrow_hashref(NAME_lc)){
	    $form->{"$selectname"} .= qq|<option value="$ref->{description}--$ref->{id}">$ref->{description}\n|;
    	}
    }
}


###############################
sub bld_warehouse {
    my $selectname = shift;
    $selectname = 'selectwarehouse' if !$selectname;

    my $where = "1 = 1";
    $query = qq|SELECT id, description FROM warehouse WHERE $where ORDER BY description|;
    $dbh = $form->dbconnect(\%myconfig);
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    $form->{"$selectname"} = "<option>\n";
    while (my $ref = $sth->fetchrow_hashref(NAME_lc)){
	$form->{"$selectname"} .= qq|<option value="$ref->{description}--$ref->{id}">$ref->{description}\n|;
    }
}


###############################
sub bld_partsgroup {
    $query = qq|SELECT id, partsgroup FROM partsgroup ORDER BY partsgroup|;
    $dbh = $form->dbconnect(\%myconfig);
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror;

    $form->{selectpartsgroup} = "<option>\n";
    while (my $ref = $sth->fetchrow_hashref(NAME_lc)){
	$form->{selectpartsgroup} .= qq|<option value="$ref->{partsgroup}--$ref->{id}">$ref->{partsgroup}\n|;
    }
}

###############################
sub print_select {
    my ($fldname, $fldprompt) = @_;
    print qq|<tr><th align=right>$fldprompt</th>\n|;
    print qq|<td><select name=$fldname>$form->{"select$fldname"}</select></td></tr>\n|;
}

###############################
sub print_radio {
   print qq|
	<input name=summary type=radio class=radio value=1 checked> |.$locale->text('Summary').qq|
	<input name=summary type=radio class=radio value=0> |.$locale->text('Detail').qq|<br>
   |;
}

###############################
sub bld_employee {
    my ($fldname) = @_;
    $fldname = 'employee' if !$fldname;
    $query = qq|SELECT id, name FROM employee ORDER BY name|;
    $dbh = $form->dbconnect(\%myconfig);
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror;

    $form->{"select$fldname"} = "<option>\n";
    while (my $ref = $sth->fetchrow_hashref(NAME_lc)){
	$form->{"select$fldname"} .= qq|<option value="$ref->{name}--$ref->{id}">$ref->{name}\n|;
    }
}


###############################
sub bld_chart {
    my ($type, $selectname) = @_;
    my $where;

    if ($type eq 'ALL'){
        $where = "";
    } elsif ($type eq 'CASH') {
	$where = qq| AND link LIKE '%_paid%'|;
    } elsif ($type eq 'AR') {
	$where = qq| AND link = 'AR'|;
    } elsif ($type eq 'AP') {
	$where = qq| AND link = 'AP'|;
    } elsif ($type eq 'EXPENSE') {
	$where = qq| AND link LIKE '%IC_expense%'|;
    }

    $query = qq|SELECT id, accno, description 
		FROM chart 
		WHERE charttype = 'A' $where
		ORDER BY accno|;

    $dbh = $form->dbconnect(\%myconfig);
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror;

    $form->{"$selectname"} = "<option>\n";
    while (my $ref = $sth->fetchrow_hashref(NAME_lc)){
	$form->{"$selectname"} .= qq|<option value="$ref->{accno}--$ref->{id}">$ref->{accno}--$ref->{description}\n|;
    }
}

###############################
sub bld_combo {
    my ($values, $blank, $default) = @_;
    my @combovals = split(/,/, $values);
    my $combo, $i;
    $combo = qq|<option>| if $blank;
    for (@combovals) {
        my ($val1, $val2) = split(/:/, $_); 
	$combo .= qq|<option value "$val2--$val1">$val2\n|;
	$i++;
    }
    $combo =~ s/--$default>/--$default selected>/;
}

###############################
sub split_combos {
   $combos_list = shift;
   @combos = split /,/, $combos_list;
   for (@combos){
      $fldname = $_ . "_name";
      $fldid = $_ . "_id"; 
      ($form->{"$fldname"}, $form->{"$fldid"}) = split(/--/, $form->{"$_"});
   }
}

###############################
sub print_criteria {
   my ($fldname, $fldprompt) = @_;
   print qq|$fldprompt : $form->{"$fldname"}<br>\n| if $form->{"$fldname"};
}

###############################
sub print_date {
    my ($fldname, $fldprompt, $defaultvalue) = @_;
    print qq|<tr><th align=right>$fldprompt</th><td><input type=text name=$fldname 
		size=11 title='$myconfig{dateformat}' value='$defaultvalue' class="date"></td></tr>\n|;
}

###############################
sub print_text {
    my ($fldname, $fldprompt, $size, $defaultvalue) = @_;
    print qq|<tr><th align=right>$fldprompt</th><td><input type=text name=$fldname 
	size=$size value="$defaultvalue"></td></tr>\n|;
}

###############################
sub print_plain {
    my ($fldvalue, $fldprompt) = @_;
    print qq|<tr><th align=right>$fldprompt</th><td>$fldvalue</td></tr>\n|;
}

###############################
sub print_checkbox {
    my ($fldname, $fldprompt, $checked, $extratag) = @_;
    print qq|<input name=$fldname class=checkbox type=checkbox value=Y $checked> $fldprompt\n|;
    print qq|$extratag| if $extratag;
}

###############################
sub report_checkbox {
    my ($fldname, $fldprompt, $checked) = @_;
    print qq|<td>|;
    print qq|<input name=$fldname class=checkbox type=checkbox value=Y $checked> $fldprompt\n|;
    print qq|</td>|;
}

###############################
sub print_readonly {
    my ($fldname, $fldprompt, $size, $defaultvalue) = @_;
    print qq|<tr><th align=right>$fldprompt</th><td><input type=text name=$fldname 
	size=$size value="$defaultvalue" READONLY></td></tr>\n|;
}

###############################
sub print_hidden {
    my ($fldname) = @_;
    print qq|<input type=hidden name=$fldname value="$form->{$fldname}">\n|;
}

###############################
sub print_title {
    $form->header;
    print qq|<body><table width=100%><tr><th class=listtop>$form->{title}</th></tr></table>\n|;
}

###############################
sub start_form {
  my $script = shift;
  $script = $form->{script} if !$script;
  print qq|<form method=post action=$script>\n|;
}

###############################
sub add_button {
  my $action = shift;
  print qq|<input type=submit class=submit name=action value="$action">\n|;
}

###############################
sub end_form {
  for (qw(nextsub path login callback)){
    if ($form->{$_}) {
      print qq|<input type=hidden name=$_ value="$form->{$_}">\n|;
    }
  }
  print qq|</form></body></html>\n|;
}

###############################
sub start_table {
   print qq|<table width=100%>\n|;
}

###############################
sub start_heading_row {
   print qq|<tr class=listheading>|;
}

###############################
sub end_row {
   print qq|</tr>\n|;
}

###############################
sub end_table {
   print qq|</table>\n|;
}

###############################
# format header column
sub rpt_hdr {
  my $column_name = shift;
  my $column_heading = shift;
  my $href = shift;
  my $str;
  if ($href){
     $str = qq|<th><a class=listheading href=$href&sort=$column_name>$column_heading</a></th>|;
  } else {
     $str = qq|<th class=listheading>$column_heading</th>|;
  }
  $str;
}

###############################
# format simple header column
sub tbl_hdr {
  my $column_heading = shift;
  my $str;
  $str = qq|<th>$column_heading</th>|;
  $str;
}


###############################
# format text column
sub rpt_txt {
  my $column_data = shift;
  my $link = shift;
  my $str;
  if ($link) {
     $str = qq|<td><a href="$link">$column_data</a></td>|;
  } else {
     $str = qq|<td>$column_data</td>|;
  }
  $str;
}

###############################
# format URL
sub rpt_url {
  my $column_data = shift;
  my $link = $uploadurl . $myconfig{dbname} . "/" . $column_data;
  my $str = qq|<td><a href="$link">$column_data<a></td|;
  $str;
}

###############################
# format integer column
sub rpt_int {
  my $column_data = shift;
  my $str = qq|<td align=right>$column_data</td>|;
  $str;
}

###############################
# format decimal column
sub rpt_dec {
  my ($column_data, $precision, $dash) = @_;
  $precision = $form->{precision} if !($precision);
  my $str = qq|<td align=right>| . $form->format_amount(\%myconfig, $column_data, $precision, $dash) . qq|</td>|;
  $str;
}

###############################
# format decimal column
sub rpt_print_date {
  my ($fldname, $defaultvalue) = @_;
  my $str = qq|<td><input type=text name=$fldname size=11 title='$myconfig{dateformat}' value='$defaultvalue' class="date"></td>\n|;
  $str;  
}

###############################
sub list_parts {

   $partnumber = $form->like(lc $form->{partnumber});
   my $where = qq| LOWER(partnumber) LIKE '$partnumber'|;
   my $dbh = $form->dbconnect(\%myconfig);

   $query = qq|SELECT COUNT(*) FROM parts WHERE $where|;
   my ($rows) = $dbh->selectrow_array($query);
   $form->error("No such partnumber") if ($rows == 0);

   $query = qq|SELECT id, partnumber, 
		description, 
		0 AS onhand, 
		unit,
		lastcost
	      FROM parts WHERE $where ORDER BY partnumber|;

   my $j = $form->{rowcount};
   if ($rows == 1){
	($form->{"parts_id_$j"}, $form->{"partnumber_$j"},
	$form->{"description_$j"}, $form->{"onhand_$j"}, 
	$form->{"unit_$j"}, $form->{"cost_$j"}) 
		= $dbh->selectrow_array($query);
	$form->{"qty_$j"} = 1 if !$form->{"qty_$j"};
	$form->{rowcount} += 1;
	&display_trf_form;
	exit;
   }

   $sth = $dbh->prepare($query) || $form->dberror($query);
   $sth->execute || $form->dberror($query);
 
   $form->{title} = $locale->text('Select Part Number');
   print_title;

   start_form;
   $form->hide_form;
   print qq|<table width=100%>|;
   print qq|<tr class=listheading>\n|;
   print qq|<th>&nbsp;</th>|;
   print qq|<th>|.$locale->text('Number').qq|</th>|;
   print qq|<th>|.$locale->text('Description').qq|</th>|;
   print qq|<th>|.$locale->text('Onhand').qq|</th>|;
   print qq|<th>|.$locale->text('Unit').qq|</th>|;
   print qq|</tr>|;

   my $i = 1;
   my $j = 1;
   $checked = 'checked';
   while (my $ref = $sth->fetchrow_hashref(NAME_lc)){
      print qq|<tr class=listrow$i>|;
      print qq|<td><input name=ndx class=radio type=radio value=$j $checked></td>\n|;
      print qq|<td>$ref->{partnumber}</td>|;
      print qq|<td>$ref->{description}</td>|;
      print qq|<td>$ref->{onhand}</td>|;
      print qq|<td>$ref->{unit}</td>|;
      print qq|</tr>\n|;
      print qq|<input name="new_id_$j" type=hidden value="$ref->{id}">\n|;
      $i++; $i %= 2;
      $j++;
      $checked = ''; # only first line is checked.
   }
   print qq|</table>\n|;
   print("<hr size=3 noshade>\n");
   add_button('Continue');
   $form->{nextsub} = 'select_part';
   end_form;
}

#////////////////////////////////////////////////////
##
## post_acc_trans
##
sub post_acc_trans {
   my ($acc_trans, $dbh) = @_;
   my $query;
   $query = qq|INSERT INTO acc_trans(
		trans_id,
		transdate,
		source,
		chart_id,
		amount,
		project_id,
		parent_trans_id)
	VALUES (
		$acc_trans->{trans_id},
		'$acc_trans->{transdate}',
		'$acc_trans->{source}',
		$acc_trans->{chart_id},
		$acc_trans->{amount},
		$acc_trans->{project_id},
		$acc_trans->{parent_trans_id}
	)|;
   $dbh->do($query) || $form->dberror($query);
}

#---------------------------
sub post_doc {
  my ($doc, $dbh) = @_;
  $doc->{trans_id} *= 1;
  if ($doc->{id}){
	$query = qq|
		UPDATE doc SET 
			department_id = $doc->{department_id},
			trans_id = $doc->{trans_id},
			reference = '$doc->{reference}',
			description = '$doc->{description}',
			filename = '$doc->{filename}',
			filetype = '$doc->{filetype}',
			imagetype = '$doc->{imagetype}',
			closed = '$doc->{closed}'
		WHERE id = $doc->{id}|;
  } else {
	$query = qq|
		INSERT INTO doc (department_id, trans_id, description, 
			filename, filetype, imagetype,
			reference, closed)
		VALUES ($doc->{department_id}, $doc->{trans_id}, '$doc->{description}',
			'$doc->{filename}', '$doc->{filetype}', '$doc->{imagetype}',
			'$doc->{reference}', '$doc->{closed}')|;
  }
  $dbh->do($query) || $form->dberror($query);
}

#---------------------------
sub post_earnest {
  my ($earnest, $dbh) = @_;

  my $uid = time;
  $uid .= $form->{login};

  my $id = $earnest->{id};
  if (!$id){
	# if no existing transaction, create new row
	$query = qq|INSERT INTO earnest (reference) VALUES ('$uid')|; 
	$dbh->do($query) || $form->dberror($query);
	$query = qq|SELECT id FROM earnest WHERE reference='$uid'|;
	$id = $dbh->selectrow_array($query);
  }
  # TODO: Find some better way
  $form->{id} = $id;

  $query = qq|UPDATE earnest SET
		reference 	= '$earnest->{reference}',
		transdate 	= '$earnest->{transdate}',
		duedate 	= | . $form->dbquote($earnest->{duedate}, 'SQL_DATE') . qq|,
		department_id 	= $earnest->{department_id},
		customer_id 	= $earnest->{customer_id},
		cash_accno_id 	= $earnest->{cash_accno_id},
		ar_accno_id 	= $earnest->{ar_accno_id},
		employee_id 	= $earnest->{employee_id},
		source 		= '$earnest->{source}',
		description 	= '$earnest->{description}',
		amount 		= $earnest->{amount},
		closed 		= '$earnest->{closed}',
		close_date 	= | . $form->dbquote($earnest->{close_date}, 'SQL_DATE') . qq|
	WHERE id = $id|;
  $dbh->do($query) || $form->dberror($query);
}

###
### post_gl
###
sub post_gl {
  my ($gl, $dbh) = @_;
  my $gl_id;

  my $uid = time;
  $uid .= $form->{login};

  $query = qq|SELECT id FROM gl 
		WHERE parent_trans_id = $gl->{parent_trans_id}
		AND parent_trans_type = '$gl->{parent_trans_type}'|;
  $gl_id = $dbh->do($query) || $form->dberror($query);

  if (!$gl_id){
	# if no existing GL transaction, create new row
	$query = qq|INSERT INTO gl (reference) VALUES ('$uid')|; 
	$dbh->do($query) || $form->dberror($query);
	$query = qq|SELECT id FROM gl WHERE reference='$uid'|;
	$gl_id = $dbh->selectrow_array($query);
  }

  # TODO: Find to better way to pass back the value
  $form->{gl_id} = $gl_id;

  $query = qq|UPDATE gl SET 
		reference = '$gl->{reference}',
		description = '$gl->{description}',
		transdate = '$gl->{transdate}',
		employee_id = $gl->{employee_id},
		notes = '$gl->{notes}',
		department_id = $gl->{department_id},
		parent_trans_id = $form->{id},
		parent_trans_type = '$form->{parent_trans_type}'
	WHERE id = $gl_id|;
  $dbh->do($query) || $form->dberror($query);
}

###
### post_inventory
###
sub post_inventory {
   my ($inventory, $dbh) = @_;
   my $query;
   $query = qq|INSERT INTO inventory(
		trans_id,
		shippingdate,
		department_id,
		warehouse_id,
		warehouse_id2,
		parts_id,
		description,
		itemnotes,
		serialnumber,
		qty,
		cost,
		employee_id,
		linetype)
	VALUES (
		$inventory->{trans_id},
		'$inventory->{transdate}',
		$inventory->{department_id},
		$inventory->{warehouse_id},
		$inventory->{warehouse_id2},
		$inventory->{parts_id},
		$inventory->{description},
		$inventory->{itemnotes},
		$inventory->{serialnumber},
		$inventory->{qty},
		$inventory->{cost},
		$inventory->{employee_id},
		$inventory->{linetype}
	)|;
   $dbh->do($query) || $form->dberror($query);
}

###
### post_trf
###
sub post_trf {
  my ($trf, $dbh) = @_;

  my $uid = time;
  $uid .= $form->{login};

  my $trf_id = $trf->{id};
  if (!$trf_id){
	$query = qq|INSERT INTO trf (trfnumber) VALUES ('$uid')|; 
	$dbh->do($query) || $form->dberror($query);
	$query = qq|SELECT id FROM trf WHERE trfnumber='$uid'|;
	$trf_id = $dbh->selectrow_array($query);
  }

  # TODO: Find to better way to pass back the value
  $form->{trf_id} = $trf_id;

  $query = qq|UPDATE trf SET
		trfnumber = '$trf->{trfnumber}',
		transdate = '$trf->{transdate}',
		description = '$trf->{description}',
		notes = '$trf->{notes}',
		department_id = $trf->{department_id},
		from_warehouse_id = $trf->{from_warehouse_id},
		to_warehouse_id = $trf->{to_warehouse_id},
		employee_id = $trf->{employee_id}
	WHERE id = $trf_id|;
  $dbh->do($query) || $form->dberror($query);
}

#########
### END
#########
