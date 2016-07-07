#!/usr/bin/perl

use Mojolicious::Lite;
use DBI;
use SL::Form;
use SL::AM;
use SL::CT;
use SL::RP;
use SL::AA;
use SL::IS;
use Data::Dumper;
use XML::Simple;
use DBIx::Simple;

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


get '/customers' => sub {
   my $c = shift;
   my $form = new Form;
   $form->{db} = 'customer';
   for (qw(name customernumber address contact)) { $form->{"l_$_"} = 'Y' }
   CT->search($c->slconfig, $form);

   $form->{ctype} = $c->req->headers->content_type;
   if ($c->accepts('', 'json')){
        $c->render(json => $form->{CT});
   } else {
        $c->render('customers', form => $form);
   }
};


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

    my ($department_id) = $c->dbh->selectrow_array("SELECT MAX(id) FROM department WHERE description = '@$row[0]'");
    @{$form->{ALL}} = ( { id => $department_id, description => @$row[0], role => @$row[1] } );
    my $html = $ws->render_to_string( 'departmentrow', form => $form );

    $ws->send({ json => {row => $html} });
  });
};


any '/trial' => sub {
    my $c = shift;
    my $form = new Form;
    @{$form->{TB}} = ({ accno => 'NA', description => 'NA' });
    $c->render('trial', form => $form, slconfig => $c->slconfig );
};

# setup websocket to update trial for given dates
websocket '/updatetrial' => sub {
    my $c = shift;
    my $form = new Form;

    $c->on( json => sub {
        my ($ws, $row) = @_;

        $form->{fromdate} = @$row[0];
        $form->{todate} = @$row[1];

        RP->trial_balance($c->slconfig, $form);
        my $html = $ws->render_to_string('trialrow', form => $form, slconfig => $c->slconfig);

        $ws->send({ json => {row => $html} });
    });
};


any '/printinvoice' => sub {
    my $c = shift;
    my $form = new Form;

    # sql-ledger.conf
    my $userspath = 'users';
    my $spool = 'spool';
    my $templates = 'templates';

    $form->{id} = $c->param('id');
    $form->{type} = 'invoice';
    $form->{formname} = 'invoice';
    $form->{format} = 'pdf';
    $form->{media} = 'queue';
    $form->{vc} = 'customer';
    $form->{copies} = 1;
    $form->{templates} = $c->slconfig->{templates};
    $form->{IN} = "$form->{formname}.$form->{format}";
    if ($form->{format} =~ /(postscript|pdf)/) {
        $form->{IN} =~ s/$&$/tex/;
    }
 
    my $filename = time;
    $filename .= int rand 10000;
    $filename .= ($form->{format} eq 'postscript') ? '.ps' : '.pdf';
    $form->{OUT} = ">$spool/$filename";

    $form->create_links("AR", $c->slconfig, "customer", 1);
    AA->get_name($c->slconfig, \%$form);
    IS->retrieve_invoice($c->slconfig, \%$form);

    for (qw(invnumber ordnumber ponumber quonumber shippingpoint shipvia waybill notes intnotes)) { $form->{$_} = $form->quote($form->{$_}) }

    my $i = 1;
    my $ml = 1;
    foreach my $ref (@{ $form->{invoice_details} } ) {
      for (keys %$ref) { $form->{"${_}_$i"} = $ref->{$_} }

      $form->{"projectnumber_$i"} = qq|$ref->{projectnumber}--$ref->{project_id}| if $ref->{project_id};
      $form->{"partsgroup_$i"} = qq|$ref->{partsgroup}--$ref->{partsgroup_id}| if $ref->{partsgroup_id};

      $form->{"discount_$i"} = $form->format_amount($c->slconfig, $form->{"discount_$i"} * 100);

      for (qw(netweight grossweight volume)) { $form->{"${_}_$i"} = $form->format_amount($c->slconfig, $form->{"${_}_$i"}) }

      my ($dec) = ($form->{"sellprice_$i"} =~ /\.(\d+)/);
      $dec = length $dec;
      my $decimalplaces = ($dec > $form->{precision}) ? $dec : $form->{precision};

      $form->{"sellprice_$i"} = $form->format_amount($c->slconfig, $form->{"sellprice_$i"}, $decimalplaces);
      $form->{"qty_$i"} = $form->format_amount($c->slconfig, $form->{"qty_$i"} * $ml);
      $form->{"oldqty_$i"} = $form->{"qty_$i"};
      
      for (qw(partnumber sku description unit)) { $form->{"${_}_$i"} = $form->quote($form->{"${_}_$i"}) }
      $form->{rowcount} = $i;
      $i++;
    }
    $form->{rowcount} = $i;

    AA->company_details($c->slconfig, $form);
    IS->invoice_details($c->slconfig, $form);

    $form->parse_template($c->slconfig, $userspath) if $form->{copies};
    $form->{filename} = "$spool/$filename";

    $c->render('printinvoice', form => $form, slconfig => $c->slconfig);
};


any '/artrans' => sub {
    my $c = shift;
    my $form = new Form;
    $form->{db} = 'customer';
    $form->{ARAP} = 'ar';
    @{ $form->{transactions} } = $c->dbs->query('
        SELECT ar.id, ar.invnumber, c.name, ar.transdate, ar.amount, ar.paid, ar.invoice
        FROM ar
        JOIN customer c ON (c.id = ar.customer_id)
        ORDER BY invnumber
    ')->hashes;
    $c->render('artrans', form => $form, slconfig => $c->slconfig );
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


@@ trialform.html.ep
<div class="row">
    <p>NOTE: This form uses websocket protocol to update trial balance below without refreshing page.
</div>

<div class="col-sm-4">
    <div class="row">
        <div class="form-group">
            <label for="fromdate" class="control-label col-sm-4">From</label>
            <div class="col-sm-8">
                <input type=text id="fromdate" class="form-control" name=fromdate>
            </div>
        </div>
    </div>
    <div class="row">
        <div class="form-group">
            <label for="todate" class="control-label col-sm-4">To</label>
            <div class="col-sm-8">
                <input type=text id="todate" class="form-control" name=todate>
            </div>
        </div>
    </div>
</div>

<div>
<input type=submit value="Update" onclick="updatetrial()">
</div>


@@ trial.html.ep
% layout 'default';
% title 'Trial Balance';
%= include 'menu';

<h1>Trial Balance</h1>

%= include 'trialform';

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
%= include 'trialrow';
</tbody>
</table>
%= javascript begin
    function updatetrial () {
      if (!("WebSocket" in window)) {
        alert('WebSockets not supported!');
        return;
      }
      var ws = new WebSocket("<%= url_for('updatetrial')->to_abs %>");
      ws.onopen = function () {
        var fromdate = $('#fromdate');
        var todate = $('#todate');
        ws.send(JSON.stringify([fromdate.val(), todate.val()]));
        fromdate.val('');
        todate.val('');
      };
      ws.onmessage = function (evt) {
        var data = JSON.parse(evt.data);
        $('#trial').replaceWith(data.row);
      };
    }
%= end
<br/>
<pre>

@@ trialrow.html.ep
<tr>
<td colspan=6>
<pre>
%= dumper(time());
</pre>
</td>
</tr>
</tr>
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


@@ printinvoice.html.ep
% layout 'default';
% title 'AR Transactions';
%= include 'menu';
<h2>Invoice printed to queue</h2>
<a href="<%= $form->{filename} %>" target="_blank">View invoice</a>

@@ artrans.html.ep
% layout 'default';
% title 'AR Transactions';
%= include 'menu';

<h1>AR Transactions</h1>

<table class="table table-striped">
<thead>
<tr>
    <th>Invoice</th>
    <th>Date</th>
    <th>Customer</th>
    <th>Amount</th>
    <th>Paid</th>
    <th>&nbsp;</th>
</tr>
</thead>
<tbody id="artrans">
%= include 'artransrow';
</tbody>
</table>
<br/>
<pre>

@@ artransrow.html.ep
<tr>
<td colspan=6>
<pre>
%= dumper(time());
</pre>
</td>
</tr>
</tr>
% for my $row ( @{ $form->{transactions} } ) {
<tr>
  <td><%= $row->{invnumber} %></td>
  <td><%= $row->{transdate} %></td>
  <td><%= $row->{name} %></td>
  <td align="right"><%= $form->format_amount($slconfig, $row->{amount}, 2) %></td>
  <td align="right"><%= $form->format_amount($slconfig, $row->{paid}, 2) %></td>
% if ($row->{invoice}){
  <td><a href="<%= url_for('printinvoice')->to_abs %>?id=<%= $row->{id} %>">Print</a></td>
% } else {
  <td>&nbsp;</td>
% }
</tr>
% }


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
<h3>Adding a customer with JSON from command line</h3>
<pre>curl -X POST -H "Content-Type: application/json" -d @customer.json http://localhost:3000/customers</pre>
<h3>Adding a customer with XML from command line</h3>
<pre>curl -X POST -H "Content-Type: applicaiton/xml" -d @customer.xml http://localhost:3000/customers</pre>
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
    <li><a href="/customers">Customers HTML</a></li>
    <li><a href="/customers.xml">Customers XML</a></li>
    <li><a href="/customers.json">Customers JSON</a></li>
    <li><a href="/departments">Departments</a></li>
    <li><a href="/departments.xml">Departments XML</a></li>
    <li><a href="/departments.json">Departments JSON</a></li>
    <li><a href="/customers">Customers</a></li>
    <li><a href="/artrans">AR Transactions</a></li>
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
  <script src="https://ajax.googleapis.com/ajax/libs/jquery/2.2.4/jquery.min.js"></script>
  <script src="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.6/js/bootstrap.min.js" integrity="sha384-0mSbJDEHialfmuBBQP6A4Qrprq5OVfW37PRR3j5ELqxss1yVqOtnepnHVP9aJ7xS" crossorigin="anonymous"></script>
</html>

