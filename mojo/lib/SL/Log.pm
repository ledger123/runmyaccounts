package SL::Log;
use List::Util qw(max);


my %level_map = (
    0 => "TRACE",
    1 => "DEBUG",
    2 => "INFO",
    3 => "WARN",
    4 => "ERROR",
);

my %color_map = (
    0 => '#ADD8E6',
    1 => '#ADD8E6',
    2 => '#90EE90',
    3 => '#FFFF00',
    4 => '#F0A0A0',
);


sub new {
    my $class = shift;


    my $self = {
        events      => [],
        _current_id => 0,
    };

    bless $self, $class;
    
}

sub events { @{ shift->{events} } }

sub maxlevel {
    my $self = shift;

    return max map { $_->{level} } $self->events;
}

    
sub trace { shift->_add_event(0, @_) }
sub debug { shift->_add_event(1, @_) }
sub info  { shift->_add_event(2, @_) }
sub warn  { shift->_add_event(3, @_) }
sub error { shift->_add_event(4, @_) }


sub _add_event {
    my $self = shift;
    my ($level, @lines) = @_;

    push @{$self->{events}}, SL::Log::Event->new(
        id    => ++$self->{_current_id},
        level => $level,
        lines => \@lines
    );
}


sub to_html {
    my $self = shift;
    my $minlevel_name = $_[0] // "trace";
    
    my %reverse_level_map = reverse %level_map;

    my $minlevel = $reverse_level_map{uc $minlevel_name};
    
    
    my $html = "<div id='log'>\n<table class='log'>\n";

    foreach my $event ($self->events) {
        next if $event->{level} < $minlevel;
        $html .= "<tr>\n";
        $html .= "<td class='log'>$event->{id}</td>\n";
        $html .= "<td class='log' style='background: $color_map{$event->{level}}'>$level_map{$event->{level}}</td>\n";
        $html .= "<td class='log'>" . shift(@{$event->{lines}}). "</td>\n";
        $html .= "</tr>\n";
        foreach (@{$event->{lines}}) {
             $html .= "<tr><td/><td/><td class='log'>$_</td></tr>\n";
        }
    }
    $html .= "\n</table>\n</div>";
    
    return $html;
}





package SL::Log::Event;



sub new {
    my $class = shift;
    my %args = @_;

    my $self = {
        %args
    };

    bless $self, $class;
    
}



1;
