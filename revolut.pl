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

$Data::Dumper::Indent = 1;

# TODO populate revolut_accounts table on setup/initialization only.

helper dbs => sub {
    my ( $c, $dbname ) = @_;
    state $dbs;
    if ($dbs) {
        return $dbs;
    }
    my $dbh = DBI->connect( "dbi:Pg:dbname=$dbname", 'sql-ledger', '' ) or die $DBI::errstr;
    $dbs = DBIx::Simple->connect($dbh);

    unless ( $dbs->query('SELECT 1 FROM revolut_accounts LIMIT 1')->list ) {
        $dbs->query(
            q{
              CREATE TABLE revolut_accounts (
                id text,
                curr character varying(3),
                name text,
                balance numeric(12,2)
              )
            }
        );
    }

    unless ( $dbs->query('SELECT transjson FROM gl LIMIT 1')->list ) {
        $dbs->query(q{ALTER TABLE gl ADD COLUMN transjson JSON});
    }

    unless ( $dbs->query('SELECT transjson FROM gl_log LIMIT 1')->list ) {
        $dbs->query(q{ALTER TABLE gl_log ADD COLUMN transjson JSON});
    }

    unless ( $dbs->query('SELECT transjson FROM gl_log_deleted LIMIT 1')->list ) {
        $dbs->query(q{ALTER TABLE gl_log_deleted ADD COLUMN transjson JSON});
    }
    return $dbs;
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
    my $table_data = HTML::Table->new( -head => [qw/transactions currency name balance state public/], );
    $table_data->setRowClass( 1, 'listheading' );
    # $dbs->query("DELETE FROM revolut_accounts");
    for my $item ( @{$hash} ) {
        if ( $item->{balance} ) {
            my $rownum = $table_data->addRow(
                "<a href=" . $c->url_for('/transactions')->query( account => $item->{id} ) . ">Transactions</a>",
                $item->{currency}, $item->{name}, $c->nf->format_price( $item->{balance}, 2 ),
                $item->{state}, $item->{public},
            );
            $table_data->setRowClass( $rownum, 'listrow0' );
            # $dbs->query( "INSERT INTO revolut_accounts (id, curr, name, balance) VALUES (?,?,?,?)", $item->{id}, $item->{currency}, $item->{name}, $item->{balance} );
            # $dbs->commit;
        }
    }
    my $tablehtml   = $table_data;
    my $hash_pretty = format_pretty( $hash, { linum => 1 } );
    $c->render( template => 'accounts', hash_pretty => '', tablehtml => $tablehtml, defaults => \%defaults );

};

any 'transactions' => sub ($c) {

    my $params = $c->req->params->to_hash;
    my $dbs    = $c->dbs( $c->session->{myconfig}->{dbname} );

    $params->{from_date} = $dbs->query("SELECT transdate FROM gl WHERE transjson IS NOT NULL")->list if !$params->{from_date};
    $params->{to_date}   = $dbs->query("SELECT '$params->{from_date}'::DATE + 1")->list              if !$params->{to_date};
    $params->{account}   = 'bbe762b6-e590-4880-bb30-f6940060cb57'                                    if !$params->{account};

    if ( !$c->session->{dbname} ) {
        $c->render( text => 'Session timed out' );
        return;
    }

    if ($params->{bank_account}){
        $dbs->query("UPDATE revolut_accounts SET chart_id = ? WHERE id = ?", $params->{bank_account}, $params->{account});
        $dbs->commit;
    } else {
        my $bank_account = $dbs->query("SELECT chart_id FROM revolut_accounts WHERE id = ?", $params->{account})->list;
        $c->param(bank_account => $bank_account);
    }

    my %defaults        = $dbs->query("SELECT fldname, fldvalue FROM defaults")->map;
    my $ua              = Mojo::UserAgent->new;
    my $access_token    = $c->session->{access_token};
    my $selectedaccount = $dbs->query("SELECT fldvalue FROM defaults WHERE fldname='selectedaccount'")->list;
    my @accounts        = $dbs->query("SELECT curr, id FROM revolut_accounts ORDER BY curr")->arrays;
    my @chart1          = $dbs->query("SELECT accno || '--' || description, id AS accno FROM chart WHERE link LIKE '%_paid%' ORDER BY 2")->arrays;
    my @chart2          = $dbs->query( "SELECT accno || '--' || description, id AS accno FROM chart WHERE accno LIKE ? ORDER BY 2", $selectedaccount )->arrays;
    my $from_date       = $params->{from_date};
    my $to_date         = $params->{to_date};
    my $apicall         = "$defaults{revolut_api_url}/transactions?";

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

    my $table_data = HTML::Table->new( -head => [qw/date type amount fee balance currency description state card_number merchant_name/], );
    $table_data->setRowClass( 1, 'listheading' );

    my $msg;
    for my $item ( @{$hash} ) {
        my $transdate = substr( $item->{created_at}, 0, 10 );
        my $rownum    = $table_data->addRow(
            $transdate, $item->{type},
            $c->nf->format_price( $item->{legs}->[0]->{amount},  2 ), $c->nf->format_price( $item->{legs}->[0]->{fee}, 2 ),
            $c->nf->format_price( $item->{legs}->[0]->{balance}, 2 ), $item->{legs}->[0]->{currency},
            $item->{legs}->[0]->{description}, $item->{state},
            $item->{card}->{card_number},      $item->{merchant}->{name},
        );
        $table_data->setRowClass( $rownum, 'listrow0' );

        if ( $params->{import} ) {
            my ( $exists, $reference ) = $dbs->query( "SELECT id, reference FROM gl WHERE reference = ?", $item->{id} )->list;
            if ($exists) {
                $dbs->query( "DELETE FROM acc_trans WHERE trans_id = ?", $exists );
                $dbs->query( "DELETE FROM gl WHERE id = ?",              $exists );
                $msg .= "Updating $reference ...<br/>";
            } else {
                $reference = $item->{id};
                $msg .= "Adding $reference ...<br/>";
            }
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
            my $other_account;
            my $tax_chart_id;

            if ( $item->{type} eq 'topup' ) {
                ( $other_account, $tax_chart_id ) = $dbs->query( "
                    SELECT chart_id, tax_chart_id
                    FROM revolut_rules
                    WHERE type = ?
                    LIMIT 1",
                    $item->{type},
                )->list;
            } else {
                ( $other_account, $tax_chart_id ) = $dbs->query( "
                    SELECT chart_id, tax_chart_id
                    FROM revolut_rules
                    WHERE merchant_name = ?
                    AND merchant_city = ?
                    AND merchant_country = ?
                    AND category_code = ?
                    LIMIT 1",
                    $item->{merchant}->{name},
                    $item->{merchant}->{city},
                    $item->{merchant}->{country},
                    $item->{merchant}->{category_code} )->list;
            }
            $other_account = $params->{clearing_account} if !$other_account;
            my $tax;
            if ($tax_chart_id) {
                $tax = $dbs->query( "SELECT accno || '--' || description FROM chart WHERE id = ?", $tax_chart_id )->list;
            }
            $dbs->query( "
                    INSERT INTO gl(reference, description, notes, transdate, department_id, curr, exchangerate, transjson)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                $item->{id}, $item->{legs}->[0]->{description}, "$item->{type} -- $item->{merchant}->{category_code}", $transdate, $department_id, $curr, $exchangerate, $transjson )
              or die $dbs->error;
            my $id = $dbs->query( "SELECT id FROM gl WHERE reference = ?", $item->{id} )->list;
            if ($id) {
                $item->{legs}->[0]->{fee} *= 1;
                $dbs->query( "
                    INSERT INTO acc_trans(trans_id, transdate, chart_id, amount) VALUES (?, ?, ?, ?)",
                    $id, $transdate, $params->{bank_account}, ( $item->{legs}->[0]->{amount} + $item->{legs}->[0]->{fee} ) * -1 )
                  or die $dbs->error;
                $dbs->query( "
                    INSERT INTO acc_trans(trans_id, transdate, chart_id, amount, tax_chart_id, tax) VALUES (?, ?, ?, ?, ?, ?)",
                    $id, $transdate, $other_account, $item->{legs}->[0]->{amount} + $item->{legs}->[0]->{fee}, $tax_chart_id, $tax )
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

    my $dbs          = $c->dbs( $c->session->{myconfig}->{dbname} );
    my %defaults     = $dbs->query("SELECT fldname, fldvalue FROM defaults")->map;
    my $ua           = Mojo::UserAgent->new;
    my $access_token = $c->session->{access_token};
    my $params       = $c->req->params->to_hash;
    my $apicall      = "$defaults{revolut_api_url}/counterparties";
    my $res          = $ua->get( $apicall => { "Authorization" => "Bearer $access_token" } )->result;
    my $code         = $res->code;

    if ( $code eq '500' ) {
        $c->render( text => "<pre>API call: $apicall\n\n" . $c->dumper($res) );
        return;
    }

    my $body        = $res->{content}->{asset}->{content};
    my $hash        = decode_json($body);
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
    <div class="listtop">Accounts List</div>
</div>
<%== $tablehtml %>
<pre>
<%== $hash_pretty %>
</pre>




 
@@ transactions.html.ep
% layout 'default';
% title 'Transactions List';
<div class="listtop">Transactions List</div>
<div><%== $msg %></div>
<br/>
    <%= form_for 'transactions' => method => 'POST' => begin %>
        <table width="100%">
            <tr>
                <th align="right">Period</th>
                <td>
                    <%= select_field 'month', ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'], class => "form-select" %>
                    <%= select_field 'year', [ 2007 .. 2023 ], class => "form-select" %>
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
                <%= select_field 'account', $accounts, class=>"form-select" %>
                </td>
            </tr>
            <tr>
                <th align="right">From Date</th>
                <td>
                   %= date_field 'from_date', class => 'datepicker', value => $params->{from_date}, class=>"form-control"
                </td>
            </tr>
            <tr>
                <th align="right">To Date</th>
                <td>
                    %= date_field 'to_date', class => 'datepicker', value => $params->{to_date}, class=>"form-control"
                </td>
            </tr>
            <tr>
                <th align="right">Bank Account</th>
                <td><%= select_field 'bank_account', $chart1, class=>"form-select" %></td>
            </tr>
            <tr>
                <th align="right">Clearing Account</th>
                <td><%= select_field 'clearing_account', $chart2, class=>"form-select" %></td>
            </tr>
            <tr>
                <th align="right">Import?</th>
                <td>
                    <%= check_box 'import' => 1, class=>"form-check" %>
                </td>
            </tr>
            <tr>
                <td colspan="2">
                    <hr/>
                    <%= submit_button 'Submit', class=>"submit" %>
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
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title><%= title %></title>

  <link rel="stylesheet" href="//code.jquery.com/ui/1.13.0/themes/base/jquery-ui.css">
  <!-- <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.0.2/dist/css/bootstrap.min.css" rel="stylesheet"> -->

  % my $css_path = $c->url_for('css/sql-ledger.css')->to_abs; 
  % $css_path =~ s/\/revolut\.pl\//\//;
  <link rel="stylesheet" type="text/css" href="<%= $css_path %>">
 
  <script src="//code.jquery.com/jquery-3.6.0.min.js"></script>
  <script src="//code.jquery.com/ui/1.13.0/jquery-ui.min.js"></script>
  <script>
    $(document).ready(function() {
      $('.datepicker').datepicker({
        dateFormat: 'dd/mm/yy'
      });
    });
  </script>
</head>
<body>

<main class="container-fluid">
  <%= content %>
</main>

<footer class="mt-4 py-3 bg-light">
  <div class="container text-center">
    <hr>
    <p>To manage your Revolut connection, visit: <a href="https://business.revolut.com/settings/api">https://business.revolut.com/settings/api</a></p>
    % my $debug = 0;
    <% if ($debug) { %>
      <h2 class="listheading">Session:</h2>
      <pre><%= dumper($self->session) %></pre>
      
      <h2 class="listheading">Request Parameters</h2>
      <pre><%= dumper($self->req->params->to_hash) %></pre>
      
      <h2 class="listheading">Controller</h2>
      <pre><%= dumper($self->stash) %></pre>
    <% } %>
  </div>
</footer>
<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.0.2/dist/js/bootstrap.bundle.min.js"></script>
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

