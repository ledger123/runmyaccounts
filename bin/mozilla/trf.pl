
use SL::AA;
use SL::Trf;

require "$form->{path}/arap.pl";
require "$form->{path}/mylib.pl";
require "$form->{path}/lib.pl";
require "$form->{path}/io.pl";

1;

#===============================
sub continue { &{$form->{nextsub}} };

sub display_trf_form {
  &form_header;
  &form_footer;
}

sub form_header {
   &print_title;
   &start_form($form->{script});
   &start_table;

   # unescape all select lists and select the correct value
   $form->{selectdepartment} = $form->unescape($form->{selectdepartment});
   $form->{selectexpense_accno} = $form->unescape($form->{selectexpense_accno});
   $form->{selectfrom_warehouse} = $form->unescape($form->{selectfrom_warehouse});
   $form->{selectto_warehouse} = $form->unescape($form->{selectto_warehouse});
   $form->{selectpartsgroup} = $form->unescape($form->{selectpartsgroup});

   if ($form->{department_id}){
      $form->{"selectdepartment"} =~ s/ selected//;
      $form->{"selectdepartment"} =~ s/(\Q--$form->{department_id}"\E)/$1 selected/;
   }

   if ($form->{from_warehouse_id}){
      $form->{"selectfrom_warehouse"} =~ s/ selected//;
      $form->{"selectfrom_warehouse"} =~ s/(\Q--$form->{from_warehouse_id}"\E)/$1 selected/;
   }

   if ($form->{to_warehouse_id}){
      $form->{"selectto_warehouse"} =~ s/ selected//;
      $form->{"selectto_warehouse"} =~ s/(\Q--$form->{to_warehouse_id}"\E)/$1 selected/;
   }

   # create hidden variables
   &print_hidden('title');
   &print_hidden('id');

   # Left column
   print qq|<tr><td valign=top><table>|;
   &print_text('trfnumber', $locale->text('Transfer Number'), 10, "$form->{trfnumber}");
   &print_date('transdate', $locale->text('Date'), "$form->{transdate}");
   &print_select('from_warehouse', $locale->text('From Warehouse'));
   &print_select('to_warehouse', $locale->text('To Warehouse'));

   # Right column
   print qq|</table></td><td valign=top><table>|;
   &print_select('department', $locale->text('Department'));
   &print_text('description', $locale->text('Description'), 30, "$form->{description}");
   &print_text('notes', $locale->text('Notes'), 30, "$form->{notes}");

   print qq|</table></td></tr>|;
   &end_table;

   &start_table;
   &start_heading_row;
   print &tbl_hdr($locale->text('No.'));
   print &tbl_hdr($locale->text('Number'));
   print &tbl_hdr('');
   print &tbl_hdr($locale->text('Description'));
   print &tbl_hdr($locale->text('Qty'));
   print &tbl_hdr($locale->text('Unit'));
   print &tbl_hdr($locale->text('Cost'));
   print &tbl_hdr($locale->text('Extended'));
   &end_row;

   $itemdetailok = ($myconfig{acs} =~ /Goods \& Services--Add /) ? 0 : 1;

   my $j = 1;
   my $total = 0;
   $form->{rowcount}++;
   for $i (1 .. $form->{rowcount}){
	$form->{"partnumber_$i"} = "" if !$form->{"parts_id_$i"};
	if (($form->{"partnumber_$i"} eq "") and ($i != $form->{rowcount})) {
	   # Get rid of lines with blank partnumber
	} else {
    	   $itemdetail = "<td></td>";
      	   if ($itemdetailok) {
		$itemdetail = qq|<td><a href="ic.pl?login=$form->{login}&path=$form->{path}&action=edit&id=$form->{"parts_id_$i"}" target=_blank>?</a></td>|;
      	   }
	   $total += $form->{"cost_$i"}*$form->{"qty_$i"};
	   print qq|<tr>|;
	   print qq|<td><input name="no_$j" type=text size=3 value=$j></td>\n|;
	   print qq|<input type=hidden name="parts_id_$j" value="$form->{"parts_id_$i"}"></td>\n|;
	   print qq|<input type=hidden name="weight_$j" value="$form->{"weight_$i"}"></td>\n|;
	   print qq|<td><input name="partnumber_$j" type=text size=15 value="$form->{"partnumber_$i"}"></td>\n|;
	   print $itemdetail;
	   print qq|<td><input name="description_$j" type=text size=48 value="$form->{"description_$i"}"></td>\n|;
	   print qq|<td><input name="qty_$j" type=text size=5 value="$form->{"qty_$i"}"></td>\n|;
	   print qq|<td><input name="unit_$j" type=text size=5 value="$form->{"unit_$i"}"></td>\n|;
	   print qq|<td><input name="cost_$j" type=text size=5 value="$form->{"cost_$i"}"></td>\n|;
	   print qq|<td align=right>| . $form->format_amount(\%myconfig, $form->{"cost_$i"}*$form->{"qty_$i"}, 2) . qq|</td>\n|;
	   print qq|</tr>\n|;

	   print qq|<tr>|;
	   print qq|<td colspan=3>|;
	   print qq|<select name=partsgroup_$j>| . $form->select_option($form->{selectpartsgroup}, '', 1) . qq|</select>| if !$form->{"partnumber_$i"};
	   print qq|</td>|;

	   print qq|<td><input name="itemnotes_$j" type=text size=48 value='$form->{"itemnotes_$i"}' title='Notes'</td>\n|;
	   print qq|<td colspan=4><input name="serialnumber_$j" value='$form->{"serialnumber_$i"}' title='Serial No.'</td>\n|;
	   print qq|</tr>\n|;

	   print qq|<tr><td colspan=8><hr></td></tr>\n|;
	   $j++;
	}
   }
   print qq|<tr><td colspan=6></td><th>Total</th><th align=right>| . $form->format_amount(\%myconfig, $total, 2) . qq|</th></tr>|;
   &end_table;
   $j--;
   $form->{rowcount} = $j;

   # Now save select lists as hidden variables after escaping them
   $form->{selectdepartment} 		= $form->escape($form->{selectdepartment},1);
   $form->{selectfrom_warehouse} 	= $form->escape($form->{selectfrom_warehouse},1);
   $form->{selectto_warehouse} 		= $form->escape($form->{selectto_warehouse},1);
   $form->{selectpartsgroup} 		= $form->escape($form->{selectpartsgroup},1);


   print('<hr size=3 noshade>');

   $form->{format} ||= $myconfig{outputformat};
   if ($myconfig{printer}) {
     $form->{format} ||= "postscript";
   } else {
     $form->{format} ||= "pdf";
   }
   $form->{media} ||= $myconfig{printer};
   for (qw(html postscript pdf)){
      $selected = ''; $selected = 'selected' if $form->{format} eq $_;
      $form->{selectformat} .= qq|<option value="$_" $selected>$_</option>\n|
   }
   $form->{selectformname} = qq|transfer--|.$locale->text('Transfer');
   $form->{formname} = 'transfer';
   print qq|  
<table width="100%">

    <tbody><tr>
      <td><select name="formname">|.$form->select_option($form->{selectformname}, $form->{formname}, undef, 1).qq|
</option></select></td>
      <td></td>
      <td><select name="format">$form->{selectformat}</select></td>
      <td><select name="media">
          <option value="screen">Screen 
          </option><option value="Epson">Epson 
          </option><option value="Laser">Laser</option></select></td>

<td align="right" width="90%">
      </td>
    </tr>
  </tbody></table>
|;

   $form->hide_form(qw(vc rowcount selectdepartment selectfrom_warehouse selectto_warehouse selectpartsgroup selectformname));

   %button = ( 'Update' => { ndx => 1, key => 'U', value => $locale->text('Update') },
	       'Print' => { ndx => 2, key => 'P', value => $locale->text('Print') },
	       'Save' => { ndx => 3, key => 'S', value => $locale->text('Save') },
	       'E-mail' => { ndx => 4, key => 'E', value => $locale->text('E-mail') },
	       'Delete' => { ndx => 5, key => 'D', value => $locale->text('Delete') },
   );

   $transdate = $form->datetonum(\%myconfig, $form->{"transdate"});
   if ($form->{id}) {
      if ($form->{locked} || $transdate <= $form->{closedto}) {
	for ("Save", "Delete") { delete $button{$_} }
      }
   } else {
      if ($transdate > $form->{closedto}) {
	for ("Update", "Print", "Save") { $a{$_} = 1 }
      }
      for (keys %button) { delete $button{$_} if !$a{$_} }
   }
    
   for (sort { $button{$a}->{ndx} <=> $button{$b}->{ndx} } keys %button) { $form->print_button(\%button, $_) }

   $form->hide_form(qw(closedto revtrans precision locked));
   &end_form;
}

#-------------------------------
sub form_footer {
  # stub only. required by bin/mozilla/io.pl
  # will be needed when we use io.pl display_row procedure
}

sub display_row {
  # stub to support tarnsfer display form bug
}

#-------------------------------
sub create_links {
  $dbh = $form->dbconnect(\%myconfig);
  my %defaults = $form->get_defaults($dbh, \@{[qw(closedto revtrans precision)]});
  for (keys %defaults) { $form->{$_} = $defaults{$_} }
  $form->{locked} = ($form->{revtrans}) ? '1' : ($form->datetonum(\%myconfig, $form->{transdate}) <= $form->{closedto});

  $form->{vc} = 'customer'; # Stub to satisfy e_email sub in io.pl
  $form->get_partsgroup(\%myconfig, { language_code => $form->{language_code}, searchitems => 'nolabor' });
  
  if (@{ $form->{all_partsgroup} }) {
    $form->{selectpartsgroup} = "\n";
    foreach $ref (@ { $form->{all_partsgroup} }) {
      if ($ref->{translation}) {
	$form->{selectpartsgroup} .= qq|$ref->{translation}--$ref->{id}\n|;
      } else {
	$form->{selectpartsgroup} .= qq|$ref->{partsgroup}--$ref->{id}\n|;
      }
    }
  }
}

#-------------------------------
sub add {
   &create_links;
   $form->{title} = $locale->text('Add New Transfer');
   $form->{callback} = qq|$form->{script}?action=add&path=$form->{path}&login=$form->{login}&sessionid=$form->{sessionid}|;
   $form->{callback} = $form->escape($form->{callback},1);
   &bld_department;
   &bld_warehouse('selectfrom_warehouse');
   &bld_warehouse('selectto_warehouse');
   $form->{transdate} = $form->current_date(\%myconfig);
   $form->{rowcount} = 1;
   &form_header;
}

#-------------------------------
sub edit {
   my $dbh = $form->dbconnect(\%myconfig);
   my $query = qq|SELECT trf.id, trf.transdate, trf.trfnumber,
		trf.description, trf.notes,
		trf.department_id, d.description AS department,
		trf.from_warehouse_id, trf.to_warehouse_id
		FROM trf
		JOIN department d ON (d.id = trf.department_id)
		JOIN warehouse w1 ON (w1.id = trf.from_warehouse_id)
		JOIN warehouse w2 ON (w2.id = trf.to_warehouse_id)
		WHERE trf.id = $form->{id}|;
   my $sth = $dbh->prepare($query);
   $sth->execute || $form->dberror($query);
   $ref = $sth->fetchrow_hashref(NAME_lc);
   foreach $key (keys %$ref) {
      $form->{$key} = $ref->{$key};
   }
   $sth->finish;
   $query = qq|
	SELECT i.parts_id, p.partnumber, p.description,
		p.unit, i.qty, i.cost,
		i.itemnotes, i.serialnumber
	FROM inventory i
	JOIN parts p ON (p.id = i.parts_id)
	WHERE i.trans_id = $form->{id}
	AND linetype = '1'|;
   $sth = $dbh->prepare($query);
   $sth->execute || $form->dberror($query);
   my $i = 1;
   while ($ref = $sth->fetchrow_hashref(NAME_lc)){
	$form->{"no_$i"} = $i;
	$form->{"parts_id_$i"} = $ref->{parts_id};
	$form->{"partnumber_$i"} = $ref->{partnumber};
	$form->{"description_$i"} = $ref->{description};
	$form->{"cost_$i"} = $ref->{cost};
	$form->{"unit_$i"} = $ref->{unit};
	$form->{"qty_$i"} = $ref->{qty};
	$form->{"itemnotes_$i"} = $ref->{itemnotes};
	$form->{"serialnumber_$i"} = $ref->{serialnumber};
	$i++;
   }
   $form->{rowcount} = $i;
   $sth->finish;
   $dbh->disconnect;

   &bld_department;
   &bld_warehouse('selectfrom_warehouse');
   &bld_warehouse('selectto_warehouse');
   $form->{title} = $locale->text('Edit Transfer');
   &create_links;
   &form_header;
}

#-------------------------------
sub select_part {
   $ndx = $form->{ndx};

   $dbh = $form->dbconnect(\%myconfig);
   my $id = $form->{"new_id_$ndx"};
   $query = qq|SELECT id, partnumber, description, 0 AS onhand, unit
                FROM parts WHERE id = $id ORDER BY partnumber|;

   my $j = $form->{rowcount};
   ($form->{"parts_id_$j"}, $form->{"partnumber_$j"}, $form->{"description_$j"}, 
	$form->{"onhand_$j"}, $form->{"unit_$j"}) = $dbh->selectrow_array($query);

   $form->{"qty_$j"} = 1 if !$form->{"qty_$j"};
   $j++;
   $form->{rowcount} = $j;
   &form_header
}

#-------------------------------
sub update {
   &split_combos('department,from_warehouse,to_warehouse');

   $form->{department_id} *= 1;
   $form->{from_warehouse_id} *= 1;
   $form->{to_warehouse_id} *= 1;

   $i = $form->{rowcount};
   if (($form->{"partnumber_$i"} ne "") or ($form->{"description_$i"} ne "") or ($form->{"partsgroup_$i"})){
      $cost = $form->parse_amount(\%myconfig, $form->{"cost_$i"});
      Trf->retrieve_item(\%myconfig, \%$form);
      $rows = scalar @{ $form->{item_list} };

      if ($rows){
       if ($rows > 1) {
          $form->{display_form} = 'display_trf_form';
          &select_item;
          exit;
       } else {
          $form->{"qty_$i"} = ($form->{"qty_$i"} * 1) ? $form->{"qty_$i"} : 1;
          for (qw(partnumber description unit)) { $form->{item_list}[$i]{$_} = $form->quote($form->{item_list}[$i]{$_}) }
          for (keys %{ $form->{item_list}[0] }) { $form->{"${_}_$i"} = $form->{item_list}[0]{$_} }
          $form->{"parts_id_$i"} = $form->{"id_$i"};
          $form->{"cost_$i"} = $form->{"lastcost_$i"} if !$cost;
          $form->{rowcount} += 1;
       }
      }
   }

   #$j++ if $form->{"partnumber_$j"} ne "";
   #$form->{rowcount} = $j;
   &form_header;
}


#-------------------------------
sub delete {

  $transdate = $form->datetonum(\%myconfig, $form->{transdate});
  $form->error($locale->text('Cannot delete transfer for a closed period!')) if ($transdate <= $form->{closedto});

  $form->header;

  print qq|
<body>

<form method=post action=$form->{script}>
|;

  $form->{action} = "yes";
  $form->hide_form;

  print qq|
<h2 class=confirm>|.$locale->text('Confirm!').qq|</h2>

<h4>|.$locale->text('Are you sure you want to delete Transfer Number').qq| $form->{trfnumber}
</h4>

<p>
<input name=action class=submit type=submit value="|.$locale->text('Yes').qq|">
</form>
|;


}

#-------------------------------
sub yes {
  $dbh = $form->dbconnect_noauto(\%myconfig);
  $query = qq|DELETE FROM inventory WHERE trans_id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);
  $query = qq|DELETE FROM trf WHERE id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

   # Now commit the whole tranaction 
  my $rc = $dbh->commit;
  $dbh->disconnect;

  $form->{callback} = $form->unescape($form->{callback});
  $form->redirect($locale->text('Transfer deleted!'));
}

#-------------------------------
sub save {
  $form->isblank('trfnumber', $locale->text('Transfer Number cannot be blank'));
  $form->isblank('department', $locale->text('Department cannot be blank'));
  $form->isblank('from_warehouse', $locale->text('From warehouse cannot be blank'));
  $form->isblank('to_warehouse', $locale->text('To warehouse cannot be blank'));
  $form->isblank('transdate', $locale->text('Transfer date cannot be blank')) if $form->{closed} eq 'Y';

  $transdate = $form->datetonum(\%myconfig, $form->{transdate});
  $form->error($locale->text('Cannot post transfer for a closed period!')) if ($transdate <= $form->{closedto});

  &split_combos('department,from_warehouse,to_warehouse');
  $form->{department_id} *= 1;
  $form->{from_warehouse_id} *= 1;
  $form->{to_warehouse_id} *= 1;

  $dbh = $form->dbconnect_noauto(\%myconfig);

  # Remove old detail posting. 
  if ($form->{id}){
	$query = qq|DELETE FROM inventory WHERE trans_id = $form->{id}|;
	$dbh->do($query) || $form->dberror($query);
  }
  my ($null, $employee_id) = $form->get_employee($dbh); # Get employee_id of current login

  my %trf;
  $trf{id}			= $form->{id};
  $trf{transdate}   		= $form->{transdate};
  $trf{trfnumber}   		= $form->{trfnumber};
  $trf{description} 		= $form->{description};
  $trf{notes}   		= $form->{notes};
  $trf{department_id}  		= $form->{department_id};
  $trf{from_warehouse_id}  	= $form->{from_warehouse_id};
  $trf{to_warehouse_id}  	= $form->{to_warehouse_id};
  $trf{employee_id} 		= $employee_id;

  &post_trf(\%trf, $dbh);

  my %inventory;
  my $j = $form->{rowcount} - 1;
  for $i (1 .. $j){
     $form->{"qty_$i"} *= 1;
     $form->{"cost_$i"} *= 1;
     $inventory{trans_id}	= $form->{trf_id};
     $inventory{transdate}	= $form->{transdate};
     $inventory{department_id}	= $form->{department_id};
     $inventory{warehouse_id}	= $form->{to_warehouse_id};
     $inventory{warehouse_id2}	= $form->{from_warehouse_id};
     $inventory{parts_id}	= $form->{"parts_id_$i"};
     $inventory{qty} 		= $form->{"qty_$i"};
     $inventory{cost} 		= $form->{"cost_$i"};
     $inventory{description}	= $dbh->quote($form->{"description_$i"});
     $inventory{itemnotes}	= $dbh->quote($form->{"itemnotes_$i"});
     $inventory{serialnumber}	= $dbh->quote($form->{"serialnumber_$i"});
     $inventory{employee_id}	= $employee_id;
     $inventory{linetype}	= '1';
     &post_inventory(\%inventory, $dbh);
     $inventory{warehouse_id}	= $form->{from_warehouse_id};
     $inventory{warehouse_id2}	= $form->{to_warehouse_id};
     $inventory{qty} 		*= -1;
     $inventory{linetype}	= '2';
     &post_inventory(\%inventory, $dbh);
  }

  # Audit trail posting
  my %audittrail = ( tablename  => 'trf',
                     reference  => "$form->{trfnumber}",
                     formname   => 'trf',
                     action     => 'posted',
                     id         => $form->{id} );
  $form->audittrail($dbh, "", \%audittrail);

  # Now commit the whole tranaction 
  my $rc = $dbh->commit;
  $dbh->disconnect;

  $form->{callback} = $form->unescape($form->{callback});
  $form->redirect($locale->text('Transfer saved!'));
}

#-------------------------------
sub search {
   $form->{title} = $locale->text('Transfer List');

   &bld_department;
   &bld_partsgroup;
   &bld_warehouse('selectfrom_warehouse');
   &bld_warehouse('selectto_warehouse');

   $form->header;
   print qq|
<body>

<form method=post action=$form->{script}>

<table width=100%>
  <tr><th class=listtop>$form->{title}</th></tr>
  <tr height="5"></tr>
</table>
<table>
|;
   &print_text('trfnumber', $locale->text('Transfer Number'), 15);
   &print_text('description', $locale->text('Description'), 30);
   &print_text('notes', $locale->text('Notes'), 30);
   &print_text('partnumber', $locale->text('Number'), 20);
   &print_text('partdescription', $locale->text('Description'), 30);
   &print_text('itemnotes', $locale->text('Item Notes'), 40);
   &print_text('serialnumber', $locale->text('Serial No.'), 25);
   
   &print_date('fromdate', $locale->text('From'), $form->{fromdate});
   &print_date('todate', $locale->text('To'), $form->{todate});
 
   &print_select('partsgroup', $locale->text('Group'));
   &print_select('department', $locale->text('Department'));
   &print_select('from_warehouse', $locale->text('From Warehouse'));
   &print_select('to_warehouse', $locale->text('To Warehouse'));

   print qq|
	      <tr>
		<th align=right>|.$locale->text('Include in Report').qq|</th>
		<td><table>
		<tr>
		  <td><input name=summary type=radio class=radio value=1 checked> |.$locale->text('Summary').qq|</td>
		  <td><input name=summary type=radio class=radio value=0> |.$locale->text('Detail').qq|</td>
	        </tr>
|;

   @a = ();
   push @a, qq|<input name="l_no" class=checkbox type=checkbox value=Y> |.$locale->text('No.');
   push @a, qq|<input name="l_id" class=checkbox type=checkbox value=Y> |.$locale->text('ID');
   push @a, qq|<input name="l_trfnumber" class=checkbox type=checkbox value=Y checked> |.$locale->text('Number');
   push @a, qq|<input name="l_transdate" class=checkbox type=checkbox value=Y checked> |.$locale->text('Date');
   push @a, qq|<input name="l_description" class=checkbox type=checkbox value=Y checked> |.$locale->text('Description');
   push @a, qq|<input name="l_notes" class=checkbox type=checkbox value=Y checked> |.$locale->text('Notes');
   push @a, qq|<input name="l_department" class=checkbox type=checkbox value=Y> |.$locale->text('Department');
   push @a, qq|<input name="l_from_warehouse" class=checkbox type=checkbox value=Y checked> |.$locale->text('From WH');
   push @a, qq|<input name="l_to_warehouse" class=checkbox type=checkbox value=Y checked> |.$locale->text('To WH');
   push @a, qq|<input name="l_partnumber" class=checkbox type=checkbox value=Y checked> |.$locale->text('Number');
   push @a, qq|<input name="l_partdescription" class=checkbox type=checkbox value=Y> |.$locale->text('Description');
   push @a, qq|<input name="l_itemnotes" class=checkbox type=checkbox value=Y> |.$locale->text('Item Notes');
   push @a, qq|<input name="l_serialnumber" class=checkbox type=checkbox value=Y> |.$locale->text('Serial No.');
   push @a, qq|<input name="l_serialnumber" class=checkbox type=checkbox value=Y> |.$locale->text('Serial No.');
   push @a, qq|<input name="l_qty" class=checkbox type=checkbox value=Y checked> |.$locale->text('Qty');
   push @a, qq|<input name="l_cost" class=checkbox type=checkbox value=Y checked> |.$locale->text('Cost');
   push @a, qq|<input name="l_extended" class=checkbox type=checkbox value=Y> |.$locale->text('Extended');
   push @a, qq|<input name="l_subtotal" class=checkbox type=checkbox value=Y> |.$locale->text('Subtotal');
   push @a, qq|<input name="l_csv" class=checkbox type=checkbox value=Y> |.$locale->text('CSV');

   while (@a) {
     print qq|<tr>\n|;
     for (1 .. 5) {
       print qq|<td nowrap>|. shift @a;
       print qq|</td>\n|;
     }
     print qq|</tr>\n|;
   }

   print qq|
	</table></td></tr>
</table>
<hr size=3 noshade>
<input type=hidden name=action value=continue>
<input class=submit type=submit name=action value="|.$locale->text('Continue').qq|">|;

  $form->{nextsub} = 'list';
  $form->hide_form(qw(nextsub path login));
  
  print qq|
</form>
|;
}

#-------------------------------
sub list {
   # callback to report list
   my $callback = qq|$form->{script}?action=list|;
   for (qw(path login sessionid)) { $callback .= "&$_=$form->{$_}" }

   &split_combos('department,from_warehouse,to_warehouse,partsgroup');
   $form->{department_id} *= 1;
   $form->{from_warehouse_id} *= 1;
   $form->{to_warehouse_id} *= 1;
   $form->{partsgroup_id} *= 1;
   $trfnumber = $form->like(lc $form->{trfnumber});
   $partnumber = $form->like(lc $form->{partnumber});
   $partdescription = $form->like(lc $form->{partdescription});
   $itemnotes = $form->like(lc $form->{itemnotes});
   $serialnumber = $form->like(lc $form->{serialnumber});
   
   @columns = qw(id transdate trfnumber description notes department from_warehouse to_warehouse);
   my $where = qq| (1 = 1)|;
   $where .= qq| AND (LOWER(trfnumber) LIKE '$trfnumber')| if $form->{trfnumber};
   $where .= qq| AND (trf.department_id = $form->{department_id})| if $form->{department};
   $where .= qq| AND (trf.from_warehouse_id = $form->{from_warehouse_id})| if $form->{from_warehouse};
   $where .= qq| AND (trf.to_warehouse_id = $form->{to_warehouse_id})| if $form->{to_warehouse};
   $where .= qq| AND (trf.transdate >= '$form->{fromdate}')| if $form->{fromdate};
   $where .= qq| AND (trf.transdate <= '$form->{todate}')| if $form->{todate};
   if (!$form->{summary}){
      @columns = qw(id transdate trfnumber description notes department from_warehouse to_warehouse partnumber partdescription itemnotes serialnumber qty cost extended);
      $where .= qq| AND (LOWER(partnumber) LIKE '$partnumber')| if $form->{partnumber};
      $where .= qq| AND (LOWER(partdescription) LIKE '$partdescription')| if $form->{partdescription};
      $where .= qq| AND (LOWER(itemnotes) LIKE '$itemnotes')| if $form->{itemnotes};
      $where .= qq| AND (LOWER(serialnumber) LIKE '$serialnumber')| if $form->{serialnumber};
      $where .= qq| AND (p.partsgroup_id = $form->{partsgroup_id})| if $form->{partsgroup};
   }

   # if this is first time we are running this report.
   $form->{sort} = 'transdate' if !$form->{sort};
   $form->{oldsort} = 'none' if !$form->{oldsort};
   $form->{direction} = 'ASC' if !$form->{direction};
   @columns = $form->sort_columns(@columns);

   my %ordinal = (	id => 1,
			transdate => 2,
			trfnumber => 3,
			description => 4,
			notes => 5,
			department => 6,
			from_warehouse => 9,
			to_warehouse => 10,
			partnumber => 11,
			partdescription => 12,
			itemnotes => 13,
			serialnumber => 14,
			qty => 15,
			cost => 16,
			extended => 17
   );
   my $sort_order = $form->sort_order(\@columns, \%ordinal);

   # No. columns should always come first
   splice @columns, 0, 0, 'no';

   # Select columns selected for report display
   foreach $item (@columns) {
     if ($form->{"l_$item"} eq "Y") {
       push @column_index, $item;

       # add column to href and callback
       $callback .= "&l_$item=Y";
     }
   }

   for (qw(l_subtotal summary transdate trfnumber description notes department from_warehouse to_warehouse partnumber partdescription itemnotes serialnumber)){
      $callback .= "&$_=".$form->escape($form->{$_});
   }
   my $href = $callback;
   $form->{callback} = $form->escape($callback,1);

   if ($form->{summary}){
   	$query = qq|SELECT trf.id, trf.transdate, trf.trfnumber,
			trf.description, trf.notes,
			trf.department_id, d.description AS department,
			trf.from_warehouse_id, w1.description AS from_warehouse,
			trf.to_warehouse_id, w2.description AS to_warehouse
		    FROM trf
			JOIN department d ON (d.id = trf.department_id)
			JOIN warehouse w1 ON (w1.id = trf.from_warehouse_id)
			JOIN warehouse w2 ON (w2.id = trf.to_warehouse_id)
		    WHERE $where
		    ORDER BY $form->{sort} $form->{direction}|;
		    #ORDER BY $sort_order|;
   } else {
	$where .= qq| AND (i.linetype = '1')|;
   	$query = qq|SELECT trf.id, trf.transdate, trf.trfnumber,
			trf.description, trf.notes,
			trf.department_id, d.description AS department,
			trf.from_warehouse_id, w1.description AS from_warehouse,
			trf.to_warehouse_id, w2.description AS to_warehouse,
			p.partnumber, i.qty, i.cost, i.qty * i.cost AS extended,
			i.description AS partdescription, i.itemnotes, i.serialnumber
		    FROM trf
			JOIN inventory i ON (i.trans_id = trf.id)
			JOIN parts p ON (p.id = i.parts_id)
			JOIN department d ON (d.id = trf.department_id)
			JOIN warehouse w1 ON (w1.id = trf.from_warehouse_id)
			JOIN warehouse w2 ON (w2.id = trf.to_warehouse_id)
		    WHERE $where
		    ORDER BY $form->{sort} $form->{direction}|;
		    #ORDER BY $sort_order|;

   }

   # store oldsort/direction information
   $href .= "&direction=$form->{direction}&oldsort=$form->{sort}";

   $column_header{no}   		= rpt_hdr('no', $locale->text('No.'));
   $column_header{id}   		= rpt_hdr('id', $locale->text('ID'), $href);
   $column_header{transdate}    	= rpt_hdr('transdate', $locale->text('Date'), $href);
   $column_header{trfnumber}  		= rpt_hdr('trfnumber', $locale->text('Transfer Number'), $href);
   $column_header{reference}    	= rpt_hdr('reference', $locale->text('Reference'), $href);
   $column_header{description}  	= rpt_hdr('description', $locale->text('Description'), $href);
   $column_header{department}  		= rpt_hdr('department', $locale->text('Department'), $href);
   $column_header{from_warehouse}	= rpt_hdr('from_warehouse', $locale->text('From WH'), $href);
   $column_header{to_warehouse}      	= rpt_hdr('to_warehouse', $locale->text('To WH'), $href);
   $column_header{partnumber}   	= rpt_hdr('partnumber', $locale->text('Number'), $href);
   $column_header{partdescription}     	= rpt_hdr('partdescription', $locale->text('Part Description'), $href);
   $column_header{itemnotes}      	= rpt_hdr('itemnotes', $locale->text('Item Notes'), $href);
   $column_header{serialnumber}      	= rpt_hdr('serialnumber', $locale->text('Serial No.'), $href);
   $column_header{qty}      		= rpt_hdr('qty', $locale->text('Qty'), $href);
   $column_header{cost}      		= rpt_hdr('cost', $locale->text('Cost'), $href);
   $column_header{extended}    		= rpt_hdr('extended', $locale->text('Extended'), $href);

   $form->error($query) if $form->{l_sql};
   $dbh = $form->dbconnect(\%myconfig);
   my %defaults = $form->get_defaults($dbh, \@{['precision', 'company']});
   for (keys %defaults) { $form->{$_} = $defaults{$_} }

   if ($form->{l_csv} eq 'Y'){
	&export_to_csv($dbh, $query, 'warehouse_transfers');
	exit;
   }
   $sth = $dbh->prepare($query);
   $sth->execute || $form->dberror($query);

   $form->{title} = $locale->text('Transfers List');
   &print_title;
   &start_table;
   &end_table;

   print qq|<table width=100%><tr class=listheading>|;
   # print header
   for (@column_index) { print "\n$column_header{$_}" }
   print qq|</tr>|; 

   # Subtotal and total variables
   my $qty_subtotal = 0;
   my $qty_total = 0;
   my $extended_subtotal = 0;
   my $extended_total = 0;

   # print data
   my $i = 1; my $no = 1;
   my $groupbreak = 'none';
   while (my $ref = $sth->fetchrow_hashref(NAME_lc)){
   	$form->{link} = qq|$form->{script}?action=edit&id=$ref->{id}&path=$form->{path}&login=$form->{login}&sessionid=$form->{sessionid}&callback=$form->{callback}|;
	$groupbreak = $ref->{$form->{sort}} if $groupbreak eq 'none';
	if ($form->{l_subtotal}){
	   if ($groupbreak ne $ref->{$form->{sort}}){
		$groupbreak = $ref->{$form->{sort}};
		# prepare data for footer

   		$column_data{no}   		= rpt_txt('&nbsp;');
   		$column_data{id}   		= rpt_txt('&nbsp;');
   		$column_data{transdate}    	= rpt_txt('&nbsp;');
   		$column_data{trfnumber} 	= rpt_txt('&nbsp;');
   		$column_data{reference}    	= rpt_txt('&nbsp;');
   		$column_data{description}  	= rpt_txt('&nbsp;');
   		$column_data{department}  	= rpt_txt('&nbsp;');
    		$column_data{from_warehouse}	= rpt_txt('&nbsp;');
   		$column_data{to_warehouse}    	= rpt_txt('&nbsp;');
   		$column_data{partnumber}    	= rpt_txt('&nbsp;');
   		$column_data{partdescription}  	= rpt_txt('&nbsp;');
   		$column_data{itemnotes}  	= rpt_txt('&nbsp;');
   		$column_data{serialnumber}  	= rpt_txt('&nbsp;');
  		$column_data{qty}    		= rpt_txt('&nbsp;');
   		$column_data{cost}    		= rpt_txt('&nbsp;');
   		$column_data{extended}    	= rpt_txt('&nbsp;');

		# print footer
		print "<tr valign=top class=listsubtotal>";
		for (@column_index) { print "\n$column_data{$_}" }
		print "</tr>";

		$qty_subtotal = 0;
   		$extended_subtotal = 0;
	   }
	}

	$column_data{no}   		= rpt_txt($no);
   	$column_data{id}   		= rpt_txt($ref->{id});
   	$column_data{trfnumber} 	= rpt_txt($ref->{trfnumber}, $form->{link});
   	$column_data{transdate}    	= rpt_txt($ref->{transdate});
   	$column_data{reference}    	= rpt_txt($ref->{reference});
   	$column_data{description}  	= rpt_txt($ref->{description});
   	$column_data{department}  	= rpt_txt($ref->{department});
  	$column_data{from_warehouse}	= rpt_txt($ref->{from_warehouse});
   	$column_data{to_warehouse}    	= rpt_txt($ref->{to_warehouse});
   	$column_data{partnumber}    	= rpt_txt($ref->{partnumber});
   	$column_data{partdescription} 	= rpt_txt($ref->{partdescription});
    	$column_data{itemnotes}  	= rpt_txt($ref->{itemnotes});
   	$column_data{serialnumber}  	= rpt_txt($ref->{serialnumber});
   	$column_data{qty}    		= rpt_dec($ref->{qty});
   	$column_data{cost}    		= rpt_dec($ref->{cost});
   	$column_data{extended}    	= rpt_dec($ref->{extended});

	print "<tr valign=top class=listrow$i>";
	for (@column_index) { print "\n$column_data{$_}" }
	print "</tr>";
	$i++; $i %= 2; $no++;

	$qty_subtotal += $ref->{qty};
	$qty_total += $ref->{qty};
	$extended_subtotal += $ref->{extended};
	$extended_total += $ref->{extended};
   }

   # prepare data for footer
  $column_data{no}   		= rpt_txt('&nbsp;');
  $column_data{id}   		= rpt_txt('&nbsp;');
  $column_data{transdate}    	= rpt_txt('&nbsp;');
  $column_data{trfnumber} 	= rpt_txt('&nbsp;');
  $column_data{reference}    	= rpt_txt('&nbsp;');
  $column_data{description}  	= rpt_txt('&nbsp;');
  $column_data{department}  	= rpt_txt('&nbsp;');
  $column_data{from_warehouse}	= rpt_txt('&nbsp;');
  $column_data{to_warehouse}   	= rpt_txt('&nbsp;');
  $column_data{partnumber}   	= rpt_txt('&nbsp;');
  $column_data{partdescription} = rpt_txt('&nbsp;');
  $column_data{itemnotes}  	= rpt_txt('&nbsp;');
  $column_data{serialnumber}  	= rpt_txt('&nbsp;');
  $column_data{qty}	   	= rpt_dec($qty_subtotal);
  $column_data{cost}   		= rpt_txt('&nbsp;');
  $column_data{extended} 	= rpt_dec($extended_subtotal);

   if ($form->{l_subtotal}){
	# print last subtotal
	print "<tr valign=top class=listsubtotal>";
	for (@column_index) { print "\n$column_data{$_}" }
	print "</tr>";
   }

   # grand total
   $column_data{qty} 		= rpt_dec($qty_total);
   $column_data{extended} 	= rpt_dec($extended_total);

   # print footer
   print "<tr valign=top class=listtotal>";
   for (@column_index) { print "\n$column_data{$_}" }
   print "</tr>";

   print qq|</table>|;
   $sth->finish;
   $dbh->disconnect;
}


#============================================================
#
# Report/Form related to delivereddate management
#
#============================================================
sub delivered_search {
   $form->{title} = $locale->text('Transfers to be Delivered');
   &print_title;
   &start_form;
   &start_table;

   &bld_department;
   &bld_warehouse('selectfrom_warehouse');

   &print_text('trfnumber', $locale->text('Transfer Number'), 15);
   &print_text('description', $locale->text('Description'), 30);
   &print_text('notes', $locale->text('Notes'), 30);
   
   &print_date('fromdate', $locale->text('From'), $form->{fromdate});
   &print_date('fromdate', $locale->text('To'), $form->{todate});
 
   &print_select('department', $locale->text('Department'));
   &print_select('from_warehouse', $locale->text('From Warehouse'));
   print qq|<tr><th align=right>|.$locale->text('To Warehouse').qq|</th><td>$myconfig{warehouse}</td></tr>|;

   print qq|<tr><th align=right>| . $locale->text('Include in Report') . qq|</th><td>|;

   &print_checkbox('undelivered', $locale->text('Un-delivered'), 'checked', '');
   &print_checkbox('delivered', $locale->text('Delivered'), '', '<br>');

   &print_radio;
   &print_checkbox('l_no', $locale->text('No.'), '', '<br>');
   &print_checkbox('l_id', $locale->text('ID'), '', '<br>');
   &print_checkbox('l_trfnumber', $locale->text('Number'), 'checked', '<br>');
   &print_checkbox('l_transdate', $locale->text('Date'), 'checked', '<br>');
   &print_checkbox('l_description', $locale->text('Description'), 'checked', '<br>');
   &print_checkbox('l_notes', $locale->text('Notes'), 'checked', '<br>');
   &print_checkbox('l_department', $locale->text('Department'), '', '<br>');
   &print_checkbox('l_from_warehouse', $locale->text('From WH'), 'checked', '<br>');
   &print_checkbox('l_csv', $locale->text('CSV'), '', '<br>');
   print qq|</td></tr>|;
   &end_table;
   print('<hr size=3 noshade>');
   $form->{nextsub} = 'delivered_form';
   &add_button($locale->text('Continue'));
   &end_form;
}

sub delivered_form {
   # callback to report list
   my $callback = qq|$form->{script}?action=list|;
   for (qw(path login sessionid)) { $callback .= "&$_=$form->{$_}" }

   &split_combos('department,from_warehouse,to_warehouse');
   $form->{department_id} *= 1;
   $form->{from_warehouse_id} *= 1;
   $form->{to_warehouse_id} *= 1;
   $trfnumber = $form->like(lc $form->{trfnumber});
   
   my $where = qq| (1 = 1)|;
   $where .= qq| AND (LOWER(trfnumber) LIKE '$trfnumber')| if $form->{trfnumber};
   $where .= qq| AND (trf.to_warehouse_id = $myconfig{warehouse_id})| if $myconfig{warehouse_id};

   if ($form->{delivered} || $form->{undelivered}){
     if ($form->{undelivered}){
	$where .= " AND delivereddate IS NULL" unless $form->{delivered};
     } 
     if ($form->{delivered}){
	$where .= " AND delivereddate IS NOT NULL" unless $form->{undelivered};
     }
   }

   @columns = qw(id transdate trfnumber description notes department from_warehouse delivereddate);
   # if this is first time we are running this report.
   $form->{sort} = 'transdate' if !$form->{sort};
   $form->{oldsort} = 'none' if !$form->{oldsort};
   $form->{direction} = 'ASC' if !$form->{direction};
   @columns = $form->sort_columns(@columns);

   my %ordinal = (	id => 1,
			transdate => 2,
			trfnumber => 3,
			description => 4,
			notes => 5,
			department => 6,
			fromwarehouse => 9,
			delivereddate => 10,
   );
   my $sort_order = $form->sort_order(\@columns, \%ordinal);

   # No. columns should always come first
   splice @columns, 0, 0, 'no';

   # TODO: patch
   $form->{l_delivereddate} = 'Y';
 
   # Select columns selected for report display
   foreach $item (@columns) {
     if ($form->{"l_$item"} eq "Y") {
       push @column_index, $item;

       # add column to href and callback
       $callback .= "&l_$item=Y";
     }
   }

   $callback .= "&l_subtotal=$form->{l_subtotal}";
   $callback .= "&summary=$form->{summary}";
   my $href = $callback;
   $form->{callback} = $form->escape($callback,1);

   $query = qq|SELECT trf.id, trf.transdate, trf.trfnumber,
			trf.description, trf.notes, trf.delivereddate,
			trf.department_id, d.description AS department,
			trf.from_warehouse_id, w1.description AS from_warehouse,
			trf.to_warehouse_id, w2.description AS to_warehouse
		    FROM trf
			JOIN department d ON (d.id = trf.department_id)
			JOIN warehouse w1 ON (w1.id = trf.from_warehouse_id)
			JOIN warehouse w2 ON (w2.id = trf.to_warehouse_id)
		    WHERE $where
		    ORDER BY $form->{sort} $form->{direction}|;
		    #ORDER BY $sort_order|;

   # store oldsort/direction information
   $href .= "&direction=$form->{direction}&oldsort=$form->{sort}";

   $column_header{no}   		= rpt_hdr('no', $locale->text('No.'));
   $column_header{id}   		= rpt_hdr('id', $locale->text('ID'), $href);
   $column_header{transdate}    	= rpt_hdr('transdate', $locale->text('Date'), $href);
   $column_header{trfnumber}  		= rpt_hdr('trfnumber', $locale->text('Transfer Number'), $href);
   $column_header{reference}    	= rpt_hdr('reference', $locale->text('Reference'), $href);
   $column_header{description}  	= rpt_hdr('description', $locale->text('Description'), $href);
   $column_header{notes}  		= rpt_hdr('notes', $locale->text('Notes'), $href);
   $column_header{from_warehouse}	= rpt_hdr('from_warehouse', $locale->text('From WH'), $href);
   $column_header{delivereddate}      	= rpt_hdr('delivereddate', $locale->text('Delivered Date'));

   $form->error($query) if $form->{l_sql};
   $dbh = $form->dbconnect(\%myconfig);
   my %defaults = $form->get_defaults($dbh, \@{['precision', 'company']});
   for (keys %defaults) { $form->{$_} = $defaults{$_} }

   if ($form->{l_csv} eq 'Y'){
	&export_to_csv($dbh, $query, 'deliveries_list');
	exit;
   }
   $sth = $dbh->prepare($query);
   $sth->execute || $form->dberror($query);

   $form->{title} = $locale->text('Transfers to be Delivered');
   &print_title;
   print qq|<table border=0 cellpadding=5 cellspacing=1>|;
   print qq|<tr><th align=left>|.$locale->text('My Warehouse').qq|</th><td>| . $myconfig{warehouse} . qq|</td></tr>| if $myconfig{warehouse};
   print qq|</table>|;


   print qq|<table width=100%><tr class=listheading>|;
   # print header
   for (@column_index) { print "\n$column_header{$_}" }
   print qq|</tr>|; 

   # Subtotal and total variables
   my $qty_subtotal = 0;
   my $qty_total = 0;
   my $extended_subtotal = 0;
   my $extended_total = 0;

   &start_form($form->{script});

   # print data
   my $i = 1; my $no = 1;
   my $groupbreak = 'none';
   while (my $ref = $sth->fetchrow_hashref(NAME_lc)){
   	$form->{link} = qq|$form->{script}?action=edit&id=$ref->{id}&path=$form->{path}&login=$form->{login}&sessionid=$form->{sessionid}&callback=$form->{callback}|;
	$groupbreak = $ref->{$form->{sort}} if $groupbreak eq 'none';
	if ($form->{l_subtotal}){
	   if ($groupbreak ne $ref->{$form->{sort}}){
		$groupbreak = $ref->{$form->{sort}};
		# prepare data for footer

   		$column_data{no}   		= rpt_txt('&nbsp;');
   		$column_data{id}   		= rpt_txt('&nbsp;');
   		$column_data{transdate}    	= rpt_txt('&nbsp;');
   		$column_data{trfnumber} 	= rpt_txt('&nbsp;');
   		$column_data{reference}    	= rpt_txt('&nbsp;');
   		$column_data{description}  	= rpt_txt('&nbsp;');
   		$column_data{from_warehouse}	= rpt_txt('&nbsp;');

		# print footer
		print "<tr valign=top class=listsubtotal>";
		for (@column_index) { print "\n$column_data{$_}" }
		print "</tr>";

		$qty_subtotal = 0;
   		$extended_subtotal = 0;
	   }
	}

	$column_data{no}   		= rpt_txt($no);
   	$column_data{id}   		= rpt_txt($ref->{id});
   	$column_data{trfnumber} 	= rpt_txt($ref->{trfnumber}, $form->{link});
   	$column_data{transdate}    	= rpt_txt($ref->{transdate});
   	$column_data{reference}    	= rpt_txt($ref->{reference});
   	$column_data{description}  	= rpt_txt($ref->{description});
   	$column_data{notes}  		= rpt_txt($ref->{notes});
   	$column_data{from_warehouse}	= rpt_txt($ref->{from_warehouse});
	if ($myconfig{role} eq 'user'){
   	   $column_data{delivereddate}	= qq|<input type=hidden name="delivereddate_$no" value=$ref->{delivereddate}>|;
	   $column_data{delivereddate}  .= qq|<td>$ref->{delivereddate}</td>|
	} else {
   	   $column_data{delivereddate}	= rpt_print_date("delivereddate_$no", $ref->{delivereddate});
	}

	print "<tr valign=top class=listrow$i>";
	for (@column_index) { 
	   print "\n<input type=hidden name=id_$no value=$ref->{id}>";
	   print "\n<input type=hidden name=transdate_$no value='$ref->{transdate}'>";
	   print "\n$column_data{$_}";
	}
	print "</tr>";
	$i++; $i %= 2; $no++;

	$qty_subtotal += $ref->{qty};
	$qty_total += $ref->{qty};
	$extended_subtotal += $ref->{extended};
	$extended_total += $ref->{extended};
   }

   # prepare data for footer
  $column_data{no}   		= rpt_txt('&nbsp;');
  $column_data{id}   		= rpt_txt('&nbsp;');
  $column_data{transdate}    	= rpt_txt('&nbsp;');
  $column_data{trfnumber} 	= rpt_txt('&nbsp;');
  $column_data{reference}    	= rpt_txt('&nbsp;');
  $column_data{description}  	= rpt_txt('&nbsp;');
  $column_data{notes}  		= rpt_txt('&nbsp;');
  $column_data{from_warehouse}	= rpt_txt('&nbsp;');
  $column_data{delivereddate}	= rpt_txt('&nbsp;');

   if ($form->{l_subtotal}){
	# print last subtotal
	print "<tr valign=top class=listsubtotal>";
	for (@column_index) { print "\n$column_data{$_}" }
	print "</tr>";
   }

   # grand total
   $column_data{qty} 		= "&nbsp;";
   $column_data{extended} 	= "&nbsp;";

   # print footer
   print "<tr valign=top class=listtotal>";
   for (@column_index) { print "\n$column_data{$_}" }
   print "</tr>";


   print qq|</table>|;

   print('<hr size=3 noshade>');
   &add_button($locale->text('Save Delivered'));

   $form->{rowcount} = --$no;
   &print_hidden(rowcount);
   &end_form;

   $sth->finish;
   $dbh->disconnect;
}

sub save_delivered {
   $form->{title} = $locale->text('Transfers Deliveries');
   &print_title;
   $dbh = $form->dbconnect(\%myconfig);
   for $i (1 .. $form->{rowcount}){
      if ($form->{"delivereddate_$i"}){
	if ($form->datediff(\%myconfig,  $form->{"delivereddate_$i"}, $form->{"transdate_$i"}) <= 0){
	  $query = qq|UPDATE trf 
		SET delivereddate = '$form->{"delivereddate_$i"}'
		WHERE id = $form->{"id_$i"}|;
	  $dbh->do($query) || $form->dberror($query);
	  $form->info(qq|$form->{"id_$i"}--$form->{"delivereddate_$i"}\n|);
	} else {
	  $form->error('Delivered date cannot be before transfer date');
	}
      } 
   }
   $dbh->disconnect;
   $form->info('Deliveries updated');
}

#######
## EOF
#######
