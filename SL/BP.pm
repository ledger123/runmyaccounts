#=====================================================================
# SQL-Ledger ERP
# Copyright (C) 2006
#
#  Author: DWS Systems Inc.
#     Web: http://www.sql-ledger.com
#
#======================================================================
#
# Batch printing module backend routines
#
#======================================================================

package BP;


sub get_vc {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);
  
  my %arap = ( invoice => { ar => customer, ap => vendor },
               remittance_voucher => { ar => customer },
               packing_list => { oe => customer, ar => customer, ap => vendor },
	       sales_order => { oe => customer },
	       work_order => { oe => customer },
	       pick_list => { oe => customer, ar => customer, ap => vendor },
	       purchase_order => { oe => vendor },
	       bin_list => { oe => customer, ar => customer, ap => vendor },
	       sales_quotation => { oe => customer },
	       request_quotation => { oe => vendor },
	       timecard => { jcitems => employee },
	       reminder => { ar => customer },
	     );
  
  my $query;
  my $sth;
  my $count;
  my $item;
  my $vc;
  my $wildcard;
  
  $form->{vc} = 'vendor' if $form->{vc} ne 'customer'; # SQLI protection
  # SQLI protection: $form->{type} needs to be validated
  if ($form->{batch} eq 'queue') {
    for (keys %{ $arap{$form->{type}} }) {
      $query = qq|
		SELECT count(*)
		FROM (SELECT DISTINCT vc.id
		      FROM $arap{$form->{type}}{$_} vc, $_ a, status s
		      WHERE a.$arap{$form->{type}}{$_}_id = vc.id
		      AND s.trans_id = a.id
		      AND s.formname LIKE '$wildcard$form->{type}'
		      AND s.spoolfile IS NOT NULL) AS total|;
      ($vc) = $dbh->selectrow_array($query);
      $form->{$arap{$form->{type}}{$_}} ||= $vc;
      if ($form->{type} eq 'invoice') {
	if ($form->{$arap{$form->{type}}{$_}}) {
	  if ($arap{$form->{type}}{$_} eq $form->{vc}) {
	    $count += $vc;
	  }
	}
      } else {
	$count += $vc;
      }
    }
  }

  # build selection list
  my $union = "";
  $query = "";
  if ($form->{batch} eq 'queue') {
    if (($count < $myconfig->{vclimit}) && $count) {
      foreach $item (keys %{ $arap{$form->{type}} }) {
	$query .= qq|
		    $union
		    SELECT DISTINCT ON (vc.name, vc.id) vc.id, vc.name, '$arap{$form->{type}}{$item}' AS vclabel
		    FROM $item a
		    JOIN $arap{$form->{type}}{$item} vc ON (a.$arap{$form->{type}}{$item}_id = vc.id)
		    JOIN status s ON (s.trans_id = a.id)
		    WHERE s.formname LIKE '$wildcard$form->{type}'
		    AND s.spoolfile IS NOT NULL|;
	$union = "UNION";
      }
      $query .= qq| ORDER BY 2, 1|;

      $sth = $dbh->prepare($query);
      $sth->execute || $form->dberror($query);

      while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
	push @{ $form->{"all_$ref->{vclabel}"} }, $ref;
      }
      $sth->finish;
    }
  } else {
    # get all vc or employee
    my $c;
    my $count;
    foreach $item (keys %{ $arap{$form->{type}} }) {
      $query = qq|SELECT count(*) FROM $arap{$form->{type}}{$item}|;
      ($c) = $dbh->selectrow_array($query);
      if ($form->{vc}) {
	if ($form->{vc} eq $arap{$form->{type}}{$item}) {
	  $count = $c;
	}
      } else {
	$count = ($count > $c) ? $count : $c;
      }
    }

    $query = "";
    if ($count < $myconfig->{vclimit}) {
	
      foreach $item (keys %{ $arap{$form->{type}} }) {
	$query .= qq|
		    $union
		    SELECT vc.id, vc.name,
		    '$arap{$form->{type}}{$item}' AS vclabel
		    FROM $arap{$form->{type}}{$item} vc|;
	$union = "UNION";
      }
      $query .= qq| ORDER BY 2, 1|;
      $sth = $dbh->prepare($query);
      $sth->execute || $form->dberror($query);
      while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
	push @{ $form->{"all_$ref->{vclabel}"} }, $ref;
	$form->{$ref->{vclabel}} = 1;
      }
      $sth->finish;
    } else {
      foreach $item (keys %{ $arap{$form->{type}} }) {
	$form->{$arap{$form->{type}}{$item}} = 1;
      }
    }

    $query = qq|SELECT *
		FROM paymentmethod
		ORDER BY rn|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);
    while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
      push @{ $form->{"all_paymentmethod"} }, $ref;
    }
    $sth->finish;
   
  }

  # get dispatch types
  $query = qq|SELECT *
              FROM dispatch
	      ORDER BY 1|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);
  
  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{all_dispatch} }, $ref;
  }
  $sth->finish;

  $form->all_years($myconfig, $dbh);

  if ($form->{type} =~ /(timecard|storescard)/) {
    $form->all_projects($myconfig, $dbh);
  }

  $dbh->disconnect;

  $count;
 
}

  
sub get_spoolfiles {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my %defaults = $form->get_defaults($dbh, \@{['precision']});
  for (keys %defaults) { $form->{$_} = $defaults{$_} }
    
  my $query;
  my $invnumber = "invnumber";
  my $item;
  my $var;
  my $wildcard = ($form->{type} eq 'invoice') ? '%' : '';
  
  my %arap = ( invoice => { ar => customer, ap => vendor },
               remittance_voucher => { ar => customer },
               packing_list => { oe => customer, ar => customer, ap => vendor },
	       sales_order => { oe => customer },
	       work_order => { oe => customer },
	       pick_list => { oe => customer, ar => customer, ap => vendor },
	       purchase_order => { oe => vendor },
	       bin_list => { oe => customer, ar => customer, ap => vendor },
	       sales_quotation => { oe => customer },
	       request_quotation => { oe => vendor },
	       reminder => { ar => customer },
	     );
 
  ($form->{transdatefrom}, $form->{transdateto}) = $form->from_to($form->{year}, $form->{month}, $form->{interval}) if $form->{year} && $form->{month};

  my $where;

  if ($form->{type} eq 'timecard') {
    my $dateformat = $myconfig->{dateformat};

    $dateformat =~ s/yy/yyyy/;
    $dateformat =~ s/yyyyyy/yyyy/;
    
    $invnumber = 'id';
    $where = "1=1";
    
    if ($form->{batch} eq 'queue') {

      $query = qq|SELECT j.id, e.name, e.employeenumber AS vcnumber,
                  j.id AS invnumber,
		  to_char(j.checkedin, '$dateformat') AS transdate,
		  '' AS ordnumber, '' AS quonumber, '0' AS invoice,
		  'jc' AS module, s.spoolfile, j.description,
		  j.sellprice * j.qty AS amount, e.city, e.id AS employee_id
		  FROM jcitems j
		  JOIN employee e ON (e.id = j.employee_id)
		  JOIN status s ON (s.trans_id = j.id)
		  WHERE s.formname = '$form->{type}'
		  AND s.spoolfile IS NOT NULL|;
		  
    } else {
      
      if ($form->{open} || $form->{closed}) {
	unless ($form->{open} && $form->{closed}) {
	  $where .= " AND j.qty != j.allocated" if $form->{open};
	  $where .= " AND j.qty = j.allocated" if $form->{closed};
	}
      }
     
      if ($form->{batch} eq 'print') {
	if (! ($form->{printed} && $form->{notprinted})) {
	  
	  if (! $form->{printed}) {
	    $not = "NOT";
	  }
	  
	  $where .= " AND $not j.id IN (SELECT s.trans_id
					FROM status s
					WHERE s.trans_id = j.id
					AND s.printed = '1'
					AND s.formname LIKE '$wildcard$form->{type}')";
	}
      }
      
      $query = qq|SELECT j.id, e.name, e.employeenumber AS vcnumber,
                  j.id AS invnumber,
		  to_char(j.checkedin, '$dateformat') AS transdate,
		  '' AS ordnumber, '' AS quonumber, '0' AS invoice,
		  'jc' AS module, '' AS spoolfile, j.description, 
		  j.sellprice * j.qty AS amount, e.city, e.id AS employee_id
		  FROM jcitems j
		  JOIN employee e ON (e.id = j.employee_id)
		  WHERE $where|;
    }

    my ($employee, $employee_id) = split /--/, $form->{employee};
    if ($employee_id) {
      $query .= qq| AND j.employee_id = $employee_id|;
    } else {
      if ($employee) {
	$item = $form->like(lc $employee);
	$query .= " AND lower(e.name) LIKE '$item'";
      }
    }
    if ($form->{description} ne "") {
      $item = $form->like(lc $form->{description});
      $query .= " AND lower(j.description) LIKE '$item'";
    }
    if ($form->{projectnumber} ne "") {
      ($item, $var) = split /--/, $form->{projectnumber};
      $query .= " AND j.project_id = $var";
    }

    $query .= " AND j.checkedin >= '$form->{transdatefrom}'" if $form->{transdatefrom};
    $query .= " AND j.checkedin < date '$form->{transdateto}' + 1" if $form->{transdateto};

  } else {
    
    foreach $item (keys %{ $arap{$form->{type}} }) {
      ($form->{$arap{$form->{type}}{$item}}, $form->{"$arap{$form->{type}}{$item}_id"}) = split /--/, $form->{$arap{$form->{type}}{$item}};
    }

    foreach $item (keys %{ $arap{$form->{type}} }) {

      $where = "1=1";
      
      $invoice = "a.invoice";
      $invnumber = "invnumber";
      
      if ($item eq 'oe') {
	$invnumber = "ordnumber";
	$invoice = "'0'";
	$where .= ($form->{type} =~ /_quotation/) ? " AND a.quotation = '1'" : " AND a.quotation = '0'";
      }

      if ($form->{"print$arap{$form->{type}}{$item}"} ne 'Y') {
	$form->{$arap{$form->{type}}{$item}} = "\r";
	$form->{"$arap{$form->{type}}{$item}_id"} = 0;
      }

      if ($form->{dispatch}){
         my ($null, $dispatch_id) = split /--/, $form->{dispatch};
         $dispatch_id *= 1;
         $where .= qq| AND vc.dispatch_id = $dispatch_id|;
      }

      if ($form->{type} eq 'remittance_voucher') {
	$where .= qq| AND vc.remittancevoucher = '1'|;

	if ($form->{paymentmethod}) {
	  ($var, $paymentmethod_id) = split /--/, $form->{paymentmethod};
	  $where .= qq| AND a.paymentmethod_id = $paymentmethod_id|;
	}
      }

      if ($form->{batch} eq 'queue') {
	$query .= qq|
		  $union
		  SELECT a.id, vc.name,
		  vc.$arap{$form->{type}}{$item}number AS vcnumber,
		  a.$invnumber AS invnumber, a.transdate,
		  a.ordnumber, a.quonumber, $invoice AS invoice,
		  '$item' AS module, s.spoolfile, a.description, a.amount,
		  ad.city, vc.email, vc.cc, '$arap{$form->{type}}{$item}' AS db,
		  vc.id AS vc_id
		  FROM $item a
		  JOIN $arap{$form->{type}}{$item} vc ON (a.$arap{$form->{type}}{$item}_id = vc.id)
		  JOIN address ad ON (ad.trans_id = vc.id)
		  JOIN status s ON (s.trans_id = a.id)
		  WHERE s.spoolfile IS NOT NULL
		  AND s.formname LIKE '$wildcard$form->{type}'
          AND $where|;
      } else {
	
	if ($item ne 'oe' && $form->{onhold}) {
	  $form->{open} = "Y";
	  $form->{closed} = "";
	  $where .= " AND a.onhold = '1'";
	}
	
	if ($item eq 'oe') {
	  if (!$form->{open} && !$form->{closed}) {
	    $where .= " AND a.id = 0";
	  } elsif (!($form->{open} && $form->{closed})) {
	    $where .= ($form->{open}) ? " AND a.closed = '0'" : " AND a.closed = '1'";
	  }
	} else {
	  $where .= " AND a.invoice = '1'";
	  if ($form->{open} || $form->{closed}) {
	    unless ($form->{open} && $form->{closed}) {
             $where .= " AND ROUND(a.amount::numeric,6) != ROUND(a.paid::numeric,6)" if ($form->{open});
             $where .= " AND ROUND(a.amount::numeric,6) = ROUND(a.paid::numeric,6)" if ($form->{closed});
	    }
	  }
	}

	if ($form->{batch} ne 'queue') {

	  if ($form->{printed} || $form->{notprinted} || $form->{emailed} || $form->{notemailed}) {
	    for (qw(printed emailed)) {
	      if ($form->{$_}) {
		if (!$form->{"not$_"}) {
		  $where .= qq| AND a.id IN (SELECT s.trans_id
					      FROM status s
					      WHERE s.trans_id = a.id
					      AND s.$_ = '1'
					      AND s.formname LIKE '$wildcard$form->{type}')|;
		}
	      }
	      if ($form->{"not$_"}) {
		if (!$form->{$_}) {
		  $where .= qq| AND NOT a.id IN (SELECT s.trans_id
					      FROM status s
					      WHERE s.trans_id = a.id
					      AND s.$_ = '1'
					      AND s.formname LIKE '$wildcard$form->{type}')|;
		}
	      }
	    }
	    } else {
	      $where .= qq| AND a.id = 0|;
	  }

	}

	$query .= qq|
		  $union
		  SELECT a.id, vc.name,
		  vc.$arap{$form->{type}}{$item}number AS vcnumber,
		  a.$invnumber AS invnumber, a.transdate,
		  a.ordnumber, a.quonumber, $invoice AS invoice,
		  '$item' AS module, '' AS spoolfile, a.description, a.amount,
		  '$arap{$form->{type}}{$item}' AS vc,
		  ad.city, vc.email, '$arap{$form->{type}}{$item}' AS db,
                  vc.id AS vc_id
		  FROM $item a
		  JOIN $arap{$form->{type}}{$item} vc ON (a.$arap{$form->{type}}{$item}_id = vc.id)
		  JOIN address ad ON (ad.trans_id = vc.id)
		  WHERE $where|;
      }

      if ($form->{$arap{$form->{type}}{$item}}) {
	if ($form->{"$arap{$form->{type}}{$item}_id"}) {
	  $query .= qq| AND a.$arap{$form->{type}}{$item}_id = $form->{"$arap{$form->{type}}{$item}_id"}|;
	} else {
      $form->{$arap{$form->{type}}{$item}} =~ s/^\s+|\s+$//g; # remove leading/trailing white space
	  $var = $form->like(lc $form->{$arap{$form->{type}}{$item}});
	  $query .= " AND lower(vc.name) LIKE '$var'";
	}
      }
      $form->{$arap{$form->{type}}{$item}} =~ s/^\r//;
      
      if ($form->{"$arap{$form->{type}}{$item}number"}) {
	$var = $form->like(lc $form->{"$arap{$form->{type}}{$item}number"});
	$query .= " AND lower(vc.$arap{$form->{type}}{$item}number) LIKE '$var'";
      }
     
      if ($form->{description} ne "") {
	$var = $form->like(lc $form->{description});
	$query .= " AND lower(a.description) LIKE '$var'";
      }
      if ($form->{invnumber} ne "") {
	$var = $form->like(lc $form->{invnumber});
	$query .= " AND lower(a.invnumber) LIKE '$var'";
      }
      if ($form->{ordnumber} ne "") {
	$var = $form->like(lc $form->{ordnumber});
	$query .= " AND lower(a.ordnumber) LIKE '$var'";
      }
      if ($form->{quonumber} ne "") {
	$var = $form->like(lc $form->{quonumber});
	$query .= " AND lower(a.quonumber) LIKE '$var'";
      }

      $query .= " AND a.transdate >= '$form->{transdatefrom}'" if $form->{transdatefrom};
      $query .= " AND a.transdate <= '$form->{transdateto}'" if $form->{transdateto};

      $union = "UNION";

    }
  }

  my %ordinal = ( name => 2,
                  vcnumber => 3,
                  invnumber => 4,
                  transdate => 5,
		  ordnumber => 6,
		  quonumber => 7,
		  description => 11
		);

  my @a = ();
  push @a, ("transdate", "$invnumber", "name");
  my $sortorder = $form->sort_order(\@a, \%ordinal);
  $query .= " ORDER by $sortorder";

  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{SPOOL} }, $ref;
  }
  
  $sth->finish;
  $dbh->disconnect;

}


sub zip_spool {
  my ($self, $myconfig, $form, $spool) = @_;

  my $fileid = time;
  my $tmpfile = "$form->{login}.$fileid.zip";

  foreach my $i (1 .. $form->{rowcount}) {
      $_ = qq|$spool/$form->{"spoolfile_$i"}|;
      if ($form->{"ndx_$i"}) {
	system("zip -q -u $spool/$tmpfile $_");
	#system("tar -cvf $spool/$tmpfile $_");
      }
  }
  
  open(IN, "$spool/$tmpfile");
  binmode(IN);

  print qq|Content-Type: application/zip
Content-Disposition: attachment; filename="$tmpfile"\n\n|;

  open(OUT, ">-");

  while (<IN>) {
     print OUT $_;
  }

  close(IN);
  close(OUT);
  unlink $spool/$tmpfile;
}


sub delete_spool {
  my ($self, $myconfig, $form, $spool) = @_;

  # connect to database, turn AutoCommit off
  my $dbh = $form->dbconnect_noauto($myconfig);

  my $query;
  my %audittrail;
  
  $query = qq|SELECT formname
              FROM status
	      WHERE spoolfile = ?|;
  my $fth = $dbh->prepare($query) || $form->dberror($query);
 
  $query = qq|UPDATE status SET
	      spoolfile = NULL
	      WHERE spoolfile = ?|;
  my $sth = $dbh->prepare($query) || $form->dberror($query);

  my $formname;
  
  foreach my $i (1 .. $form->{rowcount}) {
    if ($form->{"ndx_$i"}) {
      $fth->execute($form->{"spoolfile_$i"}) || $form->dberror;
      ($formname) = $fth->fetchrow_array;
      $fth->finish;
      
      $sth->execute($form->{"spoolfile_$i"}) || $form->dberror;
      $sth->finish;
      
      %audittrail = ( tablename  => $form->{module},
                      reference  => $form->{"reference_$i"},
		      formname   => $formname,
		      action     => 'dequeued',
		      id         => $form->{"id_$i"} );
 
      $form->audittrail($dbh, "", \%audittrail);
    }
  }
    
  # commit
  my $rc = $dbh->commit;
  $dbh->disconnect;

  if ($rc) {
    foreach my $i (1 .. $form->{rowcount}) {
      $_ = qq|$spool/$form->{"spoolfile_$i"}|;
      if ($form->{"ndx_$i"}) {
	unlink;
      }
    }
  }

  $rc;
  
}


sub print_spool {
  my ($self, $myconfig, $form, $spool) = @_;

  # connect to database
  my $dbh = $form->dbconnect_noauto($myconfig);

  my $query;
  my %audittrail;
  
  $query = qq|SELECT formname
              FROM status
	      WHERE spoolfile = ?|;
  my $fth = $dbh->prepare($query) || $form->dberror($query);
    
  $query = qq|UPDATE status SET
	      printed = '1'
              WHERE spoolfile = ?|;
  my $sth = $dbh->prepare($query) || $form->dberror($query);
  
  my $formname;
  
  open(OUT, $form->{OUT}) or $form->error("$form->{OUT} : $!");
  binmode(OUT);
  
  $spoolfile = qq|$spool/$form->{spoolfile}|;
  
  # send file to printer
  open(IN, $spoolfile) or $form->error("$spoolfile : $!");
  binmode(IN);

  while (<IN>) {
    print OUT $_;
  }
  close(IN);
  close(OUT);
  
  $fth->execute($form->{spoolfile}) || $form->dberror;
  ($formname) = $fth->fetchrow_array;
  $fth->finish;

  $sth->execute($form->{spoolfile}) || $form->dberror;
  $sth->finish;
  
  %audittrail = ( tablename  => $form->{module},
		  reference  => $form->{reference},
		  formname   => $formname,
		  action     => 'printed',
		  id         => $form->{id} );

  $form->audittrail($dbh, "", \%audittrail);
  
  my $rc = $dbh->commit;

  $dbh->disconnect;

  $rc;

}


1;

