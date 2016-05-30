#!/usr/bin/perl

use Mojolicious::Lite;
use DBI;
use SL::Form;
use SL::AM;
use SL::CT;
use SL::RP;
use Data::Dumper;
use XML::Simple;

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
);

my $globalform = new Form; # should not be needed except connecting to db so get rid of it
my $dbh = $globalform->dbconnect(\%myconfig);

helper slconfig => sub { \%myconfig };
helper dbh => sub { $dbh };

get '/' => sub {
    my $c = shift;
    $c->render('index');
};

any '/customer' => sub {
    my $c = shift;
    my $params = $c->req->params->to_hash;
    my $errormsg;
    my $form = new Form;
    $form->{db} = 'customer';
    $form->{ARAP} = 'ar';
    if ($params->{action} eq 'Save'){
        if ($params->{name}){
            for (qw(id customernumber name firstname lastname contactid addressid)){ $form->{$_} = $params->{$_} };
            CT->save($c->slconfig, $form);
            $c->redirect_to('/customers');
        } else {
            $errormsg = 'Blank name not allowed. Please correct.'
        }
    } else {
        $form->{id} = $params->{id};
        CT->create_links($c->slconfig, $form);
        for (qw(email phone fax mobile salutation firstname lastname gender contacttitle occupation)) { $form->{$_} = $form->{all_contact}->[0]->{$_} }
        $form->{contactid} = $form->{all_contact}->[0]->{id};
    }
    $c->render('customer', form => $form, errormsg => $errormsg);
};

any '/trial' => sub {
    my $c = shift;
    my $form = new Form;
    
    RP->trial_balance($c->slconfig, $form);
    
    $c->render('trial', form => $form, slconfig => $c->slconfig );
};


get '/customers' => sub {
   my $c = shift;
   my $form = new Form;
   $form->{db} = 'customer';
   for (qw(name customernumber address contact)) { $form->{"l_$_"} = 'Y' }
   CT->search($c->slconfig, $form);
   $c->render('customers', form => $form);
};


any '/department' => sub {
    my $c = shift;
    my $form = new Form;
    my $params = $c->req->params->to_hash;
    my $errormsg;
    if ($params->{action} eq 'Save'){
        if ($params->{description}){
            for (qw(id description role)){ $form->{$_} = $params->{$_} };
            AM->save_department($c->slconfig, $form);
            for (qw(id description role)){ delete $form->{$_} }
            $c->redirect_to('/departments');
        } else {
            $errormsg = 'Blank description not allowed. Please correct.'
        }
    } else {
        $form->{id} = $params->{id};
        AM->get_department($c->slconfig, $form);
    }
    $c->render('department', form => $form, errormsg => $errormsg);
};



get '/departments' => sub {
    my $c = shift;
    my $form = new Form;
    AM->departments($c->slconfig, $form);
    if ($c->accepts('', 'json')){
        $c->render(json => $form->{ALL});
    } else {
        $c->render('departments', form => $form);
    }
};



helper insert => sub {
  my $c = shift;
  my $form = new Form;
  ($form->{description}, $form->{role}, $form->{id}) = @_;
  AM->save_department($c->slconfig, $form);
  for (qw(id description role)){ delete $form->{$_} }

  return 1;
};



# setup websocket message handler
websocket '/insert' => sub {
  my $c = shift;
  my $form = new Form;
  $c->on( json => sub {
    my ($ws, $row) = @_;
    
    $c->insert(@$row);
    $form->{ALL} = ($row);

    #my $html = $ws->render_to_string( 'departmentrow', form => $form );
    my ($department_id) = $c->dbh->selectrow_array("SELECT MAX(id) FROM department WHERE description = '@$row[0]'");
    my $html = "<tr><td>$department_id</td><td>@$row[0]</td><td>@$row[1]</td></tr>";
    $ws->send({ json => {row => $html} });
  });
};


any '/jsontest' => sub {
    my $c = shift;
    my $form = new Form;
    my $data = $c->req->json;
    my @keys = keys $data->{customer};

    $form->{db} = 'customer';
    $form->{ARAP} = 'ar';
    for (@keys) { $form->{$_} = $data->{customer}->{$_} }
    CT->save($c->slconfig, $form);

    $c->render(text => "Customer added successfully ...\n");
};


any '/xmltest' => sub {
    my $c = shift;
    my $form = new Form;
    my $xmldata = $c->req->body;
    my $xml = new XML::Simple;

    my $data = $xml->XMLin($xmldata);
    my @keys = keys $data->{customer};

    $form->{db} = 'customer';
    $form->{ARAP} = 'ar';
    for (@keys) { $form->{$_} = $data->{customer}->{$_} if $data->{customer}->{$_} }
    #$c->render(text => Dumper($form));
    CT->save($c->slconfig, $form);
    $c->render(text => "Customer added successfully ...\n");
};


app->start;

__DATA__

@@ index.html.ep
% layout 'default';
% title 'Welcome';
%= include 'menu';

<div class="container">
    <div class="row">
        <p>NOTE: Resize browser window and see how form controls are stacked on smaller windows sizes. This makes it easy to develop one app for mobile or desktop.</p>
    </div>
    <div class="row">
        <h3>Sample form</h3>
        <div class="col-sm-4">
            <div class="row">
                <div class="form-group">
                    <label for="customernumber" class="control-label col-sm-4">Number</label>
                    <div class="col-sm-8">
                        <input type=text id="customernumber" class="form-control" name=customernumber>
                    </div>
                </div>
            </div>
            <div class="row">
                <div class="form-group">
                    <label for="customernumber" class="control-label col-sm-4">Name</label>
                    <div class="col-sm-8">
                        <input type=text id="customernumber" class="form-control" name=customernumber>
                    </div>
                </div>
            </div>
            <div class="row">
                <div class="form-group">
                    <label for="customernumber" class="control-label col-sm-4">Address</label>
                    <div class="col-sm-8">
                        <input type=text id="customernumber" class="form-control" name=customernumber>
                    </div>
                </div>
            </div>
        </div>

        <div class="col-sm-4">
            <div class="row">
                <div class="form-group">
                    <label for="customernumber" class="control-label col-sm-4">Tax Number</label>
                    <div class="col-sm-8">
                        <input type=text id="customernumber" class="form-control" name=customernumber>
                    </div>
                </div>
            </div>
        </div>

        <div class="col-sm-4">
            <div class="row">
                <div class="form-group">
                    <label for="customernumber" class="control-label col-sm-4">First Name</label>
                    <div class="col-sm-8">
                        <input type=text id="customernumber" class="form-control" name=customernumber>
                    </div>
                </div>
            </div>
            <div class="row">
                <div class="form-group">
                    <label for="customernumber" class="control-label col-sm-4">Last Name</label>
                    <div class="col-sm-8">
                        <input type=text id="customernumber" class="form-control" name=customernumber>
                    </div>
                </div>
            </div>
        </div>


    </div>
</div>



@@ trial.html.ep
% layout 'default';
% title 'Trial Balance';
%= include 'menu';

<h1>Trial Balance</h1>
<table class="table table-striped">
<thead>
<tr>
    <th>Account</th>
    <th>Description</th>
    <th>Beginning Balance</th>
    <th>Debit</th>
    <th>Credit</th>
    <th>Ending Balance</th>
</tr>
</thead>
<tbody id="trial">
% for my $row ( sort { $a->{accno} cmp $b->{accno} } @{ $form->{TB} } ) {
<tr>
  <td><%= $row->{accno} %></td>
  <td><%= $row->{description} %></td>
  <td align="right"><%= $form->format_amount($slconfig, $row->{begbalance}, 2) %></td>
  <td align="right"><%= $form->format_amount($slconfig, $row->{debit}, 2) %></td>
  <td align="right"><%= $form->format_amount($slconfig, $row->{credit}, 2) %></td>
  <td align="right"><%= $form->format_amount($slconfig, $row->{endbalance}, 2) %></td>
</tr>
% }
</tbody>
</table>
<br/>




@@ customers.html.ep
% layout 'default';
% title 'Customers';
%= include 'menu';
<h3>Adding a customer with JSON from command line</h3>
<pre>curl -X POST -H "Content-Type: application/json" -d @customer.json http://localhost:3000/jsontest</pre>
<h3>Adding a customer with XML from command line</h3>
<pre>curl -X POST -d @customer.xml http://localhost:3000/xmltest</pre>

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
  <td><a href="/customer?id=<%=$row->{id}%>"><%= $row->{id} %></a></td>
  <td><%= $row->{customernumber} %></td>
  <td><%= $row->{name} %></td>
  <td><%= $row->{address} %></td>
  <td><%= $row->{contact} %></td>
</tr>
% }



@@ customer.html.ep
% layout 'default';
% title 'Add / Change Customer';
%= include 'menu'
% if ($errormsg){
<div class="alert alert-danger" role="alert">
  <span class="glyphicon glyphicon-exclamation-sign" aria-hidden="true"></span>
  <span class="sr-only">Error:</span>
  <%= $errormsg %>
</div>
% }
%= include 'customerform'



@@ customerform.html.ep
<h2>Customer Form</h2>
<form method=post action="/customer" class="form-horizontal">
<div class="form-group">
    <label for="customernumber" class="control-label col-xs-2">Customer Number</label>
    <div class="col-xs-10">
        <input type=text id="customernumber" class="form-control" name=customernumber value="<%== $form->{customernumber} %>">
    </div>
</div>
<div class="form-group">
    <label for="name" class="control-label col-xs-2">Name</label>
    <div class="col-xs-10">
        <input type=text id="name" class="form-control" name=name value="<%== $form->{name} %>">
    </div>
</div>
<div class="form-group">
    <label for="firstname" class="control-label col-xs-2">First Name</label>
    <div class="col-xs-10">
        <input type=text id="firstname" class="form-control" name=firstname value="<%== $form->{firstname} %>">
    </div>
</div>
<div class="form-group">
    <label for="lastname" class="control-label col-xs-2">Last Name</label>
    <div class="col-xs-10">
        <input type=text id="lastname" class="form-control" name=lastname value="<%== $form->{lastname} %>">
    </div>
</div>


<input type=submit class="btn btn-primary" name=action value="Save">
<input type=hidden name=id value="<%== $form->{id} %>">
<input type=hidden name=addressid value="<%== $form->{addressid} %>">
<input type=hidden name=contactid value="<%== $form->{contactid} %>">
</form>



@@ departments.html.ep
% layout 'default';
% title 'Departments';
%= include 'menu'
%= include 'departmentform2'
<h1>List of departments</h1>
<table class="table table-striped">
<thead>
<tr>
    <th>ID</th>
    <th>Description</th>
    <th>Role</th>
</tr>
</thead>
<tbody id="deptrows">
    %= include 'departmentrow'
</tbody>
</table>
<br/>
<a href="/department">Add new department</a>
%= javascript begin
    function insert () {
      if (!("WebSocket" in window)) {
        alert('WebSockets not supported!');
        return;
      }
      var ws = new WebSocket("<%= url_for('insert')->to_abs %>");
      ws.onopen = function () {
        var description = $('#description');
        var role = $('#role');
        var department_id = $('#department_id');
        ws.send(JSON.stringify([description.val(), role.val(), department_id.val()]));
        description.val('');
        role.val('');
        department_id.val('');
      };
      ws.onmessage = function (evt) {
        var data = JSON.parse(evt.data);
        $('#deptrows').append(data.row);
      };
    }
%= end
<pre>
%= dumper($form);

@@ departmentrow.html.ep
% for my $row (@{$form->{ALL}}) {
<tr>
  <td><a href="/department?id=<%=$row->{id}%>"><%= $row->{id} %></a></td>
  <td><%= $row->{description} %></td>
  <td><%= $row->{role} %></td>
</tr>
% }


@@ departments.xml.ep
<departments>
% for my $row (@{$form->{ALL}}) {
<department>
<id><%= $row->{id} %></id>
<description><%= $row->{description} %></description>
<role><%= $row->{role} %></role>
</department>
% }
</departments>



@@ department.html.ep
% layout 'default';
% title 'Add / Change Department';
% if ($errormsg){
<div class="alert alert-danger" role="alert">
  <span class="glyphicon glyphicon-exclamation-sign" aria-hidden="true"></span>
  <span class="sr-only">Error:</span>
  <%= $errormsg %>
</div>
% }
%= include 'departmentform'



@@ departmentform.html.ep
<h2>Department Form</h2>
<form method=post action="/department" class="form-horizontal">
<div class="form-group">
    <label for="description" class="control-label col-xs-2">Department</label>
    <div class="col-xs-10">
        <input type=text id="description" class="form-control" name=description value="<%== $form->{description} %>">
    </div>
</div>
<div class="form-group">
    <label for="role" class="control-label col-xs-2">Role</label>
    <div class="col-xs-10">
        <input type=text id="role" class="form-control" name=role value="<%== $form->{role} %>">
    </div>
</div>
<input type=submit class="btn btn-primary" name=action value="Save">
<input type=hidden name=id value="<%== $form->{id} %>">
</form>



@@ departmentform2.html.ep
<h2>Department Form</h2>
<div class="row">
    <p>NOTE: This form uses websocket protocol to save new department to database and shows it on list below without refreshing page.
</div>

<div class="form-horizontal" role="form">
<div class="form-group">
    <label for="description" class="control-label col-xs-2">Department</label>
    <div class="col-xs-10">
        <input type=text id="description" class="form-control">
    </div>
</div>
<div class="form-group">
    <label for="role" class="control-label col-xs-2">Role</label>
    <div class="col-xs-10">
        <input type=text id="role" class="form-control">
    </div>
</div>
<input type=submit value="Add" onclick="insert()">
</div>


@@ department.json.ep
{
"id":"<%= $form->{id} %>",
"description":"<%= $form->{description} %>",
}



@@ menu.html.ep
<div class="row">
<ul class="list-inline">
    <li><a href="/">Home</a></li>
    <li><a href="/departments">Departments</a></li>
    <li><a href="/departments.xml">Departments XML</a></li>
    <li><a href="/departments.json">Departments JSON</a></li>
    <li><a href="/customers">Customers</a></li>
    <li><a href="/trial">Trial Balance</a></li>
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
        <p>Just proof-of-concept code</p>
      </div>
      <div class="container">
        <%= content %>
      </div>
  </div>

  </body>
  <script src="https://ajax.googleapis.com/ajax/libs/jquery/1.11.3/jquery.min.js"></script>
  <script src="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.6/js/bootstrap.min.js" integrity="sha384-0mSbJDEHialfmuBBQP6A4Qrprq5OVfW37PRR3j5ELqxss1yVqOtnepnHVP9aJ7xS" crossorigin="anonymous"></script>
</html>

