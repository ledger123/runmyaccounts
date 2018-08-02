package SL::Controller::Testing;
use Mojo::Base 'Mojolicious::Controller';

sub index {
    my $self = shift;

    my $cookies = $self->req->cookies;

    my $username = $self->session('login_name');
    my $cookievalue;

    foreach (@$cookies) {
        if ($_->name eq "SL-$username") {
            $cookievalue = $_->value;
            last;
        }
    }

    my $sessionkey = $self->userconfig->val("sessionkey");

	my $s = "";
	my %ndx = ();
	my $l = length $cookievalue;
    my $j;

    for my $i (0 .. $l - 1) {
        $j = substr($sessionkey, $i * 2, 2);
	    $ndx{$j} = substr($cookievalue, $i, 1);
    }

    for (sort keys %ndx) {
	    $s .= $ndx{$_};
    }

    $l = length $username;
    my $login = substr($s, 0, $l);
    my $password = substr($s, $l, (length $s) - ($l + 10));

    # validate cookie
    my $ok = 'Session is ok.';
    if (($login ne $username) || ($self->userconfig->val("password") ne crypt $password, substr($username, 0, 2))) {
        $ok = 'Session is not ok';
    }

    $self->render(msg => "Hi $ok");
}

1;
