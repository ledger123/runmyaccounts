#=====================================================================
# SQL-Ledger ERP
# Copyright (c) 2006
#
#  Author: DWS Systems Inc.
#     Web: http://www.sql-ledger.com
#
#======================================================================
#
# Administration module
#    Chart of Accounts
#    template routines
#    preferences
#
#======================================================================

package AM;

use Time::Local;

sub get_account {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  $form->{id} *= 1;

  my $query = qq|SELECT accno, description, charttype, gifi_accno,
                 category, link, contra, allow_gl
                 FROM chart
	         WHERE id = $form->{id}|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  my $ref = $sth->fetchrow_hashref(NAME_lc);
  for (keys %$ref) { $form->{$_} = $ref->{$_} }
  $sth->finish;

  # get default accounts
  my %defaults = $form->get_defaults($dbh, \@{['%accno_id']});
  for (keys %defaults) { $form->{$_} = $defaults{$_} }

  # check if we have any transactions
  $query = qq|SELECT trans_id FROM acc_trans
              WHERE chart_id = $form->{id}|;
  ($form->{orphaned}) = $dbh->selectrow_array($query);
  $form->{orphaned} = !$form->{orphaned};

  $dbh->disconnect;

}


sub save_account {
  my ($self, $myconfig, $form) = @_;

  # connect to database, turn off AutoCommit
  my $dbh = $form->dbconnect_noauto($myconfig);

  $form->{link} = "";
  foreach my $item ($form->{AR},
		    $form->{AR_amount},
                    $form->{AR_tax},
                    $form->{AR_paid},
		    $form->{AR_discount},
                    $form->{AP},
		    $form->{AP_amount},
		    $form->{AP_tax},
		    $form->{AP_paid},
		    $form->{AP_discount},
		    $form->{IC},
		    $form->{IC_income},
		    $form->{IC_sale},
		    $form->{IC_expense},
		    $form->{IC_cogs},
		    $form->{IC_taxpart},
		    $form->{IC_taxservice},
		    ) {
     $form->{link} .= "${item}:" if ($item);
  }
  chop $form->{link};

  # strip blanks from accno
  for (qw(accno gifi_accno)) { $form->{$_} =~ s/( |')//g }

  foreach my $item (qw(accno gifi_accno description)) {
    $form->{$item} =~ s/-(-+)/-/g;
    $form->{$item} =~ s/ ( )+/ /g;
    $form->{$item} =~ s/^\s+//;
    $form->{$item} =~ s/\s+$//;
  }

  my $query;
  my $sth;

  $form->{contra} *= 1;
  $form->{allow_gl} *= 1;

  # if we have an id then replace the old record
  if ($form->{id} *= 1) {
    $query = qq|UPDATE chart SET
                accno = '$form->{accno}',
		description = |.$dbh->quote($form->{description}).qq|,
		charttype = |.$dbh->quote($form->{charttype}).qq|,
		gifi_accno = '$form->{gifi_accno}',
		category = |.$dbh->quote($form->{category}).qq|,
		link = |.$dbh->quote($form->{link}).qq|,
		contra = |.$dbh->quote($form->{contra}).qq|,
		allow_gl = |.$dbh->quote($form->{allow_gl}).qq|
		WHERE id = $form->{id}|;
  } else {
    $query = qq|INSERT INTO chart
                (accno, description, charttype, gifi_accno, category, link,
		contra, allow_gl)
                VALUES ('$form->{accno}',|
		.$dbh->quote($form->{description}).qq|,
		|.$dbh->quote($form->{charttype}).qq|, |
		.$dbh->quote($form->{gifi_accno}).qq|,
		|.$dbh->quote($form->{category}).qq|, |.$dbh->quote($form->{link}).qq|, |.$dbh->quote($form->{contra}).qq|, |.$dbh->quote($form->{allow_gl}).qq|)|;
  }
  $dbh->do($query) || $form->dberror($query);


  $chart_id = $form->{id};

  if (! $form->{id}) {
    # get id from chart
    $query = qq|SELECT id
		FROM chart
		WHERE accno = '$form->{accno}'|;
    ($chart_id) = $dbh->selectrow_array($query);
  }

  if ($form->{IC_taxpart} || $form->{IC_taxservice} || $form->{AR_tax} || $form->{AP_tax}) {

    # add account if it doesn't exist in tax
    $query = qq|SELECT chart_id
                FROM tax
		WHERE chart_id = $chart_id|;
    my ($tax_id) = $dbh->selectrow_array($query);

    # add tax if it doesn't exist
    unless ($tax_id) {
      $query = qq|INSERT INTO tax (chart_id, rate)
                  VALUES ($chart_id, 0)|;
      $dbh->do($query) || $form->dberror($query);
    }
  } else {
    # remove tax
    if ($form->{id}) {
      $query = qq|DELETE FROM tax
		  WHERE chart_id = $form->{id}|;
      $dbh->do($query) || $form->dberror($query);
    }
  }

  # commit
  my $rc = $dbh->commit;
  $dbh->disconnect;

  $rc;

}



sub delete_account {
  my ($self, $myconfig, $form) = @_;

  # connect to database, turn off AutoCommit
  my $dbh = $form->dbconnect_noauto($myconfig);

  my $query;

  # set inventory_accno_id, income_accno_id, expense_accno_id to defaults
  my %defaults = $form->get_defaults($dbh, \@{['%_accno_id']});

  $form->{id} *= 1;

  for (qw(inventory_accno_id income_accno_id expense_accno_id)) {
    $query = qq|SELECT count(*)
                FROM parts
		WHERE $_ = $defaults{$_}|;
    if ($dbh->selectrow_array($query)) {
      if ($defaults{$_}) {
	$query = qq|UPDATE parts
	            SET $_ = $defaults{$_}
		    WHERE $_ = $form->{id}|;
        $dbh->do($query) || $form->dberror($query);
      } else {
	$dbh->disconnect;
	return;
      }
    }
  }

  # delete chart of account record
  $query = qq|DELETE FROM chart
              WHERE id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

  $query = qq|DELETE FROM bank
              WHERE id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

  $query = qq|DELETE FROM address
              WHERE trans_id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

  $query = qq|DELETE FROM translation
              WHERE trans_id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

  foreach my $table (qw(partstax customertax vendortax tax)) {
    $query = qq|DELETE FROM $table
		WHERE chart_id = $form->{id}|;
    $dbh->do($query) || $form->dberror($query);
  }

  # commit and redirect
  my $rc = $dbh->commit;
  $dbh->disconnect;

  $rc;

}


sub gifi_accounts {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query = qq|SELECT accno, description
                 FROM gifi
		 ORDER BY accno|;

  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{ALL} }, $ref;
  }
  $sth->finish;

  $dbh->disconnect;

}



sub get_gifi {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query = qq|SELECT accno, description
                 FROM gifi
	         WHERE accno = |.$dbh->quote($form->{accno});

  ($form->{accno}, $form->{description}) = $dbh->selectrow_array($query);

  # check for transactions
  $query = qq|SELECT * FROM acc_trans a
              JOIN chart c ON (a.chart_id = c.id)
	      JOIN gifi g ON (c.gifi_accno = g.accno)
	      WHERE g.accno = |.$dbh->quote($form->{accno});
  ($form->{orphaned}) = $dbh->selectrow_array($query);
  $form->{orphaned} = !$form->{orphaned};

  $dbh->disconnect;

}


sub save_gifi {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  $form->{accno} =~ s/( |')//g;

  foreach my $item (qw(accno description)) {
    $form->{$item} =~ s/-(-+)/-/g;
    $form->{$item} =~ s/ ( )+/ /g;
  }

  # id is the old account number!
  if ($form->{id} *= 1) {
    $query = qq|UPDATE gifi SET
                accno = '$form->{accno}',
		description = |.$dbh->quote($form->{description}).qq|
		WHERE accno = '$form->{id}'|;
  } else {
    $query = qq|INSERT INTO gifi
                (accno, description)
                VALUES (|
		.$dbh->quote($form->{accno}).qq|,|
		.$dbh->quote($form->{description}).qq|)|;
  }
  $dbh->do($query) || $form->dberror;

  $dbh->disconnect;

}


sub delete_gifi {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  # id is the old account number!
  $query = qq|DELETE FROM gifi
	      WHERE accno = |.$dbh->quote($form->{id});
  $dbh->do($query) || $form->dberror($query);

  $dbh->disconnect;

}


sub warehouses {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  # SQLI protection. $form->{direction} variable needs to be investigated.

  $form->sort_order();
  my $query = qq|SELECT w.id, w.description,
                 a.address1, a.address2, a.city, a.state, a.zipcode, a.country
                 FROM warehouse w
		 JOIN address a ON (a.trans_id = w.id)
		 ORDER BY 2 $form->{direction}|;

  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{ALL} }, $ref;
  }
  $sth->finish;

  $dbh->disconnect;

}



sub get_warehouse {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  $form->{id} *= 1;

  my $query = qq|SELECT w.description, a.address1, a.address2, a.city,
                 a.state, a.zipcode, a.country
                 FROM warehouse w
		 JOIN address a ON (a.trans_id = w.id)
	         WHERE w.id = $form->{id}|;
  my $sth = $dbh->prepare($query) || $form->dberror($query);
  $sth->execute;

  my $ref = $sth->fetchrow_hashref(NAME_lc);
  for (keys %$ref) { $form->{$_} = $ref->{$_} }
  $sth->finish;

  # see if it is in use
  $query = qq|SELECT * FROM inventory
              WHERE warehouse_id = $form->{id}|;
  ($form->{orphaned}) = $dbh->selectrow_array($query);
  $form->{orphaned} = !$form->{orphaned};

  $dbh->disconnect;

}


sub save_warehouse {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect_noauto($myconfig);

  $form->{description} =~ s/-(-)+/-/g;
  $form->{description} =~ s/ ( )+/ /g;

  if ($form->{id} *= 1) {
    $query = qq|SELECT id
                FROM warehouse
		WHERE id = $form->{id}|;
    ($form->{id}) = $dbh->selectrow_array($query);
  }

  if (!$form->{id}) {
    $uid = localtime;
    $uid .= $$;

    $query = qq|INSERT INTO warehouse (description)
                VALUES ('$uid')|;
    $dbh->do($query) || $form->dberror($query);

    $query = qq|SELECT id
                FROM warehouse
		WHERE description = '$uid'|;
    ($form->{id}) = $dbh->selectrow_array($query);

    $query = qq|INSERT INTO address (trans_id)
                VALUES ($form->{id})|;
    $dbh->do($query) || $form->dberror($query);

  }

  $query = qq|UPDATE warehouse SET
	      description = |.$dbh->quote($form->{description}).qq|
	      WHERE id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

  $query = qq|UPDATE address SET
              address1 = |.$dbh->quote($form->{address1}).qq|,
              address2 = |.$dbh->quote($form->{address2}).qq|,
              city = |.$dbh->quote($form->{city}).qq|,
              state = |.$dbh->quote($form->{state}).qq|,
              zipcode = |.$dbh->quote($form->{zipcode}).qq|,
              country = |.$dbh->quote($form->{country}).qq|
	      WHERE trans_id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

  my $rc = $dbh->commit;
  $dbh->disconnect;

  $rc;

}


sub delete_warehouse {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect_noauto($myconfig);

  $form->{id} *= 1;

  my $query = qq|DELETE FROM warehouse
	      WHERE id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

  $query = qq|DELETE FROM address
	      WHERE trans_id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

  my $rc = $dbh->commit;
  $dbh->disconnect;

  $rc;

}



sub departments {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  $form->sort_order();
  my $query = qq|SELECT id, description, role
                 FROM department
		 ORDER BY 2 $form->{direction}|;

  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{ALL} }, $ref;
  }
  $sth->finish;

  $dbh->disconnect;

}



sub get_department {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  $form->{id} *= 1;

  my $query = qq|SELECT description, role
                 FROM department
	         WHERE id = $form->{id}|;
  ($form->{description}, $form->{role}) = $dbh->selectrow_array($query);

  # see if it is in use
  $query = qq|SELECT * FROM dpt_trans
              WHERE department_id = $form->{id}|;
  ($form->{orphaned}) = $dbh->selectrow_array($query);
  $form->{orphaned} = !$form->{orphaned};

  $dbh->disconnect;

}


sub save_department {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  $form->{description} =~ s/-(-)+/-/g;
  $form->{description} =~ s/ ( )+/ /g;

  if ($form->{id} *= 1) {
    $query = qq|UPDATE department SET
		description = |.$dbh->quote($form->{description}).qq|,
		role = |.$dbh->quote($form->{role}).qq|
		WHERE id = $form->{id}|;
  } else {
    $query = qq|INSERT INTO department
                (description, role)
                VALUES (|
		.$dbh->quote($form->{description}).qq|, |.$dbh->quote($form->{role}).qq|)|;
  }
  $dbh->do($query) || $form->dberror($query);

  $dbh->disconnect;

}


sub delete_department {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  $form->{id} *= 1;

  $query = qq|DELETE FROM department
	      WHERE id = $form->{id}|;
  $dbh->do($query);

  $dbh->disconnect;

}


sub business {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  $form->sort_order();
  my $query = qq|SELECT id, description, discount
                 FROM business
		 ORDER BY 2 $form->{direction}|;

  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{ALL} }, $ref;
  }
  $sth->finish;

  $dbh->disconnect;

}



sub get_business {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  $form->{id} *= 1;

  my $query = qq|SELECT description, discount
                 FROM business
	         WHERE id = $form->{id}|;
  ($form->{description}, $form->{discount}) = $dbh->selectrow_array($query);

  $dbh->disconnect;

}


sub save_business {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  $form->{description} =~ s/-(-)+/-/g;
  $form->{description} =~ s/ ( )+/ /g;
  $form->{discount} /= 100;

  if ($form->{id} *= 1) {
    $query = qq|UPDATE business SET
		description = |.$dbh->quote($form->{description}).qq|,
		discount = $form->{discount}
		WHERE id = $form->{id}|;
  } else {
    $query = qq|INSERT INTO business
                (description, discount)
		VALUES (|
		.$dbh->quote($form->{description}).qq|, $form->{discount})|;
  }
  $dbh->do($query) || $form->dberror($query);

  $dbh->disconnect;

}


sub delete_business {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  $form->{id} *= 1;

  $query = qq|DELETE FROM business
	      WHERE id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

  $dbh->disconnect;

}

sub dispatch {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  $form->sort_order();
  my $query = qq|SELECT id, description
                 FROM dispatch
		 ORDER BY 1 $form->{direction}|;

  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{ALL} }, $ref;
  }
  $sth->finish;

  $dbh->disconnect;

}



sub get_dispatch {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  $form->{id} *= 1;

  my $query = qq|SELECT description
                 FROM dispatch
	         WHERE id = $form->{id}|;
  ($form->{description}) = $dbh->selectrow_array($query);

  $dbh->disconnect;

}


sub save_dispatch {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  $form->{description} =~ s/-(-)+/-/g;
  $form->{description} =~ s/ ( )+/ /g;

  if ($form->{id} *= 1) {
    $query = qq|UPDATE dispatch SET
		description = |.$dbh->quote($form->{description}).qq|
		WHERE id = $form->{id}|;
  } else {
    $query = qq|INSERT INTO dispatch
                (description)
		VALUES (|
		.$dbh->quote($form->{description}).qq|)|;
  }
  $dbh->do($query) || $form->dberror($query);

  $dbh->disconnect;

}


sub delete_dispatch {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  $form->{id} *= 1;

  $query = qq|DELETE FROM dispatch
	      WHERE id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

  $dbh->disconnect;

}


sub paymentmethod {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my %defaults = $form->get_defaults($dbh, \@{['precision']});
  for (keys %defaults) { $form->{$_} = $defaults{$_} }

  $form->{sort} ||= "rn";

  my @a = qw(description rn);
  my %ordinal = ( description	=> 2,
                  rn		=> 4 );
  my $sortorder = $form->sort_order(\@a, \%ordinal);

  my $query = qq|SELECT *
                 FROM paymentmethod
		 ORDER BY $sortorder|;

  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{ALL} }, $ref;
  }
  $sth->finish;

  $dbh->disconnect;

}



sub get_paymentmethod {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  $form->{id} *= 1;

  my $query = qq|SELECT description, fee
                 FROM paymentmethod
	         WHERE id = $form->{id}|;
  ($form->{description}, $form->{fee}) = $dbh->selectrow_array($query);

  $dbh->disconnect;

}


sub save_paymentmethod {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  $form->{description} =~ s/-(-)+/-/g;
  $form->{description} =~ s/ ( )+/ /g;

  if ($form->{id} *= 1) {
    $query = qq|UPDATE paymentmethod SET
		description = |.$dbh->quote($form->{description}).qq|,
		fee = |.$form->parse_amount($myconfig, $form->{fee}).qq|
		WHERE id = $form->{id}|;
  } else {
    $query = qq|SELECT MAX(rn) FROM paymentmethod|;
    my ($rn) = $dbh->selectrow_array($query);
    $rn++;

    $query = qq|INSERT INTO paymentmethod
                (rn, description, fee)
		VALUES ($rn, |
		.$dbh->quote($form->{description}).qq|, |.
		$form->parse_amount($myconfig, $form->{fee}).qq|)|;
  }
  $dbh->do($query) || $form->dberror($query);

  $dbh->disconnect;

}


sub delete_paymentmethod {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect_noauto($myconfig);

  $form->{id} *= 1;

  my $query = qq|SELECT rn FROM paymentmethod
                 WHERE id = $form->{id}|;
  my ($rn) = $dbh->selectrow_array($query);

  $query = qq|UPDATE paymentmethod SET rn = rn - 1
              WHERE rn > $rn|;
  $dbh->do($query) || $form->dberror($query);

  $query = qq|DELETE FROM paymentmethod
	      WHERE id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

  $dbh->commit;

  $dbh->disconnect;

}


sub sic {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  $form->{sort} = "code" unless $form->{sort};
  my @a = qw(code description);
  my %ordinal = ( code		=> 1,
                  description	=> 3 );
  my $sortorder = $form->sort_order(\@a, \%ordinal);
  my $query = qq|SELECT code, sictype, description
                 FROM sic
		 ORDER BY $sortorder|;

  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{ALL} }, $ref;
  }
  $sth->finish;

  $dbh->disconnect;

}



sub get_sic {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query = qq|SELECT code, sictype, description
                 FROM sic
	         WHERE code = |.$dbh->quote($form->{code});
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  my $ref = $sth->fetchrow_hashref(NAME_lc);
  for (keys %$ref) { $form->{$_} = $ref->{$_} }
  $sth->finish;

  $dbh->disconnect;

}


sub save_sic {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  foreach my $item (qw(code description)) {
    $form->{$item} =~ s/-(-)+/-/g;
  }

  # if there is an id
  if ($form->{id}) {
    $query = qq|UPDATE sic SET
                code = |.$dbh->quote($form->{code}).qq|,
		sictype = |.$dbh->quote($form->{sictype}).qq|,
		description = |.$dbh->quote($form->{description}).qq|
		WHERE code = |.$dbh->quote($form->{id});
  } else {
    $query = qq|INSERT INTO sic
                (code, sictype, description)
                VALUES (|
		.$dbh->quote($form->{code}).qq|,
		|.$dbh->quote($form->{sictype}).qq|,|
		.$dbh->quote($form->{description}).qq|)|;
  }
  $dbh->do($query) || $form->dberror($query);

  $dbh->disconnect;

}


sub delete_sic {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  $query = qq|DELETE FROM sic
	      WHERE code = |.$dbh->quote($form->{code});
  $dbh->do($query);

  $dbh->disconnect;

}


sub language {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  $form->{sort} = "code" unless $form->{sort};
  my @a = qw(code description);
  my %ordinal = ( code		=> 1,
                  description	=> 2 );
  my $sortorder = $form->sort_order(\@a, \%ordinal);

  my $query = qq|SELECT code, description
                 FROM language
		 ORDER BY $sortorder|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{ALL} }, $ref;
  }
  $sth->finish;

  $dbh->disconnect;

}



sub get_language {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query = qq|SELECT *
                 FROM language
	         WHERE code = |.$dbh->quote($form->{code});
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  my $ref = $sth->fetchrow_hashref(NAME_lc);
  for (keys %$ref) { $form->{$_} = $ref->{$_} }
  $sth->finish;

  $dbh->disconnect;

}


sub save_language {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  $form->{code} =~ s/ //g;
  foreach my $item (qw(code description)) {
    $form->{$item} =~ s/-(-)+/-/g;
    $form->{$item} =~ s/ ( )+/-/g;
  }

  # if there is an id
  if ($form->{id}) {
    $query = qq|UPDATE language SET
                code = |.$dbh->quote($form->{code}).qq|,
		description = |.$dbh->quote($form->{description}).qq|
		WHERE code = |.$dbh->quote($form->{id});
  } else {
    $query = qq|INSERT INTO language
                (code, description)
                VALUES (|
		.$dbh->quote($form->{code}).qq|,|
		.$dbh->quote($form->{description}).qq|)|;
  }
  $dbh->do($query) || $form->dberror($query);

  $dbh->disconnect;

}


sub delete_language {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  $query = qq|DELETE FROM language
	      WHERE code = |.$dbh->quote($form->{code});
  $dbh->do($query) || $form->dberror($query);

  $dbh->disconnect;

}


sub recurring_transactions {
  my ($self, $myconfig, $form) = @_;

  my $dbh = $form->dbconnect($myconfig);

  my %defaults = $form->get_defaults($dbh, \@{['precision', 'company']});
  for (keys %defaults) { $form->{$_} = $defaults{$_} }

  my %ordinal = ( reference => 10,
                  department => 26,
                  description => 4,
		  name => 5,
		  vcnumber => 6,
		  nextdate => 12,
		  enddate => 13 );

  $form->{sort} ||= "nextdate";
  my @a = ($form->{sort});
  my $sortorder = $form->sort_order(\@a, \%ordinal);

  # get default currency
  $query = qq|SELECT curr FROM curr
              ORDER BY rn|;
  my ($defaultcurrency) = $dbh->selectrow_array($query);

  $query = qq|SELECT 'ar' AS module, 'ar' AS transaction, a.invoice,
                 a.description, n.name, n.customernumber AS vcnumber,
		 n.id AS name_id, a.amount, s.*, se.formname AS recurringemail,
                 sp.formname AS recurringprint,
		 s.nextdate - current_date AS overdue, 'customer' AS vc,
		 ex.buy AS exchangerate, a.curr,
		 (s.nextdate IS NULL OR s.nextdate > s.enddate) AS expired, d.description AS department
                 FROM recurring s
		 JOIN ar a ON (a.id = s.id)
         LEFT JOIN department d ON (d.id = a.department_id)
		 JOIN customer n ON (n.id = a.customer_id)
                 LEFT JOIN recurringemail se ON (se.id = s.id)
                 LEFT JOIN recurringprint sp ON (sp.id = s.id)
		 LEFT JOIN exchangerate ex ON
		      (ex.curr = a.curr AND a.transdate = ex.transdate)

	 UNION

                 SELECT 'ap' AS module, 'ap' AS transaction, a.invoice,
		 a.description, n.name, n.vendornumber AS vcnumber,
		 n.id AS name_id, a.amount, s.*, se.formname AS recurringemail,
                 sp.formname AS recurringprint,
		 s.nextdate - current_date AS overdue, 'vendor' AS vc,
		 ex.sell AS exchangerate, a.curr,
		 (s.nextdate IS NULL OR s.nextdate > s.enddate) AS expired, d.description AS department
                 FROM recurring s
		 JOIN ap a ON (a.id = s.id)
         LEFT JOIN department d ON (d.id = a.department_id)
		 JOIN vendor n ON (n.id = a.vendor_id)
                 LEFT JOIN recurringemail se ON (se.id = s.id)
                 LEFT JOIN recurringprint sp ON (sp.id = s.id)
		 LEFT JOIN exchangerate ex ON
		      (ex.curr = a.curr AND a.transdate = ex.transdate)

	 UNION

                 SELECT 'gl' AS module, 'gl' AS transaction, FALSE AS invoice,
		 a.description, '' AS name, '' AS vcnumber, 0 AS name_id,
		 (SELECT SUM(ac.amount) FROM acc_trans ac WHERE ac.trans_id = a.id AND ac.amount > 0) AS amount,
                 s.*, se.formname AS recurringemail,
                 sp.formname AS recurringprint,
		 s.nextdate - current_date AS overdue, '' AS vc,
		 '1' AS exchangerate, '$defaultcurrency' AS curr,
		 (s.nextdate IS NULL OR s.nextdate > s.enddate) AS expired, d.description AS department
                 FROM recurring s
		 JOIN gl a ON (a.id = s.id)
         LEFT JOIN department d ON (d.id = a.department_id)
                 LEFT JOIN recurringemail se ON (se.id = s.id)
                 LEFT JOIN recurringprint sp ON (sp.id = s.id)

	UNION

                 SELECT 'oe' AS module, 'so' AS transaction, FALSE AS invoice,
		 a.description, n.name, n.customernumber AS vcnumber,
		 n.id AS name_id, a.amount, s.*, se.formname AS recurringemail,
                 sp.formname AS recurringprint,
		 s.nextdate - current_date AS overdue, 'customer' AS vc,
		 ex.buy AS exchangerate, a.curr,
		 (s.nextdate IS NULL OR s.nextdate > s.enddate) AS expired, d.description AS department
                 FROM recurring s
		 JOIN oe a ON (a.id = s.id)
         LEFT JOIN department d ON (d.id = a.department_id)
		 JOIN customer n ON (n.id = a.customer_id)
                 LEFT JOIN recurringemail se ON (se.id = s.id)
                 LEFT JOIN recurringprint sp ON (sp.id = s.id)
		 LEFT JOIN exchangerate ex ON
		      (ex.curr = a.curr AND a.transdate = ex.transdate)
		 WHERE a.quotation = '0'

	UNION

                 SELECT 'oe' AS module, 'po' AS transaction, FALSE AS invoice,
		 a.description, n.name, n.vendornumber AS vcnumber,
		 n.id AS name_id, a.amount, s.*, se.formname AS recurringemail,
                 sp.formname AS recurringprint,
		 s.nextdate - current_date AS overdue, 'vendor' AS vc,
		 ex.sell AS exchangerate, a.curr,
		 (s.nextdate IS NULL OR s.nextdate > s.enddate) AS expired, d.description AS department
                 FROM recurring s
		 JOIN oe a ON (a.id = s.id)
         LEFT JOIN department d ON (d.id = a.department_id)
		 JOIN vendor n ON (n.id = a.vendor_id)
                 LEFT JOIN recurringemail se ON (se.id = s.id)
                 LEFT JOIN recurringprint sp ON (sp.id = s.id)
		 LEFT JOIN exchangerate ex ON
		      (ex.curr = a.curr AND a.transdate = ex.transdate)
		 WHERE a.quotation = '0'

		 ORDER BY $sortorder|;

  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  my $id;
  my $transaction;
  my %e = ();
  my %p = ();

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {

    $ref->{exchangerate} ||= 1;

    if ($ref->{id} != $id) {

      if (%e) {
	$form->{transactions}{$transaction}->[$i]->{recurringemail} = "";
	for (keys %e) { $form->{transactions}{$transaction}->[$i]->{recurringemail} .= "${_}:" }
	chop $form->{transactions}{$transaction}->[$i]->{recurringemail};
      }
      if (%p) {
	$form->{transactions}{$transaction}->[$i]->{recurringprint} = "";
	for (keys %p) { $form->{transactions}{$transaction}->[$i]->{recurringprint} .= "${_}:" }
	chop $form->{transactions}{$transaction}->[$i]->{recurringprint};
      }

      %e = ();
      %p = ();

      push @{ $form->{transactions}{$ref->{transaction}} }, $ref;

      $id = $ref->{id};
      $i = $#{ $form->{transactions}{$ref->{transaction}} };

    }

    $transaction = $ref->{transaction};

    $e{$ref->{recurringemail}} = 1 if $ref->{recurringemail};
    $p{$ref->{recurringprint}} = 1 if $ref->{recurringprint};

  }
  $sth->finish;

  # this is for the last row
  if (%e) {
    $form->{transactions}{$transaction}->[$i]->{recurringemail} = "";
    for (keys %e) { $form->{transactions}{$transaction}->[$i]->{recurringemail} .= "${_}:" }
    chop $form->{transactions}{$transaction}->[$i]->{recurringemail};
  }
  if (%p) {
    $form->{transactions}{$transaction}->[$i]->{recurringprint} = "";
    for (keys %p) { $form->{transactions}{$transaction}->[$i]->{recurringprint} .= "${_}:" }
    chop $form->{transactions}{$transaction}->[$i]->{recurringprint};
  }


  $dbh->disconnect;

}


sub recurring_details {
  my ($self, $myconfig, $form, $id) = @_;

  my $dbh = $form->dbconnect($myconfig);

  my $query = qq~SELECT s.*, ar.id AS arid, ar.invoice AS arinvoice,
                 ap.id AS apid, ap.invoice AS apinvoice,
		 ar.duedate - ar.transdate AS overdue,
		 ar.datepaid - ar.transdate AS paid,
		 oe.reqdate - oe.transdate AS req,
		 oe.id AS oeid, oe.customer_id, oe.vendor_id
                 FROM recurring s
                 LEFT JOIN ar ON (ar.id = s.id)
		 LEFT JOIN ap ON (ap.id = s.id)
		 LEFT JOIN oe ON (oe.id = s.id)
                 WHERE s.id = $id~;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  my $ref = $sth->fetchrow_hashref(NAME_lc);
  $form->{vc} = "customer" if $ref->{customer_id};
  $form->{vc} = "vendor" if $ref->{vendor_id};
  for (keys %$ref) { $form->{$_} = $ref->{$_} }
  $sth->finish;

  $form->{invoice} = ($form->{arid} && $form->{arinvoice});
  $form->{invoice} = ($form->{apid} && $form->{apinvoice}) unless $form->{invoice};

  $query = qq|SELECT * FROM recurringemail
              WHERE id = $id|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  $form->{recurringemail} = "";
  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    $form->{recurringemail} .= "$ref->{formname}:$ref->{format}:";
    $form->{message} = $ref->{message};
  }
  $sth->finish;

  $query = qq|SELECT * FROM recurringprint
              WHERE id = $id|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  $form->{recurringprint} = "";
  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    $form->{recurringprint} .= "$ref->{formname}:$ref->{format}:$ref->{printer}:";
  }
  $sth->finish;

  chop $form->{recurringemail};
  chop $form->{recurringprint};

  for (qw(arinvoice apinvoice)) { delete $form->{$_} }

  $dbh->disconnect;

}


sub update_recurring {
  my ($self, $myconfig, $form, $id) = @_;

  my $dbh = $form->dbconnect($myconfig);

  my $query = qq|SELECT repeat, unit
                 FROM recurring
		 WHERE id = $id|;
  my ($repeat, $unit) = $dbh->selectrow_array($query);

  my %advance = ( 'Pg' => qq|(date '$form->{nextdate}' + interval '$repeat $unit')|,
              'Sybase' => qq|dateadd($myconfig->{dateformat}, $repeat $unit, $form->{nextdate})|,
                 'DB2' => qq|(date ('$form->{nextdate}') + "$repeat $unit")|,
		 );
  for (qw(PgPP Oracle)) { $interval{$_} = $interval{Pg} }

  # check if it is the last date
  $query = qq|SELECT $advance{$myconfig->{dbdriver}} > enddate
              FROM recurring
	      WHERE id = $id|;
  my ($last_repeat) = $dbh->selectrow_array($query);
  if ($last_repeat) {
    $advance{$myconfig->{dbdriver}} = "NULL";
  }

  $query = qq|UPDATE recurring SET
              nextdate = $advance{$myconfig->{dbdriver}}
	      WHERE id = $id|;
  $dbh->do($query) || $form->dberror($query);

  $dbh->disconnect;

}

sub check_access {
	my ($self, $form, $folders, $errormessage) = @_;

	$errormessage ||= 'Access Denied!';
	$form->error("$form->{file}: $errormessage") unless @$folders;
	my $folderstring = join "|^", @$folders;
	$_ = $form->{file};
	s|\w+/\.\./||;
	s|~||g;
	s|\.+/||g;
	s|//|/|g;
	$form->error("$_: $errormessage") unless /^$folderstring/ and -f $_;
	$form->{file} = $_;
}

sub load_template {
  my ($self, $form) = @_;
  shift;

  $self->check_access(@_);
  open(TEMPLATE, "$form->{file}") or $form->error("$form->{file} : $!");

  while (<TEMPLATE>) {
    $form->{body} .= $_;
  }

  close(TEMPLATE);

}


sub save_template {
  my ($self, $form) = @_;
  shift;

  $self->check_access(@_);
  open(TEMPLATE, ">$form->{file}") or $form->error("$form->{file} : $!");

  # strip 
  $form->{body} =~ s/\r//g;
  print TEMPLATE $form->{body};

  close(TEMPLATE);

}



sub save_preferences {
  my ($self, $myconfig, $form, $memberfile, $userspath) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  # update name
  my $query = qq|UPDATE employee SET
                    name = |.$dbh->quote($form->{name}).qq|,
	                role = |.$dbh->quote($form->{role}).qq|,
		            workphone = |.$dbh->quote($form->{tel}).qq|
	            WHERE login = '$form->{login}'|;
  $dbh->do($query) || $form->dberror($query);

  my %defaults = $form->get_defaults($dbh, \@{['company']});

  $dbh->disconnect;

  my $myconfig = new User "$memberfile", "$form->{login}";

  foreach my $item (keys %$form) {
    $myconfig->{$item} = $form->{$item};
  }

  $myconfig->{company} = $defaults{company};
  $myconfig->{password} = $form->{new_password} if ($form->{old_password} ne $form->{new_password});

  $myconfig->save_member($memberfile, $userspath);
  $form->{sessioncookie} = $myconfig->{sessioncookie};

  1;

}


sub save_defaults {
  my ($self, $myconfig, $form) = @_;

  for (qw(IC IC_income IC_expense FX_gain FX_loss)) { ($form->{$_}) = split /--/, $form->{$_} }
  $form->{inventory_accno} = $form->{IC};
  $form->{income_accno} = $form->{IC_income};
  $form->{expense_accno} = $form->{IC_expense};
  $form->{fxgain_accno} = $form->{FX_gain};
  $form->{fxloss_accno} = $form->{FX_loss};

  # connect to database
  my $dbh = $form->dbconnect_noauto($myconfig);

  my $query;
  my $delquery;

  $query = qq|INSERT INTO defaults (fldname, fldvalue)
              VALUES (?, ?)|;
  $sth = $dbh->prepare($query) || $form->dberror($query);

  $delquery = qq|DELETE FROM defaults WHERE fldname = ?|;
  $delsth = $dbh->prepare($delquery) || $form->dberror($delquery);

  # must be present
  $delsth->execute('version') || $form->dberror;
  $sth->execute('version', $form->{dbversion}) || $form->dberror;
  $sth->finish;

  for (qw(inventory income expense fxgain fxloss)) {
    $delsth->execute(${_} . '_accno_id') || $form->dberror;

    $query = qq|INSERT INTO defaults (fldname, fldvalue)
                VALUES ('${_}_accno_id', (SELECT id
		                FROM chart
				WHERE accno = '$form->{"${_}_accno"}'))|;
    $dbh->do($query) || $form->dberror($query);
  }

  for (qw(transitionaccount selectedaccount glnumber sinumber vinumber batchnumber vouchernumber sonumber ponumber sqnumber rfqnumber partnumber employeenumber customernumber vendornumber projectnumber precision)) {
    $delsth->execute($_) || $form->dberror;

    $sth->execute($_, $form->{$_}) || $form->dberror;
    $sth->finish;
  }

  # optional
  for (split / /, $form->{optional}) {
    $delsth->execute($_) || $form->dberror;
    if ($form->{$_}) {
      $sth->execute($_, $form->{$_}) || $form->dberror;
      $sth->finish;
    }
  }

  my $rc = $dbh->commit;
  $dbh->disconnect;

  $rc;

}


sub defaultaccounts {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query;
  my $sth;

  # get defaults from defaults table
  my %defaults = $form->get_defaults($dbh);

  for (keys %defaults) { $form->{$_} = $defaults{$_} }

  $form->{defaults}{IC} = $form->{inventory_accno_id};
  $form->{defaults}{IC_income} = $form->{income_accno_id};
  $form->{defaults}{IC_sale} = $form->{income_accno_id};
  $form->{defaults}{IC_expense} = $form->{expense_accno_id};
  $form->{defaults}{IC_cogs} = $form->{expense_accno_id};
  $form->{defaults}{FX_gain} = $form->{fxgain_accno_id};
  $form->{defaults}{FX_loss} = $form->{fxloss_accno_id};

  $query = qq|SELECT c.id, c.accno, c.description, c.link,
              l.description AS translation
              FROM chart c
	      LEFT JOIN translation l ON (l.trans_id = c.id AND l.language_code = '$myconfig->{countrycode}')
              WHERE c.link LIKE '%IC%'
              ORDER BY c.accno|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  my $nkey;
  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    foreach my $key (split(/:/, $ref->{link})) {
      if ($key =~ /IC/) {
	$nkey = $key;
	if ($key =~ /cogs/) {
	  $nkey = "IC_expense";
	}
	if ($key =~ /sale/) {
	  $nkey = "IC_income";
	}
	$ref->{description} = $ref->{translation} if $ref->{translation};

        %{ $form->{accno}{$nkey}{$ref->{accno}} } = ( id => $ref->{id},
                                        description => $ref->{description} );
      }
    }
  }
  $sth->finish;


  $query = qq|SELECT c.id, c.accno, c.description,
              l.description AS translation
              FROM chart c
	      LEFT JOIN translation l ON (l.trans_id = c.id AND l.language_code = '$myconfig->{countrycode}')
	      WHERE (c.category = 'I' OR c.category = 'E')
	      AND c.charttype = 'A'
              ORDER BY c.accno|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    $ref->{description} = $ref->{translation} if $ref->{translation};

    %{ $form->{accno}{FX_gain}{$ref->{accno}} } = ( id => $ref->{id},
                                      description => $ref->{description} );
    %{ $form->{accno}{FX_loss}{$ref->{accno}} } = ( id => $ref->{id},
                                      description => $ref->{description} );
  }
  $sth->finish;

  $dbh->disconnect;

}


sub taxes {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query = qq|SELECT c.id, c.accno, c.description,
              t.rate * 100 AS rate, t.taxnumber, t.validto,
	      l.description AS translation
              FROM chart c
	      JOIN tax t ON (c.id = t.chart_id)
	      LEFT JOIN translation l ON (l.trans_id = c.id AND l.language_code = '$myconfig->{countrycode}')
	      ORDER BY 3, 6|;

  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    $ref->{description} = $ref->{translation} if $ref->{translation};
    push @{ $form->{taxrates} }, $ref;
  }
  $sth->finish;

  $dbh->disconnect;

}


sub save_taxes {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect_noauto($myconfig);

  my $query = qq|DELETE FROM tax|;
  $dbh->do($query) || $form->dberror($query);

  foreach my $item (split / /, $form->{taxaccounts}) {
    my ($chart_id, $i) = split /_/, $item;
	print STDERR "$i " . $form->{"taxrate_$i"} . "\n";
    if ( $form->{"taxrate_$i"} ne "" ) {
      my $rate = $form->parse_amount($myconfig, $form->{"taxrate_$i"}) / 100;
      $query = qq|INSERT INTO tax (chart_id, rate, taxnumber, validto)
                  VALUES ($chart_id, $rate, |
		  .$dbh->quote($form->{"taxnumber_$i"}).qq|, |
		  .$form->dbquote($form->dbclean($form->{"validto_$i"}), SQL_DATE)
		  .qq|)|;
      $dbh->do($query) || $form->dberror($query);
    }
  }

  my $rc = $dbh->commit;
  $dbh->disconnect;

  $rc;

}


sub backup {
    my ( $self, $myconfig, $form ) = @_;

    my $mail;
    my $err;

    my @t = localtime(time);
    $t[4]++;
    $t[5] += 1900;
    $t[3] = substr( "0$t[3]", -2 );
    $t[4] = substr( "0$t[4]", -2 );

    my $boundary = time;
    my $tmpfile = "/tmp/$myconfig->{dbname}-$t[5]-$t[4]-$t[3].sql.gz";

    my $out = $form->{OUT};
    $form->{OUT} = "$tmpfile";

    open( OUT, '>:raw', "$form->{OUT}" ) or $form->error("$form->{OUT} : $!");

    my $today = scalar localtime;

    if ( $form->{media} eq 'email' ) {
        print OUT qx(PGPASSWORD="$myconfig->{dbpasswd}" /usr/bin/pg_dump -C -U $myconfig->{dbuser} $myconfig->{dbname} | gzip -c);
        close OUT;

        use SL::Mailer;
        $mail = new Mailer;

        $mail->{charset} = $form->{charset};
        $mail->{to} = qq|"$myconfig->{name}" <$myconfig->{email}>|;
        $mail->{from} = qq|"$myconfig->{name}" <$myconfig->{email}>|;
        $mail->{subject} = "Run my Accounts Backup / $myconfig->{dbname}-$form->{version}-$t[5]$t[4]$t[3].sql.gz";
        @{ $mail->{attachments} } = ($tmpfile);
        $mail->{version} = $form->{version};
        $mail->{fileid} = "$boundary.";

        $myconfig->{signature} =~ s/\\n/\n/g;
        $mail->{message} = "-- \n$myconfig->{signature}";

        $err = $mail->send($out);
    }
    if ( $form->{media} eq 'file' ) {
        open( IN, '<:raw', "$tmpfile" ) or $form->error("$tmpfile : $!");
        open( OUT, ">-" ) or $form->error("STDOUT : $!");
        binmode( OUT, ':raw' );

        print OUT qq|Content-Type: application/file;\n| . qq|Content-Disposition: attachment; filename="$myconfig->{dbname}-$t[5]-$t[4]-$t[3].sql.gz"\n\n|;
        print OUT qx(PGPASSWORD="$myconfig->{dbpasswd}" /usr/bin/pg_dump -C -U $myconfig->{dbuser} $myconfig->{dbname} | gzip -c );
    }
    unlink "$tmpfile";
}

sub backup_templates {
    my ( $self, $myconfig, $form ) = @_;

    my $mail;
    my $err;

    my @t = localtime(time);
    $t[4]++;
    $t[5] += 1900;
    $t[3] = substr( "0$t[3]", -2 );
    $t[4] = substr( "0$t[4]", -2 );

    my $boundary = time;
    my $tmpfile = "/tmp/$myconfig->{dbname}-$t[5]-$t[4]-$t[3].tar.gz";

    my $out = $form->{OUT};
    $form->{OUT} = "$tmpfile";

    open( OUT, '>:raw', "$form->{OUT}" ) or $form->error("$form->{OUT} : $!");

    my $today = scalar localtime;

    if ( $form->{media} eq 'email' ) {
        print OUT qx(tar -czf - $myconfig->{templates});
        close OUT;

        use SL::Mailer;
        $mail = new Mailer;

        $mail->{charset} = $form->{charset};
        $mail->{to} = qq|"$myconfig->{name}" <$myconfig->{email}>|;
        $mail->{from} = qq|"$myconfig->{name}" <$myconfig->{email}>|;
        $mail->{subject} = "Run my Accounts Templates Backup / $myconfig->{dbname}-$form->{version}-$t[5]$t[4]$t[3]-templates.tar.gz";
        @{ $mail->{attachments} } = ($tmpfile);
        $mail->{version} = $form->{version};
        $mail->{fileid} = "$boundary.";

        $myconfig->{signature} =~ s/\\n/\n/g;
        $mail->{message} = "-- \n$myconfig->{signature}";

        $err = $mail->send($out);
    }
    if ( $form->{media} eq 'file' ) {
        open( IN, '<:raw', "$tmpfile" ) or $form->error("$tmpfile : $!");
        open( OUT, ">-" ) or $form->error("STDOUT : $!");
        binmode( OUT, ':raw' );

        print OUT qq|Content-Type: application/file;\n| . qq|Content-Disposition: attachment; filename="$myconfig->{dbname}-$t[5]-$t[4]-$t[3]-templates.tar.gz"\n\n|;
        print OUT qx(tar -czf - $myconfig->{templates});
    }
    unlink "$tmpfile";
}


sub closedto {
  my ($self, $myconfig, $form) = @_;

  my $dbh = $form->dbconnect($myconfig);

  my %defaults = $form->get_defaults($dbh, \@{[qw(closedto revtrans audittrail extendedlog)]});
  for (keys %defaults) { $form->{$_} = $defaults{$_} }

  $dbh->disconnect;

}


sub closebooks {
  my ($self, $myconfig, $form) = @_;

  my $dbh = $form->dbconnect_noauto($myconfig);
  my $query = qq|DELETE FROM defaults
                 WHERE fldname = ?|;
  my $dth = $dbh->prepare($query) || $form->dberror($query);

  $query = qq|INSERT INTO defaults (fldname, fldvalue)
              VALUES (?, ?)|;
  my $sth = $dbh->prepare($query) || $form->dberror($query);

  $form->{closedto} = $form->datetonum($myconfig, $form->{closedto});

  my $date = $form->{closedto};
  $date =~ s/\s+$//;
  $date =~ s/^\s*//;
  my ($year, $month, $day) = unpack "A4 A2 A2", $date;
  eval{
    timelocal(0,0,0,$day, $month-1, $year); # dies in case of bad date
  };

  for (qw(revtrans closedto audittrail extendedlog)) {
    $dth->execute($_) || $form->dberror;
    $dth->finish;

    if ($form->{$_}) {
      $sth->execute($_, $form->{$_}) || $form->dberror;
      $sth->finish;
    }
  }

  if ($form->{removeaudittrail}) {
    $query = qq|DELETE FROM audittrail
                WHERE transdate < '$form->{removeaudittrail}'|;
    $dbh->do($query) || $form->dberror($query);
  }

  $dbh->commit;
  $dbh->disconnect;

}


sub earningsaccounts {
  my ($self, $myconfig, $form) = @_;

  my ($query, $sth, $ref);

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  # get chart of accounts
  $query = qq|SELECT c.accno, c.description,
              l.description AS translation
              FROM chart c
	      LEFT JOIN translation l ON (l.trans_id = c.id AND l.language_code = '$myconfig->{countrycode}')
              WHERE c.charttype = 'A'
	      AND c.category = 'Q'
              ORDER by c.accno|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);
  $form->{chart} = "";

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    $ref->{description} = $ref->{translation} if $ref->{translation};
    push @{ $form->{chart} }, $ref;
  }
  $sth->finish;

  my %defaults = $form->get_defaults($dbh, \@{['method', 'precision']});
  $form->{precision} = $defaults{precision};
  $form->{method} ||= "accrual";

  $dbh->disconnect;

}


sub post_yearend {
  my ($self, $myconfig, $form) = @_;

  # connect to database, turn off AutoCommit
  my $dbh = $form->dbconnect_noauto($myconfig);

  my $query;
  my $uid = localtime;
  $uid .= $$;

  my $curr = substr($form->get_currencies($dbh, $myconfig),0,3);
  $query = qq|INSERT INTO gl (reference, employee_id, curr)
	      VALUES ('$uid', (SELECT id FROM employee
			       WHERE login = '$form->{login}'), '$curr')|;
  $dbh->do($query) || $form->dberror($query);

  $query = qq|SELECT id FROM gl
	      WHERE reference = '$uid'|;
  ($form->{id}) = $dbh->selectrow_array($query);

  $form->{reference} = $form->update_defaults($myconfig, 'glnumber', $dbh) unless $form->{reference};

  my ($null, $department_id) = split(/--/, $form->{department});
  $department_id *= 1;

  if ($department_id){
    $query = qq|INSERT INTO dpt_trans (trans_id, department_id) VALUES ($form->{id}, $department_id)|;
    $dbh->do($query) || $form->dberror($query);
  }

    # if there is an amount, add the record
  $query = qq|UPDATE gl SET
	      reference = |.$dbh->quote($form->{reference}).qq|,
	      description = |.$dbh->quote($form->{description}).qq|,
	      notes = |.$dbh->quote($form->{notes}).qq|,
	      transdate = '$form->{transdate}',
	      department_id = $department_id
	      WHERE id = $form->{id}|;

  $dbh->do($query) || $form->dberror($query);

  my $amount;
  my $accno;

  # insert acc_trans transactions
  for my $i (1 .. $form->{rowcount}) {
    # extract accno
    ($accno) = split(/--/, $form->{"accno_$i"});
    $amount = 0;

    if ($form->{"credit_$i"}) {
      $amount = $form->{"credit_$i"};
    }
    if ($form->{"debit_$i"}) {
      $amount = $form->{"debit_$i"} * -1;
    }

    # if there is an amount, add the record
    if ($amount) {
      $query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount, transdate,
                  source)
		  VALUES
		  ($form->{id}, (SELECT id
		                 FROM chart
				 WHERE accno = '$accno'),
		   $amount, '$form->{transdate}', |
		   .$dbh->quote($form->{reference}).qq|)|;

      $dbh->do($query) || $form->dberror($query);
    }
  }

  $query = qq|INSERT INTO yearend (trans_id, transdate)
              VALUES ($form->{id}, '$form->{transdate}')|;
  $dbh->do($query) || $form->dberror($query);

  my %audittrail = ( tablename	=> 'gl',
                     reference	=> $form->{reference},
	  	     formname	=> 'yearend',
		     action	=> 'posted',
		     id		=> $form->{id} );
  $form->audittrail($dbh, "", \%audittrail);

  # commit and redirect
  my $rc = $dbh->commit;
  $dbh->disconnect;

  $rc;

}


sub company_defaults {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my %defaults = $form->get_defaults($dbh, \@{['company','address']});
  for (keys %defaults) { $form->{$_} = $defaults{$_} }

  $dbh->disconnect;

}


sub bank_accounts {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query = qq|SELECT c.id, c.accno, c.description,
                 bk.name, bk.iban, bk.bic, bk.membernumber, bk.dcn, bk.rvc,
                 bk.qriban, bk.strdbkginf, bk.invdescriptionqr,
		 ad.address1, ad.address2, ad.city,
                 ad.state, ad.zipcode, ad.country,
		 l.description AS translation
                 FROM chart c
		 LEFT JOIN bank bk ON (bk.id = c.id)
		 LEFT JOIN address ad ON (c.id = ad.trans_id)
		 LEFT JOIN translation l ON (l.trans_id = c.id AND l.language_code = '$myconfig->{countrycode}')
		 WHERE c.link LIKE '%AR_paid%'
		 ORDER BY 2|;

  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  my $ref;

  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    $ref->{address} = "";
    for (qw(address1 address2 city state zipcode country)) {
      $ref->{address} .= "$ref->{$_}\n" if $ref->{$_};
    }
    chop $ref->{address};

    $ref->{description} = $ref->{translation} if $ref->{translation};

    push @{ $form->{ALL} }, $ref;
  }
  $sth->finish;

  $dbh->disconnect;

}


sub get_bank {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  $form->{id} *= 1;

  $query = qq|SELECT c.accno, c.description,
              bk.name, bk.iban, bk.bic, bk.membernumber, bk.dcn, bk.rvc,
              bk.qriban, bk.strdbkginf, bk.invdescriptionqr,
	      ad.address1, ad.address2, ad.city,
              ad.state, ad.zipcode, ad.country,
	      l.description AS translation
	      FROM chart c
	      LEFT JOIN bank bk ON (c.id = bk.id)
	      LEFT JOIN address ad ON (c.id = ad.trans_id)
	      LEFT JOIN translation l ON (l.trans_id = c.id AND l.language_code = '$myconfig->{countrycode}')
	      WHERE c.id = $form->{id}|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  $ref = $sth->fetchrow_hashref(NAME_lc);
  $ref->{account} = "$ref->{accno}--";
  $ref->{account} .= ($ref->{translation}) ? $ref->{translation} : $ref->{description};
  for (keys %$ref) { $form->{$_} = $ref->{$_} }
  $sth->finish;

  $dbh->disconnect;

}


sub save_bank {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect_noauto($myconfig);

  $form->{id} *= 1;

  my $query = qq|SELECT id FROM bank
                 WHERE id = $form->{id}|;
  my ($id) = $dbh->selectrow_array($query);

  my $ok;
  for (qw(name iban bic address1 address2 city state zipcode country membernumber rvc dcn qriban strdbkginf invdescriptionqr)) {
    if ($form->{$_}) {
      $ok = 1;
      last;
    }
  }
  if ($ok) {
    if ($id) {
      $query = qq|UPDATE bank SET
		  name = |.$dbh->quote(uc $form->{name}).qq|,
		  iban = |.$dbh->quote($form->{iban}).qq|,
		  bic = |.$dbh->quote(uc $form->{bic}).qq|,
		  membernumber = |.$dbh->quote($form->{membernumber}).qq|,
		  rvc = |.$dbh->quote($form->{rvc}).qq|,
		  qriban = |.$dbh->quote($form->{qriban}).qq|,
		  strdbkginf = |.$dbh->quote($form->{strdbkginf}).qq|,
		  invdescriptionqr = |.$dbh->quote($form->{invdescriptionqr}).qq|,
		  dcn = |.$dbh->quote($form->{dcn}).qq|
		  WHERE id = $form->{id}|;
      $dbh->do($query) || $form->dberror($query);
    } else {
      $query = qq|INSERT INTO bank (id, name, iban, bic, membernumber, rvc, dcn, qriban, strdbkginf, invdescriptionqr)
		  VALUES ($form->{id}, |
		  .$dbh->quote(uc $form->{name}).qq|, |
		  .$dbh->quote(uc $form->{iban}).qq|, |
		  .$dbh->quote($form->{bic}).qq|, |
		  .$dbh->quote($form->{membernumber}).qq|, |
		  .$dbh->quote($form->{rvc}).qq|, |
		  .$dbh->quote($form->{dcn}).qq|, |
		  .$dbh->quote($form->{qriban}).qq|, |
		  .$dbh->quote($form->{strdbkginf}).qq|, |
		  .$dbh->quote($form->{invdescriptionqr}).qq|
		  )|;
      $dbh->do($query) || $form->dberror($query);

      $query = qq|SELECT address_id
                  FROM bank
		  WHERE id = $form->{id}|;
      ($id) = $dbh->selectrow_array($query);

      $query = qq|INSERT INTO address (id, trans_id)
		  VALUES ($id, $form->{id})|;
      $dbh->do($query) || $form->dberror($query);
    }

    $query = qq|UPDATE address SET
		address1 = |.$dbh->quote(uc $form->{address1}).qq|,
		address2 = |.$dbh->quote(uc $form->{address2}).qq|,
		city = |.$dbh->quote(uc $form->{city}).qq|,
		state = |.$dbh->quote(uc $form->{state}).qq|,
		zipcode = |.$dbh->quote(uc $form->{zipcode}).qq|,
		country = |.$dbh->quote(uc $form->{country}).qq|
		WHERE trans_id = $form->{id}|;
    $dbh->do($query) || $form->dberror($query);

  } else {
    $query = qq|DELETE FROM bank
                WHERE id = $form->{id}|;
    $dbh->do($query) || $form->dberror($query);

    $query = qq|DELETE FROM address
                WHERE trans_id = $form->{id}|;
    $dbh->do($query) || $form->dberror($query);

  }

  my $rc = $dbh->commit;

  $dbh->disconnect;

  $rc;

}


sub exchangerates {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  $form->{currencies} = $form->get_currencies($dbh, $myconfig);

  $form->all_years($myconfig);

  $dbh->disconnect;

}



sub get_exchangerates {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $where = "1 = 1";

  my @a = qw(transdate);
  my $sortorder = $form->sort_order(\@a);

  $form->{currencies} = $form->get_currencies($dbh, $myconfig);

  ($form->{transdatefrom}, $form->{transdateto}) = $form->from_to($form->{year}, $form->{month}, $form->{interval}) if $form->{year} && $form->{month};

  $where .= " AND transdate >= '$form->{transdatefrom}'" if $form->{transdatefrom};
  $where .= " AND transdate <= '$form->{transdateto}'" if $form->{transdateto};
  $where .= " AND curr = '$form->{currency}'" if $form->{currency};

  my $query = qq|SELECT * FROM exchangerate
                 WHERE $where
		 ORDER BY $sortorder|;

  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{transactions} }, $ref;
  }
  $sth->finish;
  $dbh->disconnect;

}


sub save_exchangerate {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect_noauto($myconfig);

  my $query;
  my $sth;
  my $dth;

  $query = qq|DELETE FROM exchangerate
	      WHERE transdate = ?
	      AND curr = ?|;
  $dth = $dbh->prepare($query) || $form->dberror($query);

  $query = qq|INSERT INTO exchangerate
	      (transdate, buy, sell, curr)
	      VALUES (?,?,?,?)|;
  $sth = $dbh->prepare($query) || $form->dberror($query);

  for (split /:/, $form->{currencies}) {

    if ($form->{$_}) {

      $dth->execute($form->{transdate}, $_) || $form->dberror;
      $dth->finish;

      $form->{"${_}buy"} = $form->parse_amount($myconfig, $form->{"${_}buy"});
      $form->{"${_}sell"} = $form->parse_amount($myconfig, $form->{"${_}sell"});

      if ($form->{"${_}buy"} || $form->{"${_}sell"}) {
	$sth->execute($form->{transdate}, $form->{"${_}buy"}, $form->{"${_}sell"}, $_) || $form->dberror;
	$sth->finish;
      }
    }
  }

  $dbh->commit;
  $dbh->disconnect;

}


sub remove_locks {
  my ($self, $myconfig, $form) = @_;

  $dbh = $form->dbconnect($myconfig);

  my $query = qq|DELETE FROM semaphore|;
  $dbh->do($query) || $form->dberror($query);

  $dbh->disconnect;

}


sub currencies {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  $form->{sort} = "rn" unless $form->{sort};
  my @a = qw(rn curr);
  my %ordinal = ( rn	=> 1,
                  curr	=> 2 );
  my $sortorder = $form->sort_order(\@a, \%ordinal);

  my $query = qq|SELECT * FROM curr
		 ORDER BY $sortorder|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{ALL} }, $ref;
  }
  $sth->finish;

  $dbh->disconnect;

}


sub get_currency {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query = qq|SELECT * FROM curr
	         WHERE curr = |.$dbh->quote($form->{curr});
  my $sth = $dbh->prepare($query) || $form->dberror($query);
  $sth->execute;

  my $ref = $sth->fetchrow_hashref(NAME_lc);
  for (keys %$ref) { $form->{$_} = $ref->{$_} }
  $sth->finish;

  $query = qq|SELECT DISTINCT curr FROM ar WHERE curr = '$form->{curr}'
        UNION SELECT DISTINCT curr FROM ap WHERE curr = '$form->{curr}'
	UNION SELECT DISTINCT curr FROM oe WHERE curr = '$form->{curr}'|;
  ($form->{orphaned}) = $dbh->selectrow_array($query);
  $form->{orphaned} = !$form->{orphaned};

  $dbh->disconnect;

}


sub save_currency {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect_noauto($myconfig);

  $form->{curr} = substr($form->{curr}, 0, 3);

  $query = qq|SELECT curr
	      FROM curr
	      WHERE curr = |.$dbh->quote($form->{curr});
  my ($curr) = $dbh->selectrow_array($query);

  my $rn;

  if (!$curr) {
    $query = qq|SELECT MAX(rn) FROM curr|;
    ($rn) = $dbh->selectrow_array($query);
    $rn++;

    $query = qq|INSERT INTO curr (rn, curr)
                VALUES ($rn, |.$dbh->quote($form->{curr}).qq|)|;
    $dbh->do($query) || $form->dberror($query);
  }

  for (qw(precision)) { $form->{$_} *= 1 }
  $query = qq|UPDATE curr SET
	      precision = $form->{precision}
	      WHERE curr = |.$dbh->quote($form->{curr});
  $dbh->do($query) || $form->dberror($query);

  my $rc = $dbh->commit;
  $dbh->disconnect;

  $rc;

}


sub delete_currency {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect_noauto($myconfig);

  my $query = qq|SELECT rn FROM curr
                 WHERE curr = |.$dbh->quote($form->{curr});
  my ($rn) = $dbh->selectrow_array($query);

  $query = qq|UPDATE curr SET rn = rn - 1
              WHERE rn > $rn|;
  $dbh->do($query) || $form->dberror($query);

  $query = qq|DELETE FROM curr
	      WHERE curr = |.$dbh->quote($form->{curr});
  $dbh->do($query) || $form->dberror($query);

  my $rc = $dbh->commit;
  $dbh->disconnect;

  $rc;

}


sub move {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect_noauto($myconfig);

  my $id;

  my @dballowed = qw(paymentmethod curr);
  my @fldallowed = qw(id curr);

  # This error will appear only to someone who is trying to break code.
  $form->error('Invalid table name...') if !grep( /^$form->{db}$/, @dballowed);
  $form->error('Invalid column name...') if !grep( /^$form->{fld}$/, @fldallowed);

  my $query = qq|SELECT rn FROM $form->{db}
                 WHERE $form->{fld} = |.$dbh->quote($form->{id});
  my ($rn) = $dbh->selectrow_array($query);

  $query = qq|SELECT MAX(rn) FROM $form->{db}|;
  my ($lastrn) = $dbh->selectrow_array($query);

  if ($form->{move} eq 'down' && $rn != $lastrn) {
    $query = qq|SELECT $form->{fld} FROM $form->{db}
	        WHERE rn = $rn + 1|;
    ($id) = $dbh->selectrow_array($query);

    $query = qq|UPDATE $form->{db} SET rn = $rn + 1
                WHERE $form->{fld} = |.$dbh->quote($form->{id});
    $dbh->do($query) || $form->dberror($query);

    $query = qq|UPDATE $form->{db} SET rn = $rn
                WHERE $form->{fld} = '$id'|;
    $dbh->do($query) || $form->dberror($query);
  }

  if ($form->{move} eq 'up' && $rn > 1) {
    $query = qq|SELECT $form->{fld} FROM $form->{db}
	        WHERE rn = $rn - 1|;
    ($id) = $dbh->selectrow_array($query);

    $query = qq|UPDATE $form->{db} SET rn = $rn - 1
                WHERE $form->{fld} = |.$dbh->quote($form->{id});
    $dbh->do($query) || $form->dberror($query);

    $query = qq|UPDATE $form->{db} SET rn = $rn
                WHERE $form->{fld} = '$id'|;
    $dbh->do($query) || $form->dberror($query);
  }

  my $rc = $dbh->commit;
  $dbh->disconnect;

  $rc;


}


1;

