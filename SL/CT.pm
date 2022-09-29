#=====================================================================
# SQL-Ledger ERP
# Copyright (C) 2006
#
#  Author: DWS Systems Inc.
#     Web: http://www.sql-ledger.com
#
#======================================================================
#
# backend code for customers and vendors
#
#======================================================================

package CT;


sub create_links {
  my ($self, $myconfig, $form) = @_;

  my $dbh = $form->dbconnect($myconfig);
  my $query;
  my $sth;
  my $ref;
  my $arap = lc $form->{ARAP};
  my $accno;
  my $description;
  my $translation;
  
  $form->{db} = 'vendor' if $form->{db} ne 'customer';

  if ($form->{id} *= 1) {
    $query = qq/SELECT ct.*,
                ad.id AS addressid, ad.address1, ad.address2, ad.city,
		ad.state, ad.zipcode, ad.country,
        ad.post_office,
        ad.is_migrated,
		b.description || '--' || b.id AS business,
		d.description || '--' || d.id AS dispatch,
        s.*,
                e.name || '--' || e.id AS employee,
		g.pricegroup || '--' || g.id AS pricegroup,
		m.description || '--' || m.id AS paymentmethod,
		bk.name AS bankname,
		ad1.address1 AS bankaddress1,
		ad1.address2 AS bankaddress2,
		ad1.city AS bankcity,
		ad1.state AS bankstate,
		ad1.zipcode AS bankzipcode,
		ad1.country AS bankcountry,
        ad1.post_office AS bankpost_office,
        ad1.is_migrated AS bankis_migrated,
		ct.curr
                FROM $form->{db} ct
		LEFT JOIN address ad ON (ct.id = ad.trans_id)
		LEFT JOIN business b ON (ct.business_id = b.id)
		LEFT JOIN dispatch d ON (ct.dispatch_id = d.id)
		LEFT JOIN shipto s ON (ct.id = s.trans_id)
		LEFT JOIN employee e ON (ct.employee_id = e.id)
		LEFT JOIN pricegroup g ON (g.id = ct.pricegroup_id)
		LEFT JOIN paymentmethod m ON (m.id = ct.paymentmethod_id)
		LEFT JOIN bank bk ON (bk.id = ct.id)
		LEFT JOIN address ad1 ON (bk.address_id = ad1.id)
                WHERE ct.id = /.$form->dbclean($form->{id}).qq//;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);
  
    $ref = $sth->fetchrow_hashref(NAME_lc);
    for (keys %$ref) { $form->{$_} = $ref->{$_} }
    $sth->finish;
    
    $query = qq|SELECT * FROM contact
                WHERE trans_id = |.$form->dbclean($form->{id}).qq|
		ORDER BY id|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
      push @{ $form->{all_contact} }, $ref;
    }
    $sth->finish;

    ($form->{department_id}, $form->{department}) = $dbh->selectrow_array(qq|
        SELECT id, description 
        FROM department 
        WHERE id IN (
            SELECT department_id FROM dpt_trans WHERE trans_id = |.$form->dbclean($form->{id}).qq|
        )
    |);

    # check if it is orphaned
    $query = qq|SELECT a.id
              FROM |.$form->dbclean($arap).qq| a
	      JOIN $form->{db} ct ON (a.|.$form->dbclean($form->{db}).qq|_id = ct.id)
	      WHERE ct.id = $form->{id}
	    UNION
	      SELECT a.id
	      FROM oe a
	      JOIN |.$form->dbclean($form->{db}).qq| ct ON (a.|.$form->dbclean($form->{db}).qq|_id = ct.id)
	      WHERE ct.id = |.$form->dbclean($form->{id}).qq||;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);
  
    unless ($sth->fetchrow_array) {
      $form->{status} = "orphaned";
    }
    $sth->finish;

    # get taxes for customer/vendor
    $query = qq|SELECT c.accno
		FROM chart c
		JOIN |.$form->dbclean($form->{db}).qq|tax t ON (t.chart_id = c.id)
		WHERE t.|.$form->dbclean($form->{db}).qq|_id = |.$form->dbclean($form->{id}).qq||;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
      $form->{"tax_$ref->{accno}"} = 1;
    }
    $sth->finish;

    for (qw(arap payment discount)) {
      $form->{"${_}_accno_id"} *= 1;
      $query = qq|SELECT c.accno, c.description,
                  l.description AS translation
		  FROM chart c
		  LEFT JOIN translation l ON (l.trans_id = c.id AND l.language_code = '$myconfig->{countrycode}')
		  WHERE id = |.$form->dbclean($form->{"${_}_accno_id"}).qq||;
      ($accno, $description, $translation) = $dbh->selectrow_array($query);

      $description = $translation if $translation;
      $form->{"${_}_accno"} = "${accno}--$description";
    }

  } else {

    ($form->{employee}, $form->{employee_id}) = $form->get_employee($dbh);
    $form->{employee} = "$form->{employee}--$form->{employee_id}";
    $form->{startdate} = $form->current_date($myconfig);

  }

  # ARAP, payment and discount account
  $query = qq|SELECT c.accno, c.description, c.link,
              l.description AS translation
              FROM chart c
	      LEFT JOIN translation l ON (l.trans_id = c.id AND l.language_code = '$myconfig->{countrycode}')
	      WHERE c.link LIKE '%|.$form->dbclean($form->{ARAP}).qq|%'
	      ORDER BY c.accno|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);
  
  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    $ref->{description} = $ref->{translation} if $ref->{translation};

    if ($ref->{link} =~ /$form->{ARAP}_paid/) {
      push @{ $form->{payment_accounts} }, $ref;
    }
    if ($ref->{link} =~ /$form->{ARAP}_discount/) {
      push @{ $form->{discount_accounts} }, $ref;
    }
    if (($ref->{link} !~ /_/) && ($ref->{link} =~ /$form->{ARAP}/)) {
      push @{ $form->{arap_accounts} }, $ref;
    }
  }
  $sth->finish;
  
  # get tax labels
  $query = qq|SELECT DISTINCT c.accno, c.description,
              l.description AS translation
              FROM chart c
	      JOIN tax t ON (t.chart_id = c.id)
	      LEFT JOIN translation l ON (l.trans_id = c.id AND l.language_code = '$myconfig->{countrycode}')
	      WHERE c.link LIKE '%|.$form->dbclean($form->{ARAP}).qq|_tax%'
	      ORDER BY c.accno|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    $ref->{description} = $ref->{translation} if $ref->{translation};
    $form->{taxaccounts} .= "$ref->{accno} ";
    $form->{"tax_$ref->{accno}_description"} = $ref->{description};
  }
  $sth->finish;
  chop $form->{taxaccounts};

    
  # get business types
  $query = qq|SELECT *
              FROM business
	      ORDER BY 2|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);
  
  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{all_business} }, $ref;
  }
  $sth->finish;

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

  # employees/salespersons
  $form->all_employees($myconfig, $dbh, undef, ($form->{vc} eq 'customer') ? 1 : 0);

  $form->all_languages($myconfig, $dbh);
 
  # get pricegroups
  $query = qq|SELECT *
              FROM pricegroup
	      ORDER BY 2|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);
  
  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{all_pricegroup} }, $ref;
  }
  $sth->finish;

  # get paymentmethod
  $query = qq|SELECT *
              FROM paymentmethod
	      ORDER BY rn|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);
  
  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{all_paymentmethod} }, $ref;
  }
  $sth->finish;
 
  # get currencies
  $form->{currencies} = $form->get_currencies($dbh, $myconfig);

  $dbh->disconnect;

}


sub save {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect_noauto($myconfig);

  my $query;
  my $sth;
  my $null;
  
  my @postoffice = (
            # EN
            "postoffice",
            "post office",
            "postbox",
            "post box",
            "po box",
            "pobox",
            "p.o. box",
            "p.o.box",
            "p.o.",
            "letter box",
            "letterbox",

            # DE
            "postfach",
            "post fach",
            "postkasten",
            "post kasten",
            "briefkasten",
            "brief kasten",
            "briefbox",
            "brief box",
            "postbriefkasten",
            "p.o. kasten",

            # FR
            "boîte postale",
            "boîtepostale",
            "b.p.",
            "boite postale",
            "boitepostale",
            "boîte aux lettres",
            "boite aux lettres",
            "boîte à lettres",
            "boîte a lettres",
            "boite à lettres",
            "boite a lettres",

            # IT
            "cassetta delle lettere",
            "cassetta per le lettere",
            "cassetta per lettere",
            "casella postale",
            "casellapostale",
            "cassetta postale",
            "cassettapostale",
            "case postale",

            # RM
            "caum postal",
            "uffizi postal",
            "chascha da brevs",
  );

  my @careof = (
      "careof",
      "c/o",
  );

  $form->{name} ||= "$form->{lastname} $form->{firstname}";
  $form->{contact} = "$form->{firstname} $form->{lastname}";
  $form->{name} =~ s/^\s+//;
  $form->{name} =~ s/\s+$//;

  # remove double spaces
  $form->{name} =~ s/  / /g;
  # remove double minus and minus at the end
  $form->{name} =~ s/--+/-/g;
  $form->{name} =~ s/-+$//;
  
  for (qw(discount cashdiscount)) {
    $form->{$_} = $form->parse_amount($myconfig, $form->{$_});
    $form->{$_} /= 100;
  }

  for (qw(id terms discountterms taxincluded addressid contactid remittancevoucher)) { $form->{$_} *= 1 }
  
  for (qw(creditlimit threshold)) { $form->{$_} = $form->parse_amount($myconfig, $form->{$_}) }
 
  my $bank_address_id;
  
  if ($form->{id}) {
    $query = qq|DELETE FROM |.$form->dbclean($form->{db}).qq|tax
                WHERE $form->{db}_id = $form->{id}|;
    $dbh->do($query) || $form->dberror($query);

    $query = qq|DELETE FROM dpt_trans
                WHERE trans_id = $form->{id}|;
    $dbh->do($query) || $form->dberror($query);

    $query = qq|DELETE FROM shipto
                WHERE trans_id = $form->{id}|;
    $dbh->do($query) || $form->dberror($query);
   
    $query = qq|DELETE FROM contact
                WHERE id = $form->{contactid}|;
    $dbh->do($query) || $form->dberror($query);
 
    $query = qq|SELECT address_id
                FROM bank
                WHERE id = $form->{id}|;
    ($bank_address_id) = $dbh->selectrow_array($query);
    
    $query = qq|DELETE FROM bank
                WHERE id = $form->{id}|;
    $dbh->do($query) || $form->dberror($query);
   
    $query = qq|DELETE FROM address
                WHERE id = $form->{addressid}|;
    $dbh->do($query) || $form->dberror($query);
    
    $bank_address_id *= 1;
    $query = qq|DELETE FROM address
                WHERE trans_id = $bank_address_id|;
    $dbh->do($query) || $form->dberror($query);
		
    $query = qq|SELECT id FROM $form->{db}
                WHERE id = $form->{id}|;
    if (! $dbh->selectrow_array($query)) {
      $query = qq|INSERT INTO $form->{db} (id)
                  VALUES ($form->{id})|;
      $dbh->do($query) || $form->dberror($query);
    }
    
    # retrieve enddate
    if ($form->{type} && $form->{enddate}) {
      my $now;
      $query = qq|SELECT enddate, current_date AS now FROM $form->{db}|;
      ($form->{enddate}, $now) = $dbh->selectrow_array($query);
      $form->{enddate} = $now if $form->{enddate} lt $now;
    }

  } else {

    my $uid = localtime;
    $uid .= $$;
    
    $query = qq|INSERT INTO $form->{db} (name)
                VALUES (|.$dbh->quote($uid).qq|)|;
    $dbh->do($query) || $form->dberror($query);
   
    $query = qq|SELECT id FROM $form->{db}
                WHERE name = |.$dbh->quote($uid).qq||;
    ($form->{id}) = $dbh->selectrow_array($query);

    delete $form->{addressid};

  }

  my $ok;
  
  if ($form->{bankname}) {
    if ($bank_address_id) {
      $query = qq|INSERT INTO bank (id, name, iban, bic, address_id)
		  VALUES ($form->{id}, |
		  .$dbh->quote(uc $form->{bankname}).qq|,|
		  .$dbh->quote($form->{iban}).qq|,|
		  .$dbh->quote($form->{bic}).qq|,
		  $bank_address_id
		  )|;
    } else {
      $query = qq|INSERT INTO bank (id, name, iban, bic)
		  VALUES ($form->{id}, |
		  .$dbh->quote(uc $form->{bankname}).qq|,|
		  .$dbh->quote($form->{iban}).qq|,|
		  .$dbh->quote($form->{bic}).qq|
		  )|;
    }
    $dbh->do($query) || $form->dberror($query);

    $query = qq|SELECT address_id
                FROM bank
                WHERE id = $form->{id}|;
    ($bank_address_id) = $dbh->selectrow_array($query);

  }
  
    if ($form->{"bankaddress1"}) {
        # c/o processing
        for (@careof){
          if (lc($form->{bankaddress1}) =~ $_){
              my $bankaddress1 = $form->{bankaddress1};
              $form->{bankaddress1} = $form->{bankaddress2};
              $form->{bankaddress2} = $bankaddress1;
              last;
          }
        }
        # bankpost_office processing
        if (!$form->{bankpost_office}){
            for (@postoffice){
              if (lc($form->{bankaddress1}) =~ $_){
                  $form->{bankpost_office} = $form->{bankaddress1};
                  $form->{bankaddress1} = $form->{bankaddress2};
              }
              if (lc($form->{bankaddress2}) =~ $_){
                  $form->{bankpost_office} = $form->{bankaddress2};
                  $form->{bankaddress2} = '';
              }
            }
        }
    }

  $form->{bankis_migrated} = ($form->{bankis_migrated}) ? '1' : '0';
  for (qw(address1 address2 city state zipcode country)) {
    if ($form->{"bank$_"}) {
      if ($bank_address_id) {
	    $query = qq|INSERT INTO address (id, trans_id, address1, address2,
		    city, state, zipcode, country, post_office, is_migrated) VALUES (
		    $bank_address_id, $bank_address_id,
		    |.$dbh->quote(uc $form->{bankaddress1}).qq|,
		    |.$dbh->quote(uc $form->{bankaddress2}).qq|,
		    |.$dbh->quote(uc $form->{bankcity}).qq|,
		    |.$dbh->quote(uc $form->{bankstate}).qq|,
		    |.$dbh->quote(uc $form->{bankzipcode}).qq|,
	        |.$dbh->quote(uc $form->{bankcountry}).qq|,
	        |.$dbh->quote($form->{bankpost_office}).qq|,
	        |."'$form->{bankis_migrated}'".qq|
          )|;
	    $dbh->do($query) || $form->dberror($query);

      } else {
	$query = qq|INSERT INTO bank (id, name)
		    VALUES ($form->{id},
		    |.$dbh->quote(uc $form->{bankname}).qq|)|;
	$dbh->do($query) || $form->dberror($query);
	
	$query = qq|SELECT address_id
		    FROM bank
		    WHERE id = $form->{id}|;
	($bank_address_id) = $dbh->selectrow_array($query);

	$query = qq|INSERT INTO address (id, trans_id, address1, address2,
		    city, state, zipcode, country, post_office, is_migrated) VALUES (
		    $bank_address_id, $bank_address_id,
		    |.$dbh->quote(uc $form->{bankaddress1}).qq|,
		    |.$dbh->quote(uc $form->{bankaddress2}).qq|,
		    |.$dbh->quote(uc $form->{bankcity}).qq|,
		    |.$dbh->quote(uc $form->{bankstate}).qq|,
		    |.$dbh->quote(uc $form->{bankzipcode}).qq|,
	        |.$dbh->quote(uc $form->{bankcountry}).qq|,
	        |.$dbh->quote($form->{bankpost_office}).qq|,
	        |."'$form->{bankis_migrated}'".qq|
          )|;
	$dbh->do($query) || $form->dberror($query);
      }
      last;
    }
  }
    
 
  $form->{"$form->{db}number"} = $form->update_defaults($myconfig, "$form->{db}number", $dbh) if ! $form->{"$form->{db}number"};
 
  my %rec;
  for (qw(employee pricegroup business dispatch paymentmethod)) {
    ($null, $rec{"${_}_id"}) = split /--/, $form->{$_};
    $rec{"${_}_id"} *= 1;
  }
  
  for (qw(arap payment discount)) {
    ($rec{"${_}_accno"}) = split /--/, $form->{"${_}_accno"};
  }

    
  my $gifi;
  $gifi = qq|
	      gifi_accno = |.$dbh->quote($form->{gifi_accno}).qq|,| if $form->{db} eq 'vendor';

  $form->{is_migrated} = ($form->{is_migrated}) ? '1' : '0';
  
  # SQLI: use of dbh->quote for all columns
  $query = qq|UPDATE $form->{db} SET
              $form->{db}number = |.$dbh->quote($form->{"$form->{db}number"}).qq|,
	      name = |.$dbh->quote($form->{name}).qq|,
	      contact = |.$dbh->quote($form->{contact}).qq|,
	      phone = |.$dbh->quote($form->{phone}).qq|,
	      fax = |.$dbh->quote($form->{fax}).qq|,
	      email = |.$dbh->quote($form->{email}).qq|,
	      cc = |.$dbh->quote($form->{cc}).qq|,
	      bcc = |.$dbh->quote($form->{bcc}).qq|,
	      notes = |.$dbh->quote($form->{notes}).qq|,
	      terms = $form->{terms},
	      discount = $form->{discount},
	      creditlimit = $form->{creditlimit},
              iban = |.$dbh->quote($form->{iban}).qq|,
              bic = |.$dbh->quote($form->{bic}).qq|,
	      taxincluded = '$form->{taxincluded}',
	      $gifi
	      business_id = $rec{business_id},
	      dispatch_id = $rec{dispatch_id},
	      taxnumber = |.$dbh->quote($form->{taxnumber}).qq|,
	      sic_code = |.$dbh->quote($form->{sic_code}).qq|,
	      employee_id = $rec{employee_id},
	      language_code = |.$dbh->quote($form->{language_code}).qq|,
	      pricegroup_id = $rec{pricegroup_id},
	      curr = |.$dbh->quote($form->{curr}).qq|,
	      startdate = |.$form->dbquote($form->dbclean($form->{startdate}), SQL_DATE).qq|,
	      enddate = |.$form->dbquote($form->dbclean($form->{enddate}), SQL_DATE).qq|,
	      arap_accno_id = (SELECT id FROM chart WHERE accno = |.$dbh->quote($rec{arap_accno}).qq|),
	      payment_accno_id = (SELECT id FROM chart WHERE accno = |.$dbh->quote($rec{payment_accno}).qq|),
	      discount_accno_id = (SELECT id FROM chart WHERE accno = |.$dbh->quote($rec{discount_accno}).qq|),
	      cashdiscount = $form->{cashdiscount},
	      threshold = $form->{threshold},
	      discountterms = $form->{discountterms},
	      paymentmethod_id = $rec{paymentmethod_id},
	      remittancevoucher = '$form->{remittancevoucher}'
	      WHERE id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

  # save taxes
  foreach $item (split / /, $form->{taxaccounts}) {
    if ($form->{"tax_$item"}) {
      $query = qq|INSERT INTO $form->{db}tax ($form->{db}_id, chart_id)
		  VALUES ($form->{id}, (SELECT id
				        FROM chart
				        WHERE accno = '$item'))|;
      $dbh->do($query) || $form->dberror($query);
    }
  }

  # save department
  if ($form->{department}){
     ($null, $form->{department_id}) = split /--/, $form->{department};
     $form->{department_id} *= 1;
     $query = qq|INSERT INTO dpt_trans (trans_id, department_id) VALUES ($form->{id}, $form->{department_id})|;
     $dbh->do($query) || $form->dberror($query);
  }

  # add address
  my $id;
  my $var;
  
  if ($form->{addressid}) {
    $id = "id, ";
    $var = "$form->{addressid}, ";
  }

  # c/o processing
  for (@careof){
    if (lc($form->{address1}) =~ $_){
        my $address1 = $form->{address1};
        $form->{address1} = $form->{address2};
        $form->{address2} = $address1;
        last;
    }
  }

  # post_office processing
  if (!$form->{post_office}){
      for (@postoffice){
        if (lc($form->{address1}) =~ $_){
            $form->{post_office} = $form->{address1};
            $form->{address1} = $form->{address2};
        }
        if (lc($form->{address2}) =~ $_){
            $form->{post_office} = $form->{address2};
            $form->{address2} = '';
        }
      }
  }

  $query = qq|INSERT INTO address ($id trans_id, address1, address2,
              city, state, zipcode, country, post_office, is_migrated) VALUES ($var
	      $form->{id},
	      |.$dbh->quote($form->{address1}).qq|,
	      |.$dbh->quote($form->{address2}).qq|,
	      |.$dbh->quote($form->{city}).qq|,
	      |.$dbh->quote($form->{state}).qq|,
	      |.$dbh->quote($form->{zipcode}).qq|,
	      |.$dbh->quote($form->{country}).qq|,
	      |.$dbh->quote($form->{post_office}).qq|,
	      |."'$form->{is_migrated}'".qq|
          )|;
  $dbh->do($query) || $form->dberror($query);

  $id = "";
  $var = "";
  
  if ($form->{contactid}) {
    $id = "id, ";
    $var = "$form->{contactid}, ";
  }

  $query = qq|INSERT INTO contact ($id trans_id, firstname, lastname,
              salutation, contacttitle, occupation, phone, fax, mobile,
	      typeofcontact, email, gender) VALUES ($var
	      $form->{id},
	      |.$dbh->quote($form->{firstname}).qq|,
	      |.$dbh->quote($form->{lastname}).qq|,
	      |.$dbh->quote($form->{salutation}).qq|,
	      |.$dbh->quote($form->{contacttitle}).qq|,
	      |.$dbh->quote($form->{occupation}).qq|,
	      |.$dbh->quote($form->{phone}).qq|,
	      |.$dbh->quote($form->{fax}).qq|,
	      |.$dbh->quote($form->{mobile}).qq|,
	      |.$dbh->quote($form->{typeofcontact}).qq|,
	      |.$dbh->quote($form->{email}).qq|,
	      |.$dbh->quote($form->{gender}).qq|)|;
  $dbh->do($query) || $form->dberror($query);
 
  # add shipto
  $form->add_shipto($dbh, $form->{id});

  $dbh->commit;
  $dbh->disconnect;

}



sub delete {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect_noauto($myconfig);

  $form->{id} *= 1;

  # delete customer/vendor
  my $query = qq|DELETE FROM $form->{db}
	         WHERE id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

  $query = qq|SELECT address_id FROM bank
              WHERE id = $form->{id}|;
  my ($address_id) = $dbh->selectrow_array($query);
  
  if ($address_id) {
    $query = qq|DELETE FROM address WHERE id = $address_id|;
    $dbh->do($query) || $form->dberror($query);
  }
  
  for (qw(shipto address)) {
    $query = qq|DELETE FROM $_ WHERE trans_id = $form->{id}|;
    $dbh->do($query) || $form->dberror($query);
  }

  $query = qq|DELETE FROM bank WHERE id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);
  
  $query = qq|DELETE FROM $form->{db}tax WHERE $form->{db}_id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);
  
  $query = qq|DELETE FROM parts$form->{db} WHERE $form->{db}_id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

  $dbh->commit;
  $dbh->disconnect;

}


sub search {
  my ($self, $myconfig, $form) = @_;


  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my %defaults = $form->get_defaults($dbh, \@{['precision', 'company']});
  for (keys %defaults) { $form->{$_} = $defaults{$_} }
    
  my $where = "1 = 1";
  $form->{sort} = ($form->{sort}) ? $form->{sort} : "name";
  my @a = qw(name);
  my $sortorder = $form->sort_order(\@a);

  my $ref;
  my $var;
  my $item;

  $form->{db} = 'vendor' if $form->{db} ne 'customer'; # SQLI protection

  @a = ("$form->{db}number");
  push @a, qw(name contact notes phone email);

  if ($form->{employee}) {
    $var = $form->like(lc $form->{employee});
    $where .= " AND lower(e.name) LIKE '$var'";
  }
 
  foreach $item (@a) {
    if ($form->{$item} ne "") {
      $var = $form->like(lc $form->{$item});
      $where .= " AND lower(c.$item) LIKE '$var'";
    }
  }

  @a = ();
  push @a, qw(city state zipcode country);
  foreach $item (@a) {
    if ($form->{$item} ne "") {
      $var = $form->like(lc $form->{$item});
      $where .= " AND lower(ad.$item) LIKE '$var'";
    }
  }

  if ($form->{address} ne "") {
    $var = $form->like(lc $form->{address});
    $where .= " AND (lower(ad.address1) LIKE '$var' OR lower(ad.address2) LIKE '$var')";
  }
  
  if ($form->{startdatefrom}) {
    $where .= " AND c.startdate >= '$form->{startdatefrom}'";
  }
  if ($form->{startdateto}) {
    $where .= " AND c.startdate <= '$form->{startdateto}'";
  }

  if ($form->{status} eq 'active') {
    $where .= " AND c.enddate IS NULL";
  }
  if ($form->{status} eq 'inactive') {
    $where .= " AND c.enddate <= current_date";
  }

  if ($form->{status} eq 'orphaned') {
    $where .= qq| AND c.id NOT IN (SELECT o.$form->{db}_id
                                    FROM oe o, $form->{db} vc
		 	            WHERE vc.id = o.$form->{db}_id)|;
    if ($form->{db} eq 'customer') {
      $where .= qq| AND c.id NOT IN (SELECT a.customer_id
                                      FROM ar a, customer vc
				      WHERE vc.id = a.customer_id)|;
    }
    if ($form->{db} eq 'vendor') {
      $where .= qq| AND c.id NOT IN (SELECT a.vendor_id
                                      FROM ap a, vendor vc
				      WHERE vc.id = a.vendor_id)|;
    }
    $form->{l_invnumber} = $form->{l_ordnumber} = $form->{l_quonumber} = "";
  }
  
  my $department_where;
  if ($form->{department}){
     ($null, $department_id) = split /--/, $form->{department};
     $department_id *= 1;
     $department_where = qq|AND c.id IN (SELECT trans_id FROM dpt_trans WHERE department_id = $department_id)|;
  }

  my $query = qq|SELECT c.*, b.description AS business, d.description AS dispatch,
                 e.name AS employee, g.pricegroup, l.description AS language,
		 m.name AS manager,
		 ad.address1, ad.address2, ad.city, ad.state, ad.zipcode,
		 ad.country,
		 pm.description AS paymentmethod,
		 ct.salutation, ct.firstname, ct.lastname, ct.contacttitle,
		 ct.occupation, ct.mobile, ct.gender, ct.typeofcontact
                 FROM $form->{db} c
	      JOIN contact ct ON (ct.trans_id = c.id)
	      LEFT JOIN address ad ON (ad.trans_id = c.id)
	      LEFT JOIN business b ON (c.business_id = b.id)
	      LEFT JOIN dispatch d ON (c.dispatch_id = d.id)
	      LEFT JOIN employee e ON (c.employee_id = e.id)
	      LEFT JOIN employee m ON (m.id = e.managerid)
	      LEFT JOIN pricegroup g ON (c.pricegroup_id = g.id)
	      LEFT JOIN language l ON (l.code = c.language_code)
	      LEFT JOIN paymentmethod pm ON (pm.id = c.paymentmethod_id)
                 WHERE $where
                 $department_where|;

  # redo for invoices, orders and quotations
  if ($form->{l_transnumber} || $form->{l_invnumber} || $form->{l_ordnumber} || $form->{l_quonumber}) {

    my ($ar, $union, $module);
    $query = "";
    my $transwhere;
    my $openarap = "";
    my $openoe = "";
   
    if ($form->{open} || $form->{closed}) {
      unless ($form->{open} && $form->{closed}) {
	$openarap = " AND a.amount != a.paid" if $form->{open};
	$openarap = " AND a.amount = a.paid" if $form->{closed};
	$openoe = " AND o.closed = '0'" if $form->{open};
	$openoe = " AND o.closed = '1'" if $form->{closed};
      }
    }
      
    if ($form->{l_transnumber}) {
      $ar = ($form->{db} eq 'customer') ? 'ar' : 'ap';
      $module = $ar;

      $transwhere = "";
      $transwhere .= " AND a.transdate >= '$form->{transdatefrom}'" if $form->{transdatefrom};
      $transwhere .= " AND a.transdate <= '$form->{transdateto}'" if $form->{transdateto};
      
   
      $query = qq|SELECT c.*, b.description AS business, d.description dispatch,
                  a.invnumber, a.ordnumber, a.quonumber, a.id AS invid,
		  '$ar' AS module, 'invoice' AS formtype,
		  (a.amount = a.paid) AS closed, a.amount, a.netamount,
		  e.name AS employee, m.name AS manager,
		  ad.address1, ad.address2, ad.city, ad.state, ad.zipcode,
		  ad.country,
		  pm.description AS paymentmethod,
		  ct.salutation, ct.firstname, ct.lastname, ct.contacttitle,
		  ct.occupation, ct.mobile, ct.gender, ct.typeofcontact
		  FROM $form->{db} c
	        JOIN contact ct ON (ct.trans_id = c.id)
		JOIN address ad ON (ad.trans_id = c.id)
		JOIN $ar a ON (a.$form->{db}_id = c.id)
	        LEFT JOIN business b ON (c.business_id = b.id)
	        LEFT JOIN dispatch d ON (c.dispatch_id = d.id)
		LEFT JOIN employee e ON (a.employee_id = e.id)
		LEFT JOIN employee m ON (m.id = e.managerid)
		LEFT JOIN paymentmethod pm ON (pm.id = c.paymentmethod_id)
		  WHERE $where
		  AND a.invoice = '0'
		  $transwhere
		  $openarap
		  |;
  
      $union = qq|
              UNION|;
      
    }

    if ($form->{l_invnumber}) {
      $ar = ($form->{db} eq 'customer') ? 'ar' : 'ap';
      $module = ($ar eq 'ar') ? 'is' : 'ir';

      $transwhere = "";
      $transwhere .= " AND a.transdate >= '$form->{transdatefrom}'" if $form->{transdatefrom};
      $transwhere .= " AND a.transdate <= '$form->{transdateto}'" if $form->{transdateto};
    
      $query .= qq|$union
		   SELECT c.*, b.description AS business, d.description AS dispatch,
		   a.invnumber, a.ordnumber, a.quonumber, a.id AS invid,
		   '$module' AS module, 'invoice' AS formtype,
		   (a.amount = a.paid) AS closed, a.amount, a.netamount,
		   e.name AS employee, m.name AS manager,
		   ad.address1, ad.address2, ad.city, ad.state, ad.zipcode,
		   ad.country,
		   pm.description AS paymentmethod,
		   ct.salutation, ct.firstname, ct.lastname, ct.contacttitle,
		   ct.occupation, ct.mobile, ct.gender, ct.typeofcontact
		   FROM $form->{db} c
	        JOIN contact ct ON (ct.trans_id = c.id)
		JOIN address ad ON (ad.trans_id = c.id)
		JOIN $ar a ON (a.$form->{db}_id = c.id)
	        LEFT JOIN business b ON (c.business_id = b.id)
	        LEFT JOIN dispatch d ON (c.dispatch_id = d.id)
		LEFT JOIN employee e ON (a.employee_id = e.id)
		LEFT JOIN employee m ON (m.id = e.managerid)
		LEFT JOIN paymentmethod pm ON (pm.id = c.paymentmethod_id)
		  WHERE $where
		  AND a.invoice = '1'
		  $transwhere
		  $openarap
		  |;
  
      $union = qq|
              UNION|;
      
    }
    
    if ($form->{l_ordnumber}) {
      
      $transwhere = "";
      $transwhere .= " AND o.transdate >= '$form->{transdatefrom}'" if $form->{transdatefrom};
      $transwhere .= " AND o.transdate <= '$form->{transdateto}'" if $form->{transdateto};
      $query .= qq|$union
		   SELECT c.*, b.description AS business, d.description AS dispatch,
		   ' ' AS invnumber, o.ordnumber, o.quonumber, o.id AS invid,
		   'oe' AS module, 'order' AS formtype,
		   o.closed, o.amount, o.netamount,
		   e.name AS employee, m.name AS manager,
		   ad.address1, ad.address2, ad.city, ad.state, ad.zipcode,
		   ad.country,
		   pm.description AS paymentmethod,
		   ct.salutation, ct.firstname, ct.lastname, ct.contacttitle,
		   ct.occupation, ct.mobile, ct.gender, ct.typeofcontact
		  FROM $form->{db} c
	        JOIN contact ct ON (ct.trans_id = c.id)
		JOIN address ad ON (ad.trans_id = c.id)
		JOIN oe o ON (o.$form->{db}_id = c.id)
	        LEFT JOIN business b ON (c.business_id = b.id)
	        LEFT JOIN dispatch d ON (c.dispatch_id = d.id)
		LEFT JOIN employee e ON (o.employee_id = e.id)
		LEFT JOIN employee m ON (m.id = e.managerid)
		LEFT JOIN paymentmethod pm ON (pm.id = c.paymentmethod_id)
		  WHERE $where
		  AND o.quotation = '0'
		  $transwhere
		  $openoe
		  |;
  
      $union = qq|
              UNION|;

    }

    if ($form->{l_quonumber}) {

      $transwhere = "";
      $transwhere .= " AND o.transdate >= '$form->{transdatefrom}'" if $form->{transdatefrom};
      $transwhere .= " AND o.transdate <= '$form->{transdateto}'" if $form->{transdateto};
      $query .= qq|$union
		   SELECT c.*, b.description AS business, d.description AS dispatch,
		   ' ' AS invnumber, o.ordnumber, o.quonumber, o.id AS invid,
		   'oe' AS module, 'quotation' AS formtype,
		   o.closed, o.amount, o.netamount,
		   e.name AS employee, m.name AS manager,
		   ad.address1, ad.address2, ad.city, ad.state, ad.zipcode,
		   ad.country,
		   pm.description AS paymentmethod,
		   ct.salutation, ct.firstname, ct.lastname, ct.contacttitle,
		   ct.occupation, ct.mobile, ct.gender, ct.typeofcontact
		  FROM $form->{db} c
	        JOIN contact ct ON (ct.trans_id = c.id)
		JOIN address ad ON (ad.trans_id = c.id)
		JOIN oe o ON (o.$form->{db}_id = c.id)
	        LEFT JOIN business b ON (c.business_id = b.id)
	        LEFT JOIN dispatch d ON (c.dispatch_id = d.id)
		LEFT JOIN employee e ON (o.employee_id = e.id)
		LEFT JOIN employee m ON (m.id = e.managerid)
		LEFT JOIN paymentmethod pm ON (pm.id = c.paymentmethod_id)
		  WHERE $where
		  AND o.quotation = '1'
		  $transwhere
		  $openoe
		  |;

    }

      $sortorder .= ", invid";
  }

  $query .= qq|
		 ORDER BY $sortorder|;
		 
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  # accounts
  my %accno;
  $query = qq|SELECT id, accno FROM chart
              WHERE link LIKE '%|.$form->dbclean($form->{ARAP}).qq|%'|;
  my $tth = $dbh->prepare($query);
  $tth->execute || $form->dberror($query);
  while ($ref = $tth->fetchrow_hashref(NAME_lc)) {
    $accno{$ref->{id}} = $ref->{accno};
  }
  $tth->finish;

  $query = qq|SELECT c.accno
              FROM chart c
	      JOIN $form->{db}tax t ON (t.chart_id = c.id)
	      WHERE t.$form->{db}_id = ?|;
  $tth = $dbh->prepare($query) || $form->dberror($query);

  # bank
  my $bref;
  $query = qq|SELECT b.*, a.*
              FROM bank b
	      LEFT JOIN address a ON (a.trans_id = b.address_id)
	      WHERE b.id = ?|;
  $bth = $dbh->prepare($query) || $form->dberror($query);

  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    $bth->execute($ref->{id});
    $bref = $bth->fetchrow_hashref(NAME_lc);
    for (qw(name address1 address2 city state zipcode country)) {
      $ref->{"bank$_"} = $bref->{$_};
    }
    $bth->finish;

    $tth->execute($ref->{id});
    while (($item) = $tth->fetchrow_array) {
      $ref->{taxaccounts} .= "$item ";
    }
    $tth->finish;
    chop $ref->{taxaccount};
    
    for (qw(arap payment discount)) { $ref->{"${_}_accno"} = $accno{$ref->{"${_}_accno_id"}} }
    
    $ref->{address} = "";
    for (qw(address1 address2 city state zipcode country)) { $ref->{address} .= "$ref->{$_} " }

    push @{ $form->{CT} }, $ref;

  }

  $sth->finish;
  $dbh->disconnect;

}


sub get_history {
  my ($self, $myconfig, $form) = @_;
  
  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query;
  my $where = "1 = 1";
  $form->{sort} = "partnumber" unless $form->{sort};
  $form->{sort} =~ s/;//g;
  $form->{sort} = $form->dbclean($form->{sort});
  my $sortorder = $form->{sort};
  my %ordinal = ();
  my $var;
  my $table;

  $form->{db} = $form->dbclean($form->{db});

  # setup ASC or DESC
  $form->sort_order();
  
  my %defaults = $form->get_defaults($dbh, \@{['precision', 'company']});
  for (keys %defaults) { $form->{$_} = $defaults{$_} }
  
  if ($form->{business}){
    (undef, $business_id) = split(/--/, $form->{business});
    $business_id *= 1;
    $where .= " AND ct.business_id = $business_id";
  }
  if ($form->{"$form->{db}number"} ne "") {
    $var = $form->like(lc $form->{"$form->{db}number"});
    $where .= " AND lower(ct.$form->{db}number) LIKE '$var'";
  }
  if ($form->{address} ne "") {
    $var = $form->like(lc $form->{address});
    $where .= " AND lower(ad.address1) LIKE '$var'";
  }
  for (qw(name contact email phone notes)) {
    if ($form->{$_} ne "") {
      $var = $form->like(lc $form->{$_});
      $where .= " AND lower(ct.$_) LIKE '$var'";
    }
  }
  for (qw(city state zipcode country)) {
    if ($form->{$_} ne "") {
      $var = $form->like(lc $form->{$_});
      $where .= " AND lower(ad.$_) LIKE '$var'";
    }
  }
     
  if ($form->{employee} ne "") {
    $var = $form->like(lc $form->{employee});
    $where .= " AND lower(e.name) LIKE '$var'";
  }
  
  $form->{transdatefrom} = $form->dbclean($form->{transdatefrom});
  $form->{transdateto} = $form->dbclean($form->{transdateto});
  $form->{type} = $form->dbclean($form->{type});

  $where .= " AND a.transdate >= '$form->{transdatefrom}'" if $form->{transdatefrom};
  $where .= " AND a.transdate <= '$form->{transdateto}'" if $form->{transdateto};

  if ($form->{open} || $form->{closed}) {
    unless ($form->{open} && $form->{closed}) {
      if ($form->{type} eq 'invoice') {
	$where .= " AND a.amount != a.paid" if $form->{open};
	$where .= " AND a.amount = a.paid" if $form->{closed};
      } else {
	$where .= " AND a.closed = '0'" if $form->{open};
	$where .= " AND a.closed = '1'" if $form->{closed};
      }
    }
  }
  
  my $invnumber = 'invnumber';
  my $deldate = 'deliverydate';
  my $buysell;
  my $sellprice = "sellprice";
  
  if ($form->{db} eq 'customer') {
    $buysell = "buy";
    if ($form->{type} eq 'invoice') {
      $where .= qq| AND a.invoice = '1' AND i.assemblyitem = '0'|;
      $table = 'ar';
      $sellprice = "fxsellprice";
    } else {
      $table = 'oe';
      if ($form->{type} eq 'order') {
	$invnumber = 'ordnumber';
	$where .= qq| AND a.quotation = '0'|;
      } else {
	$invnumber = 'quonumber';
	$where .= qq| AND a.quotation = '1'|;
      }
      $deldate = 'reqdate';
    }
  }
  if ($form->{db} eq 'vendor') {
    $buysell = "sell";
    if ($form->{type} eq 'invoice') {
      $where .= qq| AND a.invoice = '1' AND i.assemblyitem = '0'|;
      $table = 'ap';
      $sellprice = "fxsellprice";
    } else {
      $table = 'oe';
      if ($form->{type} eq 'order') {
	$invnumber = 'ordnumber';
	$where .= qq| AND a.quotation = '0'|;
      } else {
	$invnumber = 'quonumber';
	$where .= qq| AND a.quotation = '1'|;
      } 
      $deldate = 'reqdate';
    }
  }
 
  my $invjoin = qq|
		 JOIN invoice i ON (i.trans_id = a.id)|;

  if ($form->{type} eq 'order') {
    $invjoin = qq|
		 JOIN orderitems i ON (i.trans_id = a.id)|;
  }
  if ($form->{type} eq 'quotation') {
    $invjoin = qq|
		 JOIN orderitems i ON (i.trans_id = a.id)|;
    $where .= qq| AND a.quotation = '1'|;
  }


  %ordinal = ( partnumber	=> 9,
	       description	=> 14,
	       "$deldate"	=> 18,
	       serialnumber	=> 19,
	       projectnumber	=> 20
	      );

  $form->{direction} =~ s/;//g;
  $sortorder = "2 $form->{direction}, 1, $ordinal{$sortorder} $form->{direction}";
    
  $query = qq|SELECT ct.id AS ctid, ct.$form->{db}number, a.transdate, ct.name, ad.address1,
	      ad.address2, ad.city, ad.state,
	      p.id AS pid, p.partnumber, a.id AS invid,
	      a.$invnumber, a.curr, i.description,
	      i.qty, i.$sellprice AS sellprice, i.discount,
	      i.$deldate, i.serialnumber, pr.projectnumber,
	      e.name AS employee, ad.zipcode, ad.country, i.unit,
              (SELECT $buysell FROM exchangerate ex
		    WHERE a.curr = ex.curr
		    AND a.transdate = ex.transdate) AS exchangerate
	      FROM $form->{db} ct
	      JOIN address ad ON (ad.trans_id = ct.id)
	      JOIN $table a ON (a.$form->{db}_id = ct.id)
	      $invjoin
	      JOIN parts p ON (p.id = i.parts_id)
	      LEFT JOIN project pr ON (pr.id = i.project_id)
	      LEFT JOIN employee e ON (e.id = a.employee_id)
	      WHERE $where
	      ORDER BY $sortorder|;

  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    $ref->{address} = "";
    $ref->{exchangerate} ||= 1;
    for (qw(address1 address2 city state zipcode country)) { $ref->{address} .= "$ref->{$_} " }
    $ref->{id} = $ref->{ctid};
    push @{ $form->{CT} }, $ref;
  }

  $sth->finish;
  $dbh->disconnect;

}


sub pricelist {
  my ($self, $myconfig, $form) = @_;
  
  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query;
  my $sth;
  my $ref;

  if ($form->{db} eq 'customer') {
    $query = qq|SELECT DISTINCT pg.id, pg.partsgroup
		FROM parts p
		JOIN partsgroup pg ON (pg.id = p.partsgroup_id)
		WHERE p.partsgroup_id > 0
		ORDER BY pg.partsgroup|;

    $sth = $dbh->prepare($query);
    $sth->execute || $self->dberror($query);

    $form->{all_partsgroup} = ();
    while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
      push @{ $form->{all_partsgroup} }, $ref;
    }
    $sth->finish;
 
    $query = qq|SELECT p.id, p.partnumber, p.description,
                p.sellprice, pg.partsgroup, p.partsgroup_id,
                m.pricebreak, m.sellprice,
		m.validfrom, m.validto, m.curr
                FROM partscustomer m
		JOIN parts p ON (p.id = m.parts_id)
		LEFT JOIN partsgroup pg ON (pg.id = p.partsgroup_id)
		WHERE m.customer_id = $form->{id}
		ORDER BY partnumber|;
  }
  if ($form->{db} eq 'vendor') {
    $query = qq|SELECT DISTINCT pg.id, pg.partsgroup
		FROM parts p
		JOIN partsgroup pg ON (pg.id = p.partsgroup_id)
		WHERE p.partsgroup_id > 0
		AND p.assembly = '0'
		ORDER BY pg.partsgroup|;

    $sth = $dbh->prepare($query);
    $sth->execute || $self->dberror($query);

    $form->{all_partsgroup} = ();
    while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
      push @{ $form->{all_partsgroup} }, $ref;
    }
    $sth->finish;
   
    $query = qq|SELECT p.id, p.partnumber AS sku, p.description,
                pg.partsgroup, p.partsgroup_id,
		m.partnumber, m.leadtime, m.lastcost, m.curr
		FROM partsvendor m
		JOIN parts p ON (p.id = m.parts_id)
		LEFT JOIN partsgroup pg ON (pg.id = p.partsgroup_id)
		WHERE m.vendor_id = $form->{id}
		ORDER BY p.partnumber|;
  }

  if ($form->{id}) {
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
      push @{ $form->{all_partspricelist} }, $ref;
    }
    $sth->finish;
  }

  $form->{currencies} = $form->get_currencies($dbh, $myconfig);
 
  $dbh->disconnect;

}


sub save_pricelist {
  my ($self, $myconfig, $form) = @_;

  my $dbh = $form->dbconnect_noauto($myconfig);
  
  $form->{id} *= 1;
  
  $form->{db} = 'vendor' if $form->{db} ne 'customer'; # SQLI protection

  my $query = qq|DELETE FROM parts$form->{db}
                 WHERE $form->{db}_id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

  foreach $i (1 .. $form->{rowcount}) {

    if ($form->{"id_$i"}) {

      if ($form->{db} eq 'customer') {
	for (qw(pricebreak sellprice)) { $form->{"${_}_$i"} = $form->parse_amount($myconfig, $form->{"${_}_$i"}) }
	
	$query = qq|INSERT INTO parts$form->{db} (parts_id, customer_id,
		    pricebreak, sellprice, validfrom, validto, curr)
		    VALUES (|.$form->dbclean($form->{"id_$i"}).qq|, $form->{id},
		    |.$form->dbclean($form->{"pricebreak_$i"}).qq|, |.$form->dbclean($form->{"sellprice_$i"}).qq|,|
		    .$form->dbquote($form->dbclean($form->{"validfrom_$i"}), SQL_DATE) .qq|,|
		    .$form->dbquote($form->dbclean($form->{"validto_$i"}), SQL_DATE) .qq|,
		    |.$dbh->quote($form->{"curr_$i"}).qq|)|;
      } else {
	for (qw(leadtime lastcost)) { $form->{"${_}_$i"} = $form->parse_amount($myconfig, $form->{"${_}_$i"}) }
	
	$query = qq|INSERT INTO parts$form->{db} (parts_id, vendor_id,
		    partnumber, lastcost, leadtime, curr)
		    VALUES (|.$form->dbclean($form->{"id_$i"}).qq|, $form->{id},
		    |.$dbh->quote($form->{"partnumber_$i"}).qq|, $form->{"lastcost_$i"},
		    $form->{"leadtime_$i"}, |.$dbh->quote($form->{"curr_$i"}).qq|)|;

      }
      $dbh->do($query) || $form->dberror($query);
    }

  }

  $_ = $dbh->commit;
  $dbh->disconnect;

}



sub retrieve_item {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $i = $form->{rowcount};
  my $var;
  my $null;

  my $where = "WHERE p.obsolete = '0'";

  if ($form->{db} eq 'vendor') {
    # parts, services, labor
    $where .= " AND p.assembly = '0'";
  }
  if ($form->{db} eq 'customer') {
    # parts, assemblies, services
    $where .= " AND p.income_accno_id > 0";
  }

  if ($form->{"partnumber_$i"} ne "") {
    $var = $form->like(lc $form->{"partnumber_$i"});
    $where .= " AND lower(p.partnumber) LIKE '$var'";
  }
  if ($form->{"description_$i"} ne "") {
    $var = $form->like(lc $form->{"description_$i"});
    $where .= " AND lower(p.description) LIKE '$var'";
  }

  if ($form->{"partsgroup_$i"} ne "") {
    ($null, $var) = split /--/, $form->{"partsgroup_$i"};
    $var *= 1;
    $where .= qq| AND p.partsgroup_id = $var|;
  }
  
  
  my $query = qq|SELECT p.id, p.partnumber, p.description, p.sellprice,
                 p.lastcost, p.unit, pg.partsgroup, p.partsgroup_id
		 FROM parts p
		 LEFT JOIN partsgroup pg ON (pg.id = p.partsgroup_id)
		 $where
		 ORDER BY partnumber|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);
  my $ref;
  $form->{item_list} = ();
  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{item_list} }, $ref;
  }
  $sth->finish;
  $dbh->disconnect;

}


sub ship_to {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query;
  
  $form->{db} = 'vendor' if $form->{db} ne 'customer'; # SQLI protection
  my $table = ($form->{db} eq 'customer') ? 'ar' : 'ap';

  if ($form->{id} *= 1) {
    $query = qq|SELECT
                s.shiptoname, s.shiptoaddress1, s.shiptoaddress2,
                s.shiptocity, s.shiptostate, s.shiptozipcode,
		s.shiptocountry, s.shiptocontact, s.shiptophone,
		s.shiptofax, s.shiptoemail
	        FROM shipto s
		JOIN oe o ON (o.id = s.trans_id)
		WHERE o.$form->{db}_id = |.$form->dbclean($form->{id}).qq|
		UNION
		SELECT
                s.shiptoname, s.shiptoaddress1, s.shiptoaddress2,
                s.shiptocity, s.shiptostate, s.shiptozipcode,
		s.shiptocountry, s.shiptocontact, s.shiptophone,
		s.shiptofax, s.shiptoemail
		FROM shipto s
		JOIN $table a ON (a.id = s.trans_id)
	        WHERE a.$form->{db}_id = |.$form->dbclean($form->{id}).qq|
		EXCEPT
		SELECT
	        s.shiptoname, s.shiptoaddress1, s.shiptoaddress2,
                s.shiptocity, s.shiptostate, s.shiptozipcode,
		s.shiptocountry, s.shiptocontact, s.shiptophone,
		s.shiptofax, s.shiptoemail
		FROM shipto s
		WHERE s.trans_id = |.$form->dbclean($form->{id}).qq||;
	 
    my $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
      push @{ $form->{all_shipto} }, $ref;
    }
    $sth->finish;

  }

  $dbh->disconnect;

}

1;

