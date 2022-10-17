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

$Data::Dumper::Indent = 1;

my $dbs = "";
helper dbs => sub {
    my ( $c, $dbname ) = @_;
    if ($dbname) {
        my $dbh = DBI->connect( "dbi:Pg:dbname=$dbname;host=gh.mnapk.com", 'postgres', '' ) or die $DBI::errstr;
        $dbs = DBIx::Simple->connect($dbh);
        return $dbs;
    } else {
        return $dbs;
    }
};


get '/access/:dbname' => sub ($c) {

    my $params = $c->req->params->to_hash;
    my $dbname = $c->param('dbname');

    my $dbs = $c->dbs($dbname);

    my $jwt_header = q|
{
  "alg": "RS256",
  "typ": "JWT"
}
|;

    my $client_id = $dbs->query("SELECT fldvalue FROM defaults WHERE fldname='revolut_client_id'")->list;
    my $private_key = $dbs->query("SELECT fldvalue FROM defaults WHERE fldname='revolut_private_key'")->list;

    my $payload = {
        iss => "ledger123.net",
        sub => $client_id,
        aud => "https://revolut.com",
        exp => time + 86400
    };

    my $jws_token = encode_jwt( payload => $payload, alg => 'RS256', key => \$private_key );

    my $ua      = Mojo::UserAgent->new;
    my $apicall = "https://sandbox-b2b.revolut.com/api/1.0/auth/token";
    my $res     = $ua->post(
        $apicall => form => {
            grant_type            => 'authorization_code',
            code                  => $params->{code},
            client_id             => $client_id,
            client_assertion_type => 'urn:ietf:params:oauth:client-assertion-type:jwt-bearer',
            client_assertion      => $jws_token
        }
    )->result;

    my $code = $res->code;
    my $body = $res->body;
    my $hash = decode_json($body);
    if ( $params->{code} ) {
        $c->session(expiration => 86400);
        $c->session->{access_token} = $hash->{access_token};
    }
    $c->render( template => 'index', hash => $hash, dbname => $dbname );
};


get 'accounts' => sub ($c) {

    my $ua           = Mojo::UserAgent->new;
    my $access_token = $c->session->{access_token};
    my $apicall      = "https://sandbox-b2b.revolut.com/api/1.0/accounts";
    my $res          = $ua->get( $apicall => { "Authorization" => "Bearer $access_token" } )->result;

    my $code = $res->code;
    my $body = $res->body;
    my $hash = decode_json($body);

    my $table_data = HTML::Table->new(
        -class => 'table table-border',
        -head  => [qw/currency name balance state id public updated_at created_at/],
    );
    for my $item ( @{$hash} ) {
        $table_data->addRow( $item->{currency}, $item->{name}, $item->{balance}, $item->{state}, 
        "<a href=/rel3/revolut/index.pl/transactions?account=$item->{id}>$item->{id}</a>", $item->{public}, $item->{updated_at}, $item->{created_at}, );
    }
    my $tablehtml = $table_data;

    my $hash_pretty = format_pretty( $hash, { linum => 1 } );

    $c->render( template => 'accounts', hash_pretty => $hash_pretty, tablehtml => $tablehtml );

};

any 'transactions' => sub ($c) {

    my $ua           = Mojo::UserAgent->new;
    my $access_token = $c->session->{access_token};
    my $params = $c->req->params->to_hash;
    $params->{account} = 'bbe762b6-e590-4880-bb30-f6940060cb57' if !$params->{account};
    $params->{from} = '2022-08-01' if !$params->{from};
    $params->{to} = '2022-12-03' if !$params->{to};
    $params->{import} = 'NO' if !$params->{import};

    my $dbs = $c->dbs('munshi10');
    my @chart1 = $dbs->query("SELECT id, accno || '--' || description FROM chart WHERE link LIKE '%_paid%' ORDER BY 1")->arrays;
    my @chart2 = $dbs->query("SELECT id, accno || '--' || description FROM chart WHERE link LIKE '%_paid%' ORDER BY 1")->arrays;

    my $form1 = CGI::FormBuilder->new(
        method   => 'post',
        action   => '/rel3/revolut/index.pl/transactions',
        method   => 'post',
        table    => 1,
        selectnum => 1,
        fields   => [qw(account from to bank_account clearing_account import)],
        required => [qw()],
        options => { import => [qw(NO YES)] , bank_account => \@chart1, clearing_account => \@chart2},
        messages => { form_required_text => '', },
        values   => $params,
        submit   => [qw(Continue)],
    );
    $form1->field(name=>"account", size=>"50");

    my $form1html;
    my $msg;
    if ($params->{import} eq 'YES'){
        $msg = "Transactions imported into SQL-Ledger.";
    }

    $form1html = $form1->render;
    if ( $params->{"_submitted"} ) {
    }

    my $apicall      = "https://sandbox-b2b.revolut.com/api/1.0/transactions?";
    $apicall .= "account=$params->{account}&from=$params->{from}&to=$params->{to}";

    my $res = $ua->get( $apicall => { "Authorization" => "Bearer $access_token" } )->result;

    my $code = $res->code;
    my $body = $res->body;
    my $hash = decode_json($body);

    if (!ref($hash)){
        $c->render("Unknow error");
        return;
    }

    if ($hash->{message}){
        $c->render(text => $hash->{message});
        return;
    }

    my $table_data = HTML::Table->new(
        -class => 'table table-border',
        -head  => [qw/date type legs_amount legs_balance legs_currency legs_description state card_number merchant_name id/],
    );

    for my $item ( @{$hash} ) {
        my $transdate = substr($item->{created_at}, 0, 10);
        $table_data->addRow( 
            $transdate,
            $item->{type},
            $item->{legs}->[0]->{amount},
            $item->{legs}->[0]->{balance},
            $item->{legs}->[0]->{currency},
            $item->{legs}->[0]->{description},
            $item->{state},
            $item->{card}->{card_number},
            $item->{merchant}->{name},
            $item->{id},
        );
  
        if ($params->{import} eq 'YES'){
            my $department_id = $dbs->query("SELECT id FROM department LIMIT 1")->list;
            $dbs->query("
                INSERT INTO gl(reference, transdate, department_id, description) VALUES (?, ?, ?, ?)",
                $item->{id}, $transdate, $department_id, 'revoluttest'
            );
            my $id = $dbs->query("SELECT max(id) FROM gl")->list;
            $dbs->query("
                INSERT INTO acc_trans(trans_id, transdate, chart_id, amount) VALUES (?, ?, ?, ?)",
                $id, $transdate, $params->{bank_account}, $item->{legs}->[0]->{amount}
            );
            $dbs->query("
                INSERT INTO acc_trans(trans_id, transdate, chart_id, amount) VALUES (?, ?, ?, ?)",
                $id, $transdate, $params->{clearing_account}, $item->{legs}->[0]->{amount} * -1
            );
            $dbs->commit;
        }
    }
    my $tablehtml = $table_data;

    my $hash_pretty = format_pretty( $hash, { linum => 1 } );

    $c->render( template => 'transactions', msg => $msg, form1html => $form1html, account => $params->{account}, tablehtml => $tablehtml, hash_pretty => $hash_pretty );
};

app->start;
__DATA__

@@ index.html.ep
% layout 'default';
% title 'Home';
<h1>Revolut - SQL-Ledger Integration!</h1>
<h2>Database: <%= $dbname %></h2>
<pre>
    <%= dumper($hash) %>
</pre>

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
<div><%= $msg %></div>
<br/>
<%== $form1html %>
<br/>
<div class="h3">Account: <%= $account %></div>
<%== $tablehtml %>
<pre>
<%== $hash_pretty %>
</pre>





@@ layouts/default.html.ep
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.0.2/dist/css/bootstrap.min.css" rel="stylesheet" integrity="sha384-EVSTQN3/azprG1Anm3QDgpJLIm9Nao0Yz1ztcQTwFspd3yD65VohhpuuCOmLASjC" crossorigin="anonymous">

     <title><%= title %></title>
  </head>
  <body>
  
  <div class="container">
  <header>
    <div class="d-flex flex-column flex-md-row align-items-center pb-3 mb-4 border-bottom">
      <a href="/" class="d-flex align-items-center text-dark text-decoration-none">
        <svg xmlns="http://www.w3.org/2000/svg" width="40" height="32" class="me-2" viewBox="0 0 118 94" role="img"><title>Bootstrap</title><path fill-rule="evenodd" clip-rule="evenodd" d="M24.509 0c-6.733 0-11.715 5.893-11.492 12.284.214 6.14-.064 14.092-2.066 20.577C8.943 39.365 5.547 43.485 0 44.014v5.972c5.547.529 8.943 4.649 10.951 11.153 2.002 6.485 2.28 14.437 2.066 20.577C12.794 88.106 17.776 94 24.51 94H93.5c6.733 0 11.714-5.893 11.491-12.284-.214-6.14.064-14.092 2.066-20.577 2.009-6.504 5.396-10.624 10.943-11.153v-5.972c-5.547-.529-8.934-4.649-10.943-11.153-2.002-6.484-2.28-14.437-2.066-20.577C105.214 5.894 100.233 0 93.5 0H24.508zM80 57.863C80 66.663 73.436 72 62.543 72H44a2 2 0 01-2-2V24a2 2 0 012-2h18.437c9.083 0 15.044 4.92 15.044 12.474 0 5.302-4.01 10.049-9.119 10.88v.277C75.317 46.394 80 51.21 80 57.863zM60.521 28.34H49.948v14.934h8.905c6.884 0 10.68-2.772 10.68-7.727 0-4.643-3.264-7.207-9.012-7.207zM49.948 49.2v16.458H60.91c7.167 0 10.964-2.876 10.964-8.281 0-5.406-3.903-8.178-11.425-8.178H49.948z" fill="currentColor"></path></svg>
        <span class="fs-4">Revolut - SQL-Ledger Integration</span>
      </a>

      <nav class="d-inline-flex mt-2 mt-md-0 ms-md-auto">
        <a class="me-3 py-2 text-dark text-decoration-none" href="/rel3/revolut/index.pl">Home</a>
        <a class="me-3 py-2 text-dark text-decoration-none" href="/rel3/revolut/index.pl/accounts">Accounts</a>
        <a class="me-3 py-2 text-dark text-decoration-none" href="/rel3/revolut/index.pl/transactions">Transactions</a>
      </nav>
    </div>

  </header>

    <%= content %>
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

