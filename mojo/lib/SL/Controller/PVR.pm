package SL::Controller::PVR;
use Mojo::Base 'Mojolicious::Controller';

use Mojolicious::Static;
use Mojo::File;

use SL::Model::Config;
use SL::Model::Calc::Document;
use SL::Model::SQL::Statement;

use utf8;
use Time::Piece;
use Time::Seconds;
use File::Path qw(make_path remove_tree);


sub start {
    my $c = shift;

    my $conf = SL::Model::Config->instance($c);
    
    my $sth = SL::Model::SQL::Statement->new(
        config => $conf,
        query  => "common/earliest_trans_year"
    );
    
    my $result = $sth->execute->fetch;
    
    $c->render("pvr/start", earliest_trans_year => $result->[0][0]);
}


sub generate {
    my $c = shift;

    my $conf = SL::Model::Config->instance($c);

    my $workdir = File::Spec->catfile(
        $conf->val('x_myspool'),
        "_pvr"
    );

    make_path($workdir);
    remove_tree($workdir, {keep_root => 1} );

    $c->app->plugin('SL::Helper::DateIntervalPicker');
    
    my ($from_iso, $to_iso, $interval) = $c->foo;

    unless (defined($from_iso) && defined($to_iso)) {
        $c->render("pvr/start", value_error => 1);
        return;
    }

    my $t1 = Time::Piece->strptime($from_iso, "%Y-%m-%d");
    my $t2 = Time::Piece->strptime($to_iso,   "%Y-%m-%d");

    my $delta = $t2 - $t1;
    my $days = $delta->days;
    
    
    my $doc = SL::Model::Calc::Document->new(
        config    => $conf,
        src       => "ustva-template.ods",
        dest      => "ustva.ods",
        workdir   => $workdir,
    );


    # Headline:
    my $headline = "Umsatzsteuer-Voranmeldung " . $t1->year;
    $doc->fill_in(
        cells => ["B1"],
        text  => [$headline],
    );

    
    # Voranmeldungszeitraum:
    
    if ($interval eq 'month') {
        my %field_map = (
             '1' => "G4",  '2' => "G5",  '3' => "G6",
             '4' => "G7",  '5' => "G8",  '6' => "G9",
             '7' => "I4",  '8' => "I5",  '9' => "I6",
            '10' => "I7", '11' => "I8", '12' => "I9",
        );

        $doc->fill_in(
            cells => [$field_map{$t1->mon}],
            text  => ["X"],
        );   
    }
    elsif ($interval eq 'quarter') {
        my %field_map = (
             '1' => "K4",
             '4' => "K5",
             '7' => "K6",
            '10' => "K7",
        );

        $doc->fill_in(
            cells => [$field_map{$t1->mon}],
            text  => ["X"],
        );   
    }


    # Method: NULL = Accrual, "cash" = Cash
    my $method = SL::Model::SQL::Statement->new(
        config => $conf,
        query  => "company/method",
    )->execute->fetch->[0][0];

    $doc->fill_in(
        cells => [defined $method? "E6" : "E7"],
        text  => ["X"],
    );   
    
    
    
    my $firma_info = $doc->fill_in(
        cells    => ["B4", "B5", "B6"],
        from_sql => "company/name_address",
    );

    my $result_b9 = $doc->fill_in(
        cells    => ["B9"],
        from_sql => "company/businessnumber",
    );

    my $result_d9 = $doc->fill_in(
        cells    => ["D9"],
        from_sql => "company/ust_idnr",
    );


    # Create inline tax view:
    SL::Model::SQL::Statement->new(
        config => $conf,
        query  => "ustva/create_view_inline_tax",
    )->execute;



    my $result_h17 = $doc->fill_in(
        cells    => ["H17"],
        from_sql => "ustva/41",
        bind_values => [$from_iso, $to_iso],
    );

    $doc->fill_in(
        cells    => ["H18"],
        from_sql => "ustva/43",
        bind_values => [$from_iso, $to_iso],
    );

    my $result_hj20 = $doc->fill_in(
        cells    => ["H20", "J20"],
        from_sql => "ustva/81",
        bind_values => [$from_iso, $to_iso],
    );

    my $result_hj21 = $doc->fill_in(
        cells    => ["H21", "J21"],
        from_sql => "ustva/86",
        bind_values => [$from_iso, $to_iso],
    );

    my $result_hj22 = $doc->fill_in(
        cells    => ["H22", "J22"],
        from_sql => "ustva/89",
        bind_values => [$from_iso, $to_iso],
    );

    my $result_h24 = $doc->fill_in(
        cells    => ["H24"],
        from_sql => "ustva/21",
        bind_values => [$from_iso, $to_iso],
    );

    $doc->fill_in(
        cells    => ["H27"],
        from_sql => "ustva/45",
        bind_values => [$from_iso, $to_iso],
    );

    
    my $result_hj31 = $doc->fill_in(
        cells    => ["H31", "J31"],
        from_sql => "ustva/46",
        bind_values => [$from_iso, $to_iso],
    );

    my $result_hj34 = $doc->fill_in(
        cells    => ["H34", "J34"],
        from_sql => "ustva/84",
        bind_values => [$from_iso, $to_iso],
    );


    
    my $j36 = sprintf("%.2f", $result_hj20->[1] + $result_hj21->[1] +
                          $result_hj22->[1] + $result_hj31->[1] +
                          $result_hj34->[1]);

    $doc->fill_in(
        cells => ["J36"],
        text  => [$j36],
    );   


    my $result_j43 = $doc->fill_in(
        cells    => ["J43"],
        from_sql => "ustva/66",
        bind_values => [$from_iso, $to_iso],
    );

    my $result_j44 = $doc->fill_in(
        cells    => ["J44"],
        from_sql => "ustva/61",
        bind_values => [$from_iso, $to_iso],
    );
    
    my $result_j45 = $doc->fill_in(
        cells    => ["J45"],
        from_sql => "ustva/62",
        bind_values => [$from_iso, $to_iso],
    );
    
    my $result_j47 = $doc->fill_in(
        cells    => ["J47"],
        from_sql => "ustva/67",
        bind_values => [$from_iso, $to_iso],
    );


    my $j50 = sprintf("%.2f", $j36 +
                          $result_j43->[0] + $result_j44->[0] +
                          $result_j45->[0] + $result_j47->[0]);
    
    $doc->fill_in(
        cells => ["J50"],
        text  => [$j50],
    );   

    $doc->fill_in(
        cells => ["J56"],
        types => ["string"],
        text  => [$result_d9->[0]],
    );   
    $doc->fill_in(
        cells => ["J59"],
        text  => [$result_h17->[0] + $result_h24->[0]],
    );   

    
    my $result_cfij65 = $doc->fill_in(
        cells    => ["C65", "F65", "I65", "J65"],
        types    => ["string", "float", "float", "string" ],
        from_sql => "ustva/page2",
        multirow => 1,
        bind_values => [$from_iso, $to_iso],
    );

    my $sum_non_eu = 0;
    $sum_non_eu += $_->[1] foreach @$result_cfij65;
    $doc->fill_in(
        cells => ["J60"],
        text  => [int($sum_non_eu)],
    );   


    $doc->fill_in(
        cells    => ["C112", "C113", "C114", "C118", "C120"],
        from_sql => "ustva/finanzamt",
        bind_values => ['Finanzamt']
    );


    $doc->fill_in(
        cells => ["J110"],
        text  => [$j50],
    );   

    $doc->fill_in(
        cells => ["C116", "D116"],
        text  => [$result_b9->[0], $headline],
    );   


    $doc->save; # Everything has been filled in.

    
    # Build download filename:
    my $firma = $firma_info->[0];
    $firma =~ s/\s+$//;
    $firma =~ s/\s/_/g;

    my $datetag;

    if ($interval eq 'month') {
        $datetag = sprintf("%d-%02d", $t1->year, $t1->mon);
    }
    elsif ($interval eq 'quarter') {
        $datetag = sprintf("%d-Q%d", $t1->year, int($t1->_mon / 3) + 1);
    }
    elsif ($interval eq 'year') {
        $datetag = sprintf("%d", $t1->year);
    }
    
    $doc->download_name("${firma}_Umsatzsteuer-Voranmeldung_$datetag.ods");


    my $static = Mojolicious::Static->new( paths => [ $workdir ] );

    $c->res->headers->content_type("application/octet-stream");
    $c->res->headers->content_disposition(
        "attachment; filename=$doc->{download_name}"
    );

    $static->serve($c, $doc->{download_name});

    $c->rendered();
}

1;
