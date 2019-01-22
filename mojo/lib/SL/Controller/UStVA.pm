package SL::Controller::UStVA;
use strict;
use warnings;
use utf8;
use Mojo::Base 'Mojolicious::Controller';
use Mojolicious::Static;
use Mojo::File;

use SL::Model::Config;
use SL::Model::Calc::Document;

use Time::Piece;
use Time::Seconds;
use Data::Dumper;



sub download {
    my $c = shift;

    my $conf = SL::Model::Config->instance($c);

    my $workdir = $c->private_spool_realm("ustva", empty => 1);



    my $doc = SL::Model::Calc::Document->new(
        config    => $conf,
        src       => "ustva-template.ods",
        dest      => "ustva.ods",
        workdir   => $workdir,
    );


    # fromdate is simple: YYYY-MM-01
    my $fromdate = join("-", $c->param("year"), $c->param("month"), "01");

    # todate: Add (interval-1) months and three days (to reach the following
    # month for sure).
    # Then detect the last day of this month.

    my $t1 = Time::Piece->strptime($fromdate, "%Y-%m-%d");
    my $t2 = $t1 + ONE_MONTH * ($c->param("interval")-1) + ONE_DAY*3;

    
    my $todate = sprintf("%d-%02d-%02d",
                         $t2->year,
                         $t2->mon,
                         $t2->month_last_day);


    # Headline:
    $doc->fill_in(
        cells => ["B1"],
        text  => ["Umsatzsteuer-Voranmeldung " . $c->param("year")],
    );

    
    # Voranmeldungszeitraum:
    my $interval = $c->param("interval");
    
    if ($interval == 1) { # Month
        my %field_map = (
            '01' => "G4", '02' => "G5", '03' => "G6",
            '04' => "G7", '05' => "G8", '06' => "G9",
            '07' => "I4", '08' => "I5", '09' => "I6",
            '10' => "I7", '11' => "I8", '12' => "I9",
        );

        $doc->fill_in(
            cells => [$field_map{$c->param("month")}],
            text  => ["X"],
        );   
    }
    elsif ($interval == 3) { # Quarter
        my %field_map = (
            '01' => "K4",
            '04' => "K5",
            '07' => "K6",
            '10' => "K7",
        );

        $doc->fill_in(
            cells => [$field_map{$c->param("month")}],
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

    $doc->fill_in(
        cells    => ["B9"],
        from_sql => "company/businessnumber",
    );

    $doc->fill_in(
        cells    => ["D9"],
        from_sql => "company/ust_idnr",
    );


    # Create inline tax view:
    SL::Model::SQL::Statement->new(
        config => $conf,
        query  => "ustva/create_view_inline_tax",
    )->execute;



    $doc->fill_in(
        cells    => ["H17"],
        from_sql => "ustva/41",
        bind_values => [$fromdate, $todate],
    );

    $doc->fill_in(
        cells    => ["H18"],
        from_sql => "ustva/43",
        bind_values => [$fromdate, $todate],
    );

    $doc->fill_in(
        cells    => ["H20"],
        from_sql => "ustva/81",
        bind_values => [$fromdate, $todate],
    );

    $doc->fill_in(
        cells    => ["H21"],
        from_sql => "ustva/86",
        bind_values => [$fromdate, $todate],
    );

    $doc->fill_in(
        cells    => ["H22"],
        from_sql => "ustva/89",
        bind_values => [$fromdate, $todate],
    );

    $doc->fill_in(
        cells    => ["H24"],
        from_sql => "ustva/21",
        bind_values => [$fromdate, $todate],
    );

    $doc->fill_in(
        cells    => ["H27"],
        from_sql => "ustva/45",
        bind_values => [$fromdate, $todate],
    );

    
    $doc->fill_in(
        cells    => ["H31"],
        from_sql => "ustva/46",
        bind_values => [$fromdate, $todate],
    );

    $doc->fill_in(
        cells    => ["H34"],
        from_sql => "ustva/52",
        bind_values => [$fromdate, $todate],
    );

    $doc->fill_in(
        cells    => ["J43"],
        from_sql => "ustva/66",
        bind_values => [$fromdate, $todate],
    );

    $doc->fill_in(
        cells    => ["J44"],
        from_sql => "ustva/61",
        bind_values => [$fromdate, $todate],
    );
    
    $doc->fill_in(
        cells    => ["J45"],
        from_sql => "ustva/62",
        bind_values => [$fromdate, $todate],
    );
    
    $doc->fill_in(
        cells    => ["J47"],
        from_sql => "ustva/67",
        bind_values => [$fromdate, $todate],
    );

    $doc->fill_in(
        cells    => ["C65", "F65", "I65"],
        types    => ["string", "float", "float" ],
        from_sql => "ustva/page2",
        multirow => 1,
        bind_values => [$fromdate, $todate],
    );

    $doc->fill_in(
        cells    => ["C112", "C113", "C114", "C118", "C120"],
        from_sql => "ustva/finanzamt",
        bind_values => ['Finanzamt']
    );
    
    $doc->save; # Everything has been filled in.

    
    # Build download filename:
    my $firma = $firma_info->[0];
    $firma =~ s/\s+$//;
    $firma =~ s/\s/_/g;

    my $datetag;

    if ($c->param('interval') == 1) {
        $datetag = sprintf("%d-%02d", $t1->year, $t1->mon);
    }
    elsif ($c->param('interval') == 3) {
        $datetag = sprintf("%d-Q%d", $t1->year, int($t1->_mon / 3) + 1);
    }
    elsif ($c->param('interval') == 12) {
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
