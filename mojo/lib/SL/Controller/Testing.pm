package SL::Controller::Testing;
use Mojo::Base 'Mojolicious::Controller';

sub index {
    my $self = shift;

    $self->render( type => $self->param('type') );
}

1;
