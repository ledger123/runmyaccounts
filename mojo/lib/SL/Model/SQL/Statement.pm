##################################
package SL::Model::SQL::Statement;
##################################
use strict;
use warnings;
use feature ':5.10';
use utf8;

use Cwd qw(abs_path cwd);
use File::Spec;
use File::Basename;
use File::Copy;
use YAML::Tiny;
use Mojo::Pg;
use Data::Dumper;


sub new {
    my $class = shift;
    my %args = @_;

    my $self = {
        config      => $args{config},
        query       => $args{query},
    };

    
    my $queries_path = abs_path(File::Spec->catfile(
        dirname(__FILE__),
        'resources',
    ));
    $self->{queries_path} = $queries_path;
    
    my ($filename, $key) = split(m|/|, $args{query});
        
    my $yml_file = File::Spec->catfile(
        $self->{queries_path},
        "$filename.yml"
    );

    my $yaml = YAML::Tiny->read($yml_file);
    $self->{_sql} = $yaml->[0]{$key};

    defined $self->{_sql} || die "No such key: $key";

    
    bless $self, $class;

    return $self;
}        



sub execute {
    my $self = shift;
    my @bind_values = @_;
    
    my $pg = Mojo::Pg->new($self->{config}->pg_connstr);
        
    my $results = $pg->db->query($self->{_sql}, @bind_values);

    if ($results->rows >= 0) {
        $self->{_result} = $results->arrays->to_array;
    }
    
    return $self;
}



sub fetch {
    my $self = shift;

    return $self->{_result};
}


1;
