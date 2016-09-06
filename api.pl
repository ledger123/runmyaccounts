#!/usr/bin/perl

use Mojolicious::Lite;
use DBI;
use Data::Dumper;
use XML::Simple;
use DBIx::Simple;

use SL::Form;
use SL::CT;

my %myconfig = (
  company => 'Maverick Solutions',
  dateformat => 'mm/dd/yy',
  dbconnect => 'dbi:Pg:dbname=ledger28',
  dbdriver => 'Pg',
  dbhost => '',
  dbname => 'ledger28',
  dboptions => 'set DateStyle to \'SQL, US\'',
  dbpasswd => '',
  dbport => '',
  dbuser => 'postgres',
  email => 'armaghan@system3software.com',
  name => 'Armaghan Saqib',
  numberformat => '1,000.00',
  templates => 'templates/demo@ledger28',
);

my $globalform = new Form; # should not be needed except connecting to db so get rid of it
my $dbh = $globalform->dbconnect(\%myconfig);
my $dbs = DBIx::Simple->connect($dbh);

helper slconfig => sub { \%myconfig };
helper dbh => sub { $dbh };
helper dbs => sub { $dbs };

get '/' => sub {
    my $c = shift;
    $c->render('index');
};

# Customers list in json, xml or html depending how it is called.
get '/customers/:id' => { id => '0' } => sub {
   my $c = shift;
   my $form = new Form;
   my $id = $c->stash('id');
   $id *= 1;

   $form->{db} = 'customer';

   if ($id){
       # List a single customer if id is given.
       $form->{customernumber} = $c->dbs->query('SELECT customernumber FROM customer WHERE id = ?', $id)->list;
       $form->{customernumber} = 'not found' if !$form->{customernumber};
   }

   for (qw(name customernumber address contact)) { $form->{"l_$_"} = 'Y' }
   CT->search($c->slconfig, $form);

   $form->{ctype} = $c->req->headers->content_type;
   if ($c->accepts('', 'json')){
        $c->render(json => $form->{CT});
   } else {
        $c->render('customers', form => $form);
   }
};


# Single customer in json or xml format
get '/customersdisable/:id' => sub {
   my $c = shift;
   my $txt = $c->stash('id');
   my $key = $c->param('key');
   $c->render(text => "$txt -- $key");
};


# Delete single customer
del '/customers/:id' => sub {
   my $c = shift;
   my $id = $c->stash('id');
   $id *= 1;
   my $status;

   if ($id){
        my $anyinvoice = $c->dbs->query('SELECT id FROM ar WHERE customer_id = ? LIMIT 1', $id)->list;
        my $anyorder = $c->dbs->query('SELECT id FROM oe WHERE customer_id = ? LIMIT 1', $id)->list;
        if ($anyinvoice or $anyorder){
            $status = 'Transactions exist';
        } else {
            $c->dbs->query('DELETE FROM contact WHERE trans_id = ?', $id);
            $c->dbs->query('DELETE FROM address WHERE trans_id = ?', $id);
            $c->dbs->query('DELETE FROM customertax   WHERE customer_id = ?', $id);
            $c->dbs->query('DELETE FROM partscustomer WHERE customer_id = ?', $id);
            $c->dbs->query('DELETE FROM customer WHERE id = ?', $id);
            $status = 'Deleted';
        }
   } else {
       $status = 'Invalid id';
   }
   $c->render(text => $status, status => 200);
};


# Add new customer in json or XML format
# Update customer if id is given
post '/customers' => sub {
    my $c = shift;
    my $form = new Form;

    my $content_type = $c->req->headers->content_type;

    $form->{db} = 'customer';
    $form->{ARAP} = 'ar';

    my $data = {};
    my @keys;

    if ($content_type eq 'application/json'){
        $data = $c->req->json;
    } elsif ($content_type eq 'application/xml'){
        my $xmldata = $c->req->body;
        my $xml = new XML::Simple;
        $data = $xml->XMLin($xmldata);
    } else {
        $c->render(text => 'Invalid content type'); 
    }
    @keys = keys $data->{customer};
    for (@keys) { $form->{$_} = $data->{customer}->{$_} if $data->{customer}->{$_} }

    if ($form->{id}){
        # if it existing customer and we are updating then find correct contactid and addressid
        $form->{contactid} = $c->dbs->query('SELECT id FROM contact WHERE trans_id = ?', $form->{id})->list;
        $form->{addressid} = $c->dbs->query('SELECT id FROM address WHERE trans_id = ?', $form->{id})->list;
    }

    CT->save($c->slconfig, $form);
    $c->render(text => "Customer added successfully posted as $content_type ...\n");
};


app->start;

__DATA__

@@ index.html.ep
% layout 'default';
% title 'Welcome';
%= include 'menu';

<h3>View all customers in XML format</h3>
<pre>http://localhost:3000/customers.xml</pre>

<h3>View all customers in JSON format</h3>
<pre>http://localhost:3000/customers.json</pre>

<h3>View Single customer in XML format</h3>
<pre>http://localhost:3000/customers/10825.xml</pre>

<h3>View Single customer in JSON format</h3>
<pre>http://localhost:3000/customers/10825.json</pre>

<h3>Adding a customer with JSON from command line</h3>
<pre>curl -X POST -H "Content-Type: application/json" -d @customer.json http://localhost:3000/customers</pre>

<h3>Adding a customer with XML from command line</h3>
<pre>curl -X POST -H "Content-Type: applicaiton/xml" -d @customer.xml http://localhost:3000/customers</pre>

<h3>Delete a customer with DELETE request</h3>
<pre>curl -X DELETE http://localhost:3000/customers/10494</pre>




@@ customers.xml.ep
<customers>
% for my $row (@{$form->{CT}}) {
<customer>
% for my $k (keys ($row)){
<<%= $k %>><%= $row->{$k} %></<%= $k %>>
% }
</customer>
% }
</customers>


@@ customers.html.ep
% layout 'default';
% title 'Customers';
%= include 'menu';

<h1>List of customers</h1>
<table class="table table-striped">
<thead>
<tr>
    <th>ID</th>
    <th>Name</th>
    <th>Number</th>
    <th>Address</th>
    <th>Contact</th>
</tr>
</thead>
<tbody id="deptrows">
    %= include 'customerrow'
</tbody>
</table>
<br/>


@@ customerrow.html.ep
% for my $row (@{$form->{CT}}) {
<tr>
  <td><%= $row->{id} %></td>
  <td><%= $row->{customernumber} %></td>
  <td><%= $row->{name} %></td>
  <td><%= $row->{address} %></td>
  <td><%= $row->{contact} %></td>
</tr>
% }

@@ menu.html.ep
<div class="row">
<ul class="list-inline">
    <li><a href="/">Home</a></li>
    <li><a href="/customers">Customers</a></li>
    <li><a href="/customers.xml">Customers XML</a></li>
    <li><a href="/customers.json">Customers JSON</a></li>
</ul>
</div>


@@ layouts/default.html.ep
<!DOCTYPE html>
<html>
  <head>
    <title><%= title %></title>
    <link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.6/css/bootstrap.min.css" integrity="sha384-1q8mTJOASx8j1Au+a5WDVnPi2lkFfwwEAa8hDDdjZlpLegxhjVME1fgjWPGmkzs7" crossorigin="anonymous">
    <link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.6/css/bootstrap-theme.min.css" integrity="sha384-fLW2N01lMqjakBkx3l/M9EahuwpSfeNvV63J5ezn3uZzapT0u7EYsXMjQV+0En5r" crossorigin="anonymous">
  </head>
  <body role=document>

  <div class="container" role="main">
      <!-- Main jumbotron for a primary marketing message or call to action -->
      <div class="jumbotron">
        <h1>SQL-Ledger on Mojolicious</h1>
        <p>REST API for Customers</p>
      </div>
      <div class="container">
        <%= content %>
      </div>
  </div>

  </body>
  <script src="https://ajax.googleapis.com/ajax/libs/jquery/2.2.4/jquery.min.js"></script>
  <script src="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.6/js/bootstrap.min.js" integrity="sha384-0mSbJDEHialfmuBBQP6A4Qrprq5OVfW37PRR3j5ELqxss1yVqOtnepnHVP9aJ7xS" crossorigin="anonymous"></script>
</html>

