#!/usr/bin/perl

use Data::Dumper;
use CGI::FormBuilder;

1;

sub continue { &{ $form->{nextsub} } }

#--------------------------------------------------------------------------------
sub search_domus {

    my @departments = $form->{dbs}->query('select id, description from department order by 2')->arrays;
    my @form1flds   = qw(department_id add_missing);

    my $form1 = CGI::FormBuilder->new(
        method     => 'post',
        table      => 1,
        fields     => \@form1flds,
        required   => [qw(department_id)],
        options    => { department_id => \@departments },
        messages   => { form_required_text => '', },
        labels     => { department_id => $locale->text('Department'), add_missing => $locale->text('Add missing account?'), },
        selectnum  => 2,
        submit     => [qw(Continue)],
        params     => $form,
        stylesheet => 1,
        template   => {
            type     => 'TT2',
            template => 'search.tmpl',
            variable => 'form1',
        },
        keepextras => [qw(id title action path login callback)],
    );
    $form1->fields(name => 'add_missing', type => 'checkbox', options => [qw(Y)]);
    $form->header;
    print $form1->render;
    print qq|
    </table>
  </tr>
</table>
<hr size=3 noshade />
<input type=hidden name=nextsub value="process_domus" >
<input type=submit class=submit name=action value="Continue" >
</form>
<br/>
<br/>
|;

    $form->info( $locale->text('Import preview ...') );

    my $table1 = $form->{dbs}->query(
        qq|
        select c1 reference, c2 transdate, c3 accno, chart.description account_description, c6 project, project.description project_description, c7 source, c8 debit, c9 credit, c10 description
        from generic_import
        left join chart on (chart.accno = generic_import.c3)
        left join project on (project.projectnumber = generic_import.c6)
        order by reference|
      )->xto(
        tr => { class => [ 'listrow0', 'listrow1' ] },
        th => { class => ['listheading'] },
      );
    $table1->set_group( 'reference', 1 );
    $table1->calc_totals(    [qw(debit credit)] );
    $table1->calc_subtotals( [qw(debit credit)] );
    $table1->modify( td => { align => 'right' }, [qw(debit credit)] );

    print $table1->output;

    print qq|
</body>
</html>
|;

}

#--------------------------------------------------------------------------------
sub process_domus {

    use SL::GL;
    my $newform = new Form;
    my @rows = $form->{dbs}->query('select id, c8, c9 from generic_import order by id')->hashes or die( $form->{dbs}->error );
    for (@rows) {
        $form->{dbs}->query( '
           update generic_import set c8 = ?, c9 = ? where id = ?',
            $form->parse_amount( { numberformat => '1.000,00' }, $_->{c8} ),
            $form->parse_amount( { numberformat => '1.000,00' }, $_->{c9} ),
            $_->{id} )
          or die( $form->{dbs}->error );
    }

    @missing_accounts = $form->{dbs}->query('select distinct c3 from generic_import where c3 not in (select accno from chart) order by 1')->hashes;

    if (@missing_accounts){
        if ($form->{add_missing}){
            $form->info("Adding missing accounts ...\n");
            for (@missing_accounts){
               $form->info("$_->{c3} is missing...");
               $form->{dbs}->query('insert into chart (accno, description) values (?, ?)', $_->{c3}, 'New account' ); 
               $form->info(" added.\n");
            }
            $form->{dbs}->commit;
        } else {
            $form->info($locale->text("Missing accounts ...\n"));
            for (@missing_accounts){ $form->info("$_->{c3}\n") }
            $form->error($locale->text('Missing accounts found. Data not imported...'));
        }
    }

    my @gl = $form->{dbs}->query('select distinct c1 from generic_import order by c1')->hashes or die( $form->{dbs}->error );

    $query = qq|SELECT curr FROM curr ORDER BY rn|;
    ( $form->{defaultcurrency} ) = $form->{dbh}->selectrow_array($query);
    $form->{curr} ||= $form->{defaultcurrency};
    $form->{currency} = $form->{curr};

    $form->{department} = $form->{dbs}->query( qq/select description || '--' || id from department where id = ?/, $form->{department_id} )->list;

    my $i;
    my $diff;
    for $gl (@gl) {
        $i     = 1;
        @trans = $form->{dbs}->query( 'select * from generic_import where c1 = ? order by c1', $gl->{c1} )->hashes or die( $form->{dbs}->error );
        $diff  = 0;
        for $trans (@trans) {
            $newform->{currency}    = $form->{currency};
            $newform->{department}  = $form->{department};
            $newform->{reference}   = $trans->{c1};
            $newform->{transdate}   = $trans->{c2};
            $newform->{description} = $trans->{c10};
            $newform->{"projectnumber_$i"} = $form->{dbs}->query( qq/select projectnumber || '--' || id from project where projectnumber = ?/, $trans->{c6} )->list;
            $newform->{"source_$i"}        = $trans->{c7};
            $newform->{"accno_$i"}         = $trans->{c3};
            $newform->{"debit_$i"}         = $trans->{c8};
            $newform->{"credit_$i"}        = $trans->{c9};
            $diff += $trans->{c8} - $trans->{c9};
            $i++;
        }
        $newform->{rowcount} = $i;
        if ( GL->post_transaction( \%myconfig, \%$newform ) ) {
            $form->info(qq| $newform->{reference}|);
            $form->info( " ... " . $locale->text('ok') . "\n" );
            for ( keys %$newform ) { delete $newform->{$_} }
        }
        else {
            $form->error( $locale->text('Posting failed!') );
        }
    }

    $form->{dbs}->commit;

    $form->redirect( $locale->text('Processed!') );
}

#--------------------------------------------------------------------------------
sub search_datev {

    my @departments = $form->{dbs}->query('select id, description from department order by 2')->arrays;
    my @projects    = $form->{dbs}->query('select id, projectnumber from project order by 2')->arrays;
    my @form1flds   = qw(department_id project_id year add_missing);

    my $form1 = CGI::FormBuilder->new(
        method   => 'post',
        table    => 1,
        fields   => \@form1flds,
        required => [qw(year)],
        options  => {
            department_id => \@departments,
            project_id    => \@projects,
            year          => [qw(2013 2014 2015 2016 2017 2018 2019 2020)]
        },
        messages => { form_required_text => '', },
        labels     => { department_id => $locale->text('Department'), add_missing => $locale->text('Add missing account?'), },
        labels   => {
            department_id => $locale->text('Department'),
            project_id    => $locale->text('Project'),
            year          => $locale->text('Year'),
        },
        selectnum  => 2,
        submit     => [qw(Continue)],
        params     => $form,
        stylesheet => 1,
        template   => {
            type     => 'TT2',
            template => 'search.tmpl',
            variable => 'form1',
        },
        keepextras => [qw(id title action path login callback)],
    );
    $form1->fields(name => 'add_missing', type => 'checkbox', options => [qw(Y)]);
    $form1->field( name => 'year', other => 1 );
    $form->header;
    print $form1->render;
    print qq|
    </table>
  </tr>
</table>
<hr size=3 noshade />
<input type=hidden name=nextsub value="process_datev" >
<input type=submit class=submit name=action value="Continue" >
</form>
<br/>
<br/>
|;

    $form->info( $locale->text('Import preview ...') );

    my @rows = $form->{dbs}->query('select id, c1 from generic_import order by id')->hashes or die( $form->{dbs}->error );
    for (@rows) {
        $form->{dbs}->query( '
           update generic_import set c1 = ? where id = ?',
            $form->parse_amount( { numberformat => '1.000,00' }, $_->{c1} ),
            $_->{id} )
          or die( $form->{dbs}->error );
    }

    my $table1 = $form->{dbs}->query(
        qq|
        select c1 amount, c2 dr_cr, c7 debit, c8 credit, c9 source, c10 transdate, c14 description 
        from generic_import
        order by source|
      )->xto(
        tr => { class => [ 'listrow0', 'listrow1' ] },
        th => { class => ['listheading'] },
      ) or die $form->{dbs}->error;
    $table1->calc_totals( [qw(amount)] );

    #$table1->calc_subtotals([qw(amount)]);
    $table1->modify( td => { align => 'right' }, [qw(amount)] );

    print $table1->output;

    print qq|
</body>
</html>
|;

}

#--------------------------------------------------------------------------------
sub process_datev {

    use SL::GL;
    my $newform = new Form;

    @missing_accounts = $form->{dbs}->query('
        select distinct c7 c3 from generic_import where c7 not in (select accno from chart) 
        union
        select distinct c8 from generic_import where c8 not in (select accno from chart) 
        order by 1
    ')->hashes;

    if (@missing_accounts){
        if ($form->{add_missing}){
            $form->info("Adding missing accounts ...\n");
            for (@missing_accounts){
               $form->info("$_->{c3} is missing...");
               $form->{dbs}->query('insert into chart (accno, description) values (?, ?)', $_->{c3}, 'New account' ); 
               $form->info(" added.\n");
            }
            $form->{dbs}->commit;
        } else {
            $form->info($locale->text("Missing accounts ...\n"));
            for (@missing_accounts){ $form->info("$_->{c3}\n") }
            $form->error($locale->text('Missing accounts found. Data not imported...'));
        }
    }

    my @gl = $form->{dbs}->query('select * from generic_import order by id')->hashes or die( $form->{dbs}->error );

    $query = qq|SELECT curr FROM curr ORDER BY rn|;
    ( $form->{defaultcurrency} ) = $form->{dbh}->selectrow_array($query);
    $form->{curr} ||= $form->{defaultcurrency};
    $form->{currency} = $form->{curr};

    if ( $form->{department_id} ) {
        $form->{department} = $form->{dbs}->query( qq/select description || '--' || id from department where id = ?/, $form->{department_id} )->list;
    }
    if ( $form->{project_id} ) {
        $form->{projectnumber} = $form->{dbs}->query( qq/select projectnumber || '--' || id from project where id = ?/, $form->{project_id} )->list;
    }

    my $i;
    my $diff;
    for $gl (@gl) {
        $newform->{currency}        = $form->{currency};
        $newform->{transdate}       = $form->format_date( $myconfig{dateformat}, $form->{year} . substr( $gl->{c10}, 2, 2 ) . substr( $gl->{c10}, 0, 2 ) );
        $newform->{description}     = $gl->{c14};
        $newform->{department}      = $form->{department};
        $newform->{projectnumber_1} = $form->{projectnumber};
        $newform->{projectnumber_2} = $form->{projectnumber};

        if ( $gl->{c2} eq 'S' ) {

            # debit
            $newform->{"accno_1"}  = $gl->{c7};
            $newform->{"debit_1"}  = $gl->{c1};
            $newform->{"credit_1"} = 0;

            $newform->{"accno_2"}  = $gl->{c8};
            $newform->{"debit_2"}  = 0;
            $newform->{"credit_2"} = $gl->{c1};
        }
        else {

            # credit
            $newform->{"accno_1"}  = $gl->{c8};
            $newform->{"debit_1"}  = $gl->{c1};
            $newform->{"credit_1"} = 0;

            $newform->{"accno_2"}  = $gl->{c7};
            $newform->{"debit_2"}  = 0;
            $newform->{"credit_2"} = $gl->{c1};
        }
        $newform->{"source_1"} = $gl->{c9};
        $newform->{"source_2"} = $gl->{c9};

        $newform->{rowcount} = 3;
        if ( GL->post_transaction( \%myconfig, \%$newform ) ) {
            $form->info(qq| $newform->{reference}|);
            $form->info( " ... " . $locale->text('ok') . "\n" );
            for ( keys %$newform ) { delete $newform->{$_} }
        }
        else {
            $form->error( $locale->text('Posting failed!') );
        }
    }

    $form->{dbs}->commit;
    $form->redirect( $locale->text('Processed!') );
}

#########
### EOF
#########

