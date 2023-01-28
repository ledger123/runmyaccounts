#!/usr/bin/env perl

BEGIN {
    push @INC, '.';
}

use Mojolicious::Lite;
use XML::Hash::XS;
use JSON::XS;
use Data::Dumper;
use Mojo::Util qw(unquote);
use DBI;
use DBIx::Simple;
use XML::Simple;
use Data::Format::Pretty::JSON qw(format_pretty);

use SL::Form;
use SL::AM;
use SL::CT;
use SL::RP;
use SL::AA;
use SL::IS;
use SL::CA;
use SL::GL;

my %myconfig = (
    dateformat   => 'mm/dd/yy',
    dbdriver     => 'Pg',
    dbhost       => '',
    dbname       => 'ledger28',
    dbpasswd     => '',
    dbport       => '',
    dbuser       => 'postgres',
    numberformat => '1,000.00',
);

helper slconfig => sub { \%myconfig };

helper dbs => sub {
    my ( $c, $dbname ) = @_;
    my $dbs;
    if ($dbname) {
        my $dbh = DBI->connect( "dbi:Pg:dbname=$dbname", 'postgres', '' ) or die $DBI::errstr;
        $dbs = DBIx::Simple->connect($dbh);
        return $dbs;
    } else {
        return $dbs;
    }
};

get '/' => sub {
    my $c = shift;
} => 'index';

get 'setapi_key' => sub {
    my $c      = shift;
    my $api_key = $c->session->{api_key};
    my $client = $c->session->{client};

    $c->session->{api_key} = 'd1bvbxkI8f1bnMBJ4sZiC-xupl4fOEzf';     # if !$c->session->{api_key};
    $c->session->{client} = 'ledger28' if !$c->session->{client};

    #$c->session->{api_key} = $c->param('api_key')                if $c->param('api_key');
    $c->session->{client} = $c->param('client') if $c->param('client');
    $c->render( api_key => $c->session->{api_key}, client => $c->session->{client} );
};

##########################################
#  OUR SQL-LEDGER API CALLS DEFINITIONS  #
##########################################

any '/:clientname/sql_customers' => sub {
    my $c              = shift;
    my $params         = $c->req->params->to_hash;
    my $dbname         = $c->param('clientname');
    my $customernumber = $c->stash('customernumber');
    my $dbs            = $c->dbs($dbname);
    my $api_key         = $dbs->query("SELECT fldvalue FROM defaults WHERE fldname='api_key'")->list;
    if ( $api_key ne $params->{api_key} ) {
        $c->render( status => 401, text => 'Invalid key' );
        return;
    }
    $c->slconfig->{dbconnect} = "dbi:Pg:dbname=$dbname";

    my $form = new Form;
    $form->{db} = 'customer';
    for ( keys %$params ) { $form->{$_} = $params->{$_} if $params->{$_} }
    CT->search( $c->slconfig, $form );
    $c->render( json => $form->{CT} );
};

any '/:clientname/sqlchart' => sub {
    my $c      = shift;
    my $params = $c->req->params->to_hash;
    my $dbname = $c->param('clientname');
    my $dbs    = $c->dbs($dbname);
    my $api_key = $dbs->query("SELECT fldvalue FROM defaults WHERE fldname='api_key'")->list;
    if ( $api_key ne $params->{api_key} ) {
        $c->render( status => 401, text => 'Invalid key' );
        return;
    }

    $c->slconfig->{dbconnect} = "dbi:Pg:dbname=$dbname";

    my $form = new Form;
    for ( keys %$params ) { $form->{$_} = $params->{$_} if $params->{$_} }
    CA->all_accounts( $c->slconfig, $form );
    $c->render( json => $form->{CA} );
};

any '/:clientname/sqltrial_balance' => sub {
    my $c      = shift;
    my $params = $c->req->params->to_hash;
    my $dbname = $c->param('clientname');

    my $dbs    = $c->dbs($dbname);
    my $api_key = $dbs->query("SELECT fldvalue FROM defaults WHERE fldname='api_key'")->list;
    if ( $api_key ne $params->{api_key} ) {
        $c->render( status => 401, text => 'Invalid key' );
        return;
    }

    $c->slconfig->{dbconnect} = "dbi:Pg:dbname=$dbname";

    my $form = new Form;
    for ( keys %$params ) { $form->{$_} = $params->{$_} if $params->{$_} }
    RP->trial_balance( $c->slconfig, $form );
    $c->render( json => $form->{TB} );
};

any '/:clientname/sqlgl_transaction' => sub {
    my $c      = shift;
    my $params = $c->req->params->to_hash;
    my $dbname = $c->param('clientname');

    my $dbs    = $c->dbs($dbname);
    my $api_key = $dbs->query("SELECT fldvalue FROM defaults WHERE fldname='api_key'")->list;
    if ( $api_key ne $params->{api_key} ) {
        $c->render( status => 401, text => 'Invalid key' );
        return;
    }

    $c->slconfig->{dbconnect} = "dbi:Pg:dbname=$dbname";
    my $form = new Form;
    for ( keys %$params ) { $form->{$_} = $params->{$_} if $params->{$_} }
    GL->transaction( $c->slconfig, $form );
    $c->render( json => $form->{TR} );
};

any '/:clientname/sqlgl_transactions' => sub {
    my $c      = shift;
    my $params = $c->req->params->to_hash;
    my $dbname = $c->param('clientname');

    my $dbs    = $c->dbs($dbname);
    my $api_key = $dbs->query("SELECT fldvalue FROM defaults WHERE fldname='api_key'")->list;
    if ( $api_key ne $params->{api_key} ) {
        $c->render( status => 401, text => 'Invalid key' );
        return;
    }

    $c->slconfig->{dbconnect} = "dbi:Pg:dbname=$dbname";

    my $form = new Form;
    for ( keys %$params ) { $form->{$_} = $params->{$_} if $params->{$_} }
    GL->transactions( $c->slconfig, $form );
    $c->render( json => $form->{GL} );
};

any '/:clientname/sqlgl_activity' => sub {
    my $c      = shift;
    my $params = $c->req->params->to_hash;
    my $dbname = $c->param('clientname');

    my $dbs    = $c->dbs($dbname);
    my $api_key = $dbs->query("SELECT fldvalue FROM defaults WHERE fldname='api_key'")->list;
    if ( $api_key ne $params->{api_key} ) {
        $c->render( status => 401, text => 'Invalid key' );
        return;
    }

    $c->slconfig->{dbconnect} = "dbi:Pg:dbname=$dbname";

    my $form = new Form;
    for ( keys %$params ) { $form->{$_} = $params->{$_} if $params->{$_} }
    $form->{accno}          = '1200';
    $form->{accounttype}    = 'standard';
    $form->{sort}           = 'transdate';
    $form->{fx_transaction} = '1';
    CA->all_transactions( $c->slconfig, $form );
    $c->render( json => $form->{CA} );
};

any '/:clientname/sqlbalance_sheet' => sub {
    my $c      = shift;
    my $params = $c->req->params->to_hash;
    my $dbname = $c->param('clientname');

    my $dbs    = $c->dbs($dbname);
    my $api_key = $dbs->query("SELECT fldvalue FROM defaults WHERE fldname='api_key'")->list;
    if ( $api_key ne $params->{api_key} ) {
        $c->render( status => 401, text => 'Invalid key' );
        return;
    }

    $c->slconfig->{dbconnect} = "dbi:Pg:dbname=$dbname";

    my $form = new Form;
    for ( keys %$params ) { $form->{$_} = $params->{$_} if $params->{$_} }
    $form->{method}      = 'accrual';
    $form->{accounttype} = 'standard';
    RP->balance_sheet( $c->slconfig, $form );
    $c->render( json => $form->{BALSHT} );
};

any '/:clientname/sql_post_gl_transaction' => sub {
    my $c            = shift;
    my $dbname       = $c->param('clientname');
    my $params       = $c->req->params->to_hash;
    my $content_type = $c->req->headers->content_type;
    my $data;
    my @keys;
    my $form = new Form;

    my $x_api_key = $c->req->headers->header('X-API-Key');

    my $dbs    = $c->dbs($dbname);
    my $api_key = $dbs->query("SELECT fldvalue FROM defaults WHERE fldname='api_key'")->list;
    if ( $api_key ne $x_api_key ) {
        $c->render( status => 401, text => 'Invalid key' );
        return;
    }

    $c->slconfig->{dbconnect} = "dbi:Pg:dbname=$dbname";

    if ( $content_type eq 'application/json' ) {
        $data = $c->req->json;
    } elsif ( $content_type eq 'application/xml' ) {
        my $xmldata = $c->req->body;
        my $xml     = new XML::Simple;
        $data = $xml->XMLin($xmldata);
    } else {
        $c->render( text => 'Invalid content type' );
    }

    for ( keys %{ $data->{HEADER} } ) { $form->{$_} = $data->{HEADER}->{$_} }
    my $i = 1;
    for my $row ( @{ $data->{LINES} } ) {
        for ( keys %$row ) { $form->{"${_}_$i"} = $row->{$_} }
        #delete $form->{"trans_id_$i"};
        #delete $form->{"entry_id_$i"};
        $i++;
    }
    $form->{rowcount} = $i;
    delete $form->{id};

    #my $pretty_hash .= format_pretty( $form, { linum => 1 } );
    #$c->render('apicall', code => '500', body => $pretty_hash);

    #delete $form->{reference};

    GL->post_transaction( $c->slconfig, $form );
    $c->render( json => { code => 300, message => $form->{accno_1} } );
};

any '/:clientname/sqlincome_statement' => sub {
    my $c      = shift;
    my $params = $c->req->params->to_hash;
    my $dbname = $c->param('clientname');

    my $dbs    = $c->dbs($dbname);
    my $api_key = $dbs->query("SELECT fldvalue FROM defaults WHERE fldname='api_key'")->list;
    if ( $api_key ne $params->{api_key} ) {
        $c->render( status => 401, text => 'Invalid key' );
        return;
    }

    $c->slconfig->{dbconnect} = "dbi:Pg:dbname=$dbname";

    my $form = new Form;
    for ( keys %$params ) { $form->{$_} = $params->{$_} if $params->{$_} }
    $form->{method}      = 'accrual';
    $form->{accounttype} = 'standard';
    RP->income_statement( $c->slconfig, $form );
    $c->render( json => $form->{INCOME} );
};

app->start;
__DATA__

@@ setapi_key.html.ep
% layout 'default';
<h1>Set API key</h1>
<form action=setapi_key>
API Key: <input name=api_key value="<%= $api_key %>" size=40><br/>
Client: <input name=client value="<%= $client %>" size=20><br/>
%= submit_button 'Set API key and client'
</form>

@@ apicall.html.ep
% layout 'default';
<h1>API Call</h1>
Code:<%== $code %><br/>
Body:<pre><%== $body %></pre><br/>

@@ copygl.html.ep
% layout 'default';
<h1>Set API key</h1>
<form action=copygl>
ID: <input name=id value="<%= $id %>" size=10><br/>
From URL: <input name=fromurl value="<%= $fromurl %>" size=50><br/>
To URL: <input name=tourl value="<%= $tourl %>" size=50><br/>
%= submit_button 'Copy', name => "action"
</form>


@@ apicall.html.ep
% layout 'default';
<h1>API Call</h1>
Code:<%== $code %><br/>
Body:<pre><%== $body %></pre><br/>


@@ jsonform.html.ep
% layout 'default';
<h1><%= $subname %> form</h1>
<form action=<%= $subname %> method='post'>
<textarea name=json rows=40 cols=60><%== $jsondefault %></textarea>
    %= submit_button 'Send'
</form>

@@ createresult.html.ep
<h1>Create result</h1>
Code: <%= $code %><br/>
Body:<pre><%= $body %><br/>

@@ customerlist_html.html.ep
% layout 'default';
<h1>Customer List</h1>
Code: <%= $code %><br/>
Body:<%== $body %><br/>

@@ index.html.ep
% layout 'default';
% title 'Welcome';
<h1>Important Links</h1>
<br/>
<div class="h5"><a href="https://www.runmyaccounts.ch/support-artikel/run-my-accounts-restful-api/" target=_blank>RMA API Docs</a></div>
<div class="h5"><a href="https://zapier.com/apps/run-my-accounts/integrations" target=_blank>RMA Zapier Integration</a></div>
<div class="h5"><a href="https://github.com/openstream/woocommerce-runmyaccounts" target=_blank>Wordpress Integration</a></div>


<h1>API calls</h1>
<div class="row">
%= link_to "Set API key" => 'setapi_key'
</div>
<p>Current API Key</b>: <%= $c->session->{api_key} %></p>
<p>This key must exist in sql-ledger database defaults table. (fldname='api_key', fldvalue='key value')</p>

<h1>SQL-Ledger API</h1>
<b>Note 1: Parameter values can be passed to the request but adding ? to the end of url and then specifying parameters in parameter=value format. Multiple parameters can be seperated by &. See customer list for an example.</b><br/><br/>
<b>Note 2: Login to SQL-Ledger, go to search screen of the respective report and right click on any field to find the parameter name.</b><br/><br/>
<ol>
<li><a href="/api/index.pl/<%= $c->session->{client} %>/sqlchart?api_key=<%= $c->session->{api_key} %>" target=_blank>Chart of accounts</a><br/>
https://ledger123.net/api/index.pl/<%= $c->session->{client} %>/sqlchart
<li><a href="/api/index.pl/<%= $c->session->{client} %>/sqltrial_balance?api_key=<%= $c->session->{api_key} %>" target=_blank>Trial Balance</a><br/>
https://ledger123.net/api/index.pl/<%= $c->session->{client} %>/sqltrial_balance
<li><a href="/api/index.pl/<%= $c->session->{client} %>/sqlgl_transactions?api_key=<%= $c->session->{api_key} %>" target=_blank>Journal</a><br/>
https://ledger123.net/api/index.pl/<%= $c->session->{client} %>/sqlgl_transactions
<li><a href="/api/index.pl/<%= $c->session->{client} %>/sqlgl_activity?api_key=<%= $c->session->{api_key} %>" target=_blank>Account Activity</a><br/>
https://ledger123.net/api/index.pl/<%= $c->session->{client} %>/sqlgl_activity
<li><a href="/api/index.pl/<%= $c->session->{client} %>/sqlincome_statement?api_key=<%= $c->session->{api_key} %>" target=_blank>Income Statement</a><br/>
https://ledger123.net/api/index.pl/<%= $c->session->{client} %>/sqlincome_statement
<li><a href="/api/index.pl/<%= $c->session->{client} %>/sqlbalance_sheet?api_key=<%= $c->session->{api_key} %>" target=_blank>Balance Sheet</a><br/>
https://ledger123.net/api/index.pl/<%= $c->session->{client} %>/sqlbalance_sheet
<li><a href="/api/index.pl/<%= $c->session->{client} %>/sqlgl_transaction?id=10142&api_key=<%= $c->session->{api_key} %>" target=_blank>Get a GL Transaction</a><br/>
https://ledger123.net/api/index.pl/<%= $c->session->{client} %>/sqlgl_transaction?id=10142
<li><a href="/api/index.pl/<%= $c->session->{client} %>/sql_post_gl_transaction" target=_blank>Add a GL Transaction</a><br/>
https://ledger123.net/api/index.pl/<%= $c->session->{client} %>/sql_post_gl_transaction<br/>
curl -X POST -H "Content-Type: application/json"  -H "X-API-Key: <%= $c->session->{api_key} %>" -d @gl.json https://ledger123.net/api/index.pl/<%= $c->session->{client} %>/sql_post_gl_transaction
<li><a href="/api/index.pl/<%= $c->session->{client} %>/sql_customers?api_key=<%= $c->session->{api_key} %>" target=_blank>Customers</a><br/>
https://ledger123.net/api/index.pl/<%= $c->session->{client} %>/sql_customers
</ol>


@@ layouts/default.html.ep
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1"><!-- lightbox css -->

  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/lightbox2/2.11.3/css/lightbox.min.css" integrity="sha512-ZKX+BvQihRJPA8CROKBhDNvoc2aDMOdAlcm7TUQY+35XYtrd3yh95QOOhsPDQY9QnKE0Wqag9y38OIgEvb88cA==" crossorigin="anonymous" referrerpolicy="no-referrer"><!-- Bootstrap CSS -->

  <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.0.2/dist/css/bootstrap.min.css" rel="stylesheet" integrity="sha384-EVSTQN3/azprG1Anm3QDgpJLIm9Nao0Yz1ztcQTwFspd3yD65VohhpuuCOmLASjC" crossorigin="anonymous">

   <title>RMA API Clone - <%= title %></title>
</head>

<body>

  <div class="container">
    <div><a href="/api/">Home</a></div>

    <%= content %>
  </div>

  <hr>

  <!-- Footer -->
  <footer>
    <div class="container">
      <div class="row">
        <div class="col-lg-8 col-md-10 mx-auto">
          <ul class="list-inline text-center">
            <li class="list-inline-item">
              <a href="#">
                <span class="fa-stack fa-lg">
                  <i class="fas fa-circle fa-stack-2x"></i>
                  <i class="fab fa-twitter fa-stack-1x fa-inverse"></i>
                </span>
              </a>
            </li>
            <li class="list-inline-item">
              <a href="#">
                <span class="fa-stack fa-lg">
                  <i class="fas fa-circle fa-stack-2x"></i>
                  <i class="fab fa-facebook-f fa-stack-1x fa-inverse"></i>
                </span>
              </a>
            </li>
            <li class="list-inline-item">
              <a href="#">
                <span class="fa-stack fa-lg">
                  <i class="fas fa-circle fa-stack-2x"></i>
                  <i class="fab fa-github fa-stack-1x fa-inverse"></i>
                </span>
              </a>
            </li>
          </ul>
          <p class="copyright text-muted">Copyright &copy; selfservice.pk 2021</p>
        </div>
      </div>
    </div>
  </footer>

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
% }

  <script src="https://cdnjs.cloudflare.com/ajax/libs/jquery/3.6.0/jquery.min.js" integrity="sha512-894YE6QWD5I59HgZOGReFYm4dnWc1Qt5NtvYSaNcOP+u1T9qYdvdihz0PPSiiqn/+/3e7Jo4EaG7TubfWGUrMQ==" crossorigin="anonymous" referrerpolicy="no-referrer"></script> 

  <script src="https://cdnjs.cloudflare.com/ajax/libs/lightbox2/2.11.3/js/lightbox.min.js" integrity="sha512-k2GFCTbp9rQU412BStrcD/rlwv1PYec9SNrkbQlo6RZCf75l6KcC3UwDY8H5n5hl4v77IDtIPwOk9Dqjs/mMBQ==" crossorigin="anonymous" referrerpolicy="no-referrer"></script> 

  <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.0.2/dist/js/bootstrap.bundle.min.js" integrity="sha384-MrcW6ZMFYlzcLA8Nl+NtUVF0sA7MsXsP1UyJoMp4YLEuNSfAP+JcXn/tWtIaxVXM" crossorigin="anonymous"></script>

</body>

</html>

