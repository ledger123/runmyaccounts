package SL::Controller::Testing;
use Mojo::Base 'Mojolicious::Controller';

sub index {
    my $self = shift;

    $self->render(msg => "Hi");
}

1;
