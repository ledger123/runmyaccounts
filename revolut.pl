#!/usr/bin/env perl

use Mojolicious::Lite -signatures;
use Mojo::UserAgent;
use Crypt::X509;
use Crypt::JWT ':all';
use Crypt::PK::RSA;
use JSON::XS;
use HTML::Table;
use Data::Format::Pretty::JSON qw(format_pretty);
use CGI::FormBuilder;
use DBI;
use DBD::Pg;
use DBIx::Simple;
use Number::Format;
use Time::Piece;

$Data::Dumper::Indent = 1;

my $dbs = "";
helper dbs => sub {
    my ( $c, $dbname ) = @_;
    if ($dbname) {
        my $dbh = DBI->connect( "dbi:Pg:dbname=$dbname", 'sql-ledger', '' ) or die $DBI::errstr;
        $dbs = DBIx::Simple->connect($dbh);
        return $dbs;
    } else {
        return $dbs;
    }
};

helper nf => sub {
    return my $nf = new Number::Format( -int_curr_symbol => '' );
};

sub _refresh_session {

    my ( $c, $dbname, $defaults ) = @_;

    my $dbs      = $c->dbs( $c->session->{myconfig}->{dbname} );
    my %defaults = $dbs->query("SELECT fldname, fldvalue FROM defaults")->map;
    my $ua       = Mojo::UserAgent->new;
    my $apicall  = "$defaults{revolut_api_url}/auth/token";
    my $res;
    $res = $ua->post(
        $apicall => form => {
            grant_type            => 'refresh_token',
            client_id             => $defaults->{revolut_client_id},
            refresh_token         => $defaults->{revolut_refresh_token},
            client_assertion_type => 'urn:ietf:params:oauth:client-assertion-type:jwt-bearer',
            client_assertion      => $defaults->{revolut_jwt_token},
        }
    )->result;

    my $code = $res->code;
    my $body = $res->body;
    my $hash = decode_json($body);
    $c->session->{access_token} = $hash->{access_token};
    $c->session->{dbname}       = $dbname;
}

get '/access/:dbname' => sub ($c) {

    my $params     = $c->req->params->to_hash;
    my $dbname     = $c->param('dbname');
    my $dbs        = $c->dbs($dbname);
    my %defaults   = $dbs->query("SELECT fldname, fldvalue FROM defaults")->map;
    my $jwt_header = q|{"alg": "RS256", "typ": "JWT"}|;
    my $payload    = {
        iss => $defaults{revolut_jwt_domain},
        sub => $defaults{revolut_client_id},
        aud => "https://revolut.com",
        exp => time + ( 90 * 24 * 60 * 60 ),
    };
    my $jwt_token = encode_jwt( payload => $payload, alg => 'RS256', key => \$defaults{revolut_private_key} );
    my $ua        = Mojo::UserAgent->new;
    my $apicall   = "$defaults{revolut_api_url}/auth/token";
    my $msg;
    my $res;

    if ( $params->{code} ) {
        $res = $ua->post(
            $apicall => form => {
                grant_type            => 'authorization_code',
                code                  => $params->{code},
                client_id             => $defaults{revolut_client_id},
                client_assertion_type => 'urn:ietf:params:oauth:client-assertion-type:jwt-bearer',
                client_assertion      => $jwt_token
            }
        )->result;
    }
    my $code = $res->code;
    my $body = $res->body;
    my $hash = decode_json($body);
    if ( $code eq '200' ) {
        $c->session( expiration => 86400 );
        $c->session->{jwt_token}     = $jwt_token;
        $c->session->{access_token}  = $hash->{access_token};
        $c->session->{refresh_token} = $hash->{refresh_token};
        $c->session->{dbname}        = $dbname;
        $dbs->query("DELETE FROM defaults WHERE fldname IN ('revolut_access_token', 'revolut_refresh_token', 'revolut_jwt_token')");
        $dbs->query( "INSERT INTO defaults (fldname, fldvalue) VALUES (?, ?)", 'revolut_jwt_token',     $jwt_token );
        $dbs->query( "INSERT INTO defaults (fldname, fldvalue) VALUES (?, ?)", 'revolut_access_token',  $hash->{access_token} );
        $dbs->query( "INSERT INTO defaults (fldname, fldvalue) VALUES (?, ?)", 'revolut_refresh_token', $hash->{refresh_token} );
        $msg = "$code: Access granted.";
    } else {
        $msg = "$code: $hash->{error_description}.";
    }
    $c->render( template => 'index', msg => $msg, dbname => $dbname, defaults => \%defaults );
};

get 'accounts' => sub ($c) {

    our %myconfig;
    my $params = $c->req->params->to_hash;
    my $login  = $params->{login};

    eval { require "./users/$login.conf" };
    if ($@) { die "cannot load user config for $login: $@" }
    $c->session->{myconfig} = \%myconfig;
    $c->session->{myconfig}->{login} = $login;

    my $dbs          = $c->dbs( $c->session->{myconfig}->{dbname} );
    my %defaults     = $dbs->query("SELECT fldname, fldvalue FROM defaults")->map;
    my $ua           = Mojo::UserAgent->new;
    my $access_token = $c->session->{access_token};
    my $apicall      = "$defaults{revolut_api_url}/accounts";
    my $res          = $ua->get( $apicall => { "Authorization" => "Bearer $access_token" } )->result;

    if ( $res->is_error ) {
        &_refresh_session( $c, $c->session->{myconfig}->{dbname}, \%defaults );
        $access_token = $c->session->{access_token};
        $res          = $ua->get( $apicall => { "Authorization" => "Bearer $access_token" } )->result;
    }
    my $hash       = $res->json;
    my $table_data = HTML::Table->new(
        -class => 'table table-border',
        -head  => [qw/transactions currency name balance state public/],
    );
    $dbs->query("DELETE FROM revolut_accounts");
    for my $item ( @{$hash} ) {
        if ( $item->{balance} ) {
            $table_data->addRow(
                "<a href=" . $c->url_for('/transactions')->query( account => $item->{id} ) . ">Transactions</a>",
                $item->{currency}, $item->{name}, $c->nf->format_price( $item->{balance}, 2 ),
                $item->{state},    $item->{public},
            );
            $dbs->query( "
                INSERT INTO revolut_accounts (id, curr, name, balance) VALUES (?,?,?,?)",
                $item->{id}, $item->{currency}, $item->{name}, $item->{balance} );
            $dbs->commit;
        }
    }
    my $tablehtml   = $table_data;
    my $hash_pretty = format_pretty( $hash, { linum => 1 } );
    $c->render( template => 'accounts', hash_pretty => '', tablehtml => $tablehtml, defaults => \%defaults );

};

any 'transactions' => sub ($c) {

    my $params = $c->req->params->to_hash;

    $params->{from_date} = '01/08/2022'                           if !$params->{from_date};
    $params->{to_date}   = '30/08/2022'                           if !$params->{to_date};
    $params->{account}   = 'bbe762b6-e590-4880-bb30-f6940060cb57' if !$params->{account};

    if ( !$c->session->{dbname} ) {
        $c->render( text => 'Session timed out' );
        return;
    }

    my $dbs             = $c->dbs( $c->session->{myconfig}->{dbname} );
    my %defaults        = $dbs->query("SELECT fldname, fldvalue FROM defaults")->map;
    my $ua              = Mojo::UserAgent->new;
    my $access_token    = $c->session->{access_token};
    my $selectedaccount = $dbs->query("SELECT fldvalue FROM defaults WHERE fldname='selectedaccount'")->list;
    my @accounts        = $dbs->query("SELECT curr, id FROM revolut_accounts ORDER BY curr")->arrays;
    my @chart1          = $dbs->query("SELECT accno || '--' || description, id AS accno FROM chart WHERE link LIKE '%_paid%' ORDER BY 2")->arrays;
    my @chart2          = $dbs->query( "SELECT accno || '--' || description, id AS accno FROM chart WHERE accno LIKE ? ORDER BY 2", $selectedaccount )->arrays;

    my $date1     = Time::Piece->strptime( $params->{from_date}, '%d/%m/%Y' );
    my $date2     = Time::Piece->strptime( $params->{to_date},   '%d/%m/%Y' );
    my $from_date = $date1->strftime('%Y-%m-%d');
    my $to_date   = $date2->strftime('%Y-%m-%d');

    my $apicall = "$defaults{revolut_api_url}/transactions?";
    $apicall .= "account=$params->{account}&from=$from_date&to=$to_date";
    my $res  = $ua->get( $apicall => { "Authorization" => "Bearer $access_token" } )->result;
    my $code = $res->code;

    if ( $code eq '500' ) {
        $c->render( text => "<pre>API call: $apicall\n\n" . $c->dumper($res) );
        return;
    }

    my $body = $res->{content}->{asset}->{content};
    my $hash = decode_json($body);

    if ( !ref($hash) ) {
        $c->render("Unknow error");
        return;
    }

    my $table_data = HTML::Table->new(
        -class => 'table table-border',
        -head  => [qw/date type amount balance currency description state card_number merchant_name/],
    );

    my $msg;
    for my $item ( @{$hash} ) {
        my $transdate = substr( $item->{created_at}, 0, 10 );
        $table_data->addRow(
            $transdate, $item->{type},
            $c->nf->format_price( $item->{legs}->[0]->{amount},  2 ),
            $c->nf->format_price( $item->{legs}->[0]->{balance}, 2 ),
            $item->{legs}->[0]->{currency},
            $item->{legs}->[0]->{description},
            $item->{state},
            $item->{card}->{card_number},
            $item->{merchant}->{name},
        );

        if ( $params->{import} ) {
            my ( $exists, $reference ) = $dbs->query( "SELECT id, reference FROM gl WHERE reference = ?", $item->{id} )->list;
            if ($exists) {
                $dbs->query( "DELETE FROM acc_trans WHERE trans_id = ?", $exists );
                $dbs->query( "DELETE FROM gl WHERE id = ?",              $exists );
            }
            $msg .= "Adding $reference ...<br/>";
            my $department_id = $dbs->query("SELECT id FROM department LIMIT 1")->list;
            $department_id *= 1;
            my $curr         = $item->{legs}->[0]->{currency};
            my $exchangerate = $dbs->query( "
                    SELECT buy
                    FROM exchangerate
                    WHERE curr = ?
                    AND transdate = ?", $curr, $transdate )->list;
            $exchangerate *= 1;
            $exchangerate = 1 if !$exchangerate;
            my $transjson = encode_json($item);
            $dbs->query( "
                    INSERT INTO gl(reference, description, notes, transdate, department_id, curr, exchangerate, transjson)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                $item->{id}, $item->{legs}->[0]->{description}, "$item->{type} -- $item->{merchant}->{category_code}", $transdate, $department_id, $curr, $exchangerate, $transjson )
              or die $dbs->error;
            my $id = $dbs->query( "SELECT id FROM gl WHERE reference = ?", $item->{id} )->list;
            if ($id) {
                $dbs->query( "
                    INSERT INTO acc_trans(trans_id, transdate, chart_id, amount) VALUES (?, ?, ?, ?)",
                    $id, $transdate, $params->{bank_account}, $item->{legs}->[0]->{amount} * -1 )
                  or die $dbs->error;
                $dbs->query( "
                    INSERT INTO acc_trans(trans_id, transdate, chart_id, amount) VALUES (?, ?, ?, ?)",
                    $id, $transdate, $params->{clearing_account}, $item->{legs}->[0]->{amount} )
                  or die $dbs->error;
                $dbs->commit;
            }
        }
    }
    my $tablehtml   = $table_data;
    my $hash_pretty = format_pretty( $hash, { linum => 1 } );

    $c->render(
        template    => 'transactions',
        msg         => $msg,
        defaults    => \%defaults,
        account     => $params->{account},
        params      => $params,
        accounts    => \@accounts,
        chart1      => \@chart1,
        chart2      => \@chart2,
        tablehtml   => $tablehtml,
        hash_pretty => $hash_pretty,
    );
};

any 'counterparties' => sub ($c) {

    if ( !$c->session->{dbname} ) {
        $c->render( text => 'Session timed out' );
        return;
    }

    my $dbs      = $c->dbs( $c->session->{myconfig}->{dbname} );
    my %defaults = $dbs->query("SELECT fldname, fldvalue FROM defaults")->map;

    my $ua           = Mojo::UserAgent->new;
    my $access_token = $c->session->{access_token};
    my $params       = $c->req->params->to_hash;

    my $apicall = "$defaults{revolut_api_url}/counterparties";

    my $res = $ua->get( $apicall => { "Authorization" => "Bearer $access_token" } )->result;

    my $code = $res->code;

    if ( $code eq '500' ) {
        $c->render( text => "<pre>API call: $apicall\n\n" . $c->dumper($res) );
        return;
    }

    my $body = $res->{content}->{asset}->{content};
    my $hash = decode_json($body);

    my $hash_pretty = format_pretty( $hash, { linum => 1 } );

    $c->render(
        template    => 'counterparties',
        defaults    => \%defaults,
        hash_pretty => $hash_pretty
    );
};

app->start;
__DATA__

@@ index.html.ep
% layout 'activate';
% title 'Home';
<h1>Revolut - SQL-Ledger Integration!</h1>
<h2>Database: <%= $dbname %></h2>
<br/>
<h3><%= $msg %></h3>
<br/>
To manage your revolut connection visit: <a href="https://business.revolut.com/settings/api">https://business.revolut.com/settings/api</a>

@@ accounts.html.ep
% layout 'default';
% title 'Accounts List';
<div class="pricing-header p-3 pb-md-4 mx-auto text-center">
    <h1 class="display-4 fw-normal">Accounts List</h1>
    <p class="fs-5 text-muted">Accounts List</p>
</div>
<%== $tablehtml %>
<pre>
<%== $hash_pretty %>
</pre>




 
@@ transactions.html.ep
% layout 'default';
% title 'Transactions List';
<div class="pricing-header p-3 pb-md-4 mx-auto text-center">
    <h1 class="display-4 fw-normal">Transactions List</h1>
    <p class="fs-5 text-muted">Transactions List</p>
</div>
<div><%== $msg %></div>
<br/>
    <%= form_for 'transactions' => method => 'POST' => begin %>
        <table>
            <tr>
                <th align="right">Period</th>
                <td>
                    <%= select_field 'month', ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'], {} %>
                    <%= select_field 'year', [ 2007 .. 2023 ], {} %>
                    <br>
                    <%= radio_button 'interval', 0, checked => 'checked' %> <%= label_for 'interval', 'Current' %>
                    <%= radio_button 'interval', 1 %> <%= label_for 'interval', 'Month' %>
                    <%= radio_button 'interval', 3 %> <%= label_for 'interval', 'Quarter' %>
                    <%= radio_button 'interval', 12 %> <%= label_for 'interval', 'Year' %>
                </td>
            </tr>
            <tr>
                <td colspan="2">&nbsp;</td>
            </tr>
            <tr>
                <th align="right">Account</th>
                <td>
                <%= select_field 'account', $accounts %>
                </td>
            </tr>
            <tr>
                <th align="right">From Date</th>
                <td>
                   %= text_field 'from_date', class => 'datepicker', value => $params->{from_date}
                </td>
            </tr>
            <tr>
                <th align="right">To Date</th>
                <td>
                    %= text_field 'to_date', class => 'datepicker', value => $params->{to_date}
                </td>
            </tr>
            <tr>
                <th align="right">Bank Account</th>
                <td><%= select_field 'bank_account', $chart1 %></td>
            </tr>
            <tr>
                <th align="right">Clearing Account</th>
                <td><%= select_field 'clearing_account', $chart2 %></td>
            </tr>
            <tr>
                <th align="right">Import?</th>
                <td>
                    <%= check_box 'import' => 1 %>
                </td>
            </tr>
            <tr>
                <td colspan="2">
                    <hr/>
                    <%= submit_button 'Submit' %>
                </td>
            </tr>
        </table>
    <% end %>

<br/>
<%== $tablehtml %>
<pre>
<%== $hash_pretty %>
</pre>




@@ counterparties.html.ep
% layout 'default';
% title 'Counter Parties';
<div class="pricing-header p-3 pb-md-4 mx-auto text-center">
    <h1 class="display-4 fw-normal">Counter Parties</h1>
    <p class="fs-5 text-muted">Counter Parties</p>
</div>
<pre>
<%== $hash_pretty %>
</pre>




@@ layouts/default.html.ep
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">

    <link rel="stylesheet" href="//code.jquery.com/ui/1.13.0/themes/base/jquery-ui.css">
    <script src="//code.jquery.com/jquery-3.6.0.min.js"></script>
    <script src="//code.jquery.com/ui/1.13.0/jquery-ui.min.js"></script>

    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.0.2/dist/css/bootstrap.min.css" rel="stylesheet" integrity="sha384-EVSTQN3/azprG1Anm3QDgpJLIm9Nao0Yz1ztcQTwFspd3yD65VohhpuuCOmLASjC" crossorigin="anonymous">

%= javascript begin
  $(document).ready(function() {
    $('.datepicker').datepicker({
      dateFormat: 'dd/mm/yy'
    });
  });
% end

     <title><%= title %></title>
  </head>
  <body>
  
  <div class="container-fluid">
  <header>
    <div class="d-flex flex-column flex-md-row align-items-center pb-3 mb-4 border-bottom">
      <a href="/" class="d-flex align-items-center text-dark text-decoration-none">
        <span class="fs-4">Revolut</span>
      </a>
      <nav class="d-inline-flex mt-2 mt-md-0 ms-md-auto">
        <a class="me-3 py-2 text-dark text-decoration-none" href="<%= url_for('/accounts')->query(login => $c->session->{myconfig}->{login}) %>">Accounts</a>
        <a class="me-3 py-2 text-dark text-decoration-none" href="<%= url_for('/transactions')->query(login => $c->session->{myconfig}->{login}) %>">Transactions</a>
      </nav>
    </div>
  </header>

    <%= content %>

To manage your revolut connection visit:
<a href="https://business.revolut.com/settings/api">https://business.revolut.com/settings/api</a>
<br/><br/>

  </div>

  <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.0.2/dist/js/bootstrap.bundle.min.js" integrity="sha384-MrcW6ZMFYlzcLA8Nl+NtUVF0sA7MsXsP1UyJoMp4YLEuNSfAP+JcXn/tWtIaxVXM" crossorigin="anonymous"></script>

% my $debug = 0;
% if ($debug){
<h2 class='listheading'>Session:</h2>
<pre>
    <%= dumper($self->session) %>
</pre>
        
<h2 class='listheading'>Request Parameters</h2>
<pre>
   <%= dumper($self->req->params->to_hash) %>
</pre>

<h2 class='listheading'>Controller</h2>
<pre>
   <%= dumper($self->stash) %>
</pre>
% }


  </body>
</html>


@@ layouts/activate.html.ep
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.0.2/dist/css/bootstrap.min.css" rel="stylesheet" integrity="sha384-EVSTQN3/azprG1Anm3QDgpJLIm9Nao0Yz1ztcQTwFspd3yD65VohhpuuCOmLASjC" crossorigin="anonymous">

     <title><%= title %></title>
  </head>
  <body>
  
  <div class="container-fluid">
  <header>
    <div class="d-flex flex-column flex-md-row align-items-center pb-3 mb-4 border-bottom">
      <a href="/" class="d-flex align-items-center text-dark text-decoration-none">
        <span class="fs-4">Revolut - SQL-Ledger Integration</span>
      </a>
    </div>

  </header>

    <%= content %>

  </div>

% my $debug = 0;
% if ($debug){
<h2 class='listheading'>Session:</h2>
<pre>
    <%= dumper($self->session) %>
</pre>
        
<h2 class='listheading'>Request Parameters</h2>
<pre>
   <%= dumper($self->req->params->to_hash) %>
</pre>

<h2 class='listheading'>Controller</h2>
<pre>
   <%= dumper($self->stash) %>
</pre>
% }


  </body>
</html>
