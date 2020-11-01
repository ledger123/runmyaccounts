package SL;
use Mojo::Base 'Mojolicious';
use Data::Dumper;


sub startup {
    my $self = shift;

    # "development" or "production":
    $self->mode('production') unless exists $ENV{MOJO_MODE};

    $self->plugin('SL::Helper::Basic');
    $self->plugin('I18N', no_header_detect => 1);
    
    $self->secrets(['ok3YeeSeGh5sighe']);

    # $self->hook(
    #     before_dispatch => sub {
    #         my $c = shift;
    #         if (my $prefix = $c->req->headers->header('X-Forwarded-Prefix')) {
    #             $c->req->url->base->path("$prefix/mojo.pl")
    #         }
               
    #     });
    
    my $r = $self->routes;

    my $auth = $r->under(
        '/' => sub {
            my $c = shift;

            # Get login name:
            my $url_login_name     = $c->param('login');
            my $session_login_name = $c->session('login_name');

            # Both undefined? There's nothing we can do here. 
            if (!defined $url_login_name && !defined $session_login_name) {
                $c->render(text => "No login name", status => 403);
                return undef;
            }

            # Otherwise: URL param is always stronger.
            if (defined $url_login_name) {
                $c->session('login_name' => $url_login_name);
            }
            
            my $login_name = $c->session('login_name');
            
            unless ( $self->logged_in($c, $login_name) ) {
                $c->render(text => "Not logged in", status => 403);
                return undef;
            }

            return 1;
        }
    );


    
    $auth->any('/hello')      ->to('Mojolicious#hello');
    $auth->any('/sysinfo')    ->to('Mojolicious#sysinfo');
    $auth->any('/expire')     ->to('Mojolicious#expire');
    $auth->any('/clear_spool')->to('Mojolicious#clear_spool');

    $auth->any('/gobd/start')          ->to('GoBD#start');
    $auth->any('/gobd/generate')       ->to('GoBD#generate');
    $auth->get('/gobd/show/#filename') ->to('GoBD#show');
    $auth->get('/gobd/download')       ->to('GoBD#download');

    $auth->any('/pvr/start')    ->to('PVR#start');
    $auth->any('/pvr/generate') ->to('PVR#generate');

    
    $auth->any('/admin/backup_restore/start')
        ->to('Admin::BackupRestore#start')->name('admin_br_start');
    $auth->any('/admin/backup_restore/backup/:dbname')
        ->to('Admin::BackupRestore#backup')->name('admin_br_backup');
    $auth->any('/admin/backup_restore/restore')
        ->to('Admin::BackupRestore#restore')->name('admin_br_restore');
}



sub logged_in {
    my $self = shift;
    
    my ($controller, $username) = @_;
    
    my $cookievalue = $controller->cookies->{"SL-$username"};
    
    my $sessionkey = $controller->userconfig->val("sessionkey");

    # say STDERR "*** cookievalue: $cookievalue";
    # say STDERR "*** sesssionkey: $sessionkey";
    # say STDERR "*** password:    ", $controller->userconfig->val("password");
    
    my $s = "";
    my %ndx = ();
    my $l = length($cookievalue) || return 0;
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
    my $ok = 1;
    if (($login ne $username) ||
            ($controller->userconfig->val("password")
             ne
             crypt $password, substr($username, 0, 2))) {
        $ok = 0;
    }

    return $ok;
}

1;
