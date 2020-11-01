################################
package SL::Model::GoBD::Export;
################################
use strict;
use warnings;
use feature ':5.10';
use Carp;
use Data::Dumper;
use Cwd qw(abs_path cwd);

use File::Basename;
use File::pushd;
use File::Copy;
use File::Spec;
use File::Path qw(make_path remove_tree);

use Time::Piece;
use Module::Load;
use XML::LibXML;
use Text::CSV_XS;
use Mojo::Pg;
use utf8;

use SL::Model::Log;

sub new {
    my $class = shift;
    my %args = @_;

    my $self = {
        config      => $args{config},
        from        => $args{from}, # ISO Format
        to          => $args{to},   # ISO Format
        log         => SL::Model::Log->new(),
    };

    $self->{workdir} = File::Spec->catfile(
        $self->{config}->val('x_myspool'),
        "_gobd"
    );

    # workdir is now something like /srv/www/sql-ledger/spool/john/_gobd.
    # ensure that it exists and is empty:
    make_path($self->{workdir});
    remove_tree($self->{workdir}, {keep_root => 1} );
    
    
    bless $self, $class;

    return $self;
}        

sub log { shift->{log} }


sub create {
    my $self = shift;


    my @tables = (
        'SL::Model::GoBD::Table::Firma',
        'SL::Model::GoBD::Table::Kontenplan',
        'SL::Model::GoBD::Table::Journal',
        'SL::Model::GoBD::Table::SummenSalden',
        #'SL::Model::GoBD::Table::DebitorenKreditoren',
    );


    foreach my $class (@tables) {
        load $class;

        push @{$self->{table_objects}}, $class->new(
            config => $self->{config},
            from   => $self->{from},
            to     => $self->{to},
            log    => $self->{log}
        );
    }

    $self->create_table_files();
    $self->create_dtd();
    $self->create_index_xml();

    $self->create_zip();
}




sub create_table_files {
    my $self = shift;

    {
        my $dir = pushd($self->{workdir});


        foreach my $obj (@{$self->{table_objects}}) {

            my $csv = Text::CSV_XS->new($obj->{csv_settings});

            my $csvfile;
            
            open($csvfile, ">:encoding(UTF8)", $obj->filename) || die $!;

            # Headline:
            $csv->combine(map { $_->{name} } $obj->columns);
            print $csvfile $csv->string();
            
            # Data:
            foreach my $rowref (@{ $obj->data }) {
                $csv->combine(
                    map { utf8::upgrade (my $x = $_); $x } @$rowref
                ) || die "@$rowref";
                
                print $csvfile $csv->string();
            }
            close $csvfile;
        }
    }
}



sub create_index_xml {
    my $self = shift;

    {
        my $dir = pushd($self->{workdir});

        my $doc = XML::LibXML::Document->new('1.0', 'utf-8');

        my $root = $doc->createElement("DataSet");
        $doc->setDocumentElement($root);

        $doc->createInternalSubset( "DataSet", undef, "gdpdu-01-08-2002.dtd" );

        $root->appendTextChild("Version", "2.0");

        my $ds = XML::LibXML::Element->new('DataSupplier');
        $root->addChild($ds);


        my $pg = Mojo::Pg->new($self->{config}->val('x_pg_connstr'));

        my $sql = qq|
        SELECT * FROM
        (
          SELECT fldvalue FROM defaults WHERE fldname = 'company'
          UNION ALL
          SELECT NULL
          LIMIT 1
        ) AS company,
        (
          SELECT fldvalue FROM defaults WHERE fldname = 'city'
          UNION ALL
          SELECT NULL
          LIMIT 1
        ) AS city
        |;


        my $data = $pg->db->query($sql)->arrays;

        utf8::upgrade(my $name     = $data->[0][0]);
        utf8::upgrade(my $location = $data->[0][1]);

        $ds->appendTextChild("Name",     $name);
        $ds->appendTextChild("Location", $location);


        my $now = localtime;
        $ds->appendTextChild(
            "Comment",
            "Datenträgerüberlassung nach GoBD; erzeugt am " . $now->dmy(".")
        );

        my $media = XML::LibXML::Element->new('Media');
        $root->addChild($media);

        $media->appendTextChild("Name", "CSV-Set 1");


        foreach my $obj (@{$self->{table_objects}}) {
            $media->addChild($obj->xmltree);
        }

        my $doc_as_string = $doc->toString(1);

        $doc_as_string =~ s|XMLENT\((\d+)\)|&#$1;|g;

        # Validation:
        my $parser = XML::LibXML->new();

        $parser->validation(1);

        eval {
            $parser->parse_string( $doc_as_string );
        };

        if (my $msg = $@) {
            $msg =~ s/</&lt;/g;
            $self->log->error("<pre>$msg</pre>");
        }

        open(my $index, ">:crlf", "index.xml") || die $!;
        print $index  $doc_as_string;
        close $index;
    }
}




sub create_dtd {
    my $self = shift;

    my $resource_path = abs_path(File::Spec->catfile(
        dirname(__FILE__),
        'resources'
    ));

    my $dtd_filename = 'gdpdu-01-08-2002.dtd';

    $self->{dtd_filename} = $dtd_filename;
    copy("$resource_path/$dtd_filename", $self->{workdir}) || die $!;
}




sub create_zip {
    my $self = shift;

    my $now = localtime;
    $self->{archive_name} =
        $now->ymd . '_gobd-export_' . $self->{from} . '_' . $self->{to} .
        ".zip";

    
    {
        my $dir = pushd($self->{workdir});
        
        system('zip', '--quiet', '-r', $self->{archive_name}, '.');
    }
    
    $self->{zipfile_path} = File::Spec->catfile(
        $self->{workdir},
        $self->{archive_name}
    );
    
}



1;
