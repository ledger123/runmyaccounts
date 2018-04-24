#!/usr/bin/perl

#----------------------------------------------------------------------------------------
# Docs: http://search.cpan.org/~nwiger/CGI-FormBuilder-3.08/lib/CGI/FormBuilder.pod
#----------------------------------------------------------------------------------------

# CURRENT PROBLEMS IN THIS CRIPT
#- Subtotals / totals are not formatted as number.
#- Edit link is only on ID. For other columns we need to modify sql select.
#- Title is not correctly displayed from template.
#- Sorting on a column does not make it as first column.
#- More than 10 columns in report display totals and subtotals
#- Date widget

use Data::Dumper;
use CGI::FormBuilder;

1;

sub continue { &{ $form->{nextsub} } }

sub list_trans {

    use DBIx::Simple;
    my $dbh = $form->dbconnect(\%myconfig);
    my $dbs = DBIx::Simple->connect($dbh);

    $form->header;
    print qq|<h1>Clearing Account Adjustment</h1>|;
    my $query = "
      SELECT gl.reference, ac.transdate, ac.source, ac.memo,
      (case when ac.amount < 0 then 0 - ac.amount else 0 end) debit,
      (case when ac.amount > 0 then ac.amount else 0 end) credit
      FROM acc_trans ac
      JOIN gl ON gl.id = ac.trans_id
      WHERE ac.trans_id = ?
      AND ac.chart_id = (SELECT id FROM chart WHERE accno = ?)
    ";

    $table = $dbs->query( $query, $form->{trans_id}, $form->{accno} )->xto();
    $table->modify( table => { cellpadding => "3", cellspacing => "2" } );
    $table->modify( tr => { class => [ 'listrow0', 'listrow1' ] } );
    $table->modify( th => { class => 'listheading' }, 'head' );
    $table->modify( th => { class => 'listtotal' },   'foot' );
    $table->modify( th => { class => 'listsubtotal' } );
    $table->modify( th => { align => 'center' },      'head' );
    $table->modify( th => { align => 'right' },       'foot' );
    $table->modify( th => { align => 'right' } );

    $table->modify( td => { align => 'right' }, [qw(debit credit)] );
    #$table->calc_totals( [qw(count)] );
    print $table->output;

    $query = "
      SELECT
      (case when ac.amount < 0 then 0 - ac.amount else 0 end) debit,
      (case when ac.amount > 0 then ac.amount else 0 end) credit
      FROM acc_trans ac
      JOIN gl ON gl.id = ac.trans_id
      WHERE ac.trans_id = ?
      AND ac.chart_id = (SELECT id FROM chart WHERE accno = ?)
    ";
    my ($debit, $credit) = $dbs->query( $query, $form->{trans_id}, $form->{accno} )->list or $form->error($dbs->error);
    $search_amount = $debit + $credit; # one value will be always 0

    my @form1flds = qw(fromdate todate arap gl_account_id);
    $form->{nextsub}  = 'list_trans';
    $form->{arap} = 'ap' if $debit;
    $form->{arap} = 'ar' if $credit;

    my $form1 = CGI::FormBuilder->new(
        method     => 'post',
        table      => 1,
        title      => $locale->text('Select a transaction'),
        fields     => \@form1flds,
        required   => [qw(arap)],
        options => {
            arap => [qw(ar ap)],
            gl_account_id => \@chart,
        },
        messages   => { form_required_text => '', },
        selectnum  => 0,
        submit     => ["Continue"],
        params     => $form,
        stylesheet => 1,
        template   => {
            type     => 'TT2',
            template => 'search.tmpl',
            variable => 'form1',
        },
        keepextras => [qw(trans_id accno nextsub action path login callback)],
    );
    $form1->field( name => 'fromdate', class => 'date', size => 10 );
    $form1->field( name => 'todate', class => 'date', size => 10 );
    print $form1->render;

    my @bind = ();
    my $where;

    if ( $form->{fromdate} ) {
        $where .= qq| AND aa.transdate >= ?|;
        push @bind, $form->{fromdate};
    }
    if ( $form->{todate} ) {
        $where .= qq| AND aa.transdate <= ?|;
        push @bind, $form->{todate};
    }

    my $arap = $form->{arap};
    my $vc = $arap eq 'ar' ? 'customer' : 'vendor';
    my $query = qq|
        SELECT
           aa.id, aa.invnumber, aa.transdate, aa.description, aa.amount, aa.paid, aa.amount - aa.paid due
        FROM $arap aa
        JOIN $vc vc ON (vc.id = aa.${vc}_id)
        WHERE aa.amount - aa.paid > 0
        $where
        ORDER BY aa.transdate|;
    my @allrows = $dbs->query( $query, @bind )->hashes or die( 'No transactions found ...' );

    my @report_columns = qw(x invnumber transdate description amount paid due);
    my @total_columns = qw(amount paid due);
    my ( %tabledata, %totals, %subtotals );

    for (@report_columns) { $tabledata{$_} = qq|<th><a class="listheading">| . ucfirst $_ . qq|</th>\n| }

    my @chart = $dbs->query("SELECT id, accno || '--' || substr(description,1,30) descrip FROM chart WHERE charttype='A' ORDER BY accno")->hashes;
    my $selectaccno = "<option>\n";
    for (@chart){ $selectaccno .= "<option value=$_->{id}>$_->{descrip}\n" }

    print qq|
<form action="$form->{script}" method="post">
<input type=submit class=button name=action value="Book selected transactions">
<table>
<tr>
<th>GL Account</th><td><select name=gl_account_id>$selectaccno</select></td>
</tr>
</table>

        <table cellpadding="3" cellspacing="2">
        <tr class="listheading">
|;
    for (@report_columns) { print $tabledata{$_} }

    print qq|
        </tr>
|;

    my $sort = 'transdate';
    $form->{l_subtotal} = 0;
    my $groupvalue;
    my $i = 0;
    my $j = 1;
    my $link;
    for $row (@allrows) {
        $groupvalue = $row->{$sort} if !$groupvalue;
        if ( $form->{l_subtotal} and $row->{$sort} ne $groupvalue ) {
            for (@report_columns) { $tabledata{$_} = qq|<td>&nbsp;</td>| }
            $subtotals{balance} = $balance;
            for (@total_columns) { $tabledata{$_} = qq|<th align="right">| . $form->format_amount( \%myconfig, $subtotals{$_}, 2 ) . qq|</th>| }

            print qq|<tr class="listsubtotal">|;
            for (@report_columns) { print $tabledata{$_} }
            print qq|</tr>\n|;
            $groupvalue = $row->{$sort};
            for (@total_columns) { $subtotals{$_} = 0 }
        }
        for (@report_columns) { $tabledata{$_} = qq|<td>$row->{$_}</td>| }

        $url = qq|$arap.pl?id=$row->{id}&action=edit&path=$form->{path}&login=$form->{login}&callback=$form->{callback}|;
        $tabledata{invnumber} = qq|<td><a href="$url" target=_blank>$row->{invnumber}</a></td>|;

        $row->{amount} *= 1;
        $checked = '';
        if ($row->{amount} eq $search_amount){
            $checked = 'checked';
        }
        $tabledata{x} = qq|<td><input type=checkbox class=checkbox name=x_$j $checked><input type=hidden name=id_$j value=$row->{id}></td>|;
        for (@total_columns) { $tabledata{$_} = qq|<td align="right">| . $form->format_amount( \%myconfig, $row->{$_}, 2 ) . qq|</td>| }
        for (@total_columns) { $totals{$_}    += $row->{$_} }
        for (@total_columns) { $subtotals{$_} += $row->{$_} }

        print qq|<tr class="listrow$i">|;
        for (@report_columns) { print $tabledata{$_} }
        print qq|</tr>\n|;
        $i += 1; $j += 1;
        $i %= 2;
    }

    for (@report_columns) { $tabledata{$_} = qq|<td>&nbsp;</td>| }
    for (@total_columns) { $tabledata{$_} = qq|<th align="right">| . $form->format_amount( \%myconfig, $subtotals{$_}, 2 ) . qq|</th>| }

    if ( $form->{l_subtotal} ) {
        print qq|<tr class="listsubtotal">|;
        for (@report_columns) { print $tabledata{$_} }
        print qq|</tr>\n|;
    }

    for (@total_columns) { $tabledata{$_} = qq|<th align="right">| . $form->format_amount( \%myconfig, $totals{$_}, 2 ) . qq|</th>| }
    print qq|<tr class="listtotal">|;
    for (@report_columns) { print $tabledata{$_} }
    $form->hide_form(qw(path login trans_id accno));
    print qq|</tr>
</table>
<input type=hidden name=rowcount value=$j>
</form>
<hr/>
|;


}

sub book_selected_transactions {
   $trans_id = $form->{trans_id};
   $accno = $form->{accno};

    use DBIx::Simple;
    my $dbh = $form->dbconnect(\%myconfig);
    my $dbs = DBIx::Simple->connect($dbh);

    $form->header;
    print qq|<h1>Final step: Clearing Account Adjustment</h1>|;
    my $query = "
      SELECT gl.id, gl.reference, ac.transdate, ac.source, ac.memo,
      (case when ac.amount < 0 then 0 - ac.amount else 0 end) debit,
      (case when ac.amount > 0 then ac.amount else 0 end) credit
      FROM acc_trans ac
      JOIN gl ON gl.id = ac.trans_id
      WHERE ac.trans_id = ?
      AND ac.chart_id = (SELECT id FROM chart WHERE accno = ?)";

    $table = $dbs->query( $query, $form->{trans_id}, $form->{accno} )->xto();
    $table->modify( table => { cellpadding => "3", cellspacing => "2" } );
    $table->modify( tr => { class => [ 'listrow0', 'listrow1' ] } );
    $table->modify( th => { class => 'listheading' }, 'head' );
    $table->modify( th => { class => 'listtotal' },   'foot' );
    $table->modify( th => { class => 'listsubtotal' } );
    $table->modify( th => { align => 'center' },      'head' );
    $table->modify( th => { align => 'right' },       'foot' );
    $table->modify( th => { align => 'right' } );

    $table->modify( td => { align => 'right' }, [qw(debit credit)] );
    #$table->calc_totals( [qw(count)] );
    $table->map_cell(
        sub {
            my $datum = shift;
            return qq|<a href="gl.pl?action=edit&id=$datum&path=$form->{path}&login=$form->{login}">$datum</a>|;
        },
        'id'
    );

    print qq|<h3>Clearing account transaction ...</h3>|;
    print $table->output;

   my $trans;
   for $i (1 .. $form->{rowcount} - 1){
       $trans .= qq|$form->{"id_$i"},| if $form->{"x_$i"};
   }
   chop $trans;

   my $table;

   if ($trans){
       $query = "
          SELECT 'ar.pl' module
          FROM ar
          WHERE id IN ($trans)

          UNION ALL

          SELECT 'ap.pl' module
          FROM ap
          WHERE id IN ($trans)

          ORDER BY 1";

       my $module = $dbs->query($query)->list;

       $query = "
          SELECT id, ar.invnumber, ar.transdate, ar.amount
          FROM ar
          WHERE id IN ($trans)

          UNION ALL

          SELECT id, ap.invnumber, ap.transdate, ap.amount
          FROM ap
          WHERE id IN ($trans)

          ORDER BY 1";

        $table = $dbs->query( $query )->xto();
        $table->modify( table => { cellpadding => "3", cellspacing => "2" } );
        $table->modify( tr => { class => [ 'listrow0', 'listrow1' ] } );
        $table->modify( th => { class => 'listheading' }, 'head' );
        $table->modify( th => { class => 'listtotal' },   'foot' );
        $table->modify( th => { class => 'listsubtotal' } );
        $table->modify( th => { align => 'center' },      'head' );
        $table->modify( th => { align => 'right' },       'foot' );
        $table->modify( th => { align => 'right' } );

        $table->modify( td => { align => 'right' }, [qw(amount)] );
        $table->calc_totals( [qw(amount)] );
        print qq|<h3>Transactions to be adjusted ...</h3>|;

        $table->map_cell(
            sub {
                my $datum = shift;
                return qq|<a href="$module?action=edit&id=$datum&path=$form->{path}&login=$form->{login}">$datum</a>|;
            },
            'id'
        );
        print $table->output;
   } elsif ($form->{gl_account_id}) {
        my $query = qq|SELECT accno, description FROM chart WHERE id = ?|;
        $table = $dbs->query( $query, $form->{gl_account_id} )->xto();
        $table->modify( table => { cellpadding => "3", cellspacing => "2" } );
        $table->modify( tr => { class => [ 'listrow0', 'listrow1' ] } );
        $table->modify( th => { class => 'listheading' }, 'head' );
        $table->modify( th => { class => 'listtotal' },   'foot' );
        $table->modify( th => { class => 'listsubtotal' } );
        $table->modify( th => { align => 'center' },      'head' );
        $table->modify( th => { align => 'right' },       'foot' );
        $table->modify( th => { align => 'right' } );
        print $table->output;
   } else {
      return;
   }

   print qq|
<form action="$form->{script}" method="post">
<input type=hidden name=trans_id value="$form->{trans_id}">
<input type=hidden name=gl_account_id value="$form->{gl_account_id}">
<input type=hidden name=accno value="$form->{accno}">
<input type=hidden name=trans value="$trans">
<input type=hidden name=login value="$form->{login}">
<input type=hidden name=path value="$form->{path}">
<input type=submit name=action value="Just do it">
|;

}

sub just_do_it {
   use DBIx::Simple;
   my $dbh = $form->dbconnect_noauto(\%myconfig);
   my $dbs = DBIx::Simple->connect($dbh);

   my $clearing_accno_id = $dbs->query("SELECT id FROM chart WHERE accno = (SELECT fldvalue FROM defaults WHERE fldname='selectedaccount')")->list;
   my $transition_accno_id = $dbs->query("SELECT id FROM chart WHERE accno = (SELECT fldvalue FROM defaults WHERE fldname='transitionaccount')")->list;

   $form->info("Trans id: $form->{trans_id}\n");
   $form->info("Accno: $form->{accno}\n");
   $form->info("Trans: $form->{trans}\n");
   $form->info("Clearing: $clearing_accno_id\n");
   $form->info("Transition: $transition_accno_id\n");

   if ($form->{gl_account_id}){
      $dbs->query("
        UPDATE acc_trans SET chart_id = ? WHERE chart_id = ? AND trans_id = ?",
           $form->{gl_account_id}, $clearing_accno_id, $form->{trans_id}
      );
      $dbs->commit;
      $form->info("GL entry updated ...");
      return;
   }

   # Amount to be adjusted
   my $amount = $dbs->query("SELECT ABS(amount) FROM acc_trans WHERE chart_id = ? AND trans_id = ? ",
       $clearing_accno_id, $form->{trans_id}
   )->list;

   # Update GL transaction and replace clearing account with transition account
   $dbs->query("
      UPDATE acc_trans SET chart_id = ? WHERE chart_id = ? AND trans_id = ?",
         $transition_accno_id, $clearing_accno_id, $form->{trans_id}
   );

   # Get payment date from GL transaction
   my $payment_date = $dbs->query("SELECT transdate FROM gl WHERE id = ?", $form->{trans_id})->list;

   # Add payment row to each AR/AP transactions which are to be updated
   $query = "
      SELECT id, 'ar' tbl, ar.invnumber, ar.transdate, ar.amount-ar.paid due
      FROM ar
      WHERE id IN ($form->{trans})

      UNION ALL

      SELECT id, 'ap' tbl, ap.invnumber, ap.transdate, ap.amount-ap.paid due
      FROM ap
      WHERE id IN ($form->{trans})

      ORDER BY 1";

   @rows = $dbs->query($query)->hashes;

   for (@rows){
      my $arap = uc $_->{tbl};
      my $ml = $arap eq 'ar' ? 1 : -1;
      my $arap_accno_id = $dbs->query("
         SELECT chart_id FROM acc_trans WHERE trans_id = ? AND chart_id IN (SELECT id FROM chart WHERE link LIKE '$arap') LIMIT 1", $_->{id}
      )->list;
      $dbs->query("
        INSERT INTO acc_trans(trans_id, chart_id, transdate, amount)
        VALUES (?, ?, ?, ?)", $_->{id}, $transition_accno_id, $payment_date, $amount
      ) or $form->error($dbs->error);
      $dbs->query("
        INSERT INTO acc_trans(trans_id, chart_id, transdate, amount)
        VALUES (?, ?, ?, ?)", $_->{id}, $arap_accno_id, $payment_date, $amount * $ml
      ) or $form->error($dbs->error);
      $dbs->query("UPDATE $arap SET paid = paid + ? WHERE id = ?", $amount, $_->{id}) or $form->error($dbs->error);
   }
   $dbs->commit;

   $form->info("It is done ...");
}


#########
### EOF
#########

