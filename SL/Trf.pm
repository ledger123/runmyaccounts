package Trf;

sub transfer_details {
   my ($self, $myconfig, $form) = @_;

   $form->{trfdate} = $form->{transdate};
   $form->{trfdescription} = $form->{description};
   ($form->{from_warehouse}) = split(/--/, $form->{from_warehouse});
   ($form->{to_warehouse}) = split(/--/, $form->{to_warehouse});
   ($form->{department}) = split(/--/, $form->{department});

   my $runningnumber = 1;
   my $linetotal = 0;
   my $totalnetweight = 0;
   for $i (1 .. $form->{rowcount} - 1){
      push(@{ $form->{runningnumber} }, $runningnumber++);
      push (@{ $form->{number} }, $form->{"partnumber_$i"});
      push (@{ $form->{descrip} }, $form->{"description_$i"});
      push (@{ $form->{description} }, $form->{"description_$i"});
      push (@{ $form->{unit} }, $form->{"unit_$i"});
      push (@{ $form->{qty} }, $form->format_amount($myconfig, $form->{"qty_$i"}, 2));
      push (@{ $form->{cost} }, $form->format_amount($myconfig, $form->{"cost_$i"}, 2));
      push (@{ $form->{netweight} }, $form->format_amount($myconfig, $form->{"weight_$i"} * $form->{"qty_$i"}, 2));

      $linetotal = $form->{"qty_$i"} * $form->{"cost_$i"};
      push (@{ $form->{linetotal} }, $form->format_amount($myconfig, $linetotal, 2));

      $form->{totalnetweight} += $form->{"weight_$i"} * $form->{"qty_$i"};
      $form->{trftotal} += $linetotal;
   }
   $form->{totalnetweight} = $form->format_amount($myconfig, $form->{totalnetweight}, 2);
   $form->{trftotal} = $form->format_amount($myconfig, $form->{trftotal}, 2);
}

sub retrieve_item {
  my ($self, $myconfig, $form) = @_;
  
  my $dbh = $form->dbconnect($myconfig);
  my $i = $form->{rowcount};
  my $var;
 
  my $where = "WHERE p.obsolete = '0' AND p.income_accno_id IS NOT NULL";
  if ($form->{"partnumber_$i"} ne ""){
    $var = $form->like(lc $form->{"partnumber_$i"});
    $where .= " AND LOWER(p.partnumber) LIKE '$var'";
  }
  if ($form->{"description_$i"} ne ""){
    $var = $form->like(lc $form->{"description_$i"});
    $where .= " AND LOWER(p.description) LIKE '$var'";
  }
  if ($form->{"partsgroup_$i"}){
     my ($null, $partsgroup_id) = split(/--/, $form->{"partsgroup_$i"});
     $partsgroup_id *= 1;
     $where .= " AND p.partsgroup_id = $partsgroup_id";
  }
  if ($form->{"description_$i"} ne ""){
    $where .= " ORDER BY 3";
  } else {
    $where .= " ORDER BY 2";
  }
  $onhandfld = 'p.onhand';
  if ($form->{from_warehouse_id}){
     $onhandfld = "(SELECT SUM(qty) FROM inventory i WHERE i.parts_id = p.id AND warehouse_id = $form->{from_warehouse_id}) AS onhand";
  }
  my $query = qq|SELECT p.id, p.partnumber, p.description, p.sellprice,
		p.listprice, p.lastcost, p.unit, p.assembly, $onhandfld,
		p.notes AS itemnotes, p.weight
		FROM parts p
		$where|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);
  while ($ref = $sth->fetchrow_hashref(NAME_lc)){
     push @{ $form->{item_list} }, $ref;
  }
  $sth->finish;
  $dbh->disconnect;
}

1;

